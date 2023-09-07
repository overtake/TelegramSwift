/* Spa A2DP Source
 *
 * Copyright © 2018 Wim Taymans
 * Copyright © 2019 Collabora Ltd.
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

#include <unistd.h>
#include <stddef.h>
#include <stdio.h>
#include <time.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>

#include <spa/support/plugin.h>
#include <spa/support/loop.h>
#include <spa/support/log.h>
#include <spa/support/system.h>
#include <spa/utils/list.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/monitor/device.h>

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/node/keys.h>
#include <spa/param/param.h>
#include <spa/param/audio/format.h>
#include <spa/param/audio/format-utils.h>
#include <spa/pod/filter.h>

#include "defs.h"
#include "rtp.h"
#include "a2dp-codecs.h"

struct props {
	uint32_t min_latency;
	uint32_t max_latency;
};

#define FILL_FRAMES 2
#define MAX_BUFFERS 32

struct buffer {
	uint32_t id;
	unsigned int outstanding:1;
	struct spa_buffer *buf;
	struct spa_meta_header *h;
	struct spa_list link;
};

struct port {
	struct spa_audio_info current_format;
	uint32_t frame_size;
	unsigned int have_format:1;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_io_buffers *io;
	struct spa_param_info params[8];

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list free;
	struct spa_list ready;

	struct buffer *current_buffer;
	uint32_t ready_offset;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_loop *data_loop;
	struct spa_system *data_system;

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[8];
	struct props props;

	struct spa_bt_transport *transport;
	struct spa_hook transport_listener;

	struct port port;

	unsigned int started:1;
	unsigned int transport_acquired:1;
	unsigned int following:1;

	struct spa_source source;

	struct spa_io_clock *clock;
        struct spa_io_position *position;

	const struct a2dp_codec *codec;
	bool codec_props_changed;
	void *codec_props;
	void *codec_data;
	struct spa_audio_info codec_format;

	uint8_t buffer_read[4096];
	struct timespec now;
	uint64_t sample_count;
	uint64_t skip_count;

	bool is_input;
};

#define NAME "a2dp-source"

#define CHECK_PORT(this,d,p)    ((d) == SPA_DIRECTION_OUTPUT && (p) == 0)

static const uint32_t default_min_latency = MIN_LATENCY;
static const uint32_t default_max_latency = MAX_LATENCY;

static void reset_props(struct props *props)
{
	props->min_latency = default_min_latency;
	props->max_latency = default_max_latency;
}

static int impl_node_enum_params(void *object, int seq,
			uint32_t id, uint32_t start, uint32_t num,
			const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0, index_offset = 0;
	bool enum_codec = false;

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
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_minLatency),
				SPA_PROP_INFO_name, SPA_POD_String("The minimum latency"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Int(p->min_latency, 1, INT32_MAX));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_maxLatency),
				SPA_PROP_INFO_name, SPA_POD_String("The maximum latency"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Int(p->max_latency, 1, INT32_MAX));
			break;
		default:
			enum_codec = true;
			index_offset = 2;
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
				SPA_PROP_minLatency, SPA_POD_Int(p->min_latency),
				SPA_PROP_maxLatency, SPA_POD_Int(p->max_latency));
			break;
		default:
			enum_codec = true;
			index_offset = 1;
		}
		break;
	}
	default:
		return -ENOENT;
	}

	if (enum_codec) {
		int res;
		if (this->codec->enum_props == NULL || this->codec_props == NULL)
			return 0;
		else if ((res = this->codec->enum_props(this->codec_props,
					this->transport->device->settings,
					id, result.index - index_offset,
					&b, &param)) != 1)
			return res;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int do_reassing_follower(struct spa_loop *loop,
			bool async,
			uint32_t seq,
			const void *data,
			size_t size,
			void *user_data)
{
	return 0;
}

static inline bool is_following(struct impl *this)
{
	return this->position && this->clock && this->position->clock.id != this->clock->id;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	bool following;

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

	following = is_following(this);
	if (this->started && following != this->following) {
		spa_log_debug(this->log, NAME" %p: reassign follower %d->%d", this, this->following, following);
		this->following = following;
		spa_loop_invoke(this->data_loop, do_reassing_follower, 0, NULL, 0, true, this);
	}
	return 0;
}

static void emit_node_info(struct impl *this, bool full);

static int apply_props(struct impl *this, const struct spa_pod *param)
{
	struct props new_props = this->props;
	int changed = 0;

	if (param == NULL) {
		reset_props(&new_props);
	} else {
		spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_Props, NULL,
				SPA_PROP_minLatency, SPA_POD_OPT_Int(&new_props.min_latency),
				SPA_PROP_maxLatency, SPA_POD_OPT_Int(&new_props.max_latency));
	}

	changed = (memcmp(&new_props, &this->props, sizeof(struct props)) != 0);
	this->props = new_props;
	return changed;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Props:
	{
		int res, codec_res = 0;
		res = apply_props(this, param);
		if (this->codec_props && this->codec->set_props) {
			codec_res = this->codec->set_props(this->codec_props, param);
			if (codec_res > 0)
				this->codec_props_changed = true;
		}
		if (res > 0 || codec_res > 0) {
			this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
			this->params[1].flags ^= SPA_PARAM_INFO_SERIAL;
			emit_node_info(this, false);
		}
		break;
	}
	default:
		return -ENOENT;
	}

	return 0;
}

static void reset_buffers(struct port *port)
{
	uint32_t i;

	spa_list_init(&port->free);
	spa_list_init(&port->ready);
	port->current_buffer = NULL;

	for (i = 0; i < port->n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		spa_list_append(&port->free, &b->link);
		b->outstanding = false;
	}
}

static void recycle_buffer(struct impl *this, struct port *port, uint32_t buffer_id)
{
	struct buffer *b = &port->buffers[buffer_id];

	if (b->outstanding) {
		spa_log_trace(this->log, NAME " %p: recycle buffer %u", this, buffer_id);
		spa_list_append(&port->free, &b->link);
		b->outstanding = false;
	}
}

static int32_t read_data(struct impl *this) {
	const ssize_t b_size = sizeof(this->buffer_read);
	int32_t size_read = 0;

again:
	/* read data from socket */
	size_read = read(this->source.fd, this->buffer_read, b_size);

	if (size_read == 0)
		return 0;
	else if (size_read < 0) {
		/* retry if interrupted */
		if (errno == EINTR)
			goto again;

		/* return socket has no data */
		if (errno == EAGAIN || errno == EWOULDBLOCK)
		    return 0;

		/* go to 'stop' if socket has an error */
		spa_log_error(this->log, "read error: %s", strerror(errno));
		return -errno;
	}

	return size_read;
}

