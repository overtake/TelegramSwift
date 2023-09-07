/* Simple Plugin API
 * Copyright © 2018 Collabora Ltd.
 *   @author George Kiagiadakis <george.kiagiadakis@collabora.com>
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
#include <spa/utils/result.h>
#include <spa/utils/dict.h>
#include <spa/utils/list.h>
#include <spa/utils/hook.h>
#include <spa/utils/ringbuffer.h>
#include <spa/utils/type.h>

static void test_abi(void)
{
	/* defs */
	spa_assert(SPA_DIRECTION_INPUT == 0);
	spa_assert(SPA_DIRECTION_OUTPUT == 1);

	spa_assert(sizeof(struct spa_rectangle) == 8);
	spa_assert(sizeof(struct spa_point) == 8);
	spa_assert(sizeof(struct spa_region) == 16);
	spa_assert(sizeof(struct spa_fraction) == 8);

	{
		struct spa_rectangle r = SPA_RECTANGLE(12, 14);
		spa_assert(r.width == 12);
		spa_assert(r.height == 14);
	}
	{
		struct spa_point p = SPA_POINT(8, 34);
		spa_assert(p.x == 8);
		spa_assert(p.y == 34);
	}
	{
		struct spa_region r = SPA_REGION(4, 5, 12, 13);
		spa_assert(r.position.x == 4);
		spa_assert(r.position.y == 5);
		spa_assert(r.size.width == 12);
		spa_assert(r.size.height == 13);
	}
	{
		struct spa_fraction f = SPA_FRACTION(56, 125);
		spa_assert(f.num == 56);
		spa_assert(f.denom == 125);
	}

#if defined(__x86_64__) && defined(__LP64__)
	/* dict */
	spa_assert(sizeof(struct spa_dict_item) == 16);
	spa_assert(sizeof(struct spa_dict) == 16);

	/* hook */
	spa_assert(sizeof(struct spa_hook_list) == sizeof(struct spa_list));
	spa_assert(sizeof(struct spa_hook) == 48);

	/* list */
	spa_assert(sizeof(struct spa_list) == 16);
#endif

	/* ringbuffer */
	spa_assert(sizeof(struct spa_ringbuffer) == 8);

	/* type */
	spa_assert(SPA_TYPE_START == 0);
	spa_assert(SPA_TYPE_None == 1);
	spa_assert(SPA_TYPE_Bool == 2);
	spa_assert(SPA_TYPE_Id == 3);
	spa_assert(SPA_TYPE_Int == 4);
	spa_assert(SPA_TYPE_Long == 5);
	spa_assert(SPA_TYPE_Float == 6);
	spa_assert(SPA_TYPE_Double == 7);
	spa_assert(SPA_TYPE_String == 8);
	spa_assert(SPA_TYPE_Bytes == 9);
	spa_assert(SPA_TYPE_Rectangle == 10);
	spa_assert(SPA_TYPE_Fraction == 11);
	spa_assert(SPA_TYPE_Bitmap == 12);
	spa_assert(SPA_TYPE_Array == 13);
	spa_assert(SPA_TYPE_Struct == 14);
	spa_assert(SPA_TYPE_Object == 15);
	spa_assert(SPA_TYPE_Sequence == 16);
	spa_assert(SPA_TYPE_Pointer == 17);
	spa_assert(SPA_TYPE_Fd == 18);
	spa_assert(SPA_TYPE_Choice == 19);
	spa_assert(SPA_TYPE_Pod == 20);
	spa_assert(SPA_TYPE_LAST == 21);

	spa_assert(SPA_TYPE_EVENT_START == 0x20000);
	spa_assert(SPA_TYPE_EVENT_Device == 0x20001);
	spa_assert(SPA_TYPE_EVENT_Node == 0x20002);
	spa_assert(SPA_TYPE_EVENT_LAST == 0x20003);

	spa_assert(SPA_TYPE_COMMAND_START == 0x30000);
	spa_assert(SPA_TYPE_COMMAND_Device == 0x30001);
	spa_assert(SPA_TYPE_COMMAND_Node == 0x30002);
	spa_assert(SPA_TYPE_COMMAND_LAST == 0x30003);

	spa_assert(SPA_TYPE_OBJECT_START == 0x40000);
	spa_assert(SPA_TYPE_OBJECT_PropInfo == 0x40001);
	spa_assert(SPA_TYPE_OBJECT_Props == 0x40002);
	spa_assert(SPA_TYPE_OBJECT_Format == 0x40003);
	spa_assert(SPA_TYPE_OBJECT_ParamBuffers == 0x40004);
	spa_assert(SPA_TYPE_OBJECT_ParamMeta == 0x40005);
	spa_assert(SPA_TYPE_OBJECT_ParamIO == 0x40006);
	spa_assert(SPA_TYPE_OBJECT_ParamProfile == 0x40007);
	spa_assert(SPA_TYPE_OBJECT_ParamPortConfig == 0x40008);
	spa_assert(SPA_TYPE_OBJECT_ParamRoute == 0x40009);
	spa_assert(SPA_TYPE_OBJECT_Profiler == 0x4000a);
	spa_assert(SPA_TYPE_OBJECT_LAST == 0x4000b);

	spa_assert(SPA_TYPE_VENDOR_PipeWire == 0x02000000);
	spa_assert(SPA_TYPE_VENDOR_Other == 0x7f000000);
}

