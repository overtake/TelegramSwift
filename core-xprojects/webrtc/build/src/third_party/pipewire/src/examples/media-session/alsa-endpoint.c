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

#include <alsa/asoundlib.h>
#include <alsa/use-case.h>

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/names.h>
#include <spa/utils/keys.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/dict.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include <extensions/session-manager.h>

#include "media-session.h"

#define NAME		"alsa-endpoint"
#define SESSION_KEY	"alsa-endpoint"

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

	struct endpoint *monitor;

	unsigned int use_ucm:1;
	snd_use_case_mgr_t *ucm;

	struct spa_audio_info format;

	struct spa_list stream_list;
};

struct stream {
	struct spa_list link;
	struct endpoint *endpoint;

	struct pw_properties *props;
	struct pw_endpoint_stream_info info;

	struct spa_audio_info format;

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
	char buf[1024];
	struct spa_pod_builder b = { 0, };
	struct spa_pod *param;

	if (stream->active == active)
		return 0;

	if (active) {
		stream->format.info.raw.rate = 48000;

		spa_pod_builder_init(&b, buf, sizeof(buf));
		param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &stream->format.info.raw);
		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
			SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(endpoint->info.direction),
			SPA_PARAM_PORT_CONFIG_mode,	 SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
			SPA_PARAM_PORT_CONFIG_monitor,   SPA_POD_Bool(true),
			SPA_PARAM_PORT_CONFIG_format,    SPA_POD_Pod(param));

		if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
			spa_debug_pod(2, NULL, param);

		pw_node_set_param((struct pw_node*)endpoint->node->node->obj.proxy,
				SPA_PARAM_PortConfig, 0, param);
	}
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
		if (obj == NULL || strcmp(obj->type, PW_TYPE_INTERFACE_Endpoint) !=0) {
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
		if (endpoint->monitor != NULL)
			pw_properties_set(s->props, PW_KEY_ENDPOINT_STREAM_NAME, "Monitor");
		else
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
	s->format = endpoint->format;

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

static struct endpoint *create_endpoint(struct node *node, struct endpoint *monitor);

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
		struct spa_audio_info info = { 0, };

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

		if (spa_format_audio_raw_parse(p->param, &info.info.raw) < 0)
			continue;

		if (endpoint->format.info.raw.channels < info.info.raw.channels)
			endpoint->format = info;
	}

	pw_client_endpoint_update(endpoint->client_endpoint,
			PW_CLIENT_ENDPOINT_UPDATE_INFO,
			0, NULL,
			&endpoint->info);

	stream = endpoint_add_stream(endpoint);

	if (endpoint->info.direction == PW_DIRECTION_INPUT) {
		struct endpoint *monitor;

		/* make monitor for sinks */
		monitor = create_endpoint(endpoint->node, endpoint);
		if (monitor == NULL)
			return;

		endpoint_add_stream(monitor);
	}
	stream_set_active(endpoint, stream, true);

	sm_object_add_listener(&endpoint->node->node->obj, &endpoint->listener, &object_events, endpoint);
}

