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

#include <pipewire/pipewire.h>

#include <spa/utils/result.h>
#include <spa/pod/builder.h>
#include <spa/pod/parser.h>

#include <extensions/session-manager.h>
#include <extensions/protocol-native.h>

static void push_dict(struct spa_pod_builder *b, const struct spa_dict *dict)
{
	struct spa_pod_frame f;
	uint32_t n_items;
	uint32_t i;

	n_items = dict ? dict->n_items : 0;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b, SPA_POD_Int(n_items), NULL);
	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
			SPA_POD_String(dict->items[i].key),
			SPA_POD_String(dict->items[i].value),
			NULL);
	}
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define parse_dict(p, f, dict) \
do { \
	uint32_t i; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, SPA_POD_Int(&(dict)->n_items), NULL) < 0) \
		return -EINVAL; \
	\
	if ((dict)->n_items > 0) { \
		(dict)->items = alloca((dict)->n_items * sizeof(struct spa_dict_item)); \
		for (i = 0; i < (dict)->n_items; i++) { \
			if (spa_pod_parser_get(p, \
					SPA_POD_String(&(dict)->items[i].key), \
					SPA_POD_String(&(dict)->items[i].value), \
					NULL) < 0) \
				return -EINVAL; \
		} \
	} \
	spa_pod_parser_pop(p, f); \
} while(0)

static void push_param_infos(struct spa_pod_builder *b, uint32_t n_params,
				const struct spa_param_info *params)
{
	struct spa_pod_frame f;
	uint32_t i;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b, SPA_POD_Int(n_params), NULL);
	for (i = 0; i < n_params; i++) {
		spa_pod_builder_add(b,
			SPA_POD_Id(params[i].id),
			SPA_POD_Int(params[i].flags),
			NULL);
	}
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define parse_param_infos(p, f, n_params_p, params_p) \
do { \
	uint32_t i; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, SPA_POD_Int(n_params_p), NULL) < 0) \
		return -EINVAL; \
	\
	if (*(n_params_p) > 0) { \
		*(params_p) = alloca(*(n_params_p) * sizeof(struct spa_param_info)); \
		for (i = 0; i < *(n_params_p); i++) { \
			if (spa_pod_parser_get(p, \
					SPA_POD_Id(&(*(params_p))[i].id), \
					SPA_POD_Int(&(*(params_p))[i].flags), \
					NULL) < 0) \
				return -EINVAL; \
		} \
	} \
	spa_pod_parser_pop(p, f); \
} while(0)

/***********************************************
 *             INFO STRUCTURES
 ***********************************************/

static void
marshal_pw_session_info(struct spa_pod_builder *b,
			 const struct pw_session_info *info)
{
	struct spa_pod_frame f;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(info->version),
		SPA_POD_Int(info->id),
		SPA_POD_Int(info->change_mask),
		NULL);
	push_dict(b, info->props);
	push_param_infos(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define demarshal_pw_session_info(p, f, info) \
do { \
	struct spa_pod_frame sub_f; \
	uint32_t version; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, \
			SPA_POD_Int(&version), \
			SPA_POD_Int(&(info)->id), \
			SPA_POD_Int(&(info)->change_mask), \
			NULL) < 0) \
		return -EINVAL; \
	\
	(info)->change_mask &= PW_SESSION_CHANGE_MASK_ALL; \
	\
	parse_dict(p, &sub_f, (info)->props); \
	parse_param_infos(p, &sub_f, &(info)->n_params, &(info)->params); \
	\
	spa_pod_parser_pop(p, f); \
} while(0)

static void
marshal_pw_endpoint_info(struct spa_pod_builder *b,
			 const struct pw_endpoint_info *info)
{
	struct spa_pod_frame f;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(info->version),
		SPA_POD_Int(info->id),
		SPA_POD_String(info->name),
		SPA_POD_String(info->media_class),
		SPA_POD_Int(info->direction),
		SPA_POD_Int(info->flags),
		SPA_POD_Int(info->change_mask),
		SPA_POD_Int(info->n_streams),
		SPA_POD_Int(info->session_id),
		NULL);
	push_dict(b, info->props);
	push_param_infos(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define demarshal_pw_endpoint_info(p, f, info) \
do { \
	struct spa_pod_frame sub_f; \
	uint32_t version; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, \
			SPA_POD_Int(&version), \
			SPA_POD_Int(&(info)->id), \
			SPA_POD_String(&(info)->name), \
			SPA_POD_String(&(info)->media_class), \
			SPA_POD_Int(&(info)->direction), \
			SPA_POD_Int(&(info)->flags), \
			SPA_POD_Int(&(info)->change_mask), \
			SPA_POD_Int(&(info)->n_streams), \
			SPA_POD_Int(&(info)->session_id), \
			NULL) < 0) \
		return -EINVAL; \
	\
	(info)->change_mask &= PW_ENDPOINT_CHANGE_MASK_ALL; \
	\
	parse_dict(p, &sub_f, (info)->props); \
	parse_param_infos(p, &sub_f, &(info)->n_params, &(info)->params); \
	\
	spa_pod_parser_pop(p, f); \
} while(0)

static void
marshal_pw_endpoint_stream_info(struct spa_pod_builder *b,
			 const struct pw_endpoint_stream_info *info)
{
	struct spa_pod_frame f;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(info->version),
		SPA_POD_Int(info->id),
		SPA_POD_Int(info->endpoint_id),
		SPA_POD_String(info->name),
		SPA_POD_Int(info->change_mask),
		SPA_POD_Pod(info->link_params),
		NULL);
	push_dict(b, info->props);
	push_param_infos(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define demarshal_pw_endpoint_stream_info(p, f, info) \
do { \
	struct spa_pod_frame sub_f; \
	uint32_t version; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, \
			SPA_POD_Int(&version), \
			SPA_POD_Int(&(info)->id), \
			SPA_POD_Int(&(info)->endpoint_id), \
			SPA_POD_String(&(info)->name), \
			SPA_POD_Int(&(info)->change_mask), \
			SPA_POD_Pod(&(info)->link_params), \
			NULL) < 0) \
		return -EINVAL; \
	\
	(info)->change_mask &= PW_ENDPOINT_STREAM_CHANGE_MASK_ALL; \
	\
	parse_dict(p, &sub_f, (info)->props); \
	parse_param_infos(p, &sub_f, &(info)->n_params, &(info)->params); \
	\
	spa_pod_parser_pop(p, f); \
} while(0)

