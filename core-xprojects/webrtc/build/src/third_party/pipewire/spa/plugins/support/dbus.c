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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <dbus/dbus.h>

#include <spa/utils/type.h>
#include <spa/utils/names.h>
#include <spa/support/log.h>
#include <spa/support/plugin.h>
#include <spa/support/dbus.h>

#define NAME "dbus"

struct impl {
	struct spa_handle handle;
	struct spa_dbus dbus;

	struct spa_log *log;
	struct spa_loop_utils *utils;

	struct spa_list connection_list;
};

struct source_data {
	struct spa_list link;
	struct spa_source *source;
	struct connection *conn;
};

struct connection {
	struct spa_list link;

	struct spa_dbus_connection this;
	struct impl *impl;
	DBusConnection *conn;
	struct spa_source *dispatch_event;
	struct spa_list source_list;
};

static void source_data_free(void *data)
{
	struct source_data *d = data;
	struct connection *conn = d->conn;
	struct impl *impl = conn->impl;

	spa_list_remove(&d->link);
	spa_loop_utils_destroy_source(impl->utils, d->source);
	free(d);
}

static void dispatch_cb(void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;

	if (dbus_connection_dispatch(conn->conn) == DBUS_DISPATCH_COMPLETE)
		spa_loop_utils_enable_idle(impl->utils, conn->dispatch_event, false);
}

static void dispatch_status(DBusConnection *conn, DBusDispatchStatus status, void *userdata)
{
	struct connection *c = userdata;
	struct impl *impl = c->impl;

	spa_loop_utils_enable_idle(impl->utils, c->dispatch_event,
			status == DBUS_DISPATCH_COMPLETE ? false : true);
}

static inline uint32_t dbus_to_io(DBusWatch *watch)
{
	uint32_t mask;
	unsigned int flags;

	/* no watch flags for disabled watches */
	if (!dbus_watch_get_enabled(watch))
		return 0;

	flags = dbus_watch_get_flags(watch);
	mask = SPA_IO_HUP | SPA_IO_ERR;

	if (flags & DBUS_WATCH_READABLE)
		mask |= SPA_IO_IN;
	if (flags & DBUS_WATCH_WRITABLE)
		mask |= SPA_IO_OUT;

	return mask;
}

static inline unsigned int io_to_dbus(uint32_t mask)
{
	unsigned int flags = 0;

	if (mask & SPA_IO_IN)
		flags |= DBUS_WATCH_READABLE;
	if (mask & SPA_IO_OUT)
		flags |= DBUS_WATCH_WRITABLE;
	if (mask & SPA_IO_HUP)
		flags |= DBUS_WATCH_HANGUP;
	if (mask & SPA_IO_ERR)
		flags |= DBUS_WATCH_ERROR;
	return flags;
}

static void
handle_io_event(void *userdata, int fd, uint32_t mask)
{
	DBusWatch *watch = userdata;

	if (!dbus_watch_get_enabled(watch)) {
		fprintf(stderr, "Asked to handle disabled watch: %p %i", (void *) watch, fd);
		return;
	}
	dbus_watch_handle(watch, io_to_dbus(mask));
}

static dbus_bool_t add_watch(DBusWatch *watch, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	struct source_data *data;

	spa_log_debug(impl->log, "add watch %p %d", watch, dbus_watch_get_unix_fd(watch));

	data = calloc(1, sizeof(struct source_data));
	data->conn = conn;
	/* we dup because dbus tends to add the same fd multiple times and our epoll
	 * implementation does not like that */
	data->source = spa_loop_utils_add_io(impl->utils,
				dup(dbus_watch_get_unix_fd(watch)),
				dbus_to_io(watch), true, handle_io_event, watch);
	spa_list_append(&conn->source_list, &data->link);

	dbus_watch_set_data(watch, data, source_data_free);
	return TRUE;
}

