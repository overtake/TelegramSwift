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

void
conv_copy8d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	for (i = 0; i < n_channels; i++)
		spa_memcpy(dst[i], src[i], n_samples);
}

void
conv_copy8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	spa_memcpy(dst[0], src[0], n_samples * conv->n_channels);
}


void
conv_copy16d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	for (i = 0; i < n_channels; i++)
		spa_memcpy(dst[i], src[i], n_samples * sizeof(int16_t));
}

void
conv_copy16_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	spa_memcpy(dst[0], src[0], n_samples * sizeof(int16_t) * conv->n_channels);
}

void
conv_copy24d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	for (i = 0; i < n_channels; i++)
		spa_memcpy(dst[i], src[i], n_samples * 3);
}

void
conv_copy24_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	spa_memcpy(dst[0], src[0], n_samples * 3 * conv->n_channels);
}

void
conv_copy32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	for (i = 0; i < n_channels; i++)
		spa_memcpy(dst[i], src[i], n_samples * sizeof(int32_t));
}

void
conv_copy32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	spa_memcpy(dst[0], src[0], n_samples * sizeof(int32_t) * conv->n_channels);
}

void
conv_u8d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const uint8_t *s = src[i];
		float *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = U8_TO_F32(s[j]);
	}
}

void
conv_u8_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;;
	const uint8_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = U8_TO_F32(s[i]);
}

void
conv_u8_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = U8_TO_F32(*s++);
	}
}

void
conv_u8d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t **s = (const uint8_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = U8_TO_F32(s[i][j]);
	}
}

void
conv_s8d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const int8_t *s = src[i];
		float *d = dst[i];
		for (j = 0; j < n_samples; j++)
			d[j] = S8_TO_F32(s[j]);
	}
}

void
conv_s8_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const int8_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = S8_TO_F32(s[i]);
}

void
conv_s8_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = S8_TO_F32(*s++);
	}
}

void
conv_s8d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t **s = (const int8_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = S8_TO_F32(s[i][j]);
	}
}

void
conv_s16d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const int16_t *s = src[i];
		float *d = dst[i];
		for (j = 0; j < n_samples; j++)
			d[j] = S16_TO_F32(s[j]);
	}
}

void
conv_s16_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const int16_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = S16_TO_F32(s[i]);
}

void
conv_s16_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int16_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = S16_TO_F32(*s++);
	}
}

void
conv_s16d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int16_t **s = (const int16_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = S16_TO_F32(s[i][j]);
	}
}

void
conv_s32d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const int32_t *s = src[i];
		float *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = S32_TO_F32(s[j]);
	}
}

void
conv_s32_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const int32_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = S32_TO_F32(s[i]);
}

void
conv_s32_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = S32_TO_F32(*s++);
	}
}

void
conv_s32d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t **s = (const int32_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = S32_TO_F32(s[i][j]);
	}
}

void
conv_s24d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const int8_t *s = src[i];
		float *d = dst[i];

		for (j = 0; j < n_samples; j++) {
			d[j] = S24_TO_F32(read_s24(s));
			s += 3;
		}
	}
}

void
conv_s24_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const int8_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++) {
		d[i] = S24_TO_F32(read_s24(s));
		s += 3;
	}
}

void
conv_s24_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			d[i][j] = S24_TO_F32(read_s24(s));
			s += 3;
		}
	}
}

void
conv_s24s_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			d[i][j] = S24_TO_F32(read_s24s(s));
			s += 3;
		}
	}
}

void
conv_s24d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t **s = (const uint8_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			*d++ = S24_TO_F32(read_s24(&s[i][j*3]));
		}
	}
}

void
conv_s24_32d_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const int32_t *s = src[i];
		float *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = S24_TO_F32(s[j]);
	}
}

void
conv_s24_32_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const int32_t *s = src[0];
	float *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = S24_TO_F32(s[i]);
}

void
conv_s24_32_to_f32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t *s = src[0];
	float **d = (float **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = S24_TO_F32(*s++);
	}
}

void
conv_s24_32d_to_f32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t **s = (const int32_t **) src;
	float *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = S24_TO_F32(s[i][j]);
	}
}

void
conv_f32d_to_u8d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		uint8_t *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = F32_TO_U8(s[j]);
	}
}

void
conv_f32_to_u8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	uint8_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = F32_TO_U8(s[i]);
}

void
conv_f32_to_u8d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	uint8_t **d = (uint8_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = F32_TO_U8(*s++);
	}
}

void
conv_f32d_to_u8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	uint8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = F32_TO_U8(s[i][j]);
	}
}

