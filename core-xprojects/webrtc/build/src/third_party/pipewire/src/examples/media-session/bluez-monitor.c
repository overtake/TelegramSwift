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
#include <spa/monitor/event.h>
#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/names.h>
#include <spa/utils/keys.h>
#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/param/props.h>
#include <spa/debug/dict.h>
#include <spa/debug/pod.h>

#include "pipewire/impl.h"
#include "media-session.h"

#define NAME		"bluez5-monitor"
#define SESSION_CONF	"bluez-monitor.conf"

struct device;

struct node {
	struct impl *impl;
	enum pw_direction direction;
	struct device *device;
	struct spa_list link;
	uint32_t id;

	struct pw_properties *props;

	struct pw_impl_node *adapter;

	struct sm_node *snode;
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

	bool have_info;
	bool seat_active;

	struct pw_properties *conf;
	struct pw_properties *props;

	struct spa_handle *handle;

	struct spa_device *monitor;
	struct spa_hook listener;

	struct spa_list device_list;
};

static struct node *bluez5_find_node(struct device *device, uint32_t id)
{
	struct node *node;

	spa_list_for_each(node, &device->node_list, link) {
		if (node->id == id)
			return node;
	}
	return NULL;
}

static void update_icon_name(struct pw_properties *p, bool is_sink)
{
	const char *s, *d = NULL, *bus;

	if ((s = pw_properties_get(p, PW_KEY_DEVICE_FORM_FACTOR))) {
		if (strcmp(s, "microphone") == 0)
			d = "audio-input-microphone";
		else if (strcmp(s, "webcam") == 0)
			d = "camera-web";
		else if (strcmp(s, "computer") == 0)
			d = "computer";
		else if (strcmp(s, "handset") == 0)
			d = "phone";
		else if (strcmp(s, "portable") == 0)
			d = "multimedia-player";
		else if (strcmp(s, "tv") == 0)
			d = "video-display";
		else if (strcmp(s, "headset") == 0)
			d = "audio-headset";
		else if (strcmp(s, "headphone") == 0)
			d = "audio-headphones";
		else if (strcmp(s, "speaker") == 0)
			d = "audio-speakers";
		else if (strcmp(s, "hands-free") == 0)
			d = "audio-handsfree";
	}
	if (!d)
		if ((s = pw_properties_get(p, PW_KEY_DEVICE_CLASS)))
			if (strcmp(s, "modem") == 0)
				d = "modem";

	if (!d) {
		if (is_sink)
			d = "audio-card";
		else
			d = "audio-input-microphone";
	}

	if ((s = pw_properties_get(p, "device.profile.name")) != NULL) {
		if (strstr(s, "analog"))
			s = "-analog";
		else if (strstr(s, "iec958"))
			s = "-iec958";
		else if (strstr(s, "hdmi"))
			s = "-hdmi";
		else
			s = NULL;
	}

	bus = pw_properties_get(p, PW_KEY_DEVICE_BUS);

	pw_properties_setf(p, PW_KEY_DEVICE_ICON_NAME,
			"%s%s%s%s", d, s ? s : "", bus ? "-" : "", bus ? bus : "");
}

static void bluez5_update_node(struct device *device, struct node *node,
		const struct spa_device_object_info *info)
{
	pw_log_debug("update node %u", node->id);

	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);
}

