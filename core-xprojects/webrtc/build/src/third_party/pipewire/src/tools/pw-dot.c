/* PipeWire
 *
 * Copyright © 2019 Collabora Ltd.
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

#define GLOBAL_ID_NONE UINT32_MAX
#define DEFAULT_DOT_PATH "pw.dot"

struct global;

typedef void (*draw_t)(struct global *g);
typedef void *(*info_update_t) (void *info, const void *update);

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct spa_list globals;
	char *dot_str;
	const char *dot_rankdir;
	bool dot_orthoedges;

	bool show_all;
	bool show_smart;
	bool show_detail;
};

struct global {
	struct spa_list link;

	struct data *data;
	struct pw_proxy *proxy;

	uint32_t id;
#define INTERFACE_Port		0
#define INTERFACE_Node		1
#define INTERFACE_Link		2
#define INTERFACE_Client	3
#define INTERFACE_Device	4
#define INTERFACE_Module	5
#define INTERFACE_Factory	6
	uint32_t type;
	struct pw_properties *props;
	void *info;

	pw_destroy_t info_destroy;
	info_update_t info_update;
	draw_t draw;

	struct spa_hook proxy_listener;
	struct spa_hook object_listener;
};

static char *dot_str_new()
{
        return strdup("");
}

static void dot_str_clear(char **str)
{
	if (str && *str) {
		  free(*str);
		  *str = NULL;
	}
}

static SPA_PRINTF_FUNC(2,0) void dot_str_vadd(char **str, const char *fmt, va_list varargs)
{
	char *res = NULL;
	char *fmt2 = NULL;

	spa_return_if_fail(str != NULL);
	spa_return_if_fail(fmt != NULL);

	if (asprintf(&fmt2, "%s%s", *str, fmt) < 0) {
		spa_assert_not_reached();
		return;
	}

	if (vasprintf(&res, fmt2, varargs) < 0) {
		free (fmt2);
		spa_assert_not_reached();
		return;
	}
	free (fmt2);

	free(*str);
	*str = res;
}

static SPA_PRINTF_FUNC(2,3) void dot_str_add(char **str, const char *fmt, ...)
{
	va_list varargs;
	va_start(varargs, fmt);
	dot_str_vadd(str, fmt, varargs);
	va_end(varargs);
}

static void draw_dict(char **str, const char *title,
		      const struct spa_dict *props)
{
	const struct spa_dict_item *item;

	dot_str_add(str, "%s:\\l", title);
	if (props == NULL || props->n_items == 0) {
		dot_str_add(str, "- none\\l");
		return;
	}

	spa_dict_for_each(item, props) {
		if (item->value)
			dot_str_add(str, "- %s: %s\\l", item->key, item->value);
		else
			dot_str_add(str, "- %s: (null)\\l", item->key);
	}
}

static SPA_PRINTF_FUNC(7,0) void draw_vlabel(char **str, const char *name, uint32_t id, bool detail,
		       const struct spa_dict *info_p, const struct spa_dict *p,
		       const char *fmt, va_list varargs)
{
	/* draw the label header */
	dot_str_add(str, "%s_%u [label=\"", name, id);

	/* draw the label body */
	dot_str_vadd(str, fmt, varargs);

	if (detail) {
		draw_dict(str, "info_props", info_p);
		draw_dict(str, "properties", p);
	}

	/*draw the label footer */
	dot_str_add(str, "%s", "\"];\n");
}

static SPA_PRINTF_FUNC(7,8) void draw_label(char **str, const char *name, uint32_t id, bool detail,
		       const struct spa_dict *info_p, const struct spa_dict *p,
		       const char *fmt, ...)
{
	va_list varargs;
	va_start(varargs, fmt);
	draw_vlabel(str, name, id, detail, info_p, p, fmt, varargs);
	va_end(varargs);
}

static void draw_port(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Port);

	struct pw_port_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	/* draw the box */
	dot_str_add(dot_str,
		"port_%u [shape=box style=filled fillcolor=%s];\n",
		g->id,
		info->direction == PW_DIRECTION_INPUT ? "lightslateblue" : "lightcoral"
	);

	/* draw the label */
	draw_label(dot_str,
		"port", g->id, g->data->show_detail, info->props, &g->props->dict,
		"port_id: %u\\lname: %s\\ldirection: %s\\l",
		g->id,
		spa_dict_lookup(info->props, PW_KEY_PORT_NAME),
		pw_direction_as_string(info->direction)
	);
}


