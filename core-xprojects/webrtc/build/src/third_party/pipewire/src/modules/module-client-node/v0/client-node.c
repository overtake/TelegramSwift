/* PipeWire
 *
 * Copyright © 2015 Wim Taymans <wim.taymans@gmail.com>
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

#include <string.h>
#include <stddef.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <sys/socket.h>
#include <sys/mman.h>

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/pod/filter.h>
#include <spa/utils/keys.h>

#include "pipewire/pipewire.h"
#include "pipewire/private.h"

#include "pipewire/context.h"
#include "modules/spa/spa-node.h"
#include "client-node.h"
#include "transport.h"

#define NAME "client-node0"

/** \cond */

#define MAX_INPUTS       64
#define MAX_OUTPUTS      64

#define MAX_BUFFERS      64

#define CHECK_IN_PORT_ID(this,d,p)       ((d) == SPA_DIRECTION_INPUT && (p) < MAX_INPUTS)
#define CHECK_OUT_PORT_ID(this,d,p)      ((d) == SPA_DIRECTION_OUTPUT && (p) < MAX_OUTPUTS)
#define CHECK_PORT_ID(this,d,p)          (CHECK_IN_PORT_ID(this,d,p) || CHECK_OUT_PORT_ID(this,d,p))
#define CHECK_FREE_IN_PORT(this,d,p)     (CHECK_IN_PORT_ID(this,d,p) && !(this)->in_ports[p].valid)
#define CHECK_FREE_OUT_PORT(this,d,p)    (CHECK_OUT_PORT_ID(this,d,p) && !(this)->out_ports[p].valid)
#define CHECK_FREE_PORT(this,d,p)        (CHECK_FREE_IN_PORT (this,d,p) || CHECK_FREE_OUT_PORT (this,d,p))
#define CHECK_IN_PORT(this,d,p)          (CHECK_IN_PORT_ID(this,d,p) && (this)->in_ports[p].valid)
#define CHECK_OUT_PORT(this,d,p)         (CHECK_OUT_PORT_ID(this,d,p) && (this)->out_ports[p].valid)
#define CHECK_PORT(this,d,p)             (CHECK_IN_PORT (this,d,p) || CHECK_OUT_PORT (this,d,p))

#define GET_IN_PORT(this,p)	(&this->in_ports[p])
#define GET_OUT_PORT(this,p)	(&this->out_ports[p])
#define GET_PORT(this,d,p)	(d == SPA_DIRECTION_INPUT ? GET_IN_PORT(this,p) : GET_OUT_PORT(this,p))

#define CHECK_PORT_BUFFER(this,b,p)      (b < p->n_buffers)

extern uint32_t pw_protocol_native0_type_from_v2(struct pw_impl_client *client, uint32_t type);
extern uint32_t pw_protocol_native0_name_to_v2(struct pw_impl_client *client, const char *name);

struct mem {
	uint32_t id;
	int ref;
	int fd;
	uint32_t type;
	uint32_t flags;
};

struct buffer {
	struct spa_buffer *outbuf;
	struct spa_buffer buffer;
	struct spa_meta metas[4];
	struct spa_data datas[4];
	bool outstanding;
	uint32_t memid;
};

struct port {
	uint32_t id;
	enum spa_direction direction;

	bool valid;
	struct spa_port_info info;
	struct pw_properties *properties;

	bool have_format;
	uint32_t n_params;
	struct spa_pod **params;
	struct spa_io_buffers *io;

	uint32_t n_buffers;
	struct buffer buffers[MAX_BUFFERS];
};

struct node {
	struct spa_node node;

	struct impl *impl;

	struct spa_log *log;
	struct spa_loop *data_loop;
	struct spa_system *data_system;

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	struct spa_io_position *position;

	struct pw_resource *resource;

	struct spa_source data_source;
	int writefd;

	struct spa_node_info info;

	uint32_t n_inputs;
	uint32_t n_outputs;
	struct port in_ports[MAX_INPUTS];
	struct port out_ports[MAX_OUTPUTS];

	uint32_t n_params;
	struct spa_pod **params;

	uint32_t seq;
	uint32_t init_pending;
};

struct impl {
	struct pw_impl_client_node0 this;

	bool client_reuse;

	struct pw_context *context;

	struct node node;

	struct pw_client_node0_transport *transport;

	struct spa_hook node_listener;
	struct spa_hook resource_listener;
	struct spa_hook object_listener;

	struct pw_array mems;

	int fds[2];
	int other_fds[2];

	uint32_t input_ready;
	bool out_pending;
};

/** \endcond */

static struct mem *ensure_mem(struct impl *impl, int fd, uint32_t type, uint32_t flags)
{
	struct mem *m, *f = NULL;

