/* PipeWire
 *
 * Copyright © 2021 Wim Taymans <wim.taymans@gmail.com>
 * Copyright © 2021 Arun Raghavan <arun@asymptotic.io>
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

#include <spa/param/audio/format-utils.h>
#include <spa/utils/hook.h>
#include <spa/utils/json.h>
#include <pipewire/pipewire.h>
#include <pipewire/private.h>

#include "../defs.h"
#include "../module.h"
#include "registry.h"

#define ERROR_RETURN(str) 		\
	{ 				\
		pw_log_error(str); 	\
		res = -EINVAL; 		\
		goto out; 		\
	}

struct module_loopback_data {
	struct module *module;

	struct pw_impl_module *mod;
	struct spa_hook mod_listener;

	struct pw_properties *capture_props;
	struct pw_properties *playback_props;

	struct spa_audio_info_raw info;
};

static void module_destroy(void *data)
{
	struct module_loopback_data *d = data;
	spa_hook_remove(&d->mod_listener);
	d->mod = NULL;
	module_schedule_unload(d->module);
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy
};

static void serialize_dict(FILE *f, const struct spa_dict *dict)
{
	const struct spa_dict_item *it;
	fprintf(f, "{");
	spa_dict_for_each(it, dict) {
		size_t len = it->value ? strlen(it->value) : 0;
		fprintf(f, " \"%s\" = ", it->key);
		if (it->value == NULL) {
			fprintf(f, "null");
		} else if ( spa_json_is_null(it->value, len) ||
		    spa_json_is_float(it->value, len) ||
		    spa_json_is_object(it->value, len)) {
			fprintf(f, "%s", it->value);
		} else {
			size_t size = (len+1) * 4;
			char str[size];
				spa_json_encode_string(str, size, it->value);
			fprintf(f, "%s", str);
		}
	}
	fprintf(f, " }");
}

static int module_loopback_load(struct client *client, struct module *module)
{
	struct module_loopback_data *data = module->user_data;
	FILE *f;
	char *args;
	size_t size;

	pw_properties_setf(data->capture_props, PW_KEY_NODE_GROUP, "loopback-%u", module->idx);
	pw_properties_setf(data->playback_props, PW_KEY_NODE_GROUP, "loopback-%u", module->idx);

	f = open_memstream(&args, &size);
	fprintf(f, "{");
	if (data->info.channels != 0)
		fprintf(f, " audio.channels = %u", data->info.channels);
	fprintf(f, " capture.props = ");
	serialize_dict(f, &data->capture_props->dict);
	fprintf(f, " playback.props = ");
	serialize_dict(f, &data->playback_props->dict);
	fprintf(f, " }");
	fclose(f);

	data->mod = pw_context_load_module(module->impl->context,
			"libpipewire-module-loopback",
			args, NULL);
	free(args);

	if (data->mod == NULL)
		return -errno;

	pw_impl_module_add_listener(data->mod,
			&data->mod_listener,
			&module_events, data);

	pw_log_info("loaded module %p id:%u name:%s", module, module->idx, module->name);
	module_emit_loaded(module, 0);

	return 0;
}

static int module_loopback_unload(struct client *client, struct module *module)
{
	struct module_loopback_data *d = module->user_data;

	pw_log_info("unload module %p id:%u name:%s", module, module->idx, module->name);

	if (d->mod) {
		spa_hook_remove(&d->mod_listener);
		pw_impl_module_destroy(d->mod);
		d->mod = NULL;
	}
	return 0;
}

static const struct module_methods module_loopback_methods = {
	VERSION_MODULE_METHODS,
	.load = module_loopback_load,
	.unload = module_loopback_unload,
};

static const struct spa_dict_item module_loopback_info[] = {
	{ PW_KEY_MODULE_AUTHOR, "Arun Raghavan <arun@asymptotic.io>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Loopback from source to sink" },
	{ PW_KEY_MODULE_USAGE, "source=<source to connect to> "
				"sink=<sink to connect to> "
				"latency_msec=<latency in ms> "
				"rate=<sample rate> "
				"channels=<number of channels> "
				"channel_map=<channel map> "
				"sink_input_properties=<proplist> "
				"source_output_properties=<proplist> "
				"source_dont_move=<boolean> "
				"sink_dont_move=<boolean> "
				"remix=<remix channels?> " },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct module *create_module_loopback(struct impl *impl, const char *argument)
{
	struct module *module;
	struct module_loopback_data *d;
	struct pw_properties *props = NULL, *playback_props = NULL, *capture_props = NULL;
	const char *str;
	struct spa_audio_info_raw info = { 0 };
	int res;

	props = pw_properties_new_dict(&SPA_DICT_INIT_ARRAY(module_loopback_info));
	capture_props = pw_properties_new(NULL, NULL);
	playback_props = pw_properties_new(NULL, NULL);
	if (!props || !capture_props || !playback_props) {
		res = -EINVAL;
		goto out;
	}
	if (argument)
		module_args_add_props(props, argument);

	/* The following modargs are not implemented:
	 * adjust_time, max_latency_msec, fast_adjust_threshold_msec: these are just not relevant
	 */

	if ((str = pw_properties_get(props, "source")) != NULL) {
		if (pw_endswith(str, ".monitor")) {
			pw_properties_setf(capture_props, PW_KEY_NODE_TARGET,
					"%.*s", (int)strlen(str)-8, str);
		} else {
			pw_properties_set(capture_props, PW_KEY_NODE_TARGET, str);
		}
		pw_properties_set(props, "source", NULL);
	}

	if ((str = pw_properties_get(props, "sink")) != NULL) {
		pw_properties_set(playback_props, PW_KEY_NODE_TARGET, str);
		pw_properties_set(props, "sink", NULL);
	}

	if (module_args_to_audioinfo(impl, props, &info) < 0) {
		res = -EINVAL;
		goto out;
	}

	if ((str = pw_properties_get(props, "source_dont_move")) != NULL) {
		pw_properties_set(capture_props, PW_KEY_NODE_DONT_RECONNECT, str);
		pw_properties_set(props, "source_dont_move", NULL);
	}

	if ((str = pw_properties_get(props, "sink_dont_move")) != NULL) {
		pw_properties_set(playback_props, PW_KEY_NODE_DONT_RECONNECT, str);
		pw_properties_set(props, "sink_dont_move", NULL);
	}

	if ((str = pw_properties_get(props, "remix")) != NULL) {
		/* Note that the boolean is inverted */
		pw_properties_set(playback_props, PW_KEY_STREAM_DONT_REMIX,
				pw_properties_parse_bool(str) ? "false" : "true");
		pw_properties_set(props, "remix", NULL);
	}

	if ((str = pw_properties_get(props, "latency_msec")) != NULL) {
		/* Half the latency on each of the playback and capture streams */
		pw_properties_setf(capture_props, PW_KEY_NODE_LATENCY, "%s/2000", str);
		pw_properties_setf(playback_props, PW_KEY_NODE_LATENCY, "%s/2000", str);
		pw_properties_set(props, "latency_msec", NULL);
	} else {
		pw_properties_set(capture_props, PW_KEY_NODE_LATENCY, "100/1000");
		pw_properties_set(playback_props, PW_KEY_NODE_LATENCY, "100/1000");
	}

	if ((str = pw_properties_get(props, "sink_input_properties")) != NULL) {
		module_args_add_props(playback_props, str);
		pw_properties_set(props, "sink_input_properties", NULL);
	}

	if ((str = pw_properties_get(props, "source_output_properties")) != NULL) {
		module_args_add_props(capture_props, str);
		pw_properties_set(props, "source_output_properties", NULL);
	}

	module = module_new(impl, &module_loopback_methods, sizeof(*d));
	if (module == NULL) {
		res = -errno;
		goto out;
	}

	module->props = props;
	d = module->user_data;
	d->module = module;
	d->capture_props = capture_props;
	d->playback_props = playback_props;
	d->info = info;

	return module;
out:
	if (props)
		pw_properties_free(props);
	if (playback_props)
		pw_properties_free(playback_props);
	if (capture_props)
		pw_properties_free(capture_props);
	errno = -res;

	return NULL;
}
