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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>

#include "config.h"

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/pod.h>
#include <spa/utils/json.h>

#include "pipewire/pipewire.h"
#include "extensions/metadata.h"

#include "media-session.h"

#define NAME		"policy-node"
#define SESSION_KEY	"policy-node"

#define DEFAULT_IDLE_SECONDS	3

#define DEFAULT_AUDIO_SINK_KEY		"default.audio.sink"
#define DEFAULT_AUDIO_SOURCE_KEY	"default.audio.source"
#define DEFAULT_VIDEO_SOURCE_KEY	"default.video.source"
#define DEFAULT_CONFIG_AUDIO_SINK_KEY	"default.configured.audio.sink"
#define DEFAULT_CONFIG_AUDIO_SOURCE_KEY	"default.configured.audio.source"
#define DEFAULT_CONFIG_VIDEO_SOURCE_KEY	"default.configured.video.source"

#define DEFAULT_AUDIO_SINK		0
#define DEFAULT_AUDIO_SOURCE		1
#define DEFAULT_VIDEO_SOURCE		2

#define MAX_LINK_RETRY			5

struct default_node {
	char *key;
	char *key_config;
	char *value;
	char *config;
};

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct spa_hook meta_listener;

	struct pw_context *context;

	uint32_t sample_rate;

	struct spa_list node_list;
	unsigned int node_list_changed:1;
	unsigned int linking_node_removed:1;
	int seq;

	struct default_node defaults[4];

	bool streams_follow_default;
};

struct node {
	struct sm_node *obj;

	uint32_t id;
	struct impl *impl;

	struct spa_list link;		/**< link in impl node_list */
	enum pw_direction direction;

	struct spa_hook listener;

	struct node *peer;
	struct node *failed_peer;

	uint32_t client_id;
	int32_t priority;

#define NODE_TYPE_UNKNOWN	0
#define NODE_TYPE_STREAM	1
#define NODE_TYPE_DEVICE	2
	uint32_t type;
	char *media;

	struct spa_audio_info format;

	int connect_count;
	int failed_count;
	uint64_t plugged;
	unsigned int active:1;
	unsigned int exclusive:1;
	unsigned int enabled:1;
	unsigned int configured:1;
	unsigned int dont_remix:1;
	unsigned int monitor:1;
	unsigned int moving:1;
	unsigned int capture_sink:1;
	unsigned int virtual:1;
	unsigned int linking:1;
};

static int check_new_target(struct impl *impl, struct node *target);

static bool find_format(struct node *node)
{
	struct impl *impl = node->impl;
	struct sm_param *p;
	bool have_format = false;

	spa_list_for_each(p, &node->obj->param_list, link) {
		struct spa_audio_info info = { 0, };
		struct spa_pod *position = NULL;
		uint32_t n_position = 0;

		if (p->id != SPA_PARAM_EnumFormat)
			continue;

		if (spa_format_parse(p->param, &info.media_type, &info.media_subtype) < 0)
			continue;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			continue;

		spa_pod_object_fixate((struct spa_pod_object*)p->param);
		if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
			spa_debug_pod(2, NULL, p->param);

		/* defaults */
		info.info.raw.format = SPA_AUDIO_FORMAT_F32;
		info.info.raw.rate = impl->sample_rate;
		info.info.raw.channels = 2;
		info.info.raw.position[0] = SPA_AUDIO_CHANNEL_FL;
		info.info.raw.position[1] = SPA_AUDIO_CHANNEL_FR;

		spa_pod_parse_object(p->param,
			SPA_TYPE_OBJECT_Format, NULL,
			SPA_FORMAT_AUDIO_format,	SPA_POD_Id(&info.info.raw.format),
			SPA_FORMAT_AUDIO_rate,		SPA_POD_OPT_Int(&info.info.raw.rate),
			SPA_FORMAT_AUDIO_channels,	SPA_POD_Int(&info.info.raw.channels),
			SPA_FORMAT_AUDIO_position,	SPA_POD_OPT_Pod(&position));

		if (position != NULL)
			n_position = spa_pod_copy_array(position, SPA_TYPE_Id,
					info.info.raw.position, SPA_AUDIO_MAX_CHANNELS);
		if (n_position == 0 || n_position != info.info.raw.channels)
			SPA_FLAG_SET(info.info.raw.flags, SPA_AUDIO_FLAG_UNPOSITIONED);

		if (node->format.info.raw.channels < info.info.raw.channels)
			node->format = info;

		have_format = true;
	}
	return have_format;
}