void
conv_f32d_to_s8d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		int8_t *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = F32_TO_S8(s[j]);
	}
}

void
conv_f32_to_s8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	int8_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = F32_TO_S8(s[i]);
}

void
conv_f32_to_s8d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	int8_t **d = (int8_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = F32_TO_S8(*s++);
	}
}

void
conv_f32d_to_s8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	int8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = F32_TO_S8(s[i][j]);
	}
}

void
conv_f32d_to_s16d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		int16_t *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = F32_TO_S16(s[j]);
	}
}

void
conv_f32_to_s16_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	int16_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = F32_TO_S16(s[i]);
}

void
conv_f32_to_s16d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	int16_t **d = (int16_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = F32_TO_S16(*s++);
	}
}

void
conv_f32d_to_s16_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	int16_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = F32_TO_S16(s[i][j]);
	}
}

void
conv_f32d_to_s32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		int32_t *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = F32_TO_S32(s[j]);
	}
}

void
conv_f32_to_s32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	int32_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = F32_TO_S32(s[i]);
}

void
conv_f32_to_s32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	int32_t **d = (int32_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = F32_TO_S32(*s++);
	}
}

void
conv_f32d_to_s32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	int32_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = F32_TO_S32(s[i][j]);
	}
}



void
conv_f32d_to_s24d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		uint8_t *d = dst[i];

		for (j = 0; j < n_samples; j++) {
			write_s24(d, F32_TO_S24(s[j]));
			d += 3;
		}
	}
}

void
conv_f32_to_s24_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	uint8_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++) {
		write_s24(d, F32_TO_S24(s[i]));
		d += 3;
	}
}

void
conv_f32_to_s24d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	uint8_t **d = (uint8_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			write_s24(&d[i][j*3], F32_TO_S24(*s++));
		}
	}
}

void
conv_f32d_to_s24_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	uint8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			write_s24(d, F32_TO_S24(s[i][j]));
			d += 3;
		}
	}
}

void
conv_f32d_to_s24s_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	uint8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			write_s24s(d, F32_TO_S24(s[i][j]));
			d += 3;
		}
	}
}


void
conv_f32d_to_s24_32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, j, n_channels = conv->n_channels;

	for (i = 0; i < n_channels; i++) {
		const float *s = src[i];
		int32_t *d = dst[i];

		for (j = 0; j < n_samples; j++)
			d[j] = F32_TO_S24(s[j]);
	}
}

void
conv_f32_to_s24_32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	uint32_t i, n_channels = conv->n_channels;
	const float *s = src[0];
	int32_t *d = dst[0];

	n_samples *= n_channels;

	for (i = 0; i < n_samples; i++)
		d[i] = F32_TO_S24(s[i]);
}

void
conv_f32_to_s24_32d_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float *s = src[0];
	int32_t **d = (int32_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = F32_TO_S24(*s++);
	}
}

void
conv_f32d_to_s24_32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const float **s = (const float **) src;
	int32_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = F32_TO_S24(s[i][j]);
	}
}

void
conv_deinterleave_8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t *s = src[0];
	uint8_t **d = (uint8_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = *s++;
	}
}

void
conv_deinterleave_16_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint16_t *s = src[0];
	uint16_t **d = (uint16_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = *s++;
	}
}

void
conv_deinterleave_24_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint8_t *s = src[0];
	uint8_t **d = (uint8_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			write_s24(&d[i][j*3], read_s24(s));
			s += 3;
		}
	}
}

void
conv_deinterleave_32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const uint32_t *s = src[0];
	uint32_t **d = (uint32_t **) dst;
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			d[i][j] = *s++;
	}
}

void
conv_interleave_8_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t **s = (const int8_t **) src;
	uint8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = s[i][j];
	}
}

void
conv_interleave_16_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int16_t **s = (const int16_t **) src;
	uint16_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = s[i][j];
	}
}

void
conv_interleave_24_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int8_t **s = (const int8_t **) src;
	uint8_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++) {
			write_s24(d, read_s24(&s[i][j*3]));
			d += 3;
		}
	}
}

void
conv_interleave_32_c(struct convert *conv, void * SPA_RESTRICT dst[], const void * SPA_RESTRICT src[],
		uint32_t n_samples)
{
	const int32_t **s = (const int32_t **) src;
	uint32_t *d = dst[0];
	uint32_t i, j, n_channels = conv->n_channels;

	for (j = 0; j < n_samples; j++) {
		for (i = 0; i < n_channels; i++)
			*d++ = s[i][j];
	}
}