static struct node *bluez5_create_node(struct device *device, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct node *node;
	struct impl *impl = device->impl;
	struct pw_context *context = impl->session->context;
	struct pw_impl_factory *factory;
	int res;
	const char *prefix, *str, *profile, *rules;
	int priority;
	char tmp[1024];
	bool is_sink;

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

	if (pw_properties_get(node->props, PW_KEY_DEVICE_FORM_FACTOR) == NULL)
		pw_properties_set(node->props, PW_KEY_DEVICE_FORM_FACTOR,
				pw_properties_get(device->props, PW_KEY_DEVICE_FORM_FACTOR));
	if (pw_properties_get(node->props, PW_KEY_DEVICE_BUS) == NULL)
		pw_properties_set(node->props, PW_KEY_DEVICE_BUS,
				pw_properties_get(device->props, PW_KEY_DEVICE_BUS));

	str = pw_properties_get(device->props, SPA_KEY_DEVICE_DESCRIPTION);
	if (str == NULL)
		str = pw_properties_get(device->props, SPA_KEY_DEVICE_NAME);
	if (str == NULL)
		str = pw_properties_get(device->props, SPA_KEY_DEVICE_NICK);
	if (str == NULL)
		str = pw_properties_get(device->props, SPA_KEY_DEVICE_ALIAS);
	if (str == NULL)
		str = "bluetooth-device";

	pw_properties_setf(node->props, PW_KEY_DEVICE_ID, "%d", device->device_id);

	pw_properties_set(node->props, PW_KEY_NODE_DESCRIPTION,
		sm_media_session_sanitize_description(tmp, sizeof(tmp),
			' ', "%s", str));

	profile = pw_properties_get(node->props, SPA_KEY_API_BLUEZ5_PROFILE);
	if (profile == NULL)
		profile = "unknown";
	str = pw_properties_get(node->props, SPA_KEY_API_BLUEZ5_ADDRESS);
	if (str == NULL)
		str = pw_properties_get(device->props, SPA_KEY_DEVICE_NAME);

	is_sink = strstr(info->factory_name, "sink") != NULL;
	if (is_sink)
		prefix = "bluez_output";
	else if (strstr(info->factory_name, "source") != NULL)
		prefix = "bluez_input";
	else
		prefix = info->factory_name;

	pw_properties_set(node->props, PW_KEY_NODE_NAME,
		sm_media_session_sanitize_name(tmp, sizeof(tmp),
			'_', "%s.%s.%s", prefix, str, profile));

	pw_properties_set(node->props, PW_KEY_FACTORY_NAME, info->factory_name);

	if (pw_properties_get(node->props, PW_KEY_PRIORITY_DRIVER) == NULL) {
		priority = device->priority + 10;

		if (strstr(info->factory_name, "source") != NULL)
			priority += 1000;

		pw_properties_setf(node->props, PW_KEY_PRIORITY_DRIVER, "%d", priority);
		pw_properties_setf(node->props, PW_KEY_PRIORITY_SESSION, "%d", priority);
	}
	if (pw_properties_get(node->props, PW_KEY_DEVICE_ICON_NAME) == NULL)
		update_icon_name(node->props, is_sink);

	node->impl = impl;
	node->device = device;
	node->id = id;

	if ((rules = pw_properties_get(impl->conf, "rules")) != NULL)
		sm_media_session_match_rules(rules, strlen(rules), node->props);

	factory = pw_context_find_factory(context, "adapter");
	if (factory == NULL) {
		pw_log_error("no adapter factory found");
		res = -EIO;
		goto clean_node;
	}
	node->adapter = pw_impl_factory_create_object(factory,
			NULL,
			PW_TYPE_INTERFACE_Node,
			PW_VERSION_NODE,
			pw_properties_copy(node->props),
			0);
	if (node->adapter == NULL) {
		res = -errno;
		goto clean_node;
	}
	node->snode = sm_media_session_export_node(impl->session,
			&node->props->dict,
			node->adapter);
	if (node->snode == NULL) {
		res = -errno;
		goto clean_node;
	}

	spa_list_append(&device->node_list, &node->link);

	bluez5_update_node(device, node, info);

	return node;

clean_node:
	pw_properties_free(node->props);
	free(node);
exit:
	errno = -res;
	return NULL;
}

