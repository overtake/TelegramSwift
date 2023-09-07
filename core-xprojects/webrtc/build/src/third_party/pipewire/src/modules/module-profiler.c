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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "config.h"

#include <spa/utils/result.h>
#include <spa/utils/ringbuffer.h>
#include <spa/param/profiler.h>
#include <spa/debug/pod.h>

#include <pipewire/private.h>
#include <pipewire/impl.h>
#include <extensions/profiler.h>

#define NAME "profiler"

#define MAX_BUFFER		(8 * 1024 * 1024)
#define MIN_FLUSH		(16 * 1024)
#define DEFAULT_IDLE		5
#define DEFAULT_INTERVAL	1

int pw_protocol_native_ext_profiler_init(struct pw_context *context);

#define pw_profiler_resource(r,m,v,...)      \
	pw_resource_call(r,struct pw_profiler_events,m,v,__VA_ARGS__)

#define pw_profiler_resource_profile(r,...)        \
        pw_profiler_resource(r,profile,0,__VA_ARGS__)

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Generate Profiling data" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct impl {
	struct pw_context *context;
	struct pw_properties *properties;

	struct spa_hook context_listener;
	struct spa_hook module_listener;

	struct pw_global *global;

	int64_t count;
	uint32_t busy;
	uint32_t empty;
	struct spa_source *flush_timeout;
	unsigned int flushing:1;
	unsigned int listening:1;

	struct spa_ringbuffer buffer;
	uint8_t data[MAX_BUFFER];
};

struct resource_data {
	struct impl *impl;

	struct pw_resource *resource;
	struct spa_hook resource_listener;
};

static void start_flush(struct impl *impl)
{
	struct timespec value, interval;

	value.tv_sec = 0;
        value.tv_nsec = 1;
	interval.tv_sec = DEFAULT_INTERVAL;
        interval.tv_nsec = 0;
        pw_loop_update_timer(impl->context->main_loop,
			impl->flush_timeout, &value, &interval, false);
	impl->flushing = true;
}

static void stop_flush(struct impl *impl)
{
	struct timespec value, interval;

	if (!impl->flushing)
		return;

	value.tv_sec = 0;
        value.tv_nsec = 0;
	interval.tv_sec = 0;
        interval.tv_nsec = 0;
        pw_loop_update_timer(impl->context->main_loop,
			impl->flush_timeout, &value, &interval, false);
	impl->flushing = false;
}

static void flush_timeout(void *data, uint64_t expirations)
{
	struct impl *impl = data;
	int32_t avail, size;
	uint32_t idx;
	struct spa_pod_struct *p;
	struct pw_resource *resource;

	avail = spa_ringbuffer_get_read_index(&impl->buffer, &idx);

	pw_log_trace(NAME"%p avail %d", impl, avail);

	if (avail <= 0) {
		if (++impl->empty == DEFAULT_IDLE)
			stop_flush(impl);
		return;
	}
	impl->empty = 0;

	size = avail + sizeof(struct spa_pod_struct);
	p = alloca(size);
	*p = SPA_POD_INIT_Struct(avail);

	spa_ringbuffer_read_data(&impl->buffer, impl->data, MAX_BUFFER,
			idx % MAX_BUFFER,
			SPA_MEMBER(p, sizeof(struct spa_pod_struct), void), avail);
	spa_ringbuffer_read_update(&impl->buffer, idx + avail);

	spa_list_for_each(resource, &impl->global->resource_list, link)
		pw_profiler_resource_profile(resource, &p->pod);
}

