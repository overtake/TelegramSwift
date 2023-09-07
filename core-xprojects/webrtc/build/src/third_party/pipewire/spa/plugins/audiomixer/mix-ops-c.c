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

void
mix_f32_c(struct mix_ops *ops, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_src, uint32_t n_samples)
{
	uint32_t i, n;
	float *d = dst;

	if (n_src == 0)
		memset(dst, 0, n_samples * sizeof(float));
	else if (dst != src[0])
		memcpy(dst, src[0], n_samples * sizeof(float));

	for (i = 1; i < n_src; i++) {
		const float *s = src[i];
		for (n = 0; n < n_samples; n++)
			d[n] += s[n];
	}
}

void
mix_f64_c(struct mix_ops *ops, void * SPA_RESTRICT dst, const void * SPA_RESTRICT src[],
		uint32_t n_src, uint32_t n_samples)
{
	uint32_t i, n;
	double *d = dst;

	if (n_src == 0)
		memset(dst, 0, n_samples * sizeof(double));
	else if (dst != src[0])
		memcpy(dst, src[0], n_samples * sizeof(double));

	for (i = 1; i < n_src; i++) {
		const double *s = src[i];
		for (n = 0; n < n_samples; n++)
			d[n] += s[n];
	}
}
