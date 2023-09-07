/* SPA
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

#include <spa/support/plugin.h>
#include <spa/support/log.h>
#include <spa/support/cpu.h>

#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/node/keys.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/buffer/alloc.h>
#include <spa/pod/parser.h>
#include <spa/pod/filter.h>
#include <spa/param/param.h>
#include <spa/param/audio/format-utils.h>
#include <spa/debug/format.h>
#include <spa/debug/pod.h>

#define NAME "audioadapter"

#define MAX_PORTS	SPA_AUDIO_MAX_CHANNELS

/** \cond */

struct impl {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_cpu *cpu;

	uint32_t max_align;
	enum spa_direction direction;

	struct spa_node *target;

	struct spa_node *follower;
	struct spa_hook follower_listener;
	uint32_t follower_flags;
	struct spa_audio_info follower_current_format;

	struct spa_handle *hnd_convert;
	struct spa_node *convert;
	struct spa_hook convert_listener;
	uint32_t convert_flags;

	uint32_t n_buffers;
	struct spa_buffer **buffers;

	struct spa_io_buffers io_buffers;
	struct spa_io_rate_match io_rate_match;

	uint64_t info_all;
	struct spa_node_info info;
#define IDX_EnumFormat		0
#define IDX_PropInfo		1
#define IDX_Props		2
#define IDX_Format		3
#define IDX_EnumPortConfig	4
#define IDX_PortConfig		5
	struct spa_param_info params[6];
	uint32_t convert_params_flags[6];
	uint32_t follower_params_flags[6];

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	unsigned int add_listener:1;
	unsigned int have_format:1;
	unsigned int started:1;
	unsigned int driver:1;
	unsigned int async:1;
};

/** \endcond */

static int impl_node_enum_params(void *object, int seq,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
next:
	result.index = result.next;

	spa_log_debug(this->log, NAME" %p: %d id:%u", this, seq, id);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumPortConfig:
	case SPA_PARAM_PortConfig:
		res = spa_node_enum_params(this->convert, seq, id, start, num, filter);
		return res;
	case SPA_PARAM_PropInfo:
	case SPA_PARAM_Props:
	{
		if (result.next < 0x10000) {
			if ((res = spa_node_enum_params_sync(this->convert,
					id, &result.next, filter, &result.param, &b)) == 1)
				break;
			result.next = 0x10000;
		}
		if (result.next >= 0x10000) {
			result.next &= 0xffff;
			if ((res = spa_node_enum_params_sync(this->follower,
					id, &result.next, filter, &result.param, &b)) == 1) {
				result.next |= 0x10000;
				break;
			}
		}
		return res;
	}
	case SPA_PARAM_EnumFormat:
	case SPA_PARAM_Format:
		if ((res = spa_node_port_enum_params_sync(this->follower,
				this->direction, 0,
				id, &result.next, filter, &result.param, &b)) == 1)
			break;
		return res;
	default:
		return -ENOENT;
	}

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int link_io(struct impl *this)
{
	int res;

	if (this->convert == NULL)
		return 0;

	spa_log_debug(this->log, NAME " %p: controls", this);

	spa_zero(this->io_rate_match);
	this->io_rate_match.rate = 1.0;

	if ((res = spa_node_port_set_io(this->follower,
			this->direction, 0,
			SPA_IO_RateMatch,
			&this->io_rate_match, sizeof(this->io_rate_match))) < 0) {
		spa_log_debug(this->log, NAME " %p: set RateMatch on follower disabled %d %s", this,
			res, spa_strerror(res));
	}
	else if ((res = spa_node_port_set_io(this->convert,
			SPA_DIRECTION_REVERSE(this->direction), 0,
			SPA_IO_RateMatch,
			&this->io_rate_match, sizeof(this->io_rate_match))) < 0) {
		spa_log_warn(this->log, NAME " %p: set RateMatch on convert failed %d %s", this,
			res, spa_strerror(res));
	}

	this->io_buffers = SPA_IO_BUFFERS_INIT;

	if ((res = spa_node_port_set_io(this->follower,
			this->direction, 0,
			SPA_IO_Buffers,
			&this->io_buffers, sizeof(this->io_buffers))) < 0) {
		spa_log_warn(this->log, NAME " %p: set Buffers on follower failed %d %s", this,
			res, spa_strerror(res));
		return res;
	}
	else if ((res = spa_node_port_set_io(this->convert,
			SPA_DIRECTION_REVERSE(this->direction), 0,
			SPA_IO_Buffers,
			&this->io_buffers, sizeof(this->io_buffers))) < 0) {
		spa_log_warn(this->log, NAME " %p: set Buffers on convert failed %d %s", this,
			res, spa_strerror(res));
		return res;
	}
	return 0;
}

