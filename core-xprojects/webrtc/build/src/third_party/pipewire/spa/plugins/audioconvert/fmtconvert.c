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
#include <limits.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/cpu.h>
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/types.h>
#include <spa/debug/format.h>

#include "fmt-ops.h"

#define NAME "fmtconvert"

#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2

#define MAX_SAMPLES	8192
#define MAX_BUFFERS	32
#define MAX_ALIGN	16
#define MAX_DATAS	SPA_AUDIO_MAX_CHANNELS

#define PROP_DEFAULT_TRUNCATE	false
#define PROP_DEFAULT_DITHER	0

struct impl;

struct props {
	bool truncate;
	uint32_t dither;
};

static void props_reset(struct props *props)
{
	props->truncate = PROP_DEFAULT_TRUNCATE;
	props->dither = PROP_DEFAULT_DITHER;
}

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT		(1 << 0)
	uint32_t flags;
	struct spa_list link;
	struct spa_buffer *outbuf;
	struct spa_meta_header *h;
	void *datas[MAX_DATAS];
};

struct port {
	uint32_t direction;
	uint32_t id;

	struct spa_io_buffers *io;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_param_info params[8];

	struct spa_audio_info format;
	uint32_t stride;
	uint32_t blocks;
	uint32_t size;
	unsigned int have_format:1;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list queue;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_cpu *cpu;

	struct spa_io_position *io_position;

	uint64_t info_all;
	struct spa_node_info info;
	struct props props;
	struct spa_param_info params[8];

	struct spa_hook_list hooks;

	struct port ports[2][1];

	uint32_t src_remap[SPA_AUDIO_MAX_CHANNELS];
	uint32_t dst_remap[SPA_AUDIO_MAX_CHANNELS];

	uint32_t cpu_flags;
	struct convert conv;
	unsigned int started:1;
	unsigned int is_passthrough:1;
};

#define CHECK_PORT(this,d,id)		(id == 0)
#define GET_PORT(this,d,id)		(&this->ports[d][id])
#define GET_IN_PORT(this,id)		GET_PORT(this,SPA_DIRECTION_INPUT,id)
#define GET_OUT_PORT(this,id)		GET_PORT(this,SPA_DIRECTION_OUTPUT,id)

static int can_convert(const struct spa_audio_info *info1, const struct spa_audio_info *info2)
{
	if (info1->info.raw.channels != info2->info.raw.channels ||
	    info1->info.raw.rate != info2->info.raw.rate) {
		return 0;
	}
	return 1;
}

