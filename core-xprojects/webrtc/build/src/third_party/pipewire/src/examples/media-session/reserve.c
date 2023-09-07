/* DBus device reservation API
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

#ifndef NAME
#define NAME "reserve"
#endif

#include "reserve.h"

#define SERVICE_PREFIX "org.freedesktop.ReserveDevice1."
#define OBJECT_PREFIX "/org/freedesktop/ReserveDevice1/"

static const char introspection[] =
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE
	"<node>"
	" <!-- If you are looking for documentation make sure to check out\n"
	"      http://git.0pointer.de/?p=reserve.git;a=blob;f=reserve.txt -->\n"
	" <interface name=\"org.freedesktop.ReserveDevice1\">"
	"  <method name=\"RequestRelease\">"
	"   <arg name=\"priority\" type=\"i\" direction=\"in\"/>"
	"   <arg name=\"result\" type=\"b\" direction=\"out\"/>"
	"  </method>"
	"  <property name=\"Priority\" type=\"i\" access=\"read\"/>"
	"  <property name=\"ApplicationName\" type=\"s\" access=\"read\"/>"
	"  <property name=\"ApplicationDeviceName\" type=\"s\" access=\"read\"/>"
	" </interface>"
	" <interface name=\"org.freedesktop.DBus.Properties\">"
	"  <method name=\"Get\">"
	"   <arg name=\"interface\" direction=\"in\" type=\"s\"/>"
	"   <arg name=\"property\" direction=\"in\" type=\"s\"/>"
	"   <arg name=\"value\" direction=\"out\" type=\"v\"/>"
	"  </method>"
	" </interface>"
	" <interface name=\"org.freedesktop.DBus.Introspectable\">"
	"  <method name=\"Introspect\">"
	"   <arg name=\"data\" type=\"s\" direction=\"out\"/>"
	"  </method>"
	" </interface>"
	"</node>";

struct rd_device {
	DBusConnection *connection;

	int32_t priority;
	char *service_name;
	char *object_path;
	char *application_name;
	char *application_device_name;

	const struct rd_device_callbacks *callbacks;
	void *data;

	DBusMessage *reply;

	unsigned int filtering:1;
	unsigned int registered:1;
	unsigned int acquiring:1;
	unsigned int owning:1;
};

static dbus_bool_t add_variant(DBusMessage *m, int type, const void *data)
{
	DBusMessageIter iter, sub;
	char t[2];

	t[0] = (char) type;
	t[1] = 0;

	dbus_message_iter_init_append(m, &iter);

	if (!dbus_message_iter_open_container(&iter, DBUS_TYPE_VARIANT, t, &sub))
		return false;

	if (!dbus_message_iter_append_basic(&sub, type, data))
		return false;

	if (!dbus_message_iter_close_container(&iter, &sub))
		return false;

	return true;
}

static DBusHandlerResult object_handler(DBusConnection *c, DBusMessage *m, void *userdata)
{
	struct rd_device *d = userdata;
	DBusError error;
	DBusMessage *reply = NULL;

	dbus_error_init(&error);

	if (dbus_message_is_method_call(m, "org.freedesktop.ReserveDevice1",
				"RequestRelease")) {
		int32_t priority;

		if (!dbus_message_get_args(m, &error,
					DBUS_TYPE_INT32, &priority,
					DBUS_TYPE_INVALID))
			goto invalid;

		pw_log_debug(NAME" %p: request release priority:%d", d, priority);

		if (!(reply = dbus_message_new_method_return(m)))
			goto oom;

		if (d->reply)
			rd_device_complete_release(d, false);
		d->reply = reply;

		if (priority > d->priority && d->callbacks->release)
			d->callbacks->release(d->data, d, 0);
		else
			rd_device_complete_release(d, false);

		return DBUS_HANDLER_RESULT_HANDLED;

	} else if (dbus_message_is_method_call(
			   m,
			   "org.freedesktop.DBus.Properties",
			   "Get")) {

		const char *interface, *property;

		if (!dbus_message_get_args( m, &error,
					DBUS_TYPE_STRING, &interface,
					DBUS_TYPE_STRING, &property,
					DBUS_TYPE_INVALID))
			goto invalid;

		if (strcmp(interface, "org.freedesktop.ReserveDevice1") == 0) {
			const char *empty = "";

			if (strcmp(property, "ApplicationName") == 0 && d->application_name) {
				if (!(reply = dbus_message_new_method_return(m)))
					goto oom;

				if (!add_variant(reply,
					    DBUS_TYPE_STRING,
					    d->application_name ? (const char**) &d->application_name : &empty))
					goto oom;

			} else if (strcmp(property, "ApplicationDeviceName") == 0) {
				if (!(reply = dbus_message_new_method_return(m)))
					goto oom;

				if (!add_variant(reply,
					    DBUS_TYPE_STRING,
					    d->application_device_name ? (const char**) &d->application_device_name : &empty))
					goto oom;

			} else if (strcmp(property, "Priority") == 0) {
				if (!(reply = dbus_message_new_method_return(m)))
					goto oom;

				if (!add_variant(reply,
					    DBUS_TYPE_INT32, &d->priority))
					goto oom;
			} else {
				if (!(reply = dbus_message_new_error_printf(m,
								DBUS_ERROR_UNKNOWN_METHOD,
								"Unknown property %s", property)))
					goto oom;
			}

			if (!dbus_connection_send(c, reply, NULL))
				goto oom;

			dbus_message_unref(reply);

			return DBUS_HANDLER_RESULT_HANDLED;
		}

	} else if (dbus_message_is_method_call(
			   m,
			   "org.freedesktop.DBus.Introspectable",
			   "Introspect")) {
			    const char *i = introspection;

		if (!(reply = dbus_message_new_method_return(m)))
			goto oom;

		if (!dbus_message_append_args(reply,
					DBUS_TYPE_STRING, &i,
					DBUS_TYPE_INVALID))
			goto oom;

		if (!dbus_connection_send(c, reply, NULL))
			goto oom;

		dbus_message_unref(reply);

		return DBUS_HANDLER_RESULT_HANDLED;
	}

	return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

invalid:
	if (!(reply = dbus_message_new_error(m,
					DBUS_ERROR_INVALID_ARGS,
					"Invalid arguments")))
		goto oom;

	if (!dbus_connection_send(c, reply, NULL))
		goto oom;

	dbus_message_unref(reply);

	dbus_error_free(&error);

	return DBUS_HANDLER_RESULT_HANDLED;

oom:
	if (reply)
		dbus_message_unref(reply);

	dbus_error_free(&error);

	return DBUS_HANDLER_RESULT_NEED_MEMORY;
}

static const struct DBusObjectPathVTable vtable ={
	.message_function = object_handler
};

static DBusHandlerResult filter_handler(DBusConnection *c, DBusMessage *m, void *userdata)
{

	struct rd_device *d = userdata;
	DBusError error;
	const char *name;

	dbus_error_init(&error);

	if (dbus_message_is_signal(m, "org.freedesktop.DBus", "NameAcquired")) {
		if (!dbus_message_get_args( m, &error,
			    DBUS_TYPE_STRING, &name,
			    DBUS_TYPE_INVALID))
			goto invalid;

		if (strcmp(name, d->service_name) != 0)
			goto invalid;

		pw_log_debug(NAME" %p: acquired %s, %s", d, name, d->service_name);

		d->owning = true;

		if (!d->registered) {
			if (!(dbus_connection_register_object_path(d->connection,
							d->object_path,
							&vtable,
							d)))
				goto invalid;

			if (strcmp(name, d->service_name) != 0)
				goto invalid;

			d->registered = true;

			if (d->callbacks->acquired)
				d->callbacks->acquired(d->data, d);
		}
	} else if (dbus_message_is_signal(m, "org.freedesktop.DBus", "NameLost")) {
		if (!dbus_message_get_args( m, &error,
			    DBUS_TYPE_STRING, &name,
			    DBUS_TYPE_INVALID))
			goto invalid;

		if (strcmp(name, d->service_name) != 0)
			goto invalid;

		pw_log_debug(NAME" %p: lost %s", d, name);

		d->owning = false;

		if (d->registered) {
			dbus_connection_unregister_object_path(d->connection,
					d->object_path);
			d->registered = false;
		}
	}
	if (dbus_message_is_signal(m, "org.freedesktop.DBus", "NameOwnerChanged")) {
		const char *old, *new;
		if (!dbus_message_get_args( m, &error,
			    DBUS_TYPE_STRING, &name,
			    DBUS_TYPE_STRING, &old,
			    DBUS_TYPE_STRING, &new,
			    DBUS_TYPE_INVALID))
			goto invalid;

		if (strcmp(name, d->service_name) != 0 || d->owning)
			goto invalid;

		pw_log_debug(NAME" %p: changed %s: %s -> %s", d, name, old, new);

		if (old == NULL || *old == 0) {
			if (d->callbacks->busy && !d->acquiring)
				d->callbacks->busy(d->data, d, name, 0);
		} else {
			if (d->callbacks->available)
				d->callbacks->available(d->data, d, name);
		}
	}

invalid:
	dbus_error_free(&error);
	return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

struct rd_device *
rd_device_new(DBusConnection *connection, const char *device_name, const char *application_name,
		int32_t priority, const struct rd_device_callbacks *callbacks, void *data)
{
	struct rd_device *d;
	int res;

	d = calloc(1, sizeof(struct rd_device));
	if (d == NULL)
		return NULL;

	d->connection = connection;
	d->priority = priority;
	d->callbacks = callbacks;
	d->data = data;

	d->application_name = strdup(application_name);

	d->object_path = spa_aprintf(OBJECT_PREFIX "%s", device_name);
	if (d->object_path == NULL) {
		res = -errno;
		goto error_free;
	}
	d->service_name = spa_aprintf(SERVICE_PREFIX "%s", device_name);
	if (d->service_name == NULL) {
		res = -errno;
		goto error_free;
	}

	if (!dbus_connection_add_filter(d->connection,
				filter_handler,
				d,
				NULL)) {
		res = -ENOMEM;
		goto error_free;
	}
	dbus_bus_add_match(d->connection,
                        "type='signal',sender='org.freedesktop.DBus',"
                        "interface='org.freedesktop.DBus',member='NameLost'", NULL);
	dbus_bus_add_match(d->connection,
                        "type='signal',sender='org.freedesktop.DBus',"
                        "interface='org.freedesktop.DBus',member='NameAcquired'", NULL);
	dbus_bus_add_match(d->connection,
                        "type='signal',sender='org.freedesktop.DBus',"
                        "interface='org.freedesktop.DBus',member='NameOwnerChanged'", NULL);

	dbus_connection_ref(d->connection);

	pw_log_debug(NAME"%p: new device %s", d, device_name);

	return d;

error_free:
	free(d->service_name);
	free(d->object_path);
	free(d);
	errno = -res;
	return NULL;
}

int rd_device_acquire(struct rd_device *d)
{
	int res;
	DBusError error;

	dbus_error_init(&error);

	pw_log_debug(NAME"%p: reserve %s", d, d->service_name);

	d->acquiring = true;

	if ((res = dbus_bus_request_name(d->connection,
					d->service_name,
					(d->priority < INT32_MAX ? DBUS_NAME_FLAG_ALLOW_REPLACEMENT : 0),
					&error)) < 0) {
			dbus_error_free(&error);
	}

	if (res != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER)
		return -EBUSY;

	return 0;
}

int rd_device_request_release(struct rd_device *d)
{
	DBusMessage *m = NULL;

	if (d->priority <= INT32_MIN)
		return -EBUSY;

	if ((m = dbus_message_new_method_call(d->service_name,
					d->object_path,
					"org.freedesktop.ReserveDevice1",
					"RequestRelease")) == NULL) {
		return -ENOMEM;
	}
        if (!dbus_message_append_args(m,
				DBUS_TYPE_INT32, &d->priority,
				DBUS_TYPE_INVALID)) {
		dbus_message_unref(m);
		return -ENOMEM;
        }
	if (!dbus_connection_send(d->connection, m, NULL)) {
		return -ENOMEM;
	}
	return 0;
}

int rd_device_complete_release(struct rd_device *d, int res)
{
	dbus_bool_t ret = res != 0;

	if (d->reply == NULL)
		return -EINVAL;

	pw_log_debug(NAME" %p: complete release %d", d, res);

	if (!dbus_message_append_args(d->reply,
				DBUS_TYPE_BOOLEAN, &ret,
				DBUS_TYPE_INVALID)) {
		res = -ENOMEM;
		goto exit;
	}

	if (!dbus_connection_send(d->connection, d->reply, NULL)) {
		res = -ENOMEM;
		goto exit;
	}
	res = 0;
exit:
	dbus_message_unref(d->reply);
	d->reply = NULL;
	return res;
}

void rd_device_release(struct rd_device *d)
{
	pw_log_debug(NAME" %p: release %d", d, d->owning);

	if (d->owning) {
		DBusError error;
		dbus_error_init(&error);

		dbus_bus_release_name(d->connection,
				d->service_name, &error);
		dbus_error_free(&error);
	}
	d->acquiring = false;
}

void rd_device_destroy(struct rd_device *d)
{
	dbus_connection_remove_filter(d->connection,
			filter_handler, d);

	if (d->registered)
		dbus_connection_unregister_object_path(d->connection,
				d->object_path);

	rd_device_release(d);

	free(d->service_name);
	free(d->object_path);
	free(d->application_name);
	free(d->application_device_name);
	if (d->reply)
		dbus_message_unref(d->reply);

	dbus_connection_unref(d->connection);

	free(d);
}

int rd_device_set_application_device_name(struct rd_device *d, const char *name)
{
	char *t;

	if (!d)
		return -EINVAL;

	if (!(t = strdup(name)))
		return -ENOMEM;

	free(d->application_device_name);
	d->application_device_name = t;

	return 0;
}
