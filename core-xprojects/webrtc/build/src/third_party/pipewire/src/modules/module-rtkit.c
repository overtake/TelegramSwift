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

#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifdef __FreeBSD__
#include <sys/thr.h>
#endif
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/resource.h>

#include "config.h"

#include <spa/support/dbus.h>
#include <spa/utils/result.h>

#include <pipewire/impl.h>

#define DEFAULT_NICE_LEVEL	-11
#define DEFAULT_RT_PRIO		88
#define DEFAULT_RT_TIME_SOFT	200000
#define DEFAULT_RT_TIME_HARD	200000

#define MODULE_USAGE	"[nice.level=<priority: default "SPA_STRINGIFY(DEFAULT_NICE_LEVEL) ">] "	\
			"[rt.prio=<priority: default "SPA_STRINGIFY(DEFAULT_RT_PRIO) ">] "		\
			"[rt.time.soft=<in usec: default "SPA_STRINGIFY(DEFAULT_RT_TIME_SOFT)"] "	\
			"[rt.time.hard=<in usec: default "SPA_STRINGIFY(DEFAULT_RT_TIME_HARD)"] "

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Use RTKit to raise thread priorities" },
	{ PW_KEY_MODULE_USAGE, MODULE_USAGE },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct pw_rtkit_bus;

struct impl {
	struct pw_context *context;

	struct spa_loop *loop;
	struct spa_system *system;
	struct spa_source source;
	struct pw_properties *props;

	struct pw_rtkit_bus *system_bus;

	int nice_level;
	int rt_prio;
	rlim_t rt_time_soft;
	rlim_t rt_time_hard;

	struct spa_hook module_listener;
};

/***
  Copyright 2009 Lennart Poettering
  Copyright 2010 David Henningsson <diwic@ubuntu.com>

  Permission is hereby granted, free of charge, to any person
  obtaining a copy of this software and associated documentation files
  (the "Software"), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge,
  publish, distribute, sublicense, and/or sell copies of the Software,
  and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
***/

#include <dbus/dbus.h>

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/syscall.h>

#define RTKIT_SERVICE_NAME "org.freedesktop.RealtimeKit1"
#define RTKIT_OBJECT_PATH "/org/freedesktop/RealtimeKit1"

#ifndef RLIMIT_RTTIME
#define RLIMIT_RTTIME 15
#endif

/** \cond */
struct pw_rtkit_bus {
	DBusConnection *bus;
};
/** \endcond */

struct pw_rtkit_bus *pw_rtkit_bus_get_system(void)
{
	struct pw_rtkit_bus *bus;
	DBusError error;

	if (getenv("DISABLE_RTKIT")) {
		errno = ENOTSUP;
		return NULL;
	}

	dbus_error_init(&error);

	bus = calloc(1, sizeof(struct pw_rtkit_bus));
	if (bus == NULL)
		return NULL;

	bus->bus = dbus_bus_get_private(DBUS_BUS_SYSTEM, &error);
	if (bus->bus == NULL)
		goto error;

	dbus_connection_set_exit_on_disconnect(bus->bus, false);

	return bus;

error:
	free(bus);
	pw_log_error("Failed to connect to system bus: %s", error.message);
	dbus_error_free(&error);
	errno = ECONNREFUSED;
	return NULL;
}

void pw_rtkit_bus_free(struct pw_rtkit_bus *system_bus)
{
	dbus_connection_close(system_bus->bus);
	dbus_connection_unref(system_bus->bus);
	free(system_bus);
}

static pid_t _gettid(void)
{
#ifndef __FreeBSD__
	return (pid_t) syscall(SYS_gettid);
#else
	long pid;
	thr_self(&pid);
	return (pid_t)pid;
#endif
}

static int translate_error(const char *name)
{
	pw_log_warn("RTKit error: %s", name);

	if (0 == strcmp(name, DBUS_ERROR_NO_MEMORY))
		return -ENOMEM;
	if (0 == strcmp(name, DBUS_ERROR_SERVICE_UNKNOWN) ||
	    0 == strcmp(name, DBUS_ERROR_NAME_HAS_NO_OWNER))
		return -ENOENT;
	if (0 == strcmp(name, DBUS_ERROR_ACCESS_DENIED) ||
	    0 == strcmp(name, DBUS_ERROR_AUTH_FAILED))
		return -EACCES;

	return -EIO;
}