static int32_t decode_data(struct impl *this, uint8_t *src, uint32_t src_size,
			   uint8_t *dst, uint32_t dst_size)
{
	ssize_t processed;
	size_t written, avail;

	if ((processed = this->codec->start_decode(this->codec_data,
				src, src_size, NULL, NULL)) < 0)
		return processed;

	src += processed;
	src_size -= processed;

	/* decode */
	avail = dst_size;
	while (src_size > 0) {
		if ((processed = this->codec->decode(this->codec_data,
				src, src_size, dst, avail, &written)) <= 0)
			return processed;

		/* update source and dest pointers */
		spa_return_val_if_fail (avail > written, -ENOSPC);
		src_size -= processed;
		src += processed;
		avail -= written;
		dst += written;
	}
	return dst_size - avail;
}

static void skip_ready_buffers(struct impl *this)
{
	struct port *port = &this->port;

	/* Move all buffers from ready to free */
	while (!spa_list_is_empty(&port->ready)) {
		struct buffer *b;
		b = spa_list_first(&port->ready, struct buffer, link);
		spa_list_remove(&b->link);
		spa_list_append(&port->free, &b->link);
		spa_assert(!b->outstanding);
		this->skip_count += b->buf->datas[0].chunk->size / port->frame_size;
	}
}

