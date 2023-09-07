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

#include "config.h"

#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/ip.h>
#include <sys/un.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <regex.h>
#if HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif
#if HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif
#if HAVE_PWD_H
#include <pwd.h>
#endif

#ifdef HAVE_SYSTEMD
#include <systemd/sd-daemon.h>
#endif

#include <pipewire/log.h>

#define spa_debug pw_log_debug

#include <spa/support/cpu.h>
#include <spa/utils/result.h>
#include <spa/debug/dict.h>
#include <spa/debug/mem.h>
#include <spa/debug/types.h>
#include <spa/param/audio/raw.h>
#include <spa/pod/pod.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/utils/ringbuffer.h>
#include <spa/utils/json.h>

#include "pipewire/pipewire.h"
#include "pipewire/private.h"
#include "extensions/metadata.h"

#include "pulse-server.h"
#include "defs.h"
#include "internal.h"

#define DEFAULT_MIN_REQ		"256/48000"
#define DEFAULT_DEFAULT_REQ	"960/48000"
#define DEFAULT_MIN_FRAG	"256/48000"
#define DEFAULT_DEFAULT_FRAG	"96000/48000"
#define DEFAULT_DEFAULT_TLENGTH	"96000/48000"
#define DEFAULT_MIN_QUANTUM	"256/48000"
#if __BYTE_ORDER == __BIG_ENDIAN
#define DEFAULT_FORMAT		"F32BE"
#else
#define DEFAULT_FORMAT		"F32LE"
#endif
#define DEFAULT_POSITION	"[ FL FR ]"

#define MAX_FORMATS	32

#include "format.c"
#include "volume.c"
#include "message.c"
#include "manager.h"
#include "dbus-name.c"

static bool debug_messages = false;

#include "sample.c"

struct operation {
	struct spa_list link;
	struct client *client;
	uint32_t tag;
};

struct latency_offset_data {
	int64_t prev_latency_offset;
	unsigned int initialized:1;
};

/* Functions that modules can use */
static void broadcast_subscribe_event(struct impl *impl, uint32_t mask, uint32_t event, uint32_t id);

#include "collect.c"
#include "module.c"
#include "message-handler.c"

static void client_free(struct client *client);

static void sample_free(struct sample *sample)
{
	struct impl *impl = sample->impl;

	pw_log_info("free sample id:%u name:%s", sample->index, sample->name);

	impl->stat.sample_cache -= sample->length;

	if (sample->index != SPA_ID_INVALID)
		pw_map_remove(&impl->samples, sample->index);
	if (sample->props)
		pw_properties_free(sample->props);
	free(sample->buffer);
	free(sample);
}

static struct sample *find_sample(struct impl *impl, uint32_t idx, const char *name)
{
	union pw_map_item *item;

	if (idx != SPA_ID_INVALID)
		return pw_map_lookup(&impl->samples, idx);

	pw_array_for_each(item, &impl->samples.items) {
		struct sample *s = item->data;
                if (!pw_map_item_is_free(item) &&
		    strcmp(s->name, name) == 0)
			return s;
	}
	return NULL;
}

struct command {
	const char *name;
	int (*run) (struct client *client, uint32_t command, uint32_t tag, struct message *msg);
};
static const struct command commands[COMMAND_MAX];

static void message_free(struct impl *impl, struct message *msg, bool dequeue, bool destroy)
{
	if (dequeue)
		spa_list_remove(&msg->link);
	if (destroy) {
		pw_log_trace("destroy message %p", msg);
		msg->stat->n_allocated--;
		msg->stat->allocated -= msg->allocated;
		free(msg->data);
		free(msg);
	} else {
		pw_log_trace("recycle message %p", msg);
		spa_list_append(&impl->free_messages, &msg->link);
	}
}

static struct message *message_alloc(struct impl *impl, uint32_t channel, uint32_t size)
{
	struct message *msg;

	if (!spa_list_is_empty(&impl->free_messages)) {
		msg = spa_list_first(&impl->free_messages, struct message, link);
		spa_list_remove(&msg->link);
		pw_log_trace("using recycled message %p", msg);
	} else {
		if ((msg = calloc(1, sizeof(struct message))) == NULL)
			return NULL;
		pw_log_trace("new message %p", msg);
		msg->stat = &impl->stat;
		msg->stat->n_allocated++;
		msg->stat->n_accumulated++;
	}
	if (ensure_size(msg, size) < 0)
		return NULL;
	spa_zero(msg->extra);
	msg->channel = channel;
	msg->offset = 0;
	msg->length = size;
	return msg;
}

static int flush_messages(struct client *client)
{
	struct impl *impl = client->impl;
	int res;

	while (true) {
		struct message *m;
		struct descriptor desc;
		void *data;
		size_t size;

		if (spa_list_is_empty(&client->out_messages))
			break;
		m = spa_list_first(&client->out_messages, struct message, link);

		if (client->out_index < sizeof(desc)) {
			desc.length = htonl(m->length);
			desc.channel = htonl(m->channel);
			desc.offset_hi = 0;
			desc.offset_lo = 0;
			desc.flags = 0;

			data = SPA_MEMBER(&desc, client->out_index, void);
			size = sizeof(desc) - client->out_index;
		} else if (client->out_index < m->length + sizeof(desc)) {
			uint32_t idx = client->out_index - sizeof(desc);
			data = m->data + idx;
			size = m->length - idx;
		} else {
			if (debug_messages && m->channel == SPA_ID_INVALID)
				message_dump(SPA_LOG_LEVEL_INFO, m);
			message_free(impl, m, true, false);
			client->out_index = 0;
			continue;
		}

		while (true) {
			res = send(client->source->fd, data, size, MSG_NOSIGNAL | MSG_DONTWAIT);
			if (res < 0) {
				if (errno == EINTR)
					continue;
				if (errno != EAGAIN && errno != EWOULDBLOCK)
					pw_log_warn("send channel:%d %zu, res %d: %m", m->channel, size, res);
				return -errno;
			}
			client->out_index += res;
			break;
		}
	}
	return 0;
}

static int send_message(struct client *client, struct message *m)
{
	struct impl *impl = client->impl;
	int res, mask;

	if (m == NULL)
		return -EINVAL;

	if (m->length == 0) {
		res = 0;
		goto error;
	} else if (m->length > m->allocated) {
		res = -ENOMEM;
		goto error;
	}

	m->offset = 0;
	spa_list_append(&client->out_messages, &m->link);

	mask = client->source->mask;
	if (!SPA_FLAG_IS_SET(mask, SPA_IO_OUT)) {
		client->need_flush = true;
		SPA_FLAG_SET(mask, SPA_IO_OUT);
		pw_loop_update_io(impl->loop, client->source, mask);
	}
	return 0;
error:
	message_free(impl, m, false, false);
	return res;
}

static struct message *reply_new(struct client *client, uint32_t tag)
{
	struct impl *impl = client->impl;
	struct message *reply;
	reply = message_alloc(impl, -1, 0);
	pw_log_debug(NAME" %p: REPLY tag:%u", client, tag);
	message_put(reply,
		TAG_U32, COMMAND_REPLY,
		TAG_U32, tag,
		TAG_INVALID);
	return reply;
}

static int reply_simple_ack(struct client *client, uint32_t tag)
{
	struct message *reply = reply_new(client, tag);
	return send_message(client, reply);
}

static int reply_error(struct client *client, uint32_t command, uint32_t tag, int res)
{
	struct impl *impl = client->impl;
	struct message *reply;
	uint32_t error = res_to_err(res);
	const char *name;

	if (command < COMMAND_MAX)
		name = commands[command].name;
	else
		name = "invalid";

	pw_log(res == -ENOENT ? SPA_LOG_LEVEL_INFO : SPA_LOG_LEVEL_WARN,
			NAME" %p: [%s] ERROR command:%d (%s) tag:%u error:%u (%s)",
			client, client->name, command, name, tag, error, spa_strerror(res));

	reply = message_alloc(impl, -1, 0);
	message_put(reply,
		TAG_U32, COMMAND_ERROR,
		TAG_U32, tag,
		TAG_U32, error,
		TAG_INVALID);
	return send_message(client, reply);
}

static int operation_new(struct client *client, uint32_t tag)
{
	struct operation *o;

	if ((o = calloc(1, sizeof(*o))) == NULL)
		return -errno;

	o->client = client;
	o->tag = tag;
	spa_list_append(&client->operations, &o->link);
	pw_manager_sync(client->manager);
	pw_log_debug(NAME" %p: operation tag:%u", client, tag);
	return 0;
}

static void operation_free(struct operation *o)
{
	spa_list_remove(&o->link);
	free(o);
}

static void operation_complete(struct operation *o)
{
	struct client *client = o->client;

	pw_log_info(NAME" %p: [%s] tag:%u complete", client, client->name, o->tag);
	reply_simple_ack(o->client, o->tag);
	operation_free(o);
}

#include "extension.c"

static int send_underflow(struct stream *stream, int64_t offset, uint32_t underrun_for)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	struct message *reply;

	if (ratelimit_test(&impl->rate_limit, stream->timestamp)) {
		pw_log_warn(NAME" %p: [%s] UNDERFLOW channel:%u offset:%"PRIi64" underrun:%u",
				client, client->name, stream->channel, offset, underrun_for);
	}

	reply = message_alloc(impl, -1, 0);
	message_put(reply,
		TAG_U32, COMMAND_UNDERFLOW,
		TAG_U32, -1,
		TAG_U32, stream->channel,
		TAG_INVALID);
	if (client->version >= 23) {
		message_put(reply,
			TAG_S64, offset,
			TAG_INVALID);
	}
	return send_message(client, reply);
}

static int send_subscribe_event(struct client *client, uint32_t mask, uint32_t event, uint32_t id)
{
	struct impl *impl = client->impl;
	struct message *reply, *m, *t;

	if (!(client->subscribed & mask))
		return 0;

	pw_log_debug(NAME" %p: SUBSCRIBE event:%08x id:%u", client, event, id);

	if ((event & SUBSCRIPTION_EVENT_TYPE_MASK) != SUBSCRIPTION_EVENT_NEW) {
		spa_list_for_each_safe_reverse(m, t, &client->out_messages, link) {
			if (m->extra[0] != COMMAND_SUBSCRIBE_EVENT)
				continue;
			if ((m->extra[1] ^ event) & SUBSCRIPTION_EVENT_FACILITY_MASK)
				continue;
			if (m->extra[2] != id)
				continue;

			if ((event & SUBSCRIPTION_EVENT_TYPE_MASK) == SUBSCRIPTION_EVENT_REMOVE) {
		                /* This object is being removed, hence there is no
		                 * point in keeping the old events regarding this
		                 * entry in the queue. */
				message_free(impl, m, true, false);
				pw_log_debug("Dropped redundant event due to remove event.");
				continue;
			}
			if ((event & SUBSCRIPTION_EVENT_TYPE_MASK) == SUBSCRIPTION_EVENT_CHANGE) {
				/* This object has changed. If a "new" or "change" event for
				 * this object is still in the queue we can exit. */
				pw_log_debug("Dropped redundant event due to change event.");
				return 0;
			}
		}
	}

	reply = message_alloc(impl, -1, 0);
	reply->extra[0] = COMMAND_SUBSCRIBE_EVENT,
	reply->extra[1] = event,
	reply->extra[2] = id,
	message_put(reply,
		TAG_U32, COMMAND_SUBSCRIBE_EVENT,
		TAG_U32, -1,
		TAG_U32, event,
		TAG_U32, id,
		TAG_INVALID);
	return send_message(client, reply);
}

static void broadcast_subscribe_event(struct impl *impl, uint32_t mask, uint32_t event, uint32_t id)
{
	struct server *s;
	spa_list_for_each(s, &impl->servers, link) {
		struct client *c;
		spa_list_for_each(c, &s->clients, link)
			send_subscribe_event(c, mask, event, id);
	}
}

static int send_overflow(struct stream *stream)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	struct message *reply;

	pw_log_warn(NAME" %p: [%s] OVERFLOW channel:%u", client,
			client->name, stream->channel);

	reply = message_alloc(impl, -1, 0);
	message_put(reply,
		TAG_U32, COMMAND_OVERFLOW,
		TAG_U32, -1,
		TAG_U32, stream->channel,
		TAG_INVALID);
	return send_message(client, reply);
}

static int send_stream_killed(struct stream *stream)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	struct message *reply;
	uint32_t command;

	command = stream->direction == PW_DIRECTION_OUTPUT ?
		COMMAND_PLAYBACK_STREAM_KILLED :
		COMMAND_RECORD_STREAM_KILLED;

	pw_log_info(NAME" %p: [%s] %s channel:%u", client, client->name,
			commands[command].name, stream->channel);

	if (client->version < 23)
		return 0;

	reply = message_alloc(impl, -1, 0);
	message_put(reply,
		TAG_U32, command,
		TAG_U32, -1,
		TAG_U32, stream->channel,
		TAG_INVALID);
	return send_message(client, reply);
}

static int send_stream_started(struct stream *stream)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	struct message *reply;

	pw_log_debug(NAME" %p: STARTED channel:%u", client, stream->channel);

	reply = message_alloc(impl, -1, 0);
	message_put(reply,
		TAG_U32, COMMAND_STARTED,
		TAG_U32, -1,
		TAG_U32, stream->channel,
		TAG_INVALID);
	return send_message(client, reply);
}

static int do_command_auth(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;
	uint32_t version;
	const void *cookie;
	size_t len;

	if (message_get(m,
			TAG_U32, &version,
			TAG_ARBITRARY, &cookie, &len,
			TAG_INVALID) < 0) {
		return -EPROTO;
	}
	if (version < 8)
		return -EPROTO;
	if (len != NATIVE_COOKIE_LENGTH)
		return -EINVAL;

	if ((version & PROTOCOL_VERSION_MASK) >= 13)
		version &= PROTOCOL_VERSION_MASK;

	client->version = version;

	pw_log_info(NAME" %p: client:%p AUTH tag:%u version:%d", impl, client, tag, version);

	reply = reply_new(client, tag);
	message_put(reply,
			TAG_U32, PROTOCOL_VERSION,
			TAG_INVALID);

	return send_message(client, reply);
}

static int reply_set_client_name(struct client *client, uint32_t tag)
{
	struct message *reply;
	struct pw_client *c;
	uint32_t id;

	c = pw_core_get_client(client->core);
	if (c == NULL)
		return -ENOENT;

	id = pw_proxy_get_bound_id((struct pw_proxy*)c);

	pw_log_info(NAME" %p: [%s] reply tag:%u id:%u", client, client->name, tag, id);

	reply = reply_new(client, tag);

	if (client->version >= 13) {
		message_put(reply,
			TAG_U32, id,		/* client index */
			TAG_INVALID);
	}
	return send_message(client, reply);
}

static void manager_sync(void *data)
{
	struct client *client = data;
	struct operation *o;

	pw_log_debug(NAME" %p: manager sync", client);

	if (client->connect_tag != SPA_ID_INVALID) {
		reply_set_client_name(client, client->connect_tag);
		client->connect_tag = SPA_ID_INVALID;
	}
	spa_list_consume(o, &client->operations, link)
		operation_complete(o);
}

static struct stream *find_stream(struct client *client, uint32_t id)
{
	union pw_map_item *item;
	pw_array_for_each(item, &client->streams.items) {
		struct stream *s = item->data;
                if (!pw_map_item_is_free(item) &&
		    s->id == id)
			return s;
	}
	return NULL;
}

static int send_object_event(struct client *client, struct pw_manager_object *o,
		uint32_t facility)
{
	uint32_t event = 0, mask = 0, res_id = o->id;

	if (pw_manager_object_is_sink(o)) {
		send_subscribe_event(client,
				SUBSCRIPTION_MASK_SINK,
				SUBSCRIPTION_EVENT_SINK | facility,
				res_id);
	}
	if (pw_manager_object_is_source_or_monitor(o)) {
		if (!pw_manager_object_is_source(o))
			res_id |= MONITOR_FLAG;
		mask = SUBSCRIPTION_MASK_SOURCE;
		event = SUBSCRIPTION_EVENT_SOURCE;
	}
	else if (pw_manager_object_is_sink_input(o)) {
		mask = SUBSCRIPTION_MASK_SINK_INPUT;
		event = SUBSCRIPTION_EVENT_SINK_INPUT;
	}
	else if (pw_manager_object_is_source_output(o)) {
		mask = SUBSCRIPTION_MASK_SOURCE_OUTPUT;
		event = SUBSCRIPTION_EVENT_SOURCE_OUTPUT;
	}
	else if (pw_manager_object_is_module(o)) {
		mask = SUBSCRIPTION_MASK_MODULE;
		event = SUBSCRIPTION_EVENT_MODULE;
	}
	else if (pw_manager_object_is_client(o)) {
		mask = SUBSCRIPTION_MASK_CLIENT;
		event = SUBSCRIPTION_EVENT_CLIENT;
	}
	else if (pw_manager_object_is_card(o)) {
		mask = SUBSCRIPTION_MASK_CARD;
		event = SUBSCRIPTION_EVENT_CARD;
	} else
		event = SPA_ID_INVALID;

	if (event != SPA_ID_INVALID)
		send_subscribe_event(client,
				mask,
				event | facility,
				res_id);
	return 0;
}

static struct pw_manager_object *find_device(struct client *client,
		uint32_t id, const char *name, bool sink, bool *is_monitor);

static int64_t get_node_latency_offset(struct pw_manager_object *o)
{
	int64_t latency_offset = 0LL;
	struct pw_manager_param *p;

	spa_list_for_each(p, &o->param_list, link) {
		if (p->id != SPA_PARAM_Props)
			continue;
		if (spa_pod_parse_object(p->param,
		                         SPA_TYPE_OBJECT_Props, NULL,
		                         SPA_PROP_latencyOffsetNsec, SPA_POD_Long(&latency_offset)) == 1)
			break;
	}
	return latency_offset;
}

static void send_latency_offset_subscribe_event(struct client *client, struct pw_manager_object *o)
{
	struct latency_offset_data *d;
	struct pw_node_info *info;
	const char *str;
	uint32_t card_id = SPA_ID_INVALID;
	int64_t latency_offset = 0LL;
	bool changed = false;

	if (!pw_manager_object_is_sink(o) && !pw_manager_object_is_source_or_monitor(o))
		return;

	/*
	 * Pulseaudio sends card change events on latency offset change.
	 */
	if ((info = o->info) == NULL || info->props == NULL)
		return;
	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if (card_id == SPA_ID_INVALID)
		return;

	d = pw_manager_object_add_data(o, "latency_offset_data", sizeof(struct latency_offset_data));
	if (d == NULL)
		return;

	latency_offset = get_node_latency_offset(o);
	changed = (!d->initialized || latency_offset != d->prev_latency_offset);

	d->prev_latency_offset = latency_offset;
	d->initialized = true;

	if (changed)
		send_subscribe_event(client,
				SUBSCRIPTION_MASK_CARD,
				SUBSCRIPTION_EVENT_CARD | SUBSCRIPTION_EVENT_CHANGE,
				card_id);
}

static void send_default_change_subscribe_event(struct client *client, bool sink, bool source)
{
	struct pw_manager_object *def;
	bool changed = false;

	if (sink) {
		def = find_device(client, SPA_ID_INVALID, NULL, true, NULL);
		if (client->prev_default_sink != def) {
			client->prev_default_sink = def;
			changed = true;
		}
	}

	if (source) {
		def = find_device(client, SPA_ID_INVALID, NULL, false, NULL);
		if (client->prev_default_source != def) {
			client->prev_default_source = def;
			changed = true;
		}
	}

	if (changed)
		send_subscribe_event(client,
				SUBSCRIPTION_MASK_SERVER,
				SUBSCRIPTION_EVENT_CHANGE |
				SUBSCRIPTION_EVENT_SERVER,
				-1);
}

static void handle_metadata(struct client *client, struct pw_manager_object *old,
		struct pw_manager_object *new, const char *name)
{
	if (strcmp(name, "default") == 0) {
		if (client->metadata_default == old)
			client->metadata_default = new;
	}
	else if (strcmp(name, "route-settings") == 0) {
		if (client->metadata_routes == old)
			client->metadata_routes = new;
	}
}

static void manager_added(void *data, struct pw_manager_object *o)
{
	struct client *client = data;
	const char *str;

	register_object_message_handlers(o);

	if (strcmp(o->type, PW_TYPE_INTERFACE_Metadata) == 0) {
		if (o->props != NULL &&
		    (str = pw_properties_get(o->props, PW_KEY_METADATA_NAME)) != NULL)
			handle_metadata(client, NULL, o, str);
	}

	send_object_event(client, o, SUBSCRIPTION_EVENT_NEW);

	/* Adding sinks etc. may also change defaults */
	send_default_change_subscribe_event(client, pw_manager_object_is_sink(o), pw_manager_object_is_source_or_monitor(o));
}

static void manager_updated(void *data, struct pw_manager_object *o)
{
	struct client *client = data;

	send_object_event(client, o, SUBSCRIPTION_EVENT_CHANGE);

	send_latency_offset_subscribe_event(client, o);
	send_default_change_subscribe_event(client, pw_manager_object_is_sink(o), pw_manager_object_is_source_or_monitor(o));
}

static void manager_removed(void *data, struct pw_manager_object *o)
{
	struct client *client = data;
	const char *str;

	send_object_event(client, o, SUBSCRIPTION_EVENT_REMOVE);

	send_default_change_subscribe_event(client, pw_manager_object_is_sink(o), pw_manager_object_is_source_or_monitor(o));

	if (strcmp(o->type, PW_TYPE_INTERFACE_Metadata) == 0) {
		if (o->props != NULL &&
		    (str = pw_properties_get(o->props, PW_KEY_METADATA_NAME)) != NULL)
			handle_metadata(client, o, NULL, str);
	}
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

static inline int strzcmp(const char *s1, const char *s2)
{
	if (s1 == s2)
		return 0;
	if (s1 == NULL || s2 == NULL)
		return 1;
	return strcmp(s1, s2);
}

static void manager_metadata(void *data, struct pw_manager_object *o,
		uint32_t subject, const char *key, const char *type, const char *value)
{
	struct client *client = data;
	bool changed = false;

	pw_log_debug("meta id:%d subject:%d key:%s type:%s value:%s",
			o->id, subject, key, type, value);

	if (subject == PW_ID_CORE && o == client->metadata_default) {
		char name[1024];

		if (key == NULL || strcmp(key, "default.audio.sink") == 0) {
			if (value != NULL) {
				if (json_object_find(value,
						"name", name, sizeof(name)) < 0)
					value = NULL;
				else
					value = name;
			}
			if ((changed = strzcmp(client->default_sink, value))) {
				free(client->default_sink);
				client->default_sink = value ? strdup(value) : NULL;
			}
		}
		if (key == NULL || strcmp(key, "default.audio.source") == 0) {
			if (value != NULL) {
				if (json_object_find(value,
						"name", name, sizeof(name)) < 0)
					value = NULL;
				else
					value = name;
			}
			if ((changed = strzcmp(client->default_source, value))) {
				free(client->default_source);
				client->default_source = value ? strdup(value) : NULL;
			}
		}
		if (changed)
			send_default_change_subscribe_event(client, true, true);
	}
	if (subject == PW_ID_CORE && o == client->metadata_routes) {
		if (key == NULL)
			pw_properties_clear(client->routes);
		else
			pw_properties_set(client->routes, key, value);
	}
}

static const struct pw_manager_events manager_events = {
	PW_VERSION_MANAGER_EVENTS,
	.sync = manager_sync,
	.added = manager_added,
	.updated = manager_updated,
	.removed = manager_removed,
	.metadata = manager_metadata,
};

static int do_set_client_name(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	const char *name = NULL;
	int res = 0, changed = 0;

	if (client->version < 13) {
		if (message_get(m,
				TAG_STRING, &name,
				TAG_INVALID) < 0)
			return -EPROTO;
		if (name)
			changed += pw_properties_set(client->props,
					PW_KEY_APP_NAME, name);
	} else {
		if (message_get(m,
				TAG_PROPLIST, client->props,
				TAG_INVALID) < 0)
			return -EPROTO;
		changed++;
	}

	client->name = pw_properties_get(client->props, PW_KEY_APP_NAME);
	pw_log_info(NAME" %p: [%s] %s tag:%d", impl, client->name,
			commands[command].name, tag);

	if (client->core == NULL) {
		client->core = pw_context_connect(impl->context,
				pw_properties_copy(client->props), 0);
		if (client->core == NULL) {
			res = -errno;
			goto error;
		}
		client->manager = pw_manager_new(client->core);
		if (client->manager == NULL) {
			res = -errno;
			goto error;
		}
		client->connect_tag = tag;
		pw_manager_add_listener(client->manager, &client->manager_listener,
				&manager_events, client);
	} else {
		if (changed)
			pw_core_update_properties(client->core, &client->props->dict);

		if (client->connect_tag == SPA_ID_INVALID)
			res = reply_set_client_name(client, tag);
	}
	return res;
error:
	pw_log_error(NAME" %p: failed to connect client: %s", impl, spa_strerror(res));
	return res;

}

static int do_subscribe(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t mask;

	if (message_get(m,
			TAG_U32, &mask,
			TAG_INVALID) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] SUBSCRIBE tag:%u mask:%08x", impl,
			client->name, tag, mask);

	client->subscribed = mask;

	return reply_simple_ack(client, tag);
}

