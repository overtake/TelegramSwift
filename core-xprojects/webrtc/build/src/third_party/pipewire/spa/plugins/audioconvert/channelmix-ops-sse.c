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

#include "channelmix-ops.h"

#include <xmmintrin.h>

void channelmix_copy_sse(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n, unrolled;
	float **d = (float **)dst;
	const float **s = (const float **)src;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_IDENTITY)) {
		for (i = 0; i < n_dst; i++)
			spa_memcpy(d[i], s[i], n_samples * sizeof(float));
	}
	else {
		for (i = 0; i < n_dst; i++) {
			float *di = d[i];
			const float *si = s[i];
			__m128 t[4];
			const __m128 vol = _mm_set1_ps(mix->matrix[i][i]);

			if (SPA_IS_ALIGNED(di, 16) &&
			    SPA_IS_ALIGNED(si, 16))
				unrolled = n_samples & ~15;
			else
				unrolled = 0;

			for(n = 0; n < unrolled; n += 16) {
				t[0] = _mm_load_ps(&si[n]);
				t[1] = _mm_load_ps(&si[n+4]);
				t[2] = _mm_load_ps(&si[n+8]);
				t[3] = _mm_load_ps(&si[n+12]);
				_mm_store_ps(&di[n], _mm_mul_ps(t[0], vol));
				_mm_store_ps(&di[n+4], _mm_mul_ps(t[1], vol));
				_mm_store_ps(&di[n+8], _mm_mul_ps(t[2], vol));
				_mm_store_ps(&di[n+12], _mm_mul_ps(t[3], vol));
			}
			for(; n < n_samples; n++)
				_mm_store_ss(&di[n], _mm_mul_ss(_mm_load_ss(&si[n]), vol));
		}
	}
}

