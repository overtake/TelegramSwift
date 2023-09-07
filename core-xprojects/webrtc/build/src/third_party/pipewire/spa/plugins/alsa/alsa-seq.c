/* Spa ALSA Sequencer
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sched.h>
#include <errno.h>
#include <getopt.h>
#include <sys/time.h>
#include <math.h>
#include <limits.h>

#include <spa/utils/result.h>
#include <spa/pod/filter.h>
#include <spa/support/system.h>
#include <spa/control/control.h>

#define NAME "alsa-seq"

#include "dll.h"
#include "alsa-seq.h"

#define CHECK(s,msg,...) if ((res = (s)) < 0) { spa_log_error(state->log, msg ": %s", ##__VA_ARGS__, snd_strerror(res)); return res; }

static int seq_open(struct seq_state *state, struct seq_conn *conn, bool with_queue)
{
	struct props *props = &state->props;
	int res;

	spa_log_debug(state->log, "%p: ALSA seq open '%s' duplex", state, props->device);

	if ((res = snd_seq_open(&conn->hndl,
			   props->device,
			   SND_SEQ_OPEN_DUPLEX,
			   0)) < 0) {
		return res;
	}
	return 0;
}

static int seq_init(struct seq_state *state, struct seq_conn *conn, bool with_queue)
{
	struct pollfd pfd;
	snd_seq_port_info_t *pinfo;
	int res;

	/* client id */
	if ((res = snd_seq_client_id(conn->hndl)) < 0) {
		spa_log_error(state->log, "failed to get client id: %d", res);
		goto error_exit_close;
        }
	conn->addr.client = res;

	/* queue */
	if (with_queue) {
		if ((res = snd_seq_alloc_queue(conn->hndl)) < 0) {
			spa_log_error(state->log, "failed to create queue: %d", res);
			goto error_exit_close;
		}
		conn->queue_id = res;
	} else {
		conn->queue_id = -1;
	}

	if ((res = snd_seq_nonblock(conn->hndl, 1)) < 0)
		spa_log_warn(state->log, "can't set nonblock mode: %s", snd_strerror(res));

	/* port for receiving */
	snd_seq_port_info_alloca(&pinfo);
	snd_seq_port_info_set_name(pinfo, "input");
	snd_seq_port_info_set_type(pinfo, SND_SEQ_PORT_TYPE_MIDI_GENERIC);
	snd_seq_port_info_set_capability(pinfo,
			SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_READ);
        /* Enable timestamping for events sent by external subscribers. */
        snd_seq_port_info_set_timestamping(pinfo, 1);
        snd_seq_port_info_set_timestamp_real(pinfo, 1);
	if (with_queue)
	        snd_seq_port_info_set_timestamp_queue(pinfo, conn->queue_id);

        if ((res = snd_seq_create_port(conn->hndl, pinfo)) < 0) {
		spa_log_error(state->log, "failed to create port: %s", snd_strerror(res));
		goto error_exit_close;
        }
        conn->addr.port = snd_seq_port_info_get_port(pinfo);

	spa_log_debug(state->log, "queue:%d client:%d port:%d",
			conn->queue_id, conn->addr.client, conn->addr.port);

	snd_seq_poll_descriptors(conn->hndl, &pfd, 1, POLLIN);
	conn->source.fd = pfd.fd;
	conn->source.mask = SPA_IO_IN;

	return 0;

error_exit_close:
	snd_seq_close(conn->hndl);
	return res;
}

static int seq_close(struct seq_state *state, struct seq_conn *conn)
{
	int res;
	spa_log_debug(state->log, "%p: Device '%s' closing", state, state->props.device);
	if ((res = snd_seq_close(conn->hndl)) < 0) {
		spa_log_warn(state->log, "close failed: %s", snd_strerror(res));
	}
	return res;
}