static void remove_watch(DBusWatch *watch, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	spa_log_debug(impl->log, "remove watch %p", watch);
	dbus_watch_set_data(watch, NULL, NULL);
}

static void toggle_watch(DBusWatch *watch, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	struct source_data *data;

	spa_log_debug(impl->log, "toggle watch %p", watch);

	if ((data = dbus_watch_get_data(watch)) != NULL)
		spa_loop_utils_update_io(impl->utils, data->source, dbus_to_io(watch));
}

static void
handle_timer_event(void *userdata, uint64_t expirations)
{
	DBusTimeout *timeout = userdata;
	uint64_t t;
	struct timespec ts;
	struct source_data *data = dbus_timeout_get_data(timeout);
	struct connection *conn = data->conn;
	struct impl *impl = conn->impl;

	spa_log_debug(impl->log, "timeout %p conn:%p impl:%p", timeout, conn, impl);

	if (dbus_timeout_get_enabled(timeout)) {
		t = dbus_timeout_get_interval(timeout) * SPA_NSEC_PER_MSEC;
		ts.tv_sec = t / SPA_NSEC_PER_SEC;
		ts.tv_nsec = t % SPA_NSEC_PER_SEC;
		spa_loop_utils_update_timer(impl->utils,
				     data->source, &ts, NULL, false);
		dbus_timeout_handle(timeout);
	}
}

static dbus_bool_t add_timeout(DBusTimeout *timeout, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	struct timespec ts;
	struct source_data *data;
	uint64_t t;

	if (!dbus_timeout_get_enabled(timeout))
		return FALSE;

	spa_log_debug(impl->log, "add timeout %p conn:%p impl:%p", timeout, conn, impl);

	data = calloc(1, sizeof(struct source_data));
	data->conn = conn;
	data->source = spa_loop_utils_add_timer(impl->utils, handle_timer_event, timeout);
	spa_list_append(&conn->source_list, &data->link);

	dbus_timeout_set_data(timeout, data, source_data_free);

	t = dbus_timeout_get_interval(timeout) * SPA_NSEC_PER_MSEC;
	ts.tv_sec = t / SPA_NSEC_PER_SEC;
	ts.tv_nsec = t % SPA_NSEC_PER_SEC;
	spa_loop_utils_update_timer(impl->utils, data->source, &ts, NULL, false);

	return TRUE;
}

static void remove_timeout(DBusTimeout *timeout, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	spa_log_debug(impl->log, "remove timeout %p conn:%p impl:%p", timeout, conn, impl);
	dbus_timeout_set_data(timeout, NULL, NULL);
}

static void toggle_timeout(DBusTimeout *timeout, void *userdata)
{
	struct connection *conn = userdata;
	struct impl *impl = conn->impl;
	struct source_data *data;
	struct timespec ts, *tsp;

	data = dbus_timeout_get_data(timeout);

	spa_log_debug(impl->log, "toggle timeout %p conn:%p impl:%p", timeout, conn, impl);

	if (dbus_timeout_get_enabled(timeout)) {
		uint64_t t = dbus_timeout_get_interval(timeout) * SPA_NSEC_PER_MSEC;
		ts.tv_sec = t / SPA_NSEC_PER_SEC;
		ts.tv_nsec = t % SPA_NSEC_PER_SEC;
		tsp = &ts;
	} else {
		tsp = NULL;
	}
	spa_loop_utils_update_timer(impl->utils, data->source, tsp, NULL, false);
}

static void wakeup_main(void *userdata)
{
	struct connection *this = userdata;
	struct impl *impl = this->impl;

	spa_loop_utils_enable_idle(impl->utils, this->dispatch_event, true);
}

static void *
impl_connection_get(struct spa_dbus_connection *conn)
{
	struct connection *this = SPA_CONTAINER_OF(conn, struct connection, this);
	return this->conn;
}

