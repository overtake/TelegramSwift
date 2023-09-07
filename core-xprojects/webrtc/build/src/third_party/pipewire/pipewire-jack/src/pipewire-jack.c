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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <regex.h>
#include <math.h>

#include <jack/jack.h>
#include <jack/session.h>
#include <jack/thread.h>
#include <jack/midiport.h>
#include <jack/uuid.h>
#include <jack/metadata.h>

#include <spa/support/cpu.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/video/format-utils.h>
#include <spa/debug/types.h>
#include <spa/debug/pod.h>
#include <spa/utils/json.h>

#include <pipewire/pipewire.h>
#include <pipewire/private.h>
#include <pipewire/data-loop.h>

#include "extensions/client-node.h"
#include "extensions/metadata.h"
#include "pipewire-jack-extensions.h"

#define JACK_DEFAULT_VIDEO_TYPE	"32 bit float RGBA video"

#define JACK_CLIENT_NAME_SIZE		128
#define JACK_PORT_NAME_SIZE		256
#define JACK_PORT_MAX			4096
#define JACK_PORT_TYPE_SIZE             32
#define CONNECTION_NUM_FOR_PORT		1024
#define MONITOR_EXT			" Monitor"

#define MAX_BUFFER_FRAMES		8192

#define MAX_ALIGN			16
#define MAX_PORTS			1024
#define MAX_BUFFERS			2
#define MAX_BUFFER_DATAS		1u

#define REAL_JACK_PORT_NAME_SIZE (JACK_CLIENT_NAME_SIZE + JACK_PORT_NAME_SIZE)

#define NAME	"jack-client"

#define TYPE_ID_AUDIO	0
#define TYPE_ID_MIDI	1
#define TYPE_ID_VIDEO	2
#define TYPE_ID_OTHER	3

#define SELF_CONNECT_ALLOW	0
#define SELF_CONNECT_FAIL_EXT	-1
#define SELF_CONNECT_IGNORE_EXT	1
#define SELF_CONNECT_FAIL_ALL	-2
#define SELF_CONNECT_IGNORE_ALL	2

struct client;
struct port;

struct globals {
	jack_thread_creator_t creator;
	pthread_mutex_t lock;
	struct pw_array descriptions;
};

static struct globals globals;
static bool mlock_warned = false;

#define OBJECT_CHUNK	8

typedef void (*mix2_func) (float *dst, float *src1, float *src2, int n_samples);

static mix2_func mix2;

struct object {
	struct spa_list link;

	struct client *client;

#define INTERFACE_Port	0
#define INTERFACE_Node	1
#define INTERFACE_Link	2
	uint32_t type;
	uint32_t id;

	union {
		struct {
			char name[JACK_CLIENT_NAME_SIZE+1];
			char node_name[512];
			int32_t priority;
			uint32_t client_id;
		} node;
		struct {
			uint32_t src;
			uint32_t dst;
		} port_link;
		struct {
			unsigned long flags;
			char name[REAL_JACK_PORT_NAME_SIZE+1];
			char alias1[REAL_JACK_PORT_NAME_SIZE+1];
			char alias2[REAL_JACK_PORT_NAME_SIZE+1];
			char system[REAL_JACK_PORT_NAME_SIZE+1];
			uint32_t type_id;
			uint32_t node_id;
			uint32_t port_id;
			uint32_t monitor_requests;
			jack_latency_range_t capture_latency;
			jack_latency_range_t playback_latency;
			int32_t priority;
			struct port *port;
			bool is_monitor;
			struct object *node;
		} port;
	};
};

struct midi_buffer {
#define MIDI_BUFFER_MAGIC 0x900df00d
	uint32_t magic;
	int32_t buffer_size;
	uint32_t nframes;
	int32_t write_pos;
	uint32_t event_count;
	uint32_t lost_events;
};

#define MIDI_INLINE_MAX	4

struct midi_event {
	uint16_t time;
        uint16_t size;
        union {
		uint32_t byte_offset;
		uint8_t inline_data[MIDI_INLINE_MAX];
	};
};

struct buffer {
	struct spa_list link;
#define BUFFER_FLAG_OUT		(1<<0)
#define BUFFER_FLAG_MAPPED	(1<<1)
	uint32_t flags;
	uint32_t id;

	struct spa_data datas[MAX_BUFFER_DATAS];
	uint32_t n_datas;

	struct pw_memmap *mem[MAX_BUFFER_DATAS+1];
	uint32_t n_mem;
};

struct mix {
	struct spa_list link;
	struct spa_list port_link;
	uint32_t id;
	struct port *port;

	struct spa_io_buffers *io;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;
	struct spa_list queue;
};

struct port {
	bool valid;
	struct spa_list link;

	struct client *client;

	enum spa_direction direction;
	uint32_t id;
	struct object *object;

	struct spa_io_buffers io;
	struct spa_list mix;
	struct mix *global_mix;

	unsigned int empty_out:1;
	unsigned int zeroed:1;

	float *emptyptr;
	float empty[MAX_BUFFER_FRAMES + MAX_ALIGN];

	void *(*get_buffer) (struct port *p, jack_nframes_t frames);
};

struct link {
	struct spa_list link;
	struct spa_list target_link;
	struct client *client;
	uint32_t node_id;
	struct pw_memmap *mem;
	struct pw_node_activation *activation;
	int signalfd;
};

struct context {
	struct pw_loop *l;
	struct pw_thread_loop *loop;	/* thread_lock protects all below */
	struct pw_context *context;

	struct spa_list free_objects;

	pthread_mutex_t lock;		/* protects map and lists below, in addition to thread_lock */
	struct pw_map globals;
	struct spa_list ports;
	struct spa_list nodes;
	struct spa_list links;
};

#define GET_DIRECTION(f)	((f) & JackPortIsInput ? SPA_DIRECTION_INPUT : SPA_DIRECTION_OUTPUT)

#define GET_IN_PORT(c,p)	(c->port_pool[SPA_DIRECTION_INPUT][p])
#define GET_OUT_PORT(c,p)	(c->port_pool[SPA_DIRECTION_OUTPUT][p])
#define GET_PORT(c,d,p)		(d == SPA_DIRECTION_INPUT ? GET_IN_PORT(c,p) : GET_OUT_PORT(c,p))

struct metadata {
	struct pw_metadata *proxy;
	struct spa_hook listener;

	char default_audio_sink[1024];
	char default_audio_source[1024];
};

struct client {
	char name[JACK_CLIENT_NAME_SIZE+1];

	struct context context;

	char *server_name;
	char *load_name;		/* load module name */
	char *load_init;		/* initialization string */
	jack_uuid_t session_id;		/* requested session_id */

	struct pw_data_loop *loop;
	struct pw_properties *props;

	struct pw_core *core;
	struct spa_hook core_listener;
	struct pw_mempool *pool;
	int last_sync;
	int last_res;
	bool error;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_client_node *node;
	struct spa_hook node_listener;
        struct spa_hook proxy_listener;

	struct metadata *metadata;

	uint32_t node_id;
	struct spa_source *socket_source;

	JackThreadCallback thread_callback;
	void *thread_arg;
	JackThreadInitCallback thread_init_callback;
	void *thread_init_arg;
	JackShutdownCallback shutdown_callback;
	void *shutdown_arg;
	JackInfoShutdownCallback info_shutdown_callback;
	void *info_shutdown_arg;
	JackProcessCallback process_callback;
	void *process_arg;
	JackFreewheelCallback freewheel_callback;
	void *freewheel_arg;
	JackBufferSizeCallback bufsize_callback;
	void *bufsize_arg;
	JackSampleRateCallback srate_callback;
	void *srate_arg;
	JackClientRegistrationCallback registration_callback;
	void *registration_arg;
	JackPortRegistrationCallback portregistration_callback;
	void *portregistration_arg;
	JackPortConnectCallback connect_callback;
	void *connect_arg;
	JackPortRenameCallback rename_callback;
	void *rename_arg;
	JackGraphOrderCallback graph_callback;
	void *graph_arg;
	JackXRunCallback xrun_callback;
	void *xrun_arg;
	JackLatencyCallback latency_callback;
	void *latency_arg;
	JackSyncCallback sync_callback;
	void *sync_arg;
	JackTimebaseCallback timebase_callback;
	void *timebase_arg;
	JackPropertyChangeCallback property_callback;
	void *property_arg;

	struct spa_io_position *position;
	uint32_t sample_rate;
	uint32_t buffer_frames;
	struct spa_fraction latency;

	struct spa_list free_mix;

	uint32_t n_port_pool[2];
	struct port *port_pool[2][MAX_PORTS];
	struct spa_list ports[2];
	struct spa_list free_ports[2];

	struct spa_list links;
	uint32_t driver_id;
	struct pw_node_activation *driver_activation;

	struct pw_memmap *mem;
	struct pw_node_activation *activation;
	uint32_t xrun_count;

	struct {
		struct spa_io_position *position;
		struct pw_node_activation *driver_activation;
		struct spa_list target_links;
	} rt;

	int pending;

	unsigned int started:1;
	unsigned int active:1;
	unsigned int destroyed:1;
	unsigned int first:1;
	unsigned int thread_entered:1;
	unsigned int has_transport:1;
	unsigned int allow_mlock:1;
	unsigned int warn_mlock:1;
	unsigned int timeowner_pending:1;
	unsigned int timeowner_conditional:1;
	unsigned int merge_monitor:1;
	unsigned int short_name:1;
	unsigned int filter_name:1;
	int self_connect_mode;

	jack_position_t jack_position;
	jack_transport_state_t jack_state;
};

static int do_sync(struct client *client);

#include "metadata.c"

static void init_port_pool(struct client *c, enum spa_direction direction)
{
	spa_list_init(&c->ports[direction]);
	spa_list_init(&c->free_ports[direction]);
	c->n_port_pool[direction] = 0;
}

static struct object * alloc_object(struct client *c, int type)
{
	struct object *o;
	int i;

	if (spa_list_is_empty(&c->context.free_objects)) {
		o = calloc(OBJECT_CHUNK, sizeof(struct object));
		if (o == NULL)
			return NULL;
		for (i = 0; i < OBJECT_CHUNK; i++)
			spa_list_append(&c->context.free_objects, &o[i].link);
	}

	o = spa_list_first(&c->context.free_objects, struct object, link);
	spa_list_remove(&o->link);
	o->client = c;
	o->type = type;

	return o;
}

static void free_object(struct client *c, struct object *o)
{
	pthread_mutex_lock(&c->context.lock);
        spa_list_remove(&o->link);
	pthread_mutex_unlock(&c->context.lock);
	spa_list_append(&c->context.free_objects, &o->link);
}

static void init_mix(struct mix *mix, uint32_t mix_id, struct port *port)
{
	mix->id = mix_id;
	mix->port = port;
	mix->io = NULL;
	mix->n_buffers = 0;
	spa_list_init(&mix->queue);
	if (mix_id == SPA_ID_INVALID)
		port->global_mix = mix;
}

static struct mix *find_mix(struct client *c, struct port *port, uint32_t mix_id)
{
	struct mix *mix;

	spa_list_for_each(mix, &port->mix, port_link) {
		if (mix->id == mix_id)
			return mix;
	}
	return NULL;
}

static struct mix *ensure_mix(struct client *c, struct port *port, uint32_t mix_id)
{
	struct mix *mix;
	uint32_t i;

	if ((mix = find_mix(c, port, mix_id)) != NULL)
		return mix;

	if (spa_list_is_empty(&c->free_mix)) {
		mix = calloc(OBJECT_CHUNK, sizeof(struct mix));
		if (mix == NULL)
			return NULL;
		for (i = 0; i < OBJECT_CHUNK; i++)
			spa_list_append(&c->free_mix, &mix[i].link);
	}
	mix = spa_list_first(&c->free_mix, struct mix, link);
	spa_list_remove(&mix->link);

	spa_list_append(&port->mix, &mix->port_link);

	init_mix(mix, mix_id, port);

	return mix;
}

static int clear_buffers(struct client *c, struct mix *mix)
{
	struct port *port = mix->port;
	struct buffer *b;
	uint32_t i, j;

	pw_log_debug(NAME" %p: port %p clear buffers", c, port);

	for (i = 0; i < mix->n_buffers; i++) {
		b = &mix->buffers[i];

		for (j = 0; j < b->n_mem; j++)
			pw_memmap_free(b->mem[j]);

		b->n_mem = 0;
	}
	mix->n_buffers = 0;
	spa_list_init(&mix->queue);
	return 0;
}

static void free_mix(struct client *c, struct mix *mix)
{
	clear_buffers(c, mix);
	spa_list_remove(&mix->port_link);
	if (mix->id == SPA_ID_INVALID)
		mix->port->global_mix = NULL;
	spa_list_append(&c->free_mix, &mix->link);
}

static struct port * alloc_port(struct client *c, enum spa_direction direction)
{
	struct port *p;
	struct object *o;
	uint32_t i, n;

	if (spa_list_is_empty(&c->free_ports[direction])) {
		p = calloc(OBJECT_CHUNK, sizeof(struct port));
		if (p == NULL)
			return NULL;
		n = c->n_port_pool[direction];
		for (i = 0; i < OBJECT_CHUNK; i++, n++) {
			p[i].direction = direction;
			p[i].id = n;
			p[i].emptyptr = SPA_PTR_ALIGN(p[i].empty, MAX_ALIGN, float);
			c->port_pool[direction][n] = &p[i];
			spa_list_append(&c->free_ports[direction], &p[i].link);
		}
		c->n_port_pool[direction] = n;

	}
	p = spa_list_first(&c->free_ports[direction], struct port, link);
	spa_list_remove(&p->link);

	o = alloc_object(c, INTERFACE_Port);
	o->id = SPA_ID_INVALID;
	o->port.node_id = c->node_id;
	o->port.port_id = p->id;
	o->port.port = p;

	p->valid = true;
	p->zeroed = false;
	p->client = c;
	p->object = o;
	spa_list_init(&p->mix);

	spa_list_append(&c->ports[direction], &p->link);

	pthread_mutex_lock(&c->context.lock);
	spa_list_append(&c->context.ports, &o->link);
	pthread_mutex_unlock(&c->context.lock);

	return p;
}

static void free_port(struct client *c, struct port *p)
{
	struct mix *m;

	if (!p->valid)
		return;

	spa_list_consume(m, &p->mix, port_link)
		free_mix(c, m);

	spa_list_remove(&p->link);
	p->valid = false;
	free_object(c, p->object);
	spa_list_append(&c->free_ports[p->direction], &p->link);
}

static struct object *find_node(struct client *c, const char *name)
{
	struct object *o;

	spa_list_for_each(o, &c->context.nodes, link) {
		if (!strcmp(o->node.name, name))
			return o;
	}
	return NULL;
}

static bool is_port_default(struct client *c, struct object *o)
{
	struct object *ot;

	if (c->metadata == NULL)
		return false;

	if ((ot = o->port.node) != NULL &&
	    (strcmp(ot->node.node_name, c->metadata->default_audio_source) == 0 ||
	     strcmp(ot->node.node_name, c->metadata->default_audio_sink) == 0))
		return true;

	return false;
}

static struct object *find_port(struct client *c, const char *name)
{
	struct object *o;

	spa_list_for_each(o, &c->context.ports, link) {
		if (strcmp(o->port.name, name) == 0 ||
		    strcmp(o->port.alias1, name) == 0 ||
		    strcmp(o->port.alias2, name) == 0)
			return o;
		if (is_port_default(c, o) && strcmp(o->port.system, name) == 0)
			return o;
	}
	return NULL;
}

static struct object *find_link(struct client *c, uint32_t src, uint32_t dst)
{
	struct object *l;

	spa_list_for_each(l, &c->context.links, link) {
		if (l->port_link.src == src &&
		    l->port_link.dst == dst) {
			return l;
		}
	}
	return NULL;
}

static struct buffer *dequeue_buffer(struct mix *mix)
{
	struct buffer *b;

	if (SPA_UNLIKELY(spa_list_is_empty(&mix->queue)))
		return NULL;

	b = spa_list_first(&mix->queue, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

	return b;
}

#if defined (__SSE__)
#include <xmmintrin.h>
static void mix2_sse(float *dst, float *src1, float *src2, int n_samples)
{
	int n, unrolled;
	__m128 in[2];

	if (SPA_IS_ALIGNED(src1, 16) &&
	    SPA_IS_ALIGNED(src2, 16) &&
	    SPA_IS_ALIGNED(dst, 16))
		unrolled = n_samples / 4;
	else
		unrolled = 0;

	for (n = 0; unrolled--; n += 4) {
		in[0] = _mm_load_ps(&src1[n]),
		in[1] = _mm_load_ps(&src2[n]),
		in[0] = _mm_add_ps(in[0], in[1]);
		_mm_store_ps(&dst[n], in[0]);
	}
	for (; n < n_samples; n++) {
		in[0] = _mm_load_ss(&src1[n]),
		in[1] = _mm_load_ss(&src2[n]),
		in[0] = _mm_add_ss(in[0], in[1]);
		_mm_store_ss(&dst[n], in[0]);
	}
}
#endif

static void mix2_c(float *dst, float *src1, float *src2, int n_samples)
{
	int i;
	for (i = 0; i < n_samples; i++)
		dst[i] = src1[i] + src2[i];
}

SPA_EXPORT
void jack_get_version(int *major_ptr, int *minor_ptr, int *micro_ptr, int *proto_ptr)
{
	if (major_ptr)
		*major_ptr = 3;
	if (minor_ptr)
		*minor_ptr = 0;
	if (micro_ptr)
		*micro_ptr = 0;
	if (proto_ptr)
		*proto_ptr = 0;
}

SPA_EXPORT
const char *
jack_get_version_string(void)
{
	static char name[1024];
	snprintf(name, sizeof(name), "3.0.0.0 (using PipeWire %s)", pw_get_library_version());
	return name;
}

static void on_sync_reply(void *data, uint32_t id, int seq)
{
	struct client *client = data;
	if (id != PW_ID_CORE)
		return;
	client->last_sync = seq;
	pw_thread_loop_signal(client->context.loop, false);
}


static void on_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct client *client = data;

	pw_log_warn(NAME" %p: error id:%u seq:%d res:%d (%s): %s", client,
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE) {
		client->error = true;
		client->last_res = res;
		if (client->shutdown_callback && !client->destroyed)
			client->shutdown_callback(client->shutdown_arg);
	}
	pw_thread_loop_signal(client->context.loop, false);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.done = on_sync_reply,
	.error = on_error,
};

static int do_sync(struct client *client)
{
	int seq;

	seq = pw_proxy_sync((struct pw_proxy*)client->core, client->last_sync);

	while (true) {
	        pw_thread_loop_wait(client->context.loop);

		if (client->error)
			return client->last_res;

		if (client->last_sync == seq)
			break;
	}
	return 0;
}

static void on_node_removed(void *data)
{
	struct client *client = data;
	pw_proxy_destroy((struct pw_proxy*)client->node);
}

