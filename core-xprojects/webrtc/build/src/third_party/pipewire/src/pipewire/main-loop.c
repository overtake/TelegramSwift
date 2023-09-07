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

#include "pipewire/log.h"
#include "pipewire/main-loop.h"
#include "pipewire/private.h"

#define NAME "main-loop"

static void do_stop(void *data, uint64_t count)
{
	struct pw_main_loop *this = data;
	pw_log_debug(NAME" %p: do stop", this);
	this->running = false;
}

static struct pw_main_loop *loop_new(struct pw_loop *loop, const struct spa_dict *props)
{
	struct pw_main_loop *this;
	int res;

	this = calloc(1, sizeof(struct pw_main_loop));
	if (this == NULL) {
		res = -errno;
		goto error_cleanup;
	}

	pw_log_debug(NAME" %p: new", this);

	if (loop == NULL) {
		loop = pw_loop_new(props);
		this->created = true;
	}
	if (loop == NULL) {
		res = -errno;
		goto error_free;
	}
	this->loop = loop;

        this->event = pw_loop_add_event(this->loop, do_stop, this);
	if (this->event == NULL) {
		res = -errno;
		goto error_free_loop;
	}

	spa_hook_list_init(&this->listener_list);

	return this;

error_free_loop:
	if (this->created && this->loop)
		pw_loop_destroy(this->loop);
error_free:
	free(this);
error_cleanup:
	errno = -res;
	return NULL;
}

/** Create a new main loop
 * \return a newly allocated \ref pw_main_loop
 *
 * \memberof pw_main_loop
 */
SPA_EXPORT
struct pw_main_loop *pw_main_loop_new(const struct spa_dict *props)
{
	return loop_new(NULL, props);
}

/** Destroy a main loop
 * \param loop the main loop to destroy
 *
 * \memberof pw_main_loop
 */
SPA_EXPORT
void pw_main_loop_destroy(struct pw_main_loop *loop)
{
	pw_log_debug(NAME" %p: destroy", loop);
	pw_main_loop_emit_destroy(loop);

	if (loop->created)
		pw_loop_destroy(loop->loop);

	spa_hook_list_clean(&loop->listener_list);

	free(loop);
}

SPA_EXPORT
void pw_main_loop_add_listener(struct pw_main_loop *loop,
			       struct spa_hook *listener,
			       const struct pw_main_loop_events *events,
			       void *data)
{
	spa_hook_list_append(&loop->listener_list, listener, events, data);
}

SPA_EXPORT
struct pw_loop * pw_main_loop_get_loop(struct pw_main_loop *loop)
{
	return loop->loop;
}

/** Stop a main loop
 * \param loop a \ref pw_main_loop to stop
 *
 * The call to \ref pw_main_loop_run() will return
 *
 * \memberof pw_main_loop
 */
SPA_EXPORT
int pw_main_loop_quit(struct pw_main_loop *loop)
{
	pw_log_debug(NAME" %p: quit", loop);
	return pw_loop_signal_event(loop->loop, loop->event);
}

/** Start a main loop
 * \param loop the main loop to start
 *
 * Start running \a loop. This function blocks until \ref pw_main_loop_quit()
 * has been called
 *
 * \memberof pw_main_loop
 */
SPA_EXPORT
int pw_main_loop_run(struct pw_main_loop *loop)
{
	int res = 0;

	pw_log_debug(NAME" %p: run", loop);

	loop->running = true;
	pw_loop_enter(loop->loop);
	while (loop->running) {
		if ((res = pw_loop_iterate(loop->loop, -1)) < 0) {
			if (res == -EINTR)
				continue;
			pw_log_warn(NAME" %p: iterate error %d (%s)",
					loop, res, spa_strerror(res));
		}
	}
	pw_loop_leave(loop->loop);
	return res;
}
