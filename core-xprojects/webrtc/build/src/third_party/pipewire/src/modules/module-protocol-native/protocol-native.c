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

#include <stdio.h>
#include <errno.h>

#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/utils/result.h>

#include <pipewire/impl.h>
#include <extensions/protocol-native.h>

#include "connection.h"

static int core_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_core_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int core_method_marshal_hello(void *object, uint32_t version)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_HELLO, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(version));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int core_method_marshal_sync(void *object, uint32_t id, int seq)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_SYNC, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int core_method_marshal_pong(void *object, uint32_t id, int seq)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_PONG, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Int(seq));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int core_method_marshal_error(void *object, uint32_t id, int seq, int res, const char *error)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_ERROR, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(id),
			       SPA_POD_Int(seq),
			       SPA_POD_Int(res),
			       SPA_POD_String(error));

	return pw_protocol_native_end_proxy(proxy, b);
}

static struct pw_registry * core_method_marshal_get_registry(void *object,
		uint32_t version, size_t user_data_size)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct pw_proxy *res;
	uint32_t new_id;

	res = pw_proxy_new(object, PW_TYPE_INTERFACE_Registry, version, user_data_size);
	if (res == NULL)
		return NULL;

	new_id = pw_proxy_get_id(res);

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_GET_REGISTRY, NULL);

	spa_pod_builder_add_struct(b,
		       SPA_POD_Int(version),
		       SPA_POD_Int(new_id));

	pw_protocol_native_end_proxy(proxy, b);

	return (struct pw_registry *) res;
}

static inline void push_item(struct spa_pod_builder *b, const struct spa_dict_item *item)
{
	const char *str;
	spa_pod_builder_string(b, item->key);
	str = item->value;
	if (strstr(str, "pointer:") == str)
		str = "";
	spa_pod_builder_string(b, str);
}

static void push_dict(struct spa_pod_builder *b, const struct spa_dict *dict)
{
	uint32_t i, n_items;
	struct spa_pod_frame f;

	n_items = dict ? dict->n_items : 0;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_int(b, n_items);
	for (i = 0; i < n_items; i++)
		push_item(b, &dict->items[i]);
	spa_pod_builder_pop(b, &f);
}

static inline int parse_item(struct spa_pod_parser *prs, struct spa_dict_item *item)
{
	int res;
	if ((res = spa_pod_parser_get(prs,
		       SPA_POD_String(&item->key),
		       SPA_POD_String(&item->value),
		       NULL)) < 0)
		return res;
	if (strstr(item->value, "pointer:") == item->value)
		item->value = "";
	return 0;
}

static inline int parse_dict(struct spa_pod_parser *prs, struct spa_dict *dict)
{
	uint32_t i;
	int res;
	for (i = 0; i < dict->n_items; i++) {
		if ((res = parse_item(prs, (struct spa_dict_item *) &dict->items[i])) < 0)
			return res;
	}
	return 0;
}

static void push_params(struct spa_pod_builder *b, uint32_t n_params,
		const struct spa_param_info *params)
{
	uint32_t i;
	struct spa_pod_frame f;

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_int(b, n_params);
	for (i = 0; i < n_params; i++) {
		spa_pod_builder_id(b, params[i].id);
		spa_pod_builder_int(b, params[i].flags);
	}
	spa_pod_builder_pop(b, &f);
}

static void *
core_method_marshal_create_object(void *object,
			   const char *factory_name,
			   const char *type, uint32_t version,
			   const struct spa_dict *props, size_t user_data_size)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	struct pw_proxy *res;
	uint32_t new_id;

	res = pw_proxy_new(object, type, version, user_data_size);
	if (res == NULL)
		return NULL;

	new_id = pw_proxy_get_id(res);

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_CREATE_OBJECT, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			SPA_POD_String(factory_name),
			SPA_POD_String(type),
			SPA_POD_Int(version),
			NULL);
	push_dict(b, props);
	spa_pod_builder_int(b, new_id);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_proxy(proxy, b);

	return (void *)res;
}

static int
core_method_marshal_destroy(void *object, void *p)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	uint32_t id = pw_proxy_get_id(p);

	b = pw_protocol_native_begin_proxy(proxy, PW_CORE_METHOD_DESTROY, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int core_event_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct spa_pod_frame f[2];
	struct pw_core_info info;
	struct spa_pod_parser prs;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0)
		return -EINVAL;
	if (spa_pod_parser_get(&prs,
			 SPA_POD_Int(&info.id),
			 SPA_POD_Int(&info.cookie),
			 SPA_POD_String(&info.user_name),
			 SPA_POD_String(&info.host_name),
			 SPA_POD_String(&info.version),
			 SPA_POD_String(&info.name),
			 SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0)
		return -EINVAL;
	if (spa_pod_parser_get(&prs,
			 SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, info, 0, &info);
}

static int core_event_demarshal_done(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&seq)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, done, 0, id, seq);
}

static int core_event_demarshal_ping(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&seq)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, ping, 0, id, seq);
}