static void stream_free(struct stream *stream)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;

	pw_log_debug(NAME" %p: stream %p channel:%d", impl, stream, stream->channel);

	if (stream->drain_tag)
		reply_error(client, -1, stream->drain_tag, -ENOENT);

	if (stream->killed)
		send_stream_killed(stream);

	/* force processing of all pending messages before we destroy
	 * the stream */
	pw_loop_invoke(impl->loop, NULL, 0, NULL, 0, false, client);

	if (stream->channel != SPA_ID_INVALID)
		pw_map_remove(&client->streams, stream->channel);
	if (stream->stream) {
		spa_hook_remove(&stream->stream_listener);
		pw_stream_destroy(stream->stream);
	}
	pw_work_queue_cancel(impl->work_queue, stream, SPA_ID_INVALID);

	if (stream->buffer)
		free(stream->buffer);
	if (stream->props)
		pw_properties_free(stream->props);
	free(stream);
}

static bool stream_prebuf_active(struct stream *stream)
{
	uint32_t index;
	int32_t avail;

	avail = spa_ringbuffer_get_write_index(&stream->ring, &index);
	if (stream->in_prebuf)
		return avail < (int32_t) stream->attr.prebuf;
	else
		return stream->attr.prebuf > 0 && avail >= 0;
}

static uint32_t stream_pop_missing(struct stream *stream)
{
	uint32_t missing;

	if (stream->missing <= 0)
		return 0;

	if (stream->missing < stream->attr.minreq &&
	    !stream_prebuf_active(stream))
		return 0;

	missing = stream->missing;
	stream->requested += missing;
	stream->missing = 0;
	return missing;
}

static int send_command_request(struct stream *stream)
{
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	struct message *msg;
	uint32_t size;

	size = stream_pop_missing(stream);
	pw_log_debug(NAME" %p: REQUEST channel:%d %u", stream, stream->channel, size);

	if (size == 0)
		return 0;

	msg = message_alloc(impl, -1, 0);
	message_put(msg,
		TAG_U32, COMMAND_REQUEST,
		TAG_U32, -1,
		TAG_U32, stream->channel,
		TAG_U32, size,
		TAG_INVALID);

	return send_message(client, msg);
}

static uint32_t frac_to_bytes_round_up(struct spa_fraction val, const struct sample_spec *ss)
{
	uint64_t u;
	u = (uint64_t) (val.num * 1000000UL * (uint64_t) ss->rate) / val.denom;
	u = (u + 1000000UL - 1) / 1000000UL;
	u *= sample_spec_frame_size(ss);
	return (uint32_t) u;
}

static void fix_playback_buffer_attr(struct stream *s, struct buffer_attr *attr)
{
	uint32_t frame_size, max_prebuf, minreq;
	struct defs *defs = &s->impl->defs;

	frame_size = s->frame_size;
	minreq = frac_to_bytes_round_up(defs->min_req, &s->ss);

	if (attr->maxlength == (uint32_t) -1 || attr->maxlength > MAXLENGTH)
		attr->maxlength = MAXLENGTH;
	attr->maxlength -= attr->maxlength % frame_size;
	attr->maxlength = SPA_MAX(attr->maxlength, frame_size);

	if (attr->tlength == (uint32_t) -1)
		attr->tlength = frac_to_bytes_round_up(defs->default_tlength, &s->ss);
	if (attr->tlength > attr->maxlength)
		attr->tlength = attr->maxlength;
	attr->tlength -= attr->tlength % frame_size;
	attr->tlength = SPA_MAX(attr->tlength, frame_size);
	attr->tlength = SPA_MAX(attr->tlength, minreq);

	if (attr->minreq == (uint32_t) -1) {
		uint32_t process = frac_to_bytes_round_up(defs->default_req, &s->ss);
		/* With low-latency, tlength/4 gives a decent default in all of traditional,
		 * adjust latency and early request modes. */
		uint32_t m = attr->tlength / 4;
		m -= m % frame_size;
		attr->minreq = SPA_MIN(process, m);
	}
	attr->minreq = SPA_MAX(attr->minreq, minreq);

	if (attr->tlength < attr->minreq+frame_size)
		attr->tlength = attr->minreq + frame_size;

	attr->minreq -= attr->minreq % frame_size;
	if (attr->minreq <= 0) {
		attr->minreq = frame_size;
		attr->tlength += frame_size*2;
	}
	if (attr->tlength <= attr->minreq)
		attr->tlength = attr->minreq*2 + frame_size;

	max_prebuf = attr->tlength + frame_size - attr->minreq;
	if (attr->prebuf == (uint32_t) -1 || attr->prebuf > max_prebuf)
		attr->prebuf = max_prebuf;
	attr->prebuf -= attr->prebuf % frame_size;

	s->missing = attr->tlength;
	attr->fragsize = 0;

	pw_log_info(NAME" %p: [%s] maxlength:%u tlength:%u minreq:%u prebuf:%u", s,
			s->client->name, attr->maxlength, attr->tlength,
			attr->minreq, attr->prebuf);
}

static int reply_create_playback_stream(struct stream *stream)
{
	struct client *client = stream->client;
	struct pw_manager *manager = client->manager;
	struct message *reply;
	uint32_t missing, peer_id;
	struct spa_dict_item items[5];
	char latency[32];
	char attr_maxlength[32];
	char attr_tlength[32];
	char attr_prebuf[32];
	char attr_minreq[32];
	struct pw_manager_object *peer;
	const char *peer_name;
	struct spa_fraction lat;
	uint64_t lat_usec;
	struct defs *defs = &stream->impl->defs;

	fix_playback_buffer_attr(stream, &stream->attr);

	stream->buffer = calloc(1, stream->attr.maxlength);
	if (stream->buffer == NULL)
		return -errno;

	spa_ringbuffer_init(&stream->ring);

	if (stream->early_requests) {
		lat.num = stream->attr.minreq;
	} else if (stream->adjust_latency) {
		if (stream->attr.tlength > stream->attr.minreq * 2)
			lat.num = (stream->attr.tlength - stream->attr.minreq * 2) / 2;
		else
			lat.num = stream->attr.minreq;
	} else {
		if (stream->attr.tlength > stream->attr.minreq * 2)
			lat.num = stream->attr.tlength - stream->attr.minreq * 2;
		else
			lat.num = stream->attr.minreq;
	}
	lat.denom = stream->ss.rate;
	lat.num /= stream->frame_size;
	if (lat.num * defs->min_quantum.denom / lat.denom < defs->min_quantum.num)
		lat.num = (defs->min_quantum.num * lat.denom +
				(defs->min_quantum.denom -1)) / defs->min_quantum.denom;
	lat_usec = lat.num * SPA_USEC_PER_SEC / lat.denom;

	snprintf(latency, sizeof(latency), "%u/%u", lat.num, lat.denom);
	snprintf(attr_maxlength, sizeof(attr_maxlength), "%u", stream->attr.maxlength);
	snprintf(attr_tlength, sizeof(attr_tlength), "%u", stream->attr.tlength);
	snprintf(attr_prebuf, sizeof(attr_prebuf), "%u", stream->attr.prebuf);
	snprintf(attr_minreq, sizeof(attr_minreq), "%u", stream->attr.minreq);

	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_NODE_LATENCY, latency);
	items[1] = SPA_DICT_ITEM_INIT("pulse.attr.maxlength", attr_maxlength);
	items[2] = SPA_DICT_ITEM_INIT("pulse.attr.tlength", attr_tlength);
	items[3] = SPA_DICT_ITEM_INIT("pulse.attr.prebuf", attr_prebuf);
	items[4] = SPA_DICT_ITEM_INIT("pulse.attr.minreq", attr_minreq);
	pw_stream_update_properties(stream->stream, &SPA_DICT_INIT(items, 5));

	missing = stream_pop_missing(stream);

	pw_log_info(NAME" %p: [%s] reply CREATE_PLAYBACK_STREAM tag:%u missing:%u latency:%s",
			stream, client->name, stream->create_tag, missing, latency);

	reply = reply_new(client, stream->create_tag);
	message_put(reply,
		TAG_U32, stream->channel,		/* stream index/channel */
		TAG_U32, stream->id,			/* sink_input/stream index */
		TAG_U32, missing,			/* missing/requested bytes */
		TAG_INVALID);

	peer = find_linked(manager, stream->id, stream->direction);
	if (peer && pw_manager_object_is_sink(peer)) {
		peer_id = peer->id;
		peer_name = pw_properties_get(peer->props, PW_KEY_NODE_NAME);
	} else {
		peer_id = SPA_ID_INVALID;
		peer_name = NULL;
	}

	if (client->version >= 9) {
		message_put(reply,
			TAG_U32, stream->attr.maxlength,
			TAG_U32, stream->attr.tlength,
			TAG_U32, stream->attr.prebuf,
			TAG_U32, stream->attr.minreq,
			TAG_INVALID);
	}
	if (client->version >= 12) {
		message_put(reply,
			TAG_SAMPLE_SPEC, &stream->ss,
			TAG_CHANNEL_MAP, &stream->map,
			TAG_U32, peer_id,		/* sink index */
			TAG_STRING, peer_name,		/* sink name */
			TAG_BOOLEAN, false,		/* sink suspended state */
			TAG_INVALID);
	}
	if (client->version >= 13) {
		message_put(reply,
			TAG_USEC, lat_usec,		/* sink configured latency */
			TAG_INVALID);
	}
	if (client->version >= 21) {
		struct format_info info;
		spa_zero(info);
		info.encoding = ENCODING_PCM;
		message_put(reply,
			TAG_FORMAT_INFO, &info,		/* sink_input format */
			TAG_INVALID);
	}

	stream->create_tag = SPA_ID_INVALID;

	return send_message(client, reply);
}

static void fix_record_buffer_attr(struct stream *s, struct buffer_attr *attr)
{
	uint32_t frame_size, minfrag;
	struct defs *defs = &s->impl->defs;

	frame_size = s->frame_size;

	if (attr->maxlength == (uint32_t) -1 || attr->maxlength > MAXLENGTH)
		attr->maxlength = MAXLENGTH;
	attr->maxlength -= attr->maxlength % frame_size;
	attr->maxlength = SPA_MAX(attr->maxlength, frame_size);

	minfrag = frac_to_bytes_round_up(defs->min_frag, &s->ss);

	if (attr->fragsize == (uint32_t) -1 || attr->fragsize == 0)
		attr->fragsize = frac_to_bytes_round_up(defs->default_frag, &s->ss);
	attr->fragsize -= attr->fragsize % frame_size;
	attr->fragsize = SPA_MAX(attr->fragsize, minfrag);
	attr->fragsize = SPA_MAX(attr->fragsize, frame_size);

	if (attr->fragsize > attr->maxlength)
		attr->fragsize = attr->maxlength;

	attr->tlength = attr->minreq = attr->prebuf = 0;

	pw_log_info(NAME" %p: [%s] maxlength:%u fragsize:%u minfrag:%u", s,
			s->client->name, attr->maxlength, attr->fragsize, minfrag);
}

static int reply_create_record_stream(struct stream *stream)
{
	struct client *client = stream->client;
	struct pw_manager *manager = client->manager;
	struct message *reply;
	struct spa_dict_item items[3];
	char latency[32], *tmp;
	char attr_maxlength[32];
	char attr_fragsize[32];
	struct pw_manager_object *peer;
	const char *peer_name, *name;
	uint32_t peer_id;
	struct spa_fraction lat;
	uint64_t lat_usec;
	struct defs *defs = &stream->impl->defs;

	fix_record_buffer_attr(stream, &stream->attr);

	stream->buffer = calloc(1, stream->attr.maxlength);
	if (stream->buffer == NULL)
		return -errno;

	spa_ringbuffer_init(&stream->ring);

	if (stream->early_requests) {
		lat.num = stream->attr.fragsize;
	} else if (stream->adjust_latency) {
		lat.num = stream->attr.fragsize;
	} else {
		lat.num = stream->attr.fragsize;
	}

	lat.num /= stream->frame_size;
	lat.denom = stream->ss.rate;
	if (lat.num * defs->min_quantum.denom / lat.denom < defs->min_quantum.num)
		lat.num = (defs->min_quantum.num * lat.denom +
				(defs->min_quantum.denom -1)) / defs->min_quantum.denom;
	lat_usec = lat.num * SPA_USEC_PER_SEC / lat.denom;

	snprintf(latency, sizeof(latency), "%u/%u", lat.num, lat.denom);

	snprintf(attr_maxlength, sizeof(attr_maxlength), "%u", stream->attr.maxlength);
	snprintf(attr_fragsize, sizeof(attr_fragsize), "%u", stream->attr.fragsize);

	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_NODE_LATENCY, latency);
	items[1] = SPA_DICT_ITEM_INIT("pulse.attr.maxlength", attr_maxlength);
	items[2] = SPA_DICT_ITEM_INIT("pulse.attr.fragsize", attr_fragsize);
	pw_stream_update_properties(stream->stream,
			&SPA_DICT_INIT(items, 3));

	pw_log_info(NAME" %p: [%s] reply CREATE_RECORD_STREAM tag:%u latency:%s",
			stream, client->name, stream->create_tag, latency);

	reply = reply_new(client, stream->create_tag);
	message_put(reply,
		TAG_U32, stream->channel,	/* stream index/channel */
		TAG_U32, stream->id,		/* source_output/stream index */
		TAG_INVALID);

	peer = find_linked(manager, stream->id, stream->direction);
	if (peer && pw_manager_object_is_sink_input(peer))
		peer = find_linked(manager, peer->id, PW_DIRECTION_OUTPUT);
	if (peer && pw_manager_object_is_source_or_monitor(peer)) {
		name = pw_properties_get(peer->props, PW_KEY_NODE_NAME);
		if (!pw_manager_object_is_source(peer)) {
			size_t len = (name ? strlen(name) : 5) + 10;
			peer_id = peer->id | MONITOR_FLAG;
			peer_name = tmp = alloca(len);
			snprintf(tmp, len, "%s.monitor", name ? name : "sink");
		} else {
			peer_id = peer->id;
			peer_name = name;
		}
	} else {
		peer_id = SPA_ID_INVALID;
		peer_name = NULL;
	}

	if (client->version >= 9) {
		message_put(reply,
			TAG_U32, stream->attr.maxlength,
			TAG_U32, stream->attr.fragsize,
			TAG_INVALID);
	}
	if (client->version >= 12) {
		message_put(reply,
			TAG_SAMPLE_SPEC, &stream->ss,
			TAG_CHANNEL_MAP, &stream->map,
			TAG_U32, peer_id,		/* source index */
			TAG_STRING, peer_name,		/* source name */
			TAG_BOOLEAN, false,		/* source suspended state */
			TAG_INVALID);
	}
	if (client->version >= 13) {
		message_put(reply,
			TAG_USEC, lat_usec,		/* source configured latency */
			TAG_INVALID);
	}
	if (client->version >= 22) {
		struct format_info info;
		spa_zero(info);
		info.encoding = ENCODING_PCM;
		message_put(reply,
			TAG_FORMAT_INFO, &info,		/* source_output format */
			TAG_INVALID);
	}

	stream->create_tag = SPA_ID_INVALID;

	return send_message(client, reply);
}

static void stream_control_info(void *data, uint32_t id,
		const struct pw_stream_control *control)
{
	struct stream *stream = data;

	switch (id) {
	case SPA_PROP_channelVolumes:
		stream->volume.channels = control->n_values;
		memcpy(stream->volume.values, control->values, control->n_values * sizeof(float));
		pw_log_info("stream %p: volume changed %f", stream, stream->volume.values[0]);
		break;
	case SPA_PROP_mute:
		stream->muted = control->values[0] >= 0.5;
		pw_log_info("stream %p: mute changed %d", stream, stream->muted);
		break;
	}
}

static void on_stream_cleanup(void *obj, void *data, int res, uint32_t id)
{
	struct stream *stream = obj;
	struct client *client = stream->client;
	stream_free(stream);
	if (client->ref <= 0)
		client_free(client);
}

static void stream_state_changed(void *data, enum pw_stream_state old,
		enum pw_stream_state state, const char *error)
{
	struct stream *stream = data;
	struct client *client = stream->client;
	struct impl *impl = client->impl;

	switch (state) {
	case PW_STREAM_STATE_ERROR:
		reply_error(client, -1, stream->create_tag, -EIO);
		stream->done = true;
		break;
	case PW_STREAM_STATE_UNCONNECTED:
		if (!client->disconnecting)
			stream->killed = true;
		stream->done = true;
		break;
	case PW_STREAM_STATE_CONNECTING:
	case PW_STREAM_STATE_PAUSED:
	case PW_STREAM_STATE_STREAMING:
		break;
	}
	if (stream->done) {
		pw_work_queue_add(impl->work_queue, stream, 0,
				on_stream_cleanup, client);
	}
}

static const struct spa_pod *get_buffers_param(struct stream *s,
		struct buffer_attr *attr, struct spa_pod_builder *b)
{
	const struct spa_pod *param;
	uint32_t blocks, buffers, size, maxsize, stride;

	blocks = 1;
	stride = s->frame_size;

	if (s->direction == PW_DIRECTION_OUTPUT) {
		maxsize = attr->tlength * 4;
		size = attr->minreq * 2;
	} else {
		size = attr->fragsize;
		maxsize = attr->fragsize * MAX_BUFFERS;
	}
	buffers = SPA_CLAMP(maxsize / size, MIN_BUFFERS, MAX_BUFFERS);

	pw_log_info("stream %p: stride %d maxsize %d size %u buffers %d", s, stride, maxsize,
			size, buffers);

