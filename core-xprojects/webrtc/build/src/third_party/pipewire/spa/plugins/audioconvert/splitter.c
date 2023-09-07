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
#include <spa/support/cpu.h>
#include <spa/support/log.h>
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/types.h>
#include <spa/debug/pod.h>

#include "fmt-ops.h"

#define NAME "splitter"

#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2
#define DEFAULT_MASK		(1LL << SPA_AUDIO_CHANNEL_FL) | (1LL << SPA_AUDIO_CHANNEL_FR)

#define MAX_SAMPLES	8192
#define MAX_ALIGN	16
#define MAX_BUFFERS	32
#define MAX_DATAS	SPA_AUDIO_MAX_CHANNELS
#define MAX_PORTS	SPA_AUDIO_MAX_CHANNELS

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_QUEUED	(1<<0)
	uint32_t flags;
	struct spa_list link;
	struct spa_buffer *buf;
	void *datas[MAX_DATAS];
};

struct port {
	uint32_t direction;
	uint32_t id;

	struct spa_io_buffers *io;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_param_info params[8];

	struct spa_dict info_props;
	struct spa_dict_item info_props_items[2];
	char position[16];

	bool have_format;
	struct spa_audio_info format;
	uint32_t blocks;
	uint32_t stride;

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
	struct spa_param_info params[8];

	struct spa_hook_list hooks;

	struct port in_ports[1];
	struct port out_ports[MAX_PORTS];
	uint32_t port_count;

	struct spa_audio_info format;
	unsigned int have_profile:1;

	uint32_t cpu_flags;
	struct convert conv;
	unsigned int is_passthrough:1;
	unsigned int started:1;

	uint32_t src_remap[SPA_AUDIO_MAX_CHANNELS];
	uint32_t dst_remap[SPA_AUDIO_MAX_CHANNELS];

	float empty[MAX_SAMPLES + MAX_ALIGN];
};

#define CHECK_OUT_PORT(this,d,p)	((d) == SPA_DIRECTION_OUTPUT && (p) < this->port_count)
#define CHECK_IN_PORT(this,d,p)		((d) == SPA_DIRECTION_INPUT && (p) == 0)
#define CHECK_PORT(this,d,p)		(CHECK_OUT_PORT(this,d,p) || CHECK_IN_PORT (this,d,p))
#define GET_IN_PORT(this,p)		(&this->in_ports[p])
#define GET_OUT_PORT(this,p)		(&this->out_ports[p])
#define GET_PORT(this,d,p)		(d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,p) : GET_OUT_PORT(this,p))

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

