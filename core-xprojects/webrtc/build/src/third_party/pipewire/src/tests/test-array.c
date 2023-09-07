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

#include <pipewire/array.h>

static void test_abi(void)
{
	/* array */
#if defined(__x86_64__) && defined(__LP64__)
	spa_assert(sizeof(struct pw_array) == 32);
#else
	fprintf(stderr, "%zd\n", sizeof(struct pw_array));
#endif
}

static void test_array(void)
{
	struct pw_array arr;
	uint32_t *ptr;
	uint32_t vals[] = { 0, 100, 0x8a, 0 };
	size_t i;

	pw_array_init(&arr, 64);
	spa_assert(SPA_N_ELEMENTS(vals) == 4);

	spa_assert(pw_array_get_len(&arr, uint32_t) == 0);
	spa_assert(pw_array_check_index(&arr, 0, uint32_t) == false);
	spa_assert(pw_array_first(&arr) == pw_array_end(&arr));
	pw_array_for_each(ptr, &arr)
		spa_assert_not_reached();

	for (i = 0; i < 4; i++) {
		ptr = (uint32_t*)pw_array_add(&arr, sizeof(uint32_t));
		*ptr = vals[i];
	}

	spa_assert(pw_array_get_len(&arr, uint32_t) == 4);
	spa_assert(pw_array_check_index(&arr, 2, uint32_t) == true);
	spa_assert(pw_array_check_index(&arr, 3, uint32_t) == true);
	spa_assert(pw_array_check_index(&arr, 4, uint32_t) == false);

	i = 0;
	pw_array_for_each(ptr, &arr) {
		spa_assert(*ptr == vals[i++]);
	}

	/* remove second */
	ptr = pw_array_get_unchecked(&arr, 2, uint32_t);
	spa_assert(ptr != NULL);
	pw_array_remove(&arr, ptr);
	spa_assert(pw_array_get_len(&arr, uint32_t) == 3);
	spa_assert(pw_array_check_index(&arr, 3, uint32_t) == false);
	ptr = pw_array_get_unchecked(&arr, 2, uint32_t);
	spa_assert(ptr != NULL);
	spa_assert(*ptr == vals[3]);

	/* remove first */
	ptr = pw_array_get_unchecked(&arr, 0, uint32_t);
	spa_assert(ptr != NULL);
	pw_array_remove(&arr, ptr);
	spa_assert(pw_array_get_len(&arr, uint32_t) == 2);
	ptr = pw_array_get_unchecked(&arr, 0, uint32_t);
	spa_assert(ptr != NULL);
	spa_assert(*ptr == vals[1]);

	/* iterate */
	ptr = (uint32_t*)pw_array_first(&arr);
	spa_assert(pw_array_check(&arr, ptr));
	spa_assert(*ptr == vals[1]);
	ptr++;
	spa_assert(pw_array_check(&arr, ptr));
	spa_assert(*ptr == vals[3]);
	ptr++;
	spa_assert(pw_array_check(&arr, ptr) == false);

	pw_array_reset(&arr);
	spa_assert(pw_array_get_len(&arr, uint32_t) == 0);

	pw_array_clear(&arr);
}

int main(int argc, char *argv[])
{
	test_abi();
	test_array();

	return 0;
}