static void proxy_destroy(void *data)
{
	struct endpoint *endpoint = data;
	struct stream *s;

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

static struct endpoint *create_endpoint(struct node *node, struct endpoint *monitor)
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

	if (monitor != NULL) {
		pw_properties_set(props, PW_KEY_MEDIA_CLASS, "Audio/Source");
		direction = PW_DIRECTION_OUTPUT;
	} else {
		pw_properties_set(props, PW_KEY_MEDIA_CLASS, media_class);
	}

	if ((str = pw_properties_get(pr, PW_KEY_PRIORITY_SESSION)) != NULL)
		pw_properties_set(props, PW_KEY_PRIORITY_SESSION, str);
	if ((name = pw_properties_get(pr, PW_KEY_NODE_DESCRIPTION)) != NULL) {
		if (monitor != NULL) {
			pw_properties_setf(props, PW_KEY_ENDPOINT_NAME, "Monitor of %s", monitor->info.name);
			pw_properties_setf(props, PW_KEY_ENDPOINT_MONITOR, "%d", monitor->info.id);
		} else {
			pw_properties_set(props, PW_KEY_ENDPOINT_NAME, name);
		}
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
	endpoint->monitor = monitor;
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

	pw_log_debug(NAME" %p: new endpoint %p for alsa node %p", impl, endpoint, node);
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

	if (monitor == NULL)
		sm_media_session_sync(impl->session, complete_endpoint, endpoint);

	return endpoint;
}

static void destroy_endpoint(struct endpoint *endpoint)
{
	if (endpoint->client_endpoint)
		pw_proxy_destroy((struct pw_proxy*)endpoint->client_endpoint);
}

/** fallback, one stream for each node */
static int setup_alsa_fallback_endpoint(struct device *device)
{
	struct impl *impl = device->impl;
	struct sm_node *n;
	struct sm_device *d = device->device;

	pw_log_debug(NAME" %p: device %p fallback", impl, d);

	spa_list_for_each(n, &d->node_list, link) {
		struct node *node;

		pw_log_debug(NAME" %p: device %p has node %p", impl, d, n);

		node = sm_object_add_data(&n->obj, SESSION_KEY, sizeof(struct node));
		node->device = device;
		node->node = n;
		node->impl = impl;
		node->endpoint = create_endpoint(node, NULL);
		if (node->endpoint == NULL)
			return -errno;
	}
	return 0;
}

/** UCM.
 *
 * We create 1 stream for each verb + modifier combination
 */
static int setup_alsa_ucm_endpoint(struct device *device)
{
	const char *str, *card_name = NULL;
	char *name_free = NULL;
	int i, res, num_verbs;
	const char **verb_list = NULL;
	struct spa_dict *props = device->device->info->props;
	snd_use_case_mgr_t *ucm;

	card_name = spa_dict_lookup(props, SPA_KEY_API_ALSA_CARD_NAME);
	if (card_name == NULL &&
	    (str = spa_dict_lookup(props, SPA_KEY_API_ALSA_CARD)) != NULL) {
		snd_card_get_name(atoi(str), &name_free);
		card_name = name_free;
		pw_log_debug("got card name %s for index %s", card_name, str);
	}
	if (card_name == NULL) {
		pw_log_error("can't get card name for index %s", str);
		res = -ENOTSUP;
		goto exit;
	}

	if ((res = snd_use_case_mgr_open(&ucm, card_name)) < 0) {
		pw_log_error("can not open UCM for %s: %s", card_name, snd_strerror(res));
		goto exit;
	}

	num_verbs = snd_use_case_verb_list(ucm, &verb_list);
	if (num_verbs < 0) {
		res = num_verbs;
		pw_log_error("UCM verb list not found for %s: %s", card_name, snd_strerror(num_verbs));
		goto close_exit;
	}

	for (i = 0; i < num_verbs; i++) {
		pw_log_debug("verb: %s", verb_list[i]);
	}

	snd_use_case_free_list(verb_list, num_verbs);

	res = -ENOTSUP;

close_exit:
	snd_use_case_mgr_close(ucm);
exit:
	free(name_free);
	return res;
}

static int activate_device(struct device *device)
{
	int res;

	if ((res = setup_alsa_ucm_endpoint(device)) < 0)
		res = setup_alsa_fallback_endpoint(device);

	return res;
}

static int deactivate_device(struct device *device)
{
	struct endpoint *e;
	spa_list_consume(e, &device->endpoint_list, link)
		destroy_endpoint(e);
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
			SM_DEVICE_CHANGE_MASK_NODES |
			SM_DEVICE_CHANGE_MASK_PARAMS))
		return;

	if (SPA_FLAG_IS_SET(device->device->obj.changed,
			SM_DEVICE_CHANGE_MASK_NODES |
			SM_DEVICE_CHANGE_MASK_PARAMS)) {
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

	if (strstr(media_class, "Audio/") != media_class)
		return 0;
	if (strcmp(str, "alsa") != 0)
		return 0;

	device = sm_object_add_data(obj, SESSION_KEY, sizeof(struct device));
	device->impl = impl;
	device->id = obj->id;
	device->device = (struct sm_device*)obj;
	spa_list_init(&device->endpoint_list);
	pw_log_debug(NAME" %p: found alsa device %d media_class %s", impl, obj->id, media_class);

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

int sm_alsa_endpoint_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	sm_media_session_add_listener(session, &impl->listener, &session_events, impl);
	return 0;
}