static void a2dp_on_ready_read(struct spa_source *source)
{
	struct impl *this = source->data;
	struct port *port = &this->port;
	struct spa_io_buffers *io = port->io;
	int32_t size_read, decoded, avail;
	struct spa_data *datas;
	struct buffer *buffer;
	uint32_t min_data;
	uint8_t read_decoded[4096];

	/* make sure the source is an input */
	if ((source->rmask & SPA_IO_IN) == 0) {
		spa_log_error(this->log, "source is not an input, rmask=%d", source->rmask);
		goto stop;
	}
	if (this->transport == NULL) {
		spa_log_debug(this->log, "no transport, stop reading");
		goto stop;
	}

	/* update the current pts */
	spa_system_clock_gettime(this->data_system, CLOCK_MONOTONIC, &this->now);

	/* read */
	size_read = read_data (this);
	if (size_read == 0)
		return;
	if (size_read < 0) {
		spa_log_error(this->log, "failed to read data: %s", spa_strerror(size_read));
		goto stop;
	}
	spa_log_trace(this->log, "read socket data %d", size_read);

	if (this->codec_props_changed && this->codec_props
			&& this->codec->update_props) {
		this->codec->update_props(this->codec_data, this->codec_props);
		this->codec_props_changed = false;
	}

	/* decode */
	decoded = decode_data(this, this->buffer_read, size_read,
			read_decoded, sizeof (read_decoded));
	if (decoded < 0) {
		spa_log_error(this->log, "failed to decode data: %d", decoded);
		goto stop;
	}
	if (decoded == 0)
		return;

	spa_log_trace(this->log, "decoded socket data %d", decoded);

	/* discard when not started */
	if (!this->started)
		return;

	/* get buffer */
	if (!port->current_buffer) {
		if (spa_list_is_empty(&port->free)) {
			/* xrun, skip ahead */
			skip_ready_buffers(this);
			this->skip_count += decoded / port->frame_size;
			this->sample_count += decoded / port->frame_size;
			return;
		}
		if (this->skip_count > 0) {
			spa_log_info(this->log, NAME " %p: xrun, skipped %"PRIu64" usec",
			             this, (uint64_t)(this->skip_count * SPA_USEC_PER_SEC / port->current_format.info.raw.rate));
			this->skip_count = 0;
		}

		buffer = spa_list_first(&port->free, struct buffer, link);
		spa_list_remove(&buffer->link);

		port->current_buffer = buffer;
		port->ready_offset = 0;
		spa_log_trace(this->log, "dequeue %d", buffer->id);

		if (buffer->h) {
			buffer->h->seq = this->sample_count;
			buffer->h->pts = SPA_TIMESPEC_TO_NSEC(&this->now);
			buffer->h->dts_offset = 0;
		}
	} else {
		buffer = port->current_buffer;
	}
	datas = buffer->buf->datas;

	/* copy data into buffer */
	avail = SPA_MIN(decoded, (int32_t)(datas[0].maxsize - port->ready_offset));
	if (avail < decoded)
		spa_log_warn(this->log, NAME ": buffer too small (%d > %d)", decoded, avail);
	memcpy ((uint8_t *)datas[0].data + port->ready_offset, read_decoded, avail);
	port->ready_offset += avail;
	this->sample_count += decoded / port->frame_size;

	/* send buffer if full */
	min_data = SPA_MIN(this->props.min_latency * port->frame_size, datas[0].maxsize / 2);
	if (port->ready_offset >= min_data) {
		uint64_t sample_count;

		datas[0].chunk->offset = 0;
		datas[0].chunk->size = port->ready_offset;
		datas[0].chunk->stride = port->frame_size;

		sample_count = datas[0].chunk->size / port->frame_size;

		spa_log_trace(this->log, "queue %d", buffer->id);
		spa_list_append(&port->ready, &buffer->link);
		port->current_buffer = NULL;

		if (!this->following && this->clock) {
			this->clock->nsec = SPA_TIMESPEC_TO_NSEC(&this->now);
			this->clock->duration = sample_count * this->clock->rate.denom / port->current_format.info.raw.rate;
			this->clock->position = this->sample_count * this->clock->rate.denom / port->current_format.info.raw.rate;
			this->clock->delay = 0;
			this->clock->rate_diff = 1.0f;
			this->clock->next_nsec = this->clock->nsec + (uint64_t)sample_count * SPA_NSEC_PER_SEC / port->current_format.info.raw.rate;
		}
	}

	/* done if there are no buffers ready */
	if (spa_list_is_empty(&port->ready))
		return;

	if (this->following)
		return;

	/* process the buffer if IO does not have any */
	if (io != NULL && io->status != SPA_STATUS_HAVE_DATA) {
		struct buffer *b;

		if (io->buffer_id < port->n_buffers)
			recycle_buffer(this, port, io->buffer_id);

		b = spa_list_first(&port->ready, struct buffer, link);
		spa_list_remove(&b->link);
		b->outstanding = true;

		io->buffer_id = b->id;
		io->status = SPA_STATUS_HAVE_DATA;
	}

	/* notify ready */
	spa_node_call_ready(&this->callbacks, SPA_STATUS_HAVE_DATA);
	return;

stop:
	if (this->source.loop)
		spa_loop_remove_source(this->data_loop, &this->source);
}