static void draw_node(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Node);

	struct pw_node_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	const char *client_id_str, *factory_id_str;
	uint32_t client_id, factory_id;

	client_id_str = spa_dict_lookup(info->props, PW_KEY_CLIENT_ID);
	factory_id_str = spa_dict_lookup(info->props, PW_KEY_FACTORY_ID);
	client_id = client_id_str ? (uint32_t)atoi(client_id_str) : GLOBAL_ID_NONE;
	factory_id = factory_id_str ? (uint32_t)atoi(factory_id_str) : GLOBAL_ID_NONE;

	/* draw the node header */
	dot_str_add(dot_str, "subgraph cluster_node_%u {\n", g->id);
	dot_str_add(dot_str, "bgcolor=palegreen;\n");

	/* draw the label header */
	dot_str_add(dot_str, "label=\"");

	/* draw the label body */
	dot_str_add(dot_str, "node_id: %u\\lname: %s\\lmedia_class: %s\\l",
		g->id,
		spa_dict_lookup(info->props, PW_KEY_NODE_NAME),
		spa_dict_lookup(info->props, PW_KEY_MEDIA_CLASS));
	if (g->data->show_detail) {
		draw_dict(dot_str, "info_props", info->props);
		draw_dict(dot_str, "properties", &g->props->dict);
	}

	/*draw the label footer */
	dot_str_add(dot_str, "%s", "\"\n");

	/* draw all node ports */
	struct global *p;
	const char *prop_node_id;
	spa_list_for_each(p, &g->data->globals, link) {
		if (p->info == NULL)
			continue;
		if (p->type != INTERFACE_Port)
			continue;
		prop_node_id = pw_properties_get(p->props, PW_KEY_NODE_ID);
		if (!prop_node_id || (uint32_t)atoi(prop_node_id) != g->id)
			continue;
		if (p->draw)
			p->draw(p);
	}

	/* draw the client/factory box if all option is enabled */
	if (g->data->show_all) {
		dot_str_add(dot_str, "node_%u [shape=box style=filled fillcolor=white];\n", g->id);
		dot_str_add(dot_str, "node_%u [label=\"client_id: %u\\lfactory_id: %u\\l\"];\n", g->id, client_id, factory_id);
	}

	/* draw the node footer */
	dot_str_add(dot_str, "}\n");

	/* draw the client/factory arrows if all option is enabled */
	if (g->data->show_all) {
		dot_str_add(dot_str, "node_%u -> client_%u [style=dashed];\n", g->id, client_id);
		dot_str_add(dot_str, "node_%u -> factory_%u [style=dashed];\n", g->id, factory_id);
	}
}

static void draw_link(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Link);

	struct pw_link_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	/* draw the box */
	dot_str_add(dot_str, "link_%u [shape=box style=filled fillcolor=lightblue];\n", g->id);

	/* draw the label */
	draw_label(dot_str,
		"link", g->id, g->data->show_detail, info->props, &g->props->dict,
		"link_id: %u\\loutput_node_id: %u\\linput_node_id: %u\\loutput_port_id: %u\\linput_port_id: %u\\lstate: %s\\l",
		g->id,
		info->output_node_id,
		info->input_node_id,
		info->output_port_id,
		info->input_port_id,
		pw_link_state_as_string(info->state)
	);

	/* draw the arrows */
	dot_str_add(dot_str, "port_%u -> link_%u -> port_%u;\n", info->output_port_id, g->id, info->input_port_id);
}

static void draw_client(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Client);

	struct pw_client_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	/* draw the box */
	dot_str_add(dot_str, "client_%u [shape=box style=filled fillcolor=tan1];\n", g->id);

	/* draw the label */
	draw_label(dot_str,
		"client", g->id, g->data->show_detail, info->props, &g->props->dict,
		"client_id: %u\\lname: %s\\lpid: %s\\l",
		g->id,
		spa_dict_lookup(info->props, PW_KEY_APP_NAME),
		spa_dict_lookup(info->props, PW_KEY_APP_PROCESS_ID)
	);
}

