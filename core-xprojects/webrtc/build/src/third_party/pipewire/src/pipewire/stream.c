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
#include <math.h>
#include <sys/mman.h>
#include <time.h>

#include <spa/buffer/alloc.h>
#include <spa/param/props.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/utils/ringbuffer.h>
#include <spa/pod/filter.h>
#include <spa/debug/format.h>
#include <spa/debug/types.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include "pipewire/stream.h"
#include "pipewire/private.h"

#define NAME "stream"

#define MAX_BUFFERS	64

#define MASK_BUFFERS	(MAX_BUFFERS-1)
#define MAX_PORTS	1

static bool mlock_warned = false;

static uint32_t mappable_dataTypes = (1<<SPA_DATA_MemFd);

struct buffer {
	struct pw_buffer this;
	uint32_t id;
#define BUFFER_FLAG_MAPPED	(1 << 0)
#define BUFFER_FLAG_QUEUED	(1 << 1)
#define BUFFER_FLAG_ADDED	(1 << 2)
	uint32_t flags;
	struct spa_meta_busy *busy;
};

struct queue {
	uint32_t ids[MAX_BUFFERS];
	struct spa_ringbuffer ring;
	uint64_t incount;
	uint64_t outcount;
};

struct data {
	struct pw_context *context;
	struct spa_hook stream_listener;
};

struct param {
	uint32_t id;
#define PARAM_FLAG_LOCKED	(1 << 0)
	uint32_t flags;
	struct spa_list link;
	struct spa_pod *param;
};

struct control {
	uint32_t id;
	uint32_t type;
	uint32_t container;
	struct spa_list link;
	struct pw_stream_control control;
	struct spa_pod *info;
	unsigned int emitted:1;
	float values[64];
};

struct stream {
	struct pw_stream this;

	const char *path;

	struct pw_context *context;
	struct spa_hook context_listener;

	enum spa_direction direction;
	enum pw_stream_flags flags;

	struct pw_impl_node *node;

	struct spa_node impl_node;
	struct spa_node_methods node_methods;
	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	struct spa_io_position *position;
	struct spa_io_buffers *io;
	struct {
		struct spa_io_position *position;
	} rt;

	uint32_t port_change_mask_all;
	struct spa_port_info port_info;
	struct pw_properties *port_props;
	struct spa_param_info port_params[5];

	struct spa_list param_list;

	uint32_t change_mask_all;
	struct spa_node_info info;
	struct spa_param_info params[1];

	uint32_t media_type;
	uint32_t media_subtype;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct queue dequeued;
	struct queue queued;

	struct data data;
	uintptr_t seq;
	struct pw_time time;
	uint64_t base_pos;
	uint32_t clock_id;

	unsigned int disconnecting:1;
	unsigned int disconnect_core:1;
	unsigned int draining:1;
	unsigned int drained:1;
	unsigned int allow_mlock:1;
	unsigned int warn_mlock:1;
	unsigned int process_rt:1;
};

static int get_param_index(uint32_t id)
{
	switch (id) {
	case SPA_PARAM_Props:
		return 0;
	default:
		return -1;
	}
}

static int get_port_param_index(uint32_t id)
{
	switch (id) {
	case SPA_PARAM_EnumFormat:
		return 0;
	case SPA_PARAM_Meta:
		return 1;
	case SPA_PARAM_IO:
		return 2;
	case SPA_PARAM_Format:
		return 3;
	case SPA_PARAM_Buffers:
		return 4;
	default:
		return -1;
	}
}

static void fix_datatype(const struct spa_pod *param)
{
	const struct spa_pod_prop *pod_param;
	const struct spa_pod *vals;
	uint32_t dataType, n_vals, choice;

	pod_param = spa_pod_find_prop(param, NULL, SPA_PARAM_BUFFERS_dataType);
	if (pod_param == NULL)
		return;

	vals = spa_pod_get_values(&pod_param->value, &n_vals, &choice);
	if (n_vals == 0)
		return;

	if (spa_pod_get_int(&vals[0], (int32_t*)&dataType) < 0)
		return;

	pw_log_debug(NAME" dataType: %u", dataType);
	if (dataType & (1u << SPA_DATA_MemPtr)) {
		SPA_POD_VALUE(struct spa_pod_int, &vals[0]) =
			dataType | mappable_dataTypes;
		pw_log_debug(NAME" Change dataType: %u -> %u", dataType,
				SPA_POD_VALUE(struct spa_pod_int, &vals[0]));
	}
}

static struct param *add_param(struct stream *impl,
		uint32_t id, uint32_t flags, const struct spa_pod *param)
{
	struct param *p;
	int idx;

	if (param == NULL || !spa_pod_is_object(param)) {
		errno = EINVAL;
		return NULL;
	}
	if (id == SPA_ID_INVALID)
		id = SPA_POD_OBJECT_ID(param);

	p = malloc(sizeof(struct param) + SPA_POD_SIZE(param));
	if (p == NULL)
		return NULL;

	if (id == SPA_PARAM_Buffers &&
	    SPA_FLAG_IS_SET(impl->flags, PW_STREAM_FLAG_MAP_BUFFERS) &&
	    impl->direction == SPA_DIRECTION_INPUT)
		fix_datatype(param);

	p->id = id;
	p->flags = flags;
	p->param = SPA_MEMBER(p, sizeof(struct param), struct spa_pod);
	memcpy(p->param, param, SPA_POD_SIZE(param));
	SPA_POD_OBJECT_ID(p->param) = id;

	spa_list_append(&impl->param_list, &p->link);

	if ((idx = get_param_index(id)) != -1) {
		impl->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
		impl->params[idx].flags ^= SPA_PARAM_INFO_SERIAL;
		impl->params[idx].flags |= SPA_PARAM_INFO_READ;
	} else if ((idx = get_port_param_index(id)) != -1) {
		impl->port_info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
		impl->port_params[idx].flags ^= SPA_PARAM_INFO_SERIAL;
		impl->port_params[idx].flags |= SPA_PARAM_INFO_READ;
	}

	return p;
}

static void clear_params(struct stream *impl, uint32_t id)
{
	struct param *p, *t;

	spa_list_for_each_safe(p, t, &impl->param_list, link) {
		if (id == SPA_ID_INVALID ||
		    (p->id == id && !(p->flags & PARAM_FLAG_LOCKED))) {
			spa_list_remove(&p->link);
			free(p);
		}
	}
}

static int update_params(struct stream *impl, uint32_t id,
		const struct spa_pod **params, uint32_t n_params)
{
	uint32_t i;
	int res = 0;

	if (id != SPA_ID_INVALID) {
		clear_params(impl, id);
	} else {
		for (i = 0; i < n_params; i++) {
			if (!spa_pod_is_object(params[i]))
				continue;
			clear_params(impl, SPA_POD_OBJECT_ID(params[i]));
		}
	}
	for (i = 0; i < n_params; i++) {
		if (add_param(impl, id, 0, params[i]) == NULL) {
			res = -errno;
			break;
		}
	}
	return res;
}


static inline int push_queue(struct stream *stream, struct queue *queue, struct buffer *buffer)
{
	uint32_t index;

	if (SPA_FLAG_IS_SET(buffer->flags, BUFFER_FLAG_QUEUED))
		return -EINVAL;

	SPA_FLAG_SET(buffer->flags, BUFFER_FLAG_QUEUED);
	queue->incount += buffer->this.size;

	spa_ringbuffer_get_write_index(&queue->ring, &index);
	queue->ids[index & MASK_BUFFERS] = buffer->id;
	spa_ringbuffer_write_update(&queue->ring, index + 1);

	return 0;
}

