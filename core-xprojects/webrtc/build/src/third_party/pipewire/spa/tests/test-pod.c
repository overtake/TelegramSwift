/* Simple Plugin API
 * Copyright © 2019 Wim Taymans <wim.taymans@gmail.com>
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

#include <spa/pod/pod.h>
#include <spa/pod/builder.h>
#include <spa/pod/command.h>
#include <spa/pod/event.h>
#include <spa/pod/iter.h>
#include <spa/pod/parser.h>
#include <spa/pod/vararg.h>
#include <spa/debug/pod.h>
#include <spa/param/format.h>
#include <spa/param/video/raw.h>

static void test_abi(void)
{
	/* pod */
#if defined(__x86_64__) && defined(__LP64__)
	spa_assert(sizeof(struct spa_pod) == 8);
	spa_assert(sizeof(struct spa_pod_bool) == 16);
	spa_assert(sizeof(struct spa_pod_id) == 16);
	spa_assert(sizeof(struct spa_pod_int) == 16);
	spa_assert(sizeof(struct spa_pod_long) == 16);
	spa_assert(sizeof(struct spa_pod_float) == 16);
	spa_assert(sizeof(struct spa_pod_double) == 16);
	spa_assert(sizeof(struct spa_pod_string) == 8);
	spa_assert(sizeof(struct spa_pod_bytes) == 8);
	spa_assert(sizeof(struct spa_pod_rectangle) == 16);
	spa_assert(sizeof(struct spa_pod_fraction) == 16);
	spa_assert(sizeof(struct spa_pod_bitmap) == 8);
	spa_assert(sizeof(struct spa_pod_array_body) == 8);
	spa_assert(sizeof(struct spa_pod_array) == 16);

	spa_assert(SPA_CHOICE_None == 0);
	spa_assert(SPA_CHOICE_Range == 1);
	spa_assert(SPA_CHOICE_Step == 2);
	spa_assert(SPA_CHOICE_Enum == 3);
	spa_assert(SPA_CHOICE_Flags == 4);

	spa_assert(sizeof(struct spa_pod_choice_body) == 16);
	spa_assert(sizeof(struct spa_pod_choice) == 24);
	spa_assert(sizeof(struct spa_pod_struct) == 8);
	spa_assert(sizeof(struct spa_pod_object_body) == 8);
	spa_assert(sizeof(struct spa_pod_object) == 16);
	spa_assert(sizeof(struct spa_pod_pointer_body) == 16);
	spa_assert(sizeof(struct spa_pod_pointer) == 24);
	spa_assert(sizeof(struct spa_pod_fd) == 16);
	spa_assert(sizeof(struct spa_pod_prop) == 16);
	spa_assert(sizeof(struct spa_pod_control) == 16);
	spa_assert(sizeof(struct spa_pod_sequence_body) == 8);
	spa_assert(sizeof(struct spa_pod_sequence) == 16);

	/* builder */
	spa_assert(sizeof(struct spa_pod_frame) == 24);
	spa_assert(sizeof(struct spa_pod_builder_state) == 16);
	spa_assert(sizeof(struct spa_pod_builder) == 48);

	/* command */
	spa_assert(sizeof(struct spa_command_body) == 8);
	spa_assert(sizeof(struct spa_command) == 16);

	/* event */
	spa_assert(sizeof(struct spa_event_body) == 8);
	spa_assert(sizeof(struct spa_event) == 16);

	/* parser */
	spa_assert(sizeof(struct spa_pod_parser_state) == 16);
	spa_assert(sizeof(struct spa_pod_parser) == 32);
#endif

}

static void test_init(void)
{
	{
		struct spa_pod pod = SPA_POD_INIT(sizeof(int64_t), SPA_TYPE_Long);
		int32_t val;

		spa_assert(SPA_POD_SIZE(&pod) == sizeof(int64_t) + 8);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Long);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == sizeof(int64_t));
		spa_assert(SPA_POD_CONTENTS_SIZE(struct spa_pod, &pod) == sizeof(int64_t));
		spa_assert(spa_pod_is_long(&pod));

		pod = SPA_POD_INIT(sizeof(int32_t), SPA_TYPE_Int);
		spa_assert(SPA_POD_SIZE(&pod) == sizeof(int32_t) + 8);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Int);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == sizeof(int32_t));
		spa_assert(SPA_POD_CONTENTS_SIZE(struct spa_pod, &pod) == sizeof(int32_t));
		spa_assert(spa_pod_is_int(&pod));

		/** too small */
		pod = SPA_POD_INIT(0, SPA_TYPE_Int);
		spa_assert(!spa_pod_is_int(&pod));
		spa_assert(spa_pod_get_int(&pod, &val) < 0);
	}
	{
		struct spa_pod pod = SPA_POD_INIT_None();

		spa_assert(SPA_POD_SIZE(&pod) == 8);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_None);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 0);
		spa_assert(SPA_POD_CONTENTS_SIZE(struct spa_pod, &pod) == 0);
		spa_assert(spa_pod_is_none(&pod));
	}
	{
		struct spa_pod_bool pod = SPA_POD_INIT_Bool(true);
		bool val;

		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Bool);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_bool, &pod) == true);
		spa_assert(spa_pod_is_bool(&pod.pod));
		spa_assert(spa_pod_get_bool(&pod.pod, &val) == 0);
		spa_assert(val == true);

		pod = SPA_POD_INIT_Bool(false);
		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Bool);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_bool, &pod) == false);
		spa_assert(spa_pod_is_bool(&pod.pod));
		spa_assert(spa_pod_get_bool(&pod.pod, &val) == 0);
		spa_assert(val == false);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Bool);
		spa_assert(!spa_pod_is_bool(&pod.pod));
		spa_assert(spa_pod_get_bool(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_id pod = SPA_POD_INIT_Id(SPA_TYPE_Int);
		uint32_t val;

		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Id);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_id, &pod) == SPA_TYPE_Int);
		spa_assert(spa_pod_is_id(&pod.pod));
		spa_assert(spa_pod_get_id(&pod.pod, &val) == 0);
		spa_assert(val == SPA_TYPE_Int);

		pod = SPA_POD_INIT_Id(SPA_TYPE_Long);
		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Id);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_id, &pod) == SPA_TYPE_Long);
		spa_assert(spa_pod_is_id(&pod.pod));
		spa_assert(spa_pod_get_id(&pod.pod, &val) == 0);
		spa_assert(val == SPA_TYPE_Long);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Id);
		spa_assert(!spa_pod_is_id(&pod.pod));
		spa_assert(spa_pod_get_id(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_int pod = SPA_POD_INIT_Int(23);
		int32_t val;

		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Int);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_int, &pod) == 23);
		spa_assert(spa_pod_is_int(&pod.pod));
		spa_assert(spa_pod_get_int(&pod.pod, &val) == 0);
		spa_assert(val == 23);

		pod = SPA_POD_INIT_Int(-123);
		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Int);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_int, &pod) == -123);
		spa_assert(spa_pod_is_int(&pod.pod));
		spa_assert(spa_pod_get_int(&pod.pod, &val) == 0);
		spa_assert(val == -123);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Int);
		spa_assert(!spa_pod_is_int(&pod.pod));
		spa_assert(spa_pod_get_int(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_long pod = SPA_POD_INIT_Long(-23);
		int64_t val;

		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Long);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(SPA_POD_VALUE(struct spa_pod_long, &pod) == -23);
		spa_assert(spa_pod_is_long(&pod.pod));
		spa_assert(spa_pod_get_long(&pod.pod, &val) == 0);
		spa_assert(val == -23);

		pod = SPA_POD_INIT_Long(123);
		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Long);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(SPA_POD_VALUE(struct spa_pod_long, &pod) == 123);
		spa_assert(spa_pod_is_long(&pod.pod));
		spa_assert(spa_pod_get_long(&pod.pod, &val) == 0);
		spa_assert(val == 123);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Long);
		spa_assert(!spa_pod_is_long(&pod.pod));
		spa_assert(spa_pod_get_long(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_float pod = SPA_POD_INIT_Float(0.67f);
		float val;

		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Float);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_float, &pod) == 0.67f);
		spa_assert(spa_pod_is_float(&pod.pod));
		spa_assert(spa_pod_get_float(&pod.pod, &val) == 0);
		spa_assert(val == 0.67f);

		pod = SPA_POD_INIT_Float(-134.8f);
		spa_assert(SPA_POD_SIZE(&pod) == 12);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Float);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 4);
		spa_assert(SPA_POD_VALUE(struct spa_pod_float, &pod) == -134.8f);
		spa_assert(spa_pod_is_float(&pod.pod));
		spa_assert(spa_pod_get_float(&pod.pod, &val) == 0);
		spa_assert(val == -134.8f);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Float);
		spa_assert(!spa_pod_is_float(&pod.pod));
		spa_assert(spa_pod_get_float(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_double pod = SPA_POD_INIT_Double(0.67);
		double val;

		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Double);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(SPA_POD_VALUE(struct spa_pod_double, &pod) == 0.67);
		spa_assert(spa_pod_is_double(&pod.pod));
		spa_assert(spa_pod_get_double(&pod.pod, &val) == 0);
		spa_assert(val == 0.67);

		pod = SPA_POD_INIT_Double(-134.8);
		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Double);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(SPA_POD_VALUE(struct spa_pod_double, &pod) == -134.8);
		spa_assert(spa_pod_is_double(&pod.pod));
		spa_assert(spa_pod_get_double(&pod.pod, &val) == 0);
		spa_assert(val == -134.8);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Double);
		spa_assert(!spa_pod_is_double(&pod.pod));
		spa_assert(spa_pod_get_double(&pod.pod, &val) < 0);
	}
	{
		struct {
			struct spa_pod_string pod;
			char str[9];
		} pod;
		char val[12];

		pod.pod	= SPA_POD_INIT_String(9);
		strncpy(pod.str, "test", 9);

		spa_assert(SPA_POD_SIZE(&pod) == 17);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_String);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 9);
		spa_assert(spa_pod_is_string(&pod.pod.pod));
		spa_assert(spa_pod_copy_string(&pod.pod.pod, sizeof(val), val) == 0);
		spa_assert(strcmp(pod.str, val) == 0);

		pod.pod	= SPA_POD_INIT_String(6);
		memcpy(pod.str, "test123456789", 9);

		spa_assert(SPA_POD_SIZE(&pod) == 14);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_String);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 6);
		spa_assert(!spa_pod_is_string(&pod.pod.pod));
		spa_assert(spa_pod_copy_string(&pod.pod.pod, sizeof(val), val) < 0);
	}
	{
		struct spa_pod_rectangle pod = SPA_POD_INIT_Rectangle(SPA_RECTANGLE(320,240));
		struct spa_rectangle val;

		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Rectangle);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(memcmp(&SPA_POD_VALUE(struct spa_pod_rectangle, &pod),
					&SPA_RECTANGLE(320,240), sizeof(struct spa_rectangle)) == 0);
		spa_assert(spa_pod_is_rectangle(&pod.pod));
		spa_assert(spa_pod_get_rectangle(&pod.pod, &val) == 0);
		spa_assert(memcmp(&val, &SPA_RECTANGLE(320,240), sizeof(struct spa_rectangle)) == 0);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Rectangle);
		spa_assert(!spa_pod_is_rectangle(&pod.pod));
		spa_assert(spa_pod_get_rectangle(&pod.pod, &val) < 0);
	}
	{
		struct spa_pod_fraction pod = SPA_POD_INIT_Fraction(SPA_FRACTION(25,1));
		struct spa_fraction val;

		spa_assert(SPA_POD_SIZE(&pod) == 16);
		spa_assert(SPA_POD_TYPE(&pod) == SPA_TYPE_Fraction);
		spa_assert(SPA_POD_BODY_SIZE(&pod) == 8);
		spa_assert(memcmp(&SPA_POD_VALUE(struct spa_pod_fraction, &pod),
					&SPA_FRACTION(25,1), sizeof(struct spa_fraction)) == 0);
		spa_assert(spa_pod_is_fraction(&pod.pod));
		spa_assert(spa_pod_get_fraction(&pod.pod, &val) == 0);
		spa_assert(memcmp(&val, &SPA_FRACTION(25,1), sizeof(struct spa_fraction)) == 0);

		pod.pod = SPA_POD_INIT(0, SPA_TYPE_Fraction);
		spa_assert(!spa_pod_is_fraction(&pod.pod));
		spa_assert(spa_pod_get_fraction(&pod.pod, &val) < 0);
	}
}

