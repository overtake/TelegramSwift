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

#ifndef MODULE_SESSION_MANAGER_ENDPOINT_LINK_H
#define MODULE_SESSION_MANAGER_ENDPOINT_LINK_H

#ifdef __cplusplus
extern "C" {
#endif

struct client_session;

struct endpoint_link {
	struct spa_list link;
	struct client_session *client_sess;
	struct pw_global *global;
	uint32_t id;			/* session-local link id */
	uint32_t n_params;
	struct spa_pod **params;
	struct pw_endpoint_link_info info;
	struct pw_properties *props;	/* wrapper of info.props */
};

int endpoint_link_init(struct endpoint_link *this,
		uint32_t id, uint32_t session_id,
		struct client_session *client_sess,
		struct pw_context *context,
		struct pw_properties *properties);

void endpoint_link_clear(struct endpoint_link *this);

int endpoint_link_update(struct endpoint_link *this,
			uint32_t change_mask,
			uint32_t n_params,
			const struct spa_pod **params,
			const struct pw_endpoint_link_info *info);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* MODULE_SESSION_MANAGER_ENDPOINT_LINK_H */