static void
marshal_pw_endpoint_link_info(struct spa_pod_builder *b,
			 const struct pw_endpoint_link_info *info)
{
	struct spa_pod_frame f;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(info->version),
		SPA_POD_Int(info->id),
		SPA_POD_Int(info->session_id),
		SPA_POD_Int(info->output_endpoint_id),
		SPA_POD_Int(info->output_stream_id),
		SPA_POD_Int(info->input_endpoint_id),
		SPA_POD_Int(info->input_stream_id),
		SPA_POD_Int(info->change_mask),
		SPA_POD_Int(info->state),
		SPA_POD_String(info->error),
		NULL);
	push_dict(b, info->props);
	push_param_infos(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);
}

/* macro because of alloca() */
#define demarshal_pw_endpoint_link_info(p, f, info) \
do { \
	struct spa_pod_frame sub_f; \
	uint32_t version; \
	\
	if (spa_pod_parser_push_struct(p, f) < 0 || \
	    spa_pod_parser_get(p, \
			SPA_POD_Int(&version), \
			SPA_POD_Int(&(info)->id), \
			SPA_POD_Int(&(info)->session_id), \
			SPA_POD_Int(&(info)->output_endpoint_id), \
			SPA_POD_Int(&(info)->output_stream_id), \
			SPA_POD_Int(&(info)->input_endpoint_id), \
			SPA_POD_Int(&(info)->input_stream_id), \
			SPA_POD_Int(&(info)->change_mask), \
			SPA_POD_Int(&(info)->state), \
			SPA_POD_String(&(info)->error), \
			NULL) < 0) \
		return -EINVAL; \
	\
	(info)->change_mask &= PW_ENDPOINT_LINK_CHANGE_MASK_ALL; \
	\
	parse_dict(p, &sub_f, (info)->props); \
	parse_param_infos(p, &sub_f, &(info)->n_params, &(info)->params); \
	\
	spa_pod_parser_pop(p, f); \
} while(0)


/***********************************************
 *                 COMMON
 ***********************************************/

static int demarshal_add_listener_enotsup(void *object,
			const struct pw_protocol_native_message *msg)
{
	return -ENOTSUP;
}

/***********************************************
 *              CLIENT ENDPOINT
 ***********************************************/

static int client_endpoint_marshal_set_session_id (void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_ENDPOINT_EVENT_SET_SESSION_ID, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_endpoint_marshal_set_param (void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_ENDPOINT_EVENT_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Id(id),
				SPA_POD_Int(flags),
				SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_endpoint_marshal_stream_set_param (void *object,
				uint32_t stream_id, uint32_t id,
				uint32_t flags, const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_ENDPOINT_EVENT_STREAM_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(stream_id),
				SPA_POD_Id(id),
				SPA_POD_Int(flags),
				SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_endpoint_marshal_create_link (void *object,
				const struct spa_dict *props)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_ENDPOINT_EVENT_CREATE_LINK, NULL);

	push_dict(b, props);

	return pw_protocol_native_end_resource(resource, b);
}

static int client_endpoint_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_client_endpoint_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int client_endpoint_marshal_update(void *object,
					uint32_t change_mask,
					uint32_t n_params,
					const struct spa_pod **params,
					const struct pw_endpoint_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_CLIENT_ENDPOINT_METHOD_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(change_mask),
		SPA_POD_Int(n_params),
		NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b, SPA_POD_Pod(params[i]), NULL);

	if (info)
		marshal_pw_endpoint_info(b, info);
	else
		spa_pod_builder_add(b, SPA_POD_Pod(NULL), NULL);

	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_endpoint_marshal_stream_update(void *object,
					uint32_t stream_id,
					uint32_t change_mask,
					uint32_t n_params,
					const struct spa_pod **params,
					const struct pw_endpoint_stream_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_CLIENT_ENDPOINT_METHOD_STREAM_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(stream_id),
		SPA_POD_Int(change_mask),
		SPA_POD_Int(n_params),
		NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b, SPA_POD_Pod(params[i]), NULL);

	if (info)
		marshal_pw_endpoint_stream_info(b, info);
	else
		spa_pod_builder_add(b, SPA_POD_Pod(NULL), NULL);

	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_endpoint_demarshal_set_session_id(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_endpoint_events,
				set_session_id, 0, id);
}

static int client_endpoint_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	const struct spa_pod *param = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Id(&id),
			SPA_POD_Int(&flags),
			SPA_POD_PodObject(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_endpoint_events,
				set_param, 0, id, flags, param);
}

static int client_endpoint_demarshal_stream_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t stream_id, id, flags;
	const struct spa_pod *param = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&stream_id),
			SPA_POD_Id(&id),
			SPA_POD_Int(&flags),
			SPA_POD_PodObject(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_endpoint_events,
				stream_set_param, 0, stream_id, id, flags, param);
}

static int client_endpoint_demarshal_create_link(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);

	parse_dict(&prs, &f, &props);

	return pw_proxy_notify(proxy, struct pw_client_endpoint_events,
				create_link, 0, &props);
}

static int client_endpoint_demarshal_update(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs[2];
	struct spa_pod_frame f[2];
	uint32_t change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_info info = { .props = &props }, *infop = NULL;
	struct spa_pod *ipod;
	uint32_t i;

	spa_pod_parser_init(&prs[0], msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs[0], &f[0]) < 0 ||
	    spa_pod_parser_get(&prs[0],
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	if (n_params > 0)
		params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs[0],
				SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs[0], SPA_POD_PodStruct(&ipod), NULL) < 0)
		return -EINVAL;
	if (ipod) {
		infop = &info;
		spa_pod_parser_pod(&prs[1], ipod);
		demarshal_pw_endpoint_info(&prs[1], &f[1], infop);
	}

	return pw_resource_notify(resource, struct pw_client_endpoint_methods,
			update, 0, change_mask, n_params, params, infop);
}