static void emit_node_info(struct impl *this, bool full)
{
	uint32_t i;

	if (full)
		this->info.change_mask = this->info_all;
	if (this->info.change_mask) {
		if (this->info.change_mask & SPA_NODE_CHANGE_MASK_PARAMS) {
			for (i = 0; i < SPA_N_ELEMENTS(this->params); i++) {
				if (this->params[i].user > 0) {
					this->params[i].flags ^= SPA_PARAM_INFO_SERIAL;
					this->params[i].user = 0;
				}
			}
		}
		spa_node_emit_info(&this->hooks, &this->info);
		this->info.change_mask = 0;
	}
}

static int debug_params(struct impl *this, struct spa_node *node,
                enum spa_direction direction, uint32_t port_id, uint32_t id, struct spa_pod *filter,
		const char *debug, int err)
{
        struct spa_pod_builder b = { 0 };
        uint8_t buffer[4096];
        uint32_t state;
        struct spa_pod *param;
        int res;

        spa_log_error(this->log, "params %s: %d:%d (%s) %s",
			spa_debug_type_find_name(spa_type_param, id),
			direction, port_id, debug, spa_strerror(err));
	if (err == -EBUSY)
		return 0;

        state = 0;
        while (true) {
                spa_pod_builder_init(&b, buffer, sizeof(buffer));
                res = spa_node_port_enum_params_sync(node,
                                       direction, port_id,
                                       id, &state,
                                       NULL, &param, &b);
                if (res != 1) {
			if (res < 0)
				spa_log_error(this->log, "  error: %s", spa_strerror(res));
                        break;
		}
                spa_debug_pod(2, NULL, param);
        }

        spa_log_error(this->log, "failed filter:");
        if (filter)
                spa_debug_pod(2, NULL, filter);

        return 0;
}

