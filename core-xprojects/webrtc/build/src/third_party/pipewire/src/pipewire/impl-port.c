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

#include <string.h>
#include <stdlib.h>
#include <errno.h>

#include <spa/pod/parser.h>
#include <spa/param/audio/format-utils.h>
#include <spa/node/utils.h>
#include <spa/utils/names.h>
#include <spa/debug/types.h>
#include <spa/pod/filter.h>

#include "pipewire/impl.h"
#include "pipewire/private.h"

#define NAME "port"

/** \cond */
struct impl {
	struct pw_impl_port this;
	struct spa_node mix_node;	/**< mix node implementation */

	struct spa_list param_list;
	struct spa_list pending_list;

	unsigned int cache_params:1;
};

#define pw_port_resource(r,m,v,...)	pw_resource_call(r,struct pw_port_events,m,v,__VA_ARGS__)
#define pw_port_resource_info(r,...)	pw_port_resource(r,info,0,__VA_ARGS__)
#define pw_port_resource_param(r,...)	pw_port_resource(r,param,0,__VA_ARGS__)

struct resource_data {
	struct pw_impl_port *port;
	struct pw_resource *resource;

	struct spa_hook resource_listener;
	struct spa_hook object_listener;

	uint32_t subscribe_ids[MAX_PARAMS];
	uint32_t n_subscribe_ids;
};

/** \endcond */

static void emit_info_changed(struct pw_impl_port *port)
{
	struct pw_resource *resource;

	if (port->info.change_mask == 0)
		return;

	pw_impl_port_emit_info_changed(port, &port->info);
	if (port->node)
		pw_impl_node_emit_port_info_changed(port->node, port, &port->info);

	if (port->global)
		spa_list_for_each(resource, &port->global->resource_list, link)
			pw_port_resource_info(resource, &port->info);

	port->info.change_mask = 0;
}

static const char *port_state_as_string(enum pw_impl_port_state state)
{
	switch (state) {
	case PW_IMPL_PORT_STATE_ERROR:
		return "error";
	case PW_IMPL_PORT_STATE_INIT:
		return "init";
	case PW_IMPL_PORT_STATE_CONFIGURE:
		return "configure";
	case PW_IMPL_PORT_STATE_READY:
		return "ready";
	case PW_IMPL_PORT_STATE_PAUSED:
		return "paused";
	}
	return "invalid-state";
}

void pw_impl_port_update_state(struct pw_impl_port *port, enum pw_impl_port_state state, int res, char *error)
{
	enum pw_impl_port_state old = port->state;

	port->state = state;
	free((void*)port->error);
	port->error = error;

	if (old == state)
		return;

	pw_log(state == PW_IMPL_PORT_STATE_ERROR ?
			SPA_LOG_LEVEL_ERROR : SPA_LOG_LEVEL_DEBUG,
		NAME" %p: state %s -> %s (%s)", port,
		port_state_as_string(old), port_state_as_string(state), error);

	pw_impl_port_emit_state_changed(port, old, state, error);

	if (state == PW_IMPL_PORT_STATE_ERROR && port->global) {
		struct pw_resource *resource;
		spa_list_for_each(resource, &port->global->resource_list, link)
			pw_resource_error(resource, res, error);
	}
}

static int tee_process(void *object)
{
	struct impl *impl = object;
	struct pw_impl_port *this = &impl->this;
	struct pw_impl_port_mix *mix;
	struct spa_io_buffers *io = &this->rt.io;

	pw_log_trace_fp(NAME" %p: tee input %d %d", this, io->status, io->buffer_id);
	spa_list_for_each(mix, &this->rt.mix_list, rt_link) {
		pw_log_trace_fp(NAME" %p: port %d %p->%p %d", this,
				mix->port.port_id, io, mix->io, mix->io->buffer_id);
		*mix->io = *io;
	}
	io->status = SPA_STATUS_NEED_DATA;

        return SPA_STATUS_HAVE_DATA | SPA_STATUS_NEED_DATA;
}

static int tee_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *impl = object;
	struct pw_impl_port *this = &impl->this;

	pw_log_trace_fp(NAME" %p: tee reuse buffer %d %d", this, port_id, buffer_id);
	spa_node_port_reuse_buffer(this->node->node, this->port_id, buffer_id);

	return 0;
}

static const struct spa_node_methods schedule_tee_node = {
	SPA_VERSION_NODE_METHODS,
	.process = tee_process,
	.port_reuse_buffer = tee_reuse_buffer,
};

static int schedule_mix_input(void *object)
{
	struct impl *impl = object;
	struct pw_impl_port *this = &impl->this;
	struct spa_io_buffers *io = &this->rt.io;
	struct pw_impl_port_mix *mix;

	if (SPA_UNLIKELY(PW_IMPL_PORT_IS_CONTROL(this)))
		return SPA_STATUS_HAVE_DATA | SPA_STATUS_NEED_DATA;

	spa_list_for_each(mix, &this->rt.mix_list, rt_link) {
		pw_log_trace_fp(NAME" %p: mix input %d %p->%p %d %d", this,
				mix->port.port_id, mix->io, io, mix->io->status, mix->io->buffer_id);
		*io = *mix->io;
		mix->io->status = SPA_STATUS_NEED_DATA;
		break;
	}
        return SPA_STATUS_HAVE_DATA | SPA_STATUS_NEED_DATA;
}

static int schedule_mix_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct impl *impl = object;
	struct pw_impl_port *this = &impl->this;
	struct pw_impl_port_mix *mix;

	spa_list_for_each(mix, &this->rt.mix_list, rt_link) {
		pw_log_trace_fp(NAME" %p: reuse buffer %d %d", this, port_id, buffer_id);
		/* FIXME send reuse buffer to peer */
		break;
	}
	return 0;
}

