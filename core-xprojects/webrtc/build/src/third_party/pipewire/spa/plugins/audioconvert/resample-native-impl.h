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

#include <math.h>

#include <spa/utils/defs.h>

#include "resample.h"

typedef void (*resample_func_t)(struct resample *r,
        const void * SPA_RESTRICT src[], uint32_t ioffs, uint32_t *in_len,
        void * SPA_RESTRICT dst[], uint32_t ooffs, uint32_t *out_len);

struct resample_info {
	uint32_t format;
	uint32_t cpu_flags;
	resample_func_t process_copy;
	resample_func_t process_full;
	resample_func_t process_inter;
};

struct native_data {
	double rate;
	uint32_t n_taps;
	uint32_t n_phases;
	uint32_t in_rate;
	uint32_t out_rate;
	uint32_t phase;
	uint32_t inc;
	uint32_t frac;
	uint32_t filter_stride;
	uint32_t filter_stride_os;
	uint32_t hist;
	float **history;
	resample_func_t func;
	float *filter;
	float *hist_mem;
	const struct resample_info *info;
};

#define DEFINE_RESAMPLER(type,arch)						\
void do_resample_##type##_##arch(struct resample *r,				\
	const void * SPA_RESTRICT src[], uint32_t ioffs, uint32_t *in_len,	\
	void * SPA_RESTRICT dst[], uint32_t ooffs, uint32_t *out_len)

#define MAKE_RESAMPLER_COPY(arch)						\
DEFINE_RESAMPLER(copy,arch)							\
{										\
	struct native_data *data = r->data;					\
	uint32_t index, n_taps = data->n_taps, n_taps2 = n_taps/2;		\
	uint32_t c, olen = *out_len, ilen = *in_len;				\
										\
	if (r->channels == 0)							\
		return;								\
										\
	index = ioffs;								\
	if (ooffs < olen && index + n_taps <= ilen) {				\
		uint32_t to_copy = SPA_MIN(olen - ooffs,			\
				ilen - (index + n_taps) + 1);			\
		for (c = 0; c < r->channels; c++) {				\
			const float *s = src[c];				\
			float *d = dst[c];					\
			spa_memcpy(&d[ooffs], &s[index + n_taps2],		\
					to_copy * sizeof(float));		\
		}								\
		index += to_copy;						\
		ooffs += to_copy;						\
	}									\
	*in_len = index;							\
	*out_len = ooffs;							\
}

#define MAKE_RESAMPLER_FULL(arch)						\
DEFINE_RESAMPLER(full,arch)							\
{										\
	struct native_data *data = r->data;					\
	uint32_t n_taps = data->n_taps, stride = data->filter_stride_os;	\
	uint32_t index, phase, n_phases = data->out_rate;			\
	uint32_t c, o, olen = *out_len, ilen = *in_len;				\
	uint32_t inc = data->inc, frac = data->frac;				\
										\
	if (r->channels == 0)							\
		return;								\
										\
	for (c = 0; c < r->channels; c++) {					\
		const float *s = src[c];					\
		float *d = dst[c];						\
										\
		index = ioffs;							\
		phase = data->phase;						\
										\
		for (o = ooffs; o < olen && index + n_taps <= ilen; o++) {	\
			const float *ip, *taps;					\
										\
			ip = &s[index];						\
			taps = &data->filter[phase * stride];			\
			index += inc;						\
			phase += frac;						\
			if (phase >= n_phases) {				\
				phase -= n_phases;				\
				index += 1;					\
			}							\
			inner_product_##arch(&d[o], ip, taps, n_taps);		\
		}								\
	}									\
	*in_len = index;							\
	*out_len = o;								\
	data->phase = phase;							\
}

#define MAKE_RESAMPLER_INTER(arch)						\
DEFINE_RESAMPLER(inter,arch)							\
{										\
	struct native_data *data = r->data;					\
	uint32_t index, phase, stride = data->filter_stride;			\
	uint32_t n_phases = data->n_phases, out_rate = data->out_rate;		\
	uint32_t n_taps = data->n_taps;						\
	uint32_t c, o, olen = *out_len, ilen = *in_len;				\
	uint32_t inc = data->inc, frac = data->frac;				\
										\
	if (r->channels == 0)							\
		return;								\
										\
	for (c = 0; c < r->channels; c++) {					\
		const float *s = src[c];					\
		float *d = dst[c];						\
										\
		index = ioffs;							\
		phase = data->phase;						\
										\
		for (o = ooffs; o < olen && index + n_taps <= ilen; o++) {	\
			const float *ip, *t0, *t1;				\
			float ph, x;						\
			uint32_t offset;					\
										\
			ip = &s[index];						\
			ph = (float)phase * n_phases / out_rate;		\
			offset = floor(ph);					\
			x = ph - (float)offset;					\
										\
			t0 = &data->filter[(offset + 0) * stride];		\
			t1 = &data->filter[(offset + 1) * stride];		\
			index += inc;						\
			phase += frac;						\
			if (phase >= out_rate) {				\
				phase -= out_rate;				\
				index += 1;					\
			}							\
			inner_product_ip_##arch(&d[o], ip, t0, t1, x, n_taps);	\
		}								\
	}									\
	*in_len = index;							\
	*out_len = o;								\
	data->phase = phase;							\
}


DEFINE_RESAMPLER(copy,c);
DEFINE_RESAMPLER(full,c);
DEFINE_RESAMPLER(inter,c);

#if defined (HAVE_NEON)
DEFINE_RESAMPLER(full,neon);
DEFINE_RESAMPLER(inter,neon);
#endif
#if defined (HAVE_SSE)
DEFINE_RESAMPLER(full,sse);
DEFINE_RESAMPLER(inter,sse);
#endif
#if defined (HAVE_SSSE3)
DEFINE_RESAMPLER(full,ssse3);
DEFINE_RESAMPLER(inter,ssse3);
#endif
#if defined (HAVE_AVX) && defined(HAVE_FMA)
DEFINE_RESAMPLER(full,avx);
DEFINE_RESAMPLER(inter,avx);
#endif
