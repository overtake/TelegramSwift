/* PipeWire
 *
 * Copyright © 2021 Florian Hülsmann <fh@cbix.de>
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <unistd.h>
#include <signal.h>

#include <jack/control.h>
#include <jack/jslist.h>

#include <pipewire/pipewire.h>

struct jackctl_sigmask
{
	sigset_t signals;
};

struct jackctl_sigmask sigmask;

SPA_EXPORT
jackctl_sigmask_t * jackctl_setup_signals(unsigned int flags)
{
	// stub
	pw_log_warn("not implemented %d", flags);
	sigemptyset(&sigmask.signals);
	return &sigmask;
}

SPA_EXPORT
void jackctl_wait_signals(jackctl_sigmask_t * signals)
{
	// stub
	pw_log_warn("not implemented %p", signals);
}

SPA_EXPORT
jackctl_server_t * jackctl_server_create(
	bool (* on_device_acquire)(const char * device_name),
	void (* on_device_release)(const char * device_name))
{
	pw_log_error("deprecated");
	return jackctl_server_create2(on_device_acquire, on_device_release, NULL);
}

struct jackctl_server
{
	// stub
	JSList * empty;
	JSList * drivers;
};

struct jackctl_driver
{
	// stub
};

SPA_EXPORT
jackctl_server_t * jackctl_server_create2(
	bool (* on_device_acquire)(const char * device_name),
	void (* on_device_release)(const char * device_name),
	void (* on_device_reservation_loop)(void))
{
	// stub
	pw_log_warn("not implemented %p %p %p", on_device_acquire, on_device_release, on_device_reservation_loop);

	// setup server
	jackctl_server_t * server;
	server = (jackctl_server_t *)malloc(sizeof(jackctl_server_t));
	if (server == NULL) {
		return NULL;
	}
	server->empty = NULL;
	server->drivers = NULL;

	// setup dummy (default) driver
	jackctl_driver_t * dummy;
	dummy = (jackctl_driver_t *)malloc(sizeof(jackctl_driver_t));
	if (dummy == NULL) {
		free(server);
		return NULL;
	}
	server->drivers = jack_slist_append (server->drivers, dummy);

	return server;
}

SPA_EXPORT
void jackctl_server_destroy(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);

	if (server) {
		if (server->drivers) {
			free(server->drivers->data);
		}
		jack_slist_free(server->empty);
		jack_slist_free(server->drivers);
		free(server);
	}
}

SPA_EXPORT
bool jackctl_server_open(jackctl_server_t * server, jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, driver);
	return true;
}

SPA_EXPORT
bool jackctl_server_start(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	return true;
}

SPA_EXPORT
bool jackctl_server_stop(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	return false;
}

SPA_EXPORT
bool jackctl_server_close(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	return false;
}

SPA_EXPORT
const JSList * jackctl_server_get_drivers_list(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	if (server == NULL) {
		pw_log_warn("server == NULL");
		return NULL;
	}
	return server->drivers;
}

SPA_EXPORT
const JSList * jackctl_server_get_parameters(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	if (server == NULL) {
		return NULL;
	}
	return server->empty;
}

SPA_EXPORT
const JSList * jackctl_server_get_internals_list(jackctl_server_t * server)
{
	// stub
	pw_log_warn("%p: not implemented", server);
	if (server == NULL) {
		return NULL;
	}
	return server->empty;
}

SPA_EXPORT
bool jackctl_server_load_internal(jackctl_server_t * server, jackctl_internal_t * internal)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, internal);
	return true;
}

SPA_EXPORT
bool jackctl_server_unload_internal(jackctl_server_t * server, jackctl_internal_t * internal)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, internal);
	return true;
}

SPA_EXPORT
bool jackctl_server_load_session_file(jackctl_server_t * server_ptr, const char * file)
{
	// stub
	pw_log_warn("%p: not implemented %s", server_ptr, file);
	return false;
}

SPA_EXPORT
bool jackctl_server_add_slave(jackctl_server_t * server, jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, driver);
	return false;
}

SPA_EXPORT
bool jackctl_server_remove_slave(jackctl_server_t * server, jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, driver);
	return false;
}

SPA_EXPORT
bool jackctl_server_switch_master(jackctl_server_t * server, jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented %p", server, driver);
	return false;
}


SPA_EXPORT
const char * jackctl_driver_get_name(jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented", driver);
	return "dummy";
}

SPA_EXPORT
jackctl_driver_type_t jackctl_driver_get_type(jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented", driver);
	return (jackctl_driver_type_t)0;
}

SPA_EXPORT
const JSList * jackctl_driver_get_parameters(jackctl_driver_t * driver)
{
	// stub
	pw_log_warn("%p: not implemented", driver);
	return NULL;
}

SPA_EXPORT
int jackctl_driver_params_parse(jackctl_driver_t * driver, int argc, char* argv[])
{
	// stub
	pw_log_warn("%p: not implemented %d %p", driver, argc, argv);
	return 1;
}

SPA_EXPORT
const char * jackctl_internal_get_name(jackctl_internal_t * internal)
{
	// stub
	pw_log_warn("not implemented %p", internal);
	return "pipewire-jack-stub";
}

SPA_EXPORT
const JSList * jackctl_internal_get_parameters(jackctl_internal_t * internal)
{
	// stub
	pw_log_warn("not implemented %p", internal);
	return NULL;
}

SPA_EXPORT
const char * jackctl_parameter_get_name(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return "pipewire-jack-stub";
}

SPA_EXPORT
const char * jackctl_parameter_get_short_description(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return "pipewire-jack-stub";
}

SPA_EXPORT
const char * jackctl_parameter_get_long_description(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return "pipewire-jack-stub";
}

SPA_EXPORT
jackctl_param_type_t jackctl_parameter_get_type(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return (jackctl_param_type_t)0;
}

SPA_EXPORT
char jackctl_parameter_get_id(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return 0;
}

SPA_EXPORT
bool jackctl_parameter_is_set(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return false;
}

SPA_EXPORT
bool jackctl_parameter_reset(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return false;
}

SPA_EXPORT
union jackctl_parameter_value jackctl_parameter_get_value(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	union jackctl_parameter_value value;
	memset(&value, 0, sizeof(value));
	return value;
}

SPA_EXPORT
bool jackctl_parameter_set_value(
	jackctl_parameter_t * parameter,
	const union jackctl_parameter_value * value_ptr)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return false;
}

SPA_EXPORT
union jackctl_parameter_value jackctl_parameter_get_default_value(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	union jackctl_parameter_value value;
	memset(&value, 0, sizeof(value));
	return value;
}

SPA_EXPORT
bool jackctl_parameter_has_range_constraint(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return false;
}

SPA_EXPORT
bool jackctl_parameter_has_enum_constraint(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return false;
}

SPA_EXPORT
uint32_t jackctl_parameter_get_enum_constraints_count(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("%p: not implemented", parameter);
	return 0;
}

SPA_EXPORT
union jackctl_parameter_value jackctl_parameter_get_enum_constraint_value(
	jackctl_parameter_t * parameter,
	uint32_t index)
{
	// stub
	pw_log_warn("%p: not implemented %d", parameter, index);
	union jackctl_parameter_value value;
	memset(&value, 0, sizeof(value));
	return value;
}

SPA_EXPORT
const char * jackctl_parameter_get_enum_constraint_description(
	jackctl_parameter_t * parameter,
	uint32_t index)
{
	// stub
	pw_log_warn("%p: not implemented %d", parameter, index);
	return "pipewire-jack-stub";
}

SPA_EXPORT
void jackctl_parameter_get_range_constraint(
	jackctl_parameter_t * parameter,
	union jackctl_parameter_value * min_ptr,
	union jackctl_parameter_value * max_ptr)
{
	// stub
	pw_log_warn("%p: not implemented %p %p", parameter, min_ptr, max_ptr);
}

SPA_EXPORT
bool jackctl_parameter_constraint_is_strict(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("not implemented %p", parameter);
	return false;
}

SPA_EXPORT
bool jackctl_parameter_constraint_is_fake_value(jackctl_parameter_t * parameter)
{
	// stub
	pw_log_warn("not implemented %p", parameter);
	return false;
}

SPA_EXPORT SPA_PRINTF_FUNC(1, 2)
void jack_error(const char *format, ...)
{
	va_list args;
	va_start(args, format);
	pw_log_logv(SPA_LOG_LEVEL_ERROR, "", 0, "", format, args);
	va_end(args);
}

SPA_EXPORT SPA_PRINTF_FUNC(1, 2)
void jack_info(const char *format, ...)
{
	va_list args;
	va_start(args, format);
	pw_log_logv(SPA_LOG_LEVEL_INFO, "", 0, "", format, args);
	va_end(args);
}

SPA_EXPORT SPA_PRINTF_FUNC(1, 2)
void jack_log(const char *format, ...)
{
	va_list args;
	va_start(args, format);
	pw_log_logv(SPA_LOG_LEVEL_DEBUG, "", 0, "", format, args);
	va_end(args);
}
