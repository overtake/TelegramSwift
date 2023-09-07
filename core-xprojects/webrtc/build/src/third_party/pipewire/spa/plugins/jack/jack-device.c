/* Spa JACK Device
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

#include <stddef.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <poll.h>

#include <spa/support/log.h>
#include <spa/utils/type.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/node/node.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/monitor/device.h>
#include <spa/monitor/utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/pod/parser.h>
#include <spa/debug/pod.h>

#include "jack-client.h"

#define NAME  "jack-device"

#define MAX_DEVICES	64

#define DEFAULT_SERVER "default"

struct props {
	char server[128];
};

static void reset_props(struct props *props)
{
	strncpy(props->server, DEFAULT_SERVER, 64);
}

struct node {
	enum spa_direction direction;
};

struct impl {
	struct spa_handle handle;
	struct spa_device device;

	struct spa_log *log;
	struct spa_hook_list hooks;

	struct props props;

	struct node nodes[2];
	uint32_t n_nodes;

	uint32_t profile;

	struct spa_jack_client client;
};

static int emit_node(struct impl *this, uint32_t id)
{
	struct spa_dict_item items[6];
	struct spa_device_object_info info;
	char jack_client[64];

	info = SPA_DEVICE_OBJECT_INFO_INIT();
	info.type = SPA_TYPE_INTERFACE_Node;
	if (this->nodes[id].direction == SPA_DIRECTION_INPUT)
                info.factory_name = SPA_NAME_API_JACK_SINK;
        else
                info.factory_name = SPA_NAME_API_JACK_SOURCE;

	info.change_mask = SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;
	snprintf(jack_client, sizeof(jack_client), "pointer:%p", &this->client);
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_API_JACK_CLIENT, jack_client);
	info.props = &SPA_DICT_INIT(items, 1);

	spa_device_emit_object_info(&this->hooks, id, &info);

	return 0;
}

static int activate_profile(struct impl *this, uint32_t id)
{
	int res = 0;
	uint32_t i, n;
	const char ** ports;

	spa_log_debug(this->log, "profile %d", id);
	if (this->profile == id)
		return 0;

	for (i = 0; i < this->n_nodes; i++)
		spa_device_emit_object_info(&this->hooks, i, NULL);
	this->n_nodes = 0;

	spa_jack_client_close(&this->client);

	if (id == 0)
		goto done;

	res = spa_jack_client_open(&this->client, "PipeWire", NULL);
	if (res < 0) {
		spa_log_error(this->log, NAME" %p: can't open client: %s",
				this, spa_strerror(res));
		return res;
	}
	n = 0;
	ports = jack_get_ports(this->client.client,
			NULL, JACK_DEFAULT_AUDIO_TYPE,
			JackPortIsPhysical|JackPortIsOutput);
	if (ports) {
		jack_free(ports);
		this->nodes[n].direction = SPA_DIRECTION_OUTPUT;
		emit_node(this, n++);
	}

	ports = jack_get_ports(this->client.client,
			NULL, JACK_DEFAULT_AUDIO_TYPE,
			JackPortIsPhysical|JackPortIsInput);
	if (ports) {
		jack_free(ports);
		this->nodes[n].direction = SPA_DIRECTION_INPUT;
		emit_node(this, n++);
	}
	this->n_nodes = n;
done:
	this->profile = id;

	return res;
}

static int emit_info(struct impl *this, bool full)
{
	int err = 0;
	struct spa_dict_item items[10];
	struct spa_device_info dinfo;
	struct spa_param_info params[2];
	char name[200];

	dinfo = SPA_DEVICE_INFO_INIT();

	dinfo.change_mask = SPA_DEVICE_CHANGE_MASK_PROPS;
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_API,  "jack");
	items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_NICK, "jack");
	if (strcmp(this->props.server, "default") == 0)
		snprintf(name, sizeof(name), "JACK Client");
	else
		snprintf(name, sizeof(name), "JACK Client (%s)", this->props.server);
	items[2] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_NAME, name);
	items[3] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_DESCRIPTION, name);
	items[4] = SPA_DICT_ITEM_INIT(SPA_KEY_API_JACK_SERVER, this->props.server);
	items[5] = SPA_DICT_ITEM_INIT(SPA_KEY_MEDIA_CLASS, "Audio/Device");
	dinfo.props = &SPA_DICT_INIT(items, 6);

	dinfo.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumProfile, SPA_PARAM_INFO_READ);
	params[1] = SPA_PARAM_INFO(SPA_PARAM_Profile, SPA_PARAM_INFO_READWRITE);
	dinfo.n_params = SPA_N_ELEMENTS(params);
	dinfo.params = params;

	spa_device_emit_info(&this->hooks, &dinfo);

	return err;
}

static int impl_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	if (events->info)
		emit_info(this, true);

	if (events->object_info) {
		for (i = 0; i < this->n_nodes; i++)
			emit_node(this, i);
	}

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}


static int impl_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_device_emit_result(&this->hooks, seq, 0, 0, NULL);

	return 0;
}

static struct spa_pod *build_profile(struct impl *this, struct spa_pod_builder *b,
		uint32_t id, uint32_t index)
{
	struct spa_pod_frame f[2];
	const char *name, *desc;

	switch (index) {
	case 0:
		name = "off";
		desc = "Off";
		break;
	case 1:
		name = "on";
		desc = "On";
		break;
	default:
		errno = EINVAL;
		return NULL;
	}

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamProfile, id);
	spa_pod_builder_add(b,
		SPA_PARAM_PROFILE_index,   SPA_POD_Int(index),
		SPA_PARAM_PROFILE_name, SPA_POD_String(name),
		SPA_PARAM_PROFILE_description, SPA_POD_String(desc),
		0);
	return spa_pod_builder_pop(b, &f[0]);
}

static int impl_enum_params(void *object, int seq,
			    uint32_t id, uint32_t start, uint32_t num,
			    const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_device_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumProfile:
	{
		switch (result.index) {
		case 0:
		case 1:
			param = build_profile(this, &b, id, result.index);
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Profile:
	{
		switch (result.index) {
		case 0:
			param = build_profile(this, &b, id, this->profile);
			break;
		default:
			return 0;
		}
		break;
	}
	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_device_emit_result(&this->hooks, seq, 0,
			SPA_RESULT_TYPE_DEVICE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int impl_set_param(void *object,
			  uint32_t id, uint32_t flags,
			  const struct spa_pod *param)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Profile:
	{
		uint32_t id;

		if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&id))) < 0) {
			spa_log_warn(this->log, "can't parse profile");
			spa_debug_pod(0, NULL, param);
			return res;
		}
		activate_profile(this, id);
		break;
	}
	default:
		return -ENOENT;
	}
	return 0;
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
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	this = (struct impl *) handle;

	activate_profile(this, 0);
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
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	this->device.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Device,
			SPA_VERSION_DEVICE,
			&impl_device, this);
	spa_hook_list_init(&this->hooks);

	reset_props(&this->props);

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_JACK_SERVER)))
		snprintf(this->props.server, 64, "%s", str);
	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Device,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
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

const struct spa_handle_factory spa_jack_device_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_JACK_DEVICE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
