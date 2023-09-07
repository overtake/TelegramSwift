/* Spa Bluez5 Device
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
#include <errno.h>

#include <spa/support/log.h>
#include <spa/utils/type.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/support/i18n.h>
#include <spa/monitor/device.h>
#include <spa/monitor/utils.h>
#include <spa/monitor/event.h>
#include <spa/pod/filter.h>
#include <spa/pod/parser.h>
#include <spa/param/param.h>
#include <spa/param/audio/raw.h>
#include <spa/param/bluetooth/audio.h>
#include <spa/param/bluetooth/type-info.h>
#include <spa/debug/pod.h>

#include "defs.h"
#include "a2dp-codecs.h"

#define NAME  "bluez5-device"

#define MAX_DEVICES	64

#define DEVICE_ID_SOURCE	0
#define DEVICE_ID_SINK		1
#define DYNAMIC_NODE_ID_FLAG	0x1000

static struct spa_i18n *_i18n;

#define _(_str)	 spa_i18n_text(_i18n,(_str))
#define N_(_str) (_str)

enum {
	DEVICE_PROFILE_OFF = 0,
	DEVICE_PROFILE_AG = 1,
	DEVICE_PROFILE_A2DP = 2,
	DEVICE_PROFILE_HSP_HFP = 3,
};

struct props {
	enum spa_bluetooth_audio_codec codec;
};

static void reset_props(struct props *props)
{
	props->codec = 0;
}

struct impl;

struct node {
	struct impl *impl;
	struct spa_bt_transport *transport;
	struct spa_hook transport_listener;
	uint32_t id;
	unsigned int active:1;
	unsigned int mute:1;
	unsigned int save:1;
	uint32_t n_channels;
	int64_t latency_offset;
	uint32_t channels[SPA_AUDIO_MAX_CHANNELS];
	float volumes[SPA_AUDIO_MAX_CHANNELS];
	float soft_volumes[SPA_AUDIO_MAX_CHANNELS];
};

struct dynamic_node
{
	struct impl *impl;
	struct spa_bt_transport *transport;
	struct spa_hook transport_listener;
	uint32_t id;
	const char *factory_name;
};

struct impl {
	struct spa_handle handle;
	struct spa_device device;

	struct spa_log *log;

	uint32_t info_all;
	struct spa_device_info info;
#define IDX_EnumProfile		0
#define IDX_Profile		1
#define IDX_EnumRoute		2
#define IDX_Route		3
#define IDX_PropInfo		4
#define IDX_Props		5
	struct spa_param_info params[6];

	struct spa_hook_list hooks;

	struct props props;

	struct spa_bt_device *bt_dev;
	struct spa_hook bt_dev_listener;

	uint32_t profile;
	unsigned int switching_codec:1;
	uint32_t prev_bt_connected_profiles;

	const struct a2dp_codec **supported_codecs;
	size_t supported_codec_count;

	struct dynamic_node dyn_a2dp_source;
	struct dynamic_node dyn_sco_source;
	struct dynamic_node dyn_sco_sink;

#define MAX_SETTINGS 32
	struct spa_dict_item setting_items[MAX_SETTINGS];
	struct spa_dict setting_dict;

	struct node nodes[2];
};

static void init_node(struct impl *this, struct node *node, uint32_t id)
{
	uint32_t i;

	spa_zero(*node);
	node->id = id;
	for (i = 0; i < SPA_AUDIO_MAX_CHANNELS; i++)
		node->volumes[i] = 1.0;
}

static const struct a2dp_codec *get_a2dp_codec(enum spa_bluetooth_audio_codec id)
{
	const struct a2dp_codec **c;

	for (c = a2dp_codecs; *c; ++c)
		if ((*c)->id == id)
			return *c;

	return NULL;
}

static const struct a2dp_codec *get_supported_a2dp_codec(struct impl *this, enum spa_bluetooth_audio_codec id)
{
	const struct a2dp_codec *a2dp_codec = NULL;
	size_t i;
	for (i = 0; i < this->supported_codec_count; ++i)
		if (this->supported_codecs[i]->id == id)
			a2dp_codec = this->supported_codecs[i];
	return a2dp_codec;
}

static unsigned int get_hfp_codec(enum spa_bluetooth_audio_codec id)
{
	switch (id) {
	case SPA_BLUETOOTH_AUDIO_CODEC_CVSD:
		return HFP_AUDIO_CODEC_CVSD;
	case SPA_BLUETOOTH_AUDIO_CODEC_MSBC:
		return HFP_AUDIO_CODEC_MSBC;
	default:
		return 0;
	}
}

static enum spa_bluetooth_audio_codec get_hfp_codec_id(unsigned int codec)
{
	switch (codec) {
	case HFP_AUDIO_CODEC_MSBC:
		return SPA_BLUETOOTH_AUDIO_CODEC_MSBC;
	case HFP_AUDIO_CODEC_CVSD:
		return SPA_BLUETOOTH_AUDIO_CODEC_CVSD;
	}
	return SPA_ID_INVALID;
}

static const char *get_hfp_codec_description(unsigned int codec)
{
	switch (codec) {
	case HFP_AUDIO_CODEC_MSBC:
		return "mSBC";
	case HFP_AUDIO_CODEC_CVSD:
		return "CVSD";
	}
	return "unknown";
}

static const char *get_hfp_codec_name(unsigned int codec)
{
	switch (codec) {
	case HFP_AUDIO_CODEC_MSBC:
		return "msbc";
	case HFP_AUDIO_CODEC_CVSD:
		return "cvsd";
	}
	return "unknown";
}

static const char *get_codec_name(struct spa_bt_transport *t)
{
	if (t->a2dp_codec != NULL)
		return t->a2dp_codec->name;
	return get_hfp_codec_name(t->codec);
}

static void transport_destroy(void *userdata)
{
	struct node *node = userdata;
	node->transport = NULL;
}

static void emit_volume(struct impl *this, struct node *node)
{
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, node->id);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);
	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_channelVolumes, SPA_POD_Array(sizeof(float),
				SPA_TYPE_Float, node->n_channels, node->volumes),
			SPA_PROP_softVolumes, SPA_POD_Array(sizeof(float),
				SPA_TYPE_Float, node->n_channels, node->soft_volumes),
			SPA_PROP_channelMap, SPA_POD_Array(sizeof(uint32_t),
				SPA_TYPE_Id, node->n_channels, node->channels));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_device_emit_event(&this->hooks, event);
}

static void emit_info(struct impl *this, bool full);

static float node_get_hw_volume(struct node *node)
{
	uint32_t i;
	float hw_volume = 0.0f;
	for (i = 0; i < node->n_channels; i++)
		hw_volume = SPA_MAX(node->volumes[i], hw_volume);
	return SPA_MIN(hw_volume, 1.0f);
}

static void node_update_soft_volumes(struct node *node, float hw_volume)
{
	for (uint32_t i = 0; i < node->n_channels; ++i) {
		node->soft_volumes[i] = hw_volume > 0.0f
			? node->volumes[i] / hw_volume
			: 0.0f;
	}
}

static void volume_changed(void *userdata)
{
	struct node *node = userdata;
	struct impl *impl = node->impl;
	struct spa_bt_transport_volume *t_volume;
	float prev_hw_volume;

	if (!node->transport || !spa_bt_transport_volume_enabled(node->transport))
		return;

	/* PW is the controller for remote device. */
	if (impl->profile != DEVICE_PROFILE_A2DP
	    && impl->profile !=  DEVICE_PROFILE_HSP_HFP)
		return;

	t_volume = &node->transport->volumes[node->id];

	if (!t_volume->active)
		return;

	prev_hw_volume = node_get_hw_volume(node);
	for (uint32_t i = 0; i < node->n_channels; ++i) {
		node->volumes[i] = prev_hw_volume > 0.0f
			? node->volumes[i] * t_volume->volume / prev_hw_volume
			: t_volume->volume;
	}

	node_update_soft_volumes(node, t_volume->volume);

	impl->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	impl->params[IDX_Route].flags ^= SPA_PARAM_INFO_SERIAL;
	emit_info(impl, false);

	/* It sometimes flips volume to over 100% in pavucontrol slider
	 * if volume is emitted before route info emitting while node
	 * volumes are not identical to route volumes. Not sure why. */
	emit_volume(impl, node);
}

