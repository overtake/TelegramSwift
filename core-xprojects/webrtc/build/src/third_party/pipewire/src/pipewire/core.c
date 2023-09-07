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
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <sys/mman.h>

#include <spa/pod/parser.h>
#include <spa/debug/types.h>

#include "pipewire/pipewire.h"
#include "pipewire/private.h"

#include "extensions/protocol-native.h"

#define NAME "core"

/** \cond */

/** \endcond */
static void core_event_ping(void *data, uint32_t id, int seq)
{
	struct pw_core *this = data;
	pw_log_debug(NAME" %p: object %u ping %u", this, id, seq);
	pw_core_pong(this->core, id, seq);
}

static void core_event_done(void *data, uint32_t id, int seq)
{
	struct pw_core *this = data;
	struct pw_proxy *proxy;

	pw_log_trace(NAME" %p: object %u done %d", this, id, seq);

	proxy = pw_map_lookup(&this->objects, id);
	if (proxy)
		pw_proxy_emit_done(proxy, seq);
}

static void core_event_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct pw_core *this = data;
	struct pw_proxy *proxy;

	proxy = pw_map_lookup(&this->objects, id);

	pw_log_debug(NAME" %p: proxy %p id:%u: bound:%d seq:%d res:%d (%s) msg:\"%s\"",
			this, proxy, id, proxy ? proxy->bound_id : SPA_ID_INVALID,
			seq, res, spa_strerror(res), message);
	if (proxy)
		pw_proxy_emit_error(proxy, seq, res, message);
}

static void core_event_remove_id(void *data, uint32_t id)
{
	struct pw_core *this = data;
	struct pw_proxy *proxy;

	pw_log_debug(NAME" %p: object remove %u", this, id);
	if ((proxy = pw_map_lookup(&this->objects, id)) != NULL)
		pw_proxy_remove(proxy);
}

static void core_event_bound_id(void *data, uint32_t id, uint32_t global_id)
{
	struct pw_core *this = data;
	struct pw_proxy *proxy;

	pw_log_debug(NAME" %p: proxy id %u bound %u", this, id, global_id);
	if ((proxy = pw_map_lookup(&this->objects, id)) != NULL) {
		pw_proxy_set_bound_id(proxy, global_id);
	}
}

static void core_event_add_mem(void *data, uint32_t id, uint32_t type, int fd, uint32_t flags)
{
	struct pw_core *this = data;
	struct pw_memblock *m;

	pw_log_debug(NAME" %p: add mem %u type:%u fd:%d flags:%u", this, id, type, fd, flags);

	m = pw_mempool_import(this->pool, flags, type, fd);
	if (m->id != id) {
		pw_log_error(NAME" %p: invalid mem id %u, expected %u",
				this, id, m->id);
		pw_proxy_errorf(&this->proxy, -EINVAL, "invalid mem id %u, expected %u", id, m->id);
		pw_memblock_unref(m);
	}
}

static void core_event_remove_mem(void *data, uint32_t id)
{
	struct pw_core *this = data;
	pw_log_debug(NAME" %p: remove mem %u", this, id);
	pw_mempool_remove_id(this->pool, id);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = core_event_error,
	.ping = core_event_ping,
	.done = core_event_done,
	.remove_id = core_event_remove_id,
	.bound_id = core_event_bound_id,
	.add_mem = core_event_add_mem,
	.remove_mem = core_event_remove_mem,
};

SPA_EXPORT
struct pw_context *pw_core_get_context(struct pw_core *core)
{
	return core->context;
}

SPA_EXPORT
const struct pw_properties *pw_core_get_properties(struct pw_core *core)
{
	return core->properties;
}

SPA_EXPORT
int pw_core_update_properties(struct pw_core *core, const struct spa_dict *dict)
{
	int changed;

	changed = pw_properties_update(core->properties, dict);

	pw_log_debug(NAME" %p: updated %d properties", core, changed);

	if (!changed)
		return 0;

	if (core->client)
		pw_client_update_properties(core->client, &core->properties->dict);

	return changed;
}

SPA_EXPORT
void *pw_core_get_user_data(struct pw_core *core)
{
	return core->user_data;
}

static int remove_proxy(void *object, void *data)
{
	struct pw_core *core = data;
	struct pw_proxy *p = object;

	if (object == NULL)
		return 0;

	if (object != core)
		pw_proxy_remove(p);

	return 0;
}