static int negotiate_buffers(struct impl *this)
{
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	uint32_t state;
	struct spa_pod *param;
	int res;
	bool follower_alloc, conv_alloc;
	uint32_t i, size, buffers, blocks, align, flags, stride = 0;
	uint32_t *aligns;
	struct spa_data *datas;
	uint32_t follower_flags, conv_flags;

	spa_log_debug(this->log, NAME" %p: %d", this, this->n_buffers);

	if (this->n_buffers > 0)
		return 0;

	state = 0;
	param = NULL;
	if ((res = spa_node_port_enum_params_sync(this->follower,
				this->direction, 0,
				SPA_PARAM_Buffers, &state,
				param, &param, &b)) < 0) {
		if (res == -ENOENT)
			param = NULL;
		else {
			debug_params(this, this->follower, this->direction, 0,
				SPA_PARAM_Buffers, param, "follower buffers", res);
			return res;
		}
	}

	state = 0;
	if ((res = spa_node_port_enum_params_sync(this->convert,
				SPA_DIRECTION_REVERSE(this->direction), 0,
				SPA_PARAM_Buffers, &state,
				param, &param, &b)) != 1) {
		debug_params(this, this->convert,
				SPA_DIRECTION_REVERSE(this->direction), 0,
				SPA_PARAM_Buffers, param, "convert buffers", res);
		return -ENOTSUP;
	}
	if (param == NULL)
		return -ENOTSUP;

	spa_pod_fixate(param);

	follower_flags = this->follower_flags;
	conv_flags = this->convert_flags;

	follower_alloc = SPA_FLAG_IS_SET(follower_flags, SPA_PORT_FLAG_CAN_ALLOC_BUFFERS);
	conv_alloc = SPA_FLAG_IS_SET(conv_flags, SPA_PORT_FLAG_CAN_ALLOC_BUFFERS);

	flags = 0;
	if (conv_alloc || follower_alloc) {
		flags |= SPA_BUFFER_ALLOC_FLAG_NO_DATA;
		if (conv_alloc)
			follower_alloc = false;
	}

	if ((res = spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_ParamBuffers, NULL,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_Int(&buffers),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(&blocks),
			SPA_PARAM_BUFFERS_size,    SPA_POD_Int(&size),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(&stride),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(&align))) < 0)
		return res;

	spa_log_debug(this->log, "%p: buffers:%d, blocks:%d, size:%d, stride:%d align:%d %d:%d",
			this, buffers, blocks, size, stride, align, follower_alloc, conv_alloc);

	align = SPA_MAX(align, this->max_align);

	datas = alloca(sizeof(struct spa_data) * blocks);
	memset(datas, 0, sizeof(struct spa_data) * blocks);
	aligns = alloca(sizeof(uint32_t) * blocks);
	for (i = 0; i < blocks; i++) {
		datas[i].type = SPA_DATA_MemPtr;
		datas[i].flags = SPA_DATA_FLAG_READWRITE | SPA_DATA_FLAG_DYNAMIC;
		datas[i].maxsize = size;
		aligns[i] = align;
	}

	free(this->buffers);
	this->buffers = spa_buffer_alloc_array(buffers, flags, 0, NULL, blocks, datas, aligns);
	if (this->buffers == NULL)
		return -errno;
	this->n_buffers = buffers;

	if ((res = spa_node_port_use_buffers(this->convert,
		       SPA_DIRECTION_REVERSE(this->direction), 0,
		       conv_alloc ? SPA_NODE_BUFFERS_FLAG_ALLOC : 0,
		       this->buffers, this->n_buffers)) < 0)
		return res;

	if ((res = spa_node_port_use_buffers(this->follower,
		       this->direction, 0,
		       follower_alloc ? SPA_NODE_BUFFERS_FLAG_ALLOC : 0,
		       this->buffers, this->n_buffers)) < 0)
		return res;

	return 0;
}

static int configure_format(struct impl *this, uint32_t flags, const struct spa_pod *format)
{
	int res;

	spa_log_debug(this->log, NAME "%p: configure format:", this);
	if (format && spa_log_level_enabled(this->log, SPA_LOG_LEVEL_DEBUG))
		spa_debug_format(0, NULL, format);

	if (this->convert) {
		if ((res = spa_node_port_set_param(this->convert,
					   SPA_DIRECTION_REVERSE(this->direction), 0,
					   SPA_PARAM_Format, flags,
					   format)) < 0)
				return res;
	}

	if ((res = spa_node_port_set_param(this->follower,
					   this->direction, 0,
					   SPA_PARAM_Format, flags,
					   format)) < 0)
			return res;

	this->have_format = format != NULL;
	if (format == NULL) {
		this->n_buffers = 0;
	} else {
		res = negotiate_buffers(this);
	}

	return res;
}