static const struct spa_bt_transport_events transport_events = {
	SPA_VERSION_BT_DEVICE_EVENTS,
	.destroy = transport_destroy,
	.volume_changed = volume_changed,
};

static void emit_node(struct impl *this, struct spa_bt_transport *t,
		uint32_t id, const char *factory_name)
{
	struct spa_bt_device *device = this->bt_dev;
	struct spa_device_object_info info;
	struct spa_dict_item items[6];
	uint32_t n_items = 0;
	char transport[32], str_id[32];
	bool is_dyn_node = SPA_FLAG_IS_SET(id, DYNAMIC_NODE_ID_FLAG);

	snprintf(transport, sizeof(transport), "pointer:%p", t);
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_API_BLUEZ5_TRANSPORT, transport);
	items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_API_BLUEZ5_PROFILE, spa_bt_profile_name(t->profile));
	items[2] = SPA_DICT_ITEM_INIT(SPA_KEY_API_BLUEZ5_CODEC, get_codec_name(t));
	items[3] = SPA_DICT_ITEM_INIT(SPA_KEY_API_BLUEZ5_ADDRESS, device->address);
	items[4] = SPA_DICT_ITEM_INIT("device.routes", "1");
	n_items = 5;
	if (!is_dyn_node) {
		snprintf(str_id, sizeof(str_id), "%d", id);
		items[5] = SPA_DICT_ITEM_INIT("card.profile.device", str_id);
		n_items++;
	}

	info = SPA_DEVICE_OBJECT_INFO_INIT();
	info.type = SPA_TYPE_INTERFACE_Node;
	info.factory_name = factory_name;
	info.change_mask = SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;
	info.props = &SPA_DICT_INIT(items, n_items);

	SPA_FLAG_CLEAR(id, DYNAMIC_NODE_ID_FLAG);
	spa_device_emit_object_info(&this->hooks, id, &info);

	if (!is_dyn_node) {
		if (this->nodes[id].n_channels > 0) {
			size_t i;

			/*
			* Spread mono volume to all channels, if we had switched HFP -> A2DP.
			* XXX: we should also use different route for hfp and a2dp
			*/
			for (i = this->nodes[id].n_channels; i < t->n_channels; ++i)
				this->nodes[id].volumes[i] = this->nodes[id].volumes[i % this->nodes[id].n_channels];
		}

		this->nodes[id].impl = this;
		this->nodes[id].active = true;
		this->nodes[id].n_channels = t->n_channels;
		memcpy(this->nodes[id].channels, t->channels,
				t->n_channels * sizeof(uint32_t));
		if (this->nodes[id].transport)
			spa_hook_remove(&this->nodes[id].transport_listener);
		this->nodes[id].transport = t;
		spa_bt_transport_add_listener(t, &this->nodes[id].transport_listener, &transport_events, &this->nodes[id]);
	}
}

static struct spa_bt_transport *find_transport(struct impl *this, int profile, enum spa_bluetooth_audio_codec codec)
{
	struct spa_bt_device *device = this->bt_dev;
	struct spa_bt_transport *t;
	const struct a2dp_codec *a2dp_codec;
	unsigned int hfp_codec;

	a2dp_codec = get_a2dp_codec(codec);
	hfp_codec = get_hfp_codec(codec);

	spa_list_for_each(t, &device->transport_list, device_link) {
		if ((t->profile & device->connected_profiles) &&
				(t->profile & profile) == t->profile &&
				(a2dp_codec == NULL || t->a2dp_codec == a2dp_codec) &&
				(hfp_codec == 0 || t->codec == hfp_codec))
			return t;
	}

	return NULL;
}

static void dynamic_node_transport_destroy(void *data)
{
	struct dynamic_node *this = data;
	spa_log_debug(this->impl->log, "transport %p destroy", this->transport);
	this->transport = NULL;
}

static void dynamic_node_transport_state_changed(void *data,
	enum spa_bt_transport_state old,
	enum spa_bt_transport_state state)
{
	struct dynamic_node *this = data;
	struct impl *impl = this->impl;
	struct spa_bt_transport *t = this->transport;

	spa_log_debug(impl->log, "transport %p state %d->%d", t, old, state);

	if (state >= SPA_BT_TRANSPORT_STATE_PENDING && old < SPA_BT_TRANSPORT_STATE_PENDING) {
		if (!SPA_FLAG_IS_SET(this->id, DYNAMIC_NODE_ID_FLAG)) {
			SPA_FLAG_SET(this->id, DYNAMIC_NODE_ID_FLAG);
			emit_node(impl, t, this->id, this->factory_name);
		}
	} else if (state < SPA_BT_TRANSPORT_STATE_PENDING && old >= SPA_BT_TRANSPORT_STATE_PENDING) {
		if (SPA_FLAG_IS_SET(this->id, DYNAMIC_NODE_ID_FLAG)) {
			SPA_FLAG_CLEAR(this->id, DYNAMIC_NODE_ID_FLAG);
			spa_device_emit_object_info(&impl->hooks, this->id, NULL);
		}
	}
}

static void dynamic_node_volume_changed(void *data)
{
	struct dynamic_node *node = data;
	struct impl *impl = node->impl;
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];
	struct spa_bt_transport_volume *t_volume;
	int id = node->id, volume_id;

	SPA_FLAG_CLEAR(id, DYNAMIC_NODE_ID_FLAG);

	/* Remote device is the controller */
	if (!node->transport || impl->profile != DEVICE_PROFILE_AG
	    || !spa_bt_transport_volume_enabled(node->transport))
		return;

	if (id == 0 || id == 2)
		volume_id = SPA_BT_VOLUME_ID_RX;
	else if (id == 1)
		volume_id = SPA_BT_VOLUME_ID_TX;
	else
		return;

	t_volume = &node->transport->volumes[volume_id];
	if (!t_volume->active)
		return;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, id);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);
	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_volume, SPA_POD_Float(t_volume->volume));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_log_debug(impl->log, "dynamic node %p: volume %d changed %f, profile %d",
		node, volume_id, t_volume->volume, node->transport->profile);

	/* Dynamic node doesn't has route, we can only set volume on adaptar node. */
	spa_device_emit_event(&impl->hooks, event);
}

