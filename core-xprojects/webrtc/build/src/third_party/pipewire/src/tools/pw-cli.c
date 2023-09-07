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

#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <signal.h>
#include <string.h>
#include <ctype.h>
#ifndef __FreeBSD__
#include <alloca.h>
#endif
#include <getopt.h>

#define spa_debug(...) fprintf(stdout,__VA_ARGS__);fputc('\n', stdout)

#include <spa/utils/result.h>
#include <spa/debug/pod.h>
#include <spa/utils/keys.h>
#include <spa/utils/json.h>
#include <spa/pod/builder.h>

#include <pipewire/impl.h>
#include <pipewire/i18n.h>

#include <extensions/session-manager.h>

static const char WHITESPACE[] = " \t";

struct remote_data;

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;

	struct spa_list remotes;
	struct remote_data *current;

	struct pw_map vars;
	unsigned int interactive:1;
	unsigned int monitoring:1;
	unsigned int quit:1;
};

struct global {
	struct remote_data *rd;
	uint32_t id;
	uint32_t permissions;
	uint32_t version;
	char *type;
	struct pw_proxy *proxy;
	bool info_pending;
	struct pw_properties *properties;
};

struct remote_data {
	struct spa_list link;
	struct data *data;

	char *name;
	uint32_t id;

	int prompt_pending;

	struct pw_core *core;
	struct spa_hook core_listener;
	struct spa_hook proxy_core_listener;
	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_map globals;
};

struct proxy_data;

typedef void (*info_func_t) (struct proxy_data *pd);

struct proxy_data {
	struct remote_data *rd;
	struct global *global;
	struct pw_proxy *proxy;
        void *info;
	info_func_t info_func;
        pw_destroy_t destroy;
        struct spa_hook proxy_listener;
        struct spa_hook object_listener;
};

struct command {
	const char *name;
	const char *alias;
	const char *description;
	bool (*func) (struct data *data, const char *cmd, char *args, char **error);
};

static int pw_split_ip(char *str, const char *delimiter, int max_tokens, char *tokens[])
{
	const char *state = NULL;
	char *s;
	size_t len;
	int n = 0;

        s = (char *)pw_split_walk(str, delimiter, &len, &state);
        while (s && n + 1 < max_tokens) {
		s[len] = '\0';
		tokens[n++] = s;
                s = (char*)pw_split_walk(str, delimiter, &len, &state);
        }
        if (s) {
		tokens[n++] = s;
        }
        return n;
}

static void print_properties(struct spa_dict *props, char mark, bool header)
{
	const struct spa_dict_item *item;

	if (header)
		fprintf(stdout, "%c\tproperties:\n", mark);
	if (props == NULL || props->n_items == 0) {
		if (header)
			fprintf(stdout, "\t\tnone\n");
		return;
	}

	spa_dict_for_each(item, props) {
		fprintf(stdout, "%c\t\t%s = \"%s\"\n", mark, item->key, item->value);
	}
}

static void print_params(struct spa_param_info *params, uint32_t n_params, char mark, bool header)
{
	uint32_t i;

	if (header)
		fprintf(stdout, "%c\tparams: (%u)\n", mark, n_params);
	if (params == NULL || n_params == 0) {
		if (header)
			fprintf(stdout, "\t\tnone\n");
		return;
	}
	for (i = 0; i < n_params; i++) {
		const struct spa_type_info *type_info = spa_type_param;

		fprintf(stdout, "%c\t  %d (%s) %c%c\n",
				params[i].user > 0 ? mark : ' ', params[i].id,
				spa_debug_type_find_name(type_info, params[i].id),
				params[i].flags & SPA_PARAM_INFO_READ ? 'r' : '-',
				params[i].flags & SPA_PARAM_INFO_WRITE ? 'w' : '-');
		params[i].user = 0;
	}
}

static bool do_not_implemented(struct data *data, const char *cmd, char *args, char **error)
{
        *error = spa_aprintf("Command \"%s\" not yet implemented", cmd);
	return false;
}

static bool do_help(struct data *data, const char *cmd, char *args, char **error);
static bool do_load_module(struct data *data, const char *cmd, char *args, char **error);
static bool do_list_objects(struct data *data, const char *cmd, char *args, char **error);
static bool do_connect(struct data *data, const char *cmd, char *args, char **error);
static bool do_disconnect(struct data *data, const char *cmd, char *args, char **error);
static bool do_list_remotes(struct data *data, const char *cmd, char *args, char **error);
static bool do_switch_remote(struct data *data, const char *cmd, char *args, char **error);
static bool do_info(struct data *data, const char *cmd, char *args, char **error);
static bool do_create_device(struct data *data, const char *cmd, char *args, char **error);
static bool do_create_node(struct data *data, const char *cmd, char *args, char **error);
static bool do_destroy(struct data *data, const char *cmd, char *args, char **error);
static bool do_create_link(struct data *data, const char *cmd, char *args, char **error);
static bool do_export_node(struct data *data, const char *cmd, char *args, char **error);
static bool do_enum_params(struct data *data, const char *cmd, char *args, char **error);
static bool do_set_param(struct data *data, const char *cmd, char *args, char **error);
static bool do_permissions(struct data *data, const char *cmd, char *args, char **error);
static bool do_get_permissions(struct data *data, const char *cmd, char *args, char **error);
static bool do_dump(struct data *data, const char *cmd, char *args, char **error);

#define DUMP_NAMES "Core|Module|Device|Node|Port|Factory|Client|Link|Session|Endpoint|EndpointStream"

static struct command command_list[] = {
	{ "help", "h", "Show this help", do_help },
	{ "load-module", "lm", "Load a module. <module-name> [<module-arguments>]", do_load_module },
	{ "unload-module", "um", "Unload a module. <module-var>", do_not_implemented },
	{ "connect", "con", "Connect to a remote. [<remote-name>]", do_connect },
	{ "disconnect", "dis", "Disconnect from a remote. [<remote-var>]", do_disconnect },
	{ "list-remotes", "lr", "List connected remotes.", do_list_remotes },
	{ "switch-remote", "sr", "Switch between current remotes. [<remote-var>]", do_switch_remote },
	{ "list-objects", "ls", "List objects or current remote. [<interface>]", do_list_objects },
	{ "info", "i", "Get info about an object. <object-id>|all", do_info },
	{ "create-device", "cd", "Create a device from a factory. <factory-name> [<properties>]", do_create_device },
	{ "create-node", "cn", "Create a node from a factory. <factory-name> [<properties>]", do_create_node },
	{ "destroy", "d", "Destroy a global object. <object-id>", do_destroy },
	{ "create-link", "cl", "Create a link between nodes. <node-id> <port-id> <node-id> <port-id> [<properties>]", do_create_link },
	{ "export-node", "en", "Export a local node to the current remote. <node-id> [remote-var]", do_export_node },
	{ "enum-params", "e", "Enumerate params of an object <object-id> <param-id>", do_enum_params },
	{ "set-param", "s", "Set param of an object <object-id> <param-id> <param-json>", do_set_param },
	{ "permissions", "sp", "Set permissions for a client <client-id> <object> <permission>", do_permissions },
	{ "get-permissions", "gp", "Get permissions of a client <client-id>", do_get_permissions },
	{ "dump", "D", "Dump objects in ways that are cleaner for humans to understand "
		 "[short|deep|resolve|notype] [-sdrt] [all|"DUMP_NAMES"|<id>]", do_dump },
};

static bool do_help(struct data *data, const char *cmd, char *args, char **error)
{
	size_t i;

	fprintf(stdout, "Available commands:\n");
	for (i = 0; i < SPA_N_ELEMENTS(command_list); i++) {
		fprintf(stdout, "\t%-20.20s\t%s\n", command_list[i].name, command_list[i].description);
	}
	return true;
}

static bool do_load_module(struct data *data, const char *cmd, char *args, char **error)
{
	struct pw_impl_module *module;
	char *a[2];
	int n;
	uint32_t id;

	n = pw_split_ip(args, WHITESPACE, 2, a);
	if (n < 1) {
		*error = spa_aprintf("%s <module-name> [<module-arguments>]", cmd);
		return false;
	}

	module = pw_context_load_module(data->context, a[0], n == 2 ? a[1] : NULL, NULL);
	if (module == NULL) {
		*error = spa_aprintf("Could not load module");
		return false;
	}

	id = pw_map_insert_new(&data->vars, module);
	fprintf(stdout, "%d = @module:%d\n", id, pw_global_get_id(pw_impl_module_get_global(module)));

	return true;
}

static void on_core_info(void *_data, const struct pw_core_info *info)
{
	struct remote_data *rd = _data;
	free(rd->name);
	rd->name = info->name ? strdup(info->name) : NULL;
	if (rd->data->interactive)
		fprintf(stdout, "remote %d is named '%s'\n", rd->id, rd->name);
}

static void show_prompt(struct remote_data *rd)
{
	rd->data->monitoring = true;
	fprintf(stdout, "%s>>", rd->name);
	fflush(stdout);
}

static void on_core_done(void *_data, uint32_t id, int seq)
{
	struct remote_data *rd = _data;
	struct data *d = rd->data;

	if (seq == rd->prompt_pending) {
		if (d->interactive)
			show_prompt(rd);
		else
			pw_main_loop_quit(d->loop);
	}
}

static int print_global(void *obj, void *data)
{
	struct global *global = obj;
	const char *filter = data;

	if (global == NULL)
		return 0;

	if (filter && !strstr(global->type, filter))
		return 0;

	fprintf(stdout, "\tid %d, type %s/%d\n", global->id,
					global->type, global->version);
	if (global->properties)
		print_properties(&global->properties->dict, ' ', false);

	return 0;
}


static bool bind_global(struct remote_data *rd, struct global *global, char **error);

static void registry_event_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	struct remote_data *rd = data;
	struct global *global;
	size_t size;
	char *error;
	bool ret;

	global = calloc(1, sizeof(struct global));
	global->rd = rd;
	global->id = id;
	global->permissions = permissions;
	global->type = strdup(type);
	global->version = version;
	global->properties = props ? pw_properties_new_dict(props) : NULL;

	if (rd->data->monitoring) {
		fprintf(stdout, "remote %d added global: ", rd->id);
		print_global(global, NULL);
	}

	size = pw_map_get_size(&rd->globals);
	while (id > size)
		pw_map_insert_at(&rd->globals, size++, NULL);
	pw_map_insert_at(&rd->globals, id, global);

	/* immediately bind the object always */
	ret = bind_global(rd, global, &error);
	if (!ret) {
		if (rd->data->interactive)
			fprintf(stdout, "Error: \"%s\"\n", error);
		free(error);
	}
}

