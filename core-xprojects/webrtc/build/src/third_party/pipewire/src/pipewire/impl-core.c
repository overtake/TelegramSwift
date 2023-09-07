/* PipeWire
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

#include "config.h"

#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#ifndef ENODATA
#define ENODATA 9919
#endif
#if HAVE_SYS_RANDOM_H
#include <sys/random.h>
#endif

#undef GETRANDOM_FALLBACK
#ifndef HAVE_GETRANDOM
# ifdef __FreeBSD__
#  include <sys/param.h>
// FreeBSD versions < 12 do not have getrandom() syscall
// Give a poor-man implementation here
// Can be removed after September 30, 2021
#  if __FreeBSD_version < 1200000
#   define GETRANDOM_FALLBACK	1
#  endif
# else
#  include <fcntl.h>
#  define GETRANDOM_FALLBACK	1
# endif
#endif

#ifdef GETRANDOM_FALLBACK
ssize_t getrandom(void *buf, size_t buflen, unsigned int flags) {
	int fd = open("/dev/random", O_CLOEXEC);
	if (fd < 0)
		return -1;
	ssize_t bytes = read(fd, buf, buflen);
	close(fd);
	return bytes;
}
#endif

#include <spa/debug/types.h>

#include "pipewire/impl.h"
#include "pipewire/private.h"

#include "extensions/protocol-native.h"

#define NAME "impl-core"

struct resource_data {
	struct pw_resource *resource;
	struct spa_hook resource_listener;
	struct spa_hook object_listener;
};

static void * registry_bind(void *object, uint32_t id,
		const char *type, uint32_t version, size_t user_data_size)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_context *context = resource->context;
	struct pw_global *global;
	uint32_t permissions, new_id = user_data_size;

	if ((global = pw_context_find_global(context, id)) == NULL)
		goto error_no_id;

	permissions = pw_global_get_permissions(global, client);

	if (!PW_PERM_IS_R(permissions))
		goto error_no_id;

	if (strcmp(global->type, type) != 0)
		goto error_wrong_interface;

	pw_log_debug("global %p: bind global id %d, iface %s/%d to %d", global, id,
		     type, version, new_id);

	if (pw_global_bind(global, client, permissions, version, new_id) < 0)
		goto error_exit_clean;

	return NULL;

error_no_id:
	pw_log_debug("registry %p: no global with id %u to bind to %u", resource, id, new_id);
	pw_resource_errorf_id(resource, new_id, -ENOENT, "no global %u", id);
	goto error_exit_clean;
error_wrong_interface:
	pw_log_debug("registry %p: global with id %u has no interface %s", resource, id, type);
	pw_resource_errorf_id(resource, new_id, -ENOSYS, "no interface %s", type);
	goto error_exit_clean;
error_exit_clean:
	/* unmark the new_id the map, the client does not yet know about the failed
	 * bind and will choose the next id, which we would refuse when we don't mark
	 * new_id as 'used and freed' */
	pw_map_insert_at(&client->objects, new_id, NULL);
	pw_core_resource_remove_id(client->core_resource, new_id);
	return NULL;
}

static int registry_destroy(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_context *context = resource->context;
	struct pw_global *global;
	uint32_t permissions;
	int res;

	if ((global = pw_context_find_global(context, id)) == NULL)
		goto error_no_id;

	permissions = pw_global_get_permissions(global, client);

	if (!PW_PERM_IS_R(permissions))
		goto error_no_id;

	if (id == PW_ID_CORE || !PW_PERM_IS_X(permissions))
		goto error_not_allowed;

	pw_log_debug("global %p: destroy global id %d", global, id);

	pw_global_destroy(global);
	return 0;

error_no_id:
	pw_log_debug("registry %p: no global with id %u to destroy", resource, id);
	pw_resource_errorf(resource, -ENOENT, "no global %u", id);
	res = -ENOENT;
	goto error_exit;
error_not_allowed:
	pw_log_debug("registry %p: destroy of id %u not allowed", resource, id);
	pw_resource_errorf(resource, -EPERM, "no permission to destroy %u", id);
	res = -EPERM;
	goto error_exit;
error_exit:
	return res;
}

static const struct pw_registry_methods registry_methods = {
	PW_VERSION_REGISTRY_METHODS,
	.bind = registry_bind,
	.destroy = registry_destroy
};

