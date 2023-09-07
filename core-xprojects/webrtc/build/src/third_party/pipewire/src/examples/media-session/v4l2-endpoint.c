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
#include <spa/utils/result.h>
#include <spa/utils/names.h>
#include <spa/utils/keys.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/dict.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include <extensions/session-manager.h>

#include "media-session.h"

#define NAME		"v4l2-endpoint"
#define SESSION_KEY	"v4l2-endpoint"

struct endpoint {
	struct spa_list link;

	struct impl *impl;

	struct pw_properties *props;

	struct node *node;
	struct spa_hook listener;

	struct pw_client_endpoint *client_endpoint;
	struct spa_hook proxy_listener;
	struct spa_hook client_endpoint_listener;
	struct pw_endpoint_info info;

	struct spa_param_info params[5];

	struct spa_list stream_list;
};

struct stream {
	struct spa_list link;
	struct endpoint *endpoint;

	struct pw_properties *props;
	struct pw_endpoint_stream_info info;

	unsigned int active:1;
};

struct node {
	struct impl *impl;
	struct sm_node *node;

	struct device *device;

	struct endpoint *endpoint;
};

struct device {
	struct impl *impl;
	uint32_t id;
	struct sm_device *device;
	struct spa_hook listener;

	struct spa_list endpoint_list;
};

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;
};

static int client_endpoint_set_session_id(void *object, uint32_t id)
{
	struct endpoint *endpoint = object;
	endpoint->info.session_id = id;
	return 0;
}

static int client_endpoint_set_param(void *object,
		uint32_t id, uint32_t flags, const struct spa_pod *param)
{
	struct endpoint *endpoint = object;
	struct impl *impl = endpoint->impl;
	pw_log_debug(NAME " %p: endpoint %p set param %d", impl, endpoint, id);
	return pw_node_set_param((struct pw_node*)endpoint->node->node->obj.proxy,
				id, flags, param);
}


static int client_endpoint_stream_set_param(void *object, uint32_t stream_id,
		uint32_t id, uint32_t flags, const struct spa_pod *param)
{
	return -ENOTSUP;
}

static int stream_set_active(struct endpoint *endpoint, struct stream *stream, bool active)
{
	if (stream->active == active)
		return 0;

	stream->active = active;
	return 0;
}

static int client_endpoint_create_link(void *object, const struct spa_dict *props)
{
	struct endpoint *endpoint = object;
	struct impl *impl = endpoint->impl;
	struct pw_properties *p;
	int res;

	pw_log_debug(NAME" %p: endpoint %p", impl, endpoint);

	if (props == NULL)
		return -EINVAL;

	p = pw_properties_new_dict(props);
	if (p == NULL)
		return -errno;

	if (endpoint->info.direction == PW_DIRECTION_OUTPUT) {
		const char *str;
		struct sm_object *obj;

		str = spa_dict_lookup(props, PW_KEY_ENDPOINT_LINK_INPUT_ENDPOINT);
		if (str == NULL) {
			pw_log_warn(NAME" %p: no target endpoint given", impl);
			res = -EINVAL;
			goto exit;
		}
		obj = sm_media_session_find_object(impl->session, atoi(str));
		if (obj == NULL || strcmp(obj->type, PW_TYPE_INTERFACE_Endpoint) != 0) {
			pw_log_warn(NAME" %p: could not find endpoint %s (%p)", impl, str, obj);
			res = -EINVAL;
			goto exit;
		}

		pw_properties_setf(p, PW_KEY_LINK_OUTPUT_NODE, "%d", endpoint->node->node->info->id);
		pw_properties_setf(p, PW_KEY_LINK_OUTPUT_PORT, "-1");

		pw_endpoint_create_link((struct pw_endpoint*)obj->proxy, &p->dict);
	} else {
		pw_properties_setf(p, PW_KEY_LINK_INPUT_NODE, "%d", endpoint->node->node->info->id);
		pw_properties_setf(p, PW_KEY_LINK_INPUT_PORT, "-1");

		sm_media_session_create_links(impl->session, &p->dict);
	}

	res = 0;
exit:
	pw_properties_free(p);

	return res;
}

static const struct pw_client_endpoint_events client_endpoint_events = {
	PW_VERSION_CLIENT_ENDPOINT_EVENTS,
	.set_session_id = client_endpoint_set_session_id,
	.set_param = client_endpoint_set_param,
	.stream_set_param = client_endpoint_stream_set_param,
	.create_link = client_endpoint_create_link,
};

static struct stream *endpoint_add_stream(struct endpoint *endpoint)
{
	struct stream *s;
	const char *str;

