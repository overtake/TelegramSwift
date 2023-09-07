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
#include <errno.h>
#include <unistd.h>
#include <time.h>
#include <stdio.h>
#include <regex.h>
#include <limits.h>
#include <sys/mman.h>

#include <pipewire/log.h>

#include <spa/support/cpu.h>
#include <spa/support/dbus.h>
#include <spa/node/utils.h>
#include <spa/utils/names.h>
#include <spa/debug/format.h>
#include <spa/debug/types.h>

#include <pipewire/impl.h>
#include <pipewire/private.h>
#include <pipewire/conf.h>

#include <extensions/protocol-native.h>

#define NAME "context"

#define CLOCK_MIN_QUANTUM			4u
#define CLOCK_MAX_QUANTUM			8192u

#define DEFAULT_CLOCK_RATE			48000u
#define DEFAULT_CLOCK_QUANTUM			1024u
#define DEFAULT_CLOCK_MIN_QUANTUM		32u
#define DEFAULT_CLOCK_MAX_QUANTUM		8192u
#define DEFAULT_CLOCK_POWER_OF_TWO_QUANTUM	true
#define DEFAULT_VIDEO_WIDTH			640
#define DEFAULT_VIDEO_HEIGHT			480
#define DEFAULT_VIDEO_RATE_NUM			25u
#define DEFAULT_VIDEO_RATE_DENOM		1u
#define DEFAULT_LINK_MAX_BUFFERS		64u
#define DEFAULT_MEM_WARN_MLOCK			false
#define DEFAULT_MEM_ALLOW_MLOCK			true

/** \cond */
struct impl {
	struct pw_context this;
	struct spa_handle *dbus_handle;
	unsigned int recalc:1;
	unsigned int recalc_pending:1;
};


struct factory_entry {
	regex_t regex;
	char *lib;
};

static void fill_properties(struct pw_context *context)
{
	struct pw_properties *properties = context->properties;

	if (!pw_properties_get(properties, PW_KEY_APP_NAME))
		pw_properties_set(properties, PW_KEY_APP_NAME, pw_get_client_name());

	if (!pw_properties_get(properties, PW_KEY_APP_PROCESS_BINARY))
		pw_properties_set(properties, PW_KEY_APP_PROCESS_BINARY, pw_get_prgname());

	if (!pw_properties_get(properties, PW_KEY_APP_LANGUAGE)) {
		pw_properties_set(properties, PW_KEY_APP_LANGUAGE, getenv("LANG"));
	}
	if (!pw_properties_get(properties, PW_KEY_APP_PROCESS_ID)) {
		pw_properties_setf(properties, PW_KEY_APP_PROCESS_ID, "%zd", (size_t) getpid());
	}
	if (!pw_properties_get(properties, PW_KEY_APP_PROCESS_USER))
		pw_properties_set(properties, PW_KEY_APP_PROCESS_USER, pw_get_user_name());

	if (!pw_properties_get(properties, PW_KEY_APP_PROCESS_HOST))
		pw_properties_set(properties, PW_KEY_APP_PROCESS_HOST, pw_get_host_name());

	if (!pw_properties_get(properties, PW_KEY_APP_PROCESS_SESSION_ID)) {
		pw_properties_set(properties, PW_KEY_APP_PROCESS_SESSION_ID,
				  getenv("XDG_SESSION_ID"));
	}
	if (!pw_properties_get(properties, PW_KEY_WINDOW_X11_DISPLAY)) {
		pw_properties_set(properties, PW_KEY_WINDOW_X11_DISPLAY,
				  getenv("DISPLAY"));
	}
	pw_properties_set(properties, PW_KEY_CORE_VERSION, context->core->info.version);
	pw_properties_set(properties, PW_KEY_CORE_NAME, context->core->info.name);
}

static uint32_t get_default_int(struct pw_properties *properties, const char *name, uint32_t def)
{
	uint32_t val;
	const char *str;
	if ((str = pw_properties_get(properties, name)) != NULL)
		val = atoi(str);
	else {
		val = def;
		pw_properties_setf(properties, name, "%d", val);
	}
	return val;
}

static bool get_default_bool(struct pw_properties *properties, const char *name, bool def)
{
	bool val;
	const char *str;
	if ((str = pw_properties_get(properties, name)) != NULL)
		val = pw_properties_parse_bool(str);
	else {
		val = def;
		pw_properties_set(properties, name, val ? "true" : "false");
	}
	return val;
}