static void test_build(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod *array, *choice, *head, *pod, *it;
	const struct spa_pod_prop *prop;
	struct spa_pod_control *control;
	int64_t longs[] = { 5, 7, 11, 13, 17 }, *al;
	uint32_t i, len, yl, *ai;
	union {
		bool b;
		uint32_t I;
		int32_t i;
		int64_t l;
		float f;
		double d;
		const char *s;
		const void *y;
		const void *p;
		int64_t h;
		struct spa_rectangle R;
		struct spa_fraction F;
	} val;
	struct spa_pod_frame f;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(b.data == buffer);
	spa_assert(b.size == sizeof(buffer));
	spa_assert(b.state.offset == 0);
	spa_assert(b.state.flags == 0);

	spa_assert(spa_pod_builder_none(&b) == 0);
	spa_assert(b.state.offset == 8);
	spa_assert(spa_pod_builder_bool(&b, true) == 0);
	spa_assert(b.state.offset == 24);
	spa_assert(spa_pod_builder_id(&b, SPA_TYPE_Object) == 0);
	spa_assert(b.state.offset == 40);
	spa_assert(spa_pod_builder_int(&b, 21) == 0);
	spa_assert(b.state.offset == 56);
	spa_assert(spa_pod_builder_float(&b, 0.8f) == 0);
	spa_assert(b.state.offset == 72);
	spa_assert(spa_pod_builder_double(&b, -1.56) == 0);
	spa_assert(b.state.offset == 88);
	spa_assert(spa_pod_builder_string(&b, "test") == 0);
	spa_assert(b.state.offset == 104);
	spa_assert(spa_pod_builder_bytes(&b, "PipeWire", 8) == 0);
	spa_assert(b.state.offset == 120);
	spa_assert(spa_pod_builder_pointer(&b, SPA_TYPE_Object, &b) == 0);
	spa_assert(b.state.offset == 144);
	spa_assert(spa_pod_builder_fd(&b, 4) == 0);
	spa_assert(b.state.offset == 160);
	spa_assert(spa_pod_builder_rectangle(&b, 320, 240) == 0);
	spa_assert(b.state.offset == 176);
	spa_assert(spa_pod_builder_fraction(&b, 25, 1) == 0);

	spa_assert(b.state.offset == 192);
	spa_assert(spa_pod_builder_push_array(&b, &f) == 0);
	spa_assert(f.offset == 192);
	spa_assert(b.state.flags == (SPA_POD_BUILDER_FLAG_BODY | SPA_POD_BUILDER_FLAG_FIRST));
	spa_assert(b.state.offset == 200);
	spa_assert(spa_pod_builder_int(&b, 1) == 0);
	spa_assert(b.state.flags == SPA_POD_BUILDER_FLAG_BODY);
	spa_assert(b.state.offset == 212);
	spa_assert(spa_pod_builder_int(&b, 2) == 0);
	spa_assert(b.state.offset == 216);
	spa_assert(spa_pod_builder_int(&b, 3) == 0);
	array = spa_pod_builder_pop(&b, &f);
	spa_assert(f.pod.size == 20);
	spa_assert(array != NULL);
	spa_assert(SPA_POD_BODY_SIZE(array) == 8 + 12);
	spa_assert(b.state.flags == 0);

	spa_assert(b.state.offset == 224);
	spa_assert(spa_pod_builder_array(&b,
				sizeof(int64_t), SPA_TYPE_Long,
				SPA_N_ELEMENTS(longs), longs) == 0);
	spa_assert(b.state.flags == 0);

	spa_assert(b.state.offset == 280);
	spa_assert(spa_pod_builder_push_choice(&b, &f, SPA_CHOICE_Enum, 0) == 0);
	spa_assert(b.state.flags == (SPA_POD_BUILDER_FLAG_BODY | SPA_POD_BUILDER_FLAG_FIRST));
	spa_assert(b.state.offset == 296);
	spa_assert(spa_pod_builder_long(&b, 1) == 0);
	spa_assert(b.state.flags == SPA_POD_BUILDER_FLAG_BODY);
	spa_assert(b.state.offset == 312);
	spa_assert(spa_pod_builder_long(&b, 2) == 0);
	spa_assert(b.state.offset == 320);
	spa_assert(spa_pod_builder_long(&b, 3) == 0);
	choice = spa_pod_builder_pop(&b, &f);
	spa_assert(choice != NULL);
	spa_assert(b.state.flags == 0);

	spa_assert(b.state.offset == 328);
	spa_assert(spa_pod_builder_push_struct(&b, &f) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 336);
	spa_assert(spa_pod_builder_int(&b, 21) == 0);
	spa_assert(b.state.offset == 352);
	spa_assert(spa_pod_builder_float(&b, 0.8f) == 0);
	spa_assert(b.state.offset == 368);
	spa_assert(spa_pod_builder_double(&b, -1.56) == 0);
	spa_assert(spa_pod_builder_pop(&b, &f) != NULL);

	spa_assert(b.state.offset == 384);
	spa_assert(spa_pod_builder_push_object(&b, &f, SPA_TYPE_OBJECT_Props, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 400);
	spa_assert(spa_pod_builder_prop(&b, 1, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 408);
	spa_assert(spa_pod_builder_int(&b, 21) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 424);
	spa_assert(spa_pod_builder_prop(&b, 2, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 432);
	spa_assert(spa_pod_builder_long(&b, 42) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 448);
	spa_assert(spa_pod_builder_prop(&b, 3, 0) == 0);
	spa_assert(b.state.offset == 456);
	spa_assert(spa_pod_builder_string(&b, "test123") == 0);
	spa_assert(spa_pod_builder_pop(&b, &f) != NULL);
	spa_assert(b.state.flags == 0);

	spa_assert(b.state.offset == 472);
	spa_assert(spa_pod_builder_push_sequence(&b, &f, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 488);
	spa_assert(spa_pod_builder_control(&b, 0, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 496);
	spa_assert(spa_pod_builder_float(&b, 0.667f) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 512);
	spa_assert(spa_pod_builder_control(&b, 12, 0) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(b.state.offset == 520);
	spa_assert(spa_pod_builder_double(&b, 1.22) == 0);
	spa_assert(b.state.flags == 0);
	spa_assert(spa_pod_builder_pop(&b, &f) != NULL);
	spa_assert(b.state.flags == 0);

	spa_assert(b.state.offset == 536);

	len = b.state.offset;
	pod = head = (struct spa_pod *)buffer;

	spa_assert(spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_none(pod));
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_bool(pod));
	spa_assert(spa_pod_get_bool(pod, &val.b) == 0);
	spa_assert(val.b == true);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_id(pod));
	spa_assert(spa_pod_get_id(pod, &val.I) == 0);
	spa_assert(val.I == SPA_TYPE_Object);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_int(pod));
	spa_assert(spa_pod_get_int(pod, &val.i) == 0);
	spa_assert(val.i == 21);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_float(pod));
	spa_assert(spa_pod_get_float(pod, &val.f) == 0);
	spa_assert(val.f == 0.8f);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_double(pod));
	spa_assert(spa_pod_get_double(pod, &val.d) == 0);
	spa_assert(val.d == -1.56);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_string(pod));
	spa_assert(spa_pod_get_string(pod, &val.s) == 0);
	spa_assert(strcmp(val.s, "test") == 0);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_bytes(pod));
	spa_assert(spa_pod_get_bytes(pod, &val.y, &yl) == 0);
	spa_assert(yl == 8);
	spa_assert(memcmp(val.y, "PipeWire", yl) == 0);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_pointer(pod));
	spa_assert(spa_pod_get_pointer(pod, &yl, &val.p) == 0);
	spa_assert(yl == SPA_TYPE_Object);
	spa_assert(val.p == &b);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_fd(pod));
	spa_assert(spa_pod_get_fd(pod, &val.l) == 0);
	spa_assert(val.l == 4);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_rectangle(pod));
	spa_assert(spa_pod_get_rectangle(pod, &val.R) == 0);
	spa_assert(memcmp(&val.R, &SPA_RECTANGLE(320,240), sizeof(struct spa_rectangle)) == 0);
	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_fraction(pod));
	spa_assert(spa_pod_get_fraction(pod, &val.F) == 0);
	spa_assert(memcmp(&val.F, &SPA_FRACTION(25,1), sizeof(struct spa_fraction)) == 0);

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_array(pod));
	spa_assert(SPA_POD_ARRAY_VALUE_TYPE(pod) == SPA_TYPE_Int);
	spa_assert(SPA_POD_ARRAY_VALUE_SIZE(pod) == sizeof(int32_t));
	spa_assert(SPA_POD_ARRAY_N_VALUES(pod) == 3);
	spa_assert((ai = SPA_POD_ARRAY_VALUES(pod)) != NULL);
	spa_assert(SPA_POD_ARRAY_CHILD(pod)->type == SPA_TYPE_Int);
	spa_assert(SPA_POD_ARRAY_CHILD(pod)->size == sizeof(int32_t));
	spa_assert(ai[0] == 1);
	spa_assert(ai[1] == 2);
	spa_assert(ai[2] == 3);
	i = 1;
	SPA_POD_ARRAY_FOREACH((struct spa_pod_array*)pod, ai) {
		spa_assert(*ai == i);
		i++;
	}

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_array(pod));
	spa_assert(SPA_POD_ARRAY_VALUE_TYPE(pod) == SPA_TYPE_Long);
	spa_assert(SPA_POD_ARRAY_VALUE_SIZE(pod) == sizeof(int64_t));
	spa_assert(SPA_POD_ARRAY_N_VALUES(pod) == SPA_N_ELEMENTS(longs));
	spa_assert((al = SPA_POD_ARRAY_VALUES(pod)) != NULL);
	spa_assert(SPA_POD_ARRAY_CHILD(pod)->type == SPA_TYPE_Long);
	spa_assert(SPA_POD_ARRAY_CHILD(pod)->size == sizeof(int64_t));
	for (i = 0; i < SPA_N_ELEMENTS(longs); i++)
		spa_assert(al[i] == longs[i]);
	i = 0;
	SPA_POD_ARRAY_FOREACH((struct spa_pod_array*)pod, al) {
		spa_assert(*al == longs[i++]);
	}

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_choice(pod));
	spa_assert(SPA_POD_CHOICE_TYPE(pod) == SPA_CHOICE_Enum);
	spa_assert(SPA_POD_CHOICE_FLAGS(pod) == 0);
	spa_assert(SPA_POD_CHOICE_VALUE_TYPE(pod) == SPA_TYPE_Long);
	spa_assert(SPA_POD_CHOICE_VALUE_SIZE(pod) == sizeof(int64_t));
	spa_assert(SPA_POD_CHOICE_N_VALUES(pod) == 3);
	spa_assert((al = SPA_POD_CHOICE_VALUES(pod)) != NULL);
	spa_assert(SPA_POD_CHOICE_CHILD(pod)->type == SPA_TYPE_Long);
	spa_assert(SPA_POD_CHOICE_CHILD(pod)->size == sizeof(int64_t));
	spa_assert(al[0] == 1);
	spa_assert(al[1] == 2);
	spa_assert(al[2] == 3);
	i = 1;
	SPA_POD_CHOICE_FOREACH((struct spa_pod_choice*)pod, al) {
		spa_assert(*al == i);
		i++;
	}

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_struct(pod));
	i = 0;
	SPA_POD_STRUCT_FOREACH(pod, it) {
		switch (i++) {
		case 0:
			spa_assert(spa_pod_is_int(it));
			spa_assert(spa_pod_get_int(it, &val.i) == 0 && val.i == 21);
			break;
		case 1:
			spa_assert(spa_pod_is_float(it));
			spa_assert(spa_pod_get_float(it, &val.f) == 0 && val.f == 0.8f);
			break;
		case 2:
			spa_assert(spa_pod_is_double(it));
			spa_assert(spa_pod_get_double(it, &val.d) == 0 && val.d == -1.56);
			break;
		default:
			spa_assert_not_reached();
			break;
		}
	}

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_object(pod));
	spa_assert(spa_pod_is_object_type(pod, SPA_TYPE_OBJECT_Props));
	spa_assert(spa_pod_is_object_id(pod, 0));
	i = 0;
	SPA_POD_OBJECT_FOREACH((const struct spa_pod_object*)pod, prop) {
		switch (i++) {
		case 0:
			spa_assert(prop->key == 1);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_int(&prop->value, &val.i) == 0 && val.i == 21);
			break;
		case 1:
			spa_assert(prop->key == 2);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_long(&prop->value, &val.l) == 0 && val.l == 42);
			break;
		case 2:
			spa_assert(prop->key == 3);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_string(&prop->value, &val.s) == 0 &&
					strcmp(val.s, "test123") == 0);
			break;
		default:
			spa_assert_not_reached();
			break;
		}
	}
	spa_assert((prop = spa_pod_find_prop(pod, NULL, 3)) != NULL);
	spa_assert(prop->key == 3);
	spa_assert(spa_pod_get_string(&prop->value, &val.s) == 0 &&
				strcmp(val.s, "test123") == 0);
	spa_assert((prop = spa_pod_find_prop(pod, prop, 1)) != NULL);
	spa_assert(prop->key == 1);
	spa_assert(spa_pod_get_int(&prop->value, &val.i) == 0 && val.i == 21);
	spa_assert((prop = spa_pod_find_prop(pod, prop, 2)) != NULL);
	spa_assert(prop->key == 2);
	spa_assert(spa_pod_get_long(&prop->value, &val.l) == 0 && val.l == 42);
	spa_assert((prop = spa_pod_find_prop(pod, prop, 5)) == NULL);

	spa_assert((prop = spa_pod_find_prop(pod, NULL, 3)) != NULL);
	spa_assert(prop->key == 3);
	spa_assert(spa_pod_get_string(&prop->value, &val.s) == 0 &&
				strcmp(val.s, "test123") == 0);

	spa_assert((pod = spa_pod_next(pod)) != NULL && spa_pod_is_inside(head, len, pod));
	spa_assert(spa_pod_is_sequence(pod));

	i = 0;
	SPA_POD_SEQUENCE_FOREACH((const struct spa_pod_sequence*)pod, control) {
		switch (i++) {
		case 0:
			spa_assert(control->offset == 0);
			spa_assert(SPA_POD_CONTROL_SIZE(control) == 20);
			spa_assert(spa_pod_get_float(&control->value, &val.f) == 0 && val.f == 0.667f);
			break;
		case 1:
			spa_assert(control->offset == 12);
			spa_assert(SPA_POD_CONTROL_SIZE(control) == 24);
			spa_assert(spa_pod_get_double(&control->value, &val.d) == 0 && val.d == 1.22);
			break;
		default:
			spa_assert_not_reached();
			break;
		}
	}
}