static inline struct buffer *pop_queue(struct stream *stream, struct queue *queue)
{
	int32_t avail;
	uint32_t index, id;
	struct buffer *buffer;

	if ((avail = spa_ringbuffer_get_read_index(&queue->ring, &index)) < 1) {
		errno = EPIPE;
		return NULL;
	}

	id = queue->ids[index & MASK_BUFFERS];
	spa_ringbuffer_read_update(&queue->ring, index + 1);

	buffer = &stream->buffers[id];
	queue->outcount += buffer->this.size;
	SPA_FLAG_CLEAR(buffer->flags, BUFFER_FLAG_QUEUED);

	return buffer;
}
static inline void clear_queue(struct stream *stream, struct queue *queue)
{
	spa_ringbuffer_init(&queue->ring);
	queue->incount = queue->outcount;
}

static bool stream_set_state(struct pw_stream *stream, enum pw_stream_state state, const char *error)
{
	enum pw_stream_state old = stream->state;
	bool res = old != state;

	if (res) {
		free(stream->error);
		stream->error = error ? strdup(error) : NULL;

		pw_log_debug(NAME" %p: update state from %s -> %s (%s)", stream,
			     pw_stream_state_as_string(old),
			     pw_stream_state_as_string(state), stream->error);

		if (state == PW_STREAM_STATE_ERROR)
			pw_log_error(NAME" %p: error %s", stream, error);

		stream->state = state;
		pw_stream_emit_state_changed(stream, old, state, error);
	}
	return res;
}

static struct buffer *get_buffer(struct pw_stream *stream, uint32_t id)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	if (id < impl->n_buffers)
		return &impl->buffers[id];

	errno = EINVAL;
	return NULL;
}

static int
do_call_process(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	struct pw_stream *stream = &impl->this;
	pw_log_trace(NAME" %p: do process", stream);
	pw_stream_emit_process(stream);
	return 0;
}

static void call_process(struct stream *impl)
{
	struct pw_stream *stream = &impl->this;
	pw_log_trace(NAME" %p: call process rt:%u", impl, impl->process_rt);
	if (impl->process_rt)
		pw_stream_emit_process(stream);
	else
		pw_loop_invoke(impl->context->main_loop,
			do_call_process, 1, NULL, 0, false, impl);
}

static int
do_call_drained(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	struct pw_stream *stream = &impl->this;
	pw_log_trace(NAME" %p: drained", stream);
	pw_stream_emit_drained(stream);
	return 0;
}

static void call_drained(struct stream *impl)
{
	pw_loop_invoke(impl->context->main_loop,
		do_call_drained, 1, NULL, 0, false, impl);
}

static int
do_set_position(struct spa_loop *loop,
		bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	impl->rt.position = impl->position;
	return 0;
}

static int impl_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;

	pw_log_debug(NAME" %p: set io id %d (%s) %p %zd", impl, id,
			spa_debug_type_find_name(spa_type_io, id), data, size);

	switch(id) {
	case SPA_IO_Position:
		if (data && size >= sizeof(struct spa_io_position))
			impl->position = data;
		else
			impl->position = NULL;
		pw_loop_invoke(impl->context->data_loop,
				do_set_position, 1, NULL, 0, true, impl);
		break;
	}
	pw_stream_emit_io_changed(stream, id, data, size);

	return 0;
}

static int enum_params(void *object, bool is_port, int seq, uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct stream *d = object;
	struct spa_result_node_params result;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	uint32_t count = 0;
	struct param *p;
	bool found = false;

	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = 0;

	pw_log_debug(NAME" %p: param id %d (%s) start:%d num:%d", d, id,
			spa_debug_type_find_name(spa_type_param, id),
			start, num);

	spa_list_for_each(p, &d->param_list, link) {
		struct spa_pod *param;

		result.index = result.next++;
		if (result.index < start)
			continue;

		param = p->param;
		if (param == NULL || p->id != id)
			continue;

		found = true;

		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		if (spa_pod_filter(&b, &result.param, param, filter) != 0)
			continue;

		spa_node_emit_result(&d->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

		if (++count == num)
			break;
	}
	return found ? 0 : -ENOENT;
}

static int impl_enum_params(void *object, int seq, uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	return enum_params(object, false, seq, id, start, num, filter);
}

static int impl_set_param(void *object, uint32_t id, uint32_t flags, const struct spa_pod *param)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;

	if (id != SPA_PARAM_Props)
		return -ENOTSUP;

	pw_stream_emit_param_changed(stream, id, param);
	return 0;
}

static int impl_send_command(void *object, const struct spa_command *command)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Flush:
	case SPA_NODE_COMMAND_Pause:
		pw_loop_invoke(impl->context->main_loop,
			NULL, 0, NULL, 0, false, impl);
		if (stream->state == PW_STREAM_STATE_STREAMING) {

			pw_log_debug(NAME" %p: pause", stream);
			stream_set_state(stream, PW_STREAM_STATE_PAUSED, NULL);
		}
		break;
	case SPA_NODE_COMMAND_Start:
		if (stream->state == PW_STREAM_STATE_PAUSED) {
			pw_log_debug(NAME" %p: start %d", stream, impl->direction);

			if (impl->direction == SPA_DIRECTION_INPUT)
				impl->io->status = SPA_STATUS_NEED_DATA;
			else
				call_process(impl);

			stream_set_state(stream, PW_STREAM_STATE_STREAMING, NULL);
		}
		break;
	case SPA_NODE_COMMAND_ParamBegin:
	case SPA_NODE_COMMAND_ParamEnd:
		break;
	default:
		pw_log_warn(NAME" %p: unhandled node command %d", stream,
				SPA_NODE_COMMAND_ID(command));
		break;
	}
	return 0;
}

static void emit_node_info(struct stream *d, bool full)
{
	if (full)
		d->info.change_mask = d->change_mask_all;
	if (d->info.change_mask != 0)
		spa_node_emit_info(&d->hooks, &d->info);
	d->info.change_mask = 0;
}

static void emit_port_info(struct stream *d, bool full)
{
	if (full)
		d->port_info.change_mask = d->port_change_mask_all;
	if (d->port_info.change_mask != 0)
		spa_node_emit_port_info(&d->hooks, d->direction, 0, &d->port_info);
	d->port_info.change_mask = 0;
}

static int impl_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct stream *d = object;
	struct spa_hook_list save;

	spa_hook_list_isolate(&d->hooks, &save, listener, events, data);

	emit_node_info(d, true);
	emit_port_info(d, true);

	spa_hook_list_join(&d->hooks, &save);

	return 0;
}

static int impl_set_callbacks(void *object,
			      const struct spa_node_callbacks *callbacks, void *data)
{
	struct stream *d = object;

	d->callbacks = SPA_CALLBACKS_INIT(callbacks, data);

	return 0;
}

static int impl_port_set_io(void *object, enum spa_direction direction, uint32_t port_id,
			    uint32_t id, void *data, size_t size)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;

	pw_log_debug(NAME" %p: set io id %d (%s) %p %zd", impl, id,
			spa_debug_type_find_name(spa_type_io, id), data, size);

	switch (id) {
	case SPA_IO_Buffers:
		if (data && size >= sizeof(struct spa_io_buffers))
			impl->io = data;
		else
			impl->io = NULL;
		break;
	}
	pw_stream_emit_io_changed(stream, id, data, size);

	return 0;
}