static const struct spa_bt_transport_events dynamic_node_transport_events = {
	SPA_VERSION_BT_TRANSPORT_EVENTS,
	.destroy = dynamic_node_transport_destroy,
	.state_changed = dynamic_node_transport_state_changed,
	.volume_changed = dynamic_node_volume_changed,
};

static void emit_dynamic_node(struct dynamic_node *this, struct impl *impl,
	struct spa_bt_transport *t, uint32_t id, const char *factory_name)
{
	if (this->transport != NULL)
		return;

	this->impl = impl;
	this->transport = t;
	this->id = id;
	this->factory_name = factory_name;

	spa_bt_transport_add_listener(this->transport,
		&this->transport_listener, &dynamic_node_transport_events, this);

	/* emits the node if the state is already pending */
	dynamic_node_transport_state_changed (this, SPA_BT_TRANSPORT_STATE_IDLE, t->state);
}

static void remove_dynamic_node(struct dynamic_node *this)
{
	if (this->transport == NULL)
		return;

	/* destroy the node, if it exists */
	dynamic_node_transport_state_changed (this, this->transport->state,
		SPA_BT_TRANSPORT_STATE_IDLE);

	spa_hook_remove(&this->transport_listener);
	this->impl = NULL;
	this->transport = NULL;
	this->id = 0;
	this->factory_name = NULL;
}

static int emit_nodes(struct impl *this)
{
	struct spa_bt_transport *t;

	switch (this->profile) {
	case DEVICE_PROFILE_OFF:
		break;
	case DEVICE_PROFILE_AG:
		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY) {
			t = find_transport(this, SPA_BT_PROFILE_HFP_AG, 0);
			if (!t)
				t = find_transport(this, SPA_BT_PROFILE_HSP_AG, 0);
			if (t) {
				if (t->profile == SPA_BT_PROFILE_HSP_AG)
					this->props.codec = 0;
				else
					this->props.codec = get_hfp_codec_id(t->codec);
				emit_dynamic_node(&this->dyn_sco_source, this, t,
						0, SPA_NAME_API_BLUEZ5_SCO_SOURCE);
				emit_dynamic_node(&this->dyn_sco_sink, this, t,
						1, SPA_NAME_API_BLUEZ5_SCO_SINK);
			}
		}
		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SOURCE) {
			t = find_transport(this, SPA_BT_PROFILE_A2DP_SOURCE, 0);
			if (t) {
				this->props.codec = t->a2dp_codec->id;
				emit_dynamic_node(&this->dyn_a2dp_source, this, t,
						2, SPA_NAME_API_BLUEZ5_A2DP_SOURCE);
			}
		}
		break;
	case DEVICE_PROFILE_A2DP:
		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SOURCE) {
			t = find_transport(this, SPA_BT_PROFILE_A2DP_SOURCE, 0);
			if (t) {
				this->props.codec = t->a2dp_codec->id;
				emit_dynamic_node(&this->dyn_a2dp_source, this, t,
					DEVICE_ID_SOURCE, SPA_NAME_API_BLUEZ5_A2DP_SOURCE);
			}
		}

		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SINK) {
			t = find_transport(this, SPA_BT_PROFILE_A2DP_SINK, this->props.codec);
			if (t) {
				this->props.codec = t->a2dp_codec->id;
				emit_node(this, t, DEVICE_ID_SINK, SPA_NAME_API_BLUEZ5_A2DP_SINK);
			}
		}
		break;
	case DEVICE_PROFILE_HSP_HFP:
		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_HEADSET_HEAD_UNIT) {
			t = find_transport(this, SPA_BT_PROFILE_HFP_HF, this->props.codec);
			if (!t)
				t = find_transport(this, SPA_BT_PROFILE_HSP_HS, 0);
			if (t) {
				if (t->profile == SPA_BT_PROFILE_HSP_HS)
					this->props.codec = 0;
				else
					this->props.codec = get_hfp_codec_id(t->codec);
				emit_node(this, t, DEVICE_ID_SOURCE, SPA_NAME_API_BLUEZ5_SCO_SOURCE);
				emit_node(this, t, DEVICE_ID_SINK, SPA_NAME_API_BLUEZ5_SCO_SINK);
			}
		}
		break;
	default:
		return -EINVAL;
	}
	return 0;
}

static const struct spa_dict_item info_items[] = {
	{ SPA_KEY_DEVICE_API, "bluez5" },
	{ SPA_KEY_DEVICE_BUS, "bluetooth" },
	{ SPA_KEY_MEDIA_CLASS, "Audio/Device" },
};

static void emit_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		this->info.props = &SPA_DICT_INIT_ARRAY(info_items);

		spa_device_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_remove_nodes(struct impl *this)
{
	remove_dynamic_node (&this->dyn_a2dp_source);
	remove_dynamic_node (&this->dyn_sco_source);
	remove_dynamic_node (&this->dyn_sco_sink);

	for (uint32_t i = 0; i < 2; i++) {
		struct node * node = &this->nodes[i];
		if (node->transport) {
			spa_hook_remove(&node->transport_listener);
			node->transport = NULL;
		}
		if (node->active) {
			spa_device_emit_object_info(&this->hooks, i, NULL);
			node->active = false;
		}
	}
}

static int set_profile(struct impl *this, uint32_t profile, enum spa_bluetooth_audio_codec codec)
{
	if (this->profile == profile &&
	    (this->profile != DEVICE_PROFILE_A2DP || codec == this->props.codec) &&
	    (this->profile != DEVICE_PROFILE_HSP_HFP || codec == this->props.codec))
		return 0;

	emit_remove_nodes(this);

	spa_bt_device_release_transports(this->bt_dev);

	this->profile = profile;
	this->prev_bt_connected_profiles = this->bt_dev->connected_profiles;
	this->props.codec = codec;

	/*
	 * A2DP: ensure there's a transport with the selected codec (NULL means any).
	 * Don't try to switch codecs when the device is in the A2DP source role, since
	 * devices do not appear to like that.
	 */
	if (profile == DEVICE_PROFILE_A2DP && !(this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SOURCE)) {
		int ret;
		const struct a2dp_codec *codec_list[2], **codecs, *a2dp_codec;

		a2dp_codec = get_a2dp_codec(codec);
		if (a2dp_codec == NULL) {
			codecs = a2dp_codecs;
		} else {
			codec_list[0] = a2dp_codec;
			codec_list[1] = NULL;
			codecs = codec_list;
		}

		this->switching_codec = true;

		ret = spa_bt_device_ensure_a2dp_codec(this->bt_dev, codecs);
		if (ret < 0) {
			if (ret != -ENOTSUP)
				spa_log_error(this->log, NAME": failed to switch codec (%d), setting basic profile", ret);
		} else {
			return 0;
		}
	} else if (profile == DEVICE_PROFILE_HSP_HFP && get_hfp_codec(codec) && !(this->bt_dev->connected_profiles & SPA_BT_PROFILE_HFP_AG)) {
		int ret;

		this->switching_codec = true;

		ret = spa_bt_device_ensure_hfp_codec(this->bt_dev, get_hfp_codec(codec));
		if (ret < 0) {
			if (ret != -ENOTSUP)
				spa_log_error(this->log, NAME": failed to switch codec (%d), setting basic profile", ret);
		} else {
			return 0;
		}
	}

	this->switching_codec = false;
	this->props.codec = 0;
	emit_nodes(this);

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Profile].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Route].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_EnumRoute].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Props].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_PropInfo].flags ^= SPA_PARAM_INFO_SERIAL;
	emit_info(this, false);

	return 0;
}

