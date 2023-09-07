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
#include <spa/utils/result.h>
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/node/keys.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/types.h>
#include <spa/debug/pod.h>

#include "volume-ops.h"
#include "fmt-ops.h"

#define NAME "merger"

#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2

#define MAX_SAMPLES	8192
#define MAX_ALIGN	16
#define MAX_BUFFERS	32
#define MAX_DATAS	SPA_AUDIO_MAX_CHANNELS
#define MAX_PORTS	SPA_AUDIO_MAX_CHANNELS

#define DEFAULT_MUTE	false
#define DEFAULT_VOLUME	VOLUME_NORM

struct volumes {
	bool mute;
	uint32_t n_volumes;
	float volumes[SPA_AUDIO_MAX_CHANNELS];
};

static void init_volumes(struct volumes *vol)
{
	uint32_t i;
	vol->mute = DEFAULT_MUTE;
	vol->n_volumes = 0;
	for (i = 0; i < SPA_AUDIO_MAX_CHANNELS; i++)
		vol->volumes[i] = DEFAULT_VOLUME;
}

struct props {
	float volume;
	uint32_t n_channels;
	uint32_t channel_map[SPA_AUDIO_MAX_CHANNELS];
	struct volumes channel;
	struct volumes soft;
	struct volumes monitor;
};

static void props_reset(struct props *props)
{
	uint32_t i;
	props->volume = DEFAULT_VOLUME;
	props->n_channels = 0;
	for (i = 0; i < SPA_AUDIO_MAX_CHANNELS; i++)
		props->channel_map[i] = SPA_AUDIO_CHANNEL_UNKNOWN;
	init_volumes(&props->channel);
	init_volumes(&props->soft);
	init_volumes(&props->monitor);
}

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
	char position[16];

	struct spa_audio_info format;
	uint32_t blocks;
	uint32_t stride;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list queue;

	unsigned int have_format:1;
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

	uint32_t port_count;
	uint32_t monitor_count;
	struct port in_ports[MAX_PORTS];
	struct port out_ports[MAX_PORTS + 1];

	struct spa_audio_info format;
	unsigned int have_profile:1;

	struct convert conv;
	uint32_t cpu_flags;
	unsigned int is_passthrough:1;
	unsigned int started:1;
	unsigned int monitor:1;
	unsigned int monitor_channel_volumes:1;

	struct volume volume;
	struct props props;

	uint32_t src_remap[SPA_AUDIO_MAX_CHANNELS];
	uint32_t dst_remap[SPA_AUDIO_MAX_CHANNELS];

	float empty[MAX_SAMPLES + MAX_ALIGN];
};

#define CHECK_IN_PORT(this,d,p)		((d) == SPA_DIRECTION_INPUT && (p) < this->port_count)
#define CHECK_OUT_PORT(this,d,p)	((d) == SPA_DIRECTION_OUTPUT && (p) <= this->monitor_count)
#define CHECK_PORT(this,d,p)		(CHECK_OUT_PORT(this,d,p) || CHECK_IN_PORT (this,d,p))
#define GET_IN_PORT(this,p)		(&this->in_ports[p])
#define GET_OUT_PORT(this,p)		(&this->out_ports[p])
#define GET_PORT(this,d,p)		(d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,p) : GET_OUT_PORT(this,p))

#define PORT_IS_DSP(d,p) (p != 0 || d != SPA_DIRECTION_OUTPUT)

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
		struct spa_dict_item items[3];
		uint32_t n_items = 0;

		if (PORT_IS_DSP(port->direction, port->id)) {
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "32 bit float mono audio");
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_AUDIO_CHANNEL, port->position);
			if (port->direction == SPA_DIRECTION_OUTPUT)
				items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_MONITOR, "true");
		}
		port->info.props = &SPA_DICT_INIT(items, n_items);

		spa_node_emit_port_info(&this->hooks, port->direction, port->id, &port->info);
		port->info.change_mask = 0;
	}
}