static const struct spa_node_methods schedule_mix_node = {
	SPA_VERSION_NODE_METHODS,
	.process = schedule_mix_input,
	.port_reuse_buffer = schedule_mix_reuse_buffer,
};

SPA_EXPORT
int pw_impl_port_init_mix(struct pw_impl_port *port, struct pw_impl_port_mix *mix)
{
	uint32_t port_id;
	int res = 0;

	port_id = pw_map_insert_new(&port->mix_port_map, mix);
	if (port_id == SPA_ID_INVALID)
		return -errno;

	mix->port.direction = port->direction;
	mix->port.port_id = port_id;

	spa_list_append(&port->mix_list, &mix->link);
	port->n_mix++;
	mix->p = port;

	spa_node_add_port(port->mix, port->direction, port_id, NULL);

	res = pw_impl_port_call_init_mix(port, mix);

	/* set the same format on the mixer as on the port if any */
	{
		uint32_t idx = 0;
		uint8_t buffer[1024];
		struct spa_pod_builder b;
		struct spa_pod *param;

		spa_pod_builder_init(&b, buffer, sizeof(buffer));
		if (spa_node_port_enum_params_sync(port->mix,
				pw_direction_reverse(port->direction), 0,
				SPA_PARAM_Format, &idx, NULL, &param, &b) == 1) {
			spa_node_port_set_param(port->mix,
				port->direction, port_id,
				SPA_PARAM_Format, 0, param);
		}
	}

	pw_log_debug(NAME" %p: init mix n_mix:%d %d.%d io:%p: (%s)", port,
			port->n_mix, port->port_id, mix->port.port_id,
			mix->io, spa_strerror(res));

	return res;
}

SPA_EXPORT
int pw_impl_port_release_mix(struct pw_impl_port *port, struct pw_impl_port_mix *mix)
{
	int res = 0;
	uint32_t port_id = mix->port.port_id;

	pw_map_remove(&port->mix_port_map, port_id);
	spa_list_remove(&mix->link);
	port->n_mix--;

	res = pw_impl_port_call_release_mix(port, mix);

	spa_node_remove_port(port->mix, port->direction, port_id);

	pw_log_debug(NAME" %p: release mix %d %d.%d", port,
			port->n_mix, port->port_id, mix->port.port_id);

	return res;
}

static int update_properties(struct pw_impl_port *port, const struct spa_dict *dict, bool filter)
{
	int changed;
	const char *ignored[] = {
		PW_KEY_OBJECT_ID,
		PW_KEY_PORT_DIRECTION,
		PW_KEY_PORT_CONTROL,
		PW_KEY_NODE_ID,
		PW_KEY_PORT_ID,
		NULL
	};

	changed = pw_properties_update_ignore(port->properties, dict, filter ? ignored : NULL);
	port->info.props = &port->properties->dict;

	if (changed) {
		pw_log_debug(NAME" %p: updated %d properties", port, changed);
		port->info.change_mask |= PW_PORT_CHANGE_MASK_PROPS;
	}
	return changed;
}

static int resource_is_subscribed(struct pw_resource *resource, uint32_t id)
{
	struct resource_data *data = pw_resource_get_user_data(resource);
	uint32_t i;

	for (i = 0; i < data->n_subscribe_ids; i++) {
		if (data->subscribe_ids[i] == id)
			return 1;
	}
	return 0;
}

static int notify_param(void *data, int seq, uint32_t id,
		uint32_t index, uint32_t next, struct spa_pod *param)
{
	struct pw_impl_port *port = data;
	struct pw_resource *resource;

	spa_list_for_each(resource, &port->global->resource_list, link) {
		if (!resource_is_subscribed(resource, id))
			continue;

		pw_log_debug(NAME" %p: resource %p notify param %d", port, resource, id);
		pw_port_resource_param(resource, seq, id, index, next, param);
	}
	return 0;
}

static void emit_params(struct pw_impl_port *port, uint32_t *changed_ids, uint32_t n_changed_ids)
{
	uint32_t i;
	int res;

	if (port->global == NULL)
		return;

	pw_log_debug(NAME" %p: emit %d params", port, n_changed_ids);

	for (i = 0; i < n_changed_ids; i++) {
		struct pw_resource *resource;
		int subscribed = 0;

		pw_log_debug(NAME" %p: emit param %d/%d: %d", port, i, n_changed_ids,
				changed_ids[i]);

		pw_impl_port_emit_param_changed(port, changed_ids[i]);

		/* first check if anyone is subscribed */
		spa_list_for_each(resource, &port->global->resource_list, link) {
			if ((subscribed = resource_is_subscribed(resource, changed_ids[i])))
				break;
		}
		if (!subscribed)
			continue;

		if ((res = pw_impl_port_for_each_param(port, 1, changed_ids[i], 0, UINT32_MAX,
					NULL, notify_param, port)) < 0) {
			pw_log_error(NAME" %p: error %d (%s)", port, res, spa_strerror(res));
		}
	}
}