static void test_macros(void)
{
	spa_assert(SPA_MIN(1, 2) == 1);
	spa_assert(SPA_MIN(1, -2) == -2);
	spa_assert(SPA_MAX(1, 2) == 2);
	spa_assert(SPA_MAX(1, -2) == 1);
	spa_assert(SPA_CLAMP(23, 1, 16) == 16);
	spa_assert(SPA_CLAMP(-1, 1, 16) == 1);
	spa_assert(SPA_CLAMP(8, 1, 16) == 8);
}

static void test_result(void)
{
	int res;
	spa_assert(SPA_RESULT_IS_OK(0) == true);
	spa_assert(SPA_RESULT_IS_OK(1) == true);
	spa_assert(SPA_RESULT_IS_ERROR(0) == false);
	spa_assert(SPA_RESULT_IS_ERROR(1) == false);
	spa_assert(SPA_RESULT_IS_ERROR(-1) == true);
	spa_assert(SPA_RESULT_IS_ASYNC(-1) == false);
	spa_assert(SPA_RESULT_IS_ASYNC(0) == false);
	res = SPA_RESULT_RETURN_ASYNC(11);
	spa_assert(SPA_RESULT_IS_ASYNC(res) == true);
	spa_assert(SPA_RESULT_IS_ERROR(res) == false);
	spa_assert(SPA_RESULT_IS_OK(res) == true);
	spa_assert(SPA_RESULT_ASYNC_SEQ(res) == 11);
}

static void test_dict(void)
{
    struct spa_dict_item items[5] = {
        SPA_DICT_ITEM_INIT("key", "value"),
        SPA_DICT_ITEM_INIT("pipe", "wire"),
        SPA_DICT_ITEM_INIT("test", "Works!"),
        SPA_DICT_ITEM_INIT("123", ""),
        SPA_DICT_ITEM_INIT("SPA", "Simple Plugin API"),
    };
    struct spa_dict dict = SPA_DICT_INIT_ARRAY (items);
    const struct spa_dict_item *it;
    int i = 0;

    spa_assert(dict.n_items == 5);
    spa_assert(!strcmp(spa_dict_lookup(&dict, "pipe"), "wire"));
    spa_assert(!strcmp(spa_dict_lookup(&dict, "123"), ""));
    spa_assert(!strcmp(spa_dict_lookup(&dict, "key"), "value"));
    spa_assert(!strcmp(spa_dict_lookup(&dict, "SPA"), "Simple Plugin API"));
    spa_assert(!strcmp(spa_dict_lookup(&dict, "test"), "Works!"));
    spa_assert(spa_dict_lookup(&dict, "nonexistent") == NULL);

    spa_assert(spa_dict_lookup_item(&dict, "123") == &items[3]);
    spa_assert(spa_dict_lookup_item(&dict, "foobar") == NULL);

    spa_dict_for_each(it, &dict) {
	    spa_assert(it == &items[i++]);
    }
    spa_assert(i == 5);
}

