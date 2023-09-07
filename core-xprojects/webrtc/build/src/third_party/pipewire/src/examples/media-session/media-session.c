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

#include "config.h"

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <getopt.h>
#include <time.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/types.h>
#if HAVE_PWD_H
#include <pwd.h>
#endif

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/pod.h>
#include <spa/support/dbus.h>
#include <spa/monitor/device.h>

#include "pipewire/pipewire.h"
#include "pipewire/private.h"
#include "pipewire/conf.h"
#include "extensions/session-manager.h"
#include "extensions/client-node.h"

#include <dbus/dbus.h>

#include "media-session.h"

#define NAME		"media-session"
#define SESSION_PREFIX	"media-session.d"
#define SESSION_CONF	"media-session.conf"

#define sm_object_emit(o,m,v,...) spa_hook_list_call(&(o)->hooks, struct sm_object_events, m, v, ##__VA_ARGS__)

#define sm_object_emit_update(s)		sm_object_emit(s, update, 0)
#define sm_object_emit_destroy(s)		sm_object_emit(s, destroy, 0)
#define sm_object_emit_free(s)			sm_object_emit(s, free, 0)

#define sm_media_session_emit(s,m,v,...) spa_hook_list_call(&(s)->hooks, struct sm_media_session_events, m, v, ##__VA_ARGS__)

#define sm_media_session_emit_info(s,i)			sm_media_session_emit(s, info, 0, i)
#define sm_media_session_emit_create(s,obj)		sm_media_session_emit(s, create, 0, obj)
#define sm_media_session_emit_remove(s,obj)		sm_media_session_emit(s, remove, 0, obj)
#define sm_media_session_emit_rescan(s,seq)		sm_media_session_emit(s, rescan, 0, seq)
#define sm_media_session_emit_shutdown(s)		sm_media_session_emit(s, shutdown, 0)
#define sm_media_session_emit_destroy(s)		sm_media_session_emit(s, destroy, 0)
#define sm_media_session_emit_seat_active(s,...)	sm_media_session_emit(s, seat_active, 0, __VA_ARGS__)

int sm_access_flatpak_start(struct sm_media_session *sess);
int sm_access_portal_start(struct sm_media_session *sess);
int sm_default_nodes_start(struct sm_media_session *sess);
int sm_default_profile_start(struct sm_media_session *sess);
int sm_default_routes_start(struct sm_media_session *sess);
int sm_restore_stream_start(struct sm_media_session *sess);
int sm_streams_follow_default_start(struct sm_media_session *sess);
int sm_alsa_midi_start(struct sm_media_session *sess);
int sm_v4l2_monitor_start(struct sm_media_session *sess);
int sm_libcamera_monitor_start(struct sm_media_session *sess);
int sm_bluez5_monitor_start(struct sm_media_session *sess);
int sm_alsa_monitor_start(struct sm_media_session *sess);
int sm_suspend_node_start(struct sm_media_session *sess);
#ifdef HAVE_SYSTEMD
int sm_logind_start(struct sm_media_session *sess);
#endif

int sm_policy_node_start(struct sm_media_session *sess);

int sm_session_manager_start(struct sm_media_session *sess);

/** user data to add to an object */
struct data {
	struct spa_list link;
	const char *id;
	size_t size;
};

struct param {
	struct sm_param this;
};

struct sync {
	struct spa_list link;
	int seq;
	void (*callback) (void *data);
	void *data;
};

struct impl {
	struct sm_media_session this;

	struct pw_properties *conf;
	struct pw_properties *modules;

	struct pw_main_loop *loop;
	struct spa_dbus *dbus;

	struct pw_core *monitor_core;
	struct spa_hook monitor_listener;
	int monitor_seq;

	struct pw_core *policy_core;
	struct spa_hook policy_listener;
	struct spa_hook proxy_policy_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_registry *monitor_registry;
	struct spa_hook monitor_registry_listener;

	struct pw_map globals;
	struct spa_list object_list;		/**< all sm_objects */

	struct spa_list registry_event_list;	/**< pending registry events */

	struct spa_hook_list hooks;

	struct spa_list endpoint_link_list;	/** list of struct endpoint_link */
	struct pw_map endpoint_links;		/** map of endpoint_link */

	struct spa_list link_list;		/** list of struct link */

	struct spa_list sync_list;		/** list of struct sync */
	int rescan_seq;
	int last_seq;

	unsigned int scanning:1;
	unsigned int rescan_pending:1;
	unsigned int seat_active:1;
};

struct endpoint_link {
	uint32_t id;

	struct pw_endpoint_link_info info;

	struct impl *impl;

	struct spa_list link;			/**< link in struct impl endpoint_link_list */
	struct spa_list link_list;		/**< list of struct link */
};

struct link {
	struct pw_proxy *proxy;		/**< proxy for link */
	struct spa_hook listener;	/**< proxy listener */

	uint32_t output_node;
	uint32_t output_port;
	uint32_t input_node;
	uint32_t input_port;

	struct endpoint_link *endpoint_link;
	struct spa_list link;		/**< link in struct endpoint_link link_list or
					  *  struct impl link_list */
};

struct object_info {
	const char *type;
	uint32_t version;
	const void *events;
	size_t size;
	int (*init) (void *object);
	void (*destroy) (void *object);
};

struct registry_event {
	uint32_t id;
	uint32_t permissions;
	const char *type;
	uint32_t version;
	const struct spa_dict *props;

	struct pw_proxy *proxy;

	int seq;
	struct pw_properties *props_store;

	struct spa_list link;
	unsigned int monitor:1;
	unsigned int allocated:1;
};

static void add_object(struct impl *impl, struct sm_object *obj, uint32_t id)
{
	size_t size = pw_map_get_size(&impl->globals);
	obj->id = id;
	pw_log_debug("add global '%u' %p monitor:%d", obj->id, obj, obj->monitor_global);
	while (obj->id > size)
		pw_map_insert_at(&impl->globals, size++, NULL);
	pw_map_insert_at(&impl->globals, obj->id, obj);
	sm_media_session_emit_create(impl, obj);
}

static void remove_object(struct impl *impl, struct sm_object *obj)
{
	pw_log_debug("remove global '%u' %p monitor:%d", obj->id, obj, obj->monitor_global);
	pw_map_insert_at(&impl->globals, obj->id, NULL);
	sm_media_session_emit_remove(impl, obj);
	obj->id = SPA_ID_INVALID;
}

static void *find_object(struct impl *impl, uint32_t id, const char *type)
{
	struct sm_object *obj;
	if ((obj = pw_map_lookup(&impl->globals, id)) == NULL)
		return NULL;
	if (type != NULL && strcmp(obj->type, type) != 0)
		return NULL;
	return obj;
}

static struct data *object_find_data(struct sm_object *obj, const char *id)
{
	struct data *d;
	spa_list_for_each(d, &obj->data, link) {
		if (strcmp(d->id, id) == 0)
			return d;
	}
	return NULL;
}

void *sm_object_add_data(struct sm_object *obj, const char *id, size_t size)
{
	struct data *d;

	d = object_find_data(obj, id);
	if (d != NULL) {
		if (d->size == size)
			goto done;
		spa_list_remove(&d->link);
		free(d);
	}
	d = calloc(1, sizeof(struct data) + size);
	d->id = id;
	d->size = size;

	spa_list_append(&obj->data, &d->link);
done:
	return SPA_MEMBER(d, sizeof(struct data), void);
}

void *sm_object_get_data(struct sm_object *obj, const char *id)
{
	struct data *d;
	d = object_find_data(obj, id);
	if (d == NULL)
		return NULL;
	return SPA_MEMBER(d, sizeof(struct data), void);
}

int sm_object_remove_data(struct sm_object *obj, const char *id)
{
	struct data *d;
	d = object_find_data(obj, id);
	if (d == NULL)
		return -ENOENT;
	spa_list_remove(&d->link);
	free(d);
	return 0;
}

static int sm_object_destroy_maybe_free(struct sm_object *obj)
{
	struct impl *impl = SPA_CONTAINER_OF(obj->session, struct impl, this);
	struct data *d;

	pw_log_debug(NAME" %p: destroy object %p id:%d proxy:%p handle:%p monitor:%d destroyed:%d discarded:%d", obj->session,
			obj, obj->id, obj->proxy, obj->handle, obj->monitor_global, obj->destroyed, obj->discarded);

	if (obj->destroyed)
		goto unref;

	obj->destroyed = true;

	sm_object_emit_destroy(obj);

	if (SPA_FLAG_IS_SET(obj->mask, SM_OBJECT_CHANGE_MASK_LISTENER)) {
		SPA_FLAG_CLEAR(obj->mask, SM_OBJECT_CHANGE_MASK_LISTENER);
		spa_hook_remove(&obj->object_listener);
	}

	if (obj->id != SPA_ID_INVALID)
		remove_object(impl, obj);

	if (obj->destroy)
		obj->destroy(obj);

	spa_hook_remove(&obj->handle_listener);

	if (obj->proxy) {
		spa_hook_remove(&obj->proxy_listener);
		if (obj->proxy != obj->handle)
			pw_proxy_destroy(obj->proxy);
		obj->proxy = NULL;
	}

	pw_proxy_ref(obj->handle);
	pw_proxy_destroy(obj->handle);

	sm_object_emit_free(obj);

unref:
	if (!obj->discarded)
		return 0;

	if (obj->props) {
		pw_properties_free(obj->props);
		obj->props = NULL;
	}

	spa_list_consume(d, &obj->data, link) {
		spa_list_remove(&d->link);
		free(d);
	}

	spa_list_remove(&obj->link);
	pw_proxy_unref(obj->handle);  /* frees obj */

	return 0;
}

