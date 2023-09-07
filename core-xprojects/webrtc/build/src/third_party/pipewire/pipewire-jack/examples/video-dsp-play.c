/* PipeWire
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

#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>

#include <SDL2/SDL.h>

#include <jack/jack.h>
#include <pipewire-jack-extensions.h>

#define MAX_BUFFERS	64

#define JACK_DEFAULT_VIDEO_TYPE "32 bit float RGBA video"

#define CLAMP(v,low,high)				\
({							\
	__typeof__(v) _v = (v);				\
	__typeof__(low) _low = (low);			\
	__typeof__(high) _high = (high);		\
	(_v < _low) ? _low : (_v > _high) ? _high : _v;	\
})

struct pixel {
	float r, g, b, a;
};

struct data {
	const char *path;

	SDL_Renderer *renderer;
	SDL_Window *window;
	SDL_Texture *texture;
	SDL_Texture *cursor;

	jack_client_t *client;
	const char *client_name;
	jack_port_t *in_port;

	jack_image_size_t size;

	int counter;
	SDL_Rect rect;
	SDL_Rect cursor_rect;
};

static void handle_events(struct data *data)
{
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		switch (event.type) {
		case SDL_QUIT:
			exit(0);
			break;
		}
	}
}

static int
process (jack_nframes_t nframes, void *arg)
{
        struct data *data = (struct data*)arg;
	void *sdata, *ddata;
	int sstride, dstride;
	uint32_t i, j;
	uint8_t *src, *dst;

        sdata = jack_port_get_buffer (data->in_port, nframes);

	handle_events(data);

	if (SDL_LockTexture(data->texture, NULL, &ddata, &dstride) < 0) {
		fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
		goto done;
	}

	/* copy video image in texture */
	sstride = data->size.stride;

	src = sdata;
	dst = ddata;

	for (i = 0; i < data->size.height; i++) {
		struct pixel *p = (struct pixel *) src;
		for (j = 0; j < data->size.width; j++) {
			dst[j * 4 + 0] = CLAMP(lrintf(p[j].r * 255.0f), 0, 255);
			dst[j * 4 + 1] = CLAMP(lrintf(p[j].g * 255.0f), 0, 255);
			dst[j * 4 + 2] = CLAMP(lrintf(p[j].b * 255.0f), 0, 255);
			dst[j * 4 + 3] = CLAMP(lrintf(p[j].a * 255.0f), 0, 255);
		}
		src += sstride;
		dst += dstride;
	}
	SDL_UnlockTexture(data->texture);

	SDL_RenderClear(data->renderer);
	SDL_RenderCopy(data->renderer, data->texture, &data->rect, NULL);
	SDL_RenderPresent(data->renderer);

      done:
	return 0;
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	jack_options_t options = JackNullOption;
        jack_status_t status;
	int res;

	data.client = jack_client_open ("video-dsp-play", options, &status);
        if (data.client == NULL) {
                fprintf (stderr, "jack_client_open() failed, "
                         "status = 0x%2.0x\n", status);
                if (status & JackServerFailed) {
                        fprintf (stderr, "Unable to connect to JACK server\n");
                }
                exit (1);
        }
        if (status & JackServerStarted) {
                fprintf (stderr, "JACK server started\n");
        }
        if (status & JackNameNotUnique) {
                data.client_name = jack_get_client_name(data.client);
                fprintf (stderr, "unique name `%s' assigned\n", data.client_name);
        }

        jack_set_process_callback (data.client, process, &data);

	if ((res = jack_get_video_image_size(data.client, &data.size)) < 0) {
		fprintf(stderr, "can't get video size: %d %s\n", res, strerror(-res));
		return -1;
	}

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		fprintf(stderr, "can't initialize SDL: %s\n", SDL_GetError());
		return -1;
	}

	if (SDL_CreateWindowAndRenderer
	    (data.size.width, data.size.height, SDL_WINDOW_RESIZABLE, &data.window, &data.renderer)) {
		fprintf(stderr, "can't create window: %s\n", SDL_GetError());
		return -1;
	}

	data.texture = SDL_CreateTexture(data.renderer,
					  SDL_PIXELFORMAT_RGBA32,
					  SDL_TEXTUREACCESS_STREAMING,
					  data.size.width,
					  data.size.height);
	data.rect.x = 0;
	data.rect.y = 0;
	data.rect.w = data.size.width;
	data.rect.h = data.size.height;

	data.in_port = jack_port_register (data.client, "input",
                                          JACK_DEFAULT_VIDEO_TYPE,
                                          JackPortIsInput, 0);

       if (data.in_port == NULL) {
                fprintf(stderr, "no more JACK ports available\n");
                exit (1);
        }

        if (jack_activate (data.client)) {
                fprintf (stderr, "cannot activate client");
                exit (1);
        }

	while (1) {
		sleep (1);
	}

        jack_client_close (data.client);

	SDL_DestroyTexture(data.texture);
	SDL_DestroyRenderer(data.renderer);
	SDL_DestroyWindow(data.window);

	return 0;
}
