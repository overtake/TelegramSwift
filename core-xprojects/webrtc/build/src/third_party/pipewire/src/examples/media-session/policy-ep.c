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

#include "pipewire/pipewire.h"
#include "extensions/session-manager.h"

#include "media-session.h"

#define NAME "policy-ep"
#define SESSION_KEY	"policy-endpoint"

#define DEFAULT_CHANNELS	2
#define DEFAULT_SAMPLERATE	48000

#define DEFAULT_IDLE_SECONDS	3

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;

	struct spa_list endpoint_list;
	int seq;
};

struct endpoint {
	struct sm_endpoint *obj;

	uint32_t id;
	struct impl *impl;

	struct spa_list link;		/**< link in impl endpoint_list */
	enum pw_direction direction;

	uint32_t linked;

	uint32_t client_id;
	int32_t priority;

#define ENDPOINT_TYPE_UNKNOWN	0
#define ENDPOINT_TYPE_STREAM	1
#define ENDPOINT_TYPE_DEVICE	2
	uint32_t type;
	char *media;

	uint32_t media_type;
	uint32_t media_subtype;
	struct spa_audio_info_raw format;

	uint64_t plugged;
	unsigned int exclusive:1;
	unsigned int enabled:1;
	unsigned int busy:1;
};

struct stream {
	struct sm_endpoint_stream *obj;

	uint32_t id;
	struct impl *impl;

	struct endpoint *endpoint;
};

static int
handle_endpoint(struct impl *impl, struct sm_object *object)
{
	const char *str, *media_class;
	enum pw_direction direction;
	struct endpoint *ep;
	uint32_t client_id = SPA_ID_INVALID;

	if (object->props) {
		if ((str = pw_properties_get(object->props, PW_KEY_CLIENT_ID)) != NULL)
			client_id = atoi(str);
	}

	media_class = object->props ? pw_properties_get(object->props, PW_KEY_MEDIA_CLASS) : NULL;

	pw_log_debug(NAME" %p: endpoint "PW_KEY_MEDIA_CLASS" %s", impl, media_class);

	if (media_class == NULL)
		return 0;

	ep = sm_object_add_data(object, SESSION_KEY, sizeof(struct endpoint));
	ep->obj = (struct sm_endpoint*)object;
	ep->id = object->id;
	ep->impl = impl;
	ep->client_id = client_id;
	ep->type = ENDPOINT_TYPE_UNKNOWN;
	ep->enabled = true;
	spa_list_append(&impl->endpoint_list, &ep->link);

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

		ep->direction = direction;
		ep->type = ENDPOINT_TYPE_STREAM;
		ep->media = strdup(media_class);
		pw_log_debug(NAME "%p: endpoint %d is stream %s", impl, object->id, ep->media);
	}
	else {
		const char *media;
		if (strstr(media_class, "Audio/") == media_class) {
			media_class += strlen("Audio/");
			media = "Audio";
		}
		else if (strstr(media_class, "Video/") == media_class) {
			media_class += strlen("Video/");
			media = "Video";
		}
		else
			return 0;

		if (strcmp(media_class, "Sink") == 0)
			direction = PW_DIRECTION_INPUT;
		else if (strcmp(media_class, "Source") == 0)
			direction = PW_DIRECTION_OUTPUT;
		else
			return 0;

		ep->direction = direction;
		ep->type = ENDPOINT_TYPE_DEVICE;
		ep->media = strdup(media);

		pw_log_debug(NAME" %p: endpoint %d '%s' prio:%d", impl,
				object->id, ep->media, ep->priority);
	}
	return 1;
}

static void destroy_endpoint(struct impl *impl, struct endpoint *ep)
{
	spa_list_remove(&ep->link);
	free(ep->media);
	sm_object_remove_data((struct sm_object*)ep->obj, SESSION_KEY);
}

static int
handle_stream(struct impl *impl, struct sm_object *object)
{
	struct sm_endpoint_stream *stream = (struct sm_endpoint_stream*)object;
	struct stream *s;
	struct endpoint *ep;

	if (stream->endpoint == NULL)
		return 0;

	ep = sm_object_get_data(&stream->endpoint->obj, SESSION_KEY);
	if (ep == NULL)
		return 0;

	s = sm_object_add_data(object, SESSION_KEY, sizeof(struct stream));
	s->obj = (struct sm_endpoint_stream*)object;
	s->id = object->id;
	s->impl = impl;
	s->endpoint = ep;

	return 0;
}

