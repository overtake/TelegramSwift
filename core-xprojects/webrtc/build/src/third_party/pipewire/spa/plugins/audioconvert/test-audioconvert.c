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

#define MAX_PORTS SPA_AUDIO_MAX_CHANNELS

struct context {
	struct spa_handle *convert_handle;
	struct spa_node *convert_node;

	bool got_node_info;
	uint32_t n_port_info[2];
	bool got_port_info[2][MAX_PORTS];
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
	const struct spa_handle_factory *factory;
	void *iface;

	logger.log.level = SPA_LOG_LEVEL_TRACE;
	support[0] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, &logger);

	/* make convert */
	factory = find_factory(SPA_NAME_AUDIO_CONVERT);
	spa_assert(factory != NULL);

	size = spa_handle_factory_get_size(factory, NULL);

	ctx->convert_handle = calloc(1, size);
	spa_assert(ctx->convert_handle != NULL);

	res = spa_handle_factory_init(factory,
			ctx->convert_handle,
			NULL,
			support, 1);
	spa_assert(res >= 0);

	res = spa_handle_get_interface(ctx->convert_handle,
			SPA_TYPE_INTERFACE_Node, &iface);
	spa_assert(res >= 0);
	ctx->convert_node = iface;

	return 0;
}

static int clean_context(struct context *ctx)
{
	spa_handle_clear(ctx->convert_handle);
	free(ctx->convert_handle);
	return 0;
}

static void node_info_check(void *data, const struct spa_node_info *info)
{
	struct context *ctx = data;

	fprintf(stderr, "input %d, output %d\n",
			info->max_input_ports,
			info->max_output_ports);

	spa_assert(info->max_input_ports == MAX_PORTS);
	spa_assert(info->max_output_ports == MAX_PORTS);

	ctx->got_node_info = true;
}

static void port_info_check(void *data,
		enum spa_direction direction, uint32_t port,
		const struct spa_port_info *info)
{
	struct context *ctx = data;

	fprintf(stderr, "port %d %d %p\n", direction, port, info);

	ctx->got_port_info[direction][port] = true;
	ctx->n_port_info[direction]++;
}

static int test_init_state(struct context *ctx)
{
	struct spa_hook listener;
	static const struct spa_node_events init_events = {
		SPA_VERSION_NODE_EVENTS,
		.info = node_info_check,
		.port_info = port_info_check,
	};

	spa_zero(ctx->got_node_info);
	spa_zero(ctx->n_port_info);
	spa_zero(ctx->got_port_info);

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &init_events, ctx);
	spa_hook_remove(&listener);

	spa_assert(ctx->got_node_info);
	spa_assert(ctx->n_port_info[0] == 1);
	spa_assert(ctx->n_port_info[1] == 1);
	spa_assert(ctx->got_port_info[0][0] == true);
	spa_assert(ctx->got_port_info[1][0] == true);

	return 0;
}

static int test_set_in_format(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;

	/* other format */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	info = (struct spa_audio_info_raw) {
		.format = SPA_AUDIO_FORMAT_S16,
		.rate = 44100,
		.channels = 2,
		.position = { SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR, }
	};
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	res = spa_node_port_set_param(ctx->convert_node, SPA_DIRECTION_INPUT, 0,
			SPA_PARAM_Format, 0, param);
	spa_assert(res == 0);

	return 0;
}