static int impl_port_enum_params(void *object, int seq,
				 enum spa_direction direction, uint32_t port_id,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	return enum_params(object, true, seq, id, start, num, filter);
}

static int map_data(struct stream *impl, struct spa_data *data, int prot)
{
	void *ptr;
	struct pw_map_range range;

	pw_map_range_init(&range, data->mapoffset, data->maxsize, impl->context->sc_pagesize);

	ptr = mmap(NULL, range.size, prot, MAP_SHARED, data->fd, range.offset);
	if (ptr == MAP_FAILED) {
		pw_log_error(NAME" %p: failed to mmap buffer mem: %m", impl);
		return -errno;
	}

	data->data = SPA_MEMBER(ptr, range.start, void);
	pw_log_debug(NAME" %p: fd %"PRIi64" mapped %d %d %p", impl, data->fd,
			range.offset, range.size, data->data);

	if (impl->allow_mlock && mlock(data->data, data->maxsize) < 0) {
		if (errno != ENOMEM || !mlock_warned) {
			pw_log(impl->warn_mlock ? SPA_LOG_LEVEL_WARN : SPA_LOG_LEVEL_DEBUG,
					NAME" %p: Failed to mlock memory %p %u: %s", impl,
					data->data, data->maxsize,
					errno == ENOMEM ?
					"This is not a problem but for best performance, "
					"consider increasing RLIMIT_MEMLOCK" : strerror(errno));
			mlock_warned |= errno == ENOMEM;
		}
	}
	return 0;
}

static int unmap_data(struct stream *impl, struct spa_data *data)
{
	struct pw_map_range range;

	pw_map_range_init(&range, data->mapoffset, data->maxsize, impl->context->sc_pagesize);

	if (munmap(SPA_MEMBER(data->data, -range.start, void), range.size) < 0)
		pw_log_warn(NAME" %p: failed to unmap: %m", impl);

	pw_log_debug(NAME" %p: fd %"PRIi64" unmapped", impl, data->fd);
	return 0;
}

static void clear_buffers(struct pw_stream *stream)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	uint32_t i, j;

	pw_log_debug(NAME" %p: clear buffers %d", stream, impl->n_buffers);

	for (i = 0; i < impl->n_buffers; i++) {
		struct buffer *b = &impl->buffers[i];

		if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_ADDED))
			pw_stream_emit_remove_buffer(stream, &b->this);

		if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_MAPPED)) {
			for (j = 0; j < b->this.buffer->n_datas; j++) {
				struct spa_data *d = &b->this.buffer->datas[j];
				pw_log_debug(NAME" %p: clear buffer %d mem",
						stream, b->id);
				unmap_data(impl, d);
			}
		}
	}
	impl->n_buffers = 0;
	clear_queue(impl, &impl->dequeued);
	clear_queue(impl, &impl->queued);
}

static int impl_port_set_param(void *object,
			       enum spa_direction direction, uint32_t port_id,
			       uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;
	int res;

	if (impl->disconnecting && param != NULL)
		return -EIO;

	pw_log_debug(NAME" %p: param id %d (%s) changed: %p", impl, id,
			spa_debug_type_find_name(spa_type_param, id), param);

	if (param)
		pw_log_pod(SPA_LOG_LEVEL_DEBUG, param);

	if ((res = update_params(impl, id, &param, param ? 1 : 0)) < 0)
		return res;

	if (id == SPA_PARAM_Format)
		clear_buffers(stream);

	pw_stream_emit_param_changed(stream, id, param);

	if (stream->state == PW_STREAM_STATE_ERROR)
		return -EIO;

	emit_port_info(impl, false);

	return 0;
}

static int impl_port_use_buffers(void *object,
		enum spa_direction direction, uint32_t port_id,
		uint32_t flags,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;
	uint32_t i, j, impl_flags = impl->flags;
	int prot, res;
	int size = 0;

	if (impl->disconnecting && n_buffers > 0)
		return -EIO;

	prot = PROT_READ | (direction == SPA_DIRECTION_OUTPUT ? PROT_WRITE : 0);

	clear_buffers(stream);

	for (i = 0; i < n_buffers; i++) {
		int buf_size = 0;
		struct buffer *b = &impl->buffers[i];

		b->flags = 0;
		b->id = i;

		if (SPA_FLAG_IS_SET(impl_flags, PW_STREAM_FLAG_MAP_BUFFERS)) {
			for (j = 0; j < buffers[i]->n_datas; j++) {
				struct spa_data *d = &buffers[i]->datas[j];
				if ((mappable_dataTypes & (1<<d->type)) > 0) {
					if ((res = map_data(impl, d, prot)) < 0)
						return res;
					SPA_FLAG_SET(b->flags, BUFFER_FLAG_MAPPED);
				}
				else if (d->type == SPA_DATA_MemPtr && d->data == NULL) {
					pw_log_error(NAME" %p: invalid buffer mem", stream);
					return -EINVAL;
				}
				buf_size += d->maxsize;
			}

			if (size > 0 && buf_size != size) {
				pw_log_error(NAME" %p: invalid buffer size %d", stream, buf_size);
				return -EINVAL;
			} else
				size = buf_size;
		}
		pw_log_debug(NAME" %p: got buffer id:%d datas:%d, mapped size %d", stream, i,
				buffers[i]->n_datas, size);
	}

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &impl->buffers[i];

		b->this.buffer = buffers[i];
		b->busy = spa_buffer_find_meta_data(buffers[i], SPA_META_Busy, sizeof(*b->busy));

		if (impl->direction == SPA_DIRECTION_OUTPUT) {
			pw_log_trace(NAME" %p: recycle buffer %d", stream, b->id);
			push_queue(impl, &impl->dequeued, b);
		}

		SPA_FLAG_SET(b->flags, BUFFER_FLAG_ADDED);

		pw_stream_emit_add_buffer(stream, &b->this);
	}

	impl->n_buffers = n_buffers;

	return 0;
}

static int impl_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct stream *d = object;
	pw_log_trace(NAME" %p: recycle buffer %d", d, buffer_id);
	if (buffer_id < d->n_buffers)
		push_queue(d, &d->queued, &d->buffers[buffer_id]);
	return 0;
}

static inline void copy_position(struct stream *impl, int64_t queued)
{
	struct spa_io_position *p = impl->rt.position;
	if (SPA_UNLIKELY(p != NULL)) {
		SEQ_WRITE(impl->seq);
		impl->time.now = p->clock.nsec;
		impl->time.rate = p->clock.rate;
		if (SPA_UNLIKELY(impl->clock_id != p->clock.id)) {
			impl->base_pos = p->clock.position - impl->time.ticks;
			impl->clock_id = p->clock.id;
		}
		impl->time.ticks = p->clock.position - impl->base_pos;
		impl->time.delay = p->clock.delay;
		impl->time.queued = queued;
		SEQ_WRITE(impl->seq);
	}
}