static void connection_free(struct connection *conn)
{
	struct impl *impl = conn->impl;
	struct source_data *data;

	spa_list_remove(&conn->link);

	dbus_connection_close(conn->conn);
	dbus_connection_unref(conn->conn);

	spa_list_consume(data, &conn->source_list, link)
		source_data_free(data);

	spa_loop_utils_destroy_source(impl->utils, conn->dispatch_event);

	free(conn);
}

static void
impl_connection_destroy(struct spa_dbus_connection *conn)
{
	struct connection *this = SPA_CONTAINER_OF(conn, struct connection, this);
	struct impl *impl = this->impl;

	spa_log_debug(impl->log, "destroy conn %p", this);
	connection_free(this);
}

static const struct spa_dbus_connection impl_connection = {
	SPA_VERSION_DBUS_CONNECTION,
	impl_connection_get,
	impl_connection_destroy,
};

static struct spa_dbus_connection *
impl_get_connection(void *object,
		    enum spa_dbus_type type)
{
        struct impl *impl = object;
	struct connection *conn;
        DBusError error;
	int res;

	dbus_error_init(&error);

	conn = calloc(1, sizeof(struct connection));
	conn->this = impl_connection;
	conn->impl = impl;
	conn->conn = dbus_bus_get_private((DBusBusType)type, &error);
	if (conn->conn == NULL)
		goto error;

	conn->dispatch_event = spa_loop_utils_add_idle(impl->utils,
						false, dispatch_cb, conn);
	if (conn->dispatch_event == NULL)
		goto no_event;

	spa_list_init(&conn->source_list);

	dbus_connection_set_exit_on_disconnect(conn->conn, false);
	dbus_connection_set_dispatch_status_function(conn->conn, dispatch_status, conn, NULL);
	dbus_connection_set_watch_functions(conn->conn, add_watch, remove_watch, toggle_watch, conn,
					    NULL);
	dbus_connection_set_timeout_functions(conn->conn, add_timeout, remove_timeout,
					      toggle_timeout, conn, NULL);
	dbus_connection_set_wakeup_main_function(conn->conn, wakeup_main, conn, NULL);

	spa_list_append(&impl->connection_list, &conn->link);

	spa_log_debug(impl->log, "new conn %p", conn);

	return &conn->this;

      error:
	spa_log_error(impl->log, "Failed to connect to system bus: %s", error.message);
	dbus_error_free(&error);
	res = -ECONNREFUSED;
	goto out_free;
      no_event:
	res = -errno;
	spa_log_error(impl->log, "Failed to create idle event: %m");
	goto out_unref_dbus;

      out_unref_dbus:
	dbus_connection_close(conn->conn);
	dbus_connection_unref(conn->conn);
      out_free:
	free(conn);
	errno = -res;
	return NULL;
}

static const struct spa_dbus_methods impl_dbus = {
	SPA_VERSION_DBUS_METHODS,
	.get_connection = impl_get_connection,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_DBus) == 0)
		*interface = &this->dbus;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	struct impl *impl = (struct impl *) handle;
	struct connection *conn;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	spa_list_consume(conn, &impl->connection_list, link)
		connection_free(conn);
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

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;
	spa_list_init(&this->connection_list);

	this->dbus.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_DBus,
			SPA_VERSION_DBUS,
			&impl_dbus, this);

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->utils = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_LoopUtils);

	if (this->utils == NULL) {
		spa_log_error(this->log, "a LoopUtils is needed");
		return -EINVAL;
	}

	spa_log_debug(this->log, NAME " %p: initialized", this);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_DBus,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*info = &impl_interfaces[*index];
		break;
	default:
		return 0;
	}
	(*index)++;

	return 1;
}

static const struct spa_handle_factory dbus_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_SUPPORT_DBUS,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};

SPA_EXPORT
int spa_handle_factory_enum(const struct spa_handle_factory **factory, uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*factory = &dbus_factory;
		break;
	default:
		return 0;
	}
	(*index)++;
	return 1;
}
