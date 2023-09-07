/* PipeWire
 *
 * Copyright © 2019 Collabora Ltd.
 *   @author George Kiagiadakis <george.kiagiadakis@collabora.com>
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

#include <stdbool.h>
#include <string.h>

#include <spa/utils/result.h>
#include <pipewire/impl.h>

#include <extensions/session-manager.h>

#include "client-endpoint.h"
#include "endpoint.h"
#include "endpoint-stream.h"

#define NAME "client-endpoint"

struct factory_data {
	struct pw_impl_factory *factory;
	struct pw_impl_module *module;
	struct spa_hook module_listener;
};

static struct endpoint_stream *find_stream(struct client_endpoint *this, uint32_t id)
{
	struct endpoint_stream *s;
	spa_list_for_each(s, &this->streams, link) {
		if (s->id == id)
			return s;
	}
	return NULL;
}

static int client_endpoint_update(void *object,
				uint32_t change_mask,
				uint32_t n_params,
				const struct spa_pod **params,
				const struct pw_endpoint_info *info)
{
	struct client_endpoint *this = object;
	struct endpoint *endpoint = &this->endpoint;

	return endpoint_update(endpoint, change_mask, n_params, params, info);
}

static int client_endpoint_stream_update(void *object,
				uint32_t stream_id,
				uint32_t change_mask,
				uint32_t n_params,
				const struct spa_pod **params,
				const struct pw_endpoint_stream_info *info)
{
	struct client_endpoint *this = object;
	struct endpoint *endpoint = &this->endpoint;
	struct endpoint_stream *stream = find_stream(this, stream_id);
	struct pw_properties *props = NULL;

	if (!stream) {
		struct pw_context *context = pw_global_get_context(endpoint->global);
		const char *keys[] = {
			PW_KEY_FACTORY_ID,
			PW_KEY_CLIENT_ID,
			PW_KEY_ENDPOINT_ID,
			PW_KEY_PRIORITY_SESSION,
			PW_KEY_ENDPOINT_MONITOR,
			PW_KEY_ENDPOINT_STREAM_NAME,
			PW_KEY_ENDPOINT_STREAM_DESCRIPTION,
			NULL
		};

		stream = calloc(1, sizeof(struct endpoint_stream));
		if (!stream)
			goto no_mem;

		props = pw_properties_new(NULL, NULL);
		if (!props)
			goto no_mem;

		pw_properties_update_keys(props, &endpoint->props->dict, keys);
		if (info && info->props)
			pw_properties_update_keys(props, info->props, keys);

		if (endpoint_stream_init(stream, stream_id, endpoint->info.id,
					this, context, props) < 0)
			goto no_mem;

		spa_list_append(&this->streams, &stream->link);
	}
	else if (change_mask & PW_CLIENT_ENDPOINT_STREAM_UPDATE_DESTROYED) {
		endpoint_stream_clear(stream);
		spa_list_remove(&stream->link);
		free(stream);
		stream = NULL;
	}

	return stream ?
		endpoint_stream_update(stream, change_mask, n_params, params, info)
		: 0;

       no_mem:
	if (props)
		pw_properties_free(props);
	free(stream);
	pw_log_error(NAME" %p: cannot update stream: no memory", this);
	pw_resource_errorf(this->resource, -ENOMEM,
		NAME" %p: cannot update stream: no memory", this);
	return -ENOMEM;
}

static struct pw_client_endpoint_methods methods = {
	PW_VERSION_CLIENT_ENDPOINT_METHODS,
	.update = client_endpoint_update,
	.stream_update = client_endpoint_stream_update,
};

static void client_endpoint_destroy(void *data)
{
	struct client_endpoint *this = data;
	struct endpoint_stream *s;

	pw_log_debug(NAME" %p: destroy", this);

	spa_list_consume(s, &this->streams, link) {
		endpoint_stream_clear(s);
		spa_list_remove(&s->link);
		free(s);
	}
	endpoint_clear(&this->endpoint);
	spa_hook_remove(&this->resource_listener);

	free(this);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = client_endpoint_destroy,
};

static void *create_object(void *data,
			   struct pw_resource *owner_resource,
			   const char *type,
			   uint32_t version,
			   struct pw_properties *properties,
			   uint32_t new_id)
{
	struct factory_data *d = data;
	struct pw_impl_factory *factory = d->factory;
	struct client_endpoint *this;
	struct pw_impl_client *owner = pw_resource_get_client(owner_resource);
	struct pw_context *context = pw_impl_client_get_context(owner);

	this = calloc(1, sizeof(struct client_endpoint));
	if (this == NULL)
		goto no_mem;

	spa_list_init(&this->streams);

	pw_log_debug(NAME" %p: new", this);

	if (!properties)
		properties = pw_properties_new(NULL, NULL);
	if (!properties)
		goto no_mem;

	pw_properties_setf(properties, PW_KEY_CLIENT_ID, "%d",
			pw_impl_client_get_info(owner)->id);
	pw_properties_setf(properties, PW_KEY_FACTORY_ID, "%d",
			pw_impl_factory_get_info(factory)->id);

	this->resource = pw_resource_new(owner, new_id, PW_PERM_ALL, type, version, 0);
	if (this->resource == NULL)
		goto no_mem;

	if (endpoint_init(&this->endpoint, this, context, properties) < 0)
		goto no_mem;

	pw_resource_add_listener(this->resource, &this->resource_listener,
				 &resource_events, this);
	pw_resource_add_object_listener(this->resource, &this->object_listener,
					&methods, this);

	return this;

      no_mem:
	if (properties)
		pw_properties_free(properties);
	if (this && this->resource)
		pw_resource_destroy(this->resource);
	free(this);
	pw_log_error("can't create client endpoint: no memory");
	pw_resource_error(owner_resource, -ENOMEM,
			"can't create client endpoint: no memory");
	return NULL;
}

static const struct pw_impl_factory_implementation impl_factory = {
	PW_VERSION_IMPL_FACTORY_IMPLEMENTATION,
	.create_object = create_object,
};

static void module_destroy(void *data)
{
	struct factory_data *d = data;

	spa_hook_remove(&d->module_listener);
	pw_impl_factory_destroy(d->factory);
}

static void module_registered(void *data)
{
	struct factory_data *d = data;
	struct pw_impl_module *module = d->module;
	struct pw_impl_factory *factory = d->factory;
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

int client_endpoint_factory_init(struct pw_impl_module *module)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_impl_factory *factory;
	struct factory_data *data;

	factory = pw_context_create_factory(context,
				 "client-endpoint",
				 PW_TYPE_INTERFACE_ClientEndpoint,
				 PW_VERSION_CLIENT_ENDPOINT,
				 NULL,
				 sizeof(*data));
	if (factory == NULL)
		return -ENOMEM;

	data = pw_impl_factory_get_user_data(factory);
	data->factory = factory;
	data->module = module;

	pw_impl_factory_set_implementation(factory, &impl_factory, data);

	pw_impl_module_add_listener(module, &data->module_listener, &module_events, data);

	return 0;
}
