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

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

#include <spa/node/utils.h>
#include <spa/pod/parser.h>
#include <spa/pod/compare.h>
#include <spa/param/param.h>

#include "pipewire/impl-link.h"
#include "pipewire/private.h"

#include <spa/debug/node.h>
#include <spa/debug/pod.h>
#include <spa/debug/format.h>

#define NAME "link"

#define pw_link_resource_info(r,...)      pw_resource_call(r,struct pw_link_events,info,0,__VA_ARGS__)

/** \cond */
struct impl {
	struct pw_impl_link this;

	unsigned int io_set:1;
	unsigned int activated:1;

	struct pw_work_queue *work;

	struct spa_pod *format_filter;
	struct pw_properties *properties;

	struct spa_hook input_port_listener;
	struct spa_hook input_node_listener;
	struct spa_hook input_global_listener;
	struct spa_hook output_port_listener;
	struct spa_hook output_node_listener;
	struct spa_hook output_global_listener;

	struct spa_io_buffers io;

	struct pw_impl_node *inode, *onode;
};

/** \endcond */

static void info_changed(struct pw_impl_link *link)
{
	struct pw_resource *resource;

	if (link->info.change_mask == 0)
		return;

	pw_impl_link_emit_info_changed(link, &link->info);

	if (link->global)
		spa_list_for_each(resource, &link->global->resource_list, link)
			pw_link_resource_info(resource, &link->info);

	link->info.change_mask = 0;
}

static void link_update_state(struct pw_impl_link *link, enum pw_link_state state, int res, char *error)
{
	enum pw_link_state old = link->info.state;

	link->info.state = state;
	free((char*)link->info.error);
	link->info.error = error;

	if (state == old)
		return;

	pw_log_debug(NAME" %p: %s -> %s (%s)", link,
		     pw_link_state_as_string(old),
		     pw_link_state_as_string(state), error);

	if (state == PW_LINK_STATE_ERROR) {
		pw_log_error("(%s) %s -> error (%s)", link->name,
				pw_link_state_as_string(old), error);
	} else {
		pw_log_info("(%s) %s -> %s", link->name,
				pw_link_state_as_string(old),
				pw_link_state_as_string(state));
	}

	pw_impl_link_emit_state_changed(link, old, state, error);

	link->info.change_mask |= PW_LINK_CHANGE_MASK_STATE;
	if (state == PW_LINK_STATE_ERROR ||
	    state == PW_LINK_STATE_PAUSED ||
	    state == PW_LINK_STATE_ACTIVE)
		info_changed(link);

	if (state == PW_LINK_STATE_ERROR && link->global) {
		struct pw_resource *resource;
		spa_list_for_each(resource, &link->global->resource_list, link)
			pw_resource_error(resource, res, error);
	}

	if (old < PW_LINK_STATE_PAUSED && state == PW_LINK_STATE_PAUSED) {
		link->prepared = true;
		link->preparing = false;
		pw_context_recalc_graph(link->context, "link prepared");
	} else if (old == PW_LINK_STATE_PAUSED && state < PW_LINK_STATE_PAUSED) {
		link->prepared = false;
		link->preparing = false;
		pw_context_recalc_graph(link->context, "link unprepared");
	}
}

static void complete_ready(void *obj, void *data, int res, uint32_t id)
{
	struct pw_impl_port *port = obj;
	struct pw_impl_link *this = data;

	pw_log_debug(NAME" %p: obj:%p port %p complete READY: %s", this, obj, port, spa_strerror(res));

	if (SPA_RESULT_IS_OK(res)) {
		pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_READY,
				0, NULL);
	} else {
		pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_ERROR,
				res, spa_aprintf("port error going to READY: %s", spa_strerror(res)));
	}
	if (this->input->state >= PW_IMPL_PORT_STATE_READY &&
	    this->output->state >= PW_IMPL_PORT_STATE_READY)
		link_update_state(this, PW_LINK_STATE_ALLOCATING, 0, NULL);
}

static void complete_paused(void *obj, void *data, int res, uint32_t id)
{
	struct pw_impl_port *port = obj;
	struct pw_impl_link *this = data;
	struct pw_impl_port_mix *mix = port == this->input ? &this->rt.in_mix : &this->rt.out_mix;

	pw_log_debug(NAME" %p: obj:%p port %p complete PAUSED: %s", this, obj, port, spa_strerror(res));

	if (SPA_RESULT_IS_OK(res)) {
		pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_PAUSED,
				0, NULL);
		mix->have_buffers = true;
	} else {
		pw_impl_port_update_state(port, PW_IMPL_PORT_STATE_ERROR,
				res, spa_aprintf("port error going to PAUSED: %s", spa_strerror(res)));
		mix->have_buffers = false;
	}
	if (this->rt.in_mix.have_buffers && this->rt.out_mix.have_buffers)
		link_update_state(this, PW_LINK_STATE_PAUSED, 0, NULL);
}