int sm_object_destroy(struct sm_object *obj)
{
	sm_object_discard(obj);
	return sm_object_destroy_maybe_free(obj);
}

static struct param *add_param(struct spa_list *param_list,
		int seq, int *param_seq, uint32_t id, const struct spa_pod *param)
{
	struct param *p;

	if (param == NULL || !spa_pod_is_object(param)) {
		errno = EINVAL;
		return NULL;
	}
	if (id == SPA_ID_INVALID)
		id = SPA_POD_OBJECT_ID(param);

	if (id >= SM_MAX_PARAMS) {
		pw_log_error(NAME": too big param id %d", id);
		errno = EINVAL;
		return NULL;
	}

	if (seq != param_seq[id]) {
		pw_log_debug(NAME": ignoring param %d, seq:%d != current_seq:%d",
				id, seq, param_seq[id]);
		errno = EBUSY;
		return NULL;
	}

	p = malloc(sizeof(struct param) + SPA_POD_SIZE(param));
	if (p == NULL)
		return NULL;

	p->this.id = id;
	p->this.param = SPA_MEMBER(p, sizeof(struct param), struct spa_pod);
	memcpy(p->this.param, param, SPA_POD_SIZE(param));

	spa_list_append(param_list, &p->this.link);

	return p;
}


static uint32_t clear_params(struct spa_list *param_list, uint32_t id)
{
	struct param *p, *t;
	uint32_t count = 0;

	spa_list_for_each_safe(p, t, param_list, this.link) {
		if (id == SPA_ID_INVALID || p->this.id == id) {
			spa_list_remove(&p->this.link);
			free(p);
			count++;
		}
	}
	return count;
}

/**
 * Core
 */
static const struct object_info core_object_info = {
	.type = PW_TYPE_INTERFACE_Core,
	.version = PW_VERSION_CORE,
	.size = sizeof(struct sm_object),
	.init = NULL,
};

/**
 * Module
 */
static const struct object_info module_info = {
	.type = PW_TYPE_INTERFACE_Module,
	.version = PW_VERSION_MODULE,
	.size = sizeof(struct sm_object),
	.init = NULL,
};

/**
 * Factory
 */
static const struct object_info factory_info = {
	.type = PW_TYPE_INTERFACE_Factory,
	.version = PW_VERSION_FACTORY,
	.size = sizeof(struct sm_object),
	.init = NULL,
};

/**
 * Clients
 */
static void client_event_info(void *object, const struct pw_client_info *info)
{
	struct sm_client *client = object;
	struct impl *impl = SPA_CONTAINER_OF(client->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: client %d info", impl, client->obj.id);
	client->info = pw_client_info_update(client->info, info);

	client->obj.avail |= SM_CLIENT_CHANGE_MASK_INFO;
	client->obj.changed |= SM_CLIENT_CHANGE_MASK_INFO;
	sm_object_sync_update(&client->obj);
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_event_info,
};

static void client_destroy(void *object)
{
	struct sm_client *client = object;
	if (client->info)
		pw_client_info_free(client->info);
}

static const struct object_info client_info = {
	.type = PW_TYPE_INTERFACE_Client,
	.version = PW_VERSION_CLIENT,
	.events = &client_events,
	.size = sizeof(struct sm_client),
	.init = NULL,
	.destroy = client_destroy,
};

/**
 * Device
 */
static void device_event_info(void *object, const struct pw_device_info *info)
{
	struct sm_device *device = object;
	struct impl *impl = SPA_CONTAINER_OF(device->obj.session, struct impl, this);
	uint32_t i;

	pw_log_debug(NAME" %p: device %d info", impl, device->obj.id);
	info = device->info = pw_device_info_update(device->info, info);

	device->obj.avail |= SM_DEVICE_CHANGE_MASK_INFO;
	device->obj.changed |= SM_DEVICE_CHANGE_MASK_INFO;

	if (info->change_mask & PW_DEVICE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t id = info->params[i].id;

			if (info->params[i].user == 0)
				continue;

			if (id >= SM_MAX_PARAMS) {
				pw_log_error(NAME" %p: too big param id %d", impl, id);
				continue;
			}

			device->n_params -= clear_params(&device->param_list, id);

			if (info->params[i].flags & SPA_PARAM_INFO_READ) {
				int res;
				res = pw_device_enum_params((struct pw_device*)device->obj.proxy,
						++device->param_seq[id], id, 0, UINT32_MAX, NULL);
				if (SPA_RESULT_IS_ASYNC(res))
					device->param_seq[id] = res;
				pw_log_debug(NAME" %p: device %d enum params %d seq:%d", impl,
						device->obj.id, id, device->param_seq[id]);
			}
			info->params[i].user = 0;
		}
	}
	sm_object_sync_update(&device->obj);
	sm_media_session_schedule_rescan(&impl->this);
}

static void device_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct sm_device *device = object;
	struct impl *impl = SPA_CONTAINER_OF(device->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: device %p param %d index:%d seq:%d", impl, device, id, index, seq);
	if (add_param(&device->param_list, seq, device->param_seq, id, param) != NULL)
		device->n_params++;

	device->obj.avail |= SM_DEVICE_CHANGE_MASK_PARAMS;
	device->obj.changed |= SM_DEVICE_CHANGE_MASK_PARAMS;
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info,
	.param = device_event_param,
};

static int device_init(void *object)
{
	struct sm_device *device = object;
	spa_list_init(&device->node_list);
	spa_list_init(&device->param_list);
	return 0;
}

static void device_destroy(void *object)
{
	struct sm_device *device = object;
	struct sm_node *node;

	spa_list_consume(node, &device->node_list, link) {
		node->device = NULL;
		spa_list_remove(&node->link);
	}
	clear_params(&device->param_list, SPA_ID_INVALID);
	device->n_params = 0;

	if (device->info)
		pw_device_info_free(device->info);
	device->info = NULL;
}

static const struct object_info device_info = {
	.type = PW_TYPE_INTERFACE_Device,
	.version = PW_VERSION_DEVICE,
	.events = &device_events,
	.size = sizeof(struct sm_device),
	.init = device_init,
	.destroy = device_destroy,
};

static const struct object_info spa_device_info = {
	.type = SPA_TYPE_INTERFACE_Device,
	.version = SPA_VERSION_DEVICE,
	.size = sizeof(struct sm_device),
	.init = device_init,
	.destroy = device_destroy,
};

/**
 * Node
 */
static void node_event_info(void *object, const struct pw_node_info *info)
{
	struct sm_node *node = object;
	struct impl *impl = SPA_CONTAINER_OF(node->obj.session, struct impl, this);
	uint32_t i;

	pw_log_debug(NAME" %p: node %d info", impl, node->obj.id);
	info = node->info = pw_node_info_update(node->info, info);

	node->obj.avail |= SM_NODE_CHANGE_MASK_INFO;
	node->obj.changed |= SM_NODE_CHANGE_MASK_INFO;

	if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS &&
	    (node->obj.mask & SM_NODE_CHANGE_MASK_PARAMS)) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t id = info->params[i].id;

			if (info->params[i].user == 0)
				continue;

			if (id >= SM_MAX_PARAMS) {
				pw_log_error(NAME" %p: too big param id %d", impl, id);
				continue;
			}

			node->n_params -= clear_params(&node->param_list, id);

			if (info->params[i].flags & SPA_PARAM_INFO_READ) {
				int res;
				res = pw_node_enum_params((struct pw_node*)node->obj.proxy,
						++node->param_seq[id], id, 0, UINT32_MAX, NULL);
				if (SPA_RESULT_IS_ASYNC(res))
					node->param_seq[id] = res;
				pw_log_debug(NAME" %p: node %d enum params %d seq:%d", impl,
						node->obj.id, id, node->param_seq[id]);
			}
			info->params[i].user = 0;
		}
	}
	sm_object_sync_update(&node->obj);
	sm_media_session_schedule_rescan(&impl->this);
}

static void node_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct sm_node *node = object;
	struct impl *impl = SPA_CONTAINER_OF(node->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: node %p param %d index:%d seq:%d", impl, node, id, index, seq);
	if (add_param(&node->param_list, seq, node->param_seq, id, param) != NULL)
		node->n_params++;

	node->obj.avail |= SM_NODE_CHANGE_MASK_PARAMS;
	node->obj.changed |= SM_NODE_CHANGE_MASK_PARAMS;
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
	.info = node_event_info,
	.param = node_event_param,
};

static int node_init(void *object)
{
	struct sm_node *node = object;
	struct impl *impl = SPA_CONTAINER_OF(node->obj.session, struct impl, this);
	struct pw_properties *props = node->obj.props;
	const char *str;

	spa_list_init(&node->port_list);
	spa_list_init(&node->param_list);

	if (props) {
		if ((str = pw_properties_get(props, PW_KEY_DEVICE_ID)) != NULL)
			node->device = find_object(impl, atoi(str), NULL);
		pw_log_debug(NAME" %p: node %d parent device %s (%p)", impl,
				node->obj.id, str, node->device);
		if (node->device) {
			spa_list_append(&node->device->node_list, &node->link);
			node->device->obj.avail |= SM_DEVICE_CHANGE_MASK_NODES;
			node->device->obj.changed |= SM_DEVICE_CHANGE_MASK_NODES;
		}
	}
	return 0;
}

static void node_destroy(void *object)
{
	struct sm_node *node = object;
	struct sm_port *port;

	spa_list_consume(port, &node->port_list, link) {
		port->node = NULL;
		spa_list_remove(&port->link);
	}
	clear_params(&node->param_list, SPA_ID_INVALID);
	node->n_params = 0;

	if (node->device) {
		spa_list_remove(&node->link);
		node->device->obj.changed |= SM_DEVICE_CHANGE_MASK_NODES;
	}
	if (node->info) {
		pw_node_info_free(node->info);
		node->info = NULL;
	}
	free(node->target_node);
	node->target_node = NULL;
}

