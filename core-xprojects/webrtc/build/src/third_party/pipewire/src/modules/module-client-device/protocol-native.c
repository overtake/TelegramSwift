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

#include <errno.h>

#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/utils/result.h>

#include <pipewire/impl.h>

#include <extensions/protocol-native.h>

static inline void push_item(struct spa_pod_builder *b, const struct spa_dict_item *item)
{
	const char *str;
	spa_pod_builder_string(b, item->key);
	str = item->value;
	if (strstr(str, "pointer:") == str)
		str = "";
	spa_pod_builder_string(b, str);
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

static int device_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	pw_resource_add_object_listener(resource, listener, events, data);
	return 0;
}

static int device_demarshal_add_listener(void *object,
			const struct pw_protocol_native_message *msg)
{
	return -ENOTSUP;
}

static int device_marshal_sync(void *object, int seq)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, SPA_DEVICE_METHOD_SYNC, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)));

	return pw_protocol_native_end_resource(resource, b);
}

static int device_demarshal_sync(void *object,
			const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	int seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&seq)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct spa_device_methods, sync, 0, seq);
	return 0;
}

static int device_marshal_enum_params(void *object, int seq,
                            uint32_t id, uint32_t index, uint32_t max,
                            const struct spa_pod *filter)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, SPA_DEVICE_METHOD_ENUM_PARAMS, &msg);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(SPA_RESULT_RETURN_ASYNC(msg->seq)),
			SPA_POD_Id(id),
			SPA_POD_Int(index),
			SPA_POD_Int(max),
			SPA_POD_Pod(filter));

	return pw_protocol_native_end_resource(resource, b);
}

static int device_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, index, max;
	int seq;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&seq),
			SPA_POD_Id(&id),
			SPA_POD_Int(&index),
			SPA_POD_Int(&max),
			SPA_POD_Pod(&filter)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct spa_device_methods, enum_params, 0,
					seq, id, index, max, filter);
	return 0;
}

static int device_marshal_set_param(void *object,
                            uint32_t id, uint32_t flags,
                            const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, SPA_DEVICE_METHOD_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Id(id),
			SPA_POD_Int(flags),
			SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int device_demarshal_set_param(void *object, const struct pw_protocol_native_message *msg)
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

	pw_proxy_notify(proxy, struct spa_device_methods, set_param, 0,
					id, flags, param);
	return 0;
}

static void device_marshal_info(void *object,
		const struct spa_device_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, n_items;

	b = pw_protocol_native_begin_proxy(proxy, SPA_DEVICE_EVENT_INFO, NULL);

	spa_pod_builder_push_struct(b, &f[0]);
	if (info) {
		uint64_t change_mask = info->change_mask;

		change_mask &= SPA_DEVICE_CHANGE_MASK_FLAGS |
				SPA_DEVICE_CHANGE_MASK_PROPS |
				SPA_DEVICE_CHANGE_MASK_PARAMS;

		n_items = info->props ? info->props->n_items : 0;

		spa_pod_builder_push_struct(b, &f[1]);
		spa_pod_builder_add(b,
			    SPA_POD_Long(change_mask),
			    SPA_POD_Long(info->flags),
			    SPA_POD_Int(n_items), NULL);
		for (i = 0; i < n_items; i++)
			push_item(b, &info->props->items[i]);
		spa_pod_builder_add(b,
				    SPA_POD_Int(info->n_params), NULL);
		for (i = 0; i < info->n_params; i++) {
			spa_pod_builder_add(b,
					    SPA_POD_Id(info->params[i].id),
					    SPA_POD_Int(info->params[i].flags), NULL);
		}
		spa_pod_builder_pop(b, &f[1]);
	} else {
		spa_pod_builder_add(b,
				SPA_POD_Pod(NULL), NULL);
	}
	spa_pod_builder_pop(b, &f[0]);

	pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_info(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod *ipod;
	struct spa_device_info info = SPA_DEVICE_INFO_INIT(), *infop;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);

	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_PodStruct(&ipod)) < 0)
		return -EINVAL;

	if (ipod) {
		struct spa_pod_parser p2;
		struct spa_pod_frame f2;
		infop = &info;

		spa_pod_parser_pod(&p2, ipod);
		if (spa_pod_parser_push_struct(&p2, &f2) < 0 ||
		    spa_pod_parser_get(&p2,
				SPA_POD_Long(&info.change_mask),
				SPA_POD_Long(&info.flags),
				SPA_POD_Int(&props.n_items), NULL) < 0)
			return -EINVAL;

		info.change_mask &= SPA_DEVICE_CHANGE_MASK_FLAGS |
				SPA_DEVICE_CHANGE_MASK_PROPS |
				SPA_DEVICE_CHANGE_MASK_PARAMS;

		if (props.n_items > 0) {
			info.props = &props;

			props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
			if (parse_dict(&p2, &props) < 0)
				return -EINVAL;
		}
		if (spa_pod_parser_get(&p2,
				SPA_POD_Int(&info.n_params), NULL) < 0)
			return -EINVAL;

		if (info.n_params > 0) {
			info.params = alloca(info.n_params * sizeof(struct spa_param_info));
			for (i = 0; i < info.n_params; i++) {
				if (spa_pod_parser_get(&p2,
						SPA_POD_Id(&info.params[i].id),
						SPA_POD_Int(&info.params[i].flags), NULL) < 0)
					return -EINVAL;
			}
		}
	}
	else {
		infop = NULL;
	}
	pw_resource_notify(resource, struct spa_device_events, info, 0, infop);
	return 0;
}

