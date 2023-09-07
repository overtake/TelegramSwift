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

#include "resample-native-impl.h"

#include <assert.h>
#include <immintrin.h>

static void inner_product_avx(float *d, const float * SPA_RESTRICT s,
		const float * SPA_RESTRICT taps, uint32_t n_taps)
{
	__m256 sy[2] = { _mm256_setzero_ps(), _mm256_setzero_ps() }, ty;
	__m128 sx[2], tx;
	uint32_t i = 0;
	uint32_t n_taps4 = n_taps & ~0xf;

	for (; i < n_taps4; i += 16) {
		ty = (__m256)_mm256_lddqu_si256((__m256i*)(s + i + 0));
		sy[0] = _mm256_fmadd_ps(ty, _mm256_load_ps(taps + i + 0), sy[0]);
		ty = (__m256)_mm256_lddqu_si256((__m256i*)(s + i + 8));
		sy[1] = _mm256_fmadd_ps(ty, _mm256_load_ps(taps + i + 8), sy[1]);
	}
	sy[0] = _mm256_add_ps(sy[1], sy[0]);
	sx[1] = _mm256_extractf128_ps(sy[0], 1);
	sx[0] = _mm256_extractf128_ps(sy[0], 0);
	for (; i < n_taps; i += 8) {
		tx = (__m128)_mm_lddqu_si128((__m128i*)(s + i + 0));
		sx[0] = _mm_fmadd_ps(tx, _mm_load_ps(taps + i + 0), sx[0]);
		tx = (__m128)_mm_lddqu_si128((__m128i*)(s + i + 4));
		sx[1] = _mm_fmadd_ps(tx, _mm_load_ps(taps + i + 4), sx[1]);
	}
	sx[0] = _mm_add_ps(sx[0], sx[1]);
	sx[0] = _mm_hadd_ps(sx[0], sx[0]);
	sx[0] = _mm_hadd_ps(sx[0], sx[0]);
	_mm_store_ss(d, sx[0]);
}

static void inner_product_ip_avx(float *d, const float * SPA_RESTRICT s,
	const float * SPA_RESTRICT t0, const float * SPA_RESTRICT t1, float x,
	uint32_t n_taps)
{
	__m256 sy[2] = { _mm256_setzero_ps(), _mm256_setzero_ps() }, ty;
	__m128 sx[2], tx;
	uint32_t i, n_taps4 = n_taps & ~0xf;

	for (i = 0; i < n_taps4; i += 16) {
		ty = (__m256)_mm256_lddqu_si256((__m256i*)(s + i + 0));
		sy[0] = _mm256_fmadd_ps(ty, _mm256_load_ps(t0 + i + 0), sy[0]);
		sy[1] = _mm256_fmadd_ps(ty, _mm256_load_ps(t1 + i + 0), sy[1]);
		ty = (__m256)_mm256_lddqu_si256((__m256i*)(s + i + 8));
		sy[0] = _mm256_fmadd_ps(ty, _mm256_load_ps(t0 + i + 8), sy[0]);
		sy[1] = _mm256_fmadd_ps(ty, _mm256_load_ps(t1 + i + 8), sy[1]);
	}
	sx[0] = _mm_add_ps(_mm256_extractf128_ps(sy[0], 0), _mm256_extractf128_ps(sy[0], 1));
	sx[1] = _mm_add_ps(_mm256_extractf128_ps(sy[1], 0), _mm256_extractf128_ps(sy[1], 1));

	for (; i < n_taps; i += 8) {
		tx = (__m128)_mm_lddqu_si128((__m128i*)(s + i + 0));
		sx[0] = _mm_fmadd_ps(tx, _mm_load_ps(t0 + i + 0), sx[0]);
		sx[1] = _mm_fmadd_ps(tx, _mm_load_ps(t1 + i + 0), sx[1]);
		tx = (__m128)_mm_lddqu_si128((__m128i*)(s + i + 4));
		sx[0] = _mm_fmadd_ps(tx, _mm_load_ps(t0 + i + 4), sx[0]);
		sx[1] = _mm_fmadd_ps(tx, _mm_load_ps(t1 + i + 4), sx[1]);
	}
	sx[1] = _mm_mul_ps(_mm_sub_ps(sx[1], sx[0]), _mm_load1_ps(&x));
	sx[0] = _mm_add_ps(sx[0], sx[1]);
	sx[0] = _mm_hadd_ps(sx[0], sx[0]);
	sx[0] = _mm_hadd_ps(sx[0], sx[0]);
	_mm_store_ss(d, sx[0]);
}

MAKE_RESAMPLER_FULL(avx);
MAKE_RESAMPLER_INTER(avx);