static void update_info(struct pw_impl_port *port, const struct spa_port_info *info)
{
	uint32_t changed_ids[MAX_PARAMS], n_changed_ids = 0;

	pw_log_debug(NAME" %p: flags:%08"PRIx64" change_mask:%08"PRIx64,
			port, info->flags, info->change_mask);

	if (info->change_mask & SPA_PORT_CHANGE_MASK_FLAGS) {
		port->spa_flags = info->flags;
	}
	if (info->change_mask & SPA_PORT_CHANGE_MASK_PROPS) {
		if (info->props) {
			update_properties(port, info->props, true);
		} else {
			pw_log_warn(NAME" %p: port PROPS update but no properties", port);
		}
	}
	if (info->change_mask & SPA_PORT_CHANGE_MASK_PARAMS) {
		uint32_t i;

		port->info.change_mask |= PW_PORT_CHANGE_MASK_PARAMS;
		port->info.n_params = SPA_MIN(info->n_params, SPA_N_ELEMENTS(port->params));

		for (i = 0; i < port->info.n_params; i++) {
			uint32_t id = info->params[i].id;

			pw_log_debug(NAME" %p: param %d id:%d (%s) %08x:%08x", port, i,
					id, spa_debug_type_find_name(spa_type_param, id),
					port->info.params[i].flags, info->params[i].flags);

			port->info.params[i].id = info->params[i].id;
			if (port->info.params[i].flags == info->params[i].flags)
				continue;

			pw_log_debug(NAME" %p: update param %d", port, id);
			port->info.params[i] = info->params[i];
			port->info.params[i].user = 0;

			if (info->params[i].flags & SPA_PARAM_INFO_READ)
				changed_ids[n_changed_ids++] = id;
		}
	}

	if (n_changed_ids > 0)
		emit_params(port, changed_ids, n_changed_ids);
}

SPA_EXPORT
struct pw_impl_port *pw_context_create_port(
		struct pw_context *context,
		enum pw_direction direction,
		uint32_t port_id,
		const struct spa_port_info *info,
		size_t user_data_size)
{
	struct impl *impl;
	struct pw_impl_port *this;
	struct pw_properties *properties;
	const struct spa_node_methods *mix_methods;
	int res;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL)
		return NULL;

	spa_list_init(&impl->param_list);
	spa_list_init(&impl->pending_list);
	impl->cache_params = true;

	this = &impl->this;
	pw_log_debug(NAME" %p: new %s %d", this,
			pw_direction_as_string(direction), port_id);

	if (info && info->change_mask & SPA_PORT_CHANGE_MASK_PROPS && info->props)
		properties = pw_properties_new_dict(info->props);
	else
		properties = pw_properties_new(NULL, NULL);

	if (properties == NULL) {
		res = -errno;
		goto error_no_mem;
	}
	pw_properties_setf(properties, PW_KEY_PORT_ID, "%u", port_id);

	if (info) {
		if (SPA_FLAG_IS_SET(info->flags, SPA_PORT_FLAG_PHYSICAL))
			pw_properties_set(properties, PW_KEY_PORT_PHYSICAL, "true");
		if (SPA_FLAG_IS_SET(info->flags, SPA_PORT_FLAG_TERMINAL))
			pw_properties_set(properties, PW_KEY_PORT_TERMINAL, "true");
		this->spa_flags = info->flags;
	}

	this->direction = direction;
	this->port_id = port_id;
	this->properties = properties;
	this->state = PW_IMPL_PORT_STATE_INIT;
	this->rt.io = SPA_IO_BUFFERS_INIT;

        if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	this->info.direction = direction;
	this->info.params = this->params;
	this->info.change_mask = PW_PORT_CHANGE_MASK_PROPS;
	this->info.props = &this->properties->dict;

	spa_list_init(&this->links);
	spa_list_init(&this->mix_list);
	spa_list_init(&this->rt.mix_list);
	spa_list_init(&this->control_list[0]);
	spa_list_init(&this->control_list[1]);

	spa_hook_list_init(&this->listener_list);

	if (this->direction == PW_DIRECTION_INPUT)
		mix_methods = &schedule_mix_node;
	else
		mix_methods = &schedule_tee_node;

	impl->mix_node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			mix_methods, impl);

	pw_impl_port_set_mix(this, NULL, 0);

	pw_map_init(&this->mix_port_map, 64, 64);

	if (info)
		update_info(this, info);

	return this;

error_no_mem:
	pw_log_warn(NAME" %p: new failed", impl);
	free(impl);
	errno = -res;
	return NULL;
}

SPA_EXPORT
int pw_impl_port_set_mix(struct pw_impl_port *port, struct spa_node *node, uint32_t flags)
{
	struct impl *impl = SPA_CONTAINER_OF(port, struct impl, this);
	struct pw_impl_port_mix *mix;

	if (node == NULL) {
		node = &impl->mix_node;
		flags = 0;
	}

	pw_log_debug(NAME" %p: mix node %p->%p", port, port->mix, node);

	if (port->mix != NULL && port->mix != node) {
		spa_list_for_each(mix, &port->mix_list, link)
			spa_node_remove_port(port->mix, mix->port.direction, mix->port.port_id);

		spa_node_port_set_io(port->mix,
			     pw_direction_reverse(port->direction), 0,
			     SPA_IO_Buffers, NULL, 0);
	}
	if (port->mix_handle != NULL) {
		pw_unload_spa_handle(port->mix_handle);
		port->mix_handle = NULL;
	}

	port->mix_flags = flags;
	port->mix = node;

	if (port->mix) {
		spa_list_for_each(mix, &port->mix_list, link)
			spa_node_add_port(port->mix, mix->port.direction, mix->port.port_id, NULL);

		spa_node_port_set_io(port->mix,
			     pw_direction_reverse(port->direction), 0,
			     SPA_IO_Buffers,
			     &port->rt.io, sizeof(port->rt.io));
	}
	return 0;
}