static void on_node_destroy(void *data)
{
	struct client *client = data;
	client->node = NULL;
	spa_hook_remove(&client->proxy_listener);
}

static void on_node_bound(void *data, uint32_t global_id)
{
	struct client *client = data;
	client->node_id = global_id;
}

static const struct pw_proxy_events node_proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = on_node_removed,
	.destroy = on_node_destroy,
	.bound = on_node_bound,
};

static struct link *find_activation(struct spa_list *links, uint32_t node_id)
{
	struct link *l;

	spa_list_for_each(l, links, link) {
		if (l->node_id == node_id)
			return l;
	}
	return NULL;
}

static int
do_remove_sources(struct spa_loop *loop,
                  bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct client *c = user_data;

	if (c->socket_source) {
		pw_loop_destroy_source(c->loop->loop, c->socket_source);
		c->socket_source = NULL;
	}
	return 0;
}

static void unhandle_socket(struct client *c)
{
	pw_data_loop_invoke(c->loop,
			do_remove_sources, 1, NULL, 0, true, c);
}

static inline void reuse_buffer(struct client *c, struct mix *mix, uint32_t id)
{
	struct buffer *b;

	b = &mix->buffers[id];

	if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUT)) {
		pw_log_trace_fp(NAME" %p: port %p: recycle buffer %d", c, mix->port, id);
		spa_list_append(&mix->queue, &b->link);
		SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUT);
	}
}


static void convert_from_midi(void *midi, void *buffer, size_t size)
{
	struct spa_pod_builder b = { 0, };
	uint32_t i, count;
	struct spa_pod_frame f;

	count = jack_midi_get_event_count(midi);

	spa_pod_builder_init(&b, buffer, size);
	spa_pod_builder_push_sequence(&b, &f, 0);

	for (i = 0; i < count; i++) {
		jack_midi_event_t ev;
		jack_midi_event_get(&ev, midi, i);
		spa_pod_builder_control(&b, ev.time, SPA_CONTROL_Midi);
		spa_pod_builder_bytes(&b, ev.buffer, ev.size);
	}
        spa_pod_builder_pop(&b, &f);
}

static void convert_to_midi(struct spa_pod_sequence **seq, uint32_t n_seq, void *midi)
{
	struct spa_pod_control *c[n_seq];
	uint32_t i;

	for (i = 0; i < n_seq; i++)
		c[i] = spa_pod_control_first(&seq[i]->body);

	while (true) {
		struct spa_pod_control *next = NULL;
		uint32_t next_index = 0;

		for (i = 0; i < n_seq; i++) {
			if (!spa_pod_control_is_inside(&seq[i]->body,
						SPA_POD_BODY_SIZE(seq[i]), c[i]))
				continue;

			if (next == NULL || c[i]->offset < next->offset) {
				next = c[i];
				next_index = i;
			}
		}
		if (SPA_UNLIKELY(next == NULL))
			break;

		switch(next->type) {
		case SPA_CONTROL_Midi:
			jack_midi_event_write(midi,
					next->offset,
					SPA_POD_BODY(&next->value),
					SPA_POD_BODY_SIZE(&next->value));
			break;
		}
		c[next_index] = spa_pod_control_next(c[next_index]);
	}
}


static inline void *get_buffer_output(struct port *p, uint32_t frames, uint32_t stride)
{
	struct mix *mix;
	struct client *c = p->client;
	void *ptr = NULL;

	p->io.status = -EPIPE;
	p->io.buffer_id = SPA_ID_INVALID;

	if (frames == 0)
		return NULL;

	if (SPA_LIKELY((mix = p->global_mix) != NULL)) {
		struct buffer *b;

		if (SPA_UNLIKELY(mix->n_buffers == 0))
			goto done;

		pw_log_trace_fp(NAME" %p: port %p %d get buffer %d n_buffers:%d",
				c, p, p->id, frames, mix->n_buffers);

		if (SPA_UNLIKELY((b = dequeue_buffer(mix)) == NULL)) {
			pw_log_warn("port %p: out of buffers", p);
			goto done;
		}
		reuse_buffer(c, mix, b->id);
		ptr = b->datas[0].data;

		b->datas[0].chunk->offset = 0;
		b->datas[0].chunk->size = frames * sizeof(float);
		b->datas[0].chunk->stride = stride;

		p->io.status = SPA_STATUS_HAVE_DATA;
		p->io.buffer_id = b->id;
	}
done:
	spa_list_for_each(mix, &p->mix, port_link) {
		struct spa_io_buffers *mio = mix->io;
		if (SPA_UNLIKELY(mio == NULL))
			continue;
		pw_log_trace_fp(NAME" %p: port %p tee %d.%d get buffer %d io:%p",
				c, p, p->id, mix->id, frames, mio);
		*mio = p->io;
	}
	return ptr;
}

static void process_tee(struct client *c, uint32_t frames)
{
	struct port *p;

	spa_list_for_each(p, &c->ports[SPA_DIRECTION_OUTPUT], link) {
		void *ptr;

		if (SPA_LIKELY(!p->empty_out))
			continue;

		switch (p->object->port.type_id) {
		case TYPE_ID_AUDIO:
			ptr = get_buffer_output(p, frames, sizeof(float));
			if (SPA_LIKELY(ptr != NULL))
				memcpy(ptr, p->emptyptr, frames * sizeof(float));
			break;
		case TYPE_ID_MIDI:
			ptr = get_buffer_output(p, MAX_BUFFER_FRAMES, 1);
			if (SPA_LIKELY(ptr != NULL))
				convert_from_midi(p->emptyptr, ptr, MAX_BUFFER_FRAMES * sizeof(float));
			break;
		default:
			pw_log_warn("port %p: unhandled format %d", p, p->object->port.type_id);
			break;
		}
	}
}

static inline void debug_position(struct client *c, jack_position_t *p)
{
	pw_log_trace("usecs:       %"PRIu64, p->usecs);
	pw_log_trace("frame_rate:  %u", p->frame_rate);
	pw_log_trace("frame:       %u", p->frame);
	pw_log_trace("valid:       %08x", p->valid);

	if (p->valid & JackPositionBBT) {
		pw_log_trace("BBT");
		pw_log_trace(" bar:              %u", p->bar);
		pw_log_trace(" beat:             %u", p->beat);
		pw_log_trace(" tick:             %u", p->tick);
		pw_log_trace(" bar_start_tick:   %f", p->bar_start_tick);
		pw_log_trace(" beats_per_bar:    %f", p->beats_per_bar);
		pw_log_trace(" beat_type:        %f", p->beat_type);
		pw_log_trace(" ticks_per_beat:   %f", p->ticks_per_beat);
		pw_log_trace(" beats_per_minute: %f", p->beats_per_minute);
	}
	if (p->valid & JackPositionTimecode) {
		pw_log_trace("Timecode:");
		pw_log_trace(" frame_time:       %f", p->frame_time);
		pw_log_trace(" next_time:        %f", p->next_time);
	}
	if (p->valid & JackBBTFrameOffset) {
		pw_log_trace("BBTFrameOffset:");
		pw_log_trace(" bbt_offset:       %u", p->bbt_offset);
	}
	if (p->valid & JackAudioVideoRatio) {
		pw_log_trace("AudioVideoRatio:");
		pw_log_trace(" audio_frames_per_video_frame: %f", p->audio_frames_per_video_frame);
	}
	if (p->valid & JackVideoFrameOffset) {
		pw_log_trace("JackVideoFrameOffset:");
		pw_log_trace(" video_offset:     %u", p->video_offset);
	}
}

static inline void jack_to_position(jack_position_t *s, struct pw_node_activation *a)
{
	struct spa_io_segment *d = &a->segment;

	if (s->valid & JackPositionBBT) {
		d->bar.flags = SPA_IO_SEGMENT_BAR_FLAG_VALID;
		if (s->valid & JackBBTFrameOffset)
			d->bar.offset = s->bbt_offset;
		else
			d->bar.offset = 0;
		d->bar.signature_num = s->beats_per_bar;
		d->bar.signature_denom = s->beat_type;
		d->bar.bpm = s->beats_per_minute;
		d->bar.beat = (s->bar - 1) * s->beats_per_bar + (s->beat - 1) +
			(s->tick / s->ticks_per_beat);
	}
}

static inline jack_transport_state_t position_to_jack(struct pw_node_activation *a, jack_position_t *d)
{
	struct spa_io_position *s = &a->position;
	jack_transport_state_t state;
	struct spa_io_segment *seg = &s->segments[0];
	uint64_t running;

	switch (s->state) {
	default:
	case SPA_IO_POSITION_STATE_STOPPED:
		state = JackTransportStopped;
		break;
	case SPA_IO_POSITION_STATE_STARTING:
		state = JackTransportStarting;
		break;
	case SPA_IO_POSITION_STATE_RUNNING:
		if (seg->flags & SPA_IO_SEGMENT_FLAG_LOOPING)
			state = JackTransportLooping;
		else
			state = JackTransportRolling;
		break;
	}
	if (SPA_UNLIKELY(d == NULL))
		return state;

	d->unique_1++;
	d->usecs = s->clock.nsec / SPA_NSEC_PER_USEC;
	d->frame_rate = s->clock.rate.denom;

	running = s->clock.position - s->offset;

	if (running >= seg->start &&
	    (seg->duration == 0 || running < seg->start + seg->duration))
		d->frame = (running - seg->start) * seg->rate + seg->position;
	else
		d->frame = seg->position;

	d->valid = 0;
	if (a->segment_owner[0] && SPA_FLAG_IS_SET(seg->bar.flags, SPA_IO_SEGMENT_BAR_FLAG_VALID)) {
		double abs_beat;
		long beats;

		d->valid |= JackPositionBBT;

		d->bbt_offset = seg->bar.offset;
		if (seg->bar.offset)
			d->valid |= JackBBTFrameOffset;

		d->beats_per_bar = seg->bar.signature_num;
		d->beat_type = seg->bar.signature_denom;
		d->ticks_per_beat = 1920.0f;
		d->beats_per_minute = seg->bar.bpm;

		abs_beat = seg->bar.beat;

		d->bar = abs_beat / d->beats_per_bar;
		beats = d->bar * d->beats_per_bar;
		d->bar_start_tick = beats * d->ticks_per_beat;
		d->beat = abs_beat - beats;
		beats += d->beat;
		d->tick = (abs_beat - beats) * d->ticks_per_beat;
		d->bar++;
		d->beat++;
	}
	d->unique_2 = d->unique_1;
	return state;
}

static int
do_buffer_frames(struct spa_loop *loop,
		bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	uint32_t buffer_frames = *((uint32_t*)data);
	struct client *c = user_data;
	if (c->bufsize_callback)
		c->bufsize_callback(buffer_frames, c->bufsize_arg);
	ATOMIC_DEC(c->pending);
	return 0;
}

static inline void check_buffer_frames(struct client *c, struct spa_io_position *pos, bool rt)
{
	uint32_t buffer_frames = pos->clock.duration;
	if (SPA_UNLIKELY(buffer_frames != c->buffer_frames)) {
		pw_log_info(NAME" %p: bufferframes %d", c, buffer_frames);
		ATOMIC_INC(c->pending);
		c->buffer_frames = buffer_frames;
		if (rt)
			pw_loop_invoke(c->context.l, do_buffer_frames, 0,
					&buffer_frames, sizeof(buffer_frames), false, c);
		else
			do_buffer_frames(c->context.l->loop, false, 0,
					&buffer_frames, sizeof(buffer_frames), c);
	}
}

static int
do_sample_rate(struct spa_loop *loop,
		bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct client *c = user_data;
	uint32_t sample_rate = *((uint32_t*)data);
	if (c->srate_callback)
		c->srate_callback(sample_rate, c->srate_arg);
	ATOMIC_DEC(c->pending);
	return 0;
}

static inline void check_sample_rate(struct client *c, struct spa_io_position *pos, bool rt)
{
	uint32_t sample_rate = pos->clock.rate.denom;
	if (SPA_UNLIKELY(sample_rate != c->sample_rate)) {
		pw_log_info(NAME" %p: sample_rate %d", c, sample_rate);
		ATOMIC_INC(c->pending);
		c->sample_rate = sample_rate;
		if (rt)
			pw_loop_invoke(c->context.l, do_sample_rate, 0,
					&sample_rate, sizeof(sample_rate), false, c);
		else
			do_sample_rate(c->context.l->loop, false, 0,
					&sample_rate, sizeof(sample_rate), c);
	}
}

static inline uint32_t cycle_run(struct client *c)
{
	uint64_t cmd;
	struct timespec ts;
	int fd = c->socket_source->fd;
	struct spa_io_position *pos = c->rt.position;
	struct pw_node_activation *activation = c->activation;
	struct pw_node_activation *driver = c->rt.driver_activation;

	/* this is blocking if nothing ready */
	while (true) {
		if (SPA_UNLIKELY(read(fd, &cmd, sizeof(cmd)) != sizeof(cmd))) {
			if (errno == EINTR)
				continue;
			if (errno == EWOULDBLOCK || errno == EAGAIN)
				return 0;
			pw_log_warn(NAME" %p: read failed %m", c);
		}
		break;
	}
	if (SPA_UNLIKELY(cmd > 1))
		pw_log_warn(NAME" %p: missed %"PRIu64" wakeups", c, cmd - 1);

	clock_gettime(CLOCK_MONOTONIC, &ts);
	activation->status = PW_NODE_ACTIVATION_AWAKE;
	activation->awake_time = SPA_TIMESPEC_TO_NSEC(&ts);

	if (SPA_UNLIKELY(c->first)) {
		if (c->thread_init_callback)
			c->thread_init_callback(c->thread_init_arg);
		c->first = false;
	}

	if (SPA_UNLIKELY(pos == NULL)) {
		pw_log_error(NAME" %p: missing position", c);
		return 0;
	}

	check_buffer_frames(c, pos, true);
	check_sample_rate(c, pos, true);

	if (SPA_LIKELY(driver)) {
		c->jack_state = position_to_jack(driver, &c->jack_position);

		if (SPA_UNLIKELY(activation->pending_sync)) {
			if (c->sync_callback == NULL ||
			    c->sync_callback(c->jack_state, &c->jack_position, c->sync_arg))
				activation->pending_sync = false;
		}
		if (SPA_UNLIKELY(c->xrun_count != driver->xrun_count &&
		    c->xrun_count != 0 && c->xrun_callback))
			c->xrun_callback(c->xrun_arg);
		c->xrun_count = driver->xrun_count;
	}
	pw_log_trace_fp(NAME" %p: wait %"PRIu64" frames:%d rate:%d pos:%d delay:%"PRIi64" corr:%f", c,
			activation->awake_time, c->buffer_frames, c->sample_rate,
			c->jack_position.frame, pos->clock.delay, pos->clock.rate_diff);

	return c->buffer_frames;
}

static inline uint32_t cycle_wait(struct client *c)
{
	int res;

	res = pw_data_loop_wait(c->loop, -1);
	if (SPA_UNLIKELY(res <= 0)) {
		pw_log_warn(NAME" %p: wait error %m", c);
		return 0;
	}
	return cycle_run(c);
}

static inline void signal_sync(struct client *c)
{
	struct timespec ts;
	uint64_t cmd, nsec;
	struct link *l;
	struct pw_node_activation *activation = c->activation;

	process_tee(c, c->buffer_frames);

	clock_gettime(CLOCK_MONOTONIC, &ts);
	nsec = SPA_TIMESPEC_TO_NSEC(&ts);
	activation->status = PW_NODE_ACTIVATION_FINISHED;
	activation->finish_time = nsec;

	cmd = 1;
	spa_list_for_each(l, &c->rt.target_links, target_link) {
		struct pw_node_activation_state *state;

		if (SPA_UNLIKELY(l->activation == NULL))
			continue;

		state = &l->activation->state[0];

		pw_log_trace_fp(NAME" %p: link %p %p %d/%d", c, l, state,
				state->pending, state->required);

		if (pw_node_activation_state_dec(state, 1)) {
			l->activation->status = PW_NODE_ACTIVATION_TRIGGERED;
			l->activation->signal_time = nsec;

			pw_log_trace_fp(NAME" %p: signal %p %p", c, l, state);

			if (SPA_UNLIKELY(write(l->signalfd, &cmd, sizeof(cmd)) != sizeof(cmd)))
				pw_log_warn(NAME" %p: write failed %m", c);
		}
	}
}

static inline void cycle_signal(struct client *c, int status)
{
	struct pw_node_activation *driver = c->rt.driver_activation;
	struct pw_node_activation *activation = c->activation;

	if (SPA_LIKELY(status == 0)) {
		if (c->timebase_callback && driver && driver->segment_owner[0] == c->node_id) {
			if (activation->pending_new_pos ||
			    c->jack_state == JackTransportRolling ||
			    c->jack_state == JackTransportLooping) {
				c->timebase_callback(c->jack_state,
						     c->buffer_frames,
						     &c->jack_position,
						     activation->pending_new_pos,
						     c->timebase_arg);

				activation->pending_new_pos = false;

				debug_position(c, &c->jack_position);
				jack_to_position(&c->jack_position, activation);
			}
		}
	}
	signal_sync(c);
}

static void
on_rtsocket_condition(void *data, int fd, uint32_t mask)
{
	struct client *c = data;

	if (SPA_UNLIKELY(mask & (SPA_IO_ERR | SPA_IO_HUP))) {
		pw_log_warn(NAME" %p: got error", c);
		unhandle_socket(c);
		return;
	}
	if (SPA_UNLIKELY(c->thread_callback)) {
		if (!c->thread_entered) {
			c->thread_entered = true;
			c->thread_callback(c->thread_arg);
		}
	} else if (SPA_LIKELY(mask & SPA_IO_IN)) {
		uint32_t buffer_frames;
		int status = 0;

		buffer_frames = cycle_run(c);

		if (!ATOMIC_LOAD(c->pending) && c->process_callback)
			status = c->process_callback(buffer_frames, c->process_arg);

		cycle_signal(c, status);
	}
}

static int
do_clear_link(struct spa_loop *loop,
                  bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct link *link = user_data;
	spa_list_remove(&link->target_link);
	return 0;
}

static void clear_link(struct client *c, struct link *link)
{
	pw_data_loop_invoke(c->loop,
			do_clear_link, 1, NULL, 0, true, link);
	pw_memmap_free(link->mem);
	close(link->signalfd);
	spa_list_remove(&link->link);
	free(link);
}

static void clean_transport(struct client *c)
{
	struct link *l;

	if (!c->has_transport)
		return;

	unhandle_socket(c);

	spa_list_consume(l, &c->links, link)
		clear_link(c, l);

	c->has_transport = false;
}

