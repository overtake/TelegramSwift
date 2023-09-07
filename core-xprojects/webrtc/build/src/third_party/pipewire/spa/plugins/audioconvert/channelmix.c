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
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/utils/json.h>
#include <spa/node/keys.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/types.h>

#include "channelmix-ops.h"

#define NAME "channelmix"

#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2

#define DEFAULT_SAMPLES	8192
#define MAX_BUFFERS	32
#define MAX_DATAS	SPA_AUDIO_MAX_CHANNELS

#define DEFAULT_CONTROL_BUFFER_SIZE	32768

struct impl;

#define DEFAULT_MUTE	false
#define DEFAULT_VOLUME	1.0f

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
	unsigned int have_soft_volume:1;
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

	uint64_t info_all;
	struct spa_port_info info;
#define IDX_EnumFormat	0
#define IDX_Meta	1
#define IDX_IO		2
#define IDX_Format	3
#define IDX_Buffers	4
	struct spa_param_info params[5];

	struct spa_io_buffers *io;

	bool have_format;
	struct spa_audio_info format;
	uint32_t stride;
	uint32_t blocks;
	uint32_t size;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list queue;

	struct spa_pod_sequence *ctrl;
	uint32_t ctrl_offset;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_cpu *cpu;

	struct spa_hook_list hooks;

	uint64_t info_all;
	struct spa_node_info info;
	struct props props;
#define IDX_PropInfo	0
#define IDX_Props	1
	struct spa_param_info params[2];


	struct port control_port;
	struct port in_port;
	struct port out_port;

	struct channelmix mix;
	unsigned int started:1;
	unsigned int is_passthrough:1;
	uint32_t cpu_flags;
};

#define IS_CONTROL_PORT(this,d,id)	(id == 1 && d == SPA_DIRECTION_INPUT)
#define IS_DATA_PORT(this,d,id)		(id == 0)

#define CHECK_PORT(this,d,id)		(IS_CONTROL_PORT(this,d,id) || IS_DATA_PORT(this,d,id))
#define GET_CONTROL_PORT(this,id)	(&this->control_port)
#define GET_IN_PORT(this,id)		(&this->in_port)
#define GET_OUT_PORT(this,id)		(&this->out_port)
#define GET_PORT(this,d,id)		(IS_CONTROL_PORT(this,d,id) ? GET_CONTROL_PORT(this,id) : (d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,id) : GET_OUT_PORT(this,id)))

#define _MASK(ch)	(1ULL << SPA_AUDIO_CHANNEL_ ## ch)
#define STEREO	(_MASK(FL)|_MASK(FR))

static void emit_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_props_changed(struct impl *this)
{
	this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
	this->params[IDX_Props].flags ^= SPA_PARAM_INFO_SERIAL;
	emit_info(this, false);
}

static uint64_t default_mask(uint32_t channels)
{
	uint64_t mask = 0;
	switch (channels) {
	case 7:
	case 8:
		mask |= _MASK(RL);
		mask |= _MASK(RR);
		SPA_FALLTHROUGH
	case 5:
	case 6:
		mask |= _MASK(SL);
		mask |= _MASK(SR);
		if ((channels & 1) == 0)
			mask |= _MASK(LFE);
		SPA_FALLTHROUGH
	case 3:
		mask |= _MASK(FC);
		SPA_FALLTHROUGH
	case 2:
		mask |= _MASK(FL);
		mask |= _MASK(FR);
		break;
	case 1:
		mask |= _MASK(MONO);
		break;
	case 4:
		mask |= _MASK(FL);
		mask |= _MASK(FR);
		mask |= _MASK(RL);
		mask |= _MASK(RR);
		break;
	}
	return mask;
}

static void fix_volumes(struct volumes *vols, uint32_t channels)
{
	float s;
	uint32_t i;
	if (vols->n_volumes > 0) {
		s = 0.0f;
		for (i = 0; i < vols->n_volumes; i++)
			s += vols->volumes[i];
		s /= vols->n_volumes;
	} else {
		s = 1.0f;
	}
	vols->n_volumes = channels;
	for (i = 0; i < vols->n_volumes; i++)
		vols->volumes[i] = s;
}

