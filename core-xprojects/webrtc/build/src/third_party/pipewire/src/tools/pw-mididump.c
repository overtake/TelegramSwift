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

#include <stdio.h>
#include <signal.h>
#include <math.h>
#include <getopt.h>

#include <spa/utils/result.h>
#include <spa/utils/defs.h>
#include <spa/control/control.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>

#include <pipewire/pipewire.h>
#include <pipewire/filter.h>

#include "midifile.h"

struct data;

struct port {
	struct data *data;
};

struct data {
	struct pw_main_loop *loop;
	const char *opt_remote;
	struct pw_filter *filter;
	struct port *in_port;
	int64_t clock_time;
};

static int dump_file(const char *filename)
{
	struct midi_file *file;
	struct midi_file_info info;
	struct midi_event ev;

	file = midi_file_open(filename, "r", &info);
	if (file == NULL) {
		fprintf(stderr, "error opening %s: %m\n", filename);
		return -1;
	}

	printf("opened %s\n", filename);

	while (midi_file_read_event(file, &ev) == 1) {
		midi_file_dump_event(stdout, &ev);
	}
	midi_file_close(file);

	return 0;
}

static void on_process(void *userdata, struct spa_io_position *position)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;
	struct spa_data *d;
	struct spa_pod *pod;
	struct spa_pod_control *c;
	uint64_t frame;

	frame = data->clock_time;
	data->clock_time += position->clock.duration;

	b = pw_filter_dequeue_buffer(data->in_port);
	if (b == NULL)
		return;

	buf = b->buffer;
	d = &buf->datas[0];

	if (d->data == NULL)
		return;

	if ((pod = spa_pod_from_data(d->data, d->maxsize, d->chunk->offset, d->chunk->size)) == NULL)
		return;
	if (!spa_pod_is_sequence(pod))
		return;

	SPA_POD_SEQUENCE_FOREACH((struct spa_pod_sequence*)pod, c) {
		struct midi_event ev;

		if (c->type != SPA_CONTROL_Midi)
			continue;

		ev.track = 0;
		ev.sec = (frame + c->offset) / (float) position->clock.rate.denom;
		ev.data = SPA_POD_BODY(&c->value),
		ev.size = SPA_POD_BODY_SIZE(&c->value);

		fprintf(stdout, "%4d: ", c->offset);
		midi_file_dump_event(stdout, &ev);
	}

	pw_filter_queue_buffer(data->in_port, b);
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

static int dump_filter(struct data *data)
{
	data->loop = pw_main_loop_new(NULL);
	if (data->loop == NULL)
		return -errno;

	pw_loop_add_signal(pw_main_loop_get_loop(data->loop), SIGINT, do_quit, data);
	pw_loop_add_signal(pw_main_loop_get_loop(data->loop), SIGTERM, do_quit, data);

	data->filter = pw_filter_new_simple(
			pw_main_loop_get_loop(data->loop),
			"midi-dump",
			pw_properties_new(
				PW_KEY_REMOTE_NAME, data->opt_remote,
				PW_KEY_MEDIA_TYPE, "Midi",
				PW_KEY_MEDIA_CATEGORY, "Filter",
				PW_KEY_MEDIA_ROLE, "DSP",
				NULL),
			&filter_events,
			data);

	data->in_port = pw_filter_add_port(data->filter,
			PW_DIRECTION_INPUT,
			PW_FILTER_PORT_FLAG_MAP_BUFFERS,
			sizeof(struct port),
			pw_properties_new(
				PW_KEY_FORMAT_DSP, "8 bit raw midi",
				PW_KEY_PORT_NAME, "input",
				NULL),
			NULL, 0);

	if (pw_filter_connect(data->filter, PW_FILTER_FLAG_RT_PROCESS, NULL, 0) < 0) {
		fprintf(stderr, "can't connect\n");
		return -1;
	}

	pw_main_loop_run(data->loop);

	pw_filter_destroy(data->filter);
	pw_main_loop_destroy(data->loop);

	return 0;
}

static void show_help(const char *name)
{
        fprintf(stdout, "%s [options] [FILE]\n"
		"  -h, --help                            Show this help\n"
		"      --version                         Show version\n"
		"  -r, --remote                          Remote daemon name\n",
		name);
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	int res = 0, c;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "remote",	required_argument,	NULL, 'r' },
		{ NULL,	0, NULL, 0}
	};

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVr:", long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			show_help(argv[0]);
			return 0;
		case 'V':
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				argv[0],
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;
		case 'r':
			data.opt_remote = optarg;
			break;
		default:
			show_help(argv[0]);
			return -1;
		}
	}

	if (optind < argc) {
		res = dump_file(argv[optind]);
	} else {
		res = dump_filter(&data);
	}
	pw_deinit();
	return res;
}
