/* Spa
 *
 * Copyright © 2018 Wim Taymans
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

#include <errno.h>
#include <string.h>
#include <stdio.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/cpu.h>
#include <spa/utils/result.h>
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/buffer/alloc.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/pod.h>
#include <spa/debug/types.h>

#define NAME "audioconvert"

#define MAX_PORTS	SPA_AUDIO_MAX_CHANNELS

struct buffer {
	struct spa_list link;
#define BUFFER_FLAG_OUT		(1 << 0)
	uint32_t flags;
	struct spa_buffer *outbuf;
	struct spa_meta_header *h;
};

struct link {
	struct spa_node *out_node;
	uint32_t out_port;
	uint32_t out_flags;
	struct spa_node *in_node;
	uint32_t in_port;
	uint32_t in_flags;
	struct spa_io_buffers io;
	uint32_t min_buffers;
	uint32_t n_buffers;
	struct spa_buffer **buffers;
	unsigned int negotiated:1;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_cpu *cpu;

	uint32_t max_align;

	struct spa_hook_list hooks;

	uint64_t info_all;
	struct spa_node_info info;
#define IDX_EnumPortConfig	0
#define IDX_PortConfig		1
#define IDX_PropInfo		2
#define IDX_Props		3
	struct spa_param_info params[4];
	uint32_t param_flags[4];

	int n_links;
	struct link links[8];
	int n_nodes;
	struct spa_node *nodes[8];

	enum spa_param_port_config_mode mode[2];
	bool fmt_removing[2];

	struct spa_handle *hnd_merger;
	struct spa_handle *hnd_convert_in;
	struct spa_handle *hnd_channelmix;
	struct spa_handle *hnd_resample;
	struct spa_handle *hnd_convert_out;
	struct spa_handle *hnd_splitter;

	struct spa_node *merger;
	struct spa_node *convert_in;
	struct spa_node *channelmix;
	struct spa_node *resample;
	struct spa_node *convert_out;
	struct spa_node *splitter;

	struct spa_node *fmt[2];
	struct spa_hook fmt_listener[2];
	bool have_fmt_listener[2];

	struct spa_hook listener[2];

	unsigned int started:1;
	unsigned int add_listener:1;
};

#define IS_MONITOR_PORT(this,dir,port_id) (dir == SPA_DIRECTION_OUTPUT && port_id > 0 &&	\
		this->mode[SPA_DIRECTION_INPUT] == SPA_PARAM_PORT_CONFIG_MODE_dsp &&		\
		this->mode[SPA_DIRECTION_OUTPUT] != SPA_PARAM_PORT_CONFIG_MODE_dsp)

static void emit_node_info(struct impl *this, bool full)
{
	uint32_t i;

	if (this->add_listener)
		return;

	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		if (this->info.change_mask & SPA_NODE_CHANGE_MASK_PARAMS) {
			for (i = 0; i < SPA_N_ELEMENTS(this->params); i++) {
				if (this->params[i].user > 0) {
					this->params[i].flags ^= SPA_PARAM_INFO_SERIAL;
					this->params[i].user = 0;
				}
			}
		}
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static int make_link(struct impl *this,
		struct spa_node *out_node, uint32_t out_port,
		struct spa_node *in_node, uint32_t in_port, uint32_t min_buffers)
{
	struct link *l = &this->links[this->n_links++];

	l->out_node = out_node;
	l->out_port = out_port;
	l->out_flags = 0;
	l->in_node = in_node;
	l->in_port = in_port;
	l->in_flags = 0;
	l->negotiated = false;
	l->io = SPA_IO_BUFFERS_INIT;
	l->n_buffers = 0;
	l->min_buffers = min_buffers;

	spa_node_port_set_io(out_node,
			     SPA_DIRECTION_OUTPUT, out_port,
			     SPA_IO_Buffers,
			     &l->io, sizeof(l->io));
	spa_node_port_set_io(in_node,
			     SPA_DIRECTION_INPUT, in_port,
			     SPA_IO_Buffers,
			     &l->io, sizeof(l->io));
	return 0;
}

static void clean_link(struct impl *this, struct link *link)
{
	spa_node_port_set_param(link->in_node,
				SPA_DIRECTION_INPUT, link->in_port,
				SPA_PARAM_Format, 0, NULL);
	spa_node_port_set_param(link->out_node,
				SPA_DIRECTION_OUTPUT, link->out_port,
				SPA_PARAM_Format, 0, NULL);
	if (link->buffers)
		free(link->buffers);
	link->buffers = NULL;
}

static int debug_params(struct impl *this, struct spa_node *node,
		enum spa_direction direction, uint32_t port_id, uint32_t id, struct spa_pod *filter)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[4096];
	uint32_t state;
	struct spa_pod *param;
	int res;

	spa_log_error(this->log, "params:");

	state = 0;
	while (true) {
		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		res = spa_node_port_enum_params_sync(node,
				       direction, port_id,
				       id, &state,
				       NULL, &param, &b);
		if (res != 1)
			break;

		spa_debug_pod(2, NULL, param);
	}

	spa_log_error(this->log, "failed filter:");
	if (filter)
		spa_debug_pod(2, NULL, filter);

	return 0;
}

static int negotiate_link_format(struct impl *this, struct link *link)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[4096];
	uint32_t state;
	struct spa_pod *format, *filter;
	int res;

	if (link->negotiated)
		return 0;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	state = 0;
	filter = NULL;
	if ((res = spa_node_port_enum_params_sync(link->out_node,
			       SPA_DIRECTION_OUTPUT, link->out_port,
			       SPA_PARAM_EnumFormat, &state,
			       filter, &format, &b)) != 1) {
		debug_params(this, link->out_node, SPA_DIRECTION_OUTPUT, link->out_port,
				SPA_PARAM_EnumFormat, filter);
		return -ENOTSUP;
	}
	filter = format;
	state = 0;
	if ((res = spa_node_port_enum_params_sync(link->in_node,
			       SPA_DIRECTION_INPUT, link->in_port,
			       SPA_PARAM_EnumFormat, &state,
			       filter, &format, &b)) != 1) {
		debug_params(this, link->in_node, SPA_DIRECTION_INPUT, link->in_port,
				SPA_PARAM_EnumFormat, filter);
		return -ENOTSUP;
	}
	filter = format;

	spa_pod_fixate(filter);

	if ((res = spa_node_port_set_param(link->out_node,
				   SPA_DIRECTION_OUTPUT, link->out_port,
				   SPA_PARAM_Format, 0,
				   filter)) < 0)
		return res;

	if ((res = spa_node_port_set_param(link->in_node,
				   SPA_DIRECTION_INPUT, link->in_port,
				   SPA_PARAM_Format, 0,
				   filter)) < 0)
		return res;

	link->negotiated = true;

	return 0;
}

static int setup_convert(struct impl *this)
{
	int i, j, res;

	spa_log_debug(this->log, "setup convert n_links:%d", this->n_links);

	if (this->n_links > 0)
		return 0;

	this->n_nodes = 0;
	/* unpack */
	this->nodes[this->n_nodes++] = this->fmt[SPA_DIRECTION_INPUT];
	/* down mix */
	this->nodes[this->n_nodes++] = this->channelmix;
	/* resample */
	this->nodes[this->n_nodes++] = this->resample;
	/* pack */
	this->nodes[this->n_nodes++] = this->fmt[SPA_DIRECTION_OUTPUT];

	make_link(this, this->nodes[0], 0, this->nodes[1], 0, 2);
	make_link(this, this->nodes[1], 0, this->nodes[2], 0, 2);
	make_link(this, this->nodes[2], 0, this->nodes[3], 0, 1);

	for (i = 0, j = this->n_links - 1; j >= i; i++, j--) {
		spa_log_debug(this->log, "negotiate %d", i);
		if ((res = negotiate_link_format(this, &this->links[i])) < 0)
			return res;
		spa_log_debug(this->log, "negotiate %d", j);
		if ((res = negotiate_link_format(this, &this->links[j])) < 0)
			return res;
	}
	return 0;
}