static int destroy_global(void *obj, void *data)
{
	struct global *global = obj;

	if (global == NULL)
		return 0;

	pw_map_remove(&global->rd->globals, global->id);
	if (global->properties)
		pw_properties_free(global->properties);
	free(global->type);
	free(global);
	return 0;
}

static void registry_event_global_remove(void *data, uint32_t id)
{
	struct remote_data *rd = data;
	struct global *global;

	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		fprintf(stdout, "remote %d removed unknown global %d\n", rd->id, id);
		return;
	}

	if (rd->data->monitoring) {
		fprintf(stdout, "remote %d removed global: ", rd->id);
		print_global(global, NULL);
	}

	destroy_global(global, rd);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
	.global_remove = registry_event_global_remove,
};

static void on_core_error(void *_data, uint32_t id, int seq, int res, const char *message)
{
	struct remote_data *rd = _data;
	struct data *data = rd->data;

	pw_log_error("remote %p: error id:%u seq:%d res:%d (%s): %s", rd,
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE)
		pw_main_loop_quit(data->loop);
}

static const struct pw_core_events remote_core_events = {
	PW_VERSION_CORE_EVENTS,
	.info = on_core_info,
	.done = on_core_done,
	.error = on_core_error,
};

static void on_core_destroy(void *_data)
{
	struct remote_data *rd = _data;
	struct data *data = rd->data;

	spa_list_remove(&rd->link);

	spa_hook_remove(&rd->core_listener);
	spa_hook_remove(&rd->proxy_core_listener);

	pw_map_remove(&data->vars, rd->id);
	pw_map_for_each(&rd->globals, destroy_global, rd);
	pw_map_clear(&rd->globals);

	if (data->current == rd)
		data->current = NULL;
	free(rd->name);
}

static const struct pw_proxy_events proxy_core_events = {
	PW_VERSION_PROXY_EVENTS,
	.destroy = on_core_destroy,
};

static void remote_data_free(struct remote_data *rd)
{
	spa_hook_remove(&rd->registry_listener);
	pw_proxy_destroy((struct pw_proxy*)rd->registry);
	pw_core_disconnect(rd->core);
}

static bool do_connect(struct data *data, const char *cmd, char *args, char **error)
{
	char *a[1];
        int n;
	struct pw_properties *props = NULL;
	struct pw_core *core;
	struct remote_data *rd;

	n = args ? pw_split_ip(args, WHITESPACE, 1, a) : 0;
	if (n == 1) {
		props = pw_properties_new(PW_KEY_REMOTE_NAME, a[0], NULL);
	}
	core = pw_context_connect(data->context, props, sizeof(struct remote_data));
	if (core == NULL) {
		*error = spa_aprintf("failed to connect: %m");
		return false;
	}

	rd = pw_proxy_get_user_data((struct pw_proxy*)core);
	rd->core = core;
	rd->data = data;
	pw_map_init(&rd->globals, 64, 16);
	rd->id = pw_map_insert_new(&data->vars, rd);
	spa_list_append(&data->remotes, &rd->link);

	if (rd->data->interactive)
		fprintf(stdout, "%d = @remote:%p\n", rd->id, rd->core);

	data->current = rd;

	pw_core_add_listener(rd->core,
				   &rd->core_listener,
				   &remote_core_events, rd);
	pw_proxy_add_listener((struct pw_proxy*)rd->core,
			&rd->proxy_core_listener,
			&proxy_core_events, rd);
	rd->registry = pw_core_get_registry(rd->core, PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(rd->registry,
				       &rd->registry_listener,
				       &registry_events, rd);
	rd->prompt_pending = pw_core_sync(rd->core, 0, 0);

	return true;
}

static bool do_disconnect(struct data *data, const char *cmd, char *args, char **error)
{
	char *a[1];
        int n;
	uint32_t idx;
	struct remote_data *rd = data->current;

	n = pw_split_ip(args, WHITESPACE, 1, a);
	if (n >= 1) {
		idx = atoi(a[0]);
		rd = pw_map_lookup(&data->vars, idx);
		if (rd == NULL)
			goto no_remote;

	}
	if (rd)
		remote_data_free(rd);

	if (data->current == NULL) {
		if (spa_list_is_empty(&data->remotes)) {
			return true;
		}
		data->current = spa_list_last(&data->remotes, struct remote_data, link);
	}

	return true;

      no_remote:
        *error = spa_aprintf("Remote %d does not exist", idx);
	return false;
}

static bool do_list_remotes(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd;

	spa_list_for_each(rd, &data->remotes, link)
		fprintf(stdout, "\t%d = @remote:%p '%s'\n", rd->id, rd->core, rd->name);

	return true;
}

static bool do_switch_remote(struct data *data, const char *cmd, char *args, char **error)
{
	char *a[1];
        int n, idx = 0;
	struct remote_data *rd;

	n = pw_split_ip(args, WHITESPACE, 1, a);
	if (n == 1)
		idx = atoi(a[0]);

	rd = pw_map_lookup(&data->vars, idx);
	if (rd == NULL)
		goto no_remote;

	spa_list_remove(&rd->link);
	spa_list_append(&data->remotes, &rd->link);
	data->current = rd;

	return true;

      no_remote:
        *error = spa_aprintf("Remote %d does not exist", idx);
	return false;
}

#define MARK_CHANGE(f) ((((info)->change_mask & (f))) ? '*' : ' ')

static void info_global(struct proxy_data *pd)
{
	struct global *global = pd->global;

	if (global == NULL)
		return;

	fprintf(stdout, "\tid: %d\n", global->id);
	fprintf(stdout, "\tpermissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(global->permissions));
	fprintf(stdout, "\ttype: %s/%d\n", global->type, global->version);
}

static void info_core(struct proxy_data *pd)
{
	struct pw_core_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\tcookie: %u\n", info->cookie);
	fprintf(stdout, "\tuser-name: \"%s\"\n", info->user_name);
	fprintf(stdout, "\thost-name: \"%s\"\n", info->host_name);
	fprintf(stdout, "\tversion: \"%s\"\n", info->version);
	fprintf(stdout, "\tname: \"%s\"\n", info->name);
	print_properties(info->props, MARK_CHANGE(PW_CORE_CHANGE_MASK_PROPS), true);
	info->change_mask = 0;
}

static void info_module(struct proxy_data *pd)
{
	struct pw_module_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\tname: \"%s\"\n", info->name);
	fprintf(stdout, "\tfilename: \"%s\"\n", info->filename);
	fprintf(stdout, "\targs: \"%s\"\n", info->args);
	print_properties(info->props, MARK_CHANGE(PW_MODULE_CHANGE_MASK_PROPS), true);
	info->change_mask = 0;
}

static void info_node(struct proxy_data *pd)
{
	struct pw_node_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "%c\tinput ports: %u/%u\n", MARK_CHANGE(PW_NODE_CHANGE_MASK_INPUT_PORTS),
			info->n_input_ports, info->max_input_ports);
	fprintf(stdout, "%c\toutput ports: %u/%u\n", MARK_CHANGE(PW_NODE_CHANGE_MASK_OUTPUT_PORTS),
			info->n_output_ports, info->max_output_ports);
	fprintf(stdout, "%c\tstate: \"%s\"", MARK_CHANGE(PW_NODE_CHANGE_MASK_STATE),
			pw_node_state_as_string(info->state));
	if (info->state == PW_NODE_STATE_ERROR && info->error)
		fprintf(stdout, " \"%s\"\n", info->error);
	else
		fprintf(stdout, "\n");
	print_properties(info->props, MARK_CHANGE(PW_NODE_CHANGE_MASK_PROPS), true);
	print_params(info->params, info->n_params, MARK_CHANGE(PW_NODE_CHANGE_MASK_PARAMS), true);
	info->change_mask = 0;
}

static void info_port(struct proxy_data *pd)
{
	struct pw_port_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\tdirection: \"%s\"\n", pw_direction_as_string(info->direction));
	print_properties(info->props, MARK_CHANGE(PW_PORT_CHANGE_MASK_PROPS), true);
	print_params(info->params, info->n_params, MARK_CHANGE(PW_PORT_CHANGE_MASK_PARAMS), true);
	info->change_mask = 0;
}

static void info_factory(struct proxy_data *pd)
{
	struct pw_factory_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\tname: \"%s\"\n", info->name);
	fprintf(stdout, "\tobject-type: %s/%d\n", info->type, info->version);
	print_properties(info->props, MARK_CHANGE(PW_FACTORY_CHANGE_MASK_PROPS), true);
	info->change_mask = 0;
}

static void info_client(struct proxy_data *pd)
{
	struct pw_client_info *info = pd->info;

	info_global(pd);
	print_properties(info->props, MARK_CHANGE(PW_CLIENT_CHANGE_MASK_PROPS), true);
	info->change_mask = 0;
}

static void info_link(struct proxy_data *pd)
{
	struct pw_link_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\toutput-node-id: %u\n", info->output_node_id);
	fprintf(stdout, "\toutput-port-id: %u\n", info->output_port_id);
	fprintf(stdout, "\tinput-node-id: %u\n", info->input_node_id);
	fprintf(stdout, "\tinput-port-id: %u\n", info->input_port_id);

	fprintf(stdout, "%c\tstate: \"%s\"", MARK_CHANGE(PW_LINK_CHANGE_MASK_STATE),
			pw_link_state_as_string(info->state));
	if (info->state == PW_LINK_STATE_ERROR && info->error)
		printf(" \"%s\"\n", info->error);
	else
		printf("\n");
	fprintf(stdout, "%c\tformat:\n", MARK_CHANGE(PW_LINK_CHANGE_MASK_FORMAT));
	if (info->format)
		spa_debug_pod(2, NULL, info->format);
	else
		fprintf(stdout, "\t\tnone\n");
	print_properties(info->props, MARK_CHANGE(PW_LINK_CHANGE_MASK_PROPS), true);
	info->change_mask = 0;
}

