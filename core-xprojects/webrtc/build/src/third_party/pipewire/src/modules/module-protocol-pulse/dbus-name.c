/* pulseaudio server
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

#include <dbus/dbus.h>
#include <spa/support/dbus.h>

static void *dbus_request_name(struct pw_context *context, const char *name)
{
	struct spa_dbus *dbus;
	struct spa_dbus_connection *conn;
	const struct spa_support *support;
	uint32_t n_support;
	DBusConnection *bus;
	DBusError error;

	support = pw_context_get_support(context, &n_support);

	dbus = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DBus);
	if (dbus == NULL) {
		errno = ENOTSUP;
		return NULL;
	}

        conn = spa_dbus_get_connection(dbus, SPA_DBUS_TYPE_SESSION);
        if (conn == NULL)
		return NULL;

	bus = spa_dbus_connection_get(conn);

	dbus_error_init(&error);

	if (dbus_bus_request_name(bus, name,
			DBUS_NAME_FLAG_DO_NOT_QUEUE,
			&error) == DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER)
		return conn;

	if (dbus_error_is_set(&error))
		pw_log_error("Failed to acquire %s: %s: %s", name, error.name, error.message);
	else
		pw_log_error("D-Bus name %s already taken.", name);

	dbus_error_free(&error);

	errno = EEXIST;
	return NULL;
}

static void dbus_release_name(void *data)
{
	struct spa_dbus_connection *conn = data;
	spa_dbus_connection_destroy(conn);
}
