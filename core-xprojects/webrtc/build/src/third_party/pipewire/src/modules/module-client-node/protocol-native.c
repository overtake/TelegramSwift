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

#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/utils/result.h>

#include <pipewire/impl.h>

#include <extensions/protocol-native.h>
#include <extensions/client-node.h>

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

static int client_node_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_client_node_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static struct pw_node *
client_node_marshal_get_node(void *object, uint32_t version, size_t user_data_size)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct pw_proxy *res;
	uint32_t new_id;

	res = pw_proxy_new(object, PW_TYPE_INTERFACE_Node, version, user_data_size);
	if (res == NULL)
		return NULL;

	new_id = pw_proxy_get_id(res);

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_GET_NODE, NULL);

	spa_pod_builder_add_struct(b,
		       SPA_POD_Int(version),
		       SPA_POD_Int(new_id));

	pw_protocol_native_end_proxy(proxy, b);

	return (struct pw_node *) res;
}

static int
client_node_marshal_update(void *object,
			   uint32_t change_mask,
			   uint32_t n_params,
			   const struct spa_pod **params,
			   const struct spa_node_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, n_items, n_info_params;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_add(b,
			SPA_POD_Int(change_mask),
			SPA_POD_Int(n_params), NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b, SPA_POD_Pod(params[i]), NULL);

	if (info) {
		uint64_t change_mask = info->change_mask;

		change_mask &= SPA_NODE_CHANGE_MASK_FLAGS |
				SPA_NODE_CHANGE_MASK_PROPS |
				SPA_NODE_CHANGE_MASK_PARAMS;

		n_items = info->props && (change_mask & SPA_NODE_CHANGE_MASK_PROPS) ?
			info->props->n_items : 0;
		n_info_params = (change_mask & SPA_NODE_CHANGE_MASK_PARAMS) ?
			info->n_params : 0;

		spa_pod_builder_push_struct(b, &f[1]);
		spa_pod_builder_add(b,
				    SPA_POD_Int(info->max_input_ports),
				    SPA_POD_Int(info->max_output_ports),
				    SPA_POD_Long(change_mask),
				    SPA_POD_Long(info->flags),
				    SPA_POD_Int(n_items), NULL);
		for (i = 0; i < n_items; i++)
			push_item(b, &info->props->items[i]);
		spa_pod_builder_add(b,
				    SPA_POD_Int(n_info_params), NULL);
		for (i = 0; i < n_info_params; i++) {
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

	return pw_protocol_native_end_proxy(proxy, b);
}

static int
client_node_marshal_port_update(void *object,
				enum spa_direction direction,
				uint32_t port_id,
				uint32_t change_mask,
				uint32_t n_params,
				const struct spa_pod **params,
				const struct spa_port_info *info)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, n_items;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_PORT_UPDATE, NULL);

	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_add(b,
			    SPA_POD_Int(direction),
			    SPA_POD_Int(port_id),
			    SPA_POD_Int(change_mask),
			    SPA_POD_Int(n_params), NULL);

	for (i = 0; i < n_params; i++)
		spa_pod_builder_add(b,
				SPA_POD_Pod(params[i]), NULL);

	if (info) {
		uint64_t change_mask = info->change_mask;

		n_items = info->props ? info->props->n_items : 0;

		change_mask &= SPA_PORT_CHANGE_MASK_FLAGS |
				SPA_PORT_CHANGE_MASK_RATE |
				SPA_PORT_CHANGE_MASK_PROPS |
				SPA_PORT_CHANGE_MASK_PARAMS;

		spa_pod_builder_push_struct(b, &f[1]);
		spa_pod_builder_add(b,
				    SPA_POD_Long(change_mask),
				    SPA_POD_Long(info->flags),
				    SPA_POD_Int(info->rate.num),
				    SPA_POD_Int(info->rate.denom),
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

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_node_marshal_set_active(void *object, bool active)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_SET_ACTIVE, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Bool(active));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_node_marshal_event_method(void *object, const struct spa_event *event)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_EVENT, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Pod(event));

	return pw_protocol_native_end_proxy(proxy, b);
}

