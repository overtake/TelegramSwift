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

#include <sys/socket.h>

#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/utils/result.h>

#include <pipewire/pipewire.h>

#include "connection.h"

static void test_create(struct pw_protocol_native_connection *conn)
{
	const struct pw_protocol_native_message *msg;
	int res;

	res = pw_protocol_native_connection_get_next(conn, &msg);
	spa_assert(res != 1);

	res = pw_protocol_native_connection_get_fd(conn, 0);
	spa_assert(res == -ENOENT);

	res = pw_protocol_native_connection_flush(conn);
	spa_assert(res == 0);

	res = pw_protocol_native_connection_clear(conn);
	spa_assert(res == 0);
}

static void write_message(struct pw_protocol_native_connection *conn, int fd)
{
	struct pw_protocol_native_message *msg;
	struct spa_pod_builder *b;
	int seq = -1, res;

	b = pw_protocol_native_connection_begin(conn, 1, 5, &msg);
	spa_assert(b != NULL);
	spa_assert(msg->seq != -1);

	seq = SPA_RESULT_RETURN_ASYNC(msg->seq);

	spa_pod_builder_add_struct(b,
			SPA_POD_Int(42),
			SPA_POD_Id(SPA_TYPE_Object),
			SPA_POD_Int(pw_protocol_native_connection_add_fd(conn, fd)));

	res = pw_protocol_native_connection_end(conn, b);
	spa_assert(seq == res);
}

static int read_message(struct pw_protocol_native_connection *conn,
                        const struct pw_protocol_native_message **pmsg)
{
        struct spa_pod_parser prs;
	const struct pw_protocol_native_message *msg;
	int res, fd;
	uint32_t v_int, v_id, fdidx;

	res = pw_protocol_native_connection_get_next(conn, &msg);
	if (res != 1) {
		pw_log_error("got %d", res);
		return -1;
	}

	if (pmsg)
		*pmsg = msg;

	spa_assert(msg->opcode == 5);
	spa_assert(msg->id == 1);
	spa_assert(msg->data != NULL);
	spa_assert(msg->size > 0);

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
                        SPA_POD_Int(&v_int),
                        SPA_POD_Id(&v_id),
                        SPA_POD_Int(&fdidx)) < 0)
                spa_assert_not_reached();

	fd = pw_protocol_native_connection_get_fd(conn, fdidx);
	spa_assert(fd != -ENOENT);
	pw_log_debug("got fd %d %d", fdidx, fd);
	return 0;
}

static void test_read_write(struct pw_protocol_native_connection *in,
		struct pw_protocol_native_connection *out)
{
	write_message(out, 1);
	pw_protocol_native_connection_flush(out);
	write_message(out, 2);
	pw_protocol_native_connection_flush(out);
	spa_assert(read_message(in, NULL) == 0);
	spa_assert(read_message(in, NULL) == 0);
	spa_assert(read_message(in, NULL) == -1);

	write_message(out, 1);
	write_message(out, 2);
	pw_protocol_native_connection_flush(out);
	spa_assert(read_message(in, NULL) == 0);
	spa_assert(read_message(in, NULL) == 0);
	spa_assert(read_message(in, NULL) == -1);
}

static void test_reentering(struct pw_protocol_native_connection *in,
		struct pw_protocol_native_connection *out)
{
	const struct pw_protocol_native_message *msg1, *msg2;
	int i;

#define READ_MSG(idx) \
	spa_assert(read_message(in, &msg ## idx) == 0); \
	spa_assert((msg ## idx)->n_fds == 1); \
	spa_assert((msg ## idx)->size < sizeof(buf ## idx)); \
	fd ## idx = (msg ## idx)->fds[0]; \
	memcpy(buf ## idx, (msg ## idx)->data, (msg ## idx)->size); \
	size ## idx = (msg ## idx)->size

#define CHECK_MSG(idx) \
	spa_assert((msg ## idx)->fds[0] == fd ## idx); \
	spa_assert(memcmp((msg ## idx)->data, buf ## idx, size ## idx) == 0)

	for (i = 0; i < 50; ++i) {
		int fd1, fd2;
		char buf1[1024], buf2[1024];
		int size1, size2;

		write_message(out, 1);
		write_message(out, 2);
		write_message(out, 1);
		write_message(out, 2);
		write_message(out, 1);
		pw_protocol_native_connection_flush(out);

		READ_MSG(1);
		pw_protocol_native_connection_enter(in); /* 1 */
		READ_MSG(2);
		CHECK_MSG(1);
		pw_protocol_native_connection_enter(in); /* 2 */
		pw_protocol_native_connection_leave(in); /* 2 */
		CHECK_MSG(1);
		CHECK_MSG(2);
		pw_protocol_native_connection_enter(in); /* 2 */
		pw_protocol_native_connection_enter(in); /* 3 */
		spa_assert(read_message(in, NULL) == 0);
		CHECK_MSG(1);
		CHECK_MSG(2);
		pw_protocol_native_connection_leave(in); /* 3 */
		spa_assert(read_message(in, NULL) == 0);
		CHECK_MSG(1);
		CHECK_MSG(2);
		pw_protocol_native_connection_leave(in); /* 2 */
		CHECK_MSG(2);
		spa_assert(read_message(in, NULL) == 0);
		CHECK_MSG(1);
		pw_protocol_native_connection_leave(in); /* 1 */
		CHECK_MSG(1);
	}
}

int main(int argc, char *argv[])
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_protocol_native_connection *in, *out;
	int fds[2];

	pw_init(&argc, &argv);

	loop = pw_main_loop_new(NULL);
	context = pw_context_new(pw_main_loop_get_loop(loop), NULL, 0);

	if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) < 0) {
		spa_assert_not_reached();
		return -1;
	}

	in = pw_protocol_native_connection_new(context, fds[0]);
	spa_assert(in != NULL);
	out = pw_protocol_native_connection_new(context, fds[1]);
	spa_assert(out != NULL);

	test_create(in);
	test_create(out);
	test_read_write(in, out);
	test_reentering(in, out);

	pw_protocol_native_connection_destroy(in);
	pw_protocol_native_connection_destroy(out);
	pw_context_destroy(context);
	pw_main_loop_destroy(loop);

	return 0;
}
