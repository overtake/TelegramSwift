/* PipeWire
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

#include <stdio.h>
#include <sys/mman.h>
#include <signal.h>

#include <spa/utils/result.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/props.h>

#include <pipewire/impl.h>

struct data {
	struct pw_main_loop *loop;

	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct spa_node *node;
	const char *library;
	const char *factory;
	const char *path;

	struct pw_proxy *proxy;
	struct spa_hook proxy_listener;
	uint32_t id;
};

static void proxy_event_bound(void *object, uint32_t global_id)
{
	struct data *data = object;
	if (data->id != global_id) {
		printf("node id: %u\n", global_id);
		data->id = global_id;
	}
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.bound = proxy_event_bound,
};

static int make_node(struct data *data)
{
	struct pw_properties *props;
	struct spa_handle *hndl;
	void *iface;
	int res;

        props = pw_properties_new(SPA_KEY_LIBRARY_NAME, data->library,
                                  SPA_KEY_FACTORY_NAME, data->factory,
				  NULL);


	hndl = pw_context_load_spa_handle(data->context, data->factory, &props->dict);
	if (hndl == NULL)
		return -errno;

	if ((res = spa_handle_get_interface(hndl, SPA_TYPE_INTERFACE_Node, &iface)) < 0)
		return res;

	data->node = iface;

	if (data->path) {
		pw_properties_set(props, PW_KEY_NODE_AUTOCONNECT, "true");
		pw_properties_set(props, PW_KEY_NODE_TARGET, data->path);
	}

	data->proxy = pw_core_export(data->core,
			SPA_TYPE_INTERFACE_Node, &props->dict,
			data->node, 0);
	pw_properties_free(props);

	if (data->proxy == NULL)
		return -errno;

	pw_proxy_add_listener(data->proxy,
			&data->proxy_listener, &proxy_events, data);

	return 0;
}

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct data *d = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE)
		pw_main_loop_quit(d->loop);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
};

static void do_quit(void *data, int signal_number)
{
        struct data *d = data;
	pw_main_loop_quit(d->loop);
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	struct pw_loop *l;

	pw_init(&argc, &argv);

	if (argc < 3) {
		fprintf(stderr, "usage: %s <library> <factory> [path]\n\n"
				"\texample: %s v4l2/libspa-v4l2 api.v4l2.source\n\n",
				argv[0], argv[0]);
		return -1;
	}

	data.loop = pw_main_loop_new(NULL);
	l = pw_main_loop_get_loop(data.loop);
        pw_loop_add_signal(l, SIGINT, do_quit, &data);
        pw_loop_add_signal(l, SIGTERM, do_quit, &data);
	data.context = pw_context_new(l, NULL, 0);
	data.library = argv[1];
	data.factory = argv[2];
	if (argc > 3)
		data.path = argv[3];

	pw_context_load_module(data.context, "libpipewire-module-spa-node-factory", NULL, NULL);

        data.core = pw_context_connect(data.context, NULL, 0);
	if (data.core == NULL) {
		printf("can't connect: %m\n");
		return -1;
	}
	pw_core_add_listener(data.core,
				   &data.core_listener,
				   &core_events, &data);

	if (make_node(&data) < 0) {
		pw_log_error("can't make node");
		return -1;
	}

	pw_main_loop_run(data.loop);

	pw_proxy_destroy(data.proxy);
	pw_core_disconnect(data.core);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	return 0;
}
