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
#include <string.h>

#include "pipewire/impl.h"
#include "pipewire/private.h"

#define NAME "client"

/** \cond */
struct impl {
	struct pw_impl_client this;
	struct spa_hook context_listener;
	struct pw_array permissions;
	struct spa_hook pool_listener;
	unsigned int registered:1;
};

#define pw_client_resource(r,m,v,...)		pw_resource_call(r,struct pw_client_events,m,v,__VA_ARGS__)
#define pw_client_resource_info(r,...)		pw_client_resource(r,info,0,__VA_ARGS__)
#define pw_client_resource_permissions(r,...)	pw_client_resource(r,permissions,0,__VA_ARGS__)

struct resource_data {
	struct pw_resource *resource;
	struct spa_hook resource_listener;
	struct spa_hook object_listener;
	struct pw_impl_client *client;
};

/** find a specific permission for a global or the default when there is none */
static struct pw_permission *
find_permission(struct pw_impl_client *client, uint32_t id)
{
	struct impl *impl = SPA_CONTAINER_OF(client, struct impl, this);
	struct pw_permission *p;
	uint32_t idx = id + 1;

	if (id == PW_ID_ANY)
		goto do_default;

	if (!pw_array_check_index(&impl->permissions, idx, struct pw_permission))
		goto do_default;

	p = pw_array_get_unchecked(&impl->permissions, idx, struct pw_permission);
	if (p->permissions == PW_PERM_INVALID)
		goto do_default;

	return p;

do_default:
	return pw_array_get_unchecked(&impl->permissions, 0, struct pw_permission);
}

static struct pw_permission *ensure_permissions(struct pw_impl_client *client, uint32_t id)
{
	struct impl *impl = SPA_CONTAINER_OF(client, struct impl, this);
	struct pw_permission *p;
	uint32_t idx = id + 1;
	size_t len, i;

	len = pw_array_get_len(&impl->permissions, struct pw_permission);
	if (len <= idx) {
		size_t diff = idx - len + 1;

		p = pw_array_add(&impl->permissions, diff * sizeof(struct pw_permission));
		if (p == NULL)
			return NULL;

		for (i = 0; i < diff; i++) {
			p[i] = PW_PERMISSION_INIT(len + i - 1, PW_PERM_INVALID);
		}
	}
	p = pw_array_get_unchecked(&impl->permissions, idx, struct pw_permission);
	return p;
}

/** \endcond */

static uint32_t
client_permission_func(struct pw_global *global,
		       struct pw_impl_client *client, void *data)
{
	struct pw_permission *p = find_permission(client, global->id);
	return p->permissions;
}

struct error_data {
	uint32_t id;
	int res;
	const char *error;
};

static int error_resource(void *object, void *data)
{
	struct pw_resource *r = object;
	struct error_data *d = data;
	if (r && r->bound_id == d->id)
		pw_resource_error(r, d->res, d->error);
	return 0;
}

static int client_error(void *object, uint32_t id, int res, const char *error)
{
	struct resource_data *data = object;
	struct pw_impl_client *client = data->client;
	struct error_data d = { id, res, error };

	pw_log_debug(NAME" %p: error for global %d", client, id);
	pw_map_for_each(&client->objects, error_resource, &d);
	return 0;
}

static bool has_key(const char *keys[], const char *key)
{
	int i;
	for (i = 0; keys[i]; i++) {
		if (strcmp(keys[i], key) == 0)
			return true;
	}
	return false;
}

