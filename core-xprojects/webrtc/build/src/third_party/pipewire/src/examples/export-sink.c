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

#include <errno.h>
#include <stdio.h>
#include <sys/mman.h>

#include <spa/utils/result.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/props.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/pod/filter.h>
#include <spa/debug/format.h>
#include <spa/debug/pod.h>

#include <pipewire/pipewire.h>

#define WIDTH   640
#define HEIGHT  480
#define BPP    3

#include "sdl.h"

#define M_PI_M2 ( M_PI + M_PI )

#define MAX_BUFFERS	64

#define DEFAULT_PARAM 0.1

struct props {
	double param;
};

static void reset_props(struct props *props)
{
	props->param = DEFAULT_PARAM;
}

struct data {
	struct props props;

	const char *path;

	SDL_Renderer *renderer;
	SDL_Window *window;
	SDL_Texture *texture;

	struct pw_main_loop *loop;

	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct spa_node impl_node;
	struct spa_hook_list hooks;
	struct spa_io_buffers *io;
	struct spa_io_sequence *io_notify;
	uint32_t io_notify_size;
	double param_accum;

	uint8_t buffer[1024];

	struct spa_video_info_raw format;
	int32_t stride;

	struct spa_port_info info;
	struct spa_param_info params[5];

	struct spa_region region;

	struct spa_buffer *buffers[MAX_BUFFERS];
	uint32_t n_buffers;
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

static void update_param(struct data *data)
{
	struct spa_pod_builder b = { 0, };
	struct spa_pod_frame f[2];

	if (data->io_notify == NULL)
		return;

	spa_pod_builder_init(&b, data->io_notify, data->io_notify_size);
	spa_pod_builder_push_sequence(&b, &f[0], 0);
	spa_pod_builder_control(&b, 0, SPA_CONTROL_Properties);
	spa_pod_builder_push_object(&b, &f[1], SPA_TYPE_OBJECT_Props, 0);
	spa_pod_builder_prop(&b, SPA_PROP_contrast, 0);
	spa_pod_builder_float(&b, (sin(data->param_accum) * 127.0) + 127.0);
	spa_pod_builder_pop(&b, &f[1]);
	spa_pod_builder_pop(&b, &f[0]);

        data->param_accum += M_PI_M2 / 30.0;
        if (data->param_accum >= M_PI_M2)
                data->param_accum -= M_PI_M2;
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

	d->info.change_mask = SPA_PORT_CHANGE_MASK_FLAGS |
				SPA_PORT_CHANGE_MASK_PARAMS;
	spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_INPUT, 0, &d->info);
	d->info.change_mask = 0;

	spa_hook_list_join(&d->hooks, &save);

	return 0;
}

static int impl_set_callbacks(void *object,
			      const struct spa_node_callbacks *callbacks, void *data)
{
	return 0;
}

static int impl_set_io(void *object,
			    uint32_t id, void *data, size_t size)
{
	return 0;
}

static int impl_port_set_io(void *object,
			    enum spa_direction direction, uint32_t port_id,
			    uint32_t id, void *data, size_t size)
{
	struct data *d = object;

	switch (id) {
	case SPA_IO_Buffers:
		d->io = data;
		break;
	case SPA_IO_Notify:
		d->io_notify = data;
		d->io_notify_size = size;
		break;
	default:
		return -ENOENT;
	}
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

		if (result.index != 0)
			return 0;

		SDL_GetRendererInfo(d->renderer, &info);
		param = sdl_build_formats(&info, &b);
		break;
	}
	case SPA_PARAM_Format:
		if (result.index != 0 || d->format.format == 0)
			return 0;
		param = spa_format_video_raw_build(&b, id, &d->format);
		break;

	case SPA_PARAM_Buffers:
		if (result.index != 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 2, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_Int(d->stride * d->format.size.height),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(d->stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;

	case SPA_PARAM_Meta:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamMeta, id,
				SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
				SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamMeta, id,
				SPA_PARAM_META_type, SPA_POD_Id(SPA_META_VideoDamage),
				SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_region)));
			break;
		default:
			return 0;
		}
		break;

	case SPA_PARAM_IO:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Buffers),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_buffers)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Notify),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_sequence) + 1024));
			break;
		default:
			return 0;
		}
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

static int port_set_format(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t flags, const struct spa_pod *format)
{
	struct data *d = object;
	Uint32 sdl_format;
	void *dest;

	d->info.change_mask = SPA_PORT_CHANGE_MASK_PARAMS;
	if (format == NULL) {
		SDL_DestroyTexture(d->texture);
		d->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		d->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	} else {
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

		d->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		d->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	}
	spa_node_emit_port_info(&d->hooks, direction, port_id, &d->info);
	d->info.change_mask = 0;

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
		uint32_t flags,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct data *d = object;
	uint32_t i;

	if (n_buffers > MAX_BUFFERS)
		return -ENOSPC;

	for (i = 0; i < n_buffers; i++)
		d->buffers[i] = buffers[i];
	d->n_buffers = n_buffers;
	return 0;
}

