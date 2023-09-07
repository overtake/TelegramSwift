/* Spa SCO Sink
 *
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
#include <arpa/inet.h>
#include <sys/ioctl.h>

#include <spa/support/plugin.h>
#include <spa/support/loop.h>
#include <spa/support/log.h>
#include <spa/support/system.h>
#include <spa/utils/list.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
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

struct props {
	uint32_t min_latency;
	uint32_t max_latency;
};

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
	int frame_size;
	unsigned int have_format:1;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_io_buffers *io;
	struct spa_io_rate_match *rate_match;
	struct spa_param_info params[8];

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;

	struct spa_list free;
	struct spa_list ready;

	struct buffer *current_buffer;
	uint32_t ready_offset;
	uint8_t write_buffer[4096];
	uint32_t write_buffer_size;
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	/* Support */
	struct spa_log *log;
	struct spa_loop *data_loop;
	struct spa_system *data_system;

	/* Hooks and callbacks */
	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	/* Info */
	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[8];
	struct props props;

	/* Transport */
	struct spa_bt_transport *transport;
	struct spa_hook transport_listener;

	/* Port */
	struct port port;

	/* Flags */
	unsigned int started:1;

	/* Sources */
	struct spa_source source;

	/* Timer */
	int timerfd;
	struct timespec now;
	struct spa_io_clock *clock;
	struct spa_io_position *position;

	/* mSBC */
	sbc_t msbc;
	uint8_t *buffer;
	uint8_t *buffer_head;
	uint8_t *buffer_next;
	int buffer_size;

	/* Times */
	uint64_t start_time;
	uint64_t total_samples;
};

#define NAME "sco-sink"

#define CHECK_PORT(this,d,p)	((d) == SPA_DIRECTION_INPUT && (p) == 0)

static const uint32_t default_min_latency = MIN_LATENCY;
static const uint32_t default_max_latency = MAX_LATENCY;
static const char sntable[4] = { 0x08, 0x38, 0xC8, 0xF8 };

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
				SPA_PROP_minLatency, SPA_POD_Int(p->min_latency),
				SPA_PROP_maxLatency, SPA_POD_Int(p->max_latency));
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

static void set_timeout(struct impl *this, uint64_t timeout)
{
	struct itimerspec ts;

	ts.it_value.tv_sec = timeout / SPA_NSEC_PER_SEC;
	ts.it_value.tv_nsec = timeout % SPA_NSEC_PER_SEC;
	ts.it_interval.tv_sec = 0;
	ts.it_interval.tv_nsec = 0;

	spa_system_timerfd_settime(this->data_system, this->timerfd, 0, &ts, NULL);
	this->source.mask = SPA_IO_IN;
	spa_loop_update_source(this->data_loop, &this->source);
}