static int init_port(struct impl *this, enum spa_direction direction, uint32_t port_id,
		uint32_t position)
{
	struct port *port = GET_PORT(this, direction, port_id);

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
	port->info.flags = SPA_PORT_FLAG_NO_REF |
		SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	port->n_buffers = 0;
	port->have_format = false;
	port->format.media_type = SPA_MEDIA_TYPE_audio;
	port->format.media_subtype = SPA_MEDIA_SUBTYPE_dsp;
	port->format.info.dsp.format = SPA_AUDIO_FORMAT_DSP_F32;
	spa_list_init(&port->queue);

	spa_log_debug(this->log, NAME " %p: add port %d:%d position:%s",
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
	case SPA_PARAM_PortConfig:
		return -ENOTSUP;

	case SPA_PARAM_PropInfo:
	{
		struct props *p = &this->props;

		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_volume),
				SPA_PROP_INFO_name, SPA_POD_String("Volume"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 10.0));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_mute),
				SPA_PROP_INFO_name, SPA_POD_String("Mute"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_Bool(p->channel.mute));
			break;
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_channelVolumes),
				SPA_PROP_INFO_name, SPA_POD_String("Channel Volumes"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 10.0),
				SPA_PROP_INFO_container, SPA_POD_Id(SPA_TYPE_Array));
			break;
		case 3:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_channelMap),
				SPA_PROP_INFO_name, SPA_POD_String("Channel Map"),
				SPA_PROP_INFO_type, SPA_POD_Id(SPA_AUDIO_CHANNEL_UNKNOWN),
				SPA_PROP_INFO_container, SPA_POD_Id(SPA_TYPE_Array));
			break;
		case 4:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_monitorMute),
				SPA_PROP_INFO_name, SPA_POD_String("Monitor Mute"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_Bool(p->monitor.mute));
			break;
		case 5:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_monitorVolumes),
				SPA_PROP_INFO_name, SPA_POD_String("Monitor Volumes"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 10.0),
				SPA_PROP_INFO_container, SPA_POD_Id(SPA_TYPE_Array));
			break;
		case 6:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_softMute),
				SPA_PROP_INFO_name, SPA_POD_String("Soft Mute"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_Bool(p->soft.mute));
			break;
		case 7:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_softVolumes),
				SPA_PROP_INFO_name, SPA_POD_String("Soft Volumes"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 10.0),
				SPA_PROP_INFO_container, SPA_POD_Id(SPA_TYPE_Array));
			break;
		default:
			return 0;
		}
		break;
	}

	case SPA_PARAM_Props:
	{
		struct props *p = &this->props;

		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, id,
				SPA_PROP_volume,		SPA_POD_Float(p->volume),
				SPA_PROP_mute,			SPA_POD_Bool(p->channel.mute),
				SPA_PROP_channelVolumes,	SPA_POD_Array(sizeof(float),
									SPA_TYPE_Float,
									p->channel.n_volumes,
									p->channel.volumes),
				SPA_PROP_channelMap,		SPA_POD_Array(sizeof(uint32_t),
									SPA_TYPE_Id,
									p->n_channels,
									p->channel_map),
				SPA_PROP_softMute,		SPA_POD_Bool(p->soft.mute),
				SPA_PROP_softVolumes,		SPA_POD_Array(sizeof(float),
									SPA_TYPE_Float,
									p->soft.n_volumes,
									p->soft.volumes),
				SPA_PROP_monitorMute,		SPA_POD_Bool(p->monitor.mute),
				SPA_PROP_monitorVolumes,	SPA_POD_Array(sizeof(float),
									SPA_TYPE_Float,
									p->monitor.n_volumes,
									p->monitor.volumes));
			break;
		default:
			return 0;
		}
		break;
	}
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

