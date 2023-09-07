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

#include <math.h>

#define M_PI_M2 ( M_PI + M_PI )

#define DEFINE_SINE(type,scale)								\
static void										\
audio_test_src_create_sine_##type (struct impl *this, type *samples, size_t n_samples)	\
{											\
	size_t i;									\
	uint32_t c, channels;								\
	float step, amp;								\
	float freq = this->props.freq;							\
	float volume = this->props.volume;						\
											\
	channels = this->port.current_format.info.raw.channels;				\
	step = M_PI_M2 * freq / this->port.current_format.info.raw.rate;		\
	amp = volume * scale;								\
											\
	for (i = 0; i < n_samples; i++) {						\
		type val;								\
		this->port.accumulator += step;						\
		if (this->port.accumulator >= M_PI_M2)					\
			this->port.accumulator -= M_PI_M2;				\
		val = (type) (sin (this->port.accumulator) * amp);			\
		for (c = 0; c < channels; ++c)						\
			*samples++ = val;						\
	}										\
}

DEFINE_SINE(int16_t, 32767.0);
DEFINE_SINE(int32_t, 2147483647.0);
DEFINE_SINE(float, 1.0);
DEFINE_SINE(double, 1.0);

static const render_func_t sine_funcs[] = {
	(render_func_t) audio_test_src_create_sine_int16_t,
	(render_func_t) audio_test_src_create_sine_int32_t,
	(render_func_t) audio_test_src_create_sine_float,
	(render_func_t) audio_test_src_create_sine_double
};
