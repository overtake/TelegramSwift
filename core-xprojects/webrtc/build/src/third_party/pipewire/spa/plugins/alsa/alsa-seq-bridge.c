/* Spa ALSA Source
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

#include <stddef.h>
#include <ctype.h>

#include <alsa/asoundlib.h>

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/keys.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/utils/list.h>
#include <spa/monitor/device.h>
#include <spa/param/audio/format.h>
#include <spa/pod/filter.h>

#define NAME "alsa-bridge"

#include "alsa-seq.h"

static const char default_device[] = "default";

static void reset_props(struct props *props)
{
	strncpy(props->device, default_device, 64);
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct seq_state *this = object;
	struct spa_pod *param;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	struct props *p;
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	p = &this->props;

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_PropInfo:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_device),
				SPA_PROP_INFO_name, SPA_POD_String("The ALSA device"),
				SPA_PROP_INFO_type, SPA_POD_Stringn(p->device, sizeof(p->device)));
			break;
		default:
			return 0;
		}
		break;

	case SPA_PARAM_Props:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, id,
				SPA_PROP_device,      SPA_POD_Stringn(p->device, sizeof(p->device)));
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
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Clock),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_clock)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Position),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_position)));
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

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct seq_state *this = object;

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
	spa_alsa_seq_reassign_follower(this);
	return 0;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct seq_state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Props:
	{
		struct props *p = &this->props;

		if (param == NULL) {
			reset_props(p);
			return 0;
		}
		spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_Props, NULL,
			SPA_PROP_device,     SPA_POD_OPT_Stringn(p->device, sizeof(p->device)));
		break;
	}
	default:
		return -ENOENT;
	}

	return 0;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct seq_state *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		if ((res = spa_alsa_seq_start(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_Pause:
	case SPA_NODE_COMMAND_Suspend:
		if ((res = spa_alsa_seq_pause(this)) < 0)
			return res;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static const struct spa_dict_item node_info_items[] = {
	{ SPA_KEY_DEVICE_API, "alsa" },
	{ SPA_KEY_MEDIA_CLASS, "Midi/Bridge" },
	{ SPA_KEY_NODE_DRIVER, "true" },
};

static void emit_node_info(struct seq_state *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		this->info.props = &SPA_DICT_INIT_ARRAY(node_info_items);
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static inline void clean_name(char *name)
{
	char *c;
	for (c = name; *c; ++c) {
		if (!isalnum(*c) && strchr(" /_:()[]", *c) == NULL)
			*c = '-';
	}
}

static void emit_port_info(struct seq_state *this, struct seq_port *port, bool full)
{
	if (full)
		port->info.change_mask = port->info_all;
	if (port->info.change_mask) {
		struct spa_dict_item items[5];
		uint32_t n_items = 0;
		int id;
		snd_seq_port_info_t *info;
		snd_seq_client_info_t *client_info;
		char card[8];
		char name[128];
		char path[128];
		char alias[128];

		snd_seq_port_info_alloca(&info);
		snd_seq_get_any_port_info(this->sys.hndl,
				port->addr.client, port->addr.port, info);

		snd_seq_client_info_alloca(&client_info);
		snd_seq_get_any_client_info(this->sys.hndl,
				port->addr.client, client_info);

		snprintf(name, sizeof(name), "%s:(%s_%d) %s",
				snd_seq_client_info_get_name(client_info),
				port->direction == SPA_DIRECTION_OUTPUT ? "capture" : "playback",
				port->addr.port,
				snd_seq_port_info_get_name(info));
		clean_name(name);

		snprintf(path, sizeof(path), "alsa:seq:%s:client_%d:%s_%d",
				this->props.device,
				port->addr.client,
				port->direction == SPA_DIRECTION_OUTPUT ? "capture" : "playback",
				port->addr.port);
		clean_name(path);

		snprintf(alias, sizeof(alias), "%s:%s",
				snd_seq_client_info_get_name(client_info),
				snd_seq_port_info_get_name(info));
		clean_name(alias);

		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_FORMAT_DSP, "8 bit raw midi");
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_OBJECT_PATH, path);
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_NAME, name);
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_PORT_ALIAS, alias);
		if ((id = snd_seq_client_info_get_card(client_info)) != -1) {
			snprintf(card, sizeof(card), "%d", id);
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_CARD, card);
		}
		port->info.props = &SPA_DICT_INIT(items, n_items);

		spa_node_emit_port_info(&this->hooks,
				port->direction, port->id, &port->info);
		port->info.change_mask = 0;
	}
}

static void emit_stream_info(struct seq_state *this, struct seq_stream *stream, bool full)
{
	uint32_t i;

	for (i = 0; i < MAX_PORTS; i++) {
		struct seq_port *port = &stream->ports[i];
		if (port->valid)
			emit_port_info(this, port, full);
	}
}

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct seq_state *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	emit_stream_info(this, &this->streams[SPA_DIRECTION_INPUT], true);
	emit_stream_info(this, &this->streams[SPA_DIRECTION_OUTPUT], true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *data)
{
	struct seq_state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	this->callbacks = SPA_CALLBACKS_INIT(callbacks, data);

	return 0;
}

static int impl_node_sync(void *object, int seq)
{
	struct seq_state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_node_emit_result(&this->hooks, seq, 0, 0, NULL);

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

static struct seq_port *alloc_port(struct seq_state *state, struct seq_stream *stream)
{
	uint32_t i;
	for (i = 0; i < MAX_PORTS; i++) {
		struct seq_port *port = &stream->ports[i];
		if (!port->valid) {
			port->id = i;
			port->direction = stream->direction;
			port->valid = true;
			if (stream->last_port < i + 1)
				stream->last_port = i + 1;
			return port;
		}
	}
	return NULL;
}

static void free_port(struct seq_state *state, struct seq_stream *stream, struct seq_port *port)
{
	if (port->id + 1 == stream->last_port) {
		int i;
		for (i = stream->last_port - 1; i >= 0; i--)
			if (!stream->ports[i].valid)
				break;
		stream->last_port = i + 1;
	}
	spa_node_emit_port_info(&state->hooks,
			port->direction, port->id, NULL);
	spa_zero(*port);
}

static void init_port(struct seq_state *state, struct seq_port *port, const snd_seq_addr_t *addr,
		unsigned int caps)
{
	port->addr = *addr;
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PROPS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_LIVE;
	if (caps & (SND_SEQ_PORT_TYPE_HARDWARE|SND_SEQ_PORT_TYPE_PORT|SND_SEQ_PORT_TYPE_SPECIFIC))
		port->info.flags |= SPA_PORT_FLAG_PHYSICAL | SPA_PORT_FLAG_TERMINAL;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);

	port->info.params = port->params;
	port->info.n_params = 5;

	spa_list_init(&port->free);
	spa_list_init(&port->ready);

	spa_alsa_seq_activate_port(state, port, true);

	emit_port_info(state, port, true);
}

static void update_stream_port(struct seq_state *state, struct seq_stream *stream,
		const snd_seq_addr_t *addr, unsigned int caps, const snd_seq_port_info_t *info)
{
	struct seq_port *port = find_port(state, stream, addr);

	if (info == NULL) {
		spa_log_debug(state->log, "free port %d.%d", addr->client, addr->port);
		if (port)
			free_port(state, stream, port);
	} else {
		if (port == NULL && (caps & stream->caps) == stream->caps) {
			spa_log_debug(state->log, "new port %d.%d", addr->client, addr->port);
			port = alloc_port(state, stream);
			if (port == NULL)
				return;
			init_port(state, port, addr, caps);
		} else if (port != NULL) {
			if ((caps & stream->caps) != stream->caps) {
				spa_log_debug(state->log, "free port %d.%d", addr->client, addr->port);
				free_port(state, stream, port);
			}
			else {
				spa_log_debug(state->log, "update port %d.%d", addr->client, addr->port);
				port->info.change_mask = SPA_PORT_CHANGE_MASK_PROPS;
				emit_port_info(state, port, false);
			}
		}
	}
}

static int on_port_info(void *data, const snd_seq_addr_t *addr, const snd_seq_port_info_t *info)
{
	struct seq_state *state = data;

	if (info == NULL) {
		update_stream_port(state, &state->streams[SPA_DIRECTION_INPUT], addr, 0, info);
		update_stream_port(state, &state->streams[SPA_DIRECTION_OUTPUT], addr, 0, info);
	} else {
		unsigned int caps = snd_seq_port_info_get_capability(info);

		if (caps & SND_SEQ_PORT_CAP_NO_EXPORT)
			return 0;

		update_stream_port(state, &state->streams[SPA_DIRECTION_INPUT], addr, caps, info);
		update_stream_port(state, &state->streams[SPA_DIRECTION_OUTPUT], addr, caps, info);
	}
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
	struct seq_state *this = object;
	struct seq_port *port;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if (result.index > 0)
			return 0;
		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_application),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
		break;

	case SPA_PARAM_Format:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;
		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_application),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));
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
							4096, 4096, INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(1),
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

static int clear_buffers(struct seq_state *this, struct seq_port *port)
{
	if (port->n_buffers > 0) {
		spa_list_init(&port->free);
		spa_list_init(&port->ready);
		port->n_buffers = 0;
	}
	return 0;
}

static int port_set_format(void *object, struct seq_port *port,
			   uint32_t flags, const struct spa_pod *format)
{
	struct seq_state *this = object;
	int err;

	if (format == NULL) {
		if (!port->have_format)
			return 0;

		clear_buffers(this, port);
		port->have_format = false;
	} else {
		struct spa_audio_info info = { 0 };

		if ((err = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return err;

		if (info.media_type != SPA_MEDIA_TYPE_application ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_control)
			return -EINVAL;

		port->current_format = info;
		port->have_format = true;
	}

	port->info.change_mask |= SPA_PORT_CHANGE_MASK_RATE;
	port->info.rate = SPA_FRACTION(1, 1);
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
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
	struct seq_state *this = object;
	struct seq_port *port;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

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
	struct seq_state *this = object;
	struct seq_port *port;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_log_debug(this->log, NAME " %p: port %d.%d buffers:%d format:%d", this,
			direction, port_id, n_buffers, port->have_format);

	if (!port->have_format)
		return -EIO;

	clear_buffers(this, port);

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &port->buffers[i];
		struct spa_data *d = buffers[i]->datas;

		b->buf = buffers[i];
		b->id = i;
		b->flags = BUFFER_FLAG_OUT;

		b->h = spa_buffer_find_meta_data(b->buf, SPA_META_Header, sizeof(*b->h));

		if (d[0].data == NULL) {
			spa_log_error(this->log, NAME " %p: need mapped memory", this);
			return -EINVAL;
		}
		if (direction == SPA_DIRECTION_OUTPUT)
			spa_alsa_seq_recycle_buffer(this, port, i);
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
	struct seq_state *this = object;
	struct seq_port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	spa_log_debug(this->log, NAME " %p: io %d.%d %d %p %zd", this,
			direction, port_id, id, data, size);

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
	struct seq_state *this = object;
	struct seq_port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(!CHECK_PORT(this, SPA_DIRECTION_OUTPUT, port_id), -EINVAL);

	port = GET_PORT(this, SPA_DIRECTION_OUTPUT, port_id);

	if (port->n_buffers == 0)
		return -EIO;

	if (buffer_id >= port->n_buffers)
		return -EINVAL;

	spa_alsa_seq_recycle_buffer(this, port, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct seq_state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	return spa_alsa_seq_process(this);
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

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct seq_state *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct seq_state *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Node) == 0)
		*interface = &this->node;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	struct seq_state *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	this = (struct seq_state *) handle;

	spa_alsa_seq_close(this);
	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct seq_state);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct seq_state *this;
	uint32_t i;
	int res;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct seq_state *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);
	this->main_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Loop);

	if (this->data_loop == NULL) {
		spa_log_error(this->log, "a data loop is needed");
		return -EINVAL;
	}
	if (this->data_system == NULL) {
		spa_log_error(this->log, "a data system is needed");
		return -EINVAL;
	}

	this->node.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_Node, SPA_VERSION_NODE, &impl_node, this);

	spa_hook_list_init(&this->hooks);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info.max_input_ports = MAX_PORTS;
	this->info.max_output_ports = MAX_PORTS;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	this->info.params = this->params;
	this->info.n_params = 3;
	reset_props(&this->props);

	for (i = 0; info && i < info->n_items; i++) {
		if (!strcmp(info->items[i].key, SPA_KEY_API_ALSA_PATH)) {
			snprintf(this->props.device, 63, "%s", info->items[i].value);
		}
	}

	this->port_info = on_port_info;
	this->port_info_data = this;

	if ((res = spa_alsa_seq_open(this)) < 0)
		return res;

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Node,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	if (*index >= SPA_N_ELEMENTS(impl_interfaces))
		return 0;

	*info = &impl_interfaces[(*index)++];

	return 1;
}

static const struct spa_dict_item info_items[] = {
	{ SPA_KEY_FACTORY_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ SPA_KEY_FACTORY_DESCRIPTION, "Bridge midi ports with the alsa sequencer API" },
	{ SPA_KEY_FACTORY_USAGE, "["SPA_KEY_API_ALSA_PATH"=<device>]" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_alsa_seq_bridge_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_ALSA_SEQ_BRIDGE,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