static int update_properties(struct pw_impl_client *client, const struct spa_dict *dict, bool filter)
{
	struct pw_resource *resource;
	int changed = 0;
	uint32_t i;
	const char *old, *ignored[] = {
		PW_KEY_OBJECT_ID,
		NULL
	};

        for (i = 0; i < dict->n_items; i++) {
		if (filter) {
			if (strstr(dict->items[i].key, "pipewire.") == dict->items[i].key &&
			    (old = pw_properties_get(client->properties, dict->items[i].key)) != NULL &&
			    (dict->items[i].value == NULL || strcmp(old, dict->items[i].value) != 0)) {
				pw_log_warn(NAME" %p: refuse property update '%s' from '%s' to '%s'",
						client, dict->items[i].key, old,
						dict->items[i].value);
				continue;

			}
			if (has_key(ignored, dict->items[i].key))
				continue;
		}
                changed += pw_properties_set(client->properties, dict->items[i].key, dict->items[i].value);
	}
	client->info.props = &client->properties->dict;

	pw_log_debug(NAME" %p: updated %d properties", client, changed);

	if (!changed)
		return 0;

	client->info.change_mask |= PW_CLIENT_CHANGE_MASK_PROPS;

	pw_impl_client_emit_info_changed(client, &client->info);

	if (client->global)
		spa_list_for_each(resource, &client->global->resource_list, link)
			pw_client_resource_info(resource, &client->info);

	client->info.change_mask = 0;

	return changed;
}

static void update_busy(struct pw_impl_client *client)
{
	struct pw_permission *def;
	def = find_permission(client, PW_ID_CORE);
	pw_impl_client_set_busy(client, (def->permissions & PW_PERM_R) ? false : true);
}

static int finish_register(struct pw_impl_client *client)
{
	struct impl *impl = SPA_CONTAINER_OF(client, struct impl, this);
	struct pw_impl_client *current;
	const char *keys[] = {
		PW_KEY_ACCESS,
		PW_KEY_CLIENT_ACCESS,
		PW_KEY_APP_NAME,
		NULL
	};
	if (impl->registered)
		return 0;

	impl->registered = true;

	current = client->context->current_client;
	client->context->current_client = NULL;
	pw_context_emit_check_access(client->context, client);
	client->context->current_client = current;

	update_busy(client);

	pw_global_update_keys(client->global, client->info.props, keys);
	pw_global_register(client->global);

	return 0;
}

static int client_update_properties(void *object, const struct spa_dict *props)
{
	struct resource_data *data = object;
	struct pw_impl_client *client = data->client;
	int res = update_properties(client, props, true);
	finish_register(client);
	return res;
}

static int client_get_permissions(void *object, uint32_t index, uint32_t num)
{
	struct resource_data *data = object;
	struct pw_resource *resource = data->resource;
	struct pw_impl_client *client = data->client;
	struct impl *impl = SPA_CONTAINER_OF(client, struct impl, this);
	size_t len;

	len = pw_array_get_len(&impl->permissions, struct pw_permission);
	if ((size_t)index >= len)
		num = 0;
	else if ((size_t)index + (size_t)num >= len)
		num = len - index;

	pw_client_resource_permissions(resource, index,
			num, pw_array_get_unchecked(&impl->permissions, index, struct pw_permission));
	return 0;
}

static int client_update_permissions(void *object,
		uint32_t n_permissions, const struct pw_permission *permissions)
{
	struct resource_data *data = object;
	struct pw_impl_client *client = data->client;
	return pw_impl_client_update_permissions(client, n_permissions, permissions);
}

static const struct pw_client_methods client_methods = {
	PW_VERSION_CLIENT_METHODS,
	.error = client_error,
	.update_properties = client_update_properties,
	.get_permissions = client_get_permissions,
	.update_permissions = client_update_permissions
};

static void client_unbind_func(void *data)
{
	struct resource_data *d = data;
	struct pw_resource *resource = d->resource;
	spa_hook_remove(&d->resource_listener);
	spa_hook_remove(&d->object_listener);
	if (resource->id == 1)
		resource->client->client_resource = NULL;
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = client_unbind_func,
};