static int negotiate_link_buffers(struct impl *this, struct link *link)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	uint32_t state;
	struct spa_pod *param = NULL, *filter;
	int res;
	bool in_alloc, out_alloc;
	uint32_t i, size, buffers, blocks, align, flags;
	uint32_t *aligns;
	struct spa_data *datas;

	if (link->n_buffers > 0)
		return 0;

	state = 0;
	filter = NULL;
	if ((res = spa_node_port_enum_params_sync(link->in_node,
			       SPA_DIRECTION_INPUT, link->in_port,
			       SPA_PARAM_Buffers, &state,
			       filter, &param, &b)) != 1) {
		debug_params(this, link->in_node, SPA_DIRECTION_INPUT, link->in_port,
				SPA_PARAM_Buffers, filter);
		return -ENOTSUP;
	}
	state = 0;
	filter = param;
	if ((res = spa_node_port_enum_params_sync(link->out_node,
			       SPA_DIRECTION_OUTPUT, link->out_port,
			       SPA_PARAM_Buffers, &state,
			       filter, &param, &b)) != 1) {
		debug_params(this, link->out_node, SPA_DIRECTION_OUTPUT, link->out_port,
				SPA_PARAM_Buffers, filter);
		return -ENOTSUP;
	}

	spa_pod_fixate(param);

	in_alloc = SPA_FLAG_IS_SET(link->in_flags,
				SPA_PORT_FLAG_CAN_ALLOC_BUFFERS);
	out_alloc = SPA_FLAG_IS_SET(link->out_flags,
				SPA_PORT_FLAG_CAN_ALLOC_BUFFERS);

	flags = 0;
	if (out_alloc || in_alloc) {
		flags |= SPA_BUFFER_ALLOC_FLAG_NO_DATA;
		if (out_alloc)
			in_alloc = false;
	}

	if (spa_pod_parse_object(param,
		SPA_TYPE_OBJECT_ParamBuffers, NULL,
		SPA_PARAM_BUFFERS_buffers, SPA_POD_Int(&buffers),
		SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(&blocks),
		SPA_PARAM_BUFFERS_size,    SPA_POD_Int(&size),
		SPA_PARAM_BUFFERS_align,   SPA_POD_Int(&align)) < 0)
		return -EINVAL;

	spa_log_debug(this->log, "%p: buffers %d, blocks %d, size %d, align %d %d:%d",
			this, buffers, blocks, size, align, out_alloc, in_alloc);

	align = SPA_MAX(align, this->max_align);

	datas = alloca(sizeof(struct spa_data) * blocks);
	memset(datas, 0, sizeof(struct spa_data) * blocks);
	aligns = alloca(sizeof(uint32_t) * blocks);
	for (i = 0; i < blocks; i++) {
		datas[i].type = SPA_DATA_MemPtr;
		datas[i].flags = SPA_DATA_FLAG_DYNAMIC;
		datas[i].maxsize = size;
		aligns[i] = align;
	}

	buffers = SPA_MAX(link->min_buffers, buffers);

	if (link->buffers)
		free(link->buffers);
	link->buffers = spa_buffer_alloc_array(buffers, flags, 0, NULL, blocks, datas, aligns);
	if (link->buffers == NULL)
		return -errno;

	link->n_buffers = buffers;

	if ((res = spa_node_port_use_buffers(link->out_node,
		       SPA_DIRECTION_OUTPUT, link->out_port,
		       out_alloc ? SPA_NODE_BUFFERS_FLAG_ALLOC : 0,
		       link->buffers, link->n_buffers)) < 0)
		return res;

	if ((res = spa_node_port_use_buffers(link->in_node,
		       SPA_DIRECTION_INPUT, link->in_port,
		       in_alloc ? SPA_NODE_BUFFERS_FLAG_ALLOC : 0,
		       link->buffers, link->n_buffers)) < 0)
		return res;

	return 0;
}