static int setup_convert(struct impl *this)
{
	uint32_t src_fmt, dst_fmt;
	struct spa_audio_info informat, outformat;
	struct port *inport, *outport;
	uint32_t i, j;
	int res;

	inport = GET_IN_PORT(this, 0);
	outport = GET_OUT_PORT(this, 0);

	if (!inport->have_format || !outport->have_format)
		return -EIO;

	informat = inport->format;
	outformat = outport->format;

	src_fmt = informat.info.raw.format;
	dst_fmt = outformat.info.raw.format;

	spa_log_info(this->log, NAME " %p: %s/%d@%d->%s/%d@%d", this,
			spa_debug_type_find_name(spa_type_audio_format, src_fmt),
			informat.info.raw.channels,
			informat.info.raw.rate,
			spa_debug_type_find_name(spa_type_audio_format, dst_fmt),
			outformat.info.raw.channels,
			outformat.info.raw.rate);

	if (!can_convert(&informat, &outformat))
		return -EINVAL;

	for (i = 0; i < informat.info.raw.channels; i++) {
		for (j = 0; j < outformat.info.raw.channels; j++) {
			if (informat.info.raw.position[i] !=
			    outformat.info.raw.position[j])
				continue;
			if (inport->blocks > 1) {
				this->src_remap[j] = i;
				if (outport->blocks > 1)
					this->dst_remap[j] = j;
				else
					this->dst_remap[j] = 0;
			} else {
				this->src_remap[j] = 0;
				if (outport->blocks > 1)
					this->dst_remap[i] = j;
				else
					this->dst_remap[j] = 0;
			}
			spa_log_debug(this->log, NAME " %p: channel %d -> %d (%s -> %s)", this,
					i, j,
					spa_debug_type_find_short_name(spa_type_audio_channel,
						informat.info.raw.position[i]),
					spa_debug_type_find_short_name(spa_type_audio_channel,
						outformat.info.raw.position[j]));
			outformat.info.raw.position[j] = -1;
			break;
		}
	}
	this->conv.src_fmt = src_fmt;
	this->conv.dst_fmt = dst_fmt;
	this->conv.n_channels = outformat.info.raw.channels;
	this->conv.cpu_flags = this->cpu_flags;

	if ((res = convert_init(&this->conv)) < 0)
		return res;

	this->is_passthrough = this->conv.is_passthrough;

	spa_log_debug(this->log, NAME " %p: got converter features %08x:%08x passthrough:%d", this,
			this->cpu_flags, this->conv.cpu_flags, this->is_passthrough);

	return 0;
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	return -ENOTSUP;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	return -ENOTSUP;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, NAME " %p: io %d %p/%zd", this, id, data, size);

	switch (id) {
	case SPA_IO_Position:
		this->io_position = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		this->started = true;
		break;
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Flush:
	case SPA_NODE_COMMAND_Pause:
		this->started = false;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static void emit_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_port_info(struct impl *this, struct port *port, bool full)
{
	if (full)
		port->info.change_mask = port->info_all;
	if (port->info.change_mask) {
		spa_node_emit_port_info(&this->hooks,
				port->direction, port->id, &port->info);
		port->info.change_mask = 0;
	}
}

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_info(this, true);
	emit_port_info(this, GET_IN_PORT(this, 0), true);
	emit_port_info(this, GET_OUT_PORT(this, 0), true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *user_data)
{
	return 0;
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

static int int32_cmp(const void *v1, const void *v2)
{
	int32_t a1 = *(int32_t*)v1;
	int32_t a2 = *(int32_t*)v2;
	if (a1 == 0 && a2 != 0)
		return 1;
	if (a2 == 0 && a1 != 0)
		return -1;
	return a1 - a2;
}

static int port_enum_formats(void *object,
			     enum spa_direction direction, uint32_t port_id,
			     uint32_t index,
			     struct spa_pod **param,
			     struct spa_pod_builder *builder)
{
	struct impl *this = object;
	struct port *port, *other;

	port = GET_PORT(this, direction, port_id);
	other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), 0);

	spa_log_debug(this->log, NAME " %p: enum %p %d %d", this, other, port->have_format, other->have_format);
	switch (index) {
	case 0:
		if (port->have_format) {
			*param = spa_format_audio_raw_build(builder,
					SPA_PARAM_EnumFormat, &port->format.info.raw);
		}
		else {
			struct spa_pod_frame f;
			struct spa_audio_info info;

			spa_pod_builder_push_object(builder, &f,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);

			spa_pod_builder_add(builder,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				0);

			if (other->have_format)
				info = other->format;
			else
				info.info.raw.format = SPA_AUDIO_FORMAT_F32P;

			if (!other->have_format ||
			    info.info.raw.format == SPA_AUDIO_FORMAT_F32P ||
			    info.info.raw.format == SPA_AUDIO_FORMAT_F32) {
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(16,
								info.info.raw.format,
								SPA_AUDIO_FORMAT_F32P,
								SPA_AUDIO_FORMAT_F32,
								SPA_AUDIO_FORMAT_S32P,
								SPA_AUDIO_FORMAT_S32,
								SPA_AUDIO_FORMAT_S24_32P,
								SPA_AUDIO_FORMAT_S24_32,
								SPA_AUDIO_FORMAT_S24P,
								SPA_AUDIO_FORMAT_S24,
								SPA_AUDIO_FORMAT_S24_OE,
								SPA_AUDIO_FORMAT_S16P,
								SPA_AUDIO_FORMAT_S16,
								SPA_AUDIO_FORMAT_S8P,
								SPA_AUDIO_FORMAT_S8,
								SPA_AUDIO_FORMAT_U8P,
								SPA_AUDIO_FORMAT_U8),
					0);
			} else {
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(4,
								info.info.raw.format,
								info.info.raw.format,
								SPA_AUDIO_FORMAT_F32,
								SPA_AUDIO_FORMAT_F32P),
					0);
			}
			if (other->have_format) {
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_rate,     SPA_POD_Int(info.info.raw.rate),
					SPA_FORMAT_AUDIO_channels, SPA_POD_Int(info.info.raw.channels),
					0);
				if (!SPA_FLAG_IS_SET(info.info.raw.flags, SPA_AUDIO_FLAG_UNPOSITIONED)) {
					qsort(info.info.raw.position, info.info.raw.channels,
							sizeof(uint32_t), int32_cmp);
					spa_pod_builder_prop(builder, SPA_FORMAT_AUDIO_position, 0);
			                spa_pod_builder_array(builder, sizeof(uint32_t), SPA_TYPE_Id,
							info.info.raw.channels, info.info.raw.position);
				}
			} else {
				uint32_t rate = this->io_position ?
					this->io_position->clock.rate.denom : DEFAULT_RATE;
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(
									rate, 1, INT32_MAX),
					SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(
									DEFAULT_CHANNELS, 1, INT32_MAX),
					0);
			}
			*param = spa_pod_builder_pop(builder, &f);
		}
		break;
	default:
		return 0;
	}

	return 1;
}

