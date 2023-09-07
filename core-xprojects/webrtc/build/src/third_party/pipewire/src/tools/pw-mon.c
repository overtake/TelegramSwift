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

#include <stdio.h>
#include <signal.h>
#include <getopt.h>

#include <spa/utils/result.h>
#include <spa/debug/pod.h>
#include <spa/debug/format.h>
#include <spa/debug/types.h>

#include <pipewire/pipewire.h>

struct proxy_data;

typedef void (*print_func_t) (struct proxy_data *data);

struct param {
	struct spa_list link;
	uint32_t id;
	int seq;
	struct spa_pod *param;
	unsigned int changed:1;
};

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct spa_list pending_list;
};

struct proxy_data {
	struct data *data;
	bool first;
	struct pw_proxy *proxy;
	uint32_t id;
	uint32_t permissions;
	uint32_t version;
	char *type;
	void *info;
	pw_destroy_t destroy;
	struct spa_hook proxy_listener;
	struct spa_hook object_listener;
	int pending_seq;
	struct spa_list pending_link;
	print_func_t print_func;
	struct spa_list param_list;
};

static void add_pending(struct proxy_data *pd)
{
	struct data *d = pd->data;

	if (pd->pending_seq == 0) {
		spa_list_append(&d->pending_list, &pd->pending_link);
	}
	pd->pending_seq = pw_core_sync(d->core, 0, pd->pending_seq);
}

static void remove_pending(struct proxy_data *pd)
{
	if (pd->pending_seq != 0) {
		spa_list_remove(&pd->pending_link);
		pd->pending_seq = 0;
	}
}

static void on_core_done(void *data, uint32_t id, int seq)
{
	struct data *d = data;
	struct proxy_data *pd, *t;

	spa_list_for_each_safe(pd, t, &d->pending_list, pending_link) {
		if (pd->pending_seq == seq) {
			remove_pending(pd);
			pd->print_func(pd);
		}
	}
}

static void clear_params(struct proxy_data *data)
{
	struct param *p;
	spa_list_consume(p, &data->param_list, link) {
		spa_list_remove(&p->link);
		free(p);
	}
}

static void remove_params(struct proxy_data *data, uint32_t id, int seq)
{
	struct param *p, *t;

	spa_list_for_each_safe(p, t, &data->param_list, link) {
		if (p->id == id && seq != p->seq) {
			spa_list_remove(&p->link);
			free(p);
		}
	}
}

static void event_param(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t next, const struct spa_pod *param)
{
        struct proxy_data *data = object;
	struct param *p;

	/* remove all params with the same id and older seq */
	remove_params(data, id, seq);

	/* add new param */
	p = malloc(sizeof(struct param) + SPA_POD_SIZE(param));
	if (p == NULL) {
		pw_log_error("can't add param: %m");
		return;
	}

	p->id = id;
	p->seq = seq;
	p->param = SPA_MEMBER(p, sizeof(struct param), struct spa_pod);
	p->changed = true;
	memcpy(p->param, param, SPA_POD_SIZE(param));
	spa_list_append(&data->param_list, &p->link);
}

static void print_params(struct proxy_data *data, char mark)
{
	struct param *p;

	printf("%c\tparams:\n", mark);
	spa_list_for_each(p, &data->param_list, link) {
		printf("%c\t  id:%u (%s)\n", p->changed ? mark : ' ', p->id,
			spa_debug_type_find_name(spa_type_param, p->id));
		if (spa_pod_is_object_type(p->param, SPA_TYPE_OBJECT_Format))
			spa_debug_format(10, NULL, p->param);
		else
			spa_debug_pod(10, NULL, p->param);
		p->changed = false;
	}
}

static void print_properties(const struct spa_dict *props, char mark)
{
	const struct spa_dict_item *item;

	printf("%c\tproperties:\n", mark);
	if (props == NULL || props->n_items == 0) {
		printf("\t\tnone\n");
		return;
	}

	spa_dict_for_each(item, props) {
		if (item->value)
			printf("%c\t\t%s = \"%s\"\n", mark, item->key, item->value);
		else
			printf("%c\t\t%s = (null)\n", mark, item->key);
	}
}

#define MARK_CHANGE(f) ((print_mark && ((info)->change_mask & (f))) ? '*' : ' ')

