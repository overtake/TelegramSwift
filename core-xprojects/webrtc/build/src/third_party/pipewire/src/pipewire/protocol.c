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

#include <spa/debug/types.h>

#include <pipewire/protocol.h>
#include <pipewire/private.h>
#include <pipewire/type.h>

#define NAME "protocol"

/** \cond */
struct impl {
	struct pw_protocol this;
};

struct marshal {
	struct spa_list link;
	const struct pw_protocol_marshal *marshal;
};
/** \endcond */

SPA_EXPORT
struct pw_protocol *pw_protocol_new(struct pw_context *context,
				    const char *name,
				    size_t user_data_size)
{
	struct pw_protocol *protocol;

	protocol = calloc(1, sizeof(struct impl) + user_data_size);
	if (protocol == NULL)
		return NULL;

	protocol->context = context;
	protocol->name = strdup(name);

	spa_list_init(&protocol->marshal_list);
	spa_list_init(&protocol->server_list);
	spa_list_init(&protocol->client_list);
	spa_hook_list_init(&protocol->listener_list);

	if (user_data_size > 0)
		protocol->user_data = SPA_MEMBER(protocol, sizeof(struct impl), void);

	spa_list_append(&context->protocol_list, &protocol->link);

	pw_log_debug(NAME" %p: Created protocol %s", protocol, name);

	return protocol;
}

SPA_EXPORT
struct pw_context *pw_protocol_get_context(struct pw_protocol *protocol)
{
	return protocol->context;
}

SPA_EXPORT
void *pw_protocol_get_user_data(struct pw_protocol *protocol)
{
	return protocol->user_data;
}

SPA_EXPORT
const struct pw_protocol_implementation *
pw_protocol_get_implementation(struct pw_protocol *protocol)
{
	return protocol->implementation;
}

SPA_EXPORT
const void *
pw_protocol_get_extension(struct pw_protocol *protocol)
{
	return protocol->extension;
}

SPA_EXPORT
void pw_protocol_destroy(struct pw_protocol *protocol)
{
	struct impl *impl = SPA_CONTAINER_OF(protocol, struct impl, this);
	struct marshal *marshal, *t1;
	struct pw_protocol_server *server;
	struct pw_protocol_client *client;

	pw_log_debug(NAME" %p: destroy", protocol);
	pw_protocol_emit_destroy(protocol);

	spa_hook_list_clean(&protocol->listener_list);

	spa_list_remove(&protocol->link);

	spa_list_consume(server, &protocol->server_list, link)
		pw_protocol_server_destroy(server);

	spa_list_consume(client, &protocol->client_list, link)
		pw_protocol_client_destroy(client);

	spa_list_for_each_safe(marshal, t1, &protocol->marshal_list, link)
		free(marshal);

	free(protocol->name);

	free(impl);
}

SPA_EXPORT
void pw_protocol_add_listener(struct pw_protocol *protocol,
                              struct spa_hook *listener,
                              const struct pw_protocol_events *events,
                              void *data)
{
	spa_hook_list_append(&protocol->listener_list, listener, events, data);
}

SPA_EXPORT
int
pw_protocol_add_marshal(struct pw_protocol *protocol,
			const struct pw_protocol_marshal *marshal)
{
	struct marshal *impl;

	impl = calloc(1, sizeof(struct marshal));
	if (impl == NULL)
		return -errno;

	impl->marshal = marshal;

	spa_list_append(&protocol->marshal_list, &impl->link);

	pw_log_debug(NAME" %p: Add marshal %s/%d to protocol %s", protocol,
			marshal->type, marshal->version, protocol->name);

	return 0;
}

SPA_EXPORT
const struct pw_protocol_marshal *
pw_protocol_get_marshal(struct pw_protocol *protocol, const char *type, uint32_t version, uint32_t flags)
{
	struct marshal *impl;

	spa_list_for_each(impl, &protocol->marshal_list, link) {
		if (strcmp(impl->marshal->type, type) == 0 &&
		    impl->marshal->version == version &&
		    (impl->marshal->flags & flags) == flags)
                        return impl->marshal;
        }
	pw_log_debug(NAME" %p: No marshal %s/%d for protocol %s", protocol,
			type, version, protocol->name);
	return NULL;
}

SPA_EXPORT
struct pw_protocol *pw_context_find_protocol(struct pw_context *context, const char *name)
{
	struct pw_protocol *protocol;

	spa_list_for_each(protocol, &context->protocol_list, link) {
		if (strcmp(protocol->name, name) == 0)
			return protocol;
	}
	return NULL;
}