static int impl_node_set_param(void *object, uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	int res = 0, res2 = 0;
	struct impl *this = object;
	struct spa_audio_info info = { 0 };

	spa_log_debug(this->log, NAME" %p: set param %d", this, id);

	switch (id) {
	case SPA_PARAM_Format:
		if (this->started)
			return -EIO;
		if (param == NULL)
			return -EINVAL;

		if ((res = spa_format_parse(param, &info.media_type, &info.media_subtype)) < 0)
			return res;
		if (info.media_type != SPA_MEDIA_TYPE_audio ||
			info.media_subtype != SPA_MEDIA_SUBTYPE_raw)
				return -EINVAL;
		if (spa_format_audio_raw_parse(param, &info.info.raw) < 0)
			return -EINVAL;

		this->follower_current_format = info;
		break;

	case SPA_PARAM_PortConfig:
		if (this->started)
			return -EIO;
		if (this->target != this->follower) {
			if ((res = spa_node_set_param(this->target, id, flags, param)) < 0)
				return res;
		}
		break;

	case SPA_PARAM_Props:
		if (this->target != this->follower)
			res = spa_node_set_param(this->target, id, flags, param);
		res = spa_node_set_param(this->follower, id, flags, param);
		if (res < 0 && res2 < 0)
			return res;
		res = 0;
		break;
	default:
		res = -ENOTSUP;
		break;
	}
	return res;
}

static int impl_node_set_io(void *object, uint32_t id, void *data, size_t size)
{
	struct impl *this = object;
	int res = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (this->target)
		res = spa_node_set_io(this->target, id, data, size);

	if (this->target != this->follower)
		res = spa_node_set_io(this->follower, id, data, size);

	return res;
}

static int negotiate_format(struct impl *this)
{
	uint32_t state;
	struct spa_pod *format;
	uint8_t buffer[4096];
	struct spa_pod_builder b = { 0 };
	int res;

	if (this->have_format)
		return 0;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	spa_log_debug(this->log, NAME " %p: negiotiate", this);

	spa_node_send_command(this->follower,
			&SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_ParamBegin));

	state = 0;
	format = NULL;
	if ((res = spa_node_port_enum_params_sync(this->follower,
				this->direction, 0,
				SPA_PARAM_EnumFormat, &state,
				format, &format, &b)) < 0) {
		if (res == -ENOENT)
			format = NULL;
		else {
			debug_params(this, this->follower, this->direction, 0,
					SPA_PARAM_EnumFormat, format, "follower format", res);
			goto done;
		}
	}

	if (this->convert) {
		state = 0;
		if ((res = spa_node_port_enum_params_sync(this->convert,
					SPA_DIRECTION_REVERSE(this->direction), 0,
					SPA_PARAM_EnumFormat, &state,
					format, &format, &b)) != 1) {
			debug_params(this, this->convert,
					SPA_DIRECTION_REVERSE(this->direction), 0,
					SPA_PARAM_EnumFormat, format, "convert format", res);
			res = -ENOTSUP;
			goto done;
		}
	}
	if (format == NULL) {
		res = -ENOTSUP;
		goto done;
	}

	spa_pod_fixate(format);

	res = configure_format(this, 0, format);

done:
	spa_node_send_command(this->follower,
			&SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_ParamEnd));

	return res;
}


static int impl_node_send_command(void *object, const struct spa_command *command)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, NAME " %p: command %d", this, SPA_NODE_COMMAND_ID(command));

	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		if ((res = negotiate_format(this)) < 0)
			return res;
		if ((res = negotiate_buffers(this)) < 0)
			return res;
		break;
	case SPA_NODE_COMMAND_Suspend:
		configure_format(this, 0, NULL);
		SPA_FALLTHROUGH
	case SPA_NODE_COMMAND_Flush:
		this->io_buffers.status = SPA_STATUS_OK;
		SPA_FALLTHROUGH
	case SPA_NODE_COMMAND_Pause:
		this->started = false;
		break;
	default:
		break;
	}

	if ((res = spa_node_send_command(this->target, command)) < 0) {
		spa_log_error(this->log, NAME " %p: can't send command: %s",
				this, spa_strerror(res));
		return res;
	}

	if (this->target != this->follower) {
		if ((res = spa_node_send_command(this->follower, command)) < 0) {
			spa_log_error(this->log, NAME " %p: can't send command: %s",
					this, spa_strerror(res));
			return res;
		}
	}
	switch (SPA_NODE_COMMAND_ID(command)) {
	case SPA_NODE_COMMAND_Start:
		this->started = true;
		break;
	}
	return res;
}