	param = spa_pod_builder_add_object(b,
			SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(buffers, MIN_BUFFERS, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(blocks),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
								size, size, maxsize),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
	return param;
}

static void stream_param_changed(void *data, uint32_t id, const struct spa_pod *param)
{
	struct stream *stream = data;
	const struct spa_pod *params[4];
	uint32_t n_params = 0;
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	int res;

	if (id != SPA_PARAM_Format || param == NULL)
		return;

	if ((res = format_parse_param(param, &stream->ss, &stream->map)) < 0) {
		pw_stream_set_error(stream->stream, res, "format not supported");
		return;
	}

	pw_log_debug(NAME" %p: got rate:%u channels:%u", stream, stream->ss.rate, stream->ss.channels);

	stream->frame_size = sample_spec_frame_size(&stream->ss);
	if (stream->frame_size == 0) {
		pw_stream_set_error(stream->stream, res, "format not supported");
		return;
	}
	stream->rate = stream->ss.rate;

	if (stream->create_tag != SPA_ID_INVALID) {
		stream->id = pw_stream_get_node_id(stream->stream);

		if (stream->volume_set) {
			pw_stream_set_control(stream->stream,
				SPA_PROP_channelVolumes, stream->volume.channels, stream->volume.values, 0);
		}
		if (stream->muted_set) {
			float val = stream->muted ? 1.0f : 0.0f;
			pw_stream_set_control(stream->stream,
				SPA_PROP_mute, 1, &val, 0);
		}
		if (stream->corked)
			pw_stream_set_active(stream->stream, false);

		if (stream->direction == PW_DIRECTION_OUTPUT) {
			reply_create_playback_stream(stream);
		} else {
			reply_create_record_stream(stream);
		}
	}

	params[n_params++] = get_buffers_param(stream, &stream->attr, &b);
	pw_stream_update_params(stream->stream, params, n_params);
}

static void stream_io_changed(void *data, uint32_t id, void *area, uint32_t size)
{
	struct stream *stream = data;
	switch (id) {
	case SPA_IO_RateMatch:
		stream->rate_match = area;
		break;
	}
}

struct process_data {
	struct pw_time pwt;
	uint32_t read_index;
	uint32_t write_index;
	uint32_t underrun_for;
	uint32_t playing_for;
	uint32_t missing;
	unsigned int underrun:1;
};

static int
do_process_done(struct spa_loop *loop,
                 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct stream *stream = user_data;
	struct client *client = stream->client;
	struct impl *impl = client->impl;
	const struct process_data *pd = data;
	uint32_t index, towrite;
	int32_t avail;

	stream->timestamp = pd->pwt.now;
	if (pd->pwt.rate.denom > 0)
		stream->delay = pd->pwt.delay * SPA_USEC_PER_SEC / pd->pwt.rate.denom;
	else
		stream->delay = 0;

	if (stream->direction == PW_DIRECTION_OUTPUT) {
		stream->read_index = pd->read_index;
		if (stream->corked) {
			if (stream->underrun_for != (uint64_t)-1)
				stream->underrun_for += pd->underrun_for;
			stream->playing_for = 0;
			return 0;
		}
		if (pd->underrun != stream->is_underrun) {
			stream->is_underrun = pd->underrun;
			stream->underrun_for = 0;
			stream->playing_for = 0;
			if (pd->underrun)
				send_underflow(stream, pd->read_index, pd->underrun_for);
			else
				send_stream_started(stream);
		}
		stream->missing += pd->missing;
		stream->missing = SPA_MIN(stream->missing, stream->attr.tlength);
		stream->playing_for += pd->playing_for;
		if (stream->underrun_for != (uint64_t)-1)
			stream->underrun_for += pd->underrun_for;

		send_command_request(stream);
	} else {
		struct message *msg;
		stream->write_index = pd->write_index;

		avail = spa_ringbuffer_get_read_index(&stream->ring, &index);

		if (!spa_list_is_empty(&client->out_messages)) {
			pw_log_debug(NAME" %p: [%s] pending read:%u avail:%d",
					stream, client->name, index, avail);
			return 0;
		}

		if (avail <= 0) {
			/* underrun, can't really happen but if it does we
			 * do nothing and wait for more data */
			pw_log_warn(NAME" %p: [%s] underrun read:%u avail:%d",
					stream, client->name, index, avail);
		} else {
			if (avail > (int32_t)stream->attr.maxlength) {
				/* overrun, catch up to latest fragment and send it */
				pw_log_warn(NAME" %p: [%s] overrun recover read:%u avail:%d max:%u",
					stream, client->name, index, avail, stream->attr.maxlength);
				avail = stream->attr.fragsize;
				index = stream->write_index - avail;
			}

			while (avail > 0) {
				towrite = avail;
				if (towrite > stream->attr.fragsize)
					towrite = stream->attr.fragsize;

				msg = message_alloc(impl, stream->channel, towrite);
				if (msg == NULL)
					return -errno;

				spa_ringbuffer_read_data(&stream->ring,
						stream->buffer, stream->attr.maxlength,
						index % stream->attr.maxlength,
						msg->data, towrite);

				send_message(client, msg);

				index += towrite;
				avail -= towrite;
			}
			stream->read_index = index;
			spa_ringbuffer_read_update(&stream->ring, stream->read_index);
		}
	}
	return 0;
}


static void stream_process(void *data)
{
	struct stream *stream = data;
	struct client *client = stream->client;
	struct impl *impl = stream->impl;
	void *p;
	struct pw_buffer *buffer;
	struct spa_buffer *buf;
	uint32_t size, minreq;
	struct process_data pd;

	pw_log_trace_fp(NAME" %p: process", stream);

	buffer = pw_stream_dequeue_buffer(stream->stream);
	if (buffer == NULL)
		return;

        buf = buffer->buffer;
        if ((p = buf->datas[0].data) == NULL)
		return;

	spa_zero(pd);

	if (stream->direction == PW_DIRECTION_OUTPUT) {
		int32_t avail = spa_ringbuffer_get_read_index(&stream->ring, &pd.read_index);

		if (stream->rate_match)
			minreq = stream->rate_match->size * stream->frame_size;
		else
			minreq = stream->attr.minreq;

		if (avail < (int32_t)minreq || stream->corked) {
			/* underrun, produce a silence buffer */
			size = SPA_MIN(buf->datas[0].maxsize, minreq);
			memset(p, 0, size);

			if (stream->draining) {
				stream->draining = false;
				pw_stream_flush(stream->stream, true);
			} else {
				pd.underrun_for = size;
				pd.underrun = true;
			}
			if (stream->attr.prebuf == 0 && !stream->corked) {
				pd.missing = size;
				pd.playing_for = size;
				pd.read_index += size;
				spa_ringbuffer_read_update(&stream->ring, pd.read_index);
			}
		} else {
			if (avail > (int32_t)stream->attr.maxlength) {
				/* overrun, reported by other side, here we skip
				 * ahead to the oldest data. */
				pw_log_debug(NAME" %p: [%s] overrun read:%u avail:%d max:%u",
						stream, client->name, pd.read_index, avail,
						stream->attr.maxlength);
				pd.read_index += avail - stream->attr.maxlength;
				avail = stream->attr.maxlength;
			}
			size = SPA_MIN(buf->datas[0].maxsize, (uint32_t)avail);
			size = SPA_MIN(size, minreq);

			spa_ringbuffer_read_data(&stream->ring,
					stream->buffer, stream->attr.maxlength,
					pd.read_index % stream->attr.maxlength,
					p, size);

			pd.read_index += size;
			spa_ringbuffer_read_update(&stream->ring, pd.read_index);

			pd.playing_for = size;
			pd.missing = size;
			pd.underrun = false;
		}
	        buf->datas[0].chunk->offset = 0;
	        buf->datas[0].chunk->stride = stream->frame_size;
	        buf->datas[0].chunk->size = size;
	        buffer->size = size / stream->frame_size;
	} else  {
		int32_t filled = spa_ringbuffer_get_write_index(&stream->ring, &pd.write_index);
		size = buf->datas[0].chunk->size;
		if (filled < 0) {
			/* underrun, can't really happen because we never read more
			 * than what's available on the other side  */
			pw_log_warn(NAME" %p: [%s] underrun write:%u filled:%d",
					stream, client->name, pd.write_index, filled);
		} else if ((uint32_t)filled + size > stream->attr.maxlength) {
			/* overrun, can happen when the other side is not
			 * reading fast enough. We still write our data into the
			 * ringbuffer and expect the other side to warn and catch up. */
			pw_log_debug(NAME" %p: [%s] overrun write:%u filled:%d size:%u max:%u",
					stream, client->name, pd.write_index, filled,
					size, stream->attr.maxlength);
		}

		spa_ringbuffer_write_data(&stream->ring,
				stream->buffer, stream->attr.maxlength,
				pd.write_index % stream->attr.maxlength,
				SPA_MEMBER(p, buf->datas[0].chunk->offset, void),
				SPA_MIN(size, stream->attr.maxlength));

		pd.write_index += size;
		spa_ringbuffer_write_update(&stream->ring, pd.write_index);
	}
	pw_stream_queue_buffer(stream->stream, buffer);

	pw_stream_get_time(stream->stream, &pd.pwt);

	pw_loop_invoke(impl->loop,
			do_process_done, 1, &pd, sizeof(pd), false, stream);
}

static void stream_drained(void *data)
{
	struct stream *stream = data;
	pw_log_info(NAME" %p: [%s] drained channel:%u", stream,
			stream->client->name, stream->channel);
	reply_simple_ack(stream->client, stream->drain_tag);
	stream->drain_tag = 0;
}

static const struct pw_stream_events stream_events =
{
	PW_VERSION_STREAM_EVENTS,
	.control_info = stream_control_info,
	.state_changed = stream_state_changed,
	.param_changed = stream_param_changed,
	.io_changed = stream_io_changed,
	.process = stream_process,
	.drained = stream_drained,
};

static void log_format_info(struct impl *impl, enum spa_log_level level, struct format_info *format)
{
	const struct spa_dict_item *it;
	pw_log(level, NAME" %p: format %s",
			impl, format_encoding2name(format->encoding));
	spa_dict_for_each(it, &format->props->dict)
		pw_log(level, NAME" %p:  '%s': '%s'",
				impl, it->key, it->value);
}

static int do_create_playback_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	const char *name = NULL;
	int res;
	struct sample_spec ss;
	struct channel_map map;
	uint32_t sink_index, syncid;
	const char *sink_name;
	struct buffer_attr attr = { 0 };
	bool corked = false,
		no_remap = false,
		no_remix = false,
		fix_format = false,
		fix_rate = false,
		fix_channels = false,
		no_move = false,
		variable_rate = false,
		muted = false,
		adjust_latency = false,
		early_requests = false,
		dont_inhibit_auto_suspend = false,
		volume_set = true,
		muted_set = false,
		fail_on_suspend = false,
		relative_volume = false,
		passthrough = false;
	struct volume volume;
	struct pw_properties *props = NULL;
	uint8_t n_formats = 0;
	struct stream *stream = NULL;
	uint32_t n_params = 0, n_valid_formats = 0, flags;
	const struct spa_pod *params[MAX_FORMATS];
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	props = pw_properties_copy(client->props);
	if (props == NULL)
		goto error_errno;

	if (client->version < 13) {
		if ((res = message_get(m,
				TAG_STRING, &name,
				TAG_INVALID)) < 0)
			goto error_protocol;
		if (name == NULL)
			goto error_protocol;
	}
	if (message_get(m,
			TAG_SAMPLE_SPEC, &ss,
			TAG_CHANNEL_MAP, &map,
			TAG_U32, &sink_index,
			TAG_STRING, &sink_name,
			TAG_U32, &attr.maxlength,
			TAG_BOOLEAN, &corked,
			TAG_U32, &attr.tlength,
			TAG_U32, &attr.prebuf,
			TAG_U32, &attr.minreq,
			TAG_U32, &syncid,
			TAG_CVOLUME, &volume,
			TAG_INVALID) < 0)
		goto error_protocol;

	pw_log_info(NAME" %p: [%s] CREATE_PLAYBACK_STREAM tag:%u corked:%u sink-name:%s sink-idx:%u",
			impl, client->name, tag, corked, sink_name, sink_index);

	if (sink_index != SPA_ID_INVALID && sink_name != NULL)
		goto error_invalid;

	if (client->version >= 12) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &no_remap,
				TAG_BOOLEAN, &no_remix,
				TAG_BOOLEAN, &fix_format,
				TAG_BOOLEAN, &fix_rate,
				TAG_BOOLEAN, &fix_channels,
				TAG_BOOLEAN, &no_move,
				TAG_BOOLEAN, &variable_rate,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 13) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &muted,
				TAG_BOOLEAN, &adjust_latency,
				TAG_PROPLIST, props,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 14) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &volume_set,
				TAG_BOOLEAN, &early_requests,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 15) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &muted_set,
				TAG_BOOLEAN, &dont_inhibit_auto_suspend,
				TAG_BOOLEAN, &fail_on_suspend,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 17) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &relative_volume,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 18) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &passthrough,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}

	if (client->version >= 21) {
		if ((res = message_get(m,
				TAG_U8, &n_formats,
				TAG_INVALID)) < 0)
			goto error_protocol;

		if (n_formats) {
			uint8_t i;
			for (i = 0; i < n_formats; i++) {
				struct format_info format;

				if ((res = message_get(m,
						TAG_FORMAT_INFO, &format,
						TAG_INVALID)) < 0)
					goto error_protocol;

				if (n_params < MAX_FORMATS &&
				    (params[n_params] = format_info_build_param(&b,
						SPA_PARAM_EnumFormat, &format)) != NULL) {
					n_params++;
					n_valid_formats++;
				} else {
					log_format_info(impl, SPA_LOG_LEVEL_WARN, &format);
				}
				format_info_clear(&format);
			}
		}
	}
	if (sample_spec_valid(&ss)) {
		if (n_params < MAX_FORMATS &&
		    (params[n_params] = format_build_param(&b,
				SPA_PARAM_EnumFormat, &ss, &map)) != NULL) {
			n_params++;
			n_valid_formats++;
		} else {
			pw_log_warn(NAME" %p: unsupported format:%s rate:%d channels:%u",
					impl, format_id2name(ss.format), ss.rate,
					ss.channels);
		}
	}

	if (m->offset != m->length)
		goto error_protocol;

	if (n_valid_formats == 0)
		goto error_no_formats;

	stream = calloc(1, sizeof(struct stream));
	if (stream == NULL)
		goto error_errno;

	stream->impl = impl;
	stream->client = client;
	stream->corked = corked;
	stream->adjust_latency = adjust_latency;
	stream->early_requests = early_requests;
	stream->channel = pw_map_insert_new(&client->streams, stream);
	if (stream->channel == SPA_ID_INVALID)
		goto error_errno;

	stream->type = STREAM_TYPE_PLAYBACK;
	stream->direction = PW_DIRECTION_OUTPUT;
	stream->create_tag = tag;
	stream->ss = ss;
	stream->map = map;
	stream->volume = volume;
	stream->volume_set = volume_set;
	stream->muted = muted;
	stream->muted_set = muted_set;
	stream->attr = attr;
	stream->is_underrun = true;
	stream->underrun_for = -1;

	if (no_remix)
		pw_properties_set(props, PW_KEY_STREAM_DONT_REMIX, "true");
	flags = 0;
	if (no_move)
		flags |= PW_STREAM_FLAG_DONT_RECONNECT;

	if (sink_name != NULL)
		pw_properties_set(props,
				PW_KEY_NODE_TARGET, sink_name);
	else if (sink_index != SPA_ID_INVALID && sink_index != 0)
		pw_properties_setf(props,
				PW_KEY_NODE_TARGET, "%u", sink_index);

	stream->stream = pw_stream_new(client->core, name, props);
	props = NULL;
	if (stream->stream == NULL)
		goto error_errno;

	pw_log_debug(NAME" %p: new stream %p channel:%d", impl, stream, stream->channel);

	pw_stream_add_listener(stream->stream,
			&stream->stream_listener,
			&stream_events, stream);

	pw_stream_connect(stream->stream,
			PW_DIRECTION_OUTPUT,
			SPA_ID_INVALID,
			flags |
			PW_STREAM_FLAG_AUTOCONNECT |
			PW_STREAM_FLAG_RT_PROCESS |
			PW_STREAM_FLAG_MAP_BUFFERS,
			params, n_params);

	return 0;

error_errno:
	res = -errno;
	goto error;
error_protocol:
	res = -EPROTO;
	goto error;
error_no_formats:
	res = -ENOTSUP;
	goto error;
error_invalid:
	res = -EINVAL;
	goto error;
error:
	if (props)
		pw_properties_free(props);
	if (stream)
		stream_free(stream);
	return res;
}

static int do_create_record_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	const char *name = NULL;
	int res;
	struct sample_spec ss;
	struct channel_map map;
	uint32_t source_index;
	const char *source_name;
	struct buffer_attr attr;
	bool corked = false,
		no_remap = false,
		no_remix = false,
		fix_format = false,
		fix_rate = false,
		fix_channels = false,
		no_move = false,
		variable_rate = false,
		peak_detect = false,
		adjust_latency = false,
		early_requests = false,
		dont_inhibit_auto_suspend = false,
		volume_set = true,
		muted = false,
		muted_set = false,
		fail_on_suspend = false,
		relative_volume = false,
		passthrough = false;
	uint32_t direct_on_input_idx = SPA_ID_INVALID;
	struct volume volume = VOLUME_INIT;
	struct pw_properties *props = NULL;
	uint8_t n_formats = 0;
	struct stream *stream = NULL;
	uint32_t n_params = 0, n_valid_formats = 0, flags, id;
	const struct spa_pod *params[MAX_FORMATS];
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	props = pw_properties_copy(client->props);
	if (props == NULL)
		goto error_errno;

	if (client->version < 13) {
		if ((res = message_get(m,
				TAG_STRING, &name,
				TAG_INVALID)) < 0)
			goto error_protocol;
		if (name == NULL)
			goto error_protocol;
	}
	if ((res = message_get(m,
			TAG_SAMPLE_SPEC, &ss,
			TAG_CHANNEL_MAP, &map,
			TAG_U32, &source_index,
			TAG_STRING, &source_name,
			TAG_U32, &attr.maxlength,
			TAG_BOOLEAN, &corked,
			TAG_U32, &attr.fragsize,
			TAG_INVALID)) < 0)
		goto error_protocol;

	pw_log_info(NAME" %p: [%s] CREATE_RECORD_STREAM tag:%u corked:%u source-name:%s source-index:%u",
			impl, client->name, tag, corked, source_name, source_index);

	if (source_index != SPA_ID_INVALID && source_name != NULL)
		goto error_invalid;

	if (client->version >= 12) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &no_remap,
				TAG_BOOLEAN, &no_remix,
				TAG_BOOLEAN, &fix_format,
				TAG_BOOLEAN, &fix_rate,
				TAG_BOOLEAN, &fix_channels,
				TAG_BOOLEAN, &no_move,
				TAG_BOOLEAN, &variable_rate,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 13) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &peak_detect,
				TAG_BOOLEAN, &adjust_latency,
				TAG_PROPLIST, props,
				TAG_U32, &direct_on_input_idx,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 14) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &early_requests,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 15) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &dont_inhibit_auto_suspend,
				TAG_BOOLEAN, &fail_on_suspend,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (client->version >= 22) {
		if ((res = message_get(m,
				TAG_U8, &n_formats,
				TAG_INVALID)) < 0)
			goto error_protocol;

		if (n_formats) {
			uint8_t i;
			for (i = 0; i < n_formats; i++) {
				struct format_info format;

				if ((res = message_get(m,
						TAG_FORMAT_INFO, &format,
						TAG_INVALID)) < 0)
					goto error_protocol;

				if (n_params < MAX_FORMATS &&
				    (params[n_params] = format_info_build_param(&b,
						SPA_PARAM_EnumFormat, &format)) != NULL) {
					n_params++;
					n_valid_formats++;
				} else {
					log_format_info(impl, SPA_LOG_LEVEL_WARN, &format);
				}
				format_info_clear(&format);
			}
		}
		if ((res = message_get(m,
				TAG_CVOLUME, &volume,
				TAG_BOOLEAN, &muted,
				TAG_BOOLEAN, &volume_set,
				TAG_BOOLEAN, &muted_set,
				TAG_BOOLEAN, &relative_volume,
				TAG_BOOLEAN, &passthrough,
				TAG_INVALID)) < 0)
			goto error_protocol;
	} else {
		volume_set = false;
	}
	if (sample_spec_valid(&ss)) {
		if (n_params < MAX_FORMATS &&
		    (params[n_params] = format_build_param(&b,
				SPA_PARAM_EnumFormat, &ss, &map)) != NULL) {
			n_params++;
			n_valid_formats++;
		} else {
			pw_log_warn(NAME" %p: unsupported format:%s rate:%d channels:%u",
					impl, format_id2name(ss.format), ss.rate,
					ss.channels);
		}
	}
	if (m->offset != m->length)
		goto error_protocol;

	if (n_valid_formats == 0)
		goto error_no_formats;

	stream = calloc(1, sizeof(struct stream));
	if (stream == NULL)
		goto error_errno;

	stream->type = STREAM_TYPE_RECORD;
	stream->direction = PW_DIRECTION_INPUT;
	stream->impl = impl;
	stream->client = client;
	stream->corked = corked;
	stream->adjust_latency = adjust_latency;
	stream->early_requests = early_requests;
	stream->channel = pw_map_insert_new(&client->streams, stream);
	if (stream->channel == SPA_ID_INVALID)
		goto error_errno;

	stream->create_tag = tag;
	stream->ss = ss;
	stream->map = map;
	stream->volume = volume;
	stream->volume_set = volume_set;
	stream->muted = muted;
	stream->muted_set = muted_set;
	stream->attr = attr;

	if (peak_detect)
		pw_properties_set(props, PW_KEY_STREAM_MONITOR, "true");
	if (no_remix)
		pw_properties_set(props, PW_KEY_STREAM_DONT_REMIX, "true");
	flags = 0;
	if (no_move)
		flags |= PW_STREAM_FLAG_DONT_RECONNECT;

	if (direct_on_input_idx != SPA_ID_INVALID) {
		source_index = direct_on_input_idx;
	} else if (source_name != NULL) {
		if ((id = atoi(source_name)) != 0)
			source_index = id;
	}
	if (source_index != SPA_ID_INVALID && source_index != 0) {
		if (source_index & MONITOR_FLAG)
			source_index &= INDEX_MASK;
		pw_properties_setf(props,
				PW_KEY_NODE_TARGET, "%u", source_index);
	} else if (source_name != NULL) {
		if (pw_endswith(source_name, ".monitor")) {
			pw_properties_setf(props,
					PW_KEY_NODE_TARGET,
					"%.*s", (int)strlen(source_name)-8, source_name);
		} else {
			pw_properties_set(props,
					PW_KEY_NODE_TARGET, source_name);
		}
	}

	stream->stream = pw_stream_new(client->core, name, props);
	props = NULL;
	if (stream->stream == NULL)
		goto error_errno;

	pw_stream_add_listener(stream->stream,
			&stream->stream_listener,
			&stream_events, stream);

	pw_stream_connect(stream->stream,
			PW_DIRECTION_INPUT,
			SPA_ID_INVALID,
			flags |
			PW_STREAM_FLAG_AUTOCONNECT |
			PW_STREAM_FLAG_RT_PROCESS |
			PW_STREAM_FLAG_MAP_BUFFERS,
			params, n_params);

	return 0;

error_errno:
	res = -errno;
	goto error;
error_protocol:
	res = -EPROTO;
	goto error;
error_no_formats:
	res = -ENOTSUP;
	goto error;
error_invalid:
	res = -EINVAL;
	goto error;
error:
	if (props)
		pw_properties_free(props);
	if (stream)
		stream_free(stream);
	return res;
}

static int do_delete_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] DELETE_STREAM tag:%u channel:%u", impl,
			client->name, tag, channel);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL)
		return -ENOENT;
	if (command == COMMAND_DELETE_PLAYBACK_STREAM &&
	    stream->type != STREAM_TYPE_PLAYBACK)
		return -ENOENT;
	if (command == COMMAND_DELETE_RECORD_STREAM &&
	    stream->type != STREAM_TYPE_RECORD)
		return -ENOENT;
	if (command == COMMAND_DELETE_UPLOAD_STREAM &&
	    stream->type != STREAM_TYPE_UPLOAD)
		return -ENOENT;

	stream_free(stream);

	return reply_simple_ack(client, tag);
}

static int do_get_playback_latency(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;
	uint32_t channel;
	struct timeval tv, now;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_TIMEVAL, &tv,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_debug(NAME" %p: %s tag:%u channel:%u", impl, commands[command].name, tag, channel);
	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type != STREAM_TYPE_PLAYBACK)
		return -ENOENT;

	pw_log_debug("read:%"PRIi64" write:%"PRIi64" queued:%"PRIi64" delay:%"PRIi64
			" playing:%"PRIu64,
			stream->read_index, stream->write_index,
			stream->write_index - stream->read_index, stream->delay,
			stream->playing_for);

	gettimeofday(&now, NULL);

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_USEC, stream->delay,	/* sink latency + queued samples */
		TAG_USEC, 0,			/* always 0 */
		TAG_BOOLEAN, stream->playing_for > 0 &&
				!stream->corked,	/* playing state */
		TAG_TIMEVAL, &tv,
		TAG_TIMEVAL, &now,
		TAG_S64, stream->write_index,
		TAG_S64, stream->read_index,
		TAG_INVALID);

	if (client->version >= 13) {
		message_put(reply,
			TAG_U64, stream->underrun_for,
			TAG_U64, stream->playing_for,
			TAG_INVALID);
	}
	return send_message(client, reply);
}

static int do_get_record_latency(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;
	uint32_t channel;
	struct timeval tv, now;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_TIMEVAL, &tv,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_debug(NAME" %p: %s channel:%u", impl, commands[command].name, channel);
	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type != STREAM_TYPE_RECORD)
		return -ENOENT;

	gettimeofday(&now, NULL);
	reply = reply_new(client, tag);
	message_put(reply,
		TAG_USEC, 0,			/* monitor latency */
		TAG_USEC, stream->delay,	/* source latency + queued */
		TAG_BOOLEAN, !stream->corked,	/* playing state */
		TAG_TIMEVAL, &tv,
		TAG_TIMEVAL, &now,
		TAG_S64, stream->write_index,
		TAG_S64, stream->read_index,
		TAG_INVALID);

	return send_message(client, reply);
}

static int do_create_upload_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	const char *name;
	struct sample_spec ss;
	struct channel_map map;
	struct pw_properties *props = NULL;
	uint32_t length;
	struct stream *stream = NULL;
	struct message *reply;
	int res;

	if ((props = pw_properties_copy(client->props)) == NULL)
		goto error_errno;

	if ((res = message_get(m,
			TAG_STRING, &name,
			TAG_SAMPLE_SPEC, &ss,
			TAG_CHANNEL_MAP, &map,
			TAG_U32, &length,
			TAG_INVALID)) < 0)
		goto error_proto;

	if (client->version >= 13) {
		if ((res = message_get(m,
				TAG_PROPLIST, props,
				TAG_INVALID)) < 0)
			goto error_proto;

	} else {
		pw_properties_set(props, PW_KEY_MEDIA_NAME, name);
	}
	if (name == NULL)
		name = pw_properties_get(props, "event.id");
	if (name == NULL)
		name = pw_properties_get(props, PW_KEY_MEDIA_NAME);

	if (name == NULL ||
	    !sample_spec_valid(&ss) ||
	    !channel_map_valid(&map) ||
	    ss.channels != map.channels ||
	    length == 0 || (length % sample_spec_frame_size(&ss) != 0))
		goto error_invalid;
	if (length >= SCACHE_ENTRY_SIZE_MAX)
		goto error_toolarge;

	pw_log_info(NAME" %p: [%s] %s tag:%u name:%s length:%d",
			impl, client->name, commands[command].name, tag,
			name, length);

	stream = calloc(1, sizeof(struct stream));
	if (stream == NULL)
		goto error_errno;

	stream->type = STREAM_TYPE_UPLOAD;
	stream->direction = PW_DIRECTION_OUTPUT;
	stream->impl = impl;
	stream->client = client;
	stream->channel = pw_map_insert_new(&client->streams, stream);
	if (stream->channel == SPA_ID_INVALID)
		goto error_errno;

	stream->create_tag = tag;
	stream->ss = ss;
	stream->map = map;
	stream->props = props;

	stream->attr.maxlength = length;

	stream->buffer = calloc(1, stream->attr.maxlength);
	if (stream->buffer == NULL)
		goto error_errno;

	spa_ringbuffer_init(&stream->ring);

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_U32, stream->channel,
		TAG_U32, length,
		TAG_INVALID);
	return send_message(client, reply);

