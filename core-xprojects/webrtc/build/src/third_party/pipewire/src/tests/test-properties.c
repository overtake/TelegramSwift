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

#include <pipewire/properties.h>

static void test_abi(void)
{
#if defined(__x86_64__) && defined(__LP64__)
	spa_assert(sizeof(struct pw_properties) == 24);
#else
	fprintf(stderr, "%zd\n", sizeof(struct pw_properties));
#endif
}

static void test_empty(void)
{
	struct pw_properties *props, *copy;
	void *state = NULL;

	props = pw_properties_new(NULL, NULL);
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);

	spa_assert(props->dict.n_items == 0);
	spa_assert(pw_properties_get(props, NULL) == NULL);
	spa_assert(pw_properties_get(props, "unknown") == NULL);
	spa_assert(pw_properties_iterate(props, &state) == NULL);

	pw_properties_clear(props);
	spa_assert(props->dict.n_items == 0);
	spa_assert(pw_properties_get(props, NULL) == NULL);
	spa_assert(pw_properties_get(props, "") == NULL);
	spa_assert(pw_properties_get(props, "unknown") == NULL);
	spa_assert(pw_properties_iterate(props, &state) == NULL);

	copy = pw_properties_copy(props);
	spa_assert(copy != NULL);
	pw_properties_free(props);

	spa_assert(copy->dict.n_items == 0);
	spa_assert(pw_properties_get(copy, NULL) == NULL);
	spa_assert(pw_properties_get(copy, "") == NULL);
	spa_assert(pw_properties_get(copy, "unknown") == NULL);
	spa_assert(pw_properties_iterate(copy, &state) == NULL);

	pw_properties_free(copy);
}

static void test_set(void)
{
	struct pw_properties *props, *copy;
	void *state = NULL;
	const char *str;

	props = pw_properties_new(NULL, NULL);
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);

	spa_assert(pw_properties_set(props, "foo", "bar") == 1);
	spa_assert(props->dict.n_items == 1);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(pw_properties_set(props, "foo", "bar") == 0);
	spa_assert(props->dict.n_items == 1);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(pw_properties_set(props, "foo", "fuz") == 1);
	spa_assert(props->dict.n_items == 1);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "fuz"));
	spa_assert(pw_properties_set(props, "bar", "foo") == 1);
	spa_assert(props->dict.n_items == 2);
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "foo"));
	spa_assert(pw_properties_set(props, "him", "too") == 1);
	spa_assert(props->dict.n_items == 3);
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));
	spa_assert(pw_properties_set(props, "him", NULL) == 1);
	spa_assert(props->dict.n_items == 2);
	spa_assert(pw_properties_get(props, "him") == NULL);
	spa_assert(pw_properties_set(props, "him", NULL) == 0);
	spa_assert(props->dict.n_items == 2);
	spa_assert(pw_properties_get(props, "him") == NULL);

	spa_assert(pw_properties_set(props, "", "invalid") == 0);
	spa_assert(pw_properties_set(props, NULL, "invalid") == 0);

	str = pw_properties_iterate(props, &state);
	spa_assert(str != NULL && (!strcmp(str, "foo") || !strcmp(str, "bar")));
	str = pw_properties_iterate(props, &state);
	spa_assert(str != NULL && (!strcmp(str, "foo") || !strcmp(str, "bar")));
	str = pw_properties_iterate(props, &state);
	spa_assert(str == NULL);

	spa_assert(pw_properties_set(props, "foo", NULL) == 1);
	spa_assert(props->dict.n_items == 1);
	spa_assert(pw_properties_set(props, "bar", NULL) == 1);
	spa_assert(props->dict.n_items == 0);

	spa_assert(pw_properties_set(props, "foo", "bar") == 1);
	spa_assert(pw_properties_set(props, "bar", "foo") == 1);
	spa_assert(pw_properties_set(props, "him", "too") == 1);
	spa_assert(props->dict.n_items == 3);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "foo"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	pw_properties_clear(props);
	spa_assert(props->dict.n_items == 0);

	spa_assert(pw_properties_set(props, "foo", "bar") == 1);
	spa_assert(pw_properties_set(props, "bar", "foo") == 1);
	spa_assert(pw_properties_set(props, "him", "too") == 1);
	spa_assert(props->dict.n_items == 3);

	copy = pw_properties_copy(props);
	spa_assert(copy != NULL);
	spa_assert(copy->dict.n_items == 3);
	spa_assert(!strcmp(pw_properties_get(copy, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(copy, "bar"), "foo"));
	spa_assert(!strcmp(pw_properties_get(copy, "him"), "too"));

	spa_assert(pw_properties_set(copy, "bar", NULL) == 1);
	spa_assert(pw_properties_set(copy, "foo", NULL) == 1);
	spa_assert(copy->dict.n_items == 1);
	spa_assert(!strcmp(pw_properties_get(copy, "him"), "too"));

	spa_assert(props->dict.n_items == 3);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "foo"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	pw_properties_free(props);
	pw_properties_free(copy);
}

