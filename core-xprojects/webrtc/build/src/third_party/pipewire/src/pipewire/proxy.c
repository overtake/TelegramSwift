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

#include <assert.h>

#include <pipewire/log.h>
#include <pipewire/proxy.h>
#include <pipewire/core.h>
#include <pipewire/private.h>
#include <pipewire/type.h>

#include <spa/debug/types.h>

#define NAME "proxy"

/** \cond */
struct proxy {
	struct pw_proxy this;
};
/** \endcond */

int pw_proxy_init(struct pw_proxy *proxy, const char *type, uint32_t version)
{
	int res;

	proxy->refcount = 1;
	proxy->type = type;
	proxy->version = version;
	proxy->bound_id = SPA_ID_INVALID;

	proxy->id = pw_map_insert_new(&proxy->core->objects, proxy);
	if (proxy->id == SPA_ID_INVALID) {
		res = -errno;
		pw_log_error(NAME" %p: can't allocate new id: %m", proxy);
		goto error;
	}

	spa_hook_list_init(&proxy->listener_list);
	spa_hook_list_init(&proxy->object_listener_list);

	if ((res = pw_proxy_install_marshal(proxy, false)) < 0) {
		pw_log_error(NAME" %p: no marshal for type %s/%d: %s", proxy,
				type, version, spa_strerror(res));
		goto error_clean;
	}
	proxy->in_map = true;
	return 0;

error_clean:
	pw_map_remove(&proxy->core->objects, proxy->id);
error:
	return res;
}

/** Create a proxy object with a given id and type
 *
 * \param factory another proxy object that serves as a factory
 * \param type Type of the proxy object
 * \param user_data_size size of user_data
 * \return A newly allocated proxy object or NULL on failure
 *
 * This function creates a new proxy object with the supplied id and type. The
 * proxy object will have an id assigned from the client id space.
 *
 * \sa pw_core
 *
 * \memberof pw_proxy
 */
SPA_EXPORT
struct pw_proxy *pw_proxy_new(struct pw_proxy *factory,
			      const char *type, uint32_t version,
			      size_t user_data_size)
{
	struct proxy *impl;
	struct pw_proxy *this;
	int res;

	impl = calloc(1, sizeof(struct proxy) + user_data_size);
	if (impl == NULL)
		return NULL;

	this = &impl->this;
	this->core = factory->core;

	if ((res = pw_proxy_init(this, type, version)) < 0)
		goto error_init;

	if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct proxy), void);

	pw_log_debug(NAME" %p: new %u type %s/%d core-proxy:%p, marshal:%p",
			this, this->id, type, version, this->core, this->marshal);
	return this;

error_init:
	free(impl);
	errno = -res;
	return NULL;
}

SPA_EXPORT
int pw_proxy_install_marshal(struct pw_proxy *this, bool implementor)
{
	struct pw_core *core = this->core;
	const struct pw_protocol_marshal *marshal;

	if (core == NULL)
		return -EIO;

	marshal = pw_protocol_get_marshal(core->conn->protocol,
			this->type, this->version,
			implementor ? PW_PROTOCOL_MARSHAL_FLAG_IMPL : 0);
	if (marshal == NULL)
		return -EPROTO;

	this->marshal = marshal;
	this->type = marshal->type;

	this->impl = SPA_INTERFACE_INIT(
			this->type,
			this->marshal->version,
			this->marshal->client_marshal, this);
	return 0;
}

SPA_EXPORT
void *pw_proxy_get_user_data(struct pw_proxy *proxy)
{
	return proxy->user_data;
}

SPA_EXPORT
uint32_t pw_proxy_get_id(struct pw_proxy *proxy)
{
	return proxy->id;
}

SPA_EXPORT
int pw_proxy_set_bound_id(struct pw_proxy *proxy, uint32_t global_id)
{
	proxy->bound_id = global_id;
	pw_log_debug(NAME" %p: id:%d bound:%d", proxy, proxy->id, global_id);
	pw_proxy_emit_bound(proxy, global_id);
	return 0;
}

SPA_EXPORT
uint32_t pw_proxy_get_bound_id(struct pw_proxy *proxy)
{
	return proxy->bound_id;
}

SPA_EXPORT
const char *pw_proxy_get_type(struct pw_proxy *proxy, uint32_t *version)
{
	if (version)
		*version = proxy->version;
	return proxy->type;
}

SPA_EXPORT
struct pw_core *pw_proxy_get_core(struct pw_proxy *proxy)
{
	return proxy->core;
}

SPA_EXPORT
struct pw_protocol *pw_proxy_get_protocol(struct pw_proxy *proxy)
{
	if (proxy->core == NULL || proxy->core->conn == NULL)
		return NULL;
	return proxy->core->conn->protocol;
}