static const struct object_info node_info = {
	.type = PW_TYPE_INTERFACE_Node,
	.version = PW_VERSION_NODE,
	.events = &node_events,
	.size = sizeof(struct sm_node),
	.init = node_init,
	.destroy = node_destroy,
};

/**
 * Port
 */
static void port_event_info(void *object, const struct pw_port_info *info)
{
	struct sm_port *port = object;
	struct impl *impl = SPA_CONTAINER_OF(port->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: port %d info", impl, port->obj.id);
	port->info = pw_port_info_update(port->info, info);

	port->obj.avail |= SM_PORT_CHANGE_MASK_INFO;
	port->obj.changed |= SM_PORT_CHANGE_MASK_INFO;
	sm_object_sync_update(&port->obj);
}

static const struct pw_port_events port_events = {
	PW_VERSION_PORT_EVENTS,
	.info = port_event_info,
};

static enum spa_audio_channel find_channel(const char *name)
{
        int i;
        for (i = 0; spa_type_audio_channel[i].name; i++) {
                if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
                        return spa_type_audio_channel[i].type;
        }
        return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static int port_init(void *object)
{
	struct sm_port *port = object;
	struct impl *impl = SPA_CONTAINER_OF(port->obj.session, struct impl, this);
	struct pw_properties *props = port->obj.props;
	const char *str;

	if (props) {
		if ((str = pw_properties_get(props, PW_KEY_PORT_DIRECTION)) != NULL)
			port->direction = strcmp(str, "out") == 0 ?
				PW_DIRECTION_OUTPUT : PW_DIRECTION_INPUT;
		if ((str = pw_properties_get(props, PW_KEY_FORMAT_DSP)) != NULL) {
			if (strcmp(str, "32 bit float mono audio") == 0)
				port->type = SM_PORT_TYPE_DSP_AUDIO;
			else if (strcmp(str, "8 bit raw midi") == 0)
				port->type = SM_PORT_TYPE_DSP_MIDI;
		}
		if ((str = pw_properties_get(props, PW_KEY_AUDIO_CHANNEL)) != NULL)
			port->channel = find_channel(str);
		if ((str = pw_properties_get(props, PW_KEY_NODE_ID)) != NULL)
			port->node = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Node);

		pw_log_debug(NAME" %p: port %d parent node %s (%p) direction:%d type:%d", impl,
				port->obj.id, str, port->node, port->direction, port->type);
		if (port->node) {
			spa_list_append(&port->node->port_list, &port->link);
			port->node->obj.avail |= SM_NODE_CHANGE_MASK_PORTS;
			port->node->obj.changed |= SM_NODE_CHANGE_MASK_PORTS;
		}
	}
	return 0;
}

static void port_destroy(void *object)
{
	struct sm_port *port = object;
	if (port->info)
		pw_port_info_free(port->info);
	if (port->node) {
		spa_list_remove(&port->link);
		port->node->obj.changed |= SM_NODE_CHANGE_MASK_PORTS;
	}
}

static const struct object_info port_info = {
	.type = PW_TYPE_INTERFACE_Port,
	.version = PW_VERSION_PORT,
	.events = &port_events,
	.size = sizeof(struct sm_port),
	.init = port_init,
	.destroy = port_destroy,
};

/**
 * Session
 */
static void session_event_info(void *object, const struct pw_session_info *info)
{
	struct sm_session *sess = object;
	struct impl *impl = SPA_CONTAINER_OF(sess->obj.session, struct impl, this);
	struct pw_session_info *i = sess->info;

	pw_log_debug(NAME" %p: session %d info", impl, sess->obj.id);
	if (i == NULL && info) {
		i = sess->info = calloc(1, sizeof(struct pw_session_info));
		i->version = PW_VERSION_SESSION_INFO;
		i->id = info->id;
        }
	if (info) {
		i->change_mask = info->change_mask;
		if (info->change_mask & PW_SESSION_CHANGE_MASK_PROPS) {
			if (i->props)
				pw_properties_free ((struct pw_properties *)i->props);
			i->props = (struct spa_dict *) pw_properties_new_dict (info->props);
		}
	}

	sess->obj.avail |= SM_SESSION_CHANGE_MASK_INFO;
	sess->obj.changed |= SM_SESSION_CHANGE_MASK_INFO;
	sm_object_sync_update(&sess->obj);
}

static const struct pw_session_events session_events = {
	PW_VERSION_SESSION_EVENTS,
	.info = session_event_info,
};

static int session_init(void *object)
{
	struct sm_session *sess = object;
	struct impl *impl = SPA_CONTAINER_OF(sess->obj.session, struct impl, this);

	if (sess->obj.id == impl->this.session_id)
		impl->this.session = sess;

	spa_list_init(&sess->endpoint_list);
	return 0;
}

static void session_destroy(void *object)
{
	struct sm_session *sess = object;
	struct sm_endpoint *endpoint;
	struct pw_session_info *i = sess->info;

	spa_list_consume(endpoint, &sess->endpoint_list, link) {
		endpoint->session = NULL;
		spa_list_remove(&endpoint->link);
	}
	if (i) {
		if (i->props)
			pw_properties_free ((struct pw_properties *)i->props);
		free(i);
	}

}

static const struct object_info session_info = {
	.type = PW_TYPE_INTERFACE_Session,
	.version = PW_VERSION_SESSION,
	.events = &session_events,
	.size = sizeof(struct sm_session),
	.init = session_init,
	.destroy = session_destroy,
};

/**
 * Endpoint
 */
static void endpoint_event_info(void *object, const struct pw_endpoint_info *info)
{
	struct sm_endpoint *endpoint = object;
	struct impl *impl = SPA_CONTAINER_OF(endpoint->obj.session, struct impl, this);
	struct pw_endpoint_info *i = endpoint->info;
	const char *str;

	pw_log_debug(NAME" %p: endpoint %d info", impl, endpoint->obj.id);
	if (i == NULL && info) {
		i = endpoint->info = calloc(1, sizeof(struct pw_endpoint_info));
		i->id = info->id;
		i->name = info->name ? strdup(info->name) : NULL;
		i->media_class = info->media_class ? strdup(info->media_class) : NULL;
		i->direction = info->direction;
		i->flags = info->flags;
        }
	if (info) {
		i->change_mask = info->change_mask;
		if (info->change_mask & PW_ENDPOINT_CHANGE_MASK_SESSION) {
			i->session_id = info->session_id;
		}
		if (info->change_mask & PW_ENDPOINT_CHANGE_MASK_PROPS) {
			if (i->props)
				pw_properties_free ((struct pw_properties *)i->props);
			i->props = (struct spa_dict *) pw_properties_new_dict (info->props);
			if ((str = spa_dict_lookup(i->props, PW_KEY_PRIORITY_SESSION)) != NULL)
				endpoint->priority = pw_properties_parse_int(str);
		}
	}

	endpoint->obj.avail |= SM_ENDPOINT_CHANGE_MASK_INFO;
	endpoint->obj.changed |= SM_ENDPOINT_CHANGE_MASK_INFO;
	sm_object_sync_update(&endpoint->obj);
}

static const struct pw_endpoint_events endpoint_events = {
	PW_VERSION_ENDPOINT_EVENTS,
	.info = endpoint_event_info,
};

static int endpoint_init(void *object)
{
	struct sm_endpoint *endpoint = object;
	struct impl *impl = SPA_CONTAINER_OF(endpoint->obj.session, struct impl, this);
	struct pw_properties *props = endpoint->obj.props;
	const char *str;

	if (props) {
		if ((str = pw_properties_get(props, PW_KEY_SESSION_ID)) != NULL)
			endpoint->session = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Session);
		pw_log_debug(NAME" %p: endpoint %d parent session %s", impl,
				endpoint->obj.id, str);
		if (endpoint->session) {
			spa_list_append(&endpoint->session->endpoint_list, &endpoint->link);
			endpoint->session->obj.avail |= SM_SESSION_CHANGE_MASK_ENDPOINTS;
			endpoint->session->obj.changed |= SM_SESSION_CHANGE_MASK_ENDPOINTS;
		}
	}
	spa_list_init(&endpoint->stream_list);

	return 0;
}

static void endpoint_destroy(void *object)
{
	struct sm_endpoint *endpoint = object;
	struct sm_endpoint_stream *stream;
	struct pw_endpoint_info *i = endpoint->info;

	spa_list_consume(stream, &endpoint->stream_list, link) {
		stream->endpoint = NULL;
		spa_list_remove(&stream->link);
	}
	if (endpoint->session) {
		endpoint->session = NULL;
		spa_list_remove(&endpoint->link);
	}
	if (i) {
		if (i->props)
			pw_properties_free ((struct pw_properties *)i->props);
		free(i->name);
		free(i->media_class);
		free(i);
	}
}

static const struct object_info endpoint_info = {
	.type = PW_TYPE_INTERFACE_Endpoint,
	.version = PW_VERSION_ENDPOINT,
	.events = &endpoint_events,
	.size = sizeof(struct sm_endpoint),
	.init = endpoint_init,
	.destroy = endpoint_destroy,
};


/**
 * Endpoint Stream
 */
