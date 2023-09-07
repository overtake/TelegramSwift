/* Spa A2DP Sink
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

#include <unistd.h>
#include <stddef.h>
#include <stdio.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>

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

#include <sbc/sbc.h>

#include "defs.h"
#include "rtp.h"
#include "a2dp-codecs.h"

struct codec;

struct props {
	uint32_t min_latency;
	uint32_t max_latency;
	int64_t latency_offset;
};

#define FILL_FRAMES 2
#define MAX_BUFFERS 32

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT	(1<<0)
	uint32_t flags;
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

	size_t ready_offset;
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
	unsigned int following:1;

	struct spa_source source;
	int timerfd;
	struct spa_source flush_source;

	struct spa_io_clock *clock;
	struct spa_io_position *position;

	uint64_t current_time;
	uint64_t next_time;
	uint64_t last_error;

	const struct a2dp_codec *codec;
	bool codec_props_changed;
	void *codec_props;
	void *codec_data;
	struct spa_audio_info codec_format;

	int need_flush;
	uint32_t block_size;
	uint8_t buffer[4096];
	uint32_t buffer_used;
	uint32_t header_size;
	uint32_t frame_count;
	uint16_t seqnum;
	uint32_t timestamp;
	uint64_t sample_count;
	uint8_t tmp_buffer[4096];
	uint32_t tmp_buffer_used;
	uint32_t fd_buffer_size;
};

#define NAME "a2dp-sink"

#define CHECK_PORT(this,d,p)    ((d) == SPA_DIRECTION_INPUT && (p) == 0)

static const uint32_t default_min_latency = MIN_LATENCY;
static const uint32_t default_max_latency = MAX_LATENCY;

static void reset_props(struct props *props)
{
	props->min_latency = default_min_latency;
	props->max_latency = default_max_latency;
	props->latency_offset = 0;
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
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_latencyOffsetNsec),
				SPA_PROP_INFO_name, SPA_POD_String("Latency offset (ns)"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Long(0, INT64_MIN, INT64_MAX));
			break;
		default:
			enum_codec = true;
			index_offset = 3;
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
				SPA_PROP_maxLatency, SPA_POD_Int(p->max_latency),
				SPA_PROP_latencyOffsetNsec, SPA_POD_Long(p->latency_offset));
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
					id, result.index - index_offset, &b, &param)) != 1)
			return res;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int set_timeout(struct impl *this, uint64_t time)
{
	struct itimerspec ts;
	ts.it_value.tv_sec = time / SPA_NSEC_PER_SEC;
	ts.it_value.tv_nsec = time % SPA_NSEC_PER_SEC;
	ts.it_interval.tv_sec = 0;
	ts.it_interval.tv_nsec = 0;
	return spa_system_timerfd_settime(this->data_system,
			this->timerfd, SPA_FD_TIMER_ABSTIME, &ts, NULL);
}

static int set_timers(struct impl *this)
{
	struct timespec now;

	spa_system_clock_gettime(this->data_system, CLOCK_MONOTONIC, &now);
	this->next_time = SPA_TIMESPEC_TO_NSEC(&now);

	return set_timeout(this, this->following ? 0 : this->next_time);
}

static int do_reassign_follower(struct spa_loop *loop,
			bool async,
			uint32_t seq,
			const void *data,
			size_t size,
			void *user_data)
{
	struct impl *this = user_data;
	set_timers(this);
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
		spa_log_debug(this->log, NAME " %p: reassign follower %d->%d", this, this->following, following);
		this->following = following;
		spa_loop_invoke(this->data_loop, do_reassign_follower, 0, NULL, 0, true, this);
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
				SPA_PROP_maxLatency, SPA_POD_OPT_Int(&new_props.max_latency),
				SPA_PROP_latencyOffsetNsec, SPA_POD_OPT_Long(&new_props.latency_offset));
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

static int reset_buffer(struct impl *this)
{
	if (this->codec_props_changed && this->codec_props
			&& this->codec->update_props) {
		this->codec->update_props(this->codec_data, this->codec_props);
		this->codec_props_changed = false;
	}
	this->need_flush = 0;
	this->frame_count = 0;
	this->buffer_used = this->codec->start_encode(this->codec_data,
			this->buffer, sizeof(this->buffer),
			this->seqnum++, this->timestamp);
	this->header_size = this->buffer_used;
	this->timestamp = this->sample_count;
	return 0;
}

static int get_transport_unused_size(struct impl *this)
{
	int res, value;
	res = ioctl(this->flush_source.fd, TIOCOUTQ, &value);
	if (res < 0) {
		spa_log_error(this->log, NAME " %p: ioctl fail: %m", this);
		return -errno;
	}
	spa_log_trace(this->log, NAME " %p: fd unused buffer size:%d/%d", this, value, this->fd_buffer_size);
	return value;
}

static int send_buffer(struct impl *this)
{
	int written, unsent;
	unsent = get_transport_unused_size(this);
	if (unsent >= 0) {
		unsent = this->fd_buffer_size - unsent;
		this->codec->abr_process(this->codec_data, unsent);
	}

	spa_log_trace(this->log, NAME " %p: send %d %u %u %u %u",
			this, this->frame_count, this->block_size, this->seqnum,
			this->timestamp, this->buffer_used);

	written = send(this->flush_source.fd, this->buffer,
			this->buffer_used, MSG_DONTWAIT | MSG_NOSIGNAL);

	spa_log_trace(this->log, NAME " %p: send %d", this, written);

	if (written < 0) {
		spa_log_debug(this->log, NAME " %p: %m", this);
		return -errno;
	}

	return written;
}

static bool want_flush(struct impl *this)
{
	return (this->frame_count * this->block_size / this->port.frame_size >= MIN_LATENCY);
}

static int encode_buffer(struct impl *this, const void *data, uint32_t size)
{
	int processed;
	size_t out_encoded;
	struct port *port = &this->port;
	const void *from_data = data;
	int from_size = size;

	spa_log_trace(this->log, NAME " %p: encode %d used %d, %d %d %d",
			this, size, this->buffer_used, port->frame_size, this->block_size,
			this->frame_count);

	if (this->need_flush)
		return 0;

	if (this->buffer_used >= sizeof(this->buffer))
		return -ENOSPC;

	if (size < this->block_size - this->tmp_buffer_used) {
		memcpy(this->tmp_buffer + this->tmp_buffer_used, data, size);
		this->tmp_buffer_used += size;
		return size;
	} else if (this->tmp_buffer_used > 0) {
		memcpy(this->tmp_buffer + this->tmp_buffer_used, data, this->block_size - this->tmp_buffer_used);
		from_data = this->tmp_buffer;
		from_size = this->block_size;
		this->tmp_buffer_used = this->block_size - this->tmp_buffer_used;
	}

	processed = this->codec->encode(this->codec_data,
				from_data, from_size,
				this->buffer + this->buffer_used,
				sizeof(this->buffer) - this->buffer_used,
				&out_encoded, &this->need_flush);
	if (processed < 0)
		return processed;

	this->sample_count += processed / port->frame_size;
	this->frame_count += processed / this->block_size;
	this->buffer_used += out_encoded;

	spa_log_trace(this->log, NAME " %p: processed %d %zd used %d",
			this, processed, out_encoded, this->buffer_used);

	if (this->tmp_buffer_used) {
		processed = this->tmp_buffer_used;
		this->tmp_buffer_used = 0;
	}
	return processed;
}

static int flush_buffer(struct impl *this)
{
	spa_log_trace(this->log, NAME" %p: used:%d block_size:%d", this,
			this->buffer_used, this->block_size);

	if (this->need_flush || want_flush(this))
		return send_buffer(this);

	return 0;
}

static int add_data(struct impl *this, const void *data, uint32_t size)
{
	int processed, total = 0;

	while (size > 0) {
		processed = encode_buffer(this, data, size);

		if (processed <= 0)
			return total > 0 ? total : processed;

		data = SPA_MEMBER(data, processed, void);
		size -= processed;
		total += processed;
	}
	return total;
}

static void enable_flush(struct impl *this, bool enabled)
{
	if (SPA_FLAG_IS_SET(this->flush_source.mask, SPA_IO_OUT) != enabled) {
		SPA_FLAG_UPDATE(this->flush_source.mask, SPA_IO_OUT, enabled);
		spa_loop_update_source(this->data_loop, &this->flush_source);
	}
}

static int flush_data(struct impl *this, uint64_t now_time)
{
	int written;
	uint32_t total_frames;
	struct port *port = &this->port;

	total_frames = 0;
again:
	written = 0;
	while (!spa_list_is_empty(&port->ready) && !this->need_flush) {
		uint8_t *src;
		uint32_t n_bytes, n_frames;
		struct buffer *b;
		struct spa_data *d;
		uint32_t index, offs, avail, l0, l1;

		b = spa_list_first(&port->ready, struct buffer, link);
		d = b->buf->datas;

		src = d[0].data;

		index = d[0].chunk->offset + port->ready_offset;
		avail = d[0].chunk->size - port->ready_offset;
		avail /= port->frame_size;

		offs = index % d[0].maxsize;
		n_frames = avail;
		n_bytes = n_frames * port->frame_size;

		l0 = SPA_MIN(n_bytes, d[0].maxsize - offs);
		l1 = n_bytes - l0;

		written = add_data(this, src + offs, l0);
		if (written > 0 && l1 > 0)
			written += add_data(this, src, l1);
		if (written <= 0) {
			if (written < 0 && written != -ENOSPC) {
				spa_list_remove(&b->link);
				SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
				this->port.io->buffer_id = b->id;
				spa_log_warn(this->log, NAME " %p: error %s, reuse buffer %u",
						this, spa_strerror(written), b->id);
				spa_node_call_reuse_buffer(&this->callbacks, 0, b->id);
				port->ready_offset = 0;
			}
			break;
		}

		n_frames = written / port->frame_size;

		port->ready_offset += written;

		if (port->ready_offset >= d[0].chunk->size) {
			spa_list_remove(&b->link);
			SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
			spa_log_trace(this->log, NAME " %p: reuse buffer %u", this, b->id);
			this->port.io->buffer_id = b->id;

			spa_node_call_reuse_buffer(&this->callbacks, 0, b->id);
			port->ready_offset = 0;
		}
		total_frames += n_frames;

		spa_log_trace(this->log, NAME " %p: written %u frames", this, total_frames);
	}

	if (written > 0 && this->buffer_used == this->header_size) {
		enable_flush(this, false);
		return 0;
	}

	written = flush_buffer(this);
	if (written == -EAGAIN) {
		spa_log_trace(this->log, NAME" %p: delay flush", this);
		if (now_time - this->last_error > SPA_NSEC_PER_SEC / 2) {
			this->codec->reduce_bitpool(this->codec_data);
			this->last_error = now_time;
		}
		this->need_flush = true;
		enable_flush(this, true);
	}
	else if (written < 0) {
		spa_log_trace(this->log, NAME" %p: error flushing %s", this,
				spa_strerror(written));
		reset_buffer(this);
		return written;
	}
	else if (written > 0) {
		reset_buffer(this);
		if (now_time - this->last_error > SPA_NSEC_PER_SEC) {
			this->codec->increase_bitpool(this->codec_data);
			this->last_error = now_time;
		}
		if (!spa_list_is_empty(&port->ready))
			goto again;

		enable_flush(this, false);
	}
	return 0;
}

static void a2dp_on_flush(struct spa_source *source)
{
	struct impl *this = source->data;

	spa_log_trace(this->log, NAME" %p: flushing", this);

	if (!SPA_FLAG_IS_SET(source->rmask, SPA_IO_OUT)) {
		spa_log_warn(this->log, NAME" %p: error %d", this, source->rmask);
		if (this->flush_source.loop)
			spa_loop_remove_source(this->data_loop, &this->flush_source);
		return;
	}
	flush_data(this, this->current_time);
}

static void a2dp_on_timeout(struct spa_source *source)
{
	struct impl *this = source->data;
	struct port *port = &this->port;
	uint64_t exp, duration;
	uint32_t rate;
	struct spa_io_buffers *io = port->io;
	uint64_t prev_time, now_time;

	if (this->transport == NULL)
		return;

	if (this->started && spa_system_timerfd_read(this->data_system, this->timerfd, &exp) < 0)
		spa_log_warn(this->log, "error reading timerfd: %s", strerror(errno));

	prev_time = this->current_time;
	now_time = this->current_time = this->next_time;

	spa_log_debug(this->log, NAME" %p: timeout %"PRIu64" %"PRIu64"", this,
			now_time, now_time - prev_time);

	if (SPA_LIKELY(this->position)) {
		duration = this->position->clock.duration;
		rate = this->position->clock.rate.denom;
	} else {
		duration = 1024;
		rate = 48000;
	}

	this->next_time = now_time + duration * SPA_NSEC_PER_SEC / rate;

	if (SPA_LIKELY(this->clock)) {
		int64_t delay_nsec;

		this->clock->nsec = now_time;
		this->clock->position += duration;
		this->clock->duration = duration;
		this->clock->rate_diff = 1.0f;
		this->clock->next_nsec = this->next_time;

		delay_nsec = spa_bt_transport_get_delay_nsec(this->transport);

		/* Negative delay doesn't work properly, so disallow it */
		delay_nsec += SPA_CLAMP(this->props.latency_offset, -delay_nsec, INT64_MAX / 2);

		this->clock->delay = (delay_nsec * this->clock->rate.denom) / SPA_NSEC_PER_SEC;
	}


	spa_log_trace(this->log, NAME " %p: %d", this, io->status);
	io->status = SPA_STATUS_NEED_DATA;
	spa_node_call_ready(&this->callbacks, SPA_STATUS_NEED_DATA);

	set_timeout(this, this->next_time);
}

