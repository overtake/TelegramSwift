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

#include "config.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#include <spa/debug/mem.h>

#include "test-helper.h"
#include "fmt-ops.c"

#define N_SAMPLES	253
#define N_CHANNELS	11

static uint32_t cpu_flags;

static uint8_t samp_in[N_SAMPLES * 4];
static uint8_t samp_out[N_SAMPLES * 4];
static uint8_t temp_in[N_SAMPLES * N_CHANNELS * 4];
static uint8_t temp_out[N_SAMPLES * N_CHANNELS * 4];

static void compare_mem(int i, int j, const void *m1, const void *m2, size_t size)
{
	int res = memcmp(m1, m2, size);
	if (res != 0) {
		fprintf(stderr, "%d %d:\n", i, j);
		spa_debug_mem(0, m1, size);
		spa_debug_mem(0, m2, size);
	}
//	spa_assert(res == 0);
}

static void run_test(const char *name,
		const void *in, size_t in_size, const void *out, size_t out_size, size_t n_samples,
		bool in_packed, bool out_packed, convert_func_t func)
{
	const void *ip[N_CHANNELS];
	void *tp[N_CHANNELS];
	int i, j;
	const uint8_t *in8 = in, *out8 = out;
	struct convert conv;

	conv.n_channels = N_CHANNELS;

	for (j = 0; j < N_SAMPLES; j++) {
		memcpy(&samp_in[j * in_size], &in8[(j % n_samples) * in_size], in_size);
		memcpy(&samp_out[j * out_size], &out8[(j % n_samples) * out_size], out_size);
	}

	for (j = 0; j < N_CHANNELS; j++)
		ip[j] = samp_in;

	if (in_packed) {
		tp[0] = temp_in;
		switch(in_size) {
		case 1:
			conv_interleave_8_c(&conv, tp, ip, N_SAMPLES);
			break;
		case 2:
			conv_interleave_16_c(&conv, tp, ip, N_SAMPLES);
			break;
		case 3:
			conv_interleave_24_c(&conv, tp, ip, N_SAMPLES);
			break;
		case 4:
			conv_interleave_32_c(&conv, tp, ip, N_SAMPLES);
			break;
		default:
			fprintf(stderr, "unknown size %zd\n", in_size);
			return;
		}
		ip[0] = temp_in;
	}

	spa_zero(temp_out);
	for (j = 0; j < N_CHANNELS; j++)
		tp[j] = &temp_out[j * N_SAMPLES * out_size];

	fprintf(stderr, "test %s:\n", name);
	func(&conv, tp, ip, N_SAMPLES);

	if (out_packed) {
		const uint8_t *d = tp[0], *s = samp_out;
		for (i = 0; i < N_SAMPLES; i++) {
			for (j = 0; j < N_CHANNELS; j++) {
				compare_mem(i, j, d, s, out_size);
				d += out_size;
			}
			s += out_size;
		}
	} else {
		for (j = 0; j < N_CHANNELS; j++) {
			compare_mem(0, j, tp[j], samp_out, N_SAMPLES * out_size);
		}
	}
}