static int remap_volumes(struct impl *this, const struct spa_audio_info *info)
{
	struct props *p = &this->props;
	uint32_t i, j, target = info->info.raw.channels;

	for (i = 0; i < p->n_channels; i++) {
		for (j = i; j < target; j++) {
			spa_log_debug(this->log, "%d %d: %d <-> %d", i, j,
					p->channel_map[i], info->info.raw.position[j]);
			if (p->channel_map[i] != info->info.raw.position[j])
				continue;
			if (i != j) {
				SPA_SWAP(p->channel_map[i], p->channel_map[j]);
				SPA_SWAP(p->channel.volumes[i], p->channel.volumes[j]);
				SPA_SWAP(p->soft.volumes[i], p->soft.volumes[j]);
				SPA_SWAP(p->monitor.volumes[i], p->monitor.volumes[j]);
			}
			break;
		}
	}
	p->n_channels = target;
	for (i = 0; i < p->n_channels; i++)
		p->channel_map[i] = info->info.raw.position[i];

	if (target == 0)
		return 0;
	if (p->channel.n_volumes != target)
		fix_volumes(&p->channel, target);
	if (p->soft.n_volumes != target)
		fix_volumes(&p->soft, target);
	if (p->monitor.n_volumes != target)
		fix_volumes(&p->monitor, target);

	return 1;
}

static void set_volume(struct impl *this)
{
	struct volumes *vol;

	if (this->mix.set_volume == NULL)
		return;

	if (this->props.have_soft_volume)
		vol = &this->props.soft;
	else
		vol = &this->props.channel;

	channelmix_set_volume(&this->mix, this->props.volume, vol->mute,
			vol->n_volumes, vol->volumes);
}