static int
client_node_marshal_port_buffers(void *object,
				enum spa_direction direction,
				uint32_t port_id,
				uint32_t mix_id,
				uint32_t n_buffers,
				struct spa_buffer **buffers)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f[2];
	uint32_t i, j;

	b = pw_protocol_native_begin_proxy(proxy, PW_CLIENT_NODE_METHOD_PORT_BUFFERS, NULL);

	spa_pod_builder_push_struct(b, &f[0]);
	spa_pod_builder_add(b,
			    SPA_POD_Int(direction),
			    SPA_POD_Int(port_id),
			    SPA_POD_Int(mix_id),
			    SPA_POD_Int(n_buffers), NULL);

	for (i = 0; i < n_buffers; i++) {
		struct spa_buffer *buf = buffers[i];

		spa_pod_builder_add(b,
				SPA_POD_Int(buf->n_datas), NULL);

		for (j = 0; j < buf->n_datas; j++) {
			struct spa_data *d = &buf->datas[j];
			spa_pod_builder_add(b,
					SPA_POD_Id(d->type),
					SPA_POD_Fd(pw_protocol_native_add_proxy_fd(proxy, d->fd)),
					SPA_POD_Int(d->flags),
					SPA_POD_Int(d->mapoffset),
					SPA_POD_Int(d->maxsize), NULL);
		}
	}
	spa_pod_builder_pop(b, &f[0]);

	return pw_protocol_native_end_proxy(proxy, b);
}

static int client_node_demarshal_transport(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t mem_id, offset, sz;
	int64_t ridx, widx;
	int readfd, writefd;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Fd(&ridx),
			SPA_POD_Fd(&widx),
			SPA_POD_Int(&mem_id),
			SPA_POD_Int(&offset),
			SPA_POD_Int(&sz)) < 0)
		return -EINVAL;

	readfd = pw_protocol_native_get_proxy_fd(proxy, ridx);
	writefd = pw_protocol_native_get_proxy_fd(proxy, widx);

	if (readfd < 0 || writefd < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, transport, 0,
								   readfd, writefd, mem_id,
								   offset, sz);
	return 0;
}

static int client_node_demarshal_set_param(void *object, const struct pw_protocol_native_message *msg)
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

	pw_proxy_notify(proxy, struct pw_client_node_events, set_param, 0, id, flags, param);
	return 0;
}

static int client_node_demarshal_event_event(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	const struct spa_event *event;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_PodObject(&event)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, event, 0, event);
	return 0;
}

static int client_node_demarshal_command(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	const struct spa_command *command;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_PodObject(&command)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, command, 0, command);
	return 0;
}

static int client_node_demarshal_add_port(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	int32_t direction, port_id;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0)
		return -EINVAL;

	if (spa_pod_parser_get(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id)) < 0)
		return -EINVAL;

	if (spa_pod_parser_push_struct(&prs, &f[1]) < 0)
		return -EINVAL;
	if (spa_pod_parser_get(&prs,
			 SPA_POD_Int(&props.n_items), NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	if (parse_dict(&prs, &props) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, add_port, 0, direction, port_id,
			props.n_items ? &props : NULL);
	return 0;
}

static int client_node_demarshal_remove_port(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	int32_t direction, port_id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, remove_port, 0, direction, port_id);
	return 0;
}

static int client_node_demarshal_port_set_param(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t direction, port_id, id, flags;
	const struct spa_pod *param = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id),
			SPA_POD_Id(&id),
			SPA_POD_Int(&flags),
			SPA_POD_PodObject(&param)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, port_set_param, 0,
			direction, port_id, id, flags, param);
	return 0;
}

