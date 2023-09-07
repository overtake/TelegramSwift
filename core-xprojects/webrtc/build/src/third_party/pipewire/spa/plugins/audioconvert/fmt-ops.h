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

#define U8_MIN		0
#define U8_MAX		255
#define U8_SCALE	127.5f
#define U8_OFFS		128
#define U8_TO_F32(v)	((((uint8_t)(v)) * (1.0f / U8_OFFS)) - 1.0)
#define F32_TO_U8(v)	(uint8_t)((SPA_CLAMP(v, -1.0f, 1.0f) * U8_SCALE) + U8_OFFS)

#define S8_MIN		-127
#define S8_MAX		127
#define S8_MAX_F	127.0f
#define S8_SCALE	127.0f
#define S8_TO_F32(v)	(((int8_t)(v)) * (1.0f / S8_SCALE))
#define F32_TO_S8(v)	(int8_t)(SPA_CLAMP(v, -1.0f, 1.0f) * S8_SCALE)

#define S16_MIN		-32767
#define S16_MAX		32767
#define S16_MAX_F	32767.0f
#define S16_SCALE	32767.0f
#define S16_TO_F32(v)	(((int16_t)(v)) * (1.0f / S16_SCALE))
#define F32_TO_S16(v)	(int16_t)(SPA_CLAMP(v, -1.0f, 1.0f) * S16_SCALE)

#define S24_MIN		-8388607
#define S24_MAX		8388607
#define S24_MAX_F	8388607.0f
#define S24_SCALE	8388607.0f
#define S24_TO_F32(v)	(((int32_t)(v)) * (1.0f / S24_SCALE))
#define F32_TO_S24(v)	(int32_t)(SPA_CLAMP(v, -1.0f, 1.0f) * S24_SCALE)

#define S32_SCALE	2147483648.0f
#define S32_MIN		2147483520.0f

#define S32_TO_F32(v)	S24_TO_F32((v) >> 8)
#define F32_TO_S32(v)	(F32_TO_S24(v) << 8)

static inline int32_t read_s24(const void *src)
{
	const int8_t *s = src;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	return (((int32_t)s[2] << 16) | ((uint32_t)(uint8_t)s[1] << 8) | (uint32_t)(uint8_t)s[0]);
#else
	return (((int32_t)s[0] << 16) | ((uint32_t)(uint8_t)s[1] << 8) | (uint32_t)(uint8_t)s[2]);
#endif
}

static inline int32_t read_s24s(const void *src)
{
	const int8_t *s = src;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	return (((int32_t)s[0] << 16) | ((uint32_t)(uint8_t)s[1] << 8) | (uint32_t)(uint8_t)s[2]);
#else
	return (((int32_t)s[2] << 16) | ((uint32_t)(uint8_t)s[1] << 8) | (uint32_t)(uint8_t)s[0]);
#endif
}

static inline void write_s24(void *dst, int32_t val)
{
	uint8_t *d = dst;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	d[0] = (uint8_t) (val);
	d[1] = (uint8_t) (val >> 8);
	d[2] = (uint8_t) (val >> 16);
#else
	d[0] = (uint8_t) (val >> 16);
	d[1] = (uint8_t) (val >> 8);
	d[2] = (uint8_t) (val);
#endif
}

static inline void write_s24s(void *dst, int32_t val)
{
	uint8_t *d = dst;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	d[0] = (uint8_t) (val >> 16);
	d[1] = (uint8_t) (val >> 8);
	d[2] = (uint8_t) (val);
#else
	d[0] = (uint8_t) (val);
	d[1] = (uint8_t) (val >> 8);
	d[2] = (uint8_t) (val >> 16);
#endif
}

#define MAX_NS	64

struct convert {
	uint32_t src_fmt;
	uint32_t dst_fmt;
	uint32_t n_channels;
	uint32_t cpu_flags;

	unsigned int is_passthrough:1;
	float ns_data[MAX_NS];
	uint32_t ns_idx;
	uint32_t ns_size;

	void (*process) (struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
			uint32_t n_samples);
	void (*free) (struct convert *conv);
};

int convert_init(struct convert *conv);

#define convert_process(conv,...)	(conv)->process(conv, __VA_ARGS__)
#define convert_free(conv)		(conv)->free(conv)

#define DEFINE_FUNCTION(name,arch) \
void conv_##name##_##arch(struct convert *conv, void * SPA_RESTRICT dst[],	\
		const void * SPA_RESTRICT src[], uint32_t n_samples)		\

