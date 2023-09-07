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
#include <locale.h>
#include <ncurses.h>

#include <spa/utils/result.h>
#include <spa/pod/parser.h>
#include <spa/debug/pod.h>

#include <pipewire/impl.h>
#include <extensions/profiler.h>

#define MAX_NAME		128

struct driver {
	int64_t count;
	float cpu_load[3];
	struct spa_io_clock clock;
	uint32_t xrun_count;
};

struct measurement {
	int32_t index;
	int32_t status;
	int64_t quantum;
	int64_t prev_signal;
	int64_t signal;
	int64_t awake;
	int64_t finish;
	struct spa_fraction latency;
};

struct node {
	struct spa_list link;
	uint32_t id;
	char name[MAX_NAME];
	struct measurement measurement;
	struct driver info;
	struct node *driver;
	uint32_t errors;
	int32_t last_error_status;
};

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_proxy *profiler;
	struct spa_hook profiler_listener;
	int check_profiler;

	struct spa_source *timer;

	int n_nodes;
	struct spa_list node_list;

	WINDOW *win;
};

struct point {
	struct node *driver;
	struct driver info;
};

static int process_info(struct data *d, const struct spa_pod *pod, struct driver *info)
{
	return spa_pod_parse_struct(pod,
			SPA_POD_Long(&info->count),
			SPA_POD_Float(&info->cpu_load[0]),
			SPA_POD_Float(&info->cpu_load[1]),
			SPA_POD_Float(&info->cpu_load[2]),
			SPA_POD_Int(&info->xrun_count));
}

static int process_clock(struct data *d, const struct spa_pod *pod, struct driver *info)
{
	return spa_pod_parse_struct(pod,
			SPA_POD_Int(&info->clock.flags),
			SPA_POD_Int(&info->clock.id),
			SPA_POD_Stringn(info->clock.name, sizeof(info->clock.name)),
			SPA_POD_Long(&info->clock.nsec),
			SPA_POD_Fraction(&info->clock.rate),
			SPA_POD_Long(&info->clock.position),
			SPA_POD_Long(&info->clock.duration),
			SPA_POD_Long(&info->clock.delay),
			SPA_POD_Double(&info->clock.rate_diff),
			SPA_POD_Long(&info->clock.next_nsec));
}

static struct node *find_node(struct data *d, uint32_t id)
{
	struct node *n;
	spa_list_for_each(n, &d->node_list, link) {
		if (n->id == id)
			return n;
	}
	return NULL;
}

static struct node *add_node(struct data *d, uint32_t id, const char *name)
{
	struct node *n;

	if ((n = calloc(1, sizeof(*n))) == NULL)
		return NULL;

	if (name)
		strncpy(n->name, name, MAX_NAME-1);
	else
		snprintf(n->name, sizeof(n->name), "%u", id);
	n->id = id;
	n->driver = n;
	spa_list_append(&d->node_list, &n->link);
	d->n_nodes++;

	return n;
}

static void remove_node(struct data *d, struct node *n)
{
	spa_list_remove(&n->link);
	d->n_nodes--;
	free(n);
}

static int process_driver_block(struct data *d, const struct spa_pod *pod, struct point *point)
{
	char *name = NULL;
	uint32_t id = 0;
	struct measurement m;
	struct node *n;
	int res;

	spa_zero(m);
	if ((res = spa_pod_parse_struct(pod,
			SPA_POD_Int(&id),
			SPA_POD_String(&name),
			SPA_POD_Long(&m.prev_signal),
			SPA_POD_Long(&m.signal),
			SPA_POD_Long(&m.awake),
			SPA_POD_Long(&m.finish),
			SPA_POD_Int(&m.status),
			SPA_POD_Fraction(&m.latency))) < 0)
		return res;

	if ((n = find_node(d, id)) == NULL)
		return -ENOENT;

	n->driver = n;
	n->measurement = m;
	n->info = point->info;
	point->driver = n;

	if (m.status != 3) {
		n->errors++;
		if (n->last_error_status == -1)
			n->last_error_status = m.status;
	}
	return 0;
}

static int process_follower_block(struct data *d, const struct spa_pod *pod, struct point *point)
{
	uint32_t id = 0;
	const char *name =  NULL;
	struct measurement m;
	struct node *n;
	int res;

	spa_zero(m);
	if ((res = spa_pod_parse_struct(pod,
			SPA_POD_Int(&id),
			SPA_POD_String(&name),
			SPA_POD_Long(&m.prev_signal),
			SPA_POD_Long(&m.signal),
			SPA_POD_Long(&m.awake),
			SPA_POD_Long(&m.finish),
			SPA_POD_Int(&m.status),
			SPA_POD_Fraction(&m.latency))) < 0)
		return res;

	if ((n = find_node(d, id)) == NULL)
		return -ENOENT;

	n->measurement = m;
	n->driver = point->driver;
	if (m.status != 3) {
		n->errors++;
		if (n->last_error_status == -1)
			n->last_error_status = m.status;
	}
	return 0;
}

static const char *print_time(char *buf, size_t len, uint64_t val)
{
	if (val < 1000000llu)
		snprintf(buf, len, "%5.1fµs", val/1000.f);
	else if (val < 1000000000llu)
		snprintf(buf, len, "%5.1fms", val/1000000.f);
	else
		snprintf(buf, len, "%5.1fs", val/1000000000.f);
	return buf;
}

static const char *print_perc(char *buf, size_t len, float val, float quantum)
{
	snprintf(buf, len, "%5.2f", quantum == 0.0f ? 0.0f : val/quantum);
	return buf;
}

