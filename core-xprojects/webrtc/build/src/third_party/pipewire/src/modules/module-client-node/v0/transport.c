/* PipeWire
 *
 * Copyright © 2016 Wim Taymans <wim.taymans@gmail.com>
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

#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>

#include <spa/utils/ringbuffer.h>
#include <spa/node/io.h>

#include <pipewire/impl.h>
#include <pipewire/private.h>

#include "ext-client-node.h"

#include "transport.h"

/** \cond */

#define INPUT_BUFFER_SIZE       (1<<12)
#define OUTPUT_BUFFER_SIZE      (1<<12)

struct transport {
	struct pw_client_node0_transport trans;

	struct pw_memblock *mem;
	size_t offset;

	struct pw_client_node0_message current;
	uint32_t current_index;
};
/** \endcond */

static size_t area_get_size(struct pw_client_node0_area *area)
{
	size_t size;
	size = sizeof(struct pw_client_node0_area);
	size += area->max_input_ports * sizeof(struct spa_io_buffers);
	size += area->max_output_ports * sizeof(struct spa_io_buffers);
	size += sizeof(struct spa_ringbuffer);
	size += INPUT_BUFFER_SIZE;
	size += sizeof(struct spa_ringbuffer);
	size += OUTPUT_BUFFER_SIZE;
	return size;
}

static void transport_setup_area(void *p, struct pw_client_node0_transport *trans)
{
	struct pw_client_node0_area *a;

	trans->area = a = p;
	p = SPA_MEMBER(p, sizeof(struct pw_client_node0_area), struct spa_io_buffers);

	trans->inputs = p;
	p = SPA_MEMBER(p, a->max_input_ports * sizeof(struct spa_io_buffers), void);

	trans->outputs = p;
	p = SPA_MEMBER(p, a->max_output_ports * sizeof(struct spa_io_buffers), void);

	trans->input_buffer = p;
	p = SPA_MEMBER(p, sizeof(struct spa_ringbuffer), void);

	trans->input_data = p;
	p = SPA_MEMBER(p, INPUT_BUFFER_SIZE, void);

	trans->output_buffer = p;
	p = SPA_MEMBER(p, sizeof(struct spa_ringbuffer), void);

	trans->output_data = p;
	p = SPA_MEMBER(p, OUTPUT_BUFFER_SIZE, void);
}

static void transport_reset_area(struct pw_client_node0_transport *trans)
{
	uint32_t i;
	struct pw_client_node0_area *a = trans->area;

	for (i = 0; i < a->max_input_ports; i++) {
		trans->inputs[i] = SPA_IO_BUFFERS_INIT;
	}
	for (i = 0; i < a->max_output_ports; i++) {
		trans->outputs[i] = SPA_IO_BUFFERS_INIT;
	}
	spa_ringbuffer_init(trans->input_buffer);
	spa_ringbuffer_init(trans->output_buffer);
}

static void destroy(struct pw_client_node0_transport *trans)
{
	struct transport *impl = (struct transport *) trans;

	pw_log_debug("transport %p: destroy", trans);

	pw_memblock_free(impl->mem);
	free(impl);
}

static int add_message(struct pw_client_node0_transport *trans, struct pw_client_node0_message *message)
{
	struct transport *impl = (struct transport *) trans;
	int32_t filled, avail;
	uint32_t size, index;

	if (impl == NULL || message == NULL)
		return -EINVAL;

	filled = spa_ringbuffer_get_write_index(trans->output_buffer, &index);
	avail = OUTPUT_BUFFER_SIZE - filled;
	size = SPA_POD_SIZE(message);
	if (avail < (int)size)
		return -ENOSPC;

	spa_ringbuffer_write_data(trans->output_buffer,
				  trans->output_data, OUTPUT_BUFFER_SIZE,
				  index & (OUTPUT_BUFFER_SIZE - 1), message, size);
	spa_ringbuffer_write_update(trans->output_buffer, index + size);

	return 0;
}