static int
impl_node_port_enum_params(void *object, int seq,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t id, uint32_t start, uint32_t num,
			   const struct spa_pod *filter)
{
	struct impl *this = object;
	struct port *port, *other;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);
	other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), port_id);

	spa_log_debug(this->log, "%p: enum params port %d.%d %d %u",
			this, direction, port_id, seq, id);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if ((res = port_enum_formats(this, direction, port_id,
						result.index, &param, &b)) <= 0)
			return res;
		break;

	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_format_audio_raw_build(&b, id, &port->format.info.raw);
		break;

	case SPA_PARAM_Buffers:
	{
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		if (other->n_buffers > 0) {
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamBuffers, id,
				SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
				SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(port->blocks),
				SPA_PARAM_BUFFERS_size,    SPA_POD_Int(other->size / other->stride * port->stride),
				SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->stride),
				SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));


		} else {
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamBuffers, id,
				SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
				SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(port->blocks),
				SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
								MAX_SAMPLES * 2 * port->stride,
								16 * port->stride,
								INT32_MAX),
				SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->stride),
				SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		}
		break;
	}
	case SPA_PARAM_Meta:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamMeta, id,
				SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
				SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
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
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Buffers),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_buffers)));
			break;
		default:
			return 0;
		}
		break;

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

static int calc_width(struct spa_audio_info *info)
{
	switch (info->info.raw.format) {
	case SPA_AUDIO_FORMAT_U8P:
	case SPA_AUDIO_FORMAT_U8:
	case SPA_AUDIO_FORMAT_S8P:
	case SPA_AUDIO_FORMAT_S8:
		return 1;
	case SPA_AUDIO_FORMAT_S16P:
	case SPA_AUDIO_FORMAT_S16:
	case SPA_AUDIO_FORMAT_S16_OE:
		return 2;
	case SPA_AUDIO_FORMAT_S24P:
	case SPA_AUDIO_FORMAT_S24:
	case SPA_AUDIO_FORMAT_S24_OE:
		return 3;
	default:
		return 4;
	}
}

