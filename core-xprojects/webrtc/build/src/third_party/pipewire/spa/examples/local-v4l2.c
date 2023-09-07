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

#include "config.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>
#include <poll.h>
#include <pthread.h>
#include <errno.h>
#include <sys/mman.h>

#include <SDL2/SDL.h>

#include <spa/support/plugin.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/support/log-impl.h>
#include <spa/support/loop.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/param.h>
#include <spa/param/props.h>
#include <spa/param/video/format-utils.h>
#include <spa/debug/pod.h>

static SPA_LOG_IMPL(default_log);

#define MAX_BUFFERS     8

struct buffer {
	struct spa_buffer buffer;
	struct spa_meta metas[1];
	struct spa_meta_header header;
	struct spa_data datas[1];
	struct spa_chunk chunks[1];
	SDL_Texture *texture;
};

struct data {
	const char *plugin_dir;
	struct spa_log *log;
	struct spa_system *system;
	struct spa_loop *loop;
	struct spa_loop_control *control;

	struct spa_support support[5];
	uint32_t n_support;

	struct spa_node *source;
	struct spa_hook listener;
	struct spa_io_buffers source_output[1];

	SDL_Renderer *renderer;
	SDL_Window *window;
	SDL_Texture *texture;

	bool use_buffer;

	bool running;
	pthread_t thread;

	struct spa_buffer *bp[MAX_BUFFERS];
	struct buffer buffers[MAX_BUFFERS];
	unsigned int n_buffers;
};

static int load_handle(struct data *data, struct spa_handle **handle, const char *lib, const char *name)
{
	int res;
	void *hnd;
	spa_handle_factory_enum_func_t enum_func;
	uint32_t i;
	char *path = NULL;

	if ((path = spa_aprintf("%s/%s", data->plugin_dir, lib)) == NULL) {
		return -ENOMEM;
	}
	if ((hnd = dlopen(path, RTLD_NOW)) == NULL) {
		printf("can't load %s: %s\n", path, dlerror());
		free(path);
		return -ENOENT;
	}
	free(path);
	if ((enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		printf("can't find enum function\n");
		return -ENOENT;
	}

	for (i = 0;;) {
		const struct spa_handle_factory *factory;

		if ((res = enum_func(&factory, &i)) <= 0) {
			if (res != 0)
				printf("can't enumerate factories: %s\n", spa_strerror(res));
			break;
		}
		if (factory->version < 1)
			continue;
		if (strcmp(factory->name, name))
			continue;

		*handle = calloc(1, spa_handle_factory_get_size(factory, NULL));
		if ((res = spa_handle_factory_init(factory, *handle,
						NULL, data->support,
						data->n_support)) < 0) {
			printf("can't make factory instance: %d\n", res);
			return res;
		}
		return 0;
	}
	return -EBADF;
}

static int make_node(struct data *data, struct spa_node **node, const char *lib, const char *name)
{
	struct spa_handle *handle = NULL;
	void *iface;
	int res;

	if ((res = load_handle(data, &handle, lib, name)) < 0)
		return res;

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Node, &iface)) < 0) {
		printf("can't get interface %d\n", res);
		return res;
	}
	*node = iface;
	return 0;
}

static int on_source_ready(void *_data, int status)
{
	struct data *data = _data;
	int res;
	struct buffer *b;
	void *sdata, *ddata;
	int sstride, dstride;
	int i;
	uint8_t *src, *dst;
	struct spa_data *datas;
	struct spa_io_buffers *io = &data->source_output[0];

	if (io->status != SPA_STATUS_HAVE_DATA ||
	    io->buffer_id >= MAX_BUFFERS)
		return -EINVAL;

	b = &data->buffers[io->buffer_id];
	io->status = SPA_STATUS_NEED_DATA;

	datas = b->buffer.datas;

	if (b->texture) {
		SDL_Texture *texture = b->texture;

		SDL_UnlockTexture(texture);

		SDL_RenderClear(data->renderer);
		SDL_RenderCopy(data->renderer, texture, NULL, NULL);
		SDL_RenderPresent(data->renderer);

		if (SDL_LockTexture(texture, NULL, &sdata, &sstride) < 0) {
			fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
			return -EIO;
		}
	} else {
		uint8_t *map;

		if (SDL_LockTexture(data->texture, NULL, &ddata, &dstride) < 0) {
			fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
			return -EIO;
		}
		sdata = datas[0].data;
		if (datas[0].type == SPA_DATA_MemFd ||
		    datas[0].type == SPA_DATA_DmaBuf) {
			map = mmap(NULL, datas[0].maxsize + datas[0].mapoffset, PROT_READ,
				   MAP_PRIVATE, datas[0].fd, 0);
			if (map == MAP_FAILED)
				return -errno;
			sdata = SPA_MEMBER(map, datas[0].mapoffset, uint8_t);
		} else if (datas[0].type == SPA_DATA_MemPtr) {
			map = NULL;
			sdata = datas[0].data;
		} else
			return -EIO;

		sstride = datas[0].chunk->stride;

		for (i = 0; i < 240; i++) {
			src = ((uint8_t *) sdata + i * sstride);
			dst = ((uint8_t *) ddata + i * dstride);
			memcpy(dst, src, SPA_MIN(sstride, dstride));
		}
		SDL_UnlockTexture(data->texture);

		SDL_RenderClear(data->renderer);
		SDL_RenderCopy(data->renderer, data->texture, NULL, NULL);
		SDL_RenderPresent(data->renderer);

		if (map)
			munmap(map, datas[0].maxsize + datas[0].mapoffset);
	}

	if ((res = spa_node_process(data->source)) < 0)
		printf("got process error %d\n", res);

	return 0;
}

