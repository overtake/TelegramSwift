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

#include <pipewire/pipewire.h>

#include <extensions/protocol-native.h>
#include <extensions/metadata.h>

static int metadata_resource_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_metadata_events *events,
			void *data)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	pw_resource_add_object_listener(resource, listener, events, data);

	b = pw_protocol_native_begin_resource(resource, PW_METADATA_METHOD_ADD_LISTENER, NULL);
	return pw_protocol_native_end_resource(resource, b);
}

static int metadata_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_metadata_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int metadata_resource_demarshal_add_listener(void *object,
			const struct pw_protocol_native_message *msg)
{
	return -ENOTSUP;
}

static const struct pw_metadata_events pw_protocol_native_metadata_client_event_marshal;

static int metadata_proxy_demarshal_add_listener(void *object,
			const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_hook listener;
	int res;

	spa_zero(listener);
	res = pw_proxy_notify(proxy, struct pw_metadata_methods, add_listener, 0,
			&listener, &pw_protocol_native_metadata_client_event_marshal, object);
	spa_hook_remove(&listener);

	return res;
}

static void metadata_marshal_set_property(struct spa_pod_builder *b, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	spa_pod_builder_add_struct(b,
			SPA_POD_Int(subject),
			SPA_POD_String(key),
			SPA_POD_String(type),
			SPA_POD_String(value));
}

static int metadata_proxy_marshal_set_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_proxy(proxy, PW_METADATA_METHOD_SET_PROPERTY, NULL);
	metadata_marshal_set_property(b, subject, key, type, value);
	return pw_protocol_native_end_proxy(proxy, b);
}
static int metadata_resource_marshal_set_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_resource(resource, PW_METADATA_METHOD_SET_PROPERTY, NULL);
	metadata_marshal_set_property(b, subject, key, type, value);
	return pw_protocol_native_end_resource(resource, b);
}

static int metadata_demarshal_set_property(struct spa_pod_parser *prs, uint32_t *subject,
		char **key, char **type, char **value)
{
	return spa_pod_parser_get_struct(prs,
			SPA_POD_Int(subject),
			SPA_POD_String(key),
			SPA_POD_String(type),
			SPA_POD_String(value));
}

static int metadata_proxy_demarshal_set_property(void *object,
			const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t subject;
	char *key, *type, *value;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (metadata_demarshal_set_property(&prs, &subject, &key, &type, &value) < 0)
		return -EINVAL;
	return pw_proxy_notify(proxy, struct pw_metadata_methods, set_property, 0, subject, key, type, value);
}

static int metadata_resource_demarshal_set_property(void *object,
			const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t subject;
	char *key, *type, *value;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (metadata_demarshal_set_property(&prs, &subject, &key, &type, &value) < 0)
		return -EINVAL;
	return pw_resource_notify(resource, struct pw_metadata_methods, set_property, 0, subject, key, type, value);
}

static void metadata_marshal_clear(struct spa_pod_builder *b)
{
	spa_pod_builder_add_struct(b, SPA_POD_None());
}

static int metadata_proxy_marshal_clear(void *object)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_proxy(proxy, PW_METADATA_METHOD_CLEAR, NULL);
	metadata_marshal_clear(b);
	return pw_protocol_native_end_proxy(proxy, b);
}
static int metadata_resource_marshal_clear(void *object)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_resource(resource, PW_METADATA_METHOD_CLEAR, NULL);
	metadata_marshal_clear(b);
	return pw_protocol_native_end_resource(resource, b);
}

static int metadata_proxy_demarshal_clear(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs, SPA_POD_None()) < 0)
		return -EINVAL;
	pw_proxy_notify(proxy, struct pw_metadata_methods, clear, 0);
	return 0;
}

static int metadata_resource_demarshal_clear(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs, SPA_POD_None()) < 0)
		return -EINVAL;
	pw_resource_notify(resource, struct pw_metadata_methods, clear, 0);
	return 0;
}

static void metadata_marshal_property(struct spa_pod_builder *b, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	spa_pod_builder_add_struct(b,
			SPA_POD_Int(subject),
			SPA_POD_String(key),
			SPA_POD_String(type),
			SPA_POD_String(value));
}

static int metadata_proxy_marshal_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_proxy(proxy, PW_METADATA_EVENT_PROPERTY, NULL);
	metadata_marshal_property(b, subject, key, type, value);
	return pw_protocol_native_end_proxy(proxy, b);
}

static int metadata_resource_marshal_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	b = pw_protocol_native_begin_resource(resource, PW_METADATA_EVENT_PROPERTY, NULL);
	metadata_marshal_property(b, subject, key, type, value);
	return pw_protocol_native_end_resource(resource, b);
}