static void bluez5_remove_node(struct device *device, struct node *node)
{
	pw_log_debug("remove node %u", node->id);
	spa_list_remove(&node->link);
	sm_object_destroy(&node->snode->obj);
	pw_impl_node_destroy(node->adapter);
	pw_properties_free(node->props);
	free(node);
}

static void bluez5_device_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct device *device = data;
	struct node *node;

	node = bluez5_find_node(device, id);

	if (info == NULL) {
		if (node == NULL) {
			pw_log_warn("device %p: unknown node %u", device, id);
			return;
		}
		bluez5_remove_node(device, node);
	} else if (node == NULL) {
		bluez5_create_node(device, id, info);
	} else {
		bluez5_update_node(device, node, info);
	}

}

static void bluez_device_event(void *data, const struct spa_event *event)
{
	struct device *device = data;
	struct node *node;
	uint32_t id, type;
	struct spa_pod *props = NULL;

	if (spa_pod_parse_object(&event->pod,
			SPA_TYPE_EVENT_Device, &type,
			SPA_EVENT_DEVICE_Object, SPA_POD_Int(&id),
			SPA_EVENT_DEVICE_Props, SPA_POD_OPT_Pod(&props)) < 0)
		return;

	if ((node = bluez5_find_node(device, id)) == NULL) {
		pw_log_warn("device %p: unknown node %d", device, id);
		return;
	}

	switch (type) {
	case SPA_DEVICE_EVENT_ObjectConfig:
		if (props != NULL) {
			struct spa_node *adapter;
			adapter = pw_impl_node_get_implementation(node->adapter);
			spa_node_set_param(adapter, SPA_PARAM_Props, 0, props);
		}
		break;
	default:
		break;
	}
}

static const struct spa_device_events bluez5_device_events = {
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = bluez5_device_object_info,
	.event = bluez_device_event,
};

static struct device *bluez5_find_device(struct impl *impl, uint32_t id)
{
	struct device *device;

	spa_list_for_each(device, &impl->device_list, link) {
		if (device->id == id)
			return device;
	}
	return NULL;
}

static int update_device_props(struct device *device)
{
	struct pw_properties *p = device->props;
	const char *s;
	char temp[32], tmp[1024];

	s = pw_properties_get(p, SPA_KEY_DEVICE_NAME);
	if (s == NULL)
		s = pw_properties_get(p, SPA_KEY_API_BLUEZ5_ADDRESS);
	if (s == NULL)
		s = pw_properties_get(p, SPA_KEY_DEVICE_DESCRIPTION);
	if (s == NULL) {
		snprintf(temp, sizeof(temp), "%d", device->id);
		s = temp;
	}
	if (strstr(s, "bluez_card.") == s)
		s += strlen("bluez_card.");

	pw_properties_set(p, PW_KEY_DEVICE_NAME,
			sm_media_session_sanitize_name(tmp, sizeof(tmp),
					'_', "bluez_card.%s", s));

	if (pw_properties_get(p, SPA_KEY_DEVICE_ICON_NAME) == NULL)
		update_icon_name(p, true);

	return 0;
}

static void device_destroy(void *data)
{
	struct device *device = data;
	struct node *node;

	pw_log_debug("device %p destroy", device);

	spa_hook_remove(&device->listener);

	if (device->appeared) {
		device->appeared = false;
		spa_hook_remove(&device->device_listener);
	}

	spa_list_consume(node, &device->node_list, link)
		bluez5_remove_node(device, node);
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
		&bluez5_device_events, device);

	sm_object_sync_update(&device->sdevice->obj);
}

static const struct sm_object_events device_events = {
	SM_VERSION_OBJECT_EVENTS,
        .destroy = device_destroy,
        .update = device_update,
};