static int client_endpoint_demarshal_stream_update(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs[2];
	struct spa_pod_frame f[2];
	uint32_t stream_id, change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_stream_info info = { .props = &props }, *infop = NULL;
	struct spa_pod *ipod;
	uint32_t i;

	spa_pod_parser_init(&prs[0], msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs[0], &f[0]) < 0 ||
	    spa_pod_parser_get(&prs[0],
			SPA_POD_Int(&stream_id),
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	if (n_params > 0)
		params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs[0],
				SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs[0], SPA_POD_PodStruct(&ipod), NULL) < 0)
		return -EINVAL;
	if (ipod) {
		infop = &info;
		spa_pod_parser_pod(&prs[1], ipod);
		demarshal_pw_endpoint_stream_info(&prs[1], &f[1], infop);
	}

	return pw_resource_notify(resource, struct pw_client_endpoint_methods,
			stream_update, 0, stream_id, change_mask, n_params, params, infop);
}

static const struct pw_client_endpoint_events pw_protocol_native_client_endpoint_event_marshal = {
	PW_VERSION_CLIENT_ENDPOINT_EVENTS,
	.set_session_id = client_endpoint_marshal_set_session_id,
	.set_param = client_endpoint_marshal_set_param,
	.stream_set_param = client_endpoint_marshal_stream_set_param,
	.create_link = client_endpoint_marshal_create_link,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_endpoint_event_demarshal[PW_CLIENT_ENDPOINT_EVENT_NUM] =
{
	[PW_CLIENT_ENDPOINT_EVENT_SET_SESSION_ID] = { client_endpoint_demarshal_set_session_id, 0 },
	[PW_CLIENT_ENDPOINT_EVENT_SET_PARAM] = { client_endpoint_demarshal_set_param, 0 },
	[PW_CLIENT_ENDPOINT_EVENT_STREAM_SET_PARAM] = { client_endpoint_demarshal_stream_set_param, 0 },
	[PW_CLIENT_ENDPOINT_EVENT_CREATE_LINK] = { client_endpoint_demarshal_create_link, 0 },
};

static const struct pw_client_endpoint_methods pw_protocol_native_client_endpoint_method_marshal = {
	PW_VERSION_CLIENT_ENDPOINT_METHODS,
	.add_listener = client_endpoint_marshal_add_listener,
	.update = client_endpoint_marshal_update,
	.stream_update = client_endpoint_marshal_stream_update,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_endpoint_method_demarshal[PW_CLIENT_ENDPOINT_METHOD_NUM] =
{
	[PW_CLIENT_ENDPOINT_METHOD_ADD_LISTENER] = { NULL, 0 },
	[PW_CLIENT_ENDPOINT_METHOD_UPDATE] = { client_endpoint_demarshal_update, 0 },
	[PW_CLIENT_ENDPOINT_METHOD_STREAM_UPDATE] = { client_endpoint_demarshal_stream_update, 0 },
};

static const struct pw_protocol_marshal pw_protocol_native_client_endpoint_marshal = {
	PW_TYPE_INTERFACE_ClientEndpoint,
	PW_VERSION_CLIENT_ENDPOINT,
	0,
	PW_CLIENT_ENDPOINT_METHOD_NUM,
	PW_CLIENT_ENDPOINT_EVENT_NUM,
	&pw_protocol_native_client_endpoint_method_marshal,
	&pw_protocol_native_client_endpoint_method_demarshal,
	&pw_protocol_native_client_endpoint_event_marshal,
	&pw_protocol_native_client_endpoint_event_demarshal,
};

/***********************************************
 *              CLIENT SESSION
 ***********************************************/

static int client_session_marshal_set_param (void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_SESSION_EVENT_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Id(id),
				SPA_POD_Int(flags),
				SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_session_marshal_link_set_param (void *object,
				uint32_t link_id, uint32_t id,
				uint32_t flags, const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_SESSION_EVENT_LINK_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(link_id),
				SPA_POD_Id(id),
				SPA_POD_Int(flags),
				SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_session_marshal_link_request_state (void *object,
				uint32_t link_id, uint32_t state)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_CLIENT_SESSION_EVENT_LINK_REQUEST_STATE, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(link_id),
				SPA_POD_Int(state));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_session_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_client_session_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int client_session_marshal_update(void *object,
					uint32_t change_mask,
					uint32_t n_params,
					const struct spa_pod **params,
					const struct pw_session_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_CLIENT_SESSION_METHOD_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(change_mask),
		SPA_POD_Int(n_params),
		NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b, SPA_POD_Pod(params[i]), NULL);

	if (info)
		marshal_pw_session_info(b, info);
	else
		spa_pod_builder_add(b, SPA_POD_Pod(NULL), NULL);

	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_session_marshal_link_update(void *object,
					uint32_t link_id,
					uint32_t change_mask,
					uint32_t n_params,
					const struct spa_pod **params,
					const struct pw_endpoint_link_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_CLIENT_SESSION_METHOD_LINK_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
		SPA_POD_Int(link_id),
		SPA_POD_Int(change_mask),
		SPA_POD_Int(n_params),
		NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b, SPA_POD_Pod(params[i]), NULL);

	if (info)
		marshal_pw_endpoint_link_info(b, info);
	else
		spa_pod_builder_add(b, SPA_POD_Pod(NULL), NULL);

	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_session_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	const struct spa_pod *param = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Id(&id),
			SPA_POD_Int(&flags),
			SPA_POD_PodObject(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_session_events,
				set_param, 0, id, flags, param);
}

static int client_session_demarshal_link_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t link_id, id, flags;
	const struct spa_pod *param = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&link_id),
			SPA_POD_Id(&id),
			SPA_POD_Int(&flags),
			SPA_POD_PodObject(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_session_events,
				link_set_param, 0, link_id, id, flags, param);
}

static int client_session_demarshal_link_request_state(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t link_id, state;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&link_id),
			SPA_POD_Int(&state)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_session_events,
				link_request_state, 0, link_id, state);
}

static int client_session_demarshal_update(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs[2];
	struct spa_pod_frame f[2];
	uint32_t change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_session_info info = { .props = &props }, *infop = NULL;
	struct spa_pod *ipod;
	uint32_t i;

	spa_pod_parser_init(&prs[0], msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs[0], &f[0]) < 0 ||
	    spa_pod_parser_get(&prs[0],
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	if (n_params > 0)
		params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs[0],
				SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs[0], SPA_POD_PodStruct(&ipod), NULL) < 0)
		return -EINVAL;
	if (ipod) {
		infop = &info;
		spa_pod_parser_pod(&prs[1], ipod);
		demarshal_pw_session_info(&prs[1], &f[1], infop);
	}

	return pw_resource_notify(resource, struct pw_client_session_methods,
			update, 0, change_mask, n_params, params, infop);
}

