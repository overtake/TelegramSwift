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

#include "client-session.h"
#include "session.h"
#include "endpoint-link.h"

#define NAME "client-session"

struct factory_data {
	struct pw_impl_factory *factory;
	struct pw_impl_module *module;
	struct spa_hook module_listener;
};

static struct endpoint_link *find_link(struct client_session *this, uint32_t id)
{
	struct endpoint_link *l;
	spa_list_for_each(l, &this->links, link) {
		if (l->id == id)
			return l;
	}
	return NULL;
}

static int client_session_update(void *object,
				uint32_t change_mask,
				uint32_t n_params,
				const struct spa_pod **params,
				const struct pw_session_info *info)
{
	struct client_session *this = object;
	struct session *session = &this->session;

	return session_update(session, change_mask, n_params, params, info);
}

static int client_session_link_update(void *object,
				uint32_t link_id,
				uint32_t change_mask,
				uint32_t n_params,
				const struct spa_pod **params,
				const struct pw_endpoint_link_info *info)
{
	struct client_session *this = object;
	struct session *session = &this->session;
	struct endpoint_link *link = find_link(this, link_id);
	struct pw_properties *props = NULL;

	if (!link) {
		struct pw_context *context = pw_global_get_context(session->global);
		const char *keys[] = {
			PW_KEY_FACTORY_ID,
			PW_KEY_CLIENT_ID,
			PW_KEY_SESSION_ID,
			PW_KEY_ENDPOINT_LINK_OUTPUT_ENDPOINT,
			PW_KEY_ENDPOINT_LINK_OUTPUT_STREAM,
			PW_KEY_ENDPOINT_LINK_INPUT_ENDPOINT,
			PW_KEY_ENDPOINT_LINK_INPUT_STREAM,
			NULL
		};

		link = calloc(1, sizeof(struct endpoint_link));
		if (!link)
			goto no_mem;

		props = pw_properties_new(NULL, NULL);
		if (!props)
			goto no_mem;
		pw_properties_update_keys(props, &session->props->dict, keys);
		if (info && info->props)
			pw_properties_update_keys(props, info->props, keys);

		if (endpoint_link_init(link, link_id, session->info.id,
					this, context, props) < 0)
			goto no_mem;

		spa_list_append(&this->links, &link->link);
	}
	else if (change_mask & PW_CLIENT_SESSION_LINK_UPDATE_DESTROYED) {
		endpoint_link_clear(link);
		spa_list_remove(&link->link);
		free(link);
		link = NULL;
	}

	return link ?
		endpoint_link_update(link, change_mask, n_params, params, info)
		: 0;

       no_mem:
	if (props)
		pw_properties_free(props);
	free(link);
	pw_log_error(NAME" %p: cannot update link: no memory", this);
	pw_resource_error(this->resource, -ENOMEM,
		"cannot update link: no memory");
	return -ENOMEM;
}

static struct pw_client_session_methods methods = {
	PW_VERSION_CLIENT_SESSION_METHODS,
	.update = client_session_update,
	.link_update = client_session_link_update,
};

static void client_session_destroy(void *data)
{
	struct client_session *this = data;
	struct endpoint_link *l;

	pw_log_debug(NAME" %p: destroy", this);

	spa_list_consume(l, &this->links, link) {
		endpoint_link_clear(l);
		spa_list_remove(&l->link);
		free(l);
	}
	session_clear(&this->session);
	spa_hook_remove(&this->resource_listener);

	free(this);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = client_session_destroy,
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
	struct client_session *this;
	struct pw_impl_client *owner = pw_resource_get_client(owner_resource);
	struct pw_context *context = pw_impl_client_get_context(owner);

	this = calloc(1, sizeof(struct client_session));
	if (this == NULL)
		goto no_mem;

	spa_list_init(&this->links);

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

	if (session_init(&this->session, this, context, properties) < 0)
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
	pw_log_error("can't create client session: no memory");
	pw_resource_error(owner_resource, -ENOMEM,
			"can't create client session: no memory");
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

int client_session_factory_init(struct pw_impl_module *module)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_impl_factory *factory;
	struct factory_data *data;

	factory = pw_context_create_factory(context,
				 "client-session",
				 PW_TYPE_INTERFACE_ClientSession,
				 PW_VERSION_CLIENT_SESSION,
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
