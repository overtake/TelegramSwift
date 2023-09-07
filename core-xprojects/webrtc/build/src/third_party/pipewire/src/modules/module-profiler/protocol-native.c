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
#include <extensions/profiler.h>

static int profiler_proxy_marshal_add_listener(void *object,
			struct spa_hook *listener,
			const struct pw_profiler_events *events,
			void *data)
{
	struct pw_proxy *proxy = object;
	pw_proxy_add_object_listener(proxy, listener, events, data);
	return 0;
}

static int profiler_demarshal_add_listener(void *object,
			const struct pw_protocol_native_message *msg)
{
	return -ENOTSUP;
}

static void profiler_resource_marshal_profile(void *object, const struct spa_pod *pod)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_PROFILER_EVENT_PROFILE, NULL);

	spa_pod_builder_add_struct(b, SPA_POD_Pod(pod));

	pw_protocol_native_end_resource(resource, b);
}

static int profiler_proxy_demarshal_profile(void *object,
		const struct pw_protocol_native_message *msg)
{
	struct pw_proxy *proxy = object;
	struct spa_pod_parser prs;
	struct spa_pod *pod;

	spa_pod_parser_init(&prs, msg->data, msg->size);

	if (spa_pod_parser_get_struct(&prs, SPA_POD_Pod(&pod)) < 0)
		return -EINVAL;

	pw_proxy_notify(proxy, struct pw_profiler_events, profile, 0, pod);
	return 0;
}


static const struct pw_profiler_methods pw_protocol_native_profiler_client_method_marshal = {
	PW_VERSION_PROFILER_METHODS,
	.add_listener = &profiler_proxy_marshal_add_listener,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_profiler_server_method_demarshal[PW_PROFILER_METHOD_NUM] =
{
	[PW_PROFILER_METHOD_ADD_LISTENER] = { &profiler_demarshal_add_listener, 0 },
};

static const struct pw_profiler_events pw_protocol_native_profiler_server_event_marshal = {
	PW_VERSION_PROFILER_EVENTS,
	.profile = &profiler_resource_marshal_profile,
};

static const struct pw_protocol_native_demarshal
pw_protocol_native_profiler_client_event_demarshal[PW_PROFILER_EVENT_NUM] =
{
	[PW_PROFILER_EVENT_PROFILE] = { &profiler_proxy_demarshal_profile, 0 },
};

static const struct pw_protocol_marshal pw_protocol_native_profiler_marshal = {
	PW_TYPE_INTERFACE_Profiler,
	PW_VERSION_PROFILER,
	0,
	PW_PROFILER_METHOD_NUM,
	PW_PROFILER_EVENT_NUM,
	.client_marshal = &pw_protocol_native_profiler_client_method_marshal,
	.server_demarshal = pw_protocol_native_profiler_server_method_demarshal,
	.server_marshal = &pw_protocol_native_profiler_server_event_marshal,
	.client_demarshal = pw_protocol_native_profiler_client_event_demarshal,
};

int pw_protocol_native_ext_profiler_init(struct pw_context *context)
{
	struct pw_protocol *protocol;

	protocol = pw_context_find_protocol(context, PW_TYPE_INFO_PROTOCOL_Native);
	if (protocol == NULL)
		return -EPROTO;

	pw_protocol_add_marshal(protocol, &pw_protocol_native_profiler_marshal);
	return 0;
}