static void flush_convert(struct impl *this)
{
	int i;
	spa_log_debug(this->log, NAME " %p: %d", this, this->n_links);
	for (i = 0; i < this->n_links; i++)
		this->links[i].io.status = SPA_STATUS_OK;
}

static void clean_convert(struct impl *this)
{
	int i;

	spa_log_debug(this->log, NAME " %p: %d", this, this->n_links);

	for (i = 0; i < this->n_links; i++)
		clean_link(this, &this->links[i]);
	this->n_links = 0;
}

static int setup_buffers(struct impl *this, enum spa_direction direction)
{
	int i, res;

	spa_log_debug(this->log, NAME " %p: %d %d", this, direction, this->n_links);

	if (direction == SPA_DIRECTION_INPUT) {
		for (i = 0; i < this->n_links; i++) {
			if ((res = negotiate_link_buffers(this, &this->links[i])) < 0)
				spa_log_error(this->log, NAME " %p: buffers %d failed %s",
						this, i, spa_strerror(res));
		}
	} else {
		for (i = this->n_links-1; i >= 0 ; i--) {
			if ((res = negotiate_link_buffers(this, &this->links[i])) < 0)
				spa_log_error(this->log, NAME " %p: buffers %d failed %s",
						this, i, spa_strerror(res));
		}
	}

	return 0;
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumPortConfig:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_INPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_OUTPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp));
			break;
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_INPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_convert));
			break;
		case 3:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_OUTPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_convert));
			break;
		default:
			return 0;
		}
		break;

	case SPA_PARAM_PortConfig:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_INPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(this->mode[SPA_DIRECTION_INPUT]));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamPortConfig, id,
				SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(SPA_DIRECTION_OUTPUT),
				SPA_PARAM_PORT_CONFIG_mode,      SPA_POD_Id(this->mode[SPA_DIRECTION_OUTPUT]));
			break;
		default:
			return 0;
		}
		break;

	case SPA_PARAM_PropInfo:
		return spa_node_enum_params(this->channelmix, seq, id, start, num, filter);

	case SPA_PARAM_Props:
		if (this->fmt[SPA_DIRECTION_INPUT] == this->merger)
			return spa_node_enum_params(this->merger, seq, id, start, num, filter);
		else
			return spa_node_enum_params(this->channelmix, seq, id, start, num, filter);

	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, NAME " %p: io %d %p/%zd", this, id, data, size);

	switch (id) {
	case SPA_IO_Position:
		res = spa_node_set_io(this->resample, id, data, size);
		res = spa_node_set_io(this->fmt[0], id, data, size);
		res = spa_node_set_io(this->fmt[1], id, data, size);
		break;
	default:
		res = -ENOENT;
		break;
	}
	return res;
}