static int do_render(struct spa_loop *loop, bool async, uint32_t seq,
		     const void *_data, size_t size, void *user_data)
{
	struct data *d = user_data;
	const struct spa_buffer *buf = *(struct spa_buffer**)_data;
	uint8_t *map;
	void *sdata, *ddata;
	int sstride, dstride, ostride;
	uint32_t i;
	uint8_t *src, *dst;
	struct spa_meta *m;
	struct spa_meta_region *r;

	handle_events(d);

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

	if ((m = spa_buffer_find_meta(buf, SPA_META_VideoDamage))) {
		spa_meta_for_each(r, m) {
			if (!spa_meta_region_is_valid(r))
				break;
			if (memcmp(&r->region, &d->region, sizeof(struct spa_region)) == 0)
				break;
			d->region = r->region;
			fprintf(stderr, "region %dx%d->%dx%d\n",
					r->region.position.x, r->region.position.y,
					r->region.size.width, r->region.size.height);
		}
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
	struct spa_buffer *buf;
	int res;

	if (d->io->status != SPA_STATUS_HAVE_DATA)
		return SPA_STATUS_NEED_DATA;

	if (d->io->buffer_id >= d->n_buffers)
		return SPA_STATUS_NEED_DATA;

	buf = d->buffers[d->io->buffer_id];

	if ((res = pw_loop_invoke(pw_main_loop_get_loop(d->loop), do_render,
				  SPA_ID_INVALID, &buf, sizeof(struct spa_buffer *),
				  false, d)) < 0)
		return res;

	update_param(d);

	return d->io->status = SPA_STATUS_NEED_DATA;
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

static void make_node(struct data *data)
{
	struct pw_properties *props;

	props = pw_properties_new(PW_KEY_NODE_AUTOCONNECT, "true", NULL);
	if (data->path)
		pw_properties_set(props, PW_KEY_NODE_TARGET, data->path);
	pw_properties_set(props, PW_KEY_MEDIA_CLASS, "Stream/Input/Video");
	pw_properties_set(props, PW_KEY_MEDIA_TYPE, "Video");
	pw_properties_set(props, PW_KEY_MEDIA_CATEGORY, "Capture");
	pw_properties_set(props, PW_KEY_MEDIA_ROLE, "Camera");

	data->impl_node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, data);
	pw_core_export(data->core, SPA_TYPE_INTERFACE_Node,
			&props->dict, &data->impl_node, 0);
	pw_properties_free(props);
}

static void set_permissions(struct data *data)
{
	struct pw_permission permissions[2];

	/* an example, set specific permissions on one object, this is the
	 * core object. */
	permissions[0] = PW_PERMISSION_INIT(PW_ID_CORE, PW_PERM_R | PW_PERM_X);
	/* remove WX from all other objects */
	permissions[1] = PW_PERMISSION_INIT(PW_ID_ANY, PW_PERM_R);

	pw_client_update_permissions(
			pw_core_get_client(data->core),
			2, permissions);
}

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct data *d = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE)
		pw_main_loop_quit(d->loop);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
};

int main(int argc, char *argv[])
{
	struct data data = { 0, };

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL);
	data.context = pw_context_new(pw_main_loop_get_loop(data.loop), NULL, 0);
	data.path = argc > 1 ? argv[1] : NULL;

	spa_hook_list_init(&data.hooks);

	data.info = SPA_PORT_INFO_INIT();
	data.info.change_mask = SPA_PORT_CHANGE_MASK_FLAGS;
	data.info.flags = 0;
	data.info.change_mask = SPA_PORT_CHANGE_MASK_PARAMS;
	data.params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	data.params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	data.params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	data.params[3] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	data.params[4] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	data.info.params = data.params;
	data.info.n_params = 5;

	reset_props(&data.props);

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		printf("can't initialize SDL: %s\n", SDL_GetError());
		return -1;
	}

	if (SDL_CreateWindowAndRenderer
	    (WIDTH, HEIGHT, SDL_WINDOW_RESIZABLE, &data.window, &data.renderer)) {
		printf("can't create window: %s\n", SDL_GetError());
		return -1;
	}

        data.core = pw_context_connect(data.context, NULL, 0);
	if (data.core == NULL) {
		printf("can't connect: %m\n");
		return -1;
	}
	pw_core_add_listener(data.core, &data.core_listener, &core_events, &data);

	set_permissions(&data);

	make_node(&data);

	pw_main_loop_run(data.loop);

	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	return 0;
}