static void test_setf(void)
{
	struct pw_properties *props;

	props = pw_properties_new(NULL, NULL);
	spa_assert(pw_properties_setf(props, "foo", "%d.%08x", 657, 0x89342) == 1);
	spa_assert(props->dict.n_items == 1);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "657.00089342"));

	spa_assert(pw_properties_setf(props, "", "%f", 189.45f) == 0);
	spa_assert(pw_properties_setf(props, NULL, "%f", 189.45f) == 0);
	spa_assert(props->dict.n_items == 1);

	pw_properties_free(props);
}

static void test_new(void)
{
	struct pw_properties *props;

	props = pw_properties_new("foo", "bar", "bar", "baz", "", "invalid", "him", "too", NULL);
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 3);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	pw_properties_free(props);
}

static void test_new_dict(void)
{
	struct pw_properties *props;
	struct spa_dict_item items[5];

	items[0] = SPA_DICT_ITEM_INIT("foo", "bar");
	items[1] = SPA_DICT_ITEM_INIT("bar", "baz");
	items[3] = SPA_DICT_ITEM_INIT("", "invalid");
	items[4] = SPA_DICT_ITEM_INIT(NULL, "invalid");
	items[2] = SPA_DICT_ITEM_INIT("him", "too");

	props = pw_properties_new_dict(&SPA_DICT_INIT_ARRAY(items));
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 3);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	pw_properties_free(props);
}

static void test_new_string(void)
{
	struct pw_properties *props;

	props = pw_properties_new_string("foo=bar bar=baz \"#ignore\"=ignore him=too empty=\"\" =gg");
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 4);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));
	spa_assert(!strcmp(pw_properties_get(props, "empty"), ""));

	pw_properties_free(props);

	props = pw_properties_new_string("foo=bar bar=baz");
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 2);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));

	pw_properties_free(props);

	props = pw_properties_new_string("foo=bar bar=\"baz");
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 2);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));

	pw_properties_free(props);
}

