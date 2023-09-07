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
#include <getopt.h>

#include <spa/utils/result.h>
#include <spa/pod/parser.h>
#include <spa/debug/pod.h>

#include <pipewire/impl.h>
#include <extensions/profiler.h>

#define MAX_NAME		128
#define MAX_FOLLOWERS		64
#define DEFAULT_FILENAME	"profiler.log"

struct follower {
	uint32_t id;
	char name[MAX_NAME];
};

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	const char *filename;
	FILE *output;

	int64_t count;
	int64_t start_status;
	int64_t last_status;

	struct pw_proxy *profiler;
	struct spa_hook profiler_listener;
	int check_profiler;

	uint32_t driver_id;

	int n_followers;
	struct follower followers[MAX_FOLLOWERS];
};

struct measurement {
	int64_t period;
	int64_t prev_signal;
	int64_t signal;
	int64_t awake;
	int64_t finish;
	int32_t status;
};

struct point {
	int64_t count;
	float cpu_load[3];
	struct spa_io_clock clock;
	struct measurement driver;
	struct measurement follower[MAX_FOLLOWERS];
};

static int process_info(struct data *d, const struct spa_pod *pod, struct point *point)
{
	return spa_pod_parse_struct(pod,
			SPA_POD_Long(&point->count),
			SPA_POD_Float(&point->cpu_load[0]),
			SPA_POD_Float(&point->cpu_load[1]),
			SPA_POD_Float(&point->cpu_load[2]));
}

static int process_clock(struct data *d, const struct spa_pod *pod, struct point *point)
{
	return spa_pod_parse_struct(pod,
			SPA_POD_Int(&point->clock.flags),
			SPA_POD_Int(&point->clock.id),
			SPA_POD_Stringn(point->clock.name, sizeof(point->clock.name)),
			SPA_POD_Long(&point->clock.nsec),
			SPA_POD_Fraction(&point->clock.rate),
			SPA_POD_Long(&point->clock.position),
			SPA_POD_Long(&point->clock.duration),
			SPA_POD_Long(&point->clock.delay),
			SPA_POD_Double(&point->clock.rate_diff),
			SPA_POD_Long(&point->clock.next_nsec));
}

static int process_driver_block(struct data *d, const struct spa_pod *pod, struct point *point)
{
	char *name = NULL;
	uint32_t driver_id = 0;
	struct measurement driver;
	int res;

	spa_zero(driver);
	if ((res = spa_pod_parse_struct(pod,
			SPA_POD_Int(&driver_id),
			SPA_POD_String(&name),
			SPA_POD_Long(&driver.prev_signal),
			SPA_POD_Long(&driver.signal),
			SPA_POD_Long(&driver.awake),
			SPA_POD_Long(&driver.finish),
			SPA_POD_Int(&driver.status))) < 0)
		return res;

	if (d->driver_id == 0) {
		d->driver_id = driver_id;
		fprintf(stderr, "logging driver %u\n", driver_id);
	}
	else if (d->driver_id != driver_id)
		return -1;

	point->driver = driver;
	return 0;
}

static int find_follower(struct data *d, uint32_t id, const char *name)
{
	int i;
	for (i = 0; i < d->n_followers; i++) {
		if (d->followers[i].id == id && strcmp(d->followers[i].name, name) == 0)
			return i;
	}
	return -1;
}

static int add_follower(struct data *d, uint32_t id, const char *name)
{
	int idx = d->n_followers;

	if (idx == MAX_FOLLOWERS)
		return -1;

	d->n_followers++;

	strncpy(d->followers[idx].name, name, MAX_NAME);
	d->followers[idx].name[MAX_NAME-1] = '\0';
	d->followers[idx].id = id;
	fprintf(stderr, "logging follower %u (\"%s\")\n", id, name);

	return idx;
}

static int process_follower_block(struct data *d, const struct spa_pod *pod, struct point *point)
{
	uint32_t id = 0;
	const char *name =  NULL;
	struct measurement m;
	int res, idx;

	spa_zero(m);
	if ((res = spa_pod_parse_struct(pod,
			SPA_POD_Int(&id),
			SPA_POD_String(&name),
			SPA_POD_Long(&m.prev_signal),
			SPA_POD_Long(&m.signal),
			SPA_POD_Long(&m.awake),
			SPA_POD_Long(&m.finish),
			SPA_POD_Int(&m.status))) < 0)
		return res;

	if ((idx = find_follower(d, id, name)) < 0) {
		if ((idx = add_follower(d, id, name)) < 0) {
			pw_log_warn("too many followers");
			return -ENOSPC;
		}
	}
	point->follower[idx] = m;
	return 0;
}