static void test_empty(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod *array, *a2, *choice, *ch2;
	struct spa_pod_frame f;
	uint32_t n_vals, ch;

	/* create empty arrays */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_array(&b, &f) == 0);
	spa_assert(spa_pod_builder_child(&b, sizeof(uint32_t), SPA_TYPE_Id) == 0);
	spa_assert((array = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_debug_mem(0, array, 16);
	spa_assert(spa_pod_is_array(array));
	spa_assert((a2 = spa_pod_get_array(array, &n_vals)) != NULL);
	spa_assert(n_vals == 0);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_array(&b, &f) == 0);
	spa_assert((array = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_assert(spa_pod_is_array(array));
	spa_assert((a2 = spa_pod_get_array(array, &n_vals)) != NULL);
	spa_assert(n_vals == 0);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_array(&b, &f) == 0);
	spa_assert(spa_pod_builder_none(&b) == 0);
	spa_assert((array = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_assert(spa_pod_is_array(array));
	spa_assert((a2 = spa_pod_get_array(array, &n_vals)) != NULL);
	spa_assert(n_vals == 0);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_array(&b, 4, SPA_TYPE_Id, 0, NULL) == 0);
	array = (struct spa_pod*)buffer;
	spa_assert(spa_pod_is_array(array));
	spa_assert((a2 = spa_pod_get_array(array, &n_vals)) != NULL);
	spa_assert(n_vals == 0);

	/* create empty choice */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_choice(&b, &f, 0, 0) == 0);
	spa_assert(spa_pod_builder_child(&b, sizeof(uint32_t), SPA_TYPE_Id) == 0);
	spa_assert((choice = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_debug_mem(0, choice, 32);
	spa_assert(spa_pod_is_choice(choice));
	spa_assert((ch2 = spa_pod_get_values(choice, &n_vals, &ch)) != NULL);
	spa_assert(n_vals == 0);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_choice(&b, &f, 0, 0) == 0);
	spa_assert((choice = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_assert(spa_pod_is_choice(choice));
	spa_assert((ch2 = spa_pod_get_values(choice, &n_vals, &ch)) != NULL);
	spa_assert(n_vals == 0);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_assert(spa_pod_builder_push_choice(&b, &f, 0, 0) == 0);
	spa_assert(spa_pod_builder_none(&b) == 0);
	spa_assert((choice = spa_pod_builder_pop(&b, &f)) != NULL);
	spa_assert(spa_pod_is_choice(choice));
	spa_assert((ch2 = spa_pod_get_values(choice, &n_vals, &ch)) != NULL);
	spa_assert(n_vals == 0);
}

static void test_varargs(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod *pod;
	struct spa_pod_prop *prop;
	uint32_t i, *aI;
	union {
		bool b;
		uint32_t I;
		int32_t i;
		int64_t l;
		float f;
		double d;
		const char *s;
		const void *y;
		const void *p;
		int64_t h;
		struct spa_rectangle R;
		struct spa_fraction F;
	} val;
	uint32_t media_type, media_subtype, format;
	int32_t views;
	struct spa_rectangle *aR, size;
	struct spa_fraction *aF, framerate;
	struct spa_pod *Vformat, *Vsize, *Vframerate;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	pod = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Format, 0,
		SPA_FORMAT_mediaType,		SPA_POD_Id(SPA_MEDIA_TYPE_video),
		SPA_FORMAT_mediaSubtype,	SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
		SPA_FORMAT_VIDEO_format,	SPA_POD_CHOICE_ENUM_Id(3,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_YUY2),
		SPA_FORMAT_VIDEO_size,		SPA_POD_CHOICE_RANGE_Rectangle(
							&SPA_RECTANGLE(320,242),
							&SPA_RECTANGLE(1,1),
							&SPA_RECTANGLE(INT32_MAX,INT32_MAX)),
		SPA_FORMAT_VIDEO_framerate,	SPA_POD_CHOICE_RANGE_Fraction(
							&SPA_FRACTION(25,1),
							&SPA_FRACTION(0,1),
							&SPA_FRACTION(INT32_MAX,1)));

	i = 0;
	SPA_POD_OBJECT_FOREACH((const struct spa_pod_object*)pod, prop) {
		switch (i++) {
		case 0:
			spa_assert(prop->key == SPA_FORMAT_mediaType);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_id(&prop->value, &val.I) == 0 && val.I == SPA_MEDIA_TYPE_video);
			break;
		case 1:
			spa_assert(prop->key == SPA_FORMAT_mediaSubtype);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_id(&prop->value, &val.I) == 0 && val.I == SPA_MEDIA_SUBTYPE_raw);
			break;
		case 2:
			spa_assert(prop->key == SPA_FORMAT_VIDEO_format);
			spa_assert(spa_pod_is_choice(&prop->value));
			spa_assert(SPA_POD_CHOICE_TYPE(&prop->value) == SPA_CHOICE_Enum);
			spa_assert(SPA_POD_CHOICE_N_VALUES(&prop->value) == 3);
			spa_assert(SPA_POD_CHOICE_VALUE_TYPE(&prop->value) == SPA_TYPE_Id);
			spa_assert(SPA_POD_CHOICE_VALUE_SIZE(&prop->value) == sizeof(uint32_t));
			spa_assert((aI = SPA_POD_CHOICE_VALUES(&prop->value)) != NULL);
			spa_assert(aI[0] == SPA_VIDEO_FORMAT_I420);
			spa_assert(aI[1] == SPA_VIDEO_FORMAT_I420);
			spa_assert(aI[2] == SPA_VIDEO_FORMAT_YUY2);
			break;
		case 3:
			spa_assert(prop->key == SPA_FORMAT_VIDEO_size);
			spa_assert(spa_pod_is_choice(&prop->value));
			spa_assert(SPA_POD_CHOICE_TYPE(&prop->value) == SPA_CHOICE_Range);
			spa_assert(SPA_POD_CHOICE_N_VALUES(&prop->value) == 3);
			spa_assert(SPA_POD_CHOICE_VALUE_TYPE(&prop->value) == SPA_TYPE_Rectangle);
			spa_assert(SPA_POD_CHOICE_VALUE_SIZE(&prop->value) == sizeof(struct spa_rectangle));
			spa_assert((aR = SPA_POD_CHOICE_VALUES(&prop->value)) != NULL);
			spa_assert(memcmp(&aR[0], &SPA_RECTANGLE(320,242), sizeof(struct spa_rectangle)) == 0);
			spa_assert(memcmp(&aR[1], &SPA_RECTANGLE(1,1), sizeof(struct spa_rectangle)) == 0);
			spa_assert(memcmp(&aR[2], &SPA_RECTANGLE(INT32_MAX,INT32_MAX), sizeof(struct spa_rectangle)) == 0);
			break;
		case 4:
			spa_assert(prop->key == SPA_FORMAT_VIDEO_framerate);
			spa_assert(spa_pod_is_choice(&prop->value));
			spa_assert(SPA_POD_CHOICE_TYPE(&prop->value) == SPA_CHOICE_Range);
			spa_assert(SPA_POD_CHOICE_N_VALUES(&prop->value) == 3);
			spa_assert(SPA_POD_CHOICE_VALUE_TYPE(&prop->value) == SPA_TYPE_Fraction);
			spa_assert(SPA_POD_CHOICE_VALUE_SIZE(&prop->value) == sizeof(struct spa_fraction));
			spa_assert((aF = SPA_POD_CHOICE_VALUES(&prop->value)) != NULL);
			spa_assert(memcmp(&aF[0], &SPA_FRACTION(25,1), sizeof(struct spa_fraction)) == 0);
			spa_assert(memcmp(&aF[1], &SPA_FRACTION(0,1), sizeof(struct spa_fraction)) == 0);
			spa_assert(memcmp(&aF[2], &SPA_FRACTION(INT32_MAX,1), sizeof(struct spa_fraction)) == 0);
			break;
		default:
			spa_assert_not_reached();
			break;
		}
	}

	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,		SPA_POD_Id(&media_type),
		SPA_FORMAT_mediaSubtype,	SPA_POD_Id(&media_subtype),
		SPA_FORMAT_VIDEO_format,	SPA_POD_PodChoice(&Vformat),
		SPA_FORMAT_VIDEO_size,		SPA_POD_PodChoice(&Vsize),
		SPA_FORMAT_VIDEO_framerate,	SPA_POD_PodChoice(&Vframerate)) == 5);

	spa_assert(media_type == SPA_MEDIA_TYPE_video);
	spa_assert(media_subtype == SPA_MEDIA_SUBTYPE_raw);

	spa_assert(spa_pod_is_choice(Vformat));
	spa_assert(SPA_POD_CHOICE_TYPE(Vformat) == SPA_CHOICE_Enum);
	spa_assert(SPA_POD_CHOICE_N_VALUES(Vformat) == 3);
	spa_assert(SPA_POD_CHOICE_VALUE_TYPE(Vformat) == SPA_TYPE_Id);
	spa_assert(SPA_POD_CHOICE_VALUE_SIZE(Vformat) == sizeof(uint32_t));
	spa_assert((aI = SPA_POD_CHOICE_VALUES(Vformat)) != NULL);
	spa_assert(aI[0] == SPA_VIDEO_FORMAT_I420);
	spa_assert(aI[1] == SPA_VIDEO_FORMAT_I420);
	spa_assert(aI[2] == SPA_VIDEO_FORMAT_YUY2);

	spa_assert(spa_pod_is_choice(Vsize));
	spa_assert(SPA_POD_CHOICE_TYPE(Vsize) == SPA_CHOICE_Range);
	spa_assert(SPA_POD_CHOICE_N_VALUES(Vsize) == 3);
	spa_assert(SPA_POD_CHOICE_VALUE_TYPE(Vsize) == SPA_TYPE_Rectangle);
	spa_assert(SPA_POD_CHOICE_VALUE_SIZE(Vsize) == sizeof(struct spa_rectangle));
	spa_assert((aR = SPA_POD_CHOICE_VALUES(Vsize)) != NULL);
	spa_assert(memcmp(&aR[0], &SPA_RECTANGLE(320,242), sizeof(struct spa_rectangle)) == 0);
	spa_assert(memcmp(&aR[1], &SPA_RECTANGLE(1,1), sizeof(struct spa_rectangle)) == 0);
	spa_assert(memcmp(&aR[2], &SPA_RECTANGLE(INT32_MAX,INT32_MAX), sizeof(struct spa_rectangle)) == 0);

	spa_assert(spa_pod_is_choice(Vframerate));

	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,		SPA_POD_Id(&media_type),
		SPA_FORMAT_mediaSubtype,	SPA_POD_Id(&media_subtype),
		SPA_FORMAT_VIDEO_views,		SPA_POD_Int(&views),
		SPA_FORMAT_VIDEO_format,	SPA_POD_Id(&format),
		SPA_FORMAT_VIDEO_size,		SPA_POD_Rectangle(&size),
		SPA_FORMAT_VIDEO_framerate,	SPA_POD_Fraction(&framerate)) == -ESRCH);

	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,		SPA_POD_Id(&media_type),
		SPA_FORMAT_mediaSubtype,	SPA_POD_Id(&media_subtype),
		SPA_FORMAT_VIDEO_format,	SPA_POD_Id(&format),
		SPA_FORMAT_VIDEO_size,		SPA_POD_Rectangle(&size),
		SPA_FORMAT_VIDEO_framerate,	SPA_POD_Fraction(&framerate)) == -EPROTO);

	spa_debug_pod(0, NULL, pod);
	spa_pod_fixate(pod);

	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,		SPA_POD_Id(&media_type),
		SPA_FORMAT_mediaSubtype,	SPA_POD_Id(&media_subtype),
		SPA_FORMAT_VIDEO_format,	SPA_POD_Id(&format),
		SPA_FORMAT_VIDEO_views,		SPA_POD_OPT_Int(&views),
		SPA_FORMAT_VIDEO_size,		SPA_POD_Rectangle(&size),
		SPA_FORMAT_VIDEO_framerate,	SPA_POD_Fraction(&framerate)) == 5);

	spa_assert(media_type == SPA_MEDIA_TYPE_video);
	spa_assert(media_subtype == SPA_MEDIA_SUBTYPE_raw);
	spa_assert(format == SPA_VIDEO_FORMAT_I420);
	spa_assert(memcmp(&size, &SPA_RECTANGLE(320,242), sizeof(struct spa_rectangle)) == 0);
	spa_assert(memcmp(&framerate, &SPA_FRACTION(25,1), sizeof(struct spa_fraction)) == 0);

	spa_debug_pod(0, NULL, pod);
}