static void convert_node_info(void *data, const struct spa_node_info *info)
{
	struct impl *this = data;
	uint32_t i;

	if (info->change_mask & SPA_NODE_CHANGE_MASK_FLAGS) {
		this->info.change_mask |= SPA_NODE_CHANGE_MASK_FLAGS;
		this->info.flags = info->flags;
	}
	if (info->change_mask & SPA_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t idx;

			switch (info->params[i].id) {
			case SPA_PARAM_PropInfo:
				idx = IDX_PropInfo;
				break;
			case SPA_PARAM_Props:
				idx = IDX_Props;
				break;
			default:
				continue;
			}
			if (!this->add_listener &&
			    this->convert_params_flags[idx] == info->params[i].flags)
				continue;

			this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
			this->convert_params_flags[idx] = info->params[i].flags;
			this->params[idx].flags =
				(this->params[idx].flags & SPA_PARAM_INFO_SERIAL) |
				(info->params[i].flags & SPA_PARAM_INFO_READWRITE);

			if (!this->add_listener)
				this->params[idx].user++;
		}
	}
	emit_node_info(this, false);
}

static void convert_port_info(void *data,
		enum spa_direction direction, uint32_t port_id,
		const struct spa_port_info *info)
{
	struct impl *this = data;

	if (direction != this->direction) {
		if (port_id == 0)
			return;
		else
			port_id--;
	}

	spa_log_trace(this->log, NAME" %p: port info %d:%d", this,
			direction, port_id);

	spa_node_emit_port_info(&this->hooks, direction, port_id, info);
}

static void convert_result(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct impl *this = data;
	spa_log_trace(this->log, NAME" %p: result %d %d", this, seq, res);
	spa_node_emit_result(&this->hooks, seq, res, type, result);
}

static const struct spa_node_events convert_node_events = {
	SPA_VERSION_NODE_EVENTS,
	.info = convert_node_info,
	.port_info = convert_port_info,
	.result = convert_result,
};

static void follower_info(void *data, const struct spa_node_info *info)
{
	struct impl *this = data;
	uint32_t i;

	this->async = (info->flags & SPA_NODE_FLAG_ASYNC) != 0;

	if (info->max_input_ports > 0)
		this->direction = SPA_DIRECTION_INPUT;
        else
		this->direction = SPA_DIRECTION_OUTPUT;

	this->info.max_input_ports = this->direction == SPA_DIRECTION_INPUT ? MAX_PORTS : 0;
	this->info.max_output_ports = this->direction == SPA_DIRECTION_OUTPUT ? MAX_PORTS : 0;

	spa_log_debug(this->log, NAME" %p: follower info %s", this,
			this->direction == SPA_DIRECTION_INPUT ?
				"Input" : "Output");

	if (info->change_mask & SPA_NODE_CHANGE_MASK_PROPS) {
		this->info.change_mask |= SPA_NODE_CHANGE_MASK_PROPS;
		this->info.props = info->props;
	}
	if (info->change_mask & SPA_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t idx;

			switch (info->params[i].id) {
			case SPA_PARAM_Props:
				idx = IDX_Props;
				break;
			default:
				continue;
			}
			if (!this->add_listener &&
			    this->follower_params_flags[idx] == info->params[i].flags)
				continue;

			this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
			this->follower_params_flags[idx] = info->params[i].flags;
			this->params[idx].flags =
				(this->params[idx].flags & SPA_PARAM_INFO_SERIAL) |
				(info->params[i].flags & SPA_PARAM_INFO_READWRITE);

			if (!this->add_listener)
				this->params[idx].user++;
		}
	}
	emit_node_info(this, false);
}

