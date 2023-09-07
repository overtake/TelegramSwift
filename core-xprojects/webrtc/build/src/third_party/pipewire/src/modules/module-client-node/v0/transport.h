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

#ifndef __PIPEWIRE_CLIENT_NODE0_TRANSPORT_H__
#define __PIPEWIRE_CLIENT_NODE0_TRANSPORT_H__

#ifdef __cplusplus
extern "C" {
#endif

#include <string.h>

#include <spa/utils/defs.h>

#include <pipewire/mem.h>

/** information about the transport region \memberof pw_client_node */
struct pw_client_node0_transport_info {
	int memfd;		/**< the memfd of the transport area */
	uint32_t offset;	/**< offset to map \a memfd at */
	uint32_t size;		/**< size of memfd mapping */
};

struct pw_client_node0_transport *
pw_client_node0_transport_new(struct pw_context *context, uint32_t max_input_ports, uint32_t max_output_ports);

struct pw_client_node0_transport *
pw_client_node0_transport_new_from_info(struct pw_client_node0_transport_info *info);

int
pw_client_node0_transport_get_info(struct pw_client_node0_transport *trans,
				  struct pw_client_node0_transport_info *info);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* __PIPEWIRE_CLIENT_NODE0_TRANSPORT_H__ */