static void dump_point(struct data *d, struct point *point)
{
	int i;
	int64_t d1, d2;
	int64_t delay, period_usecs;

#define CLOCK_AS_USEC(cl,val) (val * (float)SPA_USEC_PER_SEC / (cl)->rate.denom)
#define CLOCK_AS_SUSEC(cl,val) (val * (float)SPA_USEC_PER_SEC / ((cl)->rate.denom * (cl)->rate_diff))

	delay = CLOCK_AS_USEC(&point->clock, point->clock.delay);
	period_usecs = CLOCK_AS_SUSEC(&point->clock, point->clock.duration);

	d1 = (point->driver.signal - point->driver.prev_signal) / 1000;
	d2 = (point->driver.finish - point->driver.signal) / 1000;

	if (d1 > period_usecs * 1.3 ||
	    d2 > period_usecs * 1.3)
		d1 = d2 = period_usecs * 1.4;

	/* 4 columns for the driver */
	fprintf(d->output, "%"PRIi64"\t%"PRIi64"\t%"PRIi64"\t%"PRIi64"\t",
			d1 > 0 ? d1 : 0, d2 > 0 ? d2 : 0, delay, period_usecs);

	for (i = 0; i < MAX_FOLLOWERS; i++) {
		/* 8 columns for each follower */
		if (point->follower[i].status == 0) {
			fprintf(d->output, " \t \t \t \t \t \t \t \t");
		} else {
			int64_t d4 = (point->follower[i].signal - point->driver.signal) / 1000;
			int64_t d5 = (point->follower[i].awake - point->driver.signal) / 1000;
			int64_t d6 = (point->follower[i].finish - point->driver.signal) / 1000;

			fprintf(d->output, "%u\t%"PRIi64"\t%"PRIi64"\t%"PRIi64"\t%"PRIi64"\t%"PRIi64"\t%d\t0\t",
					d->followers[i].id,
					d4 > 0 ? d4 : 0,
					d5 > 0 ? d5 : 0,
					d6 > 0 ? d6 : 0,
					(d5 > 0 && d4 > 0 && d5 > d4) ? d5 - d4 : 0,
					(d6 > 0 && d5 > 0 && d6 > d5) ? d6 - d5 : 0,
					point->follower[i].status);
		}
	}
	fprintf(d->output, "\n");
	if (d->count == 0) {
		d->start_status = point->clock.nsec;
		d->last_status = point->clock.nsec;
	}
	else if (point->clock.nsec - d->last_status > SPA_NSEC_PER_SEC) {
		fprintf(stderr, "logging %"PRIi64" samples  %"PRIi64" seconds [CPU %f %f %f]\r",
				d->count, (int64_t) ((d->last_status - d->start_status) / SPA_NSEC_PER_SEC),
				point->cpu_load[0], point->cpu_load[1], point->cpu_load[2]);
		d->last_status = point->clock.nsec;
	}
	d->count++;
}