static int core_event_demarshal_error(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, res;
	int seq;
	const char *error;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id),
			SPA_POD_Int(&seq),
			SPA_POD_Int(&res),
			SPA_POD_String(&error)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, error, 0, id, seq, res, error);
}

static int core_event_demarshal_remove_id(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs, SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, remove_id, 0, id);
}

static int core_event_demarshal_bound_id(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, global_id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&global_id)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, bound_id, 0, id, global_id);
}

static int core_event_demarshal_add_mem(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, type, flags;
	int64_t idx;
	int fd;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Id(&type),
				SPA_POD_Fd(&idx),
				SPA_POD_Int(&flags)) < 0)
		return -EINVAL;

	fd = pw_protocol_native_get_proxy_fd(proxy, idx);

	return pw_proxy_notify(proxy, struct pw_core_events, add_mem, 0, id, type, fd, flags);
}

static int core_event_demarshal_remove_mem(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_core_events, remove_mem, 0, id);
}

static void core_event_marshal_info(void *object, const struct pw_core_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Int(info->cookie),
			    SPA_POD_String(info->user_name),
			    SPA_POD_String(info->host_name),
			    SPA_POD_String(info->version),
			    SPA_POD_String(info->name),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_CORE_CHANGE_MASK_PROPS ? info->props : NULL);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_done(void *object, uint32_t id, int seq)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_DONE, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Int(seq));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_ping(void *object, uint32_t id, int seq)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct pw_protocol_native_message *msg;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_PING, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_error(void *object, uint32_t id, int seq, int res, const char *error)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_ERROR, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(id),
			       SPA_POD_Int(seq),
			       SPA_POD_Int(res),
			       SPA_POD_String(error));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_remove_id(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_REMOVE_ID, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_bound_id(void *object, uint32_t id, uint32_t global_id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_BOUND_ID, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Int(global_id));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_add_mem(void *object, uint32_t id, uint32_t type, int fd, uint32_t flags)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_ADD_MEM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id),
			SPA_POD_Id(type),
			SPA_POD_Fd(pw_protocol_native_add_resource_fd(resource, fd)),
			SPA_POD_Int(flags));

	pw_protocol_native_end_resource(resource, b);
}

static void core_event_marshal_remove_mem(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_EVENT_REMOVE_MEM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(id));

	pw_protocol_native_end_resource(resource, b);
}

static int core_method_demarshal_hello(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t version;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&version)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, hello, 0, version);
}

static int core_method_demarshal_sync(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&seq)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, sync, 0, id, seq);
}

static int core_method_demarshal_pong(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&seq)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, pong, 0, id, seq);
}

static int core_method_demarshal_error(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, res;
	int seq;
	const char *error;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id),
			SPA_POD_Int(&seq),
			SPA_POD_Int(&res),
			SPA_POD_String(&error)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, error, 0, id, seq, res, error);
}

static int core_method_demarshal_get_registry(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	int32_t version, new_id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&version),
				SPA_POD_Int(&new_id)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, get_registry, 0, version, new_id);
}

static int core_method_demarshal_create_object(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	uint32_t version, new_id;
	const char *factory_name, *type;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_String(&factory_name),
			SPA_POD_String(&type),
			SPA_POD_Int(&version),
			NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;
	spa_pod_parser_pop(&prs, &f[1]);

	if (spa_pod_parser_get(&prs,
			SPA_POD_Int(&new_id), NULL) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, create_object, 0, factory_name,
								      type, version,
								      &props, new_id);
}

static int core_method_demarshal_destroy(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct pw_resource *r;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	pw_log_debug("client %p: destroy resource %u", client, id);

	if ((r = pw_impl_client_find_resource(client, id)) == NULL)
		goto no_resource;

	return pw_resource_notify(resource, struct pw_core_methods, destroy, 0, r);

      no_resource:
	pw_log_debug("client %p: unknown resource %u op:%u", client, id, msg->opcode);
	pw_resource_errorf(resource, -ENOENT, "unknown resource %d op:%u", id, msg->opcode);
	return 0;
}

static int registry_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_registry_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void registry_marshal_global(void *object, uint32_t id, uint32_t permissions,
				    const char *type, uint32_t version, const struct spa_dict *props)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_REGISTRY_EVENT_GLOBAL, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(id),
			    SPA_POD_Int(permissions),
			    SPA_POD_String(type),
			    SPA_POD_Int(version),
			    NULL);
	push_dict(b, props);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void registry_marshal_global_remove(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_REGISTRY_EVENT_GLOBAL_REMOVE, NULL);

	spa_pod_builder_add_struct(b, SPA_POD_Int(id));

	pw_protocol_native_end_resource(resource, b);
}

static int registry_demarshal_bind(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, version, new_id;
	char *type;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id),
			SPA_POD_String(&type),
			SPA_POD_Int(&version),
			SPA_POD_Int(&new_id)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_registry_methods, bind, 0, id, type, version, new_id);
}

static int registry_demarshal_destroy(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_registry_methods, destroy, 0, id);
}