static void codec_switched(void *userdata, int status)
{
	struct impl *this = userdata;

	spa_log_debug(this->log, NAME": codec switched (status %d)", status);

	this->switching_codec = false;

	if (status < 0) {
		/* Failed to switch: return to a fallback profile */
		spa_log_error(this->log, NAME": failed to switch codec (%d), setting fallback profile", status);
		if (this->profile == DEVICE_PROFILE_A2DP && this->props.codec != 0) {
			this->props.codec = 0;
		} else if (this->profile == DEVICE_PROFILE_HSP_HFP && this->props.codec != 0) {
			this->props.codec = 0;
		} else {
			this->profile = DEVICE_PROFILE_OFF;
		}
	}

	emit_remove_nodes(this);
	emit_nodes(this);

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	if (this->prev_bt_connected_profiles != this->bt_dev->connected_profiles)
		this->params[IDX_EnumProfile].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Profile].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Route].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_EnumRoute].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Props].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_PropInfo].flags ^= SPA_PARAM_INFO_SERIAL;
	emit_info(this, false);
}

static void profiles_changed(void *userdata, uint32_t prev_profiles, uint32_t prev_connected_profiles)
{
	struct impl *this = userdata;
	uint32_t connected_change;
	bool nodes_changed = false;

	connected_change = (this->bt_dev->connected_profiles ^ prev_connected_profiles);

	/* Profiles changed. We have to re-emit device information. */
	spa_log_info(this->log, NAME": profiles changed to  %08x %08x (prev %08x %08x, change %08x)"
		     " switching_codec:%d",
		     this->bt_dev->profiles, this->bt_dev->connected_profiles,
		     prev_profiles, prev_connected_profiles, connected_change,
		     this->switching_codec);

	if (this->switching_codec)
		return;

	if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SINK) {
		free(this->supported_codecs);
		this->supported_codecs = spa_bt_device_get_supported_a2dp_codecs(
			this->bt_dev, &this->supported_codec_count);
	}

	switch (this->profile) {
	case DEVICE_PROFILE_OFF:
		/* Noop */
		nodes_changed = false;
		break;
	case DEVICE_PROFILE_AG:
		nodes_changed = (connected_change & (SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY |
						     SPA_BT_PROFILE_A2DP_SOURCE));
		spa_log_debug(this->log, NAME": profiles changed: AG nodes changed: %d",
			      nodes_changed);
		break;
	case DEVICE_PROFILE_A2DP:
		if (get_supported_a2dp_codec(this, this->props.codec) == NULL)
			this->props.codec = 0;
		nodes_changed = (connected_change & (SPA_BT_PROFILE_A2DP_SINK |
						     SPA_BT_PROFILE_A2DP_SOURCE));
		spa_log_debug(this->log, NAME": profiles changed: A2DP nodes changed: %d",
			      nodes_changed);
		break;
	case DEVICE_PROFILE_HSP_HFP:
		if (spa_bt_device_supports_hfp_codec(this->bt_dev, get_hfp_codec(this->props.codec)) != 1)
			this->props.codec = 0;
		nodes_changed = (connected_change & SPA_BT_PROFILE_HEADSET_HEAD_UNIT);
		spa_log_debug(this->log, NAME": profiles changed: HSP/HFP nodes changed: %d",
			      nodes_changed);
		break;
	}

	if (nodes_changed) {
		emit_remove_nodes(this);
		emit_nodes(this);
	}

	this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	this->params[IDX_Profile].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_EnumProfile].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Route].flags ^= SPA_PARAM_INFO_SERIAL;  /* Profile changes may affect routes */
	this->params[IDX_EnumRoute].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_Props].flags ^= SPA_PARAM_INFO_SERIAL;
	this->params[IDX_PropInfo].flags ^= SPA_PARAM_INFO_SERIAL;
	emit_info(this, false);
}

static void set_initial_profile(struct impl *this);

static void device_connected(void *userdata, bool connected) {
	struct impl *this = userdata;

	spa_log_debug(this->log, "connected: %d", connected);

	if (connected ^ (this->profile != DEVICE_PROFILE_OFF))
		set_initial_profile(this);
}

static const struct spa_bt_device_events bt_dev_events = {
	SPA_VERSION_BT_DEVICE_EVENTS,
	.connected = device_connected,
	.codec_switched = codec_switched,
	.profiles_changed = profiles_changed,
};

static int impl_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	if (events->info)
		emit_info(this, true);

	if (events->object_info)
		emit_nodes(this);

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

static uint32_t profile_direction_mask(struct impl *this, uint32_t index)
{
	struct spa_bt_device *device = this->bt_dev;
	uint32_t mask;
	bool have_output = false, have_input = false;

	switch (index) {
	case DEVICE_PROFILE_A2DP:
		if (device->connected_profiles & SPA_BT_PROFILE_A2DP_SINK)
			have_output = true;
		break;
	case DEVICE_PROFILE_HSP_HFP:
		if (device->connected_profiles & SPA_BT_PROFILE_HEADSET_HEAD_UNIT)
			have_output = have_input = true;
		break;
	default:
		break;
	}

	mask = 0;
	if (have_output)
		mask |= 1 << SPA_DIRECTION_OUTPUT;
	if (have_input)
		mask |= 1 << SPA_DIRECTION_INPUT;
	return mask;
}

static uint32_t get_profile_from_index(struct impl *this, uint32_t index, uint32_t *next, enum spa_bluetooth_audio_codec *codec)
{
	/*
	 * XXX: The codecs should probably become a separate param, and not have
	 * XXX: separate profiles for each one.
	 */

	*codec = 0;
	*next = index + 1;

	if (index <= 3) {
		return index;
	} else if (index != SPA_ID_INVALID) {
		const struct spa_type_info *info;

		*codec = index - 3;
		*next = SPA_ID_INVALID;

		for (info = spa_type_bluetooth_audio_codec; info->type; ++info)
			if (info->type > *codec)
				*next = SPA_MIN(info->type + 3, *next);

		return get_hfp_codec(*codec) ? DEVICE_PROFILE_HSP_HFP : DEVICE_PROFILE_A2DP;
	}

	*next = SPA_ID_INVALID;
	return SPA_ID_INVALID;
}

static uint32_t get_index_from_profile(struct impl *this, uint32_t profile, enum spa_bluetooth_audio_codec codec)
{
	if (profile == DEVICE_PROFILE_OFF || profile == DEVICE_PROFILE_AG)
		return profile;

	if (profile == DEVICE_PROFILE_A2DP) {
		if (codec == 0 || (this->bt_dev->connected_profiles & SPA_BT_PROFILE_A2DP_SOURCE))
			return profile;

		return codec + 3;
	}

	if (profile == DEVICE_PROFILE_HSP_HFP) {
		if (codec == 0 || (this->bt_dev->connected_profiles & SPA_BT_PROFILE_HFP_AG))
			return profile;

		return codec + 3;
	}

	return SPA_ID_INVALID;
}