	pw_array_for_each(m, &impl->mems) {
		if (m->ref <= 0)
			f = m;
		else if (m->fd == fd)
			goto found;
	}

	if (f == NULL) {
		m = pw_array_add(&impl->mems, sizeof(struct mem));
		m->id = pw_array_get_len(&impl->mems, struct mem) - 1;
		m->ref = 0;
	}
	else {
		m = f;
	}
	m->fd = fd;
	m->type = type;
	m->flags = flags;

	pw_client_node0_resource_add_mem(impl->node.resource,
					m->id,
					type,
					m->fd,
					m->flags);
      found:
	m->ref++;
	return m;
}


static int clear_buffers(struct node *this, struct port *port)
{
	uint32_t i, j;
	struct impl *impl = this->impl;

	for (i = 0; i < port->n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		struct mem *m;

		spa_log_debug(this->log, "node %p: clear buffer %d", this, i);

		for (j = 0; j < b->buffer.n_datas; j++) {
			struct spa_data *d = &b->datas[j];

			if (d->type == SPA_DATA_DmaBuf ||
			    d->type == SPA_DATA_MemFd) {
				uint32_t id;

				id = SPA_PTR_TO_UINT32(b->buffer.datas[j].data);
				m = pw_array_get_unchecked(&impl->mems, id, struct mem);
				m->ref--;
			}
		}
		m = pw_array_get_unchecked(&impl->mems, b->memid, struct mem);
		m->ref--;
	}
	port->n_buffers = 0;
	return 0;
}

static void emit_port_info(struct node *this, struct port *port)
{
	spa_node_emit_port_info(&this->hooks,
				port->direction, port->id, &port->info);
}

static int impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct node *this = object;
	struct spa_hook_list save;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	for (i = 0; i < MAX_INPUTS; i++) {
		if (this->in_ports[i].valid)
			emit_port_info(this, &this->in_ports[i]);
	}
	for (i = 0; i < MAX_OUTPUTS; i++) {
		if (this->out_ports[i].valid)
			emit_port_info(this, &this->out_ports[i]);
	}
	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct node *this = object;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	struct spa_result_node_params result;
	uint32_t count = 0;
	bool found = false;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = 0;

	while (true) {
		struct spa_pod *param;

		result.index = result.next++;
		if (result.index >= this->n_params)
			break;

		param = this->params[result.index];

		if (param == NULL || !spa_pod_is_object_id(param, id))
			continue;

		found = true;

		if (result.index < start)
			continue;

		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		if (spa_pod_filter(&b, &result.param, param, filter) != 0)
			continue;

		pw_log_debug(NAME " %p: %d param %u", this, seq, result.index);
		spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

		if (++count == num)
			break;
	}
	return found ? 0 : -ENOENT;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (this->resource == NULL)
		return -EIO;

	pw_client_node0_resource_set_param(this->resource, this->seq, id, flags, param);

	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct node *this = object;
	int res = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch(id) {
	case SPA_IO_Position:
		this->position = data;
		break;
	default:
		res = -ENOTSUP;
		break;
	}
	return res;
}

static inline void do_flush(struct node *this)
{
	if (spa_system_eventfd_write(this->data_system, this->writefd, 1) < 0)
		spa_log_warn(this->log, "node %p: error flushing : %s", this, strerror(errno));

}

static int send_clock_update(struct node *this)
{
	struct pw_impl_client *client = this->resource->client;
	uint32_t type = pw_protocol_native0_name_to_v2(client, SPA_TYPE_INFO_NODE_COMMAND_BASE "ClockUpdate");
	struct timespec ts;
	int64_t now;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	now = SPA_TIMESPEC_TO_NSEC(&ts);
	pw_log_trace(NAME " %p: now %"PRIi64, this, now);

	struct spa_command_node0_clock_update cu =
		SPA_COMMAND_NODE0_CLOCK_UPDATE_INIT(type,
						SPA_COMMAND_NODE0_CLOCK_UPDATE_TIME |
						SPA_COMMAND_NODE0_CLOCK_UPDATE_SCALE |
						SPA_COMMAND_NODE0_CLOCK_UPDATE_STATE |
						SPA_COMMAND_NODE0_CLOCK_UPDATE_LATENCY,   /* change_mask */
						SPA_USEC_PER_SEC,       /* rate */
						now / SPA_NSEC_PER_USEC,       /* ticks */
						now,       /* monotonic_time */
						0,       /* offset */
						(1 << 16) | 1,   /* scale */
						SPA_CLOCK0_STATE_RUNNING, /* state */
						SPA_COMMAND_NODE0_CLOCK_UPDATE_FLAG_LIVE,       /* flags */
						0);      /* latency */

	pw_client_node0_resource_command(this->resource, this->seq, (const struct spa_command*)&cu);
	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	if (this->resource == NULL)
		return -EIO;

	if (SPA_NODE_COMMAND_ID(command) == SPA_NODE_COMMAND_Start) {
		send_clock_update(this);
	}

	pw_client_node0_resource_command(this->resource, this->seq, command);
	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *data)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	this->callbacks = SPA_CALLBACKS_INIT(callbacks, data);

	return 0;
}

