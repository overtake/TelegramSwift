/* Spa
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#include <spa/pod/pod.h>
#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/param/video/format-utils.h>
#include <spa/debug/pod.h>

#define MAX_COUNT 10000000

static void test_builder()
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = { NULL, };
	struct spa_pod_frame f[2];
	struct timespec ts;
	uint64_t t1, t2;
	uint64_t count = 0;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	t1 = SPA_TIMESPEC_TO_NSEC(&ts);

	fprintf(stderr, "test_builder() : ");
	for (count = 0; count < MAX_COUNT; count++) {
		spa_pod_builder_init(&b, buffer, sizeof(buffer));

		spa_pod_builder_push_object(&b, &f[0], SPA_TYPE_OBJECT_Format, 0);
		spa_pod_builder_prop(&b, SPA_FORMAT_mediaType, 0);
		spa_pod_builder_id(&b, SPA_MEDIA_TYPE_video);
		spa_pod_builder_prop(&b, SPA_FORMAT_mediaSubtype, 0);
		spa_pod_builder_id(&b, SPA_MEDIA_SUBTYPE_raw);

		spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_format, 0);
		spa_pod_builder_push_choice(&b, &f[1], SPA_CHOICE_Enum, 0);
		spa_pod_builder_id(&b, SPA_VIDEO_FORMAT_I420);
		spa_pod_builder_id(&b, SPA_VIDEO_FORMAT_I420);
		spa_pod_builder_id(&b, SPA_VIDEO_FORMAT_YUY2);
		spa_pod_builder_pop(&b, &f[1]);

		struct spa_rectangle size_min_max[] = { {1, 1}, {INT32_MAX, INT32_MAX} };
		spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_size, 0);
		spa_pod_builder_push_choice(&b, &f[1], SPA_CHOICE_Range, 0);
		spa_pod_builder_rectangle(&b, 320, 240);
		spa_pod_builder_raw(&b, size_min_max, sizeof(size_min_max));
		spa_pod_builder_pop(&b, &f[1]);

		struct spa_fraction rate_min_max[] = { {0, 1}, {INT32_MAX, 1} };
		spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_framerate, 0);
		spa_pod_builder_push_choice(&b, &f[1], SPA_CHOICE_Range, 0);
		spa_pod_builder_fraction(&b, 25, 1);
		spa_pod_builder_raw(&b, rate_min_max, sizeof(rate_min_max));
		spa_pod_builder_pop(&b, &f[1]);

		spa_pod_builder_pop(&b, &f[0]);
		clock_gettime(CLOCK_MONOTONIC, &ts);
		t2 = SPA_TIMESPEC_TO_NSEC(&ts);
		if (t2 - t1 > 1 * SPA_NSEC_PER_SEC)
			break;
	}
	fprintf(stderr, "elapsed %"PRIu64" count %"PRIu64" = %"PRIu64"/sec\n",
			t2 - t1, count, count * (uint64_t)SPA_NSEC_PER_SEC / (t2 - t1));
}

static void test_builder2()
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = { NULL, };
	struct timespec ts;
	uint64_t t1, t2;
	uint64_t count = 0;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	t1 = SPA_TIMESPEC_TO_NSEC(&ts);

	fprintf(stderr, "test_builder2() : ");
	for (count = 0; count < MAX_COUNT; count++) {
		spa_pod_builder_init(&b, buffer, sizeof(buffer));

		spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Format, 0,
				SPA_FORMAT_mediaType,	    SPA_POD_Id(SPA_MEDIA_TYPE_video),
				SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
				SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(3,
								SPA_VIDEO_FORMAT_I420,
								SPA_VIDEO_FORMAT_I420,
								SPA_VIDEO_FORMAT_YUY2),
				SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
								&SPA_RECTANGLE(320, 240),
								&SPA_RECTANGLE(1, 1),
								&SPA_RECTANGLE(INT32_MAX, INT32_MAX)),
				SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
								&SPA_FRACTION(25,1),
								&SPA_FRACTION(0,1),
								&SPA_FRACTION(INT32_MAX,1)));

		clock_gettime(CLOCK_MONOTONIC, &ts);
		t2 = SPA_TIMESPEC_TO_NSEC(&ts);
		if (t2 - t1 > 1 * SPA_NSEC_PER_SEC)
			break;
	}
	fprintf(stderr, "elapsed %"PRIu64" count %"PRIu64" = %"PRIu64"/sec\n",
			t2 - t1, count, count * (uint64_t)SPA_NSEC_PER_SEC / (t2 - t1));
}

static void test_parse()
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = { NULL, };
	struct timespec ts;
	uint64_t t1, t2;
	uint64_t count = 0;
	struct spa_pod *fmt;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	fmt = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Format, 0,
			SPA_FORMAT_mediaType,	    SPA_POD_Id(SPA_MEDIA_TYPE_video),
			SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
			SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(3,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_YUY2),
			SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
							&SPA_RECTANGLE(320, 240),
							&SPA_RECTANGLE(1, 1),
							&SPA_RECTANGLE(INT32_MAX, INT32_MAX)),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
							&SPA_FRACTION(25,1),
							&SPA_FRACTION(0,1),
							&SPA_FRACTION(INT32_MAX,1)));

	spa_pod_fixate(fmt);

	clock_gettime(CLOCK_MONOTONIC, &ts);
	t1 = SPA_TIMESPEC_TO_NSEC(&ts);

	fprintf(stderr, "test_parse() : ");
	for (count = 0; count < MAX_COUNT; count++) {
		struct {
			uint32_t media_type;
			uint32_t media_subtype;
			uint32_t format;
			struct spa_rectangle size;
			struct spa_fraction framerate;
		} vals;
		struct spa_pod_prop *prop;

		spa_zero(vals);

		SPA_POD_OBJECT_FOREACH((struct spa_pod_object*)fmt, prop) {
			uint32_t n_vals, choice;
			struct spa_pod *pod = spa_pod_get_values(&prop->value, &n_vals, &choice);

			switch(prop->key) {
			case SPA_FORMAT_mediaType:
				spa_pod_get_id(pod, &vals.media_type);
				break;
			case SPA_FORMAT_mediaSubtype:
				spa_pod_get_id(pod, &vals.media_subtype);
				break;
			case SPA_FORMAT_VIDEO_format:
				spa_pod_get_id(pod, &vals.format);
				break;
			case SPA_FORMAT_VIDEO_size:
				spa_pod_get_rectangle(pod, &vals.size);
				break;
			case SPA_FORMAT_VIDEO_framerate:
				spa_pod_get_fraction(pod, &vals.framerate);
				break;
			default:
				break;
			}
		}
		spa_assert(vals.media_type == SPA_MEDIA_TYPE_video);
		spa_assert(vals.media_subtype == SPA_MEDIA_SUBTYPE_raw);
		spa_assert(vals.format == SPA_VIDEO_FORMAT_I420);
		spa_assert(vals.size.width == 320 && vals.size.height == 240);
		spa_assert(vals.framerate.num == 25 && vals.framerate.denom == 1);

		clock_gettime(CLOCK_MONOTONIC, &ts);
		t2 = SPA_TIMESPEC_TO_NSEC(&ts);
		if (t2 - t1 > 1 * SPA_NSEC_PER_SEC)
			break;
	}
	fprintf(stderr, "elapsed %"PRIu64" count %"PRIu64" = %"PRIu64"/sec\n",
			t2 - t1, count, count * (uint64_t)SPA_NSEC_PER_SEC / (t2 - t1));
}

static void test_parser()
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = { NULL, };
	struct timespec ts;
	uint64_t t1, t2;
	uint64_t count = 0;
	struct spa_pod *fmt;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	fmt = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Format, 0,
			SPA_FORMAT_mediaType,	    SPA_POD_Id(SPA_MEDIA_TYPE_video),
			SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
			SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(3,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_I420,
							SPA_VIDEO_FORMAT_YUY2),
			SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
							&SPA_RECTANGLE(320, 240),
							&SPA_RECTANGLE(1, 1),
							&SPA_RECTANGLE(INT32_MAX, INT32_MAX)),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
							&SPA_FRACTION(25,1),
							&SPA_FRACTION(0,1),
							&SPA_FRACTION(INT32_MAX,1)));

	spa_pod_fixate(fmt);

	clock_gettime(CLOCK_MONOTONIC, &ts);
	t1 = SPA_TIMESPEC_TO_NSEC(&ts);

	fprintf(stderr, "test_parser() : ");
	for (count = 0; count < MAX_COUNT; count++) {
		struct {
			uint32_t media_type;
			uint32_t media_subtype;
			uint32_t format;
			struct spa_rectangle size;
			struct spa_fraction framerate;
		} vals;

		spa_zero(vals);

		spa_pod_parse_object(fmt,
			SPA_TYPE_OBJECT_Format, NULL,
			SPA_FORMAT_mediaType,	    SPA_POD_Id(&vals.media_type),
			SPA_FORMAT_mediaSubtype,    SPA_POD_Id(&vals.media_subtype),
			SPA_FORMAT_VIDEO_format,    SPA_POD_Id(&vals.format),
			SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&vals.size),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&vals.framerate));

		spa_assert(vals.media_type == SPA_MEDIA_TYPE_video);
		spa_assert(vals.media_subtype == SPA_MEDIA_SUBTYPE_raw);
		spa_assert(vals.format == SPA_VIDEO_FORMAT_I420);
		spa_assert(vals.size.width == 320 && vals.size.height == 240);
		spa_assert(vals.framerate.num == 25 && vals.framerate.denom == 1);

		clock_gettime(CLOCK_MONOTONIC, &ts);
		t2 = SPA_TIMESPEC_TO_NSEC(&ts);
		if (t2 - t1 > 1 * SPA_NSEC_PER_SEC)
			break;
	}
	fprintf(stderr, "elapsed %"PRIu64" count %"PRIu64" = %"PRIu64"/sec\n",
			t2 - t1, count, count * (uint64_t)SPA_NSEC_PER_SEC / (t2 - t1));
}

int main(int argc, char *argv[])
{
	test_builder();
	test_builder2();
	test_parse();
	test_parser();
	return 0;
}