error_errno:
	res = -errno;
	goto error;
error_proto:
	res = -EPROTO;
	goto error;
error_invalid:
	res = -EINVAL;
	goto error;
error_toolarge:
	res = -EOVERFLOW;
	goto error;
error:
	if (props != NULL)
		pw_properties_free(props);
	if (stream)
		stream_free(stream);
	return res;
}

static int do_finish_upload_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel, event;
	struct stream *stream = NULL;
	struct sample *sample;
	const char *name;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_INVALID)) < 0)
		return -EPROTO;

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type != STREAM_TYPE_UPLOAD)
		return -ENOENT;

	name = pw_properties_get(stream->props, "event.id");
	if (name == NULL)
		name = pw_properties_get(stream->props, PW_KEY_MEDIA_NAME);
	if (name == NULL)
		goto error_invalid;

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%u name:%s",
			impl, client->name, commands[command].name, tag,
			channel, name);

	sample = find_sample(impl, SPA_ID_INVALID, name);
	if (sample == NULL) {
		sample = calloc(1, sizeof(struct sample));
		if (sample == NULL)
			goto error_errno;

		sample->index = pw_map_insert_new(&impl->samples, sample);
		if (sample->index == SPA_ID_INVALID)
			goto error_errno;

		event = SUBSCRIPTION_EVENT_NEW;
	} else {
		if (sample->props)
			pw_properties_free(sample->props);
		free(sample->buffer);
		event = SUBSCRIPTION_EVENT_CHANGE;
	}
	sample->ref = 1;
	sample->impl = impl;
	sample->name = name;
	sample->props = stream->props;
	sample->ss = stream->ss;
	sample->map = stream->map;
	sample->buffer = stream->buffer;
	sample->length = stream->attr.maxlength;

	impl->stat.sample_cache += sample->length;

	stream->props = NULL;
	stream->buffer = NULL;
	stream_free(stream);

	broadcast_subscribe_event(impl,
			SUBSCRIPTION_MASK_SAMPLE_CACHE,
			event | SUBSCRIPTION_EVENT_SAMPLE_CACHE,
			sample->index);

	return reply_simple_ack(client, tag);

error_errno:
	res = -errno;
	if (sample != NULL) {
		free(sample);
	}
	goto error;
error_invalid:
	res = -EINVAL;
	goto error;
error:
	stream_free(stream);
	return res;
}

static const char *get_default(struct client *client, bool sink)
{
	struct selector sel;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *o;
	const char *def, *str, *mon;

	spa_zero(sel);
	if (sink) {
		sel.type = pw_manager_object_is_sink;
		sel.key = PW_KEY_NODE_NAME;
		sel.value = client->default_sink;
		def = DEFAULT_SINK;
	} else {
		sel.type = pw_manager_object_is_source_or_monitor;
		sel.key = PW_KEY_NODE_NAME;
		sel.value = client->default_source;
		def = DEFAULT_SOURCE;
	}
	sel.accumulate = select_best;

	o = select_object(manager, &sel);
	if (o == NULL || o->props == NULL)
		return def;
	str = pw_properties_get(o->props, PW_KEY_NODE_NAME);

	if (!sink && pw_manager_object_is_monitor(o)) {
		def = DEFAULT_MONITOR;
		if (str != NULL &&
		    (mon = pw_properties_get(o->props, PW_KEY_NODE_NAME".monitor")) == NULL) {
			pw_properties_setf(o->props,
					PW_KEY_NODE_NAME".monitor",
					"%s.monitor", str);
		}
		str = pw_properties_get(o->props, PW_KEY_NODE_NAME".monitor");
	}
	if (str == NULL)
		str = def;
	return str;
}

static struct pw_manager_object *find_device(struct client *client,
		uint32_t id, const char *name, bool sink, bool *is_monitor)
{
	struct selector sel;
	const char *def;
	bool monitor = false;

	if (id == 0)
		id = SPA_ID_INVALID;

	if (name != NULL && !sink) {
		if (pw_endswith(name, ".monitor")) {
			name = strndupa(name, strlen(name)-8);
			monitor = true;
		} else if (strcmp(name, DEFAULT_MONITOR) == 0) {
			name = NULL;
			monitor = true;
		}
	}
	if (id != SPA_ID_INVALID && !sink) {
		if (id & MONITOR_FLAG) {
			monitor = true;
			id &= ~MONITOR_FLAG;
		}
	}
	if (monitor)
		sink = true;
	if (is_monitor)
		*is_monitor = monitor;

	spa_zero(sel);
	sel.id = id;
	sel.key = PW_KEY_NODE_NAME;
	sel.value = name;

	if (sink) {
		sel.type = pw_manager_object_is_sink;
		def = DEFAULT_SINK;
	} else {
		sel.type = pw_manager_object_is_source;
		def = DEFAULT_SOURCE;
	}
	if (id == SPA_ID_INVALID &&
	    (sel.value == NULL || strcmp(sel.value, def) == 0 ||
	    strcmp(sel.value, "0") == 0))
		sel.value = get_default(client, sink);

	return select_object(client->manager, &sel);
}

struct pending_sample {
	struct spa_list link;
	struct client *client;
	struct sample_play *play;
	struct spa_hook listener;
	uint32_t tag;
	unsigned int done:1;
};

static void pending_sample_free(struct pending_sample *ps)
{
	struct client *client = ps->client;
	struct impl *impl = client->impl;
	spa_list_remove(&ps->link);
	spa_hook_remove(&ps->listener);
	pw_work_queue_cancel(impl->work_queue, ps, SPA_ID_INVALID);
	ps->client->ref--;
	sample_play_destroy(ps->play);
}

static void sample_play_ready(void *data, uint32_t index)
{
	struct pending_sample *ps = data;
	struct client *client = ps->client;
	struct impl *impl = client->impl;
	struct message *reply;

	pw_log_info(NAME" %p: [%s] PLAY_SAMPLE tag:%u index:%u",
			impl, client->name, ps->tag, index);

	reply = reply_new(client, ps->tag);
	if (client->version >= 13)
		message_put(reply,
			TAG_U32, index,
			TAG_INVALID);

	send_message(client, reply);
}

static void on_sample_done(void *obj, void *data, int res, uint32_t id)
{
	struct pending_sample *ps = obj;
	struct client *client = ps->client;
	pending_sample_free(ps);
	if (client->ref <= 0)
		client_free(client);
}

static void sample_play_done(void *data, int res)
{
	struct pending_sample *ps = data;
	struct client *client = ps->client;
	struct impl *impl = client->impl;

	if (res < 0)
		reply_error(client, COMMAND_PLAY_SAMPLE, ps->tag, res);
	else
		pw_log_info(NAME" %p: PLAY_SAMPLE done tag:%u", client, ps->tag);

	ps->done = true;
	pw_work_queue_add(impl->work_queue, ps, 0,
				on_sample_done, client);
}

static const struct sample_play_events sample_play_events = {
	VERSION_SAMPLE_PLAY_EVENTS,
	.ready = sample_play_ready,
	.done = sample_play_done,
};

static int do_play_sample(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t sink_index, volume;
	struct sample *sample;
	struct sample_play *play;
	const char *sink_name, *name;
	struct pw_properties *props = NULL;
	struct pending_sample *ps;
	struct pw_manager_object *o;
	int res;

	if ((props = pw_properties_new(NULL, NULL)) == NULL)
		goto error_errno;

	if ((res = message_get(m,
			TAG_U32, &sink_index,
			TAG_STRING, &sink_name,
			TAG_U32, &volume,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		goto error_proto;

	if (client->version >= 13) {
		if ((res = message_get(m,
				TAG_PROPLIST, props,
				TAG_INVALID)) < 0)
			goto error_proto;

	}
	pw_log_info(NAME" %p: [%s] %s tag:%u sink_index:%u sink_name:%s name:%s",
			impl, client->name, commands[command].name, tag,
			sink_index, sink_name, name);

	pw_properties_update(props, &client->props->dict);

	if (sink_index != SPA_ID_INVALID && sink_name != NULL)
		goto error_inval;

	o = find_device(client, sink_index, sink_name, PW_DIRECTION_OUTPUT, NULL);
	if (o == NULL)
		goto error_noent;

	sample = find_sample(impl, SPA_ID_INVALID, name);
	if (sample == NULL)
		goto error_noent;

	pw_properties_setf(props, PW_KEY_NODE_TARGET, "%u", o->id);

	play = sample_play_new(client->core, sample, props, sizeof(struct pending_sample));
	props = NULL;
	if (play == NULL)
		goto error_errno;

	ps = play->user_data;
	ps->client = client;
	ps->play = play;
	ps->tag = tag;
	sample_play_add_listener(play, &ps->listener, &sample_play_events, ps);
	spa_list_append(&client->pending_samples, &ps->link);
	client->ref++;

	return 0;

error_errno:
	res = -errno;
	goto error;
error_proto:
	res = -EPROTO;
	goto error;
error_inval:
	res = -EINVAL;
	goto error;
error_noent:
	res = -ENOENT;
	goto error;
error:
	if (props != NULL)
		pw_properties_free(props);
	return res;
}

static int do_remove_sample(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	const char *name;
	struct sample *sample;
	int res;

	if ((res = message_get(m,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u name:%s",
			impl, client->name, commands[command].name, tag,
			name);
	if (name == NULL)
		return -EINVAL;
	if ((sample = find_sample(impl, SPA_ID_INVALID, name)) == NULL)
		return -ENOENT;

	broadcast_subscribe_event(impl,
			SUBSCRIPTION_MASK_SAMPLE_CACHE,
			SUBSCRIPTION_EVENT_REMOVE |
			SUBSCRIPTION_EVENT_SAMPLE_CACHE,
			sample->index);

	sample_free(sample);

	return reply_simple_ack(client, tag);
}

static int do_cork_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	bool cork;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_BOOLEAN, &cork,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%u cork:%s",
			impl, client->name, commands[command].name, tag,
			channel, cork ? "yes" : "no");

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
		return -ENOENT;

	stream->corked = cork;
	pw_stream_set_active(stream->stream, !cork);
	if (cork) {
		stream->is_underrun = true;
	} else {
		stream->playing_for = 0;
		stream->underrun_for = -1;
	}

	return reply_simple_ack(client, tag);
}

static void stream_flush(struct stream *stream)
{
	pw_stream_flush(stream->stream, false);

	if (stream->type == STREAM_TYPE_PLAYBACK) {
		stream->write_index = stream->read_index =
			stream->ring.writeindex = stream->ring.readindex;
		stream->missing = stream->attr.tlength;

		if (stream->attr.prebuf > 0)
			stream->in_prebuf = true;

		stream->playing_for = 0;
		stream->underrun_for = -1;
		stream->is_underrun = true;

		send_command_request(stream);
	} else {
		stream->read_index = stream->write_index =
			stream->ring.readindex = stream->ring.writeindex;
	}
}

static int do_flush_trigger_prebuf_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%u",
			impl, client->name, commands[command].name, tag, channel);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
		return -ENOENT;

	switch (command) {
	case COMMAND_FLUSH_PLAYBACK_STREAM:
	case COMMAND_FLUSH_RECORD_STREAM:
		stream_flush(stream);
		break;
	case COMMAND_TRIGGER_PLAYBACK_STREAM:
	case COMMAND_PREBUF_PLAYBACK_STREAM:
		break;
	default:
		return -EINVAL;
	}

	return reply_simple_ack(client, tag);
}

static int set_node_volume_mute(struct pw_manager_object *o,
		struct volume *vol, bool *mute, bool is_monitor)
{
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	struct spa_pod_frame f[1];
	struct spa_pod *param;
	uint32_t volprop, muteprop;

	if (!SPA_FLAG_IS_SET(o->permissions, PW_PERM_W | PW_PERM_X))
		return -EACCES;
	if (o->proxy == NULL)
		return -ENOENT;

	if (is_monitor) {
		volprop = SPA_PROP_monitorVolumes;
		muteprop = SPA_PROP_monitorMute;
	} else {
		volprop = SPA_PROP_channelVolumes;
		muteprop = SPA_PROP_mute;
	}

	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_OBJECT_Props,  SPA_PARAM_Props);
	if (vol)
		spa_pod_builder_add(&b,
				volprop, SPA_POD_Array(sizeof(float),
							SPA_TYPE_Float,
							vol->channels,
							vol->values), 0);
	if (mute)
		spa_pod_builder_add(&b,
				muteprop, SPA_POD_Bool(*mute), 0);
	param = spa_pod_builder_pop(&b, &f[0]);

	pw_node_set_param((struct pw_node*)o->proxy,
		SPA_PARAM_Props, 0, param);
	return 0;
}

static int set_card_volume_mute_delay(struct pw_manager_object *o, uint32_t id,
		uint32_t device_id, struct volume *vol, bool *mute, int64_t *latency_offset)
{
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	struct spa_pod_frame f[2];
	struct spa_pod *param;

	if (!SPA_FLAG_IS_SET(o->permissions, PW_PERM_W | PW_PERM_X))
		return -EACCES;

	if (o->proxy == NULL)
		return -ENOENT;

	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_OBJECT_ParamRoute, SPA_PARAM_Route);
	spa_pod_builder_add(&b,
			SPA_PARAM_ROUTE_index, SPA_POD_Int(id),
			SPA_PARAM_ROUTE_device, SPA_POD_Int(device_id),
			0);
	spa_pod_builder_prop(&b, SPA_PARAM_ROUTE_props, 0);
	spa_pod_builder_push_object(&b, &f[1],
			SPA_TYPE_OBJECT_Props,  SPA_PARAM_Props);
	if (vol)
		spa_pod_builder_add(&b,
				SPA_PROP_channelVolumes, SPA_POD_Array(sizeof(float),
								SPA_TYPE_Float,
								vol->channels,
								vol->values), 0);
	if (mute)
		spa_pod_builder_add(&b,
				SPA_PROP_mute, SPA_POD_Bool(*mute), 0);
	if (latency_offset)
		spa_pod_builder_add(&b,
				SPA_PROP_latencyOffsetNsec, SPA_POD_Long(*latency_offset), 0);
	spa_pod_builder_pop(&b, &f[1]);
	spa_pod_builder_prop(&b, SPA_PARAM_ROUTE_save, 0);
	spa_pod_builder_bool(&b, true);
	param = spa_pod_builder_pop(&b, &f[0]);

	pw_device_set_param((struct pw_device*)o->proxy,
			SPA_PARAM_Route, 0, param);
	return 0;
}

static int set_card_port(struct pw_manager_object *o, uint32_t device_id,
		uint32_t port_id)
{
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));

	if (!SPA_FLAG_IS_SET(o->permissions, PW_PERM_W | PW_PERM_X))
		return -EACCES;

	if (o->proxy == NULL)
		return -ENOENT;

	pw_device_set_param((struct pw_device*)o->proxy,
			SPA_PARAM_Route, 0,
			spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamRoute, SPA_PARAM_Route,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(port_id),
				SPA_PARAM_ROUTE_device, SPA_POD_Int(device_id),
				SPA_PARAM_ROUTE_save, SPA_POD_Bool(true)));

	return 0;
}

static int do_set_stream_volume(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	uint32_t id;
	struct stream *stream;
	struct volume volume;
	int res;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_CVOLUME, &volume,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u index:%u", impl,
			client->name, commands[command].name, tag, id);

	stream = find_stream(client, id);
	if (stream != NULL) {

		if (volume_compare(&stream->volume, &volume) == 0)
			goto done;

		pw_stream_set_control(stream->stream,
				SPA_PROP_channelVolumes, volume.channels, volume.values,
				0);
	} else {
		struct selector sel;
		struct pw_manager_object *o;

		spa_zero(sel);
		sel.id = id;
		if (command == COMMAND_SET_SINK_INPUT_VOLUME)
			sel.type = pw_manager_object_is_sink_input;
		else
			sel.type = pw_manager_object_is_source_output;

		o = select_object(manager, &sel);
		if (o == NULL)
			return -ENOENT;

		if ((res = set_node_volume_mute(o, &volume, NULL, false)) < 0)
			return res;
	}
done:
	return operation_new(client, tag);
}

static int do_set_stream_mute(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	uint32_t id;
	struct stream *stream;
	int res;
	bool mute;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_BOOLEAN, &mute,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] DO_SET_STREAM_MUTE tag:%u id:%u mute:%u",
			impl, client->name, tag, id, mute);

	stream = find_stream(client, id);
	if (stream != NULL) {
		float val;

		if (stream->muted == mute)
			goto done;

		val = mute ? 1.0f : 0.0f;
		pw_stream_set_control(stream->stream,
				SPA_PROP_mute, 1, &val,
				0);
	} else {
		struct selector sel;
		struct pw_manager_object *o;

		spa_zero(sel);
		sel.id = id;
		if (command == COMMAND_SET_SINK_INPUT_MUTE)
			sel.type = pw_manager_object_is_sink_input;
		else
			sel.type = pw_manager_object_is_source_output;

		o = select_object(manager, &sel);
		if (o == NULL)
			return -ENOENT;

		if ((res = set_node_volume_mute(o, NULL, &mute, false)) < 0)
			return res;
	}
done:
	return operation_new(client, tag);
}

static int do_set_volume(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_node_info *info;
	uint32_t id, card_id = SPA_ID_INVALID;
	const char *name, *str;
	struct volume volume;
	struct pw_manager_object *o, *card = NULL;
	int res;
	struct device_info dev_info;
	enum pw_direction direction;
	bool is_monitor;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_STRING, &name,
			TAG_CVOLUME, &volume,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u index:%u name:%s", impl,
			client->name, commands[command].name, tag, id, name);

	if ((id == SPA_ID_INVALID && name == NULL) ||
	    (id != SPA_ID_INVALID && name != NULL))
		return -EINVAL;

	if (command == COMMAND_SET_SINK_VOLUME)
		direction = PW_DIRECTION_OUTPUT;
	else
		direction = PW_DIRECTION_INPUT;

	o = find_device(client, id, name, direction == PW_DIRECTION_OUTPUT, &is_monitor);
	if (o == NULL || (info = o->info) == NULL || info->props == NULL)
		return -ENOENT;

	dev_info = DEVICE_INFO_INIT(direction);

	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
		dev_info.device = (uint32_t)atoi(str);
	if (card_id != SPA_ID_INVALID) {
		struct selector sel = { .id = card_id, .type = pw_manager_object_is_card, };
		card = select_object(manager, &sel);
	}
	collect_device_info(o, card, &dev_info, is_monitor);

	if (dev_info.have_volume &&
	    volume_compare(&dev_info.volume_info.volume, &volume) == 0)
		goto done;

	if (card != NULL && !is_monitor && dev_info.active_port != SPA_ID_INVALID)
		res = set_card_volume_mute_delay(card, dev_info.active_port,
				dev_info.device, &volume, NULL, NULL);
	else
		res = set_node_volume_mute(o, &volume, NULL, is_monitor);

	if (res < 0)
		return res;

done:
	return operation_new(client, tag);
}

static int do_set_mute(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_node_info *info;
	uint32_t id, card_id = SPA_ID_INVALID;
	const char *name, *str;
	bool mute;
	struct pw_manager_object *o, *card = NULL;
	int res;
	struct device_info dev_info;
	enum pw_direction direction;
	bool is_monitor;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_STRING, &name,
			TAG_BOOLEAN, &mute,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u index:%u name:%s mute:%d", impl,
			client->name, commands[command].name, tag, id, name, mute);

	if ((id == SPA_ID_INVALID && name == NULL) ||
	    (id != SPA_ID_INVALID && name != NULL))
		return -EINVAL;

	if (command == COMMAND_SET_SINK_MUTE)
		direction = PW_DIRECTION_OUTPUT;
	else
		direction = PW_DIRECTION_INPUT;

	o = find_device(client, id, name, direction == PW_DIRECTION_OUTPUT, &is_monitor);
	if (o == NULL || (info = o->info) == NULL || info->props == NULL)
		return -ENOENT;

	dev_info = DEVICE_INFO_INIT(direction);

	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
		dev_info.device = (uint32_t)atoi(str);
	if (card_id != SPA_ID_INVALID) {
		struct selector sel = { .id = card_id, .type = pw_manager_object_is_card, };
		card = select_object(manager, &sel);
	}
	collect_device_info(o, card, &dev_info, is_monitor);

	if (dev_info.have_volume &&
	    dev_info.volume_info.mute == mute)
		goto done;

	if (card != NULL && !is_monitor && dev_info.active_port != SPA_ID_INVALID)
		res = set_card_volume_mute_delay(card, dev_info.active_port,
				dev_info.device, NULL, &mute, NULL);
	else
		res = set_node_volume_mute(o, NULL, &mute, is_monitor);

	if (res < 0)
		return res;
done:
	return operation_new(client, tag);
}

static int do_set_port(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_node_info *info;
	uint32_t id, card_id = SPA_ID_INVALID, device_id = SPA_ID_INVALID;
	uint32_t port_id = SPA_ID_INVALID;
	const char *name, *str, *port_name;
	struct pw_manager_object *o, *card = NULL;
	int res;
	enum pw_direction direction;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_STRING, &name,
			TAG_STRING, &port_name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u index:%u name:%s port:%s", impl,
			client->name, commands[command].name, tag, id, name, port_name);

	if ((id == SPA_ID_INVALID && name == NULL) ||
	    (id != SPA_ID_INVALID && name != NULL))
		return -EINVAL;

	if (command == COMMAND_SET_SINK_PORT)
		direction = PW_DIRECTION_OUTPUT;
	else
		direction = PW_DIRECTION_INPUT;

	o = find_device(client, id, name, direction == PW_DIRECTION_OUTPUT, NULL);
	if (o == NULL || (info = o->info) == NULL || info->props == NULL)
		return -ENOENT;

	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
		device_id = (uint32_t)atoi(str);
	if (card_id != SPA_ID_INVALID) {
		struct selector sel = { .id = card_id, .type = pw_manager_object_is_card, };
		card = select_object(manager, &sel);
	}
	if (card == NULL || device_id == SPA_ID_INVALID)
		return -ENOENT;

	port_id = find_port_id(card, direction, port_name);
	if (port_id == SPA_ID_INVALID)
		return -ENOENT;

	if ((res = set_card_port(card, device_id, port_id)) < 0)
		return res;

	return operation_new(client, tag);
}

