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

#include <spa/utils/result.h>

#include "config.h"

#include "pipewire/impl.h"

#include "spa-node.h"

#define NAME "spa-node-factory"

#define FACTORY_USAGE	SPA_KEY_FACTORY_NAME"=<factory-name> " \
			"["SPA_KEY_LIBRARY_NAME"=<library-name>]"

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Provide a factory to make SPA nodes" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct factory_data {
	struct pw_context *context;
	struct pw_impl_factory *this;
	struct pw_impl_module *module;

	struct spa_hook factory_listener;
	struct spa_hook module_listener;

	struct spa_list node_list;
};

struct node_data {
	struct factory_data *data;
	struct spa_list link;
	struct pw_impl_node *node;
	struct spa_hook node_listener;
	struct spa_hook resource_listener;
	unsigned int linger:1;
};

static void resource_destroy(void *data)
{
	struct node_data *nd = data;
	pw_log_debug("node %p", nd);
	spa_hook_remove(&nd->resource_listener);
	if (nd->node && !nd->linger)
		pw_impl_node_destroy(nd->node);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = resource_destroy
};

static void node_destroy(void *data)
{
	struct node_data *nd = data;
	pw_log_debug("node %p", nd);
	spa_list_remove(&nd->link);
	spa_hook_remove(&nd->node_listener);
	nd->node = NULL;
}

static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.destroy = node_destroy,
};

static void *create_object(void *_data,
			   struct pw_resource *resource,
			   const char *type,
			   uint32_t version,
			   struct pw_properties *properties,
			   uint32_t new_id)
{
	struct factory_data *data = _data;
	struct pw_context *context = data->context;
	struct pw_impl_node *node;
	const char *factory_name, *str;
	struct node_data *nd;
	int res;
	struct pw_impl_client *client;
	bool linger;

	if (properties == NULL)
		goto error_properties;

	factory_name = pw_properties_get(properties, SPA_KEY_FACTORY_NAME);
	if (factory_name == NULL)
		goto error_properties;

	pw_properties_setf(properties, PW_KEY_FACTORY_ID, "%d",
			pw_global_get_id(pw_impl_factory_get_global(data->this)));

	str = pw_properties_get(properties, PW_KEY_OBJECT_LINGER);
	linger = str ? pw_properties_parse_bool(str) : false;

	client = resource ? pw_resource_get_client(resource) : NULL;
	if (client && !linger) {
		pw_properties_setf(properties, PW_KEY_CLIENT_ID, "%d",
			pw_global_get_id(pw_impl_client_get_global(client)));
	}
	node = pw_spa_node_load(context,
				factory_name,
				PW_SPA_NODE_FLAG_ACTIVATE,
				properties,
				sizeof(struct node_data));
	if (node == NULL)
		goto error_create_node;

	nd = pw_spa_node_get_user_data(node);
	nd->data = data;
	nd->node = node;
	nd->linger = linger;
	spa_list_append(&data->node_list, &nd->link);

	pw_impl_node_add_listener(node, &nd->node_listener, &node_events, nd);

	if (client) {
		struct pw_resource *bound_resource;

		res = pw_global_bind(pw_impl_node_get_global(node),
			       client, PW_PERM_ALL, version, new_id);
		if (res < 0)
			goto error_bind;

		if ((bound_resource = pw_impl_client_find_resource(client, new_id)) == NULL)
			goto error_bind;

		pw_resource_add_listener(bound_resource, &nd->resource_listener, &resource_events, nd);
	}
	return node;

error_properties:
	res = -EINVAL;
	pw_log_error("factory %p: usage: " FACTORY_USAGE, data->this);
	if (resource)
		pw_resource_errorf_id(resource, new_id, res,
				"usage: "FACTORY_USAGE);
	goto error_exit_cleanup;
error_create_node:
	res = -errno;
	pw_log_error("can't create node: %m");
	if (resource)
		pw_resource_errorf_id(resource, new_id, res,
				"can't create node: %s", spa_strerror(res));
	goto error_exit;
error_bind:
	pw_resource_errorf_id(resource, new_id, res, "can't bind node");
	pw_impl_node_destroy(node);
	goto error_exit;

error_exit_cleanup:
	if (properties)
		pw_properties_free(properties);
error_exit:
	errno = -res;
	return NULL;
}

static const struct pw_impl_factory_implementation factory_impl = {
	PW_VERSION_IMPL_FACTORY_IMPLEMENTATION,
	.create_object = create_object,
};

static void factory_destroy(void *_data)
{
	struct factory_data *data = _data;
	struct node_data *nd;

	spa_hook_remove(&data->factory_listener);
	spa_list_consume(nd, &data->node_list, link)
		pw_impl_node_destroy(nd->node);
	data->this = NULL;
}

static const struct pw_impl_factory_events factory_events = {
	PW_VERSION_IMPL_FACTORY_EVENTS,
	.destroy = factory_destroy,
};

static void module_destroy(void *_data)
{
	struct factory_data *data = _data;
	spa_hook_remove(&data->module_listener);
	if (data->this)
		pw_impl_factory_destroy(data->this);
}

static void module_registered(void *data)
{
	struct factory_data *d = data;
	struct pw_impl_module *module = d->module;
	struct pw_impl_factory *factory = d->this;
	struct spa_dict_item items[1];
	char id[16];
	int res;

	snprintf(id, sizeof(id), "%d", pw_global_get_id(pw_impl_module_get_global(module)));
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
				 "spa-node-factory",
				 PW_TYPE_INTERFACE_Node,
				 PW_VERSION_NODE,
				 NULL,
				 sizeof(*data));
	if (factory == NULL)
		return -errno;

	data = pw_impl_factory_get_user_data(factory);
	data->this = factory;
	data->context = context;
	data->module = module;
	spa_list_init(&data->node_list);

	pw_impl_factory_add_listener(factory, &data->factory_listener, &factory_events, data);
	pw_impl_factory_set_implementation(factory, &factory_impl, data);

	pw_log_debug("module %p: new", module);
	pw_impl_module_add_listener(module, &data->module_listener, &module_events, data);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	return 0;
}