static void on_core_info(void *data, const struct pw_core_info *info)
{
	bool print_all = true, print_mark = true;

	printf("\ttype: %s\n", PW_TYPE_INTERFACE_Core);
	printf("\tcookie: %u\n", info->cookie);
	printf("\tuser-name: \"%s\"\n", info->user_name);
	printf("\thost-name: \"%s\"\n", info->host_name);
	printf("\tversion: \"%s\"\n", info->version);
	printf("\tname: \"%s\"\n", info->name);
	if (print_all) {
		print_properties(info->props, MARK_CHANGE(PW_CORE_CHANGE_MASK_PROPS));
	}
}

static void module_event_info(void *object, const struct pw_module_info *info)
{
        struct proxy_data *data = object;
	bool print_all, print_mark;

	print_all = true;
        if (data->info == NULL) {
		printf("added:\n");
		print_mark = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

	info = data->info = pw_module_info_update(data->info, info);

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);
	printf("\tname: \"%s\"\n", info->name);
	printf("\tfilename: \"%s\"\n", info->filename);
	printf("\targs: \"%s\"\n", info->args);
	if (print_all) {
		print_properties(info->props, MARK_CHANGE(PW_MODULE_CHANGE_MASK_PROPS));
	}
}

static const struct pw_module_events module_events = {
	PW_VERSION_MODULE_EVENTS,
        .info = module_event_info,
};

static void print_node(struct proxy_data *data)
{
	struct pw_node_info *info = data->info;
	bool print_all, print_mark;

	print_all = true;
        if (data->first) {
		printf("added:\n");
		print_mark = false;
		data->first = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);
	if (print_all) {
		print_params(data, MARK_CHANGE(PW_NODE_CHANGE_MASK_PARAMS));
		printf("%c\tinput ports: %u/%u\n", MARK_CHANGE(PW_NODE_CHANGE_MASK_INPUT_PORTS),
				info->n_input_ports, info->max_input_ports);
		printf("%c\toutput ports: %u/%u\n", MARK_CHANGE(PW_NODE_CHANGE_MASK_OUTPUT_PORTS),
				info->n_output_ports, info->max_output_ports);
		printf("%c\tstate: \"%s\"", MARK_CHANGE(PW_NODE_CHANGE_MASK_STATE),
				pw_node_state_as_string(info->state));
		if (info->state == PW_NODE_STATE_ERROR && info->error)
			printf(" \"%s\"\n", info->error);
		else
			printf("\n");
		print_properties(info->props, MARK_CHANGE(PW_NODE_CHANGE_MASK_PROPS));
	}
}

static void node_event_info(void *object, const struct pw_node_info *info)
{
        struct proxy_data *data = object;
	uint32_t i;

	info = data->info = pw_node_info_update(data->info, info);

	if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			if (info->params[i].user == 0)
				continue;
			remove_params(data, info->params[i].id, 0);
			if (!SPA_FLAG_IS_SET(info->params[i].flags, SPA_PARAM_INFO_READ))
				continue;
			pw_node_enum_params((struct pw_node*)data->proxy,
					0, info->params[i].id, 0, 0, NULL);
			info->params[i].user = 0;
		}
		add_pending(data);
	}

	if (data->pending_seq == 0)
		data->print_func(data);
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
        .info = node_event_info,
        .param = event_param
};

static void print_port(struct proxy_data *data)
{
	struct pw_port_info *info = data->info;
	bool print_all, print_mark;

	print_all = true;
        if (data->first) {
		printf("added:\n");
		print_mark = false;
		data->first = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);

	printf("\tdirection: \"%s\"\n", pw_direction_as_string(info->direction));
	if (print_all) {
		print_params(data, MARK_CHANGE(PW_PORT_CHANGE_MASK_PARAMS));
		print_properties(info->props, MARK_CHANGE(PW_PORT_CHANGE_MASK_PROPS));
	}
}

static void port_event_info(void *object, const struct pw_port_info *info)
{
        struct proxy_data *data = object;
	uint32_t i;

	info = data->info = pw_port_info_update(data->info, info);

	if (info->change_mask & PW_PORT_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			if (info->params[i].user == 0)
				continue;
			remove_params(data, info->params[i].id, 0);
			if (!SPA_FLAG_IS_SET(info->params[i].flags, SPA_PARAM_INFO_READ))
				continue;
			pw_port_enum_params((struct pw_port*)data->proxy,
					0, info->params[i].id, 0, 0, NULL);
			info->params[i].user = 0;
		}
		add_pending(data);
	}

	if (data->pending_seq == 0)
		data->print_func(data);
}

