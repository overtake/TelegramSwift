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

#include "echo-cancel.h"

struct impl {
	uint32_t channels;
};

static void *webrtc_create(struct spa_dict *info, uint32_t channels)
{
	struct impl *impl;
	impl = (struct impl *)calloc(1, sizeof(struct impl));
	impl->channels = channels;
	return impl;
}

static void webrtc_destroy(void *ec)
{
	free(ec);
}

static int webrtc_run(void *ec, const float *rec[], const float *play[], float *out[], uint32_t n_samples)
{
	struct impl *impl = (struct impl*)ec;
	uint32_t i;
	for (i = 0; i < impl->channels; i++)
		memcpy(out[i], rec[i], n_samples * sizeof(float));
	return 0;
}

static const struct echo_cancel_info echo_cancel_webrtc_impl = {
	.name = "webrtc",
	.info = SPA_DICT_INIT(NULL, 0),

	.create = webrtc_create,
	.destroy = webrtc_destroy,

	.run = webrtc_run,
};

const struct echo_cancel_info *echo_cancel_webrtc = &echo_cancel_webrtc_impl;