static void endpoint_stream_event_info(void *object, const struct pw_endpoint_stream_info *info)
{
	struct sm_endpoint_stream *stream = object;
	struct impl *impl = SPA_CONTAINER_OF(stream->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: endpoint stream %d info", impl, stream->obj.id);
	if (stream->info == NULL && info) {
		stream->info = calloc(1, sizeof(struct pw_endpoint_stream_info));
		stream->info->version = PW_VERSION_ENDPOINT_STREAM_INFO;
		stream->info->id = info->id;
		stream->info->endpoint_id = info->endpoint_id;
		stream->info->name = info->name ? strdup(info->name) : NULL;
        }
	if (info) {
		stream->info->change_mask = info->change_mask;
	}

	stream->obj.avail |= SM_ENDPOINT_CHANGE_MASK_INFO;
	stream->obj.changed |= SM_ENDPOINT_CHANGE_MASK_INFO;
	sm_object_sync_update(&stream->obj);
}

static const struct pw_endpoint_stream_events endpoint_stream_events = {
	PW_VERSION_ENDPOINT_STREAM_EVENTS,
	.info = endpoint_stream_event_info,
};

static int endpoint_stream_init(void *object)
{
	struct sm_endpoint_stream *stream = object;
	struct impl *impl = SPA_CONTAINER_OF(stream->obj.session, struct impl, this);
	struct pw_properties *props = stream->obj.props;
	const char *str;

	if (props) {
		if ((str = pw_properties_get(props, PW_KEY_ENDPOINT_ID)) != NULL)
			stream->endpoint = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Endpoint);
		pw_log_debug(NAME" %p: stream %d parent endpoint %s", impl,
				stream->obj.id, str);
		if (stream->endpoint) {
			spa_list_append(&stream->endpoint->stream_list, &stream->link);
			stream->endpoint->obj.avail |= SM_ENDPOINT_CHANGE_MASK_STREAMS;
			stream->endpoint->obj.changed |= SM_ENDPOINT_CHANGE_MASK_STREAMS;
		}
	}
	spa_list_init(&stream->link_list);

	return 0;
}

static void endpoint_stream_destroy(void *object)
{
	struct sm_endpoint_stream *stream = object;

	if (stream->info) {
		free(stream->info->name);
		free(stream->info);
	}
	if (stream->endpoint) {
		stream->endpoint = NULL;
		spa_list_remove(&stream->link);
	}
}

static const struct object_info endpoint_stream_info = {
	.type = PW_TYPE_INTERFACE_EndpointStream,
	.version = PW_VERSION_ENDPOINT_STREAM,
	.events = &endpoint_stream_events,
	.size = sizeof(struct sm_endpoint_stream),
	.init = endpoint_stream_init,
	.destroy = endpoint_stream_destroy,
};

/**
 * Endpoint Link
 */
static void endpoint_link_event_info(void *object, const struct pw_endpoint_link_info *info)
{
	struct sm_endpoint_link *link = object;
	struct impl *impl = SPA_CONTAINER_OF(link->obj.session, struct impl, this);

	pw_log_debug(NAME" %p: endpoint link %d info", impl, link->obj.id);
	if (link->info == NULL && info) {
		link->info = calloc(1, sizeof(struct pw_endpoint_link_info));
		link->info->version = PW_VERSION_ENDPOINT_LINK_INFO;
		link->info->id = info->id;
		link->info->session_id = info->session_id;
		link->info->output_endpoint_id = info->output_endpoint_id;
		link->info->output_stream_id = info->output_stream_id;
		link->info->input_endpoint_id = info->input_endpoint_id;
		link->info->input_stream_id = info->input_stream_id;
	}
	if (info) {
		link->info->change_mask = info->change_mask;
	}

	link->obj.avail |= SM_ENDPOINT_LINK_CHANGE_MASK_INFO;
	link->obj.changed |= SM_ENDPOINT_LINK_CHANGE_MASK_INFO;
	sm_object_sync_update(&link->obj);
}

static const struct pw_endpoint_link_events endpoint_link_events = {
	PW_VERSION_ENDPOINT_LINK_EVENTS,
	.info = endpoint_link_event_info,
};

static void endpoint_link_destroy(void *object)
{
	struct sm_endpoint_link *link = object;

	if (link->info) {
		free(link->info->error);
		free(link->info);
	}
	if (link->output) {
		link->output = NULL;
		spa_list_remove(&link->output_link);
	}
	if (link->input) {
		link->input = NULL;
		spa_list_remove(&link->input_link);
	}
}

static const struct object_info endpoint_link_info = {
	.type = PW_TYPE_INTERFACE_EndpointLink,
	.version = PW_VERSION_ENDPOINT_LINK,
	.events = &endpoint_link_events,
	.size = sizeof(struct sm_endpoint_link),
	.init = NULL,
	.destroy = endpoint_link_destroy,
};

/**
 * Proxy
 */
static void done_proxy(void *data, int seq)
{
	struct sm_object *obj = data;

	pw_log_debug("done %p proxy %p avail:%08x update:%08x %d/%d", obj,
			obj->proxy, obj->avail, obj->changed, obj->pending, seq);

	if (obj->pending == seq) {
		obj->pending = SPA_ID_INVALID;
		if (obj->changed)
			sm_object_emit_update(obj);
		obj->changed = 0;
	}
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.done = done_proxy,
};

static void bound_handle(void *data, uint32_t id)
{
	struct sm_object *obj = data;
	struct impl *impl = SPA_CONTAINER_OF(obj->session, struct impl, this);

	pw_log_debug("bound %p proxy %p handle %p id:%d->%d",
			obj, obj->proxy, obj->handle, obj->id, id);

	if (obj->id == SPA_ID_INVALID) {
		struct sm_object *old_obj = find_object(impl, id, NULL);

		if (old_obj != NULL) {
			/*
			 * Monitor core is always more up-to-date in object creation
			 * events (see registry_global), so in case of duplicate objects
			 * we should prefer monitor globals.
			 */
			if (obj->monitor_global)
				sm_object_destroy_maybe_free(old_obj);
			else {
				sm_object_destroy_maybe_free(obj);
				return;
			}
		}

		add_object(impl, obj, id);
	}
}

static const struct pw_proxy_events handle_events = {
	PW_VERSION_PROXY_EVENTS,
	.bound = bound_handle,
};

int sm_object_sync_update(struct sm_object *obj)
{
	obj->pending = pw_proxy_sync(obj->proxy, 1);
	pw_log_debug("sync %p proxy %p %d", obj, obj->proxy, obj->pending);
	return obj->pending;
}

static const struct object_info *get_object_info(struct impl *impl, const char *type)
{
	const struct object_info *info;

	if (strcmp(type, PW_TYPE_INTERFACE_Core) == 0)
		info = &core_object_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Module) == 0)
		info = &module_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Factory) == 0)
		info = &factory_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0)
		info = &client_info;
	else if (strcmp(type, SPA_TYPE_INTERFACE_Device) == 0)
		info = &spa_device_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Device) == 0)
		info = &device_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0)
		info = &node_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0)
		info = &port_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Session) == 0)
		info = &session_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_Endpoint) == 0)
		info = &endpoint_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_EndpointStream) == 0)
		info = &endpoint_stream_info;
	else if (strcmp(type, PW_TYPE_INTERFACE_EndpointLink) == 0)
		info = &endpoint_link_info;
	else
		info = NULL;

	return info;
}

static struct sm_object *init_object(struct impl *impl, const struct object_info *info,
		struct pw_proxy *proxy, struct pw_proxy *handle, uint32_t id,
		const struct spa_dict *props, bool monitor_global)
{
	struct sm_object *obj;

	obj = pw_proxy_get_user_data(handle);
	obj->session = &impl->this;
	obj->id = id;
	obj->type = info->type;
	obj->props = props ? pw_properties_new_dict(props) : pw_properties_new(NULL, NULL);
	obj->proxy = proxy;
	obj->handle = handle;
	obj->destroy = info->destroy;
	obj->mask |= SM_OBJECT_CHANGE_MASK_PROPERTIES | SM_OBJECT_CHANGE_MASK_BIND;
	obj->avail |= obj->mask;
	obj->monitor_global = monitor_global;
	spa_hook_list_init(&obj->hooks);
	spa_list_init(&obj->data);

	spa_list_append(&impl->object_list, &obj->link);

	if (proxy) {
		pw_proxy_add_listener(obj->proxy, &obj->proxy_listener, &proxy_events, obj);
		if (info->events != NULL)
			pw_proxy_add_object_listener(obj->proxy, &obj->object_listener, info->events, obj);
		SPA_FLAG_UPDATE(obj->mask, SM_OBJECT_CHANGE_MASK_LISTENER, info->events != NULL);
	}
	pw_proxy_add_listener(obj->handle, &obj->handle_listener, &handle_events, obj);

	if (info->init)
		info->init(obj);

	return obj;
}

static struct sm_object *
create_object(struct impl *impl, struct pw_proxy *proxy, struct pw_proxy *handle,
		const struct spa_dict *props, bool monitor_global)
{
	const char *type;
	const struct object_info *info;
	struct sm_object *obj;

	type = pw_proxy_get_type(handle, NULL);

	if (strcmp(type, PW_TYPE_INTERFACE_ClientNode) == 0)
		type = PW_TYPE_INTERFACE_Node;

	info = get_object_info(impl, type);
	if (info == NULL) {
		pw_log_error(NAME" %p: unknown object type %s", impl, type);
		errno = ENOTSUP;
		return NULL;
	}
	obj = init_object(impl, info, proxy, handle, SPA_ID_INVALID, props, monitor_global);

	pw_log_debug(NAME" %p: created new object %p proxy:%p handle:%p", impl,
			obj, obj->proxy, obj->handle);

	return obj;
}

static struct sm_object *
bind_object(struct impl *impl, const struct object_info *info, struct registry_event *re)
{
	struct pw_proxy *proxy;
	struct sm_object *obj;

	proxy = re->proxy;
	re->proxy = NULL;

	obj = init_object(impl, info, proxy, proxy, re->id, re->props, false);
	sm_object_discard(obj);
	add_object(impl, obj, re->id);

	pw_log_debug(NAME" %p: bound new object %p proxy %p id:%d", impl, obj, obj->proxy, obj->id);

	return obj;
}

