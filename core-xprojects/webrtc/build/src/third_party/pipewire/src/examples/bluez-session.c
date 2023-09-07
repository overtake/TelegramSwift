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

#include <spa/monitor/device.h>
#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/dict.h>

#include "pipewire/pipewire.h"

#define NAME "media-session"

struct impl;
struct object;

struct node {
	struct impl *impl;
	struct object *object;
	struct spa_list link;
	uint32_t id;

	struct spa_handle *handle;
	struct pw_proxy *proxy;
	struct spa_node *node;
};

struct object {
	struct impl *impl;
	struct spa_list link;
	uint32_t id;

	struct spa_handle *handle;
	struct pw_proxy *proxy;
	struct spa_device *device;
	struct spa_hook listener;

	struct spa_list node_list;
};

struct impl {
	struct timespec now;

	struct pw_main_loop *loop;
	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct spa_handle *handle;
	struct spa_device *device;
	struct spa_hook listener;

	struct spa_list device_list;
};

static struct node *find_node(struct object *obj, uint32_t id)
{
	struct node *node;

	spa_list_for_each(node, &obj->node_list, link) {
		if (node->id == id)
			return node;
	}
	return NULL;
}

static void update_node(struct object *obj, struct node *node,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update node %u", node->id);
	spa_debug_dict(0, info->props);
}

static struct node *create_node(struct object *obj, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct node *node;
	struct impl *impl = obj->impl;
	struct pw_context *context = impl->context;
	struct spa_handle *handle;
	int res;
	void *iface;

	pw_log_debug("new node %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Node) != 0)
		return NULL;

	handle = pw_context_load_spa_handle(context,
			info->factory_name,
			info->props);
	if (handle == NULL) {
		pw_log_error("can't make factory instance: %m");
		goto exit;
	}

	if ((res = spa_handle_get_interface(handle, info->type, &iface)) < 0) {
		pw_log_error("can't get %s interface: %s", info->type, spa_strerror(res));
		goto unload_handle;
	}

	node = calloc(1, sizeof(*node));
	if (node == NULL)
		goto unload_handle;

	node->impl = impl;
	node->object = obj;
	node->id = id;
	node->handle = handle;
	node->node = iface;
	node->proxy = pw_core_export(impl->core,
			info->type, info->props, node->node, 0);
	if (node->proxy == NULL)
		goto clean_node;

	spa_list_append(&obj->node_list, &node->link);

	update_node(obj, node, info);

	return node;

clean_node:
	free(node);
unload_handle:
	pw_unload_spa_handle(handle);
exit:
	return NULL;
}

static void remove_node(struct object *obj, struct node *node)
{
	pw_log_debug("remove node %u", node->id);
	spa_list_remove(&node->link);
	pw_proxy_destroy(node->proxy);
	free(node->handle);
	free(node);
}

static void device_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct object *obj = data;
	struct node *node;

	node = find_node(obj, id);

	if (info == NULL) {
		if (node == NULL) {
			pw_log_warn("object %p: unknown node %u", obj, id);
			return;
		}
		remove_node(obj, node);
	} else if (node == NULL) {
		create_node(obj, id, info);
	} else {
		update_node(obj, node, info);
	}

}

static const struct spa_device_events device_events = {
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = device_object_info
};

static struct object *find_object(struct impl *impl, uint32_t id)
{
	struct object *obj;

	spa_list_for_each(obj, &impl->device_list, link) {
		if (obj->id == id)
			return obj;
	}
	return NULL;
}

static void update_object(struct impl *impl, struct object *obj,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update object %u", obj->id);
	spa_debug_dict(0, info->props);
}

static struct object *create_object(struct impl *impl, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct pw_context *context = impl->context;
	struct object *obj;
	struct spa_handle *handle;
	int res;
	void *iface;

	pw_log_debug("new object %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Device) != 0)
		return NULL;

	handle = pw_context_load_spa_handle(context,
			info->factory_name,
			info->props);
	if (handle == NULL) {
		pw_log_error("can't make factory instance: %m");
		goto exit;
	}

	if ((res = spa_handle_get_interface(handle, info->type, &iface)) < 0) {
		pw_log_error("can't get %s interface: %s", info->type, spa_strerror(res));
		goto unload_handle;
	}

	obj = calloc(1, sizeof(*obj));
	if (obj == NULL)
		goto unload_handle;

	obj->impl = impl;
	obj->id = id;
	obj->handle = handle;
	obj->device = iface;
	obj->proxy = pw_core_export(impl->core,
			info->type, info->props, obj->device, 0);
	if (obj->proxy == NULL)
		goto clean_object;

	spa_list_init(&obj->node_list);

	spa_device_add_listener(obj->device,
			&obj->listener, &device_events, obj);

	spa_list_append(&impl->device_list, &obj->link);

	update_object(impl, obj, info);

	return obj;

clean_object:
	free(obj);
unload_handle:
	pw_unload_spa_handle(handle);
exit:
	return NULL;
}

static void remove_object(struct impl *impl, struct object *obj)
{
	pw_log_debug("remove object %u", obj->id);
	spa_list_remove(&obj->link);
	spa_hook_remove(&obj->listener);
	pw_proxy_destroy(obj->proxy);
	free(obj->handle);
	free(obj);
}

static void dbus_device_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct impl *impl = data;
	struct object *obj;

	obj = find_object(impl, id);

	if (info == NULL) {
		if (obj == NULL)
			return;
		remove_object(impl, obj);
	} else if (obj == NULL) {
		if (create_object(impl, id, info) == NULL)
			return;
	} else {
		update_object(impl, obj, info);
	}
}

static const struct spa_device_events dbus_device_events =
{
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = dbus_device_object_info,
};

static int start_monitor(struct impl *impl)
{
	struct spa_handle *handle;
	int res;
	void *iface;

	handle = pw_context_load_spa_handle(impl->context, SPA_NAME_API_BLUEZ5_ENUM_DBUS, NULL);
	if (handle == NULL) {
		res = -errno;
		goto out;
	}

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Device, &iface)) < 0) {
		pw_log_error("can't get MONITOR interface: %d", res);
		goto out_unload;
	}

	impl->handle = handle;
	impl->device = iface;

	spa_device_add_listener(impl->device, &impl->listener, &dbus_device_events, impl);

	return 0;

      out_unload:
	pw_unload_spa_handle(handle);
      out:
	return res;
}

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct impl *impl = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE)
		pw_main_loop_quit(impl->loop);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
};

int main(int argc, char *argv[])
{
	struct impl impl = { 0, };
	int res;

	pw_init(&argc, &argv);

	impl.loop = pw_main_loop_new(NULL);
	impl.context = pw_context_new(pw_main_loop_get_loop(impl.loop), NULL, 0);

	clock_gettime(CLOCK_MONOTONIC, &impl.now);

	spa_list_init(&impl.device_list);

        impl.core = pw_context_connect(impl.context, NULL, 0);
	if (impl.core == NULL) {
		pw_log_error(NAME" %p: can't connect %m", &impl);
		return -1;
	}

	pw_core_add_listener(impl.core,
			&impl.core_listener,
			&core_events, &impl);

	if ((res = start_monitor(&impl)) < 0) {
		pw_log_error(NAME" %p: error starting monitor: %s", &impl, spa_strerror(res));
		return -1;
	}

	pw_main_loop_run(impl.loop);

	pw_context_destroy(impl.context);
	pw_main_loop_destroy(impl.loop);

	return 0;
}
