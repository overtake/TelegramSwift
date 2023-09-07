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

#include <errno.h>

#include <spa/param/audio/format.h>

#include "resample-native-impl.h"

struct quality {
	uint32_t n_taps;
	double cutoff;
};

static const struct quality blackman_qualities[] = {
	{ 8, 0.5, },
	{ 16, 0.70, },
	{ 24, 0.76, },
	{ 32, 0.8, },
	{ 48, 0.865, },                  /* default */
	{ 64, 0.90, },
	{ 80, 0.92, },
	{ 96, 0.933, },
	{ 128, 0.950, },
	{ 144, 0.955, },
	{ 160, 0.960, },
	{ 192, 0.965, },
	{ 256, 0.975, },
	{ 896, 0.997, },
	{ 1024, 0.998, },
};

static inline double sinc(double x)
{
	if (x < 1e-6) return 1.0;
	x *= M_PI;
	return sin(x) / x;
}

static inline double blackman(double x, double n_taps)
{
	double w = 2.0 * x * M_PI / n_taps + M_PI;
	return 0.3635819 - 0.4891775 * cos(w) +
		0.1365995 * cos(2 * w) - 0.0106411 * cos(3 * w);
}

static int build_filter(float *taps, uint32_t stride, uint32_t n_taps, uint32_t n_phases, double cutoff)
{
	uint32_t i, j, n_taps12 = n_taps/2;

	for (i = 0; i <= n_phases; i++) {
		double t = (double) i / (double) n_phases;
		for (j = 0; j < n_taps12; j++, t += 1.0) {
			/* exploit symmetry in filter taps */
			taps[(n_phases - i) * stride + n_taps12 + j] =
				taps[i * stride + (n_taps12 - j - 1)] =
					cutoff * sinc(t * cutoff) * blackman(t, n_taps);
		}
	}
	return 0;
}

static void inner_product_c(float *d, const float * SPA_RESTRICT s,
		const float * SPA_RESTRICT taps, uint32_t n_taps)
{
	float sum = 0.0f;
	uint32_t i;

	for (i = 0; i < n_taps; i++)
		sum += s[i] * taps[i];
	*d = sum;
}

static void inner_product_ip_c(float *d, const float * SPA_RESTRICT s,
	const float * SPA_RESTRICT t0, const float * SPA_RESTRICT t1, float x,
	uint32_t n_taps)
{
	float sum[2] = { 0.0f, 0.0f };
	uint32_t i;

	for (i = 0; i < n_taps; i++) {
		sum[0] += s[i] * t0[i];
		sum[1] += s[i] * t1[i];
	}
	*d = (sum[1] - sum[0]) * x + sum[0];
}

MAKE_RESAMPLER_COPY(c);
MAKE_RESAMPLER_FULL(c);
MAKE_RESAMPLER_INTER(c);

static struct resample_info resample_table[] =
{
#if defined (HAVE_NEON)
	{ SPA_AUDIO_FORMAT_F32, SPA_CPU_FLAG_NEON,
		do_resample_copy_c, do_resample_full_neon, do_resample_inter_neon },
#endif
#if defined(HAVE_AVX) && defined(HAVE_FMA)
	{ SPA_AUDIO_FORMAT_F32, SPA_CPU_FLAG_AVX | SPA_CPU_FLAG_FMA3,
		do_resample_copy_c, do_resample_full_avx, do_resample_inter_avx },
#endif
#if defined (HAVE_SSSE3)
	{ SPA_AUDIO_FORMAT_F32, SPA_CPU_FLAG_SSSE3 | SPA_CPU_FLAG_SLOW_UNALIGNED,
		do_resample_copy_c, do_resample_full_ssse3, do_resample_inter_ssse3 },
#endif
#if defined (HAVE_SSE)
	{ SPA_AUDIO_FORMAT_F32, SPA_CPU_FLAG_SSE,
		do_resample_copy_c, do_resample_full_sse, do_resample_inter_sse },
#endif
	{ SPA_AUDIO_FORMAT_F32, 0,
		do_resample_copy_c, do_resample_full_c, do_resample_inter_c },
};

#define MATCH_CPU_FLAGS(a,b)	((a) == 0 || ((a) & (b)) == a)
static const struct resample_info *find_resample_info(uint32_t format, uint32_t cpu_flags)
{
	size_t i;
	for (i = 0; i < SPA_N_ELEMENTS(resample_table); i++) {
		if (resample_table[i].format == format &&
		    MATCH_CPU_FLAGS(resample_table[i].cpu_flags, cpu_flags))
			return &resample_table[i];
	}
	return NULL;
}

