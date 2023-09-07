/* PipeWire
 *
 * Copyright © 2021 Georges Basile Stavracas Neto
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

#include <pipewire/pipewire.h>

#include "../manager.h"
#include "../module.h"
#include "registry.h"

struct module_null_sink_data {
	struct pw_proxy *proxy;
	struct spa_hook listener;
	uint32_t global_id;
};

static void module_null_sink_proxy_removed(void *data)
{
	struct module *module = data;
	struct module_null_sink_data *d = module->user_data;
	pw_proxy_destroy(d->proxy);
}

static void module_null_sink_proxy_destroy(void *data)
{
	struct module *module = data;
	struct module_null_sink_data *d = module->user_data;
	pw_log_info(NAME" %p: proxy %p destroy", module, d->proxy);
	spa_hook_remove(&d->listener);
	d->proxy = NULL;
}

static void module_null_sink_proxy_bound(void *data, uint32_t global_id)
{
	struct module *module = data;
	struct module_null_sink_data *d = module->user_data;

	pw_log_info(NAME" module %p proxy %p bound", module, d->proxy);
	d->global_id = global_id;
	module_emit_loaded(module, 0);
}

static void module_null_sink_proxy_error(void *data, int seq, int res, const char *message)
{
	struct module *module = data;
	struct module_null_sink_data *d = module->user_data;
	struct impl *impl = module->impl;

	pw_log_info(NAME" %p module %p error %d", impl, module, res);
	pw_proxy_destroy(d->proxy);
}

static int module_null_sink_load(struct client *client, struct module *module)
{
	struct module_null_sink_data *d = module->user_data;
	static const struct pw_proxy_events proxy_events = {
		.removed = module_null_sink_proxy_removed,
		.bound = module_null_sink_proxy_bound,
		.error = module_null_sink_proxy_error,
		.destroy = module_null_sink_proxy_destroy,
	};

	d->proxy = pw_core_create_object(client->core,
                                "adapter",
                                PW_TYPE_INTERFACE_Node,
                                PW_VERSION_NODE,
                                module->props ? &module->props->dict : NULL, 0);
	if (d->proxy == NULL)
		return -errno;

	pw_log_info("loaded module %p id:%u name:%s %p", module, module->idx, module->name, d->proxy);
	pw_proxy_add_listener(d->proxy, &d->listener, &proxy_events, module);
	return 0;
}

static int module_null_sink_unload(struct client *client, struct module *module)
{
	struct module_null_sink_data *d = module->user_data;
	pw_log_info("unload module %p id:%u name:%s %p", module, module->idx, module->name, d->proxy);
	if (d->proxy != NULL)
		pw_proxy_destroy(d->proxy);
	if (d->global_id != SPA_ID_INVALID)
		pw_registry_destroy(client->manager->registry, d->global_id);
	return 0;
}

static const struct module_methods module_null_sink_methods = {
	VERSION_MODULE_METHODS,
	.load = module_null_sink_load,
	.unload = module_null_sink_unload,
};

static const struct spa_dict_item module_null_sink_info[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "A NULL sink" },
	{ PW_KEY_MODULE_USAGE,  "sink_name=<name of sink> "
				"sink_properties=<properties for the sink> "
				"format=<sample format> "
				"rate=<sample rate> "
				"channels=<number of channels> "
				"channel_map=<channel map>" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct module *create_module_null_sink(struct impl *impl, const char *argument)
{
	struct module *module;
	struct module_null_sink_data *d;
	struct pw_properties *props = NULL;
	const char *str;
	struct spa_audio_info_raw info = { 0 };
	uint32_t i;
	int res;

	props = pw_properties_new_dict(&SPA_DICT_INIT_ARRAY(module_null_sink_info));
	if (props == NULL) {
		res = -EINVAL;
		goto out;
	}
	if (argument)
		module_args_add_props(props, argument);

	if ((str = pw_properties_get(props, "sink_name")) != NULL) {
		pw_properties_set(props, PW_KEY_NODE_NAME, str);
		pw_properties_set(props, "sink_name", NULL);
	} else {
		pw_properties_set(props, PW_KEY_NODE_NAME, "null");
	}
	if ((str = pw_properties_get(props, "sink_properties")) != NULL) {
		module_args_add_props(props, str);
		pw_properties_set(props, "sink_properties", NULL);
	}

	if (module_args_to_audioinfo(impl, props, &info) < 0) {
		res = -EINVAL;
		goto out;
	}

	if (info.rate)
		pw_properties_setf(props, SPA_KEY_AUDIO_RATE, "%u", info.rate);
	if (info.channels) {
		char *s, *p;

		pw_properties_setf(props, SPA_KEY_AUDIO_CHANNELS, "%u", info.channels);

		p = s = alloca(info.channels * 6);
		for (i = 0; i < info.channels; i++)
			p += snprintf(p, 6, "%s%s", i == 0 ? "" : ",",
					channel_id2name(info.position[i]));
		pw_properties_set(props, SPA_KEY_AUDIO_POSITION, s);
	}

	if (pw_properties_get(props, PW_KEY_MEDIA_CLASS) == NULL)
		pw_properties_set(props, PW_KEY_MEDIA_CLASS, "Audio/Sink");

	if ((str = pw_properties_get(props, "device.description")) != NULL) {
		pw_properties_set(props, PW_KEY_NODE_DESCRIPTION, str);
		pw_properties_set(props, "device.description", NULL);
	} else {
		const char *name, *class;

		name = pw_properties_get(props, PW_KEY_NODE_NAME);
		class = pw_properties_get(props, PW_KEY_MEDIA_CLASS);
		pw_properties_setf(props, PW_KEY_NODE_DESCRIPTION,
						"%s%s%s%ssink",
						name, (name[0] == '\0') ? "" : " ",
						class ? class : "", (class && class[0] != '\0') ? " " : "");
	}
	pw_properties_set(props, PW_KEY_FACTORY_NAME, "support.null-audio-sink");

	if (pw_properties_get(props, PW_KEY_OBJECT_LINGER) == NULL)
		pw_properties_set(props, PW_KEY_OBJECT_LINGER, "true");

	if (pw_properties_get(props, "monitor.channel-volumes") == NULL)
		pw_properties_set(props, "monitor.channel-volumes", "true");

	module = module_new(impl, &module_null_sink_methods, sizeof(*d));
	if (module == NULL) {
		res = -errno;
		goto out;
	}
	module->props = props;
	d = module->user_data;
	d->global_id = SPA_ID_INVALID;

	return module;
out:
	if (props)
		pw_properties_free(props);
	errno = -res;
	return NULL;
}
