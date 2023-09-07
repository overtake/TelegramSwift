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

#include <spa/utils/defs.h>

struct mix_ops {
	uint32_t fmt;
	uint32_t n_channels;
	uint32_t cpu_flags;

	void (*clear) (struct mix_ops *ops, void * SPA_RESTRICT dst, uint32_t n_samples);
	void (*process) (struct mix_ops *ops,
			void * SPA_RESTRICT dst,
			const void * SPA_RESTRICT src[], uint32_t n_src,
			uint32_t n_samples);
	void (*free) (struct mix_ops *ops);

	const void *priv;
};

int mix_ops_init(struct mix_ops *ops);

#define mix_ops_clear(ops,...)		(ops)->clear(ops, __VA_ARGS__)
#define mix_ops_process(ops,...)	(ops)->process(ops, __VA_ARGS__)
#define mix_ops_free(ops)		(ops)->free(ops)

#define DEFINE_FUNCTION(name,arch) \
void mix_##name##_##arch(struct mix_ops *ops, void * SPA_RESTRICT dst,	\
		const void * SPA_RESTRICT src[], uint32_t n_src,		\
		uint32_t n_samples)						\

DEFINE_FUNCTION(f32, c);
DEFINE_FUNCTION(f64, c);

#if defined(HAVE_SSE)
DEFINE_FUNCTION(f32, sse);
#endif
#if defined(HAVE_SSE2)
DEFINE_FUNCTION(f64, sse2);
#endif
#if defined(HAVE_AVX)
DEFINE_FUNCTION(f32, avx);
#endif