static int init_stream(struct seq_state *state, enum spa_direction direction)
{
	struct seq_stream *stream = &state->streams[direction];
	stream->direction = direction;
	if (direction == SPA_DIRECTION_INPUT) {
		stream->caps = SND_SEQ_PORT_CAP_SUBS_WRITE;
	} else {
		stream->caps = SND_SEQ_PORT_CAP_SUBS_READ;
	}
	snd_midi_event_new(MAX_EVENT_SIZE, &stream->codec);
	memset(stream->ports, 0, sizeof(stream->ports));
	return 0;
}

static int uninit_stream(struct seq_state *state, enum spa_direction direction)
{
	struct seq_stream *stream = &state->streams[direction];
	snd_midi_event_free(stream->codec);
	return 0;
}

static void init_ports(struct seq_state *state)
{
	snd_seq_addr_t addr;
	snd_seq_client_info_t *client_info;
	snd_seq_port_info_t *port_info;

	snd_seq_client_info_alloca(&client_info);
	snd_seq_port_info_alloca(&port_info);
	snd_seq_client_info_set_client(client_info, -1);

	while (snd_seq_query_next_client(state->sys.hndl, client_info) >= 0) {

		addr.client = snd_seq_client_info_get_client(client_info);
		if (addr.client == SND_SEQ_CLIENT_SYSTEM ||
		    addr.client == state->sys.addr.client ||
		    addr.client == state->event.addr.client)
			continue;

		snd_seq_port_info_set_client(port_info, addr.client);
		snd_seq_port_info_set_port(port_info, -1);
		while (snd_seq_query_next_port(state->sys.hndl, port_info) >= 0) {
			addr.port = snd_seq_port_info_get_port(port_info);
			state->port_info(state->port_info_data, &addr, port_info);
		}
	}
}

static void debug_event(struct seq_state *state, snd_seq_event_t *ev)
{
	if (SPA_LIKELY(!spa_log_level_enabled(state->log, SPA_LOG_LEVEL_TRACE)))
		return;

	spa_log_trace(state->log, "event type:%d flags:0x%x", ev->type, ev->flags);
	switch (ev->flags & SND_SEQ_TIME_STAMP_MASK) {
	case SND_SEQ_TIME_STAMP_TICK:
		spa_log_trace(state->log, " time: %d ticks", ev->time.tick);
		break;
	case SND_SEQ_TIME_STAMP_REAL:
		spa_log_trace(state->log, " time = %d.%09d",
			(int)ev->time.time.tv_sec,
			(int)ev->time.time.tv_nsec);
		break;
	}
	spa_log_trace(state->log, " source:%d.%d dest:%d.%d queue:%d",
		ev->source.client,
		ev->source.port,
		ev->dest.client,
		ev->dest.port,
		ev->queue);
}

static void alsa_seq_on_sys(struct spa_source *source)
{
	struct seq_state *state = source->data;
	snd_seq_event_t *ev;
	int res;

	while (snd_seq_event_input(state->sys.hndl, &ev) > 0) {
		const snd_seq_addr_t *addr = &ev->data.addr;

		if (addr->client == state->event.addr.client)
			continue;

		debug_event(state, ev);

		switch (ev->type) {
		case SND_SEQ_EVENT_CLIENT_START:
		case SND_SEQ_EVENT_CLIENT_CHANGE:
			spa_log_info(state->log, "client add/change %d", addr->client);
			break;
		case SND_SEQ_EVENT_CLIENT_EXIT:
			spa_log_info(state->log, "client exit %d", addr->client);
			break;

		case SND_SEQ_EVENT_PORT_START:
		case SND_SEQ_EVENT_PORT_CHANGE:
		{
			snd_seq_port_info_t *info;

			snd_seq_port_info_alloca(&info);

			if ((res = snd_seq_get_any_port_info(state->sys.hndl,
					addr->client, addr->port, info)) < 0) {
				spa_log_warn(state->log, "can't get port info %d.%d: %s",
						addr->client, addr->port, snd_strerror(res));
			} else {
				spa_log_info(state->log, "port add/change %d:%d",
						addr->client, addr->port);
				state->port_info(state->port_info_data, addr, info);
			}
			break;
		}
		case SND_SEQ_EVENT_PORT_EXIT:
			spa_log_info(state->log, "port_event: del %d:%d",
					addr->client, addr->port);
			state->port_info(state->port_info_data, addr, NULL);
			break;
		}
		snd_seq_free_event(ev);
        }
}