static int do_negotiate(struct pw_impl_link *this)
{
	struct pw_context *context = this->context;
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	int res = -EIO, res2;
	struct spa_pod *format = NULL, *current;
	char *error = NULL;
	bool changed = true;
	struct pw_impl_port *input, *output;
	uint8_t buffer[4096];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	uint32_t index;
	uint32_t in_state, out_state;

	if (this->info.state >= PW_LINK_STATE_NEGOTIATING)
		return 0;

	input = this->input;
	output = this->output;

	in_state = input->state;
	out_state = output->state;

	pw_log_debug(NAME" %p: in_state:%d out_state:%d", this, in_state, out_state);

	if (in_state != PW_IMPL_PORT_STATE_CONFIGURE && out_state != PW_IMPL_PORT_STATE_CONFIGURE)
		return 0;

	link_update_state(this, PW_LINK_STATE_NEGOTIATING, 0, NULL);

	input = this->input;
	output = this->output;

	/* find a common format for the ports */
	if ((res = pw_context_find_format(context,
					output, input, NULL, 0, NULL,
					&format, &b, &error)) < 0)
		goto error;

	format = spa_pod_copy(format);
	spa_pod_fixate(format);

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	/* if output port had format and is idle, check if it changed. If so, renegotiate */
	if (out_state > PW_IMPL_PORT_STATE_CONFIGURE && output->node->info.state == PW_NODE_STATE_IDLE) {
		index = 0;
		res = spa_node_port_enum_params_sync(output->node->node,
				output->direction, output->port_id,
				SPA_PARAM_Format, &index,
				NULL, &current, &b);
		switch (res) {
		case -EIO:
			current = NULL;
			res = 0;
			SPA_FALLTHROUGH
		case 1:
			break;
		case 0:
			res = -EBADF;
			SPA_FALLTHROUGH
		default:
			error = spa_aprintf("error get output format: %s", spa_strerror(res));
			goto error;
		}
		if (current == NULL || spa_pod_compare(current, format) != 0) {
			pw_log_debug(NAME" %p: output format change, renegotiate", this);
			if (current)
				pw_log_pod(SPA_LOG_LEVEL_DEBUG, current);
			pw_log_pod(SPA_LOG_LEVEL_DEBUG, format);
			pw_impl_node_set_state(output->node, PW_NODE_STATE_SUSPENDED);
			out_state = PW_IMPL_PORT_STATE_CONFIGURE;
		}
		else {
			pw_log_debug(NAME" %p: format was already set", this);
			changed = false;
		}
	}
	/* if input port had format and is idle, check if it changed. If so, renegotiate */
	if (in_state > PW_IMPL_PORT_STATE_CONFIGURE && input->node->info.state == PW_NODE_STATE_IDLE) {
		index = 0;
		res = spa_node_port_enum_params_sync(input->node->node,
				input->direction, input->port_id,
				SPA_PARAM_Format, &index,
				NULL, &current, &b);
		switch (res) {
		case -EIO:
			current = NULL;
			res = 0;
			SPA_FALLTHROUGH
		case 1:
			break;
		case 0:
			res = -EBADF;
			SPA_FALLTHROUGH
		default:
			error = spa_aprintf("error get input format: %s", spa_strerror(res));
			goto error;
		}
		if (current == NULL || spa_pod_compare(current, format) != 0) {
			pw_log_debug(NAME" %p: input format change, renegotiate", this);
			if (current)
				pw_log_pod(SPA_LOG_LEVEL_DEBUG, current);
			pw_log_pod(SPA_LOG_LEVEL_DEBUG, format);
			pw_impl_node_set_state(input->node, PW_NODE_STATE_SUSPENDED);
			in_state = PW_IMPL_PORT_STATE_CONFIGURE;
		}
		else {
			pw_log_debug(NAME" %p: format was already set", this);
			changed = false;
		}
	}

	pw_log_debug(NAME" %p: doing set format %p", this, format);
	pw_log_pod(SPA_LOG_LEVEL_DEBUG, format);

	SPA_POD_OBJECT_ID(format) = SPA_PARAM_Format;

	if (out_state == PW_IMPL_PORT_STATE_CONFIGURE) {
		pw_log_debug(NAME" %p: doing set format on output", this);
		if ((res = pw_impl_port_set_param(output,
						SPA_PARAM_Format, 0,
						format)) < 0) {
			error = spa_aprintf("error set output format: %d (%s)", res, spa_strerror(res));
			pw_log_error("tried to set output format:");
			pw_log_pod(SPA_LOG_LEVEL_ERROR, format);
			goto error;
		}
		if (SPA_RESULT_IS_ASYNC(res)) {
			res = spa_node_sync(output->node->node, res),
			pw_work_queue_add(impl->work, output, res,
					complete_ready, this);
		} else {
			complete_ready(output, this, res, 0);
		}
	}
	if (in_state == PW_IMPL_PORT_STATE_CONFIGURE) {
		pw_log_debug(NAME" %p: doing set format on input", this);
		if ((res2 = pw_impl_port_set_param(input,
						SPA_PARAM_Format, 0,
						format)) < 0) {
			error = spa_aprintf("error set input format: %d (%s)", res2, spa_strerror(res2));
			pw_log_error("tried to set input format:");
			pw_log_pod(SPA_LOG_LEVEL_ERROR, format);
			goto error;
		}
		if (SPA_RESULT_IS_ASYNC(res2)) {
			res2 = spa_node_sync(input->node->node, res2),
			pw_work_queue_add(impl->work, input, res2,
					complete_ready, this);
			if (res == 0)
				res = res2;
		} else {
			complete_ready(input, this, res2, 0);
		}
	}

	free(this->info.format);
	this->info.format = format;

	if (changed)
		this->info.change_mask |= PW_LINK_CHANGE_MASK_FORMAT;

	pw_log_debug(NAME" %p: result %d", this, res);
	return res;

error:
	pw_context_debug_port_params(context, input->node->node, input->direction,
			input->port_id, SPA_PARAM_EnumFormat, res,
			"input format (%s)", error);
	pw_context_debug_port_params(context, output->node->node, output->direction,
			output->port_id, SPA_PARAM_EnumFormat, res,
			"output format (%s)", error);
	link_update_state(this, PW_LINK_STATE_ERROR, res, error);
	free(format);
	return res;
}