static const struct pw_port_events port_events = {
	PW_VERSION_PORT_EVENTS,
        .info = port_event_info,
        .param = event_param
};

static void factory_event_info(void *object, const struct pw_factory_info *info)
{
        struct proxy_data *data = object;
	bool print_all, print_mark;

	print_all = true;
        if (data->info == NULL) {
		printf("added:\n");
		print_mark = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

        info = data->info = pw_factory_info_update(data->info, info);

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);

	printf("\tname: \"%s\"\n", info->name);
	printf("\tobject-type: %s/%d\n", info->type, info->version);
	if (print_all) {
		print_properties(info->props, MARK_CHANGE(PW_FACTORY_CHANGE_MASK_PROPS));
	}
}

static const struct pw_factory_events factory_events = {
	PW_VERSION_FACTORY_EVENTS,
        .info = factory_event_info
};

static void client_event_info(void *object, const struct pw_client_info *info)
{
        struct proxy_data *data = object;
	bool print_all, print_mark;

	print_all = true;
        if (data->info == NULL) {
		printf("added:\n");
		print_mark = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

        info = data->info = pw_client_info_update(data->info, info);

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);

	if (print_all) {
		print_properties(info->props, MARK_CHANGE(PW_CLIENT_CHANGE_MASK_PROPS));
	}
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
        .info = client_event_info
};

static void link_event_info(void *object, const struct pw_link_info *info)
{
        struct proxy_data *data = object;
	bool print_all, print_mark;

	print_all = true;
        if (data->info == NULL) {
		printf("added:\n");
		print_mark = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

        info = data->info = pw_link_info_update(data->info, info);

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);

	printf("\toutput-node-id: %u\n", info->output_node_id);
	printf("\toutput-port-id: %u\n", info->output_port_id);
	printf("\tinput-node-id: %u\n", info->input_node_id);
	printf("\tinput-port-id: %u\n", info->input_port_id);
	if (print_all) {
		printf("%c\tstate: \"%s\"", MARK_CHANGE(PW_LINK_CHANGE_MASK_STATE),
				pw_link_state_as_string(info->state));
		if (info->state == PW_LINK_STATE_ERROR && info->error)
			printf(" \"%s\"\n", info->error);
		else
			printf("\n");
		printf("%c\tformat:\n", MARK_CHANGE(PW_LINK_CHANGE_MASK_FORMAT));
		if (info->format)
			spa_debug_format(2, NULL, info->format);
		else
			printf("\t\tnone\n");
		print_properties(info->props, MARK_CHANGE(PW_LINK_CHANGE_MASK_PROPS));
	}
}

static const struct pw_link_events link_events = {
	PW_VERSION_LINK_EVENTS,
	.info = link_event_info
};

static void print_device(struct proxy_data *data)
{
	struct pw_device_info *info = data->info;
	bool print_all, print_mark;

	print_all = true;
        if (data->first) {
		printf("added:\n");
		print_mark = false;
		data->first = false;
	}
        else {
		printf("changed:\n");
		print_mark = true;
	}

	printf("\tid: %d\n", data->id);
	printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(data->permissions));
	printf("\ttype: %s (version %d)\n", data->type, data->version);

	if (print_all) {
		print_params(data, MARK_CHANGE(PW_DEVICE_CHANGE_MASK_PARAMS));
		print_properties(info->props, MARK_CHANGE(PW_DEVICE_CHANGE_MASK_PROPS));
	}
}


static void device_event_info(void *object, const struct pw_device_info *info)
{
        struct proxy_data *data = object;
	uint32_t i;

	info = data->info = pw_device_info_update(data->info, info);

	if (info->change_mask & PW_DEVICE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			if (info->params[i].user == 0)
				continue;
			remove_params(data, info->params[i].id, 0);
			if (!SPA_FLAG_IS_SET(info->params[i].flags, SPA_PARAM_INFO_READ))
				continue;
			pw_device_enum_params((struct pw_device*)data->proxy,
					0, info->params[i].id, 0, 0, NULL);
			info->params[i].user = 0;
		}
		add_pending(data);
	}
	if (data->pending_seq == 0)
		data->print_func(data);
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info,
        .param = event_param
};

static void
removed_proxy (void *data)
{
        struct proxy_data *pd = data;
	pw_proxy_destroy(pd->proxy);
}