static int module_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_module_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void module_marshal_info(void *object, const struct pw_module_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_MODULE_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_String(info->name),
			    SPA_POD_String(info->filename),
			    SPA_POD_String(info->args),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_MODULE_CHANGE_MASK_PROPS ? info->props : NULL);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int module_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_module_info info;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_String(&info.name),
			SPA_POD_String(&info.filename),
			SPA_POD_String(&info.args),
			SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_module_events, info, 0, &info);
}

static int device_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_device_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void device_marshal_info(void *object, const struct pw_device_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_DEVICE_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_DEVICE_CHANGE_MASK_PROPS ? info->props : NULL);
	push_params(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int device_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_device_info info;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;
	spa_pod_parser_pop(&prs, &f[1]);

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			       SPA_POD_Int(&info.n_params),
			       NULL) < 0)
		return -EINVAL;

	info.params = alloca(info.n_params * sizeof(struct spa_param_info));
	for (i = 0; i < info.n_params; i++) {
		if (spa_pod_parser_get(&prs,
				       SPA_POD_Id(&info.params[i].id),
				       SPA_POD_Int(&info.params[i].flags), NULL) < 0)
			return -EINVAL;
	}

	return pw_proxy_notify(proxy, struct pw_device_events, info, 0, &info);
}

static void device_marshal_param(void *object, int seq, uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_DEVICE_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(seq),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(next),
			SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int device_demarshal_param(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_proxy_notify(proxy, struct pw_device_events, param, 0,
			seq, id, index, next, param);
}

static int device_marshal_subscribe_params(void *object, uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_DEVICE_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_subscribe_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_device_methods, subscribe_params, 0,
			ids, n_ids);
}

static int device_marshal_enum_params(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t num, const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_DEVICE_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_device_methods, enum_params, 0,
			seq, id, index, num, filter);
}

static int device_marshal_set_param(void *object, uint32_t id, uint32_t flags,
		const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_DEVICE_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));
	return pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_set_param(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_device_methods, set_param, 0, id, flags, param);
}

static int factory_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_factory_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void factory_marshal_info(void *object, const struct pw_factory_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_FACTORY_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_String(info->name),
			    SPA_POD_String(info->type),
			    SPA_POD_Int(info->version),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_FACTORY_CHANGE_MASK_PROPS ? info->props : NULL);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int factory_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_factory_info info;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_String(&info.name),
			SPA_POD_String(&info.type),
			SPA_POD_Int(&info.version),
			SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_factory_events, info, 0, &info);
}

static int node_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_node_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void node_marshal_info(void *object, const struct pw_node_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_NODE_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Int(info->max_input_ports),
			    SPA_POD_Int(info->max_output_ports),
			    SPA_POD_Long(info->change_mask),
			    SPA_POD_Int(info->n_input_ports),
			    SPA_POD_Int(info->n_output_ports),
			    SPA_POD_Id(info->state),
			    SPA_POD_String(info->error),
			    NULL);
	push_dict(b, info->change_mask & PW_NODE_CHANGE_MASK_PROPS ? info->props : NULL);
	push_params(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int node_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_node_info info;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_Int(&info.max_input_ports),
			SPA_POD_Int(&info.max_output_ports),
			SPA_POD_Long(&info.change_mask),
			SPA_POD_Int(&info.n_input_ports),
			SPA_POD_Int(&info.n_output_ports),
			SPA_POD_Id(&info.state),
			SPA_POD_String(&info.error), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;
	spa_pod_parser_pop(&prs, &f[1]);

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			       SPA_POD_Int(&info.n_params),
			       NULL) < 0)
		return -EINVAL;

	info.params = alloca(info.n_params * sizeof(struct spa_param_info));
	for (i = 0; i < info.n_params; i++) {
		if (spa_pod_parser_get(&prs,
				       SPA_POD_Id(&info.params[i].id),
				       SPA_POD_Int(&info.params[i].flags), NULL) < 0)
			return -EINVAL;
	}

	return pw_proxy_notify(proxy, struct pw_node_events, info, 0, &info);
}

static void node_marshal_param(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t next, const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_NODE_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(seq),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(next),
			SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int node_demarshal_param(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_proxy_notify(proxy, struct pw_node_events, param, 0,
			seq, id, index, next, param);
}

static int node_marshal_subscribe_params(void *object, uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_NODE_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int node_demarshal_subscribe_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_node_methods, subscribe_params, 0,
			ids, n_ids);
}

static int node_marshal_enum_params(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t num, const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_NODE_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int node_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_node_methods, enum_params, 0,
			seq, id, index, num, filter);
}

static int node_marshal_set_param(void *object, uint32_t id, uint32_t flags,
		const struct spa_pod *param)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_NODE_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));
	return pw_protocol_native_end_proxy(proxy, b);
}

static int node_demarshal_set_param(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_node_methods, set_param, 0, id, flags, param);
}

static int node_marshal_send_command(void *object, const struct spa_command *command)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_NODE_METHOD_SEND_COMMAND, NULL);
	spa_pod_builder_add_struct(b,
			SPA_POD_Pod(command));
	return pw_protocol_native_end_proxy(proxy, b);
}

