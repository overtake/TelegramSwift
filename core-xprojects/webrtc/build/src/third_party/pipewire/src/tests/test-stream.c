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

#include <pipewire/pipewire.h>
#include <pipewire/main-loop.h>
#include <pipewire/stream.h>

#define TEST_FUNC(a,b,func)	\
do {				\
	a.func = b.func;	\
	spa_assert(SPA_PTRDIFF(&a.func, &a) == SPA_PTRDIFF(&b.func, &b)); \
} while(0)

static void test_abi(void)
{
	struct pw_stream_events ev;
	struct {
		uint32_t version;
		void (*destroy) (void *data);
		void (*state_changed) (void *data, enum pw_stream_state old,
			enum pw_stream_state state, const char *error);
	        void (*control_info) (void *data, uint32_t id, const struct pw_stream_control *control);
		void (*io_changed) (void *data, uint32_t id, void *area, uint32_t size);
		void (*param_changed) (void *data, uint32_t id, const struct spa_pod *param);
		void (*add_buffer) (void *data, struct pw_buffer *buffer);
		void (*remove_buffer) (void *data, struct pw_buffer *buffer);
		void (*process) (void *data);
		void (*drained) (void *data);
	} test = { PW_VERSION_STREAM_EVENTS, NULL };

	TEST_FUNC(ev, test, destroy);
	TEST_FUNC(ev, test, state_changed);
	TEST_FUNC(ev, test, control_info);
	TEST_FUNC(ev, test, io_changed);
	TEST_FUNC(ev, test, param_changed);
	TEST_FUNC(ev, test, add_buffer);
	TEST_FUNC(ev, test, remove_buffer);
	TEST_FUNC(ev, test, process);
	TEST_FUNC(ev, test, drained);

#if defined(__x86_64__) && defined(__LP64__)
	spa_assert(sizeof(struct pw_buffer) == 24);
	spa_assert(sizeof(struct pw_time) == 40);
#else
	fprintf(stderr, "%zd\n", sizeof(struct pw_buffer));
	fprintf(stderr, "%zd\n", sizeof(struct pw_time));
#endif

	spa_assert(PW_VERSION_STREAM_EVENTS == 0);
	spa_assert(sizeof(ev) == sizeof(test));

	spa_assert(PW_STREAM_STATE_ERROR == -1);
	spa_assert(PW_STREAM_STATE_UNCONNECTED == 0);
	spa_assert(PW_STREAM_STATE_CONNECTING == 1);
	spa_assert(PW_STREAM_STATE_PAUSED == 2);
	spa_assert(PW_STREAM_STATE_STREAMING == 3);

	spa_assert(pw_stream_state_as_string(PW_STREAM_STATE_ERROR) != NULL);
	spa_assert(pw_stream_state_as_string(PW_STREAM_STATE_UNCONNECTED) != NULL);
	spa_assert(pw_stream_state_as_string(PW_STREAM_STATE_CONNECTING) != NULL);
	spa_assert(pw_stream_state_as_string(PW_STREAM_STATE_PAUSED) != NULL);
	spa_assert(pw_stream_state_as_string(PW_STREAM_STATE_STREAMING) != NULL);
}

static void stream_destroy_error(void *data)
{
	spa_assert_not_reached();
}
static void stream_state_changed_error(void *data, enum pw_stream_state old,
		enum pw_stream_state state, const char *error)
{
	spa_assert_not_reached();
}
static void stream_io_changed_error(void *data, uint32_t id, void *area, uint32_t size)
{
	spa_assert_not_reached();
}
static void stream_param_changed_error(void *data, uint32_t id, const struct spa_pod *format)
{
	spa_assert_not_reached();
}
static void stream_add_buffer_error(void *data, struct pw_buffer *buffer)
{
	spa_assert_not_reached();
}
static void stream_remove_buffer_error(void *data, struct pw_buffer *buffer)
{
	spa_assert_not_reached();
}
static void stream_process_error(void *data)
{
	spa_assert_not_reached();
}
static void stream_drained_error(void *data)
{
	spa_assert_not_reached();
}

