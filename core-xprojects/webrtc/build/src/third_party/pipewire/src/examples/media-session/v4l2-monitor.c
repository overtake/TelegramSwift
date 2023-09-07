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

#define SESSION_CONF	"v4l2-monitor.conf"

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

	struct pw_properties *conf;

	struct spa_handle *handle;
	struct spa_device *monitor;
	struct spa_hook listener;

	struct spa_list device_list;
};

static struct node *v4l2_find_node(struct device *dev, uint32_t id, const char *name)
{
	struct node *node;
	const char *str;

	spa_list_for_each(node, &dev->node_list, link) {
		if (node->id == id)
			return node;
		if (name != NULL &&
		    (str = pw_properties_get(node->props, PW_KEY_NODE_NAME)) != NULL &&
		    strcmp(name, str) == 0)
			return node;
	}
	return NULL;
}

static void v4l2_update_node(struct device *dev, struct node *node,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update node %u", node->id);

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(node->props, info->props);
}

static struct node *v4l2_create_node(struct device *dev, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct node *node;
	struct impl *impl = dev->impl;
	int i, res;
	const char *prefix, *str, *d, *rules;
	char tmp[1024];

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
		str = "v4l2-device";
	if (strstr(str, "v4l2_device.") == str)
			str += 12;

	if (strstr(info->factory_name, "sink") != NULL)
		prefix = "v4l2_output";
	else if (strstr(info->factory_name, "source") != NULL)
		prefix = "v4l2_input";
	else
		prefix = info->factory_name;

	pw_properties_set(node->props, PW_KEY_NODE_NAME,
			sm_media_session_sanitize_name(tmp, sizeof(tmp),
					'_', "%s.%s", prefix, str));
	for (i = 2; i <= 99; i++) {
		if ((d = pw_properties_get(node->props, PW_KEY_NODE_NAME)) == NULL)
			break;

		if (v4l2_find_node(dev, SPA_ID_INVALID, d) == NULL)
			break;

		pw_properties_set(node->props, PW_KEY_NODE_NAME,
			sm_media_session_sanitize_name(tmp, sizeof(tmp),
					'_', "%s.%s.%d", prefix, str, i));
	}

	str = pw_properties_get(dev->props, SPA_KEY_DEVICE_DESCRIPTION);
	if (str == NULL)
		str = "v4l2-device";

	pw_properties_set(node->props, PW_KEY_NODE_DESCRIPTION,
		sm_media_session_sanitize_description(tmp, sizeof(tmp),
					' ', "%s", str));

	pw_properties_set(node->props, PW_KEY_FACTORY_NAME, info->factory_name);

	if ((rules = pw_properties_get(impl->conf, "rules")) != NULL)
		sm_media_session_match_rules(rules, strlen(rules), node->props);

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

static void v4l2_remove_node(struct device *dev, struct node *node)
{
	pw_log_debug("remove node %u", node->id);
	spa_list_remove(&node->link);
	pw_proxy_destroy(node->proxy);
	pw_properties_free(node->props);
	free(node);
}

static void v4l2_device_info(void *data, const struct spa_device_info *info)
{
	struct device *dev = data;

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(dev->props, info->props);
}

static void v4l2_device_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct device *dev = data;
	struct node *node;

	node = v4l2_find_node(dev, id, NULL);

	if (info == NULL) {
		if (node == NULL) {
			pw_log_warn("device %p: unknown node %u", dev, id);
			return;
		}
		v4l2_remove_node(dev, node);
	} else if (node == NULL) {
		v4l2_create_node(dev, id, info);
	} else {
		v4l2_update_node(dev, node, info);
	}
	sm_media_session_schedule_rescan(dev->impl->session);
}

static const struct spa_device_events v4l2_device_events = {
	SPA_VERSION_DEVICE_EVENTS,
	.info = v4l2_device_info,
	.object_info = v4l2_device_object_info
};

static struct device *v4l2_find_device(struct impl *impl, uint32_t id, const char *name)
{
	struct device *dev;
	const char *str;

	spa_list_for_each(dev, &impl->device_list, link) {
		if (dev->id == id)
			return dev;
		if (name != NULL &&
		    (str = pw_properties_get(dev->props, PW_KEY_DEVICE_NAME)) != NULL &&
		    strcmp(str, name) == 0)
			return dev;
	}
	return NULL;
}

static void v4l2_update_device(struct impl *impl, struct device *dev,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update device %u", dev->id);

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_properties_update(dev->props, info->props);
}

