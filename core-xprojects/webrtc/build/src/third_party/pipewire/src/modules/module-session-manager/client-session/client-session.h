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

#ifndef MODULE_SESSION_MANAGER_CLIENT_SESSION_H
#define MODULE_SESSION_MANAGER_CLIENT_SESSION_H

#include "session.h"

#ifdef __cplusplus
extern "C" {
#endif

struct client_session {
	struct pw_resource *resource;
	struct spa_hook resource_listener;
	struct spa_hook object_listener;
	struct session session;
	struct spa_list links;
};

#define pw_client_session_resource(r,m,v,...)	\
	pw_resource_call_res(r,struct pw_client_session_events,m,v,__VA_ARGS__)
#define pw_client_session_resource_set_id(r,...)	\
	pw_client_session_resource(r,set_id,0,__VA_ARGS__)
#define pw_client_session_resource_set_param(r,...)	\
	pw_client_session_resource(r,set_param,0,__VA_ARGS__)
#define pw_client_session_resource_link_set_param(r,...)	\
	pw_client_session_resource(r,link_set_param,0,__VA_ARGS__)
#define pw_client_session_resource_create_link(r,...)	\
	pw_client_session_resource(r,create_link,0,__VA_ARGS__)
#define pw_client_session_resource_destroy_link(r,...)	\
	pw_client_session_resource(r,destroy_link,0,__VA_ARGS__)
#define pw_client_session_resource_link_request_state(r,...)	\
	pw_client_session_resource(r,link_request_state,0,__VA_ARGS__)

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* MODULE_SESSION_MANAGER_CLIENT_SESSION_H */