	s = calloc(1, sizeof(*s));
	if (s == NULL)
		return NULL;

	s->props = pw_properties_new(NULL, NULL);
	s->endpoint = endpoint;

	if ((str = pw_properties_get(endpoint->props, PW_KEY_MEDIA_CLASS)) != NULL)
		pw_properties_set(s->props, PW_KEY_MEDIA_CLASS, str);
	if ((str = pw_properties_get(endpoint->props, PW_KEY_PRIORITY_SESSION)) != NULL)
		pw_properties_set(s->props, PW_KEY_PRIORITY_SESSION, str);
	if (endpoint->info.direction == PW_DIRECTION_OUTPUT) {
		pw_properties_set(s->props, PW_KEY_ENDPOINT_STREAM_NAME, "Capture");
	} else {
		pw_properties_set(s->props, PW_KEY_ENDPOINT_STREAM_NAME, "Playback");
	}

	s->info.version = PW_VERSION_ENDPOINT_STREAM_INFO;
	s->info.id = endpoint->info.n_streams;
	s->info.endpoint_id = endpoint->info.id;
	s->info.name = (char*)pw_properties_get(s->props, PW_KEY_ENDPOINT_STREAM_NAME);
	s->info.change_mask = PW_ENDPOINT_STREAM_CHANGE_MASK_PROPS;
	s->info.props = &s->props->dict;

	pw_log_debug("stream %d", s->info.id);
	pw_client_endpoint_stream_update(endpoint->client_endpoint,
			s->info.id,
			PW_CLIENT_ENDPOINT_STREAM_UPDATE_INFO,
			0, NULL,
			&s->info);

	spa_list_append(&endpoint->stream_list, &s->link);
	endpoint->info.n_streams++;

	return s;
}

static void destroy_stream(struct stream *stream)
{
	struct endpoint *endpoint = stream->endpoint;

	pw_client_endpoint_stream_update(endpoint->client_endpoint,
			stream->info.id,
			PW_CLIENT_ENDPOINT_STREAM_UPDATE_DESTROYED,
			0, NULL,
			&stream->info);

	spa_list_remove(&stream->link);
	endpoint->info.n_streams--;

	pw_properties_free(stream->props);
	free(stream);
}

static void update_params(void *data)
{
	uint32_t n_params;
	const struct spa_pod **params;
	struct endpoint *endpoint = data;
	struct sm_node *node = endpoint->node->node;
	struct sm_param *p;

	pw_log_debug(NAME" %p: endpoint", endpoint);

	params = alloca(sizeof(struct spa_pod *) * node->n_params);
	n_params = 0;
	spa_list_for_each(p, &node->param_list, link) {
		switch (p->id) {
		case SPA_PARAM_Props:
		case SPA_PARAM_PropInfo:
			params[n_params++] = p->param;
			break;
		default:
			break;
		}
	}

	pw_client_endpoint_update(endpoint->client_endpoint,
			PW_CLIENT_ENDPOINT_UPDATE_PARAMS |
			PW_CLIENT_ENDPOINT_UPDATE_INFO,
			n_params, params,
			&endpoint->info);
}

static struct endpoint *create_endpoint(struct node *node);