static int
impl_node_sync(void *object, int seq)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	pw_log_debug(NAME " %p: sync %p", this, this->resource);

	if (this->resource == NULL)
		return -EIO;

	this->init_pending = SPA_RESULT_RETURN_ASYNC(this->seq++);

	return this->init_pending;
}


extern struct spa_pod *pw_protocol_native0_pod_from_v2(struct pw_impl_client *client, const struct spa_pod *pod);
extern int pw_protocol_native0_pod_to_v2(struct pw_impl_client *client, const struct spa_pod *pod,
		struct spa_pod_builder *b);

static void
do_update_port(struct node *this,
	       enum spa_direction direction,
	       uint32_t port_id,
	       uint32_t change_mask,
	       uint32_t n_params,
	       const struct spa_pod **params,
	       const struct spa_port_info *info)
{
	struct port *port;

	port = GET_PORT(this, direction, port_id);

	if (!port->valid) {
		spa_log_debug(this->log, "node %p: adding port %d, direction %d",
				this, port_id, direction);
		port->id = port_id;
		port->direction = direction;
		port->have_format = false;
		port->valid = true;

		if (direction == SPA_DIRECTION_INPUT)
			this->n_inputs++;
		else
			this->n_outputs++;
	}

	if (change_mask & PW_CLIENT_NODE0_PORT_UPDATE_PARAMS) {
		uint32_t i;

		port->have_format = false;

		spa_log_debug(this->log, "node %p: port %u update %d params", this, port_id, n_params);
		for (i = 0; i < port->n_params; i++)
			free(port->params[i]);
		port->n_params = n_params;
		port->params = realloc(port->params, port->n_params * sizeof(struct spa_pod *));

		for (i = 0; i < port->n_params; i++) {
			port->params[i] = params[i] ?
				pw_protocol_native0_pod_from_v2(this->resource->client, params[i]) : NULL;

			if (port->params[i] && spa_pod_is_object_id(port->params[i], SPA_PARAM_Format))
				port->have_format = true;
		}
	}

	if (change_mask & PW_CLIENT_NODE0_PORT_UPDATE_INFO) {
		if (port->properties)
			pw_properties_free(port->properties);
		port->properties = NULL;
		port->info.props = NULL;
		port->info.n_params = 0;
		port->info.params = NULL;

		if (info) {
			port->info = *info;
			if (info->props) {
				port->properties = pw_properties_new_dict(info->props);
				port->info.props = &port->properties->dict;
			}
		}
		spa_node_emit_port_info(&this->hooks, direction, port_id, info);
	}
}

static void
clear_port(struct node *this,
	   struct port *port, enum spa_direction direction, uint32_t port_id)
{
	do_update_port(this,
		       direction,
		       port_id,
		       PW_CLIENT_NODE0_PORT_UPDATE_PARAMS |
		       PW_CLIENT_NODE0_PORT_UPDATE_INFO, 0, NULL, NULL);
	clear_buffers(this, port);
}

static void do_uninit_port(struct node *this, enum spa_direction direction, uint32_t port_id)
{
	struct port *port;

	spa_log_debug(this->log, "node %p: removing port %d", this, port_id);

	if (direction == SPA_DIRECTION_INPUT) {
		port = GET_IN_PORT(this, port_id);
		this->n_inputs--;
	} else {
		port = GET_OUT_PORT(this, port_id);
		this->n_outputs--;
	}
	clear_port(this, port, direction, port_id);
	port->valid = false;
	spa_node_emit_port_info(&this->hooks, direction, port_id, NULL);
}

static int
impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	struct node *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_FREE_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);
	clear_port(this, port, direction, port_id);

	return 0;
}

static int
impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	do_uninit_port(this, direction, port_id);

	return 0;
}