static int
update_object(struct impl *impl, const struct object_info *info, struct sm_object *obj,
              struct registry_event *re)
{
	struct pw_proxy *proxy;

	pw_properties_update(obj->props, re->props);

	if (obj->proxy != NULL)
		return 0;

	pw_log_debug(NAME" %p: update type:%s", impl, obj->type);

	proxy = re->proxy;
	re->proxy = NULL;

	obj->proxy = proxy;
	obj->type = info->type;

	pw_proxy_add_listener(obj->proxy, &obj->proxy_listener, &proxy_events, obj);
	if (info->events)
		pw_proxy_add_object_listener(obj->proxy, &obj->object_listener, info->events, obj);

	SPA_FLAG_UPDATE(obj->mask, SM_OBJECT_CHANGE_MASK_LISTENER, info->events != NULL);

	sm_media_session_emit_create(impl, obj);

	return 0;
}

static void registry_event_free(struct registry_event *re)
{
	if (re->proxy)
		pw_proxy_destroy(re->proxy);
	if (re->props_store)
		pw_properties_free(re->props_store);
	if (re->allocated) {
		spa_list_remove(&re->link);
		free(re);
	} else {
		spa_zero(*re);
	}
}

static int handle_registry_event(struct impl *impl, struct registry_event *re)
{
	struct sm_object *obj;
	const struct object_info *info = NULL;

	obj = find_object(impl, re->id, NULL);

	pw_log_debug(NAME " %p: new global '%d' %s/%d obj:%p monitor:%d seq:%d",
			impl, re->id, re->type, re->version, obj, re->monitor, re->seq);

	info = get_object_info(impl, re->type);
	if (info == NULL)
		return 0;

	if (obj == NULL && !re->monitor) {
		/*
		 * Only policy core binds new objects.
		 *
		 * The monitor core event corresponding to this one has already been
		 * processed. If monitor doesn't have the id now, the object either has
		 * not been created there, or there is a race condition and it was already
		 * removed. In that case, we create a zombie object here, but its remove
		 * event is already queued and arrives soon.
		 */
		obj = bind_object(impl, info, re);
	} else if (obj != NULL && obj->monitor_global == re->monitor) {
		/* Each core handles their own object updates */
		update_object(impl, info, obj, re);
	}

	sm_media_session_schedule_rescan(&impl->this);
	return 0;
}

static int handle_postponed_registry_events(struct impl *impl, int seq)
{
	struct registry_event *re, *t;

	spa_list_for_each_safe(re, t, &impl->registry_event_list, link) {
		if (re->seq == seq) {
			handle_registry_event(impl, re);
			registry_event_free(re);
		}
	}
	return 0;
}

static int monitor_sync(struct impl *impl)
{
	pw_core_set_paused(impl->policy_core, true);
	impl->monitor_seq = pw_core_sync(impl->monitor_core, 0, impl->monitor_seq);
	pw_log_debug(NAME " %p: monitor sync start %d", impl, impl->monitor_seq);
	sm_media_session_schedule_rescan(&impl->this);
	return impl->monitor_seq;
}

static void
registry_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	struct impl *impl = data;
	const struct object_info *info;
	struct registry_event *re = NULL;

	info = get_object_info(impl, type);
	if (info == NULL)
		return;

	pw_log_debug(NAME " %p: registry event (policy) for new global '%d'", impl, id);

	/*
	 * Handle policy core events after monitor core ones.
	 *
	 * Monitor sync pauses policy core, so the event will be handled before
	 * further registry or proxy events are received via policy core.
	 */
	re = calloc(1, sizeof(struct registry_event));
	if (re == NULL)
		goto error;

	re->allocated = true;
	spa_list_append(&impl->registry_event_list, &re->link);

	re->id = id;
	re->monitor = false;
	re->permissions = permissions;
	re->type = info->type;
	re->version = version;

	/* Bind proxy now */
	re->proxy = pw_registry_bind(impl->registry, id, type, info->version, info->size);
	if (re->proxy == NULL)
		goto error;

	if (props) {
		re->props_store = pw_properties_new_dict(props);
		if (re->props_store == NULL)
			goto error;
		re->props = &re->props_store->dict;
	}

	re->seq = monitor_sync(impl);

	return;

error:
	if (re)
		registry_event_free(re);
	pw_log_warn(NAME" %p: can't handle global %d: %s", impl, id, spa_strerror(-errno));
}

static void
registry_global_remove(void *data, uint32_t id)
{
	struct impl *impl = data;
	struct sm_object *obj;

	obj = find_object(impl, id, NULL);
	obj = (obj && !obj->monitor_global) ? obj : NULL;

	pw_log_debug(NAME " %p: registry event (policy) for remove global '%d' obj:%p",
			impl, id, obj);

	if (obj)
		sm_object_destroy_maybe_free(obj);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_global,
	.global_remove = registry_global_remove,
};

static void
monitor_registry_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	struct impl *impl = data;
	const struct object_info *info;
	struct registry_event re = {
		.id = id, .permissions = permissions, .type = type, .version = version,
		.props = props,	.monitor = true
	};

	pw_log_debug(NAME " %p: registry event (monitor) for new global '%d'", impl, id);

	info = get_object_info(impl, type);
	if (info == NULL)
		return;

	/* Bind proxy now from policy core */
	re.proxy = pw_registry_bind(impl->registry, id, type, info->version, 0);
	if (re.proxy)
		handle_registry_event(impl, &re);
	else 
		pw_log_warn(NAME" %p: can't handle global %d: %s", impl, id, spa_strerror(-errno));

	registry_event_free(&re);
	return;
}

static void
monitor_registry_global_remove(void *data, uint32_t id)
{
	struct impl *impl = data;
	struct sm_object *obj;

	obj = find_object(impl, id, NULL);
	obj = (obj && obj->monitor_global) ? obj : NULL;

	pw_log_debug(NAME " %p: registry event (monitor) for remove global '%d' obj:%p", impl, id, obj);

	if (obj)
		sm_object_destroy_maybe_free(obj);
}

static const struct pw_registry_events monitor_registry_events = {
      PW_VERSION_REGISTRY_EVENTS,
      .global = monitor_registry_global,
      .global_remove = monitor_registry_global_remove,
};

int sm_object_add_listener(struct sm_object *obj, struct spa_hook *listener,
		const struct sm_object_events *events, void *data)
{
	spa_hook_list_append(&obj->hooks, listener, events, data);
	return 0;
}

int sm_media_session_add_listener(struct sm_media_session *sess, struct spa_hook *listener,
                const struct sm_media_session_events *events, void *data)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct spa_hook_list save;
	struct sm_object *obj;

	spa_hook_list_isolate(&impl->hooks, &save, listener, events, data);

	spa_list_for_each(obj, &impl->object_list, link) {
		if (obj->id == SPA_ID_INVALID)
			continue;
		sm_media_session_emit_create(impl, obj);
	}

        spa_hook_list_join(&impl->hooks, &save);

	return 0;
}

struct sm_object *sm_media_session_find_object(struct sm_media_session *sess, uint32_t id)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	return find_object(impl, id, NULL);
}

int sm_media_session_destroy_object(struct sm_media_session *sess, uint32_t id)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	pw_registry_destroy(impl->registry, id);
	return 0;
}

int sm_media_session_for_each_object(struct sm_media_session *sess,
                            int (*callback) (void *data, struct sm_object *object),
                            void *data)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_object *obj;
	int res;

	spa_list_for_each(obj, &impl->object_list, link) {
		if (obj->id == SPA_ID_INVALID)
			continue;
		if ((res = callback(data, obj)) != 0)
			return res;
	}
	return 0;
}

int sm_media_session_schedule_rescan(struct sm_media_session *sess)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);

	if (impl->scanning) {
		impl->rescan_pending = true;
		return impl->rescan_seq;
	}
	if (impl->policy_core)
		impl->rescan_seq = pw_core_sync(impl->policy_core, 0, impl->last_seq);
	return impl->rescan_seq;
}

int sm_media_session_sync(struct sm_media_session *sess,
		void (*callback) (void *data), void *data)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sync *sync;

	sync = calloc(1, sizeof(struct sync));
	if (sync == NULL)
		return -errno;

	spa_list_append(&impl->sync_list, &sync->link);
	sync->callback = callback;
	sync->data = data;
	sync->seq = pw_core_sync(impl->policy_core, 0, impl->last_seq);
	return sync->seq;
}

static void roundtrip_callback(void *data)
{
	int *done = data;
	*done = 1;
}

int sm_media_session_roundtrip(struct sm_media_session *sess)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct pw_loop *loop = impl->this.loop;
	int done, res, seq;

	if (impl->policy_core == NULL)
		return -EIO;

	done = 0;
	if ((seq = sm_media_session_sync(sess, roundtrip_callback, &done)) < 0)
		return seq;

	pw_log_debug(NAME" %p: roundtrip %d", impl, seq);

	pw_loop_enter(loop);
	while (!done) {
		if ((res = pw_loop_iterate(loop, -1)) < 0) {
			if (res == -EINTR)
				continue;
			pw_log_warn(NAME" %p: iterate error %d (%s)",
				loop, res, spa_strerror(res));
			break;
		}
	}
        pw_loop_leave(loop);

	pw_log_debug(NAME" %p: roundtrip %d done", impl, seq);

	return 0;
}

struct pw_proxy *sm_media_session_export(struct sm_media_session *sess,
		const char *type, const struct spa_dict *props,
		void *object, size_t user_data_size)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct pw_proxy *handle;

	pw_log_debug(NAME " %p: object %s %p", impl, type, object);

	handle = pw_core_export(impl->monitor_core, type,
			props, object, user_data_size);

	monitor_sync(impl);

	return handle;
}