static void fill_defaults(struct pw_context *this)
{
	struct pw_properties *p = this->properties;
	this->defaults.clock_power_of_two_quantum = get_default_bool(p, "clock.power-of-two-quantum",
			DEFAULT_CLOCK_POWER_OF_TWO_QUANTUM);
	this->defaults.clock_rate = get_default_int(p, "default.clock.rate", DEFAULT_CLOCK_RATE);
	this->defaults.clock_quantum = get_default_int(p, "default.clock.quantum", DEFAULT_CLOCK_QUANTUM);
	this->defaults.clock_min_quantum = get_default_int(p, "default.clock.min-quantum", DEFAULT_CLOCK_MIN_QUANTUM);
	this->defaults.clock_max_quantum = get_default_int(p, "default.clock.max-quantum", DEFAULT_CLOCK_MAX_QUANTUM);
	this->defaults.video_size.width = get_default_int(p, "default.video.width", DEFAULT_VIDEO_WIDTH);
	this->defaults.video_size.height = get_default_int(p, "default.video.height", DEFAULT_VIDEO_HEIGHT);
	this->defaults.video_rate.num = get_default_int(p, "default.video.rate.num", DEFAULT_VIDEO_RATE_NUM);
	this->defaults.video_rate.denom = get_default_int(p, "default.video.rate.denom", DEFAULT_VIDEO_RATE_DENOM);
	this->defaults.link_max_buffers = get_default_int(p, "link.max-buffers", DEFAULT_LINK_MAX_BUFFERS);
	this->defaults.mem_warn_mlock = get_default_bool(p, "mem.warn-mlock", DEFAULT_MEM_WARN_MLOCK);
	this->defaults.mem_allow_mlock = get_default_bool(p, "mem.allow-mlock", DEFAULT_MEM_ALLOW_MLOCK);

	this->defaults.clock_max_quantum = SPA_CLAMP(this->defaults.clock_max_quantum,
			CLOCK_MIN_QUANTUM, CLOCK_MAX_QUANTUM);
	this->defaults.clock_min_quantum = SPA_CLAMP(this->defaults.clock_min_quantum,
			CLOCK_MIN_QUANTUM, this->defaults.clock_max_quantum);
	this->defaults.clock_quantum = SPA_CLAMP(this->defaults.clock_quantum,
			this->defaults.clock_min_quantum, this->defaults.clock_max_quantum);
}

static int try_load_conf(struct pw_context *this, const char *conf_prefix,
		const char *conf_name, struct pw_properties *conf)
{
	int res;

	if (conf_name == NULL)
		return -EINVAL;
	if (strcmp(conf_name, "null") == 0)
		return 0;
	if ((res = pw_conf_load_conf(conf_prefix, conf_name, conf)) < 0) {
		pw_log_warn(NAME" %p: can't load config %s%s%s: %s",
				this,
				conf_prefix ? conf_prefix : "",
				conf_prefix ? "/" : "",
				conf_name, spa_strerror(res));
	}
	return res;
}

/** Create a new context object
 *
 * \param main_loop the main loop to use
 * \param properties extra properties for the context, ownership it taken
 * \return a newly allocated context object
 *
 * \memberof pw_context
 */