static int destroy_proxy(void *object, void *data)
{
	struct pw_core *core = data;
	struct pw_proxy *p = object;

	if (object == NULL)
		return 0;

	if (object != core) {
		pw_log_warn(NAME" %p: leaked proxy %p id:%d", core, p, p->id);
		p->core = NULL;
	}
	return 0;
}

static void proxy_core_removed(void *data)
{
	struct pw_core *core = data;
	struct pw_stream *stream, *s2;
	struct pw_filter *filter, *f2;

	if (core->removed)
		return;

	core->removed = true;

	pw_log_debug(NAME" %p: core proxy removed", core);
	spa_list_remove(&core->link);

	spa_list_for_each_safe(stream, s2, &core->stream_list, link)
		pw_stream_disconnect(stream);
	spa_list_for_each_safe(filter, f2, &core->filter_list, link)
		pw_filter_disconnect(filter);

	pw_map_for_each(&core->objects, remove_proxy, core);
}

static void proxy_core_destroy(void *data)
{
	struct pw_core *core = data;
	struct pw_stream *stream;
	struct pw_filter *filter;

	if (core->destroyed)
		return;

	core->destroyed = true;

	pw_log_debug(NAME" %p: core proxy destroy", core);

	spa_list_consume(stream, &core->stream_list, link)
		pw_stream_destroy(stream);
	spa_list_consume(filter, &core->filter_list, link)
		pw_filter_destroy(filter);

	pw_proxy_destroy((struct pw_proxy*)core->client);

	pw_map_for_each(&core->objects, destroy_proxy, core);
	pw_map_reset(&core->objects);

	pw_protocol_client_disconnect(core->conn);

	pw_mempool_destroy(core->pool);

	pw_protocol_client_destroy(core->conn);

	pw_map_clear(&core->objects);

	pw_log_debug(NAME" %p: free", core);
	pw_properties_free(core->properties);

	spa_hook_remove(&core->core_listener);
	spa_hook_remove(&core->proxy_core_listener);
}

static const struct pw_proxy_events proxy_core_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = proxy_core_removed,
	.destroy = proxy_core_destroy,
};

SPA_EXPORT
struct pw_client * pw_core_get_client(struct pw_core *core)
{
	return core->client;
}

SPA_EXPORT
struct pw_proxy *pw_core_find_proxy(struct pw_core *core, uint32_t id)
{
	return pw_map_lookup(&core->objects, id);
}

SPA_EXPORT
struct pw_proxy *pw_core_export(struct pw_core *core,
		const char *type, const struct spa_dict *props, void *object,
		size_t user_data_size)
{
	struct pw_proxy *proxy;
	const struct pw_export_type *t;
	int res;

	t = pw_context_find_export_type(core->context, type);
	if (t == NULL) {
		res = -EPROTO;
		goto error_export_type;
	}

	proxy = t->func(core, t->type, props, object, user_data_size);
        if (proxy == NULL) {
		res = -errno;
		goto error_proxy_failed;
	}
	pw_log_debug(NAME" %p: export:%s proxy:%p", core, type, proxy);
	return proxy;

error_export_type:
	pw_log_error(NAME" %p: can't export type %s: %s", core, type, spa_strerror(res));
	goto exit;
error_proxy_failed:
	pw_log_error(NAME" %p: failed to create proxy: %s", core, spa_strerror(res));
	goto exit;
exit:
	errno = -res;
	return NULL;
}

static struct pw_core *core_new(struct pw_context *context,
		struct pw_properties *properties, size_t user_data_size)
{
	struct pw_core *p;
	struct pw_protocol *protocol;
	const char *protocol_name;
	int res;

