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

#include <smmintrin.h>

static void
conv_s24_to_f32d_1s_sse41(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const uint8_t *s = src;
	float *d0 = dst[0];
	uint32_t n, unrolled;
	__m128i in;
	__m128 out, factor = _mm_set1_ps(1.0f / S24_SCALE);

	if (SPA_IS_ALIGNED(d0, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
		in = _mm_insert_epi32(in, *((uint32_t*)&s[0 * n_channels]), 0);
		in = _mm_insert_epi32(in, *((uint32_t*)&s[3 * n_channels]), 1);
		in = _mm_insert_epi32(in, *((uint32_t*)&s[6 * n_channels]), 2);
		in = _mm_insert_epi32(in, *((uint32_t*)&s[9 * n_channels]), 3);
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

extern void conv_s24_to_f32d_2s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples);
extern void conv_s24_to_f32d_4s_ssse3(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples);

void
conv_s24_to_f32d_sse41(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t *s = src[0];
	uint32_t i = 0, n_channels = conv->n_channels;

#if defined (HAVE_SSSE3)
	for(; i + 3 < n_channels; i += 4)
		conv_s24_to_f32d_4s_ssse3(conv, &dst[i], &s[3*i], n_channels, n_samples);
#endif
#if defined (HAVE_SSE2)
	for(; i + 1 < n_channels; i += 2)
		conv_s24_to_f32d_2s_sse2(conv, &dst[i], &s[3*i], n_channels, n_samples);
#endif
	for(; i < n_channels; i++)
		conv_s24_to_f32d_1s_sse41(conv, &dst[i], &s[3*i], n_channels, n_samples);
}
