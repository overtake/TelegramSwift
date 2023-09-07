/* PipeWire
 *
 * Copyright © 2020 Collabora Ltd.
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

#include "pipewire/pipewire.h"
#include "extensions/session-manager.h"

struct object_data {
	struct spa_hook object_listener;
	struct spa_hook object_methods;
	struct spa_hook proxy_listener;
};

static void proxy_object_destroy(void *_data)
{
	struct object_data *data = _data;
	spa_hook_remove(&data->object_listener);
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.destroy = proxy_object_destroy,
};

struct pw_proxy *pw_core_endpoint_export(struct pw_core *core,
		const char *type, const struct spa_dict *props, void *object,
		size_t user_data_size)
{
	struct pw_endpoint *endpoint = object;
	struct spa_interface *remote_iface, *local_iface;
	struct pw_proxy *proxy;
	struct object_data *data;

	proxy = pw_core_create_object(core,
				    "endpoint",
				    PW_TYPE_INTERFACE_Endpoint,
				    PW_VERSION_ENDPOINT,
				    props,
				    user_data_size + sizeof(struct object_data));
        if (proxy == NULL)
		return NULL;

	data = pw_proxy_get_user_data(proxy);
	data = SPA_MEMBER(data, user_data_size, struct object_data);

	remote_iface = (struct spa_interface*)proxy;
	local_iface = (struct spa_interface*)endpoint;

	pw_proxy_install_marshal(proxy, true);

	pw_proxy_add_listener(proxy, &data->proxy_listener, &proxy_events, data);

	pw_proxy_add_object_listener(proxy, &data->object_methods,
			local_iface->cb.funcs, local_iface->cb.data);
	pw_endpoint_add_listener(endpoint, &data->object_listener,
			remote_iface->cb.funcs, remote_iface->cb.data);

	return proxy;
}

struct pw_proxy *pw_core_endpoint_stream_export(struct pw_core *core,
		const char *type, const struct spa_dict *props, void *object,
		size_t user_data_size)
{
	struct pw_endpoint_stream *endpoint_stream = object;
	struct spa_interface *remote_iface, *local_iface;
	struct pw_proxy *proxy;
	struct object_data *data;

	proxy = pw_core_create_object(core,
				    "endpoint-stream",
				    PW_TYPE_INTERFACE_EndpointStream,
				    PW_VERSION_ENDPOINT_STREAM,
				    props,
				    user_data_size + sizeof(struct object_data));
        if (proxy == NULL)
		return NULL;

	data = pw_proxy_get_user_data(proxy);
	data = SPA_MEMBER(data, user_data_size, struct object_data);

	remote_iface = (struct spa_interface*)proxy;
	local_iface = (struct spa_interface*)endpoint_stream;

	pw_proxy_install_marshal(proxy, true);

	pw_proxy_add_listener(proxy, &data->proxy_listener, &proxy_events, data);

	pw_proxy_add_object_listener(proxy, &data->object_methods,
			local_iface->cb.funcs, local_iface->cb.data);
	pw_endpoint_stream_add_listener(endpoint_stream, &data->object_listener,
			remote_iface->cb.funcs, remote_iface->cb.data);

	return proxy;
}

struct pw_proxy *pw_core_endpoint_link_export(struct pw_core *core,
		const char *type, const struct spa_dict *props, void *object,
		size_t user_data_size)
{
	struct pw_endpoint_link *endpoint_link = object;
	struct spa_interface *remote_iface, *local_iface;
	struct pw_proxy *proxy;
	struct object_data *data;

	proxy = pw_core_create_object(core,
				    "endpoint-link",
				    PW_TYPE_INTERFACE_EndpointLink,
				    PW_VERSION_ENDPOINT_LINK,
				    props,
				    user_data_size + sizeof(struct object_data));
        if (proxy == NULL)
		return NULL;

	data = pw_proxy_get_user_data(proxy);
	data = SPA_MEMBER(data, user_data_size, struct object_data);

	remote_iface = (struct spa_interface*)proxy;
	local_iface = (struct spa_interface*)endpoint_link;

	pw_proxy_install_marshal(proxy, true);

	pw_proxy_add_listener(proxy, &data->proxy_listener, &proxy_events, data);

	pw_proxy_add_object_listener(proxy, &data->object_methods,
			local_iface->cb.funcs, local_iface->cb.data);
	pw_endpoint_link_add_listener(endpoint_link, &data->object_listener,
			remote_iface->cb.funcs, remote_iface->cb.data);

	return proxy;
}

struct pw_proxy *pw_core_session_export(struct pw_core *core,
		const char *type, const struct spa_dict *props, void *object,
		size_t user_data_size)
{
	struct pw_session *session = object;
	struct spa_interface *remote_iface, *local_iface;
	struct pw_proxy *proxy;
	struct object_data *data;

	proxy = pw_core_create_object(core,
				    "session",
				    PW_TYPE_INTERFACE_Session,
				    PW_VERSION_SESSION,
				    props,
				    user_data_size + sizeof(struct object_data));
        if (proxy == NULL)
		return NULL;

	data = pw_proxy_get_user_data(proxy);
	data = SPA_MEMBER(data, user_data_size, struct object_data);

	remote_iface = (struct spa_interface*)proxy;
	local_iface = (struct spa_interface*)session;

	pw_proxy_install_marshal(proxy, true);

	pw_proxy_add_listener(proxy, &data->proxy_listener, &proxy_events, data);

	pw_proxy_add_object_listener(proxy, &data->object_methods,
			local_iface->cb.funcs, local_iface->cb.data);
	pw_session_add_listener(session, &data->object_listener,
			remote_iface->cb.funcs, remote_iface->cb.data);

	return proxy;
}