static long long rtkit_get_int_property(struct pw_rtkit_bus *connection, const char *propname,
					long long *propval)
{
	DBusMessage *m = NULL, *r = NULL;
	DBusMessageIter iter, subiter;
	dbus_int64_t i64;
	dbus_int32_t i32;
	DBusError error;
	int current_type;
	long long ret;
	const char *interfacestr = "org.freedesktop.RealtimeKit1";

	dbus_error_init(&error);

	if (!(m = dbus_message_new_method_call(RTKIT_SERVICE_NAME,
					       RTKIT_OBJECT_PATH,
					       "org.freedesktop.DBus.Properties", "Get"))) {
		ret = -ENOMEM;
		goto finish;
	}

	if (!dbus_message_append_args(m,
				      DBUS_TYPE_STRING, &interfacestr,
				      DBUS_TYPE_STRING, &propname, DBUS_TYPE_INVALID)) {
		ret = -ENOMEM;
		goto finish;
	}

	if (!(r = dbus_connection_send_with_reply_and_block(connection->bus, m, -1, &error))) {
		ret = translate_error(error.name);
		goto finish;
	}

	if (dbus_set_error_from_message(&error, r)) {
		ret = translate_error(error.name);
		goto finish;
	}

	ret = -EBADMSG;
	dbus_message_iter_init(r, &iter);
	while ((current_type = dbus_message_iter_get_arg_type(&iter)) != DBUS_TYPE_INVALID) {

		if (current_type == DBUS_TYPE_VARIANT) {
			dbus_message_iter_recurse(&iter, &subiter);

			while ((current_type =
				dbus_message_iter_get_arg_type(&subiter)) != DBUS_TYPE_INVALID) {

				if (current_type == DBUS_TYPE_INT32) {
					dbus_message_iter_get_basic(&subiter, &i32);
					*propval = i32;
					ret = 0;
				}

				if (current_type == DBUS_TYPE_INT64) {
					dbus_message_iter_get_basic(&subiter, &i64);
					*propval = i64;
					ret = 0;
				}

				dbus_message_iter_next(&subiter);
			}
		}
		dbus_message_iter_next(&iter);
	}

finish:

	if (m)
		dbus_message_unref(m);

	if (r)
		dbus_message_unref(r);

	dbus_error_free(&error);

	return ret;
}

int pw_rtkit_get_max_realtime_priority(struct pw_rtkit_bus *connection)
{
	long long retval;
	int err;

	err = rtkit_get_int_property(connection, "MaxRealtimePriority", &retval);
	return err < 0 ? err : retval;
}

int pw_rtkit_get_min_nice_level(struct pw_rtkit_bus *connection, int *min_nice_level)
{
	long long retval;
	int err;

	err = rtkit_get_int_property(connection, "MinNiceLevel", &retval);
	if (err >= 0)
		*min_nice_level = retval;
	return err;
}

long long pw_rtkit_get_rttime_usec_max(struct pw_rtkit_bus *connection)
{
	long long retval;
	int err;

	err = rtkit_get_int_property(connection, "RTTimeUSecMax", &retval);
	return err < 0 ? err : retval;
}

