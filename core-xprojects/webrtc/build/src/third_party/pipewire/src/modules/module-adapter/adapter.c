/* PipeWire
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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>

#include "config.h"

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/names.h>
#include <spa/utils/type-info.h>
#include <spa/param/format.h>
#include <spa/param/format-utils.h>
#include <spa/debug/types.h>

#include "pipewire/pipewire.h"

#include "modules/spa/spa-node.h"

#define NAME "adapter"

struct buffer {
	struct spa_buffer buf;
	struct spa_data datas[1];
	struct spa_chunk chunk[1];
};

struct node {
	struct pw_context *context;

	struct pw_impl_node *node;
	struct spa_hook node_listener;

	struct pw_impl_node *follower;

	void *user_data;
	enum pw_direction direction;
	struct pw_properties *props;

	uint32_t media_type;
	uint32_t media_subtype;

	struct spa_list ports;
};

/** \endcond */
static void node_free(void *data)
{
	struct node *n = data;
	spa_hook_remove(&n->node_listener);
	pw_properties_free(n->props);
}

static void node_port_init(void *data, struct pw_impl_port *port)
{
	struct node *n = data;
	const struct pw_properties *old;
	enum pw_direction direction;
	struct pw_properties *new;
	const char *str, *path, *desc, *nick, *name, *node_name, *media_class;
	char position[8], *prefix;
	bool is_monitor, is_device, is_duplex, is_virtual;

	direction = pw_impl_port_get_direction(port);

	old = pw_impl_port_get_properties(port);

	is_monitor = (str = pw_properties_get(old, PW_KEY_PORT_MONITOR)) != NULL &&
			pw_properties_parse_bool(str);

	if (!is_monitor && direction != n->direction)
		return;

	path = pw_properties_get(n->props, PW_KEY_OBJECT_PATH);
	media_class = pw_properties_get(n->props, PW_KEY_MEDIA_CLASS);

	if (media_class != NULL &&
	    (strstr(media_class, "Sink") != NULL ||
	     strstr(media_class, "Source") != NULL))
		is_device = true;
	else
		is_device = false;

	is_duplex = media_class != NULL && strstr(media_class, "Duplex") != NULL;
	is_virtual = media_class != NULL && strstr(media_class, "Virtual") != NULL;

	new = pw_properties_new(NULL, NULL);

	if (is_duplex)
		prefix = direction == PW_DIRECTION_INPUT ?
			"playback" : "capture";
	else if (is_virtual)
		prefix = direction == PW_DIRECTION_INPUT ?
			"input" : "capture";
	else if (is_device)
		prefix = direction == PW_DIRECTION_INPUT ?
			"playback" : is_monitor ? "monitor" : "capture";
	else
		prefix = direction == PW_DIRECTION_INPUT ?
			"input" : "output";

	if ((str = pw_properties_get(old, PW_KEY_AUDIO_CHANNEL)) == NULL ||
	    strcmp(str, "UNK") == 0) {
		snprintf(position, sizeof(position), "%d", pw_impl_port_get_id(port) + 1);
		str = position;
	}
	if (direction == n->direction) {
		if (is_device) {
			pw_properties_set(new, PW_KEY_PORT_PHYSICAL, "true");
			pw_properties_set(new, PW_KEY_PORT_TERMINAL, "true");
		}
	}

	desc = pw_properties_get(n->props, PW_KEY_NODE_DESCRIPTION);
	nick = pw_properties_get(n->props, PW_KEY_NODE_NICK);
	name = pw_properties_get(n->props, PW_KEY_NODE_NAME);

	if ((node_name = desc) == NULL && (node_name = nick) == NULL &&
	    (node_name = name) == NULL)
		node_name = "node";

	pw_properties_setf(new, PW_KEY_OBJECT_PATH, "%s:%s_%d",
			path ? path : node_name, prefix, pw_impl_port_get_id(port));

	pw_properties_setf(new, PW_KEY_PORT_NAME, "%s_%s", prefix, str);

	if ((node_name = nick) == NULL && (node_name = desc) == NULL &&
	    (node_name = name) == NULL)
		node_name = "node";

	pw_properties_setf(new, PW_KEY_PORT_ALIAS, "%s:%s_%s",
			node_name, prefix, str);

	pw_impl_port_update_properties(port, &new->dict);
	pw_properties_free(new);
}

static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.free = node_free,
	.port_init = node_port_init,
};


