/* Spa
 *
 * Copyright © 2018 Wim Taymans
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

#include "fmt-ops.h"

#include <emmintrin.h>

static void
conv_s16_to_f32d_1s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const int16_t *s = src;
	float *d0 = dst[0];
	uint32_t n, unrolled;
	__m128i in;
	__m128 out, factor = _mm_set1_ps(1.0f / S16_SCALE);

	if (SPA_LIKELY(SPA_IS_ALIGNED(d0, 16)))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in = _mm_insert_epi16(in, s[0*n_channels], 1);
		in = _mm_insert_epi16(in, s[1*n_channels], 3);
		in = _mm_insert_epi16(in, s[2*n_channels], 5);
		in = _mm_insert_epi16(in, s[3*n_channels], 7);
		in = _mm_srai_epi32(in, 16);
		out = _mm_cvtepi32_ps(in);
		out = _mm_mul_ps(out, factor);
		_mm_store_ps(&d0[n], out);
		s += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		out = _mm_cvtsi32_ss(out, s[0]);
		out = _mm_mul_ss(out, factor);
		_mm_store_ss(&d0[n], out);
		s += n_channels;
	}
}

void
conv_s16_to_f32d_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int16_t *s = src[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i < n_channels; i++)
		conv_s16_to_f32d_1s_sse2(conv, &dst[i], &s[i], n_channels, n_samples);
}

void
conv_s16_to_f32d_2_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int16_t *s = src[0];
	float *d0 = dst[0], *d1 = dst[1];
	uint32_t n, unrolled;
	__m128i in[2], t[4];
	__m128 out[4], factor = _mm_set1_ps(1.0f / S16_SCALE);

	if (SPA_IS_ALIGNED(s, 16) &&
	    SPA_IS_ALIGNED(d0, 16) &&
	    SPA_IS_ALIGNED(d1, 16))
		unrolled = n_samples & ~7;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 8) {
		in[0] = _mm_load_si128((__m128i*)(s + 0));
		in[1] = _mm_load_si128((__m128i*)(s + 8));

		t[0] = _mm_slli_epi32(in[0], 16);
		t[0] = _mm_srai_epi32(t[0], 16);
		out[0] = _mm_cvtepi32_ps(t[0]);
		out[0] = _mm_mul_ps(out[0], factor);

		t[1] = _mm_srai_epi32(in[0], 16);
		out[1] = _mm_cvtepi32_ps(t[1]);
		out[1] = _mm_mul_ps(out[1], factor);

		t[2] = _mm_slli_epi32(in[1], 16);
		t[2] = _mm_srai_epi32(t[2], 16);
		out[2] = _mm_cvtepi32_ps(t[2]);
		out[2] = _mm_mul_ps(out[2], factor);

		t[3] = _mm_srai_epi32(in[1], 16);
		out[3] = _mm_cvtepi32_ps(t[3]);
		out[3] = _mm_mul_ps(out[3], factor);

		_mm_store_ps(&d0[n + 0], out[0]);
		_mm_store_ps(&d1[n + 0], out[1]);
		_mm_store_ps(&d0[n + 4], out[2]);
		_mm_store_ps(&d1[n + 4], out[3]);

		s += 16;
	}
	for(; n < n_samples; n++) {
		out[0] = _mm_cvtsi32_ss(out[0], s[0]);
		out[0] = _mm_mul_ss(out[0], factor);
		out[1] = _mm_cvtsi32_ss(out[1], s[1]);
		out[1] = _mm_mul_ss(out[1], factor);
		_mm_store_ss(&d0[n], out[0]);
		_mm_store_ss(&d1[n], out[1]);
		s += 2;
	}
}

void
conv_s24_to_f32d_1s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const uint8_t *s = src;
	float *d0 = dst[0];
	uint32_t n, unrolled;
	__m128i in;
	__m128 out, factor = _mm_set1_ps(1.0f / S24_SCALE);

	if (SPA_IS_ALIGNED(d0, 16) && n_samples > 0) {
		unrolled = n_samples & ~3;
		if ((n_samples & 3) == 0)
			unrolled -= 4;
	}
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in = _mm_setr_epi32(
			*((uint32_t*)&s[0 * n_channels]),
			*((uint32_t*)&s[3 * n_channels]),
			*((uint32_t*)&s[6 * n_channels]),
			*((uint32_t*)&s[9 * n_channels]));
		in = _mm_slli_epi32(in, 8);
		in = _mm_srai_epi32(in, 8);
		out = _mm_cvtepi32_ps(in);
		out = _mm_mul_ps(out, factor);
		_mm_store_ps(&d0[n], out);
		s += 12 * n_channels;
	}
	for(; n < n_samples; n++) {
		out = _mm_cvtsi32_ss(out, read_s24(s));
		out = _mm_mul_ss(out, factor);
		_mm_store_ss(&d0[n], out);
		s += 3 * n_channels;
	}
}

static void
conv_s24_to_f32d_2s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const uint8_t *s = src;
	float *d0 = dst[0], *d1 = dst[1];
	uint32_t n, unrolled;
	__m128i in[2];
	__m128 out[2], factor = _mm_set1_ps(1.0f / S24_SCALE);

	if (SPA_IS_ALIGNED(d0, 16) &&
	    SPA_IS_ALIGNED(d1, 16) &&
	    n_samples > 0) {
		unrolled = n_samples & ~3;
		if ((n_samples & 3) == 0)
			unrolled -= 4;
	}
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_setr_epi32(
			*((uint32_t*)&s[0 + 0*n_channels]),
			*((uint32_t*)&s[0 + 3*n_channels]),
			*((uint32_t*)&s[0 + 6*n_channels]),
			*((uint32_t*)&s[0 + 9*n_channels]));
		in[1] = _mm_setr_epi32(
			*((uint32_t*)&s[3 + 0*n_channels]),
			*((uint32_t*)&s[3 + 3*n_channels]),
			*((uint32_t*)&s[3 + 6*n_channels]),
			*((uint32_t*)&s[3 + 9*n_channels]));

		in[0] = _mm_slli_epi32(in[0], 8);
		in[1] = _mm_slli_epi32(in[1], 8);

		in[0] = _mm_srai_epi32(in[0], 8);
		in[1] = _mm_srai_epi32(in[1], 8);

		out[0] = _mm_cvtepi32_ps(in[0]);
		out[1] = _mm_cvtepi32_ps(in[1]);

		out[0] = _mm_mul_ps(out[0], factor);
		out[1] = _mm_mul_ps(out[1], factor);

		_mm_store_ps(&d0[n], out[0]);
		_mm_store_ps(&d1[n], out[1]);

		s += 12 * n_channels;
	}
	for(; n < n_samples; n++) {
		out[0] = _mm_cvtsi32_ss(out[0], read_s24(s));
		out[1] = _mm_cvtsi32_ss(out[1], read_s24(s+3));
		out[0] = _mm_mul_ss(out[0], factor);
		out[1] = _mm_mul_ss(out[1], factor);
		_mm_store_ss(&d0[n], out[0]);
		_mm_store_ss(&d1[n], out[1]);
		s += 3 * n_channels;
	}
}
static void
conv_s24_to_f32d_4s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const uint8_t *s = src;
	float *d0 = dst[0], *d1 = dst[1], *d2 = dst[2], *d3 = dst[3];
	uint32_t n, unrolled;
	__m128i in[4];
	__m128 out[4], factor = _mm_set1_ps(1.0f / S24_SCALE);

	if (SPA_IS_ALIGNED(d0, 16) &&
	    SPA_IS_ALIGNED(d1, 16) &&
	    SPA_IS_ALIGNED(d2, 16) &&
	    SPA_IS_ALIGNED(d3, 16) &&
	    n_samples > 0) {
		unrolled = n_samples & ~3;
		if ((n_samples & 3) == 0)
			unrolled -= 4;
	}
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_setr_epi32(
			*((uint32_t*)&s[0 + 0*n_channels]),
			*((uint32_t*)&s[0 + 3*n_channels]),
			*((uint32_t*)&s[0 + 6*n_channels]),
			*((uint32_t*)&s[0 + 9*n_channels]));
		in[1] = _mm_setr_epi32(
			*((uint32_t*)&s[3 + 0*n_channels]),
			*((uint32_t*)&s[3 + 3*n_channels]),
			*((uint32_t*)&s[3 + 6*n_channels]),
			*((uint32_t*)&s[3 + 9*n_channels]));
		in[2] = _mm_setr_epi32(
			*((uint32_t*)&s[6 + 0*n_channels]),
			*((uint32_t*)&s[6 + 3*n_channels]),
			*((uint32_t*)&s[6 + 6*n_channels]),
			*((uint32_t*)&s[6 + 9*n_channels]));
		in[3] = _mm_setr_epi32(
			*((uint32_t*)&s[9 + 0*n_channels]),
			*((uint32_t*)&s[9 + 3*n_channels]),
			*((uint32_t*)&s[9 + 6*n_channels]),
			*((uint32_t*)&s[9 + 9*n_channels]));

		in[0] = _mm_slli_epi32(in[0], 8);
		in[1] = _mm_slli_epi32(in[1], 8);
		in[2] = _mm_slli_epi32(in[2], 8);
		in[3] = _mm_slli_epi32(in[3], 8);

		in[0] = _mm_srai_epi32(in[0], 8);
		in[1] = _mm_srai_epi32(in[1], 8);
		in[2] = _mm_srai_epi32(in[2], 8);
		in[3] = _mm_srai_epi32(in[3], 8);

		out[0] = _mm_cvtepi32_ps(in[0]);
		out[1] = _mm_cvtepi32_ps(in[1]);
		out[2] = _mm_cvtepi32_ps(in[2]);
		out[3] = _mm_cvtepi32_ps(in[3]);

		out[0] = _mm_mul_ps(out[0], factor);
		out[1] = _mm_mul_ps(out[1], factor);
		out[2] = _mm_mul_ps(out[2], factor);
		out[3] = _mm_mul_ps(out[3], factor);

		_mm_store_ps(&d0[n], out[0]);
		_mm_store_ps(&d1[n], out[1]);
		_mm_store_ps(&d2[n], out[2]);
		_mm_store_ps(&d3[n], out[3]);

		s += 12 * n_channels;
	}
	for(; n < n_samples; n++) {
		out[0] = _mm_cvtsi32_ss(out[0], read_s24(s));
		out[1] = _mm_cvtsi32_ss(out[1], read_s24(s+3));
		out[2] = _mm_cvtsi32_ss(out[2], read_s24(s+6));
		out[3] = _mm_cvtsi32_ss(out[3], read_s24(s+9));
		out[0] = _mm_mul_ss(out[0], factor);
		out[1] = _mm_mul_ss(out[1], factor);
		out[2] = _mm_mul_ss(out[2], factor);
		out[3] = _mm_mul_ss(out[3], factor);
		_mm_store_ss(&d0[n], out[0]);
		_mm_store_ss(&d1[n], out[1]);
		_mm_store_ss(&d2[n], out[2]);
		_mm_store_ss(&d3[n], out[3]);
		s += 3 * n_channels;
	}
}

void
conv_s24_to_f32d_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t *s = src[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i + 3 < n_channels; i += 4)
		conv_s24_to_f32d_4s_sse2(conv, &dst[i], &s[3*i], n_channels, n_samples);
	for(; i + 1 < n_channels; i += 2)
		conv_s24_to_f32d_2s_sse2(conv, &dst[i], &s[3*i], n_channels, n_samples);
	for(; i < n_channels; i++)
		conv_s24_to_f32d_1s_sse2(conv, &dst[i], &s[3*i], n_channels, n_samples);
}


void
conv_s32_to_f32d_1s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const int32_t *s = src;
	float *d0 = dst[0];
	uint32_t n, unrolled;
	__m128i in;
	__m128 out, factor = _mm_set1_ps(1.0f / S24_SCALE);

	if (SPA_IS_ALIGNED(d0, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in = _mm_setr_epi32(s[0*n_channels],
				    s[1*n_channels],
				    s[2*n_channels],
				    s[3*n_channels]);
		in = _mm_srai_epi32(in, 8);
		out = _mm_cvtepi32_ps(in);
		out = _mm_mul_ps(out, factor);
		_mm_store_ps(&d0[n], out);
		s += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		out = _mm_cvtsi32_ss(out, s[0]>>8);
		out = _mm_mul_ss(out, factor);
		_mm_store_ss(&d0[n], out);
		s += n_channels;
	}
}

void
conv_s32_to_f32d_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t *s = src[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i < n_channels; i++)
		conv_s32_to_f32d_1s_sse2(conv, &dst[i], &s[i], n_channels, n_samples);
}

static void
conv_f32d_to_s32_1s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0];
	int32_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[1];
	__m128i out[4];
	__m128 scale = _mm_set1_ps(S32_SCALE);
	__m128 int_min = _mm_set1_ps(S32_MIN);

	if (SPA_IS_ALIGNED(s0, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), scale);
		in[0] = _mm_min_ps(in[0], int_min);
		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(0, 3, 2, 1));
		out[2] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(1, 0, 3, 2));
		out[3] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(2, 1, 0, 3));

		d[0*n_channels] = _mm_cvtsi128_si32(out[0]);
		d[1*n_channels] = _mm_cvtsi128_si32(out[1]);
		d[2*n_channels] = _mm_cvtsi128_si32(out[2]);
		d[3*n_channels] = _mm_cvtsi128_si32(out[3]);
		d += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_load_ss(&s0[n]);
		in[0] = _mm_mul_ss(in[0], scale);
		in[0] = _mm_min_ss(in[0], int_min);
		*d = _mm_cvtss_si32(in[0]);
		d += n_channels;
	}
}

static void
conv_f32d_to_s32_2s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0], *s1 = src[1];
	int32_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[2];
	__m128i out[2], t[2];
	__m128 scale = _mm_set1_ps(S32_SCALE);
	__m128 int_min = _mm_set1_ps(S32_MIN);

	if (SPA_IS_ALIGNED(s0, 16) &&
	    SPA_IS_ALIGNED(s1, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), scale);
		in[1] = _mm_mul_ps(_mm_load_ps(&s1[n]), scale);

		in[0] = _mm_min_ps(in[0], int_min);
		in[1] = _mm_min_ps(in[1], int_min);

		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_cvtps_epi32(in[1]);

		t[0] = _mm_unpacklo_epi32(out[0], out[1]);
		t[1] = _mm_unpackhi_epi32(out[0], out[1]);

		_mm_storel_pd((double*)(d + 0*n_channels), (__m128d)t[0]);
		_mm_storeh_pd((double*)(d + 1*n_channels), (__m128d)t[0]);
		_mm_storel_pd((double*)(d + 2*n_channels), (__m128d)t[1]);
		_mm_storeh_pd((double*)(d + 3*n_channels), (__m128d)t[1]);
		d += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_load_ss(&s0[n]);
		in[1] = _mm_load_ss(&s1[n]);

		in[0] = _mm_unpacklo_ps(in[0], in[1]);

		in[0] = _mm_mul_ps(in[0], scale);
		in[0] = _mm_min_ps(in[0], int_min);
		out[0] = _mm_cvtps_epi32(in[0]);
		_mm_storel_epi64((__m128i*)d, out[0]);
		d += n_channels;
	}
}

static void
conv_f32d_to_s32_4s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0], *s1 = src[1], *s2 = src[2], *s3 = src[3];
	int32_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[4];
	__m128i out[4];
	__m128 scale = _mm_set1_ps(S32_SCALE);
	__m128 int_min = _mm_set1_ps(S32_MIN);

	if (SPA_IS_ALIGNED(s0, 16) &&
	    SPA_IS_ALIGNED(s1, 16) &&
	    SPA_IS_ALIGNED(s2, 16) &&
	    SPA_IS_ALIGNED(s3, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), scale);
		in[1] = _mm_mul_ps(_mm_load_ps(&s1[n]), scale);
		in[2] = _mm_mul_ps(_mm_load_ps(&s2[n]), scale);
		in[3] = _mm_mul_ps(_mm_load_ps(&s3[n]), scale);

		in[0] = _mm_min_ps(in[0], int_min);
		in[1] = _mm_min_ps(in[1], int_min);
		in[2] = _mm_min_ps(in[2], int_min);
		in[3] = _mm_min_ps(in[3], int_min);

		_MM_TRANSPOSE4_PS(in[0], in[1], in[2], in[3]);

		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_cvtps_epi32(in[1]);
		out[2] = _mm_cvtps_epi32(in[2]);
		out[3] = _mm_cvtps_epi32(in[3]);

		_mm_storeu_si128((__m128i*)(d + 0*n_channels), out[0]);
		_mm_storeu_si128((__m128i*)(d + 1*n_channels), out[1]);
		_mm_storeu_si128((__m128i*)(d + 2*n_channels), out[2]);
		_mm_storeu_si128((__m128i*)(d + 3*n_channels), out[3]);
		d += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_load_ss(&s0[n]);
		in[1] = _mm_load_ss(&s1[n]);
		in[2] = _mm_load_ss(&s2[n]);
		in[3] = _mm_load_ss(&s3[n]);

		in[0] = _mm_unpacklo_ps(in[0], in[2]);
		in[1] = _mm_unpacklo_ps(in[1], in[3]);
		in[0] = _mm_unpacklo_ps(in[0], in[1]);

		in[0] = _mm_mul_ps(in[0], scale);
		in[0] = _mm_min_ps(in[0], int_min);
		out[0] = _mm_cvtps_epi32(in[0]);
		_mm_storeu_si128((__m128i*)d, out[0]);
		d += n_channels;
	}
}

void
conv_f32d_to_s32_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	int32_t *d = dst[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i + 3 < n_channels; i += 4)
		conv_f32d_to_s32_4s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
	for(; i + 1 < n_channels; i += 2)
		conv_f32d_to_s32_2s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
	for(; i < n_channels; i++)
		conv_f32d_to_s32_1s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
}

static void
conv_f32_to_s16_1_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src,
		uint32_t n_samples)
{
	const float *s = src;
	int16_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[2];
	__m128i out[2];
	__m128 int_max = _mm_set1_ps(S16_MAX_F);
        __m128 int_min = _mm_sub_ps(_mm_setzero_ps(), int_max);

	if (SPA_IS_ALIGNED(s, 16))
		unrolled = n_samples & ~7;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 8) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s[n]), int_max);
		in[1] = _mm_mul_ps(_mm_load_ps(&s[n+4]), int_max);
		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_cvtps_epi32(in[1]);
		out[0] = _mm_packs_epi32(out[0], out[1]);
		_mm_storeu_si128((__m128i*)(d+0), out[0]);
		d += 8;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_mul_ss(_mm_load_ss(&s[n]), int_max);
		in[0] = _mm_min_ss(int_max, _mm_max_ss(in[0], int_min));
		*d++ = _mm_cvtss_si32(in[0]);
	}
}

void
conv_f32d_to_s16d_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	for(i = 0; i < n_channels; i++)
		conv_f32_to_s16_1_sse2(conv, dst[i], src[i], n_samples);
}

void
conv_f32_to_s16_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	conv_f32_to_s16_1_sse2(conv, dst[0], src[0], n_samples * conv->n_channels);
}

static void
conv_f32d_to_s16_1s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0];
	int16_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[2];
	__m128i out[2];
	__m128 int_max = _mm_set1_ps(S16_MAX_F);
        __m128 int_min = _mm_sub_ps(_mm_setzero_ps(), int_max);

	if (SPA_IS_ALIGNED(s0, 16))
		unrolled = n_samples & ~7;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 8) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), int_max);
		in[1] = _mm_mul_ps(_mm_load_ps(&s0[n+4]), int_max);
		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_cvtps_epi32(in[1]);
		out[0] = _mm_packs_epi32(out[0], out[1]);

		d[0*n_channels] = _mm_extract_epi16(out[0], 0);
		d[1*n_channels] = _mm_extract_epi16(out[0], 1);
		d[2*n_channels] = _mm_extract_epi16(out[0], 2);
		d[3*n_channels] = _mm_extract_epi16(out[0], 3);
		d[4*n_channels] = _mm_extract_epi16(out[0], 4);
		d[5*n_channels] = _mm_extract_epi16(out[0], 5);
		d[6*n_channels] = _mm_extract_epi16(out[0], 6);
		d[7*n_channels] = _mm_extract_epi16(out[0], 7);
		d += 8*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_mul_ss(_mm_load_ss(&s0[n]), int_max);
		in[0] = _mm_min_ss(int_max, _mm_max_ss(in[0], int_min));
		*d = _mm_cvtss_si32(in[0]);
		d += n_channels;
	}
}

static void
conv_f32d_to_s16_2s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0], *s1 = src[1];
	int16_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[2];
	__m128i out[4], t[2];
	__m128 int_max = _mm_set1_ps(S16_MAX_F);
        __m128 int_min = _mm_sub_ps(_mm_setzero_ps(), int_max);

	if (SPA_IS_ALIGNED(s0, 16) &&
	    SPA_IS_ALIGNED(s1, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), int_max);
		in[1] = _mm_mul_ps(_mm_load_ps(&s1[n]), int_max);

		t[0] = _mm_cvtps_epi32(in[0]);
		t[1] = _mm_cvtps_epi32(in[1]);

		t[0] = _mm_packs_epi32(t[0], t[0]);
		t[1] = _mm_packs_epi32(t[1], t[1]);

		out[0] = _mm_unpacklo_epi16(t[0], t[1]);
		out[1] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(0, 3, 2, 1));
		out[2] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(1, 0, 3, 2));
		out[3] = _mm_shuffle_epi32(out[0], _MM_SHUFFLE(2, 1, 0, 3));

		*((int32_t*)(d + 0*n_channels)) = _mm_cvtsi128_si32(out[0]);
		*((int32_t*)(d + 1*n_channels)) = _mm_cvtsi128_si32(out[1]);
		*((int32_t*)(d + 2*n_channels)) = _mm_cvtsi128_si32(out[2]);
		*((int32_t*)(d + 3*n_channels)) = _mm_cvtsi128_si32(out[3]);
		d += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_mul_ss(_mm_load_ss(&s0[n]), int_max);
		in[1] = _mm_mul_ss(_mm_load_ss(&s1[n]), int_max);
		in[0] = _mm_min_ss(int_max, _mm_max_ss(in[0], int_min));
		in[1] = _mm_min_ss(int_max, _mm_max_ss(in[1], int_min));
		d[0] = _mm_cvtss_si32(in[0]);
		d[1] = _mm_cvtss_si32(in[1]);
		d += n_channels;
	}
}

static void
conv_f32d_to_s16_4s_sse2(void *data, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_channels, uint32_t n_samples)
{
	const float *s0 = src[0], *s1 = src[1], *s2 = src[2], *s3 = src[3];
	int16_t *d = dst;
	uint32_t n, unrolled;
	__m128 in[4];
	__m128i out[4], t[4];
	__m128 int_max = _mm_set1_ps(S16_MAX_F);
        __m128 int_min = _mm_sub_ps(_mm_setzero_ps(), int_max);

	if (SPA_IS_ALIGNED(s0, 16) &&
	    SPA_IS_ALIGNED(s1, 16) &&
	    SPA_IS_ALIGNED(s2, 16) &&
	    SPA_IS_ALIGNED(s3, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n]), int_max);
		in[1] = _mm_mul_ps(_mm_load_ps(&s1[n]), int_max);
		in[2] = _mm_mul_ps(_mm_load_ps(&s2[n]), int_max);
		in[3] = _mm_mul_ps(_mm_load_ps(&s3[n]), int_max);

		t[0] = _mm_cvtps_epi32(in[0]);
		t[1] = _mm_cvtps_epi32(in[1]);
		t[2] = _mm_cvtps_epi32(in[2]);
		t[3] = _mm_cvtps_epi32(in[3]);

		t[0] = _mm_packs_epi32(t[0], t[2]);
		t[1] = _mm_packs_epi32(t[1], t[3]);

		out[0] = _mm_unpacklo_epi16(t[0], t[1]);
		out[1] = _mm_unpackhi_epi16(t[0], t[1]);
		out[2] = _mm_unpacklo_epi32(out[0], out[1]);
		out[3] = _mm_unpackhi_epi32(out[0], out[1]);

		_mm_storel_pi((__m64*)(d + 0*n_channels), (__m128)out[2]);
		_mm_storeh_pi((__m64*)(d + 1*n_channels), (__m128)out[2]);
		_mm_storel_pi((__m64*)(d + 2*n_channels), (__m128)out[3]);
		_mm_storeh_pi((__m64*)(d + 3*n_channels), (__m128)out[3]);

		d += 4*n_channels;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_mul_ss(_mm_load_ss(&s0[n]), int_max);
		in[1] = _mm_mul_ss(_mm_load_ss(&s1[n]), int_max);
		in[2] = _mm_mul_ss(_mm_load_ss(&s2[n]), int_max);
		in[3] = _mm_mul_ss(_mm_load_ss(&s3[n]), int_max);
		in[0] = _mm_min_ss(int_max, _mm_max_ss(in[0], int_min));
		in[1] = _mm_min_ss(int_max, _mm_max_ss(in[1], int_min));
		in[2] = _mm_min_ss(int_max, _mm_max_ss(in[2], int_min));
		in[3] = _mm_min_ss(int_max, _mm_max_ss(in[3], int_min));
		d[0] = _mm_cvtss_si32(in[0]);
		d[1] = _mm_cvtss_si32(in[1]);
		d[2] = _mm_cvtss_si32(in[2]);
		d[3] = _mm_cvtss_si32(in[3]);
		d += n_channels;
	}
}

void
conv_f32d_to_s16_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	int16_t *d = dst[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i + 3 < n_channels; i += 4)
		conv_f32d_to_s16_4s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
	for(; i + 1 < n_channels; i += 2)
		conv_f32d_to_s16_2s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
	for(; i < n_channels; i++)
		conv_f32d_to_s16_1s_sse2(conv, &d[i], &src[i], n_channels, n_samples);
}

void
conv_f32d_to_s16_2_sse2(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s0 = src[0], *s1 = src[1];
	int16_t *d = dst[0];
	uint32_t n, unrolled;
	__m128 in[4];
	__m128i out[4];
	__m128 int_max = _mm_set1_ps(S16_MAX_F);
        __m128 int_min = _mm_sub_ps(_mm_setzero_ps(), int_max);

	if (SPA_IS_ALIGNED(s0, 16) &&
	    SPA_IS_ALIGNED(s1, 16))
		unrolled = n_samples & ~7;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 8) {
		in[0] = _mm_mul_ps(_mm_load_ps(&s0[n+0]), int_max);
		in[1] = _mm_mul_ps(_mm_load_ps(&s1[n+0]), int_max);
		in[2] = _mm_mul_ps(_mm_load_ps(&s0[n+4]), int_max);
		in[3] = _mm_mul_ps(_mm_load_ps(&s1[n+4]), int_max);

		out[0] = _mm_cvtps_epi32(in[0]);
		out[1] = _mm_cvtps_epi32(in[1]);
		out[2] = _mm_cvtps_epi32(in[2]);
		out[3] = _mm_cvtps_epi32(in[3]);

		out[0] = _mm_packs_epi32(out[0], out[2]);
		out[1] = _mm_packs_epi32(out[1], out[3]);

		out[2] = _mm_unpacklo_epi16(out[0], out[1]);
		out[3] = _mm_unpackhi_epi16(out[0], out[1]);

		_mm_storeu_si128((__m128i*)(d+0), out[2]);
		_mm_storeu_si128((__m128i*)(d+8), out[3]);

		d += 16;
	}
	for(; n < n_samples; n++) {
		in[0] = _mm_mul_ss(_mm_load_ss(&s0[n]), int_max);
		in[1] = _mm_mul_ss(_mm_load_ss(&s1[n]), int_max);
		in[0] = _mm_min_ss(int_max, _mm_max_ss(in[0], int_min));
		in[1] = _mm_min_ss(int_max, _mm_max_ss(in[1], int_min));
		d[0] = _mm_cvtss_si32(in[0]);
		d[1] = _mm_cvtss_si32(in[1]);
		d += 2;
	}
}