static int
impl_node_port_enum_params(void *object, int seq,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t id, uint32_t start, uint32_t num,
			   const struct spa_pod *filter)
{
	struct node *this = object;
	struct port *port;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	struct spa_result_node_params result;
	uint32_t count = 0;
	bool found = false;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	pw_log_debug(NAME " %p: %d port %d.%d %u %u %u", this, seq,
			direction, port_id, id, start, num);

	result.id = id;
	result.next = 0;

	while (true) {
		struct spa_pod *param;

		result.index = result.next++;
		if (result.index >= port->n_params)
			break;

		param = port->params[result.index];

		if (param == NULL || !spa_pod_is_object_id(param, id))
			continue;

		found = true;

		if (result.index < start)
			continue;

		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		if (spa_pod_filter(&b, &result.param, param, filter) < 0)
			continue;

		pw_log_debug(NAME " %p: %d param %u", this, seq, result.index);
		spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

		if (++count == num)
			break;
	}
	return found ? 0 : -ENOENT;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct node *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	if (this->resource == NULL)
		return -EIO;

	pw_client_node0_resource_port_set_param(this->resource,
					       this->seq,
					       direction, port_id,
					       id, flags,
					       param);
	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction,
		      uint32_t port_id,
		      uint32_t id,
		      void *data, size_t size)
{
	struct node *this = object;
	struct impl *impl;
	struct pw_memblock *mem;
	struct mem *m;
	uint32_t memid, mem_offset, mem_size;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	impl = this->impl;

	spa_log_debug(this->log, "node %p: port %d.%d set io %d %p", this,
			direction, port_id, id, data);

	if (id == SPA_IO_Buffers) {
		struct port *port = GET_PORT(this, direction, port_id);
		port->io = data;
	}

	if (this->resource == NULL)
		return -EIO;


	if (data) {
		if ((mem = pw_mempool_find_ptr(impl->context->pool, data)) == NULL)
			return -EINVAL;

		mem_offset = SPA_PTRDIFF(data, mem->map->ptr);
		mem_size = mem->size;
		if (mem_size - mem_offset < size)
			return -EINVAL;

		mem_offset += mem->map->offset;
		m = ensure_mem(impl, mem->fd, SPA_DATA_MemFd, mem->flags);
		memid = m->id;
	}
	else {
		memid = SPA_ID_INVALID;
		mem_offset = mem_size = 0;
	}

	pw_client_node0_resource_port_set_io(this->resource,
					    this->seq,
					    direction, port_id,
					    id,
					    memid,
					    mem_offset, mem_size);
	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int
impl_node_port_use_buffers(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   struct spa_buffer **buffers,
			   uint32_t n_buffers)
{
	struct node *this = object;
	struct impl *impl;
	struct port *port;
	uint32_t i, j;
	struct pw_client_node0_buffer *mb;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	impl = this->impl;
	spa_log_debug(this->log, "node %p: use buffers %p %u", this, buffers, n_buffers);

	port = GET_PORT(this, direction, port_id);

	if (!port->have_format)
		return -EIO;

	clear_buffers(this, port);

	if (n_buffers > 0) {
		mb = alloca(n_buffers * sizeof(struct pw_client_node0_buffer));
	} else {
		mb = NULL;
	}

	port->n_buffers = n_buffers;

	if (this->resource == NULL)
		return -EIO;

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		struct pw_memblock *mem;
		struct mem *m;
		size_t data_size;
		void *baseptr;

		b->outbuf = buffers[i];
		memcpy(&b->buffer, buffers[i], sizeof(struct spa_buffer));
		b->buffer.datas = b->datas;
		b->buffer.metas = b->metas;

		if (buffers[i]->n_metas > 0)
			baseptr = buffers[i]->metas[0].data;
		else if (buffers[i]->n_datas > 0)
			baseptr = buffers[i]->datas[0].chunk;
		else
			return -EINVAL;

		if ((mem = pw_mempool_find_ptr(impl->context->pool, baseptr)) == NULL)
			return -EINVAL;

		data_size = 0;
		for (j = 0; j < buffers[i]->n_metas; j++) {
			data_size += buffers[i]->metas[j].size;
		}
		for (j = 0; j < buffers[i]->n_datas; j++) {
			struct spa_data *d = buffers[i]->datas;
			data_size += sizeof(struct spa_chunk);
			if (d->type == SPA_DATA_MemPtr)
				data_size += d->maxsize;
		}

		m = ensure_mem(impl, mem->fd, SPA_DATA_MemFd, mem->flags);
		b->memid = m->id;

		mb[i].buffer = &b->buffer;
		mb[i].mem_id = b->memid;
		mb[i].offset = SPA_PTRDIFF(baseptr, SPA_MEMBER(mem->map->ptr, mem->map->offset, void));
		mb[i].size = data_size;

		for (j = 0; j < buffers[i]->n_metas; j++)
			memcpy(&b->buffer.metas[j], &buffers[i]->metas[j], sizeof(struct spa_meta));
		b->buffer.n_metas = j;

		for (j = 0; j < buffers[i]->n_datas; j++) {
			struct spa_data *d = &buffers[i]->datas[j];

			memcpy(&b->buffer.datas[j], d, sizeof(struct spa_data));

			if (d->type == SPA_DATA_DmaBuf ||
			    d->type == SPA_DATA_MemFd) {
				m = ensure_mem(impl, d->fd, d->type, d->flags);
				b->buffer.datas[j].data = SPA_UINT32_TO_PTR(m->id);
			} else if (d->type == SPA_DATA_MemPtr) {
				b->buffer.datas[j].data = SPA_INT_TO_PTR(SPA_PTRDIFF(d->data, baseptr));
			} else {
				b->buffer.datas[j].type = SPA_ID_INVALID;
				b->buffer.datas[j].data = 0;
				spa_log_error(this->log, "invalid memory type %d", d->type);
			}
		}
	}

	pw_client_node0_resource_port_use_buffers(this->resource,
						 this->seq,
						 direction, port_id,
						 n_buffers, mb);

	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int
impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct node *this = object;
	struct impl *impl;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_OUT_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	impl = this->impl;

	spa_log_trace(this->log, "reuse buffer %d", buffer_id);

	pw_client_node0_transport_add_message(impl->transport, (struct pw_client_node0_message *)
			&PW_CLIENT_NODE0_MESSAGE_PORT_REUSE_BUFFER_INIT(port_id, buffer_id));
	do_flush(this);

	return 0;
}

