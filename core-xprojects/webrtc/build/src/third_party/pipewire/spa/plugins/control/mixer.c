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
#include <string.h>
#include <stdio.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/cpu.h>
#include <spa/utils/list.h>
#include <spa/utils/names.h>
#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>

#define NAME "control-mixer"

#define MAX_BUFFERS     64
#define MAX_PORTS       128

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_QUEUED	(1 << 0)
	uint32_t flags;

	struct spa_list link;
	struct spa_buffer *buffer;
};

struct port {
	uint32_t direction;
	uint32_t id;

	struct spa_io_buffers *io;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_param_info params[8];

	unsigned int valid:1;
	unsigned int have_format:1;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list queue;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[8];

	struct spa_hook_list hooks;

	uint32_t port_count;
	uint32_t last_port;
	struct port in_ports[MAX_PORTS];
	struct port out_ports[1];

	int n_formats;

	unsigned int have_format:1;
	unsigned int started:1;
};

#define CHECK_FREE_IN_PORT(this,d,p) ((d) == SPA_DIRECTION_INPUT && (p) < MAX_PORTS && !this->in_ports[(p)].valid)
#define CHECK_IN_PORT(this,d,p)      ((d) == SPA_DIRECTION_INPUT && (p) < MAX_PORTS && this->in_ports[(p)].valid)
#define CHECK_OUT_PORT(this,d,p)     ((d) == SPA_DIRECTION_OUTPUT && (p) == 0)
#define CHECK_PORT(this,d,p)         (CHECK_OUT_PORT(this,d,p) || CHECK_IN_PORT (this,d,p))
#define GET_IN_PORT(this,p)          (&this->in_ports[p])
#define GET_OUT_PORT(this,p)         (&this->out_ports[p])
#define GET_PORT(this,d,p)           (d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,p) : GET_OUT_PORT(this,p))

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	return -ENOTSUP;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	return -ENOTSUP;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	return -ENOTSUP;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		this->started = true;
		break;
	case SPA_NODE_COMMAND_Pause:
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
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_port_info(struct impl *this, struct port *port, bool full)
{
	if (full)
		port->info.change_mask = port->info_all;
	if (port->info.change_mask) {
		spa_node_emit_port_info(&this->hooks,
				port->direction, port->id, &port->info);
		port->info.change_mask = 0;
	}
}

static int impl_node_add_listener(void *object,
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
	emit_port_info(this, GET_OUT_PORT(this, 0), true);
	for (i = 0; i < this->last_port; i++) {
		if (this->in_ports[i].valid)
			emit_port_info(this, GET_IN_PORT(this, i), true);
	}

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *user_data)
{
	return 0;
}

static int impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_FREE_IN_PORT(this, direction, port_id), -EINVAL);

	port = GET_IN_PORT (this, port_id);
	port->direction = direction;
	port->id = port_id;

	spa_list_init(&port->queue);
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_NO_REF |
			   SPA_PORT_FLAG_DYNAMIC_DATA |
			   SPA_PORT_FLAG_REMOVABLE |
			   SPA_PORT_FLAG_OPTIONAL;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	this->port_count++;
	if (this->last_port <= port_id)
		this->last_port = port_id + 1;
	port->valid = true;

	spa_log_debug(this->log, NAME " %p: add port %d %d", this, port_id, this->last_port);
	emit_port_info(this, port, true);

	return 0;
}

static int
impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_IN_PORT(this, direction, port_id), -EINVAL);

	port = GET_IN_PORT (this, port_id);

	port->valid = false;
	this->port_count--;
	if (port->have_format && this->have_format) {
		if (--this->n_formats == 0)
			this->have_format = false;
	}
	spa_memzero(port, sizeof(struct port));

	if (port_id == this->last_port - 1) {
		int i;

		for (i = this->last_port - 1; i >= 0; i--)
			if (GET_IN_PORT (this, i)->valid)
				break;

		this->last_port = i + 1;
	}
	spa_log_debug(this->log, NAME " %p: remove port %d %d", this, port_id, this->last_port);

	spa_node_emit_port_info(&this->hooks, direction, port_id, NULL);

	return 0;
}