static int client_node_transport(void *object,
                           int readfd, int writefd,
			   uint32_t mem_id, uint32_t offset, uint32_t size)
{
	struct client *c = (struct client *) object;

	clean_transport(c);

	c->mem = pw_mempool_map_id(c->pool, mem_id,
				PW_MEMMAP_FLAG_READWRITE, offset, size, NULL);
	if (c->mem == NULL) {
		pw_log_debug(NAME" %p: can't map activation: %m", c);
		return -errno;
	}
	c->activation = c->mem->ptr;

	pw_log_debug(NAME" %p: create client transport with fds %d %d for node %u",
			c, readfd, writefd, c->node_id);

	close(writefd);
	c->socket_source = pw_loop_add_io(c->loop->loop,
					  readfd,
					  SPA_IO_ERR | SPA_IO_HUP,
					  true, on_rtsocket_condition, c);

	c->has_transport = true;
	c->position = &c->activation->position;
	pw_thread_loop_signal(c->context.loop, false);

	return 0;
}

static int client_node_set_param(void *object,
			uint32_t id, uint32_t flags,
			const struct spa_pod *param)
{
	struct client *c = (struct client *) object;
	pw_proxy_error((struct pw_proxy*)c->node, -ENOTSUP, "not supported");
	return -ENOTSUP;
}

static int install_timeowner(struct client *c)
{
	struct pw_node_activation *a;
	uint32_t owner;

	if (!c->timeowner_pending)
		return 0;

	if ((a = c->driver_activation) == NULL)
		return -EIO;

	pw_log_debug(NAME" %p: activation %p", c, a);

	/* was ok */
	owner = ATOMIC_LOAD(a->segment_owner[0]);
	if (owner == c->node_id)
		return 0;

	/* try to become owner */
	if (c->timeowner_conditional) {
		if (!ATOMIC_CAS(a->segment_owner[0], 0, c->node_id)) {
			pw_log_debug(NAME" %p: owner:%u id:%u", c, owner, c->node_id);
			return -EBUSY;
		}
	} else {
		ATOMIC_STORE(a->segment_owner[0], c->node_id);
	}

	pw_log_debug(NAME" %p: timebase installed for id:%u", c, c->node_id);
	c->timeowner_pending = false;

	return 0;
}

static int
do_update_driver_activation(struct spa_loop *loop,
                bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct client *c = user_data;
	c->rt.position = c->position;
	c->rt.driver_activation = c->driver_activation;
	return 0;
}

static int update_driver_activation(struct client *c)
{
	struct link *link;
	pw_log_debug(NAME" %p: driver %d", c, c->driver_id);

	link = find_activation(&c->links, c->driver_id);
	c->driver_activation = link ? link->activation : NULL;
	pw_data_loop_invoke(c->loop,
                       do_update_driver_activation, SPA_ID_INVALID, NULL, 0, true, c);
	install_timeowner(c);

	return 0;
}

static int client_node_set_io(void *object,
			uint32_t id,
			uint32_t mem_id,
			uint32_t offset,
			uint32_t size)
{
	struct client *c = (struct client *) object;
	struct pw_memmap *old, *mm;
	void *ptr;
	uint32_t tag[5] = { c->node_id, id, };

	old = pw_mempool_find_tag(c->pool, tag, sizeof(tag));

	if (mem_id == SPA_ID_INVALID) {
		mm = ptr = NULL;
		size = 0;
	} else {
		mm = pw_mempool_map_id(c->pool, mem_id,
				PW_MEMMAP_FLAG_READWRITE, offset, size, tag);
		if (mm == NULL) {
                        pw_log_warn(NAME" %p: can't map memory id %u", c, mem_id);
			return -errno;
		}
		ptr = mm->ptr;
	}
	pw_log_debug(NAME" %p: set io %s %p", c,
			spa_debug_type_find_name(spa_type_io, id), ptr);

	switch (id) {
	case SPA_IO_Position:
		c->position = ptr;
		c->driver_id = ptr ? c->position->clock.id : SPA_ID_INVALID;
		update_driver_activation(c);
		if (ptr)
			check_sample_rate(c, c->position, false);
		break;
	default:
		break;
	}
	if (old != NULL)
		pw_memmap_free(old);

	return 0;
}

static int client_node_event(void *object, const struct spa_event *event)
{
	return -ENOTSUP;
}

static int client_node_command(void *object, const struct spa_command *command)
{
	struct client *c = (struct client *) object;

	pw_log_debug(NAME" %p: got command %d", c, SPA_COMMAND_TYPE(command));

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Suspend:
	case SPA_NODE_COMMAND_Pause:
		if (c->started) {
			pw_loop_update_io(c->loop->loop,
					  c->socket_source, SPA_IO_ERR | SPA_IO_HUP);

			c->started = false;
		}
		break;

	case SPA_NODE_COMMAND_Start:
		if (!c->started) {
			pw_loop_update_io(c->loop->loop,
					  c->socket_source,
					  SPA_IO_IN | SPA_IO_ERR | SPA_IO_HUP);
			c->started = true;
			c->first = true;
			c->thread_entered = false;
		}
		break;
	default:
		pw_log_warn(NAME" %p: unhandled node command %d", c, SPA_COMMAND_TYPE(command));
		pw_proxy_errorf((struct pw_proxy*)c->node, -ENOTSUP,
				"unhandled command %d", SPA_COMMAND_TYPE(command));
	}
	return 0;
}

static int client_node_add_port(void *object,
                          enum spa_direction direction,
                          uint32_t port_id, const struct spa_dict *props)
{
	struct client *c = (struct client *) object;
	pw_proxy_error((struct pw_proxy*)c->node, -ENOTSUP, "add port not supported");
	return -ENOTSUP;
}

static int client_node_remove_port(void *object,
                             enum spa_direction direction,
                             uint32_t port_id)
{
	struct client *c = (struct client *) object;
	pw_proxy_error((struct pw_proxy*)c->node, -ENOTSUP, "remove port not supported");
	return -ENOTSUP;
}

static int param_enum_format(struct client *c, struct port *p,
		struct spa_pod **param, struct spa_pod_builder *b)
{
	switch (p->object->port.type_id) {
	case TYPE_ID_AUDIO:
		*param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
	                SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_DSP_F32));
		break;
	case TYPE_ID_MIDI:
		*param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_application),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
		break;
	case TYPE_ID_VIDEO:
		*param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_video),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
	                SPA_FORMAT_VIDEO_format,   SPA_POD_Id(SPA_VIDEO_FORMAT_DSP_F32));
		break;
	default:
		return -EINVAL;
	}
	return 1;
}

static int param_format(struct client *c, struct port *p,
		struct spa_pod **param, struct spa_pod_builder *b)
{
	switch (p->object->port.type_id) {
	case TYPE_ID_AUDIO:
		*param = spa_pod_builder_add_object(b,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_Format,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
		                SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_DSP_F32));
		break;
	case TYPE_ID_MIDI:
		*param = spa_pod_builder_add_object(b,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_Format,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_application),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
		break;
	case TYPE_ID_VIDEO:
		*param = spa_pod_builder_add_object(b,
				SPA_TYPE_OBJECT_Format, SPA_PARAM_Format,
				SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_video),
				SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_dsp),
		                SPA_FORMAT_VIDEO_format,   SPA_POD_Id(SPA_VIDEO_FORMAT_DSP_F32));
		break;
	default:
		return -EINVAL;
	}
	return 1;
}

static int param_buffers(struct client *c, struct port *p,
		struct spa_pod **param, struct spa_pod_builder *b)
{
	switch (p->object->port.type_id) {
	case TYPE_ID_AUDIO:
	case TYPE_ID_MIDI:
		*param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_STEP_Int(
								MAX_BUFFER_FRAMES * sizeof(float),
								sizeof(float),
								MAX_BUFFER_FRAMES * sizeof(float),
								sizeof(float)),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(p->object->port.type_id == TYPE_ID_AUDIO ?
									sizeof(float) : 1),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;
	case TYPE_ID_VIDEO:
		*param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
								320 * 240 * 4 * 4,
								0,
								INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_CHOICE_RANGE_Int(4, 4, INT32_MAX),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;
	default:
		return -EINVAL;
	}
	return 1;
}

static int param_io(struct client *c, struct port *p,
		struct spa_pod **param, struct spa_pod_builder *b)
{
	*param = spa_pod_builder_add_object(b,
		SPA_TYPE_OBJECT_ParamIO, SPA_PARAM_IO,
		SPA_PARAM_IO_id,	SPA_POD_Id(SPA_IO_Buffers),
		SPA_PARAM_IO_size,	SPA_POD_Int(sizeof(struct spa_io_buffers)));
	return 1;
}

static int port_set_format(struct client *c, struct port *p,
		uint32_t flags, const struct spa_pod *param)
{
	if (param == NULL) {
		struct mix *mix;

		pw_log_debug(NAME" %p: port %p clear format", c, p);

		spa_list_for_each(mix, &p->mix, port_link)
			clear_buffers(c, mix);
	}
	else {
		struct spa_audio_info info = { 0 };
		if (spa_format_parse(param, &info.media_type, &info.media_subtype) < 0)
			return -EINVAL;

		switch (info.media_type) {
		case SPA_MEDIA_TYPE_audio:
		{
			if (info.media_subtype != SPA_MEDIA_SUBTYPE_dsp)
				return -EINVAL;

			if (spa_format_audio_dsp_parse(param, &info.info.dsp) < 0)
				return -EINVAL;
			if (info.info.dsp.format != SPA_AUDIO_FORMAT_DSP_F32)
				return -EINVAL;
			break;
		}
		case SPA_MEDIA_TYPE_application:
			if (info.media_subtype != SPA_MEDIA_SUBTYPE_control)
				return -EINVAL;
			break;
		case SPA_MEDIA_TYPE_video:
		{
			struct spa_video_info vinfo = { 0 };

			if (info.media_subtype != SPA_MEDIA_SUBTYPE_dsp)
				return -EINVAL;
			if (spa_format_video_dsp_parse(param, &vinfo.info.dsp) < 0)
				return -EINVAL;
			if (vinfo.info.dsp.format != SPA_VIDEO_FORMAT_DSP_F32)
				return -EINVAL;
			break;
		}
		default:
			return -EINVAL;
		}
	}
	return 0;
}

static int client_node_port_set_param(void *object,
                                enum spa_direction direction,
                                uint32_t port_id,
                                uint32_t id, uint32_t flags,
                                const struct spa_pod *param)
{
	struct client *c = (struct client *) object;
	struct port *p = GET_PORT(c, direction, port_id);
	struct spa_pod *params[4];
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	pw_log_debug("port %p: %d.%d id:%d %p", p, direction, port_id, id, param);

        if (id == SPA_PARAM_Format) {
		port_set_format(c, p, flags, param);
	}

	param_enum_format(c, p, &params[0], &b);
	param_format(c, p, &params[1], &b);
	param_buffers(c, p, &params[2], &b);
	param_io(c, p, &params[3], &b);

	return pw_client_node_port_update(c->node,
					 direction,
					 port_id,
					 PW_CLIENT_NODE_PORT_UPDATE_PARAMS,
					 4,
					 (const struct spa_pod **) params,
					 NULL);
}

static inline void *init_buffer(struct port *p)
{
	void *data = p->emptyptr;
	if (p->zeroed)
		return data;

	if (p->object->port.type_id == TYPE_ID_MIDI) {
		struct midi_buffer *mb = data;
		mb->magic = MIDI_BUFFER_MAGIC;
		mb->buffer_size = MAX_BUFFER_FRAMES * sizeof(float);
		mb->nframes = MAX_BUFFER_FRAMES;
		mb->write_pos = 0;
		mb->event_count = 0;
		mb->lost_events = 0;
		pw_log_debug("port %p: init midi buffer size:%d", p, mb->buffer_size);
	} else
		memset(data, 0, MAX_BUFFER_FRAMES * sizeof(float));

	p->zeroed = true;
	return data;
}

static int client_node_port_use_buffers(void *object,
                                  enum spa_direction direction,
                                  uint32_t port_id,
                                  uint32_t mix_id,
                                  uint32_t flags,
                                  uint32_t n_buffers,
                                  struct pw_client_node_buffer *buffers)
{
	struct client *c = (struct client *) object;
	struct port *p = GET_PORT(c, direction, port_id);
	struct buffer *b;
	uint32_t i, j, fl;
	int res;
	struct mix *mix;

	if (!p->valid) {
		res = -EINVAL;
		goto done;
	}

	if ((mix = ensure_mix(c, p, mix_id)) == NULL) {
		res = -ENOMEM;
		goto done;
	}

	pw_log_debug(NAME" %p: port %p %d %d.%d use_buffers %d", c, p, direction,
			port_id, mix_id, n_buffers);

	if (n_buffers > MAX_BUFFERS) {
		pw_log_error(NAME" %p: too many buffers %u > %u", c, n_buffers, MAX_BUFFERS);
		return -EINVAL;
	}

	if (p->object->port.type_id == TYPE_ID_VIDEO && direction == SPA_DIRECTION_INPUT) {
		fl = PW_MEMMAP_FLAG_READ;
	} else {
		/* some apps write to the input buffer so we want everything readwrite */
		fl = PW_MEMMAP_FLAG_READWRITE;
	}

	/* clear previous buffers */
	clear_buffers(c, mix);

	for (i = 0; i < n_buffers; i++) {
		off_t offset;
		struct spa_buffer *buf;
		struct pw_memmap *mm;

		mm = pw_mempool_map_id(c->pool, buffers[i].mem_id,
				fl, buffers[i].offset, buffers[i].size, NULL);
		if (mm == NULL) {
			pw_log_warn(NAME" %p: can't map memory id %u: %m", c, buffers[i].mem_id);
			continue;
		}

		buf = buffers[i].buffer;

		b = &mix->buffers[i];
		b->id = i;
		b->flags = 0;
		b->n_mem = 0;
		b->mem[b->n_mem++] = mm;

		pw_log_debug(NAME" %p: add buffer id:%u offset:%u size:%u map:%p ptr:%p",
				c, buffers[i].mem_id, buffers[i].offset,
				buffers[i].size, mm, mm->ptr);

		offset = 0;
		for (j = 0; j < buf->n_metas; j++) {
			struct spa_meta *m = &buf->metas[j];
			offset += SPA_ROUND_UP_N(m->size, 8);
		}

		b->n_datas = SPA_MIN(buf->n_datas, MAX_BUFFER_DATAS);

		for (j = 0; j < b->n_datas; j++) {
			struct spa_data *d = &b->datas[j];

			memcpy(d, &buf->datas[j], sizeof(struct spa_data));
			d->chunk =
			    SPA_MEMBER(mm->ptr, offset + sizeof(struct spa_chunk) * j,
				       struct spa_chunk);

			if (d->type == SPA_DATA_MemId) {
				uint32_t mem_id = SPA_PTR_TO_UINT32(d->data);
				struct pw_memblock *bm;
				struct pw_memmap *bmm;

				bm = pw_mempool_find_id(c->pool, mem_id);
				if (bm == NULL) {
					pw_log_error(NAME" %p: unknown buffer mem %u", c, mem_id);
					res = -ENODEV;
					goto done;

				}

				d->fd = bm->fd;
				d->type = bm->type;
				d->data = NULL;

				bmm = pw_memblock_map(bm, fl, d->mapoffset, d->maxsize, NULL);
				if (bmm == NULL) {
					res = -errno;
					pw_log_error(NAME" %p: failed to map buffer mem %m", c);
					d->data = NULL;
					goto done;
				}
				b->mem[b->n_mem++] = bmm;
				d->data = bmm->ptr;

				pw_log_debug(NAME" %p: data %d %u -> fd %d %d",
						c, j, bm->id, bm->fd, d->maxsize);
			} else if (d->type == SPA_DATA_MemPtr) {
				int offs = SPA_PTR_TO_INT(d->data);
				d->data = SPA_MEMBER(mm->ptr, offs, void);
				d->fd = -1;
				pw_log_debug(NAME" %p: data %d %u -> mem %p %d",
						c, j, b->id, d->data, d->maxsize);
			} else {
				pw_log_warn("unknown buffer data type %d", d->type);
			}
			if (c->allow_mlock && mlock(d->data, d->maxsize) < 0) {
				if (errno != ENOMEM  || !mlock_warned) {
					pw_log(c->warn_mlock ? SPA_LOG_LEVEL_WARN : SPA_LOG_LEVEL_DEBUG,
						NAME" %p: Failed to mlock memory %p %u: %s", c,
						d->data, d->maxsize,
						errno == ENOMEM ?
						"This is not a problem but for best performance, "
						"consider increasing RLIMIT_MEMLOCK" : strerror(errno));
					mlock_warned |= errno == ENOMEM;
				}
			}
		}
		SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);
		if (direction == SPA_DIRECTION_OUTPUT)
			reuse_buffer(c, mix, b->id);

	}
	pw_log_debug(NAME" %p: have %d buffers", c, n_buffers);
	mix->n_buffers = n_buffers;
	res = 0;

      done:
	if (res < 0)
		pw_proxy_error((struct pw_proxy*)c->node, res, spa_strerror(res));
	return res;
}

static int client_node_port_set_io(void *object,
                             enum spa_direction direction,
                             uint32_t port_id,
                             uint32_t mix_id,
                             uint32_t id,
                             uint32_t mem_id,
                             uint32_t offset,
                             uint32_t size)
{
	struct client *c = (struct client *) object;
	struct port *p = GET_PORT(c, direction, port_id);
        struct pw_memmap *mm, *old;
        struct mix *mix;
	uint32_t tag[5] = { c->node_id, direction, port_id, mix_id, id };
        void *ptr;
	int res = 0;

	if ((mix = ensure_mix(c, p, mix_id)) == NULL) {
		res = -ENOMEM;
		goto exit;
	}

	old = pw_mempool_find_tag(c->pool, tag, sizeof(tag));

        if (mem_id == SPA_ID_INVALID) {
                mm = ptr = NULL;
                size = 0;
        }
        else {
		mm = pw_mempool_map_id(c->pool, mem_id,
				PW_MEMMAP_FLAG_READWRITE, offset, size, tag);
                if (mm == NULL) {
                        pw_log_warn(NAME" %p: can't map memory id %u", c, mem_id);
			res = -EINVAL;
                        goto exit_free;
                }
		ptr = mm->ptr;
        }

	pw_log_debug(NAME" %p: port %p mix:%d set io:%s id:%u ptr:%p", c, p, mix_id,
			spa_debug_type_find_name(spa_type_io, id), id, ptr);

	switch (id) {
	case SPA_IO_Buffers:
                mix->io = ptr;
		break;
	default:
		break;
	}
exit_free:
	if (old != NULL)
		pw_memmap_free(old);
exit:
	if (res < 0)
		pw_proxy_error((struct pw_proxy*)c->node, res, spa_strerror(res));
	return res;
}

static int
do_activate_link(struct spa_loop *loop,
                bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct link *link = user_data;
	struct client *c = link->client;
	pw_log_trace("link %p activate", link);
	spa_list_append(&c->rt.target_links, &link->target_link);
	return 0;
}