static int client_session_demarshal_link_update(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs[2];
	struct spa_pod_frame f[2];
	uint32_t link_id, change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_link_info info = { .props = &props }, *infop = NULL;
	struct spa_pod *ipod;
	uint32_t i;

	spa_pod_parser_init(&prs[0], msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs[0], &f[0]) < 0 ||
	    spa_pod_parser_get(&prs[0],
			SPA_POD_Int(&link_id),
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	if (n_params > 0)
		params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs[0],
				SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs[0], SPA_POD_PodStruct(&ipod), NULL) < 0)
		return -EINVAL;
	if (ipod) {
		infop = &info;
		spa_pod_parser_pod(&prs[1], ipod);
		demarshal_pw_endpoint_link_info(&prs[1], &f[1], infop);
	}

	return pw_resource_notify(resource, struct pw_client_session_methods,
			link_update, 0, link_id, change_mask, n_params, params, infop);
}

static const struct pw_client_session_events pw_protocol_native_client_session_event_marshal = {
	PW_VERSION_CLIENT_SESSION_EVENTS,
	.set_param = client_session_marshal_set_param,
	.link_set_param = client_session_marshal_link_set_param,
	.link_request_state = client_session_marshal_link_request_state,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_session_event_demarshal[PW_CLIENT_SESSION_EVENT_NUM] =
{
	[PW_CLIENT_SESSION_EVENT_SET_PARAM] = { client_session_demarshal_set_param, 0 },
	[PW_CLIENT_SESSION_EVENT_LINK_SET_PARAM] = { client_session_demarshal_link_set_param, 0 },
	[PW_CLIENT_SESSION_EVENT_LINK_REQUEST_STATE] = { client_session_demarshal_link_request_state, 0 },
};

static const struct pw_client_session_methods pw_protocol_native_client_session_method_marshal = {
	PW_VERSION_CLIENT_SESSION_METHODS,
	.add_listener = client_session_marshal_add_listener,
	.update = client_session_marshal_update,
	.link_update = client_session_marshal_link_update,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_session_method_demarshal[PW_CLIENT_SESSION_METHOD_NUM] =
{
	[PW_CLIENT_SESSION_METHOD_ADD_LISTENER] = { NULL, 0 },
	[PW_CLIENT_SESSION_METHOD_UPDATE] = { client_session_demarshal_update, 0 },
	[PW_CLIENT_SESSION_METHOD_LINK_UPDATE] = { client_session_demarshal_link_update, 0 },
};

static const struct pw_protocol_marshal pw_protocol_native_client_session_marshal = {
	PW_TYPE_INTERFACE_ClientSession,
	PW_VERSION_CLIENT_SESSION,
	0,
	PW_CLIENT_SESSION_METHOD_NUM,
	PW_CLIENT_SESSION_EVENT_NUM,
	&pw_protocol_native_client_session_method_marshal,
	&pw_protocol_native_client_session_method_demarshal,
	&pw_protocol_native_client_session_event_marshal,
	&pw_protocol_native_client_session_event_demarshal,
};

/***********************************************
 *               ENDPOINT LINK
 ***********************************************/

static void endpoint_link_proxy_marshal_info (void *object,
				const struct pw_endpoint_link_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_EVENT_INFO, NULL);

	marshal_pw_endpoint_link_info(b, info);

	pw_protocol_native_end_proxy(proxy, b);
}

static void endpoint_link_resource_marshal_info (void *object,
				const struct pw_endpoint_link_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_EVENT_INFO, NULL);

	marshal_pw_endpoint_link_info(b, info);

	pw_protocol_native_end_resource(resource, b);
}

static void endpoint_link_proxy_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_proxy(proxy, b);
}
static void endpoint_link_resource_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int endpoint_link_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_link_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int endpoint_link_resource_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_link_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	pw_resource_add_object_listener(resource, listener, events, data);
	return 0;
}

static int endpoint_link_proxy_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_link_resource_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_link_proxy_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_link_resource_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_link_proxy_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_link_resource_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_link_proxy_marshal_request_state(void *object,
					enum pw_endpoint_link_state state)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_LINK_METHOD_REQUEST_STATE, NULL);

	spa_pod_builder_add_struct(b, SPA_POD_Int(state));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_link_resource_marshal_request_state(void *object,
					enum pw_endpoint_link_state state)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_LINK_METHOD_REQUEST_STATE, NULL);

	spa_pod_builder_add_struct(b, SPA_POD_Int(state));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_link_proxy_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_link_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_link_info(&prs, &f, &info);

	return pw_proxy_notify(proxy, struct pw_endpoint_link_events,
				info, 0, &info);
}

static int endpoint_link_resource_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_link_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_link_info(&prs, &f, &info);

	return pw_resource_notify(resource, struct pw_endpoint_link_events,
				info, 0, &info);
}

static int endpoint_link_proxy_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_link_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_link_resource_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_link_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_link_proxy_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_link_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_link_resource_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_link_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_link_proxy_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_link_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_link_resource_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_link_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_link_proxy_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_link_methods,
				set_param, 0, id, flags, param);
}

static int endpoint_link_resource_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_link_methods,
				set_param, 0, id, flags, param);
}

static int endpoint_link_proxy_demarshal_request_state(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	enum pw_endpoint_link_state state;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&state)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_link_methods,
				request_state, 0, state);
}

static int endpoint_link_resource_demarshal_request_state(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	enum pw_endpoint_link_state state;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&state)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_link_methods,
				request_state, 0, state);
}

static const struct pw_endpoint_link_events pw_protocol_native_endpoint_link_client_event_marshal = {
	PW_VERSION_ENDPOINT_LINK_EVENTS,
	.info = endpoint_link_proxy_marshal_info,
	.param = endpoint_link_proxy_marshal_param,
};