static int setup_convert(struct impl *this,
		enum spa_direction direction,
		const struct spa_audio_info *info)
{
	const struct spa_audio_info *src_info, *dst_info;
	uint32_t i, src_chan, dst_chan, p;
	uint64_t src_mask, dst_mask;
	int res;

	if (direction == SPA_DIRECTION_INPUT) {
		src_info = info;
		dst_info = &GET_OUT_PORT(this, 0)->format;
	} else {
		src_info = &GET_IN_PORT(this, 0)->format;
		dst_info = info;
	}

	src_chan = src_info->info.raw.channels;
	dst_chan = dst_info->info.raw.channels;

	for (i = 0, src_mask = 0; i < src_chan; i++) {
		p = src_info->info.raw.position[i];
		src_mask |= 1ULL << (p < 64 ? p : 0);
	}
	for (i = 0, dst_mask = 0; i < dst_chan; i++) {
		p = dst_info->info.raw.position[i];
		dst_mask |= 1ULL << (p < 64 ? p : 0);
	}

	if (src_mask & 1 || src_chan == 1)
		src_mask = default_mask(src_chan);
	if (dst_mask & 1 || dst_chan == 1)
		dst_mask = default_mask(dst_chan);

	spa_log_info(this->log, NAME " %p: %s/%d@%d->%s/%d@%d %08"PRIx64":%08"PRIx64, this,
			spa_debug_type_find_name(spa_type_audio_format, src_info->info.raw.format),
			src_chan,
			src_info->info.raw.rate,
			spa_debug_type_find_name(spa_type_audio_format, dst_info->info.raw.format),
			dst_chan,
			dst_info->info.raw.rate,
			src_mask, dst_mask);

	if (src_info->info.raw.rate != dst_info->info.raw.rate)
		return -EINVAL;

	this->mix.src_chan = src_chan;
	this->mix.src_mask = src_mask;
	this->mix.dst_chan = dst_chan;
	this->mix.dst_mask = dst_mask;
	this->mix.cpu_flags = this->cpu_flags;
	this->mix.log = this->log;
	this->mix.freq = src_info->info.raw.rate;

	if ((res = channelmix_init(&this->mix)) < 0)
		return res;

	remap_volumes(this, src_info);
	set_volume(this);

	emit_props_changed(this);

	this->is_passthrough = SPA_FLAG_IS_SET(this->mix.flags, CHANNELMIX_FLAG_IDENTITY);

	spa_log_debug(this->log, NAME " %p: got channelmix features %08x:%08x flags:%08x passthrough:%d",
			this, this->cpu_flags, this->mix.cpu_flags,
			this->mix.flags, this->is_passthrough);


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
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_softVolumes),
				SPA_PROP_INFO_name, SPA_POD_String("Soft Volumes"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 10.0),
				SPA_PROP_INFO_container, SPA_POD_Id(SPA_TYPE_Array));
			break;
		case 5:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_monitorMute),
				SPA_PROP_INFO_name, SPA_POD_String("Monitor Mute"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_Bool(p->monitor.mute));
			break;
		case 6:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_monitorVolumes),
				SPA_PROP_INFO_name, SPA_POD_String("Monitor Volumes"),
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
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int apply_props(struct impl *this, const struct spa_pod *param)
{
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) param;
	struct props *p = &this->props;
	int changed = 0;
	bool have_channel_volume = false;
	bool have_soft_volume = false;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &p->volume) == 0)
				changed++;
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &p->channel.mute) == 0) {
				changed++;
				have_channel_volume = true;
			}
			break;
		case SPA_PROP_channelVolumes:
			if ((p->channel.n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					p->channel.volumes, SPA_AUDIO_MAX_CHANNELS)) > 0) {
				changed++;
				have_channel_volume = true;
			}
			break;
		case SPA_PROP_channelMap:
			if ((p->n_channels = spa_pod_copy_array(&prop->value, SPA_TYPE_Id,
					p->channel_map, SPA_AUDIO_MAX_CHANNELS)) > 0)
				changed++;
			break;
		case SPA_PROP_softMute:
			if (spa_pod_get_bool(&prop->value, &p->soft.mute) == 0) {
				changed++;
				have_soft_volume = true;
			}
			break;
		case SPA_PROP_softVolumes:
			if ((p->soft.n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					p->soft.volumes, SPA_AUDIO_MAX_CHANNELS)) > 0) {
				changed++;
				have_soft_volume = true;
			}
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
	if (changed) {
		if (have_soft_volume)
			p->have_soft_volume = true;
		else if (have_channel_volume)
			p->have_soft_volume = false;

		remap_volumes(this, &GET_IN_PORT(this, 0)->format);
		set_volume(this);
	}
	return changed;
}

static int apply_midi(struct impl *this, const struct spa_pod *value)
{
	const uint8_t *val = SPA_POD_BODY(value);
	uint32_t size = SPA_POD_BODY_SIZE(value);
	struct props *p = &this->props;

	if (size < 3)
		return -EINVAL;

	if ((val[0] & 0xf0) != 0xb0 || val[1] != 7)
		return 0;

	p->volume = val[2] / 127.0;
	set_volume(this);
	return 1;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	return -ENOTSUP;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Props:
		if (apply_props(this, param) > 0)
			emit_props_changed(this);
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
	struct spa_dict_item items[2];
	uint32_t n_items = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_info(this, true);
	emit_port_info(this, GET_IN_PORT(this, 0), true);
	emit_port_info(this, GET_OUT_PORT(this, 0), true);

	struct port *control_port = GET_CONTROL_PORT(this, 1);
	items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_NAME, "control");
	items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "8 bit raw midi");
	control_port->info.props = &SPA_DICT_INIT(items, n_items);
	emit_port_info(this, control_port, true);

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

static int impl_node_add_port(void *object,
		enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	return -ENOTSUP;
}