static int configure_node(struct node *node, struct spa_audio_info *info, bool force)
{
	struct impl *impl = node->impl;
	char buf[1024];
	struct spa_pod_builder b = { 0, };
	struct spa_pod *param;
	struct spa_audio_info format;
	enum pw_direction direction;

	if (node->configured && !force)
		return 0;

	if (strcmp(node->media, "Audio") != 0)
		return 0;

	format = node->format;

	if (info != NULL && info->info.raw.channels > 0) {
		pw_log_info("node %d monitor:%d channelmix %d->%d",
			node->id, node->monitor, format.info.raw.channels,
			info->info.raw.channels);
		format = *info;
	}
	format.info.raw.rate = impl->sample_rate;

	if (node->virtual)
		direction = pw_direction_reverse(node->direction);
	else
		direction = node->direction;

	spa_pod_builder_init(&b, buf, sizeof(buf));
	param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &format.info.raw);
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(direction),
		SPA_PARAM_PORT_CONFIG_mode,	 SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_monitor,   SPA_POD_Bool(true),
		SPA_PARAM_PORT_CONFIG_format,    SPA_POD_Pod(param));

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_pod(2, NULL, param);

	pw_node_set_param((struct pw_node*)node->obj->obj.proxy,
			SPA_PARAM_PortConfig, 0, param);

	node->configured = true;

	if (node->type == NODE_TYPE_DEVICE)
		check_new_target(impl, node);

	return 0;
}