static void test_update(void)
{
	struct pw_properties *props;
	struct spa_dict_item items[5];

	props = pw_properties_new(NULL, NULL);
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 0);

	items[0] = SPA_DICT_ITEM_INIT("foo", "bar");
	items[1] = SPA_DICT_ITEM_INIT("bar", "baz");
	items[3] = SPA_DICT_ITEM_INIT("", "invalid");
	items[4] = SPA_DICT_ITEM_INIT(NULL, "invalid");
	items[2] = SPA_DICT_ITEM_INIT("him", "too");
	spa_assert(pw_properties_update(props, &SPA_DICT_INIT_ARRAY(items)) == 3);
	spa_assert(props->dict.n_items == 3);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	items[0] = SPA_DICT_ITEM_INIT("foo", "bar");
	items[1] = SPA_DICT_ITEM_INIT("bar", "baz");
	spa_assert(pw_properties_update(props, &SPA_DICT_INIT(items, 2)) == 0);
	spa_assert(props->dict.n_items == 3);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "baz"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	items[0] = SPA_DICT_ITEM_INIT("bar", "bear");
	items[1] = SPA_DICT_ITEM_INIT("him", "too");
	spa_assert(pw_properties_update(props, &SPA_DICT_INIT(items, 2)) == 1);
	spa_assert(props->dict.n_items == 3);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "bear"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "too"));

	items[0] = SPA_DICT_ITEM_INIT("bar", "bear");
	items[1] = SPA_DICT_ITEM_INIT("him", NULL);
	spa_assert(pw_properties_update(props, &SPA_DICT_INIT(items, 2)) == 1);
	spa_assert(props->dict.n_items == 2);
	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "bear"));
	spa_assert(pw_properties_get(props, "him") == NULL);

	items[0] = SPA_DICT_ITEM_INIT("foo", NULL);
	items[1] = SPA_DICT_ITEM_INIT("bar", "beer");
	items[2] = SPA_DICT_ITEM_INIT("him", "her");
	spa_assert(pw_properties_update(props, &SPA_DICT_INIT(items, 3)) == 3);
	spa_assert(props->dict.n_items == 2);
	spa_assert(pw_properties_get(props, "foo") == NULL);
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "beer"));
	spa_assert(!strcmp(pw_properties_get(props, "him"), "her"));

	pw_properties_free(props);
}

static void test_parse(void)
{
	spa_assert(pw_properties_parse_bool("true") == true);
	spa_assert(pw_properties_parse_bool("1") == true);
	spa_assert(pw_properties_parse_bool("false") == false);
	spa_assert(pw_properties_parse_bool("0") == false);

	spa_assert(pw_properties_parse_int("10") == 10);
	spa_assert(pw_properties_parse_int("-5") == -5);
	spa_assert(pw_properties_parse_int("0700") == 0700);
	spa_assert(pw_properties_parse_int("0x700") == 0x700);
	spa_assert(pw_properties_parse_int("invalid") == 0);

	spa_assert(pw_properties_parse_int64("10") == 10);
	spa_assert(pw_properties_parse_int64("-5") == -5);
	spa_assert(pw_properties_parse_int64("0732") == 0732);
	spa_assert(pw_properties_parse_int64("0x732") == 0x732);
	spa_assert(pw_properties_parse_int64("invalid") == 0);

	spa_assert(pw_properties_parse_uint64("10") == 10);
	spa_assert(pw_properties_parse_uint64("0713") == 0713);
	spa_assert(pw_properties_parse_uint64("0x713") == 0x713);
	spa_assert(pw_properties_parse_uint64("invalid") == 0);

	spa_assert(pw_properties_parse_float("1.234") == 1.234f);
	spa_assert(pw_properties_parse_double("1.234") == 1.234);
}

static void test_new_json(void)
{
	struct pw_properties *props;

	props = pw_properties_new_string("{ \"foo\": \"bar\\n\\t\", \"bar\": 1.8, \"empty\": [ \"foo\", \"bar\" ], \"\": \"gg\"");
	spa_assert(props != NULL);
	spa_assert(props->flags == 0);
	spa_assert(props->dict.n_items == 3);

	spa_assert(!strcmp(pw_properties_get(props, "foo"), "bar\n\t"));
	spa_assert(!strcmp(pw_properties_get(props, "bar"), "1.8"));
	fprintf(stderr, "'%s'\n", pw_properties_get(props, "empty"));
	spa_assert(!strcmp(pw_properties_get(props, "empty"), "[ \"foo\", \"bar\" ]"));

	pw_properties_free(props);
}

int main(int argc, char *argv[])
{
	test_abi();
	test_empty();
	test_set();
	test_setf();
	test_new();
	test_new_dict();
	test_new_string();
	test_update();
	test_parse();
	test_new_json();

	return 0;
}