static int impl_node_remove_port(void *object,
		enum spa_direction direction, uint32_t port_id)
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

	switch (index) {
	case 0:
		if (IS_CONTROL_PORT(this, direction, port_id)) {
			*param = spa_pod_builder_add_object(builder,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
				SPA_FORMAT_mediaType,	   SPA_POD_Id(SPA_MEDIA_TYPE_application),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
		} else {
			struct spa_pod_frame f;
			struct port *other;

			other = GET_PORT(this, SPA_DIRECTION_REVERSE(direction), 0);

			spa_pod_builder_push_object(builder, &f,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
			spa_pod_builder_add(builder,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_F32P),
				0);
			if (other->have_format) {
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_rate, SPA_POD_Int(other->format.info.raw.rate),
					0);
			} else {
				spa_pod_builder_add(builder,
					SPA_FORMAT_AUDIO_rate, SPA_POD_CHOICE_RANGE_Int(DEFAULT_RATE, 1, INT32_MAX),
					0);
			}
			spa_pod_builder_add(builder,
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(DEFAULT_CHANNELS, 1, INT32_MAX),
				0);
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

		if (IS_CONTROL_PORT(this, direction, port_id))
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
				SPA_FORMAT_mediaType,	   SPA_POD_Id(SPA_MEDIA_TYPE_application),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
		else
			param = spa_format_audio_raw_build(&b, id, &port->format.info.raw);
		break;

	case SPA_PARAM_Buffers:
	{
		uint32_t buffers, size;

		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		if (IS_CONTROL_PORT(this, direction, port_id)) {
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamBuffers, id,
				SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(1, 1, MAX_BUFFERS),
				SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
				SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
								DEFAULT_CONTROL_BUFFER_SIZE,
								1024,
								INT32_MAX),
				SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(1),
				SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		} else {
			if (other->n_buffers > 0) {
				buffers = other->n_buffers;
				size = other->size / other->stride;
			} else {
				buffers = 1;
				size = DEFAULT_SAMPLES;
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
		}
		break;
	}
	case SPA_PARAM_Meta:
		switch (result.index) {
		case 0:
			if (IS_CONTROL_PORT(this, direction, port_id))
				return -EINVAL;

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
			if (this->mix.process)
				channelmix_free(&this->mix);
		}
	} else {
		struct spa_audio_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (IS_CONTROL_PORT(this, direction, port_id)) {
			if (info.media_type != SPA_MEDIA_TYPE_application ||
			    info.media_subtype != SPA_MEDIA_SUBTYPE_control)
				return -EINVAL;
		} else {
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
		}
		port->format = info;
		port->have_format = true;

		spa_log_debug(this->log, NAME " %p: set format on port %d %d", this, port_id, res);
	}

	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[IDX_Buffers] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		port->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[IDX_Buffers] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
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
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	switch (id) {
	case SPA_PARAM_Format:
		return port_set_format(object, direction, port_id, flags, param);
	default:
		break;
	}

	return -ENOENT;
}