static int client_node_demarshal_port_use_buffers(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t direction, port_id, mix_id, flags, n_buffers, data_id;
	struct pw_client_node_buffer *buffers;
	uint32_t i, j;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id),
			SPA_POD_Int(&mix_id),
			SPA_POD_Int(&flags),
			SPA_POD_Int(&n_buffers), NULL) < 0)
		return -EINVAL;

	buffers = alloca(sizeof(struct pw_client_node_buffer) * n_buffers);
	for (i = 0; i < n_buffers; i++) {
		struct spa_buffer *buf = buffers[i].buffer = alloca(sizeof(struct spa_buffer));

		if (spa_pod_parser_get(&prs,
				      SPA_POD_Int(&buffers[i].mem_id),
				      SPA_POD_Int(&buffers[i].offset),
				      SPA_POD_Int(&buffers[i].size),
				      SPA_POD_Int(&buf->n_metas), NULL) < 0)
			return -EINVAL;

		buf->metas = alloca(sizeof(struct spa_meta) * buf->n_metas);
		for (j = 0; j < buf->n_metas; j++) {
			struct spa_meta *m = &buf->metas[j];

			if (spa_pod_parser_get(&prs,
					      SPA_POD_Id(&m->type),
					      SPA_POD_Int(&m->size), NULL) < 0)
				return -EINVAL;
		}
		if (spa_pod_parser_get(&prs,
					SPA_POD_Int(&buf->n_datas), NULL) < 0)
			return -EINVAL;

		buf->datas = alloca(sizeof(struct spa_data) * buf->n_datas);
		for (j = 0; j < buf->n_datas; j++) {
			struct spa_data *d = &buf->datas[j];

			if (spa_pod_parser_get(&prs,
					      SPA_POD_Id(&d->type),
					      SPA_POD_Int(&data_id),
					      SPA_POD_Int(&d->flags),
					      SPA_POD_Int(&d->mapoffset),
					      SPA_POD_Int(&d->maxsize), NULL) < 0)
				return -EINVAL;

			d->data = SPA_UINT32_TO_PTR(data_id);
		}
	}
	pw_proxy_notify(proxy, struct pw_client_node_events, port_use_buffers, 0,
									  direction,
									  port_id,
									  mix_id,
									  flags,
									  n_buffers, buffers);
	return 0;
}

static int client_node_demarshal_port_set_io(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t direction, port_id, mix_id, id, memid, off, sz;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id),
			SPA_POD_Int(&mix_id),
			SPA_POD_Id(&id),
			SPA_POD_Int(&memid),
			SPA_POD_Int(&off),
			SPA_POD_Int(&sz)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, port_set_io, 0,
							direction, port_id, mix_id,
							id, memid,
							off, sz);
	return 0;
}

static int client_node_demarshal_set_activation(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t node_id, memid, off, sz;
	int64_t sigidx;
	int signalfd;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Int(&node_id),
			SPA_POD_Fd(&sigidx),
			SPA_POD_Int(&memid),
			SPA_POD_Int(&off),
			SPA_POD_Int(&sz)) < 0)
		return -EINVAL;

	signalfd = pw_protocol_native_get_proxy_fd(proxy, sigidx);

	pw_proxy_notify(proxy, struct pw_client_node_events, set_activation, 0,
							node_id,
							signalfd,
							memid,
							off, sz);
	return 0;
}

static int client_node_demarshal_set_io(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t id, memid, off, sz;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_Id(&id),
			SPA_POD_Int(&memid),
			SPA_POD_Int(&off),
			SPA_POD_Int(&sz)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_client_node_events, set_io, 0,
			id, memid, off, sz);
	return 0;
}