static void dump_scripts(struct data *d)
{
	FILE *out;
	int i;

	if (d->driver_id == 0)
		return;

	fprintf(stderr, "\ndumping scripts for %d followers\n", d->n_followers);

	out = fopen("Timing1.plot", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timing1.plot: %m");
	} else {
		fprintf(out,
			"set output 'Timing1.svg\n"
			"set terminal svg\n"
			"set multiplot\n"
			"set grid\n"
			"set title \"Audio driver timing\"\n"
			"set xlabel \"audio cycles\"\n"
			"set ylabel \"usec\"\n"
			"plot \"%1$s\" using 3 title \"Audio driver delay\" with lines, "
			"\"%1$s\" using 1 title \"Audio period\" with lines,"
			"\"%1$s\" using 4 title \"Audio estimated\" with lines\n"
			"unset multiplot\n"
			"unset output\n", d->filename);
		fclose(out);
	}

	out = fopen("Timing2.plot", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timing2.plot: %m");
	} else {
		fprintf(out,
			"set output 'Timing2.svg\n"
			"set terminal svg\n"
			"set grid\n"
			"set title \"Driver end date\"\n"
			"set xlabel \"audio cycles\"\n"
			"set ylabel \"usec\"\n"
			"plot  \"%s\" using 2 title \"Driver end date\" with lines \n"
			"unset output\n", d->filename);
		fclose(out);
	}

	out = fopen("Timing3.plot", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timing3.plot: %m");
	} else {
		fprintf(out,
			"set output 'Timing3.svg\n"
			"set terminal svg\n"
			"set multiplot\n"
			"set grid\n"
			"set title \"Clients end date\"\n"
			"set xlabel \"audio cycles\"\n"
			"set ylabel \"usec\"\n"
			"plot "
			"\"%s\" using 1 title \"Audio period\" with lines%s",
				d->filename,
				d->n_followers > 0 ? ", " : "");

		for (i = 0; i < d->n_followers; i++) {
			fprintf(out,
				"\"%s\" using %d title \"%s/%u\" with lines%s",
					d->filename, 4 + (i * 8) + 4,
					d->followers[i].name, d->followers[i].id,
					i+1 < d->n_followers ? ", " : "");
		}
		fprintf(out,
			"\nunset multiplot\n"
			"unset output\n");
		fclose(out);
	}

	out = fopen("Timing4.plot", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timing4.plot: %m");
	} else {
		fprintf(out,
			"set output 'Timing4.svg\n"
			"set terminal svg\n"
			"set multiplot\n"
			"set grid\n"
			"set title \"Clients scheduling latency\"\n"
			"set xlabel \"audio cycles\"\n"
			"set ylabel \"usec\"\n"
			"plot ");

		for (i = 0; i < d->n_followers; i++) {
			fprintf(out,
				"\"%s\" using %d title \"%s/%u\" with lines%s",
					d->filename, 4 + (i * 8) + 5,
					d->followers[i].name, d->followers[i].id,
					i+1 < d->n_followers ? ", " : "");
		}
		fprintf(out,
			"\nunset multiplot\n"
			"unset output\n");
		fclose(out);
	}

	out = fopen("Timing5.plot", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timing5.plot: %m");
	} else {
		fprintf(out,
			"set output 'Timing5.svg\n"
			"set terminal svg\n"
			"set multiplot\n"
			"set grid\n"
			"set title \"Clients duration\"\n"
			"set xlabel \"audio cycles\"\n"
			"set ylabel \"usec\"\n"
			"plot ");

		for (i = 0; i < d->n_followers; i++) {
			fprintf(out,
				"\"%s\" using %d title \"%s/%u\" with lines%s",
					d->filename, 4 + (i * 8) + 6,
					d->followers[i].name, d->followers[i].id,
					i+1 < d->n_followers ? ", " : "");
		}
		fprintf(out,
			"\nunset multiplot\n"
			"unset output\n");
		fclose(out);
	}
	out = fopen("Timings.html", "w");
	if (out == NULL) {
		pw_log_error("Can't open Timings.html: %m");
	} else {
		fprintf(out,
			"<?xml version='1.0' encoding='utf-8'?>\n"
			"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n"
			"\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
			"<html xmlns='http://www.w3.org/1999/xhtml' lang='en'>\n"
			"  <head>\n"
			"    <title>PipeWire profiling</title>\n"
			"    <!-- assuming that images are 600px wide -->\n"
			"    <style media='all' type='text/css'>\n"
			"    .center { margin-left:auto ; margin-right: auto; width: 650px; height: 550px }\n"
			"    </style>\n"
			"  </head>\n"
			"  <body>\n"
			"    <h2 style='text-align:center'>PipeWire profiling</h2>\n"
			"    <div class='center'><object class='center' type='image/svg+xml' data='Timing1.svg'>Timing1</object></div>"
			"    <div class='center'><object class='center' type='image/svg+xml' data='Timing2.svg'>Timing2</object></div>"
			"    <div class='center'><object class='center' type='image/svg+xml' data='Timing3.svg'>Timing3</object></div>"
			"    <div class='center'><object class='center' type='image/svg+xml' data='Timing4.svg'>Timing4</object></div>"
			"    <div class='center'><object class='center' type='image/svg+xml' data='Timing5.svg'>Timing5</object></div>"
			"  </body>\n"
			"</html>\n");
		fclose(out);
	}

	out = fopen("generate_timings.sh", "w");
	if (out == NULL) {
		pw_log_error("Can't open generate_timings.sh: %m");
	} else {
		fprintf(out,
			"gnuplot Timing1.plot\n"
			"gnuplot Timing2.plot\n"
			"gnuplot Timing3.plot\n"
			"gnuplot Timing4.plot\n"
			"gnuplot Timing5.plot\n");
		fclose(out);
	}
	fprintf(stderr, "run 'sh generate_timings.sh' and load Timings.html in a browser\n");
}

static void profiler_profile(void *data, const struct spa_pod *pod)
{
        struct data *d = data;
	struct spa_pod *o;
	struct spa_pod_prop *p;
	struct point point;

	SPA_POD_STRUCT_FOREACH(pod, o) {
		int res = 0;
		if (!spa_pod_is_object_type(o, SPA_TYPE_OBJECT_Profiler))
			continue;

		spa_zero(point);
		SPA_POD_OBJECT_FOREACH((struct spa_pod_object*)o, p) {
			switch(p->key) {
			case SPA_PROFILER_info:
				res = process_info(d, &p->value, &point);
				break;
			case SPA_PROFILER_clock:
				res = process_clock(d, &p->value, &point);
				break;
			case SPA_PROFILER_driverBlock:
				res = process_driver_block(d, &p->value, &point);
				break;
			case SPA_PROFILER_followerBlock:
				process_follower_block(d, &p->value, &point);
				break;
			default:
				break;
			}
			if (res < 0)
				break;
		}
		if (res < 0)
			continue;

		dump_point(d, &point);
	}
}

