/* PipeWire
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

#include <stdio.h>
#include <unistd.h>
#include <signal.h>

#include <spa/utils/result.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/format.h>

#include <pipewire/pipewire.h>

#define WIDTH   640
#define HEIGHT  480

#define MAX_BUFFERS	64

#include "sdl.h"

struct pixel {
	float r, g, b, a;
};

struct data {
	const char *path;

	SDL_Renderer *renderer;
	SDL_Window *window;
	SDL_Texture *texture;
	SDL_Texture *cursor;

	struct pw_main_loop *loop;
	struct spa_source *timer;

	struct pw_stream *stream;
	struct spa_hook stream_listener;

	struct spa_video_info format;
	int32_t stride;
	struct spa_rectangle size;

	int counter;
};

static void handle_events(struct data *data)
{
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		switch (event.type) {
		case SDL_QUIT:
			pw_main_loop_quit(data->loop);
			break;
		}
	}
}

/* our data processing function is in general:
 *
 *  struct pw_buffer *b;
 *  b = pw_stream_dequeue_buffer(stream);
 *
 *  .. do stuff with buffer ...
 *
 *  pw_stream_queue_buffer(stream, b);
 */
static void
on_process(void *_data)
{
	struct data *data = _data;
	struct pw_stream *stream = data->stream;
	struct pw_buffer *b;
	struct spa_buffer *buf;
	void *sdata, *ddata;
	int sstride, dstride, ostride;
	uint32_t i;
	uint8_t *src, *dst;

	b = NULL;
	/* dequeue and queue old buffers, use the last available
	 * buffer */
	while (true) {
		struct pw_buffer *t;
		if ((t = pw_stream_dequeue_buffer(stream)) == NULL)
			break;
		if (b)
			pw_stream_queue_buffer(stream, b);
		b = t;
	}
	if (b == NULL) {
		pw_log_warn("out of buffers: %m");
		return;
	}

	buf = b->buffer;

	pw_log_info("new buffer %p", buf);

	handle_events(data);

	if ((sdata = buf->datas[0].data) == NULL)
		goto done;

	if (SDL_LockTexture(data->texture, NULL, &ddata, &dstride) < 0) {
		fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
		goto done;
	}

	/* copy video image in texture */
	sstride = buf->datas[0].chunk->stride;
	ostride = SPA_MIN(sstride, dstride);

	src = sdata;
	dst = ddata;

	for (i = 0; i < data->size.height; i++) {
		memcpy(dst, src, ostride);
		src += sstride;
		dst += dstride;
	}
	SDL_UnlockTexture(data->texture);

	SDL_RenderClear(data->renderer);
	/* now render the video */
	SDL_RenderCopy(data->renderer, data->texture, NULL, NULL);
	SDL_RenderPresent(data->renderer);

      done:
	pw_stream_queue_buffer(stream, b);
}

static void on_stream_state_changed(void *_data, enum pw_stream_state old,
				    enum pw_stream_state state, const char *error)
{
	struct data *data = _data;
	fprintf(stderr, "stream state: \"%s\"\n", pw_stream_state_as_string(state));
	switch (state) {
	case PW_STREAM_STATE_UNCONNECTED:
		pw_main_loop_quit(data->loop);
		break;
	case PW_STREAM_STATE_PAUSED:
		pw_loop_update_timer(pw_main_loop_get_loop(data->loop),
				data->timer, NULL, NULL, false);
		break;
	case PW_STREAM_STATE_STREAMING:
	{
		struct timespec timeout, interval;

		timeout.tv_sec = 1;
		timeout.tv_nsec = 0;
		interval.tv_sec = 1;
		interval.tv_nsec = 0;

		pw_loop_update_timer(pw_main_loop_get_loop(data->loop),
				data->timer, &timeout, &interval, false);
	}
	default:
		break;
	}
}

/* Be notified when the stream param changes. We're only looking at the
 * format changes.
 *
 * We are now supposed to call pw_stream_finish_format() with success or
 * failure, depending on if we can support the format. Because we gave
 * a list of supported formats, this should be ok.
 *
 * As part of pw_stream_finish_format() we can provide parameters that
 * will control the buffer memory allocation. This includes the metadata
 * that we would like on our buffer, the size, alignment, etc.
 */
static void
on_stream_param_changed(void *_data, uint32_t id, const struct spa_pod *param)
{
	struct data *data = _data;
	struct pw_stream *stream = data->stream;
	uint8_t params_buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(params_buffer, sizeof(params_buffer));
	const struct spa_pod *params[1];
	Uint32 sdl_format;
	void *d;

	/* NULL means to clear the format */
	if (param == NULL || id != SPA_PARAM_Format)
		return;

	fprintf(stderr, "got format:\n");
	spa_debug_format(2, NULL, param);

	if (spa_format_parse(param, &data->format.media_type, &data->format.media_subtype) < 0)
		return;

	if (data->format.media_type != SPA_MEDIA_TYPE_video ||
	    data->format.media_subtype != SPA_MEDIA_SUBTYPE_raw)
		return;

	/* call a helper function to parse the format for us. */
	spa_format_video_raw_parse(param, &data->format.info.raw);
	sdl_format = id_to_sdl_format(data->format.info.raw.format);
	data->size = data->format.info.raw.size;

	if (sdl_format == SDL_PIXELFORMAT_UNKNOWN) {
		pw_stream_set_error(stream, -EINVAL, "unknown pixel format");
		return;
	}

	data->texture = SDL_CreateTexture(data->renderer,
					  sdl_format,
					  SDL_TEXTUREACCESS_STREAMING,
					  data->size.width,
					  data->size.height);
	SDL_LockTexture(data->texture, NULL, &d, &data->stride);
	SDL_UnlockTexture(data->texture);

	/* a SPA_TYPE_OBJECT_ParamBuffers object defines the acceptable size,
	 * number, stride etc of the buffers */
	params[0] = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
		SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(8, 2, MAX_BUFFERS),
		SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
		SPA_PARAM_BUFFERS_size,    SPA_POD_Int(data->stride * data->size.height),
		SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(data->stride),
		SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16),
		SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int((1<<SPA_DATA_MemPtr)));

	/* we are done */
	pw_stream_update_params(stream, params, 1);
}

