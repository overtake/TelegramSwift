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
#include <pipewire/impl-client.h>

#define TEST_FUNC(a,b,func)	\
do {				\
	a.func = b.func;	\
	spa_assert(SPA_PTRDIFF(&a.func, &a) == SPA_PTRDIFF(&b.func, &b)); \
} while(0)

static void test_abi(void)
{
	struct pw_impl_client_events ev;
	struct {
		uint32_t version;
		void (*destroy) (void *data);
		void (*free) (void *data);
		void (*initialized) (void *data);
		void (*info_changed) (void *data, const struct pw_client_info *info);
		void (*resource_added) (void *data, struct pw_resource *resource);
		void (*resource_removed) (void *data, struct pw_resource *resource);
		void (*busy_changed) (void *data, bool busy);
	} test = { PW_VERSION_IMPL_CLIENT_EVENTS, NULL };

	TEST_FUNC(ev, test, destroy);
	TEST_FUNC(ev, test, free);
	TEST_FUNC(ev, test, initialized);
	TEST_FUNC(ev, test, info_changed);
	TEST_FUNC(ev, test, resource_added);
	TEST_FUNC(ev, test, resource_removed);
	TEST_FUNC(ev, test, busy_changed);

	spa_assert(PW_VERSION_IMPL_CLIENT_EVENTS == 0);
	spa_assert(sizeof(ev) == sizeof(test));
}

int main(int argc, char *argv[])
{
	pw_init(&argc, &argv);

	test_abi();

	return 0;
}
