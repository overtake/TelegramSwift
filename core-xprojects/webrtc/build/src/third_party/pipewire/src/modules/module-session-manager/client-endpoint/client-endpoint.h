/* PipeWire
 *
 * Copyright © 2019 Collabora Ltd.
 *   @author George Kiagiadakis <george.kiagiadakis@collabora.com>
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

#ifndef MODULE_SESSION_MANAGER_CLIENT_ENDPOINT_H
#define MODULE_SESSION_MANAGER_CLIENT_ENDPOINT_H

#include "endpoint.h"

#ifdef __cplusplus
extern "C" {
#endif

struct client_endpoint {
	struct pw_resource *resource;
	struct spa_hook resource_listener;
	struct spa_hook object_listener;
	struct endpoint endpoint;
	struct spa_list streams;
};

#define pw_client_endpoint_resource(r,m,v,...)	\
	pw_resource_call_res(r,struct pw_client_endpoint_events,m,v,__VA_ARGS__)
#define pw_client_endpoint_resource_set_id(r,...)	\
	pw_client_endpoint_resource(r,set_id,0,__VA_ARGS__)
#define pw_client_endpoint_resource_set_session_id(r,...)	\
	pw_client_endpoint_resource(r,set_session_id,0,__VA_ARGS__)
#define pw_client_endpoint_resource_set_param(r,...)	\
	pw_client_endpoint_resource(r,set_param,0,__VA_ARGS__)
#define pw_client_endpoint_resource_stream_set_param(r,...)	\
	pw_client_endpoint_resource(r,stream_set_param,0,__VA_ARGS__)
#define pw_client_endpoint_resource_create_link(r,...)	\
	pw_client_endpoint_resource(r,create_link,0,__VA_ARGS__)

int client_endpoint_factory_init(struct pw_impl_module *module);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* MODULE_SESSION_MANAGER_CLIENT_ENDPOINT_H */
