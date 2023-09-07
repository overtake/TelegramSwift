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
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/types.h>

#include "resample.h"

#define NAME "resample"

#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2

#define MAX_SAMPLES	8192
#define MAX_ALIGN	16
#define MAX_BUFFERS	32

struct impl;

struct props {
	double rate;
	int quality;
};

static void props_reset(struct props *props)
{
	props->rate = 1.0;
	props->quality = RESAMPLE_DEFAULT_QUALITY;
}

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT		(1 << 0)
	uint32_t flags;
	struct spa_list link;
	struct spa_buffer *outbuf;
	struct spa_meta_header *h;
};

struct port {
	uint32_t direction;
	uint32_t id;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_param_info params[8];

	struct spa_io_buffers *io;

	struct spa_audio_info format;
	uint32_t stride;
	uint32_t blocks;
	uint32_t size;
	unsigned int have_format:1;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	uint32_t offset;
	struct spa_list queue;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_cpu *cpu;

	struct spa_io_position *io_position;
	struct spa_io_rate_match *io_rate_match;

	uint64_t info_all;
	struct spa_node_info info;
	struct props props;

	struct spa_hook_list hooks;

	struct port in_port;
	struct port out_port;

#define MODE_SPLIT	0
#define MODE_MERGE	1
#define MODE_CONVERT	2
	int mode;
	unsigned int started:1;
	unsigned int peaks:1;
	unsigned int drained:1;

	struct resample resample;

	float empty[MAX_SAMPLES + MAX_ALIGN];
};

#define CHECK_PORT(this,d,id)		(id == 0)
#define GET_IN_PORT(this,id)		(&this->in_port)
#define GET_OUT_PORT(this,id)		(&this->out_port)
#define GET_PORT(this,d,id)		(d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,id) : GET_OUT_PORT(this,id))

static int setup_convert(struct impl *this,
		enum spa_direction direction,
		const struct spa_audio_info *info)
{
	const struct spa_audio_info *src_info, *dst_info;
	int err;

	if (direction == SPA_DIRECTION_INPUT) {
		src_info = info;
		dst_info = &GET_OUT_PORT(this, 0)->format;
	} else {
		src_info = &GET_IN_PORT(this, 0)->format;
		dst_info = info;
	}

	spa_log_info(this->log, NAME " %p: %s/%d@%d->%s/%d@%d", this,
			spa_debug_type_find_name(spa_type_audio_format, src_info->info.raw.format),
			src_info->info.raw.channels,
			src_info->info.raw.rate,
			spa_debug_type_find_name(spa_type_audio_format, dst_info->info.raw.format),
			dst_info->info.raw.channels,
			dst_info->info.raw.rate);

	if (src_info->info.raw.channels != dst_info->info.raw.channels)
		return -EINVAL;

	if (this->resample.free)
		resample_free(&this->resample);

	this->resample.channels = src_info->info.raw.channels;
	this->resample.i_rate = src_info->info.raw.rate;
	this->resample.o_rate = dst_info->info.raw.rate;
	this->resample.log = this->log;
	this->resample.quality = this->props.quality;

	if (this->peaks)
		err = resample_peaks_init(&this->resample);
	else
		err = resample_native_init(&this->resample);

	return err;
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	return -ENOTSUP;
}

static int apply_props(struct impl *this, const struct spa_pod *param)
{
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) param;
	struct props *p = &this->props;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_rate:
			if (spa_pod_get_double(&prop->value, &p->rate) == 0) {
				resample_update_rate(&this->resample, p->rate);
			}
			break;
		case SPA_PROP_quality:
			spa_pod_get_int(&prop->value, &p->quality);
			break;
		default:
			break;
		}
	}
	return 0;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;
	int res = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Props:
		apply_props(this, param);
		break;
	default:
		return -ENOTSUP;
	}

	return res;
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

static void update_rate_match(struct impl *this, bool passthrough, uint32_t out_size, uint32_t in_queued)
{
	if (this->io_rate_match) {
		uint32_t match_size;

		if (passthrough) {
			this->io_rate_match->delay = 0;
			match_size = out_size;
		} else {
			if (SPA_FLAG_IS_SET(this->io_rate_match->flags, SPA_IO_RATE_MATCH_FLAG_ACTIVE))
				resample_update_rate(&this->resample, this->io_rate_match->rate);
			else
				resample_update_rate(&this->resample, 1.0);

			this->io_rate_match->delay = resample_delay(&this->resample);
			match_size = resample_in_len(&this->resample, out_size);
		}
		match_size -= SPA_MIN(match_size, in_queued);
		this->io_rate_match->size = match_size;
		spa_log_trace_fp(this->log, NAME " %p: next match %u", this, match_size);
	} else {
		resample_update_rate(&this->resample, this->props.rate);
	}
}