static int clear_buffers(struct impl *this, struct port *port)
{
	if (port->n_buffers > 0) {
		spa_log_debug(this->log, NAME " %p: clear buffers %p", this, port);
		port->n_buffers = 0;
		spa_list_init(&port->queue);
	}
	return 0;
}
static int port_set_format(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	struct impl *this = object;
	struct port *port, *other;
	int res;

	port = GET_PORT(this, direction, port_id);
	other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), port_id);

	if (format == NULL) {
		if (port->have_format) {
			port->have_format = false;
			clear_buffers(this, port);
			if (this->conv.process)
				convert_free(&this->conv);
		}
	} else {
		struct spa_audio_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			return -EINVAL;

		if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
			return -EINVAL;

		if (other->have_format) {
			spa_log_debug(this->log, NAME "%p: channels:%d<>%d rate:%d<>%d format:%d<>%d", this,
				info.info.raw.channels, other->format.info.raw.channels,
				info.info.raw.rate, other->format.info.raw.rate,
				info.info.raw.format, other->format.info.raw.format);
			if (!can_convert(&info, &other->format))
				return -ENOTSUP;
		}

		port->stride = calc_width(&info);

		if (SPA_AUDIO_FORMAT_IS_PLANAR(info.info.raw.format)) {
			port->blocks = info.info.raw.channels;
		} else {
			port->stride *= info.info.raw.channels;
			port->blocks = 1;
		}

		port->have_format = true;
		port->format = info;

		if (other->have_format && port->have_format)
			if ((res = setup_convert(this)) < 0)
				return res;

		spa_log_debug(this->log, NAME " %p: set format on port %d:%d res:%d stride:%d",
				this, direction, port_id, res, port->stride);
	}
	if (port->have_format) {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	}
	return 0;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct impl *this = object;

	spa_return_val_if_fail(object != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(object, direction, port_id), -EINVAL);

	spa_log_debug(this->log, NAME " %p: set param %u on port %d:%d %p",
				this, id, direction, port_id, param);

	switch (id) {
	case SPA_PARAM_Format:
		return port_set_format(object, direction, port_id, flags, param);
	default:
		return -ENOENT;
	}
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
	struct port *port;
	uint32_t i, size = SPA_ID_INVALID, j;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_return_val_if_fail(port->have_format, -EIO);

	spa_log_debug(this->log, NAME " %p: use buffers %d on port %d", this, n_buffers, port_id);

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;
		uint32_t n_datas = buffers[i]->n_datas;
		struct spa_data *d = buffers[i]->datas;

		b = &port->buffers[i];
		b->id = i;
		b->flags = 0;
		b->outbuf = buffers[i];
		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		if (n_datas != port->blocks) {
			spa_log_error(this->log, NAME " %p: expected %d blocks on buffer %d", this,
				      port->blocks, i);
			return -EINVAL;
		}

		for (j = 0; j < n_datas; j++) {
			if (size == SPA_ID_INVALID)
				size = d[j].maxsize;
			else if (size != d[j].maxsize) {
				spa_log_error(this->log, NAME " %p: expected size %d on buffer %d",
						this, size, i);
				return -EINVAL;
			}

			if (d[j].data == NULL) {
				spa_log_error(this->log, NAME " %p: invalid memory %d on buffer %d",
						this, j, i);
				return -EINVAL;
			}
			if (!SPA_IS_ALIGNED(d[j].data, MAX_ALIGN)) {
				spa_log_warn(this->log, NAME " %p: memory %d on buffer %d not aligned",
						this, j, i);
			}
			b->datas[j] = d[j].data;
			if (direction == SPA_DIRECTION_OUTPUT &&
			    !SPA_FLAG_IS_SET(d[j].flags, SPA_DATA_FLAG_DYNAMIC))
				this->is_passthrough = false;
		}

		if (direction == SPA_DIRECTION_OUTPUT)
			spa_list_append(&port->queue, &b->link);
		else
			SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
	}
	port->n_buffers = n_buffers;
	port->size = size;

	spa_log_debug(this->log, NAME " %p: buffer size %d", this, size);

	return 0;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction, uint32_t port_id,
		      uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_log_debug(this->log, NAME " %p: port %d:%d update io %d %p",
			this, direction, port_id, id, data);

	switch (id) {
	case SPA_IO_Buffers:
		port->io = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static void recycle_buffer(struct impl *this, struct port *port, uint32_t id)
{
	struct buffer *b = &port->buffers[id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		spa_list_append(&port->queue, &b->link);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
		spa_log_trace_fp(this->log, NAME " %p: recycle buffer %d", this, id);
	}
}

static inline struct buffer *dequeue_buffer(struct impl *this, struct port *port)
{
	struct buffer *b;

	if (spa_list_is_empty(&port->queue))
		return NULL;
	b = spa_list_first(&port->queue, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
	return b;
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	port = GET_OUT_PORT(this, port_id);

	recycle_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *inport, *outport;
	struct spa_io_buffers *inio, *outio;
	struct buffer *inbuf, *outbuf;
	struct spa_buffer *inb, *outb;
	const void **src_datas;
	void **dst_datas;
	uint32_t i, n_src_datas, n_dst_datas;
	uint32_t n_samples, size, maxsize, offs;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	outport = GET_OUT_PORT(this, 0);
	inport = GET_IN_PORT(this, 0);

	outio = outport->io;
	inio = inport->io;

	spa_log_trace_fp(this->log, NAME " %p: io %p %p", this, inio, outio);

	spa_return_val_if_fail(outio != NULL, -EIO);
	spa_return_val_if_fail(inio != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p: status %p %d %d -> %p %d %d", this,
			inio, inio->status, inio->buffer_id,
			outio, outio->status, outio->buffer_id);

	if (SPA_UNLIKELY(outio->status == SPA_STATUS_HAVE_DATA))
		return inio->status | outio->status;

	if (SPA_LIKELY(outio->buffer_id < outport->n_buffers)) {
		recycle_buffer(this, outport, outio->buffer_id);
		outio->buffer_id = SPA_ID_INVALID;
	}
	if (SPA_UNLIKELY(inio->status != SPA_STATUS_HAVE_DATA))
		return outio->status = inio->status;

	if (SPA_UNLIKELY(inio->buffer_id >= inport->n_buffers))
		return inio->status = -EINVAL;

	if (SPA_UNLIKELY((outbuf = dequeue_buffer(this, outport)) == NULL))
		return outio->status = -EPIPE;

	inbuf = &inport->buffers[inio->buffer_id];
	inb = inbuf->outbuf;

	n_src_datas = inb->n_datas;
	src_datas = alloca(sizeof(void*) * n_src_datas);

	outb = outbuf->outbuf;

	n_dst_datas = outb->n_datas;
	dst_datas = alloca(sizeof(void*) * n_dst_datas);

	size = UINT32_MAX;
	for (i = 0; i < n_src_datas; i++) {
		uint32_t src_remap = this->src_remap[i];
		struct spa_data *sd = &inb->datas[src_remap];
		offs = SPA_MIN(sd->chunk->offset, sd->maxsize);
		size = SPA_MIN(size, SPA_MIN(sd->maxsize - offs, sd->chunk->size));
		src_datas[i] = SPA_MEMBER(sd->data, offs, void);
	}
	n_samples = size / inport->stride;

	maxsize = outb->datas[0].maxsize;
	n_samples = SPA_MIN(n_samples, maxsize / outport->stride);

	spa_log_trace_fp(this->log, NAME " %p: n_src:%d n_dst:%d size:%d maxsize:%d n_samples:%d p:%d",
			this, n_src_datas, n_dst_datas, size, maxsize, n_samples,
			this->is_passthrough);

	for (i = 0; i < n_dst_datas; i++) {
		uint32_t dst_remap = this->dst_remap[i];
		struct spa_data *dd = outb->datas;

		if (this->is_passthrough)
			dd[i].data = (void *)src_datas[i];
		else
			dst_datas[i] = dd[dst_remap].data = outbuf->datas[dst_remap];

		dd[i].chunk->offset = 0;
		dd[i].chunk->size = n_samples * outport->stride;
	}
	if (!this->is_passthrough)
		convert_process(&this->conv, dst_datas, src_datas, n_samples);

	inio->status = SPA_STATUS_NEED_DATA;

	outio->status = SPA_STATUS_HAVE_DATA;
	outio->buffer_id = outbuf->id;

	return SPA_STATUS_NEED_DATA | SPA_STATUS_HAVE_DATA;
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
	return 0;
}

static int init_port(struct impl *this, enum spa_direction direction, uint32_t port_id)
{
	struct port *port;

	port = GET_PORT(this, direction, port_id);
	port->direction = direction;
	port->id = port_id;

	spa_list_init(&port->queue);
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF |
		SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	port->have_format = false;

	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if (this->cpu)
		this->cpu_flags = spa_cpu_get_flags(this->cpu);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	this->info_all = SPA_PORT_CHANGE_MASK_FLAGS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.flags = SPA_NODE_FLAG_RT;
	this->info.params = this->params;
	this->info.n_params = 0;
	props_reset(&this->props);

	init_port(this, SPA_DIRECTION_OUTPUT, 0);
	init_port(this, SPA_DIRECTION_INPUT, 0);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Node,},
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

const struct spa_handle_factory spa_fmtconvert_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_PROCESS_FORMAT,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