static int port_set_io(struct pw_impl_link *this, struct pw_impl_port *port, uint32_t id,
		void *data, size_t size, struct pw_impl_port_mix *mix)
{
	int res = 0;

	mix->io = data;
	pw_log_debug(NAME" %p: %s port %p %d.%d set io: %d %p %zd", this,
			pw_direction_as_string(port->direction),
			port, port->port_id, mix->port.port_id, id, data, size);

	if ((res = spa_node_port_set_io(port->mix,
			     mix->port.direction,
			     mix->port.port_id,
			     id, data, size)) < 0) {
		if (res == -ENOTSUP)
			res = 0;
		else
			pw_log_warn(NAME" %p: port %p can't set io:%d (%s): %s",
					this, port, id,
					spa_debug_type_find_name(spa_type_io, id),
					spa_strerror(res));
	}
	return res;
}

static int select_io(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	struct spa_io_buffers *io;

	io = this->rt.in_mix.io;
	if (io == NULL)
		io = this->rt.out_mix.io;
	if (io == NULL)
		io = &impl->io;
	if (io == NULL)
		return -EIO;

	this->io = io;
	*this->io = SPA_IO_BUFFERS_INIT;

	return 0;
}

static int do_allocation(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	int res;
	uint32_t in_flags, out_flags;
	char *error = NULL;
	struct pw_impl_port *input, *output;

	if (this->info.state > PW_LINK_STATE_ALLOCATING)
		return 0;

	output = this->output;
	input = this->input;

	pw_log_debug(NAME" %p: out-state:%d in-state:%d", this, output->state, input->state);

	link_update_state(this, PW_LINK_STATE_ALLOCATING, 0, NULL);

	out_flags = output->spa_flags;
	in_flags = input->spa_flags;

	pw_log_debug(NAME" %p: out-node:%p in-node:%p: out-flags:%08x in-flags:%08x",
			this, output->node, input->node, out_flags, in_flags);

	this->rt.in_mix.have_buffers = false;
	this->rt.out_mix.have_buffers = false;

	if (out_flags & SPA_PORT_FLAG_LIVE) {
		pw_log_debug(NAME" %p: setting link as live", this);
		output->node->live = true;
		input->node->live = true;
	}

	if (output->buffers.n_buffers) {
		pw_log_debug(NAME" %p: reusing %d output buffers %p", this,
				output->buffers.n_buffers, output->buffers.buffers);
		this->rt.out_mix.have_buffers = true;
	} else {
		uint32_t flags, alloc_flags;

		flags = 0;
		/* always shared buffers for the link */
		alloc_flags = PW_BUFFERS_FLAG_SHARED;
		/* if output port can alloc buffers, alloc skeleton buffers */
		if (SPA_FLAG_IS_SET(out_flags, SPA_PORT_FLAG_CAN_ALLOC_BUFFERS)) {
			SPA_FLAG_SET(alloc_flags, PW_BUFFERS_FLAG_NO_MEM);
			flags |= SPA_NODE_BUFFERS_FLAG_ALLOC;
		}

		if ((res = pw_buffers_negotiate(this->context, alloc_flags,
						output->node->node, output->port_id,
						input->node->node, input->port_id,
						&output->buffers)) < 0) {
			error = spa_aprintf("error alloc buffers: %s", spa_strerror(res));
			goto error;
		}

		pw_log_debug(NAME" %p: allocating %d buffers %p", this,
			     output->buffers.n_buffers, output->buffers.buffers);

		if ((res = pw_impl_port_use_buffers(output, &this->rt.out_mix, flags,
						output->buffers.buffers,
						output->buffers.n_buffers)) < 0) {
			error = spa_aprintf("error use output buffers: %d (%s)", res,
					spa_strerror(res));
			goto error_clear;
		}
		if (SPA_RESULT_IS_ASYNC(res)) {
			res = spa_node_sync(output->node->node, res),
			pw_work_queue_add(impl->work, output, res,
					complete_paused, this);
			if (flags & SPA_NODE_BUFFERS_FLAG_ALLOC)
				return 0;
		} else {
			complete_paused(output, this, res, 0);
		}
	}

	pw_log_debug(NAME" %p: using %d buffers %p on input port", this,
		     output->buffers.n_buffers, output->buffers.buffers);

	if ((res = pw_impl_port_use_buffers(input, &this->rt.in_mix, 0,
				output->buffers.buffers,
				output->buffers.n_buffers)) < 0) {
		error = spa_aprintf("error use input buffers: %d (%s)", res,
				spa_strerror(res));
		goto error;
	}

	if (SPA_RESULT_IS_ASYNC(res)) {
		res = spa_node_sync(input->node->node, res),
		pw_work_queue_add(impl->work, input, res,
				complete_paused, this);
	} else {
		complete_paused(input, this, res, 0);
	}
	return 0;

error_clear:
	pw_buffers_clear(&output->buffers);
error:
	link_update_state(this, PW_LINK_STATE_ERROR, res, error);
	return res;
}

