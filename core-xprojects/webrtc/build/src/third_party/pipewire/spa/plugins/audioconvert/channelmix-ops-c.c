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

void
channelmix_copy_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
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
			for (n = 0; n < n_samples; n++)
				d[i][n] = s[i][n] * mix->matrix[i][i];
		}
	}
}

#define _M(ch)		(1UL << SPA_AUDIO_CHANNEL_ ## ch)

void
channelmix_f32_n_m_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, j, n;
	float **d = (float **) dst;
	const float **s = (const float **) src;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_COPY)) {
		uint32_t copy = SPA_MIN(n_dst, n_src);
		for (i = 0; i < copy; i++)
			spa_memcpy(d[i], s[i], n_samples * sizeof(float));
		for (; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			for (i = 0; i < n_dst; i++) {
				float sum = 0.0f;
				for (j = 0; j < n_src; j++)
					sum += s[j][n] * mix->matrix[i][j];
				d[i][n] = sum;
			}
		}
		for (i = 0; i < n_dst; i++) {
			if (mix->lr4_info[i] > 0)
				lr4_process(&mix->lr4[i], d[i], n_samples);
		}
	}
}

#define MASK_MONO	_M(FC)|_M(MONO)|_M(UNKNOWN)
#define MASK_STEREO	_M(FL)|_M(FR)|_M(UNKNOWN)

void
channelmix_f32_1_2_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][0];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
		memset(d[1], 0, n_samples * sizeof(float));
	} else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_EQUAL)) {
		if (v0 == 1.0f) {
			for (n = 0; n < n_samples; n++)
				d[0][n] = d[1][n] = s[0][n];
		} else {
			for (n = 0; n < n_samples; n++)
				d[0][n] = d[1][n] = s[0][n] * v0;
		}
	} else {
		for (n = 0; n < n_samples; n++) {
			d[0][n] = s[0][n] * v0;
			d[1][n] = s[0][n] * v1;
		}
	}
}

void
channelmix_f32_2_1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[0][1];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
	} else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_EQUAL)) {
		for (n = 0; n < n_samples; n++)
			d[0][n] = (s[0][n] + s[1][n]) * v0;
	}
	else {
		for (n = 0; n < n_samples; n++)
			d[0][n] = s[0][n] * v0 + s[1][n] * v1;
	}
}

void
channelmix_f32_4_1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[0][1];
	const float v2 = mix->matrix[0][2];
	const float v3 = mix->matrix[0][3];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
	}
	else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_EQUAL)) {
		for (n = 0; n < n_samples; n++)
			d[0][n] = (s[0][n] + s[1][n] + s[2][n] + s[3][n]) * v0;
	}
	else {
		for (n = 0; n < n_samples; n++)
			d[0][n] = s[0][n] * v0 + s[1][n] * v1 +
				s[2][n] * v2 + s[3][n] * v3;
	}
}

void
channelmix_f32_3p1_1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[0][1];
	const float v2 = mix->matrix[0][2];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
	}
	else if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_EQUAL)) {
		for (n = 0; n < n_samples; n++)
			d[0][n] = (s[0][n] + s[1][n] + s[2][n] + s[3][n]) * v0;
	}
	else {
		for (n = 0; n < n_samples; n++)
			d[0][n] = s[0][n] * v0 + s[1][n] * v1 + s[2][n] * v2;
	}
}


#define MASK_QUAD	_M(FL)|_M(FR)|_M(RL)|_M(RR)|_M(UNKNOWN)

void
channelmix_f32_2_4_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v2 = mix->matrix[2][0];
	const float v3 = mix->matrix[3][1];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (v0 == v2 && v1 == v3) {
		if (v0 == 1.0f && v1 == 1.0f) {
			for (n = 0; n < n_samples; n++) {
				d[0][n] = d[2][n] = s[0][n];
				d[1][n] = d[3][n] = s[1][n];
			}
		} else {
			for (n = 0; n < n_samples; n++) {
				d[0][n] = d[2][n] = s[0][n] * v0;
				d[1][n] = d[3][n] = s[1][n] * v1;
			}
		}
	}
	else {
		for (n = 0; n < n_samples; n++) {
			d[0][n] = s[0][n] * v0;
			d[1][n] = s[1][n] * v1;
			d[2][n] = s[0][n] * v2;
			d[3][n] = s[1][n] * v3;
		}
	}
}