SPA_EXPORT
struct pw_context *pw_context_new(struct pw_loop *main_loop,
			    struct pw_properties *properties,
			    size_t user_data_size)
{
	struct impl *impl;
	struct pw_context *this;
	const char *lib, *str, *conf_prefix, *conf_name;
	void *dbus_iface = NULL;
	uint32_t n_support;
	struct pw_properties *pr, *conf = NULL;
	struct spa_cpu *cpu;
	int res = 0;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL) {
		res = -errno;
		goto error_cleanup;
	}

	this = &impl->this;

	pw_log_debug(NAME" %p: new", this);

	if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL) {
		res = -errno;
		goto error_free;
	}

	conf = pw_properties_new(NULL, NULL);
	if (conf == NULL) {
		res = -errno;
		goto error_free;
	}

	conf_prefix = getenv("PIPEWIRE_CONFIG_PREFIX");
	if (conf_prefix == NULL)
		conf_prefix = pw_properties_get(properties, PW_KEY_CONFIG_PREFIX);

	conf_name = getenv("PIPEWIRE_CONFIG_NAME");
	if (try_load_conf(this, conf_prefix, conf_name, conf) < 0) {
		conf_name = pw_properties_get(properties, PW_KEY_CONFIG_NAME);
		if (try_load_conf(this, conf_prefix, conf_name, conf) < 0) {
			conf_name = "client.conf";
			if (try_load_conf(this, conf_prefix, conf_name, conf) < 0) {
				pw_log_error(NAME" %p: can't load config %s: %s",
					this, conf_name, spa_strerror(res));
				goto error_free;
			}
		}
	}
	this->conf = conf;

	n_support = pw_get_support(this->support, SPA_N_ELEMENTS(this->support) - 6);
	cpu = spa_support_find(this->support, n_support, SPA_TYPE_INTERFACE_CPU);

	if ((str = pw_properties_get(conf, "context.properties")) != NULL) {
		pw_properties_update_string(properties, str, strlen(str));
		pw_log_info(NAME" %p: parsed context.properties section", this);
	}

	if ((str = pw_properties_get(properties, "vm.overrides")) != NULL) {
		if (cpu != NULL && spa_cpu_get_vm_type(cpu) != SPA_CPU_VM_NONE)
			pw_properties_update_string(properties, str, strlen(str));
		pw_properties_set(properties, "vm.overrides", NULL);
	}
	if (pw_properties_get(properties, PW_KEY_CPU_MAX_ALIGN) == NULL && cpu != NULL)
		pw_properties_setf(properties, PW_KEY_CPU_MAX_ALIGN,
				"%u", spa_cpu_get_max_align(cpu));

	if (getenv("PIPEWIRE_DEBUG") == NULL &&
	    (str = pw_properties_get(properties, "log.level")) != NULL)
		pw_log_set_level(atoi(str));

	if ((str = pw_properties_get(properties, "mem.mlock-all")) != NULL &&
	    pw_properties_parse_bool(str)) {
		if (mlockall(MCL_CURRENT | MCL_FUTURE) < 0)
			pw_log_warn(NAME" %p: could not mlockall; %m", impl);
		else
			pw_log_info(NAME" %p: mlockall succeeded", impl);
	}
	this->properties = properties;

	fill_defaults(this);

	pr = pw_properties_copy(properties);
	if ((str = pw_properties_get(pr, "context.data-loop." PW_KEY_LIBRARY_NAME_SYSTEM)))
		pw_properties_set(pr, PW_KEY_LIBRARY_NAME_SYSTEM, str);

	this->data_loop_impl = pw_data_loop_new(&pr->dict);
	pw_properties_free(pr);
	if (this->data_loop_impl == NULL)  {
		res = -errno;
		goto error_free;
	}

	this->pool = pw_mempool_new(NULL);
	if (this->pool == NULL) {
		res = -errno;
		goto error_free_loop;
	}

	this->data_loop = pw_data_loop_get_loop(this->data_loop_impl);
	this->data_system = this->data_loop->system;
	this->main_loop = main_loop;

	this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_System, this->main_loop->system);
	this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Loop, this->main_loop->loop);
	this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_LoopUtils, this->main_loop->utils);
	this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataSystem, this->data_system);
	this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataLoop, this->data_loop->loop);

	if ((str = pw_properties_get(properties, "support.dbus")) == NULL ||
	    pw_properties_parse_bool(str)) {
		lib = pw_properties_get(properties, PW_KEY_LIBRARY_NAME_DBUS);
		if (lib == NULL)
			lib = "support/libspa-dbus";

		impl->dbus_handle = pw_load_spa_handle(lib,
				SPA_NAME_SUPPORT_DBUS, NULL,
				n_support, this->support);

		if (impl->dbus_handle == NULL ||
		    (res = spa_handle_get_interface(impl->dbus_handle,
							SPA_TYPE_INTERFACE_DBus, &dbus_iface)) < 0) {
				pw_log_warn(NAME" %p: can't load dbus interface: %s", this, spa_strerror(res));
		} else {
			this->support[n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DBus, dbus_iface);
		}
	}
	this->n_support = n_support;

	pw_array_init(&this->factory_lib, 32);
	pw_array_init(&this->objects, 32);
	pw_map_init(&this->globals, 128, 32);

	spa_list_init(&this->core_impl_list);
	spa_list_init(&this->protocol_list);
	spa_list_init(&this->core_list);
	spa_list_init(&this->registry_resource_list);
	spa_list_init(&this->global_list);
	spa_list_init(&this->module_list);
	spa_list_init(&this->device_list);
	spa_list_init(&this->client_list);
	spa_list_init(&this->node_list);
	spa_list_init(&this->factory_list);
	spa_list_init(&this->link_list);
	spa_list_init(&this->control_list[0]);
	spa_list_init(&this->control_list[1]);
	spa_list_init(&this->export_list);
	spa_list_init(&this->driver_list);
	spa_hook_list_init(&this->listener_list);
	spa_hook_list_init(&this->driver_listener_list);

	this->core = pw_context_create_core(this, pw_properties_copy(properties), 0);
	if (this->core == NULL) {
		res = -errno;
		goto error_free_loop;
	}
	pw_impl_core_register(this->core, NULL);

	fill_properties(this);

	if ((res = pw_data_loop_start(this->data_loop_impl)) < 0)
		goto error_free_loop;

	this->sc_pagesize = sysconf(_SC_PAGESIZE);

	if ((res = pw_context_parse_conf_section(this, conf, "context.spa-libs")) >= 0)
		pw_log_info(NAME" %p: parsed context.spa-libs section", this);
	if ((res = pw_context_parse_conf_section(this, conf, "context.modules")) >= 0)
		pw_log_info(NAME" %p: parsed context.modules section", this);
	if ((res = pw_context_parse_conf_section(this, conf, "context.objects")) >= 0)
		pw_log_info(NAME" %p: parsed context.objects section", this);
	if ((res = pw_context_parse_conf_section(this, conf, "context.exec")) >= 0)
		pw_log_info(NAME" %p: parsed context.exec section", this);

	pw_log_debug(NAME" %p: created", this);

	return this;

error_free_loop:
	pw_data_loop_destroy(this->data_loop_impl);
error_free:
	free(this);
error_cleanup:
	if (conf)
		pw_properties_free(conf);
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

/** Destroy a context object
 *
 * \param context a context to destroy
 *
 * \memberof pw_context
 */