static void info_device(struct proxy_data *pd)
{
	struct pw_device_info *info = pd->info;

	info_global(pd);
	print_properties(info->props, MARK_CHANGE(PW_DEVICE_CHANGE_MASK_PROPS), true);
	print_params(info->params, info->n_params, MARK_CHANGE(PW_DEVICE_CHANGE_MASK_PARAMS), true);
	info->change_mask = 0;
}

static void info_session(struct proxy_data *pd)
{
	struct pw_session_info *info = pd->info;

	info_global(pd);
	print_properties(info->props, MARK_CHANGE(0), true);
	print_params(info->params, info->n_params, MARK_CHANGE(1), true);
	info->change_mask = 0;
}

static void info_endpoint(struct proxy_data *pd)
{
	struct pw_endpoint_info *info = pd->info;
	const char *direction;

	info_global(pd);
	fprintf(stdout, "\tname: %s\n", info->name);
	fprintf(stdout, "\tmedia-class: %s\n",  info->media_class);
	switch(info->direction) {
	case PW_DIRECTION_OUTPUT:
		direction = "source";
		break;
	case PW_DIRECTION_INPUT:
		direction = "sink";
		break;
	default:
		direction = "invalid";
		break;
	}
	fprintf(stdout, "\tdirection: %s\n", direction);
	fprintf(stdout, "\tflags: 0x%x\n", info->flags);
	fprintf(stdout, "%c\tstreams: %u\n", MARK_CHANGE(0), info->n_streams);
	fprintf(stdout, "%c\tsession: %u\n", MARK_CHANGE(1), info->session_id);
	print_properties(info->props, MARK_CHANGE(2), true);
	print_params(info->params, info->n_params, MARK_CHANGE(3), true);
	info->change_mask = 0;
}

static void info_endpoint_stream(struct proxy_data *pd)
{
	struct pw_endpoint_stream_info *info = pd->info;

	info_global(pd);
	fprintf(stdout, "\tid: %u\n", info->id);
	fprintf(stdout, "\tendpoint-id: %u\n", info->endpoint_id);
	fprintf(stdout, "\tname: %s\n", info->name);
	print_properties(info->props, MARK_CHANGE(1), true);
	print_params(info->params, info->n_params, MARK_CHANGE(2), true);
	info->change_mask = 0;
}

static void core_event_info(void *object, const struct pw_core_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d core %d changed\n", rd->id, info->id);
	pd->info = pw_core_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_core(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.info = core_event_info
};


static void module_event_info(void *object, const struct pw_module_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d module %d changed\n", rd->id, info->id);
	pd->info = pw_module_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_module(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_module_events module_events = {
	PW_VERSION_MODULE_EVENTS,
	.info = module_event_info
};

static void node_event_info(void *object, const struct pw_node_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d node %d changed\n", rd->id, info->id);
	pd->info = pw_node_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_node(pd);
		pd->global->info_pending = false;
	}
}

static void event_param(void *object, int seq, uint32_t id,
		uint32_t index, uint32_t next, const struct spa_pod *param)
{
        struct proxy_data *data = object;
	struct remote_data *rd = data->rd;

	if (rd->data->interactive)
		fprintf(stdout, "remote %d object %d param %d index %d\n",
				rd->id, data->global->id, id, index);

	spa_debug_pod(2, NULL, param);
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
	.info = node_event_info,
	.param = event_param
};


static void port_event_info(void *object, const struct pw_port_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d port %d changed\n", rd->id, info->id);
	pd->info = pw_port_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_port(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_port_events port_events = {
	PW_VERSION_PORT_EVENTS,
	.info = port_event_info,
	.param = event_param
};

static void factory_event_info(void *object, const struct pw_factory_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d factory %d changed\n", rd->id, info->id);
	pd->info = pw_factory_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_factory(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_factory_events factory_events = {
	PW_VERSION_FACTORY_EVENTS,
	.info = factory_event_info
};

static void client_event_info(void *object, const struct pw_client_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d client %d changed\n", rd->id, info->id);
	pd->info = pw_client_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_client(pd);
		pd->global->info_pending = false;
	}
}

static void client_event_permissions(void *object, uint32_t index,
		uint32_t n_permissions, const struct pw_permission *permissions)
{
        struct proxy_data *data = object;
	struct remote_data *rd = data->rd;
	uint32_t i;

	fprintf(stdout, "remote %d node %d index %d\n",
			rd->id, data->global->id, index);

	for (i = 0; i < n_permissions; i++) {
		if (permissions[i].id == PW_ID_ANY)
			fprintf(stdout, "  default:");
		else
			fprintf(stdout, "  %u:", permissions[i].id);
		fprintf(stdout, " "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(permissions[i].permissions));
	}
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_event_info,
	.permissions = client_event_permissions
};

static void link_event_info(void *object, const struct pw_link_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d link %d changed\n", rd->id, info->id);
	pd->info = pw_link_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_link(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_link_events link_events = {
	PW_VERSION_LINK_EVENTS,
	.info = link_event_info
};


static void device_event_info(void *object, const struct pw_device_info *info)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	if (pd->info)
		fprintf(stdout, "remote %d device %d changed\n", rd->id, info->id);
	pd->info = pw_device_info_update(pd->info, info);
	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_device(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info,
	.param = event_param
};

static void session_info_free(struct pw_session_info *info)
{
	free(info->params);
	if (info->props)
		pw_properties_free ((struct pw_properties *)info->props);
	free(info);
}

static void session_event_info(void *object,
				const struct pw_session_info *update)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	struct pw_session_info *info = pd->info;

	if (!info) {
		info = pd->info = calloc(1, sizeof(*info));
		info->id = update->id;
	}
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_PARAMS) {
		info->n_params = update->n_params;
		free(info->params);
		info->params = malloc(info->n_params * sizeof(struct spa_param_info));
		memcpy(info->params, update->params,
			info->n_params * sizeof(struct spa_param_info));
	}
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_properties_free ((struct pw_properties *)info->props);
		info->props =
			(struct spa_dict *) pw_properties_new_dict (update->props);
	}

	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_session(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_session_events session_events = {
	PW_VERSION_SESSION_EVENTS,
	.info = session_event_info,
	.param = event_param
};

static void endpoint_info_free(struct pw_endpoint_info *info)
{
	free(info->name);
	free(info->media_class);
	free(info->params);
	if (info->props)
		pw_properties_free ((struct pw_properties *)info->props);
	free(info);
}

static void endpoint_event_info(void *object,
				const struct pw_endpoint_info *update)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	struct pw_endpoint_info *info = pd->info;

	if (!info) {
		info = pd->info = calloc(1, sizeof(*info));
		info->id = update->id;
		info->name = update->name ? strdup(update->name) : NULL;
		info->media_class = update->media_class ? strdup(update->media_class) : NULL;
		info->direction = update->direction;
		info->flags = update->flags;
	}
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_STREAMS)
		info->n_streams = update->n_streams;
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_SESSION)
		info->session_id = update->session_id;
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_PARAMS) {
		info->n_params = update->n_params;
		free(info->params);
		info->params = malloc(info->n_params * sizeof(struct spa_param_info));
		memcpy(info->params, update->params,
			info->n_params * sizeof(struct spa_param_info));
	}
	if (update->change_mask & PW_ENDPOINT_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_properties_free ((struct pw_properties *)info->props);
		info->props =
			(struct spa_dict *) pw_properties_new_dict (update->props);
	}

	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_endpoint(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_endpoint_events endpoint_events = {
	PW_VERSION_ENDPOINT_EVENTS,
	.info = endpoint_event_info,
	.param = event_param
};

static void endpoint_stream_info_free(struct pw_endpoint_stream_info *info)
{
	free(info->name);
	free(info->params);
	if (info->props)
		pw_properties_free ((struct pw_properties *)info->props);
	free(info);
}

static void endpoint_stream_event_info(void *object,
				const struct pw_endpoint_stream_info *update)
{
	struct proxy_data *pd = object;
	struct remote_data *rd = pd->rd;
	struct pw_endpoint_stream_info *info = pd->info;

	if (!info) {
		info = pd->info = calloc(1, sizeof(*info));
		info->id = update->id;
		info->endpoint_id = update->endpoint_id;
		info->name = update->name ? strdup(update->name) : NULL;
	}
	if (update->change_mask & PW_ENDPOINT_STREAM_CHANGE_MASK_PARAMS) {
		info->n_params = update->n_params;
		free(info->params);
		info->params = malloc(info->n_params * sizeof(struct spa_param_info));
		memcpy(info->params, update->params,
			info->n_params * sizeof(struct spa_param_info));
	}
	if (update->change_mask & PW_ENDPOINT_STREAM_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_properties_free ((struct pw_properties *)info->props);
		info->props =
			(struct spa_dict *) pw_properties_new_dict (update->props);
	}

	if (pd->global == NULL)
		pd->global = pw_map_lookup(&rd->globals, info->id);
	if (pd->global && pd->global->info_pending) {
		info_endpoint_stream(pd);
		pd->global->info_pending = false;
	}
}

static const struct pw_endpoint_stream_events endpoint_stream_events = {
	PW_VERSION_ENDPOINT_STREAM_EVENTS,
	.info = endpoint_stream_event_info,
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

	spa_hook_remove(&pd->proxy_listener);
	spa_hook_remove(&pd->object_listener);

	if (pd->info == NULL)
		return;

	if (pd->global)
		pd->global->proxy = NULL;

	if (pd->destroy)
		pd->destroy(pd->info);
	pd->info = NULL;
}

static const struct pw_proxy_events proxy_events = {
        PW_VERSION_PROXY_EVENTS,
        .removed = removed_proxy,
        .destroy = destroy_proxy,
};

static bool do_list_objects(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	pw_map_for_each(&rd->globals, print_global, args);
	return true;
}

static bool bind_global(struct remote_data *rd, struct global *global, char **error)
{
        const void *events;
        uint32_t client_version;
	info_func_t info_func;
        pw_destroy_t destroy;
	struct proxy_data *pd;
	struct pw_proxy *proxy;

	if (strcmp(global->type, PW_TYPE_INTERFACE_Core) == 0) {
		events = &core_events;
		client_version = PW_VERSION_CORE;
		destroy = (pw_destroy_t) pw_core_info_free;
		info_func = info_core;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Module) == 0) {
		events = &module_events;
		client_version = PW_VERSION_MODULE;
		destroy = (pw_destroy_t) pw_module_info_free;
		info_func = info_module;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Device) == 0) {
		events = &device_events;
		client_version = PW_VERSION_DEVICE;
		destroy = (pw_destroy_t) pw_device_info_free;
		info_func = info_device;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Node) == 0) {
		events = &node_events;
		client_version = PW_VERSION_NODE;
		destroy = (pw_destroy_t) pw_node_info_free;
		info_func = info_node;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Port) == 0) {
		events = &port_events;
		client_version = PW_VERSION_PORT;
		destroy = (pw_destroy_t) pw_port_info_free;
		info_func = info_port;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Factory) == 0) {
		events = &factory_events;
		client_version = PW_VERSION_FACTORY;
		destroy = (pw_destroy_t) pw_factory_info_free;
		info_func = info_factory;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Client) == 0) {
		events = &client_events;
		client_version = PW_VERSION_CLIENT;
		destroy = (pw_destroy_t) pw_client_info_free;
		info_func = info_client;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Link) == 0) {
		events = &link_events;
		client_version = PW_VERSION_LINK;
		destroy = (pw_destroy_t) pw_link_info_free;
		info_func = info_link;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Session) == 0) {
		events = &session_events;
		client_version = PW_VERSION_SESSION;
		destroy = (pw_destroy_t) session_info_free;
		info_func = info_session;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_Endpoint) == 0) {
		events = &endpoint_events;
		client_version = PW_VERSION_ENDPOINT;
		destroy = (pw_destroy_t) endpoint_info_free;
		info_func = info_endpoint;
	} else if (strcmp(global->type, PW_TYPE_INTERFACE_EndpointStream) == 0) {
		events = &endpoint_stream_events;
		client_version = PW_VERSION_ENDPOINT_STREAM;
		destroy = (pw_destroy_t) endpoint_stream_info_free;
		info_func = info_endpoint_stream;
	} else {
		*error = spa_aprintf("unsupported type %s", global->type);
		return false;
	}

	proxy = pw_registry_bind(rd->registry,
				       global->id,
				       global->type,
				       client_version,
				       sizeof(struct proxy_data));

	pd = pw_proxy_get_user_data(proxy);
	pd->rd = rd;
	pd->global = global;
	pd->proxy = proxy;
	pd->info_func = info_func;
	pd->destroy = destroy;
	pw_proxy_add_object_listener(proxy, &pd->object_listener, events, pd);
	pw_proxy_add_listener(proxy, &pd->proxy_listener, &proxy_events, pd);

	global->proxy = proxy;

	rd->prompt_pending = pw_core_sync(rd->core, 0, 0);

	return true;
}