int pw_rtkit_make_realtime(struct pw_rtkit_bus *connection, pid_t thread, int priority)
{
	DBusMessage *m = NULL, *r = NULL;
	dbus_uint64_t u64;
	dbus_uint32_t u32;
	DBusError error;
	int ret;

	dbus_error_init(&error);

	if (thread == 0)
		thread = _gettid();

	if (!(m = dbus_message_new_method_call(RTKIT_SERVICE_NAME,
					       RTKIT_OBJECT_PATH,
					       "org.freedesktop.RealtimeKit1",
					       "MakeThreadRealtime"))) {
		ret = -ENOMEM;
		goto finish;
	}

	u64 = (dbus_uint64_t) thread;
	u32 = (dbus_uint32_t) priority;

	if (!dbus_message_append_args(m,
				      DBUS_TYPE_UINT64, &u64,
				      DBUS_TYPE_UINT32, &u32, DBUS_TYPE_INVALID)) {
		ret = -ENOMEM;
		goto finish;
	}

	if (!(r = dbus_connection_send_with_reply_and_block(connection->bus, m, -1, &error))) {
		ret = translate_error(error.name);
		goto finish;
	}


	if (dbus_set_error_from_message(&error, r)) {
		ret = translate_error(error.name);
		goto finish;
	}

	ret = 0;

finish:

	if (m)
		dbus_message_unref(m);

	if (r)
		dbus_message_unref(r);

	dbus_error_free(&error);

	return ret;
}

int pw_rtkit_make_high_priority(struct pw_rtkit_bus *connection, pid_t thread, int nice_level)
{
	DBusMessage *m = NULL, *r = NULL;
	dbus_uint64_t u64;
	dbus_int32_t s32;
	DBusError error;
	int ret;

	dbus_error_init(&error);

	if (thread == 0)
		thread = _gettid();

	if (!(m = dbus_message_new_method_call(RTKIT_SERVICE_NAME,
					       RTKIT_OBJECT_PATH,
					       "org.freedesktop.RealtimeKit1",
					       "MakeThreadHighPriority"))) {
		ret = -ENOMEM;
		goto finish;
	}

	u64 = (dbus_uint64_t) thread;
	s32 = (dbus_int32_t) nice_level;

	if (!dbus_message_append_args(m,
				      DBUS_TYPE_UINT64, &u64,
				      DBUS_TYPE_INT32, &s32, DBUS_TYPE_INVALID)) {
		ret = -ENOMEM;
		goto finish;
	}



	if (!(r = dbus_connection_send_with_reply_and_block(connection->bus, m, -1, &error))) {
		ret = translate_error(error.name);
		goto finish;
	}


	if (dbus_set_error_from_message(&error, r)) {
		ret = translate_error(error.name);
		goto finish;
	}

	ret = 0;

finish:

	if (m)
		dbus_message_unref(m);

	if (r)
		dbus_message_unref(r);

	dbus_error_free(&error);

	return ret;
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct spa_source *source = user_data;
	spa_loop_remove_source(loop, source);
	return 0;
}

static void module_destroy(void *data)
{
	struct impl *impl = data;

	spa_hook_remove(&impl->module_listener);

	if (impl->source.fd != -1) {
		spa_loop_invoke(impl->loop,
				do_remove_source,
				SPA_ID_INVALID,
				NULL,
				0,
				true,
				&impl->source);
		spa_system_close(impl->system, impl->source.fd);
		impl->source.fd = -1;
	}
	pw_properties_free(impl->props);
	if (impl->system_bus)
		pw_rtkit_bus_free(impl->system_bus);
	free(impl);
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy,
};

static void idle_func(struct spa_source *source)
{
	struct impl *impl = source->data;
	struct sched_param sp;
	struct rlimit rl;
	int r, rtprio;
	long long rttime;
	uint64_t count;

	spa_system_eventfd_read(impl->system, impl->source.fd, &count);

	rtprio = pw_rtkit_get_max_realtime_priority(impl->system_bus);
	if (rtprio >= 0)
		rtprio = SPA_MIN(rtprio, impl->rt_prio);
	else
		rtprio = impl->rt_prio;

	spa_zero(sp);
	sp.sched_priority = rtprio;

#ifndef __FreeBSD__
	if (pthread_setschedparam(pthread_self(), SCHED_OTHER | SCHED_RESET_ON_FORK, &sp) == 0) {
		pw_log_debug("SCHED_OTHER|SCHED_RESET_ON_FORK worked.");
		goto exit;
	}
#endif

	rl.rlim_cur = impl->rt_time_soft;
	rl.rlim_max = impl->rt_time_hard;

	rttime = pw_rtkit_get_rttime_usec_max(impl->system_bus);
	if (rttime >= 0) {
		rl.rlim_cur = SPA_MIN(rl.rlim_cur, (rlim_t)rttime);
		rl.rlim_max = SPA_MIN(rl.rlim_max, (rlim_t)rttime);
	}

	pw_log_debug("rt.prio:%d rt.time.soft:%"PRIi64" rt.time.hard:%"PRIi64,
			rtprio, (int64_t)rl.rlim_cur, (int64_t)rl.rlim_max);

	if ((r = setrlimit(RLIMIT_RTTIME, &rl)) < 0)
		pw_log_debug("setrlimit() failed: %s", strerror(errno));

	if ((r = pw_rtkit_make_realtime(impl->system_bus, 0, rtprio)) < 0) {
		pw_log_warn("could not make thread realtime: %s", spa_strerror(r));
	} else {
		pw_log_info("processing thread made realtime prio:%d", rtprio);
	}
exit:
	pw_rtkit_bus_free(impl->system_bus);
	impl->system_bus = NULL;
}