	p = calloc(1, sizeof(struct pw_core) + user_data_size);
	if (p == NULL) {
		res = -errno;
		goto exit_cleanup;
	}
	pw_log_debug(NAME" %p: new", p);

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL)
		goto error_properties;

	pw_properties_add(properties, &context->properties->dict);

	p->proxy.core = p;
	p->context = context;
	p->properties = properties;
	p->pool = pw_mempool_new(NULL);
	p->core = p;
	if (user_data_size > 0)
		p->user_data = SPA_MEMBER(p, sizeof(struct pw_core), void);
	p->proxy.user_data = p->user_data;

	pw_map_init(&p->objects, 64, 32);
	spa_list_init(&p->stream_list);
	spa_list_init(&p->filter_list);

	if ((protocol_name = pw_properties_get(properties, PW_KEY_PROTOCOL)) == NULL &&
	    (protocol_name = pw_properties_get(context->properties, PW_KEY_PROTOCOL)) == NULL)
		protocol_name = PW_TYPE_INFO_PROTOCOL_Native;

	protocol = pw_context_find_protocol(context, protocol_name);
	if (protocol == NULL) {
		res = -ENOTSUP;
		goto error_protocol;
	}

	p->conn = pw_protocol_new_client(protocol, p, &properties->dict);
	if (p->conn == NULL)
		goto error_connection;

	if ((res = pw_proxy_init(&p->proxy, PW_TYPE_INTERFACE_Core, PW_VERSION_CORE)) < 0)
		goto error_proxy;

	p->client = (struct pw_client*)pw_proxy_new(&p->proxy,
			PW_TYPE_INTERFACE_Client, PW_VERSION_CLIENT, 0);
	if (p->client == NULL) {
		res = -errno;
		goto error_proxy;
	}

	pw_core_add_listener(p, &p->core_listener, &core_events, p);
	pw_proxy_add_listener(&p->proxy, &p->proxy_core_listener, &proxy_core_events, p);

	pw_core_hello(p, PW_VERSION_CORE);
	pw_client_update_properties(p->client, &p->properties->dict);

	spa_list_append(&context->core_list, &p->link);

	return p;

error_properties:
	res = -errno;
	pw_log_error(NAME" %p: can't create properties: %m", p);
	goto exit_free;
error_protocol:
	pw_log_error(NAME" %p: can't find protocol '%s': %s", p, protocol_name, spa_strerror(res));
	goto exit_free;
error_connection:
	res = -errno;
	pw_log_error(NAME" %p: can't create new native protocol connection: %m", p);
	goto exit_free;
error_proxy:
	pw_log_error(NAME" %p: can't initialize proxy: %s", p, spa_strerror(res));
	goto exit_free;

exit_free:
	free(p);
exit_cleanup:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

SPA_EXPORT
struct pw_core *
pw_context_connect(struct pw_context *context, struct pw_properties *properties,
	      size_t user_data_size)
{
	struct pw_core *core;
	int res;

	core = core_new(context, properties, user_data_size);
	if (core == NULL)
		return NULL;

	pw_log_debug(NAME" %p: connect", core);

	if ((res = pw_protocol_client_connect(core->conn,
					&core->properties->dict,
					NULL, NULL)) < 0)
		goto error_free;

	return core;

error_free:
	pw_core_disconnect(core);
	errno = -res;
	return NULL;
}

SPA_EXPORT
struct pw_core *
pw_context_connect_fd(struct pw_context *context, int fd, struct pw_properties *properties,
	      size_t user_data_size)
{
	struct pw_core *core;
	int res;

	core = core_new(context, properties, user_data_size);
	if (core == NULL)
		return NULL;

	pw_log_debug(NAME" %p: connect fd:%d", core, fd);

	if ((res = pw_protocol_client_connect_fd(core->conn, fd, true)) < 0)
		goto error_free;

	return core;

error_free:
	pw_core_disconnect(core);
	errno = -res;
	return NULL;
}

SPA_EXPORT
struct pw_core *
pw_context_connect_self(struct pw_context *context, struct pw_properties *properties,
	      size_t user_data_size)
{
	if (properties == NULL)
                properties = pw_properties_new(NULL, NULL);
	if (properties == NULL)
		return NULL;

	pw_properties_set(properties, PW_KEY_REMOTE_NAME, "internal");

	return pw_context_connect(context, properties, user_data_size);
}

SPA_EXPORT
int pw_core_steal_fd(struct pw_core *core)
{
	int fd = pw_protocol_client_steal_fd(core->conn);
	pw_log_debug(NAME" %p: fd:%d", core, fd);
	return fd;
}

SPA_EXPORT
int pw_core_set_paused(struct pw_core *core, bool paused)
{
	pw_log_debug(NAME" %p: state:%s", core, paused ? "pause" : "resume");
	return pw_protocol_client_set_paused(core->conn, paused);
}

SPA_EXPORT
struct pw_mempool * pw_core_get_mempool(struct pw_core *core)
{
	return core->pool;
}

SPA_EXPORT
int pw_core_disconnect(struct pw_core *core)
{
	pw_log_debug(NAME" %p: disconnect", core);
	pw_proxy_remove(&core->proxy);
	pw_proxy_destroy(&core->proxy);
	return 0;
}
