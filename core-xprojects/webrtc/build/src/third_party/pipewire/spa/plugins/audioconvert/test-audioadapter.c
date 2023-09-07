/* Spa
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#include <spa/utils/names.h>
#include <spa/support/plugin.h>
#include <spa/param/param.h>
#include <spa/param/audio/format.h>
#include <spa/param/audio/format-utils.h>
#include <spa/node/node.h>
#include <spa/debug/mem.h>
#include <spa/support/log-impl.h>

SPA_LOG_IMPL(logger);

extern const struct spa_handle_factory test_source_factory;

struct context {
	struct spa_handle *follower_handle;
	struct spa_node *follower_node;

	struct spa_handle *adapter_handle;
	struct spa_node *adapter_node;
};

static const struct spa_handle_factory *find_factory(const char *name)
{
	uint32_t index = 0;
	const struct spa_handle_factory *factory;

	while (spa_handle_factory_enum(&factory, &index) == 1) {
		if (strcmp(factory->name, name) == 0)
			return factory;
	}
	return NULL;
}

static int setup_context(struct context *ctx)
{
	size_t size;
	int res;
	struct spa_support support[1];
	struct spa_dict_item items[1];
	const struct spa_handle_factory *factory;
	char value[32];
	void *iface;

	logger.log.level = SPA_LOG_LEVEL_TRACE;
	support[0] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, &logger.log);

	/* make follower */
	factory = &test_source_factory;
	size = spa_handle_factory_get_size(factory, NULL);
	ctx->follower_handle = calloc(1, size);
	spa_assert(ctx->follower_handle != NULL);

	res = spa_handle_factory_init(factory,
			ctx->follower_handle,
			NULL, support, 1);
	spa_assert(res >= 0);

	res = spa_handle_get_interface(ctx->follower_handle,
			SPA_TYPE_INTERFACE_Node, &iface);
	spa_assert(res >= 0);

	ctx->follower_node = iface;

	/* make adapter */
	factory = find_factory(SPA_NAME_AUDIO_ADAPT);
	spa_assert(factory != NULL);

	size = spa_handle_factory_get_size(factory, NULL);

	ctx->adapter_handle = calloc(1, size);
	spa_assert(ctx->adapter_handle != NULL);

	snprintf(value, sizeof(value), "pointer:%p", ctx->follower_node);
	items[0] = SPA_DICT_ITEM_INIT("audio.adapt.follower", value);

	res = spa_handle_factory_init(factory,
			ctx->adapter_handle,
			&SPA_DICT_INIT(items, 1),
			support, 1);
	spa_assert(res >= 0);

	res = spa_handle_get_interface(ctx->adapter_handle,
			SPA_TYPE_INTERFACE_Node, &iface);
	spa_assert(res >= 0);
	ctx->adapter_node = iface;

	return 0;
}

static int clean_context(struct context *ctx)
{
	spa_handle_clear(ctx->adapter_handle);
	spa_handle_clear(ctx->follower_handle);
	free(ctx->adapter_handle);
	free(ctx->follower_handle);
	return 0;
}

static void node_info(void *data, const struct spa_node_info *info)
{
	fprintf(stderr, "input %d, output %d\n",
			info->max_input_ports,
			info->max_output_ports);

	spa_assert(info->max_input_ports == 0);
	spa_assert(info->max_output_ports > 0);
}

static void port_info_none(void *data,
		enum spa_direction direction, uint32_t port,
		const struct spa_port_info *info)
{
	spa_assert_not_reached();
}


static int test_init_state(struct context *ctx)
{
	struct spa_hook listener;
	static const struct spa_node_events init_events = {
		SPA_VERSION_NODE_EVENTS,
		.info = node_info,
		.port_info = port_info_none,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->adapter_node,
			&listener, &init_events, ctx);
	spa_hook_remove(&listener);

	return 0;
}

static void port_info_5_1(void *data,
		enum spa_direction direction, uint32_t port,
		const struct spa_port_info *info)
{
	spa_assert(direction == SPA_DIRECTION_OUTPUT);
	spa_assert(port < 6);
}

static int test_split_setup(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_5_1,
	};

	/* external format */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.channels = 6;
	info.rate = 48000;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	info.position[2] = SPA_AUDIO_CHANNEL_FC;
	info.position[3] = SPA_AUDIO_CHANNEL_LFE;
	info.position[4] = SPA_AUDIO_CHANNEL_SL;
	info.position[5] = SPA_AUDIO_CHANNEL_SR;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	spa_log_debug(&logger.log, "set profile %d@%d", info.channels, info.rate);
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_OUTPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));

	res = spa_node_set_param(ctx->adapter_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_zero(listener);
	spa_node_add_listener(ctx->adapter_node,
			&listener, &node_events, ctx);
	spa_hook_remove(&listener);

	/* internal format */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_S16;
	info.rate = 44100;
	info.channels = 2;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	spa_log_debug(&logger.log, "set format %d@%d", info.channels, info.rate);
	res = spa_node_set_param(ctx->adapter_node, SPA_PARAM_Format, 0, param);
	spa_log_debug(&logger.log, "result %d", res);
	spa_assert(res >= 0);

	return 0;
}


int main(int argc, char *argv[])
{
	struct context ctx;

	spa_zero(ctx);

	setup_context(&ctx);

	test_init_state(&ctx);
	test_split_setup(&ctx);

	clean_context(&ctx);

	return 0;
}