static void test_f32_u8(void)
{
	const float in[] = { 0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 1.1f, -1.1f };
	uint8_t out[] = { 128, 255, 0, 191, 64, 255, 0, };

	run_test("test_f32_u8", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_f32_to_u8_c);
	run_test("test_f32d_u8", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_u8_c);
	run_test("test_f32_u8d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_f32_to_u8d_c);
	run_test("test_f32d_u8d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_f32d_to_u8d_c);
}

static void test_u8_f32(void)
{
	uint8_t in[] = { 128, 255, 0, 192, 64, };
	const float out[] = { 0.0f, 0.9921875f, -1.0f, 0.5f, -0.5f, };

	run_test("test_u8_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_u8_to_f32_c);
	run_test("test_u8d_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_u8d_to_f32_c);
	run_test("test_u8_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_u8_to_f32d_c);
	run_test("test_u8d_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_u8d_to_f32d_c);
}

static void test_f32_s16(void)
{
	const float in[] = { 0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 1.1f, -1.1f };
	const int16_t out[] = { 0, 32767, -32767, 16383, -16383, 32767, -32767 };

	run_test("test_f32_s16", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_f32_to_s16_c);
	run_test("test_f32d_s16", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_s16_c);
	run_test("test_f32_s16d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_f32_to_s16d_c);
	run_test("test_f32d_s16d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_f32d_to_s16d_c);
#if defined(HAVE_SSE2)
	if (cpu_flags & SPA_CPU_FLAG_SSE2) {
		run_test("test_f32d_s16_sse2", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_s16_sse2);
	}
#endif
}

static void test_s16_f32(void)
{
	const int16_t in[] = { 0, 32767, -32767, 16383, -16383, };
	const float out[] = { 0.0f, 1.0f, -1.0f, 0.4999847412f, -0.4999847412f };

	run_test("test_s16_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s16_to_f32d_c);
	run_test("test_s16d_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_s16d_to_f32_c);
	run_test("test_s16_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_s16_to_f32_c);
	run_test("test_s16d_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_s16d_to_f32d_c);
#if defined(HAVE_SSE2)
	if (cpu_flags & SPA_CPU_FLAG_SSE2) {
		run_test("test_s16_f32d_sse2", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s16_to_f32d_sse2);
	}
#endif
}

static void test_f32_s32(void)
{
	const float in[] = { 0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 1.1f, -1.1f };
	const int32_t out[] = { 0, 0x7fffff00, 0x80000100, 0x3fffff00, 0xc0000100,
					0x7fffff00, 0x80000100 };

	run_test("test_f32_s32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_f32_to_s32_c);
	run_test("test_f32d_s32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_s32_c);
	run_test("test_f32_s32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_f32_to_s32d_c);
	run_test("test_f32d_s32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_f32d_to_s32d_c);
#if defined(HAVE_SSE2)
	if (cpu_flags & SPA_CPU_FLAG_SSE2) {
		run_test("test_f32d_s32_sse2", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_s32_sse2);
	}
#endif
}

static void test_s32_f32(void)
{
	const int32_t in[] = { 0, 0x7fffff00, 0x80000100, 0x3fffff00, 0xc0000100 };
	const float out[] = { 0.0f, 1.0f, -1.0f, 0.4999999404f, -0.4999999404f, };

	run_test("test_s32_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s32_to_f32d_c);
	run_test("test_s32d_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_s32d_to_f32_c);
	run_test("test_s32_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_s32_to_f32_c);
	run_test("test_s32d_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_s32d_to_f32d_c);
#if defined(HAVE_SSE2)
	if (cpu_flags & SPA_CPU_FLAG_SSE2) {
		run_test("test_s32_f32d_sse2", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s32_to_f32d_sse2);
	}
#endif
}

static void test_f32_s24(void)
{
	const float in[] = { 0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 1.1f, -1.1f };
#if __BYTE_ORDER == __LITTLE_ENDIAN
	const uint8_t out[] = { 0x00, 0x00, 0x00, 0xff, 0xff, 0x7f, 0x01, 0x00, 0x80,
		0xff, 0xff, 0x3f, 0x01, 0x00, 0xc0, 0xff, 0xff, 0x7f, 0x01, 0x00, 0x80 };
#else
	const uint8_t out[] = { 0x00, 0x00, 0x00, 0x7f, 0xff, 0xff, 0x80, 0x00, 0x01,
		0x3f, 0xff, 0xff, 0xc0, 0x00, 0x01, 0x7f, 0xff, 0xff, 0x80, 0x00, 0x01 };
#endif

	run_test("test_f32_s24", in, sizeof(in[0]), out, 3, SPA_N_ELEMENTS(in),
			true, true, conv_f32_to_s24_c);
	run_test("test_f32d_s24", in, sizeof(in[0]), out, 3, SPA_N_ELEMENTS(in),
			false, true, conv_f32d_to_s24_c);
	run_test("test_f32_s24d", in, sizeof(in[0]), out, 3, SPA_N_ELEMENTS(in),
			true, false, conv_f32_to_s24d_c);
	run_test("test_f32d_s24d", in, sizeof(in[0]), out, 3, SPA_N_ELEMENTS(in),
			false, false, conv_f32d_to_s24d_c);
}

static void test_s24_f32(void)
{
#if __BYTE_ORDER == __LITTLE_ENDIAN
	const uint8_t in[] = { 0x00, 0x00, 0x00, 0xff, 0xff, 0x7f, 0x01, 0x00, 0x80,
		0xff, 0xff, 0x3f, 0x01, 0x00, 0xc0,  };
#else
	const uint8_t in[] = { 0x00, 0x00, 0x00, 0x7f, 0xff, 0xff, 0x80, 0x00, 0x01,
		0x3f, 0xff, 0xff, 0xc0, 0x00, 0x01,  };
#endif
	const float out[] = { 0.0f, 1.0f, -1.0f, 0.4999999404f, -0.4999999404f, };

	run_test("test_s24_f32d", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s24_to_f32d_c);
	run_test("test_s24d_f32", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_s24d_to_f32_c);
	run_test("test_s24_f32", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_s24_to_f32_c);
	run_test("test_s24d_f32d", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_s24d_to_f32d_c);
#if defined(HAVE_SSE2)
	if (cpu_flags & SPA_CPU_FLAG_SSE2) {
		run_test("test_s24_f32d_sse2", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s24_to_f32d_sse2);
	}
#endif
#if defined(HAVE_SSSE3)
	if (cpu_flags & SPA_CPU_FLAG_SSSE3) {
		run_test("test_s24_f32d_ssse3", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s24_to_f32d_ssse3);
	}
#endif
#if defined(HAVE_SSE41)
	if (cpu_flags & SPA_CPU_FLAG_SSE41) {
		run_test("test_s24_f32d_sse41", in, 3, out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s24_to_f32d_sse41);
	}
#endif
}

static void test_f32_s24_32(void)
{
	const float in[] = { 0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 1.1f, -1.1f };
	const int32_t out[] = { 0, 0x7fffff, 0xff800001, 0x3fffff, 0xffc00001,
					0x7fffff, 0xff800001 };

	run_test("test_f32_s24_32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_f32_to_s24_32_c);
	run_test("test_f32d_s24_32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_f32d_to_s24_32_c);
	run_test("test_f32_s24_32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_f32_to_s24_32d_c);
	run_test("test_f32d_s24_32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_f32d_to_s24_32d_c);
}

static void test_s24_32_f32(void)
{
	const int32_t in[] = { 0, 0x7fffff, 0xff800001, 0x3fffff, 0xffc00001 };
	const float out[] = { 0.0f, 1.0f, -1.0f, 0.4999999404f, -0.4999999404f, };

	run_test("test_s24_32_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, false, conv_s24_32_to_f32d_c);
	run_test("test_s24_32d_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, true, conv_s24_32d_to_f32_c);
	run_test("test_s24_32_f32", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			true, true, conv_s24_32_to_f32_c);
	run_test("test_s24_32d_f32d", in, sizeof(in[0]), out, sizeof(out[0]), SPA_N_ELEMENTS(out),
			false, false, conv_s24_32d_to_f32d_c);
}

int main(int argc, char *argv[])
{
	cpu_flags = get_cpu_flags();
	printf("got get CPU flags %d\n", cpu_flags);

	test_f32_u8();
	test_u8_f32();
	test_f32_s16();
	test_s16_f32();
	test_f32_s32();
	test_s32_f32();
	test_f32_s24();
	test_s24_f32();
	test_f32_s24_32();
	test_s24_32_f32();
	return 0;
}