static int setup_mixer(struct pw_impl_port *port, const struct spa_pod *param)
{
	uint32_t media_type, media_subtype;
	int res;
	const char *fallback_lib, *factory_name;
	struct spa_handle *handle;
	struct spa_dict_item items[1];
	void *iface;

	if ((res = spa_format_parse(param, &media_type, &media_subtype)) < 0)
		return res;

	pw_log_debug(NAME" %p: %s/%s", port,
			spa_debug_type_find_name(spa_type_media_type, media_type),
			spa_debug_type_find_name(spa_type_media_subtype, media_subtype));

	switch (media_type) {
	case SPA_MEDIA_TYPE_audio:
		switch (media_subtype) {
		case SPA_MEDIA_SUBTYPE_dsp:
		{
			struct spa_audio_info_dsp info;
			if ((res = spa_format_audio_dsp_parse(param, &info)) < 0)
				return res;

			if (info.format != SPA_AUDIO_FORMAT_DSP_F32)
				return -ENOTSUP;

			fallback_lib = "audiomixer/libspa-audiomixer";
			factory_name = SPA_NAME_AUDIO_MIXER_DSP;
			break;
		}
		default:
			return -ENOTSUP;
		}
		break;

	case SPA_MEDIA_TYPE_application:
		switch (media_subtype) {
		case SPA_MEDIA_SUBTYPE_control:
			fallback_lib = "control/libspa-control";
			factory_name = SPA_NAME_CONTROL_MIXER;
			break;
		default:
			return -ENOTSUP;
		}
		break;

	default:
		return -ENOTSUP;
	}

	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_LIBRARY_NAME, fallback_lib);
	handle = pw_context_load_spa_handle(port->node->context, factory_name,
			&SPA_DICT_INIT_ARRAY(items));
	if (handle == NULL)
		return -errno;

	if ((res = spa_handle_get_interface(handle,
					SPA_TYPE_INTERFACE_Node, &iface)) < 0) {
		pw_unload_spa_handle(handle);
		return res;
	}

	pw_log_debug("mix node handle:%p iface:%p", handle, iface);
	pw_impl_port_set_mix(port, (struct spa_node*)iface,
			PW_IMPL_PORT_MIX_FLAG_MULTI |
			PW_IMPL_PORT_MIX_FLAG_NEGOTIATE);
	port->mix_handle = handle;

	return 0;
}

SPA_EXPORT
enum pw_direction pw_impl_port_get_direction(struct pw_impl_port *port)
{
	return port->direction;
}

SPA_EXPORT
uint32_t pw_impl_port_get_id(struct pw_impl_port *port)
{
	return port->port_id;
}

SPA_EXPORT
const struct pw_properties *pw_impl_port_get_properties(struct pw_impl_port *port)
{
	return port->properties;
}

SPA_EXPORT
int pw_impl_port_update_properties(struct pw_impl_port *port, const struct spa_dict *dict)
{
	int changed = update_properties(port, dict, false);
	emit_info_changed(port);
	return changed;
}

void pw_impl_port_update_info(struct pw_impl_port *port, const struct spa_port_info *info)
{
	update_info(port, info);
	emit_info_changed(port);
}

SPA_EXPORT
struct pw_impl_node *pw_impl_port_get_node(struct pw_impl_port *port)
{
	return port->node;
}

SPA_EXPORT
void pw_impl_port_add_listener(struct pw_impl_port *port,
			  struct spa_hook *listener,
			  const struct pw_impl_port_events *events,
			  void *data)
{
	spa_hook_list_append(&port->listener_list, listener, events, data);
}

SPA_EXPORT
const struct pw_port_info *pw_impl_port_get_info(struct pw_impl_port *port)
{
	return &port->info;
}

SPA_EXPORT
void * pw_impl_port_get_user_data(struct pw_impl_port *port)
{
	return port->user_data;
}

static int do_add_port(struct spa_loop *loop,
		       bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
        struct pw_impl_port *this = user_data;

	pw_log_trace(NAME" %p: add port", this);
	if (this->direction == PW_DIRECTION_INPUT)
		spa_list_append(&this->node->rt.input_mix, &this->rt.node_link);
	else
		spa_list_append(&this->node->rt.output_mix, &this->rt.node_link);

	return 0;
}

static int check_param_io(void *data, int seq, uint32_t id,
		uint32_t index, uint32_t next, struct spa_pod *param)
{
	struct pw_impl_port *port = data;
	struct pw_impl_node *node = port->node;
	uint32_t pid, psize;

	if (spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_ParamIO, NULL,
			SPA_PARAM_IO_id,   SPA_POD_Id(&pid),
			SPA_PARAM_IO_size, SPA_POD_Int(&psize)) < 0)
		return 0;

	pw_log_debug(NAME" %p: got io id:%d (%s)", port, pid,
			spa_debug_type_find_name(spa_type_io, pid));

	switch (pid) {
	case SPA_IO_Control:
	case SPA_IO_Notify:
		pw_control_new(node->context, port, pid, psize, 0);
		SPA_FLAG_SET(port->flags, PW_IMPL_PORT_FLAG_CONTROL);
		break;
	case SPA_IO_Buffers:
		SPA_FLAG_SET(port->flags, PW_IMPL_PORT_FLAG_BUFFERS);
		break;
	default:
		break;
	}
	return 0;
}

static int reply_param(void *data, int seq, uint32_t id,
		uint32_t index, uint32_t next, struct spa_pod *param)
{
	struct resource_data *d = data;
	struct pw_resource *resource = d->resource;
	pw_log_debug(NAME" %p: resource %p reply param %u %u %u", d->port,
			resource, id, index, next);
	pw_port_resource_param(resource, seq, id, index, next, param);
	return 0;
}

static int port_enum_params(void *object, int seq, uint32_t id, uint32_t index, uint32_t num,
		const struct spa_pod *filter)
{
	struct resource_data *data = object;
	struct pw_resource *resource = data->resource;
	struct pw_impl_port *port = data->port;
	int res;

	pw_log_debug(NAME" %p: resource %p enum params seq:%d id:%d (%s) index:%u num:%u", port,
			resource, seq, id, spa_debug_type_find_name(spa_type_param, id),
			index, num);

	if ((res = pw_impl_port_for_each_param(port, seq, id, index, num, filter,
			reply_param, data)) < 0)
		pw_resource_errorf(resource, res,
				"enum params id:%d (%s) failed", id,
				spa_debug_type_find_name(spa_type_param, id));
	return res;
}