struct sm_node *sm_media_session_export_node(struct sm_media_session *sess,
		const struct spa_dict *props, struct pw_impl_node *object)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_node *node;
	struct pw_proxy *handle;

	pw_log_debug(NAME " %p: node %p", impl, object);

	handle = pw_core_export(impl->monitor_core, PW_TYPE_INTERFACE_Node,
			props, object, sizeof(struct sm_node));

	node = (struct sm_node *) create_object(impl, NULL, handle, props, true);

	monitor_sync(impl);

	return node;
}

struct sm_device *sm_media_session_export_device(struct sm_media_session *sess,
		const struct spa_dict *props, struct spa_device *object)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_device *device;
	struct pw_proxy *handle;

	pw_log_debug(NAME " %p: device %p", impl, object);

	handle = pw_core_export(impl->monitor_core, SPA_TYPE_INTERFACE_Device,
			props, object, sizeof(struct sm_device));

	device = (struct sm_device *) create_object(impl, NULL, handle, props, true);

	monitor_sync(impl);

	return device;
}

struct pw_proxy *sm_media_session_create_object(struct sm_media_session *sess,
		const char *factory_name, const char *type, uint32_t version,
		const struct spa_dict *props, size_t user_data_size)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	return pw_core_create_object(impl->policy_core,
			factory_name, type, version, props, user_data_size);
}

struct sm_node *sm_media_session_create_node(struct sm_media_session *sess,
		const char *factory_name, const struct spa_dict *props)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_node *node;
	struct pw_proxy *proxy;

	pw_log_debug(NAME " %p: node '%s'", impl, factory_name);

	proxy = pw_core_create_object(impl->policy_core,
				factory_name,
				PW_TYPE_INTERFACE_Node,
				PW_VERSION_NODE,
				props,
				sizeof(struct sm_node));

	node = (struct sm_node *)create_object(impl, proxy, proxy, props, false);

	return node;
}

static void check_endpoint_link(struct endpoint_link *link)
{
	if (!spa_list_is_empty(&link->link_list))
		return;

	if (link->impl) {
		spa_list_remove(&link->link);
		pw_map_remove(&link->impl->endpoint_links, link->id);

		pw_client_session_link_update(link->impl->this.client_session,
				link->id,
				PW_CLIENT_SESSION_LINK_UPDATE_DESTROYED,
				0, NULL, NULL);

		link->impl = NULL;
		free(link);
	}
}

static void proxy_link_error(void *data, int seq, int res, const char *message)
{
	struct link *l = data;
	pw_log_warn("can't link %d:%d -> %d:%d: %s",
			l->output_node, l->output_port,
			l->input_node, l->input_port, message);
	pw_proxy_destroy(l->proxy);
}

static void proxy_link_removed(void *data)
{
	struct link *l = data;
	pw_proxy_destroy(l->proxy);
}

static void proxy_link_destroy(void *data)
{
	struct link *l = data;

	spa_list_remove(&l->link);
	spa_hook_remove(&l->listener);

	if (l->endpoint_link) {
		check_endpoint_link(l->endpoint_link);
		l->endpoint_link = NULL;
	}
}

static const struct pw_proxy_events proxy_link_events = {
	PW_VERSION_PROXY_EVENTS,
	.error = proxy_link_error,
	.removed = proxy_link_removed,
	.destroy = proxy_link_destroy
};

static int score_ports(struct sm_port *out, struct sm_port *in)
{
	int score = 0;

	if (in->direction != PW_DIRECTION_INPUT || out->direction != PW_DIRECTION_OUTPUT)
		return 0;

	if (out->type != SM_PORT_TYPE_UNKNOWN && in->type != SM_PORT_TYPE_UNKNOWN &&
	    in->type != out->type)
		return 0;

	if (out->channel == in->channel)
		score += 100;
	else if ((out->channel == SPA_AUDIO_CHANNEL_SL && in->channel == SPA_AUDIO_CHANNEL_RL) ||
	         (out->channel == SPA_AUDIO_CHANNEL_RL && in->channel == SPA_AUDIO_CHANNEL_SL) ||
	         (out->channel == SPA_AUDIO_CHANNEL_SR && in->channel == SPA_AUDIO_CHANNEL_RR) ||
	         (out->channel == SPA_AUDIO_CHANNEL_RR && in->channel == SPA_AUDIO_CHANNEL_SR))
		score += 60;
	else if ((out->channel == SPA_AUDIO_CHANNEL_FC && in->channel == SPA_AUDIO_CHANNEL_MONO) ||
	         (out->channel == SPA_AUDIO_CHANNEL_MONO && in->channel == SPA_AUDIO_CHANNEL_FC))
		score += 50;
	else if (in->channel == SPA_AUDIO_CHANNEL_UNKNOWN ||
	    in->channel == SPA_AUDIO_CHANNEL_MONO ||
	    out->channel == SPA_AUDIO_CHANNEL_UNKNOWN ||
	    out->channel == SPA_AUDIO_CHANNEL_MONO)
		score += 10;
	if (score > 0 && !in->visited)
		score += 5;
	if (score <= 10)
		score = 0;
	return score;
}

static struct sm_port *find_input_port(struct impl *impl, struct sm_node *outnode,
		struct sm_port *outport, struct sm_node *innode)
{
	struct sm_port *inport, *best_port = NULL;
	int score, best_score = 0;

	spa_list_for_each(inport, &innode->port_list, link) {
		score = score_ports(outport, inport);
		if (score > best_score) {
			best_score = score;
			best_port = inport;
		}
	}
	return best_port;
}

static int link_nodes(struct impl *impl, struct endpoint_link *link,
		struct sm_node *outnode, struct sm_node *innode)
{
	struct pw_properties *props;
	struct sm_port *outport, *inport;
	int count = 0;
	bool passive = false;
	const char *str;

	pw_log_debug(NAME" %p: linking %d -> %d", impl, outnode->obj.id, innode->obj.id);

	if ((str = spa_dict_lookup(outnode->info->props, PW_KEY_NODE_PASSIVE)) != NULL)
		passive |= (pw_properties_parse_bool(str) || strcmp(str, "out") == 0);
	if ((str = spa_dict_lookup(innode->info->props, PW_KEY_NODE_PASSIVE)) != NULL)
		passive |= (pw_properties_parse_bool(str) || strcmp(str, "in") == 0);

	props = pw_properties_new(NULL, NULL);
	pw_properties_setf(props, PW_KEY_LINK_OUTPUT_NODE, "%d", outnode->obj.id);
	pw_properties_setf(props, PW_KEY_LINK_INPUT_NODE, "%d", innode->obj.id);
	pw_properties_setf(props, PW_KEY_LINK_PASSIVE, "%s", passive ? "true" : "false");

	spa_list_for_each(inport, &innode->port_list, link)
		inport->visited = false;

	spa_list_for_each(outport, &outnode->port_list, link) {
		struct link *l;
		struct pw_proxy *p;

		if (outport->direction != PW_DIRECTION_OUTPUT)
			continue;

		inport = find_input_port(impl, outnode, outport, innode);
		if (inport == NULL) {
			pw_log_debug(NAME" %p: port %d:%d can't be linked", impl,
				outport->direction, outport->obj.id);
			continue;
		}
		inport->visited = true;

		pw_log_debug(NAME" %p: port %d:%d -> %d:%d", impl,
				outport->direction, outport->obj.id,
				inport->direction, inport->obj.id);

		pw_properties_setf(props, PW_KEY_LINK_OUTPUT_PORT, "%d", outport->obj.id);
		pw_properties_setf(props, PW_KEY_LINK_INPUT_PORT, "%d", inport->obj.id);

		p = pw_core_create_object(impl->policy_core,
					"link-factory",
					PW_TYPE_INTERFACE_Link,
					PW_VERSION_LINK,
					&props->dict, sizeof(struct link));
		if (p == NULL)
			return -errno;

		l = pw_proxy_get_user_data(p);
		l->proxy = p;
		l->output_node = outnode->obj.id;
		l->output_port = outport->obj.id;
		l->input_node = innode->obj.id;
		l->input_port = inport->obj.id;
		pw_proxy_add_listener(p, &l->listener, &proxy_link_events, l);
		count++;

		if (link) {
			l->endpoint_link = link;
			spa_list_append(&link->link_list, &l->link);
		} else {
			spa_list_append(&impl->link_list, &l->link);
		}
	}
	pw_properties_free(props);

	return count;
}