static int do_start(struct impl *this)
{
	int i, res, val, size;
	struct port *port;
	socklen_t len;
	uint8_t *conf;

	if (this->started)
		return 0;

	spa_return_val_if_fail(this->transport, -EIO);

	this->following = is_following(this);

        spa_log_debug(this->log, NAME " %p: start following:%d", this, this->following);

	if ((res = spa_bt_transport_acquire(this->transport, false)) < 0)
		return res;

	port = &this->port;

	conf = this->transport->configuration;
	size = this->transport->configuration_len;

	for (i = 0; i < size; i++)
		spa_log_debug(this->log, "  %d: %02x", i, conf[i]);

	this->codec_data = this->codec->init(this->codec, 0,
			this->transport->configuration,
			this->transport->configuration_len,
			&port->current_format,
			this->codec_props,
			this->transport->write_mtu);
	if (this->codec_data == NULL)
		return -EIO;

        spa_log_info(this->log, NAME " %p: using A2DP codec %s, delay:%"PRIi64" ms", this, this->codec->description,
                     (int64_t)(spa_bt_transport_get_delay_nsec(this->transport) / SPA_NSEC_PER_MSEC));

	this->seqnum = 0;

	this->block_size = this->codec->get_block_size(this->codec_data);
	if (this->block_size > sizeof(this->tmp_buffer)) {
		spa_log_error(this->log, "block-size %d > %zu",
				this->block_size, sizeof(this->tmp_buffer));
		return -EIO;
	}

        spa_log_debug(this->log, NAME " %p: block_size %d", this,
			this->block_size);

	val = this->codec->send_buf_size > 0
			/* The kernel doubles the SO_SNDBUF option value set by setsockopt(). */
			? this->codec->send_buf_size / 2 + this->codec->send_buf_size % 2
			: FILL_FRAMES * this->transport->write_mtu;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_SNDBUF, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, NAME " %p: SO_SNDBUF %m", this);

	len = sizeof(val);
	if (getsockopt(this->transport->fd, SOL_SOCKET, SO_SNDBUF, &val, &len) < 0) {
		spa_log_warn(this->log, NAME " %p: SO_SNDBUF %m", this);
	}
	else {
		spa_log_debug(this->log, NAME " %p: SO_SNDBUF: %d", this, val);
	}
	this->fd_buffer_size = val;

	val = FILL_FRAMES * this->transport->read_mtu;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_RCVBUF, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, NAME " %p: SO_RCVBUF %m", this);

	val = 6;
	if (setsockopt(this->transport->fd, SOL_SOCKET, SO_PRIORITY, &val, sizeof(val)) < 0)
		spa_log_warn(this->log, "SO_PRIORITY failed: %m");

	reset_buffer(this);

	this->source.data = this;
	this->source.fd = this->timerfd;
	this->source.func = a2dp_on_timeout;
	this->source.mask = SPA_IO_IN;
	this->source.rmask = 0;
	spa_loop_add_source(this->data_loop, &this->source);

	this->flush_source.data = this;
	this->flush_source.fd = this->transport->fd;
	this->flush_source.func = a2dp_on_flush;
	this->flush_source.mask = 0;
	this->flush_source.rmask = 0;
	spa_loop_add_source(this->data_loop, &this->flush_source);

	set_timers(this);
	this->started = true;

	return 0;
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct impl *this = user_data;
	struct itimerspec ts;

	if (this->source.loop)
		spa_loop_remove_source(this->data_loop, &this->source);
	ts.it_value.tv_sec = 0;
	ts.it_value.tv_nsec = 0;
	ts.it_interval.tv_sec = 0;
	ts.it_interval.tv_nsec = 0;
	spa_system_timerfd_settime(this->data_system, this->timerfd, 0, &ts, NULL);
	if (this->flush_source.loop)
		spa_loop_remove_source(this->data_loop, &this->flush_source);

	return 0;
}

