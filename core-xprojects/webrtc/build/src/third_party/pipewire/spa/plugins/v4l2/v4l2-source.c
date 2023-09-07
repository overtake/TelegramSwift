/* Spa V4l2 Source
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
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <linux/videodev2.h>

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/utils/list.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/monitor/device.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/node/keys.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/debug/pod.h>

#include "v4l2.h"

#define NAME "v4l2-source"

static const char default_device[] = "/dev/video0";

struct props {
	char device[64];
	char device_name[128];
	int device_fd;
};

static void reset_props(struct props *props)
{
	strncpy(props->device, default_device, 64);
}

#define MAX_BUFFERS     32

#define BUFFER_FLAG_OUTSTANDING	(1<<0)
#define BUFFER_FLAG_ALLOCATED	(1<<1)
#define BUFFER_FLAG_MAPPED	(1<<2)

struct buffer {
	uint32_t id;
	uint32_t flags;
	struct spa_list link;
	struct spa_buffer *outbuf;
	struct spa_meta_header *h;
	struct v4l2_buffer v4l2_buffer;
	void *ptr;
};

#define MAX_CONTROLS	64

struct control {
	uint32_t id;
	uint32_t ctrl_id;
	double value;
};

struct port {
	struct impl *impl;

	bool alloc_buffers;
	bool have_expbuf;

	bool next_fmtdesc;
	struct v4l2_fmtdesc fmtdesc;
	bool next_frmsize;
	struct v4l2_frmsizeenum frmsize;
	struct v4l2_frmivalenum frmival;

	bool have_format;
	struct spa_video_info current_format;
	struct spa_fraction rate;

	struct spa_v4l2_device dev;

	bool have_query_ext_ctrl;
	struct v4l2_format fmt;
	enum v4l2_buf_type type;
	enum v4l2_memory memtype;

	struct control controls[MAX_CONTROLS];
	uint32_t n_controls;

	struct buffer buffers[MAX_BUFFERS];
	uint32_t n_buffers;
	struct spa_list queue;

	struct spa_source source;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_io_buffers *io;
	struct spa_io_sequence *control;
	struct spa_param_info params[8];
};

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_loop *data_loop;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[8];
	struct props props;

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	struct port out_ports[1];

	struct spa_io_position *position;
	struct spa_io_clock *clock;
};

#define CHECK_PORT(this,direction,port_id)  ((direction) == SPA_DIRECTION_OUTPUT && (port_id) == 0)

#define GET_OUT_PORT(this,p)         (&this->out_ports[p])
#define GET_PORT(this,d,p)           GET_OUT_PORT(this,p)

#include "v4l2-utils.c"

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
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_device),
				SPA_PROP_INFO_name, SPA_POD_String("The V4L2 device"),
				SPA_PROP_INFO_type, SPA_POD_String(p->device));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_deviceName),
				SPA_PROP_INFO_name, SPA_POD_String("The V4L2 device name"),
				SPA_PROP_INFO_type, SPA_POD_String(p->device_name));
			break;
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_deviceFd),
				SPA_PROP_INFO_name, SPA_POD_String("The V4L2 fd"),
				SPA_PROP_INFO_type, SPA_POD_Int(p->device_fd));
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
				SPA_PROP_device,     SPA_POD_String(p->device),
				SPA_PROP_deviceName, SPA_POD_String(p->device_name),
				SPA_PROP_deviceFd,   SPA_POD_Int(p->device_fd));
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

static int impl_node_set_param(void *object,
			       uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	struct impl *this = object;

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
			SPA_PROP_device, SPA_POD_OPT_Stringn(p->device, sizeof(p->device)));
		break;
	}
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;

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
	return 0;
}

static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(command != NULL, -EINVAL);

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
	{
		struct port *port = GET_OUT_PORT(this, 0);

		if (!port->have_format) {
			spa_log_error(this->log, "no format");
			return -EIO;
		}
		if (port->n_buffers == 0) {
			spa_log_error(this->log, "no buffers");
			return -EIO;
		}

		if ((res = spa_v4l2_stream_on(this)) < 0)
			return res;
		break;
	}
	case SPA_NODE_COMMAND_Pause:
	case SPA_NODE_COMMAND_Suspend:
		if ((res = spa_v4l2_stream_off(this)) < 0)
			return res;
		break;
	default:
		return -ENOTSUP;
	}

	return 0;
}

static const struct spa_dict_item info_items[] = {
	{ SPA_KEY_DEVICE_API, "v4l2" },
	{ SPA_KEY_MEDIA_CLASS, "Video/Source" },
	{ SPA_KEY_MEDIA_ROLE, "Camera" },
	{ SPA_KEY_NODE_DRIVER, "true" },
};

static void emit_node_info(struct impl *this, bool full)
{
	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		this->info.props = &SPA_DICT_INIT_ARRAY(info_items);
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
	emit_port_info(this, GET_OUT_PORT(this, 0), true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}

static int impl_node_set_callbacks(void *object,
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

static int impl_node_add_port(void *object,
			      enum spa_direction direction,
			      uint32_t port_id, const struct spa_dict *props)
{
	return -ENOTSUP;
}

static int impl_node_remove_port(void *object,
		                 enum spa_direction direction,
				 uint32_t port_id)
{
	return -ENOTSUP;
}

static int port_get_format(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t index,
			   const struct spa_pod *filter,
			   struct spa_pod **param,
			   struct spa_pod_builder *builder)
{
	struct impl *this = object;
	struct port *port = GET_PORT(this, direction, port_id);
	struct spa_pod_frame f;

	if (!port->have_format)
		return -EIO;
	if (index > 0)
		return 0;

	spa_pod_builder_push_object(builder, &f, SPA_TYPE_OBJECT_Format, SPA_PARAM_Format);
	spa_pod_builder_add(builder,
		SPA_FORMAT_mediaType,    SPA_POD_Id(port->current_format.media_type),
		SPA_FORMAT_mediaSubtype, SPA_POD_Id(port->current_format.media_subtype),
		0);

	switch (port->current_format.media_subtype) {
	case SPA_MEDIA_SUBTYPE_raw:
		spa_pod_builder_add(builder,
			SPA_FORMAT_VIDEO_format,    SPA_POD_Id(port->current_format.info.raw.format),
			SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&port->current_format.info.raw.size),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&port->current_format.info.raw.framerate),
			0);
		break;
	case SPA_MEDIA_SUBTYPE_mjpg:
	case SPA_MEDIA_SUBTYPE_jpeg:
		spa_pod_builder_add(builder,
			SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&port->current_format.info.mjpg.size),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&port->current_format.info.mjpg.framerate),
			0);
		break;
	case SPA_MEDIA_SUBTYPE_h264:
		spa_pod_builder_add(builder,
			SPA_FORMAT_VIDEO_size,      SPA_POD_Rectangle(&port->current_format.info.h264.size),
			SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&port->current_format.info.h264.framerate),
			0);
		break;
	default:
		return -EIO;
	}

	*param = spa_pod_builder_pop(builder, &f);

	return 1;
}

static int impl_node_port_enum_params(void *object, int seq,
				      enum spa_direction direction,
				      uint32_t port_id,
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

	port = GET_PORT(this, direction, port_id);

	result.id = id;
	result.next = start;
     next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_PropInfo:
		return spa_v4l2_enum_controls(this, seq, start, num, filter);

	case SPA_PARAM_EnumFormat:
		return spa_v4l2_enum_format(this, seq, start, num, filter);

	case SPA_PARAM_Format:
		if((res = port_get_format(this, direction, port_id,
						result.index, filter, &param, &b)) <= 0)
			return res;
		break;
	case SPA_PARAM_Buffers:
		if (!port->have_format)
			return -EIO;
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(MAX_BUFFERS, 2, MAX_BUFFERS),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_Int(port->fmt.fmt.pix.sizeimage),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(port->fmt.fmt.pix.bytesperline),
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
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Clock),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_clock)));
			break;
		case 2:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id,   SPA_POD_Id(SPA_IO_Control),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_sequence)));
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

static int port_set_format(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t flags,
			   const struct spa_pod *format)
{
	struct impl *this = object;
	struct spa_video_info info;
	struct port *port = GET_PORT(this, direction, port_id);
	int res;

	if (port->have_format) {
		spa_v4l2_stream_off(this);
		spa_v4l2_clear_buffers(this);
	}
	if (format == NULL) {
		if (!port->have_format)
			return 0;

		port->have_format = false;
		port->dev.have_format = false;
		spa_v4l2_close(&port->dev);
		goto done;
	} else {
		if ((res = spa_format_parse(format, &info.media_type, &info.media_subtype)) < 0)
			return res;

		if (info.media_type != SPA_MEDIA_TYPE_video) {
			spa_log_error(this->log, "media type must be video");
			return -EINVAL;
		}

		switch (info.media_subtype) {
		case SPA_MEDIA_SUBTYPE_raw:
			if (spa_format_video_raw_parse(format, &info.info.raw) < 0) {
				spa_log_error(this->log, "can't parse video raw");
				return -EINVAL;
			}
			break;
		case SPA_MEDIA_SUBTYPE_mjpg:
			if (spa_format_video_mjpg_parse(format, &info.info.mjpg) < 0)
				return -EINVAL;
			break;
		case SPA_MEDIA_SUBTYPE_h264:
			if (spa_format_video_h264_parse(format, &info.info.h264) < 0)
				return -EINVAL;
			break;
		default:
			return -EINVAL;
		}
	}

	if (port->have_format && !SPA_FLAG_IS_SET(flags, SPA_NODE_PARAM_FLAG_TEST_ONLY)) {
		port->have_format = false;
	}

	if ((res = spa_v4l2_set_format(this, &info, flags)) < 0)
		return res;

	if (!SPA_FLAG_IS_SET(flags, SPA_NODE_PARAM_FLAG_TEST_ONLY)) {
		port->current_format = info;
		port->have_format = true;
	}

    done:
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_PARAMS;
	if (port->have_format) {
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
		port->params[5] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	} else {
		port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		port->params[5] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	}
	emit_port_info(this, port, false);

	return 0;
}

static int impl_node_port_set_param(void *object,
				    enum spa_direction direction, uint32_t port_id,
				    uint32_t id, uint32_t flags,
				    const struct spa_pod *param)
{
	spa_return_val_if_fail(object != NULL, -EINVAL);

	spa_return_val_if_fail(CHECK_PORT(object, direction, port_id), -EINVAL);

	if (id == SPA_PARAM_Format) {
		return port_set_format(object, direction, port_id, flags, param);
	}
	else
		return -ENOENT;
}

static int impl_node_port_use_buffers(void *object,
				      enum spa_direction direction,
				      uint32_t port_id,
				      uint32_t flags,
				      struct spa_buffer **buffers,
				      uint32_t n_buffers)
{
	struct impl *this = object;
	struct port *port;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	if (!port->have_format)
		return -EIO;

	if (port->n_buffers) {
		spa_v4l2_stream_off(this);
		if ((res = spa_v4l2_clear_buffers(this)) < 0)
			return res;
	}
	if (buffers == NULL)
		return 0;

	if (flags & SPA_NODE_BUFFERS_FLAG_ALLOC) {
		res = spa_v4l2_alloc_buffers(this, buffers, n_buffers);
	} else {
		res = spa_v4l2_use_buffers(this, buffers, n_buffers);
	}
	return res;
}

static int impl_node_port_set_io(void *object,
				 enum spa_direction direction,
				 uint32_t port_id,
				 uint32_t id,
				 void *data, size_t size)
{
	struct impl *this = object;
	struct port *port;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(CHECK_PORT(this, direction, port_id), -EINVAL);

	port = GET_PORT(this, direction, port_id);

	switch (id) {
	case SPA_IO_Buffers:
		port->io = data;
		break;
	case SPA_IO_Control:
		port->control = data;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_node_port_reuse_buffer(void *object,
				       uint32_t port_id,
				       uint32_t buffer_id)
{
	struct impl *this = object;
	struct port *port;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(port_id == 0, -EINVAL);

	port = GET_OUT_PORT(this, port_id);

	spa_return_val_if_fail(buffer_id < port->n_buffers, -EINVAL);

	res = spa_v4l2_buffer_recycle(this, buffer_id);

	return res;
}

static uint32_t prop_to_control_id(uint32_t prop)
{
	switch (prop) {
	case SPA_PROP_brightness:
		return V4L2_CID_BRIGHTNESS;
	case SPA_PROP_contrast:
		return V4L2_CID_CONTRAST;
	case SPA_PROP_saturation:
		return V4L2_CID_SATURATION;
	case SPA_PROP_hue:
		return V4L2_CID_HUE;
	case SPA_PROP_gamma:
		return V4L2_CID_GAMMA;
	case SPA_PROP_exposure:
		return V4L2_CID_EXPOSURE;
	case SPA_PROP_gain:
		return V4L2_CID_GAIN;
	case SPA_PROP_sharpness:
		return V4L2_CID_SHARPNESS;
	default:
		return 0;
	}
}

static void set_control(struct impl *this, struct port *port, uint32_t control_id, float value)
{
	struct v4l2_control c;

	spa_zero(c);
	c.id = control_id;
	c.value = value;
	if (ioctl(port->dev.fd, VIDIOC_S_CTRL, &c) < 0)
		spa_log_error(this->log, "VIDIOC_S_CTRL %m");
}

static int process_control(struct impl *this, struct spa_pod_sequence *control)
{
	struct spa_pod_control *c;
	struct port *port;

	SPA_POD_SEQUENCE_FOREACH(control, c) {
		switch (c->type) {
		case SPA_CONTROL_Properties:
		{
			struct spa_pod_prop *prop;
			struct spa_pod_object *obj = (struct spa_pod_object *) &c->value;

			SPA_POD_OBJECT_FOREACH(obj, prop) {
				uint32_t control_id;

				if ((control_id = prop_to_control_id(prop->key)) == 0)
					continue;

				port = GET_OUT_PORT(this, 0);
				set_control(this, port, control_id,
						SPA_POD_VALUE(struct spa_pod_float, &prop->value));
			}
			break;
		}
		default:
			break;
		}
	}
	return 0;
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	int res;
	struct spa_io_buffers *io;
	struct port *port;
	struct buffer *b;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	port = GET_OUT_PORT(this, 0);
	io = port->io;
	spa_return_val_if_fail(io != NULL, -EIO);

	if (port->control)
		process_control(this, &port->control->sequence);

	spa_log_trace(this->log, NAME " %p; status %d", this, io->status);

	if (io->status == SPA_STATUS_HAVE_DATA)
		return SPA_STATUS_HAVE_DATA;

	if (io->buffer_id < port->n_buffers) {
		if ((res = spa_v4l2_buffer_recycle(this, io->buffer_id)) < 0)
			return res;

		io->buffer_id = SPA_ID_INVALID;
	}

	if (spa_list_is_empty(&port->queue))
		return SPA_STATUS_OK;

	b = spa_list_first(&port->queue, struct buffer, link);
	spa_list_remove(&b->link);
	SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUTSTANDING);

	spa_log_trace(this->log, NAME " %p: dequeue buffer %d", this, b->id);

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
	const char *str;
	struct port *port;
	int res;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->data_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DataLoop);

	if (this->data_loop == NULL) {
		spa_log_error(this->log, "a data_loop is needed");
		return -EINVAL;
	}

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);
	spa_hook_list_init(&this->hooks);

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
			SPA_NODE_CHANGE_MASK_PROPS |
			SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.max_output_ports = 1;
	this->info.flags = SPA_NODE_FLAG_RT;
	this->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[1] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 2;
	reset_props(&this->props);

	port = GET_OUT_PORT(this, 0);
	port->impl = this;
	spa_list_init(&port->queue);
	port->info_all = SPA_PORT_CHANGE_MASK_FLAGS |
			SPA_PORT_CHANGE_MASK_PARAMS;
	port->info = SPA_PORT_INFO_INIT();
	port->info.flags = SPA_PORT_FLAG_LIVE |
			   SPA_PORT_FLAG_PHYSICAL |
			   SPA_PORT_FLAG_TERMINAL;
	port->params[0] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	port->params[1] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	port->params[2] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	port->params[3] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	port->params[4] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	port->params[5] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	port->info.params = port->params;
	port->info.n_params = 6;

	port->alloc_buffers = true;
	port->have_expbuf = true;
	port->have_query_ext_ctrl = true;
	port->dev.log = this->log;
	port->dev.fd = -1;

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_V4L2_PATH))) {
		strncpy(this->props.device, str, 63);
		if ((res = spa_v4l2_open(&port->dev, this->props.device)) < 0)
			return res;
		spa_v4l2_close(&port->dev);
	}

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Node,},
};

static int impl_enum_interface_info(const struct spa_handle_factory *factory,
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

const struct spa_handle_factory spa_v4l2_source_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_V4L2_SOURCE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