struct string_list {
    char string[20];
    struct spa_list node;
};

static void test_list(void)
{
    struct string_list list;
    struct spa_list *head = &list.node;
    struct string_list *e;
    int i;

    spa_list_init(head);
    spa_assert(spa_list_is_empty(head));

    e = malloc(sizeof(struct string_list));
    strcpy(e->string, "test");
    spa_list_insert(head, &e->node);
    spa_assert(!spa_list_is_empty(head));
    spa_assert(spa_list_first(head, struct string_list, node) == e);
    spa_assert(spa_list_last(head, struct string_list, node) == e);

    e = malloc(sizeof(struct string_list));
    strcpy(e->string, "pipewire!");
    spa_list_append(head, &e->node);
    spa_assert(!spa_list_is_empty(head));
    spa_assert(spa_list_last(head, struct string_list, node) == e);

    e = malloc(sizeof(struct string_list));
    strcpy(e->string, "First element");
    spa_list_prepend(head, &e->node);
    spa_assert(!spa_list_is_empty(head));
    spa_assert(spa_list_first(head, struct string_list, node) == e);

    i = 0;
    spa_list_for_each(e, head, node) {
        switch (i++) {
        case 0:
            spa_assert(!strcmp(e->string, "First element"));
            break;
        case 1:
            spa_assert(!strcmp(e->string, "test"));
            break;
        case 2:
            spa_assert(!strcmp(e->string, "pipewire!"));
            break;
        default:
            spa_assert_not_reached();
            break;
        }
    }

    i = 0;
    spa_list_consume(e, head, node) {
        spa_list_remove(&e->node);
        free(e);
        i++;
    }
    spa_assert(i == 3);
    spa_assert(spa_list_is_empty(head));
}


struct my_hook {
    int version;
    void (*invoke) (void *);
};

struct my_hook_data {
    bool cb1;
    bool cb2;
    bool cb3;
};

static void test_hook_callback_1(void *data)
{
    ((struct my_hook_data *) data)->cb1 = true;
}

static void test_hook_callback_2(void *data)
{
    ((struct my_hook_data *) data)->cb2 = true;
}

static void test_hook_callback_3(void *data)
{
    ((struct my_hook_data *) data)->cb3 = true;
}

static void test_hook_callback_4(void *data)
{
    spa_assert_not_reached();
}

static int hook_free_count = 0;

static void hook_removed_cb(struct spa_hook *h)
{
    free(h);
    hook_free_count++;
}