static void impl_native_free(struct resample *r)
{
	spa_log_debug(r->log, "native %p: free", r);
	free(r->data);
	r->data = NULL;
}

static inline uint32_t calc_gcd(uint32_t a, uint32_t b)
{
	while (b != 0) {
		uint32_t temp = a;
		a = b;
		b = temp % b;
	}
	return a;
}

static void impl_native_update_rate(struct resample *r, double rate)
{
	struct native_data *data = r->data;
	uint32_t in_rate, out_rate, phase, gcd, old_out_rate;

	if (SPA_LIKELY(data->rate == rate))
		return;

	old_out_rate = data->out_rate;
	in_rate = r->i_rate / rate;
	out_rate = r->o_rate;
	phase = data->phase;

	gcd = calc_gcd(in_rate, out_rate);
	in_rate /= gcd;
	out_rate /= gcd;

	data->rate = rate;
	data->phase = phase * out_rate / old_out_rate;
	data->in_rate = in_rate;
	data->out_rate = out_rate;

	data->inc = data->in_rate / data->out_rate;
	data->frac = data->in_rate % data->out_rate;

	if (data->in_rate == data->out_rate)
		data->func = data->info->process_copy;
	else if (rate == 1.0)
		data->func = data->info->process_full;
	else
		data->func = data->info->process_inter;

	spa_log_trace_fp(r->log, "native %p: rate:%f in:%d out:%d phase:%d inc:%d frac:%d", r,
			rate, data->in_rate, data->out_rate, data->phase, data->inc, data->frac);

}

static uint32_t impl_native_in_len(struct resample *r, uint32_t out_len)
{
	struct native_data *data = r->data;
	uint32_t in_len;

	in_len = (data->phase + out_len * data->frac) / data->out_rate;
	in_len += out_len * data->inc +	(data->n_taps - data->hist);

	spa_log_trace_fp(r->log, "native %p: hist:%d %d->%d", r, data->hist, out_len, in_len);

	return in_len;
}

static void impl_native_process(struct resample *r,
		const void * SPA_RESTRICT src[], uint32_t *in_len,
		void * SPA_RESTRICT dst[], uint32_t *out_len)
{
	struct native_data *data = r->data;
	uint32_t n_taps = data->n_taps;
	float **history = data->history;
	const float **s = (const float **)src;
	uint32_t c, refill, hist, in, out, remain;

	hist = data->hist;
	refill = 0;

	if (SPA_LIKELY(hist)) {
		/* first work on the history if any. */
		if (SPA_UNLIKELY(hist <= n_taps)) {
			/* we need at least n_taps to completely process the
			 * history before we can work on the new input. When
			 * we have less, refill the history. */
			refill = SPA_MIN(*in_len, n_taps-1);
			for (c = 0; c < r->channels; c++)
				spa_memcpy(&history[c][hist], s[c], refill * sizeof(float));

			if (SPA_UNLIKELY(hist + refill < n_taps)) {
				/* not enough in the history, keep the input in
				 * the history and produce no output */
				data->hist = hist + refill;
				*in_len = refill;
				*out_len = 0;
				return;
			}
		}
		/* now we have at least n_taps of data in the history
		 * and we try to process it */
		in = hist + refill;
		out = *out_len;
		data->func(r, (const void**)history, 0, &in, dst, 0, &out);
		spa_log_trace_fp(r->log, "native %p: in:%d/%d out %d/%d hist:%d",
				r, hist + refill, in, *out_len, out, hist);
	} else {
		out = in = 0;
	}

	if (SPA_LIKELY(in >= hist)) {
		int skip = in - hist;
		/* we are past the history and can now work on the new
		 * input data */
		in = *in_len;
		data->func(r, src, skip, &in, dst, out, out_len);

		spa_log_trace_fp(r->log, "native %p: in:%d/%d out %d/%d",
				r, *in_len, in, *out_len, out);

		remain = *in_len - skip - in;
		if (remain > 0 && remain <= n_taps) {
			/* not enough input data remaining for more output,
			 * copy to history */
			for (c = 0; c < r->channels; c++)
				spa_memcpy(history[c], &s[c][in], remain * sizeof(float));
		} else {
			/* we have enough input data remaining to produce
			 * more output ask to resubmit. */
			remain = 0;
			*in_len = in;
		}
	} else {
		/* we are still working on the history */
		*out_len = out;
		remain = hist - in;
		if (*in_len < n_taps) {
			/* not enough input data, add it to the history because
			 * resubmitting it is not going to make progress.
			 * We copied this into the history above. */
			remain += refill;
		} else {
			/* input has enough data to possibly produce more output
			 * from the history so ask to resubmit */
			*in_len = 0;
		}
		if (remain) {
			/* move history */
			for (c = 0; c < r->channels; c++)
				spa_memmove(history[c], &history[c][in], remain * sizeof(float));
		}
		spa_log_trace_fp(r->log, "native %p: in:%d remain:%d", r, in, remain);

	}
	data->hist = remain;
	return;
}

