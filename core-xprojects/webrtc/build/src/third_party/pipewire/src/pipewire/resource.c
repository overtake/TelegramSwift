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

#include "pipewire/private.h"
#include "pipewire/protocol.h"
#include "pipewire/resource.h"
#include "pipewire/type.h"

#include <spa/debug/types.h>

#define NAME "resource"

/** \cond */
struct impl {
	struct pw_resource this;
};
/** \endcond */

SPA_EXPORT
struct pw_resource *pw_resource_new(struct pw_impl_client *client,
				    uint32_t id,
				    uint32_t permissions,
				    const char *type,
				    uint32_t version,
				    size_t user_data_size)
{
	struct impl *impl;
	struct pw_resource *this;
	int res;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL)
		return NULL;

	this = &impl->this;
	this->context = client->context;
	this->client = client;
	this->permissions = permissions;
	this->type = type;
	this->version = version;
	this->bound_id = SPA_ID_INVALID;

	spa_hook_list_init(&this->listener_list);
	spa_hook_list_init(&this->object_listener_list);

	if (id == SPA_ID_INVALID) {
		res = -EINVAL;
		goto error_clean;
	}

	if ((res = pw_map_insert_at(&client->objects, id, this)) < 0) {
		pw_log_error(NAME" %p: can't add id %u for client %p: %s",
			this, id, client, spa_strerror(res));
		goto error_clean;
	}
	this->id = id;

	if ((res = pw_resource_install_marshal(this, false)) < 0) {
		pw_log_error(NAME" %p: no marshal for type %s/%d: %s", this,
				type, version, spa_strerror(res));
		goto error_clean;
	}


	if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	pw_log_debug(NAME" %p: new %u type %s/%d client:%p marshal:%p",
			this, id, type, version, client, this->marshal);

	pw_impl_client_emit_resource_added(client, this);

	return this;

error_clean:
	free(impl);
	errno = -res;
	return NULL;
}

SPA_EXPORT
int pw_resource_install_marshal(struct pw_resource *this, bool implementor)
{
	struct pw_impl_client *client = this->client;
	const struct pw_protocol_marshal *marshal;

	marshal = pw_protocol_get_marshal(client->protocol,
			this->type, this->version,
			implementor ? PW_PROTOCOL_MARSHAL_FLAG_IMPL : 0);
	if (marshal == NULL)
		return -EPROTO;

	this->marshal = marshal;
	this->type = marshal->type;

	this->impl = SPA_INTERFACE_INIT(
			this->type,
			this->marshal->version,
			this->marshal->server_marshal, this);
	return 0;
}

SPA_EXPORT
struct pw_impl_client *pw_resource_get_client(struct pw_resource *resource)
{
	return resource->client;
}

SPA_EXPORT
uint32_t pw_resource_get_id(struct pw_resource *resource)
{
	return resource->id;
}

SPA_EXPORT
uint32_t pw_resource_get_permissions(struct pw_resource *resource)
{
	return resource->permissions;
}

SPA_EXPORT
const char *pw_resource_get_type(struct pw_resource *resource, uint32_t *version)
{
	if (version)
		*version = resource->version;
	return resource->type;
}

SPA_EXPORT
struct pw_protocol *pw_resource_get_protocol(struct pw_resource *resource)
{
	return resource->client->protocol;
}

SPA_EXPORT
void *pw_resource_get_user_data(struct pw_resource *resource)
{
	return resource->user_data;
}

SPA_EXPORT
void pw_resource_add_listener(struct pw_resource *resource,
			      struct spa_hook *listener,
			      const struct pw_resource_events *events,
			      void *data)
{
	spa_hook_list_append(&resource->listener_list, listener, events, data);
}

SPA_EXPORT
void pw_resource_add_object_listener(struct pw_resource *resource,
				struct spa_hook *listener,
				const void *funcs,
				void *data)
{
	spa_hook_list_append(&resource->object_listener_list, listener, funcs, data);
}

SPA_EXPORT
struct spa_hook_list *pw_resource_get_object_listeners(struct pw_resource *resource)
{
	return &resource->object_listener_list;
}

SPA_EXPORT
const struct pw_protocol_marshal *pw_resource_get_marshal(struct pw_resource *resource)
{
	return resource->marshal;
}

SPA_EXPORT
int pw_resource_ping(struct pw_resource *resource, int seq)
{
	int res = -EIO;
	struct pw_impl_client *client = resource->client;

	if (client->core_resource != NULL) {
		pw_core_resource_ping(client->core_resource, resource->id, seq);
		res = client->send_seq;
		pw_log_debug(NAME" %p: %u seq:%d ping %d", resource, resource->id, seq, res);
	}
	return res;
}

SPA_EXPORT
int pw_resource_set_bound_id(struct pw_resource *resource, uint32_t global_id)
{
	struct pw_impl_client *client = resource->client;

	resource->bound_id = global_id;
	if (client->core_resource != NULL) {
		pw_log_debug(NAME" %p: %u global_id:%u", resource, resource->id, global_id);
		pw_core_resource_bound_id(client->core_resource, resource->id, global_id);
	}
	return 0;
}

SPA_EXPORT
uint32_t pw_resource_get_bound_id(struct pw_resource *resource)
{
	return resource->bound_id;
}

static void SPA_PRINTF_FUNC(4, 0)
pw_resource_errorv_id(struct pw_resource *resource, uint32_t id, int res, const char *error, va_list ap)
{
	struct pw_impl_client *client = resource->client;
	if (client->core_resource != NULL)
		pw_core_resource_errorv(client->core_resource,
				id, client->recv_seq, res, error, ap);
}

SPA_EXPORT
void pw_resource_errorf(struct pw_resource *resource, int res, const char *error, ...)
{
	va_list ap;
	va_start(ap, error);
	pw_resource_errorv_id(resource, resource->id, res, error, ap);
	va_end(ap);
}

SPA_EXPORT
void pw_resource_errorf_id(struct pw_resource *resource, uint32_t id, int res, const char *error, ...)
{
	va_list ap;
	va_start(ap, error);
	pw_resource_errorv_id(resource, id, res, error, ap);
	va_end(ap);
}

SPA_EXPORT
void pw_resource_error(struct pw_resource *resource, int res, const char *error)
{
	struct pw_impl_client *client = resource->client;
	if (client->core_resource != NULL)
		pw_core_resource_error(client->core_resource,
				resource->id, client->recv_seq, res, error);
}

SPA_EXPORT
void pw_resource_destroy(struct pw_resource *resource)
{
	struct pw_impl_client *client = resource->client;

	if (resource->global) {
		spa_list_remove(&resource->link);
		resource->global = NULL;
	}

	pw_log_debug(NAME" %p: destroy %u", resource, resource->id);
	pw_resource_emit_destroy(resource);

	pw_map_insert_at(&client->objects, resource->id, NULL);
	pw_impl_client_emit_resource_removed(client, resource);

	if (client->core_resource && !resource->removed)
		pw_core_resource_remove_id(client->core_resource, resource->id);

	pw_log_debug(NAME" %p: free %u", resource, resource->id);

	spa_hook_list_clean(&resource->listener_list);
	spa_hook_list_clean(&resource->object_listener_list);

	free(resource);
}

SPA_EXPORT
void pw_resource_remove(struct pw_resource *resource)
{
	resource->removed = true;
	pw_resource_destroy(resource);
}