static void test_varargs2(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod *pod;
	struct spa_pod_prop *prop;
	uint32_t i, j;
	struct {
		bool b;
		uint32_t I;
		int32_t i;
		int64_t l;
		float f;
		double d;
		const char *s;
		uint32_t yl;
		const void *y;
		uint32_t ptype;
		const void *p;
		uint32_t asize, atype, anvals;
		const void *a;
		int64_t h;
		struct spa_rectangle R;
		struct spa_fraction F;
		struct spa_pod *P;
	} val;
	uint8_t bytes[] = { 0x56, 0x00, 0x12, 0xf3, 0xba };
	int64_t longs[] = { 1002, 5383, 28944, 1237748 }, *al;
	struct spa_pod_int pi = SPA_POD_INIT_Int(77);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	pod = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Props, 0,
		1,	SPA_POD_Bool(true),
		2,	SPA_POD_Id(SPA_TYPE_Id),
		3,	SPA_POD_Int(3),
		4,	SPA_POD_Long(4LL),
		5,	SPA_POD_Float(0.453f),
		6,	SPA_POD_Double(0.871),
		7,	SPA_POD_String("test"),
		8,	SPA_POD_Bytes(bytes, sizeof(bytes)),
		9,	SPA_POD_Rectangle(&SPA_RECTANGLE(3,4)),
		10,	SPA_POD_Fraction(&SPA_FRACTION(24,1)),
		11,	SPA_POD_Array(sizeof(int64_t), SPA_TYPE_Long, SPA_N_ELEMENTS(longs), longs),
		12,	SPA_POD_Pointer(SPA_TYPE_Object, &b),
		13,	SPA_POD_Fd(3),
		14,	SPA_POD_Pod(&pi));

	spa_debug_pod(0, NULL, pod);

	i = 0;
	SPA_POD_OBJECT_FOREACH((const struct spa_pod_object*)pod, prop) {
		switch (i++) {
		case 0:
			spa_assert(prop->key == 1);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_bool(&prop->value, &val.b) == 0 && val.b == true);
			break;
		case 1:
			spa_assert(prop->key == 2);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_id(&prop->value, &val.I) == 0 && val.I == SPA_TYPE_Id);
			break;
		case 2:
			spa_assert(prop->key == 3);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_int(&prop->value, &val.i) == 0 && val.i == 3);
			break;
		case 3:
			spa_assert(prop->key == 4);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_long(&prop->value, &val.l) == 0 && val.l == 4);
			break;
		case 4:
			spa_assert(prop->key == 5);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_float(&prop->value, &val.f) == 0 && val.f == 0.453f);
			break;
		case 5:
			spa_assert(prop->key == 6);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_double(&prop->value, &val.d) == 0 && val.d == 0.871);
			break;
		case 6:
			spa_assert(prop->key == 7);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 21);
			spa_assert(spa_pod_get_string(&prop->value, &val.s) == 0);
			spa_assert(strcmp(val.s, "test") == 0);
			break;
		case 7:
			spa_assert(prop->key == 8);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 21);
			spa_assert(spa_pod_get_bytes(&prop->value, &val.y, &val.yl) == 0);
			spa_assert(val.yl == sizeof(bytes));
			spa_assert(memcmp(val.y, bytes, val.yl) == 0);
			break;
		case 8:
			spa_assert(prop->key == 9);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_rectangle(&prop->value, &val.R) == 0);
			spa_assert(memcmp(&val.R, &SPA_RECTANGLE(3,4), sizeof(struct spa_rectangle)) == 0);
			break;
		case 9:
			spa_assert(prop->key == 10);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_fraction(&prop->value, &val.F) == 0);
			spa_assert(memcmp(&val.F, &SPA_FRACTION(24,1), sizeof(struct spa_fraction)) == 0);
			break;
		case 10:
			spa_assert(prop->key == 11);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 56);
			spa_assert(spa_pod_is_array(&prop->value));
			spa_assert(SPA_POD_ARRAY_VALUE_TYPE(&prop->value) == SPA_TYPE_Long);
			spa_assert(SPA_POD_ARRAY_VALUE_SIZE(&prop->value) == sizeof(int64_t));
			spa_assert(SPA_POD_ARRAY_N_VALUES(&prop->value) == SPA_N_ELEMENTS(longs));
			spa_assert((al = SPA_POD_ARRAY_VALUES(&prop->value)) != NULL);
			spa_assert(SPA_POD_ARRAY_CHILD(&prop->value)->type == SPA_TYPE_Long);
			spa_assert(SPA_POD_ARRAY_CHILD(&prop->value)->size == sizeof(int64_t));
			for (j = 0; j < SPA_N_ELEMENTS(longs); j++)
				spa_assert(al[j] == longs[j]);
			break;
		case 11:
			spa_assert(prop->key == 12);
			spa_assert(SPA_POD_PROP_SIZE(prop) == (sizeof(struct spa_pod_prop) +
					sizeof(struct spa_pod_pointer_body)));
			spa_assert(spa_pod_get_pointer(&prop->value, &val.ptype, &val.p) == 0);
			spa_assert(val.ptype == SPA_TYPE_Object);
			spa_assert(val.p == &b);
			break;
		case 12:
			spa_assert(prop->key == 13);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 24);
			spa_assert(spa_pod_get_fd(&prop->value, &val.h) == 0);
			spa_assert(val.h == 3);
			break;
		case 13:
			spa_assert(prop->key == 14);
			spa_assert(SPA_POD_PROP_SIZE(prop) == 20);
			spa_assert(spa_pod_get_int(&prop->value, &val.i) == 0);
			spa_assert(val.i == 77);
			break;
		default:
			spa_assert_not_reached();
			break;
		}
	}
	spa_assert(spa_pod_parse_object(pod, SPA_TYPE_OBJECT_Format, NULL) == -EPROTO);
	spa_assert(spa_pod_parse_object(pod, SPA_TYPE_OBJECT_Props, NULL) == 0);

	spa_zero(val);
	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Props, NULL,
		1,	SPA_POD_Bool(&val.b),
		2,	SPA_POD_Id(&val.I),
		3,	SPA_POD_Int(&val.i),
		4,	SPA_POD_Long(&val.l),
		5,	SPA_POD_Float(&val.f),
		6,	SPA_POD_Double(&val.d),
		7,	SPA_POD_String(&val.s),
		8,	SPA_POD_Bytes(&val.y, &val.yl),
		9,	SPA_POD_Rectangle(&val.R),
		10,	SPA_POD_Fraction(&val.F),
		11,	SPA_POD_Array(&val.asize, &val.atype, &val.anvals, &val.a),
		12,	SPA_POD_Pointer(&val.ptype, &val.p),
		13,	SPA_POD_Fd(&val.h),
		14,	SPA_POD_Pod(&val.P)) == 14);

	spa_assert(val.b == true);
	spa_assert(val.I == SPA_TYPE_Id);
	spa_assert(val.i == 3);
	spa_assert(val.l == 4);
	spa_assert(val.f == 0.453f);
	spa_assert(val.d == 0.871);
	spa_assert(strcmp(val.s, "test") == 0);
	spa_assert(val.yl == sizeof(bytes));
	spa_assert(memcmp(val.y, bytes, sizeof(bytes)) == 0);
	spa_assert(memcmp(&val.R, &SPA_RECTANGLE(3, 4), sizeof(struct spa_rectangle)) == 0);
	spa_assert(memcmp(&val.F, &SPA_FRACTION(24, 1), sizeof(struct spa_fraction)) == 0);
	spa_assert(val.asize == sizeof(int64_t));
	spa_assert(val.atype == SPA_TYPE_Long);
	spa_assert(val.anvals == SPA_N_ELEMENTS(longs));
	spa_assert(memcmp(val.a, longs, val.anvals * val.asize) == 0);
	spa_assert(val.ptype == SPA_TYPE_Object);
	spa_assert(val.p == &b);
	spa_assert(val.h == 3);
	spa_assert(memcmp(val.P, &pi, sizeof(pi)) == 0);

	spa_zero(val);
	spa_assert(spa_pod_parse_object(pod,
		SPA_TYPE_OBJECT_Props, NULL,
		0,	SPA_POD_OPT_Bool(&val.b),
		0,	SPA_POD_OPT_Id(&val.I),
		0,	SPA_POD_OPT_Int(&val.i),
		0,	SPA_POD_OPT_Long(&val.l),
		0,	SPA_POD_OPT_Float(&val.f),
		0,	SPA_POD_OPT_Double(&val.d),
		0,	SPA_POD_OPT_String(&val.s),
		0,	SPA_POD_OPT_Bytes(&val.y, &val.yl),
		0,	SPA_POD_OPT_Rectangle(&val.R),
		0,	SPA_POD_OPT_Fraction(&val.F),
		0,	SPA_POD_OPT_Array(&val.asize, &val.atype, &val.anvals, &val.a),
		0,	SPA_POD_OPT_Pointer(&val.ptype, &val.p),
		0,	SPA_POD_OPT_Fd(&val.h),
		0,	SPA_POD_OPT_Pod(&val.P)) == 0);

	for (i = 1; i < 15; i++) {
		spa_zero(val);
		spa_assert(spa_pod_parse_object(pod,
			SPA_TYPE_OBJECT_Props, NULL,
			i,	SPA_POD_OPT_Bool(&val.b),
			i,	SPA_POD_OPT_Id(&val.I),
			i,	SPA_POD_OPT_Int(&val.i),
			i,	SPA_POD_OPT_Long(&val.l),
			i,	SPA_POD_OPT_Float(&val.f),
			i,	SPA_POD_OPT_Double(&val.d),
			i,	SPA_POD_OPT_String(&val.s),
			i,	SPA_POD_OPT_Bytes(&val.y, &val.yl),
			i,	SPA_POD_OPT_Rectangle(&val.R),
			i,	SPA_POD_OPT_Fraction(&val.F),
			i,	SPA_POD_OPT_Array(&val.asize, &val.atype, &val.anvals, &val.a),
			i,	SPA_POD_OPT_Pointer(&val.ptype, &val.p),
			i,	SPA_POD_OPT_Fd(&val.h),
			i,	SPA_POD_OPT_Pod(&val.P)) == 2);
	}
}