static void print_node(struct data *d, struct driver *i, struct node *n)
{
	char line[1024];
	char buf1[64];
	char buf2[64];
	char buf3[64];
	char buf4[64];
	float waiting, busy, quantum;
	struct spa_fraction frac;

	if (n->driver == n)
		frac = SPA_FRACTION((uint32_t)(i->clock.duration * i->clock.rate.num), i->clock.rate.denom);
	else
		frac = SPA_FRACTION(n->measurement.latency.num, n->measurement.latency.denom);

	if (i->clock.rate.denom)
		quantum = (float)i->clock.duration * i->clock.rate.num / (float)i->clock.rate.denom;
	else
		quantum = 0.0;

	waiting = (n->measurement.awake - n->measurement.signal) / 1000000000.f,
	busy = (n->measurement.finish - n->measurement.awake) / 1000000000.f,

	snprintf(line, sizeof(line), "%s %4.1u %6.1u %6.1u %s %s %s %s  %3.1u  %s%s",
			n->measurement.status != 3 ? "!" : " ",
			n->id,
			frac.num, frac.denom,
			print_time(buf1, 64, n->measurement.awake - n->measurement.signal),
			print_time(buf2, 64, n->measurement.finish - n->measurement.awake),
			print_perc(buf3, 64, waiting, quantum),
			print_perc(buf4, 64, busy, quantum),
			i->xrun_count + n->errors,
			n->driver == n ? "" : " + ",
			n->name);

	wprintw(d->win, "%.*s\n", COLS-1, line);
}

static void do_refresh(struct data *d)
{
	struct node *n, *t, *f;

	wclear(d->win);
	wattron(d->win, A_REVERSE);
	wprintw(d->win, "%-*.*s", COLS, COLS, "S   ID  QUANT   RATE    WAIT    BUSY   W/Q   B/Q  ERR  NAME ");
	wattroff(d->win, A_REVERSE);
	wprintw(d->win, "\n");

	spa_list_for_each_safe(n, t, &d->node_list, link) {
		if (n->driver != n)
			continue;

		print_node(d, &n->info, n);

		spa_list_for_each(f, &d->node_list, link) {
			if (f->driver != n || f == n)
				continue;

			print_node(d, &n->info, f);
		}
	}
	wrefresh(d->win);
}

static void do_timeout(void *data, uint64_t expirations)
{
	struct data *d = data;
	do_refresh(d);
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
				res = process_info(d, &p->value, &point.info);
				break;
			case SPA_PROFILER_clock:
				res = process_clock(d, &p->value, &point.info);
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

	if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		struct node *n;
		const char *str;

		if ((str = spa_dict_lookup(props, PW_KEY_NODE_NAME)) == NULL &&
			(str = spa_dict_lookup(props, PW_KEY_NODE_DESCRIPTION)) == NULL) {
				str = spa_dict_lookup(props, PW_KEY_APP_NAME);
		}

		if ((n = add_node(d, id, str)) == NULL) {
			pw_log_warn("can add node %u: %m", id);
		}
	} else if (strcmp(type, PW_TYPE_INTERFACE_Profiler) == 0) {
		if (d->profiler != NULL) {
			fprintf(stderr, "Ignoring profiler %d: already attached\n", id);
			return;
		}

		proxy = pw_registry_bind(d->registry, id, type, PW_VERSION_PROFILER, 0);
		if (proxy == NULL)
			goto error_proxy;

		d->profiler = proxy;
		pw_proxy_add_object_listener(proxy, &d->profiler_listener, &profiler_events, d);
	}

	return;

error_proxy:
	pw_log_error("failed to create proxy: %m");
	return;
}

static void registry_event_global_remove(void *data, uint32_t id)
{
	struct data *d = data;
	struct node *n;
	if ((n = find_node(d, id)) != NULL)
		remove_node(d, n);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
	.global_remove = registry_event_global_remove,
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
		} else
			do_refresh(d);
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
		"  -r, --remote                          Remote daemon name\n",
		name);
}

static void terminal_start()
{
	initscr();
	cbreak();
	noecho();
	refresh();
}

static void terminal_stop()
{
	endwin();
}

static void do_handle_io(void *data, int fd, uint32_t mask)
{
	struct data *d = data;

	if (mask & SPA_IO_IN) {
		int ch = getch();

		switch(ch) {
		case 'q':
			pw_main_loop_quit(d->loop);
			break;
		default:
			do_refresh(d);
			break;
		}
	}
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	struct pw_loop *l;
	const char *opt_remote = NULL;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "remote",	required_argument,	NULL, 'r' },
		{ NULL, 0, NULL, 0}
	};
	int c;
	struct timespec value, interval;
	struct node *n;

	setlocale(LC_ALL, "");
	pw_init(&argc, &argv);

	spa_list_init(&data.node_list);

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

	pw_core_add_listener(data.core,
				   &data.core_listener,
				   &core_events, &data);
	data.registry = pw_core_get_registry(data.core,
					  PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(data.registry,
				       &data.registry_listener,
				       &registry_events, &data);

	data.check_profiler = pw_core_sync(data.core, 0, 0);

	terminal_start();

	data.win = newwin(LINES, COLS, 0, 0);

	data.timer = pw_loop_add_timer(l, do_timeout, &data);
	value.tv_sec = 1;
	value.tv_nsec = 0;
	interval.tv_sec = 1;
	interval.tv_nsec = 0;
	pw_loop_update_timer(l, data.timer, &value, &interval, false);

	pw_loop_add_io(l, fileno(stdin), SPA_IO_IN, false, do_handle_io, &data);

	pw_main_loop_run(data.loop);

	terminal_stop();

	spa_list_consume(n, &data.node_list, link)
		remove_node(&data, n);

	pw_proxy_destroy((struct pw_proxy*)data.profiler);
	pw_proxy_destroy((struct pw_proxy*)data.registry);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	pw_deinit();

	return 0;
}
