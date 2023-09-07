/* PipeWire
 *
 * Copyright © 2020 Wim Taymans
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

#include "config.h"

#include <getopt.h>
#include <signal.h>

#include <dbus/dbus.h>

#include <spa/support/dbus.h>

#include "pipewire/pipewire.h"

#include "reserve.c"

#define NAME "reserve"

struct impl {
	struct pw_main_loop *mainloop;
	struct pw_loop *loop;
	struct pw_context *context;

	struct spa_dbus *dbus;
	struct spa_dbus_connection *dbus_connection;
	DBusConnection *conn;

	struct rd_device *device;
};

static void reserve_acquired(void *data, struct rd_device *d)
{
	fprintf(stdout, "reserve acquired\n");
}

static void reserve_release(void *data, struct rd_device *d, int forced)
{
	struct impl *impl = data;
	fprintf(stdout, "reserve release\n");
	rd_device_complete_release(impl->device, true);
}

static void reserve_busy(void *data, struct rd_device *d, const char *name, int32_t prio)
{
	fprintf(stdout, "reserve busy %s, prio %d\n", name, prio);
}

static void reserve_available(void *data, struct rd_device *d, const char *name)
{
	fprintf(stdout, "reserve available %s\n", name);
}

static const struct rd_device_callbacks reserve_callbacks = {
	.acquired = reserve_acquired,
	.release = reserve_release,
	.busy = reserve_busy,
	.available = reserve_available,
};

static void do_quit(void *data, int signal_number)
{
	struct impl *impl = data;
	pw_main_loop_quit(impl->mainloop);
}

#define DEFAULT_APPNAME		"pw-reserve"
#define DEFAULT_PRIORITY	0

static void show_help(const char *name)
{
        fprintf(stdout, "%s [options]\n"
             "  -h, --help                            Show this help\n"
             "      --version                         Show version\n"
             "  -n, --name                            Name to reserve (Audio0, Midi0, Video0, ..)\n"
             "  -a, --appname                         Application Name (default %s)\n"
             "  -p, --priority                        Priority (default %d)\n"
             "  -m, --monitor                         Monitor only, don't try to acquire\n",
	     name, DEFAULT_APPNAME, DEFAULT_PRIORITY);
}

int main(int argc, char *argv[])
{
	struct impl impl = { 0, };
	const struct spa_support *support;
	uint32_t n_support;
	const char *opt_name = NULL;
	const char *opt_appname = DEFAULT_APPNAME;
	bool opt_monitor = false;
	int opt_priority= DEFAULT_PRIORITY;

	int res = 0, c;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "name",	required_argument,	NULL, 'n' },
		{ "app",	required_argument,	NULL, 'a' },
		{ "priority",	required_argument,	NULL, 'p' },
		{ "monitor",	no_argument,		NULL, 'm' },
		{ NULL, 0, NULL, 0}
	};

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVn:a:p:m", long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			show_help(argv[0]);
			return 0;
		case 'V':
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				argv[0],
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;
		case 'n':
			opt_name = optarg;
			break;
		case 'a':
			opt_appname = optarg;
			break;
		case 'p':
			opt_priority = atoi(optarg);
			break;
		case 'm':
			opt_monitor = true;
			break;
		default:
			fprintf(stderr, "invalid option '%c'\n", c);
			return -1;
		}
	}
	if (opt_name == NULL) {
		fprintf(stderr, "name must be given\n");
		return -1;
	}

	impl.mainloop = pw_main_loop_new(NULL);
	if (impl.mainloop == NULL) {
		fprintf(stderr, "can't create mainloop: %m\n");
		res = -errno;
		goto exit;
	}
	impl.loop = pw_main_loop_get_loop(impl.mainloop);

	pw_loop_add_signal(impl.loop, SIGINT, do_quit, &impl);
	pw_loop_add_signal(impl.loop, SIGTERM, do_quit, &impl);

	impl.context = pw_context_new(impl.loop, NULL, 0);
	if (impl.context == NULL) {
		fprintf(stderr, "can't create context: %m\n");
		res = -errno;
		goto exit;
	}

	support = pw_context_get_support(impl.context, &n_support);

	impl.dbus = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DBus);
	if (impl.dbus)
		impl.dbus_connection = spa_dbus_get_connection(impl.dbus, SPA_DBUS_TYPE_SESSION);
	if (impl.dbus_connection == NULL) {
		fprintf(stderr, "no dbus connection: %m\n");
		res = -errno;
		goto exit;
	}
	impl.conn = spa_dbus_connection_get(impl.dbus_connection);
	if (impl.conn == NULL) {
		fprintf(stderr, "no dbus connection: %m\n");
		res = -errno;
		goto exit;
	}

	impl.device = rd_device_new(impl.conn,
			opt_name,
			opt_appname,
			opt_priority,
			&reserve_callbacks, &impl);

	if (!opt_monitor)
		rd_device_acquire(impl.device);

	pw_main_loop_run(impl.mainloop);

	if (!opt_monitor)
		rd_device_release(impl.device);

exit:
	if (impl.context)
		pw_context_destroy(impl.context);
	if (impl.mainloop)
		pw_main_loop_destroy(impl.mainloop);

	pw_deinit();

	return res;
}