static int
do_activate_link(struct spa_loop *loop,
		 bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
	struct pw_impl_link *this = user_data;
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);

	pw_log_trace(NAME" %p: activate", this);

	spa_list_append(&this->output->rt.mix_list, &this->rt.out_mix.rt_link);
	spa_list_append(&this->input->rt.mix_list, &this->rt.in_mix.rt_link);

	if (impl->inode != impl->onode) {
		struct pw_node_activation_state *state;

		this->rt.target.activation = impl->inode->rt.activation;
		spa_list_append(&impl->onode->rt.target_list, &this->rt.target.link);

		state = &this->rt.target.activation->state[0];
		if (!this->rt.target.active && impl->onode->rt.driver_target.node != NULL) {
			state->required++;
			this->rt.target.active = true;
		}

		pw_log_trace(NAME" %p: node:%p state:%p pending:%d/%d", this, impl->inode,
				state, state->pending, state->required);
	}
	return 0;
}

int pw_impl_link_activate(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	int res;

	pw_log_debug(NAME" %p: activate activated:%d state:%s", this, impl->activated,
			pw_link_state_as_string(this->info.state));

	if (impl->activated || !this->prepared || !impl->inode->active || !impl->onode->active)
		return 0;

	if (!impl->io_set) {
		if ((res = port_set_io(this, this->output, SPA_IO_Buffers, this->io,
				sizeof(struct spa_io_buffers), &this->rt.out_mix)) < 0)
			return res;

		if ((res = port_set_io(this, this->input, SPA_IO_Buffers, this->io,
				sizeof(struct spa_io_buffers), &this->rt.in_mix)) < 0)
			return res;
		impl->io_set = true;
	}
	pw_loop_invoke(this->output->node->data_loop,
	       do_activate_link, SPA_ID_INVALID, NULL, 0, false, this);

	impl->activated = true;
	pw_log_info("(%s) activated", this->name);
	link_update_state(this, PW_LINK_STATE_ACTIVE, 0, NULL);

	return 0;
}
static void check_states(void *obj, void *user_data, int res, uint32_t id)
{
	struct pw_impl_link *this = obj;
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	int in_state, out_state;
	struct pw_impl_port *input, *output;

	if (this->info.state == PW_LINK_STATE_ERROR)
		return;

	if (this->info.state >= PW_LINK_STATE_PAUSED)
		return;

	output = this->output;
	input = this->input;

	if (output == NULL || input == NULL) {
		link_update_state(this, PW_LINK_STATE_ERROR, -EIO,
				strdup(NAME" without input or output port"));
		return;
	}

	if (output->node->info.state == PW_NODE_STATE_ERROR ||
	    input->node->info.state == PW_NODE_STATE_ERROR) {
		pw_log_warn(NAME" %p: one of the nodes is in error out:%s in:%s", this,
				pw_node_state_as_string(output->node->info.state),
				pw_node_state_as_string(input->node->info.state));
		return;
	}

	out_state = output->state;
	in_state = input->state;

	pw_log_debug(NAME" %p: output state %d, input state %d", this, out_state, in_state);

	if (out_state == PW_IMPL_PORT_STATE_ERROR || in_state == PW_IMPL_PORT_STATE_ERROR) {
		link_update_state(this, PW_LINK_STATE_ERROR, -EIO, strdup("ports are in error"));
		return;
	}

	if (PW_IMPL_PORT_IS_CONTROL(output) && PW_IMPL_PORT_IS_CONTROL(input)) {
		pw_impl_port_update_state(output, PW_IMPL_PORT_STATE_PAUSED, 0, NULL);
		pw_impl_port_update_state(input, PW_IMPL_PORT_STATE_PAUSED, 0, NULL);
		link_update_state(this, PW_LINK_STATE_PAUSED, 0, NULL);
	}

	if ((res = do_negotiate(this)) != 0)
		goto exit;

	if ((res = do_allocation(this)) != 0)
		goto exit;

exit:
	if (SPA_RESULT_IS_ERROR(res)) {
		pw_log_debug(NAME" %p: got error result %d (%s)", this, res, spa_strerror(res));
		return;
	}

	pw_work_queue_add(impl->work,
			  this, -EBUSY, (pw_work_func_t) check_states, this);
}

static void input_remove(struct pw_impl_link *this, struct pw_impl_port *port)
{
	struct impl *impl = (struct impl *) this;
	struct pw_impl_port_mix *mix = &this->rt.in_mix;
	int res;

	pw_log_debug(NAME" %p: remove input port %p", this, port);
	spa_hook_remove(&impl->input_port_listener);
	spa_hook_remove(&impl->input_node_listener);
	spa_hook_remove(&impl->input_global_listener);

	spa_list_remove(&this->input_link);
	pw_impl_port_emit_link_removed(this->input, this);

	if ((res = pw_impl_port_use_buffers(port, mix, 0, NULL, 0)) < 0) {
		pw_log_warn(NAME" %p: port %p clear error %s", this, port, spa_strerror(res));
	}
	pw_impl_port_release_mix(port, mix);
	this->input = NULL;
}