SPA_EXPORT
void pw_context_destroy(struct pw_context *context)
{
	struct impl *impl = SPA_CONTAINER_OF(context, struct impl, this);
	struct pw_global *global;
	struct pw_impl_client *client;
	struct pw_impl_module *module;
	struct pw_impl_device *device;
	struct pw_core *core;
	struct pw_resource *resource;
	struct pw_impl_node *node;
	struct factory_entry *entry;
	struct pw_impl_core *core_impl;

	pw_log_debug(NAME" %p: destroy", context);
	pw_context_emit_destroy(context);

	spa_list_consume(core, &context->core_list, link)
		pw_core_disconnect(core);

	spa_list_consume(client, &context->client_list, link)
		pw_impl_client_destroy(client);

	spa_list_consume(node, &context->node_list, link)
		pw_impl_node_destroy(node);

	spa_list_consume(device, &context->device_list, link)
		pw_impl_device_destroy(device);

	spa_list_consume(resource, &context->registry_resource_list, link)
		pw_resource_destroy(resource);

	spa_list_consume(module, &context->module_list, link)
		pw_impl_module_destroy(module);

	spa_list_consume(global, &context->global_list, link)
		pw_global_destroy(global);

	spa_list_consume(core_impl, &context->core_impl_list, link)
		pw_impl_core_destroy(core_impl);

	pw_log_debug(NAME" %p: free", context);
	pw_context_emit_free(context);

	pw_mempool_destroy(context->pool);

	pw_data_loop_destroy(context->data_loop_impl);

	if (context->work_queue)
		pw_work_queue_destroy(context->work_queue);

	pw_properties_free(context->properties);
	pw_properties_free(context->conf);

	if (impl->dbus_handle)
		pw_unload_spa_handle(impl->dbus_handle);

	pw_array_for_each(entry, &context->factory_lib) {
		regfree(&entry->regex);
		free(entry->lib);
	}
	pw_array_clear(&context->factory_lib);

	pw_array_clear(&context->objects);

	pw_map_clear(&context->globals);

	spa_hook_list_clean(&context->listener_list);
	spa_hook_list_clean(&context->driver_listener_list);

	free(context);
}

SPA_EXPORT
void *pw_context_get_user_data(struct pw_context *context)
{
	return context->user_data;
}

SPA_EXPORT
void pw_context_add_listener(struct pw_context *context,
			  struct spa_hook *listener,
			  const struct pw_context_events *events,
			  void *data)
{
	spa_hook_list_append(&context->listener_list, listener, events, data);
}

SPA_EXPORT
const struct spa_support *pw_context_get_support(struct pw_context *context, uint32_t *n_support)
{
	*n_support = context->n_support;
	return context->support;
}

SPA_EXPORT
struct pw_loop *pw_context_get_main_loop(struct pw_context *context)
{
	return context->main_loop;
}

SPA_EXPORT
struct pw_work_queue *pw_context_get_work_queue(struct pw_context *context)
{
	if (context->work_queue == NULL)
		context->work_queue = pw_work_queue_new(context->main_loop);
	return context->work_queue;
}

SPA_EXPORT
const struct pw_properties *pw_context_get_properties(struct pw_context *context)
{
	return context->properties;
}

SPA_EXPORT
const char *pw_context_get_conf_section(struct pw_context *context, const char *section)
{
	return pw_properties_get(context->conf, section);
}

/** Update context properties
 *
 * \param context a context
 * \param dict properties to update
 *
 * Update the context object with the given properties
 *
 * \memberof pw_context
 */
SPA_EXPORT
int pw_context_update_properties(struct pw_context *context, const struct spa_dict *dict)
{
	int changed;

	changed = pw_properties_update(context->properties, dict);
	pw_log_debug(NAME" %p: updated %d properties", context, changed);

	return changed;
}

static bool global_can_read(struct pw_context *context, struct pw_global *global)
{
	if (context->current_client &&
	    !PW_PERM_IS_R(pw_global_get_permissions(global, context->current_client)))
		return false;
	return true;
}

SPA_EXPORT
int pw_context_for_each_global(struct pw_context *context,
			    int (*callback) (void *data, struct pw_global *global),
			    void *data)
{
	struct pw_global *g, *t;
	int res;

	spa_list_for_each_safe(g, t, &context->global_list, link) {
		if (!global_can_read(context, g))
			continue;
		if ((res = callback(data, g)) != 0)
			return res;
	}
	return 0;
}

SPA_EXPORT
struct pw_global *pw_context_find_global(struct pw_context *context, uint32_t id)
{
	struct pw_global *global;

	global = pw_map_lookup(&context->globals, id);
	if (global == NULL || !global->registered) {
		errno = ENOENT;
		return NULL;
	}

	if (!global_can_read(context, global)) {
		errno = EACCES;
		return NULL;
	}
	return global;
}