static int client_node_set_activation(void *object,
                             uint32_t node_id,
                             int signalfd,
                             uint32_t mem_id,
                             uint32_t offset,
                             uint32_t size)
{
	struct client *c = (struct client *) object;
	struct pw_memmap *mm;
	struct link *link;
	void *ptr;
	int res = 0;

	if (c->node_id == node_id) {
		pw_log_debug(NAME" %p: our activation %u: %u %u %u", c, node_id,
				mem_id, offset, size);
		close(signalfd);
		return 0;
	}

	if (mem_id == SPA_ID_INVALID) {
		mm = ptr = NULL;
		size = 0;
	}
	else {
		mm = pw_mempool_map_id(c->pool, mem_id,
				PW_MEMMAP_FLAG_READWRITE, offset, size, NULL);
		if (mm == NULL) {
			pw_log_warn(NAME" %p: can't map memory id %u", c, mem_id);
			res = -EINVAL;
			goto exit;
		}
		ptr = mm->ptr;
	}

	pw_log_debug(NAME" %p: set activation %u: %u %u %u %p", c, node_id,
			mem_id, offset, size, ptr);

	if (ptr) {
		link = calloc(1, sizeof(struct link));
		if (link == NULL) {
			res = -errno;
			goto exit;
		}
		link->client = c;
		link->node_id = node_id;
		link->mem = mm;
		link->activation = ptr;
		link->signalfd = signalfd;
		spa_list_append(&c->links, &link->link);

		pw_data_loop_invoke(c->loop,
                       do_activate_link, SPA_ID_INVALID, NULL, 0, false, link);
	}
	else {
		link = find_activation(&c->links, node_id);
		if (link == NULL) {
			res = -EINVAL;
			goto exit;
		}
		clear_link(c, link);
	}

	if (c->driver_id == node_id)
		update_driver_activation(c);

      exit:
	if (res < 0)
		pw_proxy_error((struct pw_proxy*)c->node, res, spa_strerror(res));
	return res;
}

static const struct pw_client_node_events client_node_events = {
	PW_VERSION_CLIENT_NODE_EVENTS,
	.transport = client_node_transport,
	.set_param = client_node_set_param,
	.set_io = client_node_set_io,
	.event = client_node_event,
	.command = client_node_command,
	.add_port = client_node_add_port,
	.remove_port = client_node_remove_port,
	.port_set_param = client_node_port_set_param,
	.port_use_buffers = client_node_port_use_buffers,
	.port_set_io = client_node_port_set_io,
	.set_activation = client_node_set_activation,
};

static jack_port_type_id_t string_to_type(const char *port_type)
{
	if (!strcmp(JACK_DEFAULT_AUDIO_TYPE, port_type))
		return TYPE_ID_AUDIO;
	else if (!strcmp(JACK_DEFAULT_MIDI_TYPE, port_type))
		return TYPE_ID_MIDI;
	else if (!strcmp(JACK_DEFAULT_VIDEO_TYPE, port_type))
		return TYPE_ID_VIDEO;
	else if (!strcmp("other", port_type))
		return TYPE_ID_OTHER;
	else
		return SPA_ID_INVALID;
}

static const char* type_to_string(jack_port_type_id_t type_id)
{
	switch(type_id) {
	case TYPE_ID_AUDIO:
		return JACK_DEFAULT_AUDIO_TYPE;
	case TYPE_ID_MIDI:
		return JACK_DEFAULT_MIDI_TYPE;
	case TYPE_ID_VIDEO:
		return JACK_DEFAULT_VIDEO_TYPE;
	case TYPE_ID_OTHER:
		return "other";
	default:
		return NULL;
	}
}

static jack_uuid_t client_make_uuid(uint32_t id)
{
	jack_uuid_t uuid = 0x2; /* JackUUIDClient */
	uuid = (uuid << 32) | (id + 1);
	pw_log_debug("uuid %d -> %"PRIu64, id, uuid);
	return uuid;
}

static int json_object_find(const char *obj, const char *key, char *value, size_t len)
{
	struct spa_json it[2];
	const char *v;
	char k[128];

	spa_json_init(&it[0], obj, strlen(obj));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], k, sizeof(k)-1) > 0) {
		if (strcmp(k, key) == 0) {
			if (spa_json_get_string(&it[1], value, len) <= 0)
				continue;
			return 0;
		} else {
			if (spa_json_next(&it[1], &v) <= 0)
				break;
		}
	}
	return -ENOENT;
}

static int metadata_property(void *object, uint32_t id,
		const char *key, const char *type, const char *value)
{
	struct client *c = (struct client *) object;
	struct object *o;
	jack_uuid_t uuid;

	pw_log_debug("set id:%u key:'%s' value:'%s' type:'%s'", id, key, value, type);

	if (id == PW_ID_CORE) {
		if (key == NULL || strcmp(key, "default.audio.sink") == 0) {
			if (value != NULL) {
				if (json_object_find(value, "name",
						c->metadata->default_audio_sink,
						sizeof(c->metadata->default_audio_sink)) < 0)
					value = NULL;
			}
			if (value == NULL)
				c->metadata->default_audio_sink[0] = '\0';
		}
		if (key == NULL || strcmp(key, "default.audio.source") == 0) {
			if (value != NULL) {
				if (json_object_find(value, "name",
						c->metadata->default_audio_source,
						sizeof(c->metadata->default_audio_source)) < 0)
					value = NULL;
			}
			if (value == NULL)
				c->metadata->default_audio_source[0] = '\0';
		}
	} else {
		pthread_mutex_lock(&c->context.lock);
		o = pw_map_lookup(&c->context.globals, id);
		pthread_mutex_unlock(&c->context.lock);
		if (o == NULL)
			return -EINVAL;

		switch (o->type) {
		case INTERFACE_Node:
			uuid = client_make_uuid(id);
			break;
		case INTERFACE_Port:
			uuid = jack_port_uuid_generate(id);
			break;
		default:
			return -EINVAL;
		}
		update_property(c, uuid, key, type, value);
	}

	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property
};

#define FILTER_NAME	" ()[].:*$"
#define FILTER_PORT	" ()[].*$"

static void filter_name(char *str, const char *filter)
{
	char *p;
	for (p = str; *p; p++) {
		if (strchr(filter, *p) != NULL)
			*p = ' ';
	}
}

static void registry_event_global(void *data, uint32_t id,
                                  uint32_t permissions, const char *type, uint32_t version,
                                  const struct spa_dict *props)
{
	struct client *c = (struct client *) data;
	struct object *o, *ot, *op;
	const char *str;
	size_t size;
	bool is_first = false;

	if (props == NULL)
		return;

	if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		const char *app, *node_name;
		char tmp[JACK_CLIENT_NAME_SIZE+1];

		o = alloc_object(c, INTERFACE_Node);

		if ((str = spa_dict_lookup(props, PW_KEY_CLIENT_ID)) != NULL)
			o->node.client_id = atoi(str);

		node_name = spa_dict_lookup(props, PW_KEY_NODE_NAME);

		if (id == c->node_id) {
			pw_log_debug(NAME" %p: add our node %d", c, id);
			if (node_name != NULL)
				snprintf(c->name, sizeof(c->name), "%s", node_name);
		}
		snprintf(o->node.node_name, sizeof(o->node.node_name),
				"%s", node_name);

		app = spa_dict_lookup(props, PW_KEY_APP_NAME);

		if (c->short_name) {
			str = spa_dict_lookup(props, PW_KEY_NODE_NICK);
			if (str == NULL)
				str = spa_dict_lookup(props, PW_KEY_NODE_DESCRIPTION);
		} else {
			str = spa_dict_lookup(props, PW_KEY_NODE_DESCRIPTION);
			if (str == NULL)
				str = spa_dict_lookup(props, PW_KEY_NODE_NICK);
		}
		if (str == NULL)
			str = node_name;
		if (str == NULL)
			str = "node";

		if (app && strcmp(app, str) != 0)
			snprintf(tmp, sizeof(tmp), "%s/%s", app, str);
		else
			snprintf(tmp, sizeof(tmp), "%s", str);

		if (c->filter_name)
			filter_name(tmp, FILTER_NAME);

		ot = find_node(c, tmp);
		if (ot != NULL && o->node.client_id != ot->node.client_id) {
			snprintf(o->node.name, sizeof(o->node.name), "%.*s-%d",
					(int)(sizeof(tmp)-11), tmp, id);
		} else {
			is_first = ot == NULL;
			snprintf(o->node.name, sizeof(o->node.name), "%s", tmp);
		}

		if ((str = spa_dict_lookup(props, PW_KEY_PRIORITY_SESSION)) != NULL)
			o->node.priority = pw_properties_parse_int(str);

		pw_log_debug(NAME" %p: add node %d", c, id);

		pthread_mutex_lock(&c->context.lock);
		spa_list_append(&c->context.nodes, &o->link);
		pthread_mutex_unlock(&c->context.lock);
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0) {
		const struct spa_dict_item *item;
		unsigned long flags = 0;
		jack_port_type_id_t type_id;
		uint32_t node_id;
		bool is_monitor = false;
		char tmp[REAL_JACK_PORT_NAME_SIZE+1];

		if ((str = spa_dict_lookup(props, PW_KEY_FORMAT_DSP)) == NULL)
			str = "other";
		if ((type_id = string_to_type(str)) == SPA_ID_INVALID)
			goto exit;

		if ((str = spa_dict_lookup(props, PW_KEY_NODE_ID)) == NULL)
			goto exit;

		node_id = atoi(str);

		if ((str = spa_dict_lookup(props, PW_KEY_PORT_EXTRA)) != NULL &&
		    strstr(str, "jack:flags:") == str)
			flags = atoi(str+11);

		if ((str = spa_dict_lookup(props, PW_KEY_PORT_NAME)) == NULL)
			goto exit;

		spa_dict_for_each(item, props) {
	                if (!strcmp(item->key, PW_KEY_PORT_DIRECTION)) {
				if (strcmp(item->value, "in") == 0)
					flags |= JackPortIsInput;
				else if (strcmp(item->value, "out") == 0)
					flags |= JackPortIsOutput;
			}
			else if (!strcmp(item->key, PW_KEY_PORT_PHYSICAL)) {
				if (pw_properties_parse_bool(item->value))
					flags |= JackPortIsPhysical;
			}
			else if (!strcmp(item->key, PW_KEY_PORT_TERMINAL)) {
				if (pw_properties_parse_bool(item->value))
					flags |= JackPortIsTerminal;
			}
			else if (!strcmp(item->key, PW_KEY_PORT_CONTROL)) {
				if (pw_properties_parse_bool(item->value))
					type_id = TYPE_ID_MIDI;
			}
			else if (!strcmp(item->key, PW_KEY_PORT_MONITOR)) {
				is_monitor = pw_properties_parse_bool(item->value);
			}
		}

		o = NULL;
		if (node_id == c->node_id) {
			snprintf(tmp, sizeof(tmp), "%s:%s", c->name, str);
			o = find_port(c, tmp);
			if (o != NULL)
				pw_log_debug(NAME" %p: %s found our port %p", c, tmp, o);
		}
		if (o == NULL) {
			o = alloc_object(c, INTERFACE_Port);
			if (o == NULL)
				goto exit;

			pthread_mutex_lock(&c->context.lock);
			spa_list_append(&c->context.ports, &o->link);
			ot = pw_map_lookup(&c->context.globals, node_id);
			pthread_mutex_unlock(&c->context.lock);

			if (ot == NULL || ot->type != INTERFACE_Node)
				goto exit_free;

			if (is_monitor && !c->merge_monitor)
				snprintf(tmp, sizeof(tmp), "%.*s%s:%s",
					(int)(JACK_CLIENT_NAME_SIZE-(sizeof(MONITOR_EXT)-1)),
					ot->node.name, MONITOR_EXT, str);
			else
				snprintf(tmp, sizeof(tmp), "%s:%s", ot->node.name, str);

			if (c->filter_name)
				filter_name(tmp, FILTER_PORT);

			o->port.port_id = SPA_ID_INVALID;
			o->port.priority = ot->node.priority;
			o->port.node = ot;
		}

		if ((str = spa_dict_lookup(props, PW_KEY_OBJECT_PATH)) != NULL)
			snprintf(o->port.alias1, sizeof(o->port.alias1), "%s", str);

		if ((str = spa_dict_lookup(props, PW_KEY_PORT_ALIAS)) != NULL)
			snprintf(o->port.alias2, sizeof(o->port.alias2), "%s", str);

		if ((str = spa_dict_lookup(props, PW_KEY_PORT_ID)) != NULL)
			snprintf(o->port.system, sizeof(o->port.system), "system:%s_%d",
					flags & JackPortIsInput ? "playback" : "capture",
					atoi(str)+1);

		o->port.flags = flags;
		o->port.type_id = type_id;
		o->port.node_id = node_id;
		o->port.is_monitor = is_monitor;

		op = find_port(c, tmp);
		if (op != NULL && op != o)
			snprintf(o->port.name, sizeof(o->port.name), "%.*s-%d",
					(int)(sizeof(tmp)-11), tmp, id);
		else
			snprintf(o->port.name, sizeof(o->port.name), "%s", tmp);

		pw_log_debug(NAME" %p: add port %d name:%s %d", c, id,
				o->port.name, type_id);
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Link) == 0) {
		o = alloc_object(c, INTERFACE_Link);

		pthread_mutex_lock(&c->context.lock);
		spa_list_append(&c->context.links, &o->link);
		pthread_mutex_unlock(&c->context.lock);

		if ((str = spa_dict_lookup(props, PW_KEY_LINK_OUTPUT_PORT)) == NULL)
			goto exit_free;
		o->port_link.src = pw_properties_parse_int(str);

		if ((str = spa_dict_lookup(props, PW_KEY_LINK_INPUT_PORT)) == NULL)
			goto exit_free;
		o->port_link.dst = pw_properties_parse_int(str);

		pw_log_debug(NAME" %p: add link %d %d->%d", c, id,
				o->port_link.src, o->port_link.dst);
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Metadata) == 0) {
		struct pw_proxy *proxy;

		if (c->metadata)
			goto exit;

		proxy = pw_registry_bind(c->registry,
				id, type, PW_VERSION_METADATA, sizeof(struct metadata));

		c->metadata = pw_proxy_get_user_data(proxy);
		c->metadata->proxy = (struct pw_metadata*)proxy;
		c->metadata->default_audio_sink[0] = '\0';
		c->metadata->default_audio_source[0] = '\0';

		pw_metadata_add_listener(proxy,
				&c->metadata->listener,
				&metadata_events, c);
		goto exit;
	}
	else {
		goto exit;
	}

	o->id = id;

	pthread_mutex_lock(&c->context.lock);
        size = pw_map_get_size(&c->context.globals);
        while (id > size)
		pw_map_insert_at(&c->context.globals, size++, NULL);
	pw_map_insert_at(&c->context.globals, id, o);
	pthread_mutex_unlock(&c->context.lock);

	pw_thread_loop_unlock(c->context.loop);

	switch (o->type) {
	case INTERFACE_Node:
		if (c->registration_callback && is_first)
			c->registration_callback(o->node.name, 1, c->registration_arg);
		break;

	case INTERFACE_Port:
		if (c->portregistration_callback)
			c->portregistration_callback(o->id, 1, c->portregistration_arg);
		break;

	case INTERFACE_Link:
		if (c->connect_callback)
			c->connect_callback(o->port_link.src, o->port_link.dst, 1, c->connect_arg);
		break;
	}
	pw_thread_loop_lock(c->context.loop);

      exit:
	return;
      exit_free:
	free_object(c, o);
	return;
}

static void registry_event_global_remove(void *object, uint32_t id)
{
	struct client *c = (struct client *) object;
	struct object *o;
	bool is_last = false;

	pw_log_debug(NAME" %p: removed: %u", c, id);

	pthread_mutex_lock(&c->context.lock);
	o = pw_map_lookup(&c->context.globals, id);
	if (o != NULL)
	        spa_list_remove(&o->link);
	pthread_mutex_unlock(&c->context.lock);
	if (o == NULL)
		return;

	/* JACK clients expect the objects to hang around after
	 * they are unregistered. We keep the memory around for that
	 * reason but reuse it when we can. */
	spa_list_append(&c->context.free_objects, &o->link);

	if (o->type == INTERFACE_Node)
		is_last = find_node(c, o->node.name) == NULL;

	pw_thread_loop_unlock(c->context.loop);

	switch (o->type) {
	case INTERFACE_Node:
		if (c->metadata) {
			if (strcmp(o->node.node_name, c->metadata->default_audio_sink) == 0)
				c->metadata->default_audio_sink[0] = '\0';
			if (strcmp(o->node.node_name, c->metadata->default_audio_source) == 0)
				c->metadata->default_audio_source[0] = '\0';
		}
		if (c->registration_callback && is_last)
			c->registration_callback(o->node.name, 0, c->registration_arg);
		break;
	case INTERFACE_Port:
		if (c->portregistration_callback)
			c->portregistration_callback(o->id, 0, c->portregistration_arg);
		break;
	case INTERFACE_Link:
		if (c->connect_callback)
			c->connect_callback(o->port_link.src, o->port_link.dst, 0, c->connect_arg);
		break;
	}
	pw_thread_loop_lock(c->context.loop);

	/* we keep the object available with the id because jack clients
	 * tend to access the objects with it later.
	 *
	 * pw_map_insert_at(&c->context.globals, id, NULL);
	 */

	return;
}

static const struct pw_registry_events registry_events = {
        PW_VERSION_REGISTRY_EVENTS,
        .global = registry_event_global,
        .global_remove = registry_event_global_remove,
};

static void varargs_parse (struct client *c, jack_options_t options, va_list ap)
{
	if ((options & JackServerName))
		c->server_name = va_arg(ap, char *);
	if ((options & JackLoadName))
		c->load_name = va_arg(ap, char *);
	if ((options & JackLoadInit))
		c->load_init = va_arg(ap, char *);
	if ((options & JackSessionID)) {
		char *sid = va_arg(ap, char *);
		if (sid) {
			const long long id = atoll(sid);
			if (id > 0)
				c->session_id = id;
		}
	}
}

