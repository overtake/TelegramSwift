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

#include <spa/support/dbus.h>
#include <spa/support/cpu.h>

#include <pipewire/pipewire.h>
#include <pipewire/global.h>

#define TEST_FUNC(a,b,func)	\
do {				\
	a.func = b.func;	\
	spa_assert(SPA_PTRDIFF(&a.func, &a) == SPA_PTRDIFF(&b.func, &b)); \
} while(0)

static void test_abi(void)
{
	struct pw_context_events ev;
	struct {
		uint32_t version;
		void (*destroy) (void *data);
		void (*free) (void *data);
		void (*check_access) (void *data, struct pw_impl_client *client);
		void (*global_added) (void *data, struct pw_global *global);
		void (*global_removed) (void *data, struct pw_global *global);
	} test = { PW_VERSION_CONTEXT_EVENTS, NULL };

	TEST_FUNC(ev, test, destroy);
	TEST_FUNC(ev, test, free);
	TEST_FUNC(ev, test, check_access);
	TEST_FUNC(ev, test, global_added);
	TEST_FUNC(ev, test, global_removed);

	spa_assert(PW_VERSION_CONTEXT_EVENTS == 0);
	spa_assert(sizeof(ev) == sizeof(test));
}

static void context_destroy_error(void *data)
{
	spa_assert_not_reached();
}
static void context_free_error(void *data)
{
	spa_assert_not_reached();
}
static void context_check_access_error(void *data, struct pw_impl_client *client)
{
	spa_assert_not_reached();
}
static void context_global_added_error(void *data, struct pw_global *global)
{
	spa_assert_not_reached();
}
static void context_global_removed_error(void *data, struct pw_global *global)
{
	spa_assert_not_reached();
}

static const struct pw_context_events context_events_error =
{
	PW_VERSION_CONTEXT_EVENTS,
	.destroy = context_destroy_error,
	.free = context_free_error,
	.check_access = context_check_access_error,
	.global_added = context_global_added_error,
	.global_removed = context_global_removed_error,
};

static int destroy_count = 0;
static void context_destroy_count(void *data)
{
	destroy_count++;
}
static int free_count = 0;
static void context_free_count(void *data)
{
	free_count++;
}
static int global_removed_count = 0;
static void context_global_removed_count(void *data, struct pw_global *global)
{
	global_removed_count++;
}
static int context_foreach_count = 0;
static int context_foreach(void *data, struct pw_global *global)
{
	context_foreach_count++;
	return 0;
}
static int context_foreach_error(void *data, struct pw_global *global)
{
	context_foreach_count++;
	return -1;
}
static void test_create(void)
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct spa_hook listener = { NULL, };
	struct pw_context_events context_events = context_events_error;
	int res;

	loop = pw_main_loop_new(NULL);
	spa_assert(loop != NULL);

	context = pw_context_new(pw_main_loop_get_loop(loop),
			pw_properties_new(
				PW_KEY_CONFIG_NAME, "null",
				NULL), 12);
	spa_assert(context != NULL);
	pw_context_add_listener(context, &listener, &context_events, context);

	/* check main loop */
	spa_assert(pw_context_get_main_loop(context) == pw_main_loop_get_loop(loop));
	/* check user data */
	spa_assert(pw_context_get_user_data(context) != NULL);

	/* iterate globals */
	spa_assert(context_foreach_count == 0);
	res = pw_context_for_each_global(context, context_foreach, context);
	spa_assert(res == 0);
	spa_assert(context_foreach_count == 1);
	res = pw_context_for_each_global(context, context_foreach_error, context);
	spa_assert(res == -1);
	spa_assert(context_foreach_count == 2);

	/* check destroy */
	context_events.destroy = context_destroy_count;
	context_events.free = context_free_count;
	context_events.global_removed = context_global_removed_count;

	spa_assert(destroy_count == 0);
	spa_assert(free_count == 0);
	spa_assert(global_removed_count == 0);
	pw_context_destroy(context);
	spa_assert(destroy_count == 1);
	spa_assert(free_count == 1);
	spa_assert(global_removed_count == 1);
	pw_main_loop_destroy(loop);
}

static void test_properties(void)
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	const struct pw_properties *props;
	struct spa_hook listener = { NULL, };
	struct pw_context_events context_events = context_events_error;
	struct spa_dict_item items[3];

	loop = pw_main_loop_new(NULL);
	context = pw_context_new(pw_main_loop_get_loop(loop),
			pw_properties_new("foo", "bar",
					  "biz", "fuzz",
					  NULL),
			0);
	spa_assert(context != NULL);
	spa_assert(pw_context_get_user_data(context) == NULL);
	pw_context_add_listener(context, &listener, &context_events, context);

	props = pw_context_get_properties(context);
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
	pw_context_update_properties(context, &SPA_DICT_INIT(items, 3));

	spa_assert(props == pw_context_get_properties(context));
	spa_assert(pw_properties_get(props, "foo") == NULL);
	spa_assert(!strcmp(pw_properties_get(props, "biz"), "buzz"));
	spa_assert(!strcmp(pw_properties_get(props, "buzz"), "frizz"));

	spa_hook_remove(&listener);
	pw_context_destroy(context);
	pw_main_loop_destroy(loop);
}

static void test_support(void)
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	const struct spa_support *support;
	uint32_t n_support;
	const char * types[] = {
		SPA_TYPE_INTERFACE_DataSystem,
		SPA_TYPE_INTERFACE_DataLoop,
		SPA_TYPE_INTERFACE_System,
		SPA_TYPE_INTERFACE_Loop,
		SPA_TYPE_INTERFACE_LoopUtils,
		SPA_TYPE_INTERFACE_Log,
		SPA_TYPE_INTERFACE_DBus,
		SPA_TYPE_INTERFACE_CPU
	};
	size_t i;

	loop = pw_main_loop_new(NULL);
	context = pw_context_new(pw_main_loop_get_loop(loop), NULL, 0);

	support = pw_context_get_support(context, &n_support);
	spa_assert(support != NULL);
	spa_assert(n_support > 0);

	for (i = 0; i < SPA_N_ELEMENTS(types); i++) {
		spa_assert(spa_support_find(support, n_support, types[i]) != NULL);
	}

	pw_context_destroy(context);
	pw_main_loop_destroy(loop);
}

int main(int argc, char *argv[])
{
	pw_init(&argc, &argv);

	test_abi();
	test_create();
	test_properties();
	test_support();

	return 0;
}
