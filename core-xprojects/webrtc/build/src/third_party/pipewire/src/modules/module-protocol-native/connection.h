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

#ifndef PIPEWIRE_PROTOCOL_NATIVE_CONNECTION_H
#define PIPEWIRE_PROTOCOL_NATIVE_CONNECTION_H

#ifdef __cplusplus
extern "C" {
#endif

#include <spa/utils/defs.h>
#include <spa/utils/hook.h>

#include <extensions/protocol-native.h>

struct pw_protocol_native_connection_events {
#define PW_VERSION_PROTOCOL_NATIVE_CONNECTION_EVENTS	0
	uint32_t version;

	void (*destroy) (void *data);

	void (*error) (void *data, int error);

	void (*need_flush) (void *data);

	void (*start) (void *data, uint32_t version);
};

/** \class pw_protocol_native_connection
 *
 * \brief Manages the connection between client and server
 *
 * The \ref pw_protocol_native_connection handles the connection between client
 * and server on a given socket.
 */
struct pw_protocol_native_connection {
	int fd;	/**< the socket */

	struct spa_hook_list listener_list;
};

static inline void
pw_protocol_native_connection_add_listener(struct pw_protocol_native_connection *conn,
					   struct spa_hook *listener,
					   const struct pw_protocol_native_connection_events *events,
					   void *data)
{
	spa_hook_list_append(&conn->listener_list, listener, events, data);
}

struct pw_protocol_native_connection *
pw_protocol_native_connection_new(struct pw_context *context, int fd);

int pw_protocol_native_connection_set_fd(struct pw_protocol_native_connection *conn, int fd);

void
pw_protocol_native_connection_destroy(struct pw_protocol_native_connection *conn);

int
pw_protocol_native_connection_get_next(struct pw_protocol_native_connection *conn,
				const struct pw_protocol_native_message **msg);

uint32_t pw_protocol_native_connection_add_fd(struct pw_protocol_native_connection *conn, int fd);
int pw_protocol_native_connection_get_fd(struct pw_protocol_native_connection *conn, uint32_t index);

struct spa_pod_builder *
pw_protocol_native_connection_begin(struct pw_protocol_native_connection *conn,
                                    uint32_t id, uint8_t opcode,
				    struct pw_protocol_native_message **msg);

int
pw_protocol_native_connection_end(struct pw_protocol_native_connection *conn,
                                  struct spa_pod_builder *builder);

int
pw_protocol_native_connection_flush(struct pw_protocol_native_connection *conn);

int
pw_protocol_native_connection_clear(struct pw_protocol_native_connection *conn);

void pw_protocol_native_connection_enter(struct pw_protocol_native_connection *conn);
void pw_protocol_native_connection_leave(struct pw_protocol_native_connection *conn);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PIPEWIRE_PROTOCOL_NATIVE_CONNECTION_H */