int spa_alsa_seq_open(struct seq_state *state)
{
	int n, i, res;
	snd_seq_port_subscribe_t *sub;
	snd_seq_addr_t addr;
	snd_seq_queue_timer_t *timer;
	struct seq_conn reserve[16];

	if (state->opened)
		return 0;

	init_stream(state, SPA_DIRECTION_INPUT);
	init_stream(state, SPA_DIRECTION_OUTPUT);

	spa_zero(reserve);
	for (i = 0; i < 16; i++) {
		spa_log_debug(state->log, "close %d", i);
		if ((res = seq_open(state, &reserve[i], false)) < 0)
			break;
	}
	if (i >= 2) {
		state->event = reserve[--i];
		state->sys = reserve[--i];
		res = 0;
	}
	for (n = --i; n >= 0; n--) {
		spa_log_debug(state->log, "close %d", n);
		seq_close(state, &reserve[n]);
	}
	if (res < 0) {
		spa_log_error(state->log, "open failed: %s", snd_strerror(res));
		return res;
	}

	if ((res = seq_init(state, &state->sys, false)) < 0)
		goto error_close;

	snd_seq_set_client_name(state->sys.hndl, "PipeWire-System");

	if ((res = seq_init(state, &state->event, true)) < 0)
		goto error_close;

	snd_seq_set_client_name(state->event.hndl, "PipeWire-RT-Event");

	/* connect to system announce */
	snd_seq_port_subscribe_alloca(&sub);
	addr.client = SND_SEQ_CLIENT_SYSTEM;
	addr.port = SND_SEQ_PORT_SYSTEM_ANNOUNCE;
	snd_seq_port_subscribe_set_sender(sub, &addr);
	snd_seq_port_subscribe_set_dest(sub, &state->sys.addr);
	if ((res = snd_seq_subscribe_port(state->sys.hndl, sub)) < 0) {
		spa_log_warn(state->log, "failed to connect announce port: %s", snd_strerror(res));
	}

	addr.client = SND_SEQ_CLIENT_SYSTEM;
	addr.port = SND_SEQ_PORT_SYSTEM_TIMER;
	snd_seq_port_subscribe_set_sender(sub, &addr);
	if ((res = snd_seq_subscribe_port(state->sys.hndl, sub)) < 0) {
		spa_log_warn(state->log, "failed to connect timer port: %s", snd_strerror(res));
	}

	state->sys.source.func = alsa_seq_on_sys;
	state->sys.source.data = state;
	spa_loop_add_source(state->main_loop, &state->sys.source);

	/* increase event queue timer resolution */
	snd_seq_queue_timer_alloca(&timer);
	if ((res = snd_seq_get_queue_timer(state->event.hndl, state->event.queue_id, timer)) < 0) {
		spa_log_warn(state->log, "failed to get queue timer: %s", snd_strerror(res));
	}
	snd_seq_queue_timer_set_resolution(timer, INT_MAX);
	if ((res = snd_seq_set_queue_timer(state->event.hndl, state->event.queue_id, timer)) < 0) {
		spa_log_warn(state->log, "failed to set queue timer: %s", snd_strerror(res));
	}

	init_ports(state);

	if ((res = spa_system_timerfd_create(state->data_system,
			CLOCK_MONOTONIC, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK)) < 0)
		goto error_close;

	state->timerfd = res;

	state->opened = true;

	return 0;

error_close:
	seq_close(state, &state->event);
	seq_close(state, &state->sys);
	return res;
}

