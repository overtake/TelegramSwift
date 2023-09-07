/* Spa
 *
 * Copyright © 2021 Wim Taymans
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

#include "volume-ops.h"

void
volume_f32_c(struct volume *vol, void * SPA_RESTRICT dst,
		const void * SPA_RESTRICT src, float volume, uint32_t n_samples)
{
	uint32_t n;
	float *d = (float*)dst;
	const float *s = (const float*)src;

	if (volume == VOLUME_MIN) {
		memset(d, 0, n_samples * sizeof(float));
	}
	else if (volume == VOLUME_NORM) {
		spa_memcpy(d, s, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++)
			d[n] = s[n] * volume;
	}
}