static void destroy_registry_resource(void *object)
{
	struct resource_data *data = object;
	struct pw_resource *resource = data->resource;
	spa_list_remove(&resource->link);
	spa_hook_remove(&data->resource_listener);
	spa_hook_remove(&data->object_listener);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = destroy_registry_resource
};

static int destroy_resource(void *object, void *data)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client;

	if (resource &&
	    (client = resource->client) != NULL &&
	    resource != client->core_resource) {
		pw_resource_remove(resource);
	}
	return 0;
}

static int core_hello(void *object, uint32_t version)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_context *context = client->context;
	struct pw_impl_core *this = client->core;
	int res;

	pw_log_debug(NAME" %p: hello %d from resource %p", context, version, resource);
	pw_map_for_each(&client->objects, destroy_resource, client);

	pw_mempool_clear(client->pool);

	this->info.change_mask = PW_CORE_CHANGE_MASK_ALL;
	pw_core_resource_info(resource, &this->info);

	if (version >= 3) {
		if ((res = pw_global_bind(client->global, client,
				PW_PERM_ALL, PW_VERSION_CLIENT, 1)) < 0)
			return res;
	}
	return 0;
}

static int core_sync(void *object, uint32_t id, int seq)
{
	struct pw_resource *resource = object;
	pw_log_trace(NAME" %p: sync %d for resource %d", resource->context, seq, id);
	pw_core_resource_done(resource, id, seq);
	return 0;
}

static int core_pong(void *object, uint32_t id, int seq)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_resource *r;

	pw_log_debug(NAME" %p: pong %d for resource %d", resource->context, seq, id);

	if ((r = pw_impl_client_find_resource(client, id)) == NULL)
		return -EINVAL;

	pw_resource_emit_pong(r, seq);
	return 0;
}

static int core_error(void *object, uint32_t id, int seq, int res, const char *message)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_resource *r;

	pw_log_error(NAME" %p: error %d for resource %d: %s", resource->context, res, id, message);

	if ((r = pw_impl_client_find_resource(client, id)) == NULL)
		return -EINVAL;

	pw_resource_emit_error(r, seq, res, message);
	return 0;
}

static struct pw_registry *core_get_registry(void *object, uint32_t version, size_t user_data_size)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_context *context = client->context;
	struct pw_global *global;
	struct pw_resource *registry_resource;
	struct resource_data *data;
	uint32_t new_id = user_data_size;
	int res;

	registry_resource = pw_resource_new(client,
					    new_id,
					    PW_PERM_ALL,
					    PW_TYPE_INTERFACE_Registry,
					    version,
					    sizeof(*data));
	if (registry_resource == NULL) {
		res = -errno;
		goto error_resource;
	}

	data = pw_resource_get_user_data(registry_resource);
	data->resource = registry_resource;
	pw_resource_add_listener(registry_resource,
				&data->resource_listener,
				&resource_events,
				data);
	pw_resource_add_object_listener(registry_resource,
				&data->object_listener,
				&registry_methods,
				resource);

	spa_list_append(&context->registry_resource_list, &registry_resource->link);

	spa_list_for_each(global, &context->global_list, link) {
		uint32_t permissions = pw_global_get_permissions(global, client);
		if (PW_PERM_IS_R(permissions)) {
			pw_registry_resource_global(registry_resource,
						    global->id,
						    permissions,
						    global->type,
						    global->version,
						    &global->properties->dict);
		}
	}

	return (struct pw_registry *)registry_resource;

error_resource:
	pw_core_resource_errorf(client->core_resource, new_id,
			client->recv_seq, res,
			"can't create registry resource: %d (%s)",
			res, spa_strerror(res));
	pw_map_insert_at(&client->objects, new_id, NULL);
	pw_core_resource_remove_id(client->core_resource, new_id);
	errno = -res;
	return NULL;
}

static void *
core_create_object(void *object,
		   const char *factory_name,
		   const char *type,
		   uint32_t version,
		   const struct spa_dict *props,
		   size_t user_data_size)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_impl_factory *factory;
	void *obj;
	struct pw_properties *properties;
	struct pw_context *context = client->context;
	uint32_t new_id = user_data_size;
	int res;

	factory = pw_context_find_factory(context, factory_name);
	if (factory == NULL || factory->global == NULL)
		goto error_no_factory;

	if (!PW_PERM_IS_R(pw_global_get_permissions(factory->global, client)))
		goto error_no_factory;

	if (strcmp(factory->info.type, type) != 0)
		goto error_type;

	if (factory->info.version < version)
		goto error_version;

	if (props) {
		properties = pw_properties_new_dict(props);
		if (properties == NULL)
			goto error_properties;
	} else
		properties = NULL;

	/* error will be posted */
	obj = pw_impl_factory_create_object(factory, resource, type, version, properties, new_id);
	if (obj == NULL)
		goto error_create_failed;

	return 0;

