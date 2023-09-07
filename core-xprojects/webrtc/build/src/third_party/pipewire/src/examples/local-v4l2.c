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

#include <stdio.h>
#include <sys/mman.h>

#define WIDTH   640
#define HEIGHT  480
#define BPP    3

#include "sdl.h"

#include <spa/param/video/format-utils.h>
#include <spa/param/props.h>
#include <spa/pod/filter.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/debug/format.h>
#include <spa/utils/names.h>

#include <pipewire/impl.h>

struct data {
	SDL_Renderer *renderer;
	SDL_Window *window;
	SDL_Texture *texture;

	struct pw_main_loop *loop;

	struct pw_context *context;
	struct pw_core *core;

	struct spa_port_info info;
	struct spa_param_info params[4];

	struct spa_node impl_node;
	struct spa_io_buffers *io;

	struct spa_hook_list hooks;

	struct spa_video_info_raw format;
	int32_t stride;

	struct spa_buffer *buffers[32];
	int n_buffers;

	struct pw_proxy *out, *in, *link;
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

static int impl_set_io(void *object, uint32_t id, void *data, size_t size)
{
	return 0;
}

static int impl_send_command(void *object, const struct spa_command *command)
{
	return 0;
}

static int impl_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct data *d = object;
	struct spa_hook_list save;

	spa_hook_list_isolate(&d->hooks, &save, listener, events, data);

	spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_INPUT, 0, &d->info);

	spa_hook_list_join(&d->hooks, &save);

	return 0;
}

static int impl_set_callbacks(void *object,
			      const struct spa_node_callbacks *callbacks, void *data)
{
	return 0;
}

static int impl_port_set_io(void *object, enum spa_direction direction, uint32_t port_id,
			    uint32_t id, void *data, size_t size)
{
	struct data *d = object;

	if (id == SPA_IO_Buffers)
		d->io = data;
	else
		return -ENOENT;

	return 0;
}

static int impl_port_enum_params(void *object, int seq,
				 enum spa_direction direction, uint32_t port_id,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct data *d = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
	{
		SDL_RendererInfo info;

		if (result.index > 0)
			return 0;

		SDL_GetRendererInfo(d->renderer, &info);
		param = sdl_build_formats(&info, &b);
		break;
	}
	case SPA_PARAM_Buffers:
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, 32),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_Int(d->stride * d->format.size.height),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(d->stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;

	case SPA_PARAM_Meta:
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamMeta, id,
			SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
			SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
		break;

	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&d->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int port_set_format(void *object, enum spa_direction direction, uint32_t port_id,
			   uint32_t flags, const struct spa_pod *format)
{
	struct data *d = object;
	Uint32 sdl_format;
	void *dest;

	if (format == NULL)
		return 0;

	spa_debug_format(0, NULL, format);

	spa_format_video_raw_parse(format, &d->format);

	sdl_format = id_to_sdl_format(d->format.format);
	if (sdl_format == SDL_PIXELFORMAT_UNKNOWN)
		return -EINVAL;

	d->texture = SDL_CreateTexture(d->renderer,
				       sdl_format,
				       SDL_TEXTUREACCESS_STREAMING,
				       d->format.size.width,
				       d->format.size.height);
	SDL_LockTexture(d->texture, NULL, &dest, &d->stride);
	SDL_UnlockTexture(d->texture);

	d->info.change_mask = SPA_PORT_CHANGE_MASK_PARAMS;
	d->params[1] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
	d->params[2] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_INPUT, 0, &d->info);

	return 0;
}

static int impl_port_set_param(void *object,
			       enum spa_direction direction, uint32_t port_id,
			       uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	if (id == SPA_PARAM_Format) {
		return port_set_format(object, direction, port_id, flags, param);
	}
	else
		return -ENOENT;
}

static int impl_port_use_buffers(void *object,
		enum spa_direction direction, uint32_t port_id,
		uint32_t flags, struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct data *d = object;
	uint32_t i;

	for (i = 0; i < n_buffers; i++)
		d->buffers[i] = buffers[i];
	d->n_buffers = n_buffers;
	return 0;
}