static int init_port(struct impl *this, enum spa_direction direction,
		uint32_t port_id, uint32_t position)
{
	struct port *port = GET_OUT_PORT(this, port_id);

	port->direction = direction;
	port->id = port_id;

	if (position < SPA_N_ELEMENTS(spa_type_audio_channel)) {
		snprintf(port->position, sizeof(port->position), "%s",
				spa_debug_type_short_name(spa_type_audio_channel[position].name));
	} else if (position >= SPA_AUDIO_CHANNEL_CUSTOM_START) {
		snprintf(port->position, sizeof(port->position), "AUX%d",
				position - SPA_AUDIO_CHANNEL_CUSTOM_START);
	} else {
		snprintf(port->position, sizeof(port->position), "UNK");
	}

	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PROPS |
			SPA_PORT_CHANGE_MASK_PARAMS;

	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_DYNAMIC_DATA;
	port->info_props_items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "32 bit float mono audio");
	port->info_props_items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_AUDIO_CHANNEL, port->position);
	port->info_props = SPA_DICT_INIT(port->info_props_items, 2);
	port->info.props = &port->info_props;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	spa_list_init(&port->queue);

	port->n_buffers = 0;
	port->have_format = false;
	port->format.media_type = SPA_MEDIA_TYPE_audio;
	port->format.media_subtype = SPA_MEDIA_SUBTYPE_dsp;
	port->format.info.dsp.format = SPA_AUDIO_FORMAT_DSP_F32;

	spa_log_debug(this->log, NAME " %p: init port %d:%d position:%s",
			this, direction, port_id, port->position);
	emit_port_info(this, port, true);

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
	default:
		return 0;
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

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_PortConfig:
	{
		struct port *port;
		struct spa_audio_info info = { 0, };
		struct spa_pod *format;
		enum spa_direction direction;
		enum spa_param_port_config_mode mode;
		uint32_t i;

		if (spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamPortConfig, NULL,
				SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(&direction),
				SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(&mode),
				SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(&format)) < 0)
			return -EINVAL;

		if (!spa_pod_is_object_type(format, SPA_TYPE_OBJECT_Format))
			return -EINVAL;

		if (mode != SPA_PARAM_PORT_CONFIG_MODE_dsp)
			return -ENOTSUP;
		if (direction != SPA_DIRECTION_OUTPUT)
			return -EINVAL;

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			return -ENOTSUP;

		if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
			return -EINVAL;

		if (this->have_profile && memcmp(&this->format, &info, sizeof(info)) == 0)
			return 0;

		spa_log_debug(this->log, NAME " %p: port config %d/%d", this,
				info.info.raw.rate, info.info.raw.channels);

		for (i = 0; i < this->port_count; i++)
			spa_node_emit_port_info(&this->hooks,
					SPA_DIRECTION_OUTPUT, i, NULL);

		this->have_profile = true;
		this->is_passthrough = true;
		this->format = info;

		this->port_count = info.info.raw.channels;
		for (i = 0; i < this->port_count; i++) {
			init_port(this, SPA_DIRECTION_OUTPUT, i,
					info.info.raw.position[i]);
		}
		port = GET_IN_PORT(this, 0);
		qsort(info.info.raw.position, info.info.raw.channels,
					sizeof(uint32_t), int32_cmp);
		port->format = info;
		port->have_format = true;
		return 0;
	}
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

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	emit_port_info(this, GET_IN_PORT(this, 0), true);
	for (i = 0; i < this->port_count; i++)
		emit_port_info(this, GET_OUT_PORT(this, i), true);

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
	struct port *port = GET_PORT(this, direction, port_id);

	switch (index) {
	case 0:
		if (direction == SPA_DIRECTION_OUTPUT) {
			*param = spa_format_audio_dsp_build(builder,
					SPA_PARAM_EnumFormat, &port->format.info.dsp);
		} else if (port->have_format) {
			*param = spa_format_audio_raw_build(builder,
					SPA_PARAM_EnumFormat, &port->format.info.raw);
		}
		else {
			uint32_t rate = this->io_position ?
				this->io_position->clock.rate.denom : DEFAULT_RATE;

			*param = spa_pod_builder_add_object(builder,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(16,
							SPA_AUDIO_FORMAT_F32P,
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
				SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(
						rate, 1, INT32_MAX),
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(
						DEFAULT_CHANNELS, 1, MAX_PORTS));
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
	struct port *port;
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

		if (direction == SPA_DIRECTION_OUTPUT)
			param = spa_format_audio_dsp_build(&b, id, &port->format.info.dsp);
		else
			param = spa_format_audio_raw_build(&b, id, &port->format.info.raw);
		break;
	case SPA_PARAM_Buffers:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(1, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(port->blocks),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							MAX_SAMPLES * port->stride,
							16 * port->stride,
							MAX_SAMPLES * port->stride),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;

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

static int setup_convert(struct impl *this)
{
	struct port *inport;
	struct spa_audio_info informat, outformat;
	uint32_t i, j, src_fmt, dst_fmt;
	int res;

	inport = GET_IN_PORT(this, 0);

	informat = inport->format;
	outformat = this->format;

	src_fmt = informat.info.raw.format;
	dst_fmt = SPA_AUDIO_FORMAT_DSP_F32;

	spa_log_info(this->log, NAME " %p: %s/%d@%d->%s/%d@%dx%d", this,
			spa_debug_type_find_name(spa_type_audio_format, src_fmt),
			informat.info.raw.channels,
			informat.info.raw.rate,
			spa_debug_type_find_name(spa_type_audio_format, dst_fmt),
			1,
			outformat.info.raw.rate,
			outformat.info.raw.channels);

	for (i = 0; i < informat.info.raw.channels; i++) {
		for (j = 0; j < outformat.info.raw.channels; j++) {
			if (informat.info.raw.position[i] !=
			    outformat.info.raw.position[j])
				continue;
			this->src_remap[i] = j;
			this->dst_remap[j] = i;
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
	this->conv.n_channels = informat.info.raw.channels;
	this->conv.cpu_flags = this->cpu_flags;

	if ((res = convert_init(&this->conv)) < 0)
		return res;

	this->is_passthrough &= this->conv.is_passthrough;

	spa_log_debug(this->log, NAME " %p: got converter features %08x:%08x passthrough:%d", this,
			this->cpu_flags, this->conv.cpu_flags, this->is_passthrough);

	return 0;
}

static int calc_width(struct spa_audio_info *info)
{
	switch (info->info.raw.format) {
	case SPA_AUDIO_FORMAT_U8:
	case SPA_AUDIO_FORMAT_U8P:
	case SPA_AUDIO_FORMAT_S8:
	case SPA_AUDIO_FORMAT_S8P:
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

static int port_set_format(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	struct impl *this = object;
	struct port *port;
	int res;

	port = GET_PORT(this, direction, port_id);

	spa_log_debug(this->log, NAME " %p: set format", this);

	if (format == NULL) {
		if (port->have_format) {
			if (direction == SPA_DIRECTION_INPUT)
				port->have_format = this->have_profile;
			else
				port->have_format = false;
			clear_buffers(this, port);
		}
	} else {
		struct spa_audio_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (direction == SPA_DIRECTION_OUTPUT) {
			if (info.media_type != SPA_MEDIA_TYPE_audio ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_dsp)
				return -EINVAL;
			if (spa_format_audio_dsp_parse(format, &info.info.dsp) < 0)
				return -EINVAL;
			if (info.info.dsp.format != SPA_AUDIO_FORMAT_DSP_F32)
				return -EINVAL;

			port->stride = 4;
			port->blocks = 1;
		}
		else {
			if (info.media_type != SPA_MEDIA_TYPE_audio ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
				return -EINVAL;
			if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
				return -EINVAL;
			if (info.info.raw.channels != this->port_count)
				return -EINVAL;

			port->stride = calc_width(&info);
			if (SPA_AUDIO_FORMAT_IS_PLANAR(info.info.raw.format)) {
				port->blocks = info.info.raw.channels;
			} else {
				port->stride *= info.info.raw.channels;
				port->blocks = 1;
			}
		}

		port->format = info;

		spa_log_debug(this->log, NAME " %p: %d %d %d", this, port_id, port->stride, port->blocks);

		if (direction == SPA_DIRECTION_INPUT)
			if ((res = setup_convert(this)) < 0)
				return res;

		port->have_format = true;
	}
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	}
	emit_port_info(this, port, false);

	return 0;
}


static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	switch (id) {
	case SPA_PARAM_Format:
		return port_set_format(this, direction, port_id, flags, param);
	default:
		return -ENOENT;
	}
}

static void queue_buffer(struct impl *this, struct port *port, uint32_t id)
{
	struct buffer *b = &port->buffers[id];

	spa_log_trace_fp(this->log, NAME " %p: queue buffer %d on port %d %d",
			this, id, port->id, b->flags);
	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_QUEUED))
		return;

	spa_list_append(&port->queue, &b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_QUEUED);
}

static struct buffer *dequeue_buffer(struct impl *this, struct port *port)
{
	struct buffer *b;

	if (spa_list_is_empty(&port->queue))
		return NULL;

	b = spa_list_first(&port->queue, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_QUEUED);
	spa_log_trace_fp(this->log, NAME " %p: dequeue buffer %d on port %d %u",
			this, b->id, port->id, b->flags);

	return b;
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
	uint32_t i, j;

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
		b->buf = buffers[i];
		b->flags = 0;

		for (j = 0; j < n_datas; j++) {
			if (d[j].data == NULL) {
				spa_log_error(this->log, NAME " %p: invalid memory %d on buffer %d %d %p",
						this, j, i, d[j].type, d[j].data);
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

			spa_log_debug(this->log, NAME " %p: buffer %d data %d flags:%08x %p",
					this, i, j, d[j].flags, b->datas[j]);
		}

		if (direction == SPA_DIRECTION_OUTPUT)
			queue_buffer(this, port, i);
	}
	port->n_buffers = n_buffers;

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

	switch (id) {
	case SPA_IO_Buffers:
		port->io = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	port = GET_OUT_PORT(this, port_id);
	queue_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *inport;
	struct spa_io_buffers *inio;
	uint32_t i, maxsize, n_samples;
	struct spa_data *sd, *dd;
	struct buffer *sbuf, *dbuf;
	uint32_t n_src_datas, n_dst_datas;
	const void **src_datas;
	void **dst_datas;
	int res = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	inport = GET_IN_PORT(this, 0);
	inio = inport->io;
	spa_return_val_if_fail(inio != NULL, -EIO);
	spa_return_val_if_fail(this->conv.process != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p: status %p %d %d", this,
			inio, inio->status, inio->buffer_id);

	if (SPA_UNLIKELY(inio->status != SPA_STATUS_HAVE_DATA))
		return inio->status;

	if (SPA_UNLIKELY(inio->buffer_id >= inport->n_buffers))
		return inio->status = -EINVAL;

	sbuf = &inport->buffers[inio->buffer_id];
	sd = sbuf->buf->datas;

	n_src_datas = sbuf->buf->n_datas;
	src_datas = alloca(sizeof(void*) * n_src_datas);

	maxsize = INT_MAX;
	for (i = 0; i < n_src_datas; i++) {
		src_datas[i] = SPA_MEMBER(sd[i].data,
				sd[i].chunk->offset, void);
		maxsize = SPA_MIN(sd[i].chunk->size, maxsize);
	}
	n_samples = maxsize / inport->stride;

	n_dst_datas = this->port_count;
	dst_datas = alloca(sizeof(void*) * n_dst_datas);

	for (i = 0; i < n_dst_datas; i++) {
		struct port *outport = GET_OUT_PORT(this, i);
		struct spa_io_buffers *outio;
		uint32_t src_remap = this->src_remap[i];
		uint32_t dst_remap = this->dst_remap[i];

		if (SPA_UNLIKELY((outio = outport->io) == NULL))
			goto empty;

		spa_log_trace_fp(this->log, NAME " %p: %d %p %d %d %d", this, i,
				outio, outio->status, outio->buffer_id, outport->stride);

		if (SPA_UNLIKELY(outio->status == SPA_STATUS_HAVE_DATA)) {
			res |= SPA_STATUS_HAVE_DATA;
			goto empty;
		}

		if (SPA_LIKELY(outio->buffer_id < outport->n_buffers)) {
			queue_buffer(this, outport, outio->buffer_id);
			outio->buffer_id = SPA_ID_INVALID;
		}

		if (SPA_UNLIKELY((dbuf = dequeue_buffer(this, outport)) == NULL)) {
			outio->status = -EPIPE;
          empty:
			spa_log_trace_fp(this->log, NAME" %p: %d skip output", this, i);
			dst_datas[dst_remap] = SPA_PTR_ALIGN(this->empty, MAX_ALIGN, void);
			continue;
		}

		dd = dbuf->buf->datas;

		maxsize = dd->maxsize;
		n_samples = SPA_MIN(n_samples, maxsize / outport->stride);

		if (this->is_passthrough)
			dd[0].data = (void *)src_datas[src_remap];
		else
			dst_datas[dst_remap] = dd[0].data = dbuf->datas[0];

		dd[0].chunk->offset = 0;
		dd[0].chunk->size = n_samples * outport->stride;

		outio->status = SPA_STATUS_HAVE_DATA;
		outio->buffer_id = dbuf->id;
		res |= SPA_STATUS_HAVE_DATA;
	}

	spa_log_trace_fp(this->log, NAME " %p: n_src:%d n_dst:%d n_samples:%d max:%d stride:%d p:%d", this,
			n_src_datas, n_dst_datas, n_samples, maxsize, inport->stride,
			this->is_passthrough);

	if (!this->is_passthrough)
		convert_process(&this->conv, dst_datas, src_datas, n_samples);

	inio->status = SPA_STATUS_NEED_DATA;
	res |= SPA_STATUS_NEED_DATA;

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

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if (this->cpu)
		this->cpu_flags = spa_cpu_get_flags(this->cpu);

	spa_hook_list_init(&this->hooks);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = 1;
	this->info.max_output_ports = MAX_PORTS;
	this->info.flags = SPA_NODE_FLAG_RT |
		SPA_NODE_FLAG_OUT_PORT_CONFIG;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PortConfig, SPA_PARAM_INFO_WRITE);
	this->info.params = this->params;
	this->info.n_params = 1;

	port = GET_IN_PORT(this, 0);
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->direction = SPA_DIRECTION_INPUT;
	port->id = 0;
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

const struct spa_handle_factory spa_splitter_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_PROCESS_DEINTERLEAVE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
