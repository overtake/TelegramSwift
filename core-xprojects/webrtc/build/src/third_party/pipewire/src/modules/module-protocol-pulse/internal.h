/* PipeWire
 *
 * Copyright © 2020 Wim Taymans
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

#ifndef PULSE_SERVER_INTERNAL_H
#define PULSE_SERVER_INTERNAL_H

#include "config.h"

#include <sys/socket.h>
#include <sys/un.h>

#include <spa/utils/defs.h>
#include <spa/utils/ringbuffer.h>
#include <pipewire/pipewire.h>
#include <pipewire/private.h>

#include "format.h"

#define NAME	"pulse-server"

struct defs {
	struct spa_fraction min_req;
	struct spa_fraction default_req;
	struct spa_fraction min_frag;
	struct spa_fraction default_frag;
	struct spa_fraction default_tlength;
	struct spa_fraction min_quantum;
	struct sample_spec sample_spec;
	struct channel_map channel_map;
};

struct descriptor {
	uint32_t length;
	uint32_t channel;
	uint32_t offset_hi;
	uint32_t offset_lo;
	uint32_t flags;
};

struct stats {
	uint32_t n_allocated;
	uint32_t allocated;
	uint32_t n_accumulated;
	uint32_t accumulated;
	uint32_t sample_cache;
};

struct impl;
struct server;
struct client;

struct client {
	struct spa_list link;
	struct impl *impl;
	struct server *server;

	int ref;
	const char *name;

	struct spa_source *source;

	uint32_t version;

	struct pw_properties *props;

	struct pw_core *core;
	struct pw_manager *manager;
	struct spa_hook manager_listener;

	uint32_t subscribed;

	struct pw_manager_object *metadata_default;
	char *default_sink;
	char *default_source;
	struct pw_manager_object *metadata_routes;
	struct pw_properties *routes;

	uint32_t connect_tag;

	uint32_t in_index;
	uint32_t out_index;
	struct descriptor desc;
	struct message *message;

	struct pw_map streams;
	struct spa_list out_messages;

	struct spa_list operations;
	struct spa_list loading_modules;

	struct spa_list pending_samples;

	unsigned int disconnect:1;
	unsigned int disconnecting:1;
	unsigned int need_flush:1;

	struct pw_manager_object *prev_default_sink;
	struct pw_manager_object *prev_default_source;
};

struct buffer_attr {
	uint32_t maxlength;
	uint32_t tlength;
	uint32_t prebuf;
	uint32_t minreq;
	uint32_t fragsize;
};

struct volume {
	uint8_t channels;
	float values[CHANNELS_MAX];
};

#define VOLUME_INIT	(struct volume) {		\
				.channels = 0,		\
			}

struct stream {
	uint32_t create_tag;
	uint32_t channel;	/* index in map */
	uint32_t id;		/* id of global */

	struct impl *impl;
	struct client *client;
#define STREAM_TYPE_RECORD	0
#define STREAM_TYPE_PLAYBACK	1
#define STREAM_TYPE_UPLOAD	2
	uint32_t type;
	enum pw_direction direction;

	struct pw_properties *props;

	struct pw_stream *stream;
	struct spa_hook stream_listener;

	struct spa_io_rate_match *rate_match;
	struct spa_ringbuffer ring;
	void *buffer;

	int64_t read_index;
	int64_t write_index;
	uint64_t underrun_for;
	uint64_t playing_for;
	uint64_t ticks_base;
	uint64_t timestamp;
	int64_t delay;

	uint32_t missing;
	uint32_t requested;

	struct sample_spec ss;
	struct channel_map map;
	struct buffer_attr attr;
	uint32_t frame_size;
	uint32_t rate;

	struct volume volume;
	bool muted;

	uint32_t drain_tag;
	unsigned int corked:1;
	unsigned int draining:1;
	unsigned int volume_set:1;
	unsigned int muted_set:1;
	unsigned int early_requests:1;
	unsigned int adjust_latency:1;
	unsigned int is_underrun:1;
	unsigned int in_prebuf:1;
	unsigned int done:1;
	unsigned int killed:1;
};

struct server {
	struct spa_list link;
	struct impl *impl;

#define SERVER_TYPE_INVALID	0
#define SERVER_TYPE_UNIX	1
#define SERVER_TYPE_INET	2
	uint32_t type;
	struct sockaddr_un addr;

	struct spa_source *source;
	struct spa_list clients;
	unsigned int activated:1;
};

struct impl {
	struct pw_loop *loop;
	struct pw_context *context;
	struct spa_hook context_listener;

	struct pw_properties *props;
	void *dbus_name;

	struct ratelimit rate_limit;

	struct spa_source *source;
	struct spa_list servers;

	struct pw_work_queue *work_queue;
	struct spa_list cleanup_clients;

	struct pw_map samples;
	struct pw_map modules;

	struct spa_list free_messages;
	struct defs defs;
	struct stats stat;
};

struct server *create_server(struct impl *impl, const char *address);
void server_free(struct server *server);

#endif