static int next_message(struct pw_client_node0_transport *trans, struct pw_client_node0_message *message)
{
	struct transport *impl = (struct transport *) trans;
	int32_t avail;

	if (impl == NULL || message == NULL)
		return -EINVAL;

	avail = spa_ringbuffer_get_read_index(trans->input_buffer, &impl->current_index);
	if (avail < (int) sizeof(struct pw_client_node0_message))
		return 0;

	spa_ringbuffer_read_data(trans->input_buffer,
				 trans->input_data, INPUT_BUFFER_SIZE,
				 impl->current_index & (INPUT_BUFFER_SIZE - 1),
				 &impl->current, sizeof(struct pw_client_node0_message));

	if (avail < (int) SPA_POD_SIZE(&impl->current))
		return 0;

	*message = impl->current;

	return 1;
}

static int parse_message(struct pw_client_node0_transport *trans, void *message)
{
	struct transport *impl = (struct transport *) trans;
	uint32_t size;

	if (impl == NULL || message == NULL)
		return -EINVAL;

	size = SPA_POD_SIZE(&impl->current);

	spa_ringbuffer_read_data(trans->input_buffer,
				 trans->input_data, INPUT_BUFFER_SIZE,
				 impl->current_index & (INPUT_BUFFER_SIZE - 1), message, size);
	spa_ringbuffer_read_update(trans->input_buffer, impl->current_index + size);

	return 0;
}

/** Create a new transport
 * \param max_input_ports maximum number of input_ports
 * \param max_output_ports maximum number of output_ports
 * \return a newly allocated \ref pw_client_node0_transport
 * \memberof pw_client_node0_transport
 */
struct pw_client_node0_transport *
pw_client_node0_transport_new(struct pw_context *context,
		uint32_t max_input_ports, uint32_t max_output_ports)
{
	struct transport *impl;
	struct pw_client_node0_transport *trans;
	struct pw_client_node0_area area = { 0 };

	area.max_input_ports = max_input_ports;
	area.n_input_ports = 0;
	area.max_output_ports = max_output_ports;
	area.n_output_ports = 0;

	impl = calloc(1, sizeof(struct transport));
	if (impl == NULL)
		return NULL;

	pw_log_debug("transport %p: new %d %d", impl, max_input_ports, max_output_ports);

	trans = &impl->trans;
	impl->offset = 0;

	impl->mem = pw_mempool_alloc(context->pool,
			PW_MEMBLOCK_FLAG_READWRITE |
			PW_MEMBLOCK_FLAG_MAP |
			PW_MEMBLOCK_FLAG_SEAL,
			SPA_DATA_MemFd, area_get_size(&area));
	if (impl->mem == NULL) {
		free(impl);
		return NULL;
	}

	memcpy(impl->mem->map->ptr, &area, sizeof(struct pw_client_node0_area));
	transport_setup_area(impl->mem->map->ptr, trans);
	transport_reset_area(trans);

	trans->destroy = destroy;
	trans->add_message = add_message;
	trans->next_message = next_message;
	trans->parse_message = parse_message;

	return trans;
}

struct pw_client_node0_transport *
pw_client_node0_transport_new_from_info(struct pw_client_node0_transport_info *info)
{
	errno = ENOTSUP;
	return NULL;
}

/** Get transport info
 * \param trans the transport to get info of
 * \param[out] info transport info
 * \return 0 on success
 *
 * Fill \a info with the transport info of \a trans. This information can be
 * passed to the client to set up the shared transport.
 *
 * \memberof pw_client_node0_transport
 */
int pw_client_node0_transport_get_info(struct pw_client_node0_transport *trans,
				      struct pw_client_node0_transport_info *info)
{
	struct transport *impl = (struct transport *) trans;

	info->memfd = impl->mem->fd;
	info->offset = impl->offset;
	info->size = impl->mem->size;

	return 0;
}