static void test_hook(void)
{
    const int VERSION = 2;
    struct spa_hook_list hl;
    struct my_hook callbacks[4] = {
        {2, test_hook_callback_1},
        {3, test_hook_callback_2},
        {2, test_hook_callback_3},
        /* version 1 should not be called */
        {1, test_hook_callback_4}
    };
    struct my_hook_data data = {0};
    struct spa_hook *h;
    int count = 0;

    spa_hook_list_init(&hl);

    h = malloc(sizeof(struct spa_hook));
    spa_hook_list_append(&hl, h, &callbacks[1], &data);
    h->removed = hook_removed_cb;

    h = malloc(sizeof(struct spa_hook));
    spa_hook_list_append(&hl, h, &callbacks[2], &data);
    h->removed = hook_removed_cb;

    /* iterate with the simple API */
    spa_hook_list_call_simple(&hl, struct my_hook, invoke, VERSION);
    spa_assert(data.cb1 == false);
    spa_assert(data.cb2 == true);
    spa_assert(data.cb3 == true);

    /* reset cb* booleans to false */
    memset(&data, 0, sizeof(struct my_hook_data));

    h = malloc(sizeof(struct spa_hook));
    spa_hook_list_prepend(&hl, h, &callbacks[0], &data);
    h->removed = hook_removed_cb;

    /* call only the first hook - this should be callback_1 */
    count = spa_hook_list_call_once(&hl, struct my_hook, invoke, VERSION);
    spa_assert(count == 1);
    spa_assert(data.cb1 == true);
    spa_assert(data.cb2 == false);
    spa_assert(data.cb3 == false);

    /* reset cb* booleans to false */
    memset(&data, 0, sizeof(struct my_hook_data));

    /* add callback_4 - this is version 1, so it shouldn't be executed */
    h = malloc(sizeof(struct spa_hook));
    spa_hook_list_append(&hl, h, &callbacks[3], &data);
    h->removed = hook_removed_cb;

    count = spa_hook_list_call(&hl, struct my_hook, invoke, VERSION);
    spa_assert(count == 3);
    spa_assert(data.cb1 == true);
    spa_assert(data.cb2 == true);
    spa_assert(data.cb3 == true);

    count = 0;
    hook_free_count = 0;
    spa_list_consume(h, &hl.list, link) {
        spa_hook_remove(h);
        count++;
    }
    spa_assert(count == 4);
    spa_assert(hook_free_count == 4);
}

static void test_ringbuffer(void)
{
    struct spa_ringbuffer rb;
    char buffer[20];
    char readbuf[20];
    uint32_t idx;
    int32_t fill;

    spa_ringbuffer_init(&rb);
    fill = spa_ringbuffer_get_write_index(&rb, &idx);
    spa_assert(idx == 0);
    spa_assert(fill == 0);

    spa_ringbuffer_write_data(&rb, buffer, 20, idx, "hello pipewire", 14);
    spa_ringbuffer_write_update(&rb, idx + 14);

    fill = spa_ringbuffer_get_write_index(&rb, &idx);
    spa_assert(idx == 14);
    spa_assert(fill == 14);
    fill = spa_ringbuffer_get_read_index(&rb, &idx);
    spa_assert(idx == 0);
    spa_assert(fill == 14);

    spa_ringbuffer_read_data(&rb, buffer, 20, idx, readbuf, 6);
    spa_ringbuffer_read_update(&rb, idx + 6);
    spa_assert(!memcmp(readbuf, "hello ", 6));

    fill = spa_ringbuffer_get_read_index(&rb, &idx);
    spa_assert(idx == 6);
    spa_assert(fill == 8);
    fill = spa_ringbuffer_get_write_index(&rb, &idx);
    spa_assert(idx == 14);
    spa_assert(fill == 8);

    spa_ringbuffer_write_data(&rb, buffer, 20, idx, " rocks !!!", 10);
    spa_ringbuffer_write_update(&rb, idx + 10);

    fill = spa_ringbuffer_get_write_index(&rb, &idx);
    spa_assert(idx == 24);
    spa_assert(fill == 18);
    fill = spa_ringbuffer_get_read_index(&rb, &idx);
    spa_assert(idx == 6);
    spa_assert(fill == 18);

    spa_ringbuffer_read_data(&rb, buffer, 20, idx, readbuf, 18);
    spa_ringbuffer_read_update(&rb, idx + 18);
    spa_assert(!memcmp(readbuf, "pipewire rocks !!!", 18));

    fill = spa_ringbuffer_get_read_index(&rb, &idx);
    spa_assert(idx == 24);
    spa_assert(fill == 0);
    fill = spa_ringbuffer_get_write_index(&rb, &idx);
    spa_assert(idx == 24);
    spa_assert(fill == 0);

    /* actual buffer must have wrapped around */
    spa_assert(!memcmp(buffer, " !!!o pipewire rocks", 20));
}

int main(int argc, char *argv[])
{
    test_abi();
    test_macros();
    test_result();
    test_dict();
    test_list();
    test_hook();
    test_ringbuffer();
    return 0;
}
