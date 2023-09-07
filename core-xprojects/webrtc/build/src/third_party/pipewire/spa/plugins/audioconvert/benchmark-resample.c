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

#include "config.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#include "test-helper.h"
#include "resample.h"

#define MAX_SAMPLES	4096
#define MAX_CHANNELS	11

#define MAX_COUNT 200

static uint32_t cpu_flags;

struct stats {
	uint32_t in_rate;
	uint32_t out_rate;
	uint32_t n_samples;
	uint32_t n_channels;
	uint64_t perf;
	const char *name;
	const char *impl;
};

static float samp_in[MAX_SAMPLES * MAX_CHANNELS];
static float samp_out[MAX_SAMPLES * MAX_CHANNELS];

static const int sample_sizes[] = { 0, 1, 128, 513, 4096 };
static const int in_rates[] = { 44100, 44100, 48000, 96000, 22050, 96000 };
static const int out_rates[] = { 44100, 48000, 44100, 48000, 48000, 44100 };


#define MAX_RESAMPLER	5
#define MAX_SIZES	SPA_N_ELEMENTS(sample_sizes)
#define MAX_RATES	SPA_N_ELEMENTS(in_rates)
#define MAX_RESULTS	MAX_RESAMPLER * MAX_SIZES * MAX_RATES

static uint32_t n_results = 0;
static struct stats results[MAX_RESULTS];

static void run_test1(const char *name, const char *impl, struct resample *r, int n_samples)
{
	uint32_t i, j;
	const void *ip[MAX_CHANNELS];
	void *op[MAX_CHANNELS];
	struct timespec ts;
	uint64_t count, t1, t2;
	uint32_t in_len, out_len;

	for (j = 0; j < r->channels; j++) {
		ip[j] = &samp_in[j * MAX_SAMPLES];
		op[j] = &samp_out[j * MAX_SAMPLES];
	}

	clock_gettime(CLOCK_MONOTONIC, &ts);
	t1 = SPA_TIMESPEC_TO_NSEC(&ts);

	count = 0;
	for (i = 0; i < MAX_COUNT; i++) {
		in_len = n_samples;
		out_len = MAX_SAMPLES;
		resample_process(r, ip, &in_len, op, &out_len);
		count++;
	}
	clock_gettime(CLOCK_MONOTONIC, &ts);
	t2 = SPA_TIMESPEC_TO_NSEC(&ts);

	spa_assert(n_results < MAX_RESULTS);

	results[n_results++] = (struct stats) {
		.in_rate = r->i_rate,
		.out_rate = r->o_rate,
		.n_samples = n_samples,
		.n_channels = r->channels,
		.perf = count * (uint64_t)SPA_NSEC_PER_SEC / (t2 - t1),
		.name = name,
		.impl = impl
	};
}

static void run_test(const char *name, const char *impl, struct resample *r)
{
	size_t i;
	for (i = 0; i < SPA_N_ELEMENTS(sample_sizes); i++)
		run_test1(name, impl, r, sample_sizes[i]);
}

static int compare_func(const void *_a, const void *_b)
{
	const struct stats *a = _a, *b = _b;
	int diff;

	if ((diff = a->in_rate - b->in_rate) != 0) return diff;
	if ((diff = a->out_rate - b->out_rate) != 0) return diff;
	if ((diff = a->n_samples - b->n_samples) != 0) return diff;
	if ((diff = a->n_channels - b->n_channels) != 0) return diff;
	if ((diff = b->perf - a->perf) != 0) return diff;
	return 0;
}

int main(int argc, char *argv[])
{
	struct resample r;
	uint32_t i;

	cpu_flags = get_cpu_flags();
	printf("got get CPU flags %d\n", cpu_flags);

	for (i = 0; i < SPA_N_ELEMENTS(in_rates); i++) {
		spa_zero(r);
		r.channels = 2;
		r.cpu_flags = 0;
		r.i_rate = in_rates[i];
		r.o_rate = out_rates[i];
		r.quality = RESAMPLE_DEFAULT_QUALITY;
		resample_native_init(&r);
		run_test("native", "c", &r);
		resample_free(&r);
	}
#if defined (HAVE_SSE)
	if (cpu_flags & SPA_CPU_FLAG_SSE) {
		for (i = 0; i < SPA_N_ELEMENTS(in_rates); i++) {
			spa_zero(r);
			r.channels = 2;
			r.cpu_flags = SPA_CPU_FLAG_SSE;
			r.i_rate = in_rates[i];
			r.o_rate = out_rates[i];
			r.quality = RESAMPLE_DEFAULT_QUALITY;
			resample_native_init(&r);
			run_test("native", "sse", &r);
			resample_free(&r);
		}
	}
#endif
#if defined (HAVE_SSSE3)
	if (cpu_flags & SPA_CPU_FLAG_SSSE3) {
		for (i = 0; i < SPA_N_ELEMENTS(in_rates); i++) {
			spa_zero(r);
			r.channels = 2;
			r.cpu_flags = SPA_CPU_FLAG_SSSE3 | SPA_CPU_FLAG_SLOW_UNALIGNED;
			r.i_rate = in_rates[i];
			r.o_rate = out_rates[i];
			r.quality = RESAMPLE_DEFAULT_QUALITY;
			resample_native_init(&r);
			run_test("native", "ssse3", &r);
			resample_free(&r);
		}
	}
#endif
#if defined (HAVE_AVX) && defined(HAVE_FMA)
	if (SPA_FLAG_IS_SET(cpu_flags, SPA_CPU_FLAG_AVX | SPA_CPU_FLAG_FMA3)) {
		for (i = 0; i < SPA_N_ELEMENTS(in_rates); i++) {
			spa_zero(r);
			r.channels = 2;
			r.cpu_flags = SPA_CPU_FLAG_AVX | SPA_CPU_FLAG_FMA3;
			r.i_rate = in_rates[i];
			r.o_rate = out_rates[i];
			r.quality = RESAMPLE_DEFAULT_QUALITY;
			resample_native_init(&r);
			run_test("native", "avx", &r);
			resample_free(&r);
		}
	}
#endif

	qsort(results, n_results, sizeof(struct stats), compare_func);

	for (i = 0; i < n_results; i++) {
		struct stats *s = &results[i];
		fprintf(stderr, "%-12."PRIu64" \t%-16.16s %s \t%d->%d samples %d, channels %d\n",
				s->perf, s->name, s->impl, s->in_rate, s->out_rate,
				s->n_samples, s->n_channels);
	}
	return 0;
}