static int node_demarshal_send_command(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	const struct spa_command *command;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Pod(&command)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_node_methods, send_command, 0, command);
}

static int port_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_port_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void port_marshal_info(void *object, const struct pw_port_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_PORT_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Int(info->direction),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_PORT_CHANGE_MASK_PROPS ? info->props : NULL);
	push_params(b, info->n_params, info->params);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int port_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_port_info info;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_Int(&info.direction),
			SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;
	spa_pod_parser_pop(&prs, &f[1]);

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			       SPA_POD_Int(&info.n_params),
			       NULL) < 0)
		return -EINVAL;

	info.params = alloca(info.n_params * sizeof(struct spa_param_info));
	for (i = 0; i < info.n_params; i++) {
		if (spa_pod_parser_get(&prs,
				       SPA_POD_Id(&info.params[i].id),
				       SPA_POD_Int(&info.params[i].flags), NULL) < 0)
			return -EINVAL;
	}
	return pw_proxy_notify(proxy, struct pw_port_events, info, 0, &info);
}

static void port_marshal_param(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t next, const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_PORT_EVENT_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(seq),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(next),
			SPA_POD_Pod(param));

	pw_protocol_native_end_resource(resource, b);
}

static int port_demarshal_param(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_proxy_notify(proxy, struct pw_port_events, param, 0,
			seq, id, index, next, param);
}

static int port_marshal_subscribe_params(void *object, uint32_t *ids, uint32_t n_ids)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_PORT_METHOD_SUBSCRIBE_PARAMS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Array(sizeof(uint32_t), SPA_TYPE_Id, n_ids, ids));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int port_demarshal_subscribe_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_port_methods, subscribe_params, 0,
			ids, n_ids);
}

static int port_marshal_enum_params(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t num, const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_PORT_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(num),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int port_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
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

	return pw_resource_notify(resource, struct pw_port_methods, enum_params, 0,
			seq, id, index, num, filter);
}

static int client_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_client_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void client_marshal_info(void *object, const struct pw_client_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Long(info->change_mask),
			    NULL);
	push_dict(b, info->change_mask & PW_CLIENT_CHANGE_MASK_PROPS ? info->props : NULL);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int client_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_client_info info;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_Long(&info.change_mask), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_client_events, info, 0, &info);
}

static void client_marshal_permissions(void *object, uint32_t index, uint32_t n_permissions,
		const struct pw_permission *permissions)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, n = 0;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_EVENT_PERMISSIONS, NULL);

	for (i = 0; i < n_permissions; i++) {
		if (permissions[i].permissions != PW_PERM_INVALID)
			n++;
	}

	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_int(b, index);
	spa_pod_builder_push_struct(b, &f[1]);
	spa_pod_builder_int(b, n);

	for (i = 0; i < n_permissions; i++) {
		if (permissions[i].permissions == PW_PERM_INVALID)
			continue;
		spa_pod_builder_int(b, permissions[i].id);
		spa_pod_builder_int(b, permissions[i].permissions);
	}
	spa_pod_builder_pop(b, &f[1]);
	spa_pod_builder_pop(b, &f[0]);

	pw_protocol_native_end_resource(resource, b);
}

static int client_demarshal_permissions(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct pw_permission *permissions;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	uint32_t i, index, n_permissions;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
		    SPA_POD_Int(&index), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
		    SPA_POD_Int(&n_permissions), NULL) < 0)
		return -EINVAL;

	permissions = alloca(n_permissions * sizeof(struct pw_permission));
	for (i = 0; i < n_permissions; i++) {
		if (spa_pod_parser_get(&prs,
				SPA_POD_Int(&permissions[i].id),
				SPA_POD_Int(&permissions[i].permissions), NULL) < 0)
			return -EINVAL;
	}
	return pw_proxy_notify(proxy, struct pw_client_events, permissions, 0, index, n_permissions, permissions);
}

static int client_marshal_error(void *object, uint32_t id, int res, const char *error)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_METHOD_ERROR, NULL);
	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(id),
			       SPA_POD_Int(res),
			       SPA_POD_String(error));
	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_demarshal_error(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t id, res;
	const char *error;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id),
				SPA_POD_Int(&res),
				SPA_POD_String(&error)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_methods, error, 0, id, res, error);
}

static int client_marshal_get_permissions(void *object, uint32_t index, uint32_t num)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_METHOD_GET_PERMISSIONS, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(index),
			SPA_POD_Int(num));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_marshal_update_properties(void *object, const struct spa_dict *props)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_METHOD_UPDATE_PROPERTIES, NULL);

	spa_pod_builder_push_struct(b, &f);
	push_dict(b, props);
	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_demarshal_update_properties(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
		    SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_methods, update_properties, 0,
			&props);
}

static int client_demarshal_get_permissions(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t index, num;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&index),
				SPA_POD_Int(&num)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_methods, get_permissions, 0, index, num);
}