static void test_parser(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod_parser p;
	struct spa_pod_frame f;
	struct spa_pod *pod;
	struct {
		bool b;
		uint32_t I;
		int32_t i;
		int64_t l;
		float f;
		double d;
		const char *s;
		uint32_t yl;
		const void *y;
		uint32_t ptype;
		const void *p;
		uint32_t asize, atype, anvals;
		const void *a;
		int64_t h;
		struct spa_rectangle R;
		struct spa_fraction F;
		struct spa_pod *P;
	} val;
	uint8_t bytes[] = { 0x56, 0x00, 0x12, 0xf3, 0xba };
	int64_t longs[] = { 1002, 5383, 28944, 1237748 };
	struct spa_pod_int pi = SPA_POD_INIT_Int(77);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	pod = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Props, 0,
		1,	SPA_POD_Bool(true),
		2,	SPA_POD_Id(SPA_TYPE_Id),
		3,	SPA_POD_Int(3),
		4,	SPA_POD_Long(4LL),
		5,	SPA_POD_Float(0.453f),
		6,	SPA_POD_Double(0.871),
		7,	SPA_POD_String("test"),
		8,	SPA_POD_Bytes(bytes, sizeof(bytes)),
		9,	SPA_POD_Rectangle(&SPA_RECTANGLE(3,4)),
		10,	SPA_POD_Fraction(&SPA_FRACTION(24,1)),
		11,	SPA_POD_Array(sizeof(int64_t), SPA_TYPE_Long, SPA_N_ELEMENTS(longs), longs),
		12,	SPA_POD_Pointer(SPA_TYPE_Object, &b),
		13,	SPA_POD_Fd(3),
		14,	SPA_POD_Pod(&pi));

	spa_debug_pod(0, NULL, pod);

	spa_pod_parser_pod(&p, pod);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_bool(&p, &val.b) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_id(&p, &val.I) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_int(&p, &val.i) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_long(&p, &val.l) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_float(&p, &val.f) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_double(&p, &val.d) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_string(&p, &val.s) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_bytes(&p, &val.y, &val.yl) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_rectangle(&p, &val.R) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_fraction(&p, &val.F) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_pointer(&p, &val.ptype, &val.p) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_fd(&p, &val.h) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_pod(&p, &val.P) == 0);
	spa_assert(p.state.offset == 392);
	spa_assert(spa_pod_is_object(val.P));

	spa_pod_parser_pod(&p, val.P);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_push_struct(&p, &f) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_push_object(&p, &f, SPA_TYPE_OBJECT_Format, NULL) == -EPROTO);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_push_object(&p, &f, SPA_TYPE_OBJECT_Props, NULL) == 0);
	spa_assert(p.state.offset == 392);
	spa_assert(spa_pod_parser_frame(&p, &f) == val.P);

	spa_zero(val);
	spa_assert(spa_pod_parser_get(&p,
		1,	SPA_POD_OPT_Bool(&val.b),
		2,	SPA_POD_OPT_Id(&val.I),
		3,	SPA_POD_OPT_Int(&val.i),
		4,	SPA_POD_OPT_Long(&val.l),
		5,	SPA_POD_OPT_Float(&val.f),
		6,	SPA_POD_OPT_Double(&val.d),
		7,	SPA_POD_OPT_String(&val.s),
		8,	SPA_POD_OPT_Bytes(&val.y, &val.yl),
		9,	SPA_POD_OPT_Rectangle(&val.R),
		10,	SPA_POD_OPT_Fraction(&val.F),
		11,	SPA_POD_OPT_Array(&val.asize, &val.atype, &val.anvals, &val.a),
		12,	SPA_POD_OPT_Pointer(&val.ptype, &val.p),
		13,	SPA_POD_OPT_Fd(&val.h),
		14,	SPA_POD_OPT_Pod(&val.P), 0) == 14);
	spa_pod_parser_pop(&p, &f);

	spa_assert(val.b == true);
	spa_assert(val.I == SPA_TYPE_Id);
	spa_assert(val.i == 3);
	spa_assert(val.l == 4);
	spa_assert(val.f == 0.453f);
	spa_assert(val.d == 0.871);
	spa_assert(strcmp(val.s, "test") == 0);
	spa_assert(val.yl == sizeof(bytes));
	spa_assert(memcmp(val.y, bytes, sizeof(bytes)) == 0);
	spa_assert(memcmp(&val.R, &SPA_RECTANGLE(3, 4), sizeof(struct spa_rectangle)) == 0);
	spa_assert(memcmp(&val.F, &SPA_FRACTION(24, 1), sizeof(struct spa_fraction)) == 0);
	spa_assert(val.asize == sizeof(int64_t));
	spa_assert(val.atype == SPA_TYPE_Long);
	spa_assert(val.anvals == SPA_N_ELEMENTS(longs));
	spa_assert(memcmp(val.a, longs, val.anvals * val.asize) == 0);
	spa_assert(val.ptype == SPA_TYPE_Object);
	spa_assert(val.p == &b);
	spa_assert(val.h == 3);
	spa_assert(memcmp(val.P, &pi, sizeof(pi)) == 0);

	spa_assert(p.state.offset == 392);
}