/** Find a port to link with
 *
 * \param context a context
 * \param other_port a port to find a link with
 * \param id the id of a port or PW_ID_ANY
 * \param props extra properties
 * \param n_format_filters number of filters
 * \param format_filters array of format filters
 * \param[out] error an error when something is wrong
 * \return a port that can be used to link to \a otherport or NULL on error
 *
 * \memberof pw_context
 */
struct pw_impl_port *pw_context_find_port(struct pw_context *context,
				  struct pw_impl_port *other_port,
				  uint32_t id,
				  struct pw_properties *props,
				  uint32_t n_format_filters,
				  struct spa_pod **format_filters,
				  char **error)
{
	struct pw_impl_port *best = NULL;
	bool have_id;
	struct pw_impl_node *n;

	have_id = id != PW_ID_ANY;

	pw_log_debug(NAME" %p: id:%u", context, id);

	spa_list_for_each(n, &context->node_list, link) {
		if (n->global == NULL)
			continue;

		if (other_port->node == n)
			continue;

		if (!global_can_read(context, n->global))
			continue;

		pw_log_debug(NAME" %p: node id:%d", context, n->global->id);

		if (have_id) {
			if (n->global->id == id) {
				pw_log_debug(NAME" %p: id:%u matches node %p", context, id, n);

				best =
				    pw_impl_node_find_port(n,
						pw_direction_reverse(other_port->direction),
						PW_ID_ANY);
				if (best)
					break;
			}
		} else {
			struct pw_impl_port *p, *pin, *pout;
			uint8_t buf[4096];
			struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
			struct spa_pod *dummy;

			p = pw_impl_node_find_port(n,
					pw_direction_reverse(other_port->direction),
					PW_ID_ANY);
			if (p == NULL)
				continue;

			if (p->direction == PW_DIRECTION_OUTPUT) {
				pin = other_port;
				pout = p;
			} else {
				pin = p;
				pout = other_port;
			}

			if (pw_context_find_format(context,
						pout,
						pin,
						props,
						n_format_filters,
						format_filters,
						&dummy,
						&b,
						error) < 0) {
				free(*error);
				continue;
			}
			best = p;
			break;
		}
	}
	if (best == NULL) {
		*error = spa_aprintf("No matching Node found");
	}
	return best;
}

SPA_PRINTF_FUNC(7, 8) int pw_context_debug_port_params(struct pw_context *this,
		struct spa_node *node, enum spa_direction direction,
		uint32_t port_id, uint32_t id, int err, const char *debug, ...)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[4096];
	uint32_t state;
	struct spa_pod *param;
	int res;
	va_list args;

	va_start(args, debug);
	vsnprintf((char*)buffer, sizeof(buffer), debug, args);
	va_end(args);

	pw_log_error("params %s: %d:%d %s (%s)",
			spa_debug_type_find_name(spa_type_param, id),
			direction, port_id, spa_strerror(err), buffer);

	if (err == -EBUSY)
		return 0;

        state = 0;
        while (true) {
                spa_pod_builder_init(&b, buffer, sizeof(buffer));
                res = spa_node_port_enum_params_sync(node,
                                       direction, port_id,
                                       id, &state,
                                       NULL, &param, &b);
                if (res != 1) {
			if (res < 0)
				pw_log_error("  error: %s", spa_strerror(res));
                        break;
		}
                pw_log_pod(SPA_LOG_LEVEL_ERROR, param);
        }
        return 0;
}

/** Find a common format between two ports
 *
 * \param context a context object
 * \param output an output port
 * \param input an input port
 * \param props extra properties
 * \param n_format_filters number of format filters
 * \param format_filters array of format filters
 * \param[out] error an error when something is wrong
 * \return a common format of NULL on error
 *
 * Find a common format between the given ports. The format will
 * be restricted to a subset given with the format filters.
 *
 * \memberof pw_context
 */
