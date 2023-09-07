/* PipeWire
 *
 * Copyright © 2019 Wim Taymans
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
#include <unistd.h>
#include <errno.h>
#include <limits.h>
#include <sys/inotify.h>

#include "config.h"

#include <spa/utils/names.h>
#include <spa/utils/result.h>
#include <spa/node/keys.h>

#include "pipewire/pipewire.h"

#include "media-session.h"

#define SND_PATH "/dev/snd"
#define SEQ_NAME "seq"
#define SND_SEQ_PATH SND_PATH"/"SEQ_NAME

#define DEFAULT_NAME	"Midi-Bridge"

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_properties *props;
	struct pw_proxy *proxy;

	struct spa_source *notify;
};

static int do_create(struct impl *impl)
{
	impl->proxy = sm_media_session_create_object(impl->session,
				"spa-node-factory",
				PW_TYPE_INTERFACE_Node,
				PW_VERSION_NODE,
				&impl->props->dict,
                                0);
	if (impl->proxy == NULL)
		return -errno;

	return 0;
}

static int check_access(struct impl *impl)
{
	return access(SND_SEQ_PATH, R_OK|W_OK) >= 0;
}

static void stop_inotify(struct impl *impl)
{
	struct pw_loop *main_loop = impl->session->loop;
	if (impl->notify != NULL) {
		pw_log_info("stop inotify");
		pw_loop_destroy_source(main_loop, impl->notify);
		impl->notify = NULL;
	}
}

static void on_notify_events(void *data, int fd, uint32_t mask)
{
	struct impl *impl = data;
	bool remove = false;
	struct {
		struct inotify_event e;
		char name[NAME_MAX+1];
	} buf;

	while (true) {
		ssize_t len;
		const struct inotify_event *event;
		void *p, *e;

		len = read(fd, &buf, sizeof(buf));
		if (len < 0 && errno != EAGAIN)
			break;
		if (len <= 0)
			break;

		e = SPA_MEMBER(&buf, len, void);

		for (p = &buf; p < e;
		p = SPA_MEMBER(p, sizeof(struct inotify_event) + event->len, void)) {
			event = (const struct inotify_event *) p;

			if ((event->mask & IN_ATTRIB)) {
				if (strncmp(event->name, SEQ_NAME, event->len) != 0)
					continue;
				if (impl->proxy == NULL &&
				    check_access(impl) &&
				    do_create(impl) >= 0)
					remove = true;
			}
			if ((event->mask & (IN_DELETE_SELF | IN_MOVE_SELF)))
				remove = true;
		}
	}
	if (remove)
		stop_inotify(impl);
}

static int start_inotify(struct impl *impl)
{
	int notify_fd, res;
	struct pw_loop *main_loop = impl->session->loop;

	if ((notify_fd = inotify_init1(IN_CLOEXEC | IN_NONBLOCK)) < 0)
		return -errno;

	res = inotify_add_watch(notify_fd, SND_PATH,
				IN_ATTRIB | IN_CLOSE_WRITE | IN_DELETE_SELF | IN_MOVE_SELF);
	if (res < 0) {
		res = -errno;
		close(notify_fd);
		pw_log_error("inotify_add_watch() '%s' failed: %s",
				SND_PATH, spa_strerror(res));
		return res;
	}
	pw_log_info("start inotify");

	impl->notify = pw_loop_add_io(main_loop, notify_fd, SPA_IO_IN | SPA_IO_ERR,
			true, on_notify_events, impl);
	return 0;
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->listener);
	if (impl->proxy)
		pw_proxy_destroy(impl->proxy);
	stop_inotify(impl);
	pw_properties_free(impl->props);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.destroy = session_destroy,
};

int sm_alsa_midi_start(struct sm_media_session *session)
{
	struct impl *impl;
	int res;
	const char *name;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	if ((name = pw_properties_get(session->props, "alsa.seq.name")) == NULL)
		name = DEFAULT_NAME;

	impl->session = session;
	impl->props = pw_properties_new(
			SPA_KEY_FACTORY_NAME, SPA_NAME_API_ALSA_SEQ_BRIDGE,
			SPA_KEY_NODE_NAME, name,
			NULL);
	if (impl->props == NULL) {
		res = -errno;
		goto cleanup;
	}

	sm_media_session_add_listener(session, &impl->listener, &session_events, impl);

	if (check_access(impl)) {
		res = do_create(impl);
	} else {
		res = start_inotify(impl);
	}
	if (res < 0)
		goto cleanup_props;

	return 0;

cleanup_props:
	pw_properties_free(impl->props);
cleanup:
	free(impl);
	return res;
}