static int impl_node_process_input(void *object)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;
	struct spa_io_buffers *io = impl->io;
	struct buffer *b;

	pw_log_trace(NAME" %p: process in status:%d id:%d ticks:%"PRIu64" delay:%"PRIi64,
			stream, io->status, io->buffer_id, impl->time.ticks, impl->time.delay);

	if (io->status == SPA_STATUS_HAVE_DATA &&
	    (b = get_buffer(stream, io->buffer_id)) != NULL) {
		/* push new buffer */
		if (push_queue(impl, &impl->dequeued, b) == 0) {
			copy_position(impl, impl->dequeued.incount);
			if (b->busy)
				ATOMIC_INC(b->busy->count);
			call_process(impl);
		}
	}
	if (io->status != SPA_STATUS_NEED_DATA) {
		/* pop buffer to recycle */
		if ((b = pop_queue(impl, &impl->queued))) {
			pw_log_trace(NAME" %p: recycle buffer %d", stream, b->id);
		} else if (io->status == -EPIPE)
			return io->status;
		io->buffer_id = b ? b->id : SPA_ID_INVALID;
		io->status = SPA_STATUS_NEED_DATA;
	}
	return SPA_STATUS_NEED_DATA | SPA_STATUS_HAVE_DATA;
}

static int impl_node_process_output(void *object)
{
	struct stream *impl = object;
	struct pw_stream *stream = &impl->this;
	struct spa_io_buffers *io = impl->io;
	struct buffer *b;
	int res;
	uint32_t index;

again:
	pw_log_trace(NAME" %p: process out status:%d id:%d", stream,
			io->status, io->buffer_id);

	if ((res = io->status) != SPA_STATUS_HAVE_DATA) {
		/* recycle old buffer */
		if ((b = get_buffer(stream, io->buffer_id)) != NULL) {
			pw_log_trace(NAME" %p: recycle buffer %d", stream, b->id);
			push_queue(impl, &impl->dequeued, b);
		}

		/* pop new buffer */
		if ((b = pop_queue(impl, &impl->queued)) != NULL) {
			impl->drained = false;
			io->buffer_id = b->id;
			res = io->status = SPA_STATUS_HAVE_DATA;
			pw_log_trace(NAME" %p: pop %d %p", stream, b->id, io);
		} else if (impl->draining || impl->drained) {
			impl->draining = true;
			impl->drained = true;
			io->buffer_id = SPA_ID_INVALID;
			res = io->status = SPA_STATUS_DRAINED;
			pw_log_trace(NAME" %p: draining", stream);
		} else {
			io->buffer_id = SPA_ID_INVALID;
			res = io->status = SPA_STATUS_NEED_DATA;
			pw_log_trace(NAME" %p: no more buffers %p", stream, io);
		}
	}

	copy_position(impl, impl->queued.outcount);

	if (!impl->draining &&
	    !SPA_FLAG_IS_SET(impl->flags, PW_STREAM_FLAG_DRIVER)) {
		/* we're not draining, not a driver check if we need to get
		 * more buffers */
		if (!impl->process_rt) {
			/* not realtime and we have a free buffer, trigger process so that we have
			 * data in the next round. */
			if (spa_ringbuffer_get_read_index(&impl->dequeued.ring, &index) > 0)
				call_process(impl);
		} else if (io->status == SPA_STATUS_NEED_DATA) {
			/* realtime and we don't have a buffer, trigger process and try
			 * again when there is something in the queue now */
			call_process(impl);
			if (impl->draining ||
			    spa_ringbuffer_get_read_index(&impl->queued.ring, &index) > 0)
				goto again;
		}
	}

	pw_log_trace(NAME" %p: res %d", stream, res);

	return res;
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_add_listener,
	.set_callbacks = impl_set_callbacks,
	.enum_params = impl_enum_params,
	.set_param = impl_set_param,
	.set_io = impl_set_io,
	.send_command = impl_send_command,
	.port_set_io = impl_port_set_io,
	.port_enum_params = impl_port_enum_params,
	.port_set_param = impl_port_set_param,
	.port_use_buffers = impl_port_use_buffers,
	.port_reuse_buffer = impl_port_reuse_buffer,
};

static void proxy_removed(void *_data)
{
	struct pw_stream *stream = _data;
	pw_log_debug(NAME" %p: removed", stream);
	spa_hook_remove(&stream->proxy_listener);
	stream->node_id = SPA_ID_INVALID;
	stream_set_state(stream, PW_STREAM_STATE_UNCONNECTED, NULL);
}

static void proxy_destroy(void *_data)
{
	struct pw_stream *stream = _data;
	pw_log_debug(NAME" %p: destroy", stream);
	proxy_removed(_data);
}

static void proxy_error(void *_data, int seq, int res, const char *message)
{
	struct pw_stream *stream = _data;
	stream_set_state(stream, PW_STREAM_STATE_ERROR, message);
}

static void proxy_bound(void *data, uint32_t global_id)
{
	struct pw_stream *stream = data;
	stream->node_id = global_id;
	stream_set_state(stream, PW_STREAM_STATE_PAUSED, NULL);
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = proxy_removed,
	.destroy = proxy_destroy,
	.error = proxy_error,
	.bound = proxy_bound,
};

static struct control *find_control(struct pw_stream *stream, uint32_t id)
{
	struct control *c;
	spa_list_for_each(c, &stream->controls, link) {
		if (c->id == id)
			return c;
	}
	return NULL;
}