static void test_parser2(void)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	struct spa_pod_parser p;
	struct spa_pod_frame f;
	struct spa_pod *pod;
	struct {
		bool b;
		uint32_t I;
		int32_t i;
		int64_t l;
		float f;
		double d;
		const char *s;
		uint32_t yl;
		const void *y;
		uint32_t ptype;
		const void *p;
		uint32_t asize, atype, anvals;
		const void *a;
		int64_t h;
		struct spa_rectangle R;
		struct spa_fraction F;
		struct spa_pod *P;
	} val;
	uint8_t bytes[] = { 0x56, 0x00, 0x12, 0xf3, 0xba };
	int64_t longs[] = { 1002, 5383, 28944, 1237748 };
	struct spa_pod_int pi = SPA_POD_INIT_Int(77);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	pod = spa_pod_builder_add_struct(&b,
		SPA_POD_Bool(true),
		SPA_POD_Id(SPA_TYPE_Id),
		SPA_POD_Int(3),
		SPA_POD_Long(4LL),
		SPA_POD_Float(0.453f),
		SPA_POD_Double(0.871),
		SPA_POD_String("test"),
		SPA_POD_Bytes(bytes, sizeof(bytes)),
		SPA_POD_Rectangle(&SPA_RECTANGLE(3,4)),
		SPA_POD_Fraction(&SPA_FRACTION(24,1)),
		SPA_POD_Array(sizeof(int64_t), SPA_TYPE_Long, SPA_N_ELEMENTS(longs), longs),
		SPA_POD_Pointer(SPA_TYPE_Object, &b),
		SPA_POD_Fd(3),
		SPA_POD_Pod(&pi));

	spa_debug_pod(0, NULL, pod);

	spa_pod_parser_pod(&p, pod);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_bool(&p, &val.b) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_id(&p, &val.I) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_int(&p, &val.i) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_long(&p, &val.l) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_float(&p, &val.f) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_double(&p, &val.d) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_string(&p, &val.s) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_bytes(&p, &val.y, &val.yl) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_rectangle(&p, &val.R) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_fraction(&p, &val.F) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_pointer(&p, &val.ptype, &val.p) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_fd(&p, &val.h) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_get_pod(&p, &val.P) == 0);
	spa_assert(p.state.offset == 272);
	spa_assert(spa_pod_is_struct(val.P));

	spa_pod_parser_pod(&p, val.P);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_push_object(&p, &f, SPA_TYPE_OBJECT_Format, NULL) == -EINVAL);
	spa_assert(p.state.offset == 0);
	spa_assert(spa_pod_parser_push_struct(&p, &f) == 0);
	spa_assert(f.pod.type == SPA_TYPE_Struct);
	spa_assert(f.pod.size == 264);
	spa_assert(f.offset == 0);
	spa_assert(p.state.frame == &f);
	spa_assert(spa_pod_parser_frame(&p, &f) == val.P);
	spa_assert(p.state.offset == 8);
	spa_assert(spa_pod_parser_get_bool(&p, &val.b) == 0 && val.b == true);
	spa_assert(p.state.offset == 24);
	spa_assert(spa_pod_parser_get_id(&p, &val.I) == 0 && val.I == SPA_TYPE_Id);
	spa_assert(p.state.offset == 40);
	spa_assert(spa_pod_parser_get_int(&p, &val.i) == 0 && val.i == 3);
	spa_assert(p.state.offset == 56);
	spa_assert(spa_pod_parser_get_long(&p, &val.l) == 0 && val.l == 4);
	spa_assert(p.state.offset == 72);
	spa_assert(spa_pod_parser_get_float(&p, &val.f) == 0 && val.f == 0.453f);
	spa_assert(p.state.offset == 88);
	spa_assert(spa_pod_parser_get_double(&p, &val.d) == 0 && val.d == 0.871);
	spa_assert(p.state.offset == 104);
	spa_assert(spa_pod_parser_get_string(&p, &val.s) == 0 && strcmp(val.s, "test") == 0);
	spa_assert(p.state.offset == 120);
	spa_assert(spa_pod_parser_get_bytes(&p, &val.y, &val.yl) == 0);
	spa_assert(val.yl == sizeof(bytes));
	spa_assert(memcmp(bytes, val.y, sizeof(bytes)) == 0);
	spa_assert(p.state.offset == 136);
	spa_assert(spa_pod_parser_get_rectangle(&p, &val.R) == 0);
	spa_assert(memcmp(&val.R, &SPA_RECTANGLE(3,4), sizeof(struct spa_rectangle)) == 0);
	spa_assert(p.state.offset == 152);
	spa_assert(spa_pod_parser_get_fraction(&p, &val.F) == 0);
	spa_assert(memcmp(&val.F, &SPA_FRACTION(24,1), sizeof(struct spa_fraction)) == 0);
	spa_assert(p.state.offset == 168);
	spa_assert((val.P = spa_pod_parser_next(&p)) != NULL);
	spa_assert(spa_pod_is_array(val.P));
	spa_assert(p.state.offset == 216);
	spa_assert(SPA_POD_ARRAY_VALUE_TYPE(val.P) == SPA_TYPE_Long);
	spa_assert(SPA_POD_ARRAY_VALUE_SIZE(val.P) == sizeof(int64_t));
	spa_assert(SPA_POD_ARRAY_N_VALUES(val.P) == SPA_N_ELEMENTS(longs));
	spa_assert(spa_pod_parser_get_pointer(&p, &val.ptype, &val.p) == 0);
	spa_assert(val.ptype == SPA_TYPE_Object);
	spa_assert(val.p == &b);
	spa_assert(p.state.offset == 240);
	spa_assert(spa_pod_parser_get_fd(&p, &val.h) == 0);
	spa_assert(val.h == 3);
	spa_assert(p.state.offset == 256);
	spa_assert(spa_pod_parser_get_pod(&p, &val.P) == 0);
	spa_assert(p.state.offset == 272);
	spa_assert(spa_pod_is_int(val.P));
	spa_pod_parser_pop(&p, &f);
	spa_assert(p.state.offset == 272);
	spa_assert(p.state.frame == NULL);
}