static bool do_global_info(struct global *global, char **error)
{
	struct remote_data *rd = global->rd;
	struct proxy_data *pd;

	if (global->proxy == NULL) {
		if (!bind_global(rd, global, error))
			return false;
		global->info_pending = true;
	} else {
		pd = pw_proxy_get_user_data(global->proxy);
		if (pd->info_func)
			pd->info_func(pd);
	}
	return true;
}
static int do_global_info_all(void *obj, void *data)
{
	struct global *global = obj;
	char *error;

	if (global == NULL)
		return 0;

	if (!do_global_info(global, &error)) {
		fprintf(stderr, "info: %s\n", error);
		free(error);
	}
	return 0;
}

static bool do_info(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[1];
        int n;
	uint32_t id;
	struct global *global;

	n = pw_split_ip(args, WHITESPACE, 1, a);
	if (n < 1) {
		*error = spa_aprintf("%s <object-id>|all", cmd);
		return false;
	}
	if (strcmp(a[0], "all") == 0) {
		pw_map_for_each(&rd->globals, do_global_info_all, NULL);
	}
	else {
		id = atoi(a[0]);
		global = pw_map_lookup(&rd->globals, id);
		if (global == NULL) {
			*error = spa_aprintf("%s: unknown global %d", cmd, id);
			return false;
		}
		return do_global_info(global, error);
	}
	return true;
}

static bool do_create_device(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[2];
	int n;
	uint32_t id;
	struct pw_proxy *proxy;
	struct pw_properties *props = NULL;
	struct proxy_data *pd;

	n = pw_split_ip(args, WHITESPACE, 2, a);
	if (n < 1) {
		*error = spa_aprintf("%s <factory-name> [<properties>]", cmd);
		return false;
	}
	if (n == 2)
		props = pw_properties_new_string(a[1]);

	proxy = pw_core_create_object(rd->core, a[0],
					    PW_TYPE_INTERFACE_Device,
					    PW_VERSION_DEVICE,
					    props ? &props->dict : NULL,
					    sizeof(struct proxy_data));

	if (props)
		pw_properties_free(props);

	pd = pw_proxy_get_user_data(proxy);
	pd->rd = rd;
	pd->proxy = proxy;
	pd->destroy = (pw_destroy_t) pw_device_info_free;
	pw_proxy_add_object_listener(proxy, &pd->object_listener, &device_events, pd);
	pw_proxy_add_listener(proxy, &pd->proxy_listener, &proxy_events, pd);

	id = pw_map_insert_new(&data->vars, proxy);
	fprintf(stdout, "%d = @proxy:%d\n", id, pw_proxy_get_id(proxy));

	return true;
}

static bool do_create_node(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[2];
        int n;
	uint32_t id;
	struct pw_proxy *proxy;
	struct pw_properties *props = NULL;
	struct proxy_data *pd;

	n = pw_split_ip(args, WHITESPACE, 2, a);
	if (n < 1) {
		*error = spa_aprintf("%s <factory-name> [<properties>]", cmd);
		return false;
	}
	if (n == 2)
		props = pw_properties_new_string(a[1]);

	proxy = pw_core_create_object(rd->core, a[0],
					    PW_TYPE_INTERFACE_Node,
					    PW_VERSION_NODE,
					    props ? &props->dict : NULL,
					    sizeof(struct proxy_data));

	if (props)
		pw_properties_free(props);

	pd = pw_proxy_get_user_data(proxy);
	pd->rd = rd;
	pd->proxy = proxy;
        pd->destroy = (pw_destroy_t) pw_node_info_free;
        pw_proxy_add_object_listener(proxy, &pd->object_listener, &node_events, pd);
        pw_proxy_add_listener(proxy, &pd->proxy_listener, &proxy_events, pd);

	id = pw_map_insert_new(&data->vars, proxy);
	fprintf(stdout, "%d = @proxy:%d\n", id, pw_proxy_get_id(proxy));

	return true;
}

static bool do_destroy(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[1];
        int n;
	uint32_t id;
	struct global *global;

	n = pw_split_ip(args, WHITESPACE, 1, a);
	if (n < 1) {
		*error = spa_aprintf("%s <object-id>", cmd);
		return false;
	}
	id = atoi(a[0]);
	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		*error = spa_aprintf("%s: unknown global %d", cmd, id);
		return false;
	}
	pw_registry_destroy(rd->registry, id);

	return true;
}

static bool do_create_link(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[5];
        int n;
	uint32_t id;
	struct pw_proxy *proxy;
	struct pw_properties *props = NULL;
	struct proxy_data *pd;

	n = pw_split_ip(args, WHITESPACE, 5, a);
	if (n < 4) {
		*error = spa_aprintf("%s <node-id> <port> <node-id> <port> [<properties>]", cmd);
		return false;
	}
	if (n == 5)
		props = pw_properties_new_string(a[4]);
	else
		props = pw_properties_new(NULL, NULL);

	pw_properties_set(props, PW_KEY_LINK_OUTPUT_NODE, a[0]);
	pw_properties_set(props, PW_KEY_LINK_OUTPUT_PORT, a[1]);
	pw_properties_set(props, PW_KEY_LINK_INPUT_NODE, a[2]);
	pw_properties_set(props, PW_KEY_LINK_INPUT_PORT, a[3]);

	proxy = (struct pw_proxy*)pw_core_create_object(rd->core,
					  "link-factory",
					  PW_TYPE_INTERFACE_Link,
					  PW_VERSION_LINK,
					  props ? &props->dict : NULL,
					  sizeof(struct proxy_data));

	if (props)
		pw_properties_free(props);

	pd = pw_proxy_get_user_data(proxy);
	pd->rd = rd;
	pd->proxy = proxy;
        pd->destroy = (pw_destroy_t) pw_link_info_free;
        pw_proxy_add_object_listener(proxy, &pd->object_listener, &link_events, pd);
        pw_proxy_add_listener(proxy, &pd->proxy_listener, &proxy_events, pd);

	id = pw_map_insert_new(&data->vars, proxy);
	fprintf(stdout, "%d = @proxy:%d\n", id, pw_proxy_get_id((struct pw_proxy*)proxy));

	return true;
}

static bool do_export_node(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	struct pw_global *global;
	struct pw_node *node;
	struct pw_proxy *proxy;
	char *a[2];
	int n, idx;
	uint32_t id;

	n = pw_split_ip(args, WHITESPACE, 2, a);
	if (n < 1) {
		*error = spa_aprintf("%s <node-id> [<remote-var>]", cmd);
		return false;
	}
	if (n == 2) {
		idx = atoi(a[1]);
		rd = pw_map_lookup(&data->vars, idx);
		if (rd == NULL)
			goto no_remote;
	}

	global = pw_context_find_global(data->context, atoi(a[0]));
	if (global == NULL) {
		*error = spa_aprintf("object %d does not exist", atoi(a[0]));
		return false;
	}
	if (!pw_global_is_type(global, PW_TYPE_INTERFACE_Node)) {
		*error = spa_aprintf("object %d is not a node", atoi(a[0]));
		return false;
	}
	node = pw_global_get_object(global);
	proxy = pw_core_export(rd->core, PW_TYPE_INTERFACE_Node, NULL, node, 0);

	id = pw_map_insert_new(&data->vars, proxy);
	fprintf(stdout, "%d = @proxy:%d\n", id, pw_proxy_get_id((struct pw_proxy*)proxy));

	return true;

      no_remote:
        *error = spa_aprintf("Remote %d does not exist", idx);
	return false;
}

static const struct spa_type_info *find_type_info(const struct spa_type_info *info, const char *name)
{
	while (info && info->name) {
                if (strcmp(info->name, name) == 0)
                        return info;
                if (strcmp(spa_debug_type_short_name(info->name), name) == 0)
                        return info;
                if (info->type != 0 && info->type == (uint32_t)atoi(name))
                        return info;
                info++;
        }
        return NULL;
}

