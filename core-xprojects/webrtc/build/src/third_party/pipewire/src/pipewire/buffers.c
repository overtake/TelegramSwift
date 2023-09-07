/* PipeWire
 *
 * Copyright © 2019 Wim Taymans
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <spa/node/utils.h>
#include <spa/pod/parser.h>
#include <spa/param/param.h>
#include <spa/buffer/alloc.h>

#include <spa/debug/node.h>
#include <spa/debug/pod.h>
#include <spa/debug/format.h>

#include "pipewire/keys.h"
#include "pipewire/private.h"

#include "buffers.h"

#define NAME "buffers"

#define MAX_ALIGN	32
#define MAX_BLOCKS	64u

struct port {
	struct spa_node *node;
	enum spa_direction direction;
	uint32_t port_id;
};

/* Allocate an array of buffers that can be shared */
static int alloc_buffers(struct pw_mempool *pool,
			 uint32_t n_buffers,
			 uint32_t n_params,
			 struct spa_pod **params,
			 uint32_t n_datas,
			 uint32_t *data_sizes,
			 int32_t *data_strides,
			 uint32_t *data_aligns,
			 uint32_t *data_types,
			 uint32_t flags,
			 struct pw_buffers *allocation)
{
	struct spa_buffer **buffers;
	void *skel, *data;
	uint32_t i;
	uint32_t n_metas;
	struct spa_meta *metas;
	struct spa_data *datas;
	struct pw_memblock *m;
	struct spa_buffer_alloc_info info = { 0, };

	if (!SPA_FLAG_IS_SET(flags, PW_BUFFERS_FLAG_SHARED))
		SPA_FLAG_SET(info.flags, SPA_BUFFER_ALLOC_FLAG_INLINE_ALL);

	n_metas = 0;

	metas = alloca(sizeof(struct spa_meta) * n_params);
	datas = alloca(sizeof(struct spa_data) * n_datas);

	/* collect metadata */
	for (i = 0; i < n_params; i++) {
		if (spa_pod_is_object_type (params[i], SPA_TYPE_OBJECT_ParamMeta)) {
			uint32_t type, size;

			if (spa_pod_parse_object(params[i],
				SPA_TYPE_OBJECT_ParamMeta, NULL,
				SPA_PARAM_META_type, SPA_POD_Id(&type),
				SPA_PARAM_META_size, SPA_POD_Int(&size)) < 0)
				continue;

			pw_log_debug(NAME" %p: enable meta %d %d", allocation, type, size);

			metas[n_metas].type = type;
			metas[n_metas].size = size;
			n_metas++;
		}
	}

	for (i = 0; i < n_datas; i++) {
		struct spa_data *d = &datas[i];

		spa_zero(*d);
		if (data_sizes[i] > 0) {
			/* we allocate memory */
			d->type = SPA_DATA_MemPtr;
			d->maxsize = data_sizes[i];
			SPA_FLAG_SET(d->flags, SPA_DATA_FLAG_READWRITE);
		} else {
			/* client allocates memory. Set the mask of possible
			 * types in the type field */
			d->type = data_types[i];
			d->maxsize = 0;
		}
		if (SPA_FLAG_IS_SET(flags, PW_BUFFERS_FLAG_DYNAMIC))
			SPA_FLAG_SET(d->flags, SPA_DATA_FLAG_DYNAMIC);
	}

        spa_buffer_alloc_fill_info(&info, n_metas, metas, n_datas, datas, data_aligns);

	buffers = calloc(1, info.max_align + n_buffers * (sizeof(struct spa_buffer *) + info.skel_size));
	if (buffers == NULL)
		return -errno;

	skel = SPA_MEMBER(buffers, n_buffers * sizeof(struct spa_buffer *), void);
	skel = SPA_PTR_ALIGN(skel, info.max_align, void);

	if (SPA_FLAG_IS_SET(flags, PW_BUFFERS_FLAG_SHARED)) {
		/* pointer to buffer structures */
		m = pw_mempool_alloc(pool,
				PW_MEMBLOCK_FLAG_READWRITE |
				PW_MEMBLOCK_FLAG_SEAL |
				PW_MEMBLOCK_FLAG_MAP,
				SPA_DATA_MemFd,
				n_buffers * info.mem_size);
		if (m == NULL) {
			free(buffers);
			return -errno;
		}

		data = m->map->ptr;
	} else {
		m = NULL;
		data = NULL;
	}