static void on_node_result(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct impl *this = data;
	spa_log_trace(this->log, "%p: result %d %d", this, seq, res);
	spa_node_emit_result(&this->hooks, seq, res, type, result);
}

static void fmt_input_port_info(void *data,
		enum spa_direction direction, uint32_t port,
		const struct spa_port_info *info)
{
	struct impl *this = data;

	if (this->fmt_removing[direction])
		info = NULL;

	if (direction == SPA_DIRECTION_INPUT ||
	    IS_MONITOR_PORT(this, direction, port))
		spa_node_emit_port_info(&this->hooks, direction, port, info);
}

static struct spa_node_events fmt_input_events = {
	SPA_VERSION_NODE_EVENTS,
	.port_info = fmt_input_port_info,
	.result = on_node_result,
};

static void fmt_output_port_info(void *data,
		enum spa_direction direction, uint32_t port,
		const struct spa_port_info *info)
{
	struct impl *this = data;

	if (this->fmt_removing[direction])
		info = NULL;

	if (direction == SPA_DIRECTION_OUTPUT)
		spa_node_emit_port_info(&this->hooks, direction, port, info);
}

static struct spa_node_events fmt_output_events = {
	SPA_VERSION_NODE_EVENTS,
	.port_info = fmt_output_port_info,
	.result = on_node_result,
};

static void on_channelmix_info(void *data, const struct spa_node_info *info)
{
	struct impl *this = data;
	uint32_t i;

	if ((info->change_mask & SPA_NODE_CHANGE_MASK_PARAMS) == 0)
		return;

	for (i = 0; i < info->n_params; i++) {
		uint32_t idx;

		switch (info->params[i].id) {
		case SPA_PARAM_PropInfo:
			idx = IDX_PropInfo;
			break;
		case SPA_PARAM_Props:
			idx = IDX_Props;
			break;
		default:
			continue;
		}
		if (!this->add_listener &&
		    this->param_flags[idx] == info->params[i].flags)
			continue;

		this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
		this->param_flags[idx] = info->params[i].flags;
		this->params[idx].flags =
			(this->params[idx].flags & SPA_PARAM_INFO_SERIAL) |
			(info->params[i].flags & SPA_PARAM_INFO_READWRITE);

		if (!this->add_listener)
			this->params[idx].user++;
	}
	emit_node_info(this, false);
}

static struct spa_node_events channelmix_events = {
	SPA_VERSION_NODE_EVENTS,
	.info = on_channelmix_info,
	.result = on_node_result,
};

static struct spa_node_events resample_events = {
	SPA_VERSION_NODE_EVENTS,
	.result = on_node_result,
};