static int transport_start(struct impl *this)
{
	int res, val;
	struct port *port = &this->port;

	if (this->transport_acquired)
		return 0;

	spa_log_debug(this->log, NAME" %p: transport %p acquire", this,
			this->transport);
	if ((res = spa_bt_transport_acquire(this->transport, false)) < 0)
		return res;

	this->transport_acquired = true;

	this->codec_data = this->codec->init(this->codec, 0,
			this->transport->configuration,
			this->transport->configuration_len,
			&port->current_format,
			this->codec_props,
			this->transport->read_mtu);
	if (this->codec_data == NULL)
		return -EIO;

        spa_log_info(this->log, NAME " %p: using A2DP codec %s", this, this->codec->description);

	val = fcntl(this->transport->fd, F_GETFL);
	if (fcntl(this->transport->fd, F_SETFL, val | O_NONBLOCK) < 0)
		spa_log_warn(this->log, NAME" %p: fcntl %u %m", this, val | O_NONBLOCK);

	val = FILL_FRAMES * this->transport->write_mtu;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_SNDBUF, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, NAME" %p: SO_SNDBUF %m", this);

	val = FILL_FRAMES * this->transport->read_mtu;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_RCVBUF, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, NAME" %p: SO_RCVBUF %m", this);

	val = 6;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_PRIORITY, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, "SO_PRIORITY failed: %m");

	reset_buffers(&this->port);

	this->source.data = this;
	this->source.fd = this->transport->fd;
	this->source.func = a2dp_on_ready_read;
	this->source.mask = SPA_IO_IN;
	this->source.rmask = 0;
	spa_loop_add_source(this->data_loop, &this->source);

	this->sample_count = 0;
	this->skip_count = 0;

	return 0;
}

static int do_start(struct impl *this)
{
	int res = 0;

	if (this->started)
		return 0;

	this->following = is_following(this);

	spa_log_debug(this->log, NAME" %p: start state:%d following:%d",
			this, this->transport->state, this->following);

	spa_return_val_if_fail(this->transport != NULL, -EIO);

	if (this->transport->state >= SPA_BT_TRANSPORT_STATE_PENDING)
		res = transport_start(this);

	this->started = true;

	return res;
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct impl *this = user_data;

	if (this->source.loop)
		spa_loop_remove_source(this->data_loop, &this->source);

	return 0;
}

static int transport_stop(struct impl *this)
{
	int res;

	spa_log_debug(this->log, NAME" %p: transport stop", this);

	spa_loop_invoke(this->data_loop, do_remove_source, 0, NULL, 0, true, this);

	if (this->transport && this->transport_acquired)
		res = spa_bt_transport_release(this->transport);
	else
		res = 0;

	this->transport_acquired = false;

	if (this->codec_data)
		this->codec->deinit(this->codec_data);
	this->codec_data = NULL;

	return res;
}