static int node_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		struct spa_pod *param)
{
	struct pw_stream *stream = object;

	switch (id) {
	case SPA_PARAM_PropInfo:
	{
		struct control *c;
		const struct spa_pod *type, *pod;
		uint32_t iid, choice, n_vals, container = SPA_ID_INVALID;
		float *vals, bool_range[3] = { 1.0, 0.0, 1.0 };

		if (spa_pod_parse_object(param,
					SPA_TYPE_OBJECT_PropInfo, NULL,
					SPA_PROP_INFO_id,   SPA_POD_Id(&iid)) < 0)
			return -EINVAL;

		c = find_control(stream, iid);
		if (c != NULL)
			return 0;

		c = calloc(1, sizeof(*c) + SPA_POD_SIZE(param));
		c->info = SPA_MEMBER(c, sizeof(*c), struct spa_pod);
		memcpy(c->info, param, SPA_POD_SIZE(param));
		c->control.n_values = 0;
		c->control.max_values = 0;
		c->control.values = c->values;

		if (spa_pod_parse_object(c->info,
					SPA_TYPE_OBJECT_PropInfo, NULL,
					SPA_PROP_INFO_name, SPA_POD_String(&c->control.name),
					SPA_PROP_INFO_type, SPA_POD_PodChoice(&type),
					SPA_PROP_INFO_container, SPA_POD_OPT_Id(&container)) < 0) {
			free(c);
			return -EINVAL;
		}

		spa_list_append(&stream->controls, &c->link);

		pod = spa_pod_get_values(type, &n_vals, &choice);

		c->type = SPA_POD_TYPE(pod);
		if (spa_pod_is_float(pod))
			vals = SPA_POD_BODY(pod);
		else if (spa_pod_is_bool(pod) && n_vals > 0) {
			choice = SPA_CHOICE_Range;
			vals = bool_range;
			vals[0] = SPA_POD_VALUE(struct spa_pod_bool, pod);
			n_vals = 3;
		}
		else
			return -ENOTSUP;

		c->container = container != SPA_ID_INVALID ? container : c->type;

		switch (choice) {
		case SPA_CHOICE_None:
			if (n_vals < 1)
				return -EINVAL;
			c->control.n_values = 1;
			c->control.max_values = 1;
			c->control.values[0] = c->control.def = c->control.min = c->control.max = vals[0];
			break;
		case SPA_CHOICE_Range:
			if (n_vals < 3)
				return -EINVAL;
			c->control.n_values = 1;
			c->control.max_values = 1;
			c->control.values[0] = vals[0];
			c->control.def = vals[0];
			c->control.min = vals[1];
			c->control.max = vals[2];
			break;
		default:
			return -ENOTSUP;
		}

		c->id = iid;
		pw_log_debug(NAME" %p: add control %d (%s) container:%d (def:%f min:%f max:%f)",
				stream, c->id, c->control.name, c->container,
				c->control.def, c->control.min, c->control.max);
		break;
	}
	case SPA_PARAM_Props:
	{
		struct spa_pod_prop *prop;
		struct spa_pod_object *obj = (struct spa_pod_object *) param;
		union {
			float f;
			bool b;
		} value;
		float *values;
		uint32_t i, n_values;

		SPA_POD_OBJECT_FOREACH(obj, prop) {
			struct control *c;

			c = find_control(stream, prop->key);
			if (c == NULL)
				continue;

			switch (c->container) {
			case SPA_TYPE_Float:
				if (spa_pod_get_float(&prop->value, &value.f) < 0)
					continue;
				n_values = 1;
				values = &value.f;
				break;
			case SPA_TYPE_Bool:
				if (spa_pod_get_bool(&prop->value, &value.b) < 0)
					continue;
				value.f = value.b ? 1.0 : 0.0;
				n_values = 1;
				values = &value.f;
				break;
			case SPA_TYPE_Array:
				if ((values = spa_pod_get_array(&prop->value, &n_values)) == NULL ||
				    !spa_pod_is_float(SPA_POD_ARRAY_CHILD(&prop->value)))
					continue;
				break;
			default:
				continue;
			}

			if (c->emitted && c->control.n_values == n_values &&
			    memcmp(c->control.values, values, sizeof(float) * n_values) == 0)
				continue;

			memcpy(c->control.values, values, sizeof(float) * n_values);
			c->control.n_values = n_values;
			c->emitted = true;

			pw_log_debug(NAME" %p: control %d (%s) changed %d:", stream,
					prop->key, c->control.name, n_values);
			for (i = 0; i < n_values; i++)
				pw_log_debug(NAME" %p:  value %d %f", stream, i, values[i]);

			pw_stream_emit_control_info(stream, prop->key, &c->control);
		}
		break;
	}
	default:
		break;
	}
	return 0;
}

static void node_event_info(void *object, const struct pw_node_info *info)
{
	struct pw_stream *stream = object;
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	uint32_t i;

	if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			switch (info->params[i].id) {
			case SPA_PARAM_PropInfo:
			case SPA_PARAM_Props:
				pw_impl_node_for_each_param(impl->node,
						0, info->params[i].id,
						0, UINT32_MAX,
						NULL,
						node_event_param,
						stream);
				break;
			default:
				break;
			}
		}
	}
}

static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.info_changed = node_event_info,
};

static void on_core_error(void *object, uint32_t id, int seq, int res, const char *message)
{
	struct pw_stream *stream = object;

	pw_log_debug(NAME" %p: error id:%u seq:%d res:%d (%s): %s", stream,
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE) {
		stream_set_state(stream, PW_STREAM_STATE_UNCONNECTED, message);
	}
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
};

static void context_drained(void *data, struct pw_impl_node *node)
{
	struct stream *impl = data;
	if (impl->node != node)
		return;
	if (impl->draining && impl->drained) {
		impl->draining = false;
		impl->io->status = SPA_STATUS_NEED_DATA;
		call_drained(impl);
	}
}

static const struct pw_context_driver_events context_events = {
	PW_VERSION_CONTEXT_DRIVER_EVENTS,
	.drained = context_drained,
};

static struct stream *
stream_new(struct pw_context *context, const char *name,
		struct pw_properties *props, const struct pw_properties *extra)
{
	struct stream *impl;
	struct pw_stream *this;
	const char *str;
	int res;

	impl = calloc(1, sizeof(struct stream));
	if (impl == NULL) {
		res = -errno;
		goto error_cleanup;
	}
	impl->port_props = pw_properties_new(NULL, NULL);
	if (impl->port_props == NULL) {
		res = -errno;
		goto error_properties;
	}

	this = &impl->this;
	pw_log_debug(NAME" %p: new \"%s\"", impl, name);

	if (props == NULL) {
		props = pw_properties_new(PW_KEY_MEDIA_NAME, name, NULL);
	} else if (pw_properties_get(props, PW_KEY_MEDIA_NAME) == NULL) {
		pw_properties_set(props, PW_KEY_MEDIA_NAME, name);
	}
	if (props == NULL) {
		res = -errno;
		goto error_properties;
	}
	if ((str = pw_context_get_conf_section(context, "stream.properties")) != NULL)
		pw_properties_update_string(props, str, strlen(str));

	if (pw_properties_get(props, PW_KEY_STREAM_IS_LIVE) == NULL)
		pw_properties_set(props, PW_KEY_STREAM_IS_LIVE, "true");

	if (pw_properties_get(props, PW_KEY_NODE_NAME) == NULL && extra) {
		str = pw_properties_get(extra, PW_KEY_APP_NAME);
		if (str == NULL)
			str = pw_properties_get(extra, PW_KEY_APP_PROCESS_BINARY);
		if (str == NULL)
			str = name;
		pw_properties_set(props, PW_KEY_NODE_NAME, str);
	}
	if ((str = getenv("PIPEWIRE_LATENCY")) != NULL)
		pw_properties_set(props, PW_KEY_NODE_LATENCY, str);

	spa_hook_list_init(&impl->hooks);
	this->properties = props;

	this->name = name ? strdup(name) : NULL;
	this->node_id = SPA_ID_INVALID;

	spa_ringbuffer_init(&impl->dequeued.ring);
	spa_ringbuffer_init(&impl->queued.ring);
	spa_list_init(&impl->param_list);

	spa_hook_list_init(&this->listener_list);
	spa_list_init(&this->controls);

	this->state = PW_STREAM_STATE_UNCONNECTED;

	impl->context = context;
	impl->allow_mlock = context->defaults.mem_allow_mlock;
	impl->warn_mlock = context->defaults.mem_warn_mlock;

	spa_hook_list_append(&impl->context->driver_listener_list,
			&impl->context_listener,
			&context_events, impl);
	return impl;

error_properties:
	if (impl->port_props)
		pw_properties_free(impl->port_props);
	free(impl);
error_cleanup:
	if (props)
		pw_properties_free(props);
	errno = -res;
	return NULL;
}

SPA_EXPORT
struct pw_stream * pw_stream_new(struct pw_core *core, const char *name,
	      struct pw_properties *props)
{
	struct stream *impl;
	struct pw_stream *this;
	struct pw_context *context = core->context;

	impl = stream_new(context, name, props, core->properties);
	if (impl == NULL)
		return NULL;

	this = &impl->this;
	this->core = core;
	spa_list_append(&core->stream_list, &this->link);
	pw_core_add_listener(core,
			&this->core_listener, &core_events, this);

	return this;
}