static void draw_device(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Device);

	struct pw_device_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	const char *client_id_str = spa_dict_lookup(info->props, PW_KEY_CLIENT_ID);
	const char *factory_id_str = spa_dict_lookup(info->props, PW_KEY_FACTORY_ID);
	uint32_t client_id = client_id_str ? (uint32_t)atoi(client_id_str) : GLOBAL_ID_NONE;
	uint32_t factory_id = factory_id_str ? (uint32_t)atoi(factory_id_str) : GLOBAL_ID_NONE;

	/* draw the box */
	dot_str_add(dot_str, "device_%u [shape=box style=filled fillcolor=lightpink];\n", g->id);

	/* draw the label */
	draw_label(dot_str,
		"device", g->id, g->data->show_detail, info->props, &g->props->dict,
		"device_id: %u\\lname: %s\\lmedia_class: %s\\lapi: %s\\lpath: %s\\l",
		g->id,
		spa_dict_lookup(info->props, PW_KEY_DEVICE_NAME),
		spa_dict_lookup(info->props, PW_KEY_MEDIA_CLASS),
		spa_dict_lookup(info->props, PW_KEY_DEVICE_API),
		spa_dict_lookup(info->props, PW_KEY_OBJECT_PATH)
	);

	/* draw the arrows */
	dot_str_add(dot_str, "device_%u -> client_%u [style=dashed];\n", g->id, client_id);
	dot_str_add(dot_str, "device_%u -> factory_%u [style=dashed];\n", g->id, factory_id);
}

static void draw_factory(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Factory);

	struct pw_factory_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	const char *module_id_str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID);
	uint32_t module_id = module_id_str ? (uint32_t)atoi(module_id_str) : GLOBAL_ID_NONE;

	/* draw the box */
	dot_str_add(dot_str, "factory_%u [shape=box style=filled fillcolor=lightyellow];\n", g->id);

	/* draw the label */
	draw_label(dot_str,
		"factory", g->id, g->data->show_detail, info->props, &g->props->dict,
		"factory_id: %u\\lname: %s\\lmodule_id: %u\\l",
		g->id, info->name, module_id
	);

	/* draw the arrow */
	dot_str_add(dot_str, "factory_%u -> module_%u [style=dashed];\n", g->id, module_id);
}

static void draw_module(struct global *g)
{
	spa_assert(g != NULL);
	spa_assert(g->info != NULL);
	spa_assert(g->type == INTERFACE_Module);

	struct pw_module_info *info = g->info;
	char **dot_str = &g->data->dot_str;

	/* draw the box */
	dot_str_add(dot_str, "module_%u [shape=box style=filled fillcolor=lightgrey];\n", g->id);

	/* draw the label */
	draw_label(dot_str,
		"module", g->id, g->data->show_detail, info->props, &g->props->dict,
		"module_id: %u\\lname: %s\\l",
		g->id, info->name
	);
}

static bool is_node_id_link_referenced(uint32_t id, struct spa_list *globals)
{
        struct global *g;
        struct pw_link_info *info;
        spa_list_for_each(g, globals, link) {
                if (g->info == NULL)
                        continue;
                if (g->type != INTERFACE_Link)
                        continue;
                info = g->info;
                if (info->input_node_id == id || info->output_node_id == id)
                        return true;
        }
        return false;
}

static bool is_module_id_factory_referenced(uint32_t id, struct spa_list *globals)
{
        struct global *g;
        struct pw_factory_info *info;
        const char *module_id_str;
        spa_list_for_each(g, globals, link) {
                if (g->info == NULL)
                        continue;
                if (g->type != INTERFACE_Factory)
                        continue;
                info = g->info;
                module_id_str = spa_dict_lookup(info->props, PW_KEY_MODULE_ID);
                if (module_id_str && (uint32_t)atoi(module_id_str) == id)
                        return true;
        }
        return false;
}

static bool is_global_referenced(struct global *g)
{
	switch (g->type) {
	case INTERFACE_Node:
		return is_node_id_link_referenced(g->id, &g->data->globals);
	case INTERFACE_Module:
		return is_module_id_factory_referenced(g->id, &g->data->globals);
	default:
		break;
	}

	return true;
}

static int draw_graph(struct data *d, const char *path)
{
	FILE *fp;
	struct global *g;

	/* draw the header */
	dot_str_add(&d->dot_str, "digraph pipewire {\n");

	if (d->dot_rankdir) {
		/* set rank direction, if provided */
		dot_str_add(&d->dot_str, "rankdir = \"%s\";\n", d->dot_rankdir);
	}

	if (d->dot_orthoedges) {
		/* enable orthogonal edges */
		dot_str_add(&d->dot_str, "splines = ortho;\n");
	}

	/* iterate the globals */
	spa_list_for_each(g, &d->globals, link) {
		/* skip null and non-info globals */
		if (g->info == NULL)
			continue;

		/* always skip ports since they are drawn by the nodes */
		if (g->type == INTERFACE_Port)
			continue;

		/* skip clients, devices, factories and modules if all option is disabled */
		if (!d->show_all) {
			switch (g->type) {
				case INTERFACE_Client:
				case INTERFACE_Device:
				case INTERFACE_Factory:
				case INTERFACE_Module:
					continue;
				default:
					break;
			}
		}

		/* skip not referenced globals if smart option is enabled */
		if (d->show_smart && !is_global_referenced(g))
			continue;

		/* draw the global */
		if (g->draw)
			g->draw(g);
	}

	/* draw the footer */
	dot_str_add(&d->dot_str, "}\n");

	if (strcmp(path, "-") == 0) {
		/* wire the dot graph into to stdout */
		fputs(d->dot_str, stdout);
	} else {
		/* open the file */
		fp = fopen(path, "w");
		if (fp == NULL) {
			printf("open error: could not open %s for writing\n", path);
			return -1;
		}

		/* wire the dot graph into the file */
		fputs(d->dot_str, fp);
		fclose(fp);
	}
	return 0;
}

