/* PipeWire
 *
 * Copyright © 2020 Wim Taymans
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
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>

#include "config.h"

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include "extensions/session-manager.h"

#include "media-session.h"

#define NAME		"session-manager"
#define SESSION_KEY	"session-manager"

int sm_stream_endpoint_start(struct sm_media_session *sess);
int sm_v4l2_endpoint_start(struct sm_media_session *sess);
int sm_bluez5_endpoint_start(struct sm_media_session *sess);
int sm_alsa_endpoint_start(struct sm_media_session *sess);
int sm_policy_ep_start(struct sm_media_session *sess);

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;

	struct spa_hook proxy_client_session_listener;
	struct spa_hook client_session_listener;
};

/**
 * Session implementation
 */
static int client_session_set_param(void *object, uint32_t id, uint32_t flags,
			const struct spa_pod *param)
{
	struct impl *impl = object;
	pw_proxy_error((struct pw_proxy*)impl->session->client_session,
			-ENOTSUP, "Session:SetParam not supported");
	return -ENOTSUP;
}

static int client_session_link_set_param(void *object, uint32_t link_id, uint32_t id, uint32_t flags,
			const struct spa_pod *param)
{
	struct impl *impl = object;
	pw_proxy_error((struct pw_proxy*)impl->session->client_session,
			-ENOTSUP, "Session:LinkSetParam not supported");
	return -ENOTSUP;
}

static int client_session_link_request_state(void *object, uint32_t link_id, uint32_t state)
{
	return -ENOTSUP;
}

static const struct pw_client_session_events client_session_events = {
	PW_VERSION_CLIENT_SESSION_METHODS,
	.set_param = client_session_set_param,
	.link_set_param = client_session_link_set_param,
	.link_request_state = client_session_link_request_state,
};

static void proxy_client_session_bound(void *data, uint32_t id)
{
	struct impl *impl = data;
	struct pw_session_info info;

	impl->session->session_id = id;

	spa_zero(info);
	info.version = PW_VERSION_SESSION_INFO;
	info.id = id;

	pw_log_debug("got session id:%d", id);

	pw_client_session_update(impl->session->client_session,
			PW_CLIENT_SESSION_UPDATE_INFO,
			0, NULL,
			&info);

	/* start endpoints */
	sm_bluez5_endpoint_start(impl->session);
	sm_alsa_endpoint_start(impl->session);
	sm_v4l2_endpoint_start(impl->session);
	sm_stream_endpoint_start(impl->session);

	sm_policy_ep_start(impl->session);
}

static const struct pw_proxy_events proxy_client_session_events = {
	PW_VERSION_PROXY_EVENTS,
	.bound = proxy_client_session_bound,
};

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->listener);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.destroy = session_destroy,
};

int sm_session_manager_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;
	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	session->client_session = (struct pw_client_session *)
		sm_media_session_create_object(impl->session,
                                            "client-session",
                                            PW_TYPE_INTERFACE_ClientSession,
                                            PW_VERSION_CLIENT_SESSION,
                                            NULL, 0);

	pw_proxy_add_listener((struct pw_proxy*)session->client_session,
			&impl->proxy_client_session_listener,
			&proxy_client_session_events, impl);

	pw_client_session_add_listener(session->client_session,
			&impl->client_session_listener,
			&client_session_events, impl);

	return 0;
}
