/* PipeWire
 *
 * Copyright © 2017 Wim Taymans <wim.taymans@gmail.com>
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

#include <spa/pod/parser.h>
#include <spa/pod/builder.h>
#include <spa/utils/type-info.h>

#include "pipewire/impl.h"

#include "extensions/protocol-native.h"

#include "ext-client-node.h"

#include "transport.h"

#define PW_PROTOCOL_NATIVE_FLAG_REMAP        (1<<0)

extern uint32_t pw_protocol_native0_find_type(struct pw_impl_client *client, const char *type);
extern int pw_protocol_native0_pod_to_v2(struct pw_impl_client *client, const struct spa_pod *pod,
		struct spa_pod_builder *b);
extern struct spa_pod * pw_protocol_native0_pod_from_v2(struct pw_impl_client *client,
		const struct spa_pod *pod);
extern uint32_t pw_protocol_native0_type_to_v2(struct pw_impl_client *client,
		const struct spa_type_info *info, uint32_t type);

static void
client_node_marshal_add_mem(void *object,
			    uint32_t mem_id,
			    uint32_t type,
			    int memfd, uint32_t flags)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	const char *typename;

	switch (type) {
	case SPA_DATA_MemFd:
		typename = "Spa:Enum:DataType:Fd:MemFd";
		break;
	case SPA_DATA_DmaBuf:
		typename = "Spa:Enum:DataType:Fd:DmaBuf";
		break;
	default:
	case SPA_DATA_MemPtr:
		return;

	}
	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_ADD_MEM, NULL);

	spa_pod_builder_add_struct(b,
			       "i", mem_id,
			       "I", pw_protocol_native0_find_type(client, typename),
			       "i", pw_protocol_native_add_resource_fd(resource, memfd),
			       "i", flags);

	pw_protocol_native_end_resource(resource, b);
}

static void client_node_marshal_transport(void *object, uint32_t node_id, int readfd, int writefd,
					  struct pw_client_node0_transport *transport)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct pw_client_node0_transport_info info;

	pw_client_node0_transport_get_info(transport, &info);

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_TRANSPORT, NULL);

	spa_pod_builder_add_struct(b,
			       "i", node_id,
			       "i", pw_protocol_native_add_resource_fd(resource, readfd),
			       "i", pw_protocol_native_add_resource_fd(resource, writefd),
			       "i", pw_protocol_native_add_resource_fd(resource, info.memfd),
			       "i", info.offset,
			       "i", info.size);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_set_param(void *object, uint32_t seq, uint32_t id, uint32_t flags,
			      const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_SET_PARAM, NULL);

	spa_pod_builder_add_struct(b,
			       "i", seq,
			       "I", id,
			       "i", flags,
			       "P", param);

	pw_protocol_native_end_resource(resource, b);
}

static void client_node_marshal_event_event(void *object, const struct spa_event *event)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_EVENT, NULL);

	spa_pod_builder_add_struct(b, "P", event);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_command(void *object, uint32_t seq, const struct spa_command *command)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_COMMAND, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b, "i", seq, NULL);
	if (SPA_COMMAND_TYPE(command) == 0)
		spa_pod_builder_add(b, "P", command, NULL);
	else
		pw_protocol_native0_pod_to_v2(client, (struct spa_pod *)command, b);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_add_port(void *object,
			     uint32_t seq, enum spa_direction direction, uint32_t port_id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_ADD_PORT, NULL);

	spa_pod_builder_add_struct(b,
			       "i", seq,
			       "i", direction,
			       "i", port_id);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_remove_port(void *object,
				uint32_t seq, enum spa_direction direction, uint32_t port_id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_REMOVE_PORT, NULL);

	spa_pod_builder_add_struct(b,
			       "i", seq,
			       "i", direction,
			       "i", port_id);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_port_set_param(void *object,
				   uint32_t seq,
				   enum spa_direction direction,
				   uint32_t port_id,
				   uint32_t id,
				   uint32_t flags,
				   const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	const char *typename;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_PORT_SET_PARAM, NULL);

	switch (id) {
	case SPA_PARAM_Props:
		typename = "Spa:Enum:ParamId:Props";
		break;
	case SPA_PARAM_Format:
		typename = "Spa:Enum:ParamId:Format";
		break;
	default:
		return;
	}

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			"i", seq,
			"i", direction,
			"i", port_id,
			"I", pw_protocol_native0_find_type(client, typename),
			"i", flags, NULL);
	pw_protocol_native0_pod_to_v2(client, param, b);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_port_use_buffers(void *object,
				     uint32_t seq,
				     enum spa_direction direction,
				     uint32_t port_id,
				     uint32_t n_buffers, struct pw_client_node0_buffer *buffers)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, j;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_PORT_USE_BUFFERS, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", seq,
			    "i", direction,
			    "i", port_id,
			    "i", n_buffers, NULL);

	for (i = 0; i < n_buffers; i++) {
		struct spa_buffer *buf = buffers[i].buffer;

		spa_pod_builder_add(b,
				    "i", buffers[i].mem_id,
				    "i", buffers[i].offset,
				    "i", buffers[i].size,
				    "i", i,
				    "i", buf->n_metas, NULL);

		for (j = 0; j < buf->n_metas; j++) {
			struct spa_meta *m = &buf->metas[j];
			spa_pod_builder_add(b,
					    "I", pw_protocol_native0_type_to_v2(client, spa_type_meta_type, m->type),
					    "i", m->size, NULL);
		}
		spa_pod_builder_add(b, "i", buf->n_datas, NULL);
		for (j = 0; j < buf->n_datas; j++) {
			struct spa_data *d = &buf->datas[j];
			spa_pod_builder_add(b,
					    "I", pw_protocol_native0_type_to_v2(client, spa_type_data_type, d->type),
					    "i", SPA_PTR_TO_UINT32(d->data),
					    "i", d->flags,
					    "i", d->mapoffset,
					    "i", d->maxsize, NULL);
		}
	}
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_port_command(void *object,
				 uint32_t direction,
				 uint32_t port_id,
				 const struct spa_command *command)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_PORT_COMMAND, NULL);

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			"i", direction,
			"i", port_id, NULL);
	pw_protocol_native0_pod_to_v2(client, (struct spa_pod *)command, b);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void
client_node_marshal_port_set_io(void *object,
				uint32_t seq,
				uint32_t direction,
				uint32_t port_id,
				uint32_t id,
				uint32_t memid,
				uint32_t offset,
				uint32_t size)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_NODE0_EVENT_PORT_SET_IO, NULL);

	spa_pod_builder_add_struct(b,
			       "i", seq,
			       "i", direction,
			       "i", port_id,
			       "I", id,
			       "i", memid,
			       "i", offset,
			       "i", size);

	pw_protocol_native_end_resource(resource, b);
}


static int client_node_demarshal_done(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t seq, res;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			"i", &seq,
			"i", &res) < 0)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_node0_methods, done, 0, seq, res);
}

static int client_node_demarshal_update(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t change_mask, max_input_ports, max_output_ports, n_params;
	const struct spa_pod **params;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			"i", &change_mask,
			"i", &max_input_ports,
			"i", &max_output_ports,
			"i", &n_params, NULL) < 0)
		return -EINVAL;

	params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs, "O", &params[i], NULL) < 0)
			return -EINVAL;

	return pw_resource_notify(resource, struct pw_client_node0_methods, update, 0, change_mask,
									max_input_ports,
									max_output_ports,
									n_params,
									params);
}

static int client_node_demarshal_port_update(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	struct spa_pod_frame f[2];
	uint32_t i, direction, port_id, change_mask, n_params;
	const struct spa_pod **params = NULL;
	struct spa_port_info info = { 0 }, *infop = NULL;
	struct spa_dict props;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get(&prs,
			"i", &direction,
			"i", &port_id,
			"i", &change_mask,
			"i", &n_params, NULL) < 0)
		return -EINVAL;

	params = alloca(n_params * sizeof(struct spa_pod *));
	for (i = 0; i < n_params; i++)
		if (spa_pod_parser_get(&prs, "O", &params[i], NULL) < 0)
			return -EINVAL;


	if (spa_pod_parser_push_struct(&prs, &f[1]) >= 0) {
		infop = &info;

		if (spa_pod_parser_get(&prs,
				"i", &info.flags,
				"i", &info.rate,
				"i", &props.n_items, NULL) < 0)
			return -EINVAL;

		if (props.n_items > 0) {
			info.props = &props;

			props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
			for (i = 0; i < props.n_items; i++) {
				if (spa_pod_parser_get(&prs,
						"s", &props.items[i].key,
						"s", &props.items[i].value,
						NULL) < 0)
					return -EINVAL;
			}
		}
	}

	return pw_resource_notify(resource, struct pw_client_node0_methods, port_update, 0, direction,
									     port_id,
									     change_mask,
									     n_params,
									     params, infop);
}

static int client_node_demarshal_set_active(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	int active;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			"b", &active) < 0)
		return -EINVAL;

        return pw_resource_notify(resource, struct pw_client_node0_methods, set_active, 0, active);
}

static int client_node_demarshal_event_method(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	struct spa_event *event;
	int res;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			"O", &event) < 0)
		return -EINVAL;

	event = (struct spa_event*)pw_protocol_native0_pod_from_v2(client, (struct spa_pod *)event);

	res = pw_resource_notify(resource, struct pw_client_node0_methods, event, 0, event);
	free(event);

	return res;
}

static int client_node_demarshal_destroy(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	int res;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs, NULL) < 0)
		return -EINVAL;

	res = pw_resource_notify(resource, struct pw_client_node0_methods, destroy, 0);
	pw_resource_destroy(resource);
	return res;
}

static const struct pw_protocol_native_demarshal pw_protocol_native_client_node_method_demarshal[] = {
	{ &client_node_demarshal_done, 0, 0 },
	{ &client_node_demarshal_update, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP },
	{ &client_node_demarshal_port_update, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP },
	{ &client_node_demarshal_set_active, 0, 0 },
	{ &client_node_demarshal_event_method, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP },
	{ &client_node_demarshal_destroy, 0, 0 },
};

static const struct pw_client_node0_events pw_protocol_native_client_node_event_marshal = {
	PW_VERSION_CLIENT_NODE0_EVENTS,
	&client_node_marshal_add_mem,
	&client_node_marshal_transport,
	&client_node_marshal_set_param,
	&client_node_marshal_event_event,
	&client_node_marshal_command,
	&client_node_marshal_add_port,
	&client_node_marshal_remove_port,
	&client_node_marshal_port_set_param,
	&client_node_marshal_port_use_buffers,
	&client_node_marshal_port_command,
	&client_node_marshal_port_set_io,
};

static const struct pw_protocol_marshal pw_protocol_native_client_node_marshal = {
	PW_TYPE_INTERFACE_ClientNode,
	PW_VERSION_CLIENT_NODE0,
	PW_CLIENT_NODE0_METHOD_NUM,
	PW_CLIENT_NODE0_EVENT_NUM,
	0,
	NULL,
	.server_demarshal = &pw_protocol_native_client_node_method_demarshal,
	.server_marshal = &pw_protocol_native_client_node_event_marshal,
	NULL,
};

struct pw_protocol *pw_protocol_native_ext_client_node0_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);

	if (protocol == NULL)
		return NULL;

	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_node_marshal);

	return protocol;
}