static int do_stop(struct impl *this)
{
	int res;

	if (!this->started)
		return 0;

	spa_log_debug(this->log, NAME" %p: stop", this);

	res = transport_stop(this);

	this->started = false;

	return res;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;
	struct port *port;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	port = &this->port;

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		if (!port->have_format)
			return -EIO;
		if (port->n_buffers == 0)
			return -EIO;

		if ((res = do_start(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Pause:
		if ((res = do_stop(this)) < 0)
			return res;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static void emit_node_info(struct impl *this, bool full)
{
	char latency[64] = SPA_STRINGIFY(MIN_LATENCY)"/48000";

	struct spa_dict_item node_info_items[] = {
		{ SPA_KEY_DEVICE_API, "bluez5" },
		{ SPA_KEY_MEDIA_CLASS, this->is_input ? "Audio/Source" : "Stream/Output/Audio" },
		{ SPA_KEY_NODE_LATENCY, latency },
		{ "media.name", ((this->transport && this->transport->device->name) ?
		                 this->transport->device->name : "A2DP") },
                { SPA_KEY_NODE_DRIVER, this->is_input ? "true" : "false" },
	};

	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		if (this->transport && this->port.have_format)
			snprintf(latency, sizeof(latency), "%d/%d", (int)this->props.min_latency,
					(int)this->port.current_format.info.raw.rate);
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

static int impl_node_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_node_emit_result(&this->hooks, seq, 0, 0, NULL);

	return 0;
}

static int impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	return -ENOTSUP;
}

static int impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	return -ENOTSUP;
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
	port = &this->port;

	result.id = id;
	result.next = start;
      next:
        result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if (result.index > 0)
			return 0;
		if (this->codec == NULL)
			return -EIO;
		if (this->transport == NULL)
			return -EIO;

		if ((res = this->codec->enum_config(this->codec,
					this->transport->configuration,
					this->transport->configuration_len,
					id, result.index, &b, &param)) != 1)
			return res;
		break;

	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_format_audio_raw_build(&b, id, &port->current_format.info.raw);
		break;

	case SPA_PARAM_Buffers:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(8, 8, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							this->props.max_latency * port->frame_size,
							this->props.min_latency * port->frame_size,
							INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->frame_size),
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
	do_stop(this);
	if (port->n_buffers > 0) {
		spa_list_init(&port->free);
		spa_list_init(&port->ready);
		port->n_buffers = 0;
	}
	port->current_buffer = NULL;
	return 0;
}

static int port_set_format(struct impl *this, struct port *port,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	int err;

	if (format == NULL) {
		spa_log_debug(this->log, "clear format");
		clear_buffers(this, port);
		port->have_format = false;
	} else {
		struct spa_audio_info info = { 0 };

		if ((err = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return err;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			return -EINVAL;

		if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
			return -EINVAL;

		port->frame_size = info.info.raw.channels;

		switch (info.info.raw.format) {
		case SPA_AUDIO_FORMAT_S16:
			port->frame_size *= 2;
			break;
		case SPA_AUDIO_FORMAT_S24:
			port->frame_size *= 3;
			break;
		case SPA_AUDIO_FORMAT_S24_32:
		case SPA_AUDIO_FORMAT_S32:
		case SPA_AUDIO_FORMAT_F32:
			port->frame_size *= 4;
			break;
		default:
			return -EINVAL;
		}

		port->current_format = info;
		port->have_format = true;
	}

	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->info.change_mask |= SPA_PORT_CHANGE_MASK_FLAGS;
		port->info.flags = SPA_PORT_FLAG_LIVE;
		port->info.change_mask |= SPA_PORT_CHANGE_MASK_RATE;
		port->info.rate = SPA_FRACTION(1, port->current_format.info.raw.rate);
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
		res = -ENOENT;
		break;
	}
	return res;
}

static int
impl_node_port_use_buffers(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t flags,
			   struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct impl *this = object;
	struct port *port;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);
	port = &this->port;

	spa_log_debug(this->log, "use buffers %d", n_buffers);

	if (!port->have_format)
		return -EIO;

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		struct spa_data *d = buffers[i]->datas;

		b->buf = buffers[i];
		b->id = i;

		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		if (d[0].data == NULL) {
			spa_log_error(this->log, NAME " %p: need mapped memory", this);
			return -EINVAL;
		}
		spa_list_append(&port->free, &b->link);
		b->outstanding = false;
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

	if (port->n_buffers == 0)
		return -EIO;

	if (buffer_id >= port->n_buffers)
		return -EINVAL;

	recycle_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	struct port *port;
	struct spa_io_buffers *io;
	struct buffer *buffer;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	port = &this->port;
	io = port->io;
	spa_return_val_if_fail(io != NULL, -EIO);

	spa_log_trace(this->log, "%p status:%d", this, io->status);

	/* Return if we already have a buffer */
	if (io->status == SPA_STATUS_HAVE_DATA)
		return SPA_STATUS_HAVE_DATA;

	/* Recycle */
	if (io->buffer_id < port->n_buffers) {
		recycle_buffer(this, port, io->buffer_id);
		io->buffer_id = SPA_ID_INVALID;
	}

	/* Return if there are no buffers ready to be processed */
	if (spa_list_is_empty(&port->ready))
		return SPA_STATUS_OK;

	/* Get the new buffer from the ready list */
	buffer = spa_list_first(&port->ready, struct buffer, link);
	spa_list_remove(&buffer->link);
	buffer->outstanding = true;

	/* Set the new buffer in IO */
	io->buffer_id = buffer->id;
	io->status = SPA_STATUS_HAVE_DATA;

	/* Notify we have a buffer ready to be processed */
	return SPA_STATUS_HAVE_DATA;
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

static int do_transport_destroy(struct spa_loop *loop,
				bool async,
				uint32_t seq,
				const void *data,
				size_t size,
				void *user_data)
{
	struct impl *this = user_data;
	this->transport = NULL;
	this->transport_acquired = false;
	return 0;
}

static void transport_destroy(void *data)
{
	struct impl *this = data;
	spa_log_debug(this->log, "transport %p destroy", this->transport);
	spa_loop_invoke(this->data_loop, do_transport_destroy, 0, NULL, 0, true, this);
}

static const struct spa_bt_transport_events transport_events = {
	SPA_VERSION_BT_TRANSPORT_EVENTS,
        .destroy = transport_destroy,
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
	struct impl *this = (struct impl *) handle;
	if (this->codec_data)
		this->codec->deinit(this->codec_data);
	if (this->codec_props && this->codec->clear_props)
		this->codec->clear_props(this->codec_props);
	if (this->transport)
		spa_hook_remove(&this->transport_listener);
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
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);
	this->data_system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);

	if (this->data_loop == NULL) {
		spa_log_error(this->log, "a data loop is needed");
		return -EINVAL;
	}
	if (this->data_system == NULL) {
		spa_log_error(this->log, "a data system is needed");
		return -EINVAL;
	}

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	reset_props(&this->props);

	/* set the node info */
	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = 0;
	this->info.max_output_ports = 1;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	this->info.params = this->params;
	this->info.n_params = 3;

	/* set the port info */
	port = &this->port;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.change_mask = SPA_PORT_CHANGE_MASK_FLAGS;
	port->info.flags = SPA_PORT_FLAG_LIVE |
			   SPA_PORT_FLAG_TERMINAL;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;

	/* Init the buffer lists */
	spa_list_init(&port->ready);
	spa_list_init(&port->free);

	if (info != NULL) {
		if ((str = spa_dict_lookup(info, SPA_KEY_API_BLUEZ5_TRANSPORT)) != NULL)
			sscanf(str, "pointer:%p", &this->transport);
		if ((str = spa_dict_lookup(info, "bluez5.a2dp-source-role")) != NULL)
			this->is_input = strcmp(str, "input") == 0;
	}

	if (this->transport == NULL) {
		spa_log_error(this->log, "a transport is needed");
		return -EINVAL;
	}
	if (this->transport->a2dp_codec == NULL) {
		spa_log_error(this->log, "a transport codec is needed");
		return -EINVAL;
	}
	this->codec = this->transport->a2dp_codec;
	if (this->codec->init_props != NULL)
		this->codec_props = this->codec->init_props(this->codec,
					this->transport->device->settings);

	spa_bt_transport_add_listener(this->transport,
			&this->transport_listener, &transport_events, this);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Node,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info, uint32_t *index)
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
	{ SPA_KEY_FACTORY_AUTHOR, "Collabora Ltd. <contact@collabora.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "Capture bluetooth audio with a2dp" },
	{ SPA_KEY_FACTORY_USAGE, SPA_KEY_API_BLUEZ5_TRANSPORT"=<transport>" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_a2dp_source_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_BLUEZ5_A2DP_SOURCE,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