static void follower_port_info(void *data,
		enum spa_direction direction, uint32_t port_id,
		const struct spa_port_info *info)
{
	struct impl *this = data;
	uint32_t i;

	if (info->change_mask & SPA_PORT_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t idx;

			switch (info->params[i].id) {
			case SPA_PARAM_Format:
				idx = IDX_Format;
				break;
			default:
				continue;
			}
			if (!this->add_listener &&
			    this->follower_params_flags[idx] == info->params[i].flags)
				continue;

			this->info.change_mask |= SPA_NODE_CHANGE_MASK_PARAMS;
			this->follower_params_flags[idx] = info->params[i].flags;
			this->params[idx].flags =
				(this->params[idx].flags & SPA_PARAM_INFO_SERIAL) |
				(info->params[i].flags & SPA_PARAM_INFO_READWRITE);

			if (!this->add_listener)
				this->params[idx].user++;
		}
	}
	emit_node_info(this, false);
}

static const struct spa_node_events follower_node_events = {
	SPA_VERSION_NODE_EVENTS,
	.info = follower_info,
	.port_info = follower_port_info,
};

static int follower_ready(void *data, int status)
{
	struct impl *this = data;

	spa_log_trace_fp(this->log, NAME " %p: ready %d", this, status);

	this->driver = true;

	if (this->direction == SPA_DIRECTION_OUTPUT)
		status = spa_node_process(this->convert);

	return spa_node_call_ready(&this->callbacks, status);
}

static int follower_reuse_buffer(void *data, uint32_t port_id, uint32_t buffer_id)
{
	int res;
	struct impl *this = data;

	if (this->convert)
		res = spa_node_port_reuse_buffer(this->convert, port_id, buffer_id);
	else
		res = spa_node_call_reuse_buffer(&this->callbacks, port_id, buffer_id);

	return res;
}

static int follower_xrun(void *data, uint64_t trigger, uint64_t delay, struct spa_pod *info)
{
	struct impl *this = data;
	return spa_node_call_xrun(&this->callbacks, trigger, delay, info);
}

static const struct spa_node_callbacks follower_node_callbacks = {
	SPA_VERSION_NODE_CALLBACKS,
	.ready = follower_ready,
	.reuse_buffer = follower_reuse_buffer,
	.xrun = follower_xrun,
};

static int impl_node_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct impl *this = object;
	struct spa_hook l;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_trace(this->log, NAME" %p: add listener %p", this, listener);
	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);


	if (events->info || events->port_info) {
		this->add_listener = true;

		spa_zero(l);
		spa_node_add_listener(this->follower, &l, &follower_node_events, this);
		spa_hook_remove(&l);

		if (this->convert) {
			spa_zero(l);
			spa_node_add_listener(this->convert, &l, &convert_node_events, this);
			spa_hook_remove(&l);
		}
		this->add_listener = false;

		emit_node_info(this, true);
	}
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

static int
impl_node_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	return spa_node_sync(this->follower, seq);
}

static int
impl_node_add_port(void *object, enum spa_direction direction, uint32_t port_id,
		const struct spa_dict *props)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (direction != this->direction)
		return -EINVAL;

	return spa_node_add_port(this->target, direction, port_id, props);
}

static int
impl_node_remove_port(void *object, enum spa_direction direction, uint32_t port_id)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (direction != this->direction)
		return -EINVAL;

	return spa_node_remove_port(this->target, direction, port_id);
}

static int
impl_node_port_enum_params(void *object, int seq,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t id, uint32_t start, uint32_t num,
			   const struct spa_pod *filter)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	if (direction != this->direction)
		port_id++;

	spa_log_debug(this->log, NAME" %p: %d %u", this, seq, id);

	return spa_node_port_enum_params(this->target, seq, direction, port_id, id,
			start, num, filter);
}

