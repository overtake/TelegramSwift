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

#include <string.h>
#include <stdio.h>
#include <math.h>

#include <spa/support/cpu.h>
#include <spa/utils/defs.h>
#include <spa/param/audio/format-utils.h>

#include "fmt-ops.h"

typedef void (*convert_func_t) (struct convert *conv, void * SPA_RESTRICT dst[],
		const void * SPA_RESTRICT src[], uint32_t n_samples);

struct conv_info {
	uint32_t src_fmt;
	uint32_t dst_fmt;
	uint32_t n_channels;
	uint32_t cpu_flags;

	convert_func_t process;
};

static struct conv_info conv_table[] =
{
	/* to f32 */
	{ SPA_AUDIO_FORMAT_U8, SPA_AUDIO_FORMAT_F32, 0, 0, conv_u8_to_f32_c },
	{ SPA_AUDIO_FORMAT_U8P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_u8d_to_f32d_c },
	{ SPA_AUDIO_FORMAT_U8, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_u8_to_f32d_c },
	{ SPA_AUDIO_FORMAT_U8P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_u8d_to_f32_c },

	{ SPA_AUDIO_FORMAT_S8, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s8_to_f32_c },
	{ SPA_AUDIO_FORMAT_S8P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s8d_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S8, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s8_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S8P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s8d_to_f32_c },

	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s16_to_f32_c },
	{ SPA_AUDIO_FORMAT_S16P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s16d_to_f32d_c },
#if defined (HAVE_NEON)
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_NEON, conv_s16_to_f32d_neon },
#endif
#if defined (HAVE_AVX2)
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 2, SPA_CPU_FLAG_AVX2, conv_s16_to_f32d_2_avx2 },
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_AVX2, conv_s16_to_f32d_avx2 },
#endif
#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 2, SPA_CPU_FLAG_SSE2, conv_s16_to_f32d_2_sse2 },
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_SSE2, conv_s16_to_f32d_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s16_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S16P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s16d_to_f32_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_F32, 0, 0, conv_copy32_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_copy32d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_deinterleave_32_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_interleave_32_c },

#if defined (HAVE_AVX2)
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_AVX2, conv_s32_to_f32d_avx2 },
#endif
#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_SSE2, conv_s32_to_f32d_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s32_to_f32_c },
	{ SPA_AUDIO_FORMAT_S32P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s32d_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s32_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S32P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s32d_to_f32_c },

	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s24_to_f32_c },
	{ SPA_AUDIO_FORMAT_S24P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s24d_to_f32d_c },
#if defined (HAVE_AVX2)
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_AVX2, conv_s24_to_f32d_avx2 },
#endif
#if defined (HAVE_SSSE3)
//	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_SSSE3, conv_s24_to_f32d_ssse3 },
#endif
#if defined (HAVE_SSE41)
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_SSE41, conv_s24_to_f32d_sse41 },
#endif
#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32P, 0, SPA_CPU_FLAG_SSE2, conv_s24_to_f32d_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s24_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S24P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s24d_to_f32_c },

	{ SPA_AUDIO_FORMAT_S24_OE, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s24s_to_f32d_c },

	{ SPA_AUDIO_FORMAT_S24_32, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s24_32_to_f32_c },
	{ SPA_AUDIO_FORMAT_S24_32P, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s24_32d_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S24_32, SPA_AUDIO_FORMAT_F32P, 0, 0, conv_s24_32_to_f32d_c },
	{ SPA_AUDIO_FORMAT_S24_32P, SPA_AUDIO_FORMAT_F32, 0, 0, conv_s24_32d_to_f32_c },

	/* from f32 */
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_U8, 0, 0, conv_f32_to_u8_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_U8P, 0, 0, conv_f32d_to_u8d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_U8P, 0, 0, conv_f32_to_u8d_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_U8, 0, 0, conv_f32d_to_u8_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S8, 0, 0, conv_f32_to_s8_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S8P, 0, 0, conv_f32d_to_s8d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S8P, 0, 0, conv_f32_to_s8d_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S8, 0, 0, conv_f32d_to_s8_c },

#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S16, 0, SPA_CPU_FLAG_SSE2, conv_f32_to_s16_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S16, 0, 0, conv_f32_to_s16_c },

#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16P, 0, SPA_CPU_FLAG_SSE2, conv_f32d_to_s16d_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16P, 0, 0, conv_f32d_to_s16d_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S16P, 0, 0, conv_f32_to_s16d_c },

