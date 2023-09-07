/* Spa jack client
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

#include <jack/jack.h>

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
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>

#include "jack-client.h"

#define NAME "jack-source"

#define MAX_PORTS 128
#define MAX_BUFFERS 8
#define MAX_SAMPLES 8192

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT (1<<0)
	uint32_t flags;
	struct spa_buffer *outbuf;
	struct spa_list link;
};

struct port {
	uint32_t id;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_dict_item items[4];
	struct spa_dict props;
	struct spa_param_info params[5];

	unsigned int have_format:1;
	struct spa_audio_info current_format;
	int stride;

	struct spa_io_buffers *io;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list empty;

	jack_port_t *jack_port;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_loop *data_loop;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[5];

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	struct spa_io_clock *clock;
	struct spa_io_position *position;

	struct port out_ports[MAX_PORTS];
	uint32_t n_out_ports;

	struct spa_audio_info current_format;

	struct spa_jack_client *client;
	struct spa_hook client_listener;

	unsigned int started:1;
};

#define CHECK_OUT_PORT(this,p)		((p) < this->n_out_ports)
#define CHECK_PORT(this,d,p)		(d == SPA_DIRECTION_OUTPUT && CHECK_OUT_PORT(this,p))
#define GET_OUT_PORT(this,p)		(&this->out_ports[p])
#define GET_PORT(this,d,p)		GET_OUT_PORT(this,p)

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
		return 0;

	case SPA_PARAM_Props:
		return 0;

	case SPA_PARAM_EnumFormat:
	case SPA_PARAM_Format:
		switch (result.index) {
		case 0:
			param = spa_format_audio_dsp_build(&b,
					id, &this->current_format.info.dsp);
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
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Clock),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_clock)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Position),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_position)));
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

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_IO_Clock:
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
	default:
		return -ENOENT;
	}
	return 0;
}


static inline void reuse_buffer(struct impl *this, struct port *port, uint32_t id)
{
	struct buffer *b = &port->buffers[id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		spa_log_trace(this->log, NAME " %p: reuse buffer %d", this, id);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
		spa_list_append(&port->empty, &b->link);
	}
}

static struct buffer *dequeue_buffer(struct impl *this, struct port *port)
{
	struct buffer *b;

	if (spa_list_is_empty(&port->empty))
		return NULL;

	b = spa_list_first(&port->empty, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

	return b;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		if (this->started)
			return 0;

		this->started = true;
		break;

	case SPA_NODE_COMMAND_Pause:
		if (!this->started)
			return 0;

		this->started = false;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static void emit_node_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		struct spa_dict_item items[5];
		char latency[64];
		snprintf(latency, sizeof(latency), "%d/%d",
				this->client->buffer_size, this->client->frame_rate);
		items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_MEDIA_CLASS, "Audio/Source");
		items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_NAME, "JACK System");
		items[2] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_DRIVER, "true");
		items[3] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_PAUSE_ON_IDLE, "false");
		items[4] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_LATENCY, latency);
		this->info.props = &SPA_DICT_INIT_ARRAY(items);
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_port_info(struct impl *this, struct port *port, bool full)
{
	if (full)
		port->info.change_mask = port->info_all;
	if (port->info.change_mask) {
		char* aliases[2];
		int n_aliases, n_items;

		aliases[0] = alloca(jack_port_name_size());
		aliases[1] = alloca(jack_port_name_size());
		n_aliases = jack_port_get_aliases(port->jack_port, aliases);
		n_items = 1;
		port->items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_NAME,
				jack_port_short_name(port->jack_port));
		if (n_aliases > 0)
			port->items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_OBJECT_PATH, aliases[0]);
		if (n_aliases > 1)
			port->items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_ALIAS, aliases[1]);
		port->props = SPA_DICT_INIT(port->items, n_items);

		spa_node_emit_port_info(&this->hooks,
				SPA_DIRECTION_OUTPUT, port->id, &port->info);
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
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	for (i = 0; i < this->n_out_ports; i++)
		emit_port_info(this, GET_OUT_PORT(this, i), true);

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

static void client_process(void *data)
{
	struct impl *this = data;
	int res;

	res = spa_node_process(&this->node);

	if (res != SPA_STATUS_OK)
		spa_node_call_ready(&this->callbacks, res);
}

static const struct spa_jack_client_events client_events = {
	SPA_VERSION_JACK_CLIENT_EVENTS,
	.process = client_process,
};

static int init_port(struct impl *this, struct port *port)
{
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PROPS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF;

	port->items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "32 bit float mono audio");
	port->props = SPA_DICT_INIT(port->items, 1);
	port->info.props = &port->props;

	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	spa_list_init(&port->empty);
	return 0;
}

static int init_ports(struct impl *this)
{
	const char **ports;
	jack_client_t *client = this->client->client;
	uint32_t i;
	int res;

	ports = jack_get_ports(client,
			NULL, JACK_DEFAULT_AUDIO_TYPE,
                        JackPortIsPhysical|JackPortIsOutput);
	if (ports == NULL) {
		spa_log_error(this->log, NAME" %p: can't enumerate ports", this);
		res = -ENODEV;
		goto exit;
	}

	for (i = 0; ports[i]; i++) {
		struct port *port = GET_OUT_PORT(this, i);
		jack_port_t *p = jack_port_by_name(client, ports[i]);
		char *aliases[2];
		int n_aliases;

		port->id = i;
		port->jack_port = jack_port_register(client,
				jack_port_short_name(p),
				jack_port_type(p),
				JackPortIsInput, 0);
		if (port->jack_port == NULL) {
			spa_log_error(this->log, NAME" %p: jack_port_register() %d (%s) failed",
					this, i, ports[i]);
			res = -EFAULT;
			goto exit_free;
		}

		aliases[0] = alloca(jack_port_name_size());
		aliases[1] = alloca(jack_port_name_size());

		n_aliases = jack_port_get_aliases(p, aliases);
		if (n_aliases > 0)
			jack_port_set_alias(port->jack_port, aliases[0]);
		if (n_aliases > 1)
			jack_port_set_alias(port->jack_port, aliases[1]);

		init_port(this, port);
	}
	this->n_out_ports = i;

	this->current_format.info.dsp = SPA_AUDIO_INFO_DSP_INIT(
			.format = SPA_AUDIO_FORMAT_DSP_F32);

	spa_jack_client_add_listener(this->client,
			&this->client_listener,
			&client_events, this);

	jack_activate(client);

	for (i = 0; ports[i]; i++) {
		struct port *port = GET_OUT_PORT(this, i);
		if (jack_connect(client, ports[i], jack_port_name(port->jack_port))) {
			spa_log_warn(this->log, NAME" %p: Failed to connect %s to %s",
					this, jack_port_name(port->jack_port), ports[i]);
            }
	}

	res = 0;
exit_free:
	jack_free(ports);
exit:
	return res;
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

static int port_enum_formats(struct impl *this,
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
			SPA_FORMAT_mediaType,       SPA_POD_Id(SPA_MEDIA_TYPE_audio),
			SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
			SPA_FORMAT_AUDIO_format,    SPA_POD_Id(SPA_AUDIO_FORMAT_DSP_F32));
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

	port = GET_PORT(this, direction, port_id);

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

		param = spa_format_audio_dsp_build(&b, id, &port->current_format.info.dsp);
		break;

	case SPA_PARAM_Buffers:
	{
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							MAX_SAMPLES * port->stride,
							16 * port->stride,
							MAX_SAMPLES * port->stride),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;
	}
	case SPA_PARAM_IO:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Buffers),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_buffers)));
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
		port->n_buffers = 0;
		spa_list_init(&port->empty);
		this->started = false;
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
	} else {
		struct spa_audio_info info = { 0 };

		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_audio &&
		    info.media_subtype != SPA_MEDIA_SUBTYPE_dsp)
			return -EINVAL;

		if (spa_format_audio_dsp_parse(format, &info.info.dsp) < 0)
			return -EINVAL;

		if (info.info.dsp.format != SPA_AUDIO_FORMAT_DSP_F32)
			return -EINVAL;

		port->stride = 4;
		port->current_format = info;
		port->have_format = true;
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
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

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

	port = GET_PORT(this, direction, port_id);

	if (!port->have_format)
		return -EIO;

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;

		b = &port->buffers[i];
		b->id = i;
		b->outbuf = buffers[i];
		b->flags = 0;
		spa_list_append(&port->empty, &b->link);
	}
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

	port = GET_PORT(this, direction, port_id);

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
	spa_return_val_if_fail(CHECK_OUT_PORT(this, port_id), -EINVAL);

	port = GET_OUT_PORT(this, port_id);

	spa_return_val_if_fail(buffer_id < port->n_buffers, -EINVAL);

	reuse_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	uint32_t i;
	int res = 0;

	spa_log_trace(this->log, NAME" %p: process %d", this, this->n_out_ports);

	for (i = 0; i < this->n_out_ports; i++) {
		struct port *port = GET_OUT_PORT(this, i);
		struct spa_io_buffers *io = port->io;
		struct buffer *b;
		struct spa_data *d;
		const void *src;
		uint32_t n_frames = this->client->buffer_size;

		if (io == NULL || io->status == SPA_STATUS_HAVE_DATA)
			continue;

		if (io->buffer_id < port->n_buffers) {
			reuse_buffer(this, port, io->buffer_id);
			io->buffer_id = SPA_ID_INVALID;
		}

		if ((b = dequeue_buffer(this, port)) == NULL) {
			spa_log_trace(this->log, NAME" %p: out of buffers", this);
			io->status = -EPIPE;
			continue;
		}

		src = jack_port_get_buffer(port->jack_port, n_frames);

		d = &b->outbuf->datas[0];
		spa_memcpy(d->data, src, n_frames * port->stride);
		d->chunk->offset = 0;
		d->chunk->size = n_frames * port->stride;
		d->chunk->stride = port->stride;
		d->chunk->flags = 0;

		io->buffer_id = b->id;
		io->status = SPA_STATUS_HAVE_DATA;

		res |= SPA_STATUS_HAVE_DATA;
	}
	return res;
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
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_JACK_CLIENT)))
		sscanf(str, "pointer:%p", &this->client);

	if (this->client == NULL) {
		spa_log_error(this->log, NAME" %p: missing "SPA_KEY_API_JACK_CLIENT
				" property", this);
		return -EINVAL;
	}

	spa_hook_list_init(&this->hooks);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_output_ports = MAX_PORTS;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->params[2] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READ);
	this->params[3] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	this->params[4] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	this->info.params = this->params;
	this->info.n_params = 5;

	init_ports(this);

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
	{ SPA_KEY_FACTORY_DESCRIPTION, "Record audio with the JACK API" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_jack_source_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_JACK_SOURCE,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