static int impl_node_process_input(struct spa_node *node)
{
	struct node *this = SPA_CONTAINER_OF(node, struct node, node);
	struct impl *impl = this->impl;
//	bool client_reuse = impl->client_reuse;
	uint32_t i;
	int res;

	if (impl->input_ready == 0) {
		/* the client is not ready to receive our buffers, recycle them */
		pw_log_trace("node not ready, recycle buffers");
		for (i = 0; i < MAX_INPUTS; i++) {
			struct port *p = &this->in_ports[i];
			struct spa_io_buffers *io = p->io;

			if (!p->valid || io == NULL)
				continue;

			io->status = SPA_STATUS_NEED_DATA;
		}
		res = SPA_STATUS_NEED_DATA;
	}
	else {
		for (i = 0; i < MAX_INPUTS; i++) {
			struct port *p = &this->in_ports[i];
			struct spa_io_buffers *io = p->io;

			if (!p->valid || io == NULL)
				continue;

			pw_log_trace("set io status to %d %d", io->status, io->buffer_id);
			impl->transport->inputs[p->id] = *io;

			/* explicitly recycle buffers when the client is not going to do it */
//			if (!client_reuse && (pp = p->peer))
//		                spa_node_port_reuse_buffer(pp->node->implementation,
//						pp->port_id, io->buffer_id);
		}
		pw_client_node0_transport_add_message(impl->transport,
			       &PW_CLIENT_NODE0_MESSAGE_INIT(PW_CLIENT_NODE0_MESSAGE_PROCESS_INPUT));
		do_flush(this);

		impl->input_ready--;
		res = SPA_STATUS_OK;
	}
	return res;
}

#if 0
/** this is used for clients providing data to pipewire and currently
 * not supported in the compat layer */
static int impl_node_process_output(struct spa_node *node)
{
	struct node *this;
	struct impl *impl;
	uint32_t i;

	this = SPA_CONTAINER_OF(node, struct node, node);
	impl = this->impl;

	if (impl->out_pending)
		goto done;

	impl->out_pending = true;

	for (i = 0; i < MAX_OUTPUTS; i++) {
		struct port *p = &this->out_ports[i];
		struct spa_io_buffers *io = p->io;

		if (!p->valid || io == NULL)
			continue;

		impl->transport->outputs[p->id] = *io;

		pw_log_trace("%d %d -> %d %d", io->status, io->buffer_id,
				impl->transport->outputs[p->id].status,
				impl->transport->outputs[p->id].buffer_id);
	}

      done:
	pw_client_node0_transport_add_message(impl->transport,
			       &PW_CLIENT_NODE0_MESSAGE_INIT(PW_CLIENT_NODE0_MESSAGE_PROCESS_OUTPUT));
	do_flush(this);

	return SPA_STATUS_OK;
}
#endif

static int impl_node_process(void *object)
{
	struct node *this = object;
	struct impl *impl = this->impl;
	struct pw_impl_node *n = impl->this.node;

	return impl_node_process_input(n->node);
}

