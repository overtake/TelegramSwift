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

#include <math.h>

#include <xmmintrin.h>

#include "resample-peaks-impl.h"

static inline float hmax_ps(__m128 val)
{
	__m128 t = _mm_movehl_ps(val, val);
	t = _mm_max_ps(t, val);
	val = _mm_shuffle_ps(val, t, 0x55);
	val = _mm_max_ss(t, val);
	return _mm_cvtss_f32(val);
}

void resample_peaks_process_sse(struct resample *r,
			const void * SPA_RESTRICT src[], uint32_t *in_len,
			void * SPA_RESTRICT dst[], uint32_t *out_len)
{
	struct peaks_data *pd = r->data;
	uint32_t c, i, o, end, chunk, unrolled, i_count, o_count;
	__m128 in, max, mask = _mm_andnot_ps(_mm_set_ps1(-0.0f),
			_mm_cmpeq_ps(_mm_setzero_ps(), _mm_setzero_ps()));

	if (r->channels == 0)
		return;

	for (c = 0; c < r->channels; c++) {
		const float *s = src[c];
		float *d = dst[c], m = pd->max_f[c];

		o_count = pd->o_count;
		i_count = pd->i_count;
		o = i = 0;

		max = _mm_set1_ps(m);

		while (i < *in_len && o < *out_len) {
			end = ((uint64_t) (o_count + 1) * r->i_rate) / r->o_rate;
			end = end > i_count ? end - i_count : 0;
			chunk = SPA_MIN(end, *in_len);

			unrolled = chunk - ((chunk - i) & 3);

			for (; i < unrolled; i+=4) {
				in = _mm_loadu_ps(&s[i]);
				in = _mm_and_ps(mask, in);
				max = _mm_max_ps(in, max);
			}
			for (; i < chunk; i++)
				m = SPA_MAX(fabsf(s[i]), m);

			if (i == end) {
				d[o++] = SPA_MAX(hmax_ps(max), m);
				m = 0.0f;
				max = _mm_set1_ps(m);
				o_count++;
			}
		}
		pd->max_f[c] = SPA_MAX(hmax_ps(max), m);
	}

	*out_len = o;
	*in_len = i;
	pd->o_count = o_count;
	pd->i_count = i_count + i;

	while (pd->i_count >= r->i_rate) {
		pd->i_count -= r->i_rate;
		pd->o_count -= r->o_rate;
	}
}
