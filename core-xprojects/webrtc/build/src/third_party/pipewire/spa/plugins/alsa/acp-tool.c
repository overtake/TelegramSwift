/* ALSA card profile test
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
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <stdbool.h>
#include <getopt.h>

#include <acp/acp.h>

#define WHITESPACE	"\n\r\t "

struct data {
	int verbose;
	int card_index;
	char *properties;
	struct acp_card *card;
	bool quit;
};

static void acp_debug_dict(struct acp_dict *dict, int indent)
{
	const struct acp_dict_item *it;
	fprintf(stderr, "%*sproperties: (%d)\n", indent, "", dict->n_items);
	acp_dict_for_each(it, dict) {
		fprintf(stderr, "%*s%s = \"%s\"\n", indent+4, "", it->key, it->value);
	}
}

static char *split_walk(char *str, const char *delimiter, size_t *len, char **state)
{
	char *s = *state ? *state : str;

	if (*s == '\0')
		return NULL;

	*len = strcspn(s, delimiter);
	*state = s + *len;
	*state += strspn(*state, delimiter);
	return s;
}

static int split_ip(char *str, const char *delimiter, int max_tokens, char *tokens[])
{
	char *state = NULL, *s;
	size_t len;
	int n = 0;

	while (true) {
		if ((s = split_walk(str, delimiter, &len, &state)) == NULL)
			break;
		tokens[n++] = s;
		if (n >= max_tokens)
			break;
		s[len] = '\0';
	}
	return n;
}


static void card_props_changed(void *data)
{
	struct data *d = data;
	struct acp_card *card = d->card;
	fprintf(stderr, "*** properties changed:\n");
	acp_debug_dict(&card->props, 4);
	fprintf(stderr, "***\n");
}

static void card_profile_changed(void *data, uint32_t old_index, uint32_t new_index)
{
	struct data *d = data;
	struct acp_card *card = d->card;
	struct acp_card_profile *op = card->profiles[old_index];
	struct acp_card_profile *np = card->profiles[new_index];
	fprintf(stderr, "*** profile changed from %s to %s\n", op->name, np->name);
}

static void card_profile_available(void *data, uint32_t index,
		enum acp_available old, enum acp_available available)
{
	struct data *d = data;
	struct acp_card *card = d->card;
	struct acp_card_profile *p = card->profiles[index];
	fprintf(stderr, "*** profile %s available %s\n", p->name, acp_available_str(available));
}

static void card_port_available(void *data, uint32_t index,
		enum acp_available old, enum acp_available available)
{
	struct data *d = data;
	struct acp_card *card = d->card;
	struct acp_port *p = card->ports[index];
	fprintf(stderr, "*** port %s available %s\n", p->name, acp_available_str(available));
}

static void on_volume_changed(void *data, struct acp_device *dev)
{
	float vol;
	acp_device_get_volume(dev, &vol, 1);
	fprintf(stderr, "*** volume %s changed to %f\n", dev->name, vol);
}

static void on_mute_changed(void *data, struct acp_device *dev)
{
	bool mute;
	acp_device_get_mute(dev, &mute);
	fprintf(stderr, "*** mute %s changed to %d\n", dev->name, mute);
}

struct acp_card_events card_events = {
	ACP_VERSION_CARD_EVENTS,
        .props_changed = card_props_changed,
        .profile_changed = card_profile_changed,
        .profile_available = card_profile_available,
        .port_available = card_port_available,
	.volume_changed = on_volume_changed,
	.mute_changed = on_mute_changed,
};

static ACP_PRINTF_FUNC(6,0) void log_func(void *data,
		int level, const char *file, int line, const char *func,
		const char *fmt, va_list arg)
{
	vfprintf(stderr, fmt, arg);
	fprintf(stderr, "\n");
}

static void show_prompt(struct data *data)
{
	fprintf(stderr, ">>>");
}

struct command {
        const char *name;
        const char *args;
        const char *alias;
        const char *description;
        int (*func) (struct data *data, const struct command *cmd, int argc, char *argv[]);
	void *extra;
};

static int cmd_help(struct data *data, const struct command *cmd, int argc, char *argv[]);

static int cmd_quit(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	data->quit = true;
	return 0;
}

static void print_profile(struct data *data, struct acp_card_profile *p, int indent, int level);
static void print_device(struct data *data, struct acp_device *d, int indent, int level);

static void print_port(struct data *data, struct acp_port *p, int indent, int level)
{
	uint32_t i;

	fprintf(stderr, "%*s  %c port %u: name:\"%s\" direction:%s prio:%d (available: %s)\n",
			indent, "", p->flags & ACP_PORT_ACTIVE ? '*' : ' ', p->index,
			p->name, acp_direction_str(p->direction), p->priority,
			acp_available_str(p->available));
	if (level > 0) {
		acp_debug_dict(&p->props, indent + 8);
	}
	if (level > 1) {
		fprintf(stderr, "%*sprofiles: (%d)\n", indent+8, "", p->n_profiles);
		for (i = 0; i < p->n_profiles; i++) {
			struct acp_card_profile *pr = p->profiles[i];
			print_profile(data, pr, indent + 8, 0);
		}
		fprintf(stderr, "%*sdevices: (%d)\n", indent+8, "", p->n_devices);
		for (i = 0; i < p->n_devices; i++) {
			struct acp_device *d = p->devices[i];
			print_device(data, d, indent + 8, 0);
		}
	}
}

static void print_device(struct data *data, struct acp_device *d, int indent, int level)
{
	const char **s;
	uint32_t i;

	fprintf(stderr, "%*s  %c device %u: direction:%s name:\"%s\" prio:%d flags:%08x devices: ",
			indent, "", d->flags & ACP_DEVICE_ACTIVE ? '*' : ' ', d->index,
			acp_direction_str(d->direction), d->name, d->priority, d->flags);
	for (s = d->device_strings; *s; s++)
		fprintf(stderr, "\"%s\" ", *s);
	fprintf(stderr, "\n");
	if (level > 0) {
		fprintf(stderr, "%*srate:%d channels:%d\n", indent+8, "",
				d->format.rate_mask, d->format.channels);
		acp_debug_dict(&d->props, indent + 8);
	}
	if (level > 1) {
		fprintf(stderr, "%*sports: (%d)\n", indent+8, "", d->n_ports);
		for (i = 0; i < d->n_ports; i++) {
			struct acp_port *p = d->ports[i];
			print_port(data, p, indent + 8, 0);
		}
	}
}

static void print_profile(struct data *data, struct acp_card_profile *p, int indent, int level)
{
	uint32_t i;

	fprintf(stderr, "%*s  %c profile %u: name:\"%s\" prio:%d (available: %s)\n",
			indent, "", p->flags & ACP_PROFILE_ACTIVE ? '*' : ' ', p->index,
			p->name, p->priority, acp_available_str(p->available));
	if (level > 0) {
		fprintf(stderr, "%*sdescription:\"%s\"\n",
				indent+8, "", p->description);
	}
	if (level > 1) {
		fprintf(stderr, "%*sdevices: (%d)\n", indent+8, "", p->n_devices);
		for (i = 0; i < p->n_devices; i++) {
			struct acp_device *d = p->devices[i];
			print_device(data, d, indent + 8, 0);
		}
	}
}

static void print_card(struct data *data, struct acp_card *card, int indent, int level)
{
	fprintf(stderr, "%*scard %d: profiles:%d devices:%d ports:%d\n", indent, "",
			card->index, card->n_profiles, card->n_devices, card->n_ports);
	if (level > 0) {
		acp_debug_dict(&card->props, 4);
	}
}

static int cmd_info(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	print_card(data, card, 0, 2);
	return 0;
}

static int cmd_card(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	if (argc < 2) {
		fprintf(stderr, "arguments: <card_index> missing\n");
		return -EINVAL;
	}
	return 0;
}

static int cmd_list(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t i;
	int level = 0;

	if (!strcmp(cmd->name, "list-verbose"))
		level = 2;

	print_card(data, card, 0, level);
	for (i = 0; i < card->n_profiles; i++)
		print_profile(data, card->profiles[i], 0, level);

	for (i = 0; i < card->n_ports; i++)
		print_port(data, card->ports[i], 0, level);

	for (i = 0; i < card->n_devices; i++)
		print_device(data, card->devices[i], 0, level);

	return 0;
}

static int cmd_list_profiles(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	uint32_t i;
	struct acp_card *card = data->card;

	if (argc > 1) {
		i = atoi(argv[1]);
		if (i >= card->n_profiles)
			return -EINVAL;
		print_profile(data, card->profiles[i], 0, 2);
	} else {
		for (i = 0; i < card->n_profiles; i++)
			print_profile(data, card->profiles[i], 0, 0);
	}
	return 0;
}

static int cmd_set_profile(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t index;

	if (argc > 1)
		index = atoi(argv[1]);
	else
		index = card->active_profile_index;

	return acp_card_set_profile(card, index, 0);
}

static int cmd_list_ports(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	uint32_t i;
	struct acp_card *card = data->card;

	if (argc > 1) {
		i = atoi(argv[1]);
		if (i >= card->n_ports)
			return -EINVAL;
		print_port(data, card->ports[i], 0, 2);
	} else {
		for (i = 0; i < card->n_ports; i++)
			print_port(data, card->ports[i], 0, 0);
	}
	return 0;
}

static int cmd_set_port(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id, port_id;

	if (argc < 3) {
		fprintf(stderr, "arguments: <device_id> <port_id> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	port_id = atoi(argv[2]);

	if (dev_id >= card->n_devices)
		return -EINVAL;

	return acp_device_set_port(card->devices[dev_id], port_id, 0);
}

static int cmd_list_devices(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	uint32_t i;
	struct acp_card *card = data->card;

	if (argc > 1) {
		i = atoi(argv[1]);
		if (i >= card->n_devices)
			return -EINVAL;
		print_device(data, card->devices[i], 0, 2);
	} else {
		for (i = 0; i < card->n_devices; i++)
			print_device(data, card->devices[i], 0, 0);
	}
	return 0;
}

static int cmd_get_volume(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	float vol;

	if (argc < 2) {
		fprintf(stderr, "arguments: <device_id> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	if (dev_id >= card->n_devices)
		return -EINVAL;

	acp_device_get_volume(card->devices[dev_id], &vol, 1);

	fprintf(stderr, "volume: %f\n", vol);
	return 0;
}

static int cmd_set_volume(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	float vol;

	if (argc < 3) {
		fprintf(stderr, "arguments: <device_id> <volume> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	vol = atof(argv[2]);

	if (dev_id >= card->n_devices)
		return -EINVAL;

	return acp_device_set_volume(card->devices[dev_id], &vol, 1);
}

static int adjust_volume(struct data *data, const struct command *cmd, int argc, char *argv[], float adjust)
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	float vol;

	if (argc < 2) {
		fprintf(stderr, "arguments: <device_id> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	if (dev_id >= card->n_devices)
		return -EINVAL;
	acp_device_get_volume(card->devices[dev_id], &vol, 1);
	vol += adjust;
	acp_device_set_volume(card->devices[dev_id], &vol, 1);
	fprintf(stderr, "volume: %f\n", vol);
	return 0;
}

static int cmd_inc_volume(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	return adjust_volume(data, cmd, argc, argv, 0.2);
}

static int cmd_dec_volume(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	return adjust_volume(data, cmd, argc, argv, -0.2);
}

static int cmd_get_mute(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	bool mute;

	if (argc < 2) {
		fprintf(stderr, "arguments: <device_id> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	if (dev_id >= card->n_devices)
		return -EINVAL;

	acp_device_get_mute(card->devices[dev_id], &mute);

	fprintf(stderr, "muted: %s\n", mute ? "yes" : "no");
	return 0;
}

static int cmd_set_mute(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	bool mute;

	if (argc < 3) {
		fprintf(stderr, "arguments: <device_id> <mute> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	mute = atoi(argv[2]);
	if (dev_id >= card->n_devices)
		return -EINVAL;

	acp_device_set_mute(card->devices[dev_id], mute);
	fprintf(stderr, "muted: %s\n", mute ? "yes" : "no");
	return 0;
}

static int cmd_toggle_mute(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	struct acp_card *card = data->card;
	uint32_t dev_id;
	bool mute;

	if (argc < 2) {
		fprintf(stderr, "arguments: <device_id> missing\n");
		return -EINVAL;
	}
	dev_id = atoi(argv[1]);
	if (dev_id >= card->n_devices)
		return -EINVAL;
	acp_device_get_mute(card->devices[dev_id], &mute);
	mute = !mute;
	acp_device_set_mute(card->devices[dev_id], mute);
	fprintf(stderr, "muted: %s\n", mute ? "yes" : "no");
	return 0;
}

static const struct command command_list[] = {
	{ "help",          "",           "h",   "Show available commands", cmd_help },
	{ "quit",          "",           "q",   "Quit", cmd_quit },
	{ "card",          "<id>",       "c",   "Probe card", cmd_card },
	{ "info",          "",           "i",   "List card info", cmd_info },
	{ "list",          "",           "l",   "List all objects", cmd_list },
	{ "list-verbose",  "",           "lv",  "List all data", cmd_list },
	{ "list-profiles", "[id]",       "lpr", "List profiles", cmd_list_profiles },
	{ "set-profile",   "<id>",       "spr", "Activate a profile", cmd_set_profile },
	{ "list-ports",    "[id]",       "lp",  "List ports", cmd_list_ports },
	{ "set-port",      "<id>",       "sp",  "Activate a port", cmd_set_port },
	{ "list-devices",  "[id]",       "ld",  "List available devices", cmd_list_devices },
	{ "get-volume",    "<id>",       "gv",  "Get volume from device", cmd_get_volume },
	{ "set-volume",    "<id> <vol>", "v",   "Set volume on device", cmd_set_volume },
	{ "inc-volume",    "<id>",       "v+",  "Increase volume on device", cmd_inc_volume },
	{ "dec-volume",    "<id>",       "v-",  "Decrease volume on device", cmd_dec_volume },
	{ "get-mute",      "<id>",       "gm",  "Get mute state from device", cmd_get_mute },
	{ "set-mute",      "<id> <val>", "sm",  "Set mute on device", cmd_set_mute },
	{ "toggle-mute",   "<id>",       "m",   "Toggle mute on device", cmd_toggle_mute },
};
#define N_COMMANDS	sizeof(command_list)/sizeof(command_list[0])

static const struct command *find_command(struct data *data, const char *cmd)
{
	size_t i;
	for (i = 0; i < N_COMMANDS; i++) {
		if (!strcmp(command_list[i].name, cmd) ||
		    !strcmp(command_list[i].alias, cmd))
			return &command_list[i];
	}
	return NULL;
}

static int cmd_help(struct data *data, const struct command *cmd, int argc, char *argv[])
{
	size_t i;
	fprintf(stderr, "Available commands:\n");
	for (i = 0; i < N_COMMANDS; i++) {
		fprintf(stdout, "\t%-15.15s %-10.10s\t%s (%s)\n",
				command_list[i].name,
				command_list[i].args,
				command_list[i].description,
				command_list[i].alias);
	}
	return 0;
}

static int run_command(struct data *data, int argc, char *argv[64])
{
	const struct command *command;
	int res;

	command = find_command(data, argv[0]);
	if (command == NULL) {
		fprintf(stderr, "unknown command %s\n", argv[0]);
		cmd_help(data, NULL, argc, argv);
		res = -EINVAL;
	} else if (command->func) {
		res = command->func(data, command, argc, argv);
		if (res < 0) {
			fprintf(stderr, "error: %s\n", strerror(-res));
		}
	} else {
		res = -ENOTSUP;
	}
	return res;
}

static int handle_input(struct data *data)
{
	char buf[4096] = { 0, }, *p, *argv[64];
	ssize_t r;
	int res, argc;

	if ((r = read(STDIN_FILENO, buf, sizeof(buf)-1)) < 0)
		return -errno;
	buf[r] = 0;

	if ((p = strchr(buf, '#')))
                *p = '\0';

	argc = split_ip(buf, WHITESPACE, 64, argv);
	if (argc < 1)
		return -EINVAL;

	res = run_command(data, argc, argv);

	if (!data->quit)
		show_prompt(data);

	return res;
}

static int do_probe(struct data *data)
{
	uint32_t n_items = 0;
	struct acp_dict_item items[64];
	struct acp_dict props;

	acp_set_log_func(log_func, data);
	acp_set_log_level(data->verbose);

	items[n_items++] = ACP_DICT_ITEM_INIT("use-ucm", "true");
	items[n_items++] = ACP_DICT_ITEM_INIT("verbose", data->verbose ? "true" : "false");
	if (data->properties != NULL) {
		char *p = data->properties, *e, f;

		while (*p) {
			const char *k, *v;

			if ((e = strchr(p, '=')) == NULL)
				break;
			*e = '\0';
			k = p;
			p = e+1;

			if (*p == '\"') {
				p++;
				f = '\"';
			} else {
				f = ' ';
			}
			if ((e = strchr(p, f)) == NULL &&
			    (e = strchr(p, '\0')) == NULL)
				break;
			*e = '\0';
			v = p;
			p = e+1;
			items[n_items++] = ACP_DICT_ITEM_INIT(k, v);
			if (n_items == 64)
				break;
		}
	}
	props = ACP_DICT_INIT(items, n_items);

	data->card = acp_card_new(data->card_index, &props);
	if (data->card == NULL)
		return -errno;
	return 0;
}

static int do_prompt(struct data *data)
{
	struct pollfd *pfds;
	int err, count;

	acp_card_add_listener(data->card, &card_events, data);

	count = acp_card_poll_descriptors_count(data->card);
	if (count == 0)
		fprintf(stderr, "card has no events\n");

	count++;
	pfds = alloca(sizeof(struct pollfd) * count);
	pfds[0].fd = STDIN_FILENO;
	pfds[0].events = POLLIN;

	print_card(data, data->card, 0, 0);

	fprintf(stderr, "type 'help' for usage.\n");
	show_prompt(data);

	while (!data->quit) {
		unsigned short revents;

		err = acp_card_poll_descriptors(data->card, &pfds[1], count-1);
		if (err < 0)
			return err;

		err = poll(pfds, (unsigned int) count, -1);
		if (err < 0)
			return -errno;

		if (pfds[0].revents & POLLIN)
			handle_input(data);

		if (count < 2)
			continue;

		err = acp_card_poll_descriptors_revents(data->card, &pfds[1], count-1, &revents);
		if (err < 0)
			return err;

		if (revents)
			acp_card_handle_events(data->card);
	}
	return 0;
}

#define OPTIONS		"hvc:p:"
static const struct option long_options[] = {
	{ "help",	no_argument,		NULL, 'h'},
	{ "verbose",	no_argument,		NULL, 'v'},

	{ "card",	required_argument,	NULL, 'c' },
	{ "properties",	required_argument,	NULL, 'p' },

        { NULL, 0, NULL, 0 }
};

static void show_usage(struct data *data, const char *name, bool is_error)
{
	FILE *fp;

	fp = is_error ? stderr : stdout;

	fprintf(fp, "%s [options] [COMMAND]\n", name);
	fprintf(fp,
		"  -h, --help                            Show this help\n"
		"  -v  --verbose                         Be verbose\n"
		"  -c  --card                            Card number\n"
		"  -p  --properties                      Extra properties:\n"
		"                                         'key=value ... '\n"
		"\n");
	cmd_help(data, NULL, 0, NULL);
}

int main(int argc, char *argv[])
{
	int c, res;
	int longopt_index = 0, ret;
	struct data data = { 0, };

	data.verbose = 1;

	while ((c = getopt_long(argc, argv, OPTIONS, long_options, &longopt_index)) != -1) {
		switch (c) {
		case 'h':
                        show_usage(&data, argv[0], false);
                        return EXIT_SUCCESS;
		case 'v':
			data.verbose++;
			break;
		case 'c':
			ret = atoi(optarg);
			if (ret < 0) {
				fprintf(stderr, "error: bad card %s\n", optarg);
                                goto error_usage;
			}
			data.card_index = ret;
			break;
		case 'p':
			data.properties = strdup(optarg);
			break;
                default:
			fprintf(stderr, "error: unknown option '%c'\n", c);
			goto error_usage;
		}
	}

	if ((res = do_probe(&data)) < 0) {
		fprintf(stderr, "failed to probe card: %s\n", strerror(-res));
		return res;
	}

	if (optind < argc)
		run_command(&data, argc - optind, &argv[optind]);
	else
		do_prompt(&data);

	if (data.card)
		acp_card_destroy(data.card);

	free(data.properties);

	return 0;

error_usage:
	show_usage(&data, argv[0], true);
	return EXIT_FAILURE;
}