static void context_do_profile(void *data, struct pw_impl_node *node)
{
	struct impl *impl = data;
	char buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod_frame f[2];
	struct pw_node_activation *a = node->rt.activation;
	struct spa_io_position *pos = &a->position;
	struct pw_node_target *t;
	int32_t filled;
	uint32_t idx, avail;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_OBJECT_Profiler, 0);

	spa_pod_builder_prop(&b, SPA_PROFILER_info, 0);
	spa_pod_builder_add_struct(&b,
			SPA_POD_Long(impl->count),
			SPA_POD_Float(a->cpu_load[0]),
			SPA_POD_Float(a->cpu_load[1]),
			SPA_POD_Float(a->cpu_load[2]),
			SPA_POD_Int(a->xrun_count));

	spa_pod_builder_prop(&b, SPA_PROFILER_clock, 0);
	spa_pod_builder_add_struct(&b,
			SPA_POD_Int(pos->clock.flags),
			SPA_POD_Int(pos->clock.id),
			SPA_POD_String(pos->clock.name),
			SPA_POD_Long(pos->clock.nsec),
			SPA_POD_Fraction(&pos->clock.rate),
			SPA_POD_Long(pos->clock.position),
			SPA_POD_Long(pos->clock.duration),
			SPA_POD_Long(pos->clock.delay),
			SPA_POD_Double(pos->clock.rate_diff),
			SPA_POD_Long(pos->clock.next_nsec));

	spa_pod_builder_prop(&b, SPA_PROFILER_driverBlock, 0);
	spa_pod_builder_add_struct(&b,
			SPA_POD_Int(node->info.id),
			SPA_POD_String(node->name),
			SPA_POD_Long(a->prev_signal_time),
			SPA_POD_Long(a->signal_time),
			SPA_POD_Long(a->awake_time),
			SPA_POD_Long(a->finish_time),
			SPA_POD_Int(a->status),
			SPA_POD_Fraction(&node->latency));

	spa_list_for_each(t, &node->rt.target_list, link) {
		struct pw_impl_node *n = t->node;
		struct pw_node_activation *na;

		if (n == NULL || n == node)
			continue;

		na = n->rt.activation;
		spa_pod_builder_prop(&b, SPA_PROFILER_followerBlock, 0);
		spa_pod_builder_add_struct(&b,
			SPA_POD_Int(n->info.id),
			SPA_POD_String(n->name),
			SPA_POD_Long(a->signal_time),
			SPA_POD_Long(na->signal_time),
			SPA_POD_Long(na->awake_time),
			SPA_POD_Long(na->finish_time),
			SPA_POD_Int(na->status),
			SPA_POD_Fraction(&n->latency));
	}
	spa_pod_builder_pop(&b, &f[0]);

	filled = spa_ringbuffer_get_write_index(&impl->buffer, &idx);
	if (filled < 0 || filled > MAX_BUFFER) {
		pw_log_warn(NAME " %p: queue xrun %d", impl, filled);
		goto done;
	}
	avail = MAX_BUFFER - filled;
	if (avail < b.state.offset) {
		pw_log_warn(NAME " %p: queue full %d < %d", impl, avail, b.state.offset);
		goto done;
	}
	spa_ringbuffer_write_data(&impl->buffer,
			impl->data, MAX_BUFFER,
			idx % MAX_BUFFER,
			b.data, b.state.offset);
	spa_ringbuffer_write_update(&impl->buffer, idx + b.state.offset);

	if (!impl->flushing || filled + b.state.offset > MIN_FLUSH)
		start_flush(impl);
done:
	impl->count++;
}

static const struct pw_context_driver_events context_events = {
	PW_VERSION_CONTEXT_DRIVER_EVENTS,
	.incomplete = context_do_profile,
	.complete = context_do_profile,
};

static int do_stop(struct spa_loop *loop,
		bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct impl *impl = user_data;
	spa_hook_remove(&impl->context_listener);
	return 0;
}

static void stop_listener(struct impl *impl)
{
	if (impl->listening) {
		pw_loop_invoke(impl->context->data_loop,
                       do_stop, SPA_ID_INVALID, NULL, 0, true, impl);
		impl->listening = false;
	}
}

static void resource_destroy(void *data)
{
	struct impl *impl = data;
	if (--impl->busy == 0) {
		pw_log_info(NAME" %p: stopping profiler", impl);
		stop_listener(impl);
	}
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = resource_destroy,
};

static int
do_start(struct spa_loop *loop,
		bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct impl *impl = user_data;
	spa_hook_list_append(&impl->context->driver_listener_list,
			&impl->context_listener,
			&context_events, impl);
	return 0;
}
static int
global_bind(void *_data, struct pw_impl_client *client, uint32_t permissions,
            uint32_t version, uint32_t id)
{
	struct impl *impl = _data;
	struct pw_global *global = impl->global;
	struct pw_resource *resource;
	struct resource_data *data;

	resource = pw_resource_new(client, id, permissions,
			PW_TYPE_INTERFACE_Profiler, version, sizeof(*data));
        if (resource == NULL)
                return -errno;

        data = pw_resource_get_user_data(resource);
        data->impl = impl;
        data->resource = resource;
	pw_global_add_resource(global, resource);

	pw_resource_add_listener(resource, &data->resource_listener,
			&resource_events, impl);

	if (++impl->busy == 1) {
		pw_log_info(NAME" %p: starting profiler", impl);
		pw_loop_invoke(impl->context->data_loop,
                       do_start, SPA_ID_INVALID, NULL, 0, false, impl);
		impl->listening = true;
	}
	return 0;
}

static void module_destroy(void *data)
{
	struct impl *impl = data;

	pw_global_destroy(impl->global);

	spa_hook_remove(&impl->module_listener);

	if (impl->properties)
		pw_properties_free(impl->properties);

	free(impl);
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy,
};

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_properties *props;
	struct impl *impl;
	struct pw_loop *main_loop = pw_context_get_main_loop(context);

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	pw_protocol_native_ext_profiler_init(context);

	pw_log_debug("module %p: new %s", impl, args);

	if (args)
		props = pw_properties_new_string(args);
	else
		props = pw_properties_new(NULL, NULL);

	impl->context = context;
	impl->properties = props;

	spa_ringbuffer_init(&impl->buffer);

	impl->global = pw_global_new(context,
			PW_TYPE_INTERFACE_Profiler,
			PW_VERSION_PROFILER,
			pw_properties_copy(props),
			global_bind, impl);
	if (impl->global == NULL) {
		free(impl);
		return -errno;
	}

	impl->flush_timeout = pw_loop_add_timer(main_loop, flush_timeout, impl);

	pw_impl_module_add_listener(module, &impl->module_listener, &module_events, impl);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	pw_global_register(impl->global);

	return 0;
}