static bool find_hsp_hfp_profile(struct impl *this) {
	struct spa_bt_transport *t;
	int i;

	for (i = SPA_BT_PROFILE_HSP_HS; i <= SPA_BT_PROFILE_HFP_AG; i <<= 1) {
		if (!(this->bt_dev->connected_profiles & i))
			continue;

		t = find_transport(this, i, 0);
		if (t) {
			this->profile = (i & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY) ?
				DEVICE_PROFILE_AG : DEVICE_PROFILE_HSP_HFP;
			this->props.codec = get_hfp_codec_id(t->codec);
			return true;
		}
	}
	return false;
}

static void set_initial_profile(struct impl *this)
{
	struct spa_bt_transport *t;
	int i;

	if (this->supported_codecs)
		free(this->supported_codecs);
	this->supported_codecs = spa_bt_device_get_supported_a2dp_codecs(
					this->bt_dev, &this->supported_codec_count);

	/* Prefer A2DP, then HFP, then null, but select AG if the device
	   appears not to have A2DP_SINK or any HEAD_UNIT profile */

	// If default profile is set to HSP/HFP, first try those and exit if found
	const char *str;
	if (this->bt_dev->settings != NULL) {
		str = spa_dict_lookup(this->bt_dev->settings, "device.profile");
		if (str != NULL && strcmp(str, "headset-head-unit") == 0 && find_hsp_hfp_profile(this))
			return;
	}

	for (i = SPA_BT_PROFILE_A2DP_SINK; i <= SPA_BT_PROFILE_A2DP_SOURCE; i <<= 1) {
		if (!(this->bt_dev->connected_profiles & i))
			continue;

		t = find_transport(this, i, 0);
		if (t) {
			this->profile = (i == SPA_BT_PROFILE_A2DP_SOURCE) ?
				DEVICE_PROFILE_AG : DEVICE_PROFILE_A2DP;
			this->props.codec = t->a2dp_codec->id;
			return;
		}
	}

	if (find_hsp_hfp_profile(this)) return;

	this->profile = DEVICE_PROFILE_OFF;
	this->props.codec = 0;
}

static struct spa_pod *build_profile(struct impl *this, struct spa_pod_builder *b,
		uint32_t id, uint32_t index, uint32_t profile_index, enum spa_bluetooth_audio_codec codec)
{
	struct spa_bt_device *device = this->bt_dev;
	struct spa_pod_frame f[2];
	const char *name, *desc;
	char *name_and_codec = NULL;
	char *desc_and_codec = NULL;
	uint32_t n_source = 0, n_sink = 0;
	uint32_t capture[1] = { DEVICE_ID_SOURCE }, playback[1] = { DEVICE_ID_SINK };

	switch (profile_index) {
	case DEVICE_PROFILE_OFF:
		name = "off";
		desc = _("Off");
		break;
	case DEVICE_PROFILE_AG:
	{
		uint32_t profile = device->connected_profiles &
		      (SPA_BT_PROFILE_A2DP_SOURCE | SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY);
		if (profile == 0) {
			return NULL;
		} else {
			name = "audio-gateway";
			desc = _("Audio Gateway (A2DP Source & HSP/HFP AG)");
		}
		break;
	}
	case DEVICE_PROFILE_A2DP:
	{
		/* make this device profile visible only if there is an A2DP sink */
		uint32_t profile = device->connected_profiles &
		      (SPA_BT_PROFILE_A2DP_SINK | SPA_BT_PROFILE_A2DP_SOURCE);
		if (!(profile & SPA_BT_PROFILE_A2DP_SINK)) {
			return NULL;
		}
		name = spa_bt_profile_name(profile);
		n_sink++;
		if (codec) {
			const struct a2dp_codec *a2dp_codec = get_supported_a2dp_codec(this, codec);
			if (a2dp_codec == NULL) {
				errno = EINVAL;
				return NULL;
			}
			name_and_codec = spa_aprintf("%s-%s", name, a2dp_codec->name);
			name = name_and_codec;
			if (profile == SPA_BT_PROFILE_A2DP_SINK) {
				desc = _("High Fidelity Playback (A2DP Sink, codec %s)");
			} else {
				desc = _("High Fidelity Duplex (A2DP Source/Sink, codec %s)");
			}
			desc_and_codec = spa_aprintf(desc, a2dp_codec->description);
			desc = desc_and_codec;
		} else {
			if (profile == SPA_BT_PROFILE_A2DP_SINK) {
				desc = _("High Fidelity Playback (A2DP Sink)");
			} else {
				desc = _("High Fidelity Duplex (A2DP Source/Sink)");
			}
		}
		break;
	}
	case DEVICE_PROFILE_HSP_HFP:
	{
		/* make this device profile visible only if there is a head unit */
		uint32_t profile = device->connected_profiles &
		      SPA_BT_PROFILE_HEADSET_HEAD_UNIT;
		if (profile == 0) {
			return NULL;
		}
		name = spa_bt_profile_name(profile);
		n_source++;
		n_sink++;
		if (codec) {
			bool codec_ok = !(profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY);
			unsigned int hfp_codec = get_hfp_codec(codec);
			if (spa_bt_device_supports_hfp_codec(this->bt_dev, hfp_codec) != 1)
				codec_ok = false;
			if (!codec_ok) {
				errno = EINVAL;
				return NULL;
			}
			name_and_codec = spa_aprintf("%s-%s", name, get_hfp_codec_name(hfp_codec));
			name = name_and_codec;
			desc_and_codec = spa_aprintf(_("Headset Head Unit (HSP/HFP, codec %s)"),
						get_hfp_codec_description(hfp_codec));
			desc = desc_and_codec;
		} else {
			desc = _("Headset Head Unit (HSP/HFP)");
		}
		break;
	}
	default:
		errno = EINVAL;
		return NULL;
	}

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamProfile, id);
	spa_pod_builder_add(b,
		SPA_PARAM_PROFILE_index,   SPA_POD_Int(index),
		SPA_PARAM_PROFILE_name, SPA_POD_String(name),
		SPA_PARAM_PROFILE_description, SPA_POD_String(desc),
		SPA_PARAM_PROFILE_available, SPA_POD_Id(SPA_PARAM_AVAILABILITY_yes),
		0);
	if (n_source > 0 || n_sink > 0) {
		spa_pod_builder_prop(b, SPA_PARAM_PROFILE_classes, 0);
		spa_pod_builder_push_struct(b, &f[1]);
		if (n_source > 0) {
			spa_pod_builder_add_struct(b,
				SPA_POD_String("Audio/Source"),
				SPA_POD_Int(n_source),
				SPA_POD_String("card.profile.devices"),
				SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Int, 1, capture));
		}
		if (n_sink > 0) {
			spa_pod_builder_add_struct(b,
				SPA_POD_String("Audio/Sink"),
				SPA_POD_Int(n_sink),
				SPA_POD_String("card.profile.devices"),
				SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Int, 1, playback));
		}
		spa_pod_builder_pop(b, &f[1]);
	}

	if (name_and_codec)
		free(name_and_codec);
	if (desc_and_codec)
		free(desc_and_codec);

	return spa_pod_builder_pop(b, &f[0]);
}