DEFINE_FUNCTION(copy8d, c);
DEFINE_FUNCTION(copy8, c);
DEFINE_FUNCTION(copy16d, c);
DEFINE_FUNCTION(copy16, c);
DEFINE_FUNCTION(copy24d, c);
DEFINE_FUNCTION(copy24, c);
DEFINE_FUNCTION(copy32d, c);
DEFINE_FUNCTION(copy32, c);
DEFINE_FUNCTION(u8d_to_f32d, c);
DEFINE_FUNCTION(u8_to_f32, c);
DEFINE_FUNCTION(u8_to_f32d, c);
DEFINE_FUNCTION(u8d_to_f32, c);
DEFINE_FUNCTION(s8d_to_f32d, c);
DEFINE_FUNCTION(s8_to_f32, c);
DEFINE_FUNCTION(s8_to_f32d, c);
DEFINE_FUNCTION(s8d_to_f32, c);
DEFINE_FUNCTION(s16d_to_f32d, c);
DEFINE_FUNCTION(s16_to_f32, c);
DEFINE_FUNCTION(s16_to_f32d, c);
DEFINE_FUNCTION(s16d_to_f32, c);
DEFINE_FUNCTION(s32d_to_f32d, c);
DEFINE_FUNCTION(s32_to_f32, c);
DEFINE_FUNCTION(s32_to_f32d, c);
DEFINE_FUNCTION(s32d_to_f32, c);
DEFINE_FUNCTION(s24d_to_f32d, c);
DEFINE_FUNCTION(s24_to_f32, c);
DEFINE_FUNCTION(s24_to_f32d, c);
DEFINE_FUNCTION(s24s_to_f32d, c);
DEFINE_FUNCTION(s24d_to_f32, c);
DEFINE_FUNCTION(s24_32d_to_f32d, c);
DEFINE_FUNCTION(s24_32_to_f32, c);
DEFINE_FUNCTION(s24_32_to_f32d, c);
DEFINE_FUNCTION(s24_32d_to_f32, c);
DEFINE_FUNCTION(f32d_to_u8d, c);
DEFINE_FUNCTION(f32_to_u8, c);
DEFINE_FUNCTION(f32_to_u8d, c);
DEFINE_FUNCTION(f32d_to_u8, c);
DEFINE_FUNCTION(f32d_to_s8d, c);
DEFINE_FUNCTION(f32_to_s8, c);
DEFINE_FUNCTION(f32_to_s8d, c);
DEFINE_FUNCTION(f32d_to_s8, c);
DEFINE_FUNCTION(f32d_to_s16d, c);
DEFINE_FUNCTION(f32_to_s16, c);
DEFINE_FUNCTION(f32_to_s16d, c);
DEFINE_FUNCTION(f32d_to_s16, c);
DEFINE_FUNCTION(f32d_to_s32d, c);
DEFINE_FUNCTION(f32_to_s32, c);
DEFINE_FUNCTION(f32_to_s32d, c);
DEFINE_FUNCTION(f32d_to_s32, c);
DEFINE_FUNCTION(f32d_to_s24d, c);
DEFINE_FUNCTION(f32_to_s24, c);
DEFINE_FUNCTION(f32_to_s24d, c);
DEFINE_FUNCTION(f32d_to_s24, c);
DEFINE_FUNCTION(f32d_to_s24s, c);
DEFINE_FUNCTION(f32d_to_s24_32d, c);
DEFINE_FUNCTION(f32_to_s24_32, c);
DEFINE_FUNCTION(f32_to_s24_32d, c);
DEFINE_FUNCTION(f32d_to_s24_32, c);
DEFINE_FUNCTION(deinterleave_8, c);
DEFINE_FUNCTION(deinterleave_16, c);
DEFINE_FUNCTION(deinterleave_24, c);
DEFINE_FUNCTION(deinterleave_32, c);
DEFINE_FUNCTION(interleave_8, c);
DEFINE_FUNCTION(interleave_16, c);
DEFINE_FUNCTION(interleave_24, c);
DEFINE_FUNCTION(interleave_32, c);

#if defined(HAVE_NEON)
DEFINE_FUNCTION(s16_to_f32d, neon);
DEFINE_FUNCTION(f32d_to_s16, neon);
#endif
#if defined(HAVE_SSE2)
DEFINE_FUNCTION(s16_to_f32d_2, sse2);
DEFINE_FUNCTION(s16_to_f32d, sse2);
DEFINE_FUNCTION(s24_to_f32d, sse2);
DEFINE_FUNCTION(s32_to_f32d, sse2);
DEFINE_FUNCTION(f32d_to_s32, sse2);
DEFINE_FUNCTION(f32_to_s16, sse2);
DEFINE_FUNCTION(f32d_to_s16_2, sse2);
DEFINE_FUNCTION(f32d_to_s16, sse2);
DEFINE_FUNCTION(f32d_to_s16d, sse2);
#endif
#if defined(HAVE_SSSE3)
DEFINE_FUNCTION(s24_to_f32d, ssse3);
#endif
#if defined(HAVE_SSE41)
DEFINE_FUNCTION(s24_to_f32d, sse41);
#endif
#if defined(HAVE_AVX2)
DEFINE_FUNCTION(s16_to_f32d_2, avx2);
DEFINE_FUNCTION(s16_to_f32d, avx2);
DEFINE_FUNCTION(s24_to_f32d, avx2);
DEFINE_FUNCTION(s32_to_f32d, avx2);
DEFINE_FUNCTION(f32d_to_s32, avx2);
DEFINE_FUNCTION(f32d_to_s16_4, avx2);
DEFINE_FUNCTION(f32d_to_s16_2, avx2);
DEFINE_FUNCTION(f32d_to_s16, avx2);
#endif

#undef DEFINE_FUNCTION