static int do_render(struct spa_loop *loop, bool async, uint32_t seq,
		     const void *_data, size_t size, void *user_data)
{
	struct data *d = user_data;
	struct spa_buffer *buf;
	uint8_t *map;
	void *sdata, *ddata;
	int sstride, dstride, ostride;
	uint32_t i;
	uint8_t *src, *dst;

	buf = d->buffers[d->io->buffer_id];

	if (buf->datas[0].type == SPA_DATA_MemFd ||
	    buf->datas[0].type == SPA_DATA_DmaBuf) {
		map = mmap(NULL, buf->datas[0].maxsize + buf->datas[0].mapoffset, PROT_READ,
			   MAP_PRIVATE, buf->datas[0].fd, 0);
		sdata = SPA_MEMBER(map, buf->datas[0].mapoffset, uint8_t);
	} else if (buf->datas[0].type == SPA_DATA_MemPtr) {
		map = NULL;
		sdata = buf->datas[0].data;
	} else
		return -EINVAL;

	if (SDL_LockTexture(d->texture, NULL, &ddata, &dstride) < 0) {
		fprintf(stderr, "Couldn't lock texture: %s\n", SDL_GetError());
		return -EIO;
	}
	sstride = buf->datas[0].chunk->stride;
	ostride = SPA_MIN(sstride, dstride);

	src = sdata;
	dst = ddata;
	for (i = 0; i < d->format.size.height; i++) {
		memcpy(dst, src, ostride);
		src += sstride;
		dst += dstride;
	}
	SDL_UnlockTexture(d->texture);

	SDL_RenderClear(d->renderer);
	SDL_RenderCopy(d->renderer, d->texture, NULL, NULL);
	SDL_RenderPresent(d->renderer);

	if (map)
		munmap(map, buf->datas[0].maxsize + buf->datas[0].mapoffset);

	return 0;
}

static int impl_node_process(void *object)
{
	struct data *d = object;
	int res;

	if ((res = pw_loop_invoke(pw_main_loop_get_loop(d->loop), do_render,
				  SPA_ID_INVALID, NULL, 0, true, d)) < 0)
		return res;

	handle_events(d);

	d->io->status = SPA_STATUS_NEED_DATA;

	return SPA_STATUS_NEED_DATA;
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_add_listener,
	.set_callbacks = impl_set_callbacks,
	.set_io = impl_set_io,
	.send_command = impl_send_command,
	.port_set_io = impl_port_set_io,
	.port_enum_params = impl_port_enum_params,
	.port_set_param = impl_port_set_param,
	.port_use_buffers = impl_port_use_buffers,
	.process = impl_node_process,
};

static int make_nodes(struct data *data)
{
	struct pw_properties *props;

	data->impl_node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, data);

	data->info = SPA_PORT_INFO_INIT();
	data->info.change_mask =
		SPA_PORT_CHANGE_MASK_FLAGS |
		SPA_PORT_CHANGE_MASK_PARAMS;
	data->info.flags = 0;
	data->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	data->params[1] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	data->params[2] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	data->params[3] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	data->info.params = data->params;
	data->info.n_params = SPA_N_ELEMENTS(data->params);

	data->in = pw_core_export(data->core,
			SPA_TYPE_INTERFACE_Node,
			NULL,
			&data->impl_node,
			0);

	props = pw_properties_new(
			SPA_KEY_LIBRARY_NAME, "v4l2/libspa-v4l2",
			SPA_KEY_FACTORY_NAME, SPA_NAME_API_V4L2_SOURCE,
			NULL);

	data->out = pw_core_create_object(data->core,
			"spa-node-factory",
			PW_TYPE_INTERFACE_Node,
			PW_VERSION_NODE,
			&props->dict, 0);


	while (true) {

		if (pw_proxy_get_bound_id(data->out) != SPA_ID_INVALID &&
		    pw_proxy_get_bound_id(data->in) != SPA_ID_INVALID)
			break;

		pw_loop_iterate(pw_main_loop_get_loop(data->loop), -1);
	}

	pw_properties_clear(props);

	pw_properties_setf(props,
			PW_KEY_LINK_OUTPUT_NODE, "%d", pw_proxy_get_bound_id(data->out));
	pw_properties_setf(props,
			PW_KEY_LINK_INPUT_NODE, "%d", pw_proxy_get_bound_id(data->in));

	data->link = pw_core_create_object(data->core,
			"link-factory",
			PW_TYPE_INTERFACE_Link,
			PW_VERSION_LINK,
			&props->dict, 0);

	pw_properties_free(props);

	return 0;
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL);
	data.context = pw_context_new(
			pw_main_loop_get_loop(data.loop),
			pw_properties_new(
				PW_KEY_CORE_DAEMON, "false",
				NULL), 0);

	spa_hook_list_init(&data.hooks);

	pw_context_load_module(data.context, "libpipewire-module-spa-node-factory", NULL, NULL);
	pw_context_load_module(data.context, "libpipewire-module-link-factory", NULL, NULL);

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		printf("can't initialize SDL: %s\n", SDL_GetError());
		return -1;
	}

	if (SDL_CreateWindowAndRenderer
	    (WIDTH, HEIGHT, SDL_WINDOW_RESIZABLE, &data.window, &data.renderer)) {
		printf("can't create window: %s\n", SDL_GetError());
		return -1;
	}

	data.core = pw_context_connect_self(data.context, NULL, 0);
	if (data.core == NULL) {
		printf("can't connect to core: %m\n");
		return -1;
	}

	make_nodes(&data);

	pw_main_loop_run(data.loop);

	pw_proxy_destroy(data.link);
	pw_proxy_destroy(data.in);
	pw_proxy_destroy(data.out);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);
	pw_deinit();

	return 0;
}