static void destroy_stream(struct impl *impl, struct stream *s)
{
	sm_object_remove_data((struct sm_object*)s->obj, SESSION_KEY);
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Endpoint) == 0)
		res = handle_endpoint(impl, object);
	else if (strcmp(object->type, PW_TYPE_INTERFACE_EndpointStream) == 0)
		res = handle_stream(impl, object);
	else
		res = 0;

	if (res < 0) {
		pw_log_warn(NAME" %p: can't handle global %d", impl, object->id);
	}
	else
		sm_media_session_schedule_rescan(impl->session);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: remove global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Endpoint) == 0) {
		struct endpoint *ep;
		if ((ep = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_endpoint(impl, ep);
	}
	else if (strcmp(object->type, PW_TYPE_INTERFACE_EndpointStream) == 0) {
		struct stream *s;
		if ((s = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_stream(impl, s);
	}

	sm_media_session_schedule_rescan(impl->session);
}

struct find_data {
	struct impl *impl;
	struct endpoint *ep;
	struct endpoint *endpoint;
	bool exclusive;
	int priority;
	uint64_t plugged;
};

static int find_endpoint(void *data, struct endpoint *endpoint)
{
	struct find_data *find = data;
	struct impl *impl = find->impl;
	int priority = 0;
	uint64_t plugged = 0;

	pw_log_debug(NAME " %p: looking at endpoint '%d' enabled:%d busy:%d exclusive:%d",
			impl, endpoint->id, endpoint->enabled, endpoint->busy, endpoint->exclusive);

	if (!endpoint->enabled)
		return 0;

	if (endpoint->direction == find->ep->direction) {
		pw_log_debug(".. same direction");
		return 0;
	}
	if (strcmp(endpoint->media, find->ep->media) != 0) {
		pw_log_debug(".. incompatible media %s <-> %s", endpoint->media, find->ep->media);
		return 0;
	}

	plugged = endpoint->plugged;
	priority = endpoint->priority;

	if ((find->exclusive && endpoint->busy) || endpoint->exclusive) {
		pw_log_debug(NAME " %p: endpoint '%d' in use", impl, endpoint->id);
		return 0;
	}

	pw_log_debug(NAME " %p: found endpoint '%d' %"PRIu64" prio:%d", impl,
			endpoint->id, plugged, priority);

	if (find->endpoint == NULL ||
	    priority > find->priority ||
	    (priority == find->priority && plugged > find->plugged)) {
		pw_log_debug(NAME " %p: new best %d %" PRIu64, impl, priority, plugged);
		find->endpoint = endpoint;
		find->priority = priority;
		find->plugged = plugged;
	}
	return 0;
}

static int link_endpoints(struct endpoint *endpoint, struct endpoint *peer)
{
	struct impl *impl = endpoint->impl;
	struct pw_properties *props;

	pw_log_debug(NAME " %p: link endpoints %d %d", impl, endpoint->id, peer->id);

	if (endpoint->direction == PW_DIRECTION_INPUT) {
		struct endpoint *t = endpoint;
		endpoint = peer;
		peer = t;
	}
	props = pw_properties_new(NULL, NULL);
	pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_OUTPUT_ENDPOINT, "%d", endpoint->id);
	pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_OUTPUT_STREAM, "%d", -1);
	pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_INPUT_ENDPOINT, "%d", peer->id);
	pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_INPUT_STREAM, "%d", -1);
	pw_log_debug(NAME " %p: endpoint %d -> endpoint %d", impl,
			endpoint->id, peer->id);

	pw_endpoint_create_link((struct pw_endpoint*)endpoint->obj->obj.proxy,
                                         &props->dict);

	pw_properties_free(props);

	endpoint->linked++;
	peer->linked++;

	return 0;
}

static int link_node(struct endpoint *endpoint, struct sm_node *peer)
{
	struct impl *impl = endpoint->impl;
	struct pw_properties *props;

	pw_log_debug(NAME " %p: link endpoint %d to node %d", impl, endpoint->id, peer->obj.id);

	props = pw_properties_new(NULL, NULL);

	if (endpoint->direction == PW_DIRECTION_INPUT) {
		pw_properties_setf(props, PW_KEY_LINK_OUTPUT_NODE, "%d", peer->obj.id);
		pw_properties_setf(props, PW_KEY_LINK_OUTPUT_PORT, "%d", -1);
		pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_INPUT_ENDPOINT, "%d", endpoint->id);
		pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_INPUT_STREAM, "%d", -1);
		pw_log_debug(NAME " %p: node %d -> endpoint %d", impl,
				peer->obj.id, endpoint->id);
	} else {
		pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_OUTPUT_ENDPOINT, "%d", endpoint->id);
		pw_properties_setf(props, PW_KEY_ENDPOINT_LINK_OUTPUT_STREAM, "%d", -1);
		pw_properties_setf(props, PW_KEY_LINK_INPUT_NODE, "%d", peer->obj.id);
		pw_properties_setf(props, PW_KEY_LINK_INPUT_PORT, "%d", -1);
		pw_log_debug(NAME " %p: endpoint %d -> node %d", impl,
				endpoint->id, peer->obj.id);
	}

	pw_endpoint_create_link((struct pw_endpoint*)endpoint->obj->obj.proxy,
                                         &props->dict);

	pw_properties_free(props);

	endpoint->linked++;

	return 0;
}