static int apply_props(struct impl *this, const struct spa_pod *param)
{
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) param;
	struct props *p = &this->props;
	int changed = 0;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &p->volume) == 0)
				changed++;
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &p->channel.mute) == 0)
				changed++;
			break;
		case SPA_PROP_channelVolumes:
			if ((p->channel.n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					p->channel.volumes, SPA_AUDIO_MAX_CHANNELS)) > 0)
				changed++;
			break;
		case SPA_PROP_channelMap:
			if ((p->n_channels = spa_pod_copy_array(&prop->value, SPA_TYPE_Id,
					p->channel_map, SPA_AUDIO_MAX_CHANNELS)) > 0)
				changed++;
			break;
		case SPA_PROP_softMute:
			if (spa_pod_get_bool(&prop->value, &p->soft.mute) == 0)
				changed++;
			break;
		case SPA_PROP_softVolumes:
			if ((p->soft.n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					p->soft.volumes, SPA_AUDIO_MAX_CHANNELS)) > 0)
				changed++;
			break;
		case SPA_PROP_monitorMute:
			if (spa_pod_get_bool(&prop->value, &p->monitor.mute) == 0)
				changed++;
			break;
		case SPA_PROP_monitorVolumes:
			if ((p->monitor.n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					p->monitor.volumes, SPA_AUDIO_MAX_CHANNELS)) > 0)
				changed++;
			break;
		default:
			break;
		}
	}
	return changed;
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
		struct spa_audio_info info = { 0, };
		struct port *port;
		struct spa_pod *format;
		enum spa_direction direction;
		enum spa_param_port_config_mode mode;
		bool monitor = false;
		uint32_t i;

		if (spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamPortConfig, NULL,
				SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(&direction),
				SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(&mode),
				SPA_PARAM_PORT_CONFIG_monitor,		SPA_POD_OPT_Bool(&monitor),
				SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(&format)) < 0)
			return -EINVAL;

		if (!spa_pod_is_object_type(format, SPA_TYPE_OBJECT_Format))
			return -EINVAL;

		if (mode != SPA_PARAM_PORT_CONFIG_MODE_dsp)
			return -ENOTSUP;
		if (direction != SPA_DIRECTION_INPUT)
			return -EINVAL;

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			return -EINVAL;

		if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
			return -EINVAL;

		if (this->have_profile && memcmp(&this->format, &info, sizeof(info)) == 0)
			return 0;

		spa_log_debug(this->log, NAME " %p: port config %d/%d %d", this,
				info.info.raw.rate, info.info.raw.channels, monitor);

		for (i = 0; i < this->port_count; i++) {
			spa_node_emit_port_info(&this->hooks,
					SPA_DIRECTION_INPUT, i, NULL);
			if (this->monitor)
				spa_node_emit_port_info(&this->hooks,
						SPA_DIRECTION_OUTPUT, i+1, NULL);
		}

		this->monitor = monitor;
		this->format = info;
		this->have_profile = true;
		this->port_count = info.info.raw.channels;
		this->monitor_count = this->monitor ? this->port_count : 0;
		for (i = 0; i < this->port_count; i++)
			this->props.channel_map[i] = info.info.raw.position[i];
		this->props.channel.n_volumes = this->port_count;
		this->props.monitor.n_volumes = this->port_count;
		this->props.soft.n_volumes = this->port_count;
		this->props.n_channels = this->port_count;

		for (i = 0; i < this->port_count; i++) {
			init_port(this, SPA_DIRECTION_INPUT, i, info.info.raw.position[i]);
			if (this->monitor)
				init_port(this, SPA_DIRECTION_OUTPUT, i+1,
					info.info.raw.position[i]);
		}

		port = GET_OUT_PORT(this, 0);
		qsort(info.info.raw.position, info.info.raw.channels,
					sizeof(uint32_t), int32_cmp);
		port->format = info;
		port->have_format = true;

		this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
		this->params[2].flags ^= SPA_PARAM_INFO_SERIAL;
		emit_node_info(this, false);
		return 0;
	}
	case SPA_PARAM_Props:
		if (apply_props(this, param) > 0) {
			this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
			this->params[2].flags ^= SPA_PARAM_INFO_SERIAL;
			emit_node_info(this, false);
		}
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

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	uint32_t i;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_trace(this->log, NAME" %p: add listener %p", this, listener);
	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	emit_port_info(this, GET_OUT_PORT(this, 0), true);
	for (i = 0; i < this->port_count; i++) {
		emit_port_info(this, GET_IN_PORT(this, i), true);
		if (this->monitor)
			emit_port_info(this, GET_OUT_PORT(this, i+1), true);
	}

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
		if (PORT_IS_DSP(direction, port_id)) {
			*param = spa_format_audio_dsp_build(builder,
				SPA_PARAM_EnumFormat, &port->format.info.dsp);
		} else if (port->have_format) {
			*param = spa_format_audio_raw_build(builder,
				SPA_PARAM_EnumFormat, &port->format.info.raw);
		}
		else {
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
							SPA_AUDIO_FORMAT_U8,
							SPA_AUDIO_FORMAT_U8P),
				SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(
					DEFAULT_RATE, 1, INT32_MAX),
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

	spa_log_debug(this->log, "%p: enum params port %d.%d %d %u",
			this, direction, port_id, seq, id);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if ((res = port_enum_formats(object, direction, port_id, result.index, &param, &b)) <= 0)
			return res;
		break;
	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		if (PORT_IS_DSP(direction, port_id))
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
								INT32_MAX),
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
	struct port *outport;
	struct spa_audio_info informat, outformat;
	uint32_t i, j, src_fmt, dst_fmt;
	int res;

	outport = GET_OUT_PORT(this, 0);

	informat = this->format;
	outformat = outport->format;

	src_fmt = SPA_AUDIO_FORMAT_DSP_F32;
	dst_fmt = outformat.info.raw.format;

	spa_log_info(this->log, NAME " %p: %s/%d@%dx%d->%s/%d@%d", this,
			spa_debug_type_find_name(spa_type_audio_format, src_fmt),
			1,
			informat.info.raw.rate,
			informat.info.raw.channels,
			spa_debug_type_find_name(spa_type_audio_format, dst_fmt),
			outformat.info.raw.channels,
			outformat.info.raw.rate);

	for (i = 0; i < informat.info.raw.channels; i++) {
		for (j = 0; j < outformat.info.raw.channels; j++) {
			if (informat.info.raw.position[i] !=
			    outformat.info.raw.position[j])
				continue;
			this->src_remap[j] = i;
			this->dst_remap[i] = j;
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

static int calc_width(struct spa_audio_info *info)
{
	switch (info->info.raw.format) {
	case SPA_AUDIO_FORMAT_U8:
	case SPA_AUDIO_FORMAT_S8:
		return 1;
	case SPA_AUDIO_FORMAT_S16:
	case SPA_AUDIO_FORMAT_S16_OE:
		return 2;
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
			if (PORT_IS_DSP(direction, port_id))
				port->have_format = false;
			else
				port->have_format = this->have_profile;
			clear_buffers(this, port);
		}
	} else {
		struct spa_audio_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0) {
			spa_log_error(this->log, "can't parse format %s", spa_strerror(res));
			return res;
		}
		if (PORT_IS_DSP(direction, port_id)) {
			if (info.media_type != SPA_MEDIA_TYPE_audio ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_dsp) {
				spa_log_error(this->log, "unexpected types %d/%d",
						info.media_type, info.media_subtype);
				return -EINVAL;
			}
			if ((res = spa_format_audio_dsp_parse(format, &info.info.dsp)) < 0) {
				spa_log_error(this->log, "can't parse format %s", spa_strerror(res));
				return res;
			}
			if (info.info.dsp.format != SPA_AUDIO_FORMAT_DSP_F32) {
				spa_log_error(this->log, "unexpected format %d<->%d",
					info.info.dsp.format, SPA_AUDIO_FORMAT_DSP_F32);
				return -EINVAL;
			}
			port->blocks = 1;
			port->stride = 4;
		}
		else {
			if (info.media_type != SPA_MEDIA_TYPE_audio ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_raw) {
				spa_log_error(this->log, "unexpected types %d/%d",
						info.media_type, info.media_subtype);
				return -EINVAL;
			}
			if ((res = spa_format_audio_raw_parse(format, &info.info.raw)) < 0) {
				spa_log_error(this->log, "can't parse format %s", spa_strerror(res));
				return res;
			}
			if (info.info.raw.channels != this->port_count) {
				spa_log_error(this->log, "unexpected channels %d<->%d",
					info.info.raw.channels, this->port_count);
				return -EINVAL;
			}
			port->stride = calc_width(&info);
			if (SPA_AUDIO_FORMAT_IS_PLANAR(info.info.raw.format)) {
				port->blocks = info.info.raw.channels;
			}
			else {
				port->stride *= info.info.raw.channels;
				port->blocks = 1;
			}
		}
		port->format = info;

		spa_log_debug(this->log, NAME " %p: %d %d %d", this,
				port_id, port->stride, port->blocks);

		if (!PORT_IS_DSP(direction, port_id))
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

	spa_log_debug(this->log, NAME " %p: use buffers %d on port %d:%d",
			this, n_buffers, direction, port_id);

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;
		uint32_t n_datas = buffers[i]->n_datas;
		struct spa_data *d = buffers[i]->datas;

		b = &port->buffers[i];
		b->id = i;
		b->flags = 0;
		b->buf = buffers[i];

		if (n_datas != port->blocks) {
			spa_log_error(this->log, NAME " %p: invalid blocks %d on buffer %d",
					this, n_datas, i);
			return -EINVAL;
		}

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

	spa_log_debug(this->log, NAME " %p: set io %d on port %d:%d %p",
			this, id, direction, port_id, data);

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

static inline int get_in_buffer(struct impl *this, struct port *port, struct buffer **buf)
{
	struct spa_io_buffers *io;

	if ((io = port->io) == NULL) {
		spa_log_trace_fp(this->log, NAME " %p: no io on port %d",
				this, port->id);
		return -EIO;
	}
	if (io->status != SPA_STATUS_HAVE_DATA ||
	    io->buffer_id >= port->n_buffers) {
		spa_log_trace_fp(this->log, NAME " %p: empty port %d %p %d %d %d",
				this, port->id, io, io->status, io->buffer_id,
				port->n_buffers);
		return -EPIPE;
	}

	*buf = &port->buffers[io->buffer_id];
	io->status = SPA_STATUS_NEED_DATA;

	return 0;
}

static inline int get_out_buffer(struct impl *this, struct port *port, struct buffer **buf)
{
	struct spa_io_buffers *io;

	if (SPA_UNLIKELY((io = port->io) == NULL ||
	    io->status == SPA_STATUS_HAVE_DATA))
		return SPA_STATUS_HAVE_DATA;

	if (SPA_LIKELY(io->buffer_id < port->n_buffers))
		queue_buffer(this, port, io->buffer_id);

	if (SPA_UNLIKELY((*buf = dequeue_buffer(this, port)) == NULL))
		return -EPIPE;

	io->status = SPA_STATUS_HAVE_DATA;
	io->buffer_id = (*buf)->id;

	return 0;
}

static inline int handle_monitor(struct impl *this, const void *data, float volume, int n_samples, struct port *outport)
{
	struct buffer *dbuf;
        struct spa_data *dd;
	int res, size;

	if (SPA_UNLIKELY((res = get_out_buffer(this, outport, &dbuf)) != 0))
		return res;

	dd = &dbuf->buf->datas[0];
	size = SPA_MIN(dd->maxsize, n_samples * outport->stride);
	dd->chunk->offset = 0;
	dd->chunk->size = size;

	spa_log_trace(this->log, "%p: io %p %08x", this, outport->io, dd->flags);

	if (SPA_FLAG_IS_SET(dd->flags, SPA_DATA_FLAG_DYNAMIC) && volume == VOLUME_NORM)
		dd->data = (void*)data;
	else
		volume_process(&this->volume, dd->data, data, volume, size / outport->stride);

	return res;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *outport;
	struct spa_io_buffers *outio;
	uint32_t i, maxsize, n_samples;
	struct spa_data *sd, *dd;
	struct buffer *sbuf, *dbuf;
	uint32_t n_src_datas, n_dst_datas;
	const void **src_datas;
	void **dst_datas;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	outport = GET_OUT_PORT(this, 0);
	outio = outport->io;
	spa_return_val_if_fail(outio != NULL, -EIO);
	spa_return_val_if_fail(this->conv.process != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p: status %p %d %d", this,
			outio, outio->status, outio->buffer_id);

	if (SPA_UNLIKELY((res = get_out_buffer(this, outport, &dbuf)) != 0))
		return res;

	dd = &dbuf->buf->datas[0];

	maxsize = dd->maxsize;

	if (SPA_LIKELY(this->io_position))
		n_samples = this->io_position->clock.duration;
	else
		n_samples = maxsize / outport->stride;


	n_dst_datas = dbuf->buf->n_datas;
	dst_datas = alloca(sizeof(void*) * n_dst_datas);

	n_src_datas = this->port_count;
	src_datas = alloca(sizeof(void*) * this->port_count);

	/* produce more output if possible */
	for (i = 0; i < n_src_datas; i++) {
		struct port *inport = GET_IN_PORT(this, i);

		if (SPA_UNLIKELY(get_in_buffer(this, inport, &sbuf) < 0)) {
			src_datas[i] = SPA_PTR_ALIGN(this->empty, MAX_ALIGN, void);
			continue;
		}

		sd = &sbuf->buf->datas[0];

		src_datas[i] = SPA_MEMBER(sd->data, sd->chunk->offset, void);

		n_samples = SPA_MIN(n_samples, sd->chunk->size / inport->stride);

		spa_log_trace_fp(this->log, NAME " %p: %d %d %d %p", this,
				sd->chunk->size, maxsize, n_samples, src_datas[i]);
	}

	for (i = 0; i < this->monitor_count; i++) {
		float volume;

		volume = this->props.monitor.mute ? 0.0f : this->props.monitor.volumes[i];
		if (this->monitor_channel_volumes)
			volume *= this->props.channel.mute ? 0.0f : this->props.channel.volumes[i];

		handle_monitor(this, src_datas[i], volume, n_samples,
				GET_OUT_PORT(this, i + 1));
	}

	for (i = 0; i < n_dst_datas; i++) {
		uint32_t dst_remap = this->dst_remap[i];
		uint32_t src_remap = this->src_remap[i];
		struct spa_data *dd = dbuf->buf->datas;

		if (this->is_passthrough)
			dd[i].data = (void *)src_datas[src_remap];
		else
			dst_datas[dst_remap] = dd[i].data = dbuf->datas[i];

		dd[i].chunk->offset = 0;
		dd[i].chunk->size = n_samples * outport->stride;
	}

	spa_log_trace_fp(this->log, NAME " %p: n_src:%d n_dst:%d n_samples:%d max:%d p:%d", this,
			n_src_datas, n_dst_datas, n_samples, maxsize, this->is_passthrough);

	if (!this->is_passthrough)
		convert_process(&this->conv, dst_datas, src_datas, n_samples);

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
		this->cpu_flags = spa_cpu_get_flags(this->cpu);

	this->monitor_channel_volumes = false;
	if (info) {
		if ((str = spa_dict_lookup(info, "monitor.channel-volumes")) != NULL)
			this->monitor_channel_volumes = strcmp(str, "true") == 0 || atoi(str) == 1;
	}

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = MAX_PORTS;
	this->info.max_output_ports = MAX_PORTS+1;
	this->info.flags = SPA_NODE_FLAG_RT |
		SPA_NODE_FLAG_IN_PORT_CONFIG;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PortConfig, SPA_PARAM_INFO_WRITE);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[2] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 3;

	port = GET_OUT_PORT(this, 0);
	port->direction = SPA_DIRECTION_OUTPUT;
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

	this->volume.cpu_flags = this->cpu_flags;
	volume_init(&this->volume);
	props_reset(&this->props);

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

const struct spa_handle_factory spa_merger_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_PROCESS_INTERLEAVE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