static void object_update(void *data)
{
	struct endpoint *endpoint = data;
	struct impl *impl = endpoint->impl;
	struct sm_node *node = endpoint->node->node;

	pw_log_debug(NAME" %p: endpoint %p", impl, endpoint);

	if (node->obj.changed & SM_NODE_CHANGE_MASK_PARAMS)
		update_params(endpoint);
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static void complete_endpoint(void *data)
{
	struct endpoint *endpoint = data;
	struct stream *stream;
	struct sm_param *p;

	pw_log_debug("endpoint %p: complete", endpoint);

	spa_list_for_each(p, &endpoint->node->node->param_list, link) {
		struct spa_video_info info = { 0, };

		if (p->id != SPA_PARAM_EnumFormat)
			continue;

		if (spa_format_parse(p->param, &info.media_type, &info.media_subtype) < 0)
			continue;

		if (info.media_type != SPA_MEDIA_TYPE_video ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			continue;

		spa_pod_object_fixate((struct spa_pod_object*)p->param);
		if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
			spa_debug_pod(2, NULL, p->param);

		if (spa_format_video_raw_parse(p->param, &info.info.raw) < 0)
			continue;
	}

	pw_client_endpoint_update(endpoint->client_endpoint,
			PW_CLIENT_ENDPOINT_UPDATE_INFO,
			0, NULL,
			&endpoint->info);

	stream = endpoint_add_stream(endpoint);
	stream_set_active(endpoint, stream, true);

	sm_object_add_listener(&endpoint->node->node->obj, &endpoint->listener, &object_events, endpoint);
}

static void proxy_destroy(void *data)
{
	struct endpoint *endpoint = data;
	struct stream *s;

	pw_log_debug("endpoint %p: destroy", endpoint);

	spa_list_consume(s, &endpoint->stream_list, link)
		destroy_stream(s);

	pw_properties_free(endpoint->props);
	spa_list_remove(&endpoint->link);
	spa_hook_remove(&endpoint->proxy_listener);
	spa_hook_remove(&endpoint->client_endpoint_listener);
	endpoint->client_endpoint = NULL;
}

static void proxy_bound(void *data, uint32_t id)
{
	struct endpoint *endpoint = data;
	endpoint->info.id = id;
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.destroy = proxy_destroy,
	.bound = proxy_bound,
};

static struct endpoint *create_endpoint(struct node *node)
{
	struct impl *impl = node->impl;
	struct device *device = node->device;
	struct pw_properties *props;
	struct endpoint *endpoint;
	struct pw_proxy *proxy;
	const char *str, *media_class = NULL, *name = NULL;
	uint32_t subscribe[4], n_subscribe = 0;
	struct pw_properties *pr = node->node->obj.props;
	enum pw_direction direction;

	if (pr == NULL) {
		errno = EINVAL;
		return NULL;
	}

	if ((media_class = pw_properties_get(pr, PW_KEY_MEDIA_CLASS)) == NULL) {
		errno = EINVAL;
		return NULL;
	}

	if (strstr(media_class, "Source") != NULL) {
		direction = PW_DIRECTION_OUTPUT;
	} else if (strstr(media_class, "Sink") != NULL) {
		direction = PW_DIRECTION_INPUT;
	} else {
		errno = EINVAL;
		return NULL;
	}

	props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		return NULL;

	pw_properties_set(props, PW_KEY_MEDIA_CLASS, media_class);

	if ((str = pw_properties_get(pr, PW_KEY_PRIORITY_SESSION)) != NULL)
		pw_properties_set(props, PW_KEY_PRIORITY_SESSION, str);
	if ((name = pw_properties_get(pr, PW_KEY_NODE_DESCRIPTION)) != NULL) {
		pw_properties_set(props, PW_KEY_ENDPOINT_NAME, name);
	}
	if ((str = pw_properties_get(pr, PW_KEY_DEVICE_ICON_NAME)) != NULL)
		pw_properties_set(props, PW_KEY_ENDPOINT_ICON_NAME, str);

	proxy = sm_media_session_create_object(impl->session,
						"client-endpoint",
						PW_TYPE_INTERFACE_ClientEndpoint,
						PW_VERSION_CLIENT_ENDPOINT,
						&props->dict, sizeof(*endpoint));
	if (proxy == NULL) {
		pw_properties_free(props);
		return NULL;
	}

	endpoint = pw_proxy_get_user_data(proxy);
	endpoint->impl = impl;
	endpoint->node = node;
	endpoint->props = props;
	endpoint->client_endpoint = (struct pw_client_endpoint *) proxy;
	endpoint->info.version = PW_VERSION_ENDPOINT_INFO;
	endpoint->info.name = (char*)pw_properties_get(endpoint->props, PW_KEY_ENDPOINT_NAME);
	endpoint->info.media_class = (char*)pw_properties_get(endpoint->props, PW_KEY_MEDIA_CLASS);
	endpoint->info.session_id = impl->session->session->obj.id;
	endpoint->info.direction = direction;
	endpoint->info.flags = 0;
	endpoint->info.change_mask =
		PW_ENDPOINT_CHANGE_MASK_STREAMS |
		PW_ENDPOINT_CHANGE_MASK_SESSION |
		PW_ENDPOINT_CHANGE_MASK_PROPS |
		PW_ENDPOINT_CHANGE_MASK_PARAMS;
	endpoint->info.n_streams = 0;
	endpoint->info.props = &endpoint->props->dict;
	endpoint->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	endpoint->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	endpoint->info.params = endpoint->params;
	endpoint->info.n_params = 2;
	spa_list_init(&endpoint->stream_list);

	pw_log_debug(NAME" %p: new endpoint %p for v4l2 node %p", impl, endpoint, node);
	pw_proxy_add_listener(proxy,
			&endpoint->proxy_listener,
			&proxy_events, endpoint);

	pw_client_endpoint_add_listener(endpoint->client_endpoint,
			&endpoint->client_endpoint_listener,
			&client_endpoint_events,
			endpoint);

	subscribe[n_subscribe++] = SPA_PARAM_EnumFormat;
	subscribe[n_subscribe++] = SPA_PARAM_Props;
	subscribe[n_subscribe++] = SPA_PARAM_PropInfo;
	pw_log_debug(NAME" %p: endpoint %p proxy %p subscribe %d params", impl,
				endpoint, node->node->obj.proxy, n_subscribe);
	pw_node_subscribe_params((struct pw_node*)node->node->obj.proxy,
				subscribe, n_subscribe);

	spa_list_append(&device->endpoint_list, &endpoint->link);

	sm_media_session_sync(impl->session, complete_endpoint, endpoint);

	return endpoint;
}

static void destroy_endpoint(struct impl *impl, struct endpoint *endpoint)
{
	pw_log_debug("endpoint %p: destroy", endpoint);
	if (endpoint->client_endpoint) {
		pw_proxy_destroy((struct pw_proxy*)endpoint->client_endpoint);
	}
}

/** fallback, one stream for each node */
static int setup_v4l2_endpoint(struct device *device)
{
	struct impl *impl = device->impl;
	struct sm_node *n;
	struct sm_device *d = device->device;

	pw_log_debug(NAME" %p: device %p setup", impl, d);

	spa_list_for_each(n, &d->node_list, link) {
		struct node *node;

		pw_log_debug(NAME" %p: device %p has node %p", impl, d, n);

		node = sm_object_add_data(&n->obj, SESSION_KEY, sizeof(struct node));
		node->device = device;
		node->node = n;
		node->impl = impl;
		node->endpoint = create_endpoint(node);
		if (node->endpoint == NULL)
			return -errno;
	}
	return 0;
}

static int activate_device(struct device *device)
{
	return setup_v4l2_endpoint(device);
}

static int deactivate_device(struct device *device)
{
	struct impl *impl = device->impl;
	struct endpoint *e;

	pw_log_debug(NAME" %p: device %p deactivate", impl, device->device);
	spa_list_consume(e, &device->endpoint_list, link)
		destroy_endpoint(impl, e);

	return 0;
}

static void device_update(void *data)
{
	struct device *device = data;
	struct impl *impl = device->impl;

	pw_log_debug(NAME" %p: device %p %08x %08x", impl, device,
			device->device->obj.avail, device->device->obj.changed);

	if (!SPA_FLAG_IS_SET(device->device->obj.avail,
			SM_DEVICE_CHANGE_MASK_INFO |
			SM_DEVICE_CHANGE_MASK_NODES))
		return;

	if (SPA_FLAG_IS_SET(device->device->obj.changed,
			SM_DEVICE_CHANGE_MASK_NODES)) {
		activate_device(device);
	}
}

static const struct sm_object_events device_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = device_update
};

static int
handle_device(struct impl *impl, struct sm_object *obj)
{
	const char *media_class, *str;
	struct device *device;

	if (obj->props == NULL)
		return 0;

	media_class = pw_properties_get(obj->props, PW_KEY_MEDIA_CLASS);
	str = pw_properties_get(obj->props, PW_KEY_DEVICE_API);

	pw_log_debug(NAME" %p: device "PW_KEY_MEDIA_CLASS":%s api:%s", impl, media_class, str);

	if (strstr(media_class, "Video/") != media_class)
		return 0;
	if (strcmp(str, "v4l2") != 0)
		return 0;

	device = sm_object_add_data(obj, SESSION_KEY, sizeof(struct device));
	device->impl = impl;
	device->id = obj->id;
	device->device = (struct sm_device*)obj;
	spa_list_init(&device->endpoint_list);
	pw_log_debug(NAME" %p: found v4l2 device %d media_class %s", impl, obj->id, media_class);

	sm_object_add_listener(obj, &device->listener, &device_events, device);

	return 0;
}

static void destroy_device(struct impl *impl, struct device *device)
{
	deactivate_device(device);
	spa_hook_remove(&device->listener);
	sm_object_remove_data((struct sm_object*)device->device, SESSION_KEY);
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Device) == 0)
		res = handle_device(impl, object);
	else
		res = 0;

	if (res < 0) {
		pw_log_warn(NAME" %p: can't handle global %d: %s", impl,
				object->id, spa_strerror(res));
	}
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Device) == 0) {
		struct device *device;
		if ((device = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_device(impl, device);
	}
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->listener);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

int sm_v4l2_endpoint_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	sm_media_session_add_listener(session, &impl->listener, &session_events, impl);

	return 0;
}