static int client_node_marshal_transport(void *object, int readfd, int writefd,
		uint32_t mem_id, uint32_t offset, uint32_t size)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_TRANSPORT, &msg);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Fd(pw_protocol_native_add_resource_fd(resource, readfd)),
			       SPA_POD_Fd(pw_protocol_native_add_resource_fd(resource, writefd)),
			       SPA_POD_Int(mem_id),
			       SPA_POD_Int(offset),
			       SPA_POD_Int(size));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_set_param(void *object, uint32_t id, uint32_t flags,
			      const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Id(id),
			       SPA_POD_Int(flags),
			       SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int client_node_marshal_event_event(void *object, const struct spa_event *event)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_EVENT, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Pod(event));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_command(void *object, const struct spa_command *command)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_COMMAND, NULL);

	spa_pod_builder_add_struct(b,
			SPA_POD_Pod(command));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_add_port(void *object,
			     enum spa_direction direction, uint32_t port_id,
			     const struct spa_dict *props)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_ADD_PORT, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			SPA_POD_Int(direction),
			SPA_POD_Int(port_id));
	push_dict(b, props);
	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_remove_port(void *object,
				enum spa_direction direction, uint32_t port_id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_REMOVE_PORT, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(direction),
			       SPA_POD_Int(port_id));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_port_set_param(void *object,
				   enum spa_direction direction,
				   uint32_t port_id,
				   uint32_t id,
				   uint32_t flags,
				   const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_PORT_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(direction),
			       SPA_POD_Int(port_id),
			       SPA_POD_Id(id),
			       SPA_POD_Int(flags),
			       SPA_POD_Pod(param));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_port_use_buffers(void *object,
				     enum spa_direction direction,
				     uint32_t port_id,
				     uint32_t mix_id,
				     uint32_t flags,
				     uint32_t n_buffers, struct pw_client_node_buffer *buffers)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, j;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_PORT_USE_BUFFERS, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			SPA_POD_Int(direction),
			SPA_POD_Int(port_id),
			SPA_POD_Int(mix_id),
			SPA_POD_Int(flags),
			SPA_POD_Int(n_buffers), NULL);

	for (i = 0; i < n_buffers; i++) {
		struct spa_buffer *buf = buffers[i].buffer;

		spa_pod_builder_add(b,
				    SPA_POD_Int(buffers[i].mem_id),
				    SPA_POD_Int(buffers[i].offset),
				    SPA_POD_Int(buffers[i].size),
				    SPA_POD_Int(buf->n_metas), NULL);

		for (j = 0; j < buf->n_metas; j++) {
			struct spa_meta *m = &buf->metas[j];
			spa_pod_builder_add(b,
					    SPA_POD_Id(m->type),
					    SPA_POD_Int(m->size), NULL);
		}
		spa_pod_builder_add(b,
				SPA_POD_Int(buf->n_datas), NULL);
		for (j = 0; j < buf->n_datas; j++) {
			struct spa_data *d = &buf->datas[j];
			spa_pod_builder_add(b,
					    SPA_POD_Id(d->type),
					    SPA_POD_Int(SPA_PTR_TO_UINT32(d->data)),
					    SPA_POD_Int(d->flags),
					    SPA_POD_Int(d->mapoffset),
					    SPA_POD_Int(d->maxsize), NULL);
		}
	}
	spa_pod_builder_pop(b, &f);

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_port_set_io(void *object,
				uint32_t direction,
				uint32_t port_id,
				uint32_t mix_id,
				uint32_t id,
				uint32_t memid,
				uint32_t offset,
				uint32_t size)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_PORT_SET_IO, NULL);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(direction),
			       SPA_POD_Int(port_id),
			       SPA_POD_Int(mix_id),
			       SPA_POD_Id(id),
			       SPA_POD_Int(memid),
			       SPA_POD_Int(offset),
			       SPA_POD_Int(size));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_set_activation(void *object,
				uint32_t node_id,
				int signalfd,
				uint32_t memid,
				uint32_t offset,
				uint32_t size)
{
	struct pw_protocol_native_message *msg;
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_SET_ACTIVATION, &msg);

	spa_pod_builder_add_struct(b,
			       SPA_POD_Int(node_id),
			       SPA_POD_Fd(pw_protocol_native_add_resource_fd(resource, signalfd)),
			       SPA_POD_Int(memid),
			       SPA_POD_Int(offset),
			       SPA_POD_Int(size));

	return pw_protocol_native_end_resource(resource, b);
}

static int
client_node_marshal_set_io(void *object,
			   uint32_t id,
			   uint32_t memid,
			   uint32_t offset,
			   uint32_t size)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE_EVENT_SET_IO, NULL);
	spa_pod_builder_add_struct(b,
			       SPA_POD_Id(id),
			       SPA_POD_Int(memid),
			       SPA_POD_Int(offset),
			       SPA_POD_Int(size));
	return pw_protocol_native_end_resource(resource, b);
}

static int client_node_demarshal_get_node(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	int32_t version, new_id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Int(&version),
				SPA_POD_Int(&new_id)) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_node_methods, get_node, 0,
			version, new_id);
}