int sm_media_session_create_links(struct sm_media_session *sess,
		const struct spa_dict *dict)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_object *obj;
	struct sm_node *outnode = NULL, *innode = NULL;
	struct sm_endpoint *outendpoint = NULL, *inendpoint = NULL;
	struct sm_endpoint_stream *outstream = NULL, *instream = NULL;
	struct endpoint_link *link = NULL;
	const char *str;
	int res;

	sm_media_session_roundtrip(sess);

	/* find output node */
	if ((str = spa_dict_lookup(dict, PW_KEY_LINK_OUTPUT_NODE)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Node)) != NULL)
		outnode = (struct sm_node*)obj;

	/* find input node */
	if ((str = spa_dict_lookup(dict, PW_KEY_LINK_INPUT_NODE)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Node)) != NULL)
		innode = (struct sm_node*)obj;

	/* find endpoints and streams */
	if ((str = spa_dict_lookup(dict, PW_KEY_ENDPOINT_LINK_OUTPUT_ENDPOINT)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Endpoint)) != NULL)
		outendpoint = (struct sm_endpoint*)obj;

	if ((str = spa_dict_lookup(dict, PW_KEY_ENDPOINT_LINK_OUTPUT_STREAM)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_EndpointStream)) != NULL)
		outstream = (struct sm_endpoint_stream*)obj;

	if ((str = spa_dict_lookup(dict, PW_KEY_ENDPOINT_LINK_INPUT_ENDPOINT)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Endpoint)) != NULL)
		inendpoint = (struct sm_endpoint*)obj;

	if ((str = spa_dict_lookup(dict, PW_KEY_ENDPOINT_LINK_INPUT_STREAM)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_EndpointStream)) != NULL)
		instream = (struct sm_endpoint_stream*)obj;

	if (outendpoint != NULL && inendpoint != NULL) {
		link = calloc(1, sizeof(struct endpoint_link));
		if (link == NULL)
			return -errno;

		link->id = pw_map_insert_new(&impl->endpoint_links, link);
		link->impl = impl;
		spa_list_init(&link->link_list);
		spa_list_append(&impl->endpoint_link_list, &link->link);

		link->info.version = PW_VERSION_ENDPOINT_LINK_INFO;
		link->info.id = link->id;
		link->info.session_id = impl->this.session->obj.id;
		link->info.output_endpoint_id = outendpoint->info->id;
		link->info.output_stream_id = outstream ? outstream->info->id : SPA_ID_INVALID;
		link->info.input_endpoint_id = inendpoint->info->id;
		link->info.input_stream_id = instream ?  instream->info->id : SPA_ID_INVALID;
		link->info.change_mask =
			PW_ENDPOINT_LINK_CHANGE_MASK_STATE |
			PW_ENDPOINT_LINK_CHANGE_MASK_PROPS;
		link->info.state = PW_ENDPOINT_LINK_STATE_ACTIVE;
		link->info.props = (struct spa_dict*) dict;
	}

	/* link the nodes, record the link proxies in the endpoint_link */
	if (outnode != NULL && innode != NULL)
		res = link_nodes(impl, link, outnode, innode);
	else
		res = 0;

	if (link != NULL) {
		/* now create the endpoint link */
		pw_client_session_link_update(impl->this.client_session,
				link->id,
				PW_CLIENT_SESSION_UPDATE_INFO,
				0, NULL,
				&link->info);
	}
	return res;
}

int sm_media_session_remove_links(struct sm_media_session *sess,
		const struct spa_dict *dict)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	struct sm_object *obj;
	struct sm_node *outnode = NULL, *innode = NULL;
	const char *str;
	struct link *l, *t;

	/* find output node */
	if ((str = spa_dict_lookup(dict, PW_KEY_LINK_OUTPUT_NODE)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Node)) != NULL)
		outnode = (struct sm_node*)obj;

	/* find input node */
	if ((str = spa_dict_lookup(dict, PW_KEY_LINK_INPUT_NODE)) != NULL &&
	    (obj = find_object(impl, atoi(str), PW_TYPE_INTERFACE_Node)) != NULL)
		innode = (struct sm_node*)obj;

	if (innode == NULL || outnode == NULL)
		return -EINVAL;

	spa_list_for_each_safe(l, t, &impl->link_list, link) {
		if (l->output_node == outnode->obj.id && l->input_node == innode->obj.id) {
			pw_proxy_destroy(l->proxy);
		}
	}
	return 0;
}

int sm_media_session_load_conf(struct sm_media_session *sess, const char *name,
		struct pw_properties *conf)
{
	return pw_conf_load_conf(SESSION_PREFIX, name, conf);
}

int sm_media_session_load_state(struct sm_media_session *sess,
		const char *name, struct pw_properties *props)
{
	return pw_conf_load_state(SESSION_PREFIX, name, props);
}

int sm_media_session_save_state(struct sm_media_session *sess,
		const char *name, const struct pw_properties *props)
{
	return pw_conf_save_state(SESSION_PREFIX, name, props);
}

char *sm_media_session_sanitize_name(char *name, int size, char sub, const char *fmt, ...)
{
	char *p;
	va_list varargs;

	va_start(varargs, fmt);
	if (vsnprintf(name, size, fmt, varargs) < 0)
		return NULL;
	va_end(varargs);

	for (p = name; *p; p++) {
		switch(*p) {
		case '0' ... '9':
		case 'a' ... 'z':
		case 'A' ... 'Z':
		case '.': case '-': case '_':
			break;
		default:
			*p = sub;
			break;
		}
	}
	return name;
}

char *sm_media_session_sanitize_description(char *name, int size, char sub, const char *fmt, ...)
{
	char *p;
	va_list varargs;

	va_start(varargs, fmt);
	if (vsnprintf(name, size, fmt, varargs) < 0)
		return NULL;
	va_end(varargs);

	for (p = name; *p; p++) {
		switch(*p) {
		case ':':
			*p = sub;
			break;
		}
	}
	return name;
}

int sm_media_session_seat_active_changed(struct sm_media_session *sess, bool active)
{
	struct impl *impl = SPA_CONTAINER_OF(sess, struct impl, this);
	if (active != impl->seat_active) {
		impl->seat_active = active;
		sm_media_session_emit_seat_active(impl, active);
	}
	return 0;
}

static void monitor_core_done(void *data, uint32_t id, int seq)
{
	struct impl *impl = data;

	if (id == 0)
		handle_postponed_registry_events(impl, seq);

	if (seq == impl->monitor_seq) {
		pw_log_debug(NAME " %p: monitor sync stop %d", impl, seq);
		pw_core_set_paused(impl->policy_core, false);
	}
}

static const struct pw_core_events monitor_core_events = {
	PW_VERSION_CORE_EVENTS,
	.done = monitor_core_done,
};

static int start_session(struct impl *impl)
{
	impl->monitor_core = pw_context_connect(impl->this.context, NULL, 0);
	if (impl->monitor_core == NULL) {
		pw_log_error("can't start monitor: %m");
		return -errno;
	}

	pw_core_add_listener(impl->monitor_core,
			&impl->monitor_listener,
			&monitor_core_events, impl);

	impl->monitor_registry = pw_core_get_registry(impl->monitor_core,
			PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(impl->monitor_registry,
			&impl->monitor_registry_listener,
			&monitor_registry_events, impl);

	return 0;
}

static void core_info(void *data, const struct pw_core_info *info)
{
	struct impl *impl = data;
	pw_log_debug(NAME" %p: info", impl);
	impl->this.info = pw_core_info_update(impl->this.info, info);

	if (impl->this.info->change_mask != 0)
		sm_media_session_emit_info(impl, impl->this.info);
	impl->this.info->change_mask = 0;
}

static void core_done(void *data, uint32_t id, int seq)
{
	struct impl *impl = data;
	struct sync *s, *t;
	impl->last_seq = seq;

	spa_list_for_each_safe(s, t, &impl->sync_list, link) {
		if (s->seq == seq) {
			spa_list_remove(&s->link);
			s->callback(s->data);
			free(s);
		}
	}
	if (impl->rescan_seq == seq) {
		struct sm_object *obj, *to;

		if (!impl->scanning) {
			pw_log_trace(NAME" %p: rescan %u %d", impl, id, seq);
			impl->scanning = true;
			sm_media_session_emit_rescan(impl, seq);
			impl->scanning = false;
			if (impl->rescan_pending) {
				impl->rescan_pending = false;
				sm_media_session_schedule_rescan(&impl->this);
			}
		}

		spa_list_for_each_safe(obj, to, &impl->object_list, link) {
			if (obj->id == SPA_ID_INVALID)
				continue;
			pw_log_trace(NAME" %p: obj %p %08x", impl, obj, obj->changed);
			if (obj->changed)
				sm_object_emit_update(obj);
			obj->changed = 0;
		}
	}
}

static void core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct impl *impl = data;

	pw_log(res == -ENOENT ? SPA_LOG_LEVEL_INFO : SPA_LOG_LEVEL_WARN,
			"error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE) {
		if (res == -EPIPE)
			pw_main_loop_quit(impl->loop);
	}
}


static const struct pw_core_events policy_core_events = {
	PW_VERSION_CORE_EVENTS,
	.info = core_info,
	.done = core_done,
	.error = core_error
};

static void policy_core_destroy(void *data)
{
	struct impl *impl = data;
	pw_log_debug(NAME" %p: policy core destroy", impl);
	impl->policy_core = NULL;
}

static const struct pw_proxy_events proxy_core_events = {
	PW_VERSION_PROXY_EVENTS,
	.destroy = policy_core_destroy,
};