static void object_update(void *data)
{
	struct node *node = data;
	struct impl *impl = node->impl;

	pw_log_debug(NAME" %p: node %p %08x", impl, node, node->obj->obj.changed);

	if (node->obj->obj.avail & SM_NODE_CHANGE_MASK_PARAMS &&
	    !node->active) {
		if (!find_format(node)) {
			pw_log_debug(NAME" %p: can't find format %p", impl, node);
			return;
		}
		node->active = true;
		sm_media_session_schedule_rescan(impl->session);
	}
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static int
handle_node(struct impl *impl, struct sm_object *object)
{
	const char *str, *media_class = NULL, *role;
	enum pw_direction direction;
	struct node *node;
	uint32_t client_id = SPA_ID_INVALID;

	if (object->props) {
		if ((str = pw_properties_get(object->props, PW_KEY_CLIENT_ID)) != NULL)
			client_id = atoi(str);

		media_class = pw_properties_get(object->props, PW_KEY_MEDIA_CLASS);
		role = pw_properties_get(object->props, PW_KEY_MEDIA_ROLE);
	}

	pw_log_debug(NAME" %p: node "PW_KEY_MEDIA_CLASS" %s", impl, media_class);

	if (media_class == NULL)
		return 0;

	node = sm_object_add_data(object, SESSION_KEY, sizeof(struct node));
	node->obj = (struct sm_node*)object;
	node->id = object->id;
	node->impl = impl;
	node->client_id = client_id;
	node->type = NODE_TYPE_UNKNOWN;
	spa_list_append(&impl->node_list, &node->link);
	impl->node_list_changed = true;

	if (role && !strcmp(role, "DSP"))
		node->active = node->configured = true;

	if (strstr(media_class, "Stream/") == media_class) {
		media_class += strlen("Stream/");

		if (strstr(media_class, "Output/") == media_class) {
			direction = PW_DIRECTION_OUTPUT;
			media_class += strlen("Output/");
		}
		else if (strstr(media_class, "Input/") == media_class) {
			direction = PW_DIRECTION_INPUT;
			media_class += strlen("Input/");
		}
		else
			return 0;

		if (strstr(media_class, "Video") == media_class) {
			if (direction == PW_DIRECTION_OUTPUT) {
				if ((str = pw_properties_get(object->props, PW_KEY_NODE_PLUGGED)) != NULL)
					node->plugged = pw_properties_parse_uint64(str);
				else
					node->plugged = SPA_TIMESPEC_TO_NSEC(&impl->now);
			}
			node->active = node->configured = true;
		}
		else if (strstr(media_class, "Unknown") == media_class) {
			node->active = node->configured = true;
		}

		node->direction = direction;
		node->type = NODE_TYPE_STREAM;
		node->media = strdup(media_class);
		pw_log_debug(NAME" %p: node %d is stream %s", impl, object->id, node->media);
	}
	else {
		const char *media;
		bool virtual = false;

		if (strstr(media_class, "Audio/") == media_class) {
			media_class += strlen("Audio/");
			media = "Audio";
		}
		else if (strstr(media_class, "Video/") == media_class) {
			media_class += strlen("Video/");
			media = "Video";
			node->active = node->configured = true;
		}
		else
			return 0;

		if (strcmp(media_class, "Sink") == 0 ||
		    strcmp(media_class, "Duplex") == 0)
			direction = PW_DIRECTION_INPUT;
		else if (strcmp(media_class, "Source") == 0)
			direction = PW_DIRECTION_OUTPUT;
		else if (strcmp(media_class, "Source/Virtual") == 0) {
			virtual = true;
			direction = PW_DIRECTION_OUTPUT;
		} else
			return 0;

		if ((str = pw_properties_get(object->props, PW_KEY_NODE_PLUGGED)) != NULL)
			node->plugged = pw_properties_parse_uint64(str);
		else
			node->plugged = SPA_TIMESPEC_TO_NSEC(&impl->now);

		if ((str = pw_properties_get(object->props, PW_KEY_PRIORITY_SESSION)) != NULL)
			node->priority = pw_properties_parse_int(str);
		else
			node->priority = 0;

		node->direction = direction;
		node->virtual = virtual;
		node->type = NODE_TYPE_DEVICE;
		node->media = strdup(media);

		pw_log_debug(NAME" %p: node %d '%s' prio:%d", impl,
				object->id, node->media, node->priority);
	}

	node->enabled = true;
	node->obj->obj.mask |= SM_NODE_CHANGE_MASK_PARAMS;
	sm_object_add_listener(&node->obj->obj, &node->listener, &object_events, node);

	return 1;
}

static void destroy_node(struct impl *impl, struct node *node)
{
	spa_list_remove(&node->link);
	if (node->linking)
		impl->linking_node_removed = true;
	impl->node_list_changed = true;
	if (node->enabled)
		spa_hook_remove(&node->listener);
	free(node->media);
	if (node->peer && node->peer->peer == node)
		node->peer->peer = NULL;
	sm_object_remove_data((struct sm_object*)node->obj, SESSION_KEY);
}

static inline int strzcmp(const char *s1, const char *s2)
{
	if (s1 == s2)
		return 0;
	if (s1 == NULL || s2 == NULL)
		return 1;
	return strcmp(s1, s2);
}

static int json_object_find(const char *obj, const char *key, char *value, size_t len)
{
	struct spa_json it[2];
	const char *v;
	char k[128];

	spa_json_init(&it[0], obj, strlen(obj));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], k, sizeof(k)-1) > 0) {
		if (strcmp(k, key) == 0) {
			if (spa_json_get_string(&it[1], value, len) <= 0)
				continue;
			return 0;
		} else {
			if (spa_json_next(&it[1], &v) <= 0)
				break;
		}
	}
	return -ENOENT;
}

static bool check_node_name(struct node *node, const char *name)
{
	const char *str;
	if ((str = pw_properties_get(node->obj->obj.props, PW_KEY_NODE_NAME)) != NULL &&
	    name != NULL && strcmp(str, name) == 0)
		return true;
	return false;
}

static struct node *find_node_by_id_name(struct impl *impl, uint32_t id, const char *name)
{
	struct node *node;
	uint32_t name_id = name ? (uint32_t)atoi(name) : SPA_ID_INVALID;

	spa_list_for_each(node, &impl->node_list, link) {
		if (node->id == id || node->id == name_id)
			return node;
		if (check_node_name(node, name))
			return node;
	}
	return NULL;
}

static const char *get_device_name(struct node *node)
{
	if (node->type != NODE_TYPE_DEVICE ||
	    node->obj->obj.props == NULL)
		return NULL;
	return pw_properties_get(node->obj->obj.props, PW_KEY_NODE_NAME);
}