static int set_nice(struct impl *impl, int nice_level)
{
	int res;
	if ((res = pw_rtkit_make_high_priority(impl->system_bus, 0, nice_level)) < 0) {
		pw_log_warn("could not set nice-level to %d: %s",
				nice_level, spa_strerror(res));
	} else {
		pw_log_info("main thread nice level set to %d", nice_level);
	}
	return 0;
}

static int get_default_int(struct pw_properties *properties, const char *name, int def)
{
	int val;
	const char *str;
	if ((str = pw_properties_get(properties, name)) != NULL)
		val = atoi(str);
	else {
		val = def;
		pw_properties_setf(properties, name, "%d", val);
	}
	return val;
}

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct impl *impl;
	struct spa_loop *loop;
	struct spa_system *system;
	const struct spa_support *support;
	uint32_t n_support;
	const struct pw_properties *props;
	const char *str;
	int res;

	support = pw_context_get_support(context, &n_support);

	loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);
        if (loop == NULL)
                return -ENOTSUP;

	system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);
        if (system == NULL)
                return -ENOTSUP;

	if ((props = pw_context_get_properties(context)) != NULL &&
	    (str = pw_properties_get(props, "support.dbus")) != NULL &&
	    !pw_properties_parse_bool(str))
		return -ENOTSUP;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -ENOMEM;

	pw_log_debug("module %p: new", impl);

	impl->context = context;
	impl->loop = loop;
	impl->system = system;
	impl->props = args ? pw_properties_new_string(args) : pw_properties_new(NULL, NULL);
	if (impl->props == NULL) {
		res = -errno;
		goto error;
	}

	impl->system_bus = pw_rtkit_bus_get_system();
	if (impl->system_bus == NULL) {
		res = -errno;
		pw_log_warn("could not get system bus: %m");
		goto error;
	}
	impl->nice_level = get_default_int(impl->props, "nice.level", DEFAULT_NICE_LEVEL);

	set_nice(impl, impl->nice_level);

	impl->rt_prio = get_default_int(impl->props, "rt.prio", DEFAULT_RT_PRIO);
	impl->rt_time_soft = get_default_int(impl->props, "rt.time.soft", DEFAULT_RT_TIME_SOFT);
	impl->rt_time_hard = get_default_int(impl->props, "rt.time.hard", DEFAULT_RT_TIME_HARD);

	impl->source.loop = loop;
	impl->source.func = idle_func;
	impl->source.data = impl;
	impl->source.fd = spa_system_eventfd_create(system, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);
	impl->source.mask = SPA_IO_IN;
	if (impl->source.fd == -1) {
		res = -errno;
		goto error;
	}

	spa_loop_add_source(impl->loop, &impl->source);
	spa_system_eventfd_write(system, impl->source.fd, 1);

	pw_impl_module_add_listener(module, &impl->module_listener, &module_events, impl);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));
	pw_impl_module_update_properties(module, &impl->props->dict);

	return 0;

error:
	if (impl->props)
		pw_properties_free(impl->props);
	if (impl->system_bus)
		pw_rtkit_bus_free(impl->system_bus);
	free(impl);
	return res;
}
