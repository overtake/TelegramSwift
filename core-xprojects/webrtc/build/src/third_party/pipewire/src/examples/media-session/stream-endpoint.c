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
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"

#include "extensions/session-manager.h"
#include "media-session.h"

#define NAME "stream-endpoint"
#define SESSION_KEY	"stream-endpoint"

#define DEFAULT_CHANNELS	2
#define DEFAULT_SAMPLERATE	48000

struct endpoint;

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;
};

struct node {
	struct sm_node *obj;
	struct spa_hook listener;

	struct impl *impl;

	uint32_t id;
	enum pw_direction direction;
	char *media;

	struct endpoint *endpoint;

	struct spa_audio_info format;
};

struct stream {
	struct endpoint *endpoint;
	struct spa_list link;

	struct pw_properties *props;
	struct pw_endpoint_stream_info info;

	struct spa_audio_info format;

	unsigned int active:1;
};

struct endpoint {
	struct impl *impl;

	struct pw_properties *props;
	struct node *node;

	struct pw_client_endpoint *client_endpoint;
	struct spa_hook client_endpoint_listener;
	struct spa_hook proxy_listener;
	struct pw_endpoint_info info;

	struct spa_param_info params[5];

	struct spa_list stream_list;
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
	struct node *node = endpoint->node;

	pw_log_debug(NAME " %p: node %d set param %d", impl, node->obj->obj.id, id);
	return pw_node_set_param((struct pw_node*)node->obj->obj.proxy,
			id, flags, param);
}


static int client_endpoint_stream_set_param(void *object, uint32_t stream_id,
		uint32_t id, uint32_t flags, const struct spa_pod *param)
{
	return -ENOTSUP;
}

static int stream_set_active(struct stream *stream, bool active)
{
	struct endpoint *endpoint = stream->endpoint;
	struct node *node = endpoint->node;
	char buf[1024];
	struct spa_pod_builder b = { 0, };
	struct spa_pod *param;

	if (stream->active == active)
		return 0;

	if (active) {
		stream->format = node->format;

		switch (stream->format.media_type) {
		case SPA_MEDIA_TYPE_audio:
			switch (stream->format.media_subtype) {
			case SPA_MEDIA_SUBTYPE_raw:
				stream->format.info.raw.rate = 48000;

				spa_pod_builder_init(&b, buf, sizeof(buf));
				param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &stream->format.info.raw);
				param = spa_pod_builder_add_object(&b,
					SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
					SPA_PARAM_PORT_CONFIG_direction, SPA_POD_Id(endpoint->info.direction),
					SPA_PARAM_PORT_CONFIG_mode,	 SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
					SPA_PARAM_PORT_CONFIG_monitor,   SPA_POD_Bool(false),
					SPA_PARAM_PORT_CONFIG_format,    SPA_POD_Pod(param));

				if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
					spa_debug_pod(2, NULL, param);

				pw_node_set_param((struct pw_node*)node->obj->obj.proxy,
						SPA_PARAM_PortConfig, 0, param);
				break;
			default:
				break;
			}
		default:
			break;
		}
	}
	stream->active = active;
	return 0;
}

