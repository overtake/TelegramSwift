/* Spa V4l2 Source
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

#include <stddef.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <linux/videodev2.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/pod/builder.h>
#include <spa/monitor/device.h>
#include <spa/monitor/utils.h>
#include <spa/debug/pod.h>

#include "v4l2.h"

#define NAME "v4l2-device"

static const char default_device[] = "/dev/video0";

struct props {
	char device[64];
	char device_name[128];
	int device_fd;
};

static void reset_props(struct props *props)
{
	strncpy(props->device, default_device, 64);
}

struct impl {
	struct spa_handle handle;
	struct spa_device device;

	struct spa_log *log;

	struct props props;

	struct spa_hook_list hooks;

	struct spa_v4l2_device dev;
};

static int emit_info(struct impl *this, bool full)
{
	int res;
	struct spa_dict_item items[10];
	uint32_t n_items = 0;
	struct spa_device_info info;
	struct spa_param_info params[2];
        char path[128], version[16], capabilities[16], device_caps[16];

	if ((res = spa_v4l2_open(&this->dev, this->props.device)) < 0)
		return res;

	info = SPA_DEVICE_INFO_INIT();

	info.change_mask = SPA_DEVICE_CHANGE_MASK_PROPS;

#define ADD_ITEM(key, value) items[n_items++] = SPA_DICT_ITEM_INIT(key, value)
	snprintf(path, sizeof(path), "v4l2:%s", this->props.device);
	ADD_ITEM(SPA_KEY_OBJECT_PATH, path);
	ADD_ITEM(SPA_KEY_DEVICE_API, "v4l2");
	ADD_ITEM(SPA_KEY_MEDIA_CLASS, "Video/Device");
	ADD_ITEM(SPA_KEY_API_V4L2_PATH, (char *)this->props.device);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_DRIVER, (char *)this->dev.cap.driver);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_CARD, (char *)this->dev.cap.card);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_BUS_INFO, (char *)this->dev.cap.bus_info);
	snprintf(version, sizeof(version), "%u.%u.%u",
			(this->dev.cap.version >> 16) & 0xFF,
			(this->dev.cap.version >> 8) & 0xFF,
			(this->dev.cap.version) & 0xFF);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_VERSION, version);
	snprintf(capabilities, sizeof(capabilities), "%08x", this->dev.cap.capabilities);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_CAPABILITIES, capabilities);
	snprintf(device_caps, sizeof(device_caps), "%08x", this->dev.cap.device_caps);
	ADD_ITEM(SPA_KEY_API_V4L2_CAP_DEVICE_CAPS, device_caps);
#undef ADD_ITEM
	info.props = &SPA_DICT_INIT(items, n_items);

	info.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumProfile, SPA_PARAM_INFO_READ);
	params[1] = SPA_PARAM_INFO(SPA_PARAM_Profile, SPA_PARAM_INFO_WRITE);
	info.n_params = 0;
	info.params = params;

	spa_device_emit_info(&this->hooks, &info);

	if (spa_v4l2_is_capture(&this->dev)) {
		struct spa_device_object_info oinfo;

		oinfo = SPA_DEVICE_OBJECT_INFO_INIT();
		oinfo.type = SPA_TYPE_INTERFACE_Node;
		oinfo.factory_name = SPA_NAME_API_V4L2_SOURCE;
		oinfo.change_mask = SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;
		oinfo.props = &SPA_DICT_INIT(items, n_items);

		spa_device_emit_object_info(&this->hooks, 0, &oinfo);
	}

	spa_v4l2_close(&this->dev);

	return 0;
}

static int impl_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;
	int res = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	if (events->info || events->object_info)
		res = emit_info(this, true);

	spa_hook_list_join(&this->hooks, &save);

	return res;
}

static int impl_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_device_emit_result(&this->hooks, seq, 0, 0, NULL);

	return 0;
}

static int impl_enum_params(void *object, int seq,
			    uint32_t id, uint32_t start, uint32_t num,
			    const struct spa_pod *filter)
{
	return -ENOTSUP;
}

static int impl_set_param(void *object,
			  uint32_t id, uint32_t flags,
			  const struct spa_pod *param)
{
	return -ENOTSUP;
}

static const struct spa_device_methods impl_device = {
	SPA_VERSION_DEVICE_METHODS,
	.add_listener = impl_add_listener,
	.sync = impl_sync,
	.enum_params = impl_enum_params,
	.set_param = impl_set_param,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Device) == 0)
		*interface = &this->device;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear, this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	spa_hook_list_init(&this->hooks);

	this->device.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Device,
			SPA_VERSION_DEVICE,
			&impl_device, this);
	this->dev.log = this->log;
	this->dev.fd = -1;

	reset_props(&this->props);

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_V4L2_PATH)))
		strncpy(this->props.device, str, 63);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Device,},
};

static int impl_enum_interface_info(const struct spa_handle_factory *factory,
				    const struct spa_interface_info **info,
				    uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	if (*index >= SPA_N_ELEMENTS(impl_interfaces))
		return 0;

	*info = &impl_interfaces[(*index)++];

	return 1;
}

const struct spa_handle_factory spa_v4l2_device_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_V4L2_DEVICE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
