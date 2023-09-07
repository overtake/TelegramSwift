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

#define NAME "alsa-pcm-source"

#include "alsa-pcm.h"

#define CHECK_PORT(this,d,p)    ((d) == SPA_DIRECTION_OUTPUT && (p) == 0)

static const char default_device[] = "hw:0";
static const uint32_t default_min_latency = MIN_LATENCY;
static const uint32_t default_max_latency = MAX_LATENCY;

static void reset_props(struct props *props)
{
	strncpy(props->device, default_device, 64);
	props->min_latency = default_min_latency;
	props->max_latency = default_max_latency;
	props->use_chmap = DEFAULT_USE_CHMAP;
}

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct state *this = object;
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
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_deviceName),
				SPA_PROP_INFO_name, SPA_POD_String("The ALSA device name"),
				SPA_PROP_INFO_type, SPA_POD_Stringn(p->device_name, sizeof(p->device_name)));
			break;
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_cardName),
				SPA_PROP_INFO_name, SPA_POD_String("The ALSA card name"),
				SPA_PROP_INFO_type, SPA_POD_Stringn(p->card_name, sizeof(p->card_name)));
			break;
		case 3:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_minLatency),
				SPA_PROP_INFO_name, SPA_POD_String("The minimum latency"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Int(p->min_latency, 1, INT32_MAX));
			break;
		case 4:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_maxLatency),
				SPA_PROP_INFO_name, SPA_POD_String("The maximum latency"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Int(p->max_latency, 1, INT32_MAX));
			break;
		case 5:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_START_CUSTOM),
				SPA_PROP_INFO_name, SPA_POD_String("Use the driver channelmap"),
				SPA_PROP_INFO_type, SPA_POD_Bool(p->use_chmap));
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
				SPA_PROP_device,       SPA_POD_Stringn(p->device, sizeof(p->device)),
				SPA_PROP_deviceName,   SPA_POD_Stringn(p->device_name, sizeof(p->device_name)),
				SPA_PROP_cardName,     SPA_POD_Stringn(p->card_name, sizeof(p->card_name)),
				SPA_PROP_minLatency,   SPA_POD_Int(p->min_latency),
				SPA_PROP_maxLatency,   SPA_POD_Int(p->max_latency),
				SPA_PROP_START_CUSTOM, SPA_POD_Bool(p->use_chmap));
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
	struct state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_IO_Clock:
		if (size > 0 && size < sizeof(struct spa_io_clock))
			return -EINVAL;
		this->clock = data;
		break;
	case SPA_IO_Position:
		this->position = data;
		break;
	default:
		return -ENOENT;
	}
	spa_alsa_reassign_follower(this);
	return 0;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct state *this = object;

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
			SPA_PROP_device,       SPA_POD_OPT_Stringn(p->device, sizeof(p->device)),
			SPA_PROP_minLatency,   SPA_POD_OPT_Int(&p->min_latency),
			SPA_PROP_maxLatency,   SPA_POD_OPT_Int(&p->max_latency),
			SPA_PROP_START_CUSTOM, SPA_POD_OPT_Bool(&p->use_chmap));
		break;
	}
	default:
		return -ENOENT;
	}

	return 0;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct state *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_ParamBegin:
		if ((res = spa_alsa_open(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_ParamEnd:
		if (this->have_format)
			return 0;
		if ((res = spa_alsa_close(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_Start:
		if (!this->have_format)
			return -EIO;
		if (this->n_buffers == 0)
			return -EIO;

		if ((res = spa_alsa_start(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_Pause:
	case SPA_NODE_COMMAND_Suspend:
		if ((res = spa_alsa_pause(this)) < 0)
			return res;
		break;
	default:
		return -ENOTSUP;
	}
	return 0;
}

static void emit_node_info(struct state *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		struct spa_dict_item items[4];
		uint32_t n_items = 0;
		char latency[64];

		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_API, "alsa");
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_MEDIA_CLASS, "Audio/Source");
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_DRIVER, "true");
		if (this->have_format) {
			snprintf(latency, sizeof(latency), "%lu/%d", this->buffer_frames / 4, this->rate);
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_NODE_MAX_LATENCY, latency);
		}
		this->info.props = &SPA_DICT_INIT(items, n_items);

		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static void emit_port_info(struct state *this, bool full)
{
	if (full)
		this->port_info.change_mask = this->port_info_all;
	if (this->port_info.change_mask) {
		spa_node_emit_port_info(&this->hooks,
				SPA_DIRECTION_OUTPUT, 0, &this->port_info);
		this->port_info.change_mask = 0;
	}
}

static int
impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct state *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_node_info(this, true);
	emit_port_info(this, true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int
impl_node_set_callbacks(void *object,
			const struct spa_node_callbacks *callbacks,
			void *data)
{
	struct state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	this->callbacks = SPA_CALLBACKS_INIT(callbacks, data);

	return 0;
}

static int impl_node_sync(void *object, int seq)
{
	struct state *this = object;

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
	struct state *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		return spa_alsa_enum_format(this, seq, start, num, filter);

	case SPA_PARAM_Format:
		if (!this->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_format_audio_raw_build(&b, id, &this->current_format.info.raw);
		break;

	case SPA_PARAM_Buffers:
		if (!this->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(2, 1, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(this->blocks),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							this->props.max_latency * this->frame_size,
							this->props.min_latency * this->frame_size,
							INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(this->frame_size),
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

static int clear_buffers(struct state *this)
{
	if (this->n_buffers > 0) {
		spa_list_init(&this->free);
		spa_list_init(&this->ready);
		this->n_buffers = 0;
	}
	return 0;
}

static int port_set_format(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t flags, const struct spa_pod *format)
{
	struct state *this = object;
	int err;

	if (format == NULL) {
		if (!this->have_format)
			return 0;

		spa_alsa_pause(this);
		clear_buffers(this);
		spa_alsa_close(this);
		this->have_format = false;
	} else {
		struct spa_audio_info info = { 0 };

		if ((err = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return err;

		if (info.media_type != SPA_MEDIA_TYPE_audio ||
		    info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
			return -EINVAL;

		if (spa_format_audio_raw_parse(format, &info.info.raw) < 0)
			return -EINVAL;

		if ((err = spa_alsa_set_format(this, &info, flags)) < 0)
			return err;

		this->current_format = info;
		this->have_format = true;
	}

	this->info.change_mask |= SPA_NODE_CHANGE_MASK_PROPS;
	emit_node_info(this, false);

	this->port_info.change_mask |= SPA_PORT_CHANGE_MASK_RATE;
	this->port_info.rate = SPA_FRACTION(1, this->rate);
	this->port_info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (this->have_format) {
		this->port_params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		this->port_params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		this->port_params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		this->port_params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	}
	emit_port_info(this, false);

	return 0;
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct state *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	switch (id) {
	case SPA_PARAM_Format:
		res = port_set_format(this, direction, port_id, flags, param);
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
	struct state *this = object;
	int res;
	uint32_t i;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	if (!this->have_format)
		return -EIO;

	spa_log_debug(this->log, NAME " %p: use %d buffers", this, n_buffers);

	if (this->n_buffers > 0) {
		spa_alsa_pause(this);
		if ((res = clear_buffers(this)) < 0)
			return res;
	}
	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &this->buffers[i];
		struct spa_data *d = buffers[i]->datas;

		b->buf = buffers[i];
		b->id = i;
		b->flags = 0;

		b->h = spa_buffer_find_meta_data(b->buf, SPA_META_Header, sizeof(*b->h));

		if (d[0].data == NULL) {
			spa_log_error(this->log, NAME " %p: need mapped memory", this);
			return -EINVAL;
		}
		spa_list_append(&this->free, &b->link);
	}
	this->n_buffers = n_buffers;

	return 0;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction,
		      uint32_t port_id,
		      uint32_t id,
		      void *data, size_t size)
{
	struct state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	spa_log_debug(this->log, NAME " %p: io %d %p %zd", this, id, data, size);

	switch (id) {
	case SPA_IO_Buffers:
		this->io = data;
		break;
	case SPA_IO_RateMatch:
		this->rate_match = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct state *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_return_val_if_fail(port_id == 0, -EINVAL);

	if (this->n_buffers == 0)
		return -EIO;

	if (buffer_id >= this->n_buffers)
		return -EINVAL;

	spa_alsa_recycle_buffer(this, buffer_id);

	return 0;
}

static int impl_node_process(void *object)
{
	struct state *this = object;
	struct spa_io_buffers *io;
	struct buffer *b;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	io = this->io;
	spa_return_val_if_fail(io != NULL, -EIO);

	spa_log_trace_fp(this->log, NAME " %p; status %d", this, io->status);

	if (io->status == SPA_STATUS_HAVE_DATA)
		return SPA_STATUS_HAVE_DATA;

	if (io->buffer_id < this->n_buffers) {
		spa_alsa_recycle_buffer(this, io->buffer_id);
		io->buffer_id = SPA_ID_INVALID;
	}

	if (spa_list_is_empty(&this->ready) && this->following)
		spa_alsa_read(this, 0);

	if (spa_list_is_empty(&this->ready) || !this->following)
		return SPA_STATUS_OK;

	b = spa_list_first(&this->ready, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUT);

	spa_log_trace_fp(this->log, NAME " %p: dequeue buffer %d", this, b->id);

	io->buffer_id = b->id;
	io->status = SPA_STATUS_HAVE_DATA;

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

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct state *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct state *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Node) == 0)
		*interface = &this->node;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	struct state *this;
	spa_return_val_if_fail(handle != NULL, -EINVAL);
	this = (struct state *) handle;
	spa_alsa_close(this);
	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct state);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct state *this;
	uint32_t i;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct state *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_system = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataSystem);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);

	if (this->data_loop == NULL) {
		spa_log_error(this->log, NAME" %p: a data loop is needed", this);
		return -EINVAL;
	}
	if (this->data_system == NULL) {
		spa_log_error(this->log, NAME" %p: a data system is needed", this);
		return -EINVAL;
	}

	this->node.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_Node, SPA_VERSION_NODE, &impl_node, this);

	spa_hook_list_init(&this->hooks);
	this->stream = SND_PCM_STREAM_CAPTURE;

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info.max_output_ports = 1;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	this->info.params = this->params;
	this->info.n_params = 3;
	reset_props(&this->props);

	this->port_info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	this->port_info = SPA_PORT_INFO_INIT();
	this->port_info.flags = SPA_PORT_FLAG_LIVE |
			   SPA_PORT_FLAG_PHYSICAL |
			   SPA_PORT_FLAG_TERMINAL;
	this->port_params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	this->port_params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	this->port_params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	this->port_params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	this->port_params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	this->port_info.params = this->port_params;
	this->port_info.n_params = 5;

	spa_list_init(&this->free);
	spa_list_init(&this->ready);

	snd_config_update_free_global();

	for (i = 0; info && i < info->n_items; i++) {
		const char *k = info->items[i].key;
		const char *s = info->items[i].value;
		if (!strcmp(k, SPA_KEY_API_ALSA_PATH)) {
			snprintf(this->props.device, 63, "%s", s);
		} else if (!strcmp(k, SPA_KEY_AUDIO_CHANNELS)) {
			this->default_channels = atoi(s);
		} else if (!strcmp(k, SPA_KEY_AUDIO_RATE)) {
			this->default_rate = atoi(s);
		} else if (!strcmp(k, SPA_KEY_AUDIO_FORMAT)) {
			this->default_format = spa_alsa_format_from_name(s, strlen(s));
		} else if (!strcmp(k, SPA_KEY_AUDIO_POSITION)) {
			spa_alsa_parse_position(&this->default_pos, s, strlen(s));
		} else if (!strcmp(k, "api.alsa.period-size")) {
			this->default_period_size = atoi(s);
		} else if (!strcmp(k, "api.alsa.headroom")) {
			this->default_headroom = atoi(s);
		} else if (!strcmp(k, "api.alsa.disable-mmap")) {
			this->disable_mmap = (strcmp(s, "true") == 0 || atoi(s) == 1);
		} else if (!strcmp(k, "api.alsa.disable-batch")) {
			this->disable_batch = (strcmp(s, "true") == 0 || atoi(s) == 1);
		} else if (!strcmp(k, "api.alsa.use-chmap")) {
			this->props.use_chmap = (strcmp(s, "true") == 0 || atoi(s) == 1);
		}
	}
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
	{ SPA_KEY_FACTORY_DESCRIPTION, "Record audio with the alsa API" },
	{ SPA_KEY_FACTORY_USAGE, "["SPA_KEY_API_ALSA_PATH"=<device>]" },
};

static const struct spa_dict info = SPA_DICT_INIT_ARRAY(info_items);

const struct spa_handle_factory spa_alsa_source_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_ALSA_PCM_SOURCE,
	&info,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