SPA_EXPORT
void pw_proxy_add_listener(struct pw_proxy *proxy,
			   struct spa_hook *listener,
			   const struct pw_proxy_events *events,
			   void *data)
{
	spa_hook_list_append(&proxy->listener_list, listener, events, data);
}

SPA_EXPORT
void pw_proxy_add_object_listener(struct pw_proxy *proxy,
				 struct spa_hook *listener,
				 const void *funcs,
				 void *data)
{
	spa_hook_list_append(&proxy->object_listener_list, listener, funcs, data);
}

static inline void remove_from_map(struct pw_proxy *proxy)
{
	if (proxy->in_map) {
		if (proxy->core)
			pw_map_remove(&proxy->core->objects, proxy->id);
		proxy->in_map = false;
	}
}

/** Destroy a proxy object
 *
 * \param proxy Proxy object to destroy
 *
 * \note This is normally called by \ref pw_core when the server
 *       decides to destroy the server side object
 * \memberof pw_proxy
 */
SPA_EXPORT
void pw_proxy_destroy(struct pw_proxy *proxy)
{
	pw_log_debug(NAME" %p: destroy id:%u removed:%u zombie:%u ref:%d", proxy,
			proxy->id, proxy->removed, proxy->zombie, proxy->refcount);

	assert(!proxy->destroyed);
	proxy->destroyed = true;

	if (!proxy->removed) {
		/* if the server did not remove this proxy, schedule a
		 * destroy if we can */
		if (proxy->core && !proxy->core->removed) {
			pw_core_destroy(proxy->core, proxy);
			proxy->refcount++;
		} else {
			proxy->removed = true;
		}
	}
	if (proxy->removed)
		remove_from_map(proxy);

	if (!proxy->zombie) {
		/* mark zombie and emit destroyed. No more
		 * events will be emitted on zombie objects */
		proxy->zombie = true;
		pw_proxy_emit_destroy(proxy);
	}

	spa_hook_list_clean(&proxy->listener_list);
	spa_hook_list_clean(&proxy->object_listener_list);

	pw_proxy_unref(proxy);
}

/** called when cleaning up or when the server removed the resource. Can
 * be called multiple times */
void pw_proxy_remove(struct pw_proxy *proxy)
{
	assert(proxy->refcount > 0);

	pw_log_debug(NAME" %p: remove id:%u removed:%u destroyed:%u zombie:%u ref:%d", proxy,
			proxy->id, proxy->removed, proxy->destroyed, proxy->zombie,
			proxy->refcount);

	if (!proxy->destroyed)
		proxy->refcount++;

	if (!proxy->removed) {
		/* mark removed and emit the removed signal only once and
		 * only when not already destroyed */
		proxy->removed = true;
		if (!proxy->destroyed)
			pw_proxy_emit_removed(proxy);
	}
	if (proxy->destroyed)
		remove_from_map(proxy);

	pw_proxy_unref(proxy);
}

SPA_EXPORT
void pw_proxy_unref(struct pw_proxy *proxy)
{
	assert(proxy->refcount > 0);
	if (--proxy->refcount > 0)
		return;

	pw_log_debug(NAME" %p: free %u", proxy, proxy->id);
	/** client must explicitly destroy all proxies */
	assert(proxy->destroyed);
	free(proxy);
}

SPA_EXPORT
void pw_proxy_ref(struct pw_proxy *proxy)
{
	assert(proxy->refcount > 0);
	proxy->refcount++;
}

SPA_EXPORT
int pw_proxy_sync(struct pw_proxy *proxy, int seq)
{
	int res = -EIO;
	struct pw_core *core = proxy->core;

	if (core && !core->removed) {
		res = pw_core_sync(core, proxy->id, seq);
		pw_log_debug(NAME" %p: %u seq:%d sync %u", proxy, proxy->id, seq, res);
	}
	return res;
}

SPA_EXPORT
int pw_proxy_errorf(struct pw_proxy *proxy, int res, const char *error, ...)
{
	va_list ap;
	int r = -EIO;
	struct pw_core *core = proxy->core;

	va_start(ap, error);
	if (core && !core->removed)
		r = pw_core_errorv(core, proxy->id,
				core->recv_seq, res, error, ap);
	va_end(ap);
	return r;
}

SPA_EXPORT
int pw_proxy_error(struct pw_proxy *proxy, int res, const char *error)
{
	int r = -EIO;
	struct pw_core *core = proxy->core;

	if (core && !core->removed)
		r = pw_core_error(core, proxy->id,
				core->recv_seq, res, error);
	return r;
}

SPA_EXPORT
struct spa_hook_list *pw_proxy_get_object_listeners(struct pw_proxy *proxy)
{
	return &proxy->object_listener_list;
}

SPA_EXPORT
const struct pw_protocol_marshal *pw_proxy_get_marshal(struct pw_proxy *proxy)
{
	return proxy->marshal;
}