static int start_policy(struct impl *impl)
{
	impl->policy_core = pw_context_connect(impl->this.context, NULL, 0);
	if (impl->policy_core == NULL) {
		pw_log_error("can't start policy: %m");
		return -errno;
	}

	pw_core_add_listener(impl->policy_core,
			&impl->policy_listener,
			&policy_core_events, impl);
	pw_proxy_add_listener((struct pw_proxy*)impl->policy_core,
			&impl->proxy_policy_listener,
			&proxy_core_events, impl);

	impl->registry = pw_core_get_registry(impl->policy_core,
			PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(impl->registry,
			&impl->registry_listener,
			&registry_events, impl);

	return 0;
}

static void session_shutdown(struct impl *impl)
{
	struct sm_object *obj;
	struct registry_event *re;
	struct spa_list free_list;

	pw_log_info(NAME" %p", impl);
	sm_media_session_emit_shutdown(impl);

	/*
	 * Monitors may still hold references to objects, which they
	 * drop in session destroy event, so don't free undiscarded
	 * objects yet. Destroy event handlers may remove any objects
	 * in the list, so iterate carefully.
	 */
	spa_list_init(&free_list);
	spa_list_consume(obj, &impl->object_list, link) {
		if (obj->destroyed) {
			spa_list_remove(&obj->link);
			spa_list_append(&free_list, &obj->link);
		} else {
			sm_object_destroy_maybe_free(obj);
		}
	}

	spa_list_consume(re, &impl->registry_event_list, link)
		registry_event_free(re);

	impl->this.metadata = NULL;

	sm_media_session_emit_destroy(impl);

	spa_list_consume(obj, &free_list, link)
		sm_object_destroy(obj);
	spa_list_consume(obj, &impl->object_list, link)
		sm_object_destroy(obj);  /* in case emit_destroy created new objects */

	if (impl->registry) {
		spa_hook_remove(&impl->registry_listener);
		pw_proxy_destroy((struct pw_proxy*)impl->registry);
	}
	if (impl->monitor_registry) {
		spa_hook_remove(&impl->monitor_registry_listener);
		pw_proxy_destroy((struct pw_proxy*)impl->monitor_registry);
	}
	if (impl->policy_core) {
		spa_hook_remove(&impl->policy_listener);
		spa_hook_remove(&impl->proxy_policy_listener);
		pw_core_disconnect(impl->policy_core);
	}
	if (impl->monitor_core) {
		spa_hook_remove(&impl->monitor_listener);
		pw_core_disconnect(impl->monitor_core);
	}
	if (impl->this.info)
		pw_core_info_free(impl->this.info);
}

static int sm_metadata_start(struct sm_media_session *sess)
{
	sess->metadata = sm_media_session_export_metadata(sess, "default");
	if (sess->metadata == NULL)
		return -errno;
	return 0;
}

static int sm_pulse_bridge_start(struct sm_media_session *sess)
{
	if (pw_context_load_module(sess->context,
			"libpipewire-module-protocol-pulse",
			NULL, NULL) == NULL)
		return -errno;
	return 0;
}

static void do_quit(void *data, int signal_number)
{
	struct impl *impl = data;
	pw_main_loop_quit(impl->loop);
}

static int collect_modules(struct impl *impl, const char *str)
{
	struct spa_json it[3];
	char key[512], value[512];
	const char *dir, *val;
	char check_path[PATH_MAX];
	struct stat statbuf;
	int count = 0;

	if ((dir = getenv("PIPEWIRE_CONFIG_DIR")) == NULL)
		dir = PIPEWIRE_CONFIG_DIR;
	if (dir == NULL)
		return -ENOENT;

again:
	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_object(&it[0], &it[1]) < 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], key, sizeof(key)-1) > 0) {
		bool add = false;

		if (key[0] == '#') {
			add = false;
		} else if (pw_properties_get(impl->modules, key) != NULL) {
			add = true;
		} else {
			snprintf(check_path, sizeof(check_path),
					"%s/"SESSION_PREFIX"/%s", dir, key);
			add = (stat(check_path, &statbuf) == 0);
		}
		if (add) {
			if (spa_json_enter_array(&it[1], &it[2]) < 0)
				continue;

			while (spa_json_get_string(&it[2], value, sizeof(value)-1) > 0) {
				if (value[0] == '#')
					continue;
				pw_properties_set(impl->modules, value, "true");
			}
		}
		else if (spa_json_next(&it[1], &val) <= 0)
			break;
	}
	/* twice to resolve groups in module list */
	if (count++ == 0)
		goto again;

	return 0;
}

static const struct {
	const char *name;
	const char *desc;
	int (*start)(struct sm_media_session *sess);
	const char *props;

} modules[] = {
	{ "flatpak", "manage flatpak access", sm_access_flatpak_start, NULL },
	{ "portal", "manage portal permissions", sm_access_portal_start, NULL },
	{ "metadata", "export metadata API", sm_metadata_start, NULL },
	{ "default-nodes", "restore default nodes", sm_default_nodes_start, NULL },
	{ "default-profile", "restore default profiles", sm_default_profile_start, NULL },
	{ "default-routes", "restore default route", sm_default_routes_start, NULL },
	{ "restore-stream", "restore stream settings", sm_restore_stream_start, NULL },
	{ "streams-follow-default", "move streams when default changes", sm_streams_follow_default_start, NULL },
	{ "alsa-seq", "alsa seq midi support", sm_alsa_midi_start, NULL },
	{ "alsa-monitor", "alsa card udev detection", sm_alsa_monitor_start, NULL },
	{ "v4l2", "video for linux udev detection", sm_v4l2_monitor_start, NULL },
	{ "libcamera", "libcamera udev detection", sm_libcamera_monitor_start, NULL },
	{ "bluez5", "bluetooth support", sm_bluez5_monitor_start, NULL },
	{ "suspend-node", "suspend inactive nodes", sm_suspend_node_start, NULL },
	{ "policy-node", "configure and link nodes", sm_policy_node_start, NULL },
	{ "pulse-bridge", "accept pulseaudio clients", sm_pulse_bridge_start, NULL },
#ifdef HAVE_SYSTEMD
	{ "logind", "systemd-logind seat support", sm_logind_start, NULL },
#endif
};

static bool is_module_enabled(struct impl *impl, const char *val)
{
	const char *str = pw_properties_get(impl->modules, val);
	return str ? pw_properties_parse_bool(str) : false;
}

static void show_help(const char *name, struct impl *impl, const char *config_name)
{
	size_t i;

        fprintf(stdout, "%s [options]\n"
		"  -h, --help                            Show this help\n"
		"      --version                         Show version\n"
		"  -c, --config                          Load config (Default %s)\n",
		name, config_name);

	fprintf(stdout, "\noptions: (*=enabled)\n");
	for (i = 0; i < SPA_N_ELEMENTS(modules); i++) {
		fprintf(stdout, "\t  %c %-15.15s: %s\n",
				is_module_enabled(impl, modules[i].name) ? '*' : ' ',
				modules[i].name, modules[i].desc);
	}
}

int main(int argc, char *argv[])
{
	struct impl impl = { .seat_active = true };
	const struct spa_support *support;
	const char *str, *config_name = SESSION_CONF;
	bool do_show_help = false;
	uint32_t n_support;
	int res = 0, c;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "config",	required_argument,	NULL, 'c' },
		{ NULL, 0, NULL, 0}
	};
        size_t i;
	const struct spa_dict_item *item;

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVc:", long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			do_show_help = true;
			break;
		case 'V':
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				argv[0],
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;
		case 'c':
			config_name = optarg;
			break;
		default:
			return -1;
		}
	}

	impl.this.props = pw_properties_new(
			PW_KEY_CONFIG_PREFIX, SESSION_PREFIX,
			PW_KEY_CONFIG_NAME, config_name,
			NULL);
	if (impl.this.props == NULL)
		return -1;

	if ((impl.conf = pw_properties_new(NULL, NULL)) == NULL)
		return -1;

	pw_conf_load_conf(SESSION_PREFIX, config_name, impl.conf);

	if ((str = pw_properties_get(impl.conf, "context.properties")) != NULL)
		pw_properties_update_string(impl.this.props, str, strlen(str));

	if ((impl.modules = pw_properties_new("default", "true", NULL)) == NULL)
		return -1;
	if ((str = pw_properties_get(impl.conf, "session.modules")) != NULL)
		collect_modules(&impl, str);

	if (do_show_help) {
		show_help(argv[0], &impl, config_name);
		return 0;
	}

	spa_dict_for_each(item, &impl.this.props->dict)
		pw_log_info("  '%s' = '%s'", item->key, item->value);

	impl.loop = pw_main_loop_new(NULL);
	if (impl.loop == NULL)
		return -1;
	impl.this.loop = pw_main_loop_get_loop(impl.loop);

	pw_loop_add_signal(impl.this.loop, SIGINT, do_quit, &impl);
	pw_loop_add_signal(impl.this.loop, SIGTERM, do_quit, &impl);

	impl.this.context = pw_context_new(impl.this.loop,
				pw_properties_copy(impl.this.props),
				0);

	if (impl.this.context == NULL)
		return -1;

	pw_context_set_object(impl.this.context, SM_TYPE_MEDIA_SESSION, &impl);

	pw_map_init(&impl.globals, 64, 64);
	spa_list_init(&impl.object_list);
	spa_list_init(&impl.registry_event_list);
	spa_list_init(&impl.link_list);
	pw_map_init(&impl.endpoint_links, 64, 64);
	spa_list_init(&impl.endpoint_link_list);
	spa_list_init(&impl.sync_list);
	spa_hook_list_init(&impl.hooks);

	support = pw_context_get_support(impl.this.context, &n_support);

	impl.dbus = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DBus);
	if (impl.dbus) {
		impl.this.dbus_connection = spa_dbus_get_connection(impl.dbus, SPA_DBUS_TYPE_SESSION);
		if (impl.this.dbus_connection == NULL)
			pw_log_warn("no dbus connection");
		else
			pw_log_debug("got dbus connection %p", impl.this.dbus_connection);
	} else {
		pw_log_info("dbus disabled");
	}

	if ((res = start_session(&impl)) < 0)
		goto exit;
	if ((res = start_policy(&impl)) < 0)
		goto exit;

	for (i = 0; i < SPA_N_ELEMENTS(modules); i++) {
		const char *name = modules[i].name;
		if (is_module_enabled(&impl, name)) {
			pw_log_info("enable: %s", name);
			modules[i].start(&impl.this);
		}
	}

//	sm_session_manager_start(&impl.this);

	pw_main_loop_run(impl.loop);

exit:
	session_shutdown(&impl);

	pw_context_destroy(impl.this.context);
	pw_main_loop_destroy(impl.loop);

	pw_map_clear(&impl.endpoint_links);
	pw_map_clear(&impl.globals);
	pw_properties_free(impl.this.props);
	pw_properties_free(impl.conf);
	pw_properties_free(impl.modules);

	pw_deinit();

	return res;
}