static const struct pw_endpoint_link_events pw_protocol_native_endpoint_link_server_event_marshal = {
	PW_VERSION_ENDPOINT_LINK_EVENTS,
	.info = endpoint_link_resource_marshal_info,
	.param = endpoint_link_resource_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_link_client_event_demarshal[PW_ENDPOINT_LINK_EVENT_NUM] =
{
	[PW_ENDPOINT_LINK_EVENT_INFO] = { endpoint_link_proxy_demarshal_info, 0 },
	[PW_ENDPOINT_LINK_EVENT_PARAM] = { endpoint_link_proxy_demarshal_param, 0 },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_link_server_event_demarshal[PW_ENDPOINT_LINK_EVENT_NUM] =
{
	[PW_ENDPOINT_LINK_EVENT_INFO] = { endpoint_link_resource_demarshal_info, 0 },
	[PW_ENDPOINT_LINK_EVENT_PARAM] = { endpoint_link_resource_demarshal_param, 0 },
};

static const struct pw_endpoint_link_methods pw_protocol_native_endpoint_link_client_method_marshal = {
	PW_VERSION_ENDPOINT_LINK_METHODS,
	.add_listener = endpoint_link_proxy_marshal_add_listener,
	.subscribe_params = endpoint_link_proxy_marshal_subscribe_params,
	.enum_params = endpoint_link_proxy_marshal_enum_params,
	.set_param = endpoint_link_proxy_marshal_set_param,
	.request_state = endpoint_link_proxy_marshal_request_state,
};

static const struct pw_endpoint_link_methods pw_protocol_native_endpoint_link_server_method_marshal = {
	PW_VERSION_ENDPOINT_LINK_METHODS,
	.add_listener = endpoint_link_resource_marshal_add_listener,
	.subscribe_params = endpoint_link_resource_marshal_subscribe_params,
	.enum_params = endpoint_link_resource_marshal_enum_params,
	.set_param = endpoint_link_resource_marshal_set_param,
	.request_state = endpoint_link_resource_marshal_request_state,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_link_client_method_demarshal[PW_ENDPOINT_LINK_METHOD_NUM] =
{
	[PW_ENDPOINT_LINK_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_LINK_METHOD_SUBSCRIBE_PARAMS] = { endpoint_link_proxy_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_LINK_METHOD_ENUM_PARAMS] = { endpoint_link_proxy_demarshal_enum_params, 0 },
	[PW_ENDPOINT_LINK_METHOD_SET_PARAM] = { endpoint_link_proxy_demarshal_set_param, PW_PERM_W },
	[PW_ENDPOINT_LINK_METHOD_REQUEST_STATE] = { endpoint_link_proxy_demarshal_request_state, PW_PERM_W },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_link_server_method_demarshal[PW_ENDPOINT_LINK_METHOD_NUM] =
{
	[PW_ENDPOINT_LINK_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_LINK_METHOD_SUBSCRIBE_PARAMS] = { endpoint_link_resource_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_LINK_METHOD_ENUM_PARAMS] = { endpoint_link_resource_demarshal_enum_params, 0 },
	[PW_ENDPOINT_LINK_METHOD_SET_PARAM] = { endpoint_link_resource_demarshal_set_param, PW_PERM_W },
	[PW_ENDPOINT_LINK_METHOD_REQUEST_STATE] = { endpoint_link_resource_demarshal_request_state, PW_PERM_W },
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_link_marshal = {
	PW_TYPE_INTERFACE_EndpointLink,
	PW_VERSION_ENDPOINT_LINK,
	0,
	PW_ENDPOINT_LINK_METHOD_NUM,
	PW_ENDPOINT_LINK_EVENT_NUM,
	.client_marshal = &pw_protocol_native_endpoint_link_client_method_marshal,
	.server_demarshal = pw_protocol_native_endpoint_link_server_method_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_link_server_event_marshal,
	.client_demarshal = pw_protocol_native_endpoint_link_client_event_demarshal,
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_link_impl_marshal = {
	PW_TYPE_INTERFACE_EndpointLink,
	PW_VERSION_ENDPOINT_LINK,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	PW_ENDPOINT_LINK_EVENT_NUM,
	PW_ENDPOINT_LINK_METHOD_NUM,
	.client_marshal = &pw_protocol_native_endpoint_link_client_event_marshal,
	.server_demarshal = pw_protocol_native_endpoint_link_server_event_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_link_server_method_marshal,
	.client_demarshal = pw_protocol_native_endpoint_link_client_method_demarshal,
};

/***********************************************
 *               ENDPOINT STREAM
 ***********************************************/

static void endpoint_stream_proxy_marshal_info (void *object,
				const struct pw_endpoint_stream_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_STREAM_EVENT_INFO, NULL);

	marshal_pw_endpoint_stream_info(b, info);

	pw_protocol_native_end_proxy(proxy, b);
}

static void endpoint_stream_resource_marshal_info (void *object,
				const struct pw_endpoint_stream_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_STREAM_EVENT_INFO, NULL);

	marshal_pw_endpoint_stream_info(b, info);

	pw_protocol_native_end_resource(resource, b);
}

static void endpoint_stream_proxy_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_STREAM_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_proxy(proxy, b);
}

static void endpoint_stream_resource_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_STREAM_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int endpoint_stream_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_stream_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int endpoint_stream_resource_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_stream_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	pw_resource_add_object_listener(resource, listener, events, data);
	return 0;
}

static int endpoint_stream_proxy_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_STREAM_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_stream_resource_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_STREAM_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_stream_proxy_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_STREAM_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_stream_resource_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_STREAM_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_stream_proxy_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_STREAM_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_stream_resource_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_STREAM_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_stream_proxy_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_stream_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_stream_info(&prs, &f, &info);

	return pw_proxy_notify(proxy, struct pw_endpoint_stream_events,
				info, 0, &info);
}

static int endpoint_stream_resource_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_stream_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_stream_info(&prs, &f, &info);

	return pw_resource_notify(resource, struct pw_endpoint_stream_events,
				info, 0, &info);
}

static int endpoint_stream_proxy_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_stream_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_stream_resource_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_stream_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_stream_proxy_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_stream_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_stream_resource_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_stream_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_stream_proxy_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_stream_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_stream_resource_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_stream_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_stream_proxy_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_stream_methods,
				set_param, 0, id, flags, param);
}

static int endpoint_stream_resource_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_stream_methods,
				set_param, 0, id, flags, param);
}

static const struct pw_endpoint_stream_events pw_protocol_native_endpoint_stream_client_event_marshal = {
	PW_VERSION_ENDPOINT_STREAM_EVENTS,
	.info = endpoint_stream_proxy_marshal_info,
	.param = endpoint_stream_proxy_marshal_param,
};

