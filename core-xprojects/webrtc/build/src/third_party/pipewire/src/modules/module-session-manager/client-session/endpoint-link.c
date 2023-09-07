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

#include <pipewire/impl.h>
#include <extensions/session-manager.h>

#include <spa/pod/filter.h>

#include "endpoint-link.h"
#include "client-session.h"

#define NAME "endpoint-link"

struct resource_data {
	struct endpoint_link *link;
	struct spa_hook object_listener;
	uint32_t n_subscribe_ids;
	uint32_t subscribe_ids[32];
};

#define pw_endpoint_link_resource(r,m,v,...)	\
	pw_resource_call(r,struct pw_endpoint_link_events,m,v,__VA_ARGS__)
#define pw_endpoint_link_resource_info(r,...)	\
	pw_endpoint_link_resource(r,info,0,__VA_ARGS__)
#define pw_endpoint_link_resource_param(r,...)	\
	pw_endpoint_link_resource(r,param,0,__VA_ARGS__)

static int endpoint_link_enum_params (void *object, int seq,
				uint32_t id, uint32_t start, uint32_t num,
				const struct spa_pod *filter)
{
	struct pw_resource *resource = object;
	struct resource_data *data = pw_resource_get_user_data(resource);
	struct endpoint_link *this = data->link;
	struct spa_pod *result;
	struct spa_pod *param;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	uint32_t index;
	uint32_t next = start;
	uint32_t count = 0;

	while (true) {
		index = next++;
		if (index >= this->n_params)
			break;

		param = this->params[index];

		if (param == NULL || !spa_pod_is_object_id(param, id))
			continue;

		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		if (spa_pod_filter(&b, &result, param, filter) != 0)
			continue;

		pw_log_debug(NAME" %p: %d param %u", this, seq, index);

		pw_endpoint_link_resource_param(resource, seq, id, index, next, result);

		if (++count == num)
			break;
	}
	return 0;
}

static int endpoint_link_subscribe_params (void *object, uint32_t *ids, uint32_t n_ids)
{
	struct pw_resource *resource = object;
	struct resource_data *data = pw_resource_get_user_data(resource);
	uint32_t i;

	n_ids = SPA_MIN(n_ids, SPA_N_ELEMENTS(data->subscribe_ids));
	data->n_subscribe_ids = n_ids;

	for (i = 0; i < n_ids; i++) {
		data->subscribe_ids[i] = ids[i];
		pw_log_debug(NAME" %p: resource %d subscribe param %u",
			data->link, pw_resource_get_id(resource), ids[i]);
		endpoint_link_enum_params(resource, 1, ids[i], 0, UINT32_MAX, NULL);
	}
	return 0;
}

static int endpoint_link_set_param (void *object, uint32_t id, uint32_t flags,
				const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct resource_data *data = pw_resource_get_user_data(resource);
	struct endpoint_link *this = data->link;

	pw_client_session_resource_set_param(this->client_sess->resource,
						id, flags, param);

	return 0;
}

static int endpoint_link_request_state(void *object, enum pw_endpoint_link_state state)
{
	struct pw_resource *resource = object;
	struct resource_data *data = pw_resource_get_user_data(resource);
	struct endpoint_link *this = data->link;

	pw_client_session_resource_link_request_state(this->client_sess->resource,
						      this->id, state);

	return 0;
}

static const struct pw_endpoint_link_methods methods = {
	PW_VERSION_ENDPOINT_LINK_METHODS,
	.subscribe_params = endpoint_link_subscribe_params,
	.enum_params = endpoint_link_enum_params,
	.set_param = endpoint_link_set_param,
	.request_state = endpoint_link_request_state,
};

struct emit_param_data {
	struct endpoint_link *this;
	struct spa_pod *param;
	uint32_t id;
	uint32_t index;
	uint32_t next;
};

static int emit_param(void *_data, struct pw_resource *resource)
{
	struct emit_param_data *d = _data;
	struct resource_data *data;
	uint32_t i;

	data = pw_resource_get_user_data(resource);
	for (i = 0; i < data->n_subscribe_ids; i++) {
		if (data->subscribe_ids[i] == d->id) {
			pw_endpoint_link_resource_param(resource, 1,
				d->id, d->index, d->next, d->param);
		}
	}
	return 0;
}

static void endpoint_link_notify_subscribed(struct endpoint_link *this,
					uint32_t index, uint32_t next)
{
	struct pw_global *global = this->global;
	struct emit_param_data data;
	struct spa_pod *param = this->params[index];

	if (!param || !spa_pod_is_object (param))
		return;

	data.this = this;
	data.param = param;
	data.id = SPA_POD_OBJECT_ID (param);
	data.index = index;
	data.next = next;

	pw_global_for_each_resource(global, emit_param, &data);
}

static int emit_info(void *data, struct pw_resource *resource)
{
	struct endpoint_link *this = data;
	pw_endpoint_link_resource_info(resource, &this->info);
	return 0;
}