int spa_alsa_seq_close(struct seq_state *state)
{
	int res = 0;

	if (!state->opened)
		return 0;

	spa_loop_remove_source(state->main_loop, &state->sys.source);

	seq_close(state, &state->sys);
	seq_close(state, &state->event);

	uninit_stream(state, SPA_DIRECTION_INPUT);
	uninit_stream(state, SPA_DIRECTION_OUTPUT);

	spa_system_close(state->data_system, state->timerfd);
	state->opened = false;

	return res;
}

static int set_timeout(struct seq_state *state, uint64_t time)
{
	struct itimerspec ts;

	ts.it_value.tv_sec = time / SPA_NSEC_PER_SEC;
	ts.it_value.tv_nsec = time % SPA_NSEC_PER_SEC;
	ts.it_interval.tv_sec = 0;
	ts.it_interval.tv_nsec = 0;
	spa_system_timerfd_settime(state->data_system,
			state->timerfd, SPA_FD_TIMER_ABSTIME, &ts, NULL);
	return 0;
}

static struct seq_port *find_port(struct seq_state *state,
		struct seq_stream *stream, const snd_seq_addr_t *addr)
{
	uint32_t i;
	for (i = 0; i < stream->last_port; i++) {
		struct seq_port *port = &stream->ports[i];
		if (port->valid &&
		    port->addr.client == addr->client &&
		    port->addr.port == addr->port)
			return port;
	}
	return NULL;
}

int spa_alsa_seq_activate_port(struct seq_state *state, struct seq_port *port, bool active)
{
	int res;
	snd_seq_port_subscribe_t* sub;

	spa_log_debug(state->log, "activate: %d.%d: started:%d active:%d wanted:%d",
			port->addr.client, port->addr.port, state->started, port->active, active);

	if (active && !state->started)
		return 0;
	if (port->active == active)
		return 0;

	snd_seq_port_subscribe_alloca(&sub);
	if (port->direction == SPA_DIRECTION_OUTPUT) {
		snd_seq_port_subscribe_set_sender(sub, &port->addr);
		snd_seq_port_subscribe_set_dest(sub, &state->event.addr);
	} else {
		snd_seq_port_subscribe_set_sender(sub, &state->event.addr);
		snd_seq_port_subscribe_set_dest(sub, &port->addr);
	}

	if (active) {
		snd_seq_port_subscribe_set_time_update(sub, 1);
		snd_seq_port_subscribe_set_time_real(sub, 1);
		snd_seq_port_subscribe_set_queue(sub, state->event.queue_id);
		if ((res = snd_seq_subscribe_port(state->event.hndl, sub)) < 0) {
			spa_log_error(state->log, "can't subscribe to %d:%d - %s",
				port->addr.client, port->addr.port, snd_strerror(res));
			active = false;
		}
		spa_log_info(state->log, "subscribe: %s port %d.%d",
				port->direction == SPA_DIRECTION_OUTPUT ? "output" : "input",
				port->addr.client, port->addr.port);
	} else {
		if ((res = snd_seq_unsubscribe_port(state->event.hndl, sub)) < 0) {
			spa_log_warn(state->log, "can't unsubscribe from %d:%d - %s",
				port->addr.client, port->addr.port, snd_strerror(res));
		}
		spa_log_info(state->log, "unsubscribe: %s port %d.%d",
				port->direction == SPA_DIRECTION_OUTPUT ? "output" : "input",
				port->addr.client, port->addr.port);
	}
	port->active = active;
	return res;
}

static struct buffer *peek_buffer(struct seq_state *state,
		struct seq_port *port)
{
	if (spa_list_is_empty(&port->free))
		return NULL;
	return spa_list_first(&port->free, struct buffer, link);
}

int spa_alsa_seq_recycle_buffer(struct seq_state *state, struct seq_port *port, uint32_t buffer_id)
{
	struct buffer *b = &port->buffers[buffer_id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		spa_log_trace_fp(state->log, NAME " %p: recycle buffer port:%p buffer-id:%u",
				state, port, buffer_id);
		spa_list_append(&port->free, &b->link);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
	}
	return 0;
}

