/* PipeWire
 *
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

#include <pipewire/impl.h>
#include <pipewire/pipewire.h>

#include "../defs.h"
#include "../module.h"
#include "registry.h"

struct module_simple_protocol_tcp_data {
	struct module *module;
	struct server *server;
	struct pw_properties *module_props;
	struct pw_impl_module *mod;
};

static int module_simple_protocol_tcp_load(struct client *client, struct module *module)
{
	struct module_simple_protocol_tcp_data *data = module->user_data;
	struct impl *impl = client->impl;
	char *args;
	const char *str;
	size_t size;
	FILE *f;

	f = open_memstream(&args, &size);
	if ((str = pw_properties_get(data->module_props, "audio.format")) != NULL)
		fprintf(f, "audio.format=%s ", str);
	if ((str = pw_properties_get(data->module_props, "audio.rate")) != NULL)
		fprintf(f, "audio.rate=%s ", str);
	if ((str = pw_properties_get(data->module_props, "audio.channels")) != NULL)
		fprintf(f, "audio.channels=%s ", str);
	if ((str = pw_properties_get(data->module_props, "server.address")) != NULL)
		fprintf(f, "server.address=%s ", str);
	if ((str = pw_properties_get(data->module_props, "capture")) != NULL)
		fprintf(f, "capture=%s ", str);
	if ((str = pw_properties_get(data->module_props, "playback")) != NULL)
		fprintf(f, "playback=%s ", str);
	if ((str = pw_properties_get(data->module_props, "capture.node")) != NULL)
		fprintf(f, "capture.node=\"%s\" ", str);
	if ((str = pw_properties_get(data->module_props, "playback.node")) != NULL)
		fprintf(f, "playback.node=\"%s\" ", str);
	fclose(f);

	data->mod = pw_context_load_module(impl->context,
			"libpipewire-module-protocol-simple",
			args, NULL);
	free(args);

	if (data->mod == NULL)
		return -errno;

	pw_log_info("loaded module %p id:%u name:%s", module, module->idx, module->name);
	module_emit_loaded(module, 0);
	return 0;
}

static int module_simple_protocol_tcp_unload(struct client *client, struct module *module)
{
	struct module_simple_protocol_tcp_data *d = module->user_data;

	pw_log_info("unload module %p id:%u name:%s", module, module->idx, module->name);

	pw_impl_module_destroy(d->mod);

	return 0;
}

static const struct module_methods module_simple_protocol_tcp_methods = {
	VERSION_MODULE_METHODS,
	.load = module_simple_protocol_tcp_load,
	.unload = module_simple_protocol_tcp_unload,
};

static const struct spa_dict_item module_simple_protocol_tcp_info[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Simple protocol (TCP sockets)" },
	{ PW_KEY_MODULE_USAGE, "rate=<sample rate> "
				"format=<sample format> "
				"channels=<number of channels> "
				"sink=<sink to connect to> "
				"source=<source to connect to> "
				"playback=<enable playback?> "
				"record=<enable record?> "
				"port=<TCP port number> "
				"listen=<address to listen on>" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct module *create_module_simple_protocol_tcp(struct impl *impl, const char *argument)
{
	struct module *module;
	struct module_simple_protocol_tcp_data *d;
	struct pw_properties *props = NULL, *module_props = NULL;
	const char *str, *port, *listen;
	int res;

	props = pw_properties_new_dict(&SPA_DICT_INIT_ARRAY(module_simple_protocol_tcp_info));
	if (props == NULL) {
		res = -errno;
		goto out;
	}
	if (argument)
		module_args_add_props(props, argument);

	module_props = pw_properties_new(NULL, NULL);
	if (module_props == NULL) {
		res = -errno;
		goto out;
	}

	if ((str = pw_properties_get(props, "rate")) != NULL) {
		pw_properties_set(module_props, "audio.rate", str);
		pw_properties_set(props, "rate", NULL);
	}
	if ((str = pw_properties_get(props, "format")) != NULL) {
		pw_properties_set(module_props, "audio.format", format_id2name(format_paname2id(str, strlen(str))));
		pw_properties_set(props, "format", NULL);
	}
	if ((str = pw_properties_get(props, "channels")) != NULL) {
		pw_properties_set(module_props, "audio.channels", str);
		pw_properties_set(props, "channels", NULL);
	}
	if ((str = pw_properties_get(props, "playback")) != NULL) {
		pw_properties_set(module_props, "playback", str);
		pw_properties_set(props, "playback", NULL);
	}
	if ((str = pw_properties_get(props, "record")) != NULL) {
		pw_properties_set(module_props, "capture", str);
		pw_properties_set(props, "record", NULL);
	}

	if ((str = pw_properties_get(props, "source")) != NULL) {
		if (pw_endswith(str, ".monitor")) {
			pw_properties_setf(module_props, "capture.node",
					"%.*s", (int)strlen(str)-8, str);
		} else {
			pw_properties_set(module_props, "capture.node", str);
		}
		pw_properties_set(props, "source", NULL);
	}

	if ((str = pw_properties_get(props, "sink")) != NULL) {
		pw_properties_set(module_props, "playback.node", str);
		pw_properties_set(props, "sink", NULL);
	}

	if ((port = pw_properties_get(props, "port")) == NULL)
		port = "4711";
	listen = pw_properties_get(props, "listen");

	pw_properties_setf(module_props, "server.address", "[ \"tcp:%s%s%s\" ]",
			listen ? listen : "", listen ? ":" : "", port);

	module = module_new(impl, &module_simple_protocol_tcp_methods, sizeof(*d));
	if (module == NULL) {
		res = -errno;
		goto out;
	}

	module->props = props;
	d = module->user_data;
	d->module = module;
	d->module_props = module_props;

	return module;
out:
	if (module_props)
		pw_properties_free(module_props);
	if (props)
		pw_properties_free(props);
	errno = -res;
	return NULL;
}