static void reset_node(struct impl *this)
{
	struct port *outport, *inport;
	outport = GET_OUT_PORT(this, 0);
	inport = GET_IN_PORT(this, 0);

	resample_reset(&this->resample);
	outport->offset = 0;
	inport->offset = 0;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
	{
		bool passthrough = this->resample.i_rate == this->resample.o_rate &&
			(this->io_rate_match == NULL ||
			 !SPA_FLAG_IS_SET(this->io_rate_match->flags, SPA_IO_RATE_MATCH_FLAG_ACTIVE));
		uint32_t out_size = this->io_position ? this->io_position->clock.duration : 1024;
		this->started = true;
		update_rate_match(this, passthrough, out_size, 0);
		break;
	}
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Flush:
		reset_node(this);
		SPA_FALLTHROUGH;
	case SPA_NODE_COMMAND_Pause:
		this->started = false;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static void emit_node_info(struct impl *this, bool full)
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

	emit_node_info(this, true);
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

static int port_enum_formats(void *object,
			     enum spa_direction direction, uint32_t port_id,
			     uint32_t index,
			     struct spa_pod **param,
			     struct spa_pod_builder *builder)
{
	struct impl *this = object;
	struct port *other;
	struct spa_pod_frame f;

	other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), 0);

	switch (index) {
	case 0:
		if (other->have_format) {
			spa_pod_builder_push_object(builder, &f,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
			spa_pod_builder_add(builder,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_F32P),
				SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(
								other->format.info.raw.rate, 1, INT32_MAX),
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(other->format.info.raw.channels),
				0);
			spa_pod_builder_prop(builder, SPA_FORMAT_AUDIO_position, 0);
			spa_pod_builder_array(builder, sizeof(uint32_t), SPA_TYPE_Id,
					other->format.info.raw.channels, other->format.info.raw.position);
			*param = spa_pod_builder_pop(builder, &f);
		} else {
			*param = spa_pod_builder_add_object(builder,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_F32P),
				SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(DEFAULT_RATE, 1, INT32_MAX),
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(DEFAULT_CHANNELS, 1, INT32_MAX));
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
		uint32_t buffers, size;

		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		if (other->n_buffers > 0) {
			buffers = other->n_buffers;
			size = other->size / other->stride * 2;
		}
		else {
			buffers = 1;
			size = MAX_SAMPLES*2 * other->stride;
		}

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(buffers, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(port->blocks),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							size * port->stride,
							16 * port->stride,
							INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
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
	int res = 0;

	port = GET_PORT(this, direction, port_id);
	other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), port_id);

	if (format == NULL) {
		if (port->have_format) {
			port->have_format = false;
			clear_buffers(this, port);
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

		if (info.info.raw.format != SPA_AUDIO_FORMAT_F32P)
			return -EINVAL;

		port->stride = sizeof(float);
		port->blocks = info.info.raw.channels;

		if (other->have_format) {
			if ((res = setup_convert(this, direction, &info)) < 0)
				return res;
		}
		port->format = info;
		port->have_format = true;

		spa_log_debug(this->log, NAME " %p: set format on port %d %d", this, port_id, res);
	}

	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	} else {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	}
	emit_port_info(this, port, false);

	return res;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	spa_return_val_if_fail(object != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(object, direction, port_id), -EINVAL);

	if (id == SPA_PARAM_Format) {
		return port_set_format(object, direction, port_id, flags, param);
	}
	else
		return -ENOENT;
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
	uint32_t i, j, size = SPA_ID_INVALID;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_return_val_if_fail(port->have_format, -EIO);

	spa_log_debug(this->log, NAME " %p: use buffers %d on port %d:%d", this,
			n_buffers, direction, port_id);

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;
		struct spa_data *d = buffers[i]->datas;

		b = &port->buffers[i];
		b->id = i;
		b->flags = 0;
		b->outbuf = buffers[i];
		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		for (j = 0; j < buffers[i]->n_datas; j++) {
			if (size == SPA_ID_INVALID)
				size = d[j].maxsize;
			else
				if (size != d[j].maxsize) {
					spa_log_error(this->log, NAME " %p: invalid size %d on buffer %p", this,
						      size, buffers[i]);
					return -EINVAL;
				}

			if (d[j].data == NULL) {
				spa_log_error(this->log, NAME " %p: invalid memory on buffer %p", this,
					      buffers[i]);
				return -EINVAL;
			}
		}

		if (direction == SPA_DIRECTION_OUTPUT)
			spa_list_append(&port->queue, &b->link);
		else
			SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

		port->offset = 0;
	}
	port->n_buffers = n_buffers;
	port->size = size;

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

	spa_log_trace_fp(this->log, NAME " %p: %d:%d io %d", this, direction, port_id, id);

	port = GET_PORT(this, direction, port_id);

	switch (id) {
	case SPA_IO_Buffers:
		port->io = data;
		break;
	case SPA_IO_RateMatch:
		this->io_rate_match = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static void recycle_buffer(struct impl *this, uint32_t id)
{
	struct port *port = GET_OUT_PORT(this, 0);
	struct buffer *b = &port->buffers[id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		spa_list_append(&port->queue, &b->link);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
		spa_log_trace_fp(this->log, NAME " %p: recycle buffer %d", this, id);
	}
}

static struct buffer *peek_buffer(struct impl *this, struct port *port)
{
	struct buffer *b;

	if (spa_list_is_empty(&port->queue))
		return NULL;

	b = spa_list_first(&port->queue, struct buffer, link);
	return b;
}

static void dequeue_buffer(struct impl *this, struct buffer *b)
{
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	recycle_buffer(this, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *outport, *inport;
	struct spa_io_buffers *outio, *inio;
	struct buffer *sbuf, *dbuf;
	struct spa_buffer *sb, *db;
	uint32_t i, size, in_len, out_len, maxsize, max;
#ifndef FASTPATH
	uint32_t pin_len, pout_len;
#endif
	int res = 0;
	const void **src_datas;
	void **dst_datas;
	bool flush_out = false;
	bool flush_in = false;
	bool draining = false;
	bool passthrough;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	outport = GET_OUT_PORT(this, 0);
	inport = GET_IN_PORT(this, 0);

	outio = outport->io;
	inio = inport->io;

	spa_return_val_if_fail(outio != NULL, -EIO);
	spa_return_val_if_fail(inio != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p: status %p %d %d -> %p %d %d", this,
			inio, inio->status, inio->buffer_id,
			outio, outio->status, outio->buffer_id);

	if (SPA_UNLIKELY(outio->status == SPA_STATUS_HAVE_DATA))
		return SPA_STATUS_HAVE_DATA;
	/* recycle */
	if (SPA_LIKELY(outio->buffer_id < outport->n_buffers)) {
		recycle_buffer(this, outio->buffer_id);
		outio->buffer_id = SPA_ID_INVALID;
	}
	if (SPA_UNLIKELY(inio->status != SPA_STATUS_HAVE_DATA)) {
		if (inio->status != SPA_STATUS_DRAINED || this->drained)
			return outio->status = inio->status;

		inio->buffer_id = 0;
		inport->buffers[0].outbuf->datas[0].chunk->size = 0;
	}

	if (SPA_UNLIKELY(inio->buffer_id >= inport->n_buffers))
		return inio->status = -EINVAL;

	if (SPA_UNLIKELY((dbuf = peek_buffer(this, outport)) == NULL))
		return outio->status = -EPIPE;

	sbuf = &inport->buffers[inio->buffer_id];

	sb = sbuf->outbuf;
	db = dbuf->outbuf;

	size = sb->datas[0].chunk->size;
	maxsize = db->datas[0].maxsize;

	if (SPA_LIKELY(this->io_position))
		max = this->io_position->clock.duration;
	else
		max = maxsize / sizeof(float);

	switch (this->mode) {
	case MODE_SPLIT:
		/* in split mode we need to output exactly the size of the
		 * duration so we don't try to flush early */
		maxsize = SPA_MIN(maxsize, max * sizeof(float));
		flush_out = false;
		break;
	case MODE_MERGE:
	default:
		/* in merge mode we consume one duration of samples and
		 * always output the resulting data */
		flush_out = true;
		break;
	}
	src_datas = alloca(sizeof(void*) * this->resample.channels);
	dst_datas = alloca(sizeof(void*) * this->resample.channels);

	if (size == 0) {
		size = MAX_SAMPLES * sizeof(float);
		for (i = 0; i < sb->n_datas; i++)
			src_datas[i] = SPA_PTR_ALIGN(this->empty, MAX_ALIGN, void);
		inport->offset = 0;
		flush_in = draining = true;
	} else {
		for (i = 0; i < sb->n_datas; i++)
			src_datas[i] = SPA_MEMBER(sb->datas[i].data, inport->offset, void);
	}
	for (i = 0; i < db->n_datas; i++)
		dst_datas[i] = SPA_MEMBER(db->datas[i].data, outport->offset, void);

	in_len = (size - inport->offset) / sizeof(float);
	out_len = (maxsize - outport->offset) / sizeof(float);


#ifndef FASTPATH
	pin_len = in_len;
	pout_len = out_len;
#endif
	passthrough = this->resample.i_rate == this->resample.o_rate &&
		(this->io_rate_match == NULL ||
		 !SPA_FLAG_IS_SET(this->io_rate_match->flags, SPA_IO_RATE_MATCH_FLAG_ACTIVE));

	if (passthrough) {
		uint32_t len = SPA_MIN(in_len, out_len);
		for (i = 0; i < sb->n_datas; i++)
			memcpy(dst_datas[i], src_datas[i], len * sizeof(float));
		out_len = in_len = len;
	} else {
		resample_process(&this->resample, src_datas, &in_len, dst_datas, &out_len);
	}

#ifndef FASTPATH
	spa_log_trace_fp(this->log, NAME " %p: in %d/%d %zd %d out %d/%d %zd %d max:%d",
			this, pin_len, in_len, size / sizeof(float), inport->offset,
			pout_len, out_len, maxsize / sizeof(float), outport->offset,
			max);
#endif

	for (i = 0; i < db->n_datas; i++) {
		db->datas[i].chunk->size = outport->offset + (out_len * sizeof(float));
		db->datas[i].chunk->offset = 0;
	}

	inport->offset += in_len * sizeof(float);
	if (inport->offset >= size || flush_in) {
		inio->status = SPA_STATUS_NEED_DATA;
		spa_log_trace_fp(this->log, NAME" %p: return input buffer of %zd samples",
				this, size / sizeof(float));
		inport->offset = 0;
		size = 0;
		SPA_FLAG_SET(res, inio->status);
	}

	outport->offset += out_len * sizeof(float);
	if (outport->offset > 0 && (outport->offset >= maxsize || flush_out)) {
		outio->status = SPA_STATUS_HAVE_DATA;
		outio->buffer_id = dbuf->id;
		spa_log_trace_fp(this->log, NAME" %p: have output buffer of %zd samples",
				this, outport->offset / sizeof(float));
		dequeue_buffer(this, dbuf);
		outport->offset = 0;
		this->drained = draining;
		SPA_FLAG_SET(res, SPA_STATUS_HAVE_DATA);
	}
	if (out_len == 0 && this->peaks) {
		outio->status = SPA_STATUS_HAVE_DATA;
		outio->buffer_id = SPA_ID_INVALID;
		SPA_FLAG_SET(res, SPA_STATUS_HAVE_DATA);
		spa_log_trace_fp(this->log, NAME " %p: no output buffer", this);
	}

	update_rate_match(this, passthrough, max - outport->offset / sizeof(float),
			size - inport->offset / sizeof(float));
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

	if (this->resample.free)
		resample_free(&this->resample);
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
	struct port *port;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if (this->cpu)
		this->resample.cpu_flags = spa_cpu_get_flags(this->cpu);

	props_reset(&this->props);

	if (info != NULL) {
		if ((str = spa_dict_lookup(info, "resample.quality")) != NULL)
			this->props.quality = atoi(str);
		if ((str = spa_dict_lookup(info, "resample.peaks")) != NULL)
			this->peaks = strcmp(str, "true") == 0 || atoi(str) == 1;
		if ((str = spa_dict_lookup(info, "factory.mode")) != NULL) {
			if (strcmp(str, "split") == 0)
				this->mode = MODE_SPLIT;
			else if (strcmp(str, "merge") == 0)
				this->mode = MODE_MERGE;
			else
				this->mode = MODE_CONVERT;
		}
	}
	spa_log_debug(this->log, "mode:%d", this->mode);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);

	spa_hook_list_init(&this->hooks);

	this->info = SPA_NODE_INFO_INIT();
	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS;
	this->info.max_input_ports = 1;
	this->info.max_output_ports = 1;
	this->info.flags = SPA_NODE_FLAG_RT;

	port = GET_OUT_PORT(this, 0);
	port->direction = SPA_DIRECTION_OUTPUT;
	port->id = 0;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
		SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = 0;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	spa_list_init(&port->queue);

	port = GET_IN_PORT(this, 0);
	port->direction = SPA_DIRECTION_INPUT;
	port->id = 0;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
		SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	spa_list_init(&port->queue);

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

const struct spa_handle_factory spa_resample_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_PROCESS_RESAMPLE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