int pw_context_find_format(struct pw_context *context,
			struct pw_impl_port *output,
			struct pw_impl_port *input,
			struct pw_properties *props,
			uint32_t n_format_filters,
			struct spa_pod **format_filters,
			struct spa_pod **format,
			struct spa_pod_builder *builder,
			char **error)
{
	uint32_t out_state, in_state;
	int res;
	uint32_t iidx = 0, oidx = 0;
	struct spa_pod_builder fb = { 0 };
	uint8_t fbuf[4096];
	struct spa_pod *filter;

	out_state = output->state;
	in_state = input->state;

	pw_log_debug(NAME" %p: finding best format %d %d", context, out_state, in_state);

	/* when a port is configured but the node is idle, we can reconfigure with a different format */
	if (out_state > PW_IMPL_PORT_STATE_CONFIGURE && output->node->info.state == PW_NODE_STATE_IDLE)
		out_state = PW_IMPL_PORT_STATE_CONFIGURE;
	if (in_state > PW_IMPL_PORT_STATE_CONFIGURE && input->node->info.state == PW_NODE_STATE_IDLE)
		in_state = PW_IMPL_PORT_STATE_CONFIGURE;

	pw_log_debug(NAME" %p: states %d %d", context, out_state, in_state);

	if (in_state == PW_IMPL_PORT_STATE_CONFIGURE && out_state > PW_IMPL_PORT_STATE_CONFIGURE) {
		/* only input needs format */
		spa_pod_builder_init(&fb, fbuf, sizeof(fbuf));
		if ((res = spa_node_port_enum_params_sync(output->node->node,
						     output->direction, output->port_id,
						     SPA_PARAM_Format, &oidx,
						     NULL, &filter, &fb)) != 1) {
			if (res < 0)
				*error = spa_aprintf("error get output format: %s", spa_strerror(res));
			else
				*error = spa_aprintf("no output formats");
			goto error;
		}
		pw_log_debug(NAME" %p: Got output format:", context);
		pw_log_format(SPA_LOG_LEVEL_DEBUG, filter);

		if ((res = spa_node_port_enum_params_sync(input->node->node,
						     input->direction, input->port_id,
						     SPA_PARAM_EnumFormat, &iidx,
						     filter, format, builder)) <= 0) {
			if (res == -ENOENT || res == 0) {
				pw_log_debug(NAME" %p: no input format filter, using output format: %s",
						context, spa_strerror(res));
				*format = filter;
			} else {
				*error = spa_aprintf("error input enum formats: %s", spa_strerror(res));
				goto error;
			}
		}
	} else if (out_state >= PW_IMPL_PORT_STATE_CONFIGURE && in_state > PW_IMPL_PORT_STATE_CONFIGURE) {
		/* only output needs format */
		spa_pod_builder_init(&fb, fbuf, sizeof(fbuf));
		if ((res = spa_node_port_enum_params_sync(input->node->node,
						     input->direction, input->port_id,
						     SPA_PARAM_Format, &iidx,
						     NULL, &filter, &fb)) != 1) {
			if (res < 0)
				*error = spa_aprintf("error get input format: %s", spa_strerror(res));
			else
				*error = spa_aprintf("no input format");
			goto error;
		}
		pw_log_debug(NAME" %p: Got input format:", context);
		pw_log_format(SPA_LOG_LEVEL_DEBUG, filter);

		if ((res = spa_node_port_enum_params_sync(output->node->node,
						     output->direction, output->port_id,
						     SPA_PARAM_EnumFormat, &oidx,
						     filter, format, builder)) <= 0) {
			if (res == -ENOENT || res == 0) {
				pw_log_debug(NAME" %p: no output format filter, using input format: %s",
						context, spa_strerror(res));
				*format = filter;
			} else {
				*error = spa_aprintf("error output enum formats: %s", spa_strerror(res));
				goto error;
			}
		}
	} else if (in_state == PW_IMPL_PORT_STATE_CONFIGURE && out_state == PW_IMPL_PORT_STATE_CONFIGURE) {
	      again:
		/* both ports need a format */
		pw_log_debug(NAME" %p: do enum input %d", context, iidx);
		spa_pod_builder_init(&fb, fbuf, sizeof(fbuf));
		if ((res = spa_node_port_enum_params_sync(input->node->node,
						     input->direction, input->port_id,
						     SPA_PARAM_EnumFormat, &iidx,
						     NULL, &filter, &fb)) != 1) {
			if (res == -ENOENT) {
				pw_log_debug(NAME" %p: no input filter", context);
				filter = NULL;
			} else {
				if (res < 0)
					*error = spa_aprintf("error input enum formats: %s", spa_strerror(res));
				else
					*error = spa_aprintf("no more input formats");
				goto error;
			}
		}
		pw_log_debug(NAME" %p: enum output %d with filter: %p", context, oidx, filter);
		pw_log_format(SPA_LOG_LEVEL_DEBUG, filter);

		if ((res = spa_node_port_enum_params_sync(output->node->node,
						     output->direction, output->port_id,
						     SPA_PARAM_EnumFormat, &oidx,
						     filter, format, builder)) != 1) {
			if (res == 0 && filter != NULL) {
				oidx = 0;
				goto again;
			}
			*error = spa_aprintf("error output enum formats: %s", spa_strerror(res));
			goto error;
		}

		pw_log_debug(NAME" %p: Got filtered:", context);
		pw_log_format(SPA_LOG_LEVEL_DEBUG, *format);
	} else {
		res = -EBADF;
		*error = spa_aprintf("error bad node state");
		goto error;
	}
	return res;
error:
	if (res == 0)
		res = -EINVAL;
	return res;
}

static int ensure_state(struct pw_impl_node *node, bool running)
{
	enum pw_node_state state = node->info.state;
	if (node->active && !SPA_FLAG_IS_SET(node->spa_flags, SPA_NODE_FLAG_NEED_CONFIGURE) && running)
		state = PW_NODE_STATE_RUNNING;
	else if (state > PW_NODE_STATE_IDLE)
		state = PW_NODE_STATE_IDLE;
	return pw_impl_node_set_state(node, state);
}