static int do_set_port_latency_offset(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	const char *port_name = NULL;
	struct pw_manager_object *card;
	struct selector sel;
	struct card_info card_info = CARD_INFO_INIT;
	struct port_info *port_info;
	int64_t offset;
	int64_t value;
	int res;
	uint32_t n_ports;
	size_t i;

	spa_zero(sel);
	sel.key = PW_KEY_DEVICE_NAME;
	sel.type = pw_manager_object_is_card;

	if ((res = message_get(m,
			TAG_U32, &sel.id,
			TAG_STRING, &sel.value,
			TAG_STRING, &port_name,
			TAG_S64, &offset,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u index:%u card_name:%s port_name:%s offset:%"PRIi64, impl,
			client->name, commands[command].name, tag, sel.id, sel.value, port_name, offset);

	if ((sel.id == SPA_ID_INVALID && sel.value == NULL) ||
	    (sel.id != SPA_ID_INVALID && sel.value != NULL))
		return -EINVAL;
	if (port_name == NULL)
		return -EINVAL;

	value = offset * 1000;  /* to nsec */

	if ((card = select_object(manager, &sel)) == NULL)
		return -ENOENT;

	collect_card_info(card, &card_info);
	port_info = alloca(card_info.n_ports * sizeof(*port_info));
	card_info.active_profile = SPA_ID_INVALID;
	n_ports = collect_port_info(card, &card_info, NULL, port_info);

	/* Set offset on all devices of the port */
	res = -ENOENT;
	for (i = 0; i < n_ports; i++) {
		struct port_info *pi = &port_info[i];
		size_t j;

		if (strcmp(pi->name, port_name) != 0)
			continue;

		res = 0;
		for (j = 0; j < pi->n_devices; ++j) {
			res = set_card_volume_mute_delay(card, pi->id, pi->devices[j], NULL, NULL, &value);
			if (res < 0)
				break;
		}

		if (res < 0)
			break;

		return operation_new(client, tag);
	}

	return res;
}

static int do_set_stream_name(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	struct stream *stream;
	const char *name = NULL;
	struct spa_dict_item items[1];
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	if (name == NULL)
		return -EINVAL;

	pw_log_info(NAME" %p: [%s] SET_STREAM_NAME tag:%u channel:%d name:%s",
			impl, client->name, tag, channel, name);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
		return -ENOENT;

	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_MEDIA_NAME, name);
	pw_stream_update_properties(stream->stream,
			&SPA_DICT_INIT(items, 1));

	return reply_simple_ack(client, tag);
}

static int do_update_proplist(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel, mode;
	struct stream *stream;
	struct pw_properties *props;
	int res;

	props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		return -errno;

	if (command != COMMAND_UPDATE_CLIENT_PROPLIST) {
		if ((res = message_get(m,
				TAG_U32, &channel,
				TAG_INVALID)) < 0)
			goto error_protocol;
	} else {
		channel = SPA_ID_INVALID;
	}

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%d", impl,
			client->name, commands[command].name, tag, channel);

	if ((res = message_get(m,
			TAG_U32, &mode,
			TAG_PROPLIST, props,
			TAG_INVALID)) < 0)
		goto error_protocol;

	if (command != COMMAND_UPDATE_CLIENT_PROPLIST) {
		stream = pw_map_lookup(&client->streams, channel);
		if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
			goto error_noentity;

		pw_stream_update_properties(stream->stream, &props->dict);
	} else {
		pw_core_update_properties(client->core, &props->dict);
	}
	res = reply_simple_ack(client, tag);
exit:
	if (props)
		pw_properties_free(props);
	return res;

error_protocol:
	res = -EPROTO;
	goto exit;
error_noentity:
	res = -ENOENT;
	goto exit;
}

static int do_remove_proplist(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t i, channel;
	struct stream *stream;
	struct pw_properties *props;
	struct spa_dict dict;
	struct spa_dict_item *items;
	int res;

	props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		return -errno;

	if (command != COMMAND_REMOVE_CLIENT_PROPLIST) {
		if ((res = message_get(m,
				TAG_U32, &channel,
				TAG_INVALID)) < 0)
			goto error_protocol;
	} else {
		channel = SPA_ID_INVALID;
	}

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%d", impl,
			client->name, commands[command].name, tag, channel);

	while (true) {
		const char *key;

		if ((res = message_get(m,
				TAG_STRING, &key,
				TAG_INVALID)) < 0)
			goto error_protocol;
		if (key == NULL)
			break;
		pw_properties_set(props, key, key);
	}

	dict.n_items = props->dict.n_items;
	dict.items = items = alloca(sizeof(struct spa_dict_item) * dict.n_items);
	for (i = 0; i < dict.n_items; i++) {
		items[i].key = props->dict.items[i].key;
		items[i].value = NULL;
	}

	if (command != COMMAND_UPDATE_CLIENT_PROPLIST) {
		stream = pw_map_lookup(&client->streams, channel);
		if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
			goto error_noentity;

		pw_stream_update_properties(stream->stream, &dict);
	} else {
		pw_core_update_properties(client->core, &dict);
	}
	res = reply_simple_ack(client, tag);
exit:
	if (props)
		pw_properties_free(props);
	return res;

error_protocol:
	res = -EPROTO;
	goto exit;
error_noentity:
	res = -ENOENT;
	goto exit;
}


static int do_get_server_info(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_core_info *info = manager->info;
	char name[256];
	const char *str;
	struct message *reply;
	uint32_t cookie;

	pw_log_info(NAME" %p: [%s] GET_SERVER_INFO tag:%u", impl, client->name, tag);


	if (info != NULL) {
		if (info->props &&
		    (str = spa_dict_lookup(info->props, "default.clock.rate")) != NULL)
			impl->defs.sample_spec.rate = atoi(str);
		cookie = info->cookie;
	} else {
		cookie = 0;
	}

	snprintf(name, sizeof(name), "PulseAudio (on PipeWire %s)", pw_get_library_version());

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_STRING, name,
		TAG_STRING, "14.0.0",
		TAG_STRING, pw_get_user_name(),
		TAG_STRING, pw_get_host_name(),
		TAG_SAMPLE_SPEC, &impl->defs.sample_spec,
		TAG_STRING, get_default(client, true),		/* default sink name */
		TAG_STRING, get_default(client, false),		/* default source name */
		TAG_U32, cookie,				/* cookie */
		TAG_INVALID);

	if (client->version >= 15) {
		message_put(reply,
			TAG_CHANNEL_MAP, &impl->defs.channel_map,
			TAG_INVALID);
	}
	return send_message(client, reply);
}

static int do_stat(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;

	pw_log_info(NAME" %p: [%s] STAT tag:%u", impl, client->name, tag);

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_U32, impl->stat.n_allocated,	/* n_allocated */
		TAG_U32, impl->stat.allocated,		/* allocated size */
		TAG_U32, impl->stat.n_accumulated,	/* n_accumulated */
		TAG_U32, impl->stat.accumulated,	/* accumulated_size */
		TAG_U32, impl->stat.sample_cache,	/* sample cache size */
		TAG_INVALID);

	return send_message(client, reply);
}

static int do_lookup(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;
	struct pw_manager_object *o;
	const char *name;
	int res;
	bool is_sink = command == COMMAND_LOOKUP_SINK;
	bool is_monitor;

	if ((res = message_get(m,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] LOOKUP tag:%u name:'%s'", impl, client->name, tag, name);

	if ((o = find_device(client, SPA_ID_INVALID, name, is_sink, &is_monitor)) == NULL)
		return -ENOENT;

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_U32, is_monitor ? o->id | MONITOR_FLAG : o->id,
		TAG_INVALID);

	return send_message(client, reply);
}

static int do_drain_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	struct stream *stream;
	int res;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] DRAIN tag:%u channel:%d", impl, client->name, tag, channel);
	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type != STREAM_TYPE_PLAYBACK)
		return -ENOENT;

	stream->drain_tag = tag;
	stream->draining = true;
	pw_stream_set_active(stream->stream, true);

	return 0;
}

static int fill_client_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_client_info *info = o->info;
	const char *str;
	uint32_t module_id = SPA_ID_INVALID;

	if (!pw_manager_object_is_client(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);

	message_put(m,
		TAG_U32, o->id,				/* client index */
		TAG_STRING, pw_properties_get(o->props, PW_KEY_APP_NAME),
		TAG_U32, module_id,			/* module */
		TAG_STRING, "PipeWire",			/* driver */
		TAG_INVALID);
	if (client->version >= 13) {
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_INVALID);
	}
	return 0;
}

static int fill_module_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_module_info *info = o->info;

	if (!pw_manager_object_is_module(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	message_put(m,
		TAG_U32, o->id,				/* module index */
		TAG_STRING, info->name,
		TAG_STRING, info->args,
		TAG_U32, -1,				/* n_used */
		TAG_INVALID);

	if (client->version < 15) {
		message_put(m,
			TAG_BOOLEAN, false,		/* auto unload deprecated */
			TAG_INVALID);
	}
	if (client->version >= 15) {
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_INVALID);
	}
	return 0;
}

static int fill_ext_module_info(struct client *client, struct message *m,
		struct module *module)
{
	message_put(m,
		TAG_U32, module->idx,			/* module index */
		TAG_STRING, module->name,
		TAG_STRING, module->args,
		TAG_U32, -1,				/* n_used */
		TAG_INVALID);

	if (client->version < 15) {
		message_put(m,
			TAG_BOOLEAN, false,		/* auto unload deprecated */
			TAG_INVALID);
	}
	if (client->version >= 15) {
		message_put(m,
			TAG_PROPLIST, module->props,
			TAG_INVALID);
	}
	return 0;
}

static int64_t get_port_latency_offset(struct client *client, struct pw_manager_object *card, struct port_info *pi)
{
	struct pw_manager *m = client->manager;
	struct pw_manager_object *o;
	size_t j;

	/*
	 * The latency offset is a property of nodes in Pipewire, so we look it up on the
	 * nodes. We'll return the latency offset of the first node in the port.
	 *
	 * This is also because we need to be consistent with
	 * send_latency_offset_subscribe_event, which sends events on node changes. The
	 * route data might not be updated yet when these events arrive.
	 */
	for (j = 0; j < pi->n_devices; ++j) {
		spa_list_for_each(o, &m->object_list, link) {
			const char *str;
			uint32_t card_id = SPA_ID_INVALID;
			uint32_t device_id = SPA_ID_INVALID;
			struct pw_node_info *info;

			if (o->creating || o->removing)
				continue;
			if (!pw_manager_object_is_sink(o) && !pw_manager_object_is_source_or_monitor(o))
				continue;
			if ((info = o->info) == NULL || info->props == NULL)
				continue;
			if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
				card_id = (uint32_t)atoi(str);
			if (card_id != card->id)
				continue;

			if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
				device_id = (uint32_t)atoi(str);

			if (device_id == pi->devices[j])
				return get_node_latency_offset(o);
		}
	}

	return 0LL;
}

static int fill_card_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_device_info *info = o->info;
	const char *str, *drv_name;
	uint32_t module_id = SPA_ID_INVALID, n_profiles, n;
	struct card_info card_info = CARD_INFO_INIT;
	struct profile_info *profile_info;

	if (!pw_manager_object_is_card(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);

	drv_name = spa_dict_lookup(info->props, PW_KEY_DEVICE_API);
	if (drv_name && !strcmp("bluez5", drv_name))
		drv_name = "module-bluez5-device.c"; /* blueman needs this */

	message_put(m,
		TAG_U32, o->id,				/* card index */
		TAG_STRING, spa_dict_lookup(info->props, PW_KEY_DEVICE_NAME),
		TAG_U32, module_id,
		TAG_STRING, drv_name,
		TAG_INVALID);

	collect_card_info(o, &card_info);

	message_put(m,
		TAG_U32, card_info.n_profiles,			/* n_profiles */
		TAG_INVALID);

	profile_info = alloca(card_info.n_profiles * sizeof(*profile_info));
	n_profiles = collect_profile_info(o, &card_info, profile_info);

	for (n = 0; n < n_profiles; n++) {
		struct profile_info *pi = &profile_info[n];

		message_put(m,
			TAG_STRING, pi->name,			/* profile name */
			TAG_STRING, pi->description,		/* profile description */
			TAG_U32, pi->n_sinks,			/* n_sinks */
			TAG_U32, pi->n_sources,			/* n_sources */
			TAG_U32, pi->priority,			/* priority */
			TAG_INVALID);

		if (client->version >= 29) {
			message_put(m,
				TAG_U32, pi->available != SPA_PARAM_AVAILABILITY_no,		/* available */
				TAG_INVALID);
		}
	}
	message_put(m,
		TAG_STRING, card_info.active_profile_name,	/* active profile name */
		TAG_PROPLIST, info->props,
		TAG_INVALID);

	if (client->version >= 26) {
		uint32_t n_ports;
		struct port_info *port_info, *pi;

		port_info = alloca(card_info.n_ports * sizeof(*port_info));
		card_info.active_profile = SPA_ID_INVALID;
		n_ports = collect_port_info(o, &card_info, NULL, port_info);

		message_put(m,
			TAG_U32, n_ports,				/* n_ports */
			TAG_INVALID);

		for (n = 0; n < n_ports; n++) {
			struct spa_dict_item *items;
			struct spa_dict *pdict = NULL, dict;
			uint32_t i, pi_n_profiles;

			pi = &port_info[n];

			if (pi->info && pi->n_props > 0) {
				items = alloca(pi->n_props * sizeof(*items));
				dict.items = items;
				pdict = collect_props(pi->info, &dict);
			}

			message_put(m,
				TAG_STRING, pi->name,			/* port name */
				TAG_STRING, pi->description,		/* port description */
				TAG_U32, pi->priority,			/* port priority */
				TAG_U32, pi->available,			/* port available */
				TAG_U8, pi->direction == SPA_DIRECTION_INPUT ? 2 : 1,	/* port direction */
				TAG_PROPLIST, pdict,			/* port proplist */
				TAG_INVALID);

			pi_n_profiles = SPA_MIN(pi->n_profiles, n_profiles);
			if (pi->n_profiles != pi_n_profiles) {
				/* libpulse assumes port profile array size <= n_profiles */
				pw_log_error(NAME" %p: card %d port %d profiles inconsistent (%d < %d)",
						client->impl, o->id, n, n_profiles, pi->n_profiles);
			}

			message_put(m,
				TAG_U32, pi_n_profiles,		/* n_profiles */
				TAG_INVALID);

			for (i = 0; i < pi_n_profiles; i++) {
				uint32_t j;
				const char *name = "off";

				for (j = 0; j < n_profiles; ++j) {
					if (profile_info[j].id == pi->profiles[i]) {
						name = profile_info[j].name;
						break;
					}
				}

				message_put(m,
					TAG_STRING, name,	/* profile name */
					TAG_INVALID);
			}
			if (client->version >= 27) {
				int64_t latency_offset = get_port_latency_offset(client, o, pi);
				message_put(m,
					TAG_S64, latency_offset / 1000,	/* port latency offset */
					TAG_INVALID);
			}
			if (client->version >= 34) {
				message_put(m,
					TAG_STRING, pi->availability_group,	/* available group */
					TAG_U32, pi->type,		/* port type */
					TAG_INVALID);
			}
		}
	}
	return 0;
}

static int fill_sink_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_node_info *info = o->info;
	struct pw_manager *manager = client->manager;
	const char *name, *desc, *str;
	char *monitor_name = NULL;
	uint32_t module_id = SPA_ID_INVALID;
	uint32_t card_id = SPA_ID_INVALID;
	struct pw_manager_object *card = NULL;
	uint32_t flags;
	struct card_info card_info = CARD_INFO_INIT;
	struct device_info dev_info = DEVICE_INFO_INIT(PW_DIRECTION_OUTPUT);
	size_t size;

	if (!pw_manager_object_is_sink(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	name = spa_dict_lookup(info->props, PW_KEY_NODE_NAME);
	if ((desc = spa_dict_lookup(info->props, PW_KEY_NODE_DESCRIPTION)) == NULL)
		desc = name ? name : "Unknown";
	if (name == NULL)
		name = "unknown";

	size = strlen(name) + 10;
	monitor_name = alloca(size);
	if (pw_manager_object_is_source(o))
		snprintf(monitor_name, size, "%s", name);
	else
		snprintf(monitor_name, size, "%s.monitor", name);

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
		dev_info.device = (uint32_t)atoi(str);
	if (card_id != SPA_ID_INVALID) {
		struct selector sel = { .id = card_id, .type = pw_manager_object_is_card, };
		card = select_object(manager, &sel);
	}
	if (card)
		collect_card_info(card, &card_info);

	collect_device_info(o, card, &dev_info, false);

	if (!sample_spec_valid(&dev_info.ss) ||
	    !channel_map_valid(&dev_info.map) ||
	    !volume_valid(&dev_info.volume_info.volume)) {
		pw_log_warn("%d: sink not ready: sample:%d map:%d volume:%d",
				o->id, sample_spec_valid(&dev_info.ss),
				channel_map_valid(&dev_info.map),
				volume_valid(&dev_info.volume_info.volume));
		return -ENOENT;
	}

	flags = SINK_LATENCY | SINK_DYNAMIC_LATENCY | SINK_DECIBEL_VOLUME;
	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_API)) != NULL)
                flags |= SINK_HARDWARE;
	if (SPA_FLAG_IS_SET(dev_info.volume_info.flags, VOLUME_HW_VOLUME))
                flags |= SINK_HW_VOLUME_CTRL;
	if (SPA_FLAG_IS_SET(dev_info.volume_info.flags, VOLUME_HW_MUTE))
                flags |= SINK_HW_MUTE_CTRL;

	message_put(m,
		TAG_U32, o->id,				/* sink index */
		TAG_STRING, name,
		TAG_STRING, desc,
		TAG_SAMPLE_SPEC, &dev_info.ss,
		TAG_CHANNEL_MAP, &dev_info.map,
		TAG_U32, module_id,			/* module index */
		TAG_CVOLUME, &dev_info.volume_info.volume,
		TAG_BOOLEAN, dev_info.volume_info.mute,
		TAG_U32, o->id | MONITOR_FLAG,		/* monitor source */
		TAG_STRING, monitor_name,		/* monitor source name */
		TAG_USEC, 0LL,				/* latency */
		TAG_STRING, "PipeWire",			/* driver */
		TAG_U32, flags,				/* flags */
		TAG_INVALID);

	if (client->version >= 13) {
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_USEC, 0LL,			/* requested latency */
			TAG_INVALID);
	}
	if (client->version >= 15) {
		message_put(m,
			TAG_VOLUME, dev_info.volume_info.base,	/* base volume */
			TAG_U32, node_state(info->state),	/* state */
			TAG_U32, dev_info.volume_info.steps,	/* n_volume_steps */
			TAG_U32, card_id,		/* card index */
			TAG_INVALID);
	}
	if (client->version >= 16) {
		uint32_t n_ports, n;
		struct port_info *port_info, *pi;

		port_info = alloca(card_info.n_ports * sizeof(*port_info));
		n_ports = collect_port_info(card, &card_info, &dev_info, port_info);

		message_put(m,
			TAG_U32, n_ports,			/* n_ports */
			TAG_INVALID);
		for (n = 0; n < n_ports; n++) {
			pi = &port_info[n];
			message_put(m,
				TAG_STRING, pi->name,		/* name */
				TAG_STRING, pi->description,	/* description */
				TAG_U32, pi->priority,		/* priority */
				TAG_INVALID);
			if (client->version >= 24) {
				message_put(m,
					TAG_U32, pi->available,		/* available */
					TAG_INVALID);
			}
			if (client->version >= 34) {
				message_put(m,
					TAG_STRING, pi->availability_group,	/* availability_group */
					TAG_U32, pi->type,			/* type */
					TAG_INVALID);
			}
		}
		message_put(m,
			TAG_STRING, dev_info.active_port_name,		/* active port name */
			TAG_INVALID);
	}
	if (client->version >= 21) {
		struct format_info info;
		spa_zero(info);
		info.encoding = ENCODING_PCM;
		message_put(m,
			TAG_U8, 1,			/* n_formats */
			TAG_FORMAT_INFO, &info,
			TAG_INVALID);
	}
	return 0;
}

static int fill_source_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_node_info *info = o->info;
	struct pw_manager *manager = client->manager;
	bool is_monitor;
	const char *name, *desc, *str;
	char *monitor_name = NULL;
	char *monitor_desc = NULL;
	uint32_t module_id = SPA_ID_INVALID;
	uint32_t card_id = SPA_ID_INVALID;
	struct pw_manager_object *card = NULL;
	uint32_t flags;
	struct card_info card_info = CARD_INFO_INIT;
	struct device_info dev_info = DEVICE_INFO_INIT(PW_DIRECTION_INPUT);
	size_t size;

	is_monitor = pw_manager_object_is_monitor(o);
	if ((!pw_manager_object_is_source(o) && !is_monitor) || info == NULL || info->props == NULL)
		return -ENOENT;

	name = spa_dict_lookup(info->props, PW_KEY_NODE_NAME);
	if ((desc = spa_dict_lookup(info->props, PW_KEY_NODE_DESCRIPTION)) == NULL)
		desc = name ? name : "Unknown";
	if (name == NULL)
		name = "unknown";

	size = strlen(name) + 10;
	monitor_name = alloca(size);
	snprintf(monitor_name, size, "%s.monitor", name);

	size = strlen(desc) + 20;
	monitor_desc = alloca(size);
	snprintf(monitor_desc, size, "Monitor of %s", desc);

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL)
		card_id = (uint32_t)atoi(str);
	if ((str = spa_dict_lookup(info->props, "card.profile.device")) != NULL)
		dev_info.device = (uint32_t)atoi(str);

	if (card_id != SPA_ID_INVALID) {
		struct selector sel = { .id = card_id, .type = pw_manager_object_is_card, };
		card = select_object(manager, &sel);
	}
	if (card)
		collect_card_info(card, &card_info);

	collect_device_info(o, card, &dev_info, is_monitor);

	if (!sample_spec_valid(&dev_info.ss) ||
	    !channel_map_valid(&dev_info.map) ||
	    !volume_valid(&dev_info.volume_info.volume)) {
		pw_log_warn("%d: source not ready: sample:%d map:%d volume:%d",
				o->id, sample_spec_valid(&dev_info.ss),
				channel_map_valid(&dev_info.map),
				volume_valid(&dev_info.volume_info.volume));
		return -ENOENT;
	}

	flags = SOURCE_LATENCY | SOURCE_DYNAMIC_LATENCY | SOURCE_DECIBEL_VOLUME;
	if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_API)) != NULL)
                flags |= SOURCE_HARDWARE;
	if (SPA_FLAG_IS_SET(dev_info.volume_info.flags, VOLUME_HW_VOLUME))
                flags |= SOURCE_HW_VOLUME_CTRL;
	if (SPA_FLAG_IS_SET(dev_info.volume_info.flags, VOLUME_HW_MUTE))
                flags |= SOURCE_HW_MUTE_CTRL;

	message_put(m,
		TAG_U32, is_monitor ? o->id | MONITOR_FLAG: o->id,	/* source index */
		TAG_STRING, is_monitor ? monitor_name : name,
		TAG_STRING, is_monitor ? monitor_desc : desc,
		TAG_SAMPLE_SPEC, &dev_info.ss,
		TAG_CHANNEL_MAP, &dev_info.map,
		TAG_U32, module_id,				/* module index */
		TAG_CVOLUME, &dev_info.volume_info.volume,
		TAG_BOOLEAN, dev_info.volume_info.mute,
		TAG_U32, is_monitor ? o->id : SPA_ID_INVALID,	/* monitor of sink */
		TAG_STRING, is_monitor ? name : NULL,		/* monitor of sink name */
		TAG_USEC, 0LL,					/* latency */
		TAG_STRING, "PipeWire",				/* driver */
		TAG_U32, flags,					/* flags */
		TAG_INVALID);

	if (client->version >= 13) {
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_USEC, 0LL,			/* requested latency */
			TAG_INVALID);
	}
	if (client->version >= 15) {
		message_put(m,
			TAG_VOLUME, dev_info.volume_info.base,	/* base volume */
			TAG_U32, node_state(info->state),	/* state */
			TAG_U32, dev_info.volume_info.steps,	/* n_volume_steps */
			TAG_U32, card_id,			/* card index */
			TAG_INVALID);
	}
	if (client->version >= 16) {
		uint32_t n_ports, n;
		struct port_info *port_info, *pi;

		port_info = alloca(card_info.n_ports * sizeof(*port_info));
		n_ports = collect_port_info(card, &card_info, &dev_info, port_info);

		message_put(m,
			TAG_U32, n_ports,			/* n_ports */
			TAG_INVALID);
		for (n = 0; n < n_ports; n++) {
			pi = &port_info[n];
			message_put(m,
				TAG_STRING, pi->name,		/* name */
				TAG_STRING, pi->description,	/* description */
				TAG_U32, pi->priority,		/* priority */
				TAG_INVALID);
			if (client->version >= 24) {
				message_put(m,
					TAG_U32, pi->available,		/* available */
					TAG_INVALID);
			}
			if (client->version >= 34) {
				message_put(m,
					TAG_STRING, pi->availability_group,	/* availability_group */
					TAG_U32, pi->type,			/* type */
					TAG_INVALID);
			}
		}
		message_put(m,
			TAG_STRING, dev_info.active_port_name,		/* active port name */
			TAG_INVALID);
	}
	if (client->version >= 21) {
		struct format_info info;
		spa_zero(info);
		info.encoding = ENCODING_PCM;
		message_put(m,
			TAG_U8, 1,			/* n_formats */
			TAG_FORMAT_INFO, &info,
			TAG_INVALID);
	}
	return 0;
}