static struct spa_pod *build_route(struct impl *this, struct spa_pod_builder *b,
		uint32_t id, uint32_t port, uint32_t dev, uint32_t profile)
{
	struct spa_bt_device *device = this->bt_dev;
	struct spa_pod_frame f[2];
	enum spa_direction direction;
	const char *name_prefix, *description, *port_type;
	enum spa_bt_form_factor ff;
	enum spa_bluetooth_audio_codec codec;
	char name[128];
	uint32_t i, j, mask, next;

	ff = spa_bt_form_factor_from_class(device->bluetooth_class);

	switch (ff) {
	case SPA_BT_FORM_FACTOR_HEADSET:
		name_prefix = "headset";
		description = _("Headset");
		port_type = "headset";
		break;
	case SPA_BT_FORM_FACTOR_HANDSFREE:
		name_prefix = "handsfree";
		description = _("Handsfree");
		port_type = "handsfree";
		break;
	case SPA_BT_FORM_FACTOR_MICROPHONE:
		name_prefix = "microphone";
		description = _("Microphone");
		port_type = "mic";
		break;
	case SPA_BT_FORM_FACTOR_SPEAKER:
		name_prefix = "speaker";
		description = _("Speaker");
		port_type = "speaker";
		break;
	case SPA_BT_FORM_FACTOR_HEADPHONE:
		name_prefix = "headphone";
		description = _("Headphone");
		port_type = "headphones";
		break;
	case SPA_BT_FORM_FACTOR_PORTABLE:
		name_prefix = "portable";
		description = _("Portable");
		port_type = "portable";
		break;
	case SPA_BT_FORM_FACTOR_CAR:
		name_prefix = "car";
		description = _("Car");
		port_type = "car";
		break;
	case SPA_BT_FORM_FACTOR_HIFI:
		name_prefix = "hifi";
		description = _("HiFi");
		port_type = "hifi";
		break;
	case SPA_BT_FORM_FACTOR_PHONE:
		name_prefix = "phone";
		description = _("Phone");
		port_type = "phone";
		break;
	case SPA_BT_FORM_FACTOR_UNKNOWN:
	default:
		name_prefix = "bluetooth";
		description = _("Bluetooth");
		port_type = "bluetooth";
		break;
	}

	switch (port) {
	case 0:
		direction = SPA_DIRECTION_INPUT;
		snprintf(name, sizeof(name), "%s-input", name_prefix);
		break;
	case 1:
		direction = SPA_DIRECTION_OUTPUT;
		snprintf(name, sizeof(name), "%s-output", name_prefix);
		break;
	default:
		errno = EINVAL;
		return NULL;
	}

	if (dev != SPA_ID_INVALID && !(profile_direction_mask(this, this->profile) & (1 << direction)))
		return NULL;

	mask = 0;
	for (i = 1; i < 4; i++)
		mask |= profile_direction_mask(this, i);
	if ((mask & (1 << direction)) == 0)
		return NULL;

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamRoute, id);
	spa_pod_builder_add(b,
		SPA_PARAM_ROUTE_index, SPA_POD_Int(port),
		SPA_PARAM_ROUTE_direction,  SPA_POD_Id(direction),
		SPA_PARAM_ROUTE_name,  SPA_POD_String(name),
		SPA_PARAM_ROUTE_description,  SPA_POD_String(description),
		SPA_PARAM_ROUTE_priority,  SPA_POD_Int(0),
		SPA_PARAM_ROUTE_available,  SPA_POD_Id(SPA_PARAM_AVAILABILITY_yes),
		0);
	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_info, 0);
	spa_pod_builder_push_struct(b, &f[1]);
	spa_pod_builder_int(b, 1);
	spa_pod_builder_add(b,
			SPA_POD_String("port.type"),
			SPA_POD_String(port_type),
			NULL);
	spa_pod_builder_pop(b, &f[1]);
	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_profiles, 0);
	spa_pod_builder_push_array(b, &f[1]);
	for (i = 1; (j = get_profile_from_index(this, i, &next, &codec)) != SPA_ID_INVALID; i = next) {
		struct spa_pod_builder b2 = { 0 };
		uint8_t buffer[1024];
		struct spa_pod *param;

		if (!(profile_direction_mask(this, j) & (1 << direction)))
			continue;

		/* Check the profile actually exists */
		spa_pod_builder_init(&b2, buffer, sizeof(buffer));
		param = build_profile(this, &b2, 0, i, j, codec);
		if (param == NULL)
			continue;

		spa_pod_builder_int(b, i);
	}
	spa_pod_builder_pop(b, &f[1]);

	if (dev != SPA_ID_INVALID) {
		struct node *node = &this->nodes[dev];
		struct spa_bt_transport_volume *t_volume;

		t_volume = node->transport
			? &node->transport->volumes[node->id]
			: NULL;

		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_device, 0);
		spa_pod_builder_int(b, dev);

		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_props, 0);
		spa_pod_builder_push_object(b, &f[1], SPA_TYPE_OBJECT_Props, id);

		spa_pod_builder_prop(b, SPA_PROP_mute, 0);
		spa_pod_builder_bool(b, node->mute);

		spa_pod_builder_prop(b, SPA_PROP_channelVolumes,
			(t_volume && t_volume->active) ? SPA_POD_PROP_FLAG_HARDWARE : 0);
		spa_pod_builder_array(b, sizeof(float), SPA_TYPE_Float,
				node->n_channels, node->volumes);

		if (t_volume && t_volume->active) {
			spa_pod_builder_prop(b, SPA_PROP_volumeStep, SPA_POD_PROP_FLAG_READONLY);
			spa_pod_builder_float(b, 1.0f / (t_volume->hw_volume_max + 1));
		}

		spa_pod_builder_prop(b, SPA_PROP_channelMap, 0);
		spa_pod_builder_array(b, sizeof(uint32_t), SPA_TYPE_Id,
				node->n_channels, node->channels);

		if (this->profile == DEVICE_PROFILE_A2DP && dev == DEVICE_ID_SINK) {
			spa_pod_builder_prop(b, SPA_PROP_latencyOffsetNsec, 0);
			spa_pod_builder_long(b, node->latency_offset);
		}

		spa_pod_builder_pop(b, &f[1]);

		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_save, 0);
		spa_pod_builder_bool(b, node->save);
	}

	spa_pod_builder_prop(b, SPA_PARAM_ROUTE_devices, 0);
	spa_pod_builder_push_array(b, &f[1]);
	/* port and device indexes are the same, 0=source, 1=sink */
	spa_pod_builder_int(b, port);
	spa_pod_builder_pop(b, &f[1]);

	if (profile != SPA_ID_INVALID) {
		spa_pod_builder_prop(b, SPA_PARAM_ROUTE_profile, 0);
		spa_pod_builder_int(b, profile);
	}
	return spa_pod_builder_pop(b, &f[0]);
}