static const struct pw_endpoint_stream_events pw_protocol_native_endpoint_stream_server_event_marshal = {
	PW_VERSION_ENDPOINT_STREAM_EVENTS,
	.info = endpoint_stream_resource_marshal_info,
	.param = endpoint_stream_resource_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_stream_client_event_demarshal[PW_ENDPOINT_STREAM_EVENT_NUM] =
{
	[PW_ENDPOINT_STREAM_EVENT_INFO] = { endpoint_stream_proxy_demarshal_info, 0 },
	[PW_ENDPOINT_STREAM_EVENT_PARAM] = { endpoint_stream_proxy_demarshal_param, 0 },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_stream_server_event_demarshal[PW_ENDPOINT_STREAM_EVENT_NUM] =
{
	[PW_ENDPOINT_STREAM_EVENT_INFO] = { endpoint_stream_resource_demarshal_info, 0 },
	[PW_ENDPOINT_STREAM_EVENT_PARAM] = { endpoint_stream_resource_demarshal_param, 0 },
};

static const struct pw_endpoint_stream_methods pw_protocol_native_endpoint_stream_client_method_marshal = {
	PW_VERSION_ENDPOINT_STREAM_METHODS,
	.add_listener = endpoint_stream_proxy_marshal_add_listener,
	.subscribe_params = endpoint_stream_proxy_marshal_subscribe_params,
	.enum_params = endpoint_stream_proxy_marshal_enum_params,
	.set_param = endpoint_stream_proxy_marshal_set_param,
};

static const struct pw_endpoint_stream_methods pw_protocol_native_endpoint_stream_server_method_marshal = {
	PW_VERSION_ENDPOINT_STREAM_METHODS,
	.add_listener = endpoint_stream_resource_marshal_add_listener,
	.subscribe_params = endpoint_stream_resource_marshal_subscribe_params,
	.enum_params = endpoint_stream_resource_marshal_enum_params,
	.set_param = endpoint_stream_resource_marshal_set_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_stream_client_method_demarshal[PW_ENDPOINT_STREAM_METHOD_NUM] =
{
	[PW_ENDPOINT_STREAM_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_STREAM_METHOD_SUBSCRIBE_PARAMS] = { endpoint_stream_proxy_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_STREAM_METHOD_ENUM_PARAMS] = { endpoint_stream_proxy_demarshal_enum_params, 0 },
	[PW_ENDPOINT_STREAM_METHOD_SET_PARAM] = { endpoint_stream_proxy_demarshal_set_param, PW_PERM_W },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_stream_server_method_demarshal[PW_ENDPOINT_STREAM_METHOD_NUM] =
{
	[PW_ENDPOINT_STREAM_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_STREAM_METHOD_SUBSCRIBE_PARAMS] = { endpoint_stream_resource_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_STREAM_METHOD_ENUM_PARAMS] = { endpoint_stream_resource_demarshal_enum_params, 0 },
	[PW_ENDPOINT_STREAM_METHOD_SET_PARAM] = { endpoint_stream_resource_demarshal_set_param, PW_PERM_W },
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_stream_marshal = {
	PW_TYPE_INTERFACE_EndpointStream,
	PW_VERSION_ENDPOINT_STREAM,
	0,
	PW_ENDPOINT_STREAM_METHOD_NUM,
	PW_ENDPOINT_STREAM_EVENT_NUM,
	.client_marshal = &pw_protocol_native_endpoint_stream_client_method_marshal,
	.server_demarshal = pw_protocol_native_endpoint_stream_server_method_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_stream_server_event_marshal,
	.client_demarshal = pw_protocol_native_endpoint_stream_client_event_demarshal,
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_stream_impl_marshal = {
	PW_TYPE_INTERFACE_EndpointStream,
	PW_VERSION_ENDPOINT_STREAM,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	PW_ENDPOINT_STREAM_EVENT_NUM,
	PW_ENDPOINT_STREAM_METHOD_NUM,
	.client_marshal = &pw_protocol_native_endpoint_stream_client_event_marshal,
	.server_demarshal = pw_protocol_native_endpoint_stream_server_event_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_stream_server_method_marshal,
	.client_demarshal = pw_protocol_native_endpoint_stream_client_method_demarshal,
};

/***********************************************
 *                  ENDPOINT
 ***********************************************/

static void endpoint_proxy_marshal_info (void *object,
				const struct pw_endpoint_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_EVENT_INFO, NULL);

	marshal_pw_endpoint_info(b, info);

	pw_protocol_native_end_proxy(proxy, b);
}

static void endpoint_resource_marshal_info (void *object,
				const struct pw_endpoint_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_EVENT_INFO, NULL);

	marshal_pw_endpoint_info(b, info);

	pw_protocol_native_end_resource(resource, b);
}

static void endpoint_proxy_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_proxy(proxy, b);
}

static void endpoint_resource_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int endpoint_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int endpoint_resource_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_endpoint_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	pw_resource_add_object_listener(resource, listener, events, data);
	return 0;
}

static int endpoint_proxy_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_resource_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_proxy_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_resource_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_proxy_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_resource_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_proxy_marshal_create_link(void *object,
					const struct spa_dict *props)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_ENDPOINT_METHOD_CREATE_LINK, NULL);

	push_dict(b, props);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int endpoint_resource_marshal_create_link(void *object,
					const struct spa_dict *props)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_ENDPOINT_METHOD_CREATE_LINK, NULL);

	push_dict(b, props);

	return pw_protocol_native_end_resource(resource, b);
}

static int endpoint_proxy_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_info(&prs, &f, &info);

	return pw_proxy_notify(proxy, struct pw_endpoint_events,
				info, 0, &info);
}

static int endpoint_resource_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_endpoint_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_endpoint_info(&prs, &f, &info);

	return pw_resource_notify(resource, struct pw_endpoint_events,
				info, 0, &info);
}

static int endpoint_proxy_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_resource_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_events,
				param, 0, seq, id, index, next, param);
}

static int endpoint_proxy_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_resource_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_methods,
				subscribe_params, 0, ids, n_ids);
}

static int endpoint_proxy_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_resource_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int endpoint_proxy_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_endpoint_methods,
				set_param, 0, id, flags, param);
}

