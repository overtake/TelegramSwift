/* PipeWire
 *
 * Copyright © 2021 Wim Taymans <wim.taymans@gmail.com>
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

#include <spa/utils/dict.h>
#include <spa/param/audio/raw.h>

struct echo_cancel_info {
	const char *name;
	const struct spa_dict info;

	void *(*create) (struct spa_dict *info, uint32_t channels);
	void (*destroy) (void *ec);

	int (*run) (void *ec, const float *rec[], const float *play[], float *out[], uint32_t n_samples);
};

#define echo_cancel_create(i,...)	(i)->create(__VA_ARGS__)
#define echo_cancel_destroy(i,...)	(i)->destroy(__VA_ARGS__)
#define echo_cancel_run(i,...)		(i)->run(__VA_ARGS__)

extern const struct echo_cancel_info *echo_cancel_webrtc;
extern const struct echo_cancel_info *echo_cancel_null;