static int client_marshal_update_permissions(void *object, uint32_t n_permissions,
		const struct pw_permission *permissions)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_METHOD_UPDATE_PERMISSIONS, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_int(b, n_permissions);
	for (i = 0; i < n_permissions; i++) {
		spa_pod_builder_int(b, permissions[i].id);
		spa_pod_builder_int(b, permissions[i].permissions);
	}
	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_demarshal_update_permissions(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_permission *permissions;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[1];
	uint32_t i, n_permissions;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
				SPA_POD_Int(&n_permissions), NULL) < 0)
		return -EINVAL;

	permissions = alloca(n_permissions * sizeof(struct pw_permission));
	for (i = 0; i < n_permissions; i++) {
		if (spa_pod_parser_get(&prs,
				SPA_POD_Int(&permissions[i].id),
				SPA_POD_Int(&permissions[i].permissions), NULL) < 0)
			return -EINVAL;
	}
	return pw_resource_notify(resource, struct pw_client_methods, update_permissions, 0,
			n_permissions, permissions);
}

static int link_method_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_link_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static void link_marshal_info(void *object, const struct pw_link_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_LINK_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    SPA_POD_Int(info->id),
			    SPA_POD_Int(info->output_node_id),
			    SPA_POD_Int(info->output_port_id),
			    SPA_POD_Int(info->input_node_id),
			    SPA_POD_Int(info->input_port_id),
			    SPA_POD_Long(info->change_mask),
			    SPA_POD_Int(info->state),
			    SPA_POD_String(info->error),
			    SPA_POD_Pod(info->format),
			    NULL);
	push_dict(b, info->change_mask & PW_LINK_CHANGE_MASK_PROPS ? info->props : NULL);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int link_demarshal_info(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	struct pw_link_info info = { 0, };

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&info.id),
			SPA_POD_Int(&info.output_node_id),
			SPA_POD_Int(&info.output_port_id),
			SPA_POD_Int(&info.input_node_id),
			SPA_POD_Int(&info.input_port_id),
			SPA_POD_Long(&info.change_mask),
			SPA_POD_Int(&info.state),
			SPA_POD_String(&info.error),
			SPA_POD_Pod(&info.format), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	info.props = &props;
	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_link_events, info, 0, &info);
}

static int registry_demarshal_global(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	uint32_t id, permissions, version;
	char *type;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&id),
			SPA_POD_Int(&permissions),
			SPA_POD_String(&type),
			SPA_POD_Int(&version), NULL) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_registry_events,
			global, 0, id, permissions, type, version,
			props.n_items > 0 ? &props : NULL);
}

static int registry_demarshal_global_remove(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&id)) < 0)
		return -EINVAL;

	return pw_proxy_notify(proxy, struct pw_registry_events, global_remove, 0, id);
}

static void * registry_marshal_bind(void *object, uint32_t id,
				  const char *type, uint32_t version, size_t user_data_size)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct pw_proxy *res;
	uint32_t new_id;

	res = pw_proxy_new(object, type, version, user_data_size);
	if (res == NULL)
		return NULL;

	new_id = pw_proxy_get_id(res);

	b = pw_protocol_native_begin_proxy(proxy, PW_REGISTRY_METHOD_BIND, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(id),
			       SPA_POD_String(type),
			       SPA_POD_Int(version),
			       SPA_POD_Int(new_id));

	pw_protocol_native_end_proxy(proxy, b);

	return (void *) res;
}

static int registry_marshal_destroy(void *object, uint32_t id)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_REGISTRY_METHOD_DESTROY, NULL);
	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(id));
	return pw_protocol_native_end_proxy(proxy, b);
}

static const struct pw_core_methods pw_protocol_native_core_method_marshal = {
	PW_VERSION_CORE_METHODS,
	.add_listener = &core_method_marshal_add_listener,
	.hello = &core_method_marshal_hello,
	.sync = &core_method_marshal_sync,
	.pong = &core_method_marshal_pong,
	.error = &core_method_marshal_error,
	.get_registry = &core_method_marshal_get_registry,
	.create_object = &core_method_marshal_create_object,
	.destroy = &core_method_marshal_destroy,
};

static const struct pw_protocol_native_demarshal pw_protocol_native_core_method_demarshal[PW_CORE_METHOD_NUM] = {
	[PW_CORE_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_CORE_METHOD_HELLO] = { &core_method_demarshal_hello, 0, },
	[PW_CORE_METHOD_SYNC] = { &core_method_demarshal_sync, 0, },
	[PW_CORE_METHOD_PONG] = { &core_method_demarshal_pong, 0, },
	[PW_CORE_METHOD_ERROR] = { &core_method_demarshal_error, 0, },
	[PW_CORE_METHOD_GET_REGISTRY] = { &core_method_demarshal_get_registry, 0, },
	[PW_CORE_METHOD_CREATE_OBJECT] = { &core_method_demarshal_create_object, 0, },
	[PW_CORE_METHOD_DESTROY] = { &core_method_demarshal_destroy, 0, }
};

