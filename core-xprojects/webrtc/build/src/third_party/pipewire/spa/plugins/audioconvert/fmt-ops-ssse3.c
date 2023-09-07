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

#include <tmmintrin.h>

static void
conv_s24_to_f32d_4s_ssse3(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples)
{
	const uint8_t *s = src;
	float *d0 = dst[0], *d1 = dst[1], *d2 = dst[2], *d3 = dst[3];
	uint32_t n, unrolled;
	__m128i in[4];
	__m128 out[4], factor = _mm_set1_ps(1.0f / S24_SCALE);
	const __m128i mask = _mm_setr_epi8(-1, 0, 1, 2, -1, 3, 4, 5, -1, 6, 7, 8, -1, 9, 10, 11);
	//const __m128i mask = _mm_set_epi8(15, 14, 13, -1, 12, 11, 10, -1, 9, 8, 7, -1, 6, 5, 4, -1);

	if (SPA_IS_ALIGNED(d0, 16) &&
	    SPA_IS_ALIGNED(d1, 16) &&
	    SPA_IS_ALIGNED(d2, 16) &&
	    SPA_IS_ALIGNED(d3, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	for(n = 0; n < unrolled; n += 4) {
                in[0] = _mm_loadu_si128((__m128i*)(s + 0*n_channels));
                in[1] = _mm_loadu_si128((__m128i*)(s + 3*n_channels));
                in[2] = _mm_loadu_si128((__m128i*)(s + 6*n_channels));
                in[3] = _mm_loadu_si128((__m128i*)(s + 9*n_channels));
		in[0] = _mm_shuffle_epi8(in[0], mask);
		in[1] = _mm_shuffle_epi8(in[1], mask);
		in[2] = _mm_shuffle_epi8(in[2], mask);
		in[3] = _mm_shuffle_epi8(in[3], mask);
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

		_MM_TRANSPOSE4_PS(out[0], out[1], out[2], out[3]);

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
conv_s24_to_f32d_1s_sse2(void *data, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src,
		uint32_t n_channels, uint32_t n_samples);

void
conv_s24_to_f32d_ssse3(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t *s = src[0];
	uint32_t i = 0, n_channels = conv->n_channels;

	for(; i + 3 < n_channels; i += 4)
		conv_s24_to_f32d_4s_ssse3(conv, &dst[i], &s[3*i], n_channels, n_samples);
	for(; i < n_channels; i++)
		conv_s24_to_f32d_1s_sse2(conv, &dst[i], &s[3*i], n_channels, n_samples);
}