static const char *get_media_name(struct pw_node_info *info)
{
	const char *media_name;
	media_name = spa_dict_lookup(info->props, PW_KEY_MEDIA_NAME);
	if (media_name == NULL)
		media_name = "";
	return media_name;
}

static int fill_sink_input_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_node_info *info = o->info;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *peer;
	const char *str;
	uint32_t module_id = SPA_ID_INVALID, client_id = SPA_ID_INVALID;
	struct device_info dev_info = DEVICE_INFO_INIT(PW_DIRECTION_OUTPUT);

	if (!pw_manager_object_is_sink_input(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);
	if (!pw_manager_object_is_virtual(o) &&
	    (str = spa_dict_lookup(info->props, PW_KEY_CLIENT_ID)) != NULL)
		client_id = (uint32_t)atoi(str);

	collect_device_info(o, NULL, &dev_info, false);

	if (!sample_spec_valid(&dev_info.ss) ||
	    !channel_map_valid(&dev_info.map) ||
	    !volume_valid(&dev_info.volume_info.volume))
		return -ENOENT;

	peer = find_linked(manager, o->id, PW_DIRECTION_OUTPUT);

	message_put(m,
		TAG_U32, o->id,					/* sink_input index */
		TAG_STRING, get_media_name(info),
		TAG_U32, module_id,				/* module index */
		TAG_U32, client_id,				/* client index */
		TAG_U32, peer ? peer->id : SPA_ID_INVALID,	/* sink index */
		TAG_SAMPLE_SPEC, &dev_info.ss,
		TAG_CHANNEL_MAP, &dev_info.map,
		TAG_CVOLUME, &dev_info.volume_info.volume,
		TAG_USEC, 0LL,				/* latency */
		TAG_USEC, 0LL,				/* sink latency */
		TAG_STRING, "PipeWire",			/* resample method */
		TAG_STRING, "PipeWire",			/* driver */
		TAG_INVALID);
	if (client->version >= 11)
		message_put(m,
			TAG_BOOLEAN, dev_info.volume_info.mute,	/* muted */
			TAG_INVALID);
	if (client->version >= 13)
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_INVALID);
	if (client->version >= 19)
		message_put(m,
			TAG_BOOLEAN, info->state != PW_NODE_STATE_RUNNING,		/* corked */
			TAG_INVALID);
	if (client->version >= 20)
		message_put(m,
			TAG_BOOLEAN, true,		/* has_volume */
			TAG_BOOLEAN, true,		/* volume writable */
			TAG_INVALID);
	if (client->version >= 21) {
		struct format_info fi;
		format_info_from_spec(&fi, &dev_info.ss, &dev_info.map);
		message_put(m,
			TAG_FORMAT_INFO, &fi,
			TAG_INVALID);
		format_info_clear(&fi);
	}
	return 0;
}

static int fill_source_output_info(struct client *client, struct message *m,
		struct pw_manager_object *o)
{
	struct pw_node_info *info = o->info;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *peer;
	const char *str;
	uint32_t module_id = SPA_ID_INVALID, client_id = SPA_ID_INVALID;
	uint32_t peer_id;
	struct device_info dev_info = DEVICE_INFO_INIT(PW_DIRECTION_INPUT);

	if (!pw_manager_object_is_source_output(o) || info == NULL || info->props == NULL)
		return -ENOENT;

	if ((str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID)) != NULL)
		module_id = (uint32_t)atoi(str);
	if (!pw_manager_object_is_virtual(o) &&
	    (str = spa_dict_lookup(info->props, PW_KEY_CLIENT_ID)) != NULL)
		client_id = (uint32_t)atoi(str);

	collect_device_info(o, NULL, &dev_info, false);

	if (!sample_spec_valid(&dev_info.ss) ||
	    !channel_map_valid(&dev_info.map) ||
	    !volume_valid(&dev_info.volume_info.volume))
		return -ENOENT;

	peer = find_linked(manager, o->id, PW_DIRECTION_INPUT);
	if (peer && pw_manager_object_is_source_or_monitor(peer)) {
		peer_id = peer->id;
		if (!pw_manager_object_is_source(peer))
			peer_id |= MONITOR_FLAG;
	} else {
		peer_id = SPA_ID_INVALID;
	}

	message_put(m,
		TAG_U32, o->id,					/* source_output index */
		TAG_STRING, get_media_name(info),
		TAG_U32, module_id,				/* module index */
		TAG_U32, client_id,				/* client index */
		TAG_U32, peer_id,				/* source index */
		TAG_SAMPLE_SPEC, &dev_info.ss,
		TAG_CHANNEL_MAP, &dev_info.map,
		TAG_USEC, 0LL,				/* latency */
		TAG_USEC, 0LL,				/* source latency */
		TAG_STRING, "PipeWire",			/* resample method */
		TAG_STRING, "PipeWire",			/* driver */
		TAG_INVALID);
	if (client->version >= 13)
		message_put(m,
			TAG_PROPLIST, info->props,
			TAG_INVALID);
	if (client->version >= 19)
		message_put(m,
			TAG_BOOLEAN, info->state != PW_NODE_STATE_RUNNING,		/* corked */
			TAG_INVALID);
	if (client->version >= 22) {
		struct format_info fi;
		format_info_from_spec(&fi, &dev_info.ss, &dev_info.map);
		message_put(m,
			TAG_CVOLUME, &dev_info.volume_info.volume,
			TAG_BOOLEAN, dev_info.volume_info.mute,	/* muted */
			TAG_BOOLEAN, true,		/* has_volume */
			TAG_BOOLEAN, true,		/* volume writable */
			TAG_FORMAT_INFO, &fi,
			TAG_INVALID);
		format_info_clear(&fi);
	}
	return 0;
}

static int do_get_info(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct message *reply = NULL;
	int res;
	struct pw_manager_object *o;
	struct selector sel;
	const char *def = NULL;
	int (*fill_func) (struct client *client, struct message *m, struct pw_manager_object *o) = NULL;

	spa_zero(sel);

	if ((res = message_get(m,
			TAG_U32, &sel.id,
			TAG_INVALID)) < 0)
		goto error_protocol;

	reply = reply_new(client, tag);

	if (command == COMMAND_GET_MODULE_INFO && (sel.id & MODULE_FLAG) != 0) {
		struct module *module;
		module = pw_map_lookup(&impl->modules, sel.id & INDEX_MASK);
		if (module == NULL)
			goto error_noentity;
		fill_ext_module_info(client, reply, module);
		return send_message(client, reply);
	}

	switch (command) {
	case COMMAND_GET_CLIENT_INFO:
		sel.type = pw_manager_object_is_client;
		fill_func = fill_client_info;
		break;
	case COMMAND_GET_MODULE_INFO:
		sel.type = pw_manager_object_is_module;
		fill_func = fill_module_info;
		break;
	case COMMAND_GET_CARD_INFO:
		sel.type = pw_manager_object_is_card;
		sel.key = PW_KEY_DEVICE_NAME;
		fill_func = fill_card_info;
		break;
	case COMMAND_GET_SINK_INFO:
		sel.type = pw_manager_object_is_sink;
		sel.key = PW_KEY_NODE_NAME;
		fill_func = fill_sink_info;
		def = DEFAULT_SINK;
		break;
	case COMMAND_GET_SOURCE_INFO:
		sel.type = pw_manager_object_is_source_or_monitor;
		sel.key = PW_KEY_NODE_NAME;
		fill_func = fill_source_info;
		def = DEFAULT_SOURCE;
		break;
	case COMMAND_GET_SINK_INPUT_INFO:
		sel.type = pw_manager_object_is_sink_input;
		fill_func = fill_sink_input_info;
		break;
	case COMMAND_GET_SOURCE_OUTPUT_INFO:
		sel.type = pw_manager_object_is_source_output;
		fill_func = fill_source_output_info;
		break;
	}
	if (sel.key) {
		if ((res = message_get(m,
				TAG_STRING, &sel.value,
				TAG_INVALID)) < 0)
			goto error_protocol;
	}
	if (fill_func == NULL)
		goto error_invalid;

	if (sel.id != SPA_ID_INVALID && sel.value != NULL)
		goto error_invalid;

	pw_log_info(NAME" %p: [%s] %s tag:%u idx:%u name:%s", impl, client->name,
			commands[command].name, tag, sel.id, sel.value);

	if (command == COMMAND_GET_SINK_INFO || command == COMMAND_GET_SOURCE_INFO) {
		if ((sel.value == NULL && (sel.id == SPA_ID_INVALID || sel.id == 0)) ||
		    (sel.value != NULL && (strcmp(sel.value, def) == 0 || strcmp(sel.value, "0") == 0)))
			sel.value = get_default(client, command == COMMAND_GET_SINK_INFO);
	} else {
		if (sel.value == NULL && sel.id == SPA_ID_INVALID)
			goto error_invalid;
	}

	if (command == COMMAND_GET_SOURCE_INFO &&
	    sel.value != NULL && pw_endswith(sel.value, ".monitor")) {
		sel.value = strndupa(sel.value, strlen(sel.value)-8);
	}

	o = select_object(manager, &sel);
	if (o == NULL)
		goto error_noentity;

	if ((res = fill_func(client, reply, o)) < 0)
		goto error;

	return send_message(client, reply);

error_protocol:
	res = -EPROTO;
	goto error;
error_noentity:
	res = -ENOENT;
	goto error;
error_invalid:
	res = -EINVAL;
	goto error;
error:
	if (reply)
		message_free(impl, reply, false, false);
	return res;
}

static uint64_t bytes_to_usec(uint64_t length, const struct sample_spec *ss)
{
	uint64_t u;
	uint64_t frame_size = sample_spec_frame_size(ss);
	if (frame_size == 0)
		return 0;
	u = length / frame_size;
	u *= SPA_USEC_PER_SEC;
	u /= ss->rate;
	return u;
}

static int fill_sample_info(struct client *client, struct message *m,
		struct sample *sample)
{
	struct volume vol;

	volume_make(&vol, sample->ss.channels);

	message_put(m,
		TAG_U32, sample->index,
		TAG_STRING, sample->name,
		TAG_CVOLUME, &vol,
		TAG_USEC, bytes_to_usec(sample->length, &sample->ss),
		TAG_SAMPLE_SPEC, &sample->ss,
		TAG_CHANNEL_MAP, &sample->map,
		TAG_U32, sample->length,
		TAG_BOOLEAN, false,			/* lazy */
		TAG_STRING, NULL,			/* filename */
		TAG_INVALID);

	if (client->version >= 13) {
		message_put(m,
			TAG_PROPLIST, &sample->props->dict,
			TAG_INVALID);
	}
	return 0;
}

static int do_get_sample_info(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply = NULL;
	uint32_t id;
	const char *name;
	struct sample *sample;
	int res;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	if ((id == SPA_ID_INVALID && name == NULL) ||
	    (id != SPA_ID_INVALID && name != NULL))
		return -EINVAL;

	pw_log_info(NAME" %p: [%s] %s tag:%u idx:%u name:%s", impl, client->name,
			commands[command].name, tag, id, name);

	if ((sample = find_sample(impl, id, name)) == NULL)
		return -ENOENT;

	reply = reply_new(client, tag);
	if ((res = fill_sample_info(client, reply, sample)) < 0)
		goto error;

	return send_message(client, reply);

error:
	if (reply)
		message_free(impl, reply, false, false);
	return res;
}

static int do_get_sample_info_list(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct message *reply;
	union pw_map_item *item;

	pw_log_info(NAME" %p: [%s] %s tag:%u", impl, client->name,
			commands[command].name, tag);

	reply = reply_new(client, tag);
	pw_array_for_each(item, &impl->samples.items) {
		struct sample *s = item->data;
                if (pw_map_item_is_free(item))
			continue;
		fill_sample_info(client, reply, s);
	}
	return send_message(client, reply);
}

struct info_list_data {
	struct client *client;
	struct message *reply;
	int (*fill_func) (struct client *client, struct message *m, struct pw_manager_object *o);
};

static int do_list_info(void *data, struct pw_manager_object *object)
{
	struct info_list_data *info = data;
	info->fill_func(info->client, info->reply, object);
	return 0;
}

static int do_info_list_module(void *item, void *data)
{
	struct module *m = item;
	struct info_list_data *info = data;
	fill_ext_module_info(info->client, info->reply, m);
	return 0;
}

static int do_get_info_list(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct info_list_data info;

	pw_log_info(NAME" %p: [%s] %s tag:%u", impl, client->name,
			commands[command].name, tag);

	spa_zero(info);
	info.client = client;

	switch (command) {
	case COMMAND_GET_CLIENT_INFO_LIST:
		info.fill_func = fill_client_info;
		break;
	case COMMAND_GET_MODULE_INFO_LIST:
		info.fill_func = fill_module_info;
		break;
	case COMMAND_GET_CARD_INFO_LIST:
		info.fill_func = fill_card_info;
		break;
	case COMMAND_GET_SINK_INFO_LIST:
		info.fill_func = fill_sink_info;
		break;
	case COMMAND_GET_SOURCE_INFO_LIST:
		info.fill_func = fill_source_info;
		break;
	case COMMAND_GET_SINK_INPUT_INFO_LIST:
		info.fill_func = fill_sink_input_info;
		break;
	case COMMAND_GET_SOURCE_OUTPUT_INFO_LIST:
		info.fill_func = fill_source_output_info;
		break;
	default:
		return -ENOTSUP;
	}

	info.reply = reply_new(client, tag);
	if (info.fill_func)
		pw_manager_for_each_object(manager, do_list_info, &info);

	if (command == COMMAND_GET_MODULE_INFO_LIST)
		pw_map_for_each(&impl->modules, do_info_list_module, &info);

	return send_message(client, info.reply);
}

static int do_set_stream_buffer_attr(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel;
	struct stream *stream;
	struct message *reply;
	struct buffer_attr attr;
	int res;
	bool adjust_latency = false, early_requests = false;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u channel:%u", impl, client->name,
			commands[command].name, tag, channel);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL)
		return -ENOENT;

	if (command == COMMAND_SET_PLAYBACK_STREAM_BUFFER_ATTR) {
		if (stream->type != STREAM_TYPE_PLAYBACK)
			return -ENOENT;

		if ((res = message_get(m,
				TAG_U32, &attr.maxlength,
				TAG_U32, &attr.tlength,
				TAG_U32, &attr.prebuf,
				TAG_U32, &attr.minreq,
				TAG_INVALID)) < 0)
			return -EPROTO;
	} else {
		if (stream->type != STREAM_TYPE_RECORD)
			return -ENOENT;

		if ((res = message_get(m,
				TAG_U32, &attr.maxlength,
				TAG_U32, &attr.fragsize,
				TAG_INVALID)) < 0)
			return -EPROTO;
	}
	if (client->version >= 13) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &adjust_latency,
				TAG_INVALID)) < 0)
			return -EPROTO;
	}
	if (client->version >= 14) {
		if ((res = message_get(m,
				TAG_BOOLEAN, &early_requests,
				TAG_INVALID)) < 0)
			return -EPROTO;
	}

	reply = reply_new(client, tag);

	if (command == COMMAND_SET_PLAYBACK_STREAM_BUFFER_ATTR) {
		message_put(reply,
			TAG_U32, stream->attr.maxlength,
			TAG_U32, stream->attr.tlength,
			TAG_U32, stream->attr.prebuf,
			TAG_U32, stream->attr.minreq,
			TAG_INVALID);
		if (client->version >= 13) {
			message_put(reply,
				TAG_USEC, 0,		/* configured_sink_latency */
				TAG_INVALID);
		}
	} else {
		message_put(reply,
			TAG_U32, stream->attr.maxlength,
			TAG_U32, stream->attr.fragsize,
			TAG_INVALID);
		if (client->version >= 13) {
			message_put(reply,
				TAG_USEC, 0,		/* configured_source_latency */
				TAG_INVALID);
		}
	}
	return send_message(client, reply);
}