static int port_subscribe_params(void *object, uint32_t *ids, uint32_t n_ids)
{
	struct resource_data *data = object;
	struct pw_resource *resource = data->resource;
	uint32_t i;

	n_ids = SPA_MIN(n_ids, SPA_N_ELEMENTS(data->subscribe_ids));
	data->n_subscribe_ids = n_ids;

	for (i = 0; i < n_ids; i++) {
		data->subscribe_ids[i] = ids[i];
		pw_log_debug(NAME" %p: resource %p subscribe param id:%d (%s)", data->port,
				resource, ids[i],
				spa_debug_type_find_name(spa_type_param, ids[i]));
		port_enum_params(data, 1, ids[i], 0, UINT32_MAX, NULL);
	}
	return 0;
}

static const struct pw_port_methods port_methods = {
	PW_VERSION_PORT_METHODS,
	.subscribe_params = port_subscribe_params,
	.enum_params = port_enum_params
};

static void resource_destroy(void *data)
{
	struct resource_data *d = data;
	spa_hook_remove(&d->resource_listener);
	spa_hook_remove(&d->object_listener);
}

static const struct pw_resource_events resource_events = {
	PW_VERSION_RESOURCE_EVENTS,
	.destroy = resource_destroy,
};

static int
global_bind(void *_data, struct pw_impl_client *client, uint32_t permissions,
	       uint32_t version, uint32_t id)
{
	struct pw_impl_port *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;
	struct resource_data *data;
	int res;

	resource = pw_resource_new(client, id, permissions, global->type, version, sizeof(*data));
	if (resource == NULL) {
		res = -errno;
		goto error_resource;
	}

	data = pw_resource_get_user_data(resource);
	data->port = this;
	data->resource = resource;

	pw_resource_add_listener(resource,
			&data->resource_listener,
			&resource_events, data);
	pw_resource_add_object_listener(resource,
			&data->object_listener,
			&port_methods, data);

	pw_log_debug(NAME" %p: bound to %d", this, resource->id);
	pw_global_add_resource(global, resource);

	this->info.change_mask = PW_PORT_CHANGE_MASK_ALL;
	pw_port_resource_info(resource, &this->info);
	this->info.change_mask = 0;
	return 0;

error_resource:
	pw_log_error(NAME" %p: can't create port resource: %m", this);
	return res;
}

static void global_destroy(void *object)
{
	struct pw_impl_port *port = object;
	spa_hook_remove(&port->global_listener);
	port->global = NULL;
	pw_impl_port_destroy(port);
}

static const struct pw_global_events global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.destroy = global_destroy,
};

int pw_impl_port_register(struct pw_impl_port *port,
		     struct pw_properties *properties)
{
	struct pw_impl_node *node = port->node;
	const char *keys[] = {
		PW_KEY_OBJECT_PATH,
		PW_KEY_FORMAT_DSP,
		PW_KEY_NODE_ID,
		PW_KEY_AUDIO_CHANNEL,
		PW_KEY_PORT_ID,
		PW_KEY_PORT_NAME,
		PW_KEY_PORT_DIRECTION,
		PW_KEY_PORT_MONITOR,
		PW_KEY_PORT_PHYSICAL,
		PW_KEY_PORT_TERMINAL,
		PW_KEY_PORT_CONTROL,
		PW_KEY_PORT_ALIAS,
		PW_KEY_PORT_EXTRA,
		NULL
	};

	if (node == NULL || node->global == NULL)
		return -EIO;

	port->global = pw_global_new(node->context,
				PW_TYPE_INTERFACE_Port,
				PW_VERSION_PORT,
				properties,
				global_bind,
				port);
	if (port->global == NULL)
		return -errno;

	pw_global_add_listener(port->global, &port->global_listener, &global_events, port);

	port->info.id = port->global->id;
	pw_properties_setf(port->properties, PW_KEY_NODE_ID, "%d", node->global->id);
	pw_properties_setf(port->properties, PW_KEY_OBJECT_ID, "%d", port->info.id);
	port->info.props = &port->properties->dict;

	pw_global_update_keys(port->global, &port->properties->dict, keys);

	pw_impl_port_emit_initialized(port);

	return pw_global_register(port->global);
}