int endpoint_link_update(struct endpoint_link *this,
			uint32_t change_mask,
			uint32_t n_params,
			const struct spa_pod **params,
			const struct pw_endpoint_link_info *info)
{
	if (change_mask & PW_CLIENT_SESSION_UPDATE_PARAMS) {
		uint32_t i;
		size_t size = n_params * sizeof(struct spa_pod *);

		pw_log_debug(NAME" %p: update %d params", this, n_params);

		for (i = 0; i < this->n_params; i++)
			free(this->params[i]);
		this->params = realloc(this->params, size);
		if (size > 0 && !this->params) {
			this->n_params = 0;
			goto no_mem;
		}
		this->n_params = n_params;

		for (i = 0; i < this->n_params; i++) {
			this->params[i] = params[i] ? spa_pod_copy(params[i]) : NULL;
			endpoint_link_notify_subscribed(this, i, i+1);
		}
	}

	if (change_mask & PW_CLIENT_SESSION_UPDATE_INFO) {
		if (info->change_mask & PW_ENDPOINT_LINK_CHANGE_MASK_STATE) {
			this->info.state = info->state;
			free(this->info.error);
			this->info.error = info->error ? strdup(info->error) : NULL;
		}

		if (info->change_mask & PW_ENDPOINT_LINK_CHANGE_MASK_PROPS)
			pw_properties_update(this->props, info->props);

		if (info->change_mask & PW_ENDPOINT_LINK_CHANGE_MASK_PARAMS) {
			size_t size = info->n_params * sizeof(struct spa_param_info);

			this->info.params = realloc(this->info.params, size);
			if (size > 0 && !this->info.params) {
				this->info.n_params = 0;
				goto no_mem;
			}
			this->info.n_params = info->n_params;

			memcpy(this->info.params, info->params, size);
		}

		if (!this->info.output_endpoint_id) {
			this->info.output_endpoint_id = info->output_endpoint_id;
			this->info.output_stream_id = info->output_stream_id;
			this->info.input_endpoint_id = info->input_endpoint_id;
			this->info.input_stream_id = info->input_stream_id;
		}

		this->info.change_mask = info->change_mask;
		pw_global_for_each_resource(this->global, emit_info, this);
		this->info.change_mask = 0;
	}

	return 0;

      no_mem:
	pw_log_error(NAME" %p: can't update: no memory", this);
	pw_resource_error(this->client_sess->resource, -ENOMEM,
			"can't update: no memory");
	return -ENOMEM;
}

static int endpoint_link_bind(void *_data, struct pw_impl_client *client,
			uint32_t permissions, uint32_t version, uint32_t id)
{
	struct endpoint_link *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;
	struct resource_data *data;

	resource = pw_resource_new(client, id, permissions,
			pw_global_get_type(global), version, sizeof(*data));
	if (resource == NULL)
		goto no_mem;

	data = pw_resource_get_user_data(resource);
	data->link = this;
	pw_resource_add_object_listener(resource, &data->object_listener,
					&methods, resource);

	pw_log_debug(NAME" %p: bound to %d", this, pw_resource_get_id(resource));
	pw_global_add_resource(global, resource);

	this->info.change_mask = PW_ENDPOINT_LINK_CHANGE_MASK_ALL;
	pw_endpoint_link_resource_info(resource, &this->info);
	this->info.change_mask = 0;

	return 0;

      no_mem:
	pw_log_error(NAME" %p: can't create resource: no memory", this);
	pw_resource_error(this->client_sess->resource, -ENOMEM,
			"can't create resource: no memory");
	return -ENOMEM;
}

int endpoint_link_init(struct endpoint_link *this,
		uint32_t id, uint32_t session_id,
		struct client_session *client_sess,
		struct pw_context *context,
		struct pw_properties *properties)
{
	pw_log_debug(NAME" %p: new", this);

	this->client_sess = client_sess;
	this->id = id;
	this->props = properties;

	pw_properties_setf(properties, PW_KEY_SESSION_ID, "%u", session_id);

	properties = pw_properties_copy(properties);
	if (!properties)
		goto no_mem;

	this->global = pw_global_new(context,
			PW_TYPE_INTERFACE_EndpointLink,
			PW_VERSION_ENDPOINT_LINK,
			properties, endpoint_link_bind, this);
	if (!this->global)
		goto no_mem;

	pw_properties_setf(this->props, PW_KEY_OBJECT_ID, "%u",
			pw_global_get_id(this->global));

	this->info.version = PW_VERSION_ENDPOINT_LINK_INFO;
	this->info.id = pw_global_get_id(this->global);
	this->info.session_id = session_id;
	this->info.props = &this->props->dict;

	return pw_global_register(this->global);

      no_mem:
	pw_log_error(NAME" - can't create - out of memory");
	return -ENOMEM;
}

void endpoint_link_clear(struct endpoint_link *this)
{
	uint32_t i;

	pw_log_debug(NAME" %p: destroy", this);

	pw_global_destroy(this->global);

	for (i = 0; i < this->n_params; i++)
		free(this->params[i]);
	free(this->params);

	free(this->info.error);
	free(this->info.params);

	if (this->props)
		pw_properties_free(this->props);
}