static void output_remove(struct pw_impl_link *this, struct pw_impl_port *port)
{
	struct impl *impl = (struct impl *) this;
	struct pw_impl_port_mix *mix = &this->rt.out_mix;

	pw_log_debug(NAME" %p: remove output port %p", this, port);
	spa_hook_remove(&impl->output_port_listener);
	spa_hook_remove(&impl->output_node_listener);
	spa_hook_remove(&impl->output_global_listener);

	spa_list_remove(&this->output_link);
	pw_impl_port_emit_link_removed(this->output, this);

	/* we don't clear output buffers when the link goes away. They will get
	 * cleared when the node goes to suspend */
	pw_impl_port_release_mix(port, mix);
	this->output = NULL;
}

int pw_impl_link_prepare(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);

	pw_log_debug(NAME" %p: prepare prepared:%d busy:%d", this, this->prepared, this->preparing);

	if (this->preparing || this->prepared)
		return 0;

	this->preparing = true;

	pw_work_queue_add(impl->work,
			  this, -EBUSY, (pw_work_func_t) check_states, this);

	return 0;
}

static int
do_deactivate_link(struct spa_loop *loop,
		   bool async, uint32_t seq, const void *data, size_t size, void *user_data)
{
        struct pw_impl_link *this = user_data;
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);

	pw_log_trace(NAME" %p: disable %p and %p", this, &this->rt.in_mix, &this->rt.out_mix);

	spa_list_remove(&this->rt.out_mix.rt_link);
	spa_list_remove(&this->rt.in_mix.rt_link);

	if (this->input->node != this->output->node) {
		struct pw_node_activation_state *state;

		spa_list_remove(&this->rt.target.link);
		state = &this->rt.target.activation->state[0];
		if (this->rt.target.active) {
			state->required--;
			this->rt.target.active = false;
		}

		pw_log_trace(NAME" %p: node:%p state:%p pending:%d/%d", this, impl->inode,
				state, state->pending, state->required);
	}

	return 0;
}

int pw_impl_link_deactivate(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);

	pw_log_debug(NAME" %p: deactivate activated:%d", this, impl->activated);

	if (!impl->activated)
		return 0;

	pw_loop_invoke(this->output->node->data_loop,
		       do_deactivate_link, SPA_ID_INVALID, NULL, 0, true, this);

	port_set_io(this, this->output, SPA_IO_Buffers, NULL, 0,
			&this->rt.out_mix);
	port_set_io(this, this->input, SPA_IO_Buffers, NULL, 0,
			&this->rt.in_mix);

	impl->io_set = false;
	impl->activated = false;
	pw_log_info("(%s) deactivated", this->name);
	link_update_state(this, PW_LINK_STATE_PAUSED, 0, NULL);

	return 0;
}

static int
global_bind(void *_data, struct pw_impl_client *client, uint32_t permissions,
	       uint32_t version, uint32_t id)
{
	struct pw_impl_link *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;

	resource = pw_resource_new(client, id, permissions, global->type, version, 0);
	if (resource == NULL)
		goto error_resource;

	pw_log_debug(NAME" %p: bound to %d", this, resource->id);
	pw_global_add_resource(global, resource);

	this->info.change_mask = PW_LINK_CHANGE_MASK_ALL;
	pw_link_resource_info(resource, &this->info);
	this->info.change_mask = 0;

	return 0;

error_resource:
	pw_log_error(NAME" %p: can't create link resource: %m", this);
	return -errno;
}

static void port_state_changed(struct pw_impl_link *this, struct pw_impl_port *port, struct pw_impl_port *other,
			enum pw_impl_port_state state, const char *error)
{
	pw_log_debug(NAME" %p: port %p state %d", this, port, state);

	switch (state) {
	case PW_IMPL_PORT_STATE_ERROR:
		link_update_state(this, PW_LINK_STATE_ERROR, -EIO, error ? strdup(error) : NULL);
		break;
	case PW_IMPL_PORT_STATE_INIT:
	case PW_IMPL_PORT_STATE_CONFIGURE:
		if (this->prepared) {
			this->prepared = false;
			link_update_state(this, PW_LINK_STATE_INIT, 0, NULL);
		}
		break;
	case PW_IMPL_PORT_STATE_READY:
		if (this->prepared) {
			this->prepared = false;
			link_update_state(this, PW_LINK_STATE_NEGOTIATING, 0, NULL);
		}
		break;
	case PW_IMPL_PORT_STATE_PAUSED:
		break;
	}
}

static void port_param_changed(struct pw_impl_link *this, uint32_t id,
		struct pw_impl_port *outport, struct pw_impl_port *inport)
{
	enum pw_impl_port_state target;

	pw_log_debug(NAME" %p: outport %p input %p param %d", this,
		outport, inport, id);

	switch (id) {
	case SPA_PARAM_EnumFormat:
		target = PW_IMPL_PORT_STATE_CONFIGURE;
		break;
//	case SPA_PARAM_Buffers:
//		target = PW_IMPL_PORT_STATE_READY;
//		break;
	default:
		return;
	}
	if (outport)
		pw_impl_port_update_state(outport, target, 0, NULL);
	if (inport)
		pw_impl_port_update_state(inport, target, 0, NULL);

	pw_impl_link_prepare(this);
}

static void input_port_param_changed(void *data, uint32_t id)
{
	struct impl *impl = data;
	struct pw_impl_link *this = &impl->this;
	port_param_changed(this, id, this->output, this->input);
}

static void input_port_state_changed(void *data, enum pw_impl_port_state old,
			enum pw_impl_port_state state, const char *error)
{
	struct impl *impl = data;
	struct pw_impl_link *this = &impl->this;
	port_state_changed(this, this->input, this->output, state, error);
}

