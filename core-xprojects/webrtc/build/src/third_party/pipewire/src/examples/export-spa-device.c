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

	struct pw_impl_device *device;
	const char *library;
	const char *factory;
	const char *path;
};

static int make_device(struct data *data)
{
	struct pw_impl_factory *factory;
	struct pw_properties *props;

        factory = pw_context_find_factory(data->context, "spa-device-factory");
	if (factory == NULL)
		return -1;

        props = pw_properties_new(SPA_KEY_LIBRARY_NAME, data->library,
                                  SPA_KEY_FACTORY_NAME, data->factory, NULL);

	data->device = pw_impl_factory_create_object(factory,
					      NULL,
					      PW_TYPE_INTERFACE_Device,
					      PW_VERSION_DEVICE,
					      props, SPA_ID_INVALID);

	pw_core_export(data->core, SPA_TYPE_INTERFACE_Device, NULL,
			pw_impl_device_get_implementation(data->device), 0);

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
		fprintf(stderr, "usage: %s <library> <factory>\n\n"
				"\texample: %s v4l2/libspa-v4l2 api.v4l2.device\n\n",
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

	pw_context_load_module(data.context, "libpipewire-module-spa-device-factory", NULL, NULL);

        data.core = pw_context_connect(data.context, NULL, 0);
	if (data.core == NULL) {
		pw_log_error("can't connect %m");
		return -1;
	}

	pw_core_add_listener(data.core, &data.core_listener, &core_events, &data);

	if (make_device(&data) < 0) {
		pw_log_error("can't make device");
		return -1;
	}

	pw_main_loop_run(data.loop);

	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	return 0;
}