SPA_EXPORT
struct pw_stream *
pw_stream_new_simple(struct pw_loop *loop,
		     const char *name,
		     struct pw_properties *props,
		     const struct pw_stream_events *events,
		     void *data)
{
	struct pw_stream *this;
	struct stream *impl;
	struct pw_context *context;
	int res;

	if (props == NULL)
		props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		return NULL;

	context = pw_context_new(loop, NULL, 0);
	if (context == NULL) {
		res = -errno;
		goto error_cleanup;
	}

	impl = stream_new(context, name, props, NULL);
	if (impl == NULL) {
		res = -errno;
		props = NULL;
		goto error_cleanup;
	}

	this = &impl->this;
	impl->data.context = context;
	pw_stream_add_listener(this, &impl->data.stream_listener, events, data);

	return this;

error_cleanup:
	if (context)
		pw_context_destroy(context);
	if (props)
		pw_properties_free(props);
	errno = -res;
	return NULL;
}

SPA_EXPORT
const char *pw_stream_state_as_string(enum pw_stream_state state)
{
	switch (state) {
	case PW_STREAM_STATE_ERROR:
		return "error";
	case PW_STREAM_STATE_UNCONNECTED:
		return "unconnected";
	case PW_STREAM_STATE_CONNECTING:
		return "connecting";
	case PW_STREAM_STATE_PAUSED:
		return "paused";
	case PW_STREAM_STATE_STREAMING:
		return "streaming";
	}
	return "invalid-state";
}

SPA_EXPORT
void pw_stream_destroy(struct pw_stream *stream)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	struct control *c;

	pw_log_debug(NAME" %p: destroy", stream);

	pw_stream_emit_destroy(stream);

	if (!impl->disconnecting)
		pw_stream_disconnect(stream);

	if (stream->core) {
		spa_hook_remove(&stream->core_listener);
		spa_list_remove(&stream->link);
		stream->core = NULL;
	}

	clear_params(impl, SPA_ID_INVALID);

	pw_log_debug(NAME" %p: free", stream);
	free(stream->error);

	pw_properties_free(stream->properties);

	free(stream->name);

	spa_list_consume(c, &stream->controls, link) {
		spa_list_remove(&c->link);
		free(c);
	}

	spa_hook_list_clean(&impl->hooks);
	spa_hook_list_clean(&stream->listener_list);

	spa_hook_remove(&impl->context_listener);

	if (impl->data.context)
		pw_context_destroy(impl->data.context);

	pw_properties_free(impl->port_props);
	free(impl);
}

SPA_EXPORT
void pw_stream_add_listener(struct pw_stream *stream,
			    struct spa_hook *listener,
			    const struct pw_stream_events *events,
			    void *data)
{
	spa_hook_list_append(&stream->listener_list, listener, events, data);
}

SPA_EXPORT
enum pw_stream_state pw_stream_get_state(struct pw_stream *stream, const char **error)
{
	if (error)
		*error = stream->error;
	return stream->state;
}

SPA_EXPORT
const char *pw_stream_get_name(struct pw_stream *stream)
{
	return stream->name;
}

SPA_EXPORT
const struct pw_properties *pw_stream_get_properties(struct pw_stream *stream)
{
	return stream->properties;
}

SPA_EXPORT
int pw_stream_update_properties(struct pw_stream *stream, const struct spa_dict *dict)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	int changed, res = 0;

	changed = pw_properties_update(stream->properties, dict);

	if (!changed)
		return 0;

	if (impl->node)
		res = pw_impl_node_update_properties(impl->node, dict);

	return res;
}

SPA_EXPORT
struct pw_core *pw_stream_get_core(struct pw_stream *stream)
{
	return stream->core;
}

static void add_params(struct stream *impl)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b;

	spa_pod_builder_init(&b, buffer, 4096);

	add_param(impl, SPA_PARAM_IO, PARAM_FLAG_LOCKED,
		spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamIO, SPA_PARAM_IO,
			SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Buffers),
			SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_buffers))));

	add_param(impl, SPA_PARAM_Meta, PARAM_FLAG_LOCKED,
		spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
			SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Busy),
			SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_busy))));
}

static int find_format(struct stream *impl, enum pw_direction direction,
		uint32_t *media_type, uint32_t *media_subtype)
{
	uint32_t state = 0;
	uint8_t buffer[4096];
	struct spa_pod_builder b;
	int res;
	struct spa_pod *format;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	if ((res = spa_node_port_enum_params_sync(&impl->impl_node,
				impl->direction, 0,
				SPA_PARAM_EnumFormat, &state,
				NULL, &format, &b)) != 1) {
		pw_log_warn(NAME" %p: no format given", impl);
		return 0;
	}

	if ((res = spa_format_parse(format, media_type, media_subtype)) < 0)
		return res;

	pw_log_debug(NAME " %p: %s/%s", impl,
			spa_debug_type_find_name(spa_type_media_type, *media_type),
			spa_debug_type_find_name(spa_type_media_subtype, *media_subtype));
	return 0;
}

static const char *get_media_class(struct stream *impl)
{
	switch (impl->media_type) {
	case SPA_MEDIA_TYPE_audio:
		return "Audio";
	case SPA_MEDIA_TYPE_video:
		return "Video";
	case SPA_MEDIA_TYPE_application:
		switch(impl->media_subtype) {
		case SPA_MEDIA_SUBTYPE_control:
			return "Midi";
		}
		return "Data";
	case SPA_MEDIA_TYPE_stream:
		switch(impl->media_subtype) {
		case SPA_MEDIA_SUBTYPE_midi:
			return "Midi";
		}
		return "Data";
	default:
		return "Unknown";
	}
}