static const struct pw_stream_events stream_events_error =
{
	PW_VERSION_STREAM_EVENTS,
        .destroy = stream_destroy_error,
        .state_changed = stream_state_changed_error,
	.io_changed = stream_io_changed_error,
	.param_changed = stream_param_changed_error,
	.add_buffer = stream_add_buffer_error,
	.remove_buffer = stream_remove_buffer_error,
	.process = stream_process_error,
	.drained = stream_drained_error
};

static int destroy_count = 0;
static void stream_destroy_count(void *data)
{
	destroy_count++;
}
static void test_create(void)
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_core *core;
	struct pw_stream *stream;
	struct pw_stream_events stream_events = stream_events_error;
	struct spa_hook listener = { 0, };
	const char *error = NULL;
	struct pw_time tm;

	loop = pw_main_loop_new(NULL);
	context = pw_context_new(pw_main_loop_get_loop(loop), NULL, 12);
	spa_assert(context != NULL);
	core = pw_context_connect_self(context, NULL, 0);
	spa_assert(core != NULL);
	stream = pw_stream_new(core, "test", NULL);
	spa_assert(stream != NULL);
	pw_stream_add_listener(stream, &listener, &stream_events, stream);

	/* check state */
	spa_assert(pw_stream_get_state(stream, &error) == PW_STREAM_STATE_UNCONNECTED);
	spa_assert(error == NULL);
	/* check name */
	spa_assert(!strcmp(pw_stream_get_name(stream), "test"));

	/* check id, only when connected */
	spa_assert(pw_stream_get_node_id(stream) == SPA_ID_INVALID);

	spa_assert(pw_stream_get_time(stream, &tm) == 0);
	spa_assert(tm.now == 0);
	spa_assert(tm.rate.num == 0);
	spa_assert(tm.rate.denom == 0);
	spa_assert(tm.ticks == 0);
	spa_assert(tm.delay == 0);
	spa_assert(tm.queued == 0);

	spa_assert(pw_stream_dequeue_buffer(stream) == NULL);

	/* check destroy */
	destroy_count = 0;
	stream_events.destroy = stream_destroy_count;
	pw_stream_destroy(stream);
	spa_assert(destroy_count == 1);

	pw_context_destroy(context);
	pw_main_loop_destroy(loop);
}

static void test_properties(void)
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_core *core;
	const struct pw_properties *props;
	struct pw_stream *stream;
	struct pw_stream_events stream_events = stream_events_error;
	struct spa_hook listener = { NULL, };
	struct spa_dict_item items[3];

	loop = pw_main_loop_new(NULL);
	context = pw_context_new(pw_main_loop_get_loop(loop), NULL, 12);
	spa_assert(context != NULL);
	core = pw_context_connect_self(context, NULL, 0);
	spa_assert(core != NULL);
	stream = pw_stream_new(core, "test",
			pw_properties_new("foo", "bar",
					  "biz", "fuzz",
					  NULL));
	spa_assert(stream != NULL);
	pw_stream_add_listener(stream, &listener, &stream_events, stream);

	props = pw_stream_get_properties(stream);
	spa_assert(props != NULL);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "biz"), "fuzz"));
	spa_assert(pw_properties_get(props, "buzz") == NULL);

	/* remove foo */
	items[0] = SPA_DICT_ITEM_INIT("foo", NULL);
	/* change biz */
	items[1] = SPA_DICT_ITEM_INIT("biz", "buzz");
	/* add buzz */
	items[2] = SPA_DICT_ITEM_INIT("buzz", "frizz");
	pw_stream_update_properties(stream, &SPA_DICT_INIT(items, 3));

	spa_assert(props == pw_stream_get_properties(stream));
	spa_assert(pw_properties_get(props, "foo") == NULL);
	spa_assert(!strcmp(pw_properties_get(props, "biz"), "buzz"));
	spa_assert(!strcmp(pw_properties_get(props, "buzz"), "frizz"));

	/* check destroy */
	destroy_count = 0;
	stream_events.destroy = stream_destroy_count;
	pw_context_destroy(context);
	spa_assert(destroy_count == 1);

	pw_main_loop_destroy(loop);
}

int main(int argc, char *argv[])
{
	pw_init(&argc, &argv);

	test_abi();
	test_create();
	test_properties();

	return 0;
}