static int handle_node_message(struct node *this, struct pw_client_node0_message *message)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, node);
	uint32_t i;

	switch (PW_CLIENT_NODE0_MESSAGE_TYPE(message)) {
	case PW_CLIENT_NODE0_MESSAGE_HAVE_OUTPUT:
		for (i = 0; i < MAX_OUTPUTS; i++) {
			struct port *p = &this->out_ports[i];
			struct spa_io_buffers *io = p->io;
			if (!p->valid || io == NULL)
				continue;
			*io = impl->transport->outputs[p->id];
			pw_log_trace("have output %d %d", io->status, io->buffer_id);
		}
		impl->out_pending = false;
		spa_node_call_ready(&this->callbacks, SPA_STATUS_HAVE_DATA);
		break;

	case PW_CLIENT_NODE0_MESSAGE_NEED_INPUT:
		for (i = 0; i < MAX_INPUTS; i++) {
			struct port *p = &this->in_ports[i];
			struct spa_io_buffers *io = p->io;
			if (!p->valid || io == NULL)
				continue;
			pw_log_trace("need input %d %d", i, p->id);
			*io = impl->transport->inputs[p->id];
			pw_log_trace("need input %d %d", io->status, io->buffer_id);
		}
		impl->input_ready++;
		spa_node_call_ready(&this->callbacks, SPA_STATUS_NEED_DATA);
		break;

	case PW_CLIENT_NODE0_MESSAGE_PORT_REUSE_BUFFER:
		if (impl->client_reuse) {
			struct pw_client_node0_message_port_reuse_buffer *p =
			    (struct pw_client_node0_message_port_reuse_buffer *) message;
			spa_node_call_reuse_buffer(&this->callbacks, p->body.port_id.value,
					p->body.buffer_id.value);
		}
		break;

	default:
		pw_log_warn("unhandled message %d", PW_CLIENT_NODE0_MESSAGE_TYPE(message));
		return -ENOTSUP;
	}
	return 0;
}

static void setup_transport(struct impl *impl)
{
	struct node *this = &impl->node;
	uint32_t max_inputs = 0, max_outputs = 0, n_inputs = 0, n_outputs = 0;
	struct spa_dict_item items[1];

	n_inputs = this->n_inputs;
	max_inputs = this->info.max_input_ports == 0 ? this->n_inputs : this->info.max_input_ports;
	n_outputs = this->n_outputs;
	max_outputs = this->info.max_output_ports == 0 ? this->n_outputs : this->info.max_output_ports;

	impl->transport = pw_client_node0_transport_new(impl->context, max_inputs, max_outputs);
	impl->transport->area->n_input_ports = n_inputs;
	impl->transport->area->n_output_ports = n_outputs;

	if (n_inputs > 0) {
		items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_MEDIA_CLASS, "Stream/Input/Video");
	} else {
		items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_MEDIA_CLASS, "Stream/Output/Video");
	}
	pw_impl_node_update_properties(impl->this.node, &SPA_DICT_INIT(items, 1));
}

static void
client_node0_done(void *data, int seq, int res)
{
	struct impl *impl = data;
	struct node *this = &impl->node;

	if (seq == 0 && res == 0 && impl->transport == NULL)
		setup_transport(impl);

	pw_log_debug("seq:%d res:%d pending:%d", seq, res, this->init_pending);
	spa_node_emit_result(&this->hooks, seq, res, 0, NULL);

	if (this->init_pending != SPA_ID_INVALID) {
		spa_node_emit_result(&this->hooks, this->init_pending, res, 0, NULL);
		this->init_pending = SPA_ID_INVALID;
	}
}

static void
client_node0_update(void *data,
		   uint32_t change_mask,
		   uint32_t max_input_ports,
		   uint32_t max_output_ports,
		   uint32_t n_params,
		   const struct spa_pod **params)
{
	struct impl *impl = data;
	struct node *this = &impl->node;

	if (change_mask & PW_CLIENT_NODE0_UPDATE_MAX_INPUTS)
		this->info.max_input_ports = max_input_ports;
	if (change_mask & PW_CLIENT_NODE0_UPDATE_MAX_OUTPUTS)
		this->info.max_output_ports = max_output_ports;
	if (change_mask & PW_CLIENT_NODE0_UPDATE_PARAMS) {
		uint32_t i;
		spa_log_debug(this->log, "node %p: update %d params", this, n_params);

		for (i = 0; i < this->n_params; i++)
			free(this->params[i]);
		this->n_params = n_params;
		this->params = realloc(this->params, this->n_params * sizeof(struct spa_pod *));

		for (i = 0; i < this->n_params; i++)
			this->params[i] = params[i] ? spa_pod_copy(params[i]) : NULL;
	}
	if (change_mask & (PW_CLIENT_NODE0_UPDATE_MAX_INPUTS | PW_CLIENT_NODE0_UPDATE_MAX_OUTPUTS)) {
		spa_node_emit_info(&this->hooks, &this->info);
	}

	spa_log_debug(this->log, "node %p: got node update max_in %u, max_out %u", this,
		     this->info.max_input_ports, this->info.max_output_ports);
}