	pw_log_debug(NAME" %p: layout buffers skel:%p data:%p buffers:%p",
			allocation, skel, data, buffers);
	spa_buffer_alloc_layout_array(&info, n_buffers, buffers, skel, data);

	allocation->mem = m;
	allocation->n_buffers = n_buffers;
	allocation->buffers = buffers;
	allocation->flags = flags;

	return 0;
}

static int
param_filter(struct pw_buffers *this,
	     struct port *in_port,
	     struct port *out_port,
	     uint32_t id,
	     struct spa_pod_builder *result)
{
	uint8_t ibuf[4096];
        struct spa_pod_builder ib = { 0 };
	struct spa_pod *oparam, *iparam;
	uint32_t iidx, oidx, num = 0;
	int in_res = -EIO, out_res = -EIO;

	for (iidx = 0;;) {
	        spa_pod_builder_init(&ib, ibuf, sizeof(ibuf));
		pw_log_debug(NAME" %p: input param %d id:%d", this, iidx, id);
		in_res = spa_node_port_enum_params_sync(in_port->node,
						in_port->direction, in_port->port_id,
						id, &iidx, NULL, &iparam, &ib);

		if (in_res < 1) {
			/* in_res == -ENOENT  : unknown parameter, assume NULL and we will
			 *                      exit the loop below.
			 * in_res < 1         : some error or no data, exit now
			 */
			if (in_res == -ENOENT)
				iparam = NULL;
			else
				break;
		}

		pw_log_pod(SPA_LOG_LEVEL_DEBUG, iparam);

		for (oidx = 0;;) {
			pw_log_debug(NAME" %p: output param %d id:%d", this, oidx, id);
			out_res = spa_node_port_enum_params_sync(out_port->node,
						out_port->direction, out_port->port_id,
						id, &oidx, iparam, &oparam, result);

			/* out_res < 1 : no value or error, exit now */
			if (out_res < 1)
				break;

			pw_log_pod(SPA_LOG_LEVEL_DEBUG, oparam);
			num++;
		}
		if (out_res == -ENOENT && iparam) {
			/* no output param known but we have an input param,
			 * use that one */
			spa_pod_builder_raw_padded(result, iparam, SPA_POD_SIZE(iparam));
			num++;
		}
		/* no more input values, exit */
		if (in_res < 1)
			break;
	}
	if (num == 0) {
		if (out_res == -ENOENT && in_res == -ENOENT)
			return 0;
		if (in_res < 0)
			return in_res;
		if (out_res < 0)
			return out_res;
		return -EINVAL;
	}
	return num;
}

static struct spa_pod *find_param(struct spa_pod **params, uint32_t n_params, uint32_t type)
{
	uint32_t i;

	for (i = 0; i < n_params; i++) {
		if (spa_pod_is_object_type(params[i], type))
			return params[i];
	}
	return NULL;
}

SPA_EXPORT
int pw_buffers_negotiate(struct pw_context *context, uint32_t flags,
		struct spa_node *outnode, uint32_t out_port_id,
		struct spa_node *innode, uint32_t in_port_id,
		struct pw_buffers *result)
{
	struct spa_pod **params, *param;
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	uint32_t i, offset, n_params;
	uint32_t max_buffers, blocks;
	size_t minsize, stride, align;
	uint32_t *data_sizes;
	int32_t *data_strides;
	uint32_t *data_aligns;
	uint32_t types, *data_types;
	struct port output = { outnode, SPA_DIRECTION_OUTPUT, out_port_id };
	struct port input = { innode, SPA_DIRECTION_INPUT, in_port_id };
	const char *str;
	int res;

	res = param_filter(result, &input, &output, SPA_PARAM_Buffers, &b);
	if (res < 0) {
		pw_context_debug_port_params(context, input.node, input.direction,
				input.port_id, SPA_PARAM_Buffers, res,
				"input param");
		pw_context_debug_port_params(context, output.node, output.direction,
				output.port_id, SPA_PARAM_Buffers, res,
				"output param");
		return res;
	}
	n_params = res;
	if ((res = param_filter(result, &input, &output, SPA_PARAM_Meta, &b)) > 0)
		n_params += res;

