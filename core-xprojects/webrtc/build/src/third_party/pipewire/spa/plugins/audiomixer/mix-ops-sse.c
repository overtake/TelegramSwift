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
#include <math.h>

#include <spa/utils/defs.h>

#include "mix-ops.h"

#include <xmmintrin.h>

static inline void mix_2(float * dst, const float * SPA_RESTRICT src, uint32_t n_samples)
{
	uint32_t n, unrolled;
	__m128 in1[4], in2[4];

	if (SPA_LIKELY(SPA_IS_ALIGNED(src, 16) &&
	    SPA_IS_ALIGNED(dst, 16)))
		unrolled = n_samples & ~15;
	else
		unrolled = 0;

	for (n = 0; n < unrolled; n += 16) {
		in1[0] = _mm_load_ps(&dst[n+ 0]);
		in1[1] = _mm_load_ps(&dst[n+ 4]);
		in1[2] = _mm_load_ps(&dst[n+ 8]);
		in1[3] = _mm_load_ps(&dst[n+12]);

		in2[0] = _mm_load_ps(&src[n+ 0]);
		in2[1] = _mm_load_ps(&src[n+ 4]);
		in2[2] = _mm_load_ps(&src[n+ 8]);
		in2[3] = _mm_load_ps(&src[n+12]);

		in1[0] = _mm_add_ps(in1[0], in2[0]);
		in1[1] = _mm_add_ps(in1[1], in2[1]);
		in1[2] = _mm_add_ps(in1[2], in2[2]);
		in1[3] = _mm_add_ps(in1[3], in2[3]);

		_mm_store_ps(&dst[n+ 0], in1[0]);
		_mm_store_ps(&dst[n+ 4], in1[1]);
		_mm_store_ps(&dst[n+ 8], in1[2]);
		_mm_store_ps(&dst[n+12], in1[3]);
	}
	for (; n < n_samples; n++) {
		in1[0] = _mm_load_ss(&dst[n]),
		in2[0] = _mm_load_ss(&src[n]),
		in1[0] = _mm_add_ss(in1[0], in2[0]);
		_mm_store_ss(&dst[n], in1[0]);
	}
}

void
mix_f32_sse(struct mix_ops *ops, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_src, uint32_t n_samples)
{
	uint32_t i;

	if (n_src == 0)
		memset(dst, 0, n_samples * sizeof(float));
	else if (dst != src[0])
		memcpy(dst, src[0], n_samples * sizeof(float));

	for (i = 1; i < n_src; i++) {
		mix_2(dst, src[i], n_samples);
	}
}