static int prepare_buffer(struct seq_state *state, struct seq_port *port)
{
	if (port->buffer != NULL)
		return 0;

	if ((port->buffer = peek_buffer(state, port)) == NULL)
		return -EPIPE;

	spa_pod_builder_init(&port->builder,
			port->buffer->buf->datas[0].data,
			port->buffer->buf->datas[0].maxsize);
        spa_pod_builder_push_sequence(&port->builder, &port->frame, 0);

	return 0;
}

static int process_recycle(struct seq_state *state)
{
	struct seq_stream *stream = &state->streams[SPA_DIRECTION_OUTPUT];
	uint32_t i;

	for (i = 0; i < stream->last_port; i++) {
		struct seq_port *port = &stream->ports[i];
		struct spa_io_buffers *io = port->io;

		if (!port->valid || io == NULL)
			continue;

		if (io->status != SPA_STATUS_HAVE_DATA &&
		    io->buffer_id < port->n_buffers) {
			spa_alsa_seq_recycle_buffer(state, port, io->buffer_id);
			io->buffer_id = SPA_ID_INVALID;
		}
	}
	return 0;
}

static int process_read(struct seq_state *state)
{
	snd_seq_event_t *ev;
	struct seq_stream *stream = &state->streams[SPA_DIRECTION_OUTPUT];
	uint32_t i;
	long size;
	uint8_t data[MAX_EVENT_SIZE];
	int res;

	/* copy all new midi events into their port buffers */
	while (snd_seq_event_input(state->event.hndl, &ev) > 0) {
		const snd_seq_addr_t *addr = &ev->source;
		struct seq_port *port;
		uint64_t ev_time, diff;
		uint32_t offset;

		debug_event(state, ev);

		if ((port = find_port(state, stream, addr)) == NULL) {
			spa_log_debug(state->log, "unknown port %d.%d",
					addr->client, addr->port);
			continue;
		}
		if (port->io == NULL || port->n_buffers == 0)
			continue;

		if ((res = prepare_buffer(state, port)) < 0) {
			spa_log_debug(state->log, "can't prepare buffer port:%p %d.%d: %s",
					port, addr->client, addr->port, spa_strerror(res));
			continue;
		}

		snd_midi_event_reset_decode(stream->codec);
		if ((size = snd_midi_event_decode(stream->codec, data, MAX_EVENT_SIZE, ev)) < 0) {
			spa_log_warn(state->log, "decode failed: %s", snd_strerror(size));
			continue;
		}

		/* fixup NoteOn with vel 0 */
		if ((data[0] & 0xF0) == 0x90 && data[2] == 0x00) {
			data[0] = 0x80 + (data[0] & 0x0F);
			data[2] = 0x40;
		}

		/* queue_time is the estimated current time of the queue as calculated by
		 * the DLL. Calculate the age of the event. */
		ev_time = SPA_TIMESPEC_TO_NSEC(&ev->time.time);
		if (state->queue_time > ev_time)
			diff = state->queue_time - ev_time;
		else
			diff = 0;

		/* convert the age to samples and convert to an offset */
		offset = (diff * state->rate.denom) / (state->rate.num * SPA_NSEC_PER_SEC);
		if (state->duration > offset)
			offset = state->duration - offset;
		else
			offset = 0;

		spa_log_trace_fp(state->log, "event time:%"PRIu64" offset:%d size:%ld port:%d.%d",
				ev_time, offset, size, addr->client, addr->port);

		spa_pod_builder_control(&port->builder, offset, SPA_CONTROL_Midi);
		spa_pod_builder_bytes(&port->builder, data, size);

		snd_seq_free_event(ev);
        }

	/* prepare a buffer on each port, some ports might have their
	 * buffer filled above */
	res = 0;
	for (i = 0; i < stream->last_port; i++) {
		struct seq_port *port = &stream->ports[i];
		struct spa_io_buffers *io = port->io;

		if (!port->valid || io == NULL)
			continue;

		if (prepare_buffer(state, port) >= 0) {
			port->buffer->buf->datas[0].chunk->offset = 0;
			port->buffer->buf->datas[0].chunk->size = port->builder.state.offset,

			spa_pod_builder_pop(&port->builder, &port->frame);

			/* move buffer to ready queue */
			spa_list_remove(&port->buffer->link);
			SPA_FLAG_SET(port->buffer->flags, BUFFER_FLAG_OUT);
			spa_list_append(&port->ready, &port->buffer->link);
			port->buffer = NULL;
		}

		/* if there is already data, continue */
		if (io->status == SPA_STATUS_HAVE_DATA) {
			res |= SPA_STATUS_HAVE_DATA;
			continue;
		}

		if (io->buffer_id < port->n_buffers)
			spa_alsa_seq_recycle_buffer(state, port, io->buffer_id);

		if (spa_list_is_empty(&port->ready)) {
			/* we have no ready buffers */
			io->buffer_id = SPA_ID_INVALID;
			io->status = -EPIPE;
		} else {
			struct buffer *b = spa_list_first(&port->ready, struct buffer, link);
			spa_list_remove(&b->link);

			/* dequeue ready buffer */
			io->buffer_id = b->id;
			io->status = SPA_STATUS_HAVE_DATA;
			res |= SPA_STATUS_HAVE_DATA;
		}
	}
	return res;
}

