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
#include <spa/param/props.h>
#include <spa/debug/dict.h>
#include <spa/pod/builder.h>

#include "pipewire/pipewire.h"

#include "media-session.h"

struct device;

struct node {
	struct impl *impl;
	struct device *device;
	struct spa_list link;
	uint32_t id;

	struct pw_properties *props;

	struct pw_proxy *proxy;
	struct spa_node *node;
};

struct device {
	struct impl *impl;
	struct spa_list link;
	uint32_t id;
	uint32_t device_id;

	int priority;
	int profile;

	struct pw_properties *props;

	struct spa_handle *handle;
	struct spa_device *device;
	struct spa_hook device_listener;

	struct sm_device *sdevice;
	struct spa_hook listener;

	unsigned int appeared:1;
	struct spa_list node_list;
};

struct impl {
	struct sm_media_session *session;
	struct spa_hook session_listener;

	struct spa_handle *handle;
	struct spa_device *monitor;
	struct spa_hook listener;

	struct spa_list device_list;
};

static struct node *libcamera_find_node(struct device *dev, uint32_t id)
{
	struct node *node;

	spa_list_for_each(node, &dev->node_list, link) {
		if (node->id == id)
			return node;
	}
	return NULL;
}

static void libcamera_update_node(struct device *dev, struct node *node,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update node %u", node->id);

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(node->props, info->props);
}

static struct node *libcamera_create_node(struct device *dev, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct node *node;
	struct impl *impl = dev->impl;
	int res;
	const char *str;

	pw_log_debug("new node %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Node) != 0) {
		errno = EINVAL;
		return NULL;
	}
	node = calloc(1, sizeof(*node));
	if (node == NULL) {
		res = -errno;
		goto exit;
	}

	node->props = pw_properties_new_dict(info->props);

	pw_properties_setf(node->props, PW_KEY_DEVICE_ID, "%d", dev->device_id);

	str = pw_properties_get(dev->props, SPA_KEY_DEVICE_NAME);
	if (str == NULL)
		str = pw_properties_get(dev->props, SPA_KEY_DEVICE_NICK);
	if (str == NULL)
		str = pw_properties_get(dev->props, SPA_KEY_DEVICE_ALIAS);
	if (str == NULL)
		str = "libcamera-device";
	pw_properties_setf(node->props, PW_KEY_NODE_NAME, "%s.%s", info->factory_name, str);

	str = pw_properties_get(dev->props, SPA_KEY_DEVICE_DESCRIPTION);
	if (str == NULL)
		str = "libcamera-device";
	pw_properties_set(node->props, PW_KEY_NODE_DESCRIPTION, str);

	pw_properties_set(node->props, PW_KEY_FACTORY_NAME, info->factory_name);

	node->impl = impl;
	node->device = dev;
	node->id = id;
	node->proxy = sm_media_session_create_object(impl->session,
				"spa-node-factory",
				PW_TYPE_INTERFACE_Node,
				PW_VERSION_NODE,
				&node->props->dict,
                                0);
	if (node->proxy == NULL) {
		res = -errno;
		goto clean_node;
	}

	spa_list_append(&dev->node_list, &node->link);

	return node;

clean_node:
	pw_properties_free(node->props);
	free(node);
exit:
	errno = -res;
	return NULL;
}

static void libcamera_remove_node(struct device *dev, struct node *node)
{
	pw_log_debug("remove node %u", node->id);
	spa_list_remove(&node->link);
	pw_proxy_destroy(node->proxy);
	pw_properties_free(node->props);
	free(node);
}

static void libcamera_device_info(void *data, const struct spa_device_info *info)
{
	struct device *dev = data;

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(dev->props, info->props);
}

static void libcamera_device_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct device *dev = data;
	struct node *node;

	node = libcamera_find_node(dev, id);

	if (info == NULL) {
		if (node == NULL) {
			pw_log_warn("device %p: unknown node %u", dev, id);
			return;
		}
		libcamera_remove_node(dev, node);
	} else if (node == NULL) {
		libcamera_create_node(dev, id, info);
	} else {
		libcamera_update_node(dev, node, info);
	}
}

static const struct spa_device_events libcamera_device_events = {
	SPA_VERSION_DEVICE_EVENTS,
	.info = libcamera_device_info,
	.object_info = libcamera_device_object_info
};

static struct device *libcamera_find_device(struct impl *impl, uint32_t id)
{
	struct device *dev;

	spa_list_for_each(dev, &impl->device_list, link) {
		if (dev->id == id)
			return dev;
	}
	return NULL;
}

static void libcamera_update_device(struct impl *impl, struct device *dev,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update device %u", dev->id);

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(dev->props, info->props);
}

static int libcamera_update_device_props(struct device *dev)
{
	struct pw_properties *p = dev->props;
	const char *s, *d;
	char temp[32];

	if ((s = pw_properties_get(p, SPA_KEY_DEVICE_NAME)) == NULL) {
		if ((s = pw_properties_get(p, SPA_KEY_DEVICE_BUS_ID)) == NULL) {
			if ((s = pw_properties_get(p, SPA_KEY_DEVICE_BUS_PATH)) == NULL) {
				snprintf(temp, sizeof(temp), "%d", dev->id);
				s = temp;
			}
		}
	}
	pw_properties_setf(p, PW_KEY_DEVICE_NAME, "libcamera_device.%s", s);

	if (pw_properties_get(p, PW_KEY_DEVICE_DESCRIPTION) == NULL) {
		d = pw_properties_get(p, PW_KEY_DEVICE_PRODUCT_NAME);
		if (!d)
			d = "Unknown device";

		pw_properties_set(p, PW_KEY_DEVICE_DESCRIPTION, d);
	}
	return 0;
}