SPA_EXPORT
int pw_impl_port_add(struct pw_impl_port *port, struct pw_impl_node *node)
{
	uint32_t port_id = port->port_id;
	struct spa_list *ports;
	struct pw_map *portmap;
	struct pw_impl_port *find;
	bool control;
	const char *str, *dir;
	int res;

	if (port->node != NULL)
		return -EEXIST;

	if (port->direction == PW_DIRECTION_INPUT) {
		ports = &node->input_ports;
		portmap = &node->input_port_map;
	} else {
		ports = &node->output_ports;
		portmap = &node->output_port_map;
	}

	find = pw_map_lookup(portmap, port_id);
	if (find != NULL)
		return -EEXIST;

	if ((res = pw_map_insert_at(portmap, port_id, port)) < 0)
		return res;

	port->node = node;

	pw_impl_node_emit_port_init(node, port);

	pw_impl_port_for_each_param(port, 0, SPA_PARAM_IO, 0, 0, NULL, check_param_io, port);

	control = PW_IMPL_PORT_IS_CONTROL(port);
	if (control) {
		dir = port->direction == PW_DIRECTION_INPUT ?  "control" : "notify";
		pw_properties_set(port->properties, PW_KEY_PORT_CONTROL, "true");
	}
	else {
		dir = port->direction == PW_DIRECTION_INPUT ?  "in" : "out";
	}
	pw_properties_set(port->properties, PW_KEY_PORT_DIRECTION, dir);

	if ((str = pw_properties_get(port->properties, PW_KEY_PORT_NAME)) == NULL) {
		if ((str = pw_properties_get(port->properties, PW_KEY_AUDIO_CHANNEL)) != NULL &&
		    strcmp(str, "UNK") != 0) {
			pw_properties_setf(port->properties, PW_KEY_PORT_NAME, "%s_%s", dir, str);
		}
		else {
			pw_properties_setf(port->properties, PW_KEY_PORT_NAME, "%s_%d", dir, port->port_id);
		}
	}
	port->info.props = &port->properties->dict;

	if (control) {
		pw_log_debug(NAME" %p: setting node control", port);
	} else {
		pw_log_debug(NAME" %p: setting node io", port);
		spa_node_port_set_io(node->node,
				     port->direction, port->port_id,
				     SPA_IO_Buffers,
				     &port->rt.io, sizeof(port->rt.io));

		spa_node_port_set_io(port->mix,
			     pw_direction_reverse(port->direction), 0,
			     SPA_IO_Buffers,
			     &port->rt.io, sizeof(port->rt.io));
	}

	pw_log_debug(NAME" %p: %d add to node %p", port, port_id, node);

	spa_list_append(ports, &port->link);

	if (port->direction == PW_DIRECTION_INPUT) {
		node->info.n_input_ports++;
		node->info.change_mask |= PW_NODE_CHANGE_MASK_INPUT_PORTS;
	} else {
		node->info.n_output_ports++;
		node->info.change_mask |= PW_NODE_CHANGE_MASK_OUTPUT_PORTS;
	}

	if (node->global)
		pw_impl_port_register(port, NULL);

	if (port->state <= PW_IMPL_PORT_STATE_INIT)
		pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_CONFIGURE, 0, NULL);

	pw_impl_node_emit_port_added(node, port);
	emit_info_changed(port);

	return 0;
}

static int do_destroy_link(void *data, struct pw_impl_link *link)
{
	pw_impl_link_destroy(link);
	return 0;
}

void pw_impl_port_unlink(struct pw_impl_port *port)
{
	pw_impl_port_for_each_link(port, do_destroy_link, port);
}

static int do_remove_port(struct spa_loop *loop,
			  bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct pw_impl_port *this = user_data;

	pw_log_trace(NAME" %p: remove port", this);
	spa_list_remove(&this->rt.node_link);

	return 0;
}

static void pw_impl_port_remove(struct pw_impl_port *port)
{
	struct pw_impl_node *node = port->node;
	int res;

	if (node == NULL)
		return;

	pw_log_debug(NAME" %p: remove added:%d", port, port->added);

	if (port->added) {
		pw_loop_invoke(node->data_loop, do_remove_port,
			       SPA_ID_INVALID, NULL, 0, true, port);
		port->added = false;
	}

	if (SPA_FLAG_IS_SET(port->flags, PW_IMPL_PORT_FLAG_TO_REMOVE)) {
		if ((res = spa_node_remove_port(node->node, port->direction, port->port_id)) < 0)
			pw_log_warn(NAME" %p: can't remove: %s", port, spa_strerror(res));
	}

	if (port->direction == PW_DIRECTION_INPUT) {
		pw_map_remove(&node->input_port_map, port->port_id);
		node->info.n_input_ports--;
	} else {
		pw_map_remove(&node->output_port_map, port->port_id);
		node->info.n_output_ports--;
	}

	pw_impl_port_set_mix(port, NULL, 0);

	spa_list_remove(&port->link);
	pw_impl_node_emit_port_removed(node, port);
	port->node = NULL;
}

void pw_impl_port_destroy(struct pw_impl_port *port)
{
	struct impl *impl = SPA_CONTAINER_OF(port, struct impl, this);
	struct pw_control *control;

	pw_log_debug(NAME" %p: destroy", port);

	pw_impl_port_emit_destroy(port);

	pw_impl_port_unlink(port);

	pw_log_debug(NAME" %p: control destroy", port);
	spa_list_consume(control, &port->control_list[0], port_link)
		pw_control_destroy(control);
	spa_list_consume(control, &port->control_list[1], port_link)
		pw_control_destroy(control);

	pw_impl_port_remove(port);

	if (port->global) {
		spa_hook_remove(&port->global_listener);
		pw_global_destroy(port->global);
	}

	pw_log_debug(NAME" %p: free", port);
	pw_impl_port_emit_free(port);

	spa_hook_list_clean(&port->listener_list);

	pw_buffers_clear(&port->buffers);
	pw_buffers_clear(&port->mix_buffers);
	free((void*)port->error);

	pw_param_clear(&impl->param_list, SPA_ID_INVALID);
	pw_param_clear(&impl->pending_list, SPA_ID_INVALID);

	pw_map_clear(&port->mix_port_map);

	pw_properties_free(port->properties);

	free(port);
}

struct result_port_params_data {
	struct impl *impl;
	void *data;
	int (*callback) (void *data, int seq,
			uint32_t id, uint32_t index, uint32_t next,
			struct spa_pod *param);
	int seq;
	uint32_t count;
	unsigned int cache:1;
};

static void result_port_params(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct result_port_params_data *d = data;
	struct impl *impl = d->impl;
	switch (type) {
	case SPA_RESULT_TYPE_NODE_PARAMS:
	{
		const struct spa_result_node_params *r = result;
		if (d->seq == seq) {
			d->callback(d->data, seq, r->id, r->index, r->next, r->param);
			if (d->cache) {
				if (d->count++ == 0)
					pw_param_add(&impl->pending_list, r->id, NULL);
				pw_param_add(&impl->pending_list, r->id, r->param);
			}
		}
		break;
	}
	default:
		break;
	}
}