static int reconfigure_mode(struct impl *this, enum spa_param_port_config_mode mode,
		enum spa_direction direction, bool monitor, struct spa_audio_info *info)
{
	int res = 0;
	struct spa_node *old, *new;
	bool do_signal;

	spa_log_debug(this->log, NAME " %p: mode %d", this, mode);

	/* old node on input/output */
	old = this->fmt[direction];

	/* decide on new node based on mode and direction */
	switch (mode) {
	case SPA_PARAM_PORT_CONFIG_MODE_convert:
		new = direction == SPA_DIRECTION_INPUT ?  this->convert_in : this->convert_out;
		break;

	case SPA_PARAM_PORT_CONFIG_MODE_dsp:
		new = direction == SPA_DIRECTION_INPUT ?  this->merger : this->splitter;
		break;
	default:
		return -EIO;
	}

	this->mode[direction] = mode;
	clean_convert(this);

	this->fmt[direction] = new;

	/* signal if we change nodes or when DSP config changes */
	do_signal = this->fmt[direction] != old ||
		mode == SPA_PARAM_PORT_CONFIG_MODE_dsp;

	if (do_signal) {
		/* change, remove old ports. We trigger a new port_info event
		 * on the old node with info set to NULL to mark delete */
		if (this->have_fmt_listener[direction]) {
			spa_hook_remove(&this->fmt_listener[direction]);

			this->fmt_removing[direction] = true;
			spa_node_add_listener(old,
				&this->fmt_listener[direction],
				direction == SPA_DIRECTION_INPUT ?
					&fmt_input_events : &fmt_output_events,
				this);
			this->fmt_removing[direction] = false;

			spa_hook_remove(&this->fmt_listener[direction]);
			this->have_fmt_listener[direction] = false;
		}
	}