static int v4l2_update_device_props(struct device *dev)
{
	struct pw_properties *p = dev->props;
	const char *s, *d;
	char temp[32], tmp[1024];
	int i;

	if ((s = pw_properties_get(p, SPA_KEY_DEVICE_NAME)) == NULL) {
		if ((s = pw_properties_get(p, SPA_KEY_DEVICE_BUS_ID)) == NULL) {
			if ((s = pw_properties_get(p, SPA_KEY_DEVICE_BUS_PATH)) == NULL) {
				snprintf(temp, sizeof(temp), "%d", dev->id);
				s = temp;
			}
		}
	}
	pw_properties_set(p, PW_KEY_DEVICE_NAME,
			sm_media_session_sanitize_name(tmp, sizeof(tmp),
					'_', "v4l2_device.%s", s));

	for (i = 2; i <= 99; i++) {
		if ((d = pw_properties_get(p, PW_KEY_DEVICE_NAME)) == NULL)
			break;

		if (v4l2_find_device(dev->impl, SPA_ID_INVALID,  d) == NULL)
			break;

		pw_properties_set(p, PW_KEY_DEVICE_NAME,
			sm_media_session_sanitize_name(tmp, sizeof(tmp),
					'_', "v4l2_device.%s.%d", s, i));
	}
	if (i == 99)
		return -EEXIST;

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
	spa_list_remove(&device->link);

	spa_list_consume(node, &device->node_list, link)
		v4l2_remove_node(device, node);

	if (device->appeared)
		spa_hook_remove(&device->device_listener);
}

static void device_free(void *data)
{
	struct device *device = data;
	pw_log_debug("device %p free", device);
	spa_hook_remove(&device->listener);
	pw_unload_spa_handle(device->handle);
	pw_properties_free(device->props);
	sm_object_discard(&device->sdevice->obj);
	free(device);
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
		&v4l2_device_events, device);

	set_profile(device, 1);
	sm_object_sync_update(&device->sdevice->obj);
}

static const struct sm_object_events device_events = {
	SM_VERSION_OBJECT_EVENTS,
	.destroy = device_destroy,
	.free = device_free,
	.update = device_update,
};

static struct device *v4l2_create_device(struct impl *impl, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct pw_context *context = impl->session->context;
	struct device *dev;
	struct spa_handle *handle;
	int res;
	void *iface;
	const char *rules;

	pw_log_debug("new device %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Device) != 0) {
		errno = EINVAL;
		return NULL;
	}

	dev = calloc(1, sizeof(*dev));
	if (dev == NULL) {
		res = -errno;
		goto exit;
	}

	dev->impl = impl;
	dev->id = id;
	dev->props = pw_properties_new_dict(info->props);
	v4l2_update_device_props(dev);

	if ((rules = pw_properties_get(impl->conf, "rules")) != NULL)
		sm_media_session_match_rules(rules, strlen(rules), dev->props);

	handle = pw_context_load_spa_handle(context,
		info->factory_name,
		&dev->props->dict);
	if (handle == NULL) {
		res = -errno;
		pw_log_error("can't make factory instance: %m");
		goto clean_device;
	}

	if ((res = spa_handle_get_interface(handle, info->type, &iface)) < 0) {
		pw_log_error("can't get %s interface: %s", info->type, spa_strerror(res));
		goto unload_handle;
	}

	dev->handle = handle;
	dev->device = iface;

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

unload_handle:
	pw_unload_spa_handle(handle);
clean_device:
	pw_properties_free(dev->props);
	free(dev);
exit:
	errno = -res;
	return NULL;
}

static void v4l2_remove_device(struct impl *impl, struct device *dev)
{
	pw_log_debug("remove device %u", dev->id);
	if (dev->sdevice)
		sm_object_destroy(&dev->sdevice->obj);
}

static void v4l2_udev_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct impl *impl = data;
	struct device *dev;

	dev = v4l2_find_device(impl, id, NULL);

	if (info == NULL) {
		if (dev == NULL)
			return;
		v4l2_remove_device(impl, dev);
	} else if (dev == NULL) {
		if (v4l2_create_device(impl, id, info) == NULL)
			return;
	} else {
		v4l2_update_device(impl, dev, info);
	}
}

static const struct spa_device_events v4l2_udev_callbacks =
{
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = v4l2_udev_object_info,
};

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->session_listener);
	spa_hook_remove(&impl->listener);
	pw_unload_spa_handle(impl->handle);
	pw_properties_free(impl->conf);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.destroy = session_destroy,
};

int sm_v4l2_monitor_start(struct sm_media_session *sess)
{
	struct pw_context *context = sess->context;
	struct impl *impl;
	int res;
	void *iface;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->conf = pw_properties_new(NULL, NULL);
	if (impl->conf == NULL) {
		res = -errno;
		goto out_free;
	}
	impl->session = sess;

	impl->handle = pw_context_load_spa_handle(context, SPA_NAME_API_V4L2_ENUM_UDEV, NULL);
	if (impl->handle == NULL) {
		res = -errno;
		pw_log_info("can't load %s: %m", SPA_NAME_API_V4L2_ENUM_UDEV);
		goto out_free;
	}

	if ((res = spa_handle_get_interface(impl->handle, SPA_TYPE_INTERFACE_Device, &iface)) < 0) {
		pw_log_error("can't get MONITOR interface: %d", res);
		goto out_unload;
	}


	impl->monitor = iface;
	spa_list_init(&impl->device_list);

	if ((res = sm_media_session_load_conf(impl->session,
					SESSION_CONF, impl->conf)) < 0)
		pw_log_info("can't load "SESSION_CONF" config: %s", spa_strerror(res));

	spa_device_add_listener(impl->monitor, &impl->listener,
			&v4l2_udev_callbacks, impl);

	sm_media_session_add_listener(sess, &impl->session_listener, &session_events, impl);

	return 0;

out_unload:
	pw_unload_spa_handle(impl->handle);
out_free:
	free(impl);
	return res;
}