static struct spa_pod *build_prop_info(struct impl *this, struct spa_pod_builder *b, uint32_t id)
{
	struct spa_pod_frame f[2];
	struct spa_pod_choice *choice;
	const struct a2dp_codec *codec;
	size_t n, j;

#define FOR_EACH_A2DP_CODEC(j, codec) \
		for (j = 0; (j < this->supported_codec_count) ? (codec = this->supported_codecs[j]) : NULL; ++j)
#define FOR_EACH_HFP_CODEC(j) \
		for (j = HFP_AUDIO_CODEC_MSBC; j >= HFP_AUDIO_CODEC_CVSD; --j) \
			if (spa_bt_device_supports_hfp_codec(this->bt_dev, j) == 1)

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_PropInfo, id);

	/*
	 * XXX: the ids in principle should use builder_id, not builder_int,
	 * XXX: but the type info for _type and _labels doesn't work quite right now.
	 */

	/* Transport codec */
	spa_pod_builder_prop(b, SPA_PROP_INFO_id, 0);
	spa_pod_builder_id(b, SPA_PROP_bluetoothAudioCodec);
	spa_pod_builder_prop(b, SPA_PROP_INFO_name, 0);
	spa_pod_builder_string(b, "Air codec");
	spa_pod_builder_prop(b, SPA_PROP_INFO_type, 0);
	spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_Enum, 0);
	choice = (struct spa_pod_choice *)spa_pod_builder_frame(b, &f[1]);
	n = 0;
	if (this->profile == DEVICE_PROFILE_A2DP) {
		FOR_EACH_A2DP_CODEC(j, codec) {
			if (n == 0)
				spa_pod_builder_int(b, codec->id);
			spa_pod_builder_int(b, codec->id);
			++n;
		}
	} else if (this->profile == DEVICE_PROFILE_HSP_HFP) {
		FOR_EACH_HFP_CODEC(j) {
			if (n == 0)
				spa_pod_builder_int(b, get_hfp_codec_id(j));
			spa_pod_builder_int(b, get_hfp_codec_id(j));
			++n;
		}
	}
	if (n == 0)
		choice->body.type = SPA_CHOICE_None;
	spa_pod_builder_pop(b, &f[1]);
	spa_pod_builder_prop(b, SPA_PROP_INFO_labels, 0);
	spa_pod_builder_push_struct(b, &f[1]);
	if (this->profile == DEVICE_PROFILE_A2DP) {
		FOR_EACH_A2DP_CODEC(j, codec) {
			spa_pod_builder_int(b, codec->id);
			spa_pod_builder_string(b, codec->description);
		}
	} else if (this->profile == DEVICE_PROFILE_HSP_HFP) {
		FOR_EACH_HFP_CODEC(j) {
			spa_pod_builder_int(b, get_hfp_codec_id(j));
			spa_pod_builder_string(b, get_hfp_codec_description(j));
		}
	}
	spa_pod_builder_pop(b, &f[1]);
	return spa_pod_builder_pop(b, &f[0]);

#undef FOR_EACH_A2DP_CODEC
#undef FOR_EACH_HFP_CODEC
}

static struct spa_pod *build_props(struct impl *this, struct spa_pod_builder *b, uint32_t id)
{
	struct props *p = &this->props;

	return spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_Props, id,
			SPA_PROP_bluetoothAudioCodec, SPA_POD_Id(p->codec));
}

static int impl_enum_params(void *object, int seq,
			    uint32_t id, uint32_t start, uint32_t num,
			    const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[2048];
	struct spa_result_device_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumProfile:
	{
		uint32_t profile;
		enum spa_bluetooth_audio_codec codec;

		profile = get_profile_from_index(this, result.index, &result.next, &codec);

		switch (profile) {
		case DEVICE_PROFILE_OFF:
		case DEVICE_PROFILE_AG:
		case DEVICE_PROFILE_A2DP:
		case DEVICE_PROFILE_HSP_HFP:
			param = build_profile(this, &b, id, result.index, profile, codec);
			if (param == NULL)
				goto next;
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Profile:
	{
		uint32_t index;

		switch (result.index) {
		case 0:
			index = get_index_from_profile(this, this->profile, this->props.codec);
			param = build_profile(this, &b, id, index, this->profile, this->props.codec);
			if (param == NULL)
				return 0;
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_EnumRoute:
	{
		switch (result.index) {
		case 0: case 1:
			param = build_route(this, &b, id, result.index,
					SPA_ID_INVALID, SPA_ID_INVALID);
			if (param == NULL)
				goto next;
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Route:
	{
		switch (result.index) {
		case 0: case 1:
			param = build_route(this, &b, id, result.index,
					result.index, this->profile);
			if (param == NULL)
				goto next;
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_PropInfo:
	{
		switch (result.index) {
		case 0:
			param = build_prop_info(this, &b, id);
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Props:
	{
		switch (result.index) {
		case 0:
			param = build_props(this, &b, id);
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

	spa_device_emit_result(&this->hooks, seq, 0,
			SPA_RESULT_TYPE_DEVICE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int node_set_volume(struct impl *this, struct node *node, float volumes[], uint32_t n_volumes)
{
	uint32_t i;
	int changed = 0;
	struct spa_bt_transport_volume *t_volume;

	if (n_volumes == 0)
		return -EINVAL;

	spa_log_debug(this->log, "node %p volume %f", node, volumes[0]);

	for (i = 0; i < node->n_channels; i++) {
		if (node->volumes[i] == volumes[i % n_volumes])
			continue;
		++changed;
		node->volumes[i] = volumes[i % n_volumes];
	}

	t_volume = node->transport ? &node->transport->volumes[node->id]: NULL;

	if (t_volume && t_volume->active
	    && spa_bt_transport_volume_enabled(node->transport)) {
		float hw_volume = node_get_hw_volume(node);
		spa_log_debug(this->log, "node %p hardware volume %f", node, hw_volume);

		node_update_soft_volumes(node, hw_volume);
		spa_bt_transport_set_volume(node->transport, node->id, hw_volume);
	} else {
		for (uint32_t i = 0; i < node->n_channels; ++i)
			node->soft_volumes[i] = node->volumes[i];
	}

	return changed;
}

static int node_set_mute(struct impl *this, struct node *node, bool mute)
{
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];
	int changed = 0;

	spa_log_info(this->log, "node %p mute %d", node, mute);

	changed = (node->mute != mute);
	node->mute = mute;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, node->id);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);

	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_mute, SPA_POD_Bool(mute),
			SPA_PROP_softMute, SPA_POD_Bool(mute));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_device_emit_event(&this->hooks, event);

	return changed;
}

static int node_set_latency_offset(struct impl *this, struct node *node, int64_t latency_offset)
{
	struct spa_event *event;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[1];
	int changed = 0;

	spa_log_info(this->log, "node %p latency offset %"PRIi64" nsec", node, latency_offset);

	changed = (node->latency_offset != latency_offset);
	node->latency_offset = latency_offset;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_EVENT_Device, SPA_DEVICE_EVENT_ObjectConfig);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Object, 0);
	spa_pod_builder_int(&b, node->id);
	spa_pod_builder_prop(&b, SPA_EVENT_DEVICE_Props, 0);

	spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Props, SPA_EVENT_DEVICE_Props,
			SPA_PROP_latencyOffsetNsec, SPA_POD_Long(latency_offset));
	event = spa_pod_builder_pop(&b, &f[0]);

	spa_device_emit_event(&this->hooks, event);

	return changed;
}

static int apply_device_props(struct impl *this, struct node *node, struct spa_pod *props)
{
	float volume = 0;
	bool mute = 0;
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) props;
	int changed = 0;
	float volumes[SPA_AUDIO_MAX_CHANNELS];
	uint32_t channels[SPA_AUDIO_MAX_CHANNELS];
	uint32_t n_volumes = 0, SPA_UNUSED n_channels = 0;
	int64_t latency_offset = 0;

	if (!spa_pod_is_object_type(props, SPA_TYPE_OBJECT_Props))
		return -EINVAL;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &volume) == 0) {
				int res = node_set_volume(this, node, &volume, 1);
				if (res > 0)
					++changed;
			}
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &mute) == 0) {
				int res = node_set_mute(this, node, mute);
				if (res > 0)
					++changed;
			}
			break;
		case SPA_PROP_channelVolumes:
			n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					volumes, SPA_AUDIO_MAX_CHANNELS);
			break;
		case SPA_PROP_channelMap:
			n_channels = spa_pod_copy_array(&prop->value, SPA_TYPE_Id,
					channels, SPA_AUDIO_MAX_CHANNELS);
			break;
		case SPA_PROP_latencyOffsetNsec:
			if (spa_pod_get_long(&prop->value, &latency_offset) == 0) {
				int res = node_set_latency_offset(this, node, latency_offset);
				if (res > 0)
					++changed;
			}
		}
	}
	if (n_volumes > 0) {
		int res = node_set_volume(this, node, volumes, n_volumes);
		if (res > 0)
			++changed;
	}

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
		uint32_t id, next;
		uint32_t profile;
		enum spa_bluetooth_audio_codec codec;

		if (param == NULL)
			return -EINVAL;

		if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&id))) < 0) {
			spa_log_warn(this->log, "can't parse profile");
			spa_debug_pod(0, NULL, param);
			return res;
		}

		profile = get_profile_from_index(this, id, &next, &codec);
		if (profile == SPA_ID_INVALID)
			return -EINVAL;

		spa_log_debug(this->log, NAME": setting profile %d codec:%d", profile, codec);
		set_profile(this, profile, codec);
		break;
	}
	case SPA_PARAM_Route:
	{
		uint32_t id, device;
		struct spa_pod *props = NULL;
		struct node *node;
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
		if (device > 1 || !this->nodes[device].active)
			return -EINVAL;

		node = &this->nodes[device];
		node->save = save;
		if (props) {
			int changed = apply_device_props(this, node, props);
			if (changed > 0) {
				this->info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
				this->params[IDX_Route].flags ^= SPA_PARAM_INFO_SERIAL;
			}
			emit_info(this, false);
			/* See volume_changed(void *) */
			emit_volume(this, node);
		}
		break;
	}
	case SPA_PARAM_Props:
	{
		uint32_t codec_id = SPA_ID_INVALID;

		if (param == NULL)
			return 0;

		if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_Props, NULL,
				SPA_PROP_bluetoothAudioCodec, SPA_POD_OPT_Id(&codec_id))) < 0) {
			spa_log_warn(this->log, "can't parse props");
			spa_debug_pod(0, NULL, param);
			return res;
		}

		if (codec_id == SPA_ID_INVALID)
			return 0;

		if (this->profile == DEVICE_PROFILE_A2DP) {
			size_t j;
			for (j = 0; j < this->supported_codec_count; ++j) {
				if (this->supported_codecs[j]->id == codec_id) {
					set_profile(this, this->profile, codec_id);
					return 0;
				}
			}
		} else if (this->profile == DEVICE_PROFILE_HSP_HFP) {
			if (codec_id == SPA_BLUETOOTH_AUDIO_CODEC_CVSD &&
					spa_bt_device_supports_hfp_codec(this->bt_dev, HFP_AUDIO_CODEC_CVSD) == 1) {
				set_profile(this, this->profile, codec_id);
				return 0;
			} else if (codec_id == SPA_BLUETOOTH_AUDIO_CODEC_MSBC &&
					spa_bt_device_supports_hfp_codec(this->bt_dev, HFP_AUDIO_CODEC_MSBC) == 1) {
				set_profile(this, this->profile, codec_id);
				return 0;
			}
		}
		return -EINVAL;
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