#define MASK_3_1	_M(FL)|_M(FR)|_M(FC)|_M(LFE)
void
channelmix_f32_2_3p1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v2 = (mix->matrix[2][0] + mix->matrix[2][1]) * 0.5f;
	const float v3 = (mix->matrix[3][0] + mix->matrix[3][1]) * 0.5f;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (v0 == 1.0f && v1 == 1.0f) {
		for (n = 0; n < n_samples; n++) {
			float c = s[0][n] + s[1][n];
			d[0][n] = s[0][n];
			d[1][n] = s[1][n];
			d[2][n] = c * v2;
			d[3][n] = c * v3;
		}
		if (v3 > 0.0f)
			lr4_process(&mix->lr4[3], d[3], n_samples);
	}
	else {
		for (n = 0; n < n_samples; n++) {
			float c = s[0][n] + s[1][n];
			d[0][n] = s[0][n] * v0;
			d[1][n] = s[1][n] * v1;
			d[2][n] = c * v2;
			d[3][n] = c * v3;
		}
		if (v3 > 0.0f)
			lr4_process(&mix->lr4[3], d[3], n_samples);
	}
}

#define MASK_5_1	_M(FL)|_M(FR)|_M(FC)|_M(LFE)|_M(SL)|_M(SR)|_M(RL)|_M(RR)
void
channelmix_f32_2_5p1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **)dst;
	const float **s = (const float **)src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v2 = (mix->matrix[2][0] + mix->matrix[2][1]) * 0.5f;
	const float v3 = (mix->matrix[3][0] + mix->matrix[3][1]) * 0.5f;
	const float v4 = mix->matrix[4][0];
	const float v5 = mix->matrix[5][1];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else if (v0 == 1.0f && v1 == 1.0f && v4 == 1.0f && v5 == 1.0f) {
		for (n = 0; n < n_samples; n++) {
			float c = s[0][n] + s[1][n];
			d[0][n] = d[4][n] = s[0][n];
			d[1][n] = d[5][n] = s[1][n];
			d[2][n] = c * v2;
			d[3][n] = c * v3;
		}
		if (v3 > 0.0f)
			lr4_process(&mix->lr4[3], d[3], n_samples);
	}
	else {
		for (n = 0; n < n_samples; n++) {
			float c = s[0][n] + s[1][n];
			d[0][n] = s[0][n] * v0;
			d[1][n] = s[1][n] * v1;
			d[2][n] = c * v2;
			d[3][n] = c * v3;
			d[4][n] = s[0][n] * v4;
			d[5][n] = s[1][n] * v5;
		}
		if (v3 > 0.0f)
			lr4_process(&mix->lr4[3], d[3], n_samples);
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR */
void
channelmix_f32_5p1_2_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float clev = (mix->matrix[0][2] + mix->matrix[1][2]) * 0.5f;
	const float llev = (mix->matrix[0][3] + mix->matrix[1][3]) * 0.5f;
	const float slev0 = mix->matrix[0][4];
	const float slev1 = mix->matrix[1][5];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
		memset(d[1], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			const float ctr = clev * s[2][n] + llev * s[3][n];
			d[0][n] = s[0][n] * v0 + ctr + (slev0 * s[4][n]);
			d[1][n] = s[1][n] * v1 + ctr + (slev1 * s[5][n]);
		}
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR+FC+LFE*/
void
channelmix_f32_5p1_3p1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v2 = mix->matrix[2][2];
	const float v3 = mix->matrix[3][3];
	const float v4 = mix->matrix[0][4];
	const float v5 = mix->matrix[1][5];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			d[0][n] = s[0][n] * v0 + s[4][n] * v4;
			d[1][n] = s[1][n] * v1 + s[5][n] * v5;
			d[2][n] = s[2][n] * v2;
			d[3][n] = s[3][n] * v3;
		}
	}
}