SPA_EXPORT
jack_client_t * jack_client_open (const char *client_name,
                                  jack_options_t options,
                                  jack_status_t *status, ...)
{
	struct client *client;
	const struct spa_support *support;
	uint32_t n_support;
	const char *str;
	struct spa_cpu *cpu_iface;
	struct spa_node_info ni;
	va_list ap;

        if (getenv("PIPEWIRE_NOJACK") != NULL ||
            getenv("PIPEWIRE_INTERNAL") != NULL ||
	    strstr(pw_get_library_version(), "0.2") != NULL)
		goto disabled;

	spa_return_val_if_fail(client_name != NULL, NULL);

	client = calloc(1, sizeof(struct client));
	if (client == NULL)
		goto disabled;

	pw_log_info(NAME" %p: open '%s' options:%d", client, client_name, options);

	va_start(ap, status);
	varargs_parse(client, options, ap);
	va_end(ap);

	if (client->server_name != NULL &&
	    strcmp(client->server_name, "default") == 0)
		client->server_name = NULL;

	client->props = pw_properties_new(
			"loop.cancel", "true",
			PW_KEY_REMOTE_NAME, client->server_name,
			PW_KEY_CLIENT_NAME, client_name,
			PW_KEY_CLIENT_API, "jack",
			PW_KEY_CONFIG_NAME, "jack.conf",
			NULL);
	if (client->props == NULL)
		goto no_props;

	client->node_id = SPA_ID_INVALID;
	snprintf(client->name, sizeof(client->name), "%s", client_name);
	client->context.loop = pw_thread_loop_new(client_name, NULL);
	client->context.l = pw_thread_loop_get_loop(client->context.loop),
	client->context.context = pw_context_new(
			client->context.l,
			pw_properties_copy(client->props),
			0);
	if (client->context.context == NULL)
		goto no_props;

	client->allow_mlock = client->context.context->defaults.mem_allow_mlock;
	client->warn_mlock = client->context.context->defaults.mem_warn_mlock;

	if ((str = pw_context_get_conf_section(client->context.context,
					"jack.properties")) != NULL)
		pw_properties_update_string(client->props, str, strlen(str));

        if ((str = getenv("PIPEWIRE_PROPS")) != NULL)
		pw_properties_update_string(client->props, str, strlen(str));

	if ((str = pw_properties_get(client->props, "jack.merge-monitor")) != NULL)
		client->merge_monitor = pw_properties_parse_bool(str);
	if ((str = pw_properties_get(client->props, "jack.short-name")) != NULL)
		client->short_name = pw_properties_parse_bool(str);
	if ((str = pw_properties_get(client->props, "jack.filter-name")) != NULL)
		client->filter_name = pw_properties_parse_bool(str);

	client->self_connect_mode = SELF_CONNECT_ALLOW;
	if ((str = pw_properties_get(client->props, "jack.self-connect-mode")) != NULL) {
		if (strcmp(str, "fail-external") == 0)
			client->self_connect_mode = SELF_CONNECT_FAIL_EXT;
		else if (strcmp(str, "ignore-external") == 0)
			client->self_connect_mode = SELF_CONNECT_IGNORE_EXT;
		else if (strcmp(str, "fail-all") == 0)
			client->self_connect_mode = SELF_CONNECT_FAIL_ALL;
		else if (strcmp(str, "ignore-all") == 0)
			client->self_connect_mode = SELF_CONNECT_IGNORE_ALL;
	}

	spa_list_init(&client->context.free_objects);
	pthread_mutex_init(&client->context.lock, NULL);
	spa_list_init(&client->context.nodes);
	spa_list_init(&client->context.ports);
	spa_list_init(&client->context.links);

	support = pw_context_get_support(client->context.context, &n_support);

	mix2 = mix2_c;
	cpu_iface = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);
	if (cpu_iface) {
#if defined (__SSE__)
		uint32_t flags = spa_cpu_get_flags(cpu_iface);
		if (flags & SPA_CPU_FLAG_SSE)
			mix2 = mix2_sse;
#endif
	}
	client->loop = client->context.context->data_loop_impl;

	spa_list_init(&client->links);
	spa_list_init(&client->rt.target_links);

	client->buffer_frames = (uint32_t)-1;
	client->sample_rate = (uint32_t)-1;
	client->latency = SPA_FRACTION(-1, -1);

        spa_list_init(&client->free_mix);

	init_port_pool(client, SPA_DIRECTION_INPUT);
	init_port_pool(client, SPA_DIRECTION_OUTPUT);

	pw_map_init(&client->context.globals, 64, 64);

	pw_thread_loop_start(client->context.loop);

	pw_thread_loop_lock(client->context.loop);

        client->core = pw_context_connect(client->context.context,
				pw_properties_copy(client->props), 0);
	if (client->core == NULL)
		goto server_failed;

	client->pool = pw_core_get_mempool(client->core);

	pw_core_add_listener(client->core,
			&client->core_listener,
			&core_events, client);
	client->registry = pw_core_get_registry(client->core,
			PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(client->registry,
			&client->registry_listener,
			&registry_events, client);

	if ((str = getenv("PIPEWIRE_LATENCY")) != NULL)
		pw_properties_set(client->props, PW_KEY_NODE_LATENCY, str);
	if ((str = pw_properties_get(client->props, PW_KEY_NODE_LATENCY)) != NULL) {
		uint32_t num, denom;
		if (sscanf(str, "%u/%u", &num, &denom) == 2 && denom != 0) {
			client->latency = SPA_FRACTION(num, denom);
		}
	}
	if (pw_properties_get(client->props, PW_KEY_NODE_NAME) == NULL)
		pw_properties_set(client->props, PW_KEY_NODE_NAME, client_name);
	if (pw_properties_get(client->props, PW_KEY_NODE_DESCRIPTION) == NULL)
		pw_properties_set(client->props, PW_KEY_NODE_DESCRIPTION, client_name);
	if (pw_properties_get(client->props, PW_KEY_MEDIA_TYPE) == NULL)
		pw_properties_set(client->props, PW_KEY_MEDIA_TYPE, "Audio");
	if (pw_properties_get(client->props, PW_KEY_MEDIA_CATEGORY) == NULL)
		pw_properties_set(client->props, PW_KEY_MEDIA_CATEGORY, "Duplex");
	if (pw_properties_get(client->props, PW_KEY_MEDIA_ROLE) == NULL)
		pw_properties_set(client->props, PW_KEY_MEDIA_ROLE, "DSP");
	if (pw_properties_get(client->props, PW_KEY_NODE_ALWAYS_PROCESS) == NULL)
		pw_properties_set(client->props, PW_KEY_NODE_ALWAYS_PROCESS, "true");

	client->node = pw_core_create_object(client->core,
				"client-node",
				PW_TYPE_INTERFACE_ClientNode,
				PW_VERSION_CLIENT_NODE,
				&client->props->dict,
				0);
	if (client->node == NULL)
		goto init_failed;

	pw_client_node_add_listener(client->node,
			&client->node_listener, &client_node_events, client);
        pw_proxy_add_listener((struct pw_proxy*)client->node,
			&client->proxy_listener, &node_proxy_events, client);

	ni = SPA_NODE_INFO_INIT();
	ni.max_input_ports = MAX_PORTS;
	ni.max_output_ports = MAX_PORTS;
	ni.change_mask = SPA_NODE_CHANGE_MASK_FLAGS;
	ni.flags = SPA_NODE_FLAG_RT;

	pw_client_node_update(client->node,
                                    PW_CLIENT_NODE_UPDATE_INFO,
				    0, NULL, &ni);

	if (status)
		*status = 0;

	while (true) {
	        pw_thread_loop_wait(client->context.loop);

		if (client->error)
			goto init_failed;

		if (client->has_transport)
			break;
	}

	if (strcmp(client->name, client_name) != 0) {
		if (status)
			*status |= JackNameNotUnique;
		if (options & JackUseExactName)
			goto exit;
	}
	pw_thread_loop_unlock(client->context.loop);

	pw_log_debug(NAME" %p: new", client);
	return (jack_client_t *)client;

no_props:
	if (status)
		*status = JackFailure | JackInitFailure;
	goto exit;
init_failed:
	if (status)
		*status = JackFailure | JackInitFailure;
	goto exit_unlock;
server_failed:
	if (status)
		*status = JackFailure | JackServerFailed;
	goto exit_unlock;
exit_unlock:
	pw_thread_loop_unlock(client->context.loop);
exit:
	free(client);
	return NULL;
disabled:
	if (status)
		*status = JackFailure | JackInitFailure;
	return NULL;
}

SPA_EXPORT
jack_client_t * jack_client_new (const char *client_name)
{
	jack_options_t options = JackUseExactName;
	jack_status_t status;

        if (getenv("JACK_START_SERVER") == NULL)
		options |= JackNoStartServer;

	return jack_client_open(client_name, options, &status, NULL);
}

SPA_EXPORT
int jack_client_close (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	pw_log_info(NAME" %p: close", client);

	c->destroyed = true;

	res = jack_deactivate(client);

	pw_thread_loop_stop(c->context.loop);

	if (c->registry)
		pw_proxy_destroy((struct pw_proxy*)c->registry);
	if (c->metadata && c->metadata->proxy) {
		pw_proxy_destroy((struct pw_proxy*)c->metadata->proxy);
	}
	pw_core_disconnect(c->core);
	pw_context_destroy(c->context.context);

	pw_thread_loop_destroy(c->context.loop);

	pw_log_debug(NAME" %p: free", client);
	pw_map_clear(&c->context.globals);
	pthread_mutex_destroy(&c->context.lock);
	pw_properties_free(c->props);
	free(c);

	return res;
}

SPA_EXPORT
int jack_client_name_size (void)
{
	pw_log_trace("%d", JACK_CLIENT_NAME_SIZE);
	return JACK_CLIENT_NAME_SIZE;
}

SPA_EXPORT
char * jack_get_client_name (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	spa_return_val_if_fail(c != NULL, NULL);
	return c->name;
}

SPA_EXPORT
char *jack_get_uuid_for_client_name (jack_client_t *client,
                                     const char    *client_name)
{
	struct client *c = (struct client *) client;
	struct object *o;
	char *uuid = NULL;

	spa_return_val_if_fail(c != NULL, NULL);
	spa_return_val_if_fail(client_name != NULL, NULL);

	pthread_mutex_lock(&c->context.lock);

	spa_list_for_each(o, &c->context.nodes, link) {
		if (strcmp(o->node.name, client_name) == 0) {
			uuid = spa_aprintf( "%" PRIu64, client_make_uuid(o->id));
			pw_log_debug(NAME" %p: name %s -> %s",
					client, client_name, uuid);
			break;
		}
	}
	pthread_mutex_unlock(&c->context.lock);
	return uuid;
}

SPA_EXPORT
char *jack_get_client_name_by_uuid (jack_client_t *client,
                                    const char    *client_uuid )
{
	struct client *c = (struct client *) client;
	struct object *o;
	jack_uuid_t uuid;
	char *name = NULL;

	spa_return_val_if_fail(c != NULL, NULL);
	spa_return_val_if_fail(client_uuid != NULL, NULL);

	if (jack_uuid_parse(client_uuid, &uuid) < 0)
		return NULL;

	pthread_mutex_lock(&c->context.lock);
	spa_list_for_each(o, &c->context.nodes, link) {
		if (client_make_uuid(o->id) == uuid) {
			pw_log_debug(NAME" %p: uuid %s (%"PRIu64")-> %s",
					client, client_uuid, uuid, o->node.name);
			name = strdup(o->node.name);
			break;
		}
	}
	pthread_mutex_unlock(&c->context.lock);
	return name;
}

SPA_EXPORT
int jack_internal_client_new (const char *client_name,
                              const char *load_name,
                              const char *load_init)
{
	pw_log_warn("not implemented %s %s %s", client_name, load_name, load_init);
	return -ENOTSUP;
}

SPA_EXPORT
void jack_internal_client_close (const char *client_name)
{
	pw_log_warn("not implemented %s", client_name);
}

static int do_activate(struct client *c)
{
	int res;

	pw_thread_loop_lock(c->context.loop);

	pw_log_info(NAME" %p: activate", c);
	pw_client_node_set_active(c->node, true);

	res = do_sync(c);

	pw_thread_loop_unlock(c->context.loop);
	return res;
}

SPA_EXPORT
int jack_activate (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active)
		return 0;

	if ((res = do_activate(c)) < 0)
		return res;

	c->activation->pending_new_pos = true;
	c->activation->pending_sync = true;
	c->active = true;

	if (c->position)
		check_buffer_frames(c, c->position, false);

	return 0;
}

SPA_EXPORT
int jack_deactivate (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (!c->active)
		return 0;

	pw_thread_loop_lock(c->context.loop);
	pw_log_info(NAME" %p: deactivate", c);
	pw_data_loop_stop(c->loop);

	pw_client_node_set_active(c->node, false);

	c->activation->pending_new_pos = false;
	c->activation->pending_sync = false;

	res = do_sync(c);

	pw_data_loop_start(c->loop);
	pw_thread_loop_unlock(c->context.loop);

	if (res < 0)
		return res;

	c->active = false;

	return 0;
}

SPA_EXPORT
int jack_get_client_pid (const char *name)
{
	pw_log_error("not implemented on library side");
	return 0;
}

SPA_EXPORT
jack_native_thread_t jack_client_thread_id (jack_client_t *client)
{
	return pthread_self();
}

SPA_EXPORT
int jack_is_realtime (jack_client_t *client)
{
	return 1;
}

SPA_EXPORT
jack_nframes_t jack_thread_wait (jack_client_t *client, int status)
{
	pw_log_error(NAME" %p: jack_thread_wait: deprecated, use jack_cycle_wait/jack_cycle_signal", client);
	return 0;
}

SPA_EXPORT
jack_nframes_t jack_cycle_wait (jack_client_t* client)
{
	struct client *c = (struct client *) client;
	jack_nframes_t res;

	spa_return_val_if_fail(c != NULL, 0);

	res = cycle_wait(c);
	pw_log_trace(NAME" %p: result:%d", c, res);
	return res;
}

SPA_EXPORT
void jack_cycle_signal (jack_client_t* client, int status)
{
	struct client *c = (struct client *) client;

	spa_return_if_fail(c != NULL);

	pw_log_trace(NAME" %p: status:%d", c, status);
	cycle_signal(c, status);
}

SPA_EXPORT
int jack_set_process_thread(jack_client_t* client, JackThreadCallback thread_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	} else if (c->process_callback) {
		pw_log_error(NAME" %p: process callback was already set", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, thread_callback, arg);
	c->thread_callback = thread_callback;
	c->thread_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_thread_init_callback (jack_client_t *client,
                                   JackThreadInitCallback thread_init_callback,
                                   void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	pw_log_debug(NAME" %p: %p %p", c, thread_init_callback, arg);
	c->thread_init_callback = thread_init_callback;
	c->thread_init_arg = arg;
	return 0;
}

SPA_EXPORT
void jack_on_shutdown (jack_client_t *client,
                       JackShutdownCallback shutdown_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_if_fail(c != NULL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
	} else {
		pw_log_debug(NAME" %p: %p %p", c, shutdown_callback, arg);
		c->shutdown_callback = shutdown_callback;
		c->shutdown_arg = arg;
	}
}

SPA_EXPORT
void jack_on_info_shutdown (jack_client_t *client,
                            JackInfoShutdownCallback shutdown_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_if_fail(c != NULL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
	} else {
		pw_log_debug(NAME" %p: %p %p", c, shutdown_callback, arg);
		c->info_shutdown_callback = shutdown_callback;
		c->info_shutdown_arg = arg;
	}
}

SPA_EXPORT
int jack_set_process_callback (jack_client_t *client,
                               JackProcessCallback process_callback,
                               void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	} else if (c->thread_callback) {
		pw_log_error(NAME" %p: thread callback was already set", c);
		return -EIO;
	}

	pw_log_debug(NAME" %p: %p %p", c, process_callback, arg);
	c->process_callback = process_callback;
	c->process_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_freewheel_callback (jack_client_t *client,
                                 JackFreewheelCallback freewheel_callback,
                                 void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, freewheel_callback, arg);
	c->freewheel_callback = freewheel_callback;
	c->freewheel_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_buffer_size_callback (jack_client_t *client,
                                   JackBufferSizeCallback bufsize_callback,
                                   void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, bufsize_callback, arg);
	c->bufsize_callback = bufsize_callback;
	c->bufsize_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_sample_rate_callback (jack_client_t *client,
                                   JackSampleRateCallback srate_callback,
                                   void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, srate_callback, arg);
	c->srate_callback = srate_callback;
	c->srate_arg = arg;
	if (c->srate_callback && c->sample_rate != (uint32_t)-1)
		c->srate_callback(c->sample_rate, c->srate_arg);
	return 0;
}

SPA_EXPORT
int jack_set_client_registration_callback (jack_client_t *client,
                                            JackClientRegistrationCallback
                                            registration_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, registration_callback, arg);
	c->registration_callback = registration_callback;
	c->registration_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_port_registration_callback (jack_client_t *client,
                                          JackPortRegistrationCallback
                                          registration_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, registration_callback, arg);
	c->portregistration_callback = registration_callback;
	c->portregistration_arg = arg;
	return 0;
}


SPA_EXPORT
int jack_set_port_connect_callback (jack_client_t *client,
                                    JackPortConnectCallback
                                    connect_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, connect_callback, arg);
	c->connect_callback = connect_callback;
	c->connect_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_port_rename_callback (jack_client_t *client,
                                   JackPortRenameCallback rename_callback,
				   void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, rename_callback, arg);
	c->rename_callback = rename_callback;
	c->rename_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_graph_order_callback (jack_client_t *client,
                                   JackGraphOrderCallback graph_callback,
                                   void *data)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_trace(NAME" %p: %p %p", c, graph_callback, data);
	c->graph_callback = graph_callback;
	c->graph_arg = data;
	return 0;
}

SPA_EXPORT
int jack_set_xrun_callback (jack_client_t *client,
                            JackXRunCallback xrun_callback, void *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, xrun_callback, arg);
	c->xrun_callback = xrun_callback;
	c->xrun_arg = arg;
	return 0;
}

SPA_EXPORT
int jack_set_latency_callback (jack_client_t *client,
			       JackLatencyCallback latency_callback,
			       void *data)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_debug(NAME" %p: %p %p", c, latency_callback, data);
	c->latency_callback = latency_callback;
	c->latency_arg = data;
	return 0;
}

SPA_EXPORT
int jack_set_freewheel(jack_client_t* client, int onoff)
{
	pw_log_warn(NAME" %p: not implemented %d", client, onoff);
	return -ENOTSUP;
}

SPA_EXPORT
int jack_set_buffer_size (jack_client_t *client, jack_nframes_t nframes)
{
	struct client *c = (struct client *) client;
	struct spa_node_info ni;
	struct spa_dict_item items[1];
	char latency[128];

	spa_return_val_if_fail(c != NULL, -EINVAL);

	snprintf(latency, sizeof(latency), "%d/%d", nframes, jack_get_sample_rate(client));
	pw_log_info(NAME" %p: buffer-size %s", client, latency);

	ni = SPA_NODE_INFO_INIT();
	ni.max_input_ports = MAX_PORTS;
	ni.max_output_ports = MAX_PORTS;
	ni.change_mask = SPA_NODE_CHANGE_MASK_PROPS;
	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_NODE_LATENCY, latency);
	ni.props = &SPA_DICT_INIT_ARRAY(items);

	pw_client_node_update(c->node,
                                    PW_CLIENT_NODE_UPDATE_INFO,
				    0, NULL, &ni);

	return 0;
}