	if (info) {
		struct spa_pod_builder b = { 0 };
		uint8_t buffer[1024];
		struct spa_pod *param;

		spa_log_debug(this->log, NAME " %p: port config %d", this, info->info.raw.channels);

		spa_pod_builder_init(&b, buffer, sizeof(buffer));

		param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info->info.raw);
		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
			SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(direction),
			SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
			SPA_PARAM_PORT_CONFIG_monitor,		SPA_POD_Bool(monitor),
			SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));
		res = spa_node_set_param(this->fmt[direction], SPA_PARAM_PortConfig, 0, param);
		if (res < 0)
			return res;

		this->info.change_mask |= SPA_NODE_CHANGE_MASK_FLAGS | SPA_NODE_CHANGE_MASK_PARAMS;
		this->info.flags &= ~SPA_NODE_FLAG_NEED_CONFIGURE;
		this->params[IDX_Props].user++;
	}

	/* notify ports of new node */
	if (do_signal) {
		if (this->have_fmt_listener[direction])
			spa_hook_remove(&this->fmt_listener[direction]);

		spa_node_add_listener(this->fmt[direction],
				&this->fmt_listener[direction],
				direction == SPA_DIRECTION_INPUT ?
					&fmt_input_events : &fmt_output_events,
				this);
		this->have_fmt_listener[direction] = true;
	}
	emit_node_info(this, false);

	return 0;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	int res = 0;
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_PortConfig:
	{
		enum spa_direction dir;
		enum spa_param_port_config_mode mode;
		struct spa_pod *format = NULL;
		struct spa_audio_info info = { 0, }, *infop = NULL;
		int monitor = false;

		if (spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamPortConfig, NULL,
				SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(&dir),
				SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(&mode),
				SPA_PARAM_PORT_CONFIG_monitor,		SPA_POD_OPT_Bool(&monitor),
				SPA_PARAM_PORT_CONFIG_format,		SPA_POD_OPT_Pod(&format)) < 0)
			return -EINVAL;

		if (format) {
			if (!spa_pod_is_object_type(format, SPA_TYPE_OBJECT_Format))
				return -EINVAL;

			if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
				return res;

			if (info.media_type != SPA_MEDIA_TYPE_audio ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
				return -ENOTSUP;

			if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
				return -EINVAL;

			if (info.info.raw.channels == 0 || info.info.raw.rate == 0)
				return -EINVAL;

			infop = &info;
		}

		spa_log_debug(this->log, "mode:%d direction:%d %d", mode, dir, monitor);

		switch (mode) {
		case SPA_PARAM_PORT_CONFIG_MODE_none:
		case SPA_PARAM_PORT_CONFIG_MODE_passthrough:
			return -ENOTSUP;

		case SPA_PARAM_PORT_CONFIG_MODE_convert:
			break;

		case SPA_PARAM_PORT_CONFIG_MODE_dsp:
			info.info.raw.format = SPA_AUDIO_FORMAT_F32P;
			break;
		default:
			return -EINVAL;
		}

		res = reconfigure_mode(this, mode, dir, monitor, infop);

		break;
	}
	case SPA_PARAM_Props:
	{
		if (this->fmt[SPA_DIRECTION_INPUT] == this->merger)
			res = spa_node_set_param(this->merger, id, flags, param);
		res = spa_node_set_param(this->channelmix, id, flags, param);
		break;
	}
	default:
		res = -ENOTSUP;
		break;
	}
	return res;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;
	int res, i;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		if ((res = setup_convert(this)) < 0)
			return res;
		if ((res = setup_buffers(this, SPA_DIRECTION_INPUT)) < 0)
			return res;
		break;

	case SPA_NODE_COMMAND_Suspend:
		clean_convert(this);
		SPA_FALLTHROUGH
	case SPA_NODE_COMMAND_Flush:
		flush_convert(this);
		SPA_FALLTHROUGH
	case SPA_NODE_COMMAND_Pause:
		this->started = false;
		break;
	default:
		return -ENOTSUP;
	}

	for (i = 0; i < this->n_nodes; i++) {
		if ((res = spa_node_send_command(this->nodes[i], command)) < 0) {
			spa_log_error(this->log, NAME " %p: can't send command to node %d: %s",
					this, i, spa_strerror(res));
		}
	}

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		this->started = true;
		break;
	}

	return 0;
}

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;
	struct spa_hook l[4];

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	spa_log_trace(this->log, "%p: add listener %p", this, listener);

	this->add_listener = true;

	spa_zero(l);
	spa_node_add_listener(this->fmt[SPA_DIRECTION_INPUT],
			&l[0], &fmt_input_events, this);
	spa_node_add_listener(this->channelmix,
			&l[1], &channelmix_events, this);
	spa_node_add_listener(this->resample,
			&l[2], &resample_events, this);
	spa_node_add_listener(this->fmt[SPA_DIRECTION_OUTPUT],
			&l[3], &fmt_output_events, this);

	spa_hook_remove(&l[0]);
	spa_hook_remove(&l[1]);
	spa_hook_remove(&l[2]);
	spa_hook_remove(&l[3]);

	this->add_listener = false;

	emit_node_info(this, true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *user_data)
{
	return -ENOTSUP;
}

static int impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	return -ENOTSUP;
}

static int
impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	return -ENOTSUP;
}

static int
impl_node_port_enum_params(void *object, int seq,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t id, uint32_t start, uint32_t num,
			   const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	spa_log_debug(this->log, NAME" %p: port %d.%d %d %u", this, direction, port_id, seq, id);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_PropInfo:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_volume),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(1.0, 0.0, 10.0));
			break;
		default:
			return 0;
		}
		break;

	case SPA_PARAM_IO:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,	SPA_POD_Id(SPA_IO_Buffers),
				SPA_PARAM_IO_size,	SPA_POD_Int(sizeof(struct spa_io_buffers)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_RateMatch),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_rate_match)));
			break;
		default:
			return 0;
		}
		break;
	default:
	{
		struct spa_node *target;

		if (IS_MONITOR_PORT(this, direction, port_id))
			target = this->fmt[SPA_DIRECTION_INPUT];
		else
			target = this->fmt[direction];

		return spa_node_port_enum_params(target, seq, direction, port_id,
			id, start, num, filter);
	}
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct impl *this = object;
	int res;
	struct spa_node *target;
	bool is_monitor;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, NAME " %p: set param %u on port %d:%d %p",
				this, id, direction, port_id, param);

	is_monitor = IS_MONITOR_PORT(this, direction, port_id);
	if (is_monitor)
		target = this->fmt[SPA_DIRECTION_INPUT];
	else
		target = this->fmt[direction];

	if ((res = spa_node_port_set_param(target,
					direction, port_id, id, flags, param)) < 0)
		return res;

	return res;
}