static int process_write(struct seq_state *state)
{
	struct seq_stream *stream = &state->streams[SPA_DIRECTION_INPUT];
	uint32_t i;
	int res = 0;

	for (i = 0; i < stream->last_port; i++) {
		struct seq_port *port = &stream->ports[i];
		struct spa_io_buffers *io = port->io;
		struct buffer *buffer;
		struct spa_pod_sequence *pod;
		struct spa_data *d;
		struct spa_pod_control *c;
		snd_seq_event_t ev;
		uint64_t out_time;
		snd_seq_real_time_t out_rt;

		if (!port->valid || io == NULL)
			continue;

		if (io->status != SPA_STATUS_HAVE_DATA ||
		    io->buffer_id >= port->n_buffers)
			continue;

		buffer = &port->buffers[io->buffer_id];
		d = &buffer->buf->datas[0];

		io->status = SPA_STATUS_NEED_DATA;
		spa_node_call_reuse_buffer(&state->callbacks, i, io->buffer_id);
		res |= SPA_STATUS_NEED_DATA;

		pod = spa_pod_from_data(d->data, d->maxsize, d->chunk->offset, d->chunk->size);
		if (pod == NULL) {
			spa_log_warn(state->log, "invalid sequence in buffer max:%u offset:%u size:%u",
					d->maxsize, d->chunk->offset, d->chunk->size);
			continue;
		}

		SPA_POD_SEQUENCE_FOREACH(pod, c) {
			long size;

			if (c->type != SPA_CONTROL_Midi)
				continue;

			snd_seq_ev_clear(&ev);

			snd_midi_event_reset_encode(stream->codec);
			if ((size = snd_midi_event_encode(stream->codec,
						SPA_POD_BODY(&c->value),
						SPA_POD_BODY_SIZE(&c->value), &ev)) <= 0) {
				spa_log_warn(state->log, "failed to encode event: %s",
						snd_strerror(size));
	                        continue;
			}

			snd_seq_ev_set_source(&ev, state->event.addr.port);
			snd_seq_ev_set_dest(&ev, port->addr.client, port->addr.port);

			out_time = state->queue_time +
				(c->offset * state->rate.num * SPA_NSEC_PER_SEC) / state->rate.denom;

			out_rt.tv_nsec = out_time % SPA_NSEC_PER_SEC;
			out_rt.tv_sec = out_time / SPA_NSEC_PER_SEC;
			snd_seq_ev_schedule_real(&ev, state->event.queue_id, 0, &out_rt);

			spa_log_trace_fp(state->log, "event time:%"PRIu64" offset:%d size:%ld port:%d.%d",
				out_time, c->offset, size, port->addr.client, port->addr.port);

			if ((res = snd_seq_event_output(state->event.hndl, &ev)) < 0) {
				spa_log_warn(state->log, "failed to output event: %s",
						snd_strerror(res));
			}
		}
	}
	snd_seq_drain_output(state->event.hndl);

	return res;
}

