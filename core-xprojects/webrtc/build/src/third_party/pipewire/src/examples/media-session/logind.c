/* PipeWire
 *
 * Copyright © 2021 Pauli Virtanen
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

/*
 * Monitor systemd-logind events for changes in session/seat status, and keep session
 * manager up-to-date on whether the current session is active.
 */

#include "config.h"

#include <sys/types.h>
#include <unistd.h>

#include <systemd/sd-login.h>

#include <spa/utils/result.h>
#include "pipewire/pipewire.h"

#include "media-session.h"

#define NAME		"logind"

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;
	struct pw_context *context;

	sd_login_monitor *monitor;
	struct spa_source source;
};

static void update_seat_active(struct impl *impl)
{
	char *state;
	bool active;

	if (sd_uid_get_state(getuid(), &state) < 0)
		return;

	active = strcmp(state, "active") == 0;
	free(state);

	sm_media_session_seat_active_changed(impl->session, active);
}

static void monitor_event(struct spa_source *source)
{
	struct impl *impl = source->data;
	sd_login_monitor_flush(impl->monitor);
	update_seat_active(impl);
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->listener);
	if (impl->monitor) {
		struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);
		pw_loop_remove_source(main_loop, &impl->source);
		sd_login_monitor_unref(impl->monitor);
		impl->monitor = NULL;
	}
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.destroy = session_destroy,
};

int sm_logind_start(struct sm_media_session *session)
{
	struct impl *impl;
	struct pw_loop *main_loop;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	if ((res = sd_login_monitor_new(NULL, &impl->monitor)) < 0)
		goto fail;

	main_loop = pw_context_get_main_loop(impl->context);

	impl->source.data = impl;
	impl->source.fd = sd_login_monitor_get_fd(impl->monitor);
	impl->source.func = monitor_event;
	impl->source.mask = sd_login_monitor_get_events(impl->monitor);
	impl->source.rmask = 0;
	pw_loop_add_source(main_loop, &impl->source);

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	update_seat_active(impl);

	return 0;

fail:
	pw_log_error(NAME ": failed to start systemd logind monitor: %d (%s)", res, spa_strerror(res));
	free(impl);
	return res;
}