static void test_static(void)
{
	struct _test_format {
		struct spa_pod_object fmt;

		struct {
			struct spa_pod_prop prop_media_type	SPA_ALIGNED(8);
			uint32_t media_type;

			struct spa_pod_prop prop_media_subtype	SPA_ALIGNED(8);
			uint32_t media_subtype;

			struct spa_pod_prop prop_format		SPA_ALIGNED(8);
			struct {
				struct spa_pod_choice_body choice;
				uint32_t def_format;
				uint32_t enum_format[2];
			} format_vals;

			struct spa_pod_prop prop_size		SPA_ALIGNED(8);
			struct {
				struct spa_pod_choice_body choice;
				struct spa_rectangle def_size;
				struct spa_rectangle min_size;
				struct spa_rectangle max_size;
			} size_vals;

			struct spa_pod_prop prop_framerate	SPA_ALIGNED(8);
			struct {
				struct spa_pod_choice_body choice;
				struct spa_fraction def_framerate;
				struct spa_fraction min_framerate;
				struct spa_fraction max_framerate;
			} framerate_vals;
		} props;
	} test_format = {
		SPA_POD_INIT_Object(sizeof(test_format.props) + sizeof(struct spa_pod_object_body),
				SPA_TYPE_OBJECT_Format, 0),
		{
			SPA_POD_INIT_Prop(SPA_FORMAT_mediaType, 0,
					  sizeof(test_format.props.media_type), SPA_TYPE_Id),
			SPA_MEDIA_TYPE_video,

			SPA_POD_INIT_Prop(SPA_FORMAT_mediaSubtype, 0,
					  sizeof(test_format.props.media_subtype), SPA_TYPE_Id),
			SPA_MEDIA_SUBTYPE_raw,

			SPA_POD_INIT_Prop(SPA_FORMAT_VIDEO_format, 0,
					  sizeof(test_format.props.format_vals), SPA_TYPE_Choice),
			{
				SPA_POD_INIT_CHOICE_BODY(SPA_CHOICE_Enum, 0,
						sizeof(uint32_t), SPA_TYPE_Id),
				SPA_VIDEO_FORMAT_I420,
				{ SPA_VIDEO_FORMAT_I420, SPA_VIDEO_FORMAT_YUY2 }
			},
			SPA_POD_INIT_Prop(SPA_FORMAT_VIDEO_size, 0,
					  sizeof(test_format.props.size_vals), SPA_TYPE_Choice),

			{
				SPA_POD_INIT_CHOICE_BODY(SPA_CHOICE_Range, 0,
						sizeof(struct spa_rectangle), SPA_TYPE_Rectangle),
				SPA_RECTANGLE(320,243),
				SPA_RECTANGLE(1,1), SPA_RECTANGLE(INT32_MAX, INT32_MAX)
			},
			SPA_POD_INIT_Prop(SPA_FORMAT_VIDEO_framerate, 0,
					  sizeof(test_format.props.framerate_vals), SPA_TYPE_Choice),
			{
				SPA_POD_INIT_CHOICE_BODY(SPA_CHOICE_Range, 0,
						sizeof(struct spa_fraction), SPA_TYPE_Fraction),
				SPA_FRACTION(25,1),
				SPA_FRACTION(0,1), SPA_FRACTION(INT32_MAX,1)
			}
		}
	};
	struct {
		uint32_t media_type;
		uint32_t media_subtype;
		uint32_t format;
		struct spa_rectangle size;
		struct spa_fraction framerate;
	} vals;
	int res;

	spa_debug_pod(0, NULL, &test_format.fmt.pod);

	spa_zero(vals);
	res = spa_pod_parse_object(&test_format.fmt.pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,       SPA_POD_Id(&vals.media_type),
		SPA_FORMAT_mediaSubtype,    SPA_POD_Id(&vals.media_subtype),
		SPA_FORMAT_VIDEO_format,    SPA_POD_Id(&vals.format),
		SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&vals.size),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&vals.framerate));

	spa_assert(res == -EPROTO);
	spa_assert(vals.media_type == SPA_MEDIA_TYPE_video);
	spa_assert(vals.media_subtype == SPA_MEDIA_SUBTYPE_raw);
	spa_assert(vals.format == 0);
	spa_assert(vals.size.width == 0 && vals.size.height == 0);
	spa_assert(vals.framerate.num == 0 && vals.framerate.denom == 0);

	spa_pod_fixate(&test_format.fmt.pod);

	spa_zero(vals);
	res = spa_pod_parse_object(&test_format.fmt.pod,
		SPA_TYPE_OBJECT_Format, NULL,
		SPA_FORMAT_mediaType,       SPA_POD_Id(&vals.media_type),
		SPA_FORMAT_mediaSubtype,    SPA_POD_Id(&vals.media_subtype),
		SPA_FORMAT_VIDEO_format,    SPA_POD_Id(&vals.format),
		SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&vals.size),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&vals.framerate));

	spa_assert(res == 5);
	spa_assert(vals.media_type == SPA_MEDIA_TYPE_video);
	spa_assert(vals.media_subtype == SPA_MEDIA_SUBTYPE_raw);
	spa_assert(vals.format == SPA_VIDEO_FORMAT_I420);
	spa_assert(vals.size.width == 320 && vals.size.height == 243);
	spa_assert(vals.framerate.num == 25 && vals.framerate.denom == 1);
}