#define NSEC_TO_CLOCK(c,n) ((n) * (c)->rate.denom / ((c)->rate.num * SPA_NSEC_PER_SEC))

static int update_time(struct seq_state *state, uint64_t nsec, bool follower)
{
	snd_seq_queue_status_t *status;
	const snd_seq_real_time_t* queue_time;
	uint64_t queue_real, position;
	double err, corr;
	uint64_t clock_elapsed, queue_elapsed;

	if (state->position) {
		struct spa_io_clock *clock = &state->position->clock;
		state->rate = clock->rate;
		state->duration = clock->duration;
		state->threshold = state->duration;
		position = clock->position;
	} else {
		position = 0;
	}

	/* take queue time */
	snd_seq_queue_status_alloca(&status);
        snd_seq_get_queue_status(state->event.hndl, state->event.queue_id, status);
	queue_time = snd_seq_queue_status_get_real_time(status);
	queue_real = SPA_TIMESPEC_TO_NSEC(queue_time);

	if (state->queue_base == 0) {
		state->queue_base = nsec - queue_real;
		state->clock_base = position;
	}

	corr = 1.0 - (state->dll.z2 + state->dll.z3);

	clock_elapsed = position - state->clock_base;
	state->queue_time = nsec - state->queue_base;
	queue_elapsed = NSEC_TO_CLOCK(state->clock, state->queue_time) / corr;

	err = ((int64_t)clock_elapsed - (int64_t) queue_elapsed);

	if (state->dll.bw == 0.0) {
		spa_dll_set_bw(&state->dll, SPA_DLL_BW_MAX, state->threshold,
				state->rate.denom);
		state->next_time = nsec;
		state->base_time = nsec;
	}
	corr = spa_dll_update(&state->dll, err);

	if ((state->next_time - state->base_time) > BW_PERIOD) {
		state->base_time = state->next_time;
		spa_log_debug(state->log, NAME" %p: follower:%d rate:%f bw:%f err:%f (%f %f %f)",
				state, follower, corr, state->dll.bw, err,
				state->dll.z1, state->dll.z2, state->dll.z3);
	}

	state->next_time += state->threshold / corr * 1e9 / state->rate.denom;

	if (!follower && state->clock) {
		state->clock->nsec = nsec;
		state->clock->position += state->duration;
		state->clock->duration = state->duration;
		state->clock->delay = state->duration * corr;
		state->clock->rate_diff = corr;
		state->clock->next_nsec = state->next_time;
	}

	spa_log_trace_fp(state->log, "now:%"PRIu64" queue:%"PRIu64" err:%f corr:%f next:%"PRIu64" thr:%d",
			nsec, queue_real, err, corr, state->next_time, state->threshold);

	return 0;
}

int spa_alsa_seq_process(struct seq_state *state)
{
	int res;

	res = process_recycle(state);

	if (state->following && state->position) {
		update_time(state, state->position->clock.nsec, true);
		res |= process_read(state);
	}
	res |= process_write(state);

	return res;
}

static void alsa_on_timeout_event(struct spa_source *source)
{
	struct seq_state *state = source->data;
	uint64_t expire;
	int res;

	if (state->started && spa_system_timerfd_read(state->data_system, state->timerfd, &expire) < 0)
		spa_log_warn(state->log, "error reading timerfd: %m");

	state->current_time = state->next_time;

	spa_log_trace(state->log, "timeout %"PRIu64, state->current_time);

	update_time(state, state->current_time, false);

	res = process_read(state);
	if (res > 0)
		spa_node_call_ready(&state->callbacks, res);

	set_timeout(state, state->next_time);
}