static const struct pw_core_events pw_protocol_native_core_event_marshal = {
	PW_VERSION_CORE_EVENTS,
	.info = &core_event_marshal_info,
	.done = &core_event_marshal_done,
	.ping = &core_event_marshal_ping,
	.error = &core_event_marshal_error,
	.remove_id = &core_event_marshal_remove_id,
	.bound_id = &core_event_marshal_bound_id,
	.add_mem = &core_event_marshal_add_mem,
	.remove_mem = &core_event_marshal_remove_mem,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_core_event_demarshal[PW_CORE_EVENT_NUM] =
{
	[PW_CORE_EVENT_INFO] = { &core_event_demarshal_info, 0, },
	[PW_CORE_EVENT_DONE] = { &core_event_demarshal_done, 0, },
	[PW_CORE_EVENT_PING] = { &core_event_demarshal_ping, 0, },
	[PW_CORE_EVENT_ERROR] = { &core_event_demarshal_error, 0, },
	[PW_CORE_EVENT_REMOVE_ID] = { &core_event_demarshal_remove_id, 0, },
	[PW_CORE_EVENT_BOUND_ID] = { &core_event_demarshal_bound_id, 0, },
	[PW_CORE_EVENT_ADD_MEM] = { &core_event_demarshal_add_mem, 0, },
	[PW_CORE_EVENT_REMOVE_MEM] = { &core_event_demarshal_remove_mem, 0, },
};

static const struct pw_protocol_marshal pw_protocol_native_core_marshal = {
	PW_TYPE_INTERFACE_Core,
	PW_VERSION_CORE,
	0,
	PW_CORE_METHOD_NUM,
	PW_CORE_EVENT_NUM,
	.client_marshal = &pw_protocol_native_core_method_marshal,
	.server_demarshal = pw_protocol_native_core_method_demarshal,
	.server_marshal = &pw_protocol_native_core_event_marshal,
	.client_demarshal = pw_protocol_native_core_event_demarshal,
};

static const struct pw_registry_methods pw_protocol_native_registry_method_marshal = {
	PW_VERSION_REGISTRY_METHODS,
	.add_listener = &registry_method_marshal_add_listener,
	.bind = &registry_marshal_bind,
	.destroy = &registry_marshal_destroy,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_registry_method_demarshal[PW_REGISTRY_METHOD_NUM] =
{
	[PW_REGISTRY_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_REGISTRY_METHOD_BIND] = { &registry_demarshal_bind, 0, },
	[PW_REGISTRY_METHOD_DESTROY] = { &registry_demarshal_destroy, 0, },
};

static const struct pw_registry_events pw_protocol_native_registry_event_marshal = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = &registry_marshal_global,
	.global_remove = &registry_marshal_global_remove,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_registry_event_demarshal[PW_REGISTRY_EVENT_NUM] =
{
	[PW_REGISTRY_EVENT_GLOBAL] = { &registry_demarshal_global, 0, },
	[PW_REGISTRY_EVENT_GLOBAL_REMOVE] = { &registry_demarshal_global_remove, 0, }
};

const struct pw_protocol_marshal pw_protocol_native_registry_marshal = {
	PW_TYPE_INTERFACE_Registry,
	PW_VERSION_REGISTRY,
	0,
	PW_REGISTRY_METHOD_NUM,
	PW_REGISTRY_EVENT_NUM,
	.client_marshal = &pw_protocol_native_registry_method_marshal,
	.server_demarshal = pw_protocol_native_registry_method_demarshal,
	.server_marshal = &pw_protocol_native_registry_event_marshal,
	.client_demarshal = pw_protocol_native_registry_event_demarshal,
};

static const struct pw_module_events pw_protocol_native_module_event_marshal = {
	PW_VERSION_MODULE_EVENTS,
	.info = &module_marshal_info,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_module_event_demarshal[PW_MODULE_EVENT_NUM] =
{
	[PW_MODULE_EVENT_INFO] = { &module_demarshal_info, 0, },
};


static const struct pw_module_methods pw_protocol_native_module_method_marshal = {
	PW_VERSION_MODULE_METHODS,
	.add_listener = &module_method_marshal_add_listener,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_module_method_demarshal[PW_MODULE_METHOD_NUM] =
{
	[PW_MODULE_METHOD_ADD_LISTENER] = { NULL, 0, },
};

const struct pw_protocol_marshal pw_protocol_native_module_marshal = {
	PW_TYPE_INTERFACE_Module,
	PW_VERSION_MODULE,
	0,
	PW_MODULE_METHOD_NUM,
	PW_MODULE_EVENT_NUM,
	.client_marshal = &pw_protocol_native_module_method_marshal,
	.server_demarshal = pw_protocol_native_module_method_demarshal,
	.server_marshal = &pw_protocol_native_module_event_marshal,
	.client_demarshal = pw_protocol_native_module_event_demarshal,
};

static const struct pw_factory_events pw_protocol_native_factory_event_marshal = {
	PW_VERSION_FACTORY_EVENTS,
	.info = &factory_marshal_info,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_factory_event_demarshal[PW_FACTORY_EVENT_NUM] =
{
	[PW_FACTORY_EVENT_INFO] = { &factory_demarshal_info, 0, },
};

static const struct pw_factory_methods pw_protocol_native_factory_method_marshal = {
	PW_VERSION_FACTORY_METHODS,
	.add_listener = &factory_method_marshal_add_listener,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_factory_method_demarshal[PW_FACTORY_METHOD_NUM] =
{
	[PW_FACTORY_METHOD_ADD_LISTENER] = { NULL, 0, },
};

const struct pw_protocol_marshal pw_protocol_native_factory_marshal = {
	PW_TYPE_INTERFACE_Factory,
	PW_VERSION_FACTORY,
	0,
	PW_FACTORY_METHOD_NUM,
	PW_FACTORY_EVENT_NUM,
	.client_marshal = &pw_protocol_native_factory_method_marshal,
	.server_demarshal = pw_protocol_native_factory_method_demarshal,
	.server_marshal = &pw_protocol_native_factory_event_marshal,
	.client_demarshal = pw_protocol_native_factory_event_demarshal,
};

static const struct pw_device_methods pw_protocol_native_device_method_marshal = {
	PW_VERSION_DEVICE_METHODS,
	.add_listener = &device_method_marshal_add_listener,
	.subscribe_params = &device_marshal_subscribe_params,
	.enum_params = &device_marshal_enum_params,
	.set_param = &device_marshal_set_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_device_method_demarshal[PW_DEVICE_METHOD_NUM] = {
	[PW_DEVICE_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_DEVICE_METHOD_SUBSCRIBE_PARAMS] = { &device_demarshal_subscribe_params, 0, },
	[PW_DEVICE_METHOD_ENUM_PARAMS] = { &device_demarshal_enum_params, 0, },
	[PW_DEVICE_METHOD_SET_PARAM] = { &device_demarshal_set_param, PW_PERM_W, },
};

static const struct pw_device_events pw_protocol_native_device_event_marshal = {
	PW_VERSION_DEVICE_EVENTS,
	.info = &device_marshal_info,
	.param = &device_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_device_event_demarshal[PW_DEVICE_EVENT_NUM] = {
	[PW_DEVICE_EVENT_INFO] = { &device_demarshal_info, 0, },
	[PW_DEVICE_EVENT_PARAM] = { &device_demarshal_param, 0, }
};

static const struct pw_protocol_marshal pw_protocol_native_device_marshal = {
	PW_TYPE_INTERFACE_Device,
	PW_VERSION_DEVICE,
	0,
	PW_DEVICE_METHOD_NUM,
	PW_DEVICE_EVENT_NUM,
	.client_marshal = &pw_protocol_native_device_method_marshal,
	.server_demarshal = pw_protocol_native_device_method_demarshal,
	.server_marshal = &pw_protocol_native_device_event_marshal,
	.client_demarshal = pw_protocol_native_device_event_demarshal,
};

static const struct pw_node_methods pw_protocol_native_node_method_marshal = {
	PW_VERSION_NODE_METHODS,
	.add_listener = &node_method_marshal_add_listener,
	.subscribe_params = &node_marshal_subscribe_params,
	.enum_params = &node_marshal_enum_params,
	.set_param = &node_marshal_set_param,
	.send_command = &node_marshal_send_command,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_node_method_demarshal[PW_NODE_METHOD_NUM] =
{
	[PW_NODE_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_NODE_METHOD_SUBSCRIBE_PARAMS] = { &node_demarshal_subscribe_params, 0, },
	[PW_NODE_METHOD_ENUM_PARAMS] = { &node_demarshal_enum_params, 0, },
	[PW_NODE_METHOD_SET_PARAM] = { &node_demarshal_set_param, PW_PERM_W, },
	[PW_NODE_METHOD_SEND_COMMAND] = { &node_demarshal_send_command, PW_PERM_W, },
};

static const struct pw_node_events pw_protocol_native_node_event_marshal = {
	PW_VERSION_NODE_EVENTS,
	.info = &node_marshal_info,
	.param = &node_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_node_event_demarshal[PW_NODE_EVENT_NUM] = {
	[PW_NODE_EVENT_INFO] = { &node_demarshal_info, 0, },
	[PW_NODE_EVENT_PARAM] = { &node_demarshal_param, 0, }
};

static const struct pw_protocol_marshal pw_protocol_native_node_marshal = {
	PW_TYPE_INTERFACE_Node,
	PW_VERSION_NODE,
	0,
	PW_NODE_METHOD_NUM,
	PW_NODE_EVENT_NUM,
	.client_marshal = &pw_protocol_native_node_method_marshal,
	.server_demarshal = pw_protocol_native_node_method_demarshal,
	.server_marshal = &pw_protocol_native_node_event_marshal,
	.client_demarshal = pw_protocol_native_node_event_demarshal,
};


static const struct pw_port_methods pw_protocol_native_port_method_marshal = {
	PW_VERSION_PORT_METHODS,
	.add_listener = &port_method_marshal_add_listener,
	.subscribe_params = &port_marshal_subscribe_params,
	.enum_params = &port_marshal_enum_params,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_port_method_demarshal[PW_PORT_METHOD_NUM] =
{
	[PW_PORT_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_PORT_METHOD_SUBSCRIBE_PARAMS] = { &port_demarshal_subscribe_params, 0, },
	[PW_PORT_METHOD_ENUM_PARAMS] = { &port_demarshal_enum_params, 0, },
};

static const struct pw_port_events pw_protocol_native_port_event_marshal = {
	PW_VERSION_PORT_EVENTS,
	.info = &port_marshal_info,
	.param = &port_marshal_param,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_port_event_demarshal[PW_PORT_EVENT_NUM] =
{
	[PW_PORT_EVENT_INFO] = { &port_demarshal_info, 0, },
	[PW_PORT_EVENT_PARAM] = { &port_demarshal_param, 0, }
};

static const struct pw_protocol_marshal pw_protocol_native_port_marshal = {
	PW_TYPE_INTERFACE_Port,
	PW_VERSION_PORT,
	0,
	PW_PORT_METHOD_NUM,
	PW_PORT_EVENT_NUM,
	.client_marshal = &pw_protocol_native_port_method_marshal,
	.server_demarshal = pw_protocol_native_port_method_demarshal,
	.server_marshal = &pw_protocol_native_port_event_marshal,
	.client_demarshal = pw_protocol_native_port_event_demarshal,
};

static const struct pw_client_methods pw_protocol_native_client_method_marshal = {
	PW_VERSION_CLIENT_METHODS,
	.add_listener = &client_method_marshal_add_listener,
	.error = &client_marshal_error,
	.update_properties = &client_marshal_update_properties,
	.get_permissions = &client_marshal_get_permissions,
	.update_permissions = &client_marshal_update_permissions,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_method_demarshal[PW_CLIENT_METHOD_NUM] =
{
	[PW_CLIENT_METHOD_ADD_LISTENER] = { NULL, 0, },
	[PW_CLIENT_METHOD_ERROR] = { &client_demarshal_error, PW_PERM_W, },
	[PW_CLIENT_METHOD_UPDATE_PROPERTIES] = { &client_demarshal_update_properties, PW_PERM_W, },
	[PW_CLIENT_METHOD_GET_PERMISSIONS] = { &client_demarshal_get_permissions, 0, },
	[PW_CLIENT_METHOD_UPDATE_PERMISSIONS] = { &client_demarshal_update_permissions, PW_PERM_W, },
};

static const struct pw_client_events pw_protocol_native_client_event_marshal = {
	PW_VERSION_CLIENT_EVENTS,
	.info = &client_marshal_info,
	.permissions = &client_marshal_permissions,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_event_demarshal[PW_CLIENT_EVENT_NUM] =
{
	[PW_CLIENT_EVENT_INFO] = { &client_demarshal_info, 0, },
	[PW_CLIENT_EVENT_PERMISSIONS] = { &client_demarshal_permissions, 0, }
};

static const struct pw_protocol_marshal pw_protocol_native_client_marshal = {
	PW_TYPE_INTERFACE_Client,
	PW_VERSION_CLIENT,
	0,
	PW_CLIENT_METHOD_NUM,
	PW_CLIENT_EVENT_NUM,
	.client_marshal = &pw_protocol_native_client_method_marshal,
	.server_demarshal = pw_protocol_native_client_method_demarshal,
	.server_marshal = &pw_protocol_native_client_event_marshal,
	.client_demarshal = pw_protocol_native_client_event_demarshal,
};


static const struct pw_link_methods pw_protocol_native_link_method_marshal = {
	PW_VERSION_LINK_METHODS,
	.add_listener = &link_method_marshal_add_listener,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_link_method_demarshal[PW_LINK_METHOD_NUM] =
{
	[PW_LINK_METHOD_ADD_LISTENER] = { NULL, 0, },
};

static const struct pw_link_events pw_protocol_native_link_event_marshal = {
	PW_VERSION_LINK_EVENTS,
	.info = &link_marshal_info,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_link_event_demarshal[PW_LINK_EVENT_NUM] =
{
	[PW_LINK_EVENT_INFO] = { &link_demarshal_info, 0, }
};

static const struct pw_protocol_marshal pw_protocol_native_link_marshal = {
	PW_TYPE_INTERFACE_Link,
	PW_VERSION_LINK,
	0,
	PW_LINK_METHOD_NUM,
	PW_LINK_EVENT_NUM,
	.client_marshal = &pw_protocol_native_link_method_marshal,
	.server_demarshal = pw_protocol_native_link_method_demarshal,
	.server_marshal = &pw_protocol_native_link_event_marshal,
	.client_demarshal = pw_protocol_native_link_event_demarshal,
};

void pw_protocol_native_init(struct pw_protocol *protocol)
{
	pw_protocol_add_marshal(protocol, &pw_protocol_native_core_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_registry_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_module_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_device_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_node_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_port_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_factory_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_link_marshal);
}