static int metadata_demarshal_property(struct spa_pod_parser *prs,
		uint32_t *subject, char **key, char **type, char **value)
{
	return spa_pod_parser_get_struct(prs,
			SPA_POD_Int(subject),
			SPA_POD_String(key),
			SPA_POD_String(type),
			SPA_POD_String(value));
}

static int metadata_proxy_demarshal_property(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	uint32_t subject;
	char *key, *type, *value;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (metadata_demarshal_property(&prs,
				&subject, &key, &type, &value) < 0)
		return -EINVAL;
	pw_proxy_notify(proxy, struct pw_metadata_events, property, 0, subject, key, type, value);
	return 0;
}

static int metadata_resource_demarshal_property(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t subject;
	char *key, *type, *value;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (metadata_demarshal_property(&prs,
				&subject, &key, &type, &value) < 0)
		return -EINVAL;
	pw_resource_notify(resource, struct pw_metadata_events, property, 0, subject, key, type, value);
	return 0;
}

static const struct pw_metadata_methods pw_protocol_native_metadata_client_method_marshal = {
	PW_VERSION_METADATA_METHODS,
	.add_listener = &metadata_proxy_marshal_add_listener,
	.set_property = &metadata_proxy_marshal_set_property,
	.clear = &metadata_proxy_marshal_clear,
};
static const struct pw_metadata_methods pw_protocol_native_metadata_server_method_marshal = {
	PW_VERSION_METADATA_METHODS,
	.add_listener = &metadata_resource_marshal_add_listener,
	.set_property = &metadata_resource_marshal_set_property,
	.clear = &metadata_resource_marshal_clear,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_metadata_client_method_demarshal[PW_METADATA_METHOD_NUM] =
{
	[PW_METADATA_METHOD_ADD_LISTENER] = { &metadata_proxy_demarshal_add_listener, 0 },
	[PW_METADATA_METHOD_SET_PROPERTY] = { &metadata_proxy_demarshal_set_property, PW_PERM_W },
	[PW_METADATA_METHOD_CLEAR] = { &metadata_proxy_demarshal_clear, PW_PERM_W },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_metadata_server_method_demarshal[PW_METADATA_METHOD_NUM] =
{
	[PW_METADATA_METHOD_ADD_LISTENER] = { &metadata_resource_demarshal_add_listener, 0 },
	[PW_METADATA_METHOD_SET_PROPERTY] = { &metadata_resource_demarshal_set_property, PW_PERM_W },
	[PW_METADATA_METHOD_CLEAR] = { &metadata_resource_demarshal_clear, PW_PERM_W },
};

static const struct pw_metadata_events pw_protocol_native_metadata_client_event_marshal = {
	PW_VERSION_METADATA_EVENTS,
	.property = &metadata_proxy_marshal_property,
};

static const struct pw_metadata_events pw_protocol_native_metadata_server_event_marshal = {
	PW_VERSION_METADATA_EVENTS,
	.property = &metadata_resource_marshal_property,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_metadata_client_event_demarshal[PW_METADATA_EVENT_NUM] =
{
	[PW_METADATA_EVENT_PROPERTY] = { &metadata_proxy_demarshal_property, 0 },
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_metadata_server_event_demarshal[PW_METADATA_EVENT_NUM] =
{
	[PW_METADATA_EVENT_PROPERTY] = { &metadata_resource_demarshal_property, 0 },
};

static const struct pw_protocol_marshal pw_protocol_native_metadata_marshal = {
	PW_TYPE_INTERFACE_Metadata,
	PW_VERSION_METADATA,
	0,
	PW_METADATA_METHOD_NUM,
	PW_METADATA_EVENT_NUM,
	.client_marshal = &pw_protocol_native_metadata_client_method_marshal,
	.server_demarshal = pw_protocol_native_metadata_server_method_demarshal,
	.server_marshal = &pw_protocol_native_metadata_server_event_marshal,
	.client_demarshal = pw_protocol_native_metadata_client_event_demarshal,
};

static const struct pw_protocol_marshal pw_protocol_native_metadata_impl_marshal = {
	PW_TYPE_INTERFACE_Metadata,
	PW_VERSION_METADATA,
	PW_PROTOCOL_MARSHAL_FLAG_IMPL,
	PW_METADATA_EVENT_NUM,
	PW_METADATA_METHOD_NUM,
	.client_marshal = &pw_protocol_native_metadata_client_event_marshal,
	.server_demarshal = pw_protocol_native_metadata_server_event_demarshal,
	.server_marshal = &pw_protocol_native_metadata_server_method_marshal,
	.client_demarshal = pw_protocol_native_metadata_client_method_demarshal,
};

int pw_protocol_native_ext_metadata_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);
	if (protocol == NULL)
		return -EPROTO;

	pw_protocol_add_marshal(protocol, &pw_protocol_native_metadata_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_metadata_impl_marshal);
	return 0;
}