static void reset_buffers(struct seq_state *this, struct seq_port *port)
{
	uint32_t i;

	spa_list_init(&port->free);
	spa_list_init(&port->ready);

	for (i = 0; i < port->n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		if (port->direction == SPA_DIRECTION_INPUT) {
			SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
		} else {
			spa_list_append(&port->free, &b->link);
			SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
		}
	}
}
static void reset_stream(struct seq_state *this, struct seq_stream *stream, bool active)
{
	uint32_t i;
	for (i = 0; i < stream->last_port; i++) {
		struct seq_port *port = &stream->ports[i];
		if (port->valid) {
			reset_buffers(this, port);
			spa_alsa_seq_activate_port(this, port, active);
		}
	}
}

static int set_timers(struct seq_state *state)
{
	struct timespec now;

	spa_system_clock_gettime(state->data_system, CLOCK_MONOTONIC, &now);

	state->next_time = SPA_TIMESPEC_TO_NSEC(&now);
	if (state->following) {
		set_timeout(state, 0);
	} else {
		set_timeout(state, state->next_time);
	}
	return 0;
}

static inline bool is_following(struct seq_state *state)
{
	return state->position && state->clock && state->position->clock.id != state->clock->id;
}

int spa_alsa_seq_start(struct seq_state *state)
{
	int res;

	if (state->started)
		return 0;

	state->following = is_following(state);

	spa_log_debug(state->log, "alsa %p: start follower:%d", state, state->following);

	if ((res = snd_seq_start_queue(state->event.hndl, state->event.queue_id, NULL)) < 0) {
		spa_log_error(state->log, "failed to start queue: %s", snd_strerror(res));
		return res;
	}
	while (snd_seq_drain_output(state->event.hndl) > 0)
		sleep(1);

	if (state->position) {
		struct spa_io_clock *clock = &state->position->clock;
		state->rate = clock->rate;
		state->duration = clock->duration;
	} else {
		state->rate = SPA_FRACTION(1, 48000);
		state->duration = 1024;
	}
	state->threshold = state->duration;

	state->started = true;

	reset_stream(state, &state->streams[SPA_DIRECTION_INPUT], true);
	reset_stream(state, &state->streams[SPA_DIRECTION_OUTPUT], true);

	state->source.func = alsa_on_timeout_event;
	state->source.data = state;
	state->source.fd = state->timerfd;
	state->source.mask = SPA_IO_IN;
	state->source.rmask = 0;
	spa_loop_add_source(state->data_loop, &state->source);

	state->queue_base = 0;
	spa_dll_init(&state->dll);
	set_timers(state);

	return 0;
}

static int do_reassign_follower(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct seq_state *state = user_data;
	set_timers(state);
	return 0;
}

int spa_alsa_seq_reassign_follower(struct seq_state *state)
{
	bool following;

	if (!state->started)
		return 0;

	following = is_following(state);
	if (following != state->following) {
		spa_log_debug(state->log, "alsa %p: reassign follower %d->%d", state, state->following, following);
		state->following = following;
		spa_loop_invoke(state->data_loop, do_reassign_follower, 0, NULL, 0, true, state);
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
	struct seq_state *state = user_data;

	spa_loop_remove_source(state->data_loop, &state->source);
	set_timeout(state, 0);

	return 0;
}

int spa_alsa_seq_pause(struct seq_state *state)
{
	int res;

	if (!state->started)
		return 0;

	spa_log_debug(state->log, "alsa %p: pause", state);

	spa_loop_invoke(state->data_loop, do_remove_source, 0, NULL, 0, true, state);

	if ((res = snd_seq_stop_queue(state->event.hndl, state->event.queue_id, NULL)) < 0) {
		spa_log_warn(state->log, "failed to stop queue: %s", snd_strerror(res));
	}
	while (snd_seq_drain_output(state->event.hndl) > 0)
		sleep(1);

	state->started = false;

	reset_stream(state, &state->streams[SPA_DIRECTION_INPUT], false);
	reset_stream(state, &state->streams[SPA_DIRECTION_OUTPUT], false);

	return 0;
}