int pw_impl_port_for_each_param(struct pw_impl_port *port,
			   int seq,
			   uint32_t param_id,
			   uint32_t index, uint32_t max,
			   const struct spa_pod *filter,
			   int (*callback) (void *data, int seq,
					    uint32_t id, uint32_t index, uint32_t next,
					    struct spa_pod *param),
			   void *data)
{
	int res;
	struct impl *impl = SPA_CONTAINER_OF(port, struct impl, this);
	struct pw_impl_node *node = port->node;
	struct result_port_params_data user_data = { impl, data, callback, seq, 0, false };
	struct spa_hook listener;
	struct spa_param_info *pi;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.result = result_port_params,
	};

	pi = pw_param_info_find(port->info.params, port->info.n_params, param_id);
	if (pi == NULL)
		return -ENOENT;

	if (max == 0)
		max = UINT32_MAX;

	pw_log_debug(NAME" %p: params id:%d (%s) index:%u max:%u cached:%d", port, param_id,
			spa_debug_type_find_name(spa_type_param, param_id),
			index, max, pi->user);

	if (pi->user == 1) {
		struct pw_param *p;
		uint8_t buffer[1024];
		struct spa_pod_builder b = { 0 };
	        struct spa_result_node_params result;
		uint32_t count = 0;

		result.id = param_id;
		result.next = 0;

		spa_list_for_each(p, &impl->param_list, link) {
			result.index = result.next++;
			if (p->id != param_id)
				continue;

			if (result.index < index)
				continue;

			spa_pod_builder_init(&b, buffer, sizeof(buffer));
			if (spa_pod_filter(&b, &result.param, p->param, filter) != 0)
				continue;

			pw_log_debug(NAME " %p: %d param %u", port, seq, result.index);
			result_port_params(&user_data, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

			if (++count == max)
				break;
		}
		res = 0;
	} else {
		user_data.cache = impl->cache_params &&
			(filter == NULL && index == 0 && max == UINT32_MAX);

		spa_zero(listener);
		spa_node_add_listener(node->node, &listener, &node_events, &user_data);
		res = spa_node_port_enum_params(node->node, seq,
						port->direction, port->port_id,
						param_id, index, max,
						filter);
		spa_hook_remove(&listener);

		if (user_data.cache) {
			pw_param_update(&impl->param_list, &impl->pending_list);
			pi->user = 1;
		}
	}

	pw_log_debug(NAME" %p: res %d: (%s)", port, res, spa_strerror(res));
	return res;
}

struct param_filter {
	struct pw_impl_port *in_port;
	struct pw_impl_port *out_port;
	int seq;
	uint32_t in_param_id;
	uint32_t out_param_id;
	int (*callback) (void *data, int seq, uint32_t id, uint32_t index,
			uint32_t next, struct spa_pod *param);
	void *data;
	uint32_t n_params;
};

static int do_filter(void *data, int seq, uint32_t id, uint32_t index, uint32_t next, struct spa_pod *param)
{
	struct param_filter *f = data;
	f->n_params++;
	return pw_impl_port_for_each_param(f->out_port, seq, f->out_param_id, 0, 0, param, f->callback, f->data);
}

int pw_impl_port_for_each_filtered_param(struct pw_impl_port *in_port,
				    struct pw_impl_port *out_port,
				    int seq,
				    uint32_t in_param_id,
				    uint32_t out_param_id,
				    const struct spa_pod *filter,
				    int (*callback) (void *data, int seq,
						     uint32_t id, uint32_t index, uint32_t next,
						     struct spa_pod *param),
				    void *data)
{
	int res;
	struct param_filter fd = { in_port, out_port, seq, in_param_id, out_param_id, callback, data, 0 };

	if ((res = pw_impl_port_for_each_param(in_port, seq, in_param_id, 0, 0, filter, do_filter, &fd)) < 0)
		return res;

	if (fd.n_params == 0)
		res = do_filter(&filter, seq, 0, 0, 0, NULL);

	return res;
}

int pw_impl_port_for_each_link(struct pw_impl_port *port,
			  int (*callback) (void *data, struct pw_impl_link *link),
			  void *data)
{
	struct pw_impl_link *l, *t;
	int res = 0;

	if (port->direction == PW_DIRECTION_OUTPUT) {
		spa_list_for_each_safe(l, t, &port->links, output_link)
			if ((res = callback(data, l)) != 0)
				break;
	} else {
		spa_list_for_each_safe(l, t, &port->links, input_link)
			if ((res = callback(data, l)) != 0)
				break;
	}
	return res;
}

SPA_EXPORT
int pw_impl_port_is_linked(struct pw_impl_port *port)
{
	return spa_list_is_empty(&port->links) ? 0 : 1;
}