/* these are the stream events we listen for */
static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.state_changed = on_stream_state_changed,
	.param_changed = on_stream_param_changed,
	.process = on_process,
};

static int build_format(struct data *data, struct spa_pod_builder *b, const struct spa_pod **params)
{
	SDL_RendererInfo info;

	SDL_GetRendererInfo(data->renderer, &info);
	params[0] = sdl_build_formats(&info, b);

	fprintf(stderr, "supported SDL formats:\n");
	spa_debug_format(2, NULL, params[0]);

	return 1;
}

static int reneg_format(struct data *data)
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	const struct spa_pod *params[2];
	int32_t width, height;

	if (data->format.info.raw.format == 0)
		return -EBUSY;

	width = data->counter & 1 ? 320 : 640;
	height = data->counter & 1 ? 240 : 480;

	fprintf(stderr, "renegotiate to %dx%d:\n", width, height);
	params[0] = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
		SPA_FORMAT_mediaType,       SPA_POD_Id(SPA_MEDIA_TYPE_video),
		SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
		SPA_FORMAT_VIDEO_format,    SPA_POD_Id(data->format.info.raw.format),
		SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&SPA_RECTANGLE(width, height)),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&data->format.info.raw.framerate));

	pw_stream_update_params(data->stream, params, 1);

	data->counter++;
	return 0;
}

static int reneg_buffers(struct data *data)
{
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	const struct spa_pod *params[2];

	fprintf(stderr, "renegotiate buffers\n");
	params[0] = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
		SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(8, 2, MAX_BUFFERS),
		SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
		SPA_PARAM_BUFFERS_size,    SPA_POD_Int(data->stride * data->size.height),
		SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(data->stride),
		SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));

	pw_stream_update_params(data->stream, params, 1);

	data->counter++;
	return 0;
}

static void on_timeout(void *userdata, uint64_t expirations)
{
	struct data *data = userdata;
	if (1)
		reneg_format(data);
	else
		reneg_buffers(data);
}

static void do_quit(void *userdata, int signal_number)
{
	struct data *data = userdata;
	pw_main_loop_quit(data->loop);
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	const struct spa_pod *params[2];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	int res, n_params;

	pw_init(&argc, &argv);

	/* create a main loop */
	data.loop = pw_main_loop_new(NULL);

	pw_loop_add_signal(pw_main_loop_get_loop(data.loop), SIGINT, do_quit, &data);
	pw_loop_add_signal(pw_main_loop_get_loop(data.loop), SIGTERM, do_quit, &data);

	/* create a simple stream, the simple stream manages to core and remote
	 * objects for you if you don't need to deal with them
	 *
	 * If you plan to autoconnect your stream, you need to provide at least
	 * media, category and role properties
	 *
	 * Pass your events and a user_data pointer as the last arguments. This
	 * will inform you about the stream state. The most important event
	 * you need to listen to is the process event where you need to consume
	 * the data provided to you.
	 */
	data.stream = pw_stream_new_simple(
			pw_main_loop_get_loop(data.loop),
			"video-play-reneg",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Video",
				PW_KEY_MEDIA_CATEGORY, "Capture",
				PW_KEY_MEDIA_ROLE, "Camera",
				NULL),
			&stream_events,
			&data);

	data.path = argc > 1 ? argv[1] : NULL;

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		fprintf(stderr, "can't initialize SDL: %s\n", SDL_GetError());
		return -1;
	}

	if (SDL_CreateWindowAndRenderer
	    (WIDTH, HEIGHT, SDL_WINDOW_RESIZABLE, &data.window, &data.renderer)) {
		fprintf(stderr, "can't create window: %s\n", SDL_GetError());
		return -1;
	}

	/* build the extra parameters to connect with. To connect, we can provide
	 * a list of supported formats.  We use a builder that writes the param
	 * object to the stack. */
	n_params = build_format(&data, &b, params);

	/* now connect the stream, we need a direction (input/output),
	 * an optional target node to connect to, some flags and parameters
	 */
	if ((res = pw_stream_connect(data.stream,
			  PW_DIRECTION_INPUT,
			  data.path ? (uint32_t)atoi(data.path) : PW_ID_ANY,
			  PW_STREAM_FLAG_AUTOCONNECT |	/* try to automatically connect this stream */
			  PW_STREAM_FLAG_MAP_BUFFERS,	/* mmap the buffer data for us */
			  params, n_params))		/* extra parameters, see above */ < 0) {
		fprintf(stderr, "can't connect: %s\n", spa_strerror(res));
		return -1;
	}

	data.timer = pw_loop_add_timer(pw_main_loop_get_loop(data.loop), on_timeout, &data);

	/* do things until we quit the mainloop */
	pw_main_loop_run(data.loop);

	pw_stream_destroy(data.stream);
	pw_main_loop_destroy(data.loop);

	SDL_DestroyTexture(data.texture);
	if (data.cursor)
		SDL_DestroyTexture(data.cursor);
	SDL_DestroyRenderer(data.renderer);
	SDL_DestroyWindow(data.window);
	pw_deinit();

	return 0;
}