static int do_update_stream_sample_rate(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t channel, rate;
	struct stream *stream;
	int res;
	bool match;

	if ((res = message_get(m,
			TAG_U32, &channel,
			TAG_U32, &rate,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_warn(NAME" %p: [%s] %s tag:%u channel:%u rate:%u", impl, client->name,
			commands[command].name, tag, channel, rate);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type == STREAM_TYPE_UPLOAD)
		return -ENOENT;

	if (stream->rate_match == NULL)
		return -ENOTSUP;

	match = rate != stream->ss.rate;
	stream->rate = rate;
	stream->rate_match->rate = match ?
			(double)rate/(double)stream->ss.rate : 1.0;
	SPA_FLAG_UPDATE(stream->rate_match->flags,
			SPA_IO_RATE_MATCH_FLAG_ACTIVE, match);

	return reply_simple_ack(client, tag);
}

static int do_extension(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t idx;
	const char *name;
	struct extension *ext;
	int res;

	if ((res = message_get(m,
			TAG_U32, &idx,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u id:%u name:%s", impl, client->name,
			commands[command].name, tag, idx, name);

	if ((idx == SPA_ID_INVALID && name == NULL) ||
	    (idx != SPA_ID_INVALID && name != NULL))
		return -EINVAL;

	ext = find_extension(idx, name);
	if (ext == NULL)
		return -ENOENT;

	return ext->process(client, tag, m);
}

static int do_set_profile(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *o;
	const char *profile_name;
	uint32_t profile_id = SPA_ID_INVALID;
	int res;
	struct selector sel;
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));

	spa_zero(sel);
	sel.key = PW_KEY_DEVICE_NAME;
	sel.type = pw_manager_object_is_card;

	if ((res = message_get(m,
			TAG_U32, &sel.id,
			TAG_STRING, &sel.value,
			TAG_STRING, &profile_name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u id:%u name:%s profile:%s", impl, client->name,
			commands[command].name, tag, sel.id, sel.value, profile_name);

	if ((sel.id == SPA_ID_INVALID && sel.value == NULL) ||
	    (sel.id != SPA_ID_INVALID && sel.value != NULL))
		return -EINVAL;
	if (profile_name == NULL)
		return -EINVAL;

	if ((o = select_object(manager, &sel)) == NULL)
		return -ENOENT;

	if ((profile_id = find_profile_id(o, profile_name)) == SPA_ID_INVALID)
		return -ENOENT;

	if (!SPA_FLAG_IS_SET(o->permissions, PW_PERM_W | PW_PERM_X))
		return -EACCES;

	if (o->proxy == NULL)
		return -ENOENT;

        pw_device_set_param((struct pw_device*)o->proxy,
                        SPA_PARAM_Profile, 0,
                        spa_pod_builder_add_object(&b,
                                SPA_TYPE_OBJECT_ParamProfile, SPA_PARAM_Profile,
                                SPA_PARAM_PROFILE_index, SPA_POD_Int(profile_id),
                                SPA_PARAM_PROFILE_save, SPA_POD_Bool(true)));

	return operation_new(client, tag);
}

static int do_set_default(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *o;
	const char *name, *str;
	int res;
	bool sink = command == COMMAND_SET_DEFAULT_SINK;

	if ((res = message_get(m,
			TAG_STRING, &name,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u name:%s", impl, client->name,
			commands[command].name, tag, name);

	if (name != NULL && (o = find_device(client, SPA_ID_INVALID, name, sink, NULL)) == NULL)
		return -ENOENT;

	if (name != NULL) {
		if (o->props && (str = pw_properties_get(o->props, PW_KEY_NODE_NAME)) != NULL)
			name = str;
		else if (pw_endswith(name, ".monitor"))
			name = strndupa(name, strlen(name)-8);

		res = pw_manager_set_metadata(manager, client->metadata_default,
				PW_ID_CORE,
				sink ? METADATA_CONFIG_DEFAULT_SINK : METADATA_CONFIG_DEFAULT_SOURCE,
				"Spa:String:JSON", "{ \"name\": \"%s\" }", name);
	} else {
		res = pw_manager_set_metadata(manager, client->metadata_default,
				PW_ID_CORE,
				sink ? METADATA_CONFIG_DEFAULT_SINK : METADATA_CONFIG_DEFAULT_SOURCE,
				NULL, NULL);
	}
	if (res < 0)
		return res;

	return operation_new(client, tag);
}

static int do_suspend(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager_object *o;
	const char *name;
	int res;
	uint32_t id, cmd;;
	bool sink = command == COMMAND_SUSPEND_SINK, suspend;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_STRING, &name,
			TAG_BOOLEAN, &suspend,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u id:%u name:%s", impl, client->name,
			commands[command].name, tag, id, name);

	if ((o = find_device(client, id, name, sink, NULL)) == NULL)
		return -ENOENT;

	if (o->proxy == NULL)
		return -ENOENT;

	if (suspend) {
		cmd = SPA_NODE_COMMAND_Suspend;
		pw_node_send_command((struct pw_node*)o->proxy, &SPA_NODE_COMMAND_INIT(cmd));
	}
	return operation_new(client, tag);
}

static int do_move_stream(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *o, *dev, *dev_default;
	uint32_t id, id_device;
	const char *name_device;
	struct selector sel;
	int res;
	bool sink = command == COMMAND_MOVE_SINK_INPUT;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_U32, &id_device,
			TAG_STRING, &name_device,
			TAG_INVALID)) < 0)
		return -EPROTO;

	if ((id_device == SPA_ID_INVALID && name_device == NULL) ||
	    (id_device != SPA_ID_INVALID && name_device != NULL))
		return -EINVAL;

	pw_log_info(NAME" %p: [%s] %s tag:%u idx:%u device:%d name:%s", impl, client->name,
			commands[command].name, tag, id, id_device, name_device);

	spa_zero(sel);
	sel.id = id;
	sel.type = sink ? pw_manager_object_is_sink_input: pw_manager_object_is_source_output;

	o = select_object(manager, &sel);
	if (o == NULL)
		return -ENOENT;

	if ((dev = find_device(client, id_device, name_device, sink, NULL)) == NULL)
		return -ENOENT;

	if ((res = pw_manager_set_metadata(manager, client->metadata_default,
			o->id,
			METADATA_TARGET_NODE,
			SPA_TYPE_INFO_BASE"Id", "%d", dev->id)) < 0)
		return res;

	dev_default = find_device(client, SPA_ID_INVALID, NULL, sink, NULL);
	if (dev == dev_default) {
		/*
		 * When moving streams to a node that is equal to the default,
		 * Pulseaudio understands this to mean '... and unset preferred sink/source',
		 * forgetting target.node. Follow that behavior here.
		 *
		 * XXX: We set target.node key above regardless, to make policy-node
		 * XXX: to always see the unset event. The metadata is currently not
		 * XXX: always set when the node has explicit target.
		 */
		if ((res = pw_manager_set_metadata(manager, client->metadata_default,
				o->id,
				METADATA_TARGET_NODE,
				NULL, NULL)) < 0)
			return res;
	}

	return reply_simple_ack(client, tag);
}

static int do_kill(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	struct pw_manager_object *o;
	uint32_t id;
	struct selector sel;
	int res;

	if ((res = message_get(m,
			TAG_U32, &id,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u id:%u", impl, client->name,
			commands[command].name, tag, id);

	spa_zero(sel);
	sel.id = id;
	switch (command) {
	case COMMAND_KILL_CLIENT:
		sel.type = pw_manager_object_is_client;
		break;
	case COMMAND_KILL_SINK_INPUT:
		sel.type = pw_manager_object_is_sink_input;
		break;
	case COMMAND_KILL_SOURCE_OUTPUT:
		sel.type = pw_manager_object_is_source_output;
		break;
	default:
		return -EINVAL;
	}

	if ((o = select_object(manager, &sel)) == NULL)
		return -ENOENT;

	pw_registry_destroy(manager->registry, o->id);

	return reply_simple_ack(client, tag);
}

struct load_module_data {
	struct spa_list link;
	struct client *client;
	struct module *module;
	struct spa_hook listener;
	uint32_t tag;
};

static struct load_module_data *load_module_data_new(struct client *client, uint32_t tag)
{
	struct load_module_data *data = calloc(1, sizeof(struct load_module_data));
	data->client = client;
	data->tag = tag;
	return data;
}

static void load_module_data_free(struct load_module_data *d)
{
	spa_hook_remove(&d->listener);
	free(d);
}

static void on_module_loaded(void *data, int error)
{
	struct load_module_data *d = data;
	struct module *module = d->module;
	struct impl *impl = module->impl;
	struct message *reply;
	struct client *client;
	uint32_t tag;

	client = d->client;
	tag = d->tag;
	load_module_data_free(d);

	if (error < 0) {
		pw_log_warn(NAME" %p: [%s] error loading module", client->impl, client->name);
		reply_error(client, COMMAND_LOAD_MODULE, tag, error);
		return;
	}

	pw_log_info(NAME" %p: [%s] module %d loaded", client->impl, client->name, module->idx);

	broadcast_subscribe_event(impl,
			SUBSCRIPTION_MASK_MODULE,
			SUBSCRIPTION_EVENT_NEW | SUBSCRIPTION_EVENT_MODULE,
			module->idx);

	reply = reply_new(client, tag);
	message_put(reply,
		TAG_U32, module->idx,
		TAG_INVALID);
	send_message(client, reply);
}

static int do_load_module(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct module *module;
	struct impl *impl = client->impl;
	struct load_module_data *d;
	const char *name, *argument;
	int res;
	static struct module_events listener = {
		VERSION_MODULE_EVENTS,
		.loaded = on_module_loaded,
	};

	if ((res = message_get(m,
			TAG_STRING, &name,
			TAG_STRING, &argument,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s name:%s argument:%s", impl,
			client->name, commands[command].name, name, argument);

	module = create_module(client, name, argument);
	if (module == NULL)
		return -errno;

	d = load_module_data_new(client, tag);
	d->module = module;
	module_add_listener(module, &d->listener, &listener, d);

	return module_load(client, module);
}

static int do_unload_module(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct module *module;
	uint32_t module_idx;
	int res;

	if ((res = message_get(m,
			TAG_U32, &module_idx,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u id:%u", impl, client->name,
			commands[command].name, tag, module_idx);

	if (module_idx == SPA_ID_INVALID)
		return -EINVAL;
	if ((module_idx & MODULE_FLAG) == 0)
		return -EPERM;

	module = pw_map_lookup(&impl->modules, module_idx & INDEX_MASK);
	if (module == NULL)
		return -ENOENT;

	module_unload(client, module);

	return reply_simple_ack(client, tag);
}

static int do_send_object_message(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	struct pw_manager *manager = client->manager;
	const char *object_path = NULL;
	const char *message = NULL;
	const char *params = NULL;
	char *response = NULL;
	char *path = NULL;
	struct message *reply;
	struct pw_manager_object *o;
	int len = 0;
	int res;

	if ((res = message_get(m,
			TAG_STRING, &object_path,
			TAG_STRING, &message,
			TAG_STRING, &params,
			TAG_INVALID)) < 0)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] %s tag:%u object_path:'%s' message:'%s' params:'%s'", impl,
			client->name, commands[command].name, tag, object_path,
			message, params ? params : "<null>");

	if (object_path == NULL || message == NULL)
		return -EINVAL;

	len = strlen(object_path);
	if (len > 0 && object_path[len - 1] == '/')
		--len;
	path = strndup(object_path, len);
	if (path == NULL)
		return -ENOMEM;

	res = -ENOENT;

	spa_list_for_each(o, &manager->object_list, link) {
		if (o->message_object_path && strcmp(o->message_object_path, path) == 0) {
			if (o->message_handler)
				res = o->message_handler(manager, o, message, params, &response);
			else
				res = -ENOSYS;
			break;
		}
	}

	free(path);
	if (res < 0)
		return res;

	pw_log_debug(NAME" %p: object message response:'%s'", impl, response ? response : "<null>");

	reply = reply_new(client, tag);
	message_put(reply, TAG_STRING, response, TAG_INVALID);
	free(response);
	return send_message(client, reply);
}

static int do_error_access(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	return -EACCES;
}

static SPA_UNUSED int do_error_not_implemented(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	return -ENOSYS;
}

static const struct command commands[COMMAND_MAX] =
{
	[COMMAND_ERROR] = { "ERROR", },
	[COMMAND_TIMEOUT] = { "TIMEOUT", }, /* pseudo command */
	[COMMAND_REPLY] = { "REPLY", },

	/* CLIENT->SERVER */
	[COMMAND_CREATE_PLAYBACK_STREAM] = { "CREATE_PLAYBACK_STREAM", do_create_playback_stream, },
	[COMMAND_DELETE_PLAYBACK_STREAM] = { "DELETE_PLAYBACK_STREAM", do_delete_stream, },
	[COMMAND_CREATE_RECORD_STREAM] = { "CREATE_RECORD_STREAM", do_create_record_stream, },
	[COMMAND_DELETE_RECORD_STREAM] = { "DELETE_RECORD_STREAM", do_delete_stream, },
	[COMMAND_EXIT] = { "EXIT", do_error_access },
	[COMMAND_AUTH] = { "AUTH", do_command_auth, },
	[COMMAND_SET_CLIENT_NAME] = { "SET_CLIENT_NAME", do_set_client_name, },
	[COMMAND_LOOKUP_SINK] = { "LOOKUP_SINK", do_lookup, },
	[COMMAND_LOOKUP_SOURCE] = { "LOOKUP_SOURCE", do_lookup, },
	[COMMAND_DRAIN_PLAYBACK_STREAM] = { "DRAIN_PLAYBACK_STREAM", do_drain_stream, },
	[COMMAND_STAT] = { "STAT", do_stat, },
	[COMMAND_GET_PLAYBACK_LATENCY] = { "GET_PLAYBACK_LATENCY", do_get_playback_latency, },
	[COMMAND_CREATE_UPLOAD_STREAM] = { "CREATE_UPLOAD_STREAM", do_create_upload_stream, },
	[COMMAND_DELETE_UPLOAD_STREAM] = { "DELETE_UPLOAD_STREAM", do_delete_stream, },
	[COMMAND_FINISH_UPLOAD_STREAM] = { "FINISH_UPLOAD_STREAM", do_finish_upload_stream, },
	[COMMAND_PLAY_SAMPLE] = { "PLAY_SAMPLE", do_play_sample, },
	[COMMAND_REMOVE_SAMPLE] = { "REMOVE_SAMPLE", do_remove_sample, },

	[COMMAND_GET_SERVER_INFO] = { "GET_SERVER_INFO", do_get_server_info },
	[COMMAND_GET_SINK_INFO] = { "GET_SINK_INFO", do_get_info, },
	[COMMAND_GET_SOURCE_INFO] = { "GET_SOURCE_INFO", do_get_info, },
	[COMMAND_GET_MODULE_INFO] = { "GET_MODULE_INFO", do_get_info, },
	[COMMAND_GET_CLIENT_INFO] = { "GET_CLIENT_INFO", do_get_info, },
	[COMMAND_GET_SINK_INPUT_INFO] = { "GET_SINK_INPUT_INFO", do_get_info, },
	[COMMAND_GET_SOURCE_OUTPUT_INFO] = { "GET_SOURCE_OUTPUT_INFO", do_get_info, },
	[COMMAND_GET_SAMPLE_INFO] = { "GET_SAMPLE_INFO", do_get_sample_info, },
	[COMMAND_GET_CARD_INFO] = { "GET_CARD_INFO", do_get_info, },
	[COMMAND_SUBSCRIBE] = { "SUBSCRIBE", do_subscribe, },

	[COMMAND_GET_SINK_INFO_LIST] = { "GET_SINK_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_SOURCE_INFO_LIST] = { "GET_SOURCE_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_MODULE_INFO_LIST] = { "GET_MODULE_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_CLIENT_INFO_LIST] = { "GET_CLIENT_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_SINK_INPUT_INFO_LIST] = { "GET_SINK_INPUT_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_SOURCE_OUTPUT_INFO_LIST] = { "GET_SOURCE_OUTPUT_INFO_LIST", do_get_info_list, },
	[COMMAND_GET_SAMPLE_INFO_LIST] = { "GET_SAMPLE_INFO_LIST", do_get_sample_info_list, },
	[COMMAND_GET_CARD_INFO_LIST] = { "GET_CARD_INFO_LIST", do_get_info_list, },

	[COMMAND_SET_SINK_VOLUME] = { "SET_SINK_VOLUME", do_set_volume, },
	[COMMAND_SET_SINK_INPUT_VOLUME] = { "SET_SINK_INPUT_VOLUME", do_set_stream_volume, },
	[COMMAND_SET_SOURCE_VOLUME] = { "SET_SOURCE_VOLUME", do_set_volume, },

	[COMMAND_SET_SINK_MUTE] = { "SET_SINK_MUTE", do_set_mute, },
	[COMMAND_SET_SOURCE_MUTE] = { "SET_SOURCE_MUTE", do_set_mute, },

	[COMMAND_CORK_PLAYBACK_STREAM] = { "CORK_PLAYBACK_STREAM", do_cork_stream, },
	[COMMAND_FLUSH_PLAYBACK_STREAM] = { "FLUSH_PLAYBACK_STREAM", do_flush_trigger_prebuf_stream, },
	[COMMAND_TRIGGER_PLAYBACK_STREAM] = { "TRIGGER_PLAYBACK_STREAM", do_flush_trigger_prebuf_stream, },
	[COMMAND_PREBUF_PLAYBACK_STREAM] = { "PREBUF_PLAYBACK_STREAM", do_flush_trigger_prebuf_stream, },

	[COMMAND_SET_DEFAULT_SINK] = { "SET_DEFAULT_SINK", do_set_default, },
	[COMMAND_SET_DEFAULT_SOURCE] = { "SET_DEFAULT_SOURCE", do_set_default, },

	[COMMAND_SET_PLAYBACK_STREAM_NAME] = { "SET_PLAYBACK_STREAM_NAME", do_set_stream_name, },
	[COMMAND_SET_RECORD_STREAM_NAME] = { "SET_RECORD_STREAM_NAME", do_set_stream_name, },

	[COMMAND_KILL_CLIENT] = { "KILL_CLIENT", do_kill, },
	[COMMAND_KILL_SINK_INPUT] = { "KILL_SINK_INPUT", do_kill, },
	[COMMAND_KILL_SOURCE_OUTPUT] = { "KILL_SOURCE_OUTPUT", do_kill, },

	[COMMAND_LOAD_MODULE] = { "LOAD_MODULE", do_load_module, },
	[COMMAND_UNLOAD_MODULE] = { "UNLOAD_MODULE", do_unload_module, },

	/* Obsolete */
	[COMMAND_ADD_AUTOLOAD___OBSOLETE] = { "ADD_AUTOLOAD___OBSOLETE", do_error_access, },
	[COMMAND_REMOVE_AUTOLOAD___OBSOLETE] = { "REMOVE_AUTOLOAD___OBSOLETE", do_error_access, },
	[COMMAND_GET_AUTOLOAD_INFO___OBSOLETE] = { "GET_AUTOLOAD_INFO___OBSOLETE", do_error_access, },
	[COMMAND_GET_AUTOLOAD_INFO_LIST___OBSOLETE] = { "GET_AUTOLOAD_INFO_LIST___OBSOLETE", do_error_access, },

	[COMMAND_GET_RECORD_LATENCY] = { "GET_RECORD_LATENCY", do_get_record_latency, },
	[COMMAND_CORK_RECORD_STREAM] = { "CORK_RECORD_STREAM", do_cork_stream, },
	[COMMAND_FLUSH_RECORD_STREAM] = { "FLUSH_RECORD_STREAM", do_flush_trigger_prebuf_stream, },

	/* SERVER->CLIENT */
	[COMMAND_REQUEST] = { "REQUEST", },
	[COMMAND_OVERFLOW] = { "OVERFLOW", },
	[COMMAND_UNDERFLOW] = { "UNDERFLOW", },
	[COMMAND_PLAYBACK_STREAM_KILLED] = { "PLAYBACK_STREAM_KILLED", },
	[COMMAND_RECORD_STREAM_KILLED] = { "RECORD_STREAM_KILLED", },
	[COMMAND_SUBSCRIBE_EVENT] = { "SUBSCRIBE_EVENT", },

	/* A few more client->server commands */

	/* Supported since protocol v10 (0.9.5) */
	[COMMAND_MOVE_SINK_INPUT] = { "MOVE_SINK_INPUT", do_move_stream, },
	[COMMAND_MOVE_SOURCE_OUTPUT] = { "MOVE_SOURCE_OUTPUT", do_move_stream, },

	/* Supported since protocol v11 (0.9.7) */
	[COMMAND_SET_SINK_INPUT_MUTE] = { "SET_SINK_INPUT_MUTE", do_set_stream_mute, },

	[COMMAND_SUSPEND_SINK] = { "SUSPEND_SINK", do_suspend, },
	[COMMAND_SUSPEND_SOURCE] = { "SUSPEND_SOURCE", do_suspend, },

	/* Supported since protocol v12 (0.9.8) */
	[COMMAND_SET_PLAYBACK_STREAM_BUFFER_ATTR] = { "SET_PLAYBACK_STREAM_BUFFER_ATTR", do_set_stream_buffer_attr, },
	[COMMAND_SET_RECORD_STREAM_BUFFER_ATTR] = { "SET_RECORD_STREAM_BUFFER_ATTR", do_set_stream_buffer_attr, },

	[COMMAND_UPDATE_PLAYBACK_STREAM_SAMPLE_RATE] = { "UPDATE_PLAYBACK_STREAM_SAMPLE_RATE", do_update_stream_sample_rate, },
	[COMMAND_UPDATE_RECORD_STREAM_SAMPLE_RATE] = { "UPDATE_RECORD_STREAM_SAMPLE_RATE", do_update_stream_sample_rate, },

	/* SERVER->CLIENT */
	[COMMAND_PLAYBACK_STREAM_SUSPENDED] = { "PLAYBACK_STREAM_SUSPENDED", },
	[COMMAND_RECORD_STREAM_SUSPENDED] = { "RECORD_STREAM_SUSPENDED", },
	[COMMAND_PLAYBACK_STREAM_MOVED] = { "PLAYBACK_STREAM_MOVED", },
	[COMMAND_RECORD_STREAM_MOVED] = { "RECORD_STREAM_MOVED", },

	/* Supported since protocol v13 (0.9.11) */
	[COMMAND_UPDATE_RECORD_STREAM_PROPLIST] = { "UPDATE_RECORD_STREAM_PROPLIST", do_update_proplist, },
	[COMMAND_UPDATE_PLAYBACK_STREAM_PROPLIST] = { "UPDATE_PLAYBACK_STREAM_PROPLIST", do_update_proplist, },
	[COMMAND_UPDATE_CLIENT_PROPLIST] = { "UPDATE_CLIENT_PROPLIST", do_update_proplist, },

	[COMMAND_REMOVE_RECORD_STREAM_PROPLIST] = { "REMOVE_RECORD_STREAM_PROPLIST", do_remove_proplist, },
	[COMMAND_REMOVE_PLAYBACK_STREAM_PROPLIST] = { "REMOVE_PLAYBACK_STREAM_PROPLIST", do_remove_proplist, },
	[COMMAND_REMOVE_CLIENT_PROPLIST] = { "REMOVE_CLIENT_PROPLIST", do_remove_proplist, },

	/* SERVER->CLIENT */
	[COMMAND_STARTED] = { "STARTED", },

	/* Supported since protocol v14 (0.9.12) */
	[COMMAND_EXTENSION] = { "EXTENSION", do_extension, },
	/* Supported since protocol v15 (0.9.15) */
	[COMMAND_SET_CARD_PROFILE] = { "SET_CARD_PROFILE", do_set_profile, },

	/* SERVER->CLIENT */
	[COMMAND_CLIENT_EVENT] = { "CLIENT_EVENT", },
	[COMMAND_PLAYBACK_STREAM_EVENT] = { "PLAYBACK_STREAM_EVENT", },
	[COMMAND_RECORD_STREAM_EVENT] = { "RECORD_STREAM_EVENT", },

	/* SERVER->CLIENT */
	[COMMAND_PLAYBACK_BUFFER_ATTR_CHANGED] = { "PLAYBACK_BUFFER_ATTR_CHANGED", },
	[COMMAND_RECORD_BUFFER_ATTR_CHANGED] = { "RECORD_BUFFER_ATTR_CHANGED", },

	/* Supported since protocol v16 (0.9.16) */
	[COMMAND_SET_SINK_PORT] = { "SET_SINK_PORT", do_set_port, },
	[COMMAND_SET_SOURCE_PORT] = { "SET_SOURCE_PORT", do_set_port, },

	/* Supported since protocol v22 (1.0) */
	[COMMAND_SET_SOURCE_OUTPUT_VOLUME] = { "SET_SOURCE_OUTPUT_VOLUME",  do_set_stream_volume, },
	[COMMAND_SET_SOURCE_OUTPUT_MUTE] = { "SET_SOURCE_OUTPUT_MUTE",  do_set_stream_mute, },

	/* Supported since protocol v27 (3.0) */
	[COMMAND_SET_PORT_LATENCY_OFFSET] = { "SET_PORT_LATENCY_OFFSET", do_set_port_latency_offset, },

	/* Supported since protocol v30 (6.0) */
	/* BOTH DIRECTIONS */
	[COMMAND_ENABLE_SRBCHANNEL] = { "ENABLE_SRBCHANNEL", do_error_access, },
	[COMMAND_DISABLE_SRBCHANNEL] = { "DISABLE_SRBCHANNEL", do_error_access, },

	/* Supported since protocol v31 (9.0)
	 * BOTH DIRECTIONS */
	[COMMAND_REGISTER_MEMFD_SHMID] = { "REGISTER_MEMFD_SHMID", do_error_access, },

	/* Supported since protocol v35 (15.0) */
	[COMMAND_SEND_OBJECT_MESSAGE] = { "SEND_OBJECT_MESSAGE", do_send_object_message, },
};

static int client_free_stream(void *item, void *data)
{
	struct stream *s = item;
	stream_free(s);
	return 0;
}

static void client_disconnect(struct client *client)
{
	struct impl *impl = client->impl;

	if (client->disconnect)
		return;

	client->disconnect = true;
	spa_list_remove(&client->link);
	spa_list_append(&impl->cleanup_clients, &client->link);

	pw_map_for_each(&client->streams, client_free_stream, client);

	if (client->source)
		pw_loop_destroy_source(impl->loop, client->source);
	if (client->manager)
		pw_manager_destroy(client->manager);
}

static void client_free(struct client *client)
{
	struct impl *impl = client->impl;
	struct message *msg;
	struct pending_sample *p;
	struct operation *o;

	pw_log_info(NAME" %p: client %p free", impl, client);

	client_disconnect(client);

	spa_list_remove(&client->link);

	spa_list_consume(p, &client->pending_samples, link)
		pending_sample_free(p);

	spa_list_consume(msg, &client->out_messages, link)
		message_free(impl, msg, true, false);

	spa_list_consume(o, &client->operations, link)
		operation_free(o);

	if (client->core) {
		client->disconnecting = true;
		pw_core_disconnect(client->core);
	}
	pw_map_clear(&client->streams);
	free(client->default_sink);
	free(client->default_source);
	if (client->props)
		pw_properties_free(client->props);
	if (client->routes)
		pw_properties_free(client->routes);
	free(client);
}

static void client_unref(struct client *client)
{
	if (--client->ref == 0)
		client_free(client);
}

static int handle_packet(struct client *client, struct message *msg)
{
	struct impl *impl = client->impl;
	int res = 0;
	uint32_t command, tag;

	if (message_get(msg,
			TAG_U32, &command,
			TAG_U32, &tag,
			TAG_INVALID) < 0) {
		res = -EPROTO;
		goto finish;
	}

	pw_log_debug(NAME" %p: Received packet command %u tag %u",
			impl, command, tag);

	if (command >= COMMAND_MAX) {
		res = -EINVAL;
		goto finish;
	}

	if (debug_messages) {
		pw_log_debug(NAME" %p: command %s", impl, commands[command].name);
		message_dump(SPA_LOG_LEVEL_INFO, msg);
	}

	if (commands[command].run == NULL) {
		res = -ENOTSUP;
		goto finish;
	}

	res = commands[command].run(client, command, tag, msg);
finish:
	message_free(impl, msg, false, false);
	if (res < 0)
		reply_error(client, command, tag, res);
	return 0;
}

static int handle_memblock(struct client *client, struct message *msg)
{
	struct impl *impl = client->impl;
	struct stream *stream;
	uint32_t channel, flags, index;
	int64_t offset;
	int32_t filled, diff;
	int res = 0;

	channel = ntohl(client->desc.channel);
	offset = (int64_t) (
             (((uint64_t) ntohl(client->desc.offset_hi)) << 32) |
             (((uint64_t) ntohl(client->desc.offset_lo))));
	flags = ntohl(client->desc.flags);

	pw_log_debug(NAME" %p: Received memblock channel:%d offset:%"PRIi64
			" flags:%08x size:%u", impl, channel, offset,
			flags, msg->length);

	stream = pw_map_lookup(&client->streams, channel);
	if (stream == NULL || stream->type == STREAM_TYPE_RECORD) {
		res = -EINVAL;
		goto finish;
	}

	filled = spa_ringbuffer_get_write_index(&stream->ring, &index);
	pw_log_debug("new block %p %p/%u filled:%d index:%d flags:%02x offset:%"PRIu64,
			msg, msg->data, msg->length, filled, index, flags, offset);


	switch (flags & FLAG_SEEKMASK) {
	case SEEK_RELATIVE:
		index += offset;
		filled += offset;
		stream->missing -= offset;
		break;
	case SEEK_ABSOLUTE:
		diff = (int32_t)(offset - (uint64_t)index);
		index += diff;
		filled += diff;
		stream->missing -= diff;
		break;
	case SEEK_RELATIVE_ON_READ:
	case SEEK_RELATIVE_END:
		diff = (int32_t)(offset - (uint64_t)filled);
		index += diff;
		filled += diff;
		stream->missing -= diff;
		break;
	}

	if (filled < 0) {
		/* underrun, reported on reader side */
	} else if (filled + msg->length > stream->attr.maxlength) {
		/* overrun */
		send_overflow(stream);
	}

	/* always write data to ringbuffer, we expect the other side
	 * to recover */
	spa_ringbuffer_write_data(&stream->ring,
			stream->buffer, stream->attr.maxlength,
			index % stream->attr.maxlength,
			msg->data,
			SPA_MIN(msg->length, stream->attr.maxlength));
	stream->write_index = index + msg->length;
	spa_ringbuffer_write_update(&stream->ring, stream->write_index);
	stream->requested -= msg->length;
finish:
	message_free(impl, msg, false, false);
	return res;
}

static int do_read(struct client *client)
{
	struct impl *impl = client->impl;
	void *data;
	size_t size;
	ssize_t r;
	int res = 0;

	if (client->in_index < sizeof(client->desc)) {
		data = SPA_MEMBER(&client->desc, client->in_index, void);
		size = sizeof(client->desc) - client->in_index;
	} else {
		uint32_t idx = client->in_index - sizeof(client->desc);

		if (client->message == NULL) {
			res = -EIO;
			goto exit;
		}
		data = SPA_MEMBER(client->message->data, idx, void);
		size = client->message->length - idx;
	}
	while (true) {
		r = recv(client->source->fd, data, size, MSG_DONTWAIT);
		if (r == 0 && size != 0) {
			res = -EPIPE;
			goto exit;
		} else if (r < 0) {
			if (errno == EINTR)
		                continue;
			res = -errno;
			if (errno != EAGAIN && errno != EWOULDBLOCK)
				pw_log_warn("recv client:%p res %zd: %m", client, r);
			goto exit;
		}
		client->in_index += r;
		break;
	}

	if (client->in_index == sizeof(client->desc)) {
		uint32_t flags, length, channel;

		flags = ntohl(client->desc.flags);
		if ((flags & FLAG_SHMMASK) != 0) {
			res = -ENOTSUP;
			goto exit;
		}

		length = ntohl(client->desc.length);
		if (length > FRAME_SIZE_MAX_ALLOW || length <= 0) {
			pw_log_warn(NAME" %p: Received invalid frame size: %u",
					impl, length);
			res = -EPROTO;
			goto exit;
		}
		channel = ntohl(client->desc.channel);
		if (channel == (uint32_t) -1) {
			if (flags != 0) {
				pw_log_warn(NAME" %p: Received packet frame with invalid "
						"flags value.", impl);
				res = -EPROTO;
				goto exit;
			}
		}
		if (client->message)
			message_free(impl, client->message, false, false);
		client->message = message_alloc(impl, channel, length);
	} else if (client->message &&
	    client->in_index >= client->message->length + sizeof(client->desc)) {
		struct message *msg = client->message;

		client->message = NULL;
		client->in_index = 0;

		if (msg->channel == (uint32_t)-1)
			res = handle_packet(client, msg);
		else
			res = handle_memblock(client, msg);
	}
exit:
	return res;
}

static void
on_client_data(void *data, int fd, uint32_t mask)
{
	struct client *client = data;
	struct impl *impl = client->impl;
	int res;

	if (mask & SPA_IO_HUP) {
		res = -EPIPE;
		goto error;
	}
	if (mask & SPA_IO_ERR) {
		res = -EIO;
		goto error;
	}
	if (mask & SPA_IO_IN) {
		pw_log_trace(NAME" %p: can read", impl);
		while (true) {
			res = do_read(client);
			if (res < 0) {
				if (res != -EAGAIN)
					goto error;
				break;
			}
		}
	}
	if (mask & SPA_IO_OUT || client->need_flush) {
		pw_log_trace(NAME" %p: can write", impl);
		client->need_flush = false;
		res = flush_messages(client);
		if (res >= 0) {
			int mask = client->source->mask;
			SPA_FLAG_CLEAR(mask, SPA_IO_OUT);
			pw_loop_update_io(impl->loop, client->source, mask);
		} else if (res != -EAGAIN)
			goto error;
	}
	return;

error:
        if (res == -EPIPE)
                pw_log_info(NAME" %p: client:%p [%s] disconnected", impl, client, client->name);
        else if (res != -EPROTO) {
                pw_log_error(NAME" %p: client:%p [%s] error %d (%s)", impl,
                                client, client->name, res, spa_strerror(res));
		return;
	}
	client_disconnect(client);
	client_unref(client);
}

static int check_flatpak(struct client *client, int pid)
{
	char root_path[2048];
	int root_fd, info_fd, res;
	struct stat stat_buf;

	sprintf(root_path, "/proc/%u/root", pid);
	root_fd = openat(AT_FDCWD, root_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC | O_NOCTTY);
	if (root_fd == -1) {
		res = -errno;
		if (res == -EACCES) {
			struct statfs buf;
			/* Access to the root dir isn't allowed. This can happen if the root is on a fuse
			 * filesystem, such as in a toolbox container. We will never have a fuse rootfs
			 * in the flatpak case, so in that case its safe to ignore this and
			 * continue to detect other types of apps. */
			if (statfs(root_path, &buf) == 0 &&
			    buf.f_type == 0x65735546) /* FUSE_SUPER_MAGIC */
				return 0;
		}
		/* Not able to open the root dir shouldn't happen. Probably the app died and
		 * we're failing due to /proc/$pid not existing. In that case fail instead
		 * of treating this as privileged. */
		pw_log_info("failed to open \"%s\": %s", root_path, spa_strerror(res));
		return res;
	}
	info_fd = openat(root_fd, ".flatpak-info", O_RDONLY | O_CLOEXEC | O_NOCTTY);
	close(root_fd);
	if (info_fd == -1) {
		if (errno == ENOENT) {
			pw_log_debug("no .flatpak-info, client on the host");
			/* No file => on the host */
			return 0;
		}
		res = -errno;
		pw_log_error("error opening .flatpak-info: %m");
		return res;
        }
	if (fstat(info_fd, &stat_buf) != 0 || !S_ISREG(stat_buf.st_mode)) {
		/* Some weird fd => failure, assume sandboxed */
		pw_log_error("error fstat .flatpak-info: %m");
	}
	close(info_fd);
	return 1;
}

static int get_client_pid(struct client *client, int client_fd)
{
	socklen_t len;
#if defined(__linux__)
	struct ucred ucred;
	len = sizeof(ucred);
	if (getsockopt(client_fd, SOL_SOCKET, SO_PEERCRED, &ucred, &len) < 0) {
                pw_log_warn(NAME": client %p: no peercred: %m", client);
	} else
		return ucred.pid;
#elif defined(__FreeBSD__)
	struct xucred xucred;
	len = sizeof(xucred);
	if (getsockopt(client_fd, 0, LOCAL_PEERCRED, &xucred, &len) < 0) {
                pw_log_warn(NAME": client %p: no peercred: %m", client);
	} else {
#if __FreeBSD__ >= 13
		return xucred.cr_pid;
#endif
	}
#endif
	return 0;
}

static void
on_connect(void *data, int fd, uint32_t mask)
{
	struct server *server = data;
	struct impl *impl = server->impl;
	struct sockaddr_un name;
	socklen_t length;
	int client_fd, val, pid;
	struct client *client;

	client = calloc(1, sizeof(struct client));
	if (client == NULL)
		goto error;

	client->impl = impl;
	client->ref = 1;
	client->server = server;
	client->connect_tag = SPA_ID_INVALID;
	spa_list_append(&server->clients, &client->link);
	pw_map_init(&client->streams, 16, 16);
	spa_list_init(&client->out_messages);
	spa_list_init(&client->operations);
	spa_list_init(&client->pending_samples);

	client->props = pw_properties_new(
			PW_KEY_CLIENT_API, "pipewire-pulse",
			NULL);
	if (client->props == NULL)
		goto error;

	pw_properties_setf(client->props,
			"pulse.server.type", "%s",
			server->type == SERVER_TYPE_INET ? "tcp" : "unix");

	client->routes = pw_properties_new(NULL, NULL);
	if (client->routes == NULL)
		goto error;

	length = sizeof(name);
	client_fd = accept4(fd, (struct sockaddr *) &name, &length, SOCK_CLOEXEC);
	if (client_fd < 0)
		goto error;

	pw_log_debug(NAME": client %p fd:%d", client, client_fd);

	if (server->type == SERVER_TYPE_UNIX) {
		val = 6;
#ifdef SO_PRIORITY
		if (setsockopt(client_fd, SOL_SOCKET, SO_PRIORITY,
					(const void *) &val, sizeof(val)) < 0)
			pw_log_warn("SO_PRIORITY failed: %m");
#endif
		pid = get_client_pid(client, client_fd);
		if (pid != 0 && check_flatpak(client, pid) == 1)
			pw_properties_set(client->props, PW_KEY_CLIENT_ACCESS, "flatpak");
	} else if (server->type == SERVER_TYPE_INET) {
		val = 1;
		if (setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY,
					(const void *) &val, sizeof(val)) < 0)
	            pw_log_warn("TCP_NODELAY failed: %m");

		val = IPTOS_LOWDELAY;
		if (setsockopt(client_fd, IPPROTO_IP, IP_TOS,
					(const void *) &val, sizeof(val)) < 0)
	            pw_log_warn("IP_TOS failed: %m");

		pw_properties_set(client->props, PW_KEY_CLIENT_ACCESS, "restricted");
	}

	client->source = pw_loop_add_io(impl->loop,
					client_fd,
					SPA_IO_ERR | SPA_IO_HUP | SPA_IO_IN,
					true, on_client_data, client);
	if (client->source == NULL)
		goto error;

	return;
error:
	pw_log_error(NAME" %p: failed to create client: %m", impl);
	if (client)
		client_free(client);
	return;
}

static int
get_runtime_dir(char *buf, size_t buflen, const char *dir)
{
	const char *runtime_dir;
	struct stat stat_buf;
	int res, size;

	runtime_dir = getenv("PULSE_RUNTIME_PATH");
	if (runtime_dir == NULL)
		runtime_dir = getenv("XDG_RUNTIME_DIR");
	if (runtime_dir == NULL)
		runtime_dir = getenv("HOME");
	if (runtime_dir == NULL) {
		struct passwd pwd, *result = NULL;
		char buffer[4096];
		if (getpwuid_r(getuid(), &pwd, buffer, sizeof(buffer), &result) == 0)
			runtime_dir = result ? result->pw_dir : NULL;
	}
	size = snprintf(buf, buflen, "%s/%s", runtime_dir, dir) + 1;
	if (size > (int) buflen) {
		pw_log_error(NAME": path %s/%s too long", runtime_dir, dir);
		return -ENAMETOOLONG;
	}
	if (stat(buf, &stat_buf) < 0) {
		res = -errno;
		if (res != -ENOENT) {
			pw_log_error(NAME": stat() %s failed: %m", buf);
			return res;
		}
		if (mkdir(buf, 0700) < 0) {
			res = -errno;
			pw_log_error(NAME": mkdir() %s failed: %m", buf);
			return res;
		}
		pw_log_info(NAME": created %s", buf);
	} else if ((stat_buf.st_mode & S_IFMT) != S_IFDIR) {
		pw_log_error(NAME": %s is not a directory", buf);
		return -ENOTDIR;
	}
	return 0;
}

void server_free(struct server *server)
{
	struct impl *impl = server->impl;
	struct client *c;

	pw_log_debug(NAME" %p: free server %p", impl, server);

	spa_list_remove(&server->link);
	spa_list_consume(c, &server->clients, link)
		client_free(c);
	if (server->source)
		pw_loop_destroy_source(impl->loop, server->source);
	if (server->type == SERVER_TYPE_UNIX && !server->activated)
		unlink(server->addr.sun_path);
	free(server);
}

static const char *
get_server_name(struct pw_context *context)
{
	const char *name = NULL;
	const struct pw_properties *props = pw_context_get_properties(context);

	if (props)
		name = pw_properties_get(props, PW_KEY_REMOTE_NAME);
	if (name == NULL || name[0] == '\0')
		name = getenv("PIPEWIRE_REMOTE");
	if (name == NULL || name[0] == '\0')
		name = PW_DEFAULT_REMOTE;
	return name;
}

static bool is_stale_socket(struct server *server, int fd)
{
	socklen_t size;

	size = offsetof(struct sockaddr_un, sun_path) + strlen(server->addr.sun_path);
	if (connect(fd, (struct sockaddr *)&server->addr, size) < 0) {
		if (errno == ECONNREFUSED)
			return true;
	}
	return false;
}

static int make_local_socket(struct server *server, const char *name)
{
	char runtime_dir[PATH_MAX];
	socklen_t size;
	int name_size, fd, res;
	struct stat socket_stat;
	bool activated = false;

	if ((res = get_runtime_dir(runtime_dir, sizeof(runtime_dir), "pulse")) < 0)
		goto error;

	server->addr.sun_family = AF_LOCAL;
	name_size = snprintf(server->addr.sun_path, sizeof(server->addr.sun_path),
                             "%s/%s", runtime_dir, name) + 1;

	if (name_size > (int) sizeof(server->addr.sun_path)) {
		pw_log_error(NAME" %p: %s/%s too long",
					server, runtime_dir, name);
		res = -ENAMETOOLONG;
		goto error;
	}
	size = offsetof(struct sockaddr_un, sun_path) + strlen(server->addr.sun_path);

#ifdef HAVE_SYSTEMD
	{
		int i, n = sd_listen_fds(0);
		for (i = 0; i < n; ++i) {
			if (sd_is_socket_unix(SD_LISTEN_FDS_START + i, SOCK_STREAM,
						1, server->addr.sun_path, 0) > 0) {
				fd = SD_LISTEN_FDS_START + i;
				activated = true;
				pw_log_info("server %p: Found socket activation socket for '%s'",
						server, server->addr.sun_path);
				goto done;
			}
		}
	}
#endif

	if ((fd = socket(PF_LOCAL, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0)) < 0) {
		res = -errno;
		pw_log_info(NAME" %p: socket() failed: %m", server);
		goto error;
	}
	if (stat(server->addr.sun_path, &socket_stat) < 0) {
		if (errno != ENOENT) {
			res = -errno;
			pw_log_error(NAME" %p: stat() %s failed: %m",
					server, server->addr.sun_path);
			goto error_close;
		}
	} else if (socket_stat.st_mode & S_IWUSR || socket_stat.st_mode & S_IWGRP) {
		/* socket is there, check if it's stale */
		if (!is_stale_socket(server, fd)) {
			res = -EBUSY;
			pw_log_info(NAME" %p: socket %s is in use", server,
				server->addr.sun_path);
			goto error_close;
		}
		pw_log_warn(NAME" %p: unlink stale socket %s", server,
				server->addr.sun_path);
			unlink(server->addr.sun_path);
	}
	if (bind(fd, (struct sockaddr *) &server->addr, size) < 0) {
		res = -errno;
		pw_log_error(NAME" %p: bind() to %s failed: %m", server,
				server->addr.sun_path);
		goto error_close;
	}
	if (listen(fd, 128) < 0) {
		res = -errno;
		pw_log_error(NAME" %p: listen() on %s failed: %m", server,
				server->addr.sun_path);
		goto error_close;
	}
	pw_log_info(NAME" listening on unix:%s", server->addr.sun_path);
#ifdef HAVE_SYSTEMD
done:
#endif
	server->activated = activated;
	server->type = SERVER_TYPE_UNIX;

	return fd;

error_close:
	close(fd);
error:
	return res;
}

static int create_pid_file(void) {
	int res;
	char pid_file[PATH_MAX];
	FILE *f;

	if ((res = get_runtime_dir(pid_file, sizeof(pid_file), "pulse")) < 0) {
		return res;
	}
	if (strlen(pid_file) > PATH_MAX - 5) {
		pw_log_error(NAME" %s/pid too long", pid_file);
		return -ENAMETOOLONG;
	}
	strcat(pid_file, "/pid");

	if ((f = fopen(pid_file, "w")) == NULL) {
		res = -errno;
		pw_log_error(NAME" failed to open pid file");
		return res;
	}

	fprintf(f, "%lu\n", (unsigned long)getpid());
	fclose(f);
	return 0;
}

static int make_inet_socket(struct server *server, const char *name)
{
	struct sockaddr_in addr;
	int res, fd, on;
	uint32_t address = INADDR_ANY;
	uint16_t port;
	char *col;

	col = strchr(name, ':');
	if (col) {
		struct in_addr ipv4;
		char *n;
		port = atoi(col+1);
		n = strndupa(name, col - name);
		if (inet_pton(AF_INET, n, &ipv4) > 0)
			address = ntohl(ipv4.s_addr);
		else
			address = INADDR_ANY;
	} else {
		address = INADDR_ANY;
		port = atoi(name);
	}
	if (port == 0)
		port = PW_PROTOCOL_PULSE_DEFAULT_PORT;

	if ((fd = socket(PF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0)) < 0) {
		res = -errno;
		pw_log_error(NAME" %p: socket() failed: %m", server);
		goto error;
	}

	on = 1;
	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (const void *) &on, sizeof(on)) < 0)
		pw_log_warn(NAME" %p: setsockopt(): %m", server);

	spa_zero(addr);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = htonl(address);

	if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
		res = -errno;
		pw_log_error(NAME" %p: bind() failed: %m", server);
		goto error_close;
	}
	if (listen(fd, 5) < 0) {
		res = -errno;
		pw_log_error(NAME" %p: listen() failed: %m", server);
		goto error_close;
	}
	server->type = SERVER_TYPE_INET;
	pw_log_info(NAME" listening on tcp:%08x:%u", address, port);

	return fd;

error_close:
	close(fd);
error:
	return res;
}

struct server *create_server(struct impl *impl, const char *address)
{
	int fd, res;
	struct server *server;

	server = calloc(1, sizeof(struct server));
	if (server == NULL)
		return NULL;

	server->impl = impl;
	spa_list_init(&server->clients);
	spa_list_append(&impl->servers, &server->link);

	if (strstr(address, "unix:") == address) {
		fd = make_local_socket(server, address+5);
	} else if (strstr(address, "tcp:") == address) {
		fd = make_inet_socket(server, address+4);
	} else {
		fd = -EINVAL;
	}
	if (fd < 0) {
		res = fd;
		goto error;
	}
	server->source = pw_loop_add_io(impl->loop, fd, SPA_IO_IN, true, on_connect, server);
	if (server->source == NULL) {
		res = -errno;
		pw_log_error(NAME" %p: can't create server source: %m", impl);
		goto error_close;
	}
	return server;

error_close:
	close(fd);
error:
	server_free(server);
	errno = -res;
	return NULL;

}

static int impl_free_sample(void *item, void *data)
{
	struct sample *s = item;
	sample_free(s);
	return 0;
}

static int impl_free_module(void *item, void *data)
{
	struct module *m = item;
	module_free(m);
	return 0;
}

static void impl_free(struct impl *impl)
{
	struct server *s;
	struct client *c;
	struct message *msg;

	if (impl->dbus_name)
		dbus_release_name(impl->dbus_name);

	spa_list_consume(msg, &impl->free_messages, link)
		message_free(impl, msg, true, true);

	if (impl->context != NULL)
		spa_hook_remove(&impl->context_listener);
	spa_list_consume(c, &impl->cleanup_clients, link)
		client_free(c);
	spa_list_consume(s, &impl->servers, link)
		server_free(s);

	pw_map_for_each(&impl->samples, impl_free_sample, impl);
	pw_map_clear(&impl->samples);
	pw_map_for_each(&impl->modules, impl_free_module, impl);
	pw_map_clear(&impl->modules);

	pw_properties_free(impl->props);
	free(impl);
}

static void context_destroy(void *data)
{
	struct impl *impl = data;
	struct server *s;
	spa_list_consume(s, &impl->servers, link)
		server_free(s);
	spa_hook_remove(&impl->context_listener);
	impl->context = NULL;
}

static const struct pw_context_events context_events = {
	PW_VERSION_CONTEXT_EVENTS,
	.destroy = context_destroy,
};

static int parse_frac(struct pw_properties *props, const char *key, const char *def,
		struct spa_fraction *res)
{
	const char *str;
	if (props == NULL ||
	    (str = pw_properties_get(props, key)) == NULL)
		str = def;
	if (sscanf(str, "%u/%u", &res->num, &res->denom) != 2 || res->denom == 0)
		return -EINVAL;
	pw_log_info(NAME": defaults: %s = %u/%u", key, res->num, res->denom);
	return 0;
}

static int parse_position(struct pw_properties *props, const char *key, const char *def,
		struct channel_map *res)
{
	const char *str;
	struct spa_json it[2];
	char v[256];

	if (props == NULL ||
	    (str = pw_properties_get(props, key)) == NULL)
		str = def;

	spa_json_init(&it[0], str, strlen(str));
        if (spa_json_enter_array(&it[0], &it[1]) <= 0)
                spa_json_init(&it[1], str, strlen(str));

	res->channels = 0;
	while (spa_json_get_string(&it[1], v, sizeof(v)) > 0 &&
	    res->channels < SPA_AUDIO_MAX_CHANNELS) {
		res->map[res->channels++] = channel_name2id(v);
	}
	pw_log_info(NAME": defaults: %s = %s", key, str);
	return 0;
}
static int parse_format(struct pw_properties *props, const char *key, const char *def,
		struct sample_spec *res)
{
	const char *str;
	if (props == NULL ||
	    (str = pw_properties_get(props, key)) == NULL)
		str = def;
	res->format = format_name2id(str);
	if (res->format == SPA_AUDIO_FORMAT_UNKNOWN)
		res->format = SPA_AUDIO_FORMAT_F32;
	pw_log_info(NAME": defaults: %s = %s", key, str);
	return 0;
}

static void load_defaults(struct defs *def, struct pw_properties *props)
{
	parse_frac(props, "pulse.min.req", DEFAULT_MIN_REQ, &def->min_req);
	parse_frac(props, "pulse.default.req", DEFAULT_DEFAULT_REQ, &def->default_req);
	parse_frac(props, "pulse.min.frag", DEFAULT_MIN_FRAG, &def->min_frag);
	parse_frac(props, "pulse.default.frag", DEFAULT_DEFAULT_FRAG, &def->default_frag);
	parse_frac(props, "pulse.default.tlength", DEFAULT_DEFAULT_TLENGTH, &def->default_tlength);
	parse_frac(props, "pulse.min.quantum", DEFAULT_MIN_QUANTUM, &def->min_quantum);
	parse_format(props, "pulse.default.format", DEFAULT_FORMAT, &def->sample_spec);
	parse_position(props, "pulse.default.position", DEFAULT_POSITION, &def->channel_map);
	def->sample_spec.channels = def->channel_map.channels;
}

struct pw_protocol_pulse *pw_protocol_pulse_new(struct pw_context *context,
		struct pw_properties *props, size_t user_data_size)
{
	struct impl *impl;
	const char *str;
	struct spa_json it[2];
	char value[512];
	const struct spa_support *support;
	struct spa_cpu *cpu;
	uint32_t n_support;
	int res;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL)
		goto error_exit;


	if (props == NULL)
		props = pw_properties_new(NULL, NULL);
	if (props == NULL)
		goto error_free;

	support = pw_context_get_support(context, &n_support);
	cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if ((str = pw_properties_get(props, "vm.overrides")) != NULL) {
		if (cpu != NULL && spa_cpu_get_vm_type(cpu) != SPA_CPU_VM_NONE)
			pw_properties_update_string(props, str, strlen(str));
		pw_properties_set(props, "vm.overrides", NULL);
	}

	load_defaults(&impl->defs, props);

	debug_messages = pw_debug_is_category_enabled("connection");

	impl->context = context;
	impl->loop = pw_context_get_main_loop(context);
	impl->props = props;

	impl->work_queue = pw_context_get_work_queue(context);
	if (impl->work_queue == NULL)
		goto error_free;

	spa_list_init(&impl->servers);
	impl->rate_limit.interval = 2 * SPA_NSEC_PER_SEC;
	impl->rate_limit.burst = 1;
	pw_map_init(&impl->samples, 16, 16);
	pw_map_init(&impl->modules, 16, 16);
	spa_list_init(&impl->cleanup_clients);
	spa_list_init(&impl->free_messages);

	pw_context_add_listener(context, &impl->context_listener,
			&context_events, impl);

	str = pw_properties_get(props, "server.address");
	if (str == NULL) {
		pw_properties_setf(props, "server.address",
				"[ \"%s-%s\" ]",
				PW_PROTOCOL_PULSE_DEFAULT_SERVER,
				get_server_name(context));
		str = pw_properties_get(props, "server.address");
	}
	if (str == NULL)
		goto error_free;

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_array(&it[0], &it[1]) > 0) {
		while (spa_json_get_string(&it[1], value, sizeof(value)-1) > 0) {
			if (create_server(impl, value) == NULL) {
				pw_log_warn(NAME" %p: can't create server for %s: %m",
						impl, value);
			}
		}
	}
	if ((res = create_pid_file()) < 0) {
		pw_log_warn(NAME" %p: can't create pid file: %s",
				impl, spa_strerror(res));
	}
	impl->dbus_name = dbus_request_name(context, "org.pulseaudio.Server");

	return (struct pw_protocol_pulse*)impl;

error_free:
	free(impl);
error_exit:
	if (props != NULL)
		pw_properties_free(props);
	return NULL;
}

void *pw_protocol_pulse_get_user_data(struct pw_protocol_pulse *pulse)
{
	return SPA_MEMBER(pulse, sizeof(struct impl), void);
}

void pw_protocol_pulse_destroy(struct pw_protocol_pulse *pulse)
{
	struct impl *impl = (struct impl*)pulse;
	impl_free(impl);
}