static struct device *bluez5_create_device(struct impl *impl, uint32_t id,
		const struct spa_device_object_info *info)
{
	struct pw_context *context = impl->session->context;
	struct device *device;
	struct spa_handle *handle;
	int res;
	void *iface;
	const char *rules, *str;

	pw_log_debug("new device %u", id);

	if (strcmp(info->type, SPA_TYPE_INTERFACE_Device) != 0) {
		errno = EINVAL;
		return NULL;
	}

	device = calloc(1, sizeof(*device));
	if (device == NULL) {
		res = -errno;
		goto exit;
	}

	device->impl = impl;
	device->id = id;
	device->priority = 1000;
	device->props = pw_properties_new_dict(info->props);
	update_device_props(device);

	spa_list_init(&device->node_list);

	if ((rules = pw_properties_get(impl->conf, "rules")) != NULL)
		sm_media_session_match_rules(rules, strlen(rules), device->props);

	/* Propagate the msbc-support global property if it exists and is not
	 * overloaded by a device specific one */
	if ((str = pw_properties_get(impl->props, "bluez5.msbc-support")) != NULL &&
	    pw_properties_get(device->props, "bluez5.msbc-support") == NULL)
		pw_properties_set(device->props, "bluez5.msbc-support", str);

	handle = pw_context_load_spa_handle(context,
		info->factory_name,
		&device->props->dict);
	if (handle == NULL) {
		res = -errno;
		pw_log_error("can't make factory instance: %m");
		goto clean_device;
	}

	if ((res = spa_handle_get_interface(handle, info->type, &iface)) < 0) {
		pw_log_error("can't get %s interface: %s", info->type, spa_strerror(res));
		goto unload_handle;
	}

	device->handle = handle;
	device->device = iface;

	spa_list_append(&impl->device_list, &device->link);

	return device;

unload_handle:
	pw_unload_spa_handle(handle);
clean_device:
	pw_properties_free(device->props);
	free(device);
exit:
	errno = -res;
	return NULL;
}

static void bluez5_device_free(struct device *device)
{
	if (device->sdevice) {
		sm_object_destroy(&device->sdevice->obj);
		device->sdevice = NULL;
	}
	spa_list_remove(&device->link);
	pw_unload_spa_handle(device->handle);
	pw_properties_free(device->props);
	free(device);
}

static void bluez5_remove_device(struct impl *impl, struct device *device)
{

	pw_log_debug("remove device %u", device->id);
	bluez5_device_free(device);
}

static void bluez5_update_device(struct impl *impl, struct device *device,
		const struct spa_device_object_info *info)
{
	bool connected;
	const char *str;
	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_dict(0, info->props);

	pw_log_debug("update device %u", device->id);

	pw_properties_update(device->props, info->props);
	update_device_props(device);

	str = spa_dict_lookup(info->props, SPA_KEY_API_BLUEZ5_CONNECTION);
	connected = str != NULL && strcmp(str, "connected") == 0;

	/* Export device after bluez profiles get connected */
	if (device->sdevice == NULL && connected) {
		device->sdevice = sm_media_session_export_device(impl->session,
					&device->props->dict, device->device);
		if (device->sdevice == NULL) {
			bluez5_device_free(device);
			return;
		}

		sm_object_add_listener(&device->sdevice->obj,
				&device->listener,
				&device_events, device);
	} else if (device->sdevice != NULL && !connected) {
		sm_object_destroy(&device->sdevice->obj);
		device->sdevice = NULL;
	}
}

static void bluez5_enum_object_info(void *data, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct impl *impl = data;
	struct device *device;

	device = bluez5_find_device(impl, id);

	if (info == NULL) {
		if (device == NULL)
			return;
		bluez5_remove_device(impl, device);
	} else if (device == NULL) {
		if (bluez5_create_device(impl, id, info) == NULL)
			return;
	} else {
		bluez5_update_device(impl, device, info);
	}
}

static const struct spa_device_events bluez5_enum_callbacks =
{
	SPA_VERSION_DEVICE_EVENTS,
	.object_info = bluez5_enum_object_info,
};

