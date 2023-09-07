/* PipeWire JACK extensions
 *
 * Copyright © 2020 Wim Taymans
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

#ifndef PIPEWIRE_JACK_EXTENSIONS_H
#define PIPEWIRE_JACK_EXTENSIONS_H

#ifdef __cplusplus
extern "C" {
#endif

/** 1.0 gamma, full range HDR 0.0 -> 1.0, pre-multiplied
 * alpha, BT.2020 primaries, progressive */
#define JACK_DEFAULT_VIDEO_TYPE	"32 bit float RGBA video"

typedef struct jack_image_size {
	uint32_t width;
	uint32_t height;
	uint32_t stride;
	uint32_t flags;
} jack_image_size_t;

int jack_get_video_image_size(jack_client_t *client, jack_image_size_t *size);

#ifdef __cplusplus
}
#endif

#endif /* PIPEWIRE_JACK_EXTENSIONS_H */