SPA_EXPORT
int
pw_stream_connect(struct pw_stream *stream,
		  enum pw_direction direction,
		  uint32_t target_id,
		  enum pw_stream_flags flags,
		  const struct spa_pod **params,
		  uint32_t n_params)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	struct pw_impl_factory *factory;
	struct pw_properties *props = NULL;
	struct pw_impl_node *follower;
	const char *str;
	uint32_t i;
	int res;

	pw_log_debug(NAME" %p: connect target:%d", stream, target_id);
	impl->direction =
	    direction == PW_DIRECTION_INPUT ? SPA_DIRECTION_INPUT : SPA_DIRECTION_OUTPUT;
	impl->flags = flags;
	impl->node_methods = impl_node;

	if (impl->direction == SPA_DIRECTION_INPUT)
		impl->node_methods.process = impl_node_process_input;
	else
		impl->node_methods.process = impl_node_process_output;

	impl->process_rt = SPA_FLAG_IS_SET(flags, PW_STREAM_FLAG_RT_PROCESS);

	impl->impl_node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl->node_methods, impl);

	impl->change_mask_all =
		SPA_NODE_CHANGE_MASK_FLAGS |
		SPA_NODE_CHANGE_MASK_PROPS |
		SPA_NODE_CHANGE_MASK_PARAMS;

	impl->info = SPA_NODE_INFO_INIT();
	if (impl->direction == SPA_DIRECTION_INPUT) {
		impl->info.max_input_ports = 1;
		impl->info.max_output_ports = 0;
	} else {
		impl->info.max_input_ports = 0;
		impl->info.max_output_ports = 1;
	}
	/* we're always RT safe, if the stream was marked RT_PROCESS,
	 * the callback must be RT safe */
	impl->info.flags = SPA_NODE_FLAG_RT;
	/* if the callback was not marked RT_PROCESS, we will offload
	 * the process callback in the main thread and we are ASYNC */
	if (!impl->process_rt)
		impl->info.flags |= SPA_NODE_FLAG_ASYNC;
	impl->info.props = &stream->properties->dict;
	impl->params[0] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_WRITE);
	impl->info.params = impl->params;
	impl->info.n_params = 1;
	impl->info.change_mask = impl->change_mask_all;

	impl->port_change_mask_all =
		SPA_PORT_CHANGE_MASK_FLAGS |
		SPA_PORT_CHANGE_MASK_PROPS |
		SPA_PORT_CHANGE_MASK_PARAMS;

	impl->port_info = SPA_PORT_INFO_INIT();
	impl->port_info.change_mask = impl->port_change_mask_all;
	impl->port_info.flags = 0;
	if (SPA_FLAG_IS_SET(flags, PW_STREAM_FLAG_ALLOC_BUFFERS))
		impl->port_info.flags |= SPA_PORT_FLAG_CAN_ALLOC_BUFFERS;
	impl->port_params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, 0);
	impl->port_params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, 0);
	impl->port_params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, 0);
	impl->port_params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	impl->port_params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	impl->port_info.props = &impl->port_props->dict;
	impl->port_info.params = impl->port_params;
	impl->port_info.n_params = 5;

	clear_params(impl, SPA_ID_INVALID);
	for (i = 0; i < n_params; i++)
		add_param(impl, SPA_ID_INVALID, 0, params[i]);

	add_params(impl);

	if ((res = find_format(impl, direction, &impl->media_type, &impl->media_subtype)) < 0)
		return res;

	impl->disconnecting = false;
	stream_set_state(stream, PW_STREAM_STATE_CONNECTING, NULL);

	if (target_id != PW_ID_ANY)
		pw_properties_setf(stream->properties, PW_KEY_NODE_TARGET, "%d", target_id);
	else if ((str = getenv("PIPEWIRE_NODE")) != NULL)
		pw_properties_set(stream->properties, PW_KEY_NODE_TARGET, str);
	if ((flags & PW_STREAM_FLAG_AUTOCONNECT) &&
	    pw_properties_get(stream->properties, PW_KEY_NODE_AUTOCONNECT) == NULL) {
		str = getenv("PIPEWIRE_AUTOCONNECT");
		pw_properties_set(stream->properties, PW_KEY_NODE_AUTOCONNECT, str ? str : "true");
	}
	if (flags & PW_STREAM_FLAG_DRIVER)
		pw_properties_set(stream->properties, PW_KEY_NODE_DRIVER, "true");
	if (flags & PW_STREAM_FLAG_EXCLUSIVE)
		pw_properties_set(stream->properties, PW_KEY_NODE_EXCLUSIVE, "true");
	if (flags & PW_STREAM_FLAG_DONT_RECONNECT)
		pw_properties_set(stream->properties, PW_KEY_NODE_DONT_RECONNECT, "true");

	if ((str = pw_properties_get(stream->properties, "mem.warn-mlock")) != NULL)
		impl->warn_mlock = pw_properties_parse_bool(str);

	if ((pw_properties_get(stream->properties, PW_KEY_MEDIA_CLASS) == NULL)) {
		const char *media_type = pw_properties_get(stream->properties, PW_KEY_MEDIA_TYPE);
		pw_properties_setf(stream->properties, PW_KEY_MEDIA_CLASS, "Stream/%s/%s",
				direction == PW_DIRECTION_INPUT ? "Input" : "Output",
				media_type ? media_type : get_media_class(impl));
	}
	if ((str = pw_properties_get(stream->properties, PW_KEY_FORMAT_DSP)) != NULL)
		pw_properties_set(impl->port_props, PW_KEY_FORMAT_DSP, str);
	else if (impl->media_type == SPA_MEDIA_TYPE_application &&
	    impl->media_subtype == SPA_MEDIA_SUBTYPE_control)
		pw_properties_set(impl->port_props, PW_KEY_FORMAT_DSP, "8 bit raw midi");

	impl->port_info.props = &impl->port_props->dict;

	if (stream->core == NULL) {
		stream->core = pw_context_connect(impl->context,
				pw_properties_copy(stream->properties), 0);
		if (stream->core == NULL) {
			res = -errno;
			goto error_connect;
		}
		spa_list_append(&stream->core->stream_list, &stream->link);
		pw_core_add_listener(stream->core,
				&stream->core_listener, &core_events, stream);
		impl->disconnect_core = true;
	}

	pw_log_debug(NAME" %p: creating node", stream);
	props = pw_properties_copy(stream->properties);
	if (props == NULL) {
		res = -errno;
		goto error_node;
	}

	if ((str = pw_properties_get(props, PW_KEY_STREAM_MONITOR)) &&
	    pw_properties_parse_bool(str)) {
		pw_properties_set(props, "resample.peaks", "true");
		pw_properties_set(props, "channelmix.normalize", "true");
	}

	follower = pw_context_create_node(impl->context, pw_properties_copy(props), 0);
	if (follower == NULL) {
		res = -errno;
		goto error_node;
	}

	pw_impl_node_set_implementation(follower, &impl->impl_node);

	if (impl->media_type == SPA_MEDIA_TYPE_audio &&
	    impl->media_subtype == SPA_MEDIA_SUBTYPE_raw) {
		factory = pw_context_find_factory(impl->context, "adapter");
		if (factory == NULL) {
			pw_log_error(NAME" %p: no adapter factory found", stream);
			res = -ENOENT;
			goto error_node;
		}
		pw_properties_setf(props, "adapt.follower.node", "pointer:%p", follower);
		impl->node = pw_impl_factory_create_object(factory,
				NULL,
				PW_TYPE_INTERFACE_Node,
				PW_VERSION_NODE,
				props,
				0);
		props = NULL;
		if (impl->node == NULL) {
			res = -errno;
			goto error_node;
		}
	} else {
		impl->node = follower;
		pw_properties_free(props);
		props = NULL;
	}
	pw_impl_node_set_active(impl->node,
			!SPA_FLAG_IS_SET(impl->flags, PW_STREAM_FLAG_INACTIVE));

	pw_log_debug(NAME" %p: export node %p", stream, impl->node);
	stream->proxy = pw_core_export(stream->core,
			PW_TYPE_INTERFACE_Node, NULL, impl->node, 0);
	if (stream->proxy == NULL) {
		res = -errno;
		goto error_proxy;
	}

	pw_proxy_add_listener(stream->proxy, &stream->proxy_listener, &proxy_events, stream);

	pw_impl_node_add_listener(impl->node, &stream->node_listener, &node_events, stream);

	return 0;

error_connect:
	pw_log_error(NAME" %p: can't connect: %s", stream, spa_strerror(res));
	goto exit_cleanup;
error_node:
	pw_log_error(NAME" %p: can't make node: %s", stream, spa_strerror(res));
	goto exit_cleanup;
error_proxy:
	pw_log_error(NAME" %p: can't make proxy: %s", stream, spa_strerror(res));
	goto exit_cleanup;

exit_cleanup:
	if (props)
		pw_properties_free(props);
	return res;
}

SPA_EXPORT
uint32_t pw_stream_get_node_id(struct pw_stream *stream)
{
	return stream->node_id;
}