static void output_port_param_changed(void *data, uint32_t id)
{
	struct impl *impl = data;
	struct pw_impl_link *this = &impl->this;
	port_param_changed(this, id, this->output, this->input);
}

static void output_port_state_changed(void *data, enum pw_impl_port_state old,
			enum pw_impl_port_state state, const char *error)
{
	struct impl *impl = data;
	struct pw_impl_link *this = &impl->this;
	port_state_changed(this, this->output, this->input, state, error);
}

static const struct pw_impl_port_events input_port_events = {
	PW_VERSION_IMPL_PORT_EVENTS,
	.param_changed = input_port_param_changed,
	.state_changed = input_port_state_changed,
};

static const struct pw_impl_port_events output_port_events = {
	PW_VERSION_IMPL_PORT_EVENTS,
	.param_changed = output_port_param_changed,
	.state_changed = output_port_state_changed,
};

static void node_result(struct impl *impl, struct pw_impl_port *port,
		int seq, int res, uint32_t type, const void *result)
{
	if (SPA_RESULT_IS_ASYNC(seq))
		pw_work_queue_complete(impl->work, port, SPA_RESULT_ASYNC_SEQ(seq), res);
}

static void input_node_result(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct impl *impl = data;
	struct pw_impl_port *port = impl->this.input;
	pw_log_trace(NAME" %p: input port %p result seq:%d res:%d type:%u",
			impl, port, seq, res, type);
	node_result(impl, port, seq, res, type, result);
}

static void output_node_result(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct impl *impl = data;
	struct pw_impl_port *port = impl->this.output;
	pw_log_trace(NAME" %p: output port %p result seq:%d res:%d type:%u",
			impl, port, seq, res, type);
	node_result(impl, port, seq, res, type, result);
}

static void check_prepare(struct pw_impl_link *this)
{
	struct impl *impl = SPA_CONTAINER_OF(this, struct impl, this);
	pw_log_debug(NAME" %p: input active:%d output active:%d", impl,
			impl->inode->active, impl->onode->active);
	if (impl->inode->active && impl->onode->active)
		pw_impl_link_prepare(this);
}

static void node_active_changed(void *data, bool active)
{
	struct impl *impl = data;
	check_prepare(&impl->this);
}

static const struct pw_impl_node_events input_node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.result = input_node_result,
	.active_changed = node_active_changed,
};

static const struct pw_impl_node_events output_node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.result = output_node_result,
	.active_changed = node_active_changed,
};

static bool pw_impl_node_can_reach(struct pw_impl_node *output, struct pw_impl_node *input)
{
	struct pw_impl_port *p;

	if (output == input)
		return true;

	spa_list_for_each(p, &output->output_ports, link) {
		struct pw_impl_link *l;

		spa_list_for_each(l, &p->links, output_link) {
			if (l->feedback)
				continue;
			if (l->input->node == input)
				return true;
		}
		spa_list_for_each(l, &p->links, output_link) {
			if (l->feedback)
				continue;
			if (pw_impl_node_can_reach(l->input->node, input))
				return true;
		}
	}
	return false;
}

static void try_link_controls(struct impl *impl, struct pw_impl_port *output, struct pw_impl_port *input)
{
	struct pw_control *cin, *cout;
	struct pw_impl_link *this = &impl->this;
	uint32_t omix, imix;
	int res;

	imix = this->rt.in_mix.port.port_id;
	omix = this->rt.out_mix.port.port_id;

	pw_log_debug(NAME" %p: trying controls", impl);
	spa_list_for_each(cout, &output->control_list[SPA_DIRECTION_OUTPUT], port_link) {
		spa_list_for_each(cin, &input->control_list[SPA_DIRECTION_INPUT], port_link) {
			if ((res = pw_control_add_link(cout, omix, cin, imix, &this->control)) < 0)
				pw_log_error(NAME" %p: failed to link controls: %s",
						this, spa_strerror(res));
			break;
		}
	}
	spa_list_for_each(cin, &output->control_list[SPA_DIRECTION_INPUT], port_link) {
		spa_list_for_each(cout, &input->control_list[SPA_DIRECTION_OUTPUT], port_link) {
			if ((res = pw_control_add_link(cout, imix, cin, omix, &this->notify)) < 0)
				pw_log_error(NAME" %p: failed to link controls: %s",
						this, spa_strerror(res));
			break;
		}
	}
}

static void try_unlink_controls(struct impl *impl, struct pw_impl_port *output, struct pw_impl_port *input)
{
	struct pw_impl_link *this = &impl->this;
	int res;

	pw_log_debug(NAME" %p: unlinking controls", impl);
	if (this->control.valid) {
		if ((res = pw_control_remove_link(&this->control)) < 0)
			pw_log_error(NAME" %p: failed to unlink controls: %s",
					this, spa_strerror(res));
	}
	if (this->notify.valid) {
		if ((res = pw_control_remove_link(&this->notify)) < 0)
			pw_log_error(NAME" %p: failed to unlink controls: %s",
					this, spa_strerror(res));
	}
}

static int
check_permission(struct pw_context *context,
		 struct pw_impl_port *output,
		 struct pw_impl_port *input,
		 struct pw_properties *properties)
{
	return 0;
}

static void permissions_changed(struct pw_impl_link *this, struct pw_impl_port *other,
		struct pw_impl_client *client, uint32_t old, uint32_t new)
{
	uint32_t perm;