static void device_marshal_result(void *object,
		int seq, int res, uint32_t type, const void *result)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];

	b = pw_protocol_native_begin_proxy(proxy, SPA_DEVICE_EVENT_RESULT, NULL);
	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_add(b,
			    SPA_POD_Int(seq),
			    SPA_POD_Int(res),
			    SPA_POD_Id(type),
			    NULL);

	switch (type) {
	case SPA_RESULT_TYPE_DEVICE_PARAMS:
	{
		const struct spa_result_device_params *r = result;
		spa_pod_builder_add(b,
			    SPA_POD_Id(r->id),
			    SPA_POD_Int(r->index),
			    SPA_POD_Int(r->next),
			    SPA_POD_Pod(r->param),
			    NULL);
		break;
	}
	default:
		break;
	}

	spa_pod_builder_pop(b, &f[0]);

	pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_result(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[1];
	int seq, res;
	uint32_t type;
	const void *result;
	struct spa_result_device_params params;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&seq),
			SPA_POD_Int(&res),
			SPA_POD_Id(&type),
			NULL) < 0)
		return -EINVAL;

	switch (type) {
	case SPA_RESULT_TYPE_DEVICE_PARAMS:
		if (spa_pod_parser_get(&prs,
				SPA_POD_Id(&params.id),
				SPA_POD_Int(&params.index),
				SPA_POD_Int(&params.next),
				SPA_POD_PodObject(&params.param),
				NULL) < 0)
			return -EINVAL;

		result = &params;
		break;

	default:
		result = NULL;
		break;
	}

	pw_resource_notify(resource, struct spa_device_events, result, 0, seq, res, type, result);
	return 0;
}

static void device_marshal_event(void *object, const struct spa_event *event)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, SPA_DEVICE_EVENT_EVENT, NULL);

	spa_pod_builder_add_struct(b,
			    SPA_POD_Pod(event));

	pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_event(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_event *event;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_PodObject(&event)) < 0)
		return -EINVAL;

	pw_resource_notify(resource, struct spa_device_events, event, 0, event);
	return 0;
}

static void device_marshal_object_info(void *object, uint32_t id,
                const struct spa_device_object_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, n_items;

	b = pw_protocol_native_begin_proxy(proxy, SPA_DEVICE_EVENT_OBJECT_INFO, NULL);
	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_add(b,
			    SPA_POD_Int(id),
			    NULL);
	if (info) {
		uint64_t change_mask = info->change_mask;

		change_mask &= SPA_DEVICE_OBJECT_CHANGE_MASK_FLAGS |
				SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;

		n_items = info->props ? info->props->n_items : 0;

		spa_pod_builder_push_struct(b, &f[1]);
		spa_pod_builder_add(b,
			    SPA_POD_String(info->type),
			    SPA_POD_Long(change_mask),
			    SPA_POD_Long(info->flags),
			    SPA_POD_Int(n_items), NULL);
		for (i = 0; i < n_items; i++)
			push_item(b, &info->props->items[i]);
		spa_pod_builder_pop(b, &f[1]);
	} else {
		spa_pod_builder_add(b,
				SPA_POD_Pod(NULL), NULL);
	}
	spa_pod_builder_pop(b, &f[0]);

	pw_protocol_native_end_proxy(proxy, b);
}