static int
impl_node_port_set_param(void *object,
			 enum spa_direction direction, uint32_t port_id,
			 uint32_t id, uint32_t flags,
			 const struct spa_pod *param)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, " %d %d %d %d", port_id, id, direction, this->direction);

	if (direction != this->direction)
		port_id++;

	if ((res = spa_node_port_set_param(this->target, direction, port_id, id,
			flags, param)) < 0)
		return res;

	return res;
}

static int
impl_node_port_set_io(void *object,
		      enum spa_direction direction,
		      uint32_t port_id,
		      uint32_t id,
		      void *data, size_t size)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_log_debug(this->log, "set io %d %d %d %d", port_id, id, direction, this->direction);

	if (direction != this->direction)
		port_id++;

	return spa_node_port_set_io(this->target, direction, port_id, id, data, size);
}

static int
impl_node_port_use_buffers(void *object,
			   enum spa_direction direction,
			   uint32_t port_id,
			   uint32_t flags,
			   struct spa_buffer **buffers,
			   uint32_t n_buffers)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	if (direction != this->direction)
		port_id++;

	spa_log_debug(this->log, NAME" %p: %d %d:%d", this,
			n_buffers, direction, port_id);

	if ((res = spa_node_port_use_buffers(this->target,
					direction, port_id, flags, buffers, n_buffers)) < 0)
		return res;

	return res;
}

static int
impl_node_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	return spa_node_port_reuse_buffer(this->target, port_id, buffer_id);
}

static int impl_node_process(void *object)
{
	struct impl *this = object;
	int status = 0, fstatus;

	spa_log_trace_fp(this->log, "%p: process convert:%p driver:%d",
			this, this->convert, this->driver);

	if (this->direction == SPA_DIRECTION_INPUT) {
		/* an input node (sink).
		 * First we run the converter to process the input for the follower
		 * then if it produced data, we run the follower. */
		while (true) {
			status = this->convert ? spa_node_process(this->convert) : 0;
			/* schedule the follower when the converter needed
			 * a recycled buffer */
			if (status == -EPIPE || status == 0)
				status = SPA_STATUS_HAVE_DATA;
			else if (status < 0)
				break;

			if (status & (SPA_STATUS_HAVE_DATA | SPA_STATUS_DRAINED)) {
				/* as long as the converter produced something or
				 * is drained, process the follower. */
				fstatus = spa_node_process(this->follower);
				if (fstatus < 0) {
					status = fstatus;
					break;
				}
				/* if the follower doesn't need more data or is
				 * drained we can stop */
				if ((fstatus & SPA_STATUS_NEED_DATA) == 0 ||
				    (fstatus & SPA_STATUS_DRAINED))
					break;
			}
			/* the converter needs more data */
			if ((status & SPA_STATUS_NEED_DATA))
				break;
		}
	} else if (!this->driver) {
		bool done = false;
		while (true) {
			/* output node (source). First run the converter to make
			 * sure we push out any queued data. Then when it needs
			 * more data, schedule the follower. */
			status = this->convert ? spa_node_process(this->convert) : 0;
			if (status == 0)
				status = SPA_STATUS_NEED_DATA;
			else if (status < 0)
				break;

			done = (status & (SPA_STATUS_HAVE_DATA | SPA_STATUS_DRAINED));

			/* when not async, we can return the data when we are done.
			 * In async mode we might first need to wake up the follower
			 * to asynchronously provide more data for the next round. */
			if (!this->async && done)
				break;

			if (status & SPA_STATUS_NEED_DATA) {
				/* the converter needs more data, schedule the
				 * follower */
				fstatus = spa_node_process(this->follower);
				if (fstatus < 0) {
					status = fstatus;
					break;
				}
				/* if the follower didn't produce more data or is
				 * not drained we can stop now */
				if ((fstatus & (SPA_STATUS_HAVE_DATA | SPA_STATUS_DRAINED)) == 0)
					break;
			}
			/* converter produced something or is drained and we
			 * scheduled the follower above, we can stop now*/
			if (done)
				break;
		}
		if (!done)
			spa_node_call_xrun(&this->callbacks, 0, 0, NULL);

	} else {
		status = spa_node_process(this->follower);
	}
	spa_log_trace_fp(this->log, "%p: process status:%d", this, status);

	this->driver = false;

	return status;
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
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);

	this = (struct impl *) handle;

	spa_hook_remove(&this->follower_listener);
	spa_node_set_callbacks(this->follower, NULL, NULL);

	spa_handle_clear(this->hnd_convert);

	if (this->buffers)
		free(this->buffers);
	this->buffers = NULL;

	return 0;
}

