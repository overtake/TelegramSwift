/* Spa JACK Client
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

#ifndef SPA_JACK_CLIENT_H
#define SPA_JACK_CLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <spa/utils/defs.h>
#include <spa/utils/hook.h>
#include <spa/support/log.h>

#include <jack/jack.h>

struct spa_jack_client_events {
#define SPA_VERSION_JACK_CLIENT_EVENTS	0
	uint32_t version;

	void (*destroy) (void *data);

	void (*process) (void *data);

	void (*shutdown) (void *data);
};

struct spa_jack_client {
	struct spa_log *log;

	jack_client_t *client;

	jack_nframes_t frame_rate;
	jack_nframes_t buffer_size;
	jack_nframes_t current_frames;
	jack_time_t current_usecs;
	jack_time_t next_usecs;
	float period_usecs;
	jack_position_t pos;

	struct spa_hook_list listener_list;
};

#define spa_jack_client_emit(c,m,v,...)		spa_hook_list_call(&(c)->listener_list, \
							struct spa_jack_client_events,	\
							m, v, ##__VA_ARGS__)
#define spa_jack_client_emit_destroy(c)		spa_jack_client_emit(c, destroy, 0)
#define spa_jack_client_emit_process(c)		spa_jack_client_emit(c, process, 0)
#define spa_jack_client_emit_shutdown(c)	spa_jack_client_emit(c, shutdown, 0)

#define spa_jack_client_add_listener(c,listener,events,data) \
        spa_hook_list_append(&(c)->listener_list, listener, events, data)

int spa_jack_client_open(struct spa_jack_client *client,
		const char *client_name, const char *server_name);
int spa_jack_client_close(struct spa_jack_client *client);


#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* SPA_JACK_CLIENT_H */