static int
global_bind(void *_data, struct pw_impl_client *client, uint32_t permissions,
		 uint32_t version, uint32_t id)
{
	struct pw_impl_client *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;
	struct resource_data *data;

	resource = pw_resource_new(client, id, permissions, global->type, version, sizeof(*data));
	if (resource == NULL)
		goto error_resource;

	data = pw_resource_get_user_data(resource);
	data->resource = resource;
	data->client = this;
	pw_resource_add_listener(resource,
			&data->resource_listener,
			&resource_events, data);
	pw_resource_add_object_listener(resource,
			&data->object_listener,
			&client_methods, data);

	pw_log_debug(NAME" %p: bound to %d", this, resource->id);
	pw_global_add_resource(global, resource);

	if (resource->id == 1)
		client->client_resource = resource;

	this->info.change_mask = PW_CLIENT_CHANGE_MASK_ALL;
	pw_client_resource_info(resource, &this->info);
	this->info.change_mask = 0;

	return 0;

error_resource:
	pw_log_error(NAME" %p: can't create client resource: %m", this);
	return -errno;
}

static void pool_added(void *data, struct pw_memblock *block)
{
	struct impl *impl = data;
	struct pw_impl_client *client = &impl->this;

	pw_log_debug(NAME" %p: added block %d", client, block->id);
	if (client->core_resource) {
		pw_core_resource_add_mem(client->core_resource,
				block->id, block->type, block->fd,
				block->flags & PW_MEMBLOCK_FLAG_READWRITE);
	}
}

static void pool_removed(void *data, struct pw_memblock *block)
{
	struct impl *impl = data;
	struct pw_impl_client *client = &impl->this;
	pw_log_debug(NAME" %p: removed block %d", client, block->id);
	if (client->core_resource)
		pw_core_resource_remove_mem(client->core_resource, block->id);
}

static const struct pw_mempool_events pool_events = {
	PW_VERSION_MEMPOOL_EVENTS,
	.added = pool_added,
	.removed = pool_removed,
};

static void
context_global_removed(void *data, struct pw_global *global)
{
	struct impl *impl = data;
	struct pw_impl_client *client = &impl->this;
	struct pw_permission *p;

	p = find_permission(client, global->id);
	pw_log_debug(NAME" %p: global %d removed, %p", client, global->id, p);
	if (p->id != PW_ID_ANY)
		p->permissions = PW_PERM_INVALID;
}

static const struct pw_context_events context_events = {
	PW_VERSION_CONTEXT_EVENTS,
	.global_removed = context_global_removed,
};

/** Make a new client object
 *
 * \param context a \ref pw_context object to register the client with
 * \param ucred a ucred structure or NULL when unknown
 * \param properties optional client properties, ownership is taken
 * \return a newly allocated client object
 *
 * \memberof pw_impl_client
 */
SPA_EXPORT
struct pw_impl_client *pw_context_create_client(struct pw_impl_core *core,
				struct pw_protocol *protocol,
				struct pw_properties *properties,
				size_t user_data_size)
{
	struct pw_impl_client *this;
	struct impl *impl;
	struct pw_permission *p;
	int res;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL) {
		res = -errno;
		goto error_cleanup;
	}

	this = &impl->this;
	pw_log_debug(NAME" %p: new", this);

	this->context = core->context;
	this->core = core;
	this->protocol = protocol;

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL) {
		res = -errno;
		goto error_free;
	}

	pw_array_init(&impl->permissions, 1024);
	p = pw_array_add(&impl->permissions, sizeof(struct pw_permission));
	if (p == NULL) {
		res = -errno;
		goto error_clear_array;
	}
	p->id = PW_ID_ANY;
	p->permissions = 0;

	this->pool = pw_mempool_new(NULL);
	if (this->pool == NULL) {
		res = -errno;
		goto error_clear_array;
	}
	pw_mempool_add_listener(this->pool, &impl->pool_listener, &pool_events, impl);

	this->properties = properties;
	this->permission_func = client_permission_func;
	this->permission_data = impl;

	if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	spa_hook_list_init(&this->listener_list);

	pw_map_init(&this->objects, 0, 32);

	pw_context_add_listener(this->context, &impl->context_listener, &context_events, impl);

	this->info.props = &this->properties->dict;

	return this;

