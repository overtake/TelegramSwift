/* Spa
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

#include <errno.h>
#include <stddef.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/utils/list.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/node/keys.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>

#include "vulkan-utils.h"

#define NAME "vulkan-compute-source"

#define FRAMES_TO_TIME(this,f) ((this->position->video.framerate.denom * (f) * SPA_NSEC_PER_SEC) / \
                                (this->position->video.framerate.num))

#define DEFAULT_LIVE true

struct props {
	bool live;
};

static void reset_props(struct props *props)
{
	props->live = DEFAULT_LIVE;
}

#define MAX_PORTS 1

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT (1<<0)
	uint32_t flags;
	struct spa_buffer *outbuf;
	struct spa_meta_header *h;
	struct spa_list link;
};

struct port {
	uint64_t info_all;
	struct spa_port_info info;
	struct spa_param_info params[5];

	struct spa_io_buffers *io;

	bool have_format;
	struct spa_video_info current_format;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list empty;
	struct spa_list ready;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_loop *data_loop;
	struct spa_system *data_system;

	struct spa_io_clock *clock;
	struct spa_io_position *position;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[2];
	struct props props;

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	bool async;
	struct spa_source timer_source;
	struct itimerspec timerspec;

	bool started;
	uint64_t start_time;
	uint64_t elapsed_time;

	uint64_t frame_count;

	struct vulkan_state state;
	struct port port;
};

#define CHECK_PORT(this,d,p)  ((d) == SPA_DIRECTION_OUTPUT && (p) < MAX_PORTS)

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_PropInfo:
	{
		struct props *p = &this->props;

		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_live),
				SPA_PROP_INFO_name, SPA_POD_String("Configure live mode of the source"),
				SPA_PROP_INFO_type, SPA_POD_Bool(p->live));
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Props:
	{
		struct props *p = &this->props;

		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, id,
				SPA_PROP_live,        SPA_POD_Bool(p->live));
			break;
		default:
			return 0;
		}
		break;
	}
	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_IO_Clock:
		if (size > 0 && size < sizeof(struct spa_io_clock))
			return -EINVAL;
		this->clock = data;
		break;
	case SPA_IO_Position:
		this->position = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Props:
	{
		struct props *p = &this->props;

		if (param == NULL) {
			reset_props(p);
			return 0;
		}
		spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_Props, NULL,
			SPA_PROP_live,        SPA_POD_OPT_Bool(&p->live));

		if (p->live)
			this->info.flags |= SPA_PORT_FLAG_LIVE;
		else
			this->info.flags &= ~SPA_PORT_FLAG_LIVE;
		break;
	}
	default:
		return -ENOENT;
	}
	return 0;
}


static void set_timer(struct impl *this, bool enabled)
{
	if (this->async || this->props.live) {
		if (enabled) {
			if (this->props.live) {
				uint64_t next_time = this->start_time + this->elapsed_time;
				this->timerspec.it_value.tv_sec = next_time / SPA_NSEC_PER_SEC;
				this->timerspec.it_value.tv_nsec = next_time % SPA_NSEC_PER_SEC;
			} else {
				this->timerspec.it_value.tv_sec = 0;
				this->timerspec.it_value.tv_nsec = 1;
			}
		} else {
			this->timerspec.it_value.tv_sec = 0;
			this->timerspec.it_value.tv_nsec = 0;
		}
		spa_system_timerfd_settime(this->data_system,
				this->timer_source.fd, SPA_FD_TIMER_ABSTIME, &this->timerspec, NULL);
	}
}

static void read_timer(struct impl *this)
{
	uint64_t expirations;

	if (this->async || this->props.live) {
		if (spa_system_timerfd_read(this->data_system, this->timer_source.fd, &expirations) < 0)
			perror("read timerfd");
	}
}

static int make_buffer(struct impl *this)
{
	struct buffer *b;
	struct port *port = &this->port;
	uint32_t n_bytes;
	int res;

	read_timer(this);

	if ((res = spa_vulkan_ready(&this->state)) < 0) {
		res = SPA_STATUS_OK;
		goto next;
	}

	if (spa_list_is_empty(&port->empty)) {
		set_timer(this, false);
		spa_log_error(this->log, NAME " %p: out of buffers", this);
		return -EPIPE;
	}
	b = spa_list_first(&port->empty, struct buffer, link);
	spa_list_remove(&b->link);

	n_bytes = b->outbuf->datas[0].maxsize;

	spa_log_trace(this->log, NAME " %p: dequeue buffer %d", this, b->id);

	this->state.constants.time = this->elapsed_time / (float) SPA_NSEC_PER_SEC;
	this->state.constants.frame = this->frame_count;

	spa_vulkan_process(&this->state, b->id);

	if (this->state.ready_buffer_id != SPA_ID_INVALID) {
		struct buffer *b = &port->buffers[this->state.ready_buffer_id];

		this->state.ready_buffer_id = SPA_ID_INVALID;

		spa_log_trace(this->log, NAME " %p: ready buffer %d", this, b->id);

		b->outbuf->datas[0].chunk->offset = 0;
		b->outbuf->datas[0].chunk->size = n_bytes;
		b->outbuf->datas[0].chunk->stride = this->position->video.stride;

		if (b->h) {
			b->h->seq = this->frame_count;
			b->h->pts = this->start_time + this->elapsed_time;
			b->h->dts_offset = 0;
		}

		spa_list_append(&port->ready, &b->link);

		res = SPA_STATUS_HAVE_DATA;
	}
next:
	this->frame_count++;
	this->elapsed_time = FRAMES_TO_TIME(this, this->frame_count);
	set_timer(this, true);

	return res;
}

static inline void reuse_buffer(struct impl *this, struct port *port, uint32_t id)
{
	struct buffer *b = &port->buffers[id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		spa_log_trace(this->log, NAME " %p: reuse buffer %d", this, id);

		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
		spa_list_append(&port->empty, &b->link);

		if (!this->props.live)
			set_timer(this, true);
	}
}

static void on_output(struct spa_source *source)
{
	struct impl *this = source->data;
	struct port *port = &this->port;
	struct spa_io_buffers *io = port->io;
	int res;

	if (io == NULL)
		return;

	if (io->status == SPA_STATUS_HAVE_DATA)
		return;

	if (io->buffer_id < port->n_buffers) {
		reuse_buffer(this, port, io->buffer_id);
		io->buffer_id = SPA_ID_INVALID;
	}

	res = make_buffer(this);

	if (!spa_list_is_empty(&port->ready)) {
		struct buffer *b = spa_list_first(&port->ready, struct buffer, link);
		spa_list_remove(&b->link);
		SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

		io->buffer_id = b->id;
		io->status = SPA_STATUS_HAVE_DATA;
        }
	spa_node_call_ready(&this->callbacks, res);
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	port = &this->port;

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
	{
		struct timespec now;

		if (!port->have_format)
			return -EIO;
		if (port->n_buffers == 0)
			return -EIO;

		if (this->started)
			return 0;

		clock_gettime(CLOCK_MONOTONIC, &now);
		if (this->props.live)
			this->start_time = SPA_TIMESPEC_TO_NSEC(&now);
		else
			this->start_time = 0;
		this->frame_count = 0;
		this->elapsed_time = 0;

		this->started = true;
		set_timer(this, true);
		spa_vulkan_start(&this->state);
		break;
	}
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Pause:
		if (!this->started)
			return 0;

		this->started = false;
		set_timer(this, false);
		spa_vulkan_stop(&this->state);
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static const struct spa_dict_item node_info_items[] = {
	{ SPA_KEY_MEDIA_CLASS, "Video/Source" },
	{ SPA_KEY_NODE_DRIVER, "true" },
};

static void emit_node_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		this->info.props = &SPA_DICT_INIT_ARRAY(node_info_items);
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_port_info(struct impl *this, struct port *port, bool full)
{
	if (full)
		port->info.change_mask = port->info_all;
	if (port->info.change_mask) {
		struct spa_dict_item items[1];

		items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "32 bit float RGBA video");
		port->info.props = &SPA_DICT_INIT(items, 1);
		spa_node_emit_port_info(&this->hooks,
				SPA_DIRECTION_OUTPUT, 0, &port->info);
		port->info.change_mask = 0;
	}
}

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	emit_port_info(this, &this->port, true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *data)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	this->callbacks = SPA_CALLBACKS_INIT(callbacks, data);

	return 0;
}

static int impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	return -ENOTSUP;
}

static int
impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	return -ENOTSUP;
}

static int port_enum_formats(void *object,
			     enum spa_direction direction, uint32_t port_id,
			     uint32_t index,
			     const struct spa_pod *filter,
			     struct spa_pod **param,
			     struct spa_pod_builder *builder)
{
	switch (index) {
	case 0:
		*param = spa_pod_builder_add_object(builder,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,       SPA_POD_Id(SPA_MEDIA_TYPE_video),
			SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
			SPA_FORMAT_VIDEO_format,    SPA_POD_Id(SPA_VIDEO_FORMAT_DSP_F32));
		break;
	default:
		return 0;
	}
	return 1;
}

static int
impl_node_port_enum_params(void *object, int seq,
			enum spa_direction direction, uint32_t port_id,
			uint32_t id, uint32_t start, uint32_t num,
			const struct spa_pod *filter)
{
	struct impl *this = object;
	struct port *port;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_result_node_params result;
	uint32_t count = 0;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);
	port = &this->port;

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if ((res = port_enum_formats(this, direction, port_id,
						result.index, filter, &param, &b)) <= 0)
			return res;
		break;

	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_format_video_dsp_build(&b, id, &port->current_format.info.dsp);
		break;

	case SPA_PARAM_Buffers:
	{
		if (!port->have_format)
			return -EIO;
		if (this->position == NULL)
			return -EIO;
		if (result.index > 0)
			return 0;

		spa_log_debug(this->log, NAME" %p: %dx%d stride %d", this,
				this->position->video.size.width,
				this->position->video.size.height,
				this->position->video.stride);

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_Int(this->position->video.stride *
								this->position->video.size.height),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(this->position->video.stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;
	}
	case SPA_PARAM_Meta:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamMeta, id,
				SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
				SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
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

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int clear_buffers(struct impl *this, struct port *port)
{
	if (port->n_buffers > 0) {
		spa_log_debug(this->log, NAME " %p: clear buffers", this);
		spa_vulkan_use_buffers(&this->state, 0, 0, NULL);
		port->n_buffers = 0;
		spa_list_init(&port->empty);
		spa_list_init(&port->ready);
		this->started = false;
		set_timer(this, false);
	}
	return 0;
}

static int port_set_format(struct impl *this, struct port *port,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	int res;

	if (format == NULL) {
		port->have_format = false;
		clear_buffers(this, port);
		spa_vulkan_unprepare(&this->state);
	} else {
		struct spa_video_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_video &&
		    info.media_subtype != SPA_MEDIA_SUBTYPE_dsp)
			return -EINVAL;

		if (spa_format_video_dsp_parse(format, &info.info.dsp) < 0)
			return -EINVAL;

		if (info.info.dsp.format != SPA_VIDEO_FORMAT_DSP_F32)
			return -EINVAL;

		this->state.constants.width = this->position->video.size.width;
		this->state.constants.height = this->position->video.size.height;

		port->current_format = info;
		port->have_format = true;
		spa_vulkan_prepare(&this->state);
	}

	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	}
	emit_port_info(this, port, false);

	return 0;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct impl *this = object;
	struct port *port;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(node, direction, port_id), -EINVAL);
	port = &this->port;

	switch (id) {
	case SPA_PARAM_Format:
		res = port_set_format(this, port, flags, param);
		break;
	default:
		return -ENOENT;
	}
	return res;
}

static int
impl_node_port_use_buffers(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   struct spa_buffer **buffers,
			   uint32_t n_buffers)
{
	struct impl *this = object;
	struct port *port;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);
	port = &this->port;

	if (!port->have_format)
		return -EIO;

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;

		b = &port->buffers[i];
		b->id = i;
		b->outbuf = buffers[i];
		b->flags = 0;
		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		spa_list_append(&port->empty, &b->link);
	}
	spa_vulkan_use_buffers(&this->state, flags, n_buffers, buffers);
	port->n_buffers = n_buffers;

	return 0;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction,
		      uint32_t port_id,
		      uint32_t id,
		      void *data, size_t size)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);
	port = &this->port;

	switch (id) {
	case SPA_IO_Buffers:
		port->io = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(port_id == 0, -EINVAL);
	port = &this->port;
	spa_return_val_if_fail(buffer_id < port->n_buffers, -EINVAL);

	reuse_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *port;
	struct spa_io_buffers *io;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	port = &this->port;
	io = port->io;
	spa_return_val_if_fail(io != NULL, -EIO);

	if (io->status == SPA_STATUS_HAVE_DATA)
		return SPA_STATUS_HAVE_DATA;

	if (io->buffer_id < port->n_buffers) {
		reuse_buffer(this, port, io->buffer_id);
		io->buffer_id = SPA_ID_INVALID;
	}

	if (!this->props.live)
		return make_buffer(this);
	else
		return SPA_STATUS_OK;
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_node_add_listener,
	.set_callbacks = impl_node_set_callbacks,
	.enum_params = impl_node_enum_params,
	.set_param = impl_node_set_param,
	.set_io = impl_node_set_io,
	.send_command = impl_node_send_command,
	.add_port = impl_node_add_port,
	.remove_port = impl_node_remove_port,
	.port_enum_params = impl_node_port_enum_params,
	.port_set_param = impl_node_port_set_param,
	.port_use_buffers = impl_node_port_use_buffers,
	.port_set_io = impl_node_port_set_io,
	.port_reuse_buffer = impl_node_port_reuse_buffer,
	.process = impl_node_process,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Node) == 0)
		*interface = &this->node;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (this->data_loop)
		spa_loop_remove_source(this->data_loop, &this->timer_source);
	spa_system_close(this->data_system, this->timer_source.fd);

	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;
	struct port *port;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);
	this->data_system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);

	spa_hook_list_init(&this->hooks);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_output_ports = 1;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 2;
	reset_props(&this->props);

	this->timer_source.func = on_output;
	this->timer_source.data = this;
	this->timer_source.fd = spa_system_timerfd_create(this->data_system, CLOCK_MONOTONIC, SPA_FD_CLOEXEC);
	this->timer_source.mask = SPA_IO_IN;
	this->timer_source.rmask = 0;
	this->timerspec.it_value.tv_sec = 0;
	this->timerspec.it_value.tv_nsec = 0;
	this->timerspec.it_interval.tv_sec = 0;
	this->timerspec.it_interval.tv_nsec = 0;

	if (this->data_loop)
		spa_loop_add_source(this->data_loop, &this->timer_source);

	port = &this->port;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS |
			SPA_PORT_CHANGE_MASK_PROPS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF | SPA_PORT_FLAG_CAN_ALLOC_BUFFERS;
	if (this->props.live)
		this->info.flags |= SPA_PORT_FLAG_LIVE;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	spa_list_init(&port->empty);
	spa_list_init(&port->ready);

	this->state.log = this->log;

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Node,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*info = &impl_interfaces[*index];
		break;
	default:
		return 0;
	}
	(*index)++;
	return 1;
}

static const struct spa_dict_item info_items[] = {
	{ SPA_KEY_FACTORY_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "Generate video frames using a vulkan compute shader" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_vulkan_compute_source_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_VULKAN_COMPUTE_SOURCE,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
