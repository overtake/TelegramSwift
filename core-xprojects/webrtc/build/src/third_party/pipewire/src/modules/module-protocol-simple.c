/* PipeWire
 *
 * Copyright © 2021 Wim Taymans <wim.taymans@gmail.com>
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
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/ip.h>
#include <sys/un.h>
#include <arpa/inet.h>

#include "config.h"

#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/pod/pod.h>
#include <spa/pod/builder.h>
#include <spa/debug/types.h>
#include <spa/param/audio/type-info.h>
#include <spa/param/audio/format-utils.h>

#include <pipewire/impl.h>

#define NAME "protocol-simple"

#define DEFAULT_PORT 4711
#define DEFAULT_SERVER "[ \"tcp:"SPA_STRINGIFY(DEFAULT_PORT)"\" ]"

#define DEFAULT_FORMAT "S16"
#define DEFAULT_RATE "44100"
#define DEFAULT_CHANNELS "2"
#define DEFAULT_POSITION "[ FL FR ]"
#define DEFAULT_LATENCY "1024/48000"

#define MODULE_USAGE	"[ capture=<bool> ] "						\
			"[ playback=<bool> ] "						\
			"[ capture.node=<source-target> ] "				\
			"[ playback.node=<sink-target> ] "				\
			"[ audio.rate=<sample-rate, default:"DEFAULT_RATE"> ] "		\
			"[ audio.format=<format, default:"DEFAULT_FORMAT"> ] "		\
			"[ audio.channels=<channels, default:"DEFAULT_CHANNELS"> ] "	\
			"[ audio.position=<position, default:"DEFAULT_POSITION"> ] "	\
			"[ server.address=<[ tcp:[<ip>:]<port>[,...] ], default:"DEFAULT_SERVER">"	\

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Implements a simple protocol" },
	{ PW_KEY_MODULE_USAGE, MODULE_USAGE },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

struct impl {
	struct pw_loop *loop;
	struct pw_context *context;

	struct pw_properties *props;
	struct spa_hook module_listener;
	struct spa_list server_list;

	struct pw_work_queue *work_queue;

	bool capture;
	bool playback;

	struct spa_audio_info_raw info;
	uint32_t frame_size;
};

struct client {
	struct spa_list link;
	struct impl *impl;
	struct server *server;

	struct pw_core *core;
        struct spa_hook core_proxy_listener;

	struct spa_source *source;
	char name[512];

	struct pw_stream *capture;
	struct spa_hook capture_listener;

	struct pw_stream *playback;
	struct spa_hook playback_listener;

	struct spa_io_rate_match *rate_match;

	unsigned int disconnect:1;
	unsigned int disconnecting:1;
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

	struct spa_list client_list;
};

static void client_disconnect(struct client *client)
{
	struct impl *impl = client->impl;

	if (client->disconnect)
		return;

	client->disconnect = true;

	if (client->source)
		pw_loop_destroy_source(impl->loop, client->source);
}

static void client_free(struct client *client)
{
	struct impl *impl = client->impl;

	pw_log_info(NAME" %p: client:%p [%s] free", impl, client, client->name);

	client_disconnect(client);

	spa_list_remove(&client->link);

	if (client->capture)
		pw_stream_destroy(client->capture);
	if (client->playback)
		pw_stream_destroy(client->playback);
	if (client->core) {
		client->disconnecting = true;
		spa_hook_remove(&client->core_proxy_listener);
		pw_core_disconnect(client->core);
	}
	free(client);
}


static void on_client_cleanup(void *obj, void *data, int res, uint32_t id)
{
	struct client *c = obj;
	client_free(c);
}

static void client_cleanup(struct client *client)
{
	struct impl *impl = client->impl;
	pw_work_queue_add(impl->work_queue, client, 0, on_client_cleanup, impl);
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
	return;

error:
        if (res == -EPIPE)
                pw_log_info(NAME" %p: client:%p [%s] disconnected", impl, client, client->name);
        else  {
                pw_log_error(NAME" %p: client:%p [%s] error %d (%s)", impl,
                                client, client->name, res, spa_strerror(res));
	}
	client_cleanup(client);
}

static void capture_process(void *data)
{
	struct client *client = data;
	struct impl *impl = client->impl;
	struct pw_buffer *buf;
	struct spa_data *d;
	uint32_t size, offset;
	int res;

	if ((buf = pw_stream_dequeue_buffer(client->capture)) == NULL) {
		pw_log_warn("%p: client:%p [%s] out of capture buffers: %m", impl,
				client, client->name);
		return;
	}
	d = &buf->buffer->datas[0];

	size = d->chunk->size;
	offset = d->chunk->offset;

	while (size > 0) {
		res = send(client->source->fd,
				SPA_MEMBER(d->data, offset, void),
				size,
				MSG_NOSIGNAL | MSG_DONTWAIT);
		if (res < 0) {
			if (errno == EINTR)
				continue;
			if (errno != EAGAIN && errno != EWOULDBLOCK)
				pw_log_warn("%p: client:%p [%s] send error %d: %m", impl,
						client, client->name, res);
			client_cleanup(client);
			break;
		}
		offset += res;
		size -= res;
	}
	pw_stream_queue_buffer(client->capture, buf);
}

static void playback_process(void *data)
{
	struct client *client = data;
	struct impl *impl = client->impl;
	struct pw_buffer *buf;
	uint32_t size, offset;
	struct spa_data *d;
	int res;

	if ((buf = pw_stream_dequeue_buffer(client->playback)) == NULL) {
		pw_log_warn("%p: client:%p [%s] out of playback buffers: %m", impl,
				client, client->name);
		return;
	}
	d = &buf->buffer->datas[0];

	if (client->rate_match) {
		size = client->rate_match->size * impl->frame_size;
		size = SPA_MIN(size, d->maxsize);
	} else {
		size = d->maxsize;
	}

	offset = 0;
	while (size > 0) {
		res = recv(client->source->fd,
				SPA_MEMBER(d->data, offset, void),
				size,
				MSG_DONTWAIT);
		if (res == 0) {
			pw_log_info("%p: client:%p [%s] disconnect", impl,
					client, client->name);
			client_cleanup(client);
			break;
		}
		if (res < 0) {
			if (errno == EINTR)
				continue;
			if (errno != EAGAIN && errno != EWOULDBLOCK)
				pw_log_warn("%p: client:%p [%s] recv error %d: %m",
						impl, client, client->name, res);
			break;
		}
		offset += res;
		size -= res;
	}
	d->chunk->offset = 0;
	d->chunk->size = offset;
	d->chunk->stride = impl->frame_size;

	pw_stream_queue_buffer(client->playback, buf);
}

static void capture_destroy(void *data)
{
	struct client *client = data;
	spa_hook_remove(&client->capture_listener);
	client->capture = NULL;
}

static void on_stream_state_changed(void *data, enum pw_stream_state old,
                enum pw_stream_state state, const char *error)
{
	struct client *client = data;
	struct impl *impl = client->impl;

	switch (state) {
	case PW_STREAM_STATE_ERROR:
	case PW_STREAM_STATE_UNCONNECTED:
		if (!client->disconnect) {
			pw_log_info("%p: client:%p [%s] stream error %s",
					impl, client, client->name,
					pw_stream_state_as_string(state));
			client_cleanup(client);
		}
		break;
	default:
		break;
	}
}

static void playback_destroy(void *data)
{
	struct client *client = data;
	spa_hook_remove(&client->playback_listener);
	client->playback = NULL;
}

static void playback_io_changed(void *data, uint32_t id, void *area, uint32_t size)
{
	struct client *client = data;
	switch (id) {
	case SPA_IO_RateMatch:
		client->rate_match = area;
		break;
	}
}

static const struct pw_stream_events capture_stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = capture_destroy,
	.state_changed = on_stream_state_changed,
	.process = capture_process
};

static const struct pw_stream_events playback_stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = playback_destroy,
	.state_changed = on_stream_state_changed,
	.io_changed = playback_io_changed,
	.process = playback_process
};

static int create_streams(struct impl *impl, struct client *client)
{
	uint32_t n_params;
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	struct pw_properties *props;
	int res;

	if (impl->capture) {
		props = pw_properties_new(
			PW_KEY_NODE_GROUP, client->name,
			PW_KEY_NODE_LATENCY, DEFAULT_LATENCY,
			PW_KEY_NODE_TARGET, pw_properties_get(impl->props, "capture.node"),
			NULL);
		if (props == NULL)
			return -errno;

		pw_properties_setf(props,
				PW_KEY_MEDIA_NAME, "%s capture", client->name);
		client->capture = pw_stream_new(client->core,
				pw_properties_get(props, PW_KEY_MEDIA_NAME),
				props);
		if (client->capture == NULL)
			return -errno;

		pw_stream_add_listener(client->capture, &client->capture_listener,
				&capture_stream_events, client);
	}
	if (impl->playback) {
		props = pw_properties_new(
			PW_KEY_NODE_GROUP, client->name,
			PW_KEY_NODE_LATENCY, DEFAULT_LATENCY,
			PW_KEY_NODE_TARGET, pw_properties_get(impl->props, "playback.node"),
			NULL);
		if (props == NULL)
			return -errno;

		pw_properties_setf(props,
				PW_KEY_MEDIA_NAME, "%s playback", client->name);

		client->playback = pw_stream_new(client->core,
				pw_properties_get(props, PW_KEY_MEDIA_NAME),
				props);
		if (client->playback == NULL)
			return -errno;

		pw_stream_add_listener(client->playback, &client->playback_listener,
				&playback_stream_events, client);
	}

	n_params = 0;
	params[n_params++] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
				&impl->info);

	if (impl->capture) {
		if ((res = pw_stream_connect(client->capture,
				PW_DIRECTION_INPUT,
				PW_ID_ANY,
				PW_STREAM_FLAG_AUTOCONNECT |
				PW_STREAM_FLAG_MAP_BUFFERS |
				PW_STREAM_FLAG_RT_PROCESS,
				params, n_params)) < 0)
			return res;
	}
	if (impl->playback) {
		if ((res = pw_stream_connect(client->playback,
				PW_DIRECTION_OUTPUT,
				PW_ID_ANY,
				PW_STREAM_FLAG_AUTOCONNECT |
				PW_STREAM_FLAG_MAP_BUFFERS |
				PW_STREAM_FLAG_RT_PROCESS,
				params, n_params)) < 0)
			return res;
	}
	return 0;
}

static void on_core_proxy_destroy(void *data)
{
	struct client *client = data;
	spa_hook_remove(&client->core_proxy_listener);
	client->core = NULL;
	client_cleanup(client);
}

static struct pw_proxy_events core_proxy_events = {
	PW_VERSION_CORE_EVENTS,
	.destroy = on_core_proxy_destroy,
};

static void
on_connect(void *data, int fd, uint32_t mask)
{
	struct server *server = data;
	struct impl *impl = server->impl;
	struct sockaddr addr;
	socklen_t addrlen;
	int client_fd, val;
	struct client *client = NULL;
	struct pw_properties *props = NULL;

	addrlen = sizeof(addr);
	client_fd = accept4(fd, &addr, &addrlen, SOCK_NONBLOCK | SOCK_CLOEXEC);
	if (client_fd < 0)
		goto error;

	client = calloc(1, sizeof(struct client));
	if (client == NULL)
		goto error;

	client->impl = impl;
	client->server = server;
	spa_list_append(&server->client_list, &client->link);

	if (inet_ntop(addr.sa_family, addr.sa_data, client->name, sizeof(client->name)) == NULL)
		snprintf(client->name, sizeof(client->name), "client %d", client_fd);

	pw_log_info(NAME" %p: client:%p [%s] connected", impl, client, client->name);

	props = pw_properties_new(
			PW_KEY_CLIENT_API, "protocol-simple",
			NULL);
	if (props == NULL)
		goto error;

	pw_properties_setf(props,
			"protocol.server.type", "%s",
			server->type == SERVER_TYPE_INET ? "tcp" : "unix");

	if (server->type == SERVER_TYPE_UNIX) {
		goto error;
	} else if (server->type == SERVER_TYPE_INET) {
		val = 1;
		if (setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY,
					(const void *) &val, sizeof(val)) < 0)
	            pw_log_warn("TCP_NODELAY failed: %m");

		val = IPTOS_LOWDELAY;
		if (setsockopt(client_fd, IPPROTO_IP, IP_TOS,
					(const void *) &val, sizeof(val)) < 0)
	            pw_log_warn("IP_TOS failed: %m");

		pw_properties_set(props, PW_KEY_CLIENT_ACCESS, "restricted");
	}

	client->source = pw_loop_add_io(impl->loop,
					client_fd,
					SPA_IO_ERR | SPA_IO_HUP,
					true, on_client_data, client);
	if (client->source == NULL)
		goto error;

	client->core = pw_context_connect(impl->context, props, 0);
	props = NULL;
	if (client->core == NULL)
		goto error;

	pw_proxy_add_listener((struct pw_proxy*)client->core,
			&client->core_proxy_listener, &core_proxy_events,
			client);

	create_streams(impl, client);

	return;
error:
	pw_log_error(NAME" %p: failed to create client: %m", impl);
	if (props != NULL)
		pw_properties_free(props);
	if (client != NULL)
		client_free(client);
	return;
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
		port = DEFAULT_PORT;

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

static void server_free(struct server *server)
{
	struct impl *impl = server->impl;
	struct client *c;

	pw_log_debug(NAME" %p: free server %p", impl, server);

	spa_list_remove(&server->link);
	spa_list_consume(c, &server->client_list, link)
		client_free(c);
	if (server->source)
		pw_loop_destroy_source(impl->loop, server->source);
	free(server);
}

static struct server *create_server(struct impl *impl, const char *address)
{
	int fd, res;
	struct server *server;

	server = calloc(1, sizeof(struct server));
	if (server == NULL)
		return NULL;

	server->impl = impl;
	spa_list_init(&server->client_list);
	spa_list_append(&impl->server_list, &server->link);

	if (strstr(address, "tcp:") == address) {
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

static void impl_free(struct impl *impl)
{
	struct server *s;

	spa_hook_remove(&impl->module_listener);
	spa_list_consume(s, &impl->server_list, link)
		server_free(s);
	if (impl->props)
		pw_properties_free(impl->props);
	free(impl);
}

static inline uint32_t format_from_name(const char *name, size_t len)
{
	int i;
	for (i = 0; spa_type_audio_format[i].name; i++) {
		if (strncmp(name, spa_debug_type_short_name(spa_type_audio_format[i].name), len) == 0)
			return spa_type_audio_format[i].type;
	}
	return SPA_AUDIO_FORMAT_UNKNOWN;
}

static inline uint32_t channel_from_name(const char *name)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static inline uint32_t parse_position(uint32_t *pos, const char *val, size_t len)
{
	uint32_t channels = 0;
	struct spa_json it[2];
	char v[256];

	spa_json_init(&it[0], val, len);
	if (spa_json_enter_array(&it[0], &it[1]) <= 0)
		spa_json_init(&it[1], val, len);

	while (spa_json_get_string(&it[1], v, sizeof(v)) > 0 &&
			channels < SPA_AUDIO_MAX_CHANNELS) {
		pos[channels++] = channel_from_name(v);
	}
	return channels;
}

static int parse_params(struct impl *impl)
{
	const char *str;
	struct spa_json it[2];
	char value[512];

	if ((str = pw_properties_get(impl->props, "capture")) != NULL)
		impl->capture = pw_properties_parse_bool(str);
	if ((str = pw_properties_get(impl->props, "playback")) != NULL)
		impl->playback = pw_properties_parse_bool(str);
	if (!impl->playback && !impl->capture) {
		pw_log_error("missing capture or playback param");
		return -EINVAL;
	}

	if ((str = pw_properties_get(impl->props, "audio.format")) == NULL)
		str = DEFAULT_FORMAT;
	impl->info.format = format_from_name(str, strlen(str));
	if (impl->info.format == SPA_AUDIO_FORMAT_UNKNOWN) {
		pw_log_error("invalid format '%s'", str);
		return -EINVAL;
	}
	if ((str = pw_properties_get(impl->props, "audio.rate")) == NULL)
		str = DEFAULT_RATE;
	impl->info.rate = atoi(str);
	if (impl->info.rate == 0) {
		pw_log_error("invalid rate '%s'", str);
		return -EINVAL;
	}
	if ((str = pw_properties_get(impl->props, "audio.channels")) == NULL)
		str = DEFAULT_CHANNELS;
	impl->info.channels = atoi(str);
	if (impl->info.channels == 0) {
		pw_log_error("invalid channels '%s'", str);
		return -EINVAL;
	}
	if ((str = pw_properties_get(impl->props, "audio.position")) == NULL)
		str = DEFAULT_POSITION;
	if (parse_position(impl->info.position, str, strlen(str)) != impl->info.channels) {
		pw_log_error("invalid position '%s'", str);
		return -EINVAL;
	}

	switch (impl->info.format) {
	case SPA_AUDIO_FORMAT_U8:
		impl->frame_size = 1;
		break;
	case SPA_AUDIO_FORMAT_S16_LE:
	case SPA_AUDIO_FORMAT_S16_BE:
	case SPA_AUDIO_FORMAT_S16P:
		impl->frame_size = 2;
		break;
	case SPA_AUDIO_FORMAT_S24_LE:
	case SPA_AUDIO_FORMAT_S24_BE:
	case SPA_AUDIO_FORMAT_S24P:
		impl->frame_size = 3;
		break;
	default:
		impl->frame_size = 4;
		break;
	}
	impl->frame_size *= impl->info.channels;

	if ((str = pw_properties_get(impl->props, "server.address")) == NULL)
		str = DEFAULT_SERVER;

        spa_json_init(&it[0], str, strlen(str));
        if (spa_json_enter_array(&it[0], &it[1]) > 0) {
                while (spa_json_get_string(&it[1], value, sizeof(value)-1) > 0) {
                        if (create_server(impl, value) == NULL) {
				pw_log_warn(NAME" %p: can't create server for %s: %m",
					impl, value);
			}
		}
	}
	return 0;
}

static void module_destroy(void *data)
{
	struct impl *impl = data;
	pw_log_debug("module %p: destroy", impl);
	impl_free(impl);
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy,
};

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_properties *props;
	struct impl *impl;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	pw_log_debug("module %p: new %s", impl, args);

	if (args)
		props = pw_properties_new_string(args);
	else
		props = pw_properties_new(NULL, NULL);

	impl->context = context;
	impl->loop = pw_context_get_main_loop(context);
	impl->props = props;
	spa_list_init(&impl->server_list);

	pw_impl_module_add_listener(module, &impl->module_listener, &module_events, impl);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	impl->work_queue = pw_context_get_work_queue(context);
	if (impl->work_queue == NULL) {
		res = -errno;
		goto error_free;
	}

	if ((res = parse_params(impl)) < 0)
		goto error_free;

	return 0;

error_free:
	impl_free(impl);
	return res;
}
