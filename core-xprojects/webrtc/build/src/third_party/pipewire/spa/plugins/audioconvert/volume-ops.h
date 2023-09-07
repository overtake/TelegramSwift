/* Spa
 *
 * Copyright © 2021 Wim Taymans
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

#include <spa/utils/defs.h>
#include <spa/param/audio/raw.h>

#define VOLUME_MIN 0.0f
#define VOLUME_NORM 1.0f

struct volume {
	uint32_t cpu_flags;

	struct spa_log *log;

	uint32_t flags;

	void (*process) (struct volume *vol, void * SPA_RESTRICT dst,
			const void * SPA_RESTRICT src, float volume, uint32_t n_samples);
	void (*free) (struct volume *vol);

	void *data;
};

int volume_init(struct volume *vol);

#define volume_process(vol,...)		(vol)->process(vol, __VA_ARGS__)
#define volume_free(vol)		(vol)->free(vol)

#define DEFINE_FUNCTION(name,arch)			\
void volume_##name##_##arch(struct volume *vol,		\
		void * SPA_RESTRICT dst,		\
		const void * SPA_RESTRICT src,		\
		float volume, uint32_t n_samples);

DEFINE_FUNCTION(f32, c);

#if defined (HAVE_SSE)
DEFINE_FUNCTION(f32, sse);
#endif

#undef DEFINE_FUNCTION