static int
impl_node_port_use_buffers(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   struct spa_buffer **buffers,
			   uint32_t n_buffers)
{
	struct impl *this = object;
	int res;
	struct spa_node *target;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (IS_MONITOR_PORT(this, direction, port_id))
		target = this->fmt[SPA_DIRECTION_INPUT];
	else
		target = this->fmt[direction];

	if ((res = spa_node_port_use_buffers(target,
					direction, port_id, flags, buffers, n_buffers)) < 0)
		return res;

	return res;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction, uint32_t port_id,
		      uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	struct spa_node *target;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, "set io %d %d %d", id, direction, port_id);

	switch (id) {
	case SPA_IO_RateMatch:
		res = spa_node_port_set_io(this->resample, direction, 0, id, data, size);
		break;
	default:
		if (IS_MONITOR_PORT(this, direction, port_id))
			target = this->fmt[SPA_DIRECTION_INPUT];
		else
			target = this->fmt[direction];

		res = spa_node_port_set_io(target, direction, port_id, id, data, size);
		break;
	}
	return res;
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;
	struct spa_node *target;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (IS_MONITOR_PORT(this, SPA_DIRECTION_OUTPUT, port_id))
		target = this->fmt[SPA_DIRECTION_INPUT];
	else
		target = this->fmt[SPA_DIRECTION_OUTPUT];

	return spa_node_port_reuse_buffer(target, port_id, buffer_id);
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	int r, i, res = SPA_STATUS_OK;
	int ready;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_trace_fp(this->log, NAME " %p: process %d %d", this, this->n_links, this->n_nodes);

	while (1) {
		res = SPA_STATUS_OK;
		ready = 0;
		for (i = 0; i < this->n_nodes; i++) {
			r = spa_node_process(this->nodes[i]);

			spa_log_trace_fp(this->log, NAME " %p: process %d %d: %s",
					this, i, r, r < 0 ? spa_strerror(r) : "ok");

			if (SPA_UNLIKELY(r < 0))
				return r;

			if (r & SPA_STATUS_HAVE_DATA)
				ready++;

			if (SPA_UNLIKELY(i == 0))
				res |= r & SPA_STATUS_NEED_DATA;
			if (SPA_UNLIKELY(i == this->n_nodes-1))
				res |= r & (SPA_STATUS_HAVE_DATA | SPA_STATUS_DRAINED);
		}
		if (res & SPA_STATUS_HAVE_DATA)
			break;
		if (ready == 0)
			break;
	}

	spa_log_trace_fp(this->log, NAME " %p: process result: %d", this, res);

	return res;
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_node_add_listener,
	.set_callbacks = impl_node_set_callbacks,
	.enum_params = impl_node_enum_params,
	.set_param = impl_node_set_param,
	.set_io = impl_node_set_io,
	.send_command = impl_node_send_command,
	.add_port = impl_node_add_port,
	.remove_port = impl_node_remove_port,
	.port_enum_params = impl_node_port_enum_params,
	.port_set_param = impl_node_port_set_param,
	.port_use_buffers = impl_node_port_use_buffers,
	.port_set_io = impl_node_port_set_io,
	.port_reuse_buffer = impl_node_port_reuse_buffer,
	.process = impl_node_process,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Node) == 0)
		*interface = &this->node;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	this = (struct impl *) handle;

	clean_convert(this);

	spa_handle_clear(this->hnd_merger);
	spa_handle_clear(this->hnd_convert_in);
	spa_handle_clear(this->hnd_channelmix);
	spa_handle_clear(this->hnd_resample);
	spa_handle_clear(this->hnd_convert_out);
	spa_handle_clear(this->hnd_splitter);

	return 0;
}