error_clear_array:
	pw_array_clear(&impl->permissions);
error_free:
	free(impl);
error_cleanup:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

static void global_destroy(void *object)
{
	struct pw_impl_client *client = object;
	spa_hook_remove(&client->global_listener);
	client->global = NULL;
	pw_impl_client_destroy(client);
}

static const struct pw_global_events global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.destroy = global_destroy,
};

SPA_EXPORT
int pw_impl_client_register(struct pw_impl_client *client,
		       struct pw_properties *properties)
{
	struct pw_context *context = client->context;
	const char *keys[] = {
		PW_KEY_MODULE_ID,
		PW_KEY_PROTOCOL,
		PW_KEY_SEC_PID,
		PW_KEY_SEC_UID,
		PW_KEY_SEC_GID,
		PW_KEY_SEC_LABEL,
		NULL
	};

	if (client->registered)
		goto error_existed;

	pw_log_debug(NAME" %p: register", client);

	client->global = pw_global_new(context,
				       PW_TYPE_INTERFACE_Client,
				       PW_VERSION_CLIENT,
				       properties,
				       global_bind,
				       client);
	if (client->global == NULL)
		return -errno;

	spa_list_append(&context->client_list, &client->link);
	client->registered = true;

	client->info.id = client->global->id;
	pw_properties_setf(client->properties, PW_KEY_OBJECT_ID, "%d", client->info.id);
	client->info.props = &client->properties->dict;
	pw_global_add_listener(client->global, &client->global_listener, &global_events, client);

	pw_global_update_keys(client->global, client->info.props, keys);

	pw_impl_client_emit_initialized(client);

	return 0;

error_existed:
	if (properties)
		pw_properties_free(properties);
	return -EEXIST;
}

SPA_EXPORT
struct pw_context *pw_impl_client_get_context(struct pw_impl_client *client)
{
	return client->core->context;
}

SPA_EXPORT
struct pw_protocol *pw_impl_client_get_protocol(struct pw_impl_client *client)
{
	return client->protocol;
}

SPA_EXPORT
struct pw_resource *pw_impl_client_get_core_resource(struct pw_impl_client *client)
{
	return client->core_resource;
}

SPA_EXPORT
struct pw_resource *pw_impl_client_find_resource(struct pw_impl_client *client, uint32_t id)
{
	return pw_map_lookup(&client->objects, id);
}

SPA_EXPORT
struct pw_global *pw_impl_client_get_global(struct pw_impl_client *client)
{
	return client->global;
}

SPA_EXPORT
const struct pw_properties *pw_impl_client_get_properties(struct pw_impl_client *client)
{
	return client->properties;
}

SPA_EXPORT
void *pw_impl_client_get_user_data(struct pw_impl_client *client)
{
	return client->user_data;
}

static int destroy_resource(void *object, void *data)
{
	if (object)
		pw_resource_destroy(object);
	return 0;
}


/** Destroy a client object
 *
 * \param client the client to destroy
 *
 * \memberof pw_impl_client
 */
SPA_EXPORT
void pw_impl_client_destroy(struct pw_impl_client *client)
{
	struct impl *impl = SPA_CONTAINER_OF(client, struct impl, this);

	pw_log_debug(NAME" %p: destroy", client);
	pw_impl_client_emit_destroy(client);

	spa_hook_remove(&impl->context_listener);

	if (client->registered)
		spa_list_remove(&client->link);

	pw_map_for_each(&client->objects, destroy_resource, client);

	if (client->global) {
		spa_hook_remove(&client->global_listener);
		pw_global_destroy(client->global);
	}

	pw_log_debug(NAME" %p: free", impl);
	pw_impl_client_emit_free(client);

	spa_hook_list_clean(&client->listener_list);

	pw_map_clear(&client->objects);
	pw_array_clear(&impl->permissions);

	spa_hook_remove(&impl->pool_listener);
	pw_mempool_destroy(client->pool);

	pw_properties_free(client->properties);

	free(impl);
}