static int collect_nodes(struct pw_context *context, struct pw_impl_node *driver)
{
	struct spa_list queue;
	struct pw_impl_node *n, *t;
	struct pw_impl_port *p;
	struct pw_impl_link *l;

	spa_list_consume(t, &driver->follower_list, follower_link) {
		spa_list_remove(&t->follower_link);
		spa_list_init(&t->follower_link);
	}

	pw_log_debug("driver %p: '%s'", driver, driver->name);

	/* start with driver in the queue */
	spa_list_init(&queue);
	spa_list_append(&queue, &driver->sort_link);
	driver->visited = true;

	/* now follow all the links from the nodes in the queue
	 * and add the peers to the queue. */
	spa_list_consume(n, &queue, sort_link) {
		spa_list_remove(&n->sort_link);
		pw_impl_node_set_driver(n, driver);
		n->passive = true;

		spa_list_for_each(p, &n->input_ports, link) {
			spa_list_for_each(l, &p->links, input_link) {
				t = l->output->node;

				if (l->passive)
					pw_impl_link_prepare(l);
				else if (t->active)
					driver->passive = n->passive = false;

				if (t->visited || !t->active)
					continue;
				if (l->prepared) {
					t->visited = true;
					spa_list_append(&queue, &t->sort_link);
				}
			}
		}
		spa_list_for_each(p, &n->output_ports, link) {
			spa_list_for_each(l, &p->links, output_link) {
				t = l->input->node;

				if (l->passive)
					pw_impl_link_prepare(l);
				else if (t->active)
					driver->passive = n->passive = false;

				if (t->visited || !t->active)
					continue;
				if (l->prepared) {
					t->visited = true;
					spa_list_append(&queue, &t->sort_link);
				}
			}
		}
		/* now go through all the followers of this driver and add the
		 * nodes that have the same group and that are not yet visited */
		if (n->group_id == SPA_ID_INVALID)
			continue;

		spa_list_for_each(t, &context->node_list, link) {
			if (t->exported || t == n || !t->active || t->visited)
				continue;
			if (t->group_id != n->group_id)
				continue;
			t->visited = true;
			spa_list_append(&queue, &t->sort_link);
		}
	}
	return 0;
}

int pw_context_recalc_graph(struct pw_context *context, const char *reason)
{
	struct impl *impl = SPA_CONTAINER_OF(context, struct impl, this);
	struct pw_impl_node *n, *s, *target, *fallback;

	pw_log_info(NAME" %p: busy:%d reason:%s", context, impl->recalc, reason);

	if (impl->recalc) {
		impl->recalc_pending = true;
		return -EBUSY;
	}

again:
	impl->recalc = true;

	/* start from all drivers and group all nodes that are linked
	 * to it. Some nodes are not (yet) linked to anything and they
	 * will end up 'unassigned' to a driver. Other nodes are drivers
	 * and if they have active followers, we can use them to schedule
	 * the unassigned nodes. */
	target = fallback = NULL;
	spa_list_for_each(n, &context->driver_list, driver_link) {
		if (n->exported)
			continue;

		if (!n->visited)
			collect_nodes(context, n);

		/* from now on we are only interested in active driving nodes.
		 * We're going to see if there are active followers. */
		if (!n->driving || !n->active)
			continue;

		/* first active driving node is fallback */
		if (fallback == NULL)
			fallback = n;

		if (n->passive)
			continue;

		spa_list_for_each(s, &n->follower_list, follower_link) {
			pw_log_debug(NAME" %p: driver %p: follower %p %s: active:%d",
					context, n, s, s->name, s->active);
			if (s != n && s->active) {
				/* if the driving node has active followers, it
				 * is a target for our unassigned nodes */
				if (target == NULL)
					target = n;
				break;
			}
		}
	}
	/* no active node, use fallback driving node */
	if (target == NULL)
		target = fallback;

	/* now go through all available nodes. The ones we didn't visit
	 * in collect_nodes() are not linked to any driver. We assign them
	 * to either an active driver of the first driver */
	spa_list_for_each(n, &context->node_list, link) {
		if (n->exported)
			continue;

		if (!n->visited) {
			struct pw_impl_node *t;

			pw_log_debug(NAME" %p: unassigned node %p: '%s' active:%d want_driver:%d target:%p",
					context, n, n->name, n->active, n->want_driver, target);

			t = (n->active && n->want_driver) ? target : NULL;

			pw_impl_node_set_driver(n, t);
			if (t == NULL)
				ensure_state(n, false);
			else
				t->passive = false;
		}
		n->visited = false;
	}

	/* assign final quantum and set state for followers and drivers */
	spa_list_for_each(n, &context->driver_list, driver_link) {
		bool running = false;
		uint32_t max_quantum = context->defaults.clock_max_quantum;
		uint32_t quantum = 0;

		if (!n->driving || n->exported)
			continue;

		/* collect quantum and count active nodes */
		spa_list_for_each(s, &n->follower_list, follower_link) {

			if (s->quantum_size > 0) {
				if (quantum == 0 || s->quantum_size < quantum)
					quantum = s->quantum_size;
			}
			if (s->max_quantum_size > 0) {
				if (s->max_quantum_size < max_quantum)
					max_quantum = s->max_quantum_size;
			}
			if (s->active)
				running = !n->passive;
		}
		if (quantum == 0)
			quantum = context->defaults.clock_quantum;

		quantum = SPA_CLAMP(quantum,
				context->defaults.clock_min_quantum,
				max_quantum);

		if (n->rt.position && quantum != n->rt.position->clock.duration) {
			pw_log_info("(%s-%u) new quantum:%"PRIu64"->%u",
					n->name, n->info.id,
					n->rt.position->clock.duration,
					quantum);
			n->rt.position->clock.duration = quantum;
		}

		pw_log_debug(NAME" %p: driving %p running:%d passive:%d quantum:%u '%s'",
				context, n, running, n->passive, quantum, n->name);

		spa_list_for_each(s, &n->follower_list, follower_link) {
			if (s == n)
				continue;
			pw_log_debug(NAME" %p: follower %p: active:%d '%s'",
					context, s, s->active, s->name);
			ensure_state(s, running);
		}
		ensure_state(n, running);
	}
	impl->recalc = false;
	if (impl->recalc_pending) {
		impl->recalc_pending = false;
		goto again;
	}

	return 0;
}

