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
#include <dlfcn.h>

#include "config.h"

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>

#include <pipewire/impl.h>

#include "modules/spa/spa-node.h"
#include "module-adapter/adapter.h"

#define NAME "adapter"

#define FACTORY_USAGE	SPA_KEY_FACTORY_NAME"=<factory-name> " \
			"["SPA_KEY_LIBRARY_NAME"=<library-name>] " \
			ADAPTER_USAGE

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Manage adapter nodes" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct factory_data {
	struct pw_impl_factory *this;

	struct spa_list node_list;

	struct pw_context *context;
	struct pw_impl_module *module;
	struct spa_hook module_listener;
};

struct node_data {
	struct factory_data *data;
	struct spa_list link;
	struct pw_impl_node *adapter;
	struct pw_impl_node *follower;
	struct spa_hook adapter_listener;
	struct pw_resource *resource;
	struct spa_hook resource_listener;
	uint32_t new_id;
	unsigned int linger;
};

static void resource_destroy(void *data)
{
	struct node_data *nd = data;

	pw_log_debug(NAME" %p: destroy %p", nd, nd->adapter);
	spa_hook_remove(&nd->resource_listener);
	if (nd->adapter && !nd->linger)
		pw_impl_node_destroy(nd->adapter);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = resource_destroy
};

static void node_destroy(void *data)
{
	struct node_data *nd = data;
	pw_log_debug(NAME" %p: destroy %p", nd, nd->adapter);
	spa_list_remove(&nd->link);
	nd->adapter = NULL;
}

static void node_free(void *data)
{
	struct node_data *nd = data;
	pw_log_debug(NAME" %p: free %p", nd, nd->follower);
	spa_hook_remove(&nd->adapter_listener);
	pw_impl_node_destroy(nd->follower);
}

static void node_initialized(void *data)
{
	struct node_data *nd = data;
	struct pw_impl_client *client;
	struct pw_resource *bound_resource;
	struct pw_global *global;
	int res;

	if (nd->resource == NULL)
		return;

	client = pw_resource_get_client(nd->resource);
	global = pw_impl_node_get_global(nd->adapter);

	res = pw_global_bind(global, client,
			PW_PERM_ALL, PW_VERSION_NODE, nd->new_id);
	if (res < 0)
		goto error_bind;

	if ((bound_resource = pw_impl_client_find_resource(client, nd->new_id)) == NULL) {
		res = -EIO;
		goto error_bind;
	}

	pw_resource_add_listener(bound_resource, &nd->resource_listener, &resource_events, nd);
	return;

error_bind:
	pw_resource_errorf_id(nd->resource, nd->new_id, res,
			"can't bind adapter node: %s", spa_strerror(res));
	return;
}


static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.destroy = node_destroy,
	.free = node_free,
	.initialized = node_initialized,
};