static int client_endpoint_create_link(void *object, const struct spa_dict *props)
{
	struct endpoint *endpoint = object;
	struct impl *impl = endpoint->impl;
	struct pw_properties *p;
	struct stream *stream;
	int res;

	pw_log_debug("create link");

	if (props == NULL)
		return -EINVAL;

	if (spa_list_is_empty(&endpoint->stream_list))
		return -EIO;

	/* FIXME take first stream */
	stream = spa_list_first(&endpoint->stream_list, struct stream, link);
	stream_set_active(stream, true);

	p = pw_properties_new_dict(props);
	if (p == NULL)
		return -errno;

	if (endpoint->info.direction == PW_DIRECTION_OUTPUT) {
		const char *str;
		struct sm_object *obj;

		pw_properties_setf(p, PW_KEY_LINK_OUTPUT_NODE, "%d", endpoint->node->id);
		pw_properties_setf(p, PW_KEY_LINK_OUTPUT_PORT, "-1");

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
		pw_endpoint_create_link((struct pw_endpoint*)obj->proxy, &p->dict);
	} else {
		pw_properties_setf(p, PW_KEY_LINK_INPUT_NODE, "%d", endpoint->node->id);
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
	struct pw_properties *props = endpoint->props;
	struct node *node = endpoint->node;
	const char *str;

	s = calloc(1, sizeof(*s));
	if (s == NULL)
		return NULL;

	s->endpoint = endpoint;
	s->props = pw_properties_new(NULL, NULL);

	if ((str = pw_properties_get(props, PW_KEY_MEDIA_CLASS)) != NULL)
		pw_properties_set(s->props, PW_KEY_MEDIA_CLASS, str);
	if (node->direction == PW_DIRECTION_OUTPUT)
		pw_properties_set(s->props, PW_KEY_ENDPOINT_STREAM_NAME, "Playback");
	else
		pw_properties_set(s->props, PW_KEY_ENDPOINT_STREAM_NAME, "Capture");

	s->info.version = PW_VERSION_ENDPOINT_STREAM_INFO;
	s->info.id = 0;
	s->info.endpoint_id = endpoint->info.id;
	s->info.name = (char*)pw_properties_get(s->props, PW_KEY_ENDPOINT_STREAM_NAME);
	s->info.change_mask = PW_ENDPOINT_STREAM_CHANGE_MASK_PROPS;
	s->info.props = &s->props->dict;
	spa_list_append(&endpoint->stream_list, &s->link);

	pw_log_debug("stream %d", node->id);
	pw_client_endpoint_stream_update(endpoint->client_endpoint,
			s->info.id,
			PW_CLIENT_ENDPOINT_STREAM_UPDATE_INFO,
			0, NULL,
			&s->info);
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

	pw_properties_free(stream->props);
	spa_list_remove(&stream->link);
	free(stream);
}

static void complete_endpoint(void *data)
{
	struct endpoint *endpoint = data;
	struct impl *impl = endpoint->impl;
	struct node *node = endpoint->node;
	struct sm_param *p;

	pw_log_debug(NAME" %p: endpoint %p", impl, endpoint);

	spa_list_for_each(p, &node->obj->param_list, link) {
		struct spa_audio_info info = { 0, };

		switch (p->id) {
		case SPA_PARAM_EnumFormat:
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

			if (node->format.info.raw.channels < info.info.raw.channels)
				node->format = info;
			break;
		default:
			break;
		}
	}
	pw_client_endpoint_update(endpoint->client_endpoint,
			PW_CLIENT_ENDPOINT_UPDATE_INFO,
			0, NULL,
			&endpoint->info);

	endpoint_add_stream(endpoint);
}

static void update_params(void *data)
{
	uint32_t n_params;
	const struct spa_pod **params;
	struct endpoint *endpoint = data;
	struct impl *impl = endpoint->impl;
	struct node *node = endpoint->node;
	struct sm_param *p;

	pw_log_debug(NAME" %p: endpoint %p", impl, endpoint);

	params = alloca(sizeof(struct spa_pod *) * node->obj->n_params);
	n_params = 0;
	spa_list_for_each(p, &node->obj->param_list, link) {
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

static void proxy_destroy(void *data)
{
	struct endpoint *endpoint = data;
	struct stream *s;

	spa_list_consume(s, &endpoint->stream_list, link)
		destroy_stream(s);

	pw_properties_free(endpoint->props);
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
	struct pw_properties *props;
	struct endpoint *endpoint;
	struct pw_proxy *proxy;
	const char *str, *media_class = NULL, *name = NULL;
	uint32_t subscribe[4], n_subscribe = 0;

	props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		return NULL;

	if (node->obj->info && node->obj->info->props) {
		struct spa_dict *dict = node->obj->info->props;
		if ((media_class = spa_dict_lookup(dict, PW_KEY_MEDIA_CLASS)) != NULL)
			pw_properties_set(props, PW_KEY_MEDIA_CLASS, media_class);
		if ((name = spa_dict_lookup(dict, PW_KEY_MEDIA_NAME)) != NULL)
			pw_properties_set(props, PW_KEY_ENDPOINT_NAME, name);
		if ((str = spa_dict_lookup(dict, PW_KEY_OBJECT_ID)) != NULL)
			pw_properties_set(props, PW_KEY_NODE_ID, str);
		if ((str = spa_dict_lookup(dict, PW_KEY_CLIENT_ID)) != NULL)
			pw_properties_set(props, PW_KEY_ENDPOINT_CLIENT_ID, str);
		if ((str = spa_dict_lookup(dict, PW_KEY_NODE_AUTOCONNECT)) != NULL)
			pw_properties_set(props, PW_KEY_ENDPOINT_AUTOCONNECT, str);
		if ((str = spa_dict_lookup(dict, PW_KEY_NODE_TARGET)) != NULL)
			pw_properties_set(props, PW_KEY_NODE_TARGET, str);
		if ((str = spa_dict_lookup(dict, PW_KEY_ENDPOINT_TARGET)) != NULL)
			pw_properties_set(props, PW_KEY_ENDPOINT_TARGET, str);
	}

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
	endpoint->info.name = (char*)pw_properties_get(props, PW_KEY_ENDPOINT_NAME);
	endpoint->info.media_class = (char*)pw_properties_get(props, PW_KEY_MEDIA_CLASS);
	endpoint->info.session_id = impl->session->session->obj.id;
	endpoint->info.direction = node->direction;
	endpoint->info.flags = 0;
	endpoint->info.change_mask =
		PW_ENDPOINT_CHANGE_MASK_STREAMS |
		PW_ENDPOINT_CHANGE_MASK_SESSION |
		PW_ENDPOINT_CHANGE_MASK_PROPS |
		PW_ENDPOINT_CHANGE_MASK_PARAMS;
	endpoint->info.n_streams = 1;
	endpoint->info.props = &endpoint->props->dict;
	endpoint->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	endpoint->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	endpoint->info.params = endpoint->params;
	endpoint->info.n_params = 2;
	spa_list_init(&endpoint->stream_list);

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
	pw_log_debug(NAME" %p: node %p proxy %p subscribe %d params", impl,
				node->obj, node->obj->obj.proxy, n_subscribe);
	pw_node_subscribe_params((struct pw_node*)node->obj->obj.proxy,
				subscribe, n_subscribe);

	sm_media_session_sync(impl->session, complete_endpoint, endpoint);

	return endpoint;
}

static void destroy_endpoint(struct endpoint *endpoint)
{
	pw_proxy_destroy((struct pw_proxy*)endpoint->client_endpoint);
}

static void object_update(void *data)
{
	struct node *node = data;
	struct impl *impl = node->impl;

	pw_log_debug(NAME" %p: node %p endpoint %p %08x", impl, node, node->endpoint, node->obj->obj.changed);

	if (node->endpoint == NULL &&
	    node->obj->obj.avail & SM_OBJECT_CHANGE_MASK_PROPERTIES)
		node->endpoint = create_endpoint(node);

	if (node->endpoint &&
	    node->obj->obj.changed & SM_NODE_CHANGE_MASK_PARAMS)
		update_params(node->endpoint);
}


static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static int
handle_node(struct impl *impl, struct sm_object *obj)
{
	const char *media_class;
	enum pw_direction direction;
	struct node *node;

	media_class = obj->props ? pw_properties_get(obj->props, PW_KEY_MEDIA_CLASS) : NULL;

	pw_log_debug(NAME" %p: node "PW_KEY_MEDIA_CLASS" %s", impl, media_class);

	if (media_class == NULL)
		return 0;

	if (strstr(media_class, "Stream/") != media_class)
		return 0;

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

	node = sm_object_add_data(obj, SESSION_KEY, sizeof(struct node));
	node->obj = (struct sm_node*)obj;
	node->impl = impl;
	node->id = obj->id;
	node->direction = direction;
	node->media = strdup(media_class);
	pw_log_debug(NAME "%p: node %d is stream %d:%s", impl, node->id,
			node->direction, node->media);

	sm_object_add_listener(obj, &node->listener, &object_events, node);

	return 1;
}

static void destroy_node(struct impl *impl, struct node *node)
{
	if (node->endpoint)
		destroy_endpoint(node->endpoint);
	free(node->media);
	spa_hook_remove(&node->listener);
	sm_object_remove_data((struct sm_object*)node->obj, SESSION_KEY);
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0)
		res = handle_node(impl, object);
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

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0) {
		struct node *node;
		if ((node = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_node(impl, node);
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

int sm_stream_endpoint_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	sm_media_session_add_listener(session, &impl->listener, &session_events, impl);

	return 0;
}