static int port_enum_formats(void *object,
			     enum spa_direction direction, uint32_t port_id,
			     uint32_t index,
			     struct spa_pod **param,
			     struct spa_pod_builder *builder)
{
	switch (index) {
	case 0:
		*param = spa_pod_builder_add_object(builder,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_application),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
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
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
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
		if ((res = port_enum_formats(this, direction, port_id, result.index, &param, &b)) <= 0)
			return res;
		break;

	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if ((res = port_enum_formats(this, direction, port_id, result.index, &param, &b)) <= 0)
			return res;
		break;

	case SPA_PARAM_Buffers:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(4096, 512, INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;

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
		spa_log_debug(this->log, NAME " %p: clear buffers %p", this, port);
		port->n_buffers = 0;
		spa_list_init(&port->queue);
	}
	return 0;
}

static int queue_buffer(struct impl *this, struct port *port, struct buffer *b)
{
	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_QUEUED))
		return -EINVAL;

	spa_list_append(&port->queue, &b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_QUEUED);
	spa_log_trace_fp(this->log, NAME " %p: queue buffer %d", this, b->id);
	return 0;
}

static struct buffer *dequeue_buffer(struct impl *this, struct port *port)
{
	struct buffer *b;

	if (spa_list_is_empty(&port->queue))
		return NULL;

	b = spa_list_first(&port->queue, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_QUEUED);
	spa_log_trace_fp(this->log, NAME " %p: dequeue buffer %d", this, b->id);
	return b;
}