static void test_overflow(void)
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_builder_state state;
	struct spa_pod_frame f[2];
	uint32_t idx;
	const char *labels[] = {
		"640x480p59", "720x480i29", "720x480p59", "720x576i25", "720x576p50",
		"1280x720p24", "1280x720p25", "1280x720p30", "1280x720p50", "1280x720p60",
		"1920x1080p24", "1920x1080p25", "1920x1080p30", "1920x1080i25", "1920x1080p50",
		"1920x1080i30", "1920x1080p60", "640x350p85", "640x400p85", "720x400p85",
		"640x480p72", "640x480p75", "640x480p85", "800x600p56", "800x600p60",
		"800x600p72", "800x600p75", "800x600p85", "800x600p119", "848x480p60",
		"1024x768i43", "1024x768p60", "1024x768p70", "1024x768p75", "1024x768p84",
		"1024x768p119", "1152x864p75", "1280x768p59", "1280x768p59", "1280x768p74",
		"1280x768p84", "1280x768p119", "1280x800p59", "1280x800p59", "1280x800p74",
		"1280x800p84", "1280x800p119", "1280x960p60", "1280x960p85", "1280x960p119",
		"1280x1024p60", "1280x1024p75", "1280x1024p85", "1280x1024p119", "1360x768p60",
		"1360x768p119", "1366x768p59", "1366x768p60", "1400x1050p59", "1400x1050p59",
		"1400x1050p74", "1400x1050p84", "1400x1050p119", "1440x900p59", "1440x900p59",
		"1440x900p74", "1440x900p84", "1440x900p119", "1600x900p60", "1600x1200p60",
		"1600x1200p65", "1600x1200p70", "1600x1200p75", "1600x1200p85", "1600x1200p119",
		"1680x1050p59", "1680x1050p59", "1680x1050p74", "1680x1050p84", "1680x1050p119",
		"1792x1344p59", "1792x1344p74", "1792x1344p119", "1856x1392p59", "1856x1392p75",
		"1856x1392p119", "1920x1200p59", "1920x1200p59", "1920x1200p74", "1920x1200p84",
		"1920x1200p119", "1920x1440p60", "1920x1440p75", "1920x1440p119", "2048x1152p60",
		"2560x1600p59", "2560x1600p59", "2560x1600p74", "2560x1600p84", "2560x1600p119",
		"3840x2160p24", "3840x2160p25", "3840x2160p30", "3840x2160p50", "3840x2160p60",
		"4096x2160p24", "4096x2160p25", "4096x2160p30", "4096x2160p50", "4096x2160p59",
		"4096x2160p60", NULL };
	struct spa_pod *pod;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	spa_pod_builder_push_object(&b, &f[0], SPA_TYPE_OBJECT_PropInfo, SPA_PARAM_PropInfo);
	spa_pod_builder_add(&b,
			SPA_PROP_INFO_id,    SPA_POD_Id(32567359),
			SPA_PROP_INFO_type,  SPA_POD_CHOICE_ENUM_Int(1, 0),
			SPA_PROP_INFO_name,  SPA_POD_String("DV Timings"),
			0);

	spa_pod_builder_get_state(&b, &state),

	spa_pod_builder_prop(&b, SPA_PROP_INFO_labels, 0);
	spa_pod_builder_push_struct(&b, &f[1]);

	for (idx = 0; labels[idx]; idx++) {
		spa_pod_builder_int(&b, idx);
		spa_pod_builder_string(&b, labels[idx]);
	}
	spa_assert(b.state.offset > sizeof(buffer));
	pod = spa_pod_builder_pop(&b, &f[1]);
	spa_assert(pod == NULL);
	spa_pod_builder_reset(&b, &state);

	spa_pod_builder_prop(&b, SPA_PROP_INFO_labels, 0);
	spa_pod_builder_push_struct(&b, &f[1]);
	pod = spa_pod_builder_pop(&b, &f[1]);

	spa_assert(b.state.offset < sizeof(buffer));
	pod = spa_pod_builder_pop(&b, &f[0]);
	spa_assert(pod != NULL);

	spa_debug_pod(0, NULL, pod);
}

int main(int argc, char *argv[])
{
	test_abi();
	test_init();
	test_empty();
	test_build();
	test_varargs();
	test_varargs2();
	test_parser();
	test_parser2();
	test_static();
	test_overflow();
	return 0;
}