static void *create_object(void *_data,
			   struct pw_resource *resource,
			   const char *type,
			   uint32_t version,
			   struct pw_properties *properties,
			   uint32_t new_id)
{
	struct factory_data *d = _data;
	struct pw_impl_client *client;
	struct pw_impl_node *adapter, *follower;
	const char *str, *factory_name;
	int res;
	struct node_data *nd;
	bool linger;

	if (properties == NULL)
		goto error_properties;

	pw_properties_setf(properties, PW_KEY_FACTORY_ID, "%d",
			pw_impl_factory_get_info(d->this)->id);

	str = pw_properties_get(properties, PW_KEY_OBJECT_LINGER);
	linger = str ? pw_properties_parse_bool(str) : false;

	client = resource ? pw_resource_get_client(resource): NULL;
	if (client && !linger) {
		pw_properties_setf(properties, PW_KEY_CLIENT_ID, "%d",
				pw_impl_client_get_info(client)->id);
	}

	follower = NULL;
	str = pw_properties_get(properties, "adapt.follower.node");
	if (str != NULL) {
		if (sscanf(str, "pointer:%p", &follower) != 1)
			goto error_properties;

		pw_properties_setf(properties, "audio.adapt.follower", "pointer:%p", follower);
	}
	if (follower == NULL) {
		factory_name = pw_properties_get(properties, SPA_KEY_FACTORY_NAME);
		if (factory_name == NULL)
			goto error_properties;

		follower = pw_spa_node_load(d->context,
					factory_name,
					PW_SPA_NODE_FLAG_ACTIVATE |
					PW_SPA_NODE_FLAG_NO_REGISTER,
					pw_properties_copy(properties), 0);
		if (follower == NULL)
			goto error_errno;
	}

	adapter = pw_adapter_new(pw_impl_module_get_context(d->module),
			follower,
			properties,
			sizeof(struct node_data));
	properties = NULL;

	if (adapter == NULL) {
		if (errno == ENOMEM || errno == EBUSY)
			goto error_errno;
		else
			goto error_usage;
	}

	nd = pw_adapter_get_user_data(adapter);
	nd->data = d;
	nd->adapter = adapter;
	nd->follower = follower;
	nd->resource = resource;
	nd->new_id = new_id;
	nd->linger = linger;
	spa_list_append(&d->node_list, &nd->link);

	pw_impl_node_add_listener(adapter, &nd->adapter_listener, &node_events, nd);

	pw_impl_node_register(adapter, NULL);

	return adapter;

error_properties:
	res = -EINVAL;
	pw_log_error("factory %p: usage: " FACTORY_USAGE, d->this);
	if (resource)
		pw_resource_errorf_id(resource, new_id, res, "usage: " FACTORY_USAGE);
	goto error_cleanup;
error_errno:
	res = -errno;
	pw_log_error("can't create node: %m");
	if (resource)
		pw_resource_errorf_id(resource, new_id, res, "can't create node: %s", spa_strerror(res));
	goto error_cleanup;
error_usage:
	res = -EINVAL;
	pw_log_error("usage: "ADAPTER_USAGE);
	if (resource)
		pw_resource_errorf_id(resource, new_id, res, "usage: "ADAPTER_USAGE);
	goto error_cleanup;
error_cleanup:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

static const struct pw_impl_factory_implementation impl_factory = {
	PW_VERSION_IMPL_FACTORY_IMPLEMENTATION,
	.create_object = create_object,
};

static void module_destroy(void *data)
{
	struct factory_data *d = data;
	struct node_data *nd;

	pw_log_debug(NAME" %p: destroy", d);
	spa_hook_remove(&d->module_listener);

	spa_list_consume(nd, &d->node_list, link)
		pw_impl_node_destroy(nd->adapter);

	pw_impl_factory_destroy(d->this);
}

static void module_registered(void *data)
{
	struct factory_data *d = data;
	struct pw_impl_module *module = d->module;
	struct pw_impl_factory *factory = d->this;
	struct spa_dict_item items[1];
	char id[16];
	int res;

	snprintf(id, sizeof(id), "%d", pw_impl_module_get_info(module)->id);
	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_MODULE_ID, id);
	pw_impl_factory_update_properties(factory, &SPA_DICT_INIT(items, 1));

	if ((res = pw_impl_factory_register(factory, NULL)) < 0) {
		pw_log_error(NAME" %p: can't register factory: %s", factory, spa_strerror(res));
	}
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy,
	.registered = module_registered,
};

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_impl_factory *factory;
	struct factory_data *data;

	factory = pw_context_create_factory(context,
				 "adapter",
				 PW_TYPE_INTERFACE_Node,
				 PW_VERSION_NODE,
				 pw_properties_new(
					 PW_KEY_FACTORY_USAGE, FACTORY_USAGE,
					 NULL),
				 sizeof(*data));
	if (factory == NULL)
		return -errno;

	data = pw_impl_factory_get_user_data(factory);
	data->this = factory;
	data->context = context;
	data->module = module;
	spa_list_init(&data->node_list);

	pw_log_debug("module %p: new", module);

	pw_impl_factory_set_implementation(factory,
				      &impl_factory,
				      data);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	pw_impl_module_add_listener(module, &data->module_listener, &module_events, data);

	return 0;
}