SPA_EXPORT
jack_nframes_t jack_get_sample_rate (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	jack_nframes_t res = -1;

	spa_return_val_if_fail(c != NULL, 0);

	if (!c->active)
		res = c->latency.denom;
	if (c->active || res == (uint32_t)-1) {
		res = c->sample_rate;
		if (res == (uint32_t)-1) {
			if (c->rt.position)
				res = c->rt.position->clock.rate.denom;
			else if (c->position)
				res = c->position->clock.rate.denom;
		}
	}
	pw_log_info("sample_rate: %u", res);
	return res;
}

SPA_EXPORT
jack_nframes_t jack_get_buffer_size (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	jack_nframes_t res = -1;

	spa_return_val_if_fail(c != NULL, 0);

	if (!c->active)
		res = c->latency.num;
	if (c->active || res == (uint32_t)-1) {
		res = c->buffer_frames;
		if (res == (uint32_t)-1) {
			if (c->rt.position)
				res = c->rt.position->clock.duration;
			else if (c->position)
				res = c->position->clock.duration;
		}
	}
	pw_log_info("buffer_frames: %u", res);
	return res;
}

SPA_EXPORT
int jack_engine_takeover_timebase (jack_client_t *client)
{
	pw_log_error(NAME" %p: deprecated", client);
	return 0;
}

SPA_EXPORT
float jack_cpu_load (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	float res = 0.0f;

	spa_return_val_if_fail(c != NULL, 0.0);

	if (c->driver_activation)
		res = c->driver_activation->cpu_load[0] * 100.0f;

	pw_log_trace(NAME" %p: cpu load %f", client, res);
	return res;
}

#include "statistics.c"

static void *get_buffer_input_float(struct port *p, jack_nframes_t frames);
static void *get_buffer_input_midi(struct port *p, jack_nframes_t frames);
static void *get_buffer_input_empty(struct port *p, jack_nframes_t frames);
static void *get_buffer_output_float(struct port *p, jack_nframes_t frames);
static void *get_buffer_output_midi(struct port *p, jack_nframes_t frames);
static void *get_buffer_output_empty(struct port *p, jack_nframes_t frames);

SPA_EXPORT
jack_port_t * jack_port_register (jack_client_t *client,
                                  const char *port_name,
                                  const char *port_type,
                                  unsigned long flags,
                                  unsigned long buffer_frames)
{
	struct client *c = (struct client *) client;
	enum spa_direction direction;
	struct spa_port_info port_info;
	struct spa_param_info port_params[5];
	struct spa_dict dict;
	struct spa_dict_item items[10];
	struct object *o;
	jack_port_type_id_t type_id;
	uint8_t buffer[1024];
	char port_flags[64];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	struct spa_pod *params[4];
	uint32_t n_params = 0;
	struct port *p;
	int res;

	spa_return_val_if_fail(c != NULL, NULL);
	spa_return_val_if_fail(port_name != NULL, NULL);
	spa_return_val_if_fail(port_type != NULL, NULL);

	pw_log_info(NAME" %p: port register \"%s\" \"%s\" %08lx %ld",
			c, port_name, port_type, flags, buffer_frames);

	if (flags & JackPortIsInput)
		direction = PW_DIRECTION_INPUT;
	else if (flags & JackPortIsOutput)
		direction = PW_DIRECTION_OUTPUT;
	else
		return NULL;

	if ((type_id = string_to_type(port_type)) == SPA_ID_INVALID)
		return NULL;

	if ((p = alloc_port(c, direction)) == NULL)
		return NULL;

	o = p->object;
	o->port.flags = flags;
	snprintf(o->port.name, sizeof(o->port.name), "%s:%s", c->name, port_name);
	o->port.type_id = type_id;

	init_buffer(p);

	if (direction == SPA_DIRECTION_INPUT) {
		switch (type_id) {
		case TYPE_ID_AUDIO:
		case TYPE_ID_VIDEO:
			p->get_buffer = get_buffer_input_float;
			break;
		case TYPE_ID_MIDI:
			p->get_buffer = get_buffer_input_midi;
			break;
		default:
			p->get_buffer = get_buffer_input_empty;
			break;
		}
	} else {
		switch (type_id) {
		case TYPE_ID_AUDIO:
		case TYPE_ID_VIDEO:
			p->get_buffer = get_buffer_output_float;
			break;
		case TYPE_ID_MIDI:
			p->get_buffer = get_buffer_output_midi;
			break;
		default:
			p->get_buffer = get_buffer_output_empty;
			break;
		}
	}

	pw_log_debug(NAME" %p: port %p", c, p);

	spa_list_init(&p->mix);

	port_info = SPA_PORT_INFO_INIT();
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_FLAGS;
	port_info.flags = SPA_PORT_FLAG_NO_REF;
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_PROPS;
	dict = SPA_DICT_INIT(items, 0);
	items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_FORMAT_DSP, port_type);
	items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_PORT_NAME, port_name);
	if (flags > 0x1f) {
		snprintf(port_flags, sizeof(port_flags), "jack:flags:%lu", flags & ~0x1f);
		items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_PORT_EXTRA, port_flags);
	}
	if (flags & JackPortIsPhysical)
		items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_PORT_PHYSICAL, "true");
	if (flags & JackPortIsTerminal)
		items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_PORT_TERMINAL, "true");
	port_info.props = &dict;
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	port_params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port_params[1] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	port_params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port_params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port_info.params = port_params;
	port_info.n_params = 4;

	param_enum_format(c, p, &params[n_params++], &b);
	param_buffers(c, p, &params[n_params++], &b);
	param_io(c, p, &params[n_params++], &b);

	pw_thread_loop_lock(c->context.loop);

	pw_client_node_port_update(c->node,
					 direction,
					 p->id,
					 PW_CLIENT_NODE_PORT_UPDATE_PARAMS |
					 PW_CLIENT_NODE_PORT_UPDATE_INFO,
					 n_params,
					 (const struct spa_pod **) params,
					 &port_info);

	res = do_sync(c);

	pw_thread_loop_unlock(c->context.loop);

	if (res < 0)
		return NULL;

	return (jack_port_t *) o;
}

SPA_EXPORT
int jack_port_unregister (jack_client_t *client, jack_port_t *port)
{
	struct client *c = (struct client *) client;
	struct object *o = (struct object *) port;
	struct port *p;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(o != NULL, -EINVAL);

	if (o->type != INTERFACE_Port || o->port.port_id == SPA_ID_INVALID ||
	    o->client != c) {
		pw_log_error(NAME" %p: invalid port %p", client, port);
		return -EINVAL;
	}
	pw_log_info(NAME" %p: port unregister %p", client, port);

	pw_thread_loop_lock(c->context.loop);

	p = GET_PORT(c, GET_DIRECTION(o->port.flags), o->port.port_id);

	free_port(c, p);

	pw_client_node_port_update(c->node,
					 p->direction,
					 p->id,
					 0, 0, NULL, NULL);

	res = do_sync(c);

	pw_thread_loop_unlock(c->context.loop);

	return res;
}

static void *get_buffer_input_float(struct port *p, jack_nframes_t frames)
{
	struct mix *mix;
	struct buffer *b;
	struct spa_io_buffers *io;
	int layer = 0;
	void *ptr = NULL;

	spa_list_for_each(mix, &p->mix, port_link) {
		pw_log_trace_fp(NAME" %p: port %p mix %d.%d get buffer %d",
				p->client, p, p->id, mix->id, frames);
		io = mix->io;
		if (io == NULL ||
		    io->status != SPA_STATUS_HAVE_DATA ||
		    io->buffer_id >= mix->n_buffers)
			continue;

		io->status = SPA_STATUS_NEED_DATA;
		b = &mix->buffers[io->buffer_id];
		if (layer++ == 0)
			ptr = b->datas[0].data;
		else  {
			mix2(p->emptyptr, ptr, b->datas[0].data, frames);
			ptr = p->emptyptr;
			p->zeroed = false;
		}
	}
	if (ptr == NULL)
		ptr = init_buffer(p);
	return ptr;
}

static void *get_buffer_input_midi(struct port *p, jack_nframes_t frames)
{
	struct mix *mix;
	struct spa_io_buffers *io;
	void *ptr = p->emptyptr;
	struct spa_pod_sequence *seq[CONNECTION_NUM_FOR_PORT];
	uint32_t n_seq = 0;

	jack_midi_clear_buffer(ptr);

	spa_list_for_each(mix, &p->mix, port_link) {
		struct spa_data *d;
		void *pod;

		pw_log_trace_fp(NAME" %p: port %p mix %d.%d get buffer %d",
				p->client, p, p->id, mix->id, frames);

		io = mix->io;
		if (io == NULL ||
		    io->status != SPA_STATUS_HAVE_DATA ||
		    io->buffer_id >= mix->n_buffers)
			continue;

		io->status = SPA_STATUS_NEED_DATA;
		d = &mix->buffers[io->buffer_id].datas[0];

		if ((pod = spa_pod_from_data(d->data, d->maxsize, d->chunk->offset, d->chunk->size)) == NULL)
			continue;
		if (!spa_pod_is_sequence(pod))
			continue;

		seq[n_seq++] = pod;
	}
	convert_to_midi(seq, n_seq, ptr);

	return ptr;
}

static void *get_buffer_output_float(struct port *p, jack_nframes_t frames)
{
	void *ptr;

	ptr = get_buffer_output(p, frames, sizeof(float));
	if (SPA_UNLIKELY(p->empty_out = (ptr == NULL)))
		ptr = p->emptyptr;
	return ptr;
}

static void *get_buffer_output_midi(struct port *p, jack_nframes_t frames)
{
	p->empty_out = true;
	return p->emptyptr;
}

static void *get_buffer_output_empty(struct port *p, jack_nframes_t frames)
{
	p->empty_out = true;
	return p->emptyptr;
}

static void *get_buffer_input_empty(struct port *p, jack_nframes_t frames)
{
	return init_buffer(p);
}

SPA_EXPORT
void * jack_port_get_buffer (jack_port_t *port, jack_nframes_t frames)
{
	struct object *o = (struct object *) port;
	struct port *p;
	void *ptr;

	spa_return_val_if_fail(o != NULL, NULL);

	if ((p = o->port.port) == NULL)
		return NULL;

	ptr = p->get_buffer(p, frames);
	pw_log_trace_fp(NAME" %p: port %p buffer %p empty:%u", p->client, p, ptr, p->empty_out);
	return ptr;
}

SPA_EXPORT
jack_uuid_t jack_port_uuid (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, 0);
	return jack_port_uuid_generate(o->id);
}

SPA_EXPORT
const char * jack_port_name (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, NULL);
	return o->port.name;
}

SPA_EXPORT
const char * jack_port_short_name (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, NULL);
	return strchr(o->port.name, ':') + 1;
}

SPA_EXPORT
int jack_port_flags (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, 0);
	return o->port.flags;
}

SPA_EXPORT
const char * jack_port_type (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, NULL);
	return type_to_string(o->port.type_id);
}

SPA_EXPORT
jack_port_type_id_t jack_port_type_id (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, 0);
	return o->port.type_id;
}

SPA_EXPORT
int jack_port_is_mine (const jack_client_t *client, const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, 0);
	return o->type == INTERFACE_Port && o->port.port_id != SPA_ID_INVALID;
}

SPA_EXPORT
int jack_port_connected (const jack_port_t *port)
{
	struct object *o = (struct object *) port;
	struct client *c;
	struct object *l;
	int res = 0;

	spa_return_val_if_fail(o != NULL, 0);

	c = o->client;

	pthread_mutex_lock(&c->context.lock);
	spa_list_for_each(l, &c->context.links, link) {
		if (l->port_link.src == o->id ||
		    l->port_link.dst == o->id)
			res++;
	}
	pthread_mutex_unlock(&c->context.lock);

	pw_log_debug(NAME" %p: id:%d res:%d", port, o->id, res);

	return res;
}

SPA_EXPORT
int jack_port_connected_to (const jack_port_t *port,
                            const char *port_name)
{
	struct object *o = (struct object *) port;
	struct client *c;
	struct object *p, *l;
	int res = 0;

	spa_return_val_if_fail(o != NULL, 0);
	spa_return_val_if_fail(port_name != NULL, 0);

	c = o->client;

	pthread_mutex_lock(&c->context.lock);

	p = find_port(c, port_name);
	if (p == NULL)
		goto exit;

	if (GET_DIRECTION(p->port.flags) == GET_DIRECTION(o->port.flags))
		goto exit;

	if (p->port.flags & JackPortIsOutput) {
		l = p;
		p = o;
		o = l;
	}
	if (find_link(c, o->id, p->id))
		res = 1;

     exit:
	pthread_mutex_unlock(&c->context.lock);
	pw_log_debug(NAME" %p: id:%d name:%s res:%d", port, o->id, port_name, res);

	return res;
}

SPA_EXPORT
const char ** jack_port_get_connections (const jack_port_t *port)
{
	struct object *o = (struct object *) port;

	spa_return_val_if_fail(o != NULL, NULL);

	return jack_port_get_all_connections((jack_client_t *)o->client, port);
}

SPA_EXPORT
const char ** jack_port_get_all_connections (const jack_client_t *client,
                                             const jack_port_t *port)
{
	struct client *c = (struct client *) client;
	struct object *o = (struct object *) port;
	struct object *p, *l;
	const char **res;
	int count = 0;

	spa_return_val_if_fail(c != NULL, NULL);
	spa_return_val_if_fail(o != NULL, NULL);

	res = malloc(sizeof(char*) * (CONNECTION_NUM_FOR_PORT + 1));

	pthread_mutex_lock(&c->context.lock);
	spa_list_for_each(l, &c->context.links, link) {
		if (l->port_link.src == o->id)
			p = pw_map_lookup(&c->context.globals, l->port_link.dst);
		else if (l->port_link.dst == o->id)
			p = pw_map_lookup(&c->context.globals, l->port_link.src);
		else
			continue;

		if (p == NULL)
			continue;

		res[count++] = p->port.name;
		if (count == CONNECTION_NUM_FOR_PORT)
			break;
	}
	pthread_mutex_unlock(&c->context.lock);

	if (count == 0) {
		free(res);
		res = NULL;
	} else
		res[count] = NULL;

	return res;
}

SPA_EXPORT
int jack_port_tie (jack_port_t *src, jack_port_t *dst)
{
	pw_log_warn("not implemented %p %p", src, dst);
	return -ENOTSUP;
}

SPA_EXPORT
int jack_port_untie (jack_port_t *port)
{
	pw_log_warn("not implemented %p", port);
	return -ENOTSUP;
}

SPA_EXPORT
int jack_port_set_name (jack_port_t *port, const char *port_name)
{
	pw_log_warn("deprecated");
	return 0;
}

SPA_EXPORT
int jack_port_rename (jack_client_t* client, jack_port_t *port, const char *port_name)
{
	struct client *c = (struct client *) client;
	struct object *o = (struct object *) port;
	struct port *p;
	struct spa_port_info port_info;
	struct spa_dict dict;
	struct spa_dict_item items[1];

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(o != NULL, -EINVAL);
	spa_return_val_if_fail(port_name != NULL, -EINVAL);

	pw_thread_loop_lock(c->context.loop);

	p = GET_PORT(c, GET_DIRECTION(o->port.flags), o->port.port_id);

	port_info = SPA_PORT_INFO_INIT();
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_PROPS;
	dict = SPA_DICT_INIT(items, 0);
	items[dict.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_PORT_NAME, port_name);
	port_info.props = &dict;

	pw_client_node_port_update(c->node,
					 p->direction,
					 p->id,
					 PW_CLIENT_NODE_PORT_UPDATE_INFO,
					 0, NULL,
					 &port_info);
	pw_thread_loop_unlock(c->context.loop);

	return 0;
}

SPA_EXPORT
int jack_port_set_alias (jack_port_t *port, const char *alias)
{
	struct object *o = (struct object *) port;
	struct client *c;
	struct port *p;
	struct spa_port_info port_info;
	struct spa_dict dict;
	struct spa_dict_item items[1];
	const char *key;

	spa_return_val_if_fail(o != NULL, -EINVAL);
	spa_return_val_if_fail(alias != NULL, -EINVAL);

	c = o->client;

	pw_thread_loop_lock(c->context.loop);

	if (o->port.alias1[0] == '\0') {
		key = PW_KEY_OBJECT_PATH;
		snprintf(o->port.alias1, sizeof(o->port.alias1), "%s", alias);
	}
	else if (o->port.alias2[0] == '\0') {
		key = PW_KEY_PORT_ALIAS;
		snprintf(o->port.alias2, sizeof(o->port.alias2), "%s", alias);
	}
	else
		goto error;

	p = GET_PORT(c, GET_DIRECTION(o->port.flags), o->port.port_id);

	port_info = SPA_PORT_INFO_INIT();
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_PROPS;
	dict = SPA_DICT_INIT(items, 0);
	items[dict.n_items++] = SPA_DICT_ITEM_INIT(key, alias);
	port_info.props = &dict;

	pw_client_node_port_update(c->node,
					 p->direction,
					 p->id,
					 PW_CLIENT_NODE_PORT_UPDATE_INFO,
					 0, NULL,
					 &port_info);
	pw_thread_loop_unlock(c->context.loop);

	return 0;

error:
	pw_thread_loop_unlock(c->context.loop);
	return -1;
}

SPA_EXPORT
int jack_port_unset_alias (jack_port_t *port, const char *alias)
{
	struct object *o = (struct object *) port;
	struct client *c;
	struct port *p;
	struct spa_port_info port_info;
	struct spa_dict dict;
	struct spa_dict_item items[1];
	const char *key;

	spa_return_val_if_fail(o != NULL, -EINVAL);
	spa_return_val_if_fail(alias != NULL, -EINVAL);

	c = o->client;

	pw_thread_loop_lock(c->context.loop);

	if (strcmp(o->port.alias1, alias) == 0)
		key = PW_KEY_OBJECT_PATH;
	else if (strcmp(o->port.alias2, alias) == 0)
		key = PW_KEY_PORT_ALIAS;
	else
		goto error;

	p = GET_PORT(c, GET_DIRECTION(o->port.flags), o->port.port_id);

	port_info = SPA_PORT_INFO_INIT();
	port_info.change_mask |= SPA_PORT_CHANGE_MASK_PROPS;
	dict = SPA_DICT_INIT(items, 0);
	items[dict.n_items++] = SPA_DICT_ITEM_INIT(key, NULL);
	port_info.props = &dict;

	pw_client_node_port_update(c->node,
					 p->direction,
					 p->id,
					 PW_CLIENT_NODE_PORT_UPDATE_INFO,
					 0, NULL,
					 &port_info);
	pw_thread_loop_unlock(c->context.loop);

	return 0;

error:
	pw_thread_loop_unlock(c->context.loop);
	return -1;
}

