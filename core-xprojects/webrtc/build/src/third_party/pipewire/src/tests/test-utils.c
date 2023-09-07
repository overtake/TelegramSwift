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

#include <limits.h>

#include <pipewire/utils.h>

static void test_destroy(void *object)
{
	spa_assert_not_reached();
}

static void test_abi(void)
{
	pw_destroy_t f;
	f = test_destroy;
	spa_assert(f == test_destroy);
}

static void test_split(void)
{
	const char *test1 = "a \n test string  \n \r ";
	const char *del = "\n\r ";
	size_t len;
	const char *str, *state = NULL;
	char **res;
	int n_tokens;

	str = pw_split_walk(test1, del, &len, &state);
	spa_assert(!strncmp(str, "a", len));
	str = pw_split_walk(test1, del, &len, &state);
	spa_assert(!strncmp(str, "test", len));
	str = pw_split_walk(test1, del, &len, &state);
	spa_assert(!strncmp(str, "string", len));
	str = pw_split_walk(test1, del, &len, &state);
	spa_assert(str == NULL);

	res = pw_split_strv(test1, del, INT_MAX, &n_tokens);
	spa_assert(res != NULL);
	spa_assert(n_tokens == 3);
	spa_assert(!strcmp(res[0], "a"));
	spa_assert(!strcmp(res[1], "test"));
	spa_assert(!strcmp(res[2], "string"));
	spa_assert(res[3] == NULL);
	pw_free_strv(res);

	res = pw_split_strv(test1, del, 2, &n_tokens);
	spa_assert(res != NULL);
	spa_assert(n_tokens == 2);
	spa_assert(!strcmp(res[0], "a"));
	spa_assert(!strcmp(res[1], "test string  \n \r "));
	spa_assert(res[2] == NULL);
	pw_free_strv(res);
}

static void test_strip(void)
{
	char test1[] = " \n\r \n a test string  \n \r ";
	char test2[] = " \n\r \n   \n \r ";
	char test3[] = "a test string";
	spa_assert(!strcmp(pw_strip(test1, "\n\r "), "a test string"));
	spa_assert(!strcmp(pw_strip(test2, "\n\r "), ""));
	spa_assert(!strcmp(pw_strip(test3, "\n\r "), "a test string"));
}

int main(int argc, char *argv[])
{
	test_abi();
	test_split();
	test_strip();

	return 0;
}