static int rescan_endpoint(struct impl *impl, struct endpoint *ep)
{
	struct spa_dict *props;
        const char *str;
        bool exclusive;
        struct find_data find;
	struct pw_endpoint_info *info;
	struct endpoint *peer;
	struct sm_object *obj;
	struct sm_node *node;

	if (ep->type == ENDPOINT_TYPE_DEVICE)
		return 0;

	if (ep->obj->info == NULL || ep->obj->info->props == NULL) {
		pw_log_debug(NAME " %p: endpoint %d has no properties", impl, ep->id);
		return 0;
	}

	if (ep->linked > 0) {
		pw_log_debug(NAME " %p: endpoint %d is already linked", impl, ep->id);
		return 0;
	}

	info = ep->obj->info;
	props = info->props;

        str = spa_dict_lookup(props, PW_KEY_ENDPOINT_AUTOCONNECT);
        if (str == NULL || !pw_properties_parse_bool(str)) {
		pw_log_debug(NAME" %p: endpoint %d does not need autoconnect", impl, ep->id);
                return 0;
	}

	if (ep->media == NULL) {
		pw_log_debug(NAME" %p: endpoint %d has unknown media", impl, ep->id);
		return 0;
	}

	spa_zero(find);

	if ((str = spa_dict_lookup(props, PW_KEY_NODE_EXCLUSIVE)) != NULL)
		exclusive = pw_properties_parse_bool(str);
	else
		exclusive = false;

	find.impl = impl;
	find.ep = ep;
	find.exclusive = exclusive;

	pw_log_debug(NAME " %p: exclusive:%d", impl, exclusive);

	str = spa_dict_lookup(props, PW_KEY_ENDPOINT_TARGET);
	if (str == NULL)
		str = spa_dict_lookup(props, PW_KEY_NODE_TARGET);
	if (str != NULL) {
		uint32_t path_id = atoi(str);
		pw_log_debug(NAME " %p: target:%d", impl, path_id);

		if ((obj = sm_media_session_find_object(impl->session, path_id)) != NULL) {
			if (strcmp(obj->type, PW_TYPE_INTERFACE_Endpoint) == 0) {
				if ((peer = sm_object_get_data(obj, SESSION_KEY)) != NULL)
					goto do_link;
			}
			else if (strcmp(obj->type, PW_TYPE_INTERFACE_Node) == 0) {
				node = (struct sm_node*)obj;
				goto do_link_node;
			}
		}
	}

	spa_list_for_each(peer, &impl->endpoint_list, link)
		find_endpoint(&find, peer);

	if (find.endpoint == NULL) {
		struct sm_object *obj;

		pw_log_warn(NAME " %p: no endpoint found for %d", impl, ep->id);

		str = spa_dict_lookup(props, PW_KEY_NODE_DONT_RECONNECT);
		if (str != NULL && pw_properties_parse_bool(str)) {
//			pw_registry_destroy(impl->registry, ep->id);
		}

		obj = sm_media_session_find_object(impl->session, ep->client_id);
		if (obj && strcmp(obj->type, PW_TYPE_INTERFACE_Client) == 0) {
			pw_client_error((struct pw_client*)obj->proxy,
				ep->id, -ENOENT, "no endpoint available");
		}
		return -ENOENT;
	}
	peer = find.endpoint;

	if (exclusive && peer->busy) {
		pw_log_warn(NAME" %p: endpoint %d busy, can't get exclusive access", impl, peer->id);
		return -EBUSY;
	}
	peer->exclusive = exclusive;

	pw_log_debug(NAME" %p: linking to endpoint '%d'", impl, peer->id);

        peer->busy = true;

do_link:
	link_endpoints(ep, peer);
        return 1;
do_link_node:
	link_node(ep, node);
        return 1;
}

static void session_rescan(void *data, int seq)
{
	struct impl *impl = data;
	struct endpoint *ep;

	clock_gettime(CLOCK_MONOTONIC, &impl->now);
	pw_log_debug(NAME" %p: rescan", impl);

	spa_list_for_each(ep, &impl->endpoint_list, link)
		rescan_endpoint(impl, ep);
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
	.rescan = session_rescan,
	.destroy = session_destroy,
};

int sm_policy_ep_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	spa_list_init(&impl->endpoint_list);

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	return 0;
}