SPA_EXPORT
int jack_port_get_aliases (const jack_port_t *port, char* const aliases[2])
{
	struct object *o = (struct object *) port;
	struct client *c;
	int res = 0;

	spa_return_val_if_fail(o != NULL, -EINVAL);
	spa_return_val_if_fail(aliases != NULL, -EINVAL);
	spa_return_val_if_fail(aliases[0] != NULL, -EINVAL);
	spa_return_val_if_fail(aliases[1] != NULL, -EINVAL);

	c = o->client;

	pw_thread_loop_lock(c->context.loop);

	if (o->port.alias1[0] != '\0') {
		snprintf(aliases[0], REAL_JACK_PORT_NAME_SIZE+1, "%s", o->port.alias1);
		res++;
	}
	if (o->port.alias2[0] != '\0') {
		snprintf(aliases[1], REAL_JACK_PORT_NAME_SIZE+1, "%s", o->port.alias2);
		res++;
	}
	pw_thread_loop_unlock(c->context.loop);

	return res;
}

SPA_EXPORT
int jack_port_request_monitor (jack_port_t *port, int onoff)
{
	struct object *o = (struct object *) port;

	spa_return_val_if_fail(o != NULL, -EINVAL);

	if (onoff)
		o->port.monitor_requests++;
	else if (o->port.monitor_requests > 0)
		o->port.monitor_requests--;
	return 0;
}

SPA_EXPORT
int jack_port_request_monitor_by_name (jack_client_t *client,
                                       const char *port_name, int onoff)
{
	struct client *c = (struct client *) client;
	struct object *p;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(port_name != NULL, -EINVAL);

	pthread_mutex_lock(&c->context.lock);
	p = find_port(c, port_name);
	pthread_mutex_unlock(&c->context.lock);

	if (p == NULL) {
		pw_log_error(NAME" %p: jack_port_request_monitor_by_name called"
				" with an incorrect port %s", client, port_name);
		return -1;
	}

	return jack_port_request_monitor((jack_port_t*)p, onoff);
}

SPA_EXPORT
int jack_port_ensure_monitor (jack_port_t *port, int onoff)
{
	struct object *o = (struct object *) port;

	spa_return_val_if_fail(o != NULL, -EINVAL);

	if (onoff) {
		if (o->port.monitor_requests == 0)
			o->port.monitor_requests++;
	} else {
		if (o->port.monitor_requests > 0)
			o->port.monitor_requests = 0;
	}
	return 0;
}

SPA_EXPORT
int jack_port_monitoring_input (jack_port_t *port)
{
	struct object *o = (struct object *) port;
	spa_return_val_if_fail(o != NULL, -EINVAL);
	return o->port.monitor_requests > 0;
}

static void link_proxy_error(void *data, int seq, int res, const char *message)
{
	int *link_res = data;
	*link_res = res;
}

static const struct pw_proxy_events link_proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.error = link_proxy_error,
};

static int check_connect(struct client *c, struct object *src, struct object *dst)
{
	int src_self, dst_self, sum;

	if (c->self_connect_mode == SELF_CONNECT_ALLOW)
		return 1;

	src_self = src->port.node_id == c->node_id ? 1 : 0;
	dst_self = dst->port.node_id == c->node_id ? 1 : 0;
	sum = src_self + dst_self;
	/* check for no self connection first */
	if (sum == 0)
		return 1;

	/* internal connection */
	if (sum == 2 &&
	    (c->self_connect_mode == SELF_CONNECT_FAIL_EXT ||
	     c->self_connect_mode == SELF_CONNECT_IGNORE_EXT))
		return 1;

	/* failure -> -1 */
	if (c->self_connect_mode < 0)
		return -1;

	/* ignore -> 0 */
	return 0;
}

SPA_EXPORT
int jack_connect (jack_client_t *client,
                  const char *source_port,
                  const char *destination_port)
{
	struct client *c = (struct client *) client;
	struct object *src, *dst;
	struct spa_dict props;
	struct spa_dict_item items[6];
	struct pw_proxy *proxy;
	struct spa_hook listener;
	char val[4][16];
	const char *str;
	int res, link_res = 0;

	spa_return_val_if_fail(c != NULL, EINVAL);
	spa_return_val_if_fail(source_port != NULL, EINVAL);
	spa_return_val_if_fail(destination_port != NULL, EINVAL);

	pw_log_info(NAME" %p: connect %s %s", client, source_port, destination_port);

	pw_thread_loop_lock(c->context.loop);

	src = find_port(c, source_port);
	dst = find_port(c, destination_port);

	if (src == NULL || dst == NULL ||
	    !(src->port.flags & JackPortIsOutput) ||
	    !(dst->port.flags & JackPortIsInput) ||
	    src->port.type_id != dst->port.type_id) {
		res = -EINVAL;
		goto exit;
	}
	if ((res = check_connect(c, src, dst)) != 1)
		goto exit;

	snprintf(val[0], sizeof(val[0]), "%d", src->port.node_id);
	snprintf(val[1], sizeof(val[1]), "%d", src->id);
	snprintf(val[2], sizeof(val[2]), "%d", dst->port.node_id);
	snprintf(val[3], sizeof(val[3]), "%d", dst->id);

	props = SPA_DICT_INIT(items, 0);
	items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_OUTPUT_NODE, val[0]);
	items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_OUTPUT_PORT, val[1]);
	items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_INPUT_NODE, val[2]);
	items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_INPUT_PORT, val[3]);
	items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_OBJECT_LINGER, "true");
	if ((str = getenv("PIPEWIRE_LINK_PASSIVE")) != NULL &&
	    pw_properties_parse_bool(str))
		items[props.n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_PASSIVE, "true");

	proxy = pw_core_create_object(c->core,
				    "link-factory",
				    PW_TYPE_INTERFACE_Link,
				    PW_VERSION_LINK,
				    &props,
				    0);
	if (proxy == NULL) {
		res = -errno;
		goto exit;
	}

	spa_zero(listener);
	pw_proxy_add_listener(proxy, &listener, &link_proxy_events, &link_res);

	res = do_sync(c);

	spa_hook_remove(&listener);

	if (link_res < 0)
		res = link_res;

	pw_proxy_destroy(proxy);

      exit:
	pw_thread_loop_unlock(c->context.loop);

	return -res;
}

SPA_EXPORT
int jack_disconnect (jack_client_t *client,
                     const char *source_port,
                     const char *destination_port)
{
	struct client *c = (struct client *) client;
	struct object *src, *dst, *l;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(source_port != NULL, -EINVAL);
	spa_return_val_if_fail(destination_port != NULL, -EINVAL);

	pw_log_debug(NAME" %p: disconnect %s %s", client, source_port, destination_port);

	pw_thread_loop_lock(c->context.loop);

	src = find_port(c, source_port);
	dst = find_port(c, destination_port);

	pw_log_debug(NAME" %p: %d %d", client, src->id, dst->id);

	if (src == NULL || dst == NULL ||
	    !(src->port.flags & JackPortIsOutput) ||
	    !(dst->port.flags & JackPortIsInput)) {
		res = -EINVAL;
		goto exit;
	}

	if ((res = check_connect(c, src, dst)) != 1)
		goto exit;

	if ((l = find_link(c, src->id, dst->id)) == NULL) {
		res = -ENOENT;
		goto exit;
	}

	pw_registry_destroy(c->registry, l->id);

	res = do_sync(c);

      exit:
	pw_thread_loop_unlock(c->context.loop);

	return -res;
}

SPA_EXPORT
int jack_port_disconnect (jack_client_t *client, jack_port_t *port)
{
	struct client *c = (struct client *) client;
	struct object *o = (struct object *) port;
	struct object *l;
	int res;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(o != NULL, -EINVAL);

	pw_log_debug(NAME" %p: disconnect %p", client, port);

	pw_thread_loop_lock(c->context.loop);

	spa_list_for_each(l, &c->context.links, link) {
		if (l->port_link.src == o->id ||
		    l->port_link.dst == o->id) {
			pw_registry_destroy(c->registry, l->id);
		}
	}
	res = do_sync(c);

	pw_thread_loop_unlock(c->context.loop);

	return -res;
}

SPA_EXPORT
int jack_port_name_size(void)
{
	return REAL_JACK_PORT_NAME_SIZE+1;
}

SPA_EXPORT
int jack_port_type_size(void)
{
	return JACK_PORT_TYPE_SIZE+1;
}

SPA_EXPORT
size_t jack_port_type_get_buffer_size (jack_client_t *client, const char *port_type)
{
	spa_return_val_if_fail(client != NULL, 0);
	spa_return_val_if_fail(port_type != NULL, 0);

	if (!strcmp(JACK_DEFAULT_AUDIO_TYPE, port_type))
		return jack_get_buffer_size(client) * sizeof(float);
	else if (!strcmp(JACK_DEFAULT_MIDI_TYPE, port_type))
		return MAX_BUFFER_FRAMES * sizeof(float);
	else if (!strcmp(JACK_DEFAULT_VIDEO_TYPE, port_type))
		return 320 * 240 * 4 * sizeof(float);
	else
		return 0;
}

SPA_EXPORT
void jack_port_set_latency (jack_port_t *port, jack_nframes_t frames)
{
	struct object *o = (struct object *) port;
	jack_latency_range_t range = { frames, frames };

	spa_return_if_fail(o != NULL);

	if (o->port.flags & JackPortIsOutput) {
		jack_port_set_latency_range(port, JackCaptureLatency, &range);
        }
        if (o->port.flags & JackPortIsInput) {
		jack_port_set_latency_range(port, JackPlaybackLatency, &range);
        }
}

SPA_EXPORT
void jack_port_get_latency_range (jack_port_t *port, jack_latency_callback_mode_t mode, jack_latency_range_t *range)
{
	struct object *o = (struct object *) port;
	struct client *c;

	spa_return_if_fail(o != NULL);
	c = o->client;

	if (o->port.flags & JackPortIsTerminal) {
		jack_nframes_t nframes = jack_get_buffer_size((jack_client_t*)c);
		if (o->port.flags & JackPortIsOutput) {
			o->port.capture_latency.min = nframes;
			o->port.capture_latency.max = nframes;
		} else {
			o->port.playback_latency.min = nframes;
			o->port.playback_latency.max = nframes;
		}
	}

	if (mode == JackCaptureLatency) {
		*range = o->port.capture_latency;
	} else {
		*range = o->port.playback_latency;
	}
}

SPA_EXPORT
void jack_port_set_latency_range (jack_port_t *port, jack_latency_callback_mode_t mode, jack_latency_range_t *range)
{
	struct object *o = (struct object *) port;

	spa_return_if_fail(o != NULL);

	if (mode == JackCaptureLatency) {
		o->port.capture_latency = *range;
	} else {
		o->port.playback_latency = *range;
	}
}

SPA_EXPORT
int jack_recompute_total_latencies (jack_client_t *client)
{
	pw_log_warn(NAME" %p: not implemented", client);
	return 0;
}

SPA_EXPORT
jack_nframes_t jack_port_get_latency (jack_port_t *port)
{
	struct object *o = (struct object *) port;
	jack_latency_range_t range = { 0, 0 };

	spa_return_val_if_fail(o != NULL, 0);

	if (o->port.flags & JackPortIsOutput) {
		jack_port_get_latency_range(port, JackCaptureLatency, &range);
        }
        if (o->port.flags & JackPortIsInput) {
		jack_port_get_latency_range(port, JackPlaybackLatency, &range);
        }
	return (range.min + range.max) / 2;
}

SPA_EXPORT
jack_nframes_t jack_port_get_total_latency (jack_client_t *client,
					    jack_port_t *port)
{
	pw_log_warn(NAME" %p: not implemented %p", client, port);
	return 0;
}

SPA_EXPORT
int jack_recompute_total_latency (jack_client_t *client, jack_port_t* port)
{
	pw_log_warn(NAME" %p: not implemented %p", client, port);
	return 0;
}

static int port_compare_func(const void *v1, const void *v2)
{
	const struct object *const*o1 = v1, *const*o2 = v2;
	struct client *c = (*o1)->client;
	int res;
	bool is_cap1, is_cap2, is_def1 = false, is_def2 = false;

	is_cap1 = ((*o1)->port.flags & JackPortIsOutput) == JackPortIsOutput &&
		!(*o1)->port.is_monitor;
	is_cap2 = ((*o2)->port.flags & JackPortIsOutput) == JackPortIsOutput &&
		!(*o2)->port.is_monitor;

	if (c->metadata) {
		struct object *ot1, *ot2;

		ot1 = (*o1)->port.node;

		if (is_cap1)
			is_def1 = ot1 != NULL && strcmp(ot1->node.node_name,
					c->metadata->default_audio_source) == 0;
		else if (!is_cap1)
			is_def1 = ot1 != NULL && strcmp(ot1->node.node_name,
					c->metadata->default_audio_sink) == 0;
		ot2 = (*o2)->port.node;

		if (is_cap2)
			is_def2 = ot2 != NULL && strcmp(ot2->node.node_name,
					c->metadata->default_audio_source) == 0;
		else if (!is_cap2)
			is_def2 = ot2 != NULL && strcmp(ot2->node.node_name,
					c->metadata->default_audio_sink) == 0;
	}
	if ((*o1)->port.type_id != (*o2)->port.type_id)
		res = (*o1)->port.type_id - (*o2)->port.type_id;
	else if ((is_cap1 || is_cap2) && is_cap1 != is_cap2)
		res = is_cap2 - is_cap1;
	else if ((is_def1 || is_def2) && is_def1 != is_def2)
		res = is_def2 - is_def1;
	else if ((*o1)->port.priority != (*o2)->port.priority)
		res = (*o2)->port.priority - (*o1)->port.priority;
	else if ((res = strcmp((*o1)->port.alias1, (*o2)->port.alias1) == 0))
		res = (*o1)->id - (*o2)->id;

	pw_log_debug("port type:%d<->%d def:%d<->%d prio:%d<->%d id:%d<->%d res:%d",
			(*o1)->port.type_id, (*o2)->port.type_id,
			is_def1, is_def2,
			(*o1)->port.priority, (*o2)->port.priority,
			(*o1)->id, (*o2)->id, res);
	return res;
}

SPA_EXPORT
const char ** jack_get_ports (jack_client_t *client,
                              const char *port_name_pattern,
                              const char *type_name_pattern,
                              unsigned long flags)
{
	struct client *c = (struct client *) client;
	const char **res;
	struct object *o;
	struct object *tmp[JACK_PORT_MAX];
	const char *str;
	uint32_t i, count, id;
	regex_t port_regex, type_regex;

	spa_return_val_if_fail(c != NULL, NULL);

	if ((str = getenv("PIPEWIRE_NODE")) != NULL)
		id = pw_properties_parse_int(str);
	else
		id = SPA_ID_INVALID;

	if (port_name_pattern && port_name_pattern[0])
		regcomp(&port_regex, port_name_pattern, REG_EXTENDED | REG_NOSUB);
	if (type_name_pattern && type_name_pattern[0])
		regcomp(&type_regex, type_name_pattern, REG_EXTENDED | REG_NOSUB);

	pw_log_debug(NAME" %p: ports id:%d name:%s type:%s flags:%08lx", c, id,
			port_name_pattern, type_name_pattern, flags);

	pthread_mutex_lock(&c->context.lock);
	count = 0;
	spa_list_for_each(o, &c->context.ports, link) {
		pw_log_debug(NAME" %p: check port type:%d flags:%08lx name:%s", c,
				o->port.type_id, o->port.flags, o->port.name);
		if (count == JACK_PORT_MAX)
			break;
		if (o->port.type_id > TYPE_ID_VIDEO)
			continue;
		if (!SPA_FLAG_IS_SET(o->port.flags, flags))
			continue;
		if (id != SPA_ID_INVALID && o->port.node_id != id)
			continue;

		if (port_name_pattern && port_name_pattern[0]) {
			bool match;
			match = regexec(&port_regex, o->port.name, 0, NULL, 0) == 0;
			if (!match && is_port_default(c, o))
				match = regexec(&port_regex, o->port.system, 0, NULL, 0) == 0;
			if (!match)
				continue;
		}
		if (type_name_pattern && type_name_pattern[0]) {
			if (regexec(&type_regex, type_to_string(o->port.type_id),
						0, NULL, 0) == REG_NOMATCH)
				continue;
		}

		pw_log_debug(NAME" %p: port %s prio:%d matches (%d)",
				c, o->port.name, o->port.priority, count);
		tmp[count++] = o;
	}
	pthread_mutex_unlock(&c->context.lock);

	if (count > 0) {
		qsort(tmp, count, sizeof(struct object *), port_compare_func);

		res = malloc(sizeof(char*) * (count + 1));
		for (i = 0; i < count; i++)
			res[i] = tmp[i]->port.name;
		res[count] = NULL;
	} else {
		res = NULL;
	}

	if (port_name_pattern && port_name_pattern[0])
		regfree(&port_regex);
	if (type_name_pattern && type_name_pattern[0])
		regfree(&type_regex);

	return res;
}

SPA_EXPORT
jack_port_t * jack_port_by_name (jack_client_t *client, const char *port_name)
{
	struct client *c = (struct client *) client;
	struct object *res;

	spa_return_val_if_fail(c != NULL, NULL);

	pthread_mutex_lock(&c->context.lock);
	res = find_port(c, port_name);
	pthread_mutex_unlock(&c->context.lock);

	return (jack_port_t *)res;
}

SPA_EXPORT
jack_port_t * jack_port_by_id (jack_client_t *client,
                               jack_port_id_t port_id)
{
	struct client *c = (struct client *) client;
	struct object *res = NULL, *o;

	spa_return_val_if_fail(c != NULL, NULL);

	pthread_mutex_lock(&c->context.lock);

	o = pw_map_lookup(&c->context.globals, port_id);
	pw_log_debug(NAME" %p: port %d -> %p", c, port_id, o);

	if (o == NULL || o->type != INTERFACE_Port)
		goto exit;

	res = o;

      exit:
	pthread_mutex_unlock(&c->context.lock);

	return (jack_port_t *)res;
}

SPA_EXPORT
jack_nframes_t jack_frames_since_cycle_start (const jack_client_t *client)
{
	struct client *c = (struct client *) client;
	struct spa_io_position *pos;
	struct timespec ts;
	uint64_t diff;

	spa_return_val_if_fail(c != NULL, 0);

	if (SPA_UNLIKELY((pos = c->rt.position) == NULL))
		return 0;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	diff = SPA_TIMESPEC_TO_NSEC(&ts) - pos->clock.nsec;
	return (jack_nframes_t) floor(((float)c->sample_rate * diff) / SPA_NSEC_PER_SEC);
}

SPA_EXPORT
jack_nframes_t jack_frame_time (const jack_client_t *client)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return jack_time_to_frames(client, SPA_TIMESPEC_TO_USEC(&ts));
}

SPA_EXPORT
jack_nframes_t jack_last_frame_time (const jack_client_t *client)
{
	struct client *c = (struct client *) client;
	struct spa_io_position *pos;

	spa_return_val_if_fail(c != NULL, 0);

	if (SPA_UNLIKELY((pos = c->rt.position) == NULL))
		return 0;

	return pos->clock.position;
}