	perm = pw_global_get_permissions(other->global, client);
	old &= perm;
	new &= perm;
	pw_log_debug(NAME" %p: permissions changed %08x -> %08x", this, old, new);

	if (check_permission(this->context, this->output, this->input, this->properties) < 0) {
		pw_impl_link_destroy(this);
	} else {
		pw_global_update_permissions(this->global, client, old, new);
	}
}

static void output_permissions_changed(void *data,
		struct pw_impl_client *client, uint32_t old, uint32_t new)
{
	struct pw_impl_link *this = data;
	permissions_changed(this, this->input, client, old, new);
}

static const struct pw_global_events output_global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.permissions_changed = output_permissions_changed,
};

static void input_permissions_changed(void *data,
		struct pw_impl_client *client, uint32_t old, uint32_t new)
{
	struct pw_impl_link *this = data;
	permissions_changed(this, this->output, client, old, new);
}

static const struct pw_global_events input_global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.permissions_changed = input_permissions_changed,
};

SPA_EXPORT
struct pw_impl_link *pw_context_create_link(struct pw_context *context,
			    struct pw_impl_port *output,
			    struct pw_impl_port *input,
			    struct spa_pod *format_filter,
			    struct pw_properties *properties,
			    size_t user_data_size)
{
	struct impl *impl;
	struct pw_impl_link *this;
	struct pw_impl_node *input_node, *output_node;
	const char *str;
	int res;

	if (output == input)
		goto error_same_ports;

	if (output->direction != PW_DIRECTION_OUTPUT ||
	    input->direction != PW_DIRECTION_INPUT)
		goto error_wrong_direction;

	if (pw_impl_link_find(output, input))
		goto error_link_exists;

	if (check_permission(context, output, input, properties) < 0)
		goto error_link_not_allowed;

	output_node = output->node;
	input_node = input->node;

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL)
		goto error_no_mem;

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL)
		goto error_no_mem;

	this = &impl->this;
	this->feedback = pw_impl_node_can_reach(input_node, output_node);
	pw_properties_set(properties, PW_KEY_LINK_FEEDBACK, this->feedback ? "true" : NULL);

	pw_log_debug(NAME" %p: new out-port:%p -> in-port:%p", this, output, input);

	if (user_data_size > 0)
                this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	impl->work = pw_work_queue_new(context->main_loop);

	this->context = context;
	this->properties = properties;
	this->info.state = PW_LINK_STATE_INIT;

	this->output = output;
	this->input = input;

	/* passive means that this link does not make the nodes active */
	if ((str = pw_properties_get(properties, PW_KEY_LINK_PASSIVE)) != NULL)
		this->passive = pw_properties_parse_bool(str);

	spa_hook_list_init(&this->listener_list);

	impl->format_filter = format_filter;

	pw_impl_port_add_listener(input, &impl->input_port_listener, &input_port_events, impl);
	pw_impl_node_add_listener(input_node, &impl->input_node_listener, &input_node_events, impl);
	pw_global_add_listener(input->global, &impl->input_global_listener, &input_global_events, impl);
	pw_impl_port_add_listener(output, &impl->output_port_listener, &output_port_events, impl);
	pw_impl_node_add_listener(output_node, &impl->output_node_listener, &output_node_events, impl);
	pw_global_add_listener(output->global, &impl->output_global_listener, &output_global_events, impl);

	input_node->live = output_node->live;

	pw_log_debug(NAME" %p: output node %p live %d, feedback %d",
			this, output_node, output_node->live, this->feedback);

	spa_list_append(&output->links, &this->output_link);
	spa_list_append(&input->links, &this->input_link);

	this->info.format = NULL;
	this->info.props = &this->properties->dict;

	impl->io = SPA_IO_BUFFERS_INIT;

	pw_impl_port_init_mix(output, &this->rt.out_mix);
	pw_impl_port_init_mix(input, &this->rt.in_mix);

	if ((res = select_io(this)) < 0)
		goto error_no_io;

	if (this->feedback) {
		impl->inode = output_node;
		impl->onode = input_node;
	}
	else {
		impl->onode = output_node;
		impl->inode = input_node;
	}

	this->rt.target.signal = impl->inode->rt.target.signal;
	this->rt.target.data = impl->inode->rt.target.data;

	pw_log_debug(NAME" %p: constructed out:%p:%d.%d -> in:%p:%d.%d", impl,
		     output_node, output->port_id, this->rt.out_mix.port.port_id,
		     input_node, input->port_id, this->rt.in_mix.port.port_id);

	if (asprintf(&this->name, "%d.%d -> %d.%d",
			output_node->info.id, output->port_id,
			input_node->info.id, input->port_id) < 0)
		this->name = NULL;
	pw_log_info("(%s) (%s) -> (%s)", this->name, output_node->name, input_node->name);

	pw_impl_port_emit_link_added(output, this);
	pw_impl_port_emit_link_added(input, this);

	try_link_controls(impl, output, input);

	pw_impl_node_emit_peer_added(impl->onode, impl->inode);

	return this;

error_same_ports:
	res = -EINVAL;
	pw_log_debug("can't link the same ports");
	goto error_exit;
error_wrong_direction:
	res = -EINVAL;
	pw_log_debug("ports have wrong direction");
	goto error_exit;
error_link_exists:
	res = -EEXIST;
	pw_log_debug("link already exists");
	goto error_exit;