static void global_event_info(struct global *g, const void *info)
{
        if (g->info_update)
                g->info = g->info_update(g->info, info);
}

static void port_event_info(void *data, const struct pw_port_info *info)
{
        global_event_info(data, info);
}

static const struct pw_port_events port_events = {
        PW_VERSION_PORT_EVENTS,
        .info = port_event_info,
};

static void node_event_info(void *data, const struct pw_node_info *info)
{
	global_event_info(data, info);
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
	.info = node_event_info,
};

static void link_event_info(void *data, const struct pw_link_info *info)
{
	global_event_info(data, info);
}

static const struct pw_link_events link_events = {
	PW_VERSION_LINK_EVENTS,
	.info = link_event_info
};

static void client_event_info(void *data, const struct pw_client_info *info)
{
	global_event_info(data, info);
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_event_info
};

static void device_event_info(void *data, const struct pw_device_info *info)
{
	global_event_info(data, info);
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info
};

static void factory_event_info(void *data, const struct pw_factory_info *info)
{
	global_event_info(data, info);
}

static const struct pw_factory_events factory_events = {
	PW_VERSION_FACTORY_EVENTS,
	.info = factory_event_info
};

static void module_event_info(void *data, const struct pw_module_info *info)
{
	global_event_info(data, info);
}

static const struct pw_module_events module_events = {
	PW_VERSION_MODULE_EVENTS,
	.info = module_event_info
};

static void removed_proxy(void *user_data)
{
	struct global *g = user_data;
	pw_proxy_destroy(g->proxy);
}

static void destroy_proxy(void *user_data)
{
	struct global *g = user_data;
	if (g->props)
		pw_properties_free(g->props);
	if (g->info)
		g->info_destroy(g->info);
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = removed_proxy,
	.destroy = destroy_proxy,
};

static void registry_event_global(void *data, uint32_t id, uint32_t permissions,
				  const char *type, uint32_t version,
				  const struct spa_dict *props)
{
        struct data *d = data;
        struct pw_proxy *proxy;
        uint32_t client_version;
	uint32_t object_type;
        const void *events;
        pw_destroy_t info_destroy;
        info_update_t info_update;
        draw_t draw;
        struct global *g;

	if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0) {
		events = &port_events;
		info_destroy = (pw_destroy_t)pw_port_info_free;
		info_update = (info_update_t)pw_port_info_update;
		draw = draw_port;
		client_version = PW_VERSION_PORT;
		object_type = INTERFACE_Port;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		events = &node_events;
		info_destroy = (pw_destroy_t)pw_node_info_free;
		info_update = (info_update_t)pw_node_info_update;
		draw = draw_node;
		client_version = PW_VERSION_NODE;
		object_type = INTERFACE_Node;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Link) == 0) {
		events = &link_events;
		info_destroy = (pw_destroy_t)pw_link_info_free;
		info_update = (info_update_t)pw_link_info_update;
		draw = draw_link;
		client_version = PW_VERSION_LINK;
		object_type = INTERFACE_Link;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0) {
		events = &client_events;
		info_destroy = (pw_destroy_t)pw_client_info_free;
		info_update = (info_update_t)pw_client_info_update;
		draw = draw_client;
		client_version = PW_VERSION_CLIENT;
		object_type = INTERFACE_Client;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Device) == 0) {
		events = &device_events;
		info_destroy = (pw_destroy_t)pw_device_info_free;
		info_update = (info_update_t)pw_device_info_update;
		draw = draw_device;
		client_version = PW_VERSION_DEVICE;
		object_type = INTERFACE_Device;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Factory) == 0) {
		events = &factory_events;
		info_destroy = (pw_destroy_t)pw_factory_info_free;
		info_update = (info_update_t)pw_factory_info_update;
		draw = draw_factory;
		client_version = PW_VERSION_FACTORY;
		object_type = INTERFACE_Factory;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Module) == 0) {
		events = &module_events;
		info_destroy = (pw_destroy_t)pw_module_info_free;
		info_update = (info_update_t)pw_module_info_update;
		draw = draw_module;
		client_version = PW_VERSION_MODULE;
		object_type = INTERFACE_Module;
	}
	else if (strcmp(type, PW_TYPE_INTERFACE_Core) == 0) {
		/* sync to notify we are done with globals */
		pw_core_sync(d->core, 0, 0);
		return;
	}
	else {
		return;
	}

        proxy = pw_registry_bind(d->registry, id, type,
				       client_version,
				       sizeof(struct global));
	if (proxy == NULL)
		return;

	/* set the global data */
	g = pw_proxy_get_user_data(proxy);
	g->data = d;
	g->proxy = proxy;

	g->id = id;
	g->type = object_type;
	g->props = props ? pw_properties_new_dict(props) : NULL;
	g->info = NULL;

	g->info_destroy = info_destroy;
	g->info_update = info_update;
	g->draw = draw;

        pw_proxy_add_object_listener(proxy, &g->object_listener, events, g);
        pw_proxy_add_listener(proxy, &g->proxy_listener, &proxy_events, g);

        /* add the global to the list */
        spa_list_insert(&d->globals, &g->link);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
};