static const struct spa_node_callbacks source_callbacks = {
	SPA_VERSION_NODE_CALLBACKS,
	.ready = on_source_ready,
};

static int make_nodes(struct data *data, const char *device)
{
	int res;
	struct spa_pod *props;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[256];
	uint32_t index;

	if ((res =
	     make_node(data, &data->source,
		     "v4l2/libspa-v4l2.so",
		     SPA_NAME_API_V4L2_SOURCE)) < 0) {
		printf("can't create v4l2-source: %d\n", res);
		return res;
	}

	spa_node_set_callbacks(data->source, &source_callbacks, data);

	index = 0;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	if ((res = spa_node_enum_params_sync(data->source, SPA_PARAM_Props,
			&index, NULL, &props, &b)) == 1) {
		spa_debug_pod(0, NULL, props);
	}

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	props = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Props, 0,
		SPA_PROP_device, SPA_POD_String(device ? device : "/dev/video0"));

	if ((res = spa_node_set_param(data->source, SPA_PARAM_Props, 0, props)) < 0)
		printf("got set_props error %d\n", res);

	return res;
}

static int setup_buffers(struct data *data)
{
	int i;

	for (i = 0; i < MAX_BUFFERS; i++) {
		struct buffer *b = &data->buffers[i];

		data->bp[i] = &b->buffer;

		b->texture = NULL;

		b->buffer.metas = b->metas;
		b->buffer.n_metas = 1;
		b->buffer.datas = b->datas;
		b->buffer.n_datas = 1;

		b->header.flags = 0;
		b->header.seq = 0;
		b->header.pts = 0;
		b->header.dts_offset = 0;
		b->metas[0].type = SPA_META_Header;
		b->metas[0].data = &b->header;
		b->metas[0].size = sizeof(b->header);

		b->datas[0].type = 0;
		b->datas[0].flags = 0;
		b->datas[0].fd = -1;
		b->datas[0].mapoffset = 0;
		b->datas[0].maxsize = 0;
		b->datas[0].data = NULL;
		b->datas[0].chunk = &b->chunks[0];
		b->datas[0].chunk->offset = 0;
		b->datas[0].chunk->size = 0;
		b->datas[0].chunk->stride = 0;
	}
	data->n_buffers = MAX_BUFFERS;
	return 0;
}

static int sdl_alloc_buffers(struct data *data)
{
	int i;

	for (i = 0; i < MAX_BUFFERS; i++) {
		struct buffer *b = &data->buffers[i];
		SDL_Texture *texture;
		void *ptr;
		int stride;

		texture = SDL_CreateTexture(data->renderer,
					    SDL_PIXELFORMAT_YUY2,
					    SDL_TEXTUREACCESS_STREAMING, 320, 240);
		if (!texture) {
			printf("can't create texture: %s\n", SDL_GetError());
			return -ENOMEM;
		}
		if (SDL_LockTexture(texture, NULL, &ptr, &stride) < 0) {
			fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
			return -EIO;
		}
		b->texture = texture;

		b->datas[0].type = SPA_DATA_MemPtr;
		b->datas[0].maxsize = stride * 240;
		b->datas[0].data = ptr;
		b->datas[0].chunk->offset = 0;
		b->datas[0].chunk->size = stride * 240;
		b->datas[0].chunk->stride = stride;
	}
	return 0;
}