static int do_stop(struct impl *this)
{
	int res = 0;

	if (!this->started)
		return 0;

        spa_log_trace(this->log, NAME " %p: stop", this);

	spa_loop_invoke(this->data_loop, do_remove_source, 0, NULL, 0, true, this);

	this->started = false;

	if (this->transport)
		res = spa_bt_transport_release(this->transport);

	if (this->codec_data)
		this->codec->deinit(this->codec_data);
	this->codec_data = NULL;

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

static const struct spa_dict_item node_info_items[] = {
	{ SPA_KEY_DEVICE_API, "bluez5" },
	{ SPA_KEY_MEDIA_CLASS, "Audio/Sink" },
	{ SPA_KEY_NODE_DRIVER, "true" },
	{ SPA_KEY_NODE_LATENCY, SPA_STRINGIFY(MIN_LATENCY)"/48000" },
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
		spa_node_emit_port_info(&this->hooks,
				SPA_DIRECTION_INPUT, 0, &port->info);
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
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 2, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							this->props.min_latency * port->frame_size,
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
		spa_list_init(&port->ready);
		port->n_buffers = 0;
	}
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

		b->buf = buffers[i];
		b->id = i;
		SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		if (buffers[i]->datas[0].data == NULL) {
			spa_log_error(this->log, NAME " %p: need mapped memory", this);
			return -EINVAL;
		}
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
	return -ENOTSUP;
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

	if (io->status == SPA_STATUS_HAVE_DATA && io->buffer_id < port->n_buffers) {
		struct buffer *b = &port->buffers[io->buffer_id];

		if (!SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
			spa_log_warn(this->log, NAME " %p: buffer %u in use", this, io->buffer_id);
			io->status = -EINVAL;
			return -EINVAL;
		}

		spa_log_trace(this->log, NAME " %p: queue buffer %u", this, io->buffer_id);

		spa_list_append(&port->ready, &b->link);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);

		io->buffer_id = SPA_ID_INVALID;
		io->status = SPA_STATUS_OK;
	}
	if (!spa_list_is_empty(&port->ready)) {
		if (this->need_flush)
			reset_buffer(this);
		flush_data(this, this->current_time);
	}

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
	spa_system_close(this->data_system, this->timerfd);
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

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PARAMS |
			SPA_NODE_CHANGE_MASK_PROPS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_input_ports = 1;
	this->info.max_output_ports = 0;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 2;

	port = &this->port;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = 0;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 5;
	spa_list_init(&port->ready);

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_BLUEZ5_TRANSPORT)))
		sscanf(str, "pointer:%p", &this->transport);

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

	this->timerfd = spa_system_timerfd_create(this->data_system,
			CLOCK_MONOTONIC, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);

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
	{ SPA_KEY_FACTORY_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "Play audio with the a2dp" },
	{ SPA_KEY_FACTORY_USAGE, SPA_KEY_API_BLUEZ5_TRANSPORT"=<transport>" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_a2dp_sink_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_BLUEZ5_A2DP_SINK,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
