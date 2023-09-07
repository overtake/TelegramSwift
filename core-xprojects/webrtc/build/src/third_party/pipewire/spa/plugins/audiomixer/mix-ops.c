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

#include <spa/support/cpu.h>
#include <spa/utils/defs.h>
#include <spa/param/audio/format-utils.h>

#include "mix-ops.h"

typedef void (*mix_func_t) (struct mix_ops *ops, void * SPA_RESTRICT dst,
		const void * SPA_RESTRICT src[], uint32_t n_src, uint32_t n_samples);

struct mix_info {
	uint32_t fmt;
	uint32_t n_channels;
	uint32_t cpu_flags;
	uint32_t stride;
	mix_func_t process;
};

static struct mix_info mix_table[] =
{
	/* f32 */
#if defined(HAVE_AVX)
	{ SPA_AUDIO_FORMAT_F32, 1, SPA_CPU_FLAG_AVX, 4, mix_f32_avx },
	{ SPA_AUDIO_FORMAT_F32P, 1, SPA_CPU_FLAG_AVX, 4, mix_f32_avx },
#endif
#if defined (HAVE_SSE)
	{ SPA_AUDIO_FORMAT_F32, 1, SPA_CPU_FLAG_SSE, 4, mix_f32_sse },
	{ SPA_AUDIO_FORMAT_F32P, 1, SPA_CPU_FLAG_SSE, 4, mix_f32_sse },
#endif
	{ SPA_AUDIO_FORMAT_F32, 1, 0, 4, mix_f32_c },
	{ SPA_AUDIO_FORMAT_F32P, 1, 0, 4, mix_f32_c },

#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_F64, 1, SPA_CPU_FLAG_SSE2, 8, mix_f64_sse2 },
	{ SPA_AUDIO_FORMAT_F64P, 1, SPA_CPU_FLAG_SSE2, 8, mix_f64_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_F64, 1, 0, 8, mix_f64_c },
	{ SPA_AUDIO_FORMAT_F64P, 1, 0, 8, mix_f64_c },
};

#define MATCH_CHAN(a,b)		((a) == 0 || (a) == (b))
#define MATCH_CPU_FLAGS(a,b)	((a) == 0 || ((a) & (b)) == a)

static const struct mix_info *find_mix_info(uint32_t fmt,
		uint32_t n_channels, uint32_t cpu_flags)
{
	size_t i;

	for (i = 0; i < SPA_N_ELEMENTS(mix_table); i++) {
		if (mix_table[i].fmt == fmt &&
		    MATCH_CHAN(mix_table[i].n_channels, n_channels) &&
		    MATCH_CPU_FLAGS(mix_table[i].cpu_flags, cpu_flags))
			return &mix_table[i];
	}
	return NULL;
}

static void impl_mix_ops_clear(struct mix_ops *ops, void * SPA_RESTRICT dst, uint32_t n_samples)
{
	const struct mix_info *info = ops->priv;
	memset(dst, 0, n_samples * info->stride);
}

static void impl_mix_ops_free(struct mix_ops *ops)
{
	spa_zero(*ops);
}

int mix_ops_init(struct mix_ops *ops)
{
	const struct mix_info *info;

	info = find_mix_info(ops->fmt, ops->n_channels, ops->cpu_flags);
	if (info == NULL)
		return -ENOTSUP;

	ops->priv = info;
	ops->cpu_flags = info->cpu_flags;
	ops->clear = impl_mix_ops_clear;
	ops->process = info->process;
	ops->free = impl_mix_ops_free;

	return 0;
}