void
channelmix_f32_2_4_sse(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n, unrolled;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float m00 = mix->matrix[0][0];
	const float m11 = mix->matrix[1][1];
	__m128 in;
	const float *sFL = s[0], *sFR = s[1];
	float *dFL = d[0], *dFR = d[1], *dRL = d[2], *dRR = d[3];

	if (SPA_IS_ALIGNED(sFL, 16) &&
	    SPA_IS_ALIGNED(sFR, 16) &&
	    SPA_IS_ALIGNED(dFL, 16) &&
	    SPA_IS_ALIGNED(dFR, 16) &&
	    SPA_IS_ALIGNED(dRL, 16) &&
	    SPA_IS_ALIGNED(dRR, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (m00 == 1.0f && m11 == 1.0f) {
		for(n = 0; n < unrolled; n += 4) {
			in = _mm_load_ps(&sFL[n]);
			_mm_store_ps(&dFL[n], in);
			_mm_store_ps(&dRL[n], in);
			in = _mm_load_ps(&sFR[n]);
			_mm_store_ps(&dFR[n], in);
			_mm_store_ps(&dRR[n], in);
		}
		for(; n < n_samples; n++) {
			in = _mm_load_ss(&sFL[n]);
			_mm_store_ss(&dFL[n], in);
			_mm_store_ss(&dRL[n], in);
			in = _mm_load_ss(&sFR[n]);
			_mm_store_ss(&dFR[n], in);
			_mm_store_ss(&dRR[n], in);
		}
	}
	else {
		const __m128 v0 = _mm_set1_ps(m00);
		const __m128 v1 = _mm_set1_ps(m11);
		for(n = 0; n < unrolled; n += 4) {
			in = _mm_mul_ps(_mm_load_ps(&sFL[n]), v0);
			_mm_store_ps(&dFL[n], in);
			_mm_store_ps(&dRL[n], in);
			in = _mm_mul_ps(_mm_load_ps(&sFR[n]), v1);
			_mm_store_ps(&dFR[n], in);
			_mm_store_ps(&dRR[n], in);
		}
		for(; n < n_samples; n++) {
			in = _mm_mul_ss(_mm_load_ss(&sFL[n]), v0);
			_mm_store_ss(&dFL[n], in);
			_mm_store_ss(&dRL[n], in);
			in = _mm_mul_ss(_mm_load_ss(&sFR[n]), v1);
			_mm_store_ss(&dFR[n], in);
			_mm_store_ss(&dRR[n], in);
		}
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR */
void
channelmix_f32_5p1_2_sse(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n, unrolled;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float m00 = mix->matrix[0][0];
	const float m11 = mix->matrix[1][1];
	const __m128 clev = _mm_set1_ps((mix->matrix[0][2] + mix->matrix[1][2]) * 0.5f);
	const __m128 llev = _mm_set1_ps((mix->matrix[0][3] + mix->matrix[1][3]) * 0.5f);
	const __m128 slev0 = _mm_set1_ps(mix->matrix[0][4]);
	const __m128 slev1 = _mm_set1_ps(mix->matrix[1][5]);
	__m128 in, ctr;
	const float *sFL = s[0], *sFR = s[1], *sFC = s[2], *sLFE = s[3], *sSL = s[4], *sSR = s[5];
	float *dFL = d[0], *dFR = d[1];

	if (SPA_IS_ALIGNED(sFL, 16) &&
	    SPA_IS_ALIGNED(sFR, 16) &&
	    SPA_IS_ALIGNED(sFC, 16) &&
	    SPA_IS_ALIGNED(sLFE, 16) &&
	    SPA_IS_ALIGNED(sSL, 16) &&
	    SPA_IS_ALIGNED(sSR, 16) &&
	    SPA_IS_ALIGNED(dFL, 16) &&
	    SPA_IS_ALIGNED(dFR, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(dFL, 0, n_samples * sizeof(float));
		memset(dFR, 0, n_samples * sizeof(float));
	}
	else if (m00 == 1.0f && m11 == 1.0f) {
		for(n = 0; n < unrolled; n += 4) {
			ctr = _mm_mul_ps(_mm_load_ps(&sFC[n]), clev);
			ctr = _mm_add_ps(ctr, _mm_mul_ps(_mm_load_ps(&sLFE[n]), llev));
			in = _mm_mul_ps(_mm_load_ps(&sSL[n]), slev0);
			in = _mm_add_ps(in, ctr);
			in = _mm_add_ps(in, _mm_load_ps(&sFL[n]));
			_mm_store_ps(&dFL[n], in);
			in = _mm_mul_ps(_mm_load_ps(&sSR[n]), slev1);
			in = _mm_add_ps(in, ctr);
			in = _mm_add_ps(in, _mm_load_ps(&sFR[n]));
			_mm_store_ps(&dFR[n], in);
		}
		for(; n < n_samples; n++) {
			ctr = _mm_mul_ss(_mm_load_ss(&sFC[n]), clev);
			ctr = _mm_add_ss(ctr, _mm_mul_ss(_mm_load_ss(&sLFE[n]), llev));
			in = _mm_mul_ss(_mm_load_ss(&sSL[n]), slev0);
			in = _mm_add_ss(in, ctr);
			in = _mm_add_ss(in, _mm_load_ss(&sFL[n]));
			_mm_store_ss(&dFL[n], in);
			in = _mm_mul_ss(_mm_load_ss(&sSR[n]), slev1);
			in = _mm_add_ss(in, ctr);
			in = _mm_add_ss(in, _mm_load_ss(&sFR[n]));
			_mm_store_ss(&dFR[n], in);
		}
	}
	else {
		const __m128 v0 = _mm_set1_ps(m00);
		const __m128 v1 = _mm_set1_ps(m11);
		for(n = 0; n < unrolled; n += 4) {
			ctr = _mm_mul_ps(_mm_load_ps(&sFC[n]), clev);
			ctr = _mm_add_ps(ctr, _mm_mul_ps(_mm_load_ps(&sLFE[n]), llev));
			in = _mm_mul_ps(_mm_load_ps(&sSL[n]), slev0);
			in = _mm_add_ps(in, ctr);
			in = _mm_add_ps(in, _mm_load_ps(&sFL[n]));
			in = _mm_mul_ps(in, v0);
			_mm_store_ps(&dFL[n], in);
			in = _mm_mul_ps(_mm_load_ps(&sSR[n]), slev1);
			in = _mm_add_ps(in, ctr);
			in = _mm_add_ps(in, _mm_load_ps(&sFR[n]));
			in = _mm_mul_ps(in, v1);
			_mm_store_ps(&dFR[n], in);
		}
		for(; n < n_samples; n++) {
			ctr = _mm_mul_ss(_mm_load_ss(&sFC[n]), clev);
			ctr = _mm_add_ss(ctr, _mm_mul_ss(_mm_load_ss(&sLFE[n]), llev));
			in = _mm_mul_ss(_mm_load_ss(&sSL[n]), slev0);
			in = _mm_add_ss(in, ctr);
			in = _mm_add_ss(in, _mm_load_ss(&sFL[n]));
			in = _mm_mul_ss(in, v0);
			_mm_store_ss(&dFL[n], in);
			in = _mm_mul_ss(_mm_load_ss(&sSR[n]), slev1);
			in = _mm_add_ss(in, ctr);
			in = _mm_add_ss(in, _mm_load_ss(&sFR[n]));
			in = _mm_mul_ss(in, v1);
			_mm_store_ss(&dFR[n], in);
		}
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR+FC+LFE*/
void
channelmix_f32_5p1_3p1_sse(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n, unrolled;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const __m128 v0 = _mm_set1_ps(mix->matrix[0][0]);
	const __m128 v1 = _mm_set1_ps(mix->matrix[1][1]);
	const __m128 slev0 = _mm_set1_ps(mix->matrix[0][4]);
	const __m128 slev1 = _mm_set1_ps(mix->matrix[1][5]);
	const __m128 v2 = _mm_set1_ps(mix->matrix[2][2]);
	const __m128 v3 = _mm_set1_ps(mix->matrix[3][3]);
	__m128 avg[2];
	const float *sFL = s[0], *sFR = s[1], *sFC = s[2], *sLFE = s[3], *sSL = s[4], *sSR = s[5];
	float *dFL = d[0], *dFR = d[1], *dFC = d[2], *dLFE = d[3];

	if (SPA_IS_ALIGNED(sFL, 16) &&
	    SPA_IS_ALIGNED(sFR, 16) &&
	    SPA_IS_ALIGNED(sFC, 16) &&
	    SPA_IS_ALIGNED(sLFE, 16) &&
	    SPA_IS_ALIGNED(sSL, 16) &&
	    SPA_IS_ALIGNED(sSR, 16) &&
	    SPA_IS_ALIGNED(dFL, 16) &&
	    SPA_IS_ALIGNED(dFR, 16) &&
	    SPA_IS_ALIGNED(dFC, 16) &&
	    SPA_IS_ALIGNED(dLFE, 16))
		unrolled = n_samples & ~7;
	else
		unrolled = 0;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for(n = 0; n < unrolled; n += 8) {
			avg[0] = _mm_add_ps(
					_mm_mul_ps(_mm_load_ps(&sFL[n]), v0),
					_mm_mul_ps(_mm_load_ps(&sSL[n]), slev0));
			avg[1] = _mm_add_ps(
					_mm_mul_ps(_mm_load_ps(&sFL[n+4]), v0),
					_mm_mul_ps(_mm_load_ps(&sSL[n+4]), slev0));
			_mm_store_ps(&dFL[n], avg[0]);
			_mm_store_ps(&dFL[n+4], avg[1]);

			avg[0] = _mm_add_ps(
					_mm_mul_ps(_mm_load_ps(&sFR[n]), v1),
					_mm_mul_ps(_mm_load_ps(&sSR[n]), slev1));
			avg[1] = _mm_add_ps(
					_mm_mul_ps(_mm_load_ps(&sFR[n+4]), v1),
					_mm_mul_ps(_mm_load_ps(&sSR[n+4]), slev1));
			_mm_store_ps(&dFR[n], avg[0]);
			_mm_store_ps(&dFR[n+4], avg[1]);

			_mm_store_ps(&dFC[n], _mm_mul_ps(_mm_load_ps(&sFC[n]), v2));
			_mm_store_ps(&dFC[n+4], _mm_mul_ps(_mm_load_ps(&sFC[n+4]), v2));
			_mm_store_ps(&dLFE[n], _mm_mul_ps(_mm_load_ps(&sLFE[n]), v3));
			_mm_store_ps(&dLFE[n+4], _mm_mul_ps(_mm_load_ps(&sLFE[n+4]), v3));
		}
		for(; n < n_samples; n++) {
			avg[0] = _mm_add_ss(
					_mm_mul_ss(_mm_load_ss(&sFL[n]), v0),
					_mm_mul_ss(_mm_load_ss(&sSL[n]), slev0));
			_mm_store_ss(&dFL[n], avg[0]);

			avg[0] = _mm_add_ss(
					_mm_mul_ss(_mm_load_ss(&sFR[n]), v1),
					_mm_mul_ss(_mm_load_ss(&sSR[n]), slev1));
			_mm_store_ss(&dFR[n], avg[0]);

			_mm_store_ss(&dFC[n], _mm_mul_ss(_mm_load_ss(&sFC[n]), v2));
			_mm_store_ss(&dLFE[n], _mm_mul_ss(_mm_load_ss(&sLFE[n]), v3));
		}
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR+RL+RR*/
void
channelmix_f32_5p1_4_sse(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n, unrolled;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const __m128 clev = _mm_set1_ps(mix->matrix[0][2]);
	const __m128 llev = _mm_set1_ps(mix->matrix[0][3]);
	const float m00 = mix->matrix[0][0];
	const float m11 = mix->matrix[1][1];
	const float m24 = mix->matrix[2][4];
	const float m35 = mix->matrix[3][5];
	__m128 ctr;
	const float *sFL = s[0], *sFR = s[1], *sFC = s[2], *sLFE = s[3], *sSL = s[4], *sSR = s[5];
	float *dFL = d[0], *dFR = d[1], *dRL = d[2], *dRR = d[3];

	if (SPA_IS_ALIGNED(sFL, 16) &&
	    SPA_IS_ALIGNED(sFR, 16) &&
	    SPA_IS_ALIGNED(sFC, 16) &&
	    SPA_IS_ALIGNED(sLFE, 16) &&
	    SPA_IS_ALIGNED(sSL, 16) &&
	    SPA_IS_ALIGNED(sSR, 16) &&
	    SPA_IS_ALIGNED(dFL, 16) &&
	    SPA_IS_ALIGNED(dFR, 16) &&
	    SPA_IS_ALIGNED(dRL, 16) &&
	    SPA_IS_ALIGNED(dRR, 16))
		unrolled = n_samples & ~3;
	else
		unrolled = 0;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (m00 == 1.0f && m11 == 1.0f && m24 == 1.0f && m35 == 1.0f) {
		for(n = 0; n < unrolled; n += 4) {
			ctr = _mm_mul_ps(_mm_load_ps(&sFC[n]), clev);
			ctr = _mm_add_ps(ctr, _mm_mul_ps(_mm_load_ps(&sLFE[n]), llev));
			_mm_store_ps(&dFL[n], _mm_add_ps(_mm_load_ps(&sFL[n]), ctr));
			_mm_store_ps(&dFR[n], _mm_add_ps(_mm_load_ps(&sFR[n]), ctr));
			_mm_store_ps(&dRL[n], _mm_load_ps(&sSL[n]));
			_mm_store_ps(&dRR[n], _mm_load_ps(&sSR[n]));
		}
		for(; n < n_samples; n++) {
			ctr = _mm_mul_ss(_mm_load_ss(&sFC[n]), clev);
			ctr = _mm_add_ss(ctr, _mm_mul_ss(_mm_load_ss(&sLFE[n]), llev));
			_mm_store_ss(&dFL[n], _mm_add_ss(_mm_load_ss(&sFL[n]), ctr));
			_mm_store_ss(&dFR[n], _mm_add_ss(_mm_load_ss(&sFR[n]), ctr));
			_mm_store_ss(&dRL[n], _mm_load_ss(&sSL[n]));
			_mm_store_ss(&dRR[n], _mm_load_ss(&sSR[n]));
		}
	}
	else {
		const __m128 v0 = _mm_set1_ps(m00);
		const __m128 v1 = _mm_set1_ps(m11);
		const __m128 v4 = _mm_set1_ps(m24);
		const __m128 v5 = _mm_set1_ps(m35);

		for(n = 0; n < unrolled; n += 4) {
			ctr = _mm_mul_ps(_mm_load_ps(&sFC[n]), clev);
			ctr = _mm_add_ps(ctr, _mm_mul_ps(_mm_load_ps(&sLFE[n]), llev));
			_mm_store_ps(&dFL[n], _mm_mul_ps(_mm_add_ps(_mm_load_ps(&sFL[n]), ctr), v0));
			_mm_store_ps(&dFR[n], _mm_mul_ps(_mm_add_ps(_mm_load_ps(&sFR[n]), ctr), v1));
			_mm_store_ps(&dRL[n], _mm_mul_ps(_mm_load_ps(&sSL[n]), v4));
			_mm_store_ps(&dRR[n], _mm_mul_ps(_mm_load_ps(&sSR[n]), v5));
		}
		for(; n < n_samples; n++) {
			ctr = _mm_mul_ss(_mm_load_ss(&sFC[n]), clev);
			ctr = _mm_add_ss(ctr, _mm_mul_ss(_mm_load_ss(&sLFE[n]), llev));
			_mm_store_ss(&dFL[n], _mm_mul_ss(_mm_add_ss(_mm_load_ss(&sFL[n]), ctr), v0));
			_mm_store_ss(&dFR[n], _mm_mul_ss(_mm_add_ss(_mm_load_ss(&sFR[n]), ctr), v1));
			_mm_store_ss(&dRL[n], _mm_mul_ss(_mm_load_ss(&sSL[n]), v4));
			_mm_store_ss(&dRR[n], _mm_mul_ss(_mm_load_ss(&sSR[n]), v5));
		}
	}
}
