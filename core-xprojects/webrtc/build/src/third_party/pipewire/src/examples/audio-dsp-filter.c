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

#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <signal.h>

#include <pipewire/pipewire.h>
#include <pipewire/filter.h>

struct data;

struct port {
	struct data *data;
};

struct data {
	struct pw_main_loop *loop;
	struct pw_filter *filter;
	struct port *in_port;
	struct port *out_port;
};

/* our data processing function is in general:
 *
 *  struct pw_buffer *b;
 *  in = pw_filter_dequeue_buffer(filter, in_port);
 *  out = pw_filter_dequeue_buffer(filter, out_port);
 *
 *  .. do stuff with buffers ...
 *
 *  pw_filter_queue_buffer(filter, in_port, in);
 *  pw_filter_queue_buffer(filter, out_port, out);
 *
 *  For DSP ports, there is a shortcut to directly dequeue, get
 *  the data and requeue the buffer with pw_filter_get_dsp_buffer().
 *
 *
 */
static void on_process(void *userdata, struct spa_io_position *position)
{
	struct data *data = userdata;
	float *in, *out;
	uint32_t n_samples = position->clock.duration;

	pw_log_trace("do process %d", n_samples);

	in = pw_filter_get_dsp_buffer(data->in_port, n_samples);
	out = pw_filter_get_dsp_buffer(data->out_port, n_samples);

	memcpy(out, in, n_samples * sizeof(float));
}

static const struct pw_filter_events filter_events = {
	PW_VERSION_FILTER_EVENTS,
	.process = on_process,
};

static void do_quit(void *userdata, int signal_number)
{
	struct data *data = userdata;
	pw_main_loop_quit(data->loop);
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };

	pw_init(&argc, &argv);

	/* make a main loop. If you already have another main loop, you can add
	 * the fd of this pipewire mainloop to it. */
	data.loop = pw_main_loop_new(NULL);

	pw_loop_add_signal(pw_main_loop_get_loop(data.loop), SIGINT, do_quit, &data);
	pw_loop_add_signal(pw_main_loop_get_loop(data.loop), SIGTERM, do_quit, &data);

	/* Create a simple filter, the simple filter manages the core and remote
	 * objects for you if you don't need to deal with them.
	 *
	 * Pass your events and a user_data pointer as the last arguments. This
	 * will inform you about the filter state. The most important event
	 * you need to listen to is the process event where you need to process
	 * the data.
	 */
	data.filter = pw_filter_new_simple(
			pw_main_loop_get_loop(data.loop),
			"audio-filter",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Audio",
				PW_KEY_MEDIA_CATEGORY, "Filter",
				PW_KEY_MEDIA_ROLE, "DSP",
				NULL),
			&filter_events,
			&data);

	/* make an audio DSP input port */
	data.in_port = pw_filter_add_port(data.filter,
			PW_DIRECTION_INPUT,
			PW_FILTER_PORT_FLAG_MAP_BUFFERS,
			sizeof(struct port),
			pw_properties_new(
				PW_KEY_FORMAT_DSP, "32 bit float mono audio",
				PW_KEY_PORT_NAME, "input",
				NULL),
			NULL, 0);

	/* make an audio DSP output port */
	data.out_port = pw_filter_add_port(data.filter,
			PW_DIRECTION_OUTPUT,
			PW_FILTER_PORT_FLAG_MAP_BUFFERS,
			sizeof(struct port),
			pw_properties_new(
				PW_KEY_FORMAT_DSP, "32 bit float mono audio",
				PW_KEY_PORT_NAME, "output",
				NULL),
			NULL, 0);

	/* Now connect this filter. We ask that our process function is
	 * called in a realtime thread. */
	if (pw_filter_connect(data.filter,
				PW_FILTER_FLAG_RT_PROCESS,
				NULL, 0) < 0) {
		fprintf(stderr, "can't connect\n");
		return -1;
	}

	/* and wait while we let things run */
	pw_main_loop_run(data.loop);

	pw_filter_destroy(data.filter);
	pw_main_loop_destroy(data.loop);
	pw_deinit();

	return 0;
}