static void
client_node0_port_update(void *data,
			enum spa_direction direction,
			uint32_t port_id,
			uint32_t change_mask,
			uint32_t n_params,
			const struct spa_pod **params,
			const struct spa_port_info *info)
{
	struct impl *impl = data;
	struct node *this = &impl->node;
	bool remove;

	spa_log_debug(this->log, "node %p: got port update", this);
	if (!CHECK_PORT_ID(this, direction, port_id))
		return;

	remove = (change_mask == 0);

	if (remove) {
		do_uninit_port(this, direction, port_id);
	} else {
		do_update_port(this,
			       direction,
			       port_id,
			       change_mask,
			       n_params, params, info);
	}
}

static void client_node0_set_active(void *data, bool active)
{
	struct impl *impl = data;
	pw_impl_node_set_active(impl->this.node, active);
}

static void client_node0_event(void *data, struct spa_event *event)
{
	struct impl *impl = data;
	struct node *this = &impl->node;

	switch (SPA_EVENT_TYPE(event)) {
	case SPA_NODE0_EVENT_RequestClockUpdate:
		send_clock_update(this);
		break;
	default:
		spa_node_emit_event(&this->hooks, event);
	}
}

static struct pw_client_node0_methods client_node0_methods = {
	PW_VERSION_CLIENT_NODE0_METHODS,
	.done = client_node0_done,
	.update = client_node0_update,
	.port_update = client_node0_port_update,
	.set_active = client_node0_set_active,
	.event = client_node0_event,
};

static void node_on_data_fd_events(struct spa_source *source)
{
	struct node *this = source->data;
	struct impl *impl = this->impl;

	if (source->rmask & (SPA_IO_ERR | SPA_IO_HUP)) {
		spa_log_warn(this->log, "node %p: got error", this);
		return;
	}

	if (source->rmask & SPA_IO_IN) {
		struct pw_client_node0_message message;
		uint64_t cmd;

		if (spa_system_eventfd_read(this->data_system, this->data_source.fd, &cmd) < 0)
			spa_log_warn(this->log, "node %p: error reading message: %s",
					this, strerror(errno));

		while (pw_client_node0_transport_next_message(impl->transport, &message) == 1) {
			struct pw_client_node0_message *msg = alloca(SPA_POD_SIZE(&message));
			pw_client_node0_transport_parse_message(impl->transport, msg);
			handle_node_message(this, msg);
		}
	}
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_node_add_listener,
	.set_callbacks = impl_node_set_callbacks,
	.sync = impl_node_sync,
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

static int
node_init(struct node *this,
	  struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);
	this->data_system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);

	if (this->data_loop == NULL) {
		spa_log_error(this->log, "a data-loop is needed");
		return -EINVAL;
	}

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	this->data_source.func = node_on_data_fd_events;
	this->data_source.data = this;
	this->data_source.fd = -1;
	this->data_source.mask = SPA_IO_IN | SPA_IO_ERR | SPA_IO_HUP;
	this->data_source.rmask = 0;

	this->seq = 1;
	this->init_pending = SPA_ID_INVALID;

	return SPA_RESULT_RETURN_ASYNC(this->seq++);
}

static int node_clear(struct node *this)
{
	uint32_t i;

	for (i = 0; i < MAX_INPUTS; i++) {
		if (this->in_ports[i].valid)
			clear_port(this, &this->in_ports[i], SPA_DIRECTION_INPUT, i);
	}
	for (i = 0; i < MAX_OUTPUTS; i++) {
		if (this->out_ports[i].valid)
			clear_port(this, &this->out_ports[i], SPA_DIRECTION_OUTPUT, i);
	}

	return 0;
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct spa_source *source = user_data;
	spa_loop_remove_source(loop, source);
	return 0;
}

static void client_node0_resource_destroy(void *data)
{
	struct impl *impl = data;
	struct pw_impl_client_node0 *this = &impl->this;
	struct node *node = &impl->node;

	pw_log_debug("client-node %p: destroy", impl);

	impl->node.resource = this->resource = NULL;
	spa_hook_remove(&impl->resource_listener);
	spa_hook_remove(&impl->object_listener);

	if (node->data_source.fd != -1) {
		spa_loop_invoke(node->data_loop,
				do_remove_source,
				SPA_ID_INVALID,
				NULL,
				0,
				true,
				&node->data_source);
	}
	if (this->node)
		pw_impl_node_destroy(this->node);
}