error_no_factory:
	res = -ENOENT;
	pw_log_debug(NAME" %p: can't find factory '%s'", context, factory_name);
	pw_resource_errorf_id(resource, new_id, res, "unknown factory name %s", factory_name);
	goto error_exit;
error_version:
error_type:
	res = -EPROTO;
	pw_log_debug(NAME" %p: invalid resource type/version", context);
	pw_resource_errorf_id(resource, new_id, res, "wrong resource type/version");
	goto error_exit;
error_properties:
	res = -errno;
	pw_log_debug(NAME" %p: can't create properties: %m", context);
	pw_resource_errorf_id(resource, new_id, res, "can't create properties: %s", spa_strerror(res));
	goto error_exit;
error_create_failed:
	res = -errno;
	goto error_exit;
error_exit:
	pw_map_insert_at(&client->objects, new_id, NULL);
	pw_core_resource_remove_id(client->core_resource, new_id);
	errno = -res;
	return NULL;
}

static int core_destroy(void *object, void *proxy)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = resource->client;
	struct pw_impl_core *this = client->core;
	struct pw_resource *r = proxy;
	pw_log_debug(NAME" %p: destroy resource %p from client %p", this, r, client);
	pw_resource_destroy(r);
	return 0;
}

static const struct pw_core_methods core_methods = {
	PW_VERSION_CORE_METHODS,
	.hello = core_hello,
	.sync = core_sync,
	.pong = core_pong,
	.error = core_error,
	.get_registry = core_get_registry,
	.create_object = core_create_object,
	.destroy = core_destroy,
};

SPA_EXPORT
struct pw_impl_core *pw_context_create_core(struct pw_context *context,
				  struct pw_properties *properties,
				  size_t user_data_size)
{
	struct pw_impl_core *this;
	const char *name;
	int res;

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL)
		return NULL;

	this = calloc(1, sizeof(*this) + user_data_size);
	if (this == NULL) {
		res = -errno;
		goto error_exit;
	};

	this->context = context;
	this->properties = properties;

	if ((name = pw_properties_get(properties, PW_KEY_CORE_NAME)) == NULL) {
		pw_properties_setf(properties,
				   PW_KEY_CORE_NAME, "pipewire-%s-%d",
				   pw_get_user_name(), getpid());
		name = pw_properties_get(properties, PW_KEY_CORE_NAME);
	}

	this->info.user_name = pw_get_user_name();
	this->info.host_name = pw_get_host_name();
	this->info.version = pw_get_library_version();
	do {
		res = getrandom(&this->info.cookie,
				sizeof(this->info.cookie), 0);
	} while ((res == -1) && (errno == EINTR));
	if (res == -1) {
		res = -errno;
		goto error_exit;
	} else if (res != sizeof(this->info.cookie)) {
		res = -ENODATA;
		goto error_exit;
	}
	this->info.name = name;
	spa_hook_list_init(&this->listener_list);

	if (user_data_size > 0)
		this->user_data = SPA_MEMBER(this, sizeof(*this), void);

	pw_log_debug(NAME" %p: new %s", this, name);

	return this;

error_exit:
	if (properties)
		pw_properties_free(properties);
	free(this);
	errno = -res;
	return NULL;
}

SPA_EXPORT
struct pw_impl_core *pw_context_get_default_core(struct pw_context *context)
{
	return context->core;
}

SPA_EXPORT
void pw_impl_core_destroy(struct pw_impl_core *core)
{
	pw_log_debug(NAME" %p: destroy", core);
	pw_impl_core_emit_destroy(core);

	if (core->registered)
		spa_list_remove(&core->link);

	if (core->global) {
		spa_hook_remove(&core->global_listener);
		pw_global_destroy(core->global);
	}

	pw_impl_core_emit_free(core);
	pw_log_debug(NAME" %p: free", core);

	spa_hook_list_clean(&core->listener_list);

	pw_properties_free(core->properties);

	free(core);
}