static uint64_t get_next_timeout(struct impl *this, uint64_t now_time, uint64_t processed_samples)
{
	struct port *port = &this->port;
	uint64_t playback_time = 0, elapsed_time = 0, next_time = 1;

	this->total_samples += processed_samples;

	playback_time = (this->total_samples * SPA_NSEC_PER_SEC) / port->current_format.info.raw.rate;
	if (now_time > this->start_time)
		elapsed_time = now_time - this->start_time;
	if (elapsed_time < playback_time)
		next_time = playback_time - elapsed_time;

	return next_time;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;

	spa_return_val_if_fail(object != NULL, -EINVAL);

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
		if (apply_props(this, param) > 0) {
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

static void flush_data(struct impl *this)
{
	struct port *port = &this->port;
	struct spa_data *datas;
	uint64_t next_timeout = 1;
	uint32_t min_in_size;
	uint8_t *packet;

	if (this->transport == NULL || this->transport->sco_io == NULL)
		return;

	/* get buffer */
	if (!port->current_buffer) {
		spa_return_if_fail(!spa_list_is_empty(&port->ready));
		port->current_buffer = spa_list_first(&port->ready, struct buffer, link);
		port->ready_offset = 0;
	}
	datas = port->current_buffer->buf->datas;

	if (this->transport->codec == HFP_AUDIO_CODEC_MSBC) {
		min_in_size = MSBC_DECODED_SIZE;
		packet = this->buffer_head;
	} else {
		min_in_size = this->transport->write_mtu;
		packet = port->write_buffer;
	}

	/* if buffer has data, copy it into the write buffer */
	if (datas[0].chunk->size - port->ready_offset > 0) {
		uint32_t avail = SPA_MIN(min_in_size, datas[0].chunk->size - port->ready_offset);
		uint32_t size = (avail + port->write_buffer_size) > min_in_size ? min_in_size - port->write_buffer_size : avail;
		memcpy(port->write_buffer + port->write_buffer_size,
			(uint8_t *)datas[0].data + port->ready_offset,
			size);
		port->write_buffer_size += size;
		port->ready_offset += size;
	}

	/* otherwise request a new buffer */
	else {
		struct buffer *b;

		b = port->current_buffer;
		port->current_buffer = NULL;

		/* reuse buffer */
		spa_list_remove(&b->link);
		b->outstanding = true;
		spa_log_trace(this->log, "sco-sink %p: reuse buffer %u", this, b->id);
		port->io->buffer_id = b->id;
		spa_node_call_reuse_buffer(&this->callbacks, 0, b->id);

		/* notify we need more data */
		port->io->status = SPA_STATUS_NEED_DATA;
		spa_node_call_ready(&this->callbacks, SPA_STATUS_NEED_DATA);

		next_timeout = (this->transport->write_mtu / port->frame_size
				* SPA_NSEC_PER_SEC / port->current_format.info.raw.rate);
		set_timeout(this, next_timeout);
		return;
	}

	/* send the data if the write buffer is full */
	if (port->write_buffer_size >= min_in_size) {
		uint64_t now_time;
		static int sn = 0;
		int processed = 0;
		ssize_t out_encoded;
		int written;

		spa_system_clock_gettime(this->data_system, CLOCK_MONOTONIC, &this->now);
		now_time = SPA_TIMESPEC_TO_NSEC(&this->now);
		if (this->start_time == 0)
			this->start_time = now_time;

		if (this->transport->codec == HFP_AUDIO_CODEC_MSBC) {
			/* Encode */
			if (this->buffer_next + MSBC_ENCODED_SIZE > this->buffer + this->buffer_size) {
				/* Buffer overrun; shouldn't usually happen. Drop data and reset. */
				this->buffer_head = this->buffer_next = this->buffer;
				spa_log_warn(this->log, "sco-sink: mSBC buffer overrun, dropping data");
			}
			this->buffer_next[0] = 0x01;
			this->buffer_next[1] = sntable[sn];
			this->buffer_next[59] = 0x00;
			sn = (sn + 1) % 4;
			processed = sbc_encode(&this->msbc, port->write_buffer, port->write_buffer_size,
			                       this->buffer_next + 2, MSBC_ENCODED_SIZE - 3, &out_encoded);
			if (processed < 0) {
				spa_log_warn(this->log, "sbc_encode failed: %d", processed);
				return;
			}
			this->buffer_next += out_encoded + 3;
			port->write_buffer_size = 0;

			/* Write */
			written = spa_bt_sco_io_write(this->transport->sco_io, packet, this->buffer_next - this->buffer_head);
			if (written < 0) {
				spa_log_warn(this->log, "failed to write data");
				goto stop;
			}
			spa_log_trace(this->log, "wrote socket data %d", written);

			this->buffer_head += written;

			if (this->buffer_head == this->buffer_next)
				this->buffer_head = this->buffer_next = this->buffer;
			else if (this->buffer_next + MSBC_ENCODED_SIZE > this->buffer + this->buffer_size) {
				/* Written bytes is not necessarily commensurate
				 * with MSBC_ENCODED_SIZE. If this occurs, copy data.
				 */
				int size = this->buffer_next - this->buffer_head;
				spa_memmove(this->buffer, this->buffer_head, size);
				this->buffer_next = this->buffer + size;
				this->buffer_head = this->buffer;
			}
		} else {
			written = spa_bt_sco_io_write(this->transport->sco_io, packet, port->write_buffer_size);
			if (written < 0) {
				spa_log_warn(this->log, "sco-sink: write failure: %d", written);
				goto stop;
			}

			processed = written;
			port->write_buffer_size -= written;

			if (port->write_buffer_size > 0 && written > 0) {
				spa_memmove(port->write_buffer, port->write_buffer + written, port->write_buffer_size);
			}
		}

		next_timeout = get_next_timeout(this, now_time, processed / port->frame_size);

		if (this->clock) {
			this->clock->nsec = now_time;
			this->clock->position = this->total_samples;
			this->clock->delay = processed / port->frame_size;
			this->clock->rate_diff = 1.0f;
			this->clock->next_nsec = next_timeout;
		}
	}

	/* schedule next timeout */
	set_timeout(this, next_timeout);
	return;

stop:
	if (this->source.loop)
		spa_loop_remove_source(this->data_loop, &this->source);
}

static void sco_on_timeout(struct spa_source *source)
{
	struct impl *this = source->data;
	struct port *port = &this->port;
	uint64_t exp;

	if (this->transport == NULL)
		return;

	/* Read the timerfd */
	if (this->started && spa_system_timerfd_read(this->data_system, this->timerfd, &exp) < 0)
		spa_log_warn(this->log, "error reading timerfd: %s", strerror(errno));

	/* delay if no buffers available */
	if (spa_list_is_empty(&port->ready)) {
		set_timeout(this, this->transport->write_mtu / port->frame_size * SPA_NSEC_PER_SEC / port->current_format.info.raw.rate);
		port->io->status = SPA_STATUS_NEED_DATA;
		spa_node_call_ready(&this->callbacks, SPA_STATUS_NEED_DATA);
		return;
	}

	/* Flush data */
	flush_data(this);
}

/* greater common divider */
static int gcd(int a, int b) {
    while(b) {
        int c = b;
        b = a % b;
        a = c;
    }
    return a;
}
/* least common multiple */
static int lcm(int a, int b) {
    return (a*b)/gcd(a,b);
}

static int do_start(struct impl *this)
{
	bool do_accept;
	int res;

	/* Don't do anything if the node has already started */
	if (this->started)
		return 0;

	/* Make sure the transport is valid */
	spa_return_val_if_fail(this->transport != NULL, -EIO);

	/* Do accept if Gateway; otherwise do connect for Head Unit */
	do_accept = this->transport->profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY;

	/* acquire the socket fd (false -> connect | true -> accept) */
	if ((res = spa_bt_transport_acquire(this->transport, do_accept)) < 0)
		return res;

	/* Init mSBC if needed */
	if (this->transport->codec == HFP_AUDIO_CODEC_MSBC) {
		sbc_init_msbc(&this->msbc, 0);
		/* Libsbc expects audio samples by default in host endianness, mSBC requires little endian */
		this->msbc.endian = SBC_LE;

		/* write_mtu might not be correct at this point, so we'll throw
		 * in some common ones, at the cost of a potentially larger
		 * allocation (size <= 120 * write_mtu). If it still fails to be
		 * commensurate, we may end up doing memmoves, but nothing worse
		 * is going to happen.
		 */
		this->buffer_size = lcm(24, lcm(60, lcm(this->transport->write_mtu, 2 * MSBC_ENCODED_SIZE)));
		this->buffer = calloc(this->buffer_size, sizeof(uint8_t));
		this->buffer_head = this->buffer_next = this->buffer;
	}

	spa_return_val_if_fail(this->transport->write_mtu <= sizeof(this->port.write_buffer), -EINVAL);

	/* start socket i/o */
	if ((res = spa_bt_transport_ensure_sco_io(this->transport, this->data_loop)) < 0)
		goto fail;

	/* Add the timeout callback */
	this->source.data = this;
	this->source.fd = this->timerfd;
	this->source.func = sco_on_timeout;
	this->source.mask = SPA_IO_IN;
	this->source.rmask = 0;
	spa_loop_add_source(this->data_loop, &this->source);

	/* start processing */
	set_timeout(this, 1);

	/* Set the started flag */
	this->started = true;

	return 0;

fail:
	free(this->buffer);
	this->buffer = NULL;
	spa_bt_transport_release(this->transport);
	return res;
}

/* Drop any buffered data remaining in the port */
static void drop_port_output(struct impl *this)
{
	struct port *port = &this->port;

	port->write_buffer_size = 0;
	port->current_buffer = NULL;
	port->ready_offset = 0;

	while (!spa_list_is_empty(&port->ready)) {
		struct buffer *b;
		b = spa_list_first(&port->ready, struct buffer, link);

		spa_list_remove(&b->link);
		b->outstanding = true;
		port->io->buffer_id = b->id;
		spa_node_call_reuse_buffer(&this->callbacks, 0, b->id);
	}
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct impl *this = user_data;

	this->start_time = 0;
	this->total_samples = 0;
	set_timeout(this, 0);
	if (this->source.loop)
		spa_loop_remove_source(this->data_loop, &this->source);

	/* Drop buffered data in the ready queue. Ideally there shouldn't be any. */
	drop_port_output(this);

	return 0;
}

static int do_stop(struct impl *this)
{
	int res = 0;

	if (!this->started)
		return 0;

	spa_log_trace(this->log, "sco-sink %p: stop", this);

	spa_loop_invoke(this->data_loop, do_remove_source, 0, NULL, 0, true, this);

	this->started = false;

	if (this->buffer) {
		free(this->buffer);
		this->buffer = NULL;
		this->buffer_head = this->buffer_next = this->buffer;
	}

	if (this->transport) {
		/* Release the transport; it is responsible for closing the fd */
		res = spa_bt_transport_release(this->transport);
	}

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
	case SPA_NODE_COMMAND_Pause:
	case SPA_NODE_COMMAND_Suspend:
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
	bool is_ag = (this->transport->profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY);
	struct spa_dict_item ag_node_info_items[] = {
		{ SPA_KEY_DEVICE_API, "bluez5" },
		{ SPA_KEY_MEDIA_CLASS, "Stream/Input/Audio" },
		{ "media.name", ((this->transport && this->transport->device->name) ?
		                 this->transport->device->name : "HSP/HFP") },
	};
	struct spa_dict_item hu_node_info_items[] = {
		{ SPA_KEY_DEVICE_API, "bluez5" },
		{ SPA_KEY_MEDIA_CLASS, "Audio/Sink" },
		{ SPA_KEY_NODE_DRIVER, "true" },
	};

	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		this->info.props = is_ag ?
			&SPA_DICT_INIT_ARRAY(ag_node_info_items) :
			&SPA_DICT_INIT_ARRAY(hu_node_info_items);
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
		if (this->transport == NULL)
			return -EIO;

		/* set the info structure */
		struct spa_audio_info_raw info = { 0, };
		info.format = SPA_AUDIO_FORMAT_S16_LE;
		info.channels = 1;
		info.position[0] = SPA_AUDIO_CHANNEL_MONO;

		/* CVSD format has a rate of 8kHz
		 * MSBC format has a rate of 16kHz */
		if (this->transport->codec == HFP_AUDIO_CODEC_MSBC)
			info.rate = 16000;
		else
			info.rate = 8000;

		/* build the param */
		param = spa_format_audio_raw_build(&b, id, &info);

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
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
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
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_RateMatch),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_rate_match)));
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

		port->frame_size = info.info.raw.channels * 2;
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
		b->outstanding = true;

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
	case SPA_IO_RateMatch:
		port->rate_match = data;
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

		if (!b->outstanding) {
			spa_log_warn(this->log, NAME " %p: buffer %u in use", this, io->buffer_id);
			io->status = -EINVAL;
			return -EINVAL;
		}

		spa_log_trace(this->log, NAME " %p: queue buffer %u", this, io->buffer_id);

		spa_list_append(&port->ready, &b->link);
		b->outstanding = false;
		io->buffer_id = SPA_ID_INVALID;
		io->status = SPA_STATUS_OK;
	}

	if (!spa_list_is_empty(&port->ready))
		flush_data(this);

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
	{ SPA_KEY_FACTORY_AUTHOR, "Collabora Ltd. <contact@collabora.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "Play bluetooth audio with hsp/hfp" },
	{ SPA_KEY_FACTORY_USAGE, SPA_KEY_API_BLUEZ5_TRANSPORT"=<transport>" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

struct spa_handle_factory spa_sco_sink_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_BLUEZ5_SCO_SINK,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