static int port_set_format(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	struct impl *this = object;
	struct port *port;
	int res;

	port = GET_PORT(this, direction, port_id);

	if (format == NULL) {
		if (port->have_format) {
			port->have_format = false;
			if (--this->n_formats == 0)
				this->have_format = false;
			clear_buffers(this, port);
		}
	} else {
		uint32_t media_type, media_subtype;
		if ((res = spa_format_parse(format, &media_type, &media_subtype)) < 0)
			return res;

		if (media_type != SPA_MEDIA_TYPE_application ||
		    media_subtype != SPA_MEDIA_SUBTYPE_control)
			return -EINVAL;

		this->have_format = true;

		if (!port->have_format) {
			this->n_formats++;
			port->have_format = true;
			spa_log_debug(this->log, NAME " %p: set format on port %d:%d",
					this, direction, port_id);
		}
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

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	if (id == SPA_PARAM_Format) {
		return port_set_format(this, direction, port_id, flags, param);
	}
	else
		return -ENOENT;
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

	spa_log_debug(this->log, NAME " %p: use buffers %d on port %d:%d",
			this, n_buffers, direction, port_id);

	spa_return_val_if_fail(port->have_format, -EIO);

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;
		struct spa_data *d = buffers[i]->datas;

		b = &port->buffers[i];
		b->buffer = buffers[i];
		b->flags = 0;
		b->id = i;

		if (d[0].data == NULL) {
			spa_log_error(this->log, NAME " %p: invalid memory on buffer %d", this, i);
			return -EINVAL;
		}
		if (direction == SPA_DIRECTION_OUTPUT)
			queue_buffer(this, port, b);
	}
	port->n_buffers = n_buffers;

	return 0;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction, uint32_t port_id,
		      uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_log_debug(this->log, NAME " %p: port %d:%d io %d %p/%zd", this,
			direction, port_id, id, data, size);

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
	spa_return_val_if_fail(CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);
	port = GET_OUT_PORT(this, 0);

	if (buffer_id >= port->n_buffers)
		return -EINVAL;

	return queue_buffer(this, port, &port->buffers[buffer_id]);
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *outport;
	struct spa_io_buffers *outio;
	uint32_t n_seq, i;
        struct spa_pod_sequence **seq;
        struct spa_pod_control **ctrl;
	struct spa_pod_builder builder;
	struct spa_pod_frame f;
        struct buffer *outb;
	struct spa_data *d;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	outport = GET_OUT_PORT(this, 0);
	outio = outport->io;
	spa_return_val_if_fail(outio != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p: status %p %d %d",
			this, outio, outio->status, outio->buffer_id);

	if (outio->status == SPA_STATUS_HAVE_DATA)
		return outio->status;

	/* recycle */
	if (outio->buffer_id < outport->n_buffers) {
		queue_buffer(this, outport, &outport->buffers[outio->buffer_id]);
		outio->buffer_id = SPA_ID_INVALID;
	}

	/* get output buffer */
	if ((outb = dequeue_buffer(this, outport)) == NULL) {
                spa_log_trace(this->log, NAME " %p: out of buffers", this);
                return -EPIPE;
        }

	ctrl = alloca(MAX_PORTS * sizeof(struct spa_pod_control *));
	seq = alloca(MAX_PORTS * sizeof(struct spa_pod_sequence *));
        n_seq = 0;

	/* collect all sequence pod on input ports */
	for (i = 0; i < this->last_port; i++) {
		struct port *inport = GET_IN_PORT(this, i);
		struct spa_io_buffers *inio = NULL;
		void *pod;

		if (!inport->valid ||
		    (inio = inport->io) == NULL ||
		    inio->buffer_id >= inport->n_buffers ||
		    inio->status != SPA_STATUS_HAVE_DATA) {
			spa_log_trace_fp(this->log, NAME " %p: skip input idx:%d valid:%d "
					"io:%p status:%d buf_id:%d n_buffers:%d", this,
				i, inport->valid, inio,
				inio ? inio->status : -1,
				inio ? inio->buffer_id : SPA_ID_INVALID,
				inport->n_buffers);
			continue;
		}

		spa_log_trace_fp(this->log, NAME " %p: mix input %d %p->%p %d %d", this,
				i, inio, outio, inio->status, inio->buffer_id);

		d = inport->buffers[inio->buffer_id].buffer->datas;

		if ((pod = spa_pod_from_data(d->data, d->maxsize,
				d->chunk->offset, d->chunk->size)) == NULL)
			continue;
		if (!spa_pod_is_sequence(pod))
			continue;

		seq[n_seq] = pod;
		ctrl[n_seq] = spa_pod_control_first(&seq[n_seq]->body);
		inio->status = SPA_STATUS_NEED_DATA;
		n_seq++;
	}

	d = outb->buffer->datas;

	/* prepare to write into output */
	spa_pod_builder_init(&builder, d->data, d->maxsize);
	spa_pod_builder_push_sequence(&builder, &f, 0);

	/* merge sort all sequences into output buffer */
	while (true) {
		struct spa_pod_control *next = NULL;
		uint32_t next_index = 0;

		for (i = 0; i < n_seq; i++) {
			if (!spa_pod_control_is_inside(&seq[i]->body,
					SPA_POD_BODY_SIZE(seq[i]), ctrl[i]))
				continue;

			if (next == NULL || ctrl[i]->offset < next->offset) {
				next = ctrl[i];
				next_index = i;
			}
		}
		if (next == NULL)
			break;

		spa_pod_builder_control(&builder, next->offset, next->type);
		spa_pod_builder_primitive(&builder, &next->value);

		ctrl[next_index] = spa_pod_control_next(ctrl[next_index]);
	}
	spa_pod_builder_pop(&builder, &f);

	d->chunk->offset = 0;
	d->chunk->size = builder.state.offset;
	d->chunk->stride = 1;
	d->chunk->flags = 0;

	outio->buffer_id = outb->id;
	outio->status = SPA_STATUS_HAVE_DATA;

	return SPA_STATUS_HAVE_DATA | SPA_STATUS_NEED_DATA;
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
	struct port *port;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	spa_hook_list_init(&this->hooks);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = MAX_PORTS;
	this->info.max_output_ports = 1;
	this->info.change_mask |= SPA_NODE_CHANGE_MASK_FLAGS;
	this->info.flags = SPA_NODE_FLAG_RT | SPA_NODE_FLAG_IN_DYNAMIC_PORTS;

	port = GET_OUT_PORT(this, 0);
	port->valid = true;
	port->direction = SPA_DIRECTION_OUTPUT;
	port->id = 0;
	port->info = SPA_PORT_INFO_INIT();
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_FLAGS;
	port->info.flags = SPA_PORT_FLAG_DYNAMIC_DATA;
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	spa_list_init(&port->queue);

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

const struct spa_handle_factory spa_control_mixer_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_CONTROL_MIXER,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