static int endpoint_resource_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_endpoint_methods,
				set_param, 0, id, flags, param);
}

static int endpoint_proxy_demarshal_create_link(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);

	parse_dict(&prs, &f, &props);

	return pw_proxy_notify(proxy, struct pw_endpoint_methods,
				create_link, 0, &props);
}

static int endpoint_resource_demarshal_create_link(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);

	parse_dict(&prs, &f, &props);

	return pw_resource_notify(resource, struct pw_endpoint_methods,
				create_link, 0, &props);
}

static const struct pw_endpoint_events pw_protocol_native_endpoint_client_event_marshal = {
	PW_VERSION_ENDPOINT_EVENTS,
	.info = endpoint_proxy_marshal_info,
	.param = endpoint_proxy_marshal_param,
};

static const struct pw_endpoint_events pw_protocol_native_endpoint_server_event_marshal = {
	PW_VERSION_ENDPOINT_EVENTS,
	.info = endpoint_resource_marshal_info,
	.param = endpoint_resource_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_client_event_demarshal[PW_ENDPOINT_EVENT_NUM] =
{
	[PW_ENDPOINT_EVENT_INFO] = { endpoint_proxy_demarshal_info, 0 },
	[PW_ENDPOINT_EVENT_PARAM] = { endpoint_proxy_demarshal_param, 0 },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_server_event_demarshal[PW_ENDPOINT_EVENT_NUM] =
{
	[PW_ENDPOINT_EVENT_INFO] = { endpoint_resource_demarshal_info, 0 },
	[PW_ENDPOINT_EVENT_PARAM] = { endpoint_resource_demarshal_param, 0 },
};

static const struct pw_endpoint_methods pw_protocol_native_endpoint_client_method_marshal = {
	PW_VERSION_ENDPOINT_METHODS,
	.add_listener = endpoint_proxy_marshal_add_listener,
	.subscribe_params = endpoint_proxy_marshal_subscribe_params,
	.enum_params = endpoint_proxy_marshal_enum_params,
	.set_param = endpoint_proxy_marshal_set_param,
	.create_link = endpoint_proxy_marshal_create_link,
};

static const struct pw_endpoint_methods pw_protocol_native_endpoint_server_method_marshal = {
	PW_VERSION_ENDPOINT_METHODS,
	.add_listener = endpoint_resource_marshal_add_listener,
	.subscribe_params = endpoint_resource_marshal_subscribe_params,
	.enum_params = endpoint_resource_marshal_enum_params,
	.set_param = endpoint_resource_marshal_set_param,
	.create_link = endpoint_resource_marshal_create_link,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_client_method_demarshal[PW_ENDPOINT_METHOD_NUM] =
{
	[PW_ENDPOINT_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_METHOD_SUBSCRIBE_PARAMS] = { endpoint_proxy_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_METHOD_ENUM_PARAMS] = { endpoint_proxy_demarshal_enum_params, 0 },
	[PW_ENDPOINT_METHOD_SET_PARAM] = { endpoint_proxy_demarshal_set_param, PW_PERM_W },
	[PW_ENDPOINT_METHOD_CREATE_LINK] = { endpoint_proxy_demarshal_create_link, PW_PERM_X },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_endpoint_server_method_demarshal[PW_ENDPOINT_METHOD_NUM] =
{
	[PW_ENDPOINT_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_ENDPOINT_METHOD_SUBSCRIBE_PARAMS] = { endpoint_resource_demarshal_subscribe_params, 0 },
	[PW_ENDPOINT_METHOD_ENUM_PARAMS] = { endpoint_resource_demarshal_enum_params, 0 },
	[PW_ENDPOINT_METHOD_SET_PARAM] = { endpoint_resource_demarshal_set_param, PW_PERM_W },
	[PW_ENDPOINT_METHOD_CREATE_LINK] = { endpoint_resource_demarshal_create_link, PW_PERM_X },
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_marshal = {
	PW_TYPE_INTERFACE_Endpoint,
	PW_VERSION_ENDPOINT,
	0,
	PW_ENDPOINT_METHOD_NUM,
	PW_ENDPOINT_EVENT_NUM,
	.client_marshal = &pw_protocol_native_endpoint_client_method_marshal,
	.server_demarshal = pw_protocol_native_endpoint_server_method_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_server_event_marshal,
	.client_demarshal = pw_protocol_native_endpoint_client_event_demarshal,
};

static const struct pw_protocol_marshal pw_protocol_native_endpoint_impl_marshal = {
	PW_TYPE_INTERFACE_Endpoint,
	PW_VERSION_ENDPOINT,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	PW_ENDPOINT_EVENT_NUM,
	PW_ENDPOINT_METHOD_NUM,
	.client_marshal = &pw_protocol_native_endpoint_client_event_marshal,
	.server_demarshal = pw_protocol_native_endpoint_server_event_demarshal,
	.server_marshal = &pw_protocol_native_endpoint_server_method_marshal,
	.client_demarshal = pw_protocol_native_endpoint_client_method_demarshal,
};

/***********************************************
 *                 SESSION
 ***********************************************/

static void session_proxy_marshal_info (void *object,
				const struct pw_session_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_SESSION_EVENT_INFO, NULL);

	marshal_pw_session_info(b, info);

	pw_protocol_native_end_proxy(proxy, b);
}

static void session_resource_marshal_info (void *object,
				const struct pw_session_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_SESSION_EVENT_INFO, NULL);

	marshal_pw_session_info(b, info);

	pw_protocol_native_end_resource(resource, b);
}

static void session_proxy_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_SESSION_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_proxy(proxy, b);
}

static void session_resource_marshal_param (void *object, int seq, uint32_t id,
					uint32_t index, uint32_t next,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_SESSION_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
				SPA_POD_Int(seq),
				SPA_POD_Id(id),
				SPA_POD_Int(index),
				SPA_POD_Int(next),
				SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int session_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_session_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int session_resource_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_session_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	pw_resource_add_object_listener(resource, listener, events, data);
	return 0;
}

static int session_proxy_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_SESSION_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int session_resource_marshal_subscribe_params(void *object,
						uint32_t *ids, uint32_t n_ids)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_SESSION_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_resource(resource, b);
}

static int session_proxy_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_SESSION_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int session_resource_marshal_enum_params(void *object,
					int seq, uint32_t id,
					uint32_t index, uint32_t num,
					const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_SESSION_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_resource(resource, b);
}

static int session_proxy_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy,
		PW_SESSION_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int session_resource_marshal_set_param(void *object,
					uint32_t id, uint32_t flags,
					const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource,
		PW_SESSION_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int session_proxy_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_session_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_session_info(&prs, &f, &info);

	return pw_proxy_notify(proxy, struct pw_session_events,
				info, 0, &info);
}

static int session_resource_demarshal_info(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_session_info info = { .props = &props };

	spa_pod_parser_init(&prs, msg->data, msg->size);

	demarshal_pw_session_info(&prs, &f, &info);

	return pw_resource_notify(resource, struct pw_session_events,
				info, 0, &info);
}

static int session_proxy_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_session_events,
				param, 0, seq, id, index, next, param);
}