static const struct pw_profiler_events profiler_events = {
	PW_VERSION_PROFILER_EVENTS,
        .profile = profiler_profile,
};

static void registry_event_global(void *data, uint32_t id,
				  uint32_t permissions, const char *type, uint32_t version,
				  const struct spa_dict *props)
{
	struct data *d = data;
	struct pw_proxy *proxy;

	if (strcmp(type, PW_TYPE_INTERFACE_Profiler) != 0)
		return;

	if (d->profiler != NULL) {
		fprintf(stderr, "Ignoring profiler %d: already attached\n", id);
		return;
	}

	proxy = pw_registry_bind(d->registry, id, type, PW_VERSION_PROFILER, 0);
	if (proxy == NULL)
		goto error_proxy;

	fprintf(stderr, "Attaching to Profiler id:%d\n", id);
	d->profiler = proxy;
	pw_proxy_add_object_listener(proxy, &d->profiler_listener, &profiler_events, d);

	return;

error_proxy:
	pw_log_error("failed to create proxy: %m");
	return;
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
};

static void on_core_error(void *_data, uint32_t id, int seq, int res, const char *message)
{
	struct data *data = _data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE)
		pw_main_loop_quit(data->loop);
}

static void on_core_done(void *_data, uint32_t id, int seq)
{
	struct data *d = _data;

	if (seq == d->check_profiler) {
		if (d->profiler == NULL) {
			pw_log_error("no Profiler Interface found, please load one in the server");
			pw_main_loop_quit(d->loop);
		}
	}
}


static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
	.done = on_core_done,
};

static void do_quit(void *data, int signal_number)
{
	struct data *d = data;
	pw_main_loop_quit(d->loop);
}

static void show_help(const char *name)
{
        fprintf(stdout, "%s [options]\n"
		"  -h, --help                            Show this help\n"
		"      --version                         Show version\n"
		"  -r, --remote                          Remote daemon name\n"
		"  -o, --output                          Profiler output name (default \"%s\")\n",
		name,
		DEFAULT_FILENAME);
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	struct pw_loop *l;
	const char *opt_remote = NULL;
	const char *opt_output = DEFAULT_FILENAME;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "remote",	required_argument,	NULL, 'r' },
		{ "output",	required_argument,	NULL, 'o' },
		{ NULL, 0, NULL, 0}
	};
	int c;

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVr:o:", long_options, NULL)) != -1) {
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
		case 'o':
			opt_output = optarg;
			break;
		case 'r':
			opt_remote = optarg;
			break;
		default:
			show_help(argv[0]);
			return -1;
		}
	}

	data.loop = pw_main_loop_new(NULL);
	if (data.loop == NULL) {
		fprintf(stderr, "Can't create data loop: %m\n");
		return -1;
	}

	l = pw_main_loop_get_loop(data.loop);
	pw_loop_add_signal(l, SIGINT, do_quit, &data);
	pw_loop_add_signal(l, SIGTERM, do_quit, &data);

	data.context = pw_context_new(l, NULL, 0);
	if (data.context == NULL) {
		fprintf(stderr, "Can't create context: %m\n");
		return -1;
	}

	pw_context_load_module(data.context, PW_EXTENSION_MODULE_PROFILER, NULL, NULL);

	data.core = pw_context_connect(data.context,
			pw_properties_new(
				PW_KEY_REMOTE_NAME, opt_remote,
				NULL),
			0);
	if (data.core == NULL) {
		fprintf(stderr, "Can't connect: %m\n");
		return -1;
	}

	data.filename = opt_output;

	data.output = fopen(data.filename, "w");
	if (data.output == NULL) {
		fprintf(stderr, "Can't open file %s: %m\n", data.filename);
		return -1;
	}

	fprintf(stderr, "Logging to %s\n", data.filename);

	pw_core_add_listener(data.core,
				   &data.core_listener,
				   &core_events, &data);
	data.registry = pw_core_get_registry(data.core,
					  PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(data.registry,
				       &data.registry_listener,
				       &registry_events, &data);

	data.check_profiler = pw_core_sync(data.core, 0, 0);

	pw_main_loop_run(data.loop);

	pw_proxy_destroy((struct pw_proxy*)data.profiler);
	pw_proxy_destroy((struct pw_proxy*)data.registry);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	fclose(data.output);

	dump_scripts(&data);

	pw_deinit();

	return 0;
}