SPA_EXPORT
int pw_context_add_spa_lib(struct pw_context *context,
		const char *factory_regexp, const char *lib)
{
	struct factory_entry *entry;
	int err;

	entry = pw_array_add(&context->factory_lib, sizeof(*entry));
	if (entry == NULL)
		return -errno;

	if ((err = regcomp(&entry->regex, factory_regexp, REG_EXTENDED | REG_NOSUB)) != 0) {
		char errbuf[1024];
		regerror(err, &entry->regex, errbuf, sizeof(errbuf));
		pw_log_error(NAME" %p: can compile regex: %s", context, errbuf);
		pw_array_remove(&context->factory_lib, entry);
		return -EINVAL;
	}

	entry->lib = strdup(lib);
	pw_log_debug(NAME" %p: map factory regex '%s' to '%s", context,
			factory_regexp, lib);
	return 0;
}

SPA_EXPORT
const char *pw_context_find_spa_lib(struct pw_context *context, const char *factory_name)
{
	struct factory_entry *entry;

	pw_array_for_each(entry, &context->factory_lib) {
		if (regexec(&entry->regex, factory_name, 0, NULL, 0) == 0)
			return entry->lib;
	}
	return NULL;
}

SPA_EXPORT
struct spa_handle *pw_context_load_spa_handle(struct pw_context *context,
		const char *factory_name,
		const struct spa_dict *info)
{
	const char *lib;
	const struct spa_support *support;
	uint32_t n_support;
	struct spa_handle *handle;

	pw_log_debug(NAME" %p: load factory %s", context, factory_name);

	lib = pw_context_find_spa_lib(context, factory_name);
	if (lib == NULL && info != NULL)
		lib = spa_dict_lookup(info, SPA_KEY_LIBRARY_NAME);
	if (lib == NULL) {
		errno = ENOENT;
		pw_log_warn(NAME" %p: no library for %s: %m",
				context, factory_name);
		return NULL;
	}

	support = pw_context_get_support(context, &n_support);

	handle = pw_load_spa_handle(lib, factory_name,
			info, n_support, support);

	return handle;
}

SPA_EXPORT
int pw_context_register_export_type(struct pw_context *context, struct pw_export_type *type)
{
	if (pw_context_find_export_type(context, type->type)) {
		pw_log_warn("context %p: duplicate export type %s", context, type->type);
		return -EEXIST;
	}
	pw_log_debug("context %p: Add export type %s to context", context, type->type);
	spa_list_append(&context->export_list, &type->link);
	return 0;
}

SPA_EXPORT
const struct pw_export_type *pw_context_find_export_type(struct pw_context *context, const char *type)
{
	const struct pw_export_type *t;
	spa_list_for_each(t, &context->export_list, link) {
		if (strcmp(t->type, type) == 0)
			return t;
	}
	return NULL;
}

struct object_entry {
	const char *type;
	void *value;
};

static struct object_entry *find_object(struct pw_context *context, const char *type)
{
	struct object_entry *entry;
	pw_array_for_each(entry, &context->objects) {
		if (strcmp(entry->type, type) == 0)
			return entry;
	}
	return NULL;
}

SPA_EXPORT
int pw_context_set_object(struct pw_context *context, const char *type, void *value)
{
	struct object_entry *entry;

	entry = find_object(context, type);

	if (value == NULL) {
		if (entry)
			pw_array_remove(&context->objects, entry);
	} else {
		if (entry == NULL) {
			entry = pw_array_add(&context->objects, sizeof(*entry));
			if (entry == NULL)
				return -errno;
			entry->type = type;
		}
		entry->value = value;
	}
	return 0;
}

SPA_EXPORT
void *pw_context_get_object(struct pw_context *context, const char *type)
{
	struct object_entry *entry;

	if ((entry = find_object(context, type)) != NULL)
		return entry->value;

	return NULL;
}