static void impl_native_reset (struct resample *r)
{
	struct native_data *d = r->data;
	if (d == NULL)
		return;
	memset(d->hist_mem, 0, r->channels * sizeof(float) * d->n_taps * 2);
	d->hist = (d->n_taps / 2) - 1;
	d->phase = 0;
}

static uint32_t impl_native_delay (struct resample *r)
{
	struct native_data *d = r->data;
	return d->n_taps / 2;
}

int resample_native_init(struct resample *r)
{
	struct native_data *d;
	const struct quality *q;
	double scale;
	uint32_t c, n_taps, n_phases, filter_size, in_rate, out_rate, gcd, filter_stride;
	uint32_t history_stride, history_size, oversample;

	r->quality = SPA_CLAMP(r->quality, 0, (int) SPA_N_ELEMENTS(blackman_qualities) - 1);
	r->free = impl_native_free;
	r->update_rate = impl_native_update_rate;
	r->in_len = impl_native_in_len;
	r->process = impl_native_process;
	r->reset = impl_native_reset;
	r->delay = impl_native_delay;

	q = &blackman_qualities[r->quality];

	gcd = calc_gcd(r->i_rate, r->o_rate);

	in_rate = r->i_rate / gcd;
	out_rate = r->o_rate / gcd;

	scale = SPA_MIN(q->cutoff * out_rate / in_rate, 1.0);
	/* multiple of 8 taps to ease simd optimizations */
	n_taps = SPA_ROUND_UP_N((uint32_t)ceil(q->n_taps / scale), 8);

	/* try to get at least 256 phases so that interpolation is
	 * accurate enough when activated */
	n_phases = out_rate;
	oversample = (255 + n_phases) / n_phases;
	n_phases *= oversample;

	filter_stride = SPA_ROUND_UP_N(n_taps * sizeof(float), 64);
	filter_size = filter_stride * (n_phases + 1);
	history_stride = SPA_ROUND_UP_N(2 * n_taps * sizeof(float), 64);
	history_size = r->channels * history_stride;

	d = calloc(1, sizeof(struct native_data) +
			filter_size +
			history_size +
			(r->channels * sizeof(float*)) +
			64);

	if (d == NULL)
		return -errno;

	r->data = d;
	d->n_taps = n_taps;
	d->n_phases = n_phases;
	d->in_rate = in_rate;
	d->out_rate = out_rate;
	d->filter = SPA_MEMBER_ALIGN(d, sizeof(struct native_data), 64, float);
	d->hist_mem = SPA_MEMBER_ALIGN(d->filter, filter_size, 64, float);
	d->history = SPA_MEMBER(d->hist_mem, history_size, float*);
	d->filter_stride = filter_stride / sizeof(float);
	d->filter_stride_os = d->filter_stride * oversample;
	for (c = 0; c < r->channels; c++)
		d->history[c] = SPA_MEMBER(d->hist_mem, c * history_stride, float);

	build_filter(d->filter, d->filter_stride, n_taps, n_phases, scale);

	d->info = find_resample_info(SPA_AUDIO_FORMAT_F32, r->cpu_flags);

	spa_log_debug(r->log, "native %p: q:%d in:%d out:%d n_taps:%d n_phases:%d features:%08x:%08x",
			r, r->quality, in_rate, out_rate, n_taps, n_phases,
			r->cpu_flags, d->info->cpu_flags);

	r->cpu_flags = d->info->cpu_flags;

	impl_native_reset(r);
	impl_native_update_rate(r, 1.0);

	return 0;
}