static int client_node_demarshal_update(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	uint32_t change_mask, n_params;
	const struct spa_pod **params;
	struct spa_node_info info = SPA_NODE_INFO_INIT(), *infop = NULL;
	struct spa_pod *ipod;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs,
					SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs,
				SPA_POD_PodStruct(&ipod), NULL) < 0)
		return -EINVAL;

	if (ipod) {
		struct spa_pod_parser p2;
		struct spa_pod_frame f2;
		infop = &info;

		spa_pod_parser_pod(&p2, ipod);
		if (spa_pod_parser_push_struct(&p2, &f2) < 0 ||
		    spa_pod_parser_get(&p2,
				SPA_POD_Int(&info.max_input_ports),
				SPA_POD_Int(&info.max_output_ports),
				SPA_POD_Long(&info.change_mask),
				SPA_POD_Long(&info.flags),
				SPA_POD_Int(&props.n_items), NULL) < 0)
			return -EINVAL;

		info.change_mask &= SPA_NODE_CHANGE_MASK_FLAGS |
				SPA_NODE_CHANGE_MASK_PROPS |
				SPA_NODE_CHANGE_MASK_PARAMS;

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

	pw_resource_notify(resource, struct pw_client_node_methods, update, 0, change_mask,
									n_params,
									params, infop);
	return 0;
}

static int client_node_demarshal_port_update(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t i, direction, port_id, change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_port_info info = SPA_PORT_INFO_INIT(), *infop = NULL;
	struct spa_pod *ipod;
	struct spa_dict props = SPA_DICT_INIT(NULL, 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id),
			SPA_POD_Int(&change_mask),
			SPA_POD_Int(&n_params), NULL) < 0)
		return -EINVAL;

	params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs,
					SPA_POD_PodObject(&params[i]), NULL) < 0)
			return -EINVAL;

	if (spa_pod_parser_get(&prs,
				SPA_POD_PodStruct(&ipod), NULL) < 0)
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
				SPA_POD_Int(&info.rate.num),
				SPA_POD_Int(&info.rate.denom),
				SPA_POD_Int(&props.n_items), NULL) < 0)
			return -EINVAL;

		info.change_mask &= SPA_PORT_CHANGE_MASK_FLAGS |
				SPA_PORT_CHANGE_MASK_RATE |
				SPA_PORT_CHANGE_MASK_PROPS |
				SPA_PORT_CHANGE_MASK_PARAMS;

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

	pw_resource_notify(resource, struct pw_client_node_methods, port_update, 0, direction,
									     port_id,
									     change_mask,
									     n_params,
									     params, infop);
	return 0;
}

static int client_node_demarshal_set_active(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	bool active;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				SPA_POD_Bool(&active)) < 0)
		return -EINVAL;

	pw_resource_notify(resource, struct pw_client_node_methods, set_active, 0, active);
	return 0;
}

static int client_node_demarshal_event_method(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	const struct spa_event *event;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			SPA_POD_PodObject(&event)) < 0)
		return -EINVAL;

	pw_resource_notify(resource, struct pw_client_node_methods, event, 0, event);
	return 0;
}

static int client_node_demarshal_port_buffers(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t i, j, direction, port_id, mix_id, n_buffers;
	int64_t data_fd;
	struct spa_buffer **buffers = NULL;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			SPA_POD_Int(&direction),
			SPA_POD_Int(&port_id),
			SPA_POD_Int(&mix_id),
			SPA_POD_Int(&n_buffers), NULL) < 0)
		return -EINVAL;

	buffers = alloca(sizeof(struct spa_buffer*) * n_buffers);
	for (i = 0; i < n_buffers; i++) {
		struct spa_buffer *buf = buffers[i] = alloca(sizeof(struct spa_buffer));

		spa_zero(*buf);
		if (spa_pod_parser_get(&prs,
					SPA_POD_Int(&buf->n_datas), NULL) < 0)
			return -EINVAL;

		buf->datas = alloca(sizeof(struct spa_data) * buf->n_datas);
		for (j = 0; j < buf->n_datas; j++) {
			struct spa_data *d = &buf->datas[j];

			if (spa_pod_parser_get(&prs,
					      SPA_POD_Id(&d->type),
					      SPA_POD_Fd(&data_fd),
					      SPA_POD_Int(&d->flags),
					      SPA_POD_Int(&d->mapoffset),
					      SPA_POD_Int(&d->maxsize), NULL) < 0)
				return -EINVAL;

			d->fd = pw_protocol_native_get_resource_fd(resource, data_fd);
		}
	}

	pw_resource_notify(resource, struct pw_client_node_methods, port_buffers, 0,
			direction, port_id, mix_id, n_buffers, buffers);

	return 0;
}