static bool do_enum_params(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[2];
	int n;
	uint32_t id, param_id;
	const struct spa_type_info *ti;
	struct global *global;

	n = pw_split_ip(args, WHITESPACE, 2, a);
	if (n < 2) {
		*error = spa_aprintf("%s <object-id> <param-id>", cmd);
		return false;
	}

	id = atoi(a[0]);
	ti = find_type_info(spa_type_param, a[1]);
	if (ti == NULL) {
		*error = spa_aprintf("%s: unknown param type: %s", cmd, a[1]);
		return false;
	}
	param_id = ti->type;

	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		*error = spa_aprintf("%s: unknown global %d", cmd, id);
		return false;
	}
	if (global->proxy == NULL) {
		if (!bind_global(rd, global, error))
			return false;
	}

	if (strcmp(global->type, PW_TYPE_INTERFACE_Node) == 0)
		pw_node_enum_params((struct pw_node*)global->proxy, 0,
			param_id, 0, 0, NULL);
	else if (strcmp(global->type, PW_TYPE_INTERFACE_Port) == 0)
		pw_port_enum_params((struct pw_port*)global->proxy, 0,
			param_id, 0, 0, NULL);
	else if (strcmp(global->type, PW_TYPE_INTERFACE_Device) == 0)
		pw_device_enum_params((struct pw_device*)global->proxy, 0,
			param_id, 0, 0, NULL);
	else if (strcmp(global->type, PW_TYPE_INTERFACE_Endpoint) == 0)
		pw_endpoint_enum_params((struct pw_endpoint*)global->proxy, 0,
			param_id, 0, 0, NULL);
	else {
		*error = spa_aprintf("enum-params not implemented on object %d type:%s",
				atoi(a[0]), global->type);
		return false;
	}
	return true;
}

static int json_to_pod(struct spa_pod_builder *b, uint32_t id,
		const struct spa_type_info *info, struct spa_json *iter, const char *value, int len)
{
	const struct spa_type_info *ti;
	char key[256];
	struct spa_pod_frame f[1];
	struct spa_json it[1];
	int l, res;
	const char *v;
	uint32_t type;

	if (spa_json_is_object(value, len) && info != NULL) {
		if ((ti = spa_debug_type_find(NULL, info->parent)) == NULL)
			return -EINVAL;

		spa_pod_builder_push_object(b, &f[0], info->parent, id);

		spa_json_enter(iter, &it[0]);
		while (spa_json_get_string(&it[0], key, sizeof(key)-1) > 0) {
			const struct spa_type_info *pi;
			if ((l = spa_json_next(&it[0], &v)) <= 0)
				break;
			if ((pi = find_type_info(ti->values, key)) != NULL)
				type = pi->type;
			else if ((type = atoi(key)) == 0)
				continue;
			spa_pod_builder_prop(b, type, 0);
			if ((res = json_to_pod(b, id, pi, &it[0], v, l)) < 0)
				return res;
		}
		spa_pod_builder_pop(b, &f[0]);
	}
	else if (spa_json_is_array(value, len)) {
		if (info == NULL || info->parent == SPA_TYPE_Struct) {
			spa_pod_builder_push_struct(b, &f[0]);
		} else {
			spa_pod_builder_push_array(b, &f[0]);
			info = info->values;
		}
		spa_json_enter(iter, &it[0]);
		while ((l = spa_json_next(&it[0], &v)) > 0)
			if ((res = json_to_pod(b, id, info, &it[0], v, l)) < 0)
				return res;
		spa_pod_builder_pop(b, &f[0]);
	}
	else if (spa_json_is_float(value, len)) {
		float val = 0.0f;
		spa_json_parse_float(value, len, &val);
		switch (info ? info->parent : SPA_TYPE_Struct) {
		case SPA_TYPE_Bool:
			spa_pod_builder_bool(b, val >= 0.5f);
			break;
		case SPA_TYPE_Id:
			spa_pod_builder_id(b, val);
			break;
		case SPA_TYPE_Int:
			spa_pod_builder_int(b, val);
			break;
		case SPA_TYPE_Long:
			spa_pod_builder_long(b, val);
			break;
		case SPA_TYPE_Struct:
			if (spa_json_is_int(value, len))
				spa_pod_builder_int(b, val);
			else
				spa_pod_builder_float(b, val);
			break;
		case SPA_TYPE_Float:
			spa_pod_builder_float(b, val);
			break;
		case SPA_TYPE_Double:
			spa_pod_builder_double(b, val);
			break;
		default:
			spa_pod_builder_none(b);
			break;
		}
	}
	else if (spa_json_is_bool(value, len)) {
		bool val = false;
		spa_json_parse_bool(value, len, &val);
		spa_pod_builder_bool(b, val);
	}
	else if (spa_json_is_null(value, len)) {
		spa_pod_builder_none(b);
	}
	else {
		char *val = alloca(len+1);
		spa_json_parse_string(value, len, val);
		switch (info ? info->parent : SPA_TYPE_Struct) {
		case SPA_TYPE_Id:
			if ((ti = find_type_info(info->values, val)) != NULL)
				type = ti->type;
			else if ((type = atoi(val)) == 0)
				return -EINVAL;
			spa_pod_builder_id(b, type);
			break;
		case SPA_TYPE_Struct:
		case SPA_TYPE_String:
			spa_pod_builder_string(b, val);
			break;
		default:
			spa_pod_builder_none(b);
			break;
		}
	}
	return 0;
}

static bool do_set_param(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[3];
	const char *val;
        int res, n, len;
	uint32_t id, param_id;
	struct global *global;
	struct spa_json it[3];
	uint8_t buffer[1024];
        struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	const struct spa_type_info *ti;
	struct spa_pod *pod;

	n = pw_split_ip(args, WHITESPACE, 3, a);
	if (n < 3) {
		*error = spa_aprintf("%s <object-id> <param-id> <param-json>", cmd);
		return false;
	}

	id = atoi(a[0]);

	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		*error = spa_aprintf("%s: unknown global %d", cmd, id);
		return false;
	}
	if (global->proxy == NULL) {
		if (!bind_global(rd, global, error))
			return false;
	}

	ti = find_type_info(spa_type_param, a[1]);
	if (ti == NULL) {
		*error = spa_aprintf("%s: unknown param type: %s", cmd, a[1]);
		return false;
	}
	param_id = ti->type;

	spa_json_init(&it[0], a[2], strlen(a[2]));
	if ((len = spa_json_next(&it[0], &val)) <= 0) {
		*error = spa_aprintf("%s: not a JSON object: %s", cmd, a[2]);
		return false;
	}
	if ((res = json_to_pod(&b, param_id, ti, &it[0], val, len)) < 0) {
		*error = spa_aprintf("%s: can't make pod: %s", cmd, spa_strerror(res));
		return false;
	}
	if ((pod = spa_pod_builder_deref(&b, 0)) == NULL) {
		*error = spa_aprintf("%s: can't make pod", cmd);
		return false;
	}
	spa_debug_pod(0, NULL, pod);

	if (strcmp(global->type, PW_TYPE_INTERFACE_Node) == 0)
		pw_node_set_param((struct pw_node*)global->proxy,
				param_id, 0, pod);
	else if (strcmp(global->type, PW_TYPE_INTERFACE_Device) == 0)
		pw_device_set_param((struct pw_device*)global->proxy,
				param_id, 0, pod);
	else if (strcmp(global->type, PW_TYPE_INTERFACE_Endpoint) == 0)
		pw_endpoint_set_param((struct pw_endpoint*)global->proxy,
				param_id, 0, pod);
	else {
		*error = spa_aprintf("set-param not implemented on object %d type:%s",
				atoi(a[0]), global->type);
		return false;
	}
	return true;
}

static bool do_permissions(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[3];
	int n;
	uint32_t id, p;
	struct global *global;
	struct pw_permission permissions[1];

	n = pw_split_ip(args, WHITESPACE, 3, a);
	if (n < 3) {
		*error = spa_aprintf("%s <client-id> <object> <permission>", cmd);
		return false;
	}

	id = atoi(a[0]);
	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		*error = spa_aprintf("%s: unknown global %d", cmd, id);
		return false;
	}
	if (strcmp(global->type, PW_TYPE_INTERFACE_Client) != 0) {
		*error = spa_aprintf("object %d is not a client", atoi(a[0]));
		return false;
	}
	if (global->proxy == NULL) {
		if (!bind_global(rd, global, error))
			return false;
	}

	p = strtol(a[2], NULL, 0);
	fprintf(stderr, "setting permissions: "PW_PERMISSION_FORMAT"\n",
			PW_PERMISSION_ARGS(p));

	permissions[0] = PW_PERMISSION_INIT(atoi(a[1]), p);
	pw_client_update_permissions((struct pw_client*)global->proxy,
			1, permissions);

	return true;
}

static bool do_get_permissions(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	char *a[3];
        int n;
	uint32_t id;
	struct global *global;

	n = pw_split_ip(args, WHITESPACE, 1, a);
	if (n < 1) {
		*error = spa_aprintf("%s <client-id>", cmd);
		return false;
	}

	id = atoi(a[0]);
	global = pw_map_lookup(&rd->globals, id);
	if (global == NULL) {
		*error = spa_aprintf("%s: unknown global %d", cmd, id);
		return false;
	}
	if (strcmp(global->type, PW_TYPE_INTERFACE_Client) != 0) {
		*error = spa_aprintf("object %d is not a client", atoi(a[0]));
		return false;
	}
	if (global->proxy == NULL) {
		if (!bind_global(rd, global, error))
			return false;
	}
	pw_client_get_permissions((struct pw_client*)global->proxy,
			0, UINT32_MAX);

	return true;
}

static const char *
pw_interface_short(const char *type)
{
	size_t ilen;

	ilen = strlen(PW_TYPE_INFO_INTERFACE_BASE);

	if (!type || strlen(type) <= ilen ||
	    memcmp(type, PW_TYPE_INFO_INTERFACE_BASE, ilen))
		return NULL;

	return type + ilen;
}

static struct global *
obj_global(struct remote_data *rd, uint32_t id)
{
	struct global *global;
	struct proxy_data *pd;

	if (!rd)
		return NULL;

	global = pw_map_lookup(&rd->globals, id);
	if (!global)
		return NULL;

	pd = pw_proxy_get_user_data(global->proxy);
	if (!pd || !pd->info)
		return NULL;

	return global;
}

