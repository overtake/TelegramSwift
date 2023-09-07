/* PipeWire
 *
 * Copyright © 2020 Georges Basile Stavracas Neto
 * Copyright © 2021 Wim Taymans <wim.taymans@gmail.com>
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

#include "module.h"

static int module_unload(struct client *client, struct module *module);

static void on_module_unload(void *obj, void *data, int res, uint32_t id)
{
	struct module *module = obj;
	module_unload(NULL, module);
}

void module_schedule_unload(struct module *module)
{
	struct impl *impl = module->impl;
	pw_work_queue_add(impl->work_queue, module, 0, on_module_unload, impl);
}

struct module *module_new(struct impl *impl, const struct module_methods *methods, size_t user_data)
{
	struct module *module;

	module = calloc(1, sizeof(struct module) + user_data);
	if (module == NULL)
		return NULL;

	module->impl = impl;
	module->methods = methods;
	spa_hook_list_init(&module->hooks);
	module->user_data = SPA_MEMBER(module, sizeof(struct module), void);

	return module;
}

static void module_add_listener(struct module *module,
		struct spa_hook *listener,
		const struct module_events *events, void *data)
{
	spa_hook_list_append(&module->hooks, listener, events, data);
}

static int module_load(struct client *client, struct module *module)
{
	pw_log_info("load module id:%u name:%s", module->idx, module->name);
	if (module->methods->load == NULL)
		return -ENOTSUP;
	/* subscription event is sent when the module does a
	 * module_emit_loaded() */
	return module->methods->load(client, module);
}

static void module_free(struct module *module)
{
	struct impl *impl = module->impl;
	if (module->idx != SPA_ID_INVALID)
		pw_map_remove(&impl->modules, module->idx & INDEX_MASK);

	pw_work_queue_cancel(impl->work_queue, module, SPA_ID_INVALID);
	free((char*)module->name);
	free((char*)module->args);
	if (module->props)
		pw_properties_free(module->props);
	free(module);
}

static int module_unload(struct client *client, struct module *module)
{
	struct impl *impl = module->impl;
	uint32_t module_idx = module->idx;
	int res = 0;

	/* Note that client can be NULL (when the module is being unloaded
	 * internally and not by a client request */

	pw_log_info("unload module id:%u name:%s", module->idx, module->name);

	if (module->methods->unload)
		res = module->methods->unload(client, module);

	module_free(module);

	broadcast_subscribe_event(impl,
			SUBSCRIPTION_MASK_MODULE,
			SUBSCRIPTION_EVENT_REMOVE | SUBSCRIPTION_EVENT_MODULE,
			module_idx);

	return res;
}

/** utils */
void module_args_add_props(struct pw_properties *props, const char *str)
{
	char *s = strdup(str), *p = s, *e, f;
	const char *k, *v;

	while (*p) {
		e = strchr(p, '=');
		if (e == NULL)
			break;
		*e = '\0';
		k = p;
		p = e+1;

		if (*p == '\"') {
			p++;
			f = '\"';
		} else {
			f = ' ';
		}
		v = p;
		e = strchr(p, f);
		if (e == NULL)
			e = strchr(p, '\0');
		if (e == NULL)
			break;
		p = e;
		if (*e != '\0')
			p++;
		*e = '\0';
		pw_properties_set(props, k, v);
	}
	free(s);
}

int module_args_to_audioinfo(struct impl *impl, struct pw_properties *props, struct spa_audio_info_raw *info)
{
	const char *str;
	uint32_t i;

	/* We don't use any incoming format setting and use our native format */
	spa_zero(*info);
	info->format = SPA_AUDIO_FORMAT_F32P;

	if ((str = pw_properties_get(props, "channels")) != NULL) {
		info->channels = pw_properties_parse_int(str);
		if (info->channels == 0 || info->channels > SPA_AUDIO_MAX_CHANNELS) {
			pw_log_error("invalid channels '%s'", str);
			return -EINVAL;
		}
		pw_properties_set(props, "channels", NULL);
	}
	if ((str = pw_properties_get(props, "channel_map")) != NULL) {
		struct channel_map map;

		channel_map_parse(str, &map);
		if (map.channels == 0 || map.channels > SPA_AUDIO_MAX_CHANNELS) {
			pw_log_error("invalid channel_map '%s'", str);
			return -EINVAL;
		}
		if (info->channels == 0)
			info->channels = map.channels;
		if (info->channels != map.channels) {
			pw_log_error("Mismatched channel map");
			return -EINVAL;
		}
		channel_map_to_positions(&map, info->position);
		pw_properties_set(props, "channel_map", NULL);
	} else {
		if (info->channels == 0)
			info->channels = impl->defs.sample_spec.channels;

		if (info->channels == impl->defs.channel_map.channels) {
			channel_map_to_positions(&impl->defs.channel_map, info->position);
		} else if (info->channels == 1) {
			info->position[0] = SPA_AUDIO_CHANNEL_MONO;
		} else if (info->channels == 2) {
			info->position[0] = SPA_AUDIO_CHANNEL_FL;
			info->position[1] = SPA_AUDIO_CHANNEL_FR;
		} else {
			/* FIXME add more mappings */
			for (i = 0; i < info->channels; i++)
				info->position[i] = SPA_AUDIO_CHANNEL_UNKNOWN;
		}
	}

	if ((str = pw_properties_get(props, "rate")) != NULL) {
		info->rate = pw_properties_parse_int(str);
		pw_properties_set(props, "rate", NULL);
	} else {
		info->rate = 0;
	}
	return 0;
}

#include "modules/registry.h"

static const struct module_info module_list[] = {
	{ "module-loopback", create_module_loopback, },
	{ "module-null-sink", create_module_null_sink, },
	{ "module-native-protocol-tcp", create_module_native_protocol_tcp, },
	{ "module-remap-sink", create_module_remap_sink, },
	{ "module-remap-source", create_module_remap_source, },
	{ "module-simple-protocol-tcp", create_module_simple_protocol_tcp, },
	{ NULL, }
};

static const struct module_info *find_module_info(const char *name)
{
	int i;
	for (i = 0; module_list[i].name != NULL; i++) {
		if (strcmp(module_list[i].name, name) == 0)
			return &module_list[i];
	}
	return NULL;
}

static struct module *create_module(struct client *client, const char *name, const char *args)
{
	struct impl *impl = client->impl;
	const struct module_info *info;
	struct module *module;

	info = find_module_info(name);
	if (info == NULL) {
		errno = ENOENT;
		return NULL;
	}
	module = info->create(impl, args);
	if (module == NULL)
		return NULL;

	module->idx = pw_map_insert_new(&impl->modules, module);
	if (module->idx == SPA_ID_INVALID) {
		module_unload(client, module);
		return NULL;
	}
	module->name = strdup(name);
	module->args = args ? strdup(args) : NULL;
	module->idx |= MODULE_FLAG;
	return module;
}