static void unload_bluez_handle(struct impl *impl)
{
	struct device *device;

	if (impl->handle == NULL)
		return;

	spa_list_consume(device, &impl->device_list, link)
		bluez5_device_free(device);

	spa_hook_remove(&impl->listener);

	pw_unload_spa_handle(impl->handle);
	impl->handle = NULL;
}

static int load_bluez_handle(struct impl *impl)
{
	struct pw_context *context = impl->session->context;
	void *iface;
	int res;

	if (impl->handle != NULL || !impl->seat_active || !impl->have_info)
		return 0;

	impl->handle = pw_context_load_spa_handle(context, SPA_NAME_API_BLUEZ5_ENUM_DBUS, &impl->props->dict);
	if (impl->handle == NULL) {
		res = -errno;
		pw_log_info("can't load %s: %m", SPA_NAME_API_BLUEZ5_ENUM_DBUS);
		goto fail;
	}
	if ((res = spa_handle_get_interface(impl->handle, SPA_TYPE_INTERFACE_Device, &iface)) < 0) {
		pw_log_error("can't get Device interface: %s", spa_strerror(res));
		goto fail;
	}
	impl->monitor = iface;

	spa_device_add_listener(impl->monitor, &impl->listener,
			&bluez5_enum_callbacks, impl);

	return 0;

fail:
	if (impl->handle)
		pw_unload_spa_handle(impl->handle);
	impl->handle = NULL;
	return res;
}

static void session_info(void *data, const struct pw_core_info *info)
{
	struct impl *impl = data;

	if (info && (info->change_mask & PW_CORE_CHANGE_MASK_PROPS)) {
		const char *str;

		if ((str = spa_dict_lookup(info->props, "default.clock.rate")) != NULL &&
		    pw_properties_get(impl->props, "bluez5.default.rate") == NULL) {
			pw_properties_set(impl->props, "bluez5.default.rate", str);
		}

		impl->have_info = true;
		load_bluez_handle(impl);
	}
}

static void session_destroy(void *data)
{
	struct impl *impl = data;

	spa_hook_remove(&impl->session_listener);

	unload_bluez_handle(impl);

	pw_properties_free(impl->props);
	pw_properties_free(impl->conf);
	free(impl);
}

static void seat_active(void *data, bool active)
{
	struct impl *impl = data;

	impl->seat_active = active;

	if (impl->seat_active) {
		pw_log_info(NAME ": seat active, starting bluetooth");
		load_bluez_handle(impl);
	} else {
		pw_log_info(NAME ": seat not active, stopping bluetooth");
		unload_bluez_handle(impl);
	}
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.info = session_info,
	.destroy = session_destroy,
	.seat_active = seat_active,
};

int sm_bluez5_monitor_start(struct sm_media_session *session)
{
	int res;
	struct impl *impl;
	const char *str;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL) {
		res = -errno;
		goto out;
	}
	impl->session = session;
	impl->seat_active = true;

	spa_list_init(&impl->device_list);

	if ((impl->conf = pw_properties_new(NULL, NULL)) == NULL) {
		res = -errno;
		goto out_free;
	}
	if ((res = sm_media_session_load_conf(impl->session,
					SESSION_CONF, impl->conf)) < 0)
		pw_log_info("can't load "SESSION_CONF" config: %s", spa_strerror(res));

	if ((impl->props = pw_properties_new(NULL, NULL)) == NULL) {
		res = -errno;
		goto out_free;
	}
	if ((str = pw_properties_get(impl->conf, "properties")) != NULL)
		pw_properties_update_string(impl->props, str, strlen(str));

	pw_properties_set(impl->props, "api.bluez5.connection-info", "true");

	sm_media_session_add_listener(session, &impl->session_listener,
			&session_events, impl);

	return 0;

out_free:
	if (impl->conf)
		pw_properties_free(impl->conf);
	if (impl->props)
		pw_properties_free(impl->props);
	free(impl);
out:
	return res;
}