static void core_unbind_func(void *data)
{
	struct resource_data *d = data;
	struct pw_resource *resource = d->resource;
	spa_hook_remove(&d->resource_listener);
	spa_hook_remove(&d->object_listener);
	if (resource->id == 0)
		resource->client->core_resource = NULL;
}

static const struct pw_resource_events core_resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = core_unbind_func,
};

static int
global_bind(void *_data,
	    struct pw_impl_client *client,
	    uint32_t permissions,
	    uint32_t version,
	    uint32_t id)
{
	struct pw_impl_core *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;
	struct resource_data *data;
	int res;

	resource = pw_resource_new(client, id, permissions, global->type, version, sizeof(*data));
	if (resource == NULL) {
		res = -errno;
		goto error;
	}

	data = pw_resource_get_user_data(resource);
	data->resource = resource;

	pw_resource_add_listener(resource,
			&data->resource_listener,
			&core_resource_events, data);
	pw_resource_add_object_listener(resource,
			&data->object_listener,
			&core_methods, resource);

	pw_global_add_resource(global, resource);

	if (resource->id == 0) {
		client->core_resource = resource;
	}
	else {
		this->info.change_mask = PW_CORE_CHANGE_MASK_ALL;
		pw_core_resource_info(resource, &this->info);
		this->info.change_mask = 0;
	}

	pw_log_debug(NAME" %p: bound to %d", this, resource->id);

	return 0;

error:
	pw_log_error(NAME" %p: can't create resource: %m", this);
	return res;
}

static void global_destroy(void *object)
{
	struct pw_impl_core *core = object;
	spa_hook_remove(&core->global_listener);
	core->global = NULL;
	pw_impl_core_destroy(core);
}

static const struct pw_global_events global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.destroy = global_destroy,
};

SPA_EXPORT
const struct pw_properties *pw_impl_core_get_properties(struct pw_impl_core *core)
{
	return core->properties;
}

SPA_EXPORT
int pw_impl_core_update_properties(struct pw_impl_core *core, const struct spa_dict *dict)
{
	struct pw_resource *resource;
	int changed;

	changed = pw_properties_update(core->properties, dict);
	core->info.props = &core->properties->dict;

	pw_log_debug(NAME" %p: updated %d properties", core, changed);

	if (!changed)
		return 0;

	core->info.change_mask |= PW_CORE_CHANGE_MASK_PROPS;
	if (core->global)
		spa_list_for_each(resource, &core->global->resource_list, link)
			pw_core_resource_info(resource, &core->info);
	core->info.change_mask = 0;

	return changed;
}

SPA_EXPORT
int pw_impl_core_register(struct pw_impl_core *core,
			 struct pw_properties *properties)
{
	struct pw_context *context = core->context;
	int res;
	const char *keys[] = {
		PW_KEY_USER_NAME,
		PW_KEY_HOST_NAME,
		PW_KEY_CORE_NAME,
		PW_KEY_CORE_VERSION,
		NULL
	};

	if (core->registered)
		goto error_existed;

        core->global = pw_global_new(context,
					PW_TYPE_INTERFACE_Core,
					PW_VERSION_CORE,
					properties,
					global_bind,
					core);
	if (core->global == NULL)
		return -errno;

	spa_list_append(&context->core_impl_list, &core->link);
	core->registered = true;

	core->info.id = core->global->id;
	pw_properties_setf(core->properties, PW_KEY_OBJECT_ID, "%d", core->info.id);
	core->info.props = &core->properties->dict;

	pw_global_update_keys(core->global, core->info.props, keys);

	pw_impl_core_emit_initialized(core);

	pw_global_add_listener(core->global, &core->global_listener, &global_events, core);
	pw_global_register(core->global);

	return 0;

error_existed:
	res = -EEXIST;
	goto error_exit;
error_exit:
	if (properties)
		pw_properties_free(properties);
	return res;
}

SPA_EXPORT
void *pw_impl_core_get_user_data(struct pw_impl_core *core)
{
	return core->user_data;
}

SPA_EXPORT
struct pw_global *pw_impl_core_get_global(struct pw_impl_core *core)
{
	return core->global;
}

SPA_EXPORT
void pw_impl_core_add_listener(struct pw_impl_core *core,
			     struct spa_hook *listener,
			     const struct pw_impl_core_events *events,
			     void *data)
{
	spa_hook_list_append(&core->listener_list, listener, events, data);
}