static const struct pw_client_node_methods pw_protocol_native_client_node_method_marshal = {
	PW_VERSION_CLIENT_NODE_METHODS,
	.add_listener = &client_node_marshal_add_listener,
	.get_node = &client_node_marshal_get_node,
	.update = &client_node_marshal_update,
	.port_update = &client_node_marshal_port_update,
	.set_active = &client_node_marshal_set_active,
	.event = &client_node_marshal_event_method,
	.port_buffers = &client_node_marshal_port_buffers
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_node_method_demarshal[PW_CLIENT_NODE_METHOD_NUM] =
{
	[PW_CLIENT_NODE_METHOD_ADD_LISTENER] = { NULL, 0 },
	[PW_CLIENT_NODE_METHOD_GET_NODE] = { &client_node_demarshal_get_node, 0 },
	[PW_CLIENT_NODE_METHOD_UPDATE] = { &client_node_demarshal_update, 0 },
	[PW_CLIENT_NODE_METHOD_PORT_UPDATE] = { &client_node_demarshal_port_update, 0 },
	[PW_CLIENT_NODE_METHOD_SET_ACTIVE] = { &client_node_demarshal_set_active, 0 },
	[PW_CLIENT_NODE_METHOD_EVENT] = { &client_node_demarshal_event_method, 0 },
	[PW_CLIENT_NODE_METHOD_PORT_BUFFERS] = { &client_node_demarshal_port_buffers, 0 }
};

static const struct pw_client_node_events pw_protocol_native_client_node_event_marshal = {
	PW_VERSION_CLIENT_NODE_EVENTS,
	.transport = &client_node_marshal_transport,
	.set_param = &client_node_marshal_set_param,
	.set_io = &client_node_marshal_set_io,
	.event = &client_node_marshal_event_event,
	.command = &client_node_marshal_command,
	.add_port = &client_node_marshal_add_port,
	.remove_port = &client_node_marshal_remove_port,
	.port_set_param = &client_node_marshal_port_set_param,
	.port_use_buffers = &client_node_marshal_port_use_buffers,
	.port_set_io = &client_node_marshal_port_set_io,
	.set_activation = &client_node_marshal_set_activation,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_client_node_event_demarshal[PW_CLIENT_NODE_EVENT_NUM] =
{
	[PW_CLIENT_NODE_EVENT_TRANSPORT] = { &client_node_demarshal_transport, 0 },
	[PW_CLIENT_NODE_EVENT_SET_PARAM] = { &client_node_demarshal_set_param, 0 },
	[PW_CLIENT_NODE_EVENT_SET_IO] = { &client_node_demarshal_set_io, 0 },
	[PW_CLIENT_NODE_EVENT_EVENT] = { &client_node_demarshal_event_event, 0 },
	[PW_CLIENT_NODE_EVENT_COMMAND] = { &client_node_demarshal_command, 0 },
	[PW_CLIENT_NODE_EVENT_ADD_PORT] = { &client_node_demarshal_add_port, 0 },
	[PW_CLIENT_NODE_EVENT_REMOVE_PORT] = { &client_node_demarshal_remove_port, 0 },
	[PW_CLIENT_NODE_EVENT_PORT_SET_PARAM] = { &client_node_demarshal_port_set_param, 0 },
	[PW_CLIENT_NODE_EVENT_PORT_USE_BUFFERS] = { &client_node_demarshal_port_use_buffers, 0 },
	[PW_CLIENT_NODE_EVENT_PORT_SET_IO] = { &client_node_demarshal_port_set_io, 0 },
	[PW_CLIENT_NODE_EVENT_SET_ACTIVATION] = { &client_node_demarshal_set_activation, 0 }
};

static const struct pw_protocol_marshal pw_protocol_native_client_node_marshal = {
	PW_TYPE_INTERFACE_ClientNode,
	PW_VERSION_CLIENT_NODE,
	0,
	PW_CLIENT_NODE_METHOD_NUM,
	PW_CLIENT_NODE_EVENT_NUM,
	.client_marshal = &pw_protocol_native_client_node_method_marshal,
	.server_demarshal = &pw_protocol_native_client_node_method_demarshal,
	.server_marshal = &pw_protocol_native_client_node_event_marshal,
	.client_demarshal = pw_protocol_native_client_node_event_demarshal,
};

struct pw_protocol *pw_protocol_native_ext_client_node_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);

	if (protocol == NULL)
		return NULL;

	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_node_marshal);

	return protocol;
}