static void on_core_done(void *data, uint32_t id, int seq)
{
	struct data *d = data;
	pw_main_loop_quit(d->loop);
}

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct data *d = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE)
		pw_main_loop_quit(d->loop);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
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
		"  -a, --all                             Show all object types\n"
		"  -s, --smart                           Show linked objects only\n"
		"  -d, --detail                          Show all object properties\n"
		"  -r, --remote                          Remote daemon name\n"
		"  -o, --output                          Output file (Default %s)\n"
		"  -L, --lr                              Use left-right rank direction\n"
		"  -9, --90                              Use orthogonal edges\n",
		name,
		DEFAULT_DOT_PATH);
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	struct pw_loop *l;
	const char *opt_remote = NULL;
	const char *dot_path = DEFAULT_DOT_PATH;
	static const struct option long_options[] = {
		{ "help",	no_argument,		NULL, 'h' },
		{ "version",	no_argument,		NULL, 'V' },
		{ "all",	no_argument,		NULL, 'a' },
		{ "smart",	no_argument,		NULL, 's' },
		{ "detail",	no_argument,		NULL, 'd' },
		{ "remote",	required_argument,	NULL, 'r' },
		{ "output",	required_argument,	NULL, 'o' },
		{ "lr",		no_argument,		NULL, 'L' },
		{ "90",		no_argument,		NULL, '9' },
		{ NULL, 0, NULL, 0}
	};
	int c;

	pw_init(&argc, &argv);

	while ((c = getopt_long(argc, argv, "hVasdr:o:L9", long_options, NULL)) != -1) {
		switch (c) {
		case 'h' :
			show_help(argv[0]);
			return 0;
		case 'V' :
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				argv[0],
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;
		case 'a' :
			data.show_all = true;
			fprintf(stderr, "all option enabled\n");
			break;
		case 's' :
			data.show_smart = true;
			fprintf(stderr, "smart option enabled\n");
			break;
		case 'd' :
			data.show_detail = true;
			fprintf(stderr, "detail option enabled\n");
			break;
		case 'r' :
			opt_remote = optarg;
			fprintf(stderr, "set remote to %s\n", opt_remote);
			break;
		case 'o' :
			dot_path = optarg;
			fprintf(stderr, "set output file %s\n", dot_path);
			break;
		case 'L' :
			data.dot_rankdir = "LR";
			fprintf(stderr, "set rank direction to LR\n");
			break;
		case '9' :
			data.dot_orthoedges = true;
			fprintf(stderr, "orthogonal edges enabled\n");
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

	data.core = pw_context_connect(data.context,
			pw_properties_new(
				PW_KEY_REMOTE_NAME, opt_remote,
				NULL),
			0);
	if (data.core == NULL) {
		fprintf(stderr, "can't connect: %m\n");
		return -1;
	}

	data.dot_str = dot_str_new();
	if (data.dot_str == NULL)
		return -1;

	spa_list_init(&data.globals);

	pw_core_add_listener(data.core,
				   &data.core_listener,
				   &core_events, &data);
	data.registry = pw_core_get_registry(data.core,
					  PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(data.registry,
				       &data.registry_listener,
				       &registry_events, &data);

	pw_main_loop_run(data.loop);

	draw_graph(&data, dot_path);

	dot_str_clear(&data.dot_str);
	pw_proxy_destroy((struct pw_proxy*)data.registry);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);
	pw_deinit();

	return 0;
}
