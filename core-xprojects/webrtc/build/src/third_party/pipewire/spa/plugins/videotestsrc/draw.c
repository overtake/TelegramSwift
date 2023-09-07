/* Spa Video Test Source
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

#include <errno.h>

typedef enum {
	GRAY = 0,
	YELLOW,
	CYAN,
	GREEN,
	MAGENTA,
	RED,
	BLUE,
	BLACK,
	NEG_I,
	WHITE,
	POS_Q,
	DARK_BLACK,
	LIGHT_BLACK,
	N_COLORS
} Color;

typedef struct _Pixel Pixel;

struct _Pixel {
	unsigned char R;
	unsigned char G;
	unsigned char B;
	unsigned char Y;
	unsigned char U;
	unsigned char V;
};

static Pixel colors[N_COLORS] = {
	{191, 191, 191, 0, 0, 0},	/* GRAY */
	{191, 191, 0, 0, 0, 0},		/* YELLOW */
	{0, 191, 191, 0, 0, 0},		/* CYAN */
	{0, 191, 0, 0, 0, 0},		/* GREEN */
	{191, 0, 191, 0, 0, 0},		/* MAGENTA */
	{191, 0, 0, 0, 0, 0},		/* RED */
	{0, 0, 191, 0, 0, 0},		/* BLUE */
	{19, 19, 19, 0, 0, 0},		/* BLACK */
	{0, 33, 76, 0, 0, 0},		/* NEGATIVE I */
	{255, 255, 255, 0, 0, 0},	/* WHITE */
	{49, 0, 107, 0, 0, 0},		/* POSITIVE Q */
	{9, 9, 9, 0, 0, 0},		/* DARK BLACK */
	{29, 29, 29, 0, 0, 0},		/* LIGHT BLACK */
};

/* YUV values are computed in init_colors() */

typedef struct _DrawingData DrawingData;

typedef void (*DrawPixelFunc) (DrawingData * dd, int x, Pixel * pixel);

struct _DrawingData {
	char *line;
	int width;
	int height;
	int stride;
	DrawPixelFunc draw_pixel;
};

static inline void update_yuv(Pixel * pixel)
{
	uint16_t y, u, v;

	/* see https://en.wikipedia.org/wiki/YUV#Studio_swing_for_BT.601 */

	y = 76 * pixel->R + 150 * pixel->G + 29 * pixel->B;
	u = -43 * pixel->R - 84 * pixel->G + 127 * pixel->B;
	v = 127 * pixel->R - 106 * pixel->G - 21 * pixel->B;

	y = (y + 128) >> 8;
	u = (u + 128) >> 8;
	v = (v + 128) >> 8;

	pixel->Y = y;
	pixel->U = u + 128;
	pixel->V = v + 128;
}

static void init_colors(void)
{
	int i;

	if (colors[WHITE].Y != 0) {
		/* already computed */
		return;
	}

	for (i = 0; i < N_COLORS; i++) {
		update_yuv(&colors[i]);
	}
}

static void draw_pixel_rgb(DrawingData * dd, int x, Pixel * color)
{
	dd->line[3 * x + 0] = color->R;
	dd->line[3 * x + 1] = color->G;
	dd->line[3 * x + 2] = color->B;
}

static void draw_pixel_uyvy(DrawingData * dd, int x, Pixel * color)
{
	if (x & 1) {
		/* odd pixel */
		dd->line[2 * (x - 1) + 3] = color->Y;
	} else {
		/* even pixel */
		dd->line[2 * x + 0] = color->U;
		dd->line[2 * x + 1] = color->Y;
		dd->line[2 * x + 2] = color->V;
	}
}

static int drawing_data_init(DrawingData * dd, struct impl *this, char *data)
{
	struct port *port = &this->port;
	struct spa_video_info *format = &port->current_format;
	struct spa_rectangle *size = &format->info.raw.size;

	if ((format->media_type != SPA_MEDIA_TYPE_video) ||
	    (format->media_subtype != SPA_MEDIA_SUBTYPE_raw))
		return -ENOTSUP;

	if (format->info.raw.format == SPA_VIDEO_FORMAT_RGB) {
		dd->draw_pixel = draw_pixel_rgb;
	} else if (format->info.raw.format == SPA_VIDEO_FORMAT_UYVY) {
		dd->draw_pixel = draw_pixel_uyvy;
	} else
		return -ENOTSUP;

	dd->line = data;
	dd->width = size->width;
	dd->height = size->height;
	dd->stride = port->stride;

	return 0;
}

static inline void draw_pixels(DrawingData * dd, int offset, Color color, int length)
{
	int x;

	for (x = offset; x < offset + length; x++) {
		dd->draw_pixel(dd, x, &colors[color]);
	}
}

static inline void next_line(DrawingData * dd)
{
	dd->line += dd->stride;
}

static void draw_smpte_snow(DrawingData * dd)
{
	int h, w;
	int y1, y2;
	int i, j;

	w = dd->width;
	h = dd->height;
	y1 = 2 * h / 3;
	y2 = 3 * h / 4;

	for (i = 0; i < y1; i++) {
		for (j = 0; j < 7; j++) {
			int x1 = j * w / 7;
			int x2 = (j + 1) * w / 7;
			draw_pixels(dd, x1, j, x2 - x1);
		}
		next_line(dd);
	}

	for (i = y1; i < y2; i++) {
		for (j = 0; j < 7; j++) {
			int x1 = j * w / 7;
			int x2 = (j + 1) * w / 7;
			Color c = (j & 1) ? BLACK : BLUE - j;

			draw_pixels(dd, x1, c, x2 - x1);
		}
		next_line(dd);
	}

	for (i = y2; i < h; i++) {
		int x = 0;

		/* negative I */
		draw_pixels(dd, x, NEG_I, w / 6);
		x += w / 6;

		/* white */
		draw_pixels(dd, x, WHITE, w / 6);
		x += w / 6;

		/* positive Q */
		draw_pixels(dd, x, POS_Q, w / 6);
		x += w / 6;

		/* pluge */
		draw_pixels(dd, x, DARK_BLACK, w / 12);
		x += w / 12;
		draw_pixels(dd, x, BLACK, w / 12);
		x += w / 12;
		draw_pixels(dd, x, LIGHT_BLACK, w / 12);
		x += w / 12;

		/* war of the ants (a.k.a. snow) */
		for (j = x; j < w; j++) {
			Pixel p;
			unsigned char r = rand();

			p.R = r;
			p.G = r;
			p.B = r;
			update_yuv(&p);
			dd->draw_pixel(dd, j, &p);
		}

		next_line(dd);
	}
}

static void draw_snow(DrawingData * dd)
{
	int x, y;

	for (y = 0; y < dd->height; y++) {
		for (x = 0; x < dd->width; x++) {
			Pixel p;
			unsigned char r = rand();

			p.R = r;
			p.G = r;
			p.B = r;
			update_yuv(&p);
			dd->draw_pixel(dd, x, &p);
		}

		next_line(dd);
	}
}

static int draw(struct impl *this, char *data)
{
	DrawingData dd;
	int res;

	init_colors();

	if ((res = drawing_data_init(&dd, this, data)) < 0)
		return res;

	switch (this->props.pattern) {
	case PATTERN_SMPTE_SNOW:
		draw_smpte_snow(&dd);
		break;
	case PATTERN_SNOW:
		draw_snow(&dd);
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}