SPA_EXPORT
int jack_get_cycle_times(const jack_client_t *client,
                        jack_nframes_t *current_frames,
                        jack_time_t    *current_usecs,
                        jack_time_t    *next_usecs,
                        float          *period_usecs)
{
	struct client *c = (struct client *) client;
	struct spa_io_position *pos;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (SPA_UNLIKELY((pos = c->rt.position) == NULL))
		return -EIO;

	*current_frames = pos->clock.position;
	*current_usecs = pos->clock.nsec / SPA_NSEC_PER_USEC;
	*period_usecs = pos->clock.duration * (float)SPA_USEC_PER_SEC / (c->sample_rate * pos->clock.rate_diff);
	*next_usecs = pos->clock.next_nsec / SPA_NSEC_PER_USEC;

	pw_log_trace(NAME" %p: %d %"PRIu64" %"PRIu64" %f", c, *current_frames,
			*current_usecs, *next_usecs, *period_usecs);
	return 0;
}

SPA_EXPORT
jack_time_t jack_frames_to_time(const jack_client_t *client, jack_nframes_t frames)
{
	struct client *c = (struct client *) client;
	struct spa_io_position *pos;
	double df;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (SPA_UNLIKELY((pos = c->rt.position) == NULL))
		return 0;

	df = (frames - pos->clock.position) * (double)SPA_NSEC_PER_SEC / c->sample_rate;
	return (pos->clock.nsec + (int64_t)rint(df)) / SPA_NSEC_PER_USEC;
}

SPA_EXPORT
jack_nframes_t jack_time_to_frames(const jack_client_t *client, jack_time_t usecs)
{
	struct client *c = (struct client *) client;
	struct spa_io_position *pos;
	double du;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (SPA_UNLIKELY((pos = c->rt.position) == NULL))
		return 0;

	du = (usecs - pos->clock.nsec/SPA_NSEC_PER_USEC) * (double)c->sample_rate / SPA_USEC_PER_SEC;
	return pos->clock.position + (int32_t)rint(du);
}

SPA_EXPORT
jack_time_t jack_get_time()
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return SPA_TIMESPEC_TO_USEC(&ts);
}

SPA_EXPORT
void default_jack_error_callback(const char *desc)
{
	pw_log_error("pw jack error: %s",desc);
}

SPA_EXPORT
void silent_jack_error_callback(const char *desc)
{
}

SPA_EXPORT
void (*jack_error_callback)(const char *msg);

SPA_EXPORT
void jack_set_error_function (void (*func)(const char *))
{
	jack_error_callback = (func == NULL) ? &default_jack_error_callback : func;
}

SPA_EXPORT
void default_jack_info_callback(const char *desc)
{
	pw_log_info("pw jack info: %s", desc);
}

SPA_EXPORT
void silent_jack_info_callback(const char *desc)
{
}

SPA_EXPORT
void (*jack_info_callback)(const char *msg);


SPA_EXPORT
void jack_set_info_function (void (*func)(const char *))
{
	jack_info_callback = (func == NULL) ? &default_jack_info_callback : func;
}

SPA_EXPORT
void jack_free(void* ptr)
{
	free(ptr);
}

SPA_EXPORT
int jack_release_timebase (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if ((a = c->driver_activation) == NULL)
		return -EIO;

	if (!ATOMIC_CAS(a->segment_owner[0], c->node_id, 0))
		return -EINVAL;

	c->timebase_callback = NULL;
	c->timebase_arg = NULL;
	c->activation->pending_new_pos = false;
	c->timeowner_pending = false;

	return 0;
}

SPA_EXPORT
int jack_set_sync_callback (jack_client_t *client,
			    JackSyncCallback sync_callback,
			    void *arg)
{
	int res;
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	c->sync_callback = sync_callback;
	c->sync_arg = arg;

	if ((res = do_activate(c)) < 0)
		return res;

	c->activation->pending_sync = true;
	return 0;
}

SPA_EXPORT
int jack_set_sync_timeout (jack_client_t *client,
			   jack_time_t timeout)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if ((a = c->activation) == NULL)
		return -EIO;

	ATOMIC_STORE(a->sync_timeout, timeout);

	return 0;
}

SPA_EXPORT
int  jack_set_timebase_callback (jack_client_t *client,
				 int conditional,
				 JackTimebaseCallback timebase_callback,
				 void *arg)
{
	int res;
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(timebase_callback != NULL, -EINVAL);

	c->timebase_callback = timebase_callback;
	c->timebase_arg = arg;
	c->timeowner_pending = true;
	c->timeowner_conditional = conditional;
	install_timeowner(c);

	pw_log_debug(NAME" %p: timebase set id:%u", c, c->node_id);

	if ((res = do_activate(c)) < 0)
		return res;

	c->activation->pending_new_pos = true;

	return 0;
}

SPA_EXPORT
int  jack_transport_locate (jack_client_t *client,
			    jack_nframes_t frame)
{
	jack_position_t pos;
	pos.frame = frame;
	pos.valid = (jack_position_bits_t)0;
	return jack_transport_reposition(client, &pos);
}

SPA_EXPORT
jack_transport_state_t jack_transport_query (const jack_client_t *client,
					     jack_position_t *pos)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a;
	jack_transport_state_t jack_state = JackTransportStopped;

	spa_return_val_if_fail(c != NULL, JackTransportStopped);

	if (SPA_LIKELY((a = c->rt.driver_activation) != NULL))
		jack_state = position_to_jack(a, pos);
	else if (pos != NULL)
		memset(pos, 0, sizeof(jack_position_t));

	return jack_state;
}

SPA_EXPORT
jack_nframes_t jack_get_current_transport_frame (const jack_client_t *client)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a;
	struct spa_io_position *pos;
	struct spa_io_segment *seg;
	uint64_t running;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (SPA_UNLIKELY((a = c->rt.driver_activation) == NULL))
		return -EIO;

	pos = &a->position;
	running = pos->clock.position - pos->offset;

	if (pos->state == SPA_IO_POSITION_STATE_RUNNING) {
		struct timespec ts;
		clock_gettime(CLOCK_MONOTONIC, &ts);
		uint64_t nsecs = SPA_TIMESPEC_TO_NSEC(&ts) - pos->clock.nsec;
		running += (uint64_t)floor((((float) c->sample_rate) / SPA_NSEC_PER_SEC) * nsecs);
	}
	seg = &pos->segments[0];

	return (running - seg->start) * seg->rate + seg->position;
}

SPA_EXPORT
int  jack_transport_reposition (jack_client_t *client,
				const jack_position_t *pos)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a, *na;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	a = c->rt.driver_activation;
	na = c->activation;
	if (!a || !na)
		return -EIO;

	if (pos->valid & ~(JackPositionBBT|JackPositionTimecode))
		return -EINVAL;

	pw_log_debug("frame:%u", pos->frame);
	na->reposition.flags = 0;
	na->reposition.start = 0;
	na->reposition.duration = 0;
	na->reposition.position = pos->frame;
	na->reposition.rate = 1.0;
	ATOMIC_STORE(a->reposition_owner, c->node_id);

	return 0;
}

static void update_command(struct client *c, uint32_t command)
{
	struct pw_node_activation *a = c->rt.driver_activation;
	if (!a)
		return;
	ATOMIC_STORE(a->command, command);
}

SPA_EXPORT
void jack_transport_start (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	spa_return_if_fail(c != NULL);
	update_command(c, PW_NODE_ACTIVATION_COMMAND_START);
}

SPA_EXPORT
void jack_transport_stop (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	spa_return_if_fail(c != NULL);
	update_command(c, PW_NODE_ACTIVATION_COMMAND_STOP);
}

SPA_EXPORT
void jack_get_transport_info (jack_client_t *client,
			      jack_transport_info_t *tinfo)
{
	pw_log_error(NAME" %p: deprecated", client);
	if (tinfo)
		memset(tinfo, 0, sizeof(jack_transport_info_t));
}

SPA_EXPORT
void jack_set_transport_info (jack_client_t *client,
			      jack_transport_info_t *tinfo)
{
	pw_log_error(NAME" %p: deprecated", client);
	if (tinfo)
		memset(tinfo, 0, sizeof(jack_transport_info_t));
}

SPA_EXPORT
int jack_set_session_callback (jack_client_t       *client,
                               JackSessionCallback  session_callback,
                               void                *arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	if (c->active) {
		pw_log_error(NAME" %p: can't set callback on active client", c);
		return -EIO;
	}
	pw_log_warn(NAME" %p: not implemented", client);
	return -ENOTSUP;
}

SPA_EXPORT
int jack_session_reply (jack_client_t        *client,
                        jack_session_event_t *event)
{
	pw_log_warn(NAME" %p: not implemented", client);
	return -ENOTSUP;
}


SPA_EXPORT
void jack_session_event_free (jack_session_event_t *event)
{
	if (event) {
		free((void *)event->session_dir);
		free((void *)event->client_uuid);
		free(event->command_line);
		free(event);
	}
}

SPA_EXPORT
char *jack_client_get_uuid (jack_client_t *client)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, NULL);

	return spa_aprintf("%"PRIu64, client_make_uuid(c->node_id));
}

SPA_EXPORT
jack_session_command_t *jack_session_notify (
        jack_client_t*             client,
        const char                *target,
        jack_session_event_type_t  type,
        const char                *path)
{
	struct client *c = (struct client *) client;
	jack_session_command_t *cmds;
	spa_return_val_if_fail(c != NULL, NULL);
	pw_log_warn("not implemented");
	cmds = calloc(1, sizeof(jack_session_command_t));
	return cmds;
}

SPA_EXPORT
void jack_session_commands_free (jack_session_command_t *cmds)
{
	int i;
	if (cmds == NULL)
		return;

	for (i = 0; cmds[i].uuid != NULL; i++) {
		free((char*)cmds[i].client_name);
		free((char*)cmds[i].command);
		free((char*)cmds[i].uuid);
	}
	free(cmds);
}

SPA_EXPORT
int jack_reserve_client_name (jack_client_t *client,
                          const char    *name,
                          const char    *uuid)
{
	struct client *c = (struct client *) client;
	spa_return_val_if_fail(c != NULL, -1);
	pw_log_warn("not implemented");
	return 0;
}

SPA_EXPORT
int jack_client_has_session_callback (jack_client_t *client, const char *client_name)
{
	struct client *c = (struct client *) client;
	spa_return_val_if_fail(c != NULL, -1);
	return 0;
}


SPA_EXPORT
int jack_client_real_time_priority (jack_client_t * client)
{
	return 20;
}

SPA_EXPORT
int jack_client_max_real_time_priority (jack_client_t *client)
{
	return 20;
}

SPA_EXPORT
int jack_acquire_real_time_scheduling (jack_native_thread_t thread, int priority)
{
	pw_log_warn("not implemented %lu %d", thread, priority);
	return -ENOTSUP;
}

/**
 * Create a thread for JACK or one of its clients.  The thread is
 * created executing @a start_routine with @a arg as its sole
 * argument.
 *
 * @param client the JACK client for whom the thread is being created. May be
 * NULL if the client is being created within the JACK server.
 * @param thread place to return POSIX thread ID.
 * @param priority thread priority, if realtime.
 * @param realtime true for the thread to use realtime scheduling.  On
 * some systems that may require special privileges.
 * @param start_routine function the thread calls when it starts.
 * @param arg parameter passed to the @a start_routine.
 *
 * @returns 0, if successful; otherwise some error number.
 */
SPA_EXPORT
int jack_client_create_thread (jack_client_t* client,
                               jack_native_thread_t *thread,
                               int priority,
                               int realtime,	/* boolean */
                               void *(*start_routine)(void*),
                               void *arg)
{
	spa_return_val_if_fail(client != NULL, -EINVAL);

	if (globals.creator == NULL)
		globals.creator = pthread_create;

	pw_log_debug("client %p: create thread", client);
	return globals.creator(thread, NULL, start_routine, arg);
}

SPA_EXPORT
int jack_drop_real_time_scheduling (jack_native_thread_t thread)
{
	pw_log_warn("not implemented %lu", thread);
	return -ENOTSUP;
}

SPA_EXPORT
int jack_client_stop_thread(jack_client_t* client, jack_native_thread_t thread)
{
	void* status;

	if (thread == (jack_native_thread_t)NULL)
		return -EINVAL;

	pw_log_debug("join thread %lu", thread);
        pthread_join(thread, &status);
	pw_log_debug("stopped thread %lu", thread);
	return 0;
}

SPA_EXPORT
int jack_client_kill_thread(jack_client_t* client, jack_native_thread_t thread)
{
	void* status;

	if (thread == (jack_native_thread_t)NULL)
		return -EINVAL;

	pw_log_debug("cancel thread %lu", thread);
        pthread_cancel(thread);
	pw_log_debug("join thread %lu", thread);
        pthread_join(thread, &status);
	pw_log_debug("stopped thread %lu", thread);
	return 0;
}

SPA_EXPORT
void jack_set_thread_creator (jack_thread_creator_t creator)
{
	if (creator == NULL)
		globals.creator = pthread_create;
	else
		globals.creator = creator;
}

static inline uint8_t * midi_event_data (void* port_buffer,
                      const struct midi_event* event)
{
        if (SPA_LIKELY(event->size <= MIDI_INLINE_MAX))
                return (uint8_t *)event->inline_data;
        else
                return SPA_MEMBER(port_buffer, event->byte_offset, uint8_t);
}

SPA_EXPORT
uint32_t jack_midi_get_event_count(void* port_buffer)
{
	struct midi_buffer *mb = port_buffer;
	if (mb == NULL)
		return 0;
	return mb->event_count;
}

SPA_EXPORT
int jack_midi_event_get(jack_midi_event_t *event,
			void        *port_buffer,
			uint32_t    event_index)
{
	struct midi_buffer *mb = port_buffer;
	struct midi_event *ev = SPA_MEMBER(mb, sizeof(*mb), struct midi_event);
	spa_return_val_if_fail(mb != NULL, -EINVAL);
	spa_return_val_if_fail(ev != NULL, -EINVAL);
	if (event_index >= mb->event_count)
		return -ENOBUFS;
	ev += event_index;
	event->time = ev->time;
	event->size = ev->size;
	event->buffer = midi_event_data (port_buffer, ev);
	return 0;
}

SPA_EXPORT
void jack_midi_clear_buffer(void *port_buffer)
{
	struct midi_buffer *mb = port_buffer;
	spa_return_if_fail(mb != NULL);
	mb->event_count = 0;
	mb->write_pos = 0;
	mb->lost_events = 0;
}

SPA_EXPORT
void jack_midi_reset_buffer(void *port_buffer)
{
	jack_midi_clear_buffer(port_buffer);
}

SPA_EXPORT
size_t jack_midi_max_event_size(void* port_buffer)
{
	struct midi_buffer *mb = port_buffer;
	size_t buffer_size;

	spa_return_val_if_fail(mb != NULL, 0);

	buffer_size = mb->buffer_size;

        /* (event_count + 1) below accounts for jack_midi_port_internal_event_t
         * which would be needed to store the next event */
        size_t used_size = sizeof(struct midi_buffer)
                           + mb->write_pos
                           + ((mb->event_count + 1)
                              * sizeof(struct midi_event));

        if (SPA_UNLIKELY(used_size > buffer_size)) {
                return 0;
        } else if (SPA_LIKELY((buffer_size - used_size) < MIDI_INLINE_MAX)) {
                return MIDI_INLINE_MAX;
        } else {
                return buffer_size - used_size;
        }
}

SPA_EXPORT
jack_midi_data_t* jack_midi_event_reserve(void *port_buffer,
                        jack_nframes_t  time,
                        size_t data_size)
{
	struct midi_buffer *mb = port_buffer;
	struct midi_event *events = SPA_MEMBER(mb, sizeof(*mb), struct midi_event);
	size_t buffer_size;

	spa_return_val_if_fail(mb != NULL, NULL);

	buffer_size = mb->buffer_size;

	if (SPA_UNLIKELY(time >= mb->nframes)) {
		pw_log_warn("midi %p: time:%d frames:%d", port_buffer, time, mb->nframes);
		goto failed;
	}

	if (SPA_UNLIKELY(mb->event_count > 0 && time < events[mb->event_count - 1].time)) {
		pw_log_warn("midi %p: time:%d ev:%d", port_buffer, time, mb->event_count);
		goto failed;
	}

	/* Check if data_size is >0 and there is enough space in the buffer for the event. */
	if (SPA_UNLIKELY(data_size <= 0)) {
		pw_log_warn("midi %p: data_size:%zd", port_buffer, data_size);
		goto failed; // return NULL?
	} else if (SPA_UNLIKELY(jack_midi_max_event_size (port_buffer) < data_size)) {
		pw_log_warn("midi %p: event too large: data_size:%zd", port_buffer, data_size);
		goto failed;
	} else {
		struct midi_event *ev = &events[mb->event_count];
		uint8_t *res;

		ev->time = time;
		ev->size = data_size;
		if (SPA_LIKELY(data_size <= MIDI_INLINE_MAX)) {
			res = ev->inline_data;
		} else {
			mb->write_pos += data_size;
			ev->byte_offset = buffer_size - 1 - mb->write_pos;
			res = SPA_MEMBER(mb, ev->byte_offset, uint8_t);
		}
		mb->event_count += 1;
		return res;
	}
failed:
	mb->lost_events++;
	return NULL;
}

SPA_EXPORT
int jack_midi_event_write(void *port_buffer,
                      jack_nframes_t time,
                      const jack_midi_data_t *data,
                      size_t data_size)
{
	jack_midi_data_t *retbuf = jack_midi_event_reserve (port_buffer, time, data_size);
        if (SPA_UNLIKELY(retbuf == NULL))
                return -ENOBUFS;
	memcpy (retbuf, data, data_size);
	return 0;
}

SPA_EXPORT
uint32_t jack_midi_get_lost_event_count(void *port_buffer)
{
	struct midi_buffer *mb = port_buffer;
	spa_return_val_if_fail(mb != NULL, 0);
	return mb->lost_events;
}

/** extensions */

SPA_EXPORT
int jack_get_video_image_size(jack_client_t *client, jack_image_size_t *size)
{
	struct client *c = (struct client *) client;
	struct pw_node_activation *a;

	spa_return_val_if_fail(c != NULL, 0);

	a = c->rt.driver_activation;
	if (SPA_UNLIKELY(a == NULL))
		a = c->activation;
	if (SPA_UNLIKELY(a == NULL))
		return -EIO;

	if (SPA_UNLIKELY(!(a->position.video.flags & SPA_IO_VIDEO_SIZE_VALID)))
		return -EIO;

	size->width = a->position.video.size.width;
	size->height = a->position.video.size.height;
	size->stride = a->position.video.stride;
	size->flags = 0;
	return size->stride * size->height;
}


static void reg(void) __attribute__ ((constructor));
static void reg(void)
{
	pw_init(NULL, NULL);
	pthread_mutex_init(&globals.lock, NULL);
	pw_array_init(&globals.descriptions, 16);
}