static int device_demarshal_object_info(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_device_object_info info = SPA_DEVICE_OBJECT_INFO_INIT(), *infop;
	struct spa_pod *ipod;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&id),
			SPA_POD_PodStruct(&ipod)) < 0)
		return -EINVAL;

	if (ipod) {
		struct spa_pod_parser p2;
		struct spa_pod_frame f2;
		infop = &info;

		spa_pod_parser_pod(&p2, ipod);
		if (spa_pod_parser_push_struct(&p2, &f2) < 0 ||
		    spa_pod_parser_get(&p2,
				SPA_POD_String(&info.type),
				SPA_POD_Long(&info.change_mask),
				SPA_POD_Long(&info.flags),
				SPA_POD_Int(&props.n_items), NULL) < 0)
			return -EINVAL;

		info.change_mask &= SPA_DEVICE_OBJECT_CHANGE_MASK_FLAGS |
				SPA_DEVICE_CHANGE_MASK_PROPS;

		if (props.n_items > 0) {
			info.props = &props;

			props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
			if (parse_dict(&p2, &props) < 0)
				return -EINVAL;
		}
	} else {
		infop = NULL;
	}

	pw_resource_notify(resource, struct spa_device_events, object_info, 0, id, infop);
	return 0;
}

static const struct spa_device_methods pw_protocol_native_device_method_marshal = {
	SPA_VERSION_DEVICE_METHODS,
	.add_listener = &device_marshal_add_listener,
	.sync = &device_marshal_sync,
	.enum_params = &device_marshal_enum_params,
	.set_param = &device_marshal_set_param
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_device_method_demarshal[SPA_DEVICE_METHOD_NUM] =
{
	[SPA_DEVICE_METHOD_ADD_LISTENER] = { &device_demarshal_add_listener, 0 },
	[SPA_DEVICE_METHOD_SYNC] = { &device_demarshal_sync, 0 },
	[SPA_DEVICE_METHOD_ENUM_PARAMS] = { &device_demarshal_enum_params, 0 },
	[SPA_DEVICE_METHOD_SET_PARAM] = { &device_demarshal_set_param, 0 },
};

static const struct spa_device_events pw_protocol_native_device_event_marshal = {
	SPA_VERSION_DEVICE_EVENTS,
	.info = &device_marshal_info,
	.result = &device_marshal_result,
	.event = &device_marshal_event,
	.object_info = &device_marshal_object_info,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_device_event_demarshal[SPA_DEVICE_EVENT_NUM] =
{
	[SPA_DEVICE_EVENT_INFO] = { &device_demarshal_info, 0 },
	[SPA_DEVICE_EVENT_RESULT] = { &device_demarshal_result, 0 },
	[SPA_DEVICE_EVENT_EVENT] = { &device_demarshal_event, 0 },
	[SPA_DEVICE_EVENT_OBJECT_INFO] = { &device_demarshal_object_info, 0 },
};

static const struct pw_protocol_marshal pw_protocol_native_client_device_marshal = {
	SPA_TYPE_INTERFACE_Device,
	SPA_VERSION_DEVICE,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	SPA_DEVICE_EVENT_NUM,
	SPA_DEVICE_METHOD_NUM,
	.client_marshal = &pw_protocol_native_device_event_marshal,
	.server_demarshal = pw_protocol_native_device_event_demarshal,
	.server_marshal = &pw_protocol_native_device_method_marshal,
	.client_demarshal = pw_protocol_native_device_method_demarshal,
};

struct pw_protocol *pw_protocol_native_ext_client_device_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);

	if (protocol == NULL)
		return NULL;

	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_device_marshal);

	return protocol;
}