static struct spa_dict *
global_props(struct global *global)
{
	struct proxy_data *pd;

	if (!global)
		return NULL;

	pd = pw_proxy_get_user_data(global->proxy);
	if (!pd || !pd->info)
		return NULL;

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Core))
		return ((struct pw_core_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Module))
		return ((struct pw_module_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Device))
		return ((struct pw_device_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Node))
		return ((struct pw_node_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Port))
		return ((struct pw_port_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Factory))
		return ((struct pw_factory_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Client))
		return ((struct pw_client_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Link))
		return ((struct pw_link_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Session))
		return ((struct pw_session_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_Endpoint))
		return ((struct pw_endpoint_info *)pd->info)->props;
	if (!strcmp(global->type, PW_TYPE_INTERFACE_EndpointStream))
		return ((struct pw_endpoint_stream_info *)pd->info)->props;

	return NULL;
}

static struct spa_dict *
obj_props(struct remote_data *rd, uint32_t id)
{
	struct global *global;

	if (!rd)
		return NULL;

	global = obj_global(rd, id);
	if (!global)
		return NULL;
	return global_props(global);
}

static const char *
global_lookup(struct global *global, const char *key)
{
	struct spa_dict *dict;

	dict = global_props(global);
	if (!dict)
		return NULL;
	return spa_dict_lookup(dict, key);
}

static const char *
obj_lookup(struct remote_data *rd, uint32_t id, const char *key)
{
	struct spa_dict *dict;

	dict = obj_props(rd, id);
	if (!dict)
		return NULL;
	return spa_dict_lookup(dict, key);
}

static int
children_of(struct remote_data *rd, uint32_t parent_id,
	    const char *child_type, uint32_t **children)
{
	const char *parent_type;
	union pw_map_item *item;
	struct global *global;
	struct proxy_data *pd;
	const char *parent_key = NULL, *child_key = NULL;
	const char *parent_value = NULL, *child_value = NULL;
	int pass, i, count;

	if (!rd || !children)
		return -1;

	/* get the device info */
	global = obj_global(rd, parent_id);
	if (!global)
		return -1;
	parent_type = global->type;
	pd = pw_proxy_get_user_data(global->proxy);
	if (!pd || !pd->info)
		return -1;

	/* supported combinations */
	if (!strcmp(parent_type, PW_TYPE_INTERFACE_Device) &&
	    !strcmp(child_type, PW_TYPE_INTERFACE_Node)) {
		parent_key = PW_KEY_OBJECT_ID;
		child_key = PW_KEY_DEVICE_ID;
	} else if (!strcmp(parent_type, PW_TYPE_INTERFACE_Node) &&
		   !strcmp(child_type, PW_TYPE_INTERFACE_Port)) {
		parent_key = PW_KEY_OBJECT_ID;
		child_key = PW_KEY_NODE_ID;
	} else if (!strcmp(parent_type, PW_TYPE_INTERFACE_Module) &&
		   !strcmp(child_type, PW_TYPE_INTERFACE_Factory)) {
		parent_key = PW_KEY_OBJECT_ID;
		child_key = PW_KEY_MODULE_ID;
	} else if (!strcmp(parent_type, PW_TYPE_INTERFACE_Factory) &&
		   !strcmp(child_type, PW_TYPE_INTERFACE_Device)) {
		parent_key = PW_KEY_OBJECT_ID;
		child_key = PW_KEY_FACTORY_ID;
	} else
		return -1;

	/* get the parent key value */
	if (parent_key) {
		parent_value = global_lookup(global, parent_key);
		if (!parent_value)
			return -1;
	}

	count = 0;
	*children = NULL;
	i = 0;
	for (pass = 1; pass <= 2; pass++) {
		if (pass == 2) {
			count = i;
			if (!count)
				return 0;

			*children = malloc(sizeof(uint32_t) * count);
			if (!*children)
				return -1;
		}
		i = 0;
		pw_array_for_each(item, &rd->globals.items) {
			if (pw_map_item_is_free(item) || item->data == NULL)
				continue;

			global = item->data;

			if (strcmp(global->type, child_type))
				continue;

			pd = pw_proxy_get_user_data(global->proxy);
			if (!pd || !pd->info)
				return -1;

			if (child_key) {
				/* get the device path */
				child_value = global_lookup(global, child_key);
				if (!child_value)
					continue;
			}

			/* match? */
			if (strcmp(parent_value, child_value))
				continue;

			if (*children)
				(*children)[i] = global->id;
			i++;

		}
	}
	return count;
}

#ifndef BIT
#define BIT(x) (1U << (x))
#endif

enum dump_flags {
	is_default = 0,
	is_short = BIT(0),
	is_deep = BIT(1),
	is_resolve = BIT(2),
	is_notype = BIT(3)
};

static const char *dump_types[] = {
	PW_TYPE_INTERFACE_Core,
	PW_TYPE_INTERFACE_Module,
	PW_TYPE_INTERFACE_Device,
	PW_TYPE_INTERFACE_Node,
	PW_TYPE_INTERFACE_Port,
	PW_TYPE_INTERFACE_Factory,
	PW_TYPE_INTERFACE_Client,
	PW_TYPE_INTERFACE_Link,
	PW_TYPE_INTERFACE_Session,
	PW_TYPE_INTERFACE_Endpoint,
	PW_TYPE_INTERFACE_EndpointStream,
};

int dump_type_index(const char *type)
{
	unsigned int i;

	if (!type)
		return -1;

	for (i = 0; i < SPA_N_ELEMENTS(dump_types); i++) {
		if (!strcmp(dump_types[i], type))
			return (int)i;
	}

	return -1;
}

static inline unsigned int dump_type_count(void)
{
	return SPA_N_ELEMENTS(dump_types);
}

static const char *name_to_dump_type(const char *name)
{
	unsigned int i;

	if (!name)
		return NULL;

	for (i = 0; i < SPA_N_ELEMENTS(dump_types); i++) {
		if (!strcasecmp(name, pw_interface_short(dump_types[i])))
			return dump_types[i];
	}

	return NULL;
}

#define INDENT(_level) \
	({ \
		int __level = (_level); \
		char *_indent = alloca(__level + 1); \
		memset(_indent, '\t', __level); \
		_indent[__level] = '\0'; \
		(const char *)_indent; \
	})

static void
dump(struct data *data, struct global *global,
     enum dump_flags flags, int level);

static void
dump_properties(struct data *data, struct global *global,
		enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct spa_dict *props;
	const struct spa_dict_item *item;
	const char *ind;
	int id;
	const char *extra;

	if (!global)
		return;

	props = global_props(global);
	if (!props || !props->n_items)
		return;

	ind = INDENT(level + 2);
	spa_dict_for_each(item, props) {
		fprintf(stdout, "%s%s = \"%s\"",
				ind, item->key, item->value);

		extra = NULL;
		id = -1;
		if (!strcmp(global->type, PW_TYPE_INTERFACE_Port) && !strcmp(item->key, PW_KEY_NODE_ID)) {
			id = atoi(item->value);
			if (id >= 0)
				extra = obj_lookup(rd, id, PW_KEY_NODE_NAME);
		} else if (!strcmp(global->type, PW_TYPE_INTERFACE_Factory) && !strcmp(item->key, PW_KEY_MODULE_ID)) {
			id = atoi(item->value);
			if (id >= 0)
				extra = obj_lookup(rd, id, PW_KEY_MODULE_NAME);
		} else if (!strcmp(global->type, PW_TYPE_INTERFACE_Device) && !strcmp(item->key, PW_KEY_FACTORY_ID)) {
			id = atoi(item->value);
			if (id >= 0)
				extra = obj_lookup(rd, id, PW_KEY_FACTORY_NAME);
		} else if (!strcmp(global->type, PW_TYPE_INTERFACE_Device) && !strcmp(item->key, PW_KEY_CLIENT_ID)) {
			id = atoi(item->value);
			if (id >= 0)
				extra = obj_lookup(rd, id, PW_KEY_CLIENT_NAME);
		}

		if (extra)
			fprintf(stdout, " (\"%s\")", extra);

		fprintf(stdout, "\n");
	}
}

static void
dump_params(struct data *data, struct global *global,
	    struct spa_param_info *params, uint32_t n_params,
	    enum dump_flags flags, int level)
{
	uint32_t i;
	const char *ind;

	if (params == NULL || n_params == 0)
		return;

	ind = INDENT(level + 1);
	for (i = 0; i < n_params; i++) {
		const struct spa_type_info *type_info = spa_type_param;

		fprintf(stdout, "%s  %d (%s) %c%c\n", ind,
			params[i].id,
			spa_debug_type_find_name(type_info, params[i].id),
			params[i].flags & SPA_PARAM_INFO_READ ? 'r' : '-',
			params[i].flags & SPA_PARAM_INFO_WRITE ? 'w' : '-');
	}
}


static void
dump_global_common(struct data *data, struct global *global,
	    enum dump_flags flags, int level)
{
	const char *ind;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sid: %"PRIu32"\n", ind, global->id);
		fprintf(stdout, "%spermissions: "PW_PERMISSION_FORMAT"\n", ind,
			PW_PERMISSION_ARGS(global->permissions));
		fprintf(stdout, "%stype: %s/%d\n", ind,
				global->type, global->version);
	} else {
		ind = INDENT(level);
		fprintf(stdout, "%s%"PRIu32":", ind, global->id);
		if (!(flags & is_notype))
			fprintf(stdout, " %s", pw_interface_short(global->type));
	}
}

static bool
dump_core(struct data *data, struct global *global,
	  enum dump_flags flags, int level)
{
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_core_info *info;
	const char *ind;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;
	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%scookie: %u\n", ind, info->cookie);
		fprintf(stdout, "%suser-name: \"%s\"\n", ind, info->user_name);
		fprintf(stdout, "%shost-name: \"%s\"\n", ind, info->host_name);
		fprintf(stdout, "%sversion: \"%s\"\n", ind, info->version);
		fprintf(stdout, "%sname: \"%s\"\n", ind, info->name);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
	} else {
		fprintf(stdout, " u=\"%s\" h=\"%s\" v=\"%s\" n=\"%s\"",
				info->user_name, info->host_name, info->version, info->name);
		fprintf(stdout, "\n");
	}

	return true;
}