extern const struct spa_handle_factory spa_fmtconvert_factory;
extern const struct spa_handle_factory spa_channelmix_factory;
extern const struct spa_handle_factory spa_resample_factory;
extern const struct spa_handle_factory spa_splitter_factory;
extern const struct spa_handle_factory spa_merger_factory;

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	size_t size;

	size = sizeof(struct impl);
	size += spa_handle_factory_get_size(&spa_merger_factory, params);
	size += spa_handle_factory_get_size(&spa_fmtconvert_factory, params);
	size += spa_handle_factory_get_size(&spa_channelmix_factory, params);
	size += spa_handle_factory_get_size(&spa_resample_factory, params);
	size += spa_handle_factory_get_size(&spa_fmtconvert_factory, params);
	size += spa_handle_factory_get_size(&spa_splitter_factory, params);

	return size;
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;
	size_t size;
	void *iface;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if (this->cpu)
		this->max_align = spa_cpu_get_max_align(this->cpu);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = MAX_PORTS;
	this->info.max_output_ports = MAX_PORTS;
	this->info.flags = SPA_NODE_FLAG_RT |
		SPA_NODE_FLAG_IN_PORT_CONFIG |
		SPA_NODE_FLAG_OUT_PORT_CONFIG |
		SPA_NODE_FLAG_NEED_CONFIGURE;
	this->params[IDX_EnumPortConfig] = SPA_PARAM_INFO(SPA_PARAM_EnumPortConfig, SPA_PARAM_INFO_READ);
	this->params[IDX_PortConfig] = SPA_PARAM_INFO(SPA_PARAM_PortConfig, SPA_PARAM_INFO_READWRITE);
	this->params[IDX_PropInfo] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[IDX_Props] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 4;

	this->hnd_merger = SPA_MEMBER(this, sizeof(struct impl), struct spa_handle);
	spa_handle_factory_init(&spa_merger_factory,
				this->hnd_merger,
				info, support, n_support);
	size = spa_handle_factory_get_size(&spa_merger_factory, info);

	this->hnd_convert_in = SPA_MEMBER(this->hnd_merger, size, struct spa_handle);
	spa_handle_factory_init(&spa_fmtconvert_factory,
				this->hnd_convert_in,
				info, support, n_support);
	size = spa_handle_factory_get_size(&spa_fmtconvert_factory, info);

	this->hnd_channelmix = SPA_MEMBER(this->hnd_convert_in, size, struct spa_handle);
	spa_handle_factory_init(&spa_channelmix_factory,
				this->hnd_channelmix,
				info, support, n_support);
	size = spa_handle_factory_get_size(&spa_channelmix_factory, info);

	this->hnd_resample = SPA_MEMBER(this->hnd_channelmix, size, struct spa_handle);
	spa_handle_factory_init(&spa_resample_factory,
				this->hnd_resample,
				info, support, n_support);
	size = spa_handle_factory_get_size(&spa_resample_factory, info);

	this->hnd_convert_out = SPA_MEMBER(this->hnd_resample, size, struct spa_handle);
	spa_handle_factory_init(&spa_fmtconvert_factory,
				this->hnd_convert_out,
				info, support, n_support);
	size = spa_handle_factory_get_size(&spa_fmtconvert_factory, info);

	this->hnd_splitter = SPA_MEMBER(this->hnd_convert_out, size, struct spa_handle);
	spa_handle_factory_init(&spa_splitter_factory,
				this->hnd_splitter,
				info, support, n_support);

	spa_handle_get_interface(this->hnd_merger, SPA_TYPE_INTERFACE_Node, &iface);
	this->merger = iface;
	spa_handle_get_interface(this->hnd_convert_in, SPA_TYPE_INTERFACE_Node, &iface);
	this->convert_in = iface;
	spa_handle_get_interface(this->hnd_channelmix, SPA_TYPE_INTERFACE_Node, &iface);
	this->channelmix = iface;
	spa_handle_get_interface(this->hnd_resample, SPA_TYPE_INTERFACE_Node, &iface);
	this->resample = iface;
	spa_handle_get_interface(this->hnd_convert_out, SPA_TYPE_INTERFACE_Node, &iface);
	this->convert_out = iface;
	spa_handle_get_interface(this->hnd_splitter, SPA_TYPE_INTERFACE_Node, &iface);
	this->splitter = iface;

	reconfigure_mode(this, SPA_PARAM_PORT_CONFIG_MODE_convert, SPA_DIRECTION_OUTPUT, false, NULL);
	reconfigure_mode(this, SPA_PARAM_PORT_CONFIG_MODE_convert, SPA_DIRECTION_INPUT, false, NULL);

	spa_node_add_listener(this->channelmix,
			&this->listener[0], &channelmix_events, this);
	spa_node_add_listener(this->resample,
			&this->listener[1], &resample_events, this);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{ SPA_TYPE_INTERFACE_Node, },
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*info = &impl_interfaces[*index];
		break;
	default:
		return 0;
	}
	(*index)++;
	return 1;
}

const struct spa_handle_factory spa_audioconvert_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_CONVERT,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