static int find_format(struct pw_impl_node *node, enum pw_direction direction,
		uint32_t *media_type, uint32_t *media_subtype)
{
	uint32_t state = 0;
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	int res;
	struct spa_pod *format;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	if ((res = spa_node_port_enum_params_sync(pw_impl_node_get_implementation(node),
				direction == PW_DIRECTION_INPUT ?
					SPA_DIRECTION_INPUT :
					SPA_DIRECTION_OUTPUT, 0,
				SPA_PARAM_EnumFormat, &state,
				NULL, &format, &b)) != 1) {
		res = res < 0 ? res : -ENOENT;
		pw_log_warn(NAME " %p: can't get format: %s", node, spa_strerror(res));
		return res;
	}

	if ((res = spa_format_parse(format, media_type, media_subtype)) < 0)
		return res;

	pw_log_debug(NAME " %p: %s/%s", node,
			spa_debug_type_find_name(spa_type_media_type, *media_type),
			spa_debug_type_find_name(spa_type_media_subtype, *media_subtype));
	return 0;
}


struct pw_impl_node *pw_adapter_new(struct pw_context *context,
		struct pw_impl_node *follower,
		struct pw_properties *props,
		size_t user_data_size)
{
	struct pw_impl_node *node;
	struct node *n;
	const char *str, *factory_name;
	const struct pw_node_info *info;
	enum pw_direction direction;
	int res;
	uint32_t media_type, media_subtype;

	info = pw_impl_node_get_info(follower);
	if (info == NULL) {
		res = -EINVAL;
		goto error;
	}

	pw_log_debug(NAME " %p: in %d/%d out %d/%d", follower,
			info->n_input_ports, info->max_input_ports,
			info->n_output_ports, info->max_output_ports);

	pw_properties_update(props, info->props);

	if (info->n_output_ports > 0) {
		direction = PW_DIRECTION_OUTPUT;
	} else if (info->n_input_ports > 0) {
		direction = PW_DIRECTION_INPUT;
	} else {
		res = -EINVAL;
		goto error;
	}

	if ((str = pw_properties_get(props, PW_KEY_NODE_ID)) != NULL)
		pw_properties_set(props, PW_KEY_NODE_SESSION, str);

	if (pw_properties_get(props, "factory.mode") == NULL) {
		if (direction == PW_DIRECTION_INPUT)
			str = "merge";
		else
			str = "split";
		pw_properties_set(props, "factory.mode", str);
	}

	if ((res = find_format(follower, direction, &media_type, &media_subtype)) < 0)
		goto error;

	if (media_type == SPA_MEDIA_TYPE_audio) {
		pw_properties_setf(props, "audio.adapt.follower", "pointer:%p",
				pw_impl_node_get_implementation(follower));
		pw_properties_set(props, SPA_KEY_LIBRARY_NAME, "audioconvert/libspa-audioconvert");
		if (pw_properties_get(props, PW_KEY_MEDIA_CLASS) == NULL)
			pw_properties_setf(props, PW_KEY_MEDIA_CLASS, "Audio/%s",
				direction == PW_DIRECTION_INPUT ? "Sink" : "Source");
		factory_name = SPA_NAME_AUDIO_ADAPT;
	}
	else if (media_type == SPA_MEDIA_TYPE_video) {
		pw_properties_setf(props, "video.adapt.follower", "pointer:%p",
				pw_impl_node_get_implementation(follower));
		pw_properties_set(props, SPA_KEY_LIBRARY_NAME, "videoconvert/libspa-videoconvert");
		if (pw_properties_get(props, PW_KEY_MEDIA_CLASS) == NULL)
			pw_properties_setf(props, PW_KEY_MEDIA_CLASS, "Video/%s",
				direction == PW_DIRECTION_INPUT ? "Sink" : "Source");
		factory_name = SPA_NAME_VIDEO_ADAPT;
	} else {
		res = -ENOTSUP;
		goto error;
	}

	node = pw_spa_node_load(context,
				factory_name,
				PW_SPA_NODE_FLAG_ACTIVATE | PW_SPA_NODE_FLAG_NO_REGISTER,
				pw_properties_copy(props),
				sizeof(struct node) + user_data_size);
        if (node == NULL) {
		res = -errno;
		pw_log_error("can't load spa node: %m");
		goto error;
	}

	n = pw_spa_node_get_user_data(node);
	n->context = context;
	n->node = node;
	n->follower = follower;
	n->direction = direction;
	n->props = props;
	n->media_type = media_type;
	n->media_subtype = media_subtype;
	spa_list_init(&n->ports);

	if (user_data_size > 0)
		n->user_data = SPA_MEMBER(n, sizeof(struct node), void);

	pw_impl_node_add_listener(node, &n->node_listener, &node_events, n);

	return node;

error:
	if (props)
		pw_properties_free(props);
	errno = -res;
	return NULL;
}

void *pw_adapter_get_user_data(struct pw_impl_node *node)
{
	struct node *n = pw_spa_node_get_user_data(node);
	return n->user_data;
}