static bool
dump_module(struct data *data, struct global *global,
	    enum dump_flags flags, int level)
{
	struct remote_data *rd = global->rd;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_module_info *info;
	const char *args, *desc;
	const char *ind;
	uint32_t *factories = NULL;
	int i, factory_count;
	struct global *global_factory;

	if (!pd->info)
		return false;

	info = pd->info;

	dump_global_common(data, global, flags, level);

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sname: \"%s\"\n", ind, info->name);
		fprintf(stdout, "%sfilename: \"%s\"\n", ind, info->filename);
		fprintf(stdout, "%sargs: \"%s\"\n", ind, info->args);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
	} else {
		desc = spa_dict_lookup(info->props, PW_KEY_MODULE_DESCRIPTION);
		args = info->args && strcmp(info->args, "(null)") ? info->args : NULL;
		fprintf(stdout, " n=\"%s\" f=\"%s\"" "%s%s%s" "%s%s%s",
				info->name, info->filename,
				args ? " a=\"" : "",
				args ? args : "",
				args ? "\"" : "",
				desc ? " d=\"" : "",
				desc ? desc : "",
				desc ? "\"" : "");
		fprintf(stdout, "\n");
	}

	if (!(flags & is_deep))
		return true;

	factory_count = children_of(rd, global->id, PW_TYPE_INTERFACE_Factory, &factories);
	if (factory_count >= 0) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sfactories:\n", ind);
		for (i = 0; i < factory_count; i++) {
			global_factory = obj_global(rd, factories[i]);
			if (!global_factory)
				continue;
			dump(data, global_factory, flags | is_notype, level + 1);
		}
		free(factories);
	}

	return true;
}

static bool
dump_device(struct data *data, struct global *global,
	    enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_device_info *info;
	const char *media_class, *api, *desc, *name;
	const char *alsa_path, *alsa_card_id;
	const char *ind;
	uint32_t *nodes = NULL;
	int i, node_count;
	struct global *global_node;

	if (!pd->info)
		return false;

	info = pd->info;

	dump_global_common(data, global, flags, level);

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		media_class = spa_dict_lookup(info->props, PW_KEY_MEDIA_CLASS);
		name = spa_dict_lookup(info->props, PW_KEY_DEVICE_NAME);
		desc = spa_dict_lookup(info->props, PW_KEY_DEVICE_DESCRIPTION);
		api = spa_dict_lookup(info->props, PW_KEY_DEVICE_API);

		fprintf(stdout, "%s%s%s" "%s%s%s" "%s%s%s" "%s%s%s",
				media_class ? " c=\"" : "",
				media_class ? media_class : "",
				media_class ? "\"" : "",
				name ? " n=\"" : "",
				name ? name : "",
				name ? "\"" : "",
				desc ? " d=\"" : "",
				desc ? desc : "",
				desc ? "\"" : "",
				api ? " a=\"" : "",
				api ? api : "",
				api ? "\"" : "");

		if (media_class && !strcmp(media_class, "Audio/Device") &&
		    api && !strcmp(api, "alsa:pcm")) {

			alsa_path = spa_dict_lookup(info->props, SPA_KEY_API_ALSA_PATH);
			alsa_card_id = spa_dict_lookup(info->props, SPA_KEY_API_ALSA_CARD_ID);

			fprintf(stdout, "%s%s%s" "%s%s%s",
					alsa_path ? " p=\"" : "",
					alsa_path ? alsa_path : "",
					alsa_path ? "\"" : "",
					alsa_card_id ? " id=\"" : "",
					alsa_card_id ? alsa_card_id : "",
					alsa_card_id ? "\"" : "");
		}

		fprintf(stdout, "\n");
	}

	if (!(flags & is_deep))
		return true;

	node_count = children_of(rd, global->id, PW_TYPE_INTERFACE_Node, &nodes);
	if (node_count >= 0) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%snodes:\n", ind);
		for (i = 0; i < node_count; i++) {
			global_node = obj_global(rd, nodes[i]);
			if (!global_node)
				continue;
			dump(data, global_node, flags | is_notype, level + 1);
		}
		free(nodes);
	}

	return true;
}

static bool
dump_node(struct data *data, struct global *global,
	  enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_node_info *info;
	const char *name, *path;
	const char *ind;
	uint32_t *ports = NULL;
	int i, port_count;
	struct global *global_port;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sinput ports: %u/%u\n", ind, info->n_input_ports, info->max_input_ports);
		fprintf(stdout, "%soutput ports: %u/%u\n", ind, info->n_output_ports, info->max_output_ports);
		fprintf(stdout, "%sstate: \"%s\"", ind, pw_node_state_as_string(info->state));
		if (info->state == PW_NODE_STATE_ERROR && info->error)
			fprintf(stdout, " \"%s\"\n", info->error);
		else
			fprintf(stdout, "\n");
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		name = spa_dict_lookup(info->props, PW_KEY_NODE_NAME);
		path = spa_dict_lookup(info->props, SPA_KEY_OBJECT_PATH);

		fprintf(stdout, " s=\"%s\"", pw_node_state_as_string(info->state));

		if (info->max_input_ports) {
			fprintf(stdout, " i=%u/%u", info->n_input_ports, info->max_input_ports);
		}
		if (info->max_output_ports) {
			fprintf(stdout, " o=%u/%u", info->n_output_ports, info->max_output_ports);
		}

		fprintf(stdout, "%s%s%s" "%s%s%s",
				name ? " n=\"" : "",
				name ? name : "",
				name ? "\"" : "",
				path ? " p=\"" : "",
				path ? path : "",
				path ? "\"" : "");

		fprintf(stdout, "\n");
	}

	if (!(flags & is_deep))
		return true;

	port_count = children_of(rd, global->id, PW_TYPE_INTERFACE_Port, &ports);
	if (port_count >= 0) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sports:\n", ind);
		for (i = 0; i < port_count; i++) {
			global_port = obj_global(rd, ports[i]);
			if (!global_port)
				continue;
			dump(data, global_port, flags | is_notype, level + 1);
		}
		free(ports);
	}
	return true;
}

static bool
dump_port(struct data *data, struct global *global,
	  enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_port_info *info;
	const char *ind;
	const char *name, *format;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sdirection: \"%s\"\n", ind,
				pw_direction_as_string(info->direction));
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		fprintf(stdout, " d=\"%s\"", pw_direction_as_string(info->direction));

		name = spa_dict_lookup(info->props, PW_KEY_PORT_NAME);
		format = spa_dict_lookup(info->props, PW_KEY_FORMAT_DSP);

		fprintf(stdout, "%s%s%s" "%s%s%s",
				name ? " n=\"" : "",
				name ? name : "",
				name ? "\"" : "",
				format ? " f=\"" : "",
				format ? format : "",
				format ? "\"" : "");

		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static bool
dump_factory(struct data *data, struct global *global,
	     enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_factory_info *info;
	const char *ind;
	const char *module_id, *module_name;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sname: \"%s\"\n", ind, info->name);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
	} else {
		fprintf(stdout, " n=\"%s\"", info->name);

		module_id = spa_dict_lookup(info->props, PW_KEY_MODULE_ID);
		module_name = module_id ? obj_lookup(rd, atoi(module_id), PW_KEY_MODULE_NAME) : NULL;

		fprintf(stdout, "%s%s%s",
				module_name ? " m=\"" : "",
				module_name ? module_name : "",
				module_name ? "\"" : "");

		fprintf(stdout, "\n");
	}

	return true;
}

static bool
dump_client(struct data *data, struct global *global,
	    enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_client_info *info;
	const char *ind;
	const char *app_name, *app_pid;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
	} else {
		app_name = spa_dict_lookup(info->props, PW_KEY_APP_NAME);
		app_pid = spa_dict_lookup(info->props, PW_KEY_APP_PROCESS_ID);

		fprintf(stdout, "%s%s%s" "%s%s%s",
				app_name ? " ap=\"" : "",
				app_name ? app_name : "",
				app_name ? "\"" : "",
				app_pid ? " ai=\"" : "",
				app_pid ? app_pid : "",
				app_pid ? "\"" : "");

		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static bool
dump_link(struct data *data, struct global *global,
	  enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_link_info *info;
	const char *ind;
	const char *in_node_name, *in_port_name;
	const char *out_node_name, *out_port_name;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%soutput-node-id: %u\n", ind, info->output_node_id);
		fprintf(stdout, "%soutput-port-id: %u\n", ind, info->output_port_id);
		fprintf(stdout, "%sinput-node-id: %u\n", ind, info->input_node_id);
		fprintf(stdout, "%sinput-port-id: %u\n", ind, info->input_port_id);

		fprintf(stdout, "%sstate: \"%s\"", ind,
				pw_link_state_as_string(info->state));
		if (info->state == PW_LINK_STATE_ERROR && info->error)
			printf(" \"%s\"\n", info->error);
		else
			printf("\n");
		fprintf(stdout, "%sformat:\n", ind);
		if (info->format)
			spa_debug_pod(8 * (level + 1) + 2, NULL, info->format);
		else
			fprintf(stdout, "%s\tnone\n", ind);

		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
	} else {
		out_node_name = obj_lookup(rd, info->output_node_id, PW_KEY_NODE_NAME);
		in_node_name = obj_lookup(rd, info->input_node_id, PW_KEY_NODE_NAME);
		out_port_name = obj_lookup(rd, info->output_port_id, PW_KEY_PORT_NAME);
		in_port_name = obj_lookup(rd, info->input_port_id, PW_KEY_PORT_NAME);

		fprintf(stdout, " s=\"%s\"", pw_link_state_as_string(info->state));

		if (out_node_name && out_port_name)
			fprintf(stdout, " on=\"%s\"" " op=\"%s\"",
					out_node_name, out_port_name);
		if (in_node_name && in_port_name)
			fprintf(stdout, " in=\"%s\"" " ip=\"%s\"",
					in_node_name, in_port_name);

		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static bool
dump_session(struct data *data, struct global *global,
	     enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_session_info *info;
	const char *ind;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static bool
dump_endpoint(struct data *data, struct global *global,
	      enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_endpoint_info *info;
	const char *ind;
	const char *direction;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	switch(info->direction) {
	case PW_DIRECTION_OUTPUT:
		direction = "source";
		break;
	case PW_DIRECTION_INPUT:
		direction = "sink";
		break;
	default:
		direction = "invalid";
		break;
	}

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sname: %s\n", ind, info->name);
		fprintf(stdout, "%smedia-class: %s\n", ind, info->media_class);
		fprintf(stdout, "%sdirection: %s\n", ind, direction);
		fprintf(stdout, "%sflags: 0x%x\n", ind, info->flags);
		fprintf(stdout, "%sstreams: %u\n", ind, info->n_streams);
		fprintf(stdout, "%ssession: %u\n", ind, info->session_id);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		fprintf(stdout, " n=\"%s\" c=\"%s\" d=\"%s\" s=%u si=%"PRIu32"",
				info->name, info->media_class, direction,
				info->n_streams, info->session_id);
		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static bool
dump_endpoint_stream(struct data *data, struct global *global,
		     enum dump_flags flags, int level)
{
	struct remote_data *rd = data->current;
	struct proxy_data *pd = pw_proxy_get_user_data(global->proxy);
	struct pw_endpoint_stream_info *info;
	const char *ind;

	if (!pd->info)
		return false;

	dump_global_common(data, global, flags, level);

	info = pd->info;

	if (!(flags & is_short)) {
		ind = INDENT(level + 1);
		fprintf(stdout, "%sid: %u\n", ind, info->id);
		fprintf(stdout, "%sendpoint-id: %u\n", ind, info->endpoint_id);
		fprintf(stdout, "%sname: %s\n", ind, info->name);
		fprintf(stdout, "%sproperties:\n", ind);
		dump_properties(data, global, flags, level);
		fprintf(stdout, "%sparams:\n", ind);
		dump_params(data, global, info->params, info->n_params, flags, level);
	} else {
		fprintf(stdout, " n=\"%s\" i=%"PRIu32" ei=%"PRIu32"",
				info->name, info->id, info->endpoint_id);
		fprintf(stdout, "\n");
	}

	(void)rd;

	return true;
}

static void
dump(struct data *data, struct global *global,
     enum dump_flags flags, int level)
{
	if (!global)
		return;

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Core))
		dump_core(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Module))
		dump_module(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Device))
		dump_device(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Node))
		dump_node(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Port))
		dump_port(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Factory))
		dump_factory(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Client))
		dump_client(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Link))
		dump_link(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Session))
		dump_session(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_Endpoint))
		dump_endpoint(data, global, flags, level);

	if (!strcmp(global->type, PW_TYPE_INTERFACE_EndpointStream))
		dump_endpoint_stream(data, global, flags, level);
}