static int configure_adapt(struct impl *this)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	spa_log_debug(this->log, "%p: configure convert %p", this, this->target);

	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(this->direction),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp));

	return spa_node_set_param(this->target, SPA_PARAM_PortConfig, 0, param);
}

extern const struct spa_handle_factory spa_audioconvert_factory;

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	size_t size;

	size = spa_handle_factory_get_size(&spa_audioconvert_factory, params);
	size += sizeof(struct impl);

	return size;
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;
	void *iface;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	this->cpu = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_CPU);

	if (info == NULL ||
	    (str = spa_dict_lookup(info, "audio.adapt.follower")) == NULL)
		return -EINVAL;

	sscanf(str, "pointer:%p", &this->follower);
	if (this->follower == NULL)
		return -EINVAL;

	if (this->cpu)
		this->max_align = spa_cpu_get_max_align(this->cpu);

	spa_hook_list_init(&this->hooks);

	this->node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, this);

	this->hnd_convert = SPA_MEMBER(this, sizeof(struct impl), struct spa_handle);
	spa_handle_factory_init(&spa_audioconvert_factory,
				this->hnd_convert,
				info, support, n_support);

	spa_handle_get_interface(this->hnd_convert, SPA_TYPE_INTERFACE_Node, &iface);
	this->convert = iface;
	this->target = this->convert;

	this->info_all = SPA_NODE_CHANGE_MASK_FLAGS |
		SPA_NODE_CHANGE_MASK_PARAMS;
	this->info = SPA_NODE_INFO_INIT();
	this->info.flags = SPA_NODE_FLAG_RT |
		SPA_NODE_FLAG_IN_PORT_CONFIG |
		SPA_NODE_FLAG_OUT_PORT_CONFIG |
		SPA_NODE_FLAG_NEED_CONFIGURE;
	this->params[IDX_EnumFormat] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	this->params[IDX_PropInfo] = SPA_PARAM_INFO(SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ);
	this->params[IDX_Props] = SPA_PARAM_INFO(SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE);
	this->params[IDX_Format] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	this->params[IDX_EnumPortConfig] = SPA_PARAM_INFO(SPA_PARAM_EnumPortConfig, SPA_PARAM_INFO_READ);
	this->params[IDX_PortConfig] = SPA_PARAM_INFO(SPA_PARAM_PortConfig, SPA_PARAM_INFO_READWRITE);
	this->info.params = this->params;
	this->info.n_params = 6;

	spa_node_add_listener(this->follower,
			&this->follower_listener, &follower_node_events, this);
	spa_node_set_callbacks(this->follower, &follower_node_callbacks, this);

	spa_node_add_listener(this->convert,
			&this->convert_listener, &convert_node_events, this);

	configure_adapt(this);

	link_io(this);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{ SPA_TYPE_INTERFACE_Node, },
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
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

const struct spa_handle_factory spa_audioadapter_factory = {
	.version = SPA_VERSION_HANDLE_FACTORY,
	.name = SPA_NAME_AUDIO_ADAPT,
	.get_size = impl_get_size,
	.init = impl_init,
	.enum_interface_info = impl_enum_interface_info,
};