static void set_profile(struct device *device, int index)
{
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));

	pw_log_debug("%p: set profile %d id:%d", device, index, device->device_id);

	device->profile = index;
	if (device->device_id != 0) {
		spa_device_set_param(device->device,
				SPA_PARAM_Profile, 0,
				spa_pod_builder_add_object(&b,
					SPA_TYPE_OBJECT_ParamProfile, SPA_PARAM_Profile,
					SPA_PARAM_PROFILE_index,   SPA_POD_Int(index)));
	}
}

static void device_destroy(void *data)
{
	struct device *device = data;
	struct node *node;

	pw_log_debug("device %p destroy", device);

	spa_list_consume(node, &device->node_list, link)
		libcamera_remove_node(device, node);
}

static void device_free(void *data)
{
	struct device *dev = data;
	pw_log_debug("remove device %u", dev->id);
	spa_list_remove(&dev->link);
	if (dev->appeared)
		spa_hook_remove(&dev->device_listener);
	sm_object_discard(&dev->sdevice->obj);
	spa_hook_remove(&dev->listener);
	pw_unload_spa_handle(dev->handle);
	pw_properties_free(dev->props);
	free(dev);
}

static void device_update(void *data)
{
	struct device *device = data;

	pw_log_debug("device %p appeared %d %d", device, device->appeared, device->profile);

	if (device->appeared)
		return;

	device->device_id = device->sdevice->obj.id;
	device->appeared = true;

	spa_device_add_listener(device->device,
		&device->device_listener,
		&libcamera_device_events, device);

	set_profile(device, 1);
	sm_object_sync_update(&device->sdevice->obj);
}

static const struct sm_object_events device_events = {
	SM_VERSION_OBJECT_EVENTS,
        .destroy = device_destroy,
        .free = device_free,
        .update = device_update,
};


static struct device *libcamera_create_device(struct impl *impl, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct pw_context *context = impl->session->context;
	struct device *dev;
	struct spa_handle *handle;
	int res;
	void *iface;

	pw_log_debug("new device %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Device) != 0) {
		errno = EINVAL;
		return NULL;
	}

	handle = pw_context_load_spa_handle(context,
			info->factory_name,
			info->props);
	if (handle == NULL) {
		res = -errno;
		pw_log_error("can't make factory instance: %m");
		goto exit;
	}

	if ((res = spa_handle_get_interface(handle, info->type, &iface)) < 0) {
		pw_log_error("can't get %s interface: %s", info->type, spa_strerror(res));
		goto unload_handle;
	}

	dev = calloc(1, sizeof(*dev));
	if (dev == NULL) {
		res = -errno;
		goto unload_handle;
	}

	dev->impl = impl;
	dev->id = id;
	dev->handle = handle;
	dev->device = iface;
	dev->props = pw_properties_new_dict(info->props);
	libcamera_update_device_props(dev);

	dev->sdevice = sm_media_session_export_device(impl->session,
			&dev->props->dict, dev->device);

	if (dev->sdevice == NULL) {
		res = -errno;
		goto clean_device;
	}

	pw_log_debug("got object %p", &dev->sdevice->obj);

	sm_object_add_listener(&dev->sdevice->obj,
			&dev->listener,
			&device_events, dev);

	spa_list_init(&dev->node_list);
	spa_list_append(&impl->device_list, &dev->link);

	return dev;

clean_device:
	free(dev);
unload_handle:
	pw_unload_spa_handle(handle);
exit:
	errno = -res;
	return NULL;
}

static void libcamera_remove_device(struct impl *impl, struct device *dev)
{
	sm_object_destroy(&dev->sdevice->obj);
}

static void libcamera_udev_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct impl *impl = data;
	struct device *dev = NULL;

	dev = libcamera_find_device(impl, id);

	if (info == NULL) {
		if (dev == NULL)
			return;
		libcamera_remove_device(impl, dev);
	} else if (dev == NULL) {
		if (libcamera_create_device(impl, id, info) == NULL)
			return;
	} else {
		libcamera_update_device(impl, dev, info);
	}
}

static const struct spa_device_events libcamera_udev_callbacks =
{
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = libcamera_udev_object_info,
};

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->session_listener);
	spa_hook_remove(&impl->listener);
	pw_unload_spa_handle(impl->handle);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.destroy = session_destroy,
};

int sm_libcamera_monitor_start(struct sm_media_session *sess)
{
	struct pw_context *context = sess->context;
	struct impl *impl;
	int res;
	void *iface;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = sess;

	impl->handle = pw_context_load_spa_handle(context, SPA_NAME_API_LIBCAMERA_ENUM_CLIENT, NULL);
	if (impl->handle == NULL) {
		res = -errno;
		goto out_free;
	}

	if ((res = spa_handle_get_interface(impl->handle, SPA_TYPE_INTERFACE_Device, &iface)) < 0) {
		pw_log_error("can't get MONITOR interface: %d", res);
		goto out_unload;
	}

	impl->monitor = iface;
	spa_list_init(&impl->device_list);

	spa_device_add_listener(impl->monitor, &impl->listener,
			&libcamera_udev_callbacks, impl);

	sm_media_session_add_listener(sess, &impl->session_listener, &session_events, impl);

	return 0;

out_unload:
	pw_unload_spa_handle(impl->handle);
out_free:
	free(impl);
	return res;
}