error_link_not_allowed:
	res = -EPERM;
	pw_log_debug("link not allowed");
	goto error_exit;
error_no_mem:
	res = -errno;
	pw_log_debug("alloc failed: %m");
	goto error_exit;
error_no_io:
	pw_log_debug(NAME" %p: can't set io %d (%s)", this, res, spa_strerror(res));
	goto error_free;
error_free:
	free(impl);
error_exit:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

static void global_destroy(void *object)
{
	struct pw_impl_link *link = object;
	spa_hook_remove(&link->global_listener);
	link->global = NULL;
	pw_impl_link_destroy(link);
}

static const struct pw_global_events global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.destroy = global_destroy,
};

SPA_EXPORT
int pw_impl_link_register(struct pw_impl_link *link,
		     struct pw_properties *properties)
{
	struct pw_context *context = link->context;
	struct pw_impl_node *output_node, *input_node;
	const char *keys[] = {
		PW_KEY_OBJECT_PATH,
		PW_KEY_MODULE_ID,
		PW_KEY_FACTORY_ID,
		PW_KEY_CLIENT_ID,
		PW_KEY_LINK_OUTPUT_PORT,
		PW_KEY_LINK_INPUT_PORT,
		PW_KEY_LINK_OUTPUT_NODE,
		PW_KEY_LINK_INPUT_NODE,
		NULL
	};

	if (link->registered)
		goto error_existed;

	output_node = link->output->node;
	input_node = link->input->node;

	link->info.output_node_id = output_node->global->id;
	link->info.output_port_id = link->output->global->id;
	link->info.input_node_id = input_node->global->id;
	link->info.input_port_id = link->input->global->id;

	link->global = pw_global_new(context,
				     PW_TYPE_INTERFACE_Link,
				     PW_VERSION_LINK,
				     properties,
				     global_bind,
				     link);
	if (link->global == NULL)
		return -errno;

	spa_list_append(&context->link_list, &link->link);
	link->registered = true;

	link->info.id = link->global->id;
	pw_properties_setf(link->properties, PW_KEY_OBJECT_ID, "%d", link->info.id);
	pw_properties_setf(link->properties, PW_KEY_LINK_OUTPUT_PORT, "%d", link->info.output_port_id);
	pw_properties_setf(link->properties, PW_KEY_LINK_INPUT_PORT, "%d", link->info.input_port_id);
	link->info.props = &link->properties->dict;

	pw_global_update_keys(link->global, link->info.props, keys);

	pw_impl_link_emit_initialized(link);

	pw_global_add_listener(link->global, &link->global_listener, &global_events, link);
	pw_global_register(link->global);

	check_prepare(link);

	return 0;

error_existed:
	if (properties)
		pw_properties_free(properties);
	return -EEXIST;
}

SPA_EXPORT
void pw_impl_link_destroy(struct pw_impl_link *link)
{
	struct impl *impl = SPA_CONTAINER_OF(link, struct impl, this);

	pw_log_debug(NAME" %p: destroy", impl);
	pw_log_info("(%s) destroy", link->name);
	pw_impl_link_emit_destroy(link);

	pw_impl_link_deactivate(link);

	if (link->registered)
		spa_list_remove(&link->link);

	pw_impl_node_emit_peer_removed(impl->onode, impl->inode);

	try_unlink_controls(impl, link->output, link->input);

	output_remove(link, link->output);
	input_remove(link, link->input);

	if (link->global) {
		spa_hook_remove(&link->global_listener);
		pw_global_destroy(link->global);
	}

	if (link->prepared)
		pw_context_recalc_graph(link->context, "link destroy");

	pw_log_debug(NAME" %p: free", impl);
	pw_impl_link_emit_free(link);

	spa_hook_list_clean(&link->listener_list);

	pw_work_queue_destroy(impl->work);

	pw_properties_free(link->properties);

	free(link->name);
	free(link->info.format);
	free(impl);
}

SPA_EXPORT
void pw_impl_link_add_listener(struct pw_impl_link *link,
			  struct spa_hook *listener,
			  const struct pw_impl_link_events *events,
			  void *data)
{
	pw_log_debug(NAME" %p: add listener %p", link, listener);
	spa_hook_list_append(&link->listener_list, listener, events, data);
}

struct pw_impl_link *pw_impl_link_find(struct pw_impl_port *output_port, struct pw_impl_port *input_port)
{
	struct pw_impl_link *pl;

	spa_list_for_each(pl, &output_port->links, output_link) {
		if (pl->input == input_port)
			return pl;
	}
	return NULL;
}

SPA_EXPORT
struct pw_context *pw_impl_link_get_context(struct pw_impl_link *link)
{
	return link->context;
}

SPA_EXPORT
void *pw_impl_link_get_user_data(struct pw_impl_link *link)
{
	return link->user_data;
}

SPA_EXPORT
const struct pw_link_info *pw_impl_link_get_info(struct pw_impl_link *link)
{
	return &link->info;
}

SPA_EXPORT
struct pw_global *pw_impl_link_get_global(struct pw_impl_link *link)
{
	return link->global;
}

SPA_EXPORT
struct pw_impl_port *pw_impl_link_get_output(struct pw_impl_link *link)
{
	return link->output;
}

SPA_EXPORT
struct pw_impl_port *pw_impl_link_get_input(struct pw_impl_link *link)
{
	return link->input;
}