static bool do_dump(struct data *data, const char *cmd, char *args, char **error)
{
	struct remote_data *rd = data->current;
	union pw_map_item *item;
	struct global *global;
	char *aa[32], **a;
	char c;
	int i, n, idx;
	enum dump_flags flags = is_default;
	bool match;
	unsigned int type_mask;

	n = pw_split_ip(args, WHITESPACE, SPA_N_ELEMENTS(aa), aa);
	if (n < 0)
		goto usage;

	a = aa;
	while (n > 0 &&
		(!strcmp(a[0], "short") ||
		 !strcmp(a[0], "deep") ||
		 !strcmp(a[0], "resolve") ||
		 !strcmp(a[0], "notype"))) {
		if (!strcmp(a[0], "short"))
			flags |= is_short;
		else if (!strcmp(a[0], "deep"))
			flags |= is_deep;
		else if (!strcmp(a[0], "resolve"))
			flags |= is_resolve;
		else if (!strcmp(a[0], "notype"))
			flags |= is_notype;
		n--;
		a++;
	}

	while (n > 0 && a[0][0] == '-') {
		for (i = 1; (c = a[0][i]) != '\0'; i++) {
			if (c == 's')
				flags |= is_short;
			else if (c == 'd')
				flags |= is_deep;
			else if (c == 'r')
				flags |= is_resolve;
			else if (c == 't')
				flags |= is_notype;
			else
				goto usage;
		}
		n--;
		a++;
	}

	if (n == 0 || !strcmp(a[0], "all")) {
		type_mask = (1U << dump_type_count()) - 1;
		flags &= ~is_notype;
	} else {
		type_mask = 0;
		for (i = 0; i < n; i++) {
			/* skip direct IDs */
			if (isdigit(a[i][0]))
				continue;
			idx = dump_type_index(name_to_dump_type(a[i]));
			if (idx < 0)
				goto usage;
			type_mask |= 1U << idx;
		}

		/* single bit set? disable type */
		if ((type_mask & (type_mask - 1)) == 0)
			flags |= is_notype;
	}

	pw_array_for_each(item, &rd->globals.items) {
		if (pw_map_item_is_free(item) || item->data == NULL)
			continue;

		global = item->data;

		/* unknown type, ignore completely */
		idx = dump_type_index(global->type);
		if (idx < 0)
			continue;

		match = false;

		/* first check direct ids */
		for (i = 0; i < n; i++) {
			/* skip non direct IDs */
			if (!isdigit(a[i][0]))
				continue;
			if (atoi(a[i]) == (int)global->id) {
				match = true;
				break;
			}
		}

		/* if type match */
		if (!match && (type_mask & (1U << idx)))
			match = true;

		if (!match)
			continue;

		dump(data, global, flags, 0);
	}

	return true;
usage:
	*error = spa_aprintf("%s [short|deep|resolve|notype] [-sdrt] [all|%s|<id>]",
			cmd, DUMP_NAMES);
	return false;
}

static bool parse(struct data *data, char *buf, size_t size, char **error)
{
	char *a[2];
	int n;
	size_t i;
	char *p, *cmd, *args;

	if ((p = strchr(buf, '#')))
		*p = '\0';

	p = pw_strip(buf, "\n\r \t");

	if (*p == '\0')
		return true;

	n = pw_split_ip(p, WHITESPACE, 2, a);
	if (n < 1)
		return true;

	cmd = a[0];
	args = n > 1 ? a[1] : "";

	for (i = 0; i < SPA_N_ELEMENTS(command_list); i++) {
		if (!strcmp(command_list[i].name, cmd) ||
		    !strcmp(command_list[i].alias, cmd)) {
			return command_list[i].func(data, cmd, args, error);
		}
	}
        *error = spa_aprintf("Command \"%s\" does not exist. Type 'help' for usage.", cmd);
	return false;
}

static void do_input(void *data, int fd, uint32_t mask)
{
	struct data *d = data;
	char buf[4096], *error;
	ssize_t r;

	if (mask & SPA_IO_IN) {
		while (true) {
			r = read(fd, buf, sizeof(buf)-1);
			if (r < 0) {
				if (errno == EAGAIN)
					continue;
				perror("read");
				r = 0;
				break;
			}
			break;
		}
		if (r == 0) {
			fprintf(stdout, "\n");
			pw_main_loop_quit(d->loop);
			return;
		}
		buf[r] = '\0';

		if (!parse(d, buf, r, &error)) {
			fprintf(stdout, "Error: \"%s\"\n", error);
			free(error);
		}
		if (d->current == NULL)
			pw_main_loop_quit(d->loop);
		else  {
			struct remote_data *rd = d->current;
			if (rd->core)
				rd->prompt_pending = pw_core_sync(rd->core, 0, 0);
		}
	}
}

static void do_quit(void *data, int signal_number)
{
	struct data *d = data;
	d->quit = true;
	pw_main_loop_quit(d->loop);
}

static void show_help(struct data *data, const char *name)
{
        fprintf(stdout, _("%s [options] [command]\n"
		"  -h, --help                            Show this help\n"
		"      --version                         Show version\n"
		"  -d, --daemon                          Start as daemon (Default false)\n"
		"  -r, --remote                          Remote daemon name\n\n"),
		name);

	do_help(data, "help", "", NULL);
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	struct pw_loop *l;
	char *opt_remote = NULL;
	char *error;
	bool daemon = false;
	struct remote_data *rd;
	static const struct option long_options[] = {
		{ "help",	no_argument,		 NULL, 'h' },
		{ "version",	no_argument,		 NULL, 'V' },
		{ "daemon",	no_argument,		 NULL, 'd' },
		{ "remote",	required_argument,	 NULL, 'r' },
		{ NULL,	0, NULL, 0}
	};
	int c, i;

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVdr:", long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			show_help(&data, argv[0]);
			return 0;
		case 'V':
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				argv[0],
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;
		case 'd':
			daemon = true;
			break;
		case 'r':
			opt_remote = optarg;
			break;
		default:
			show_help(&data, argv[0]);
			return -1;
		}
	}

	data.loop = pw_main_loop_new(NULL);
	if (data.loop == NULL) {
		fprintf(stderr, "Broken installation: %m\n");
		return -1;
	}
	l = pw_main_loop_get_loop(data.loop);
	pw_loop_add_signal(l, SIGINT, do_quit, &data);
	pw_loop_add_signal(l, SIGTERM, do_quit, &data);

	spa_list_init(&data.remotes);
	pw_map_init(&data.vars, 64, 16);

	data.context = pw_context_new(l,
			pw_properties_new(
				PW_KEY_CORE_DAEMON, daemon ? "true" : NULL,
				NULL),
			0);

	pw_context_load_module(data.context, "libpipewire-module-link-factory", NULL, NULL);

	if (!do_connect(&data, "connect", opt_remote, &error)) {
		fprintf(stderr, "Error: \"%s\"\n", error);
		return -1;
	}

	if (optind == argc) {
		data.interactive = true;

		pw_loop_add_io(l, STDIN_FILENO, SPA_IO_IN|SPA_IO_HUP, false, do_input, &data);

		fprintf(stdout, "Welcome to PipeWire version %s. Type 'help' for usage.\n",
				pw_get_library_version());

		pw_main_loop_run(data.loop);
	} else {
		char buf[4096], *p, *error;

		p = buf;
		for (i = optind; i < argc; i++) {
			p = stpcpy(p, argv[i]);
			p = stpcpy(p, " ");
		}

		pw_main_loop_run(data.loop);

		if (!parse(&data, buf, p - buf, &error)) {
			fprintf(stdout, "Error: \"%s\"\n", error);
			free(error);
		}
		if (!data.quit && data.current) {
			data.current->prompt_pending = pw_core_sync(data.current->core, 0, 0);
			pw_main_loop_run(data.loop);
		}
	}
	spa_list_consume(rd, &data.remotes, link)
		remote_data_free(rd);

	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);
	pw_map_clear(&data.vars);
	pw_deinit();

	return 0;
}