static int session_resource_demarshal_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, next;
	int seq;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&next),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_session_events,
				param, 0, seq, id, index, next, param);
}

static int session_proxy_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_session_methods,
				subscribe_params, 0, ids, n_ids);
}

static int session_resource_demarshal_subscribe_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t csize, ctype, n_ids;
	uint32_t *ids;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Array(&csize, &ctype, &n_ids, &ids)) < 0)
		return -EINVAL;

	if (ctype != SPA_TYPE_Id)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_session_methods,
				subscribe_params, 0, ids, n_ids);
}

static int session_proxy_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_session_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int session_resource_demarshal_enum_params(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&seq),
				SPA_POD_Id(&id),
				SPA_POD_Int(&index),
				SPA_POD_Int(&num),
				SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_session_methods,
				enum_params, 0, seq, id, index, num, filter);
}

static int session_proxy_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_session_methods,
				set_param, 0, id, flags, param);
}

static int session_resource_demarshal_set_param(void *object,
				const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, flags;
	struct spa_pod *param;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Id(&id),
				SPA_POD_Int(&flags),
				SPA_POD_Pod(&param)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_session_methods,
				set_param, 0, id, flags, param);
}

static const struct pw_session_events pw_protocol_native_session_client_event_marshal = {
	PW_VERSION_SESSION_EVENTS,
	.info = session_proxy_marshal_info,
	.param = session_proxy_marshal_param,
};

static const struct pw_session_events pw_protocol_native_session_server_event_marshal = {
	PW_VERSION_SESSION_EVENTS,
	.info = session_resource_marshal_info,
	.param = session_resource_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_session_client_event_demarshal[PW_SESSION_EVENT_NUM] =
{
	[PW_SESSION_EVENT_INFO] = { session_proxy_demarshal_info, 0 },
	[PW_SESSION_EVENT_PARAM] = { session_proxy_demarshal_param, 0 },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_session_server_event_demarshal[PW_SESSION_EVENT_NUM] =
{
	[PW_SESSION_EVENT_INFO] = { session_resource_demarshal_info, 0 },
	[PW_SESSION_EVENT_PARAM] = { session_resource_demarshal_param, 0 },
};

static const struct pw_session_methods pw_protocol_native_session_client_method_marshal = {
	PW_VERSION_SESSION_METHODS,
	.add_listener = session_proxy_marshal_add_listener,
	.subscribe_params = session_proxy_marshal_subscribe_params,
	.enum_params = session_proxy_marshal_enum_params,
	.set_param = session_proxy_marshal_set_param,
};

static const struct pw_session_methods pw_protocol_native_session_server_method_marshal = {
	PW_VERSION_SESSION_METHODS,
	.add_listener = session_resource_marshal_add_listener,
	.subscribe_params = session_resource_marshal_subscribe_params,
	.enum_params = session_resource_marshal_enum_params,
	.set_param = session_resource_marshal_set_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_session_client_method_demarshal[PW_SESSION_METHOD_NUM] =
{
	[PW_SESSION_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_SESSION_METHOD_SUBSCRIBE_PARAMS] = { session_proxy_demarshal_subscribe_params, 0 },
	[PW_SESSION_METHOD_ENUM_PARAMS] = { session_proxy_demarshal_enum_params, 0 },
	[PW_SESSION_METHOD_SET_PARAM] = { session_proxy_demarshal_set_param, PW_PERM_W },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_session_server_method_demarshal[PW_SESSION_METHOD_NUM] =
{
	[PW_SESSION_METHOD_ADD_LISTENER] = { demarshal_add_listener_enotsup, 0 },
	[PW_SESSION_METHOD_SUBSCRIBE_PARAMS] = { session_resource_demarshal_subscribe_params, 0 },
	[PW_SESSION_METHOD_ENUM_PARAMS] = { session_resource_demarshal_enum_params, 0 },
	[PW_SESSION_METHOD_SET_PARAM] = { session_resource_demarshal_set_param, PW_PERM_W },
};

static const struct pw_protocol_marshal pw_protocol_native_session_marshal = {
	PW_TYPE_INTERFACE_Session,
	PW_VERSION_SESSION,
	0,
	PW_SESSION_METHOD_NUM,
	PW_SESSION_EVENT_NUM,
	.client_marshal = &pw_protocol_native_session_client_method_marshal,
	.server_demarshal = pw_protocol_native_session_server_method_demarshal,
	.server_marshal = &pw_protocol_native_session_server_event_marshal,
	.client_demarshal = pw_protocol_native_session_client_event_demarshal,
};

static const struct pw_protocol_marshal pw_protocol_native_session_impl_marshal = {
	PW_TYPE_INTERFACE_Session,
	PW_VERSION_SESSION,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	PW_SESSION_EVENT_NUM,
	PW_SESSION_METHOD_NUM,
	.client_marshal = &pw_protocol_native_session_client_event_marshal,
	.server_demarshal = pw_protocol_native_session_server_event_demarshal,
	.server_marshal = &pw_protocol_native_session_server_method_marshal,
	.client_demarshal = pw_protocol_native_session_client_method_demarshal,
};

int pw_protocol_native_ext_session_manager_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);
	if (protocol == NULL)
		return -EPROTO;

	/* deprecated */
	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_endpoint_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_session_marshal);

	/* client <-> server */
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_link_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_stream_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_session_marshal);

	/* impl <-> server */
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_link_impl_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_stream_impl_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_endpoint_impl_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_session_impl_marshal);

	return 0;
}