static int
impl_node_port_use_buffers(void *object,
		enum spa_direction direction, uint32_t port_id,
		uint32_t flags,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct impl *this = object;
	struct port *port;
	uint32_t i, j, size = SPA_ID_INVALID;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	if (IS_DATA_PORT(this, direction, port_id))
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

		for (j = 0; j < n_datas; j++) {
			if (size == SPA_ID_INVALID)
				size = d[j].maxsize;
			else if (size != d[j].maxsize)
				return -EINVAL;

			if (d[j].data == NULL) {
				spa_log_error(this->log, NAME " %p: invalid memory on buffer %p", this,
					      buffers[i]);
				return -EINVAL;
			}
			if (!SPA_IS_ALIGNED(d[j].data, 16)) {
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

static struct buffer *dequeue_buffer(struct impl *this, struct port *port)
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

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	recycle_buffer(this, buffer_id);

	return 0;
}

static int channelmix_process_control(struct impl *this, struct port *ctrlport,
				      uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
				      uint32_t n_src, const void * SPA_RESTRICT src[n_src],
				      uint32_t n_samples)
{
	struct spa_pod_control *c, *prev = NULL;
	uint32_t avail_samples = n_samples;
	uint32_t i;
	const float **s = (const float **)src;
	float **d = (float **)dst;

	SPA_POD_SEQUENCE_FOREACH(ctrlport->ctrl, c) {
		uint32_t chunk;

		if (avail_samples == 0)
			return 0;

		/* ignore old control offsets */
		if (c->offset <= ctrlport->ctrl_offset) {
			prev = c;
			continue;
		}

		switch (c->type) {
		case SPA_CONTROL_Midi:
		{
			if (prev)
				apply_midi(this, &prev->value);
			break;
		}
		case SPA_CONTROL_Properties:
		{
			if (prev)
				apply_props(this, &prev->value);
			break;
		}
		default:
			continue;
		}

		chunk = SPA_MIN(avail_samples, c->offset - ctrlport->ctrl_offset);

		spa_log_trace_fp(this->log, NAME " %p: process %d %d", this,
				c->offset, chunk);

		channelmix_process(&this->mix, n_dst, dst, n_src, src, chunk);
		for (i = 0; i < n_src; i++)
			s[i] += chunk;
		for (i = 0; i < n_dst; i++)
			d[i] += chunk;

		avail_samples -= chunk;
		ctrlport->ctrl_offset += chunk;

		prev = c;
	}

	/* when we get here we run out of control points but still have some
	 * remaining samples */
	spa_log_trace_fp(this->log, NAME " %p: remain %d", this, avail_samples);
	if (avail_samples > 0)
		channelmix_process(&this->mix, n_dst, dst, n_src, src, avail_samples);

	return 1;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *outport, *inport, *ctrlport;
	struct spa_io_buffers *outio, *inio, *ctrlio;
	struct buffer *sbuf, *dbuf;
	struct spa_pod_sequence *ctrl = NULL;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	outport = GET_OUT_PORT(this, 0);
	inport = GET_IN_PORT(this, 0);
	ctrlport = GET_CONTROL_PORT(this, 1);

	outio = outport->io;
	inio = inport->io;
	ctrlio = ctrlport->io;

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
	if (SPA_UNLIKELY(inio->status != SPA_STATUS_HAVE_DATA))
		return outio->status = inio->status;

	if (SPA_UNLIKELY(inio->buffer_id >= inport->n_buffers))
		return inio->status = -EINVAL;

	if (SPA_UNLIKELY((dbuf = dequeue_buffer(this, outport)) == NULL))
		return outio->status = -EPIPE;

	sbuf = &inport->buffers[inio->buffer_id];

	if (ctrlio != NULL &&
	    ctrlio->status == SPA_STATUS_HAVE_DATA &&
	    ctrlio->buffer_id < ctrlport->n_buffers) {
		struct buffer *cbuf = &ctrlport->buffers[ctrlio->buffer_id];
		struct spa_data *d = &cbuf->outbuf->datas[0];

		ctrl = spa_pod_from_data(d->data, d->maxsize, d->chunk->offset, d->chunk->size);
		if (ctrl && !spa_pod_is_sequence(&ctrl->pod))
			ctrl = NULL;
		if (ctrl != ctrlport->ctrl) {
			ctrlport->ctrl = ctrl;
			ctrlport->ctrl_offset = 0;
		}
	}

	{
		uint32_t i, n_samples;
		struct spa_buffer *sb = sbuf->outbuf, *db = dbuf->outbuf;
		uint32_t n_src_datas = sb->n_datas;
		uint32_t n_dst_datas = db->n_datas;
		const void *src_datas[n_src_datas];
		void *dst_datas[n_dst_datas];
		bool is_passthrough;

		is_passthrough = this->is_passthrough &&
			SPA_FLAG_IS_SET(this->mix.flags, CHANNELMIX_FLAG_IDENTITY) &&
			ctrlport->ctrl == NULL;

		n_samples = sb->datas[0].chunk->size / inport->stride;

		for (i = 0; i < n_src_datas; i++)
			src_datas[i] = sb->datas[i].data;
		for (i = 0; i < n_dst_datas; i++) {
			dst_datas[i] = is_passthrough ? (void*)src_datas[i] : dbuf->datas[i];
			db->datas[i].data = dst_datas[i];
			db->datas[i].chunk->size = n_samples * outport->stride;
		}

		spa_log_trace_fp(this->log, NAME " %p: n_src:%d n_dst:%d n_samples:%d p:%d",
				this, n_src_datas, n_dst_datas, n_samples, is_passthrough);

		if (!is_passthrough) {
			if (ctrlport->ctrl != NULL) {
				/* if return value is 1, the sequence has been processed */
				if (channelmix_process_control(this, ctrlport, n_dst_datas, dst_datas,
						n_src_datas, src_datas, n_samples) == 1) {
					ctrlio->status = SPA_STATUS_OK;
					ctrlport->ctrl = NULL;
				}
			} else {
				channelmix_process(&this->mix, n_dst_datas, dst_datas,
						n_src_datas, src_datas, n_samples);
			}
		}
	}

	outio->status = SPA_STATUS_HAVE_DATA;
	outio->buffer_id = dbuf->id;

	inio->status = SPA_STATUS_NEED_DATA;

	return SPA_STATUS_HAVE_DATA | SPA_STATUS_NEED_DATA;
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

static uint32_t channel_from_name(const char *name)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static inline uint32_t parse_position(uint32_t *pos, const char *val, size_t len)
{
	struct spa_json it[2];
	char v[256];
	uint32_t i = 0;

	spa_json_init(&it[0], val, len);
        if (spa_json_enter_array(&it[0], &it[1]) <= 0)
                spa_json_init(&it[1], val, len);

	while (spa_json_get_string(&it[1], v, sizeof(v)) > 0 &&
	    i < SPA_AUDIO_MAX_CHANNELS) {
		pos[i++] = channel_from_name(v);
	}
	return i;
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
	uint32_t i;

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

	props_reset(&this->props);

	for (i = 0; info && i < info->n_items; i++) {
		const char *k = info->items[i].key;
		const char *s = info->items[i].value;
		if (strcmp(k, "channelmix.normalize") == 0 &&
		    (strcmp(s, "true") == 0 || atoi(s) != 0))
			this->mix.options |= CHANNELMIX_OPTION_NORMALIZE;
		if (strcmp(k, "channelmix.mix-lfe") == 0 &&
		    (strcmp(s, "true") == 0 || atoi(s) != 0))
			this->mix.options |= CHANNELMIX_OPTION_MIX_LFE;
		if (strcmp(k, "channelmix.upmix") == 0 &&
		    (strcmp(s, "true") == 0 || atoi(s) != 0))
			this->mix.options |= CHANNELMIX_OPTION_UPMIX;
		if (strcmp(k, "channelmix.lfe-cutoff") == 0)
			this->mix.lfe_cutoff = atoi(s);
		if (strcmp(k, SPA_KEY_AUDIO_POSITION) == 0)
			this->props.n_channels = parse_position(this->props.channel_map, s, strlen(s));
	}
	this->props.channel.n_volumes = this->props.n_channels;
	this->props.soft.n_volumes = this->props.n_channels;
	this->props.monitor.n_volumes = this->props.n_channels;

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.flags = SPA_NODE_FLAG_RT;
	this->info.max_input_ports = 2;
	this->info.max_output_ports = 1;
	this->params[IDX_PropInfo] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[IDX_Props] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 2;

	port = GET_OUT_PORT(this, 0);
	port->direction = SPA_DIRECTION_OUTPUT;
	port->id = 0;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[IDX_EnumFormat] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[IDX_Meta] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[IDX_IO] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[IDX_Buffers] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	spa_list_init(&port->queue);

	port = GET_IN_PORT(this, 0);
	port->direction = SPA_DIRECTION_INPUT;
	port->id = 0;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF |
		SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[IDX_EnumFormat] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[IDX_Meta] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[IDX_IO] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[IDX_Buffers] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 0;
	spa_list_init(&port->queue);

	port = GET_CONTROL_PORT(this, 1);
	port->direction = SPA_DIRECTION_INPUT;
	port->id = 1;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PROPS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF |
		SPA_PORT_FLAG_DYNAMIC_DATA;
	port->params[IDX_EnumFormat] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[IDX_Meta] = SPA_PARAM_INFO(SPA_PARAM_Meta, 0);
	port->params[IDX_IO] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[IDX_Buffers] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 4;
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

const struct spa_handle_factory spa_channelmix_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_AUDIO_PROCESS_CHANNELMIX,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
