/* Simple Plugin API
 *
 * Copyright © 2020 Wim Taymans <wim.taymans@gmail.com>
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

#include <spa/utils/defs.h>
#include <spa/utils/json.h>

static void test_abi(void)
{
#if defined(__x86_64__) && defined(__LP64__)
	spa_assert(sizeof(struct spa_json) == 32);
#else
	fprintf(stderr, "%zd\n", sizeof(struct spa_json));
#endif
}

#define TYPE_OBJECT	0
#define TYPE_ARRAY	1
#define TYPE_STRING	2
#define TYPE_BOOL	3
#define TYPE_NULL	4
#define TYPE_TRUE	5
#define TYPE_FALSE	6
#define TYPE_FLOAT	7

static void check_type(int type, const char *value, int len)
{
	spa_assert(spa_json_is_object(value, len) == (type == TYPE_OBJECT));
	spa_assert(spa_json_is_array(value, len) == (type == TYPE_ARRAY));
	spa_assert(spa_json_is_string(value, len) == (type == TYPE_STRING));
	spa_assert(spa_json_is_bool(value, len) ==
			(type == TYPE_BOOL || type == TYPE_TRUE || type == TYPE_FALSE));
	spa_assert(spa_json_is_null(value, len) == (type == TYPE_NULL));
	spa_assert(spa_json_is_true(value, len) == (type == TYPE_TRUE || type == TYPE_BOOL));
	spa_assert(spa_json_is_false(value, len) == (type == TYPE_FALSE || type == TYPE_BOOL));
	spa_assert(spa_json_is_float(value, len) == (type == TYPE_FLOAT));
}

static void expect_type(struct spa_json *it, int type)
{
	const char *value;
	int len;
	spa_assert((len = spa_json_next(it, &value)) > 0);
	check_type(type, value, len);
}

static void expect_string(struct spa_json *it, const char *str)
{
	const char *value;
	int len;
	char *s;
	spa_assert((len = spa_json_next(it, &value)) > 0);
	check_type(TYPE_STRING, value, len);
	s = alloca(len+1);
	spa_json_parse_string(value, len, s);
	spa_assert(strcmp(s, str) == 0);
}
static void expect_float(struct spa_json *it, float val)
{
	const char *value;
	int len;
	float f;
	spa_assert((len = spa_json_next(it, &value)) > 0);
	check_type(TYPE_FLOAT, value, len);
	spa_assert(spa_json_parse_float(value, len, &f) > 0);
	spa_assert(f == val);
}

static void test_parse(void)
{
	struct spa_json it[5];
	const char *json = " { "
			"\"foo\": \"bar\","
			"\"foo\\\"  \":   true,       "
			"\"foo \\n\\r\\t\": false,"
			"  \"  arr\": [ true, false, null, 5, 5.7, \"str]\"],"
			"\"foo 2\":     null,"
			"\"foo 3\": 1,"
			"  \"obj\": { \"ba } z\": false, \"empty\": [], \"foo\": { }, \"1.9\", 1.9 },"
			"\"foo 4\"   : 1.8,   "
			"\"foo 5\": -1.8  , "
			"\"foo 6\":   +2.8   ,"
			" } ", *value;

	spa_json_init(&it[0], json, strlen(json));

	expect_type(&it[0], TYPE_OBJECT);
	spa_json_enter(&it[0], &it[1]);
	expect_string(&it[1], "foo");
	expect_string(&it[1], "bar");
	expect_string(&it[1], "foo\"  ");
	expect_type(&it[1], TYPE_TRUE);
	expect_string(&it[1], "foo \n\r\t");
	expect_type(&it[1], TYPE_FALSE);
	expect_string(&it[1], "  arr");
	expect_type(&it[1], TYPE_ARRAY);
	spa_json_enter(&it[1], &it[2]);
	expect_string(&it[1], "foo 2");
	expect_type(&it[1], TYPE_NULL);
	expect_string(&it[1], "foo 3");
	expect_float(&it[1], 1.f);
	expect_string(&it[1], "obj");
	expect_type(&it[1], TYPE_OBJECT);
	spa_json_enter(&it[1], &it[3]);
	expect_string(&it[1], "foo 4");
	expect_float(&it[1], 1.8f);
	expect_string(&it[1], "foo 5");
	expect_float(&it[1], -1.8f);
	expect_string(&it[1], "foo 6");
	expect_float(&it[1], +2.8f);
	/* in the array */
	expect_type(&it[2], TYPE_TRUE);
	expect_type(&it[2], TYPE_FALSE);
	expect_type(&it[2], TYPE_NULL);
	expect_float(&it[2], 5.f);
	expect_float(&it[2], 5.7f);
	expect_string(&it[2], "str]");
	/* in the object */
	expect_string(&it[3], "ba } z");
	expect_type(&it[3], TYPE_FALSE);
	expect_string(&it[3], "empty");
	expect_type(&it[3], TYPE_ARRAY);
	spa_json_enter(&it[3], &it[4]);
	spa_assert(spa_json_next(&it[4], &value) == 0);
	expect_string(&it[3], "foo");
	expect_type(&it[3], TYPE_OBJECT);
	spa_json_enter(&it[3], &it[4]);
	expect_string(&it[3], "1.9");
	expect_float(&it[3], 1.9f);
}