static void node_initialized(void *data)
{
	struct impl *impl = data;
	struct pw_impl_client_node0 *this = &impl->this;
	struct pw_impl_node *node = this->node;
	struct spa_system *data_system = impl->node.data_system;

	if (this->resource == NULL)
		return;

	impl->fds[0] = spa_system_eventfd_create(data_system, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);
	impl->fds[1] = spa_system_eventfd_create(data_system, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);
	impl->node.data_source.fd = impl->fds[0];
	impl->node.writefd = impl->fds[1];
	impl->other_fds[0] = impl->fds[1];
	impl->other_fds[1] = impl->fds[0];

	spa_loop_add_source(impl->node.data_loop, &impl->node.data_source);
	pw_log_debug("client-node %p: transport fd %d %d", node, impl->fds[0], impl->fds[1]);

	pw_client_node0_resource_transport(this->resource,
					  pw_global_get_id(pw_impl_node_get_global(node)),
					  impl->other_fds[0],
					  impl->other_fds[1],
					  impl->transport);
}

static void node_free(void *data)
{
	struct impl *impl = data;
	struct pw_impl_client_node0 *this = &impl->this;
	struct spa_system *data_system = impl->node.data_system;

	this->node = NULL;

	pw_log_debug("client-node %p: free", &impl->this);
	node_clear(&impl->node);

	if (impl->transport)
		pw_client_node0_transport_destroy(impl->transport);

	spa_hook_remove(&impl->node_listener);

	if (this->resource)
		pw_resource_destroy(this->resource);

	pw_array_clear(&impl->mems);

	if (impl->fds[0] != -1)
		spa_system_close(data_system, impl->fds[0]);
	if (impl->fds[1] != -1)
		spa_system_close(data_system, impl->fds[1]);
	free(impl);
}

static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.free = node_free,
	.initialized = node_initialized,
};

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = client_node0_resource_destroy,
};

static void convert_properties(struct pw_properties *properties)
{
	struct {
		const char *from, *to;
	} props[] = {
		{ "pipewire.autoconnect", PW_KEY_NODE_AUTOCONNECT, },
		{ "pipewire.target.node", PW_KEY_NODE_TARGET, }
	};
	uint32_t i;
	const char *str;

	for(i = 0; i < SPA_N_ELEMENTS(props); i++) {
		if ((str = pw_properties_get(properties, props[i].from)) != NULL) {
			pw_properties_set(properties, props[i].to, str);
			pw_properties_set(properties, props[i].from, NULL);
		}
	}
}

/** Create a new client node
 * \param client an owner \ref pw_client
 * \param id an id
 * \param name a name
 * \param properties extra properties
 * \return a newly allocated client node
 *
 * Create a new \ref pw_impl_node.
 *
 * \memberof pw_impl_client_node
 */
struct pw_impl_client_node0 *pw_impl_client_node0_new(struct pw_resource *resource,
					  struct pw_properties *properties)
{
	struct impl *impl;
	struct pw_impl_client_node0 *this;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct pw_context *context = pw_impl_client_get_context(client);
	const struct spa_support *support;
	uint32_t n_support;
	const char *name;
	const char *str;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return NULL;

	this = &impl->this;

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL) {
		res = -errno;
		goto error_exit_free;
	}
	convert_properties(properties);

	pw_properties_setf(properties, PW_KEY_CLIENT_ID, "%d", client->global->id);

	impl->context = context;
	impl->fds[0] = impl->fds[1] = -1;
	pw_log_debug("client-node %p: new", impl);

	support = pw_context_get_support(impl->context, &n_support);

	node_init(&impl->node, NULL, support, n_support);
	impl->node.impl = impl;

	pw_array_init(&impl->mems, 64);

	if ((name = pw_properties_get(properties, "node.name")) == NULL)
		name = "client-node";
	pw_properties_set(properties, PW_KEY_MEDIA_TYPE, "Video");

	impl->node.resource = resource;
	this->resource = resource;
	this->node = pw_spa_node_new(context,
				     PW_SPA_NODE_FLAG_ASYNC,
				     &impl->node.node,
				     NULL,
				     properties, 0);
	if (this->node == NULL) {
		res = -errno;
		goto error_no_node;
	}

	str = pw_properties_get(properties, "pipewire.client.reuse");
	impl->client_reuse = str && pw_properties_parse_bool(str);

	pw_resource_add_listener(this->resource,
				 &impl->resource_listener,
				 &resource_events,
				 impl);
	pw_resource_add_object_listener(this->resource,
				&impl->object_listener,
				&client_node0_methods,
				impl);


	pw_impl_node_add_listener(this->node, &impl->node_listener, &node_events, impl);

	return this;

error_no_node:
	pw_resource_destroy(this->resource);
	node_clear(&impl->node);
error_exit_free:
	free(impl);
	errno = -res;
	return NULL;
}

/** Destroy a client node
 * \param node the client node to destroy
 * \memberof pw_impl_client_node
 */
void pw_impl_client_node0_destroy(struct pw_impl_client_node0 *node)
{
	pw_resource_destroy(node->resource);
}