#if defined (HAVE_NEON)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 0, SPA_CPU_FLAG_NEON, conv_f32d_to_s16_neon },
#endif
#if defined (HAVE_AVX2)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 4, SPA_CPU_FLAG_AVX2, conv_f32d_to_s16_4_avx2 },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 2, SPA_CPU_FLAG_AVX2, conv_f32d_to_s16_2_avx2 },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 0, SPA_CPU_FLAG_AVX2, conv_f32d_to_s16_avx2 },
#endif
#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 2, SPA_CPU_FLAG_SSE2, conv_f32d_to_s16_2_sse2 },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 0, SPA_CPU_FLAG_SSE2, conv_f32d_to_s16_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S16, 0, 0, conv_f32d_to_s16_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S32, 0, 0, conv_f32_to_s32_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S32P, 0, 0, conv_f32d_to_s32d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S32P, 0, 0, conv_f32_to_s32d_c },
#if defined (HAVE_AVX2)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S32, 0, SPA_CPU_FLAG_AVX2, conv_f32d_to_s32_avx2 },
#endif
#if defined (HAVE_SSE2)
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S32, 0, SPA_CPU_FLAG_SSE2, conv_f32d_to_s32_sse2 },
#endif
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S32, 0, 0, conv_f32d_to_s32_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S24, 0, 0, conv_f32_to_s24_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S24P, 0, 0, conv_f32d_to_s24d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S24P, 0, 0, conv_f32_to_s24d_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S24, 0, 0, conv_f32d_to_s24_c },

	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S24_OE, 0, 0, conv_f32d_to_s24s_c },

	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S24_32, 0, 0, conv_f32_to_s24_32_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S24_32P, 0, 0, conv_f32d_to_s24_32d_c },
	{ SPA_AUDIO_FORMAT_F32, SPA_AUDIO_FORMAT_S24_32P, 0, 0, conv_f32_to_s24_32d_c },
	{ SPA_AUDIO_FORMAT_F32P, SPA_AUDIO_FORMAT_S24_32, 0, 0, conv_f32d_to_s24_32_c },

	/* u8 */
	{ SPA_AUDIO_FORMAT_U8, SPA_AUDIO_FORMAT_U8, 0, 0, conv_copy8_c },
	{ SPA_AUDIO_FORMAT_U8P, SPA_AUDIO_FORMAT_U8P, 0, 0, conv_copy8d_c },
	{ SPA_AUDIO_FORMAT_U8, SPA_AUDIO_FORMAT_U8P, 0, 0, conv_deinterleave_8_c },
	{ SPA_AUDIO_FORMAT_U8P, SPA_AUDIO_FORMAT_U8, 0, 0, conv_interleave_8_c },

	/* s8 */
	{ SPA_AUDIO_FORMAT_S8, SPA_AUDIO_FORMAT_S8, 0, 0, conv_copy8_c },
	{ SPA_AUDIO_FORMAT_S8P, SPA_AUDIO_FORMAT_S8P, 0, 0, conv_copy8d_c },
	{ SPA_AUDIO_FORMAT_S8, SPA_AUDIO_FORMAT_S8P, 0, 0, conv_deinterleave_8_c },
	{ SPA_AUDIO_FORMAT_S8P, SPA_AUDIO_FORMAT_S8, 0, 0, conv_interleave_8_c },

	/* s16 */
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_S16, 0, 0, conv_copy16_c },
	{ SPA_AUDIO_FORMAT_S16P, SPA_AUDIO_FORMAT_S16P, 0, 0, conv_copy16d_c },
	{ SPA_AUDIO_FORMAT_S16, SPA_AUDIO_FORMAT_S16P, 0, 0, conv_deinterleave_16_c },
	{ SPA_AUDIO_FORMAT_S16P, SPA_AUDIO_FORMAT_S16, 0, 0, conv_interleave_16_c },

	/* s32 */
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_S32, 0, 0, conv_copy32_c },
	{ SPA_AUDIO_FORMAT_S32P, SPA_AUDIO_FORMAT_S32P, 0, 0, conv_copy32d_c },
	{ SPA_AUDIO_FORMAT_S32, SPA_AUDIO_FORMAT_S32P, 0, 0, conv_deinterleave_32_c },
	{ SPA_AUDIO_FORMAT_S32P, SPA_AUDIO_FORMAT_S32, 0, 0, conv_interleave_32_c },

	/* s24 */
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_S24, 0, 0, conv_copy24_c },
	{ SPA_AUDIO_FORMAT_S24P, SPA_AUDIO_FORMAT_S24P, 0, 0, conv_copy24d_c },
	{ SPA_AUDIO_FORMAT_S24, SPA_AUDIO_FORMAT_S24P, 0, 0, conv_deinterleave_24_c },
	{ SPA_AUDIO_FORMAT_S24P, SPA_AUDIO_FORMAT_S24, 0, 0, conv_interleave_24_c },

	/* s24_32 */
	{ SPA_AUDIO_FORMAT_S24_32, SPA_AUDIO_FORMAT_S24_32, 0, 0, conv_copy32_c },
	{ SPA_AUDIO_FORMAT_S24_32P, SPA_AUDIO_FORMAT_S24_32P, 0, 0, conv_copy32d_c },
	{ SPA_AUDIO_FORMAT_S24_32, SPA_AUDIO_FORMAT_S24_32P, 0, 0, conv_deinterleave_32_c },
	{ SPA_AUDIO_FORMAT_S24_32P, SPA_AUDIO_FORMAT_S24_32, 0, 0, conv_interleave_32_c },
};

#define MATCH_CHAN(a,b)		((a) == 0 || (a) == (b))
#define MATCH_CPU_FLAGS(a,b)	((a) == 0 || ((a) & (b)) == a)

static const struct conv_info *find_conv_info(uint32_t src_fmt, uint32_t dst_fmt,
		uint32_t n_channels, uint32_t cpu_flags)
{
	size_t i;

	for (i = 0; i < SPA_N_ELEMENTS(conv_table); i++) {
		if (conv_table[i].src_fmt == src_fmt &&
		    conv_table[i].dst_fmt == dst_fmt &&
		    MATCH_CHAN(conv_table[i].n_channels, n_channels) &&
		    MATCH_CPU_FLAGS(conv_table[i].cpu_flags, cpu_flags))
			return &conv_table[i];
	}
	return NULL;
}

static void impl_convert_free(struct convert *conv)
{
	conv->process = NULL;
}

int convert_init(struct convert *conv)
{
	const struct conv_info *info;

	info = find_conv_info(conv->src_fmt, conv->dst_fmt, conv->n_channels, conv->cpu_flags);
	if (info == NULL)
		return -ENOTSUP;

	conv->is_passthrough = conv->src_fmt == conv->dst_fmt;
	conv->cpu_flags = info->cpu_flags;
	conv->process = info->process;
	conv->free = impl_convert_free;

	return 0;
}