SPA_EXPORT
int pw_impl_port_set_param(struct pw_impl_port *port, uint32_t id, uint32_t flags,
		      const struct spa_pod *param)
{
	int res;
	struct pw_impl_node *node = port->node;

	pw_log_debug(NAME" %p: %d set param %d %p", port, port->state, id, param);

	/* set parameter on node */
	res = spa_node_port_set_param(node->node,
			port->direction, port->port_id,
			id, flags, param);

	pw_log_debug(NAME" %p: %d set param on node %d:%d id:%d (%s): %d (%s)", port, port->state,
			port->direction, port->port_id, id,
			spa_debug_type_find_name(spa_type_param, id),
			res, spa_strerror(res));

	/* set the parameters on all ports of the mixer node if possible */
	if (res >= 0) {
		struct pw_impl_port_mix *mix;

		if (port->direction == PW_DIRECTION_INPUT &&
		    id == SPA_PARAM_Format && param != NULL &&
		    !SPA_FLAG_IS_SET(port->flags, PW_IMPL_PORT_FLAG_NO_MIXER)) {
			setup_mixer(port, param);
		}

		spa_list_for_each(mix, &port->mix_list, link) {
			spa_node_port_set_param(port->mix,
				mix->port.direction, mix->port.port_id,
				id, flags, param);
		}
		spa_node_port_set_param(port->mix,
				pw_direction_reverse(port->direction), 0,
				id, flags, param);
	}

	if (id == SPA_PARAM_Format) {
		pw_log_debug(NAME" %p: %d %p %d", port, port->state, param, res);

		if (port->added) {
			pw_loop_invoke(node->data_loop, do_remove_port, SPA_ID_INVALID, NULL, 0, true, port);
			port->added = false;
		}
		/* setting the format always destroys the negotiated buffers */
		pw_buffers_clear(&port->buffers);
		pw_buffers_clear(&port->mix_buffers);

		if (param == NULL || res < 0) {
			pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_CONFIGURE, 0, NULL);
		}
		else if (!SPA_RESULT_IS_ASYNC(res)) {
			pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_READY, 0, NULL);
		}
	}
	return res;
}

static int negotiate_mixer_buffers(struct pw_impl_port *port, uint32_t flags,
                struct spa_buffer **buffers, uint32_t n_buffers)
{
	int res;
	struct pw_impl_node *node = port->node;

	if (SPA_FLAG_IS_SET(port->mix_flags, PW_IMPL_PORT_MIX_FLAG_MIX_ONLY))
		return 0;

	if (SPA_FLAG_IS_SET(port->mix_flags, PW_IMPL_PORT_MIX_FLAG_NEGOTIATE)) {
		int alloc_flags;

		/* try dynamic data */
		alloc_flags = PW_BUFFERS_FLAG_DYNAMIC;

		pw_log_debug(NAME" %p: %d.%d negotiate %d buffers on node: %p",
				port, port->direction, port->port_id, n_buffers, node->node);

		if (port->added) {
			pw_loop_invoke(node->data_loop, do_remove_port, SPA_ID_INVALID, NULL, 0, true, port);
			port->added = false;
		}

		pw_buffers_clear(&port->mix_buffers);

		if (n_buffers > 0) {
			if ((res = pw_buffers_negotiate(node->context, alloc_flags,
					port->mix, 0,
					node->node, port->port_id,
					&port->mix_buffers)) < 0) {
				pw_log_warn(NAME" %p: can't negotiate buffers: %s",
						port, spa_strerror(res));
				return res;
			}
			buffers = port->mix_buffers.buffers;
			n_buffers = port->mix_buffers.n_buffers;
			flags = 0;
		}
	}

	pw_log_debug(NAME" %p: %d.%d use %d buffers on node: %p",
			port, port->direction, port->port_id, n_buffers, node->node);

	res = spa_node_port_use_buffers(node->node,
			port->direction, port->port_id,
			flags, buffers, n_buffers);

	if (SPA_RESULT_IS_OK(res)) {
		spa_node_port_use_buffers(port->mix,
			     pw_direction_reverse(port->direction), 0,
			     0, buffers, n_buffers);
	}
	if (!port->added && n_buffers > 0) {
		pw_loop_invoke(node->data_loop, do_add_port, SPA_ID_INVALID, NULL, 0, false, port);
		port->added = true;
	}
	return res;
}


SPA_EXPORT
int pw_impl_port_use_buffers(struct pw_impl_port *port, struct pw_impl_port_mix *mix, uint32_t flags,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	int res = 0, res2;

	pw_log_debug(NAME" %p: %d:%d.%d: %d buffers flags:%d state:%d n_mix:%d", port,
			port->direction, port->port_id, mix->id,
			n_buffers, flags, port->state, port->n_mix);

	if (n_buffers == 0 && port->state <= PW_IMPL_PORT_STATE_READY)
		return 0;

	if (n_buffers > 0 && port->state < PW_IMPL_PORT_STATE_READY)
		return -EIO;

	if (n_buffers == 0) {
		if (port->n_mix == 1)
			pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_READY, 0, NULL);
	}

	/* first negotiate with the node, this makes it possible to let the
	 * node allocate buffer memory if needed */
	if (port->state == PW_IMPL_PORT_STATE_READY) {
		res = negotiate_mixer_buffers(port, flags, buffers, n_buffers);

		if (res < 0) {
			pw_log_error(NAME" %p: negotiate buffers on node: %d (%s)",
				port, res, spa_strerror(res));
			pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_ERROR, res,
					strdup("can't negotiate buffers on port"));
		} else if (n_buffers > 0 && !SPA_RESULT_IS_ASYNC(res)) {
			pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_PAUSED, 0, NULL);
		}
	}

	/* then use the buffers on the mixer */
	if (!SPA_FLAG_IS_SET(port->mix_flags, PW_IMPL_PORT_MIX_FLAG_MIX_ONLY))
		flags &= ~SPA_NODE_BUFFERS_FLAG_ALLOC;

	res2 = spa_node_port_use_buffers(port->mix,
			mix->port.direction, mix->port.port_id, flags,
			buffers, n_buffers);
	if (res2 < 0) {
		if (res2 != -ENOTSUP && n_buffers > 0) {
			pw_log_warn(NAME" %p: mix use buffers failed: %d (%s)",
					port, res2, spa_strerror(res2));
			return res2;
		}
	}
	else if (SPA_RESULT_IS_ASYNC(res2))
		res = res2;

	return res;
}