static uint32_t find_device_for_name(struct impl *impl, const char *name)
{
	struct node *node;
	const char *str;
	uint32_t id = atoi(name);

	spa_list_for_each(node, &impl->node_list, link) {
		if (id == node->obj->obj.id)
			return id;
		if ((str = get_device_name(node)) == NULL)
			continue;
		if (strcmp(str, name) == 0)
			return node->obj->obj.id;
	}
	return SPA_ID_INVALID;
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	clock_gettime(CLOCK_MONOTONIC, &impl->now);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0)
		res = handle_node(impl, object);
	else
		res = 0;

	if (res < 0) {
		pw_log_warn(NAME" %p: can't handle global %d", impl, object->id);
	} else
		sm_media_session_schedule_rescan(impl->session);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: remove global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0) {
		struct node *n, *node;

		if ((node = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_node(impl, node);

		spa_list_for_each(n, &impl->node_list, link) {
			if (n->peer == node)
				n->peer = NULL;
			if (n->failed_peer == node)
				n->failed_peer = NULL;
		}
	}
	sm_media_session_schedule_rescan(impl->session);
}

struct find_data {
	struct impl *impl;
	struct node *node;

	const char *media;
	bool capture_sink;
	enum pw_direction direction;

	bool exclusive;
	int priority;
	uint64_t plugged;
};

static int find_node(void *data, struct node *node)
{
	struct find_data *find = data;
	struct impl *impl = find->impl;
	int priority = 0;
	uint64_t plugged = 0;
	struct sm_device *device = node->obj->device;
	bool is_default = false;

	if (node->obj->info == NULL) {
		pw_log_debug(NAME " %p: skipping node '%d' with no node info", impl, node->id);
		return 0;
	}

	pw_log_debug(NAME " %p: looking at node '%d' enabled:%d state:%d peer:%p exclusive:%d",
			impl, node->id, node->enabled, node->obj->info->state, node->peer, node->exclusive);

	if (!node->enabled || node->type == NODE_TYPE_UNKNOWN)
		return 0;

	if (device && device->locked) {
		pw_log_debug(".. device locked");
		return 0;
	}

	if (node->media && strcmp(node->media, find->media) != 0) {
		pw_log_debug(".. incompatible media %s <-> %s", node->media, find->media);
		return 0;
	}
	plugged = node->plugged;
	priority = node->priority;

	if (node->media) {
		if (strcmp(node->media, "Audio") == 0) {
			if (node->direction == PW_DIRECTION_INPUT) {
				if (find->direction == PW_DIRECTION_OUTPUT)
					is_default |= check_node_name(node,
						impl->defaults[DEFAULT_AUDIO_SINK].config);
				else if (find->direction == PW_DIRECTION_INPUT)
					is_default |= check_node_name(node,
						impl->defaults[DEFAULT_AUDIO_SOURCE].config);
			} else if (node->direction == PW_DIRECTION_OUTPUT &&
			    find->direction == PW_DIRECTION_INPUT)
				is_default |= check_node_name(node,
						impl->defaults[DEFAULT_AUDIO_SOURCE].config);
		} else if (strcmp(node->media, "Video") == 0) {
			if (node->direction == PW_DIRECTION_OUTPUT &&
			    find->direction == PW_DIRECTION_INPUT)
				is_default |= check_node_name(node,
						impl->defaults[DEFAULT_VIDEO_SOURCE].config);
		}
		if (is_default)
			priority += 10000;
	}

	if ((find->capture_sink && node->direction != PW_DIRECTION_INPUT) ||
	    (!find->capture_sink && !is_default && node->direction == find->direction)) {
		pw_log_debug(".. same direction");
		return 0;
	}
	if ((find->exclusive && node->obj->info->state == PW_NODE_STATE_RUNNING) ||
	    (node->peer && node->peer->exclusive)) {
		pw_log_debug(NAME " %p: node '%d' in use", impl, node->id);
		return 0;
	}

	pw_log_debug(NAME " %p: found node '%d' %"PRIu64" prio:%d", impl,
			node->id, plugged, priority);

	if (find->node == NULL ||
	    priority > find->priority ||
	    (priority == find->priority && plugged > find->plugged)) {
		pw_log_debug(NAME " %p: new best %d %" PRIu64, impl, priority, plugged);
		find->node = node;
		find->priority = priority;
		find->plugged = plugged;
	}
	return 0;
}

static struct node *find_auto_default_node(struct impl *impl, const struct default_node *def)
{
	struct node *node;
	struct find_data find;

	spa_zero(find);
	find.impl = impl;
	find.capture_sink = false;
	find.exclusive = false;

	if (strcmp(def->key, DEFAULT_AUDIO_SINK_KEY) == 0) {
		find.media = "Audio";
		find.direction = PW_DIRECTION_OUTPUT;
	} else if (strcmp(def->key, DEFAULT_AUDIO_SOURCE_KEY) == 0) {
		find.media = "Audio";
		find.direction = PW_DIRECTION_INPUT;
	} else if (strcmp(def->key, DEFAULT_VIDEO_SOURCE_KEY) == 0) {
		find.media = "Video";
		find.direction = PW_DIRECTION_INPUT;
	} else {
		return NULL;
	}

	spa_list_for_each(node, &impl->node_list, link)
		find_node(&find, node);

	return find.node;
}

static int link_nodes(struct node *node, struct node *peer)
{
	struct impl *impl = node->impl;
	struct pw_properties *props;
	struct node *output, *input;
	int res;

	pw_log_debug(NAME " %p: link nodes %d %d remix:%d", impl,
			node->id, peer->id, !node->dont_remix);

	if (node->dont_remix)
		configure_node(node, NULL, false);
	else {
		configure_node(node, &peer->format, true);
	}

	if (node->direction == PW_DIRECTION_INPUT) {
		output = peer;
		input = node;
	} else {
		output = node;
		input = peer;
	}
	props = pw_properties_new(NULL, NULL);
	pw_properties_setf(props, PW_KEY_LINK_OUTPUT_NODE, "%d", output->id);
	pw_properties_setf(props, PW_KEY_LINK_INPUT_NODE, "%d", input->id);
	pw_log_info("linking node %d to node %d", output->id, input->id);

	node->linking = true;
	res = sm_media_session_create_links(impl->session, &props->dict);
	pw_properties_free(props);

	if (impl->linking_node_removed) {
		impl->linking_node_removed = false;
		return -ENOENT;
	}
	node->linking = false;

	if (res > 0) {
		node->peer = peer;
		node->failed_peer = NULL;
		node->connect_count++;
		node->failed_count = 0;
	} else {
		if (node->failed_peer != peer)
			node->failed_count = 0;
		node->failed_peer = peer;
		node->failed_count++;
	}
	return res;
}

static int unlink_nodes(struct node *node, struct node *peer)
{
	struct impl *impl = node->impl;
	struct pw_properties *props;

	pw_log_debug(NAME " %p: unlink nodes %d %d", impl, node->id, peer->id);

	if (peer->peer == node)
		peer->peer = NULL;
	node->peer = NULL;

	if (node->direction == PW_DIRECTION_INPUT) {
		struct node *t = node;
		node = peer;
		peer = t;
	}
	props = pw_properties_new(NULL, NULL);
	pw_properties_setf(props, PW_KEY_LINK_OUTPUT_NODE, "%d", node->id);
	pw_properties_setf(props, PW_KEY_LINK_INPUT_NODE, "%d", peer->id);
	pw_log_info("unlinking node %d from peer node %d", node->id, peer->id);

	sm_media_session_remove_links(impl->session, &props->dict);

	pw_properties_free(props);

	return 0;
}

static int rescan_node(struct impl *impl, struct node *n)
{
	struct spa_dict *props;
	const char *str;
	bool exclusive, reconnect, autoconnect;
	struct find_data find;
	struct pw_node_info *info;
	struct node *peer;
	struct sm_object *obj;
	uint32_t path_id;
	bool follows_default;

	if (!n->active) {
		pw_log_debug(NAME " %p: node %d is not active", impl, n->id);
		return 0;
	}
	if (n->moving) {
		pw_log_debug(NAME " %p: node %d is moving", impl, n->id);
		return 0;
	}

	if (n->type == NODE_TYPE_DEVICE) {
		configure_node(n, NULL, false);
		return 0;
	}

	if (n->obj->info == NULL || n->obj->info->props == NULL) {
		pw_log_debug(NAME " %p: node %d has no properties", impl, n->id);
		return 0;
	}

	info = n->obj->info;
	props = info->props;

	str = spa_dict_lookup(props, PW_KEY_NODE_DONT_RECONNECT);
	reconnect = str ? !pw_properties_parse_bool(str) : true;

	follows_default = (impl->streams_follow_default &&
	                   n->type == NODE_TYPE_STREAM &&
	                   reconnect &&
	                   n->obj->target_node == NULL &&
	                   ((str = spa_dict_lookup(props, PW_KEY_NODE_TARGET)) == NULL ||
			    (uint32_t)atoi(str) == SPA_ID_INVALID));

	if (n->peer != NULL && !follows_default) {
		pw_log_debug(NAME " %p: node %d is already linked", impl, n->id);
		return 0;
	}

	if ((str = spa_dict_lookup(props, PW_KEY_STREAM_DONT_REMIX)) != NULL)
		n->dont_remix = pw_properties_parse_bool(str);

	if ((str = spa_dict_lookup(props, PW_KEY_STREAM_MONITOR)) != NULL)
		n->monitor = pw_properties_parse_bool(str);

	if (n->direction == PW_DIRECTION_INPUT &&
	    (str = spa_dict_lookup(props, PW_KEY_STREAM_CAPTURE_SINK)) != NULL)
		n->capture_sink = pw_properties_parse_bool(str);

	autoconnect = false;
	if ((str = spa_dict_lookup(props, PW_KEY_NODE_AUTOCONNECT)) != NULL)
		autoconnect = pw_properties_parse_bool(str);

	if ((str = spa_dict_lookup(props, PW_KEY_DEVICE_API)) != NULL &&
	    strcmp(str, "bluez5") == 0)
		autoconnect = true;

	if (!autoconnect) {
		pw_log_debug(NAME" %p: node %d does not need autoconnect", impl, n->id);
		configure_node(n, NULL, false);
		return 0;
	}

	if (n->media == NULL) {
		pw_log_debug(NAME" %p: node %d has unknown media", impl, n->id);
		return 0;
	}

	str = spa_dict_lookup(props, PW_KEY_NODE_EXCLUSIVE);
	exclusive = str ? pw_properties_parse_bool(str) : false;

	pw_log_debug(NAME " %p: exclusive:%d", impl, exclusive);

	spa_zero(find);
	find.impl = impl;
	find.media = n->media;
	find.capture_sink = n->capture_sink;
	find.direction = n->direction;
	find.exclusive = exclusive;

	/* we always honour the target node asked for by the client */
	path_id = SPA_ID_INVALID;
	if ((str = spa_dict_lookup(props, PW_KEY_NODE_TARGET)) != NULL)
		path_id = find_device_for_name(impl, str);
	if (path_id == SPA_ID_INVALID && n->obj->target_node != NULL)
		path_id = find_device_for_name(impl, n->obj->target_node);

	pw_log_info("trying to link node %d exclusive:%d reconnect:%d target:%d follows-default:%d", n->id,
	            exclusive, reconnect, path_id, follows_default);

	if (n->peer != NULL) {
		spa_list_for_each(peer, &impl->node_list, link)
			find_node(&find, peer);

		if (follows_default && find.node != NULL && find.node != n->peer) {
			pw_log_debug(NAME " %p: node %d follows default, changed (%d -> %d)", impl, n->id,
			             n->peer->id, find.node->id);
			unlink_nodes(n, n->peer);
		} else {
			pw_log_debug(NAME " %p: node %d already linked (not changing)", impl, n->id);
			return 0;
		}
	}

	if (path_id != SPA_ID_INVALID) {
		pw_log_debug(NAME " %p: target:%d", impl, path_id);

		if (!reconnect)
			n->obj->target_node = NULL;

		if ((obj = sm_media_session_find_object(impl->session, path_id)) != NULL) {
			pw_log_debug(NAME " %p: found target:%d type:%s", impl,
					path_id, obj->type);
			if (strcmp(obj->type, PW_TYPE_INTERFACE_Node) == 0) {
				peer = sm_object_get_data(obj, SESSION_KEY);
				if (peer == NULL)
					return -ENOENT;
				goto do_link;
			}
		}
		pw_log_warn("node %d target:%d not found, find fallback:%d", n->id,
				path_id, reconnect);
	}
	if (path_id == SPA_ID_INVALID && (reconnect || n->connect_count == 0)) {
		if (find.node == NULL)
			spa_list_for_each(peer, &impl->node_list, link)
				find_node(&find, peer);
	} else {
		find.node = NULL;
	}

	if (find.node == NULL) {
		struct sm_object *obj;

		if (!reconnect) {
			pw_log_info("don-reconnect target node destroyed: destroy %d", n->id);
			sm_media_session_destroy_object(impl->session, n->id);
		} else {
			pw_log_warn("no node found for %d", n->id);
		}

		obj = sm_media_session_find_object(impl->session, n->client_id);
		pw_log_debug(NAME " %p: client_id:%d object:%p type:%s", impl,
				n->client_id, obj, obj ? obj->type : "None");

		if (obj && strcmp(obj->type, PW_TYPE_INTERFACE_Client) == 0) {
			pw_client_error((struct pw_client*)obj->proxy,
				n->id, -ENOENT, "no node available");
		}
		return -ENOENT;
	}
	peer = find.node;

	if (exclusive && peer->obj->info->state == PW_NODE_STATE_RUNNING) {
		pw_log_warn("node %d busy, can't get exclusive access", peer->id);
		return -EBUSY;
	}
	n->exclusive = exclusive;

	pw_log_debug(NAME" %p: linking to node '%d'", impl, peer->id);

do_link:
	if (peer == n->failed_peer && n->failed_count > MAX_LINK_RETRY) {
		/* Break rescan -> failed link -> rescan loop. */
		pw_log_debug(NAME" %p: tried to link '%d' on last rescan, not retrying",
				impl, peer->id);
		return 0;
	}
	link_nodes(n, peer);
	return 1;
}

static void session_info(void *data, const struct pw_core_info *info)
{
	struct impl *impl = data;

	if (info && (info->change_mask & PW_CORE_CHANGE_MASK_PROPS)) {
		const char *str;

		if ((str = spa_dict_lookup(info->props, "default.clock.rate")) != NULL)
			impl->sample_rate = atoi(str);

		pw_log_debug(NAME" %p: props changed sample_rate:%d", impl, impl->sample_rate);
	}
}

static void refresh_auto_default_nodes(struct impl *impl)
{
	struct default_node *def;

	if (impl->session->metadata == NULL)
		return;

	pw_log_debug(NAME" %p: refresh", impl);

	/* Auto set default nodes */
	for (def = impl->defaults; def->key != NULL; ++def) {
		struct node *node;
		node = find_auto_default_node(impl, def);
		if (node == NULL && def->value != NULL) {
			def->value = NULL;
			pw_metadata_set_property(impl->session->metadata,
					PW_ID_CORE, def->key, NULL, NULL);
		} else if (node != NULL) {
			const char *name = pw_properties_get(node->obj->obj.props, PW_KEY_NODE_NAME);
			char buf[1024];

			if (name == NULL || strzcmp(name, def->value) == 0)
				continue;

			free(def->value);
			def->value = strdup(name);

			snprintf(buf, sizeof(buf), "{ \"name\": \"%s\" }", name);
			pw_metadata_set_property(impl->session->metadata,
					PW_ID_CORE, def->key,
					"Spa:String:JSON", buf);
		}
	}
}

static void session_rescan(void *data, int seq)
{
	struct impl *impl = data;
	struct node *node;

	pw_log_debug(NAME" %p: rescan", impl);

again:
	impl->node_list_changed = false;
	spa_list_for_each(node, &impl->node_list, link) {
		rescan_node(impl, node);
		if (impl->node_list_changed)
			goto again;
	}

	refresh_auto_default_nodes(impl);
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	struct default_node *def;
	for (def = impl->defaults; def->key != NULL; ++def) {
		free(def->config);
		free(def->value);
	}
	spa_hook_remove(&impl->listener);
	if (impl->session->metadata)
		spa_hook_remove(&impl->meta_listener);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.info = session_info,
	.create = session_create,
	.remove = session_remove,
	.rescan = session_rescan,
	.destroy = session_destroy,
};

static int do_move_node(struct node *n, struct node *src, struct node *dst)
{
	n->moving = true;
	if (src)
		unlink_nodes(n, src);
	if (dst)
		link_nodes(n, dst);
	n->moving = false;
	return 0;
}

static int handle_move(struct impl *impl, struct node *src_node, struct node *dst_node)
{
	const char *str;
	struct pw_node_info *info;

	if (src_node->peer == dst_node)
		return 0;

	if ((info = src_node->obj->info) == NULL)
		return -EIO;

	if ((str = spa_dict_lookup(info->props, PW_KEY_NODE_DONT_RECONNECT)) != NULL &&
		    pw_properties_parse_bool(str)) {
		pw_log_warn("can't reconnect node %d to %d", src_node->id,
				dst_node->id);
		return -EPERM;
	}

	pw_log_info("move node %d: from peer %d to %d", src_node->id,
			src_node->peer ? src_node->peer->id : SPA_ID_INVALID,
			dst_node->id);

	free(src_node->obj->target_node);
	str = get_device_name(dst_node);
	src_node->obj->target_node = str ? strdup(str) : NULL;

	return do_move_node(src_node, src_node->peer, dst_node);
}

static int check_new_target(struct impl *impl, struct node *target)
{
	struct node *node;
	const char *str = get_device_name(target);

	spa_list_for_each(node, &impl->node_list, link) {
		pw_log_debug(NAME" %p: node %d target '%s' find:%s", impl,
				node->id, node->obj->target_node, str);

		if (node->obj->target_node != NULL &&
		    strcmp(node->obj->target_node , str) == 0) {
			handle_move(impl, node, target);
		}
	}
	return 0;
}

static int metadata_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct impl *impl = object;

	if (subject == PW_ID_CORE) {
		struct default_node *def;
		bool changed = false;
		char *val = NULL;
		char name[1024];

		if (key != NULL && value != NULL) {
			pw_log_info("meta %s: %s", key, value);
			if (json_object_find(value, "name", name, sizeof(name)) < 0)
				return 0;
			pw_log_info("meta name: %s", name);
			val = name;
		}
		for (def = impl->defaults; def->key != NULL; ++def) {
			if (key == NULL || strcmp(key, def->key_config) == 0) {
				if (strzcmp(def->config, val) != 0)
					changed = true;
				free(def->config);
				def->config = val ? strdup(val) : NULL;
			}
			if (key == NULL || strcmp(key, def->key) == 0) {
				bool eff_changed = strzcmp(def->value, val) != 0;
				free(def->value);
				def->value = val ? strdup(val) : NULL;

				/* The effective value was changed. In case it was changed by
				 * someone else than us, reset the value to avoid confusion. */
				if (eff_changed)
					refresh_auto_default_nodes(impl);
			}
		}
		if (changed)
			sm_media_session_schedule_rescan(impl->session);
	} else if (key != NULL && strcmp(key, "target.node") == 0) {
		if (value != NULL) {
			struct node *src_node, *dst_node;

			dst_node = find_node_by_id_name(impl, SPA_ID_INVALID, value);
			src_node = dst_node ? find_node_by_id_name(impl, subject, NULL) : NULL;

			if (dst_node && src_node)
				handle_move(impl, src_node, dst_node);
		} else {
			/* Unset target node. Schedule rescan to re-link, if needed. */
			struct node *src_node;
			src_node = find_node_by_id_name(impl, subject, NULL);
			if (src_node) {
				free(src_node->obj->target_node);
				src_node->obj->target_node = NULL;
				sm_media_session_schedule_rescan(impl->session);
			}
		}
	}
	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

int sm_policy_node_start(struct sm_media_session *session)
{
	struct impl *impl;
	const char *flag;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	impl->sample_rate = 48000;

	impl->defaults[DEFAULT_AUDIO_SINK] = (struct default_node){
		DEFAULT_AUDIO_SINK_KEY, DEFAULT_CONFIG_AUDIO_SINK_KEY, NULL, NULL
	};
	impl->defaults[DEFAULT_AUDIO_SOURCE] = (struct default_node){
		DEFAULT_AUDIO_SOURCE_KEY, DEFAULT_CONFIG_AUDIO_SOURCE_KEY, NULL, NULL
	};
	impl->defaults[DEFAULT_VIDEO_SOURCE] = (struct default_node){
		DEFAULT_VIDEO_SOURCE_KEY, DEFAULT_CONFIG_VIDEO_SOURCE_KEY, NULL, NULL
	};
	impl->defaults[3] = (struct default_node){ NULL, NULL, NULL, NULL };

	flag = pw_properties_get(session->props, NAME ".streams-follow-default");
	impl->streams_follow_default = (flag != NULL && pw_properties_parse_bool(flag));

	spa_list_init(&impl->node_list);

	sm_media_session_add_listener(impl->session,
			&impl->listener,
			&session_events, impl);

	if (session->metadata) {
		pw_metadata_add_listener(session->metadata,
				&impl->meta_listener,
				&metadata_events, impl);
	}
	return 0;
}