SPA_EXPORT
void pw_impl_client_add_listener(struct pw_impl_client *client,
			    struct spa_hook *listener,
			    const struct pw_impl_client_events *events,
			    void *data)
{
	spa_hook_list_append(&client->listener_list, listener, events, data);
}

SPA_EXPORT
const struct pw_client_info *pw_impl_client_get_info(struct pw_impl_client *client)
{
	return &client->info;
}

/** Update client properties
 *
 * \param client the client
 * \param dict a \ref spa_dict with properties
 *
 * Add all properties in \a dict to the client properties. Existing
 * properties are overwritten. Items can be removed by setting the value
 * to NULL.
 *
 * \memberof pw_impl_client
 */
SPA_EXPORT
int pw_impl_client_update_properties(struct pw_impl_client *client, const struct spa_dict *dict)
{
	int res = update_properties(client, dict, false);
	finish_register(client);
	return res;
}

SPA_EXPORT
int pw_impl_client_update_permissions(struct pw_impl_client *client,
		uint32_t n_permissions, const struct pw_permission *permissions)
{
	struct pw_impl_core *core = client->core;
	struct pw_context *context = core->context;
	struct pw_permission *def;
	uint32_t i;

	if ((def = find_permission(client, PW_ID_ANY)) == NULL)
		return -EIO;

	for (i = 0; i < n_permissions; i++) {
		struct pw_permission *p;
		uint32_t old_perm, new_perm;
		struct pw_global *global;

		if (permissions[i].id == PW_ID_ANY) {
			old_perm = def->permissions;
			new_perm = permissions[i].permissions;

			if (context->current_client == client)
				new_perm &= old_perm;

			pw_log_debug(NAME" %p: set default permissions %08x -> %08x",
					client, old_perm, new_perm);

			def->permissions = new_perm;

			spa_list_for_each(global, &context->global_list, link) {
				if (global->id == client->info.id)
					continue;
				p = find_permission(client, global->id);
				if (p->id != PW_ID_ANY)
					continue;
				pw_global_update_permissions(global, client, old_perm, new_perm);
			}
		}
		else  {
			struct pw_global *global;

			global = pw_context_find_global(context, permissions[i].id);
			if (global == NULL || global->id != permissions[i].id) {
				pw_log_warn(NAME" %p: invalid global %d", client, permissions[i].id);
				continue;
			}
			p = ensure_permissions(client, permissions[i].id);
			if (p == NULL) {
				pw_log_warn(NAME" %p: can't ensure permission: %m", client);
				return -errno;
			}
			if ((def = find_permission(client, PW_ID_ANY)) == NULL)
				return -EIO;
			old_perm = p->permissions == PW_PERM_INVALID ? def->permissions : p->permissions;
			new_perm = permissions[i].permissions;

			if (context->current_client == client)
				new_perm &= old_perm;

			pw_log_debug(NAME" %p: set global %d permissions %08x -> %08x",
					client, global->id, old_perm, new_perm);

			p->permissions = new_perm;
			pw_global_update_permissions(global, client, old_perm, new_perm);
		}
	}
	update_busy(client);
	return 0;
}

SPA_EXPORT
void pw_impl_client_set_busy(struct pw_impl_client *client, bool busy)
{
	if (client->busy != busy) {
		pw_log_debug(NAME" %p: busy %d", client, busy);
		client->busy = busy;
		pw_impl_client_emit_busy_changed(client, busy);
	}
}

SPA_EXPORT
int pw_impl_client_check_permissions(struct pw_impl_client *client,
		uint32_t global_id, uint32_t permissions)
{
	struct pw_context *context = client->context;
	struct pw_global *global;
	uint32_t perms;

	if ((global = pw_context_find_global(context, global_id)) == NULL)
		return -ENOENT;

	perms = pw_global_get_permissions(global, client);
	if ((perms & permissions) != permissions)
		return -EPERM;

	return 0;
}