SPA_EXPORT
int pw_stream_disconnect(struct pw_stream *stream)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);

	pw_log_debug(NAME" %p: disconnect", stream);

	if (impl->disconnecting)
		return 0;

	impl->disconnecting = true;

	if (impl->node)
		pw_impl_node_set_active(impl->node, false);

	if (stream->proxy) {
		pw_proxy_destroy(stream->proxy);
		stream->proxy = NULL;
	}

	if (impl->node) {
		pw_impl_node_destroy(impl->node);
		impl->node = NULL;
	}
	if (impl->disconnect_core) {
		impl->disconnect_core = false;
		spa_hook_remove(&stream->core_listener);
		spa_list_remove(&stream->link);
		pw_core_disconnect(stream->core);
		stream->core = NULL;
	}
	return 0;
}

SPA_EXPORT
int pw_stream_set_error(struct pw_stream *stream,
			int res, const char *error, ...)
{
	if (res < 0) {
		va_list args;
		char *value;
		int r;

		va_start(args, error);
		r = vasprintf(&value, error, args);
		va_end(args);
		if (r < 0)
			return -errno;

		if (stream->proxy)
			pw_proxy_error(stream->proxy, res, value);
		stream_set_state(stream, PW_STREAM_STATE_ERROR, value);

		free(value);
	}
	return res;
}

SPA_EXPORT
int pw_stream_update_params(struct pw_stream *stream,
			const struct spa_pod **params,
			uint32_t n_params)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	int res;

	pw_log_debug(NAME" %p: update params", stream);
	if ((res = update_params(impl, SPA_ID_INVALID, params, n_params)) < 0)
		return res;

	emit_node_info(impl, false);
	emit_port_info(impl, false);

	return res;
}

SPA_EXPORT
int pw_stream_set_control(struct pw_stream *stream, uint32_t id, uint32_t n_values, float *values, ...)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
        va_list varargs;
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	struct spa_pod_frame f[1];
	struct spa_pod *pod;
	struct control *c;

	va_start(varargs, values);

	spa_pod_builder_push_object(&b, &f[0], SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);
	while (1) {
		pw_log_debug(NAME" %p: set control %d %d %f", stream, id, n_values, values[0]);

		if ((c = find_control(stream, id))) {
			spa_pod_builder_prop(&b, id, 0);
			switch (c->container) {
			case SPA_TYPE_Float:
				spa_pod_builder_float(&b, values[0]);
				break;
			case SPA_TYPE_Bool:
				spa_pod_builder_bool(&b, values[0] < 0.5 ? false : true);
				break;
			case SPA_TYPE_Array:
				spa_pod_builder_array(&b,
						sizeof(float), SPA_TYPE_Float,
						n_values, values);
				break;
			default:
				spa_pod_builder_none(&b);
				break;
			}
		} else {
			pw_log_warn(NAME" %p: unknown control with id %d", stream, id);
		}
		if ((id = va_arg(varargs, uint32_t)) == 0)
			break;
		n_values = va_arg(varargs, uint32_t);
		values = va_arg(varargs, float *);
	}
	pod = spa_pod_builder_pop(&b, &f[0]);

	va_end(varargs);

	pw_impl_node_set_param(impl->node, SPA_PARAM_Props, 0, pod);

	return 0;
}

SPA_EXPORT
const struct pw_stream_control *pw_stream_get_control(struct pw_stream *stream, uint32_t id)
{
	struct control *c;

	if (id == 0)
		return NULL;

	if ((c = find_control(stream, id)))
		return &c->control;

	return NULL;
}

SPA_EXPORT
int pw_stream_set_active(struct pw_stream *stream, bool active)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	pw_log_debug(NAME" %p: active:%d", stream, active);
	if (impl->node)
		pw_impl_node_set_active(impl->node, active);
	return 0;
}

SPA_EXPORT
int pw_stream_get_time(struct pw_stream *stream, struct pw_time *time)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	uintptr_t seq1, seq2;

	do {
		seq1 = SEQ_READ(impl->seq);
		*time = impl->time;
		seq2 = SEQ_READ(impl->seq);
	} while (!SEQ_READ_SUCCESS(seq1, seq2));

	if (impl->direction == SPA_DIRECTION_INPUT)
		time->queued = (int64_t)(time->queued - impl->dequeued.outcount);
	else
		time->queued = (int64_t)(impl->queued.incount - time->queued);

	pw_log_trace(NAME" %p: %"PRIi64" %"PRIi64" %"PRIu64" %d/%d %"PRIu64" %"
			PRIu64" %"PRIu64" %"PRIu64" %"PRIu64, stream,
			time->now, time->delay, time->ticks,
			time->rate.num, time->rate.denom, time->queued,
			impl->dequeued.outcount, impl->dequeued.incount,
			impl->queued.outcount, impl->queued.incount);

	return 0;
}

static int
do_process(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	int res = impl_node_process_output(impl);
	return spa_node_call_ready(&impl->callbacks, res);
}

static inline int call_trigger(struct stream *impl)
{
	int res = 0;
	if (SPA_FLAG_IS_SET(impl->flags, PW_STREAM_FLAG_DRIVER)) {
		res = pw_loop_invoke(impl->context->data_loop,
			do_process, 1, NULL, 0, false, impl);
	}
	return res;
}

SPA_EXPORT
struct pw_buffer *pw_stream_dequeue_buffer(struct pw_stream *stream)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	struct buffer *b;
	int res;

	if ((b = pop_queue(impl, &impl->dequeued)) == NULL) {
		res = -errno;
		pw_log_trace(NAME" %p: no more buffers: %m", stream);
		errno = -res;
		return NULL;
	}
	pw_log_trace(NAME" %p: dequeue buffer %d", stream, b->id);

	if (b->busy && impl->direction == SPA_DIRECTION_OUTPUT) {
		if (ATOMIC_INC(b->busy->count) > 1) {
			ATOMIC_DEC(b->busy->count);
			push_queue(impl, &impl->dequeued, b);
			pw_log_trace(NAME" %p: buffer busy", stream);
			errno = EBUSY;
			return NULL;
		}
	}
	return &b->this;
}

SPA_EXPORT
int pw_stream_queue_buffer(struct pw_stream *stream, struct pw_buffer *buffer)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	struct buffer *b = SPA_CONTAINER_OF(buffer, struct buffer, this);
	int res;

	if (b->busy)
		ATOMIC_DEC(b->busy->count);

	pw_log_trace(NAME" %p: queue buffer %d", stream, b->id);
	if ((res = push_queue(impl, &impl->queued, b)) < 0)
		return res;

	return call_trigger(impl);
}

static int
do_flush(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	struct buffer *b;

	pw_log_trace(NAME" %p: flush", impl);
	do {
		b = pop_queue(impl, &impl->queued);
		if (b != NULL)
			push_queue(impl, &impl->dequeued, b);
	}
	while (b);

	impl->queued.outcount = impl->dequeued.incount =
		impl->dequeued.outcount = impl->queued.incount = 0;

	return 0;
}
static int
do_drain(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *impl = user_data;
	pw_log_trace(NAME" %p", impl);
	impl->draining = true;
	impl->drained = false;
	return 0;
}

SPA_EXPORT
int pw_stream_flush(struct pw_stream *stream, bool drain)
{
	struct stream *impl = SPA_CONTAINER_OF(stream, struct stream, this);
	pw_loop_invoke(impl->context->data_loop,
			drain ? do_drain : do_flush, 1, NULL, 0, true, impl);
	if (!drain)
		spa_node_send_command(impl->node->node,
				&SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Flush));
	return 0;
}