static int test_split_setup1(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, output as DSP */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.rate = 48000;
	info.channels = 6;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	info.position[2] = SPA_AUDIO_CHANNEL_FC;
	info.position[3] = SPA_AUDIO_CHANNEL_LFE;
	info.position[4] = SPA_AUDIO_CHANNEL_SL;
	info.position[5] = SPA_AUDIO_CHANNEL_SR;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_OUTPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_split_setup2(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, output as DSP */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.rate = 48000;
	info.channels = 4;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	info.position[2] = SPA_AUDIO_CHANNEL_RL;
	info.position[3] = SPA_AUDIO_CHANNEL_RR;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_OUTPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_convert_setup1(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, output convert */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_OUTPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_convert));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_set_out_format(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;

	/* out format */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	info = (struct spa_audio_info_raw) {
		.format = SPA_AUDIO_FORMAT_S32P,
		.rate = 96000,
		.channels = 8,
		.position = { SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR,
			SPA_AUDIO_CHANNEL_FC, SPA_AUDIO_CHANNEL_LFE,
			SPA_AUDIO_CHANNEL_SL, SPA_AUDIO_CHANNEL_SR,
			SPA_AUDIO_CHANNEL_RL, SPA_AUDIO_CHANNEL_RR, }
	};
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	res = spa_node_port_set_param(ctx->convert_node, SPA_DIRECTION_OUTPUT, 0,
			SPA_PARAM_Format, 0, param);
	spa_assert(res == 0);

	return 0;
}

static int test_merge_setup1(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, output as DSP */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.rate = 48000;
	info.channels = 6;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	info.position[2] = SPA_AUDIO_CHANNEL_FC;
	info.position[3] = SPA_AUDIO_CHANNEL_LFE;
	info.position[4] = SPA_AUDIO_CHANNEL_RL;
	info.position[5] = SPA_AUDIO_CHANNEL_RR;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_INPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_set_out_format2(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;

	/* out format */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	info = (struct spa_audio_info_raw) {
		.format = SPA_AUDIO_FORMAT_S16,
		.rate = 32000,
		.channels = 2,
		.position = { SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR, }
	};
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	res = spa_node_port_set_param(ctx->convert_node, SPA_DIRECTION_OUTPUT, 0,
			SPA_PARAM_Format, 0, param);
	spa_assert(res == 0);

	return 0;
}

static int test_merge_setup2(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, output as DSP */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.rate = 96000;
	info.channels = 4;
	info.position[0] = SPA_AUDIO_CHANNEL_FL;
	info.position[1] = SPA_AUDIO_CHANNEL_FR;
	info.position[2] = SPA_AUDIO_CHANNEL_FC;
	info.position[3] = SPA_AUDIO_CHANNEL_LFE;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_INPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_convert_setup2(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	int res;
	struct spa_hook listener;
	static const struct spa_node_events node_events = {
		SPA_VERSION_NODE_EVENTS,
		.port_info = port_info_check,
	};

	spa_zero(listener);
	spa_node_add_listener(ctx->convert_node,
			&listener, &node_events, ctx);

	/* port config, input convert */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig, SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_INPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_convert));

	res = spa_node_set_param(ctx->convert_node, SPA_PARAM_PortConfig, 0, param);
	spa_assert(res == 0);

	spa_hook_remove(&listener);

	return 0;
}

static int test_set_in_format2(struct context *ctx)
{
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_pod *param;
	struct spa_audio_info_raw info;
	int res;

	/* other format */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	info = (struct spa_audio_info_raw) {
		.format = SPA_AUDIO_FORMAT_S24,
		.rate = 48000,
		.channels = 3,
		.position = { SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR,
			SPA_AUDIO_CHANNEL_LFE, }
	};
        param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);

	res = spa_node_port_set_param(ctx->convert_node, SPA_DIRECTION_INPUT, 0,
			SPA_PARAM_Format, 0, param);
	spa_assert(res == 0);

	return 0;
}

int main(int argc, char *argv[])
{
	struct context ctx;

	spa_zero(ctx);

	setup_context(&ctx);

	test_init_state(&ctx);
	test_set_in_format(&ctx);
	test_split_setup1(&ctx);
	test_split_setup2(&ctx);
	test_convert_setup1(&ctx);
	test_set_out_format(&ctx);
	test_merge_setup1(&ctx);
	test_set_out_format2(&ctx);
	test_merge_setup2(&ctx);
	test_convert_setup2(&ctx);
	test_set_in_format2(&ctx);
	test_set_out_format(&ctx);

	clean_context(&ctx);

	return 0;
}