static void test_encode(void)
{
	char dst[1024];
	char dst4[4];
	char dst6[6];
	char result[1024];
	spa_assert(spa_json_encode_string(dst, sizeof(dst), "test") == 6);
	spa_assert(strcmp(dst, "\"test\"") == 0);
	spa_assert(spa_json_encode_string(dst4, sizeof(dst4), "test") == 6);
	spa_assert(strncmp(dst4, "\"tes", 4) == 0);
	spa_assert(spa_json_encode_string(dst6, sizeof(dst6), "test") == 6);
	spa_assert(strncmp(dst6, "\"test\"", 6) == 0);
	spa_assert(spa_json_encode_string(dst, sizeof(dst), "test\"\n\r \t\b\f\'") == 20);
	spa_assert(strcmp(dst, "\"test\\\"\\n\\r \\t\\b\\f'\"") == 0);
	spa_assert(spa_json_encode_string(dst, sizeof(dst), "\x04\x05\x1f\x20\x01\x7f\x90") == 29);
	spa_assert(strcmp(dst, "\"\\u0004\\u0005\\u001f \\u0001\x7f\x90\"") == 0);
	spa_assert(spa_json_parse_string(dst, sizeof(dst), result) == 1);
	spa_assert(strcmp(result, "\x04\x05\x1f\x20\x01\x7f\x90") == 0);
}

static void test_array(char *str, char **vals)
{
	struct spa_json it[2];
	char val[256];
	int i;

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_array(&it[0], &it[1]) <= 0)
		spa_json_init(&it[1], str, strlen(str));
	for (i = 0; vals[i]; i++) {
		spa_assert(spa_json_get_string(&it[1], val, sizeof(val)) > 0);
		spa_assert(strcmp(val, vals[i]) == 0);
	}
}

static void test_arrays(void)
{
	test_array("FL,FR", (char *[]){ "FL", "FR", NULL });
	test_array(" FL , FR ", (char *[]){ "FL", "FR", NULL });
	test_array("[ FL , FR ]", (char *[]){ "FL", "FR", NULL });
	test_array("[FL FR]", (char *[]){ "FL", "FR", NULL });
	test_array("FL FR", (char *[]){ "FL", "FR", NULL });
	test_array("[ FL FR ]", (char *[]){ "FL", "FR", NULL });
}

static void test_overflow(void)
{
	struct spa_json it[2];
	char val[3];
	const char *str = "[ F, FR, FRC ]";

	spa_json_init(&it[0], str, strlen(str));
	spa_assert(spa_json_enter_array(&it[0], &it[1]) > 0);

	spa_assert(spa_json_get_string(&it[1], val, sizeof(val)) > 0);
	spa_assert(strcmp(val, "F") == 0);
	spa_assert(spa_json_get_string(&it[1], val, sizeof(val)) > 0);
	spa_assert(strcmp(val, "FR") == 0);
	spa_assert(spa_json_get_string(&it[1], val, sizeof(val)) < 0);
}

int main(int argc, char *argv[])
{
	test_abi();
	test_parse();
	test_encode();
	test_arrays();
	test_overflow();
	return 0;
}
