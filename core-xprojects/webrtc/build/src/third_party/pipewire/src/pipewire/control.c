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

#include <spa/pod/parser.h>
#include <spa/debug/types.h>

#include <pipewire/control.h>
#include <pipewire/private.h>

#define NAME "control"

struct impl {
	struct pw_control this;

	struct pw_memblock *mem;
};

struct pw_control *
pw_control_new(struct pw_context *context,
	       struct pw_impl_port *port,
	       uint32_t id, uint32_t size,
	       size_t user_data_size)
{
	struct impl *impl;
	struct pw_control *this;
	enum spa_direction direction;

	switch (id) {
	case SPA_IO_Control:
		direction = SPA_DIRECTION_INPUT;
		break;
	case SPA_IO_Notify:
		direction = SPA_DIRECTION_OUTPUT;
		break;
	default:
		errno = ENOTSUP;
		goto error_exit;
	}

	impl = calloc(1, sizeof(struct impl) + user_data_size);
	if (impl == NULL)
		goto error_exit;

	this = &impl->this;
	this->id = id;
	this->size = size;

	pw_log_debug(NAME" %p: new %s %d", this,
			spa_debug_type_find_name(spa_type_io, this->id), direction);

	this->context = context;
	this->port = port;
	this->direction = direction;

	spa_list_init(&this->links);

        if (user_data_size > 0)
		this->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	spa_hook_list_init(&this->listener_list);

	spa_list_append(&context->control_list[direction], &this->link);
	if (port) {
		spa_list_append(&port->control_list[direction], &this->port_link);
		pw_impl_port_emit_control_added(port, this);
	}
	return this;

error_exit:
	return NULL;
}

void pw_control_destroy(struct pw_control *control)
{
	struct impl *impl = SPA_CONTAINER_OF(control, struct impl, this);
	struct pw_control_link *link;

	pw_log_debug(NAME" %p: destroy", control);

	pw_control_emit_destroy(control);

	if (control->direction == SPA_DIRECTION_OUTPUT) {
		spa_list_consume(link, &control->links, out_link)
			pw_control_remove_link(link);
	}
	else {
		spa_list_consume(link, &control->links, in_link)
			pw_control_remove_link(link);
	}

	spa_list_remove(&control->link);

	if (control->port) {
		spa_list_remove(&control->port_link);
		pw_impl_port_emit_control_removed(control->port, control);
	}

	pw_log_debug(NAME" %p: free", control);
	pw_control_emit_free(control);

	spa_hook_list_clean(&control->listener_list);

	if (control->direction == SPA_DIRECTION_OUTPUT) {
		if (impl->mem)
			pw_memblock_unref(impl->mem);
	}
	free(control);
}

SPA_EXPORT
struct pw_impl_port *pw_control_get_port(struct pw_control *control)
{
	return control->port;
}

SPA_EXPORT
void pw_control_add_listener(struct pw_control *control,
			     struct spa_hook *listener,
			     const struct pw_control_events *events,
			     void *data)
{
	spa_hook_list_append(&control->listener_list, listener, events, data);
}

static int port_set_io(struct pw_impl_port *port, uint32_t mix, uint32_t id, void *data, uint32_t size)
{
	int res;

	if (port->mix) {
		res = spa_node_port_set_io(port->mix, port->direction, mix, id, data, size);
		if (SPA_RESULT_IS_OK(res))
			return res;
	}

	if ((res = spa_node_port_set_io(port->node->node,
			port->direction, port->port_id,
			id, data, size)) < 0) {
		pw_log_warn("port %p: set io failed %d %s", port,
			res, spa_strerror(res));
	}
	return res;
}

SPA_EXPORT
int pw_control_add_link(struct pw_control *control, uint32_t cmix,
		struct pw_control *other, uint32_t omix,
		struct pw_control_link *link)
{
	int res = 0;
	struct impl *impl;
	uint32_t size;

	if (control->direction == SPA_DIRECTION_INPUT) {
		SPA_SWAP(control, other);
		SPA_SWAP(cmix, omix);
	}
	if (control->direction != SPA_DIRECTION_OUTPUT ||
	    other->direction != SPA_DIRECTION_INPUT)
		return -EINVAL;

	impl = SPA_CONTAINER_OF(control, struct impl, this);

	pw_log_debug(NAME" %p: link to %p %s", control, other,
			spa_debug_type_find_name(spa_type_io, control->id));

	size = SPA_MAX(control->size, other->size);

	if (impl->mem == NULL) {
		impl->mem = pw_mempool_alloc(control->context->pool,
						PW_MEMBLOCK_FLAG_READWRITE |
						PW_MEMBLOCK_FLAG_SEAL |
						PW_MEMBLOCK_FLAG_MAP,
						SPA_DATA_MemFd, size);
		if (impl->mem == NULL) {
			res = -errno;
			goto exit;
		}
	}

	if (spa_list_is_empty(&control->links)) {
		if (control->port) {
			if ((res = port_set_io(control->port, cmix,
						control->id,
						impl->mem->map->ptr, size)) < 0) {
				pw_log_warn(NAME" %p: set io failed %d %s", control,
					res, spa_strerror(res));
				goto exit;
			}
		}
	}

	if (other->port) {
		if ((res = port_set_io(other->port, omix,
				other->id, impl->mem->map->ptr, size)) < 0) {
			pw_log_warn(NAME" %p: set io failed %d %s", control,
					res, spa_strerror(res));
			goto exit;
		}
	}

	link->output = control;
	link->input = other;
	link->out_port = cmix;
	link->in_port = omix;
	link->valid = true;
	spa_list_append(&control->links, &link->out_link);
	spa_list_append(&other->links, &link->in_link);

	pw_control_emit_linked(control, other);
	pw_control_emit_linked(other, control);
exit:
	return res;
}

SPA_EXPORT
int pw_control_remove_link(struct pw_control_link *link)
{
	int res = 0;
	struct pw_control *output = link->output;
	struct pw_control *input = link->input;

	pw_log_debug(NAME" %p: unlink from %p", output, input);

	spa_list_remove(&link->in_link);
	spa_list_remove(&link->out_link);
	link->valid = false;

	if (spa_list_is_empty(&output->links)) {
		if ((res = port_set_io(output->port, link->out_port,
					output->id, NULL, 0)) < 0) {
			pw_log_warn(NAME" %p: can't unset port control io", output);
		}
	}

	if (input->port) {
		if ((res = port_set_io(input->port, link->in_port,
				     input->id, NULL, 0)) < 0) {
			pw_log_warn(NAME" %p: can't unset port control io", output);
		}
	}

	pw_control_emit_unlinked(output, input);
	pw_control_emit_unlinked(input, output);

	return res;
}