	params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0, offset = 0; i < n_params; i++) {
		params[i] = SPA_MEMBER(buffer, offset, struct spa_pod);
		spa_pod_fixate(params[i]);
		pw_log_debug(NAME" %p: fixated param %d:", result, i);
		pw_log_pod(SPA_LOG_LEVEL_DEBUG, params[i]);
		offset += SPA_ROUND_UP_N(SPA_POD_SIZE(params[i]), 8);
	}

	max_buffers = context->defaults.link_max_buffers;

	if ((str = pw_properties_get(context->properties, PW_KEY_CPU_MAX_ALIGN)) != NULL)
		align = pw_properties_parse_int(str);
	else
		align = MAX_ALIGN;

	minsize = stride = 0;
	types = SPA_ID_INVALID; /* bitmask of allowed types */
	blocks = 1;

	param = find_param(params, n_params, SPA_TYPE_OBJECT_ParamBuffers);
	if (param) {
		uint32_t qmax_buffers = max_buffers,
		    qminsize = minsize, qstride = stride, qalign = align;
		uint32_t qtypes = types, qblocks = blocks;

		spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_ParamBuffers, NULL,
			SPA_PARAM_BUFFERS_buffers,  SPA_POD_OPT_Int(&qmax_buffers),
			SPA_PARAM_BUFFERS_blocks,   SPA_POD_OPT_Int(&qblocks),
			SPA_PARAM_BUFFERS_size,     SPA_POD_OPT_Int(&qminsize),
			SPA_PARAM_BUFFERS_stride,   SPA_POD_OPT_Int(&qstride),
			SPA_PARAM_BUFFERS_align,    SPA_POD_OPT_Int(&qalign),
			SPA_PARAM_BUFFERS_dataType, SPA_POD_OPT_Int(&qtypes));

		max_buffers =
		    qmax_buffers == 0 ? max_buffers : SPA_MIN(qmax_buffers,
						      max_buffers);
		blocks = SPA_CLAMP(qblocks, blocks, MAX_BLOCKS);
		minsize = SPA_MAX(minsize, qminsize);
		stride = SPA_MAX(stride, qstride);
		align = SPA_MAX(align, qalign);
		types = qtypes;

		pw_log_debug(NAME" %p: %d %d %d %d %d %d -> %d %zd %zd %d %zd %d", result,
				qblocks, qminsize, qstride, qmax_buffers, qalign, qtypes,
				blocks, minsize, stride, max_buffers, align, types);
	} else {
		pw_log_warn(NAME" %p: no buffers param", result);
		minsize = 8192;
		max_buffers = 2;
	}

	if (SPA_FLAG_IS_SET(flags, PW_BUFFERS_FLAG_NO_MEM))
		minsize = 0;

	data_sizes = alloca(sizeof(uint32_t) * blocks);
	data_strides = alloca(sizeof(int32_t) * blocks);
	data_aligns = alloca(sizeof(uint32_t) * blocks);
	data_types = alloca(sizeof(uint32_t) * blocks);

	for (i = 0; i < blocks; i++) {
		data_sizes[i] = minsize;
		data_strides[i] = stride;
		data_aligns[i] = align;
		data_types[i] = types;
	}

	if ((res = alloc_buffers(context->pool,
				 max_buffers,
				 n_params,
				 params,
				 blocks,
				 data_sizes, data_strides,
				 data_aligns, data_types,
				 flags,
				 result)) < 0) {
		pw_log_error(NAME" %p: can't alloc buffers: %s", result, spa_strerror(res));
	}

	return res;
}

SPA_EXPORT
void pw_buffers_clear(struct pw_buffers *buffers)
{
	pw_log_debug(NAME" %p: clear %d buffers:%p", buffers, buffers->n_buffers, buffers->buffers);
	if (buffers->mem)
		pw_memblock_unref(buffers->mem);
	free(buffers->buffers);
	spa_zero(*buffers);
}