static int negotiate_formats(struct data *data)
{
	int res;
	struct spa_pod *format;
	uint8_t buffer[256];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	data->source_output[0] = SPA_IO_BUFFERS_INIT;

	if ((res =
	     spa_node_port_set_io(data->source,
				  SPA_DIRECTION_OUTPUT, 0,
				  SPA_IO_Buffers,
				  &data->source_output[0], sizeof(data->source_output[0]))) < 0)
		return res;

	format = spa_format_video_raw_build(&b, 0,
			&SPA_VIDEO_INFO_RAW_INIT(
				.format =  SPA_VIDEO_FORMAT_YUY2,
				.size = SPA_RECTANGLE(320, 240),
				.framerate = SPA_FRACTION(25,1)));

	if ((res = spa_node_port_set_param(data->source,
					   SPA_DIRECTION_OUTPUT, 0,
					   SPA_PARAM_Format, 0,
					   format)) < 0)
		return res;


	setup_buffers(data);

	if (data->use_buffer) {
		if ((res = sdl_alloc_buffers(data)) < 0)
			return res;

		if ((res = spa_node_port_use_buffers(data->source,
						SPA_DIRECTION_OUTPUT, 0, 0,
						data->bp, data->n_buffers)) < 0) {
			printf("can't allocate buffers: %s\n", spa_strerror(res));
			return -1;
		}
	} else {
		unsigned int n_buffers;

		data->texture = SDL_CreateTexture(data->renderer,
						  SDL_PIXELFORMAT_YUY2,
						  SDL_TEXTUREACCESS_STREAMING, 320, 240);
		if (!data->texture) {
			printf("can't create texture: %s\n", SDL_GetError());
			return -1;
		}
		n_buffers = MAX_BUFFERS;
		if ((res = spa_node_port_use_buffers(data->source,
						SPA_DIRECTION_OUTPUT, 0,
						SPA_NODE_BUFFERS_FLAG_ALLOC,
						data->bp, n_buffers)) < 0) {
			printf("can't allocate buffers: %s\n", spa_strerror(res));
			return -1;
		}
		data->n_buffers = n_buffers;
	}
	return 0;
}

static void *loop(void *user_data)
{
	struct data *data = user_data;

	printf("enter thread\n");
        spa_loop_control_enter(data->control);

	while (data->running) {
		spa_loop_control_iterate(data->control, -1);
	}

	printf("leave thread\n");
        spa_loop_control_leave(data->control);
	return NULL;
}

static void run_async_source(struct data *data)
{
	int res, err;
	struct spa_command cmd;
	SDL_Event event;
	bool running = true;

	cmd = SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Start);
	if ((res = spa_node_send_command(data->source, &cmd)) < 0)
		printf("got error %d\n", res);

	spa_loop_control_leave(data->control);

	data->running = true;
	if ((err = pthread_create(&data->thread, NULL, loop, data)) != 0) {
		printf("can't create thread: %d %s", err, strerror(err));
		data->running = false;
	}

	while (running && SDL_WaitEvent(&event)) {
		switch (event.type) {
		case SDL_QUIT:
			running = false;
			break;
		}
	}

	if (data->running) {
		data->running = false;
		pthread_join(data->thread, NULL);
	}

	spa_loop_control_enter(data->control);

	cmd = SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Pause);
	if ((res = spa_node_send_command(data->source, &cmd)) < 0)
		printf("got error %d\n", res);
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	int res;
	const char *str;
	struct spa_handle *handle = NULL;
	void *iface;

	if ((str = getenv("SPA_PLUGIN_DIR")) == NULL)
		str = PLUGINDIR;
	data.plugin_dir = str;

	if ((res = load_handle(&data, &handle,
					"support/libspa-support.so",
					SPA_NAME_SUPPORT_SYSTEM)) < 0)
		return res;

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_System, &iface)) < 0) {
		printf("can't get System interface %d\n", res);
		return res;
	}
	data.system = iface;
	data.support[data.n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_System, data.system);

	if ((res = load_handle(&data, &handle,
					"support/libspa-support.so",
					SPA_NAME_SUPPORT_LOOP)) < 0)
		return res;

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Loop, &iface)) < 0) {
		printf("can't get interface %d\n", res);
		return res;
	}
	data.loop = iface;
	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_LoopControl, &iface)) < 0) {
		printf("can't get interface %d\n", res);
		return res;
	}
	data.control = iface;

	data.use_buffer = true;

	data.log = &default_log.log;

	if ((str = getenv("SPA_DEBUG")))
		data.log->level = atoi(str);

	data.support[data.n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, data.log);
	data.support[data.n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Loop, data.loop);
	data.support[data.n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataLoop, data.loop);

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		printf("can't initialize SDL: %s\n", SDL_GetError());
		return -1;
	}

	if (SDL_CreateWindowAndRenderer
	    (320, 240, SDL_WINDOW_RESIZABLE, &data.window, &data.renderer)) {
		printf("can't create window: %s\n", SDL_GetError());
		return -1;
	}


	if ((res = make_nodes(&data, argv[1])) < 0) {
		printf("can't make nodes: %d\n", res);
		return -1;
	}
	if ((res = negotiate_formats(&data)) < 0) {
		printf("can't negotiate nodes: %d\n", res);
		return -1;
	}

	spa_loop_control_enter(data.control);
	run_async_source(&data);
	spa_loop_control_leave(data.control);

	SDL_DestroyRenderer(data.renderer);

	return 0;
}