static void
destroy_proxy (void *data)
{
        struct proxy_data *pd = data;

	clear_params(pd);
	remove_pending(pd);

        if (pd->info == NULL)
                return;

	if (pd->destroy)
		pd->destroy(pd->info);
        pd->info = NULL;
	free(pd->type);
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = removed_proxy,
	.destroy = destroy_proxy,
};

static void registry_event_global(void *data, uint32_t id,
				  uint32_t permissions, const char *type, uint32_t version,
				  const struct spa_dict *props)
{
        struct data *d = data;
        struct pw_proxy *proxy;
        uint32_t client_version;
        const void *events;
	struct proxy_data *pd;
	pw_destroy_t destroy;
	print_func_t print_func = NULL;

	if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		events = &node_events;
		client_version = PW_VERSION_NODE;
		destroy = (pw_destroy_t) pw_node_info_free;
		print_func = print_node;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0) {
		events = &port_events;
		client_version = PW_VERSION_PORT;
		destroy = (pw_destroy_t) pw_port_info_free;
		print_func = print_port;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Module) == 0) {
		events = &module_events;
		client_version = PW_VERSION_MODULE;
		destroy = (pw_destroy_t) pw_module_info_free;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Device) == 0) {
		events = &device_events;
		client_version = PW_VERSION_DEVICE;
		destroy = (pw_destroy_t) pw_device_info_free;
		print_func = print_device;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Factory) == 0) {
		events = &factory_events;
		client_version = PW_VERSION_FACTORY;
		destroy = (pw_destroy_t) pw_factory_info_free;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0) {
		events = &client_events;
		client_version = PW_VERSION_CLIENT;
		destroy = (pw_destroy_t) pw_client_info_free;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Link) == 0) {
		events = &link_events;
		client_version = PW_VERSION_LINK;
		destroy = (pw_destroy_t) pw_link_info_free;
	} else {
		printf("added:\n");
		printf("\tid: %u\n", id);
		printf("\tpermissions: "PW_PERMISSION_FORMAT"\n",
				PW_PERMISSION_ARGS(permissions));
		printf("\ttype: %s (version %d)\n", type, version);
		print_properties(props, ' ');
		return;
	}

        proxy = pw_registry_bind(d->registry, id, type,
				       client_version,
				       sizeof(struct proxy_data));
        if (proxy == NULL)
                goto no_mem;

	pd = pw_proxy_get_user_data(proxy);
	pd->data = d;
	pd->first = true;
	pd->proxy = proxy;
	pd->id = id;
	pd->permissions = permissions;
	pd->version = version;
	pd->type = strdup(type);
	pd->destroy = destroy;
	pd->pending_seq = 0;
	pd->print_func = print_func;
	spa_list_init(&pd->param_list);
        pw_proxy_add_object_listener(proxy, &pd->object_listener, events, pd);
        pw_proxy_add_listener(proxy, &pd->proxy_listener, &proxy_events, pd);
        return;

      no_mem:
        printf("failed to create proxy");
        return;
}

static void registry_event_global_remove(void *object, uint32_t id)
{
	printf("removed:\n");
	printf("\tid: %u\n", id);
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

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.info = on_core_info,
	.done = on_core_done,
	.error = on_core_error,
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

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	struct pw_loop *l;
	const char *opt_remote = NULL;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "remote",	required_argument,	NULL, 'r' },
		{ NULL,	0, NULL, 0}
	};
	int c;

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
			opt_remote = optarg;
			break;
		default:
			show_help(argv[0]);
			return -1;
		}
	}

	data.loop = pw_main_loop_new(NULL);
	if (data.loop == NULL) {
		fprintf(stderr, "can't create main loop: %m\n");
		return -1;
	}

	l = pw_main_loop_get_loop(data.loop);
	pw_loop_add_signal(l, SIGINT, do_quit, &data);
	pw_loop_add_signal(l, SIGTERM, do_quit, &data);

	data.context = pw_context_new(l, NULL, 0);
	if (data.context == NULL) {
		fprintf(stderr, "can't create context: %m\n");
		return -1;
	}

	spa_list_init(&data.pending_list);

	data.core = pw_context_connect(data.context,
			pw_properties_new(
				PW_KEY_REMOTE_NAME, opt_remote,
				NULL),
			0);
	if (data.core == NULL) {
		fprintf(stderr, "can't connect: %m\n");
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

	pw_main_loop_run(data.loop);

	pw_proxy_destroy((struct pw_proxy*)data.registry);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);
	pw_deinit();

	return 0;
}
