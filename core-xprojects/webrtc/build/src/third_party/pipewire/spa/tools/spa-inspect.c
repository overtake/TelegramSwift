/* Simple Plugin API
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>

#include <spa/support/plugin.h>
#include <spa/support/log-impl.h>
#include <spa/support/loop.h>
#include <spa/utils/result.h>
#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/pod/parser.h>
#include <spa/param/param.h>
#include <spa/param/format.h>
#include <spa/debug/dict.h>
#include <spa/debug/pod.h>
#include <spa/debug/format.h>
#include <spa/debug/types.h>

static SPA_LOG_IMPL(default_log);

struct data {
	struct spa_support support[4];
	uint32_t n_support;
	struct spa_log *log;
	struct spa_loop loop;
	struct spa_node *node;
	struct spa_hook listener;
};

static void print_param(void *data, int seq, int res, uint32_t type, const void *result)
{
	switch (type) {
	case SPA_RESULT_TYPE_NODE_PARAMS:
	{
		const struct spa_result_node_params *r = result;

		if (spa_pod_is_object_type(r->param, SPA_TYPE_OBJECT_Format))
			spa_debug_format(16, NULL, r->param);
		else
			spa_debug_pod(16, NULL, r->param);
		break;
	}
	default:
		break;
	}
}

static void
inspect_node_params(struct data *data, struct spa_node *node,
		uint32_t n_params, struct spa_param_info *params)
{
	int res;
	uint32_t i;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.result = print_param,
	};

	for (i = 0; i < n_params; i++) {
		printf("enumerating: %s:\n", spa_debug_type_find_name(spa_type_param, params[i].id));

		if (!SPA_FLAG_IS_SET(params[i].flags, SPA_PARAM_INFO_READ))
			continue;

		spa_zero(listener);
		spa_node_add_listener(node, &listener, &node_events, data);
		res = spa_node_enum_params(node, 0, params[i].id, 0, UINT32_MAX, NULL);
		spa_hook_remove(&listener);

		if (res != 0) {
			printf("error enum_params %d: %s", params[i].id, spa_strerror(res));
			break;
		}
	}
}

static void
inspect_port_params(struct data *data, struct spa_node *node,
		    enum spa_direction direction, uint32_t port_id,
		    uint32_t n_params, struct spa_param_info *params)
{
	int res;
	uint32_t i;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.result = print_param,
	};

	for (i = 0; i < n_params; i++) {
		printf("param: %s: flags %c%c\n",
				spa_debug_type_find_name(spa_type_param, params[i].id),
				params[i].flags & SPA_PARAM_INFO_READ ? 'r' : '-',
				params[i].flags & SPA_PARAM_INFO_WRITE ? 'w' : '-');

		if (!SPA_FLAG_IS_SET(params[i].flags, SPA_PARAM_INFO_READ))
			continue;

		printf("values:\n");
		spa_zero(listener);
		spa_node_add_listener(node, &listener, &node_events, data);
		res = spa_node_port_enum_params(node, 0,
				direction, port_id,
				params[i].id, 0, UINT32_MAX,
				NULL);
		spa_hook_remove(&listener);

		if (res != 0) {
			printf("error port_enum_params %d: %s", params[i].id, spa_strerror(res));
			break;
		}
	}
}

static void node_info(void *_data, const struct spa_node_info *info)
{
	struct data *data = _data;

	printf("node info: %08"PRIx64"\n", info->change_mask);
	printf("max input ports: %u\n", info->max_input_ports);
	printf("max output ports: %u\n", info->max_output_ports);

	if (info->change_mask & SPA_NODE_CHANGE_MASK_PROPS) {
		printf("node properties:\n");
		spa_debug_dict(2, info->props);
	}
	if (info->change_mask & SPA_NODE_CHANGE_MASK_PARAMS) {
		inspect_node_params(data, data->node, info->n_params, info->params);
	}
}

static void node_port_info(void *_data, enum spa_direction direction, uint32_t id,
		const struct spa_port_info *info)
{
	struct data *data = _data;

	printf(" %s port: %08x",
		direction == SPA_DIRECTION_INPUT ? "input" : "output",
		id);

	if (info == NULL) {
		printf(" removed\n");
	}
	else {
		printf(" info:\n");
		if (info->change_mask & SPA_PORT_CHANGE_MASK_PROPS) {
			printf("port properties:\n");
			spa_debug_dict(2, info->props);
		}
		if (info->change_mask & SPA_PORT_CHANGE_MASK_PARAMS) {
			inspect_port_params(data, data->node, direction, id,
					info->n_params, info->params);
		}
	}
}

static const struct spa_node_events node_events =
{
	SPA_VERSION_NODE_EVENTS,
	.info = node_info,
	.port_info = node_port_info,
};

static void inspect_node(struct data *data, struct spa_node *node)
{
	data->node = node;
	spa_node_add_listener(node, &data->listener, &node_events, data);
	spa_hook_remove(&data->listener);
}

static void inspect_factory(struct data *data, const struct spa_handle_factory *factory)
{
	int res;
	struct spa_handle *handle;
	void *interface;
	const struct spa_interface_info *info;
	uint32_t index;

	printf("factory version:\t\t%d\n", factory->version);
	printf("factory name:\t\t'%s'\n", factory->name);
	if (factory->version < 1) {
		printf("\tno further info for version %d < 1\n", factory->version);
		return;
	}

	printf("factory info:\n");
	if (factory->info)
		spa_debug_dict(2, factory->info);
	else
		printf("  none\n");

	printf("factory interfaces:\n");
	for (index = 0;;) {
		if ((res = spa_handle_factory_enum_interface_info(factory, &info, &index)) <= 0) {
			if (res != 0)
				printf("error spa_handle_factory_enum_interface_info: %s",
						 spa_strerror(res));
			break;
		}
		printf(" interface: '%s'\n", info->type);
	}

	handle = calloc(1, spa_handle_factory_get_size(factory, NULL));
	if ((res =
	     spa_handle_factory_init(factory, handle, NULL, data->support, data->n_support)) < 0) {
		printf("can't make factory instance: %d\n", res);
		return;
	}

	printf("factory instance:\n");

	for (index = 0;;) {
		if ((res = spa_handle_factory_enum_interface_info(factory, &info, &index)) <= 0) {
			if (res != 0)
				printf("error spa_handle_factory_enum_interface_info: %s",
						 spa_strerror(res));
			break;
		}
		printf(" interface: '%s'\n", info->type);

		if ((res = spa_handle_get_interface(handle, info->type, &interface)) < 0) {
			printf("can't get interface: %s: %d\n", info->type, res);
			continue;
		}

		if (strcmp(info->type, SPA_TYPE_INTERFACE_Node) == 0)
			inspect_node(data, interface);
		else
			printf("skipping unknown interface\n");
	}
}

static const struct spa_loop_methods impl_loop = {
	SPA_VERSION_LOOP_METHODS,
};

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	int res;
	void *handle;
	spa_handle_factory_enum_func_t enum_func;
	uint32_t index;
	const char *str;

	if (argc < 2) {
		printf("usage: %s <plugin.so>\n", argv[0]);
		return -1;
	}

	data.log = &default_log.log;
	data.loop.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Loop,
			SPA_VERSION_LOOP,
			&impl_loop, &data);

	if ((str = getenv("SPA_DEBUG")))
		data.log->level = atoi(str);

	data.support[0] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, data.log);
	data.support[1] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Loop, &data.loop);
	data.support[2] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataLoop, &data.loop);
	data.n_support = 3;

	if ((handle = dlopen(argv[1], RTLD_NOW)) == NULL) {
		printf("can't load %s\n", argv[1]);
		return -1;
	}
	if ((enum_func = dlsym(handle, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		printf("can't find function\n");
		return -1;
	}

	for (index = 0;;) {
		const struct spa_handle_factory *factory;

		if ((res = enum_func(&factory, &index)) <= 0) {
			if (res != 0)
				printf("error enum_func: %s", spa_strerror(res));
			break;
		}
		inspect_factory(&data, factory);
	}
	return 0;
}
