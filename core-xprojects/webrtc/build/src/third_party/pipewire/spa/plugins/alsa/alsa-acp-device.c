/* Spa ALSA Device
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

#include <stddef.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <poll.h>

#include <alsa/asoundlib.h>

#include <spa/support/log.h>
#include <spa/utils/type.h>
#include <spa/node/node.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/support/i18n.h>
#include <spa/monitor/device.h>
#include <spa/monitor/utils.h>
#include <spa/monitor/event.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/pod/parser.h>
#include <spa/debug/pod.h>

#include "acp/acp.h"

extern struct spa_i18n *acp_i18n;

#define NAME  "alsa-device"

#define MAX_POLL	16

#define DEFAULT_DEVICE		"hw:0"
#define DEFAULT_AUTO_PROFILE	true
#define DEFAULT_AUTO_PORT	true

struct props {
	char device[64];
	bool auto_profile;
	bool auto_port;
};

static void reset_props(struct props *props)
{
	strncpy(props->device, DEFAULT_DEVICE, 64);
	props->auto_profile = DEFAULT_AUTO_PROFILE;
	props->auto_port = DEFAULT_AUTO_PORT;
}

struct impl {
	struct spa_handle handle;
	struct spa_device device;

	struct spa_log *log;
	struct spa_loop *loop;

	uint32_t info_all;
	struct spa_device_info info;
#define IDX_EnumProfile		0
#define IDX_Profile		1
#define IDX_EnumRoute		2
#define IDX_Route		3
	struct spa_param_info params[4];

	struct spa_hook_list hooks;

	struct props props;

	uint32_t profile;

	struct acp_card *card;
	struct pollfd pfds[MAX_POLL];
	int n_pfds;
	struct spa_source sources[MAX_POLL];
};

static int emit_info(struct impl *this, bool full);

static void handle_acp_poll(struct spa_source *source)
{
	struct impl *this = source->data;
	int i;

	for (i = 0; i < this->n_pfds; i++)
		this->pfds[i].revents = this->sources[i].rmask;
	acp_card_handle_events(this->card);
	for (i = 0; i < this->n_pfds; i++)
		this->sources[i].rmask = 0;
	emit_info(this, false);
}

static void remove_sources(struct impl *this)
{
	int i;
	for (i = 0; i < this->n_pfds; i++) {
		spa_loop_remove_source(this->loop, &this->sources[i]);
	}
	this->n_pfds = 0;
}

static int setup_sources(struct impl *this)
{
	int i;

	remove_sources(this);

	this->n_pfds = acp_card_poll_descriptors(this->card, this->pfds, MAX_POLL);

	for (i = 0; i < this->n_pfds; i++) {
		this->sources[i].func = handle_acp_poll;
		this->sources[i].data = this;
		this->sources[i].fd = this->pfds[i].fd;
		this->sources[i].mask = this->pfds[i].events;
		this->sources[i].rmask = 0;
		spa_loop_add_source(this->loop, &this->sources[i]);
	}
	return 0;
}

static int emit_node(struct impl *this, struct acp_device *dev)
{
	struct spa_dict_item *items;
	const struct acp_dict_item *it;
	uint32_t n_items, i;
	char device_name[128], path[180], channels[16], ch[12], routes[16];
	char card_id[16], *p;
	char positions[SPA_AUDIO_MAX_CHANNELS * 12];
	struct spa_device_object_info info;
	struct acp_card *card = this->card;
	const char *stream, *devstr;;

	info = SPA_DEVICE_OBJECT_INFO_INIT();
	info.type = SPA_TYPE_INTERFACE_Node;

	if (dev->direction == ACP_DIRECTION_PLAYBACK) {
		info.factory_name = SPA_NAME_API_ALSA_PCM_SINK;
		stream = "playback";
	} else {
		info.factory_name = SPA_NAME_API_ALSA_PCM_SOURCE;
		stream = "capture";
	}

	info.change_mask = SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;

	n_items = dev->props.n_items + 7;
	items = alloca(n_items * sizeof(*items));

	snprintf(card_id, sizeof(card), "%d", card->index);

	devstr = dev->device_strings[0];
	p = strstr(devstr, "%f");
	if (p) {
		snprintf(device_name, sizeof(device_name), "%.*s%d%s",
				(int)SPA_PTRDIFF(p, devstr), devstr,
				card->index, p+2);
	} else {
		snprintf(device_name, sizeof(device_name), "%s", devstr);
	}
	snprintf(path, sizeof(path), "alsa:pcm:%s:%s:%s", card_id, device_name, stream);
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_OBJECT_PATH,	       path);
	items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PATH,           device_name);
	items[2] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_CARD,       card_id);
	items[3] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_STREAM,     stream);

	snprintf(channels, sizeof(channels), "%d", dev->format.channels);
	items[4] = SPA_DICT_ITEM_INIT(SPA_KEY_AUDIO_CHANNELS, channels);

	p = positions;
	for (i = 0; i < dev->format.channels; i++) {
		p += snprintf(p, 12, "%s%s", i == 0 ? "" : ",",
				acp_channel_str(ch, sizeof(ch), dev->format.map[i]));
	}
	items[5] = SPA_DICT_ITEM_INIT(SPA_KEY_AUDIO_POSITION, positions);

	snprintf(routes, sizeof(routes), "%d", dev->n_ports);
	items[6] = SPA_DICT_ITEM_INIT("device.routes", routes);
	n_items = 7;
	acp_dict_for_each(it, &dev->props)
		items[n_items++] = SPA_DICT_ITEM_INIT(it->key, it->value);

	info.props = &SPA_DICT_INIT(items, n_items);

	spa_device_emit_object_info(&this->hooks, dev->index, &info);

	return 0;
}

static int emit_info(struct impl *this, bool full)
{
	int err = 0;
	struct spa_dict_item *items;
	uint32_t i, n_items;
	const struct acp_dict_item *it;
	struct acp_card *card = this->card;
	char path[128];

	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		n_items = card->props.n_items + 4;
		items = alloca(n_items * sizeof(*items));

		n_items = 0;
#define ADD_ITEM(key, value) items[n_items++] = SPA_DICT_ITEM_INIT(key, value)
		snprintf(path, sizeof(path), "alsa:pcm:%d", card->index);
		ADD_ITEM(SPA_KEY_OBJECT_PATH, path);
		ADD_ITEM(SPA_KEY_DEVICE_API, "alsa:pcm");
		ADD_ITEM(SPA_KEY_MEDIA_CLASS, "Audio/Device");
		ADD_ITEM(SPA_KEY_API_ALSA_PATH,	(char *)this->props.device);
		acp_dict_for_each(it, &card->props)
			ADD_ITEM(it->key, it->value);
		this->info.props = &SPA_DICT_INIT(items, n_items);
#undef ADD_ITEM

		if (this->info.change_mask & SPA_DEVICE_CHANGE_MASK_PARAMS) {
			for (i = 0; i < SPA_N_ELEMENTS(this->params); i++) {
				if (this->params[i].user > 0) {
					this->params[i].flags ^= SPA_PARAM_INFO_SERIAL;
					this->params[i].user = 0;
				}
			}
		}
		spa_device_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
	return err;
}

static int impl_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;
	struct acp_card *card;
	struct acp_card_profile *profile;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	card = this->card;
	if (card->active_profile_index < card->n_profiles)
		profile = card->profiles[card->active_profile_index];
	else
		profile = NULL;

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	if (events->info || events->object_info)
		emit_info(this, true);

	if (profile) {
		for (i = 0; i < profile->n_devices; i++)
			emit_node(this, profile->devices[i]);
	}

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}


static int impl_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_device_emit_result(&this->hooks, seq, 0, 0, NULL);

	return 0;
}

static struct spa_pod *build_profile(struct spa_pod_builder *b, uint32_t id,
	struct acp_card_profile *pr, bool current)
{
	struct spa_pod_frame f[2];
	uint32_t i, n_classes, n_capture = 0, n_playback = 0;
	uint32_t *capture, *playback;

	capture = alloca(sizeof(uint32_t) * pr->n_devices);
	playback = alloca(sizeof(uint32_t) * pr->n_devices);

	for (i = 0; i < pr->n_devices; i++) {
		struct acp_device *dev = pr->devices[i];
		switch (dev->direction) {
		case ACP_DIRECTION_PLAYBACK:
			playback[n_playback++] = dev->index;
			break;
		case ACP_DIRECTION_CAPTURE:
			capture[n_capture++] = dev->index;
			break;
		}
	}
	n_classes = n_capture > 0 ? 1 : 0;
	n_classes += n_playback > 0 ? 1 : 0;

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamProfile, id);
	spa_pod_builder_add(b,
		SPA_PARAM_PROFILE_index, SPA_POD_Int(pr->index),
		SPA_PARAM_PROFILE_name,  SPA_POD_String(pr->name),
		SPA_PARAM_PROFILE_description,  SPA_POD_String(pr->description),
		SPA_PARAM_PROFILE_priority,  SPA_POD_Int(pr->priority),
		SPA_PARAM_PROFILE_available,  SPA_POD_Id(pr->available),
		0);
	spa_pod_builder_prop(b, SPA_PARAM_PROFILE_classes, 0);
	spa_pod_builder_push_struct(b, &f[1]);
	spa_pod_builder_int(b, n_classes);
	if (n_capture > 0) {
		spa_pod_builder_add_struct(b,
			SPA_POD_String("Audio/Source"),
			SPA_POD_Int(n_capture),
			SPA_POD_String("card.profile.devices"),
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Int,
				n_capture, capture));
	}
	if (n_playback > 0) {
		spa_pod_builder_add_struct(b,
			SPA_POD_String("Audio/Sink"),
			SPA_POD_Int(n_playback),
			SPA_POD_String("card.profile.devices"),
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Int,
				n_playback, playback));
	}
	spa_pod_builder_pop(b, &f[1]);
	if (current) {
		spa_pod_builder_prop(b, SPA_PARAM_PROFILE_save, 0);
		spa_pod_builder_bool(b, SPA_FLAG_IS_SET(pr->flags, ACP_PROFILE_SAVE));
	}

	return spa_pod_builder_pop(b, &f[0]);
}

static struct spa_pod *build_route(struct spa_pod_builder *b, uint32_t id,
	struct acp_port *p, struct acp_device *dev, uint32_t profile)
{
	struct spa_pod_frame f[2];
	const struct acp_dict_item *item;
	uint32_t i;
	enum spa_direction direction;

	switch (p->direction) {
	case ACP_DIRECTION_PLAYBACK:
		direction = SPA_DIRECTION_OUTPUT;
		break;
	case ACP_DIRECTION_CAPTURE:
		direction = SPA_DIRECTION_INPUT;
		break;
	default:
		errno = EINVAL;
		return NULL;
	}

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamRoute, id);
	spa_pod_builder_add(b,
		SPA_PARAM_ROUTE_index, SPA_POD_Int(p->index),
		SPA_PARAM_ROUTE_direction,  SPA_POD_Id(direction),
		SPA_PARAM_ROUTE_name,  SPA_POD_String(p->name),
		SPA_PARAM_ROUTE_description,  SPA_POD_String(p->description),
		SPA_PARAM_ROUTE_priority,  SPA_POD_Int(p->priority),
		SPA_PARAM_ROUTE_available,  SPA_POD_Id(p->available),
		0);
	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_info, SPA_POD_PROP_FLAG_HINT_DICT);
	spa_pod_builder_push_struct(b, &f[1]);
	spa_pod_builder_int(b, p->props.n_items);
	acp_dict_for_each(item, &p->props) {
		spa_pod_builder_add(b,
				SPA_POD_String(item->key),
				SPA_POD_String(item->value),
				NULL);
	}
	spa_pod_builder_pop(b, &f[1]);
	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_profiles, 0);
	spa_pod_builder_push_array(b, &f[1]);
	for (i = 0; i < p->n_profiles; i++)
		spa_pod_builder_int(b, p->profiles[i]->index);
	spa_pod_builder_pop(b, &f[1]);
	if (dev != NULL) {
		uint32_t channels = dev->format.channels;
		float volumes[channels];
		float soft_volumes[channels];
		bool mute;

		acp_device_get_mute(dev, &mute);
		spa_zero(volumes);
		spa_zero(soft_volumes);
		acp_device_get_volume(dev, volumes, channels);
		acp_device_get_soft_volume(dev, soft_volumes, channels);

		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_device, 0);
		spa_pod_builder_int(b, dev->index);

		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_props, 0);
		spa_pod_builder_push_object(b, &f[1], SPA_TYPE_OBJECT_Props, id);

		spa_pod_builder_prop(b, SPA_PROP_mute,
			SPA_FLAG_IS_SET(dev->flags, ACP_DEVICE_HW_MUTE) ?
			SPA_POD_PROP_FLAG_HARDWARE : 0);
		spa_pod_builder_bool(b, mute);

		spa_pod_builder_prop(b, SPA_PROP_channelVolumes,
			SPA_FLAG_IS_SET(dev->flags, ACP_DEVICE_HW_VOLUME) ?
			SPA_POD_PROP_FLAG_HARDWARE : 0);
		spa_pod_builder_array(b, sizeof(float), SPA_TYPE_Float,
				channels, volumes);

		spa_pod_builder_prop(b, SPA_PROP_volumeBase, SPA_POD_PROP_FLAG_READONLY);
		spa_pod_builder_float(b, dev->base_volume);
		spa_pod_builder_prop(b, SPA_PROP_volumeStep, SPA_POD_PROP_FLAG_READONLY);
		spa_pod_builder_float(b, dev->volume_step);

		spa_pod_builder_prop(b, SPA_PROP_channelMap, 0);
		spa_pod_builder_array(b, sizeof(uint32_t), SPA_TYPE_Id,
				channels, dev->format.map);

		spa_pod_builder_prop(b, SPA_PROP_softVolumes, 0);
		spa_pod_builder_array(b, sizeof(float), SPA_TYPE_Float,
				channels, soft_volumes);

		spa_pod_builder_pop(b, &f[1]);
	}
	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_devices, 0);
	spa_pod_builder_push_array(b, &f[1]);
	for (i = 0; i < p->n_devices; i++)
		spa_pod_builder_int(b, p->devices[i]->index);
	spa_pod_builder_pop(b, &f[1]);

	if (profile != SPA_ID_INVALID) {
		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_profile, 0);
		spa_pod_builder_int(b, profile);
		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_save, 0);
		spa_pod_builder_bool(b, SPA_FLAG_IS_SET(p->flags, ACP_PORT_SAVE));
	}
	return spa_pod_builder_pop(b, &f[0]);
}

static struct acp_port *find_port_for_device(struct acp_card *card, struct acp_device *dev)
{
	uint32_t i;
	for (i = 0; i < dev->n_ports; i++) {
		struct acp_port *p = dev->ports[i];
		if (SPA_FLAG_IS_SET(p->flags, ACP_PORT_ACTIVE))
			return p;
	}
	return NULL;
}

static int impl_enum_params(void *object, int seq,
			    uint32_t id, uint32_t start, uint32_t num,
			    const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[4096];
	struct spa_result_device_params result;
	uint32_t count = 0;
	struct acp_card *card;
	struct acp_card_profile *pr;
	struct acp_port *p;
	struct acp_device *dev;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	card = this->card;

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumProfile:
		if (result.index >= card->n_profiles)
			return 0;

		pr = card->profiles[result.index];
		param = build_profile(&b, id, pr, false);
		break;

	case SPA_PARAM_Profile:
		if (result.index > 0 || card->active_profile_index >= card->n_profiles)
			return 0;

		pr = card->profiles[card->active_profile_index];
		param = build_profile(&b, id, pr, true);
		break;

	case SPA_PARAM_EnumRoute:
		if (result.index >= card->n_ports)
			return 0;

		p = card->ports[result.index];
		param = build_route(&b, id, p, NULL, SPA_ID_INVALID);
		break;

	case SPA_PARAM_Route:
		while (true) {
			if (result.index >= card->n_devices)
				return 0;

			dev = card->devices[result.index];
			if (SPA_FLAG_IS_SET(dev->flags, ACP_DEVICE_ACTIVE) &&
			    (p = find_port_for_device(card, dev)) != NULL)
				break;

			result.index++;
		}
		result.next = result.index + 1;
		param = build_route(&b, id, p, dev, card->active_profile_index);
		if (param == NULL)
			return -errno;
		break;

	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_device_emit_result(&this->hooks, seq, 0,
			SPA_RESULT_TYPE_DEVICE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int apply_device_props(struct impl *this, struct acp_device *dev, struct spa_pod *props)
{
	float volume = 0;
	bool mute = 0;
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) props;
	int changed = 0;
	float volumes[ACP_MAX_CHANNELS];
	uint32_t channels[ACP_MAX_CHANNELS];
	uint32_t n_volumes = 0, n_channels = 0;

	if (!spa_pod_is_object_type(props, SPA_TYPE_OBJECT_Props))
		return -EINVAL;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &volume) == 0) {
				acp_device_set_volume(dev, &volume, 1);
				changed++;
			}
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &mute) == 0) {
				acp_device_set_mute(dev, mute);
				changed++;
			}
			break;
		case SPA_PROP_channelVolumes:
			if ((n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					volumes, ACP_MAX_CHANNELS)) > 0) {
				changed++;
			}
			break;
		case SPA_PROP_channelMap:
			if ((n_channels = spa_pod_copy_array(&prop->value, SPA_TYPE_Id,
					channels, ACP_MAX_CHANNELS)) > 0) {
				changed++;
			}
			break;
		}
	}
	if (n_volumes > 0)
		acp_device_set_volume(dev, volumes, n_volumes);

	return changed;
}

static int impl_set_param(void *object,
			  uint32_t id, uint32_t flags,
			  const struct spa_pod *param)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Profile:
	{
		uint32_t id;
		bool save = false;

		if (param == NULL) {
			id = acp_card_find_best_profile_index(this->card, NULL);
			save = true;
		} else if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&id),
				SPA_PARAM_PROFILE_save, SPA_POD_OPT_Bool(&save))) < 0) {
			spa_log_warn(this->log, "can't parse profile");
			spa_debug_pod(0, NULL, param);
			return res;
		}

		res = acp_card_set_profile(this->card, id, save ? ACP_PROFILE_SAVE : 0);
		emit_info(this, false);
		break;
	}
	case SPA_PARAM_Route:
	{
		uint32_t id, device;
		struct spa_pod *props = NULL;
		struct acp_device *dev;
		bool save = false;

		if (param == NULL)
			return -EINVAL;

		if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamRoute, NULL,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(&id),
				SPA_PARAM_ROUTE_device, SPA_POD_Int(&device),
				SPA_PARAM_ROUTE_props, SPA_POD_OPT_Pod(&props),
				SPA_PARAM_ROUTE_save, SPA_POD_OPT_Bool(&save))) < 0) {
			spa_log_warn(this->log, "can't parse route");
			spa_debug_pod(0, NULL, param);
			return res;
		}
		if (device >= this->card->n_devices)
			return -EINVAL;

		dev = this->card->devices[device];
		res = acp_device_set_port(dev, id, save ? ACP_PORT_SAVE : 0);
		if (props)
			apply_device_props(this, dev, props);
		emit_info(this, false);
		break;
	}
	default:
		return -ENOENT;
	}
	return 0;
}

static const struct spa_device_methods impl_device = {
	SPA_VERSION_DEVICE_METHODS,
	.add_listener = impl_add_listener,
	.sync = impl_sync,
	.enum_params = impl_enum_params,
	.set_param = impl_set_param,
};

static void card_props_changed(void *data)
{
	struct impl *this = data;
	spa_log_info(this->log, "card properties changed");
}

static bool has_device(struct acp_card_profile *pr, uint32_t index)
{
	uint32_t i;

	for (i = 0; i < pr->n_devices; i++)
		if (pr->devices[i]->index == index)
			return true;
	return false;
}

static void card_profile_changed(void *data, uint32_t old_index, uint32_t new_index)
{
	struct impl *this = data;
	struct acp_card *card = this->card;
	struct acp_card_profile *op = card->profiles[old_index];
	struct acp_card_profile *np = card->profiles[new_index];
	uint32_t i;

	spa_log_info(this->log, "card profile changed from %s to %s",
			op->name, np->name);

	for (i = 0; i < op->n_devices; i++) {
		uint32_t index = op->devices[i]->index;
		if (has_device(np, index))
			continue;
		spa_device_emit_object_info(&this->hooks, index, NULL);
	}
	for (i = 0; i < np->n_devices; i++) {
		emit_node(this, np->devices[i]);
	}
	setup_sources(this);

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Profile].user++;
	this->params[IDX_Route].user++;
	this->params[IDX_EnumRoute].user++;
}

static void card_profile_available(void *data, uint32_t index,
		enum acp_available old, enum acp_available available)
{
	struct impl *this = data;
	struct acp_card *card = this->card;
	struct acp_card_profile *p = card->profiles[index];

	spa_log_info(this->log, "card profile %s available %s -> %s", p->name,
			acp_available_str(old), acp_available_str(available));

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_EnumProfile].user++;
	this->params[IDX_Profile].user++;

	if (this->props.auto_profile) {
		uint32_t best = acp_card_find_best_profile_index(card, NULL);
		acp_card_set_profile(card, best, 0);
	}
}

static void card_port_changed(void *data, uint32_t old_index, uint32_t new_index)
{
	struct impl *this = data;
	struct acp_card *card = this->card;
	struct acp_port *op = card->ports[old_index];
	struct acp_port *np = card->ports[new_index];

	spa_log_info(this->log, "card port changed from %s to %s",
			op->name, np->name);

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Route].user++;
}

static void card_port_available(void *data, uint32_t index,
		enum acp_available old, enum acp_available available)
{
	struct impl *this = data;
	struct acp_card *card = this->card;
	struct acp_port *p = card->ports[index];

	spa_log_info(this->log, "card port %s available %s -> %s", p->name,
			acp_available_str(old), acp_available_str(available));

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_EnumRoute].user++;
	this->params[IDX_Route].user++;

	if (this->props.auto_port) {
		uint32_t i;

		for (i = 0; i < p->n_devices; i++) {
			struct acp_device *d = p->devices[i];
			uint32_t best;

			if (!(d->flags & ACP_DEVICE_ACTIVE))
				continue;

			best = acp_device_find_best_port_index(d, NULL);
			acp_device_set_port(d, best, 0);
		}
	}
}

static void on_volume_changed(void *data, struct acp_device *dev)
{
	struct impl *this = data;
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];
	uint32_t n_volume = dev->format.channels;
	float volume[n_volume];
	float soft_volume[n_volume];

	spa_log_info(this->log, "device %s volume changed", dev->name);
	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Route].user++;

	spa_zero(volume);
	spa_zero(soft_volume);
	acp_device_get_volume(dev, volume, n_volume);
	acp_device_get_soft_volume(dev, soft_volume, n_volume);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, dev->index);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);
	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_channelVolumes, SPA_POD_Array(sizeof(float),
						SPA_TYPE_Float, n_volume, volume),
			SPA_PROP_channelMap, SPA_POD_Array(sizeof(uint32_t),
						SPA_TYPE_Id, dev->format.channels,
						dev->format.map),
			SPA_PROP_softVolumes, SPA_POD_Array(sizeof(float),
						SPA_TYPE_Float, n_volume, soft_volume));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_device_emit_event(&this->hooks, event);
}

static void on_mute_changed(void *data, struct acp_device *dev)
{
	struct impl *this = data;
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];
	bool mute;

	spa_log_info(this->log, "device %s mute changed", dev->name);
	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Route].user++;

	acp_device_get_mute(dev, &mute);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, dev->index);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);

	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_mute, SPA_POD_Bool(mute),
			SPA_PROP_softMute, SPA_POD_Bool(mute));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_device_emit_event(&this->hooks, event);
}

struct acp_card_events card_events = {
	ACP_VERSION_CARD_EVENTS,
	.props_changed = card_props_changed,
	.profile_changed = card_profile_changed,
	.profile_available = card_profile_available,
	.port_changed = card_port_changed,
	.port_available = card_port_available,
	.volume_changed = on_volume_changed,
	.mute_changed = on_mute_changed,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Device) == 0)
		*interface = &this->device;
	else
		return -ENOENT;

	return 0;
}

static SPA_PRINTF_FUNC(6,0) void impl_acp_log_func(void *data,
		int level, const char *file, int line, const char *func,
		const char *fmt, va_list arg)
{
	struct spa_log *log = data;
	spa_log_logv(log, (enum spa_log_level)level, file, line, func, fmt, arg);
}

static int impl_clear(struct spa_handle *handle)
{
	struct impl *this = (struct impl *) handle;
	remove_sources(this);
	if (this->card) {
		acp_card_destroy(this->card);
		this->card = NULL;
	}
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
	const char *str;
	struct acp_dict_item *items = NULL;
	const struct spa_dict_item *it;
	uint32_t n_items = 0;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Loop);
	acp_i18n = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_I18N);
	if (this->loop == NULL) {
		spa_log_error(this->log, "a Loop interface is needed");
		return -EINVAL;
	}

	acp_set_log_func(impl_acp_log_func, this->log);
	acp_set_log_level(6);

	this->device.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Device,
			SPA_VERSION_DEVICE,
			&impl_device, this);
	spa_hook_list_init(&this->hooks);

	reset_props(&this->props);

	if (info) {
		if ((str = spa_dict_lookup(info, SPA_KEY_API_ALSA_PATH)) != NULL)
			snprintf(this->props.device, sizeof(this->props.device), "%s", str);
		if ((str = spa_dict_lookup(info, "api.acp.auto-port")) != NULL)
			this->props.auto_port = strcmp(str, "true") == 0 || atoi(str) != 0;
		if ((str = spa_dict_lookup(info, "api.acp.auto-profile")) != NULL)
			this->props.auto_profile = strcmp(str, "true") == 0 || atoi(str) != 0;

		items = alloca((info->n_items) * sizeof(*items));
		spa_dict_for_each(it, info)
			items[n_items++] = ACP_DICT_ITEM_INIT(it->key, it->value);
	}

	spa_log_debug(this->log, "probe card %s", this->props.device);
	if ((str = strchr(this->props.device, ':')) == NULL)
		return -EINVAL;

	this->card = acp_card_new(atoi(str+1), &ACP_DICT_INIT(items, n_items));
	if (this->card == NULL)
		return -errno;

	setup_sources(this);

	acp_card_add_listener(this->card, &card_events, this);

	this->info = SPA_DEVICE_INFO_INIT();
	this->info_all = SPA_DEVICE_CHANGE_MASK_PROPS |
		SPA_DEVICE_CHANGE_MASK_PARAMS;

	this->params[IDX_EnumProfile] = SPA_PARAM_INFO(SPA_PARAM_EnumProfile, SPA_PARAM_INFO_READ);
	this->params[IDX_Profile] = SPA_PARAM_INFO(SPA_PARAM_Profile, SPA_PARAM_INFO_READWRITE);
	this->params[IDX_EnumRoute] = SPA_PARAM_INFO(SPA_PARAM_EnumRoute, SPA_PARAM_INFO_READ);
	this->params[IDX_Route] = SPA_PARAM_INFO(SPA_PARAM_Route, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 4;

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Device,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	if (*index >= SPA_N_ELEMENTS(impl_interfaces))
		return 0;

	*info = &impl_interfaces[(*index)++];
	return 1;
}

const struct spa_handle_factory spa_alsa_acp_device_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_ALSA_ACP_DEVICE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
