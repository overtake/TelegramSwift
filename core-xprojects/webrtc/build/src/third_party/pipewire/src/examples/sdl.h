/* PipeWire
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

#include <SDL2/SDL.h>

#include <spa/utils/type.h>
#include <spa/pod/builder.h>
#include <spa/param/video/raw.h>
#include <spa/param/video/format.h>

static struct {
	Uint32 format;
	uint32_t id;
} sdl_video_formats[] = {
	{ SDL_PIXELFORMAT_UNKNOWN, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX1LSB, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_UNKNOWN, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX1LSB, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX1MSB, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX4LSB, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX4MSB, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_INDEX8, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGB332, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGB444, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGB555, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_BGR555, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_ARGB4444, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGBA4444, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_ABGR4444, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_BGRA4444, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_ARGB1555, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGBA5551, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_ABGR1555, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_BGRA5551, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGB565, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_BGR565, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGB24, SPA_VIDEO_FORMAT_RGB,},
	{ SDL_PIXELFORMAT_RGB888, SPA_VIDEO_FORMAT_RGB,},
	{ SDL_PIXELFORMAT_RGBX8888, SPA_VIDEO_FORMAT_RGBx,},
	{ SDL_PIXELFORMAT_BGR24, SPA_VIDEO_FORMAT_BGR,},
	{ SDL_PIXELFORMAT_BGR888, SPA_VIDEO_FORMAT_BGR,},
	{ SDL_PIXELFORMAT_BGRX8888, SPA_VIDEO_FORMAT_BGRx,},
	{ SDL_PIXELFORMAT_ARGB2101010, SPA_VIDEO_FORMAT_UNKNOWN,},
	{ SDL_PIXELFORMAT_RGBA8888, SPA_VIDEO_FORMAT_RGBA,},
	{ SDL_PIXELFORMAT_ARGB8888, SPA_VIDEO_FORMAT_ARGB,},
	{ SDL_PIXELFORMAT_BGRA8888, SPA_VIDEO_FORMAT_BGRA,},
	{ SDL_PIXELFORMAT_ABGR8888, SPA_VIDEO_FORMAT_ABGR,},
	{ SDL_PIXELFORMAT_YV12, SPA_VIDEO_FORMAT_YV12,},
	{ SDL_PIXELFORMAT_IYUV, SPA_VIDEO_FORMAT_I420,},
	{ SDL_PIXELFORMAT_YUY2, SPA_VIDEO_FORMAT_YUY2,},
	{ SDL_PIXELFORMAT_UYVY, SPA_VIDEO_FORMAT_UYVY,},
	{ SDL_PIXELFORMAT_YVYU, SPA_VIDEO_FORMAT_YVYU,},
#if SDL_VERSION_ATLEAST(2,0,4)
	{ SDL_PIXELFORMAT_NV12, SPA_VIDEO_FORMAT_NV12,},
	{ SDL_PIXELFORMAT_NV21, SPA_VIDEO_FORMAT_NV21,},
#endif
};

static inline uint32_t sdl_format_to_id(Uint32 format)
{
	size_t i;
	for (i = 0; i < SPA_N_ELEMENTS(sdl_video_formats); i++) {
		if (sdl_video_formats[i].format == format)
			return sdl_video_formats[i].id;
	}
	return SPA_VIDEO_FORMAT_UNKNOWN;
}

static inline Uint32 id_to_sdl_format(uint32_t id)
{
	size_t i;
	for (i = 0; i < SPA_N_ELEMENTS(sdl_video_formats); i++) {
		if (sdl_video_formats[i].id == id)
			return sdl_video_formats[i].format;
	}
	return SDL_PIXELFORMAT_UNKNOWN;
}


static inline struct spa_pod *sdl_build_formats(SDL_RendererInfo *info, struct spa_pod_builder *b)
{
	uint32_t i, c;
	struct spa_pod_frame f[2];

	/* make an object of type SPA_TYPE_OBJECT_Format and id SPA_PARAM_EnumFormat.
	 * The object type is important because it defines the properties that are
	 * acceptable. The id gives more context about what the object is meant to
	 * contain. In this case we enumerate supported formats. */
	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
	/* add media type and media subtype properties */
	spa_pod_builder_prop(b, SPA_FORMAT_mediaType, 0);
	spa_pod_builder_id(b, SPA_MEDIA_TYPE_video);
	spa_pod_builder_prop(b, SPA_FORMAT_mediaSubtype, 0);
	spa_pod_builder_id(b, SPA_MEDIA_SUBTYPE_raw);

	/* build an enumeration of formats */
	spa_pod_builder_prop(b, SPA_FORMAT_VIDEO_format, 0);
	spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_Enum, 0);
	/* first the formats supported by the textures */
	for (i = 0, c = 0; i < info->num_texture_formats; i++) {
		uint32_t id = sdl_format_to_id(info->texture_formats[i]);
		if (id == 0)
			continue;
		if (c++ == 0)
			spa_pod_builder_id(b, id);
		spa_pod_builder_id(b, id);
	}
	/* then all the other ones SDL can convert from/to */
	for (i = 0; i < SPA_N_ELEMENTS(sdl_video_formats); i++) {
		uint32_t id = sdl_video_formats[i].id;
		if (id != SPA_VIDEO_FORMAT_UNKNOWN)
			spa_pod_builder_id(b, id);
	}
	spa_pod_builder_id(b, SPA_VIDEO_FORMAT_RGBA_F32);
	spa_pod_builder_pop(b, &f[1]);
	/* add size and framerate ranges */
	spa_pod_builder_add(b,
		SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
							&SPA_RECTANGLE(WIDTH, HEIGHT),
							&SPA_RECTANGLE(1,1),
							&SPA_RECTANGLE(info->max_texture_width,
								      info->max_texture_height)),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
							&SPA_FRACTION(25,1),
							&SPA_FRACTION(0,1),
							&SPA_FRACTION(30,1)),
		0);
	return spa_pod_builder_pop(b, &f[0]);
}