/* FL+FR+FC+LFE+SL+SR -> FL+FR+RL+RR*/
void
channelmix_f32_5p1_4_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float clev = mix->matrix[0][2];
	const float llev = mix->matrix[0][3];
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v4 = mix->matrix[2][4];
	const float v5 = mix->matrix[3][5];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			const float ctr = s[2][n] * clev + s[3][n] * llev;
			d[0][n] = s[0][n] * v0 + ctr;
			d[1][n] = s[1][n] * v1 + ctr;
			d[2][n] = s[4][n] * v4;
			d[3][n] = s[5][n] * v5;
		}
	}
}

#define MASK_7_1	_M(FL)|_M(FR)|_M(FC)|_M(LFE)|_M(SL)|_M(SR)|_M(RL)|_M(RR)

/* FL+FR+FC+LFE+SL+SR+RL+RR -> FL+FR */
void
channelmix_f32_7p1_2_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float clev = (mix->matrix[0][2] + mix->matrix[1][2]) * 0.5f;
	const float llev = (mix->matrix[0][3] + mix->matrix[1][3]) * 0.5f;
	const float slev0 = mix->matrix[0][4];
	const float slev1 = mix->matrix[1][5];
	const float rlev0 = mix->matrix[0][6];
	const float rlev1 = mix->matrix[1][7];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		memset(d[0], 0, n_samples * sizeof(float));
		memset(d[1], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			const float ctr = clev * s[2][n] + llev * s[3][n];
			d[0][n] = s[0][n] * v0 + ctr + s[4][n] * slev0 + s[6][n] * rlev0;
			d[1][n] = s[1][n] * v1 + ctr + s[5][n] * slev1 + s[7][n] * rlev1;
		}
	}
}

/* FL+FR+FC+LFE+SL+SR+RL+RR -> FL+FR+FC+LFE*/
void
channelmix_f32_7p1_3p1_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float v2 = mix->matrix[2][2];
	const float v3 = mix->matrix[3][3];
	const float v4 = (mix->matrix[0][4] + mix->matrix[0][6]) * 0.5f;
	const float v5 = (mix->matrix[1][5] + mix->matrix[1][7]) * 0.5f;

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			d[0][n] = s[0][n] * v0 + (s[4][n] + s[6][n]) * v4;
			d[1][n] = s[1][n] * v1 + (s[5][n] + s[7][n]) * v5;
			d[2][n] = s[2][n] * v2;
			d[3][n] = s[3][n] * v3;
		}
	}
}

/* FL+FR+FC+LFE+SL+SR+RL+RR -> FL+FR+RL+RR*/
void
channelmix_f32_7p1_4_c(struct channelmix *mix, uint32_t n_dst, void * SPA_RESTRICT dst[n_dst],
		   uint32_t n_src, const void * SPA_RESTRICT src[n_src], uint32_t n_samples)
{
	uint32_t i, n;
	float **d = (float **) dst;
	const float **s = (const float **) src;
	const float v0 = mix->matrix[0][0];
	const float v1 = mix->matrix[1][1];
	const float clev = (mix->matrix[0][2] + mix->matrix[1][2]) * 0.5f;
	const float llev = (mix->matrix[0][3] + mix->matrix[1][3]) * 0.5f;
	const float slev0 = mix->matrix[2][4];
	const float slev1 = mix->matrix[3][5];
	const float rlev0 = mix->matrix[2][6];
	const float rlev1 = mix->matrix[3][7];

	if (SPA_FLAG_IS_SET(mix->flags, CHANNELMIX_FLAG_ZERO)) {
		for (i = 0; i < n_dst; i++)
			memset(d[i], 0, n_samples * sizeof(float));
	}
	else {
		for (n = 0; n < n_samples; n++) {
			const float ctr = s[2][n] * clev + s[3][n] * llev;
			const float sl = s[4][n] * slev0;
			const float sr = s[5][n] * slev1;
			d[0][n] = s[0][n] * v0 + ctr + sl;
			d[1][n] = s[1][n] * v1 + ctr + sr;
			d[2][n] = s[6][n] * rlev0 + sl;
			d[3][n] = s[7][n] * rlev1 + sr;
		}
	}
}