static int impl_clear(struct spa_handle *handle)
{
	struct impl *this = (struct impl *) handle;
	const struct spa_dict_item *it;

	emit_remove_nodes(this);

	free(this->supported_codecs);
	if (this->bt_dev) {
		this->bt_dev->settings = NULL;
		spa_hook_remove(&this->bt_dev_listener);
	}

	spa_dict_for_each(it, &this->setting_dict) {
		if(it->key)
			free((void *)it->key);
		if(it->value)
			free((void *)it->value);
	}

	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

static const struct spa_dict*
filter_bluez_device_setting(struct impl *this, const struct spa_dict *dict)
{
	uint32_t n_items = 0;
	for (uint32_t i = 0
		; i < dict->n_items && n_items < SPA_N_ELEMENTS(this->setting_items)
		; i++)
	{
		const struct spa_dict_item *it = &dict->items[i];
		if (it->key != NULL && strncmp(it->key, "bluez", 5) == 0 && it->value != NULL) {
			this->setting_items[n_items++] =
				SPA_DICT_ITEM_INIT(strdup(it->key), strdup(it->value));
		}
	}
	this->setting_dict = SPA_DICT_INIT(this->setting_items, n_items);
	return &this->setting_dict;
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

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	_i18n = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_I18N);

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_BLUEZ5_DEVICE)))
		sscanf(str, "pointer:%p", &this->bt_dev);

	if (this->bt_dev == NULL) {
		spa_log_error(this->log, "a device is needed");
		return -EINVAL;
	}

	if (info) {
		int profiles;
		this->bt_dev->settings = filter_bluez_device_setting(this, info);

		if ((str = spa_dict_lookup(info, "bluez5.auto-connect")) != NULL) {
			if ((profiles = spa_bt_profiles_from_json_array(str)) >= 0)
				this->bt_dev->reconnect_profiles = profiles;
		}

		if ((str = spa_dict_lookup(info, "bluez5.hw-volume")) != NULL) {
			if ((profiles = spa_bt_profiles_from_json_array(str)) >= 0)
				this->bt_dev->hw_volume_profiles = profiles;
		}
	}

	this->device.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Device,
			SPA_VERSION_DEVICE,
			&impl_device, this);

	spa_hook_list_init(&this->hooks);

	reset_props(&this->props);

	init_node(this, &this->nodes[0], 0);
	init_node(this, &this->nodes[1], 1);

	this->info = SPA_DEVICE_INFO_INIT();
	this->info_all = SPA_DEVICE_CHANGE_MASK_PROPS |
		SPA_DEVICE_CHANGE_MASK_PARAMS;

	this->params[IDX_EnumProfile] = SPA_PARAM_INFO(SPA_PARAM_EnumProfile, SPA_PARAM_INFO_READ);
	this->params[IDX_Profile] = SPA_PARAM_INFO(SPA_PARAM_Profile, SPA_PARAM_INFO_READWRITE);
	this->params[IDX_EnumRoute] = SPA_PARAM_INFO(SPA_PARAM_EnumRoute, SPA_PARAM_INFO_READ);
	this->params[IDX_Route] = SPA_PARAM_INFO(SPA_PARAM_Route, SPA_PARAM_INFO_READWRITE);
	this->params[IDX_PropInfo] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[IDX_Props] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 6;

	spa_bt_device_add_listener(this->bt_dev, &this->bt_dev_listener, &bt_dev_events, this);

	set_initial_profile(this);

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

static const struct spa_dict_item handle_info_items[] = {
	{ SPA_KEY_FACTORY_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "A bluetooth device" },
	{ SPA_KEY_FACTORY_USAGE, SPA_KEY_API_BLUEZ5_DEVICE"=<device>" },
};

static const struct spa_dict handle_info = SPA_DICT_INIT_ARRAY(handle_info_items);

const struct spa_handle_factory spa_bluez5_device_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_BLUEZ5_DEVICE,
	&handle_info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
