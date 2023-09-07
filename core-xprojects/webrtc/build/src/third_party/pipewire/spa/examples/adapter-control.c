/* Spa
 *
 * Copyright © 2020 Collabora Ltd.
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


#include "config.h"

#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <poll.h>

#include <spa/control/control.h>
#include <spa/graph/graph.h>
#include <spa/support/plugin.h>
#include <spa/support/log-impl.h>
#include <spa/support/loop.h>
#include <spa/node/node.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/param/param.h>
#include <spa/param/props.h>
#include <spa/param/audio/format-utils.h>
#include <spa/utils/names.h>
#include <spa/utils/result.h>

static SPA_LOG_IMPL(default_log);

#define MIN_LATENCY	  1024

struct buffer {
	struct spa_buffer buffer;
	struct spa_meta metas[1];
	struct spa_meta_header header;
	struct spa_data datas[1];
	struct spa_chunk chunks[1];
};

struct data {
	const char *plugin_dir;
	struct spa_log *log;
	struct spa_system *system;
	struct spa_loop *loop;
	struct spa_loop_control *control;
	struct spa_support support[5];
	uint32_t n_support;

	struct spa_graph graph;
	struct spa_graph_state graph_state;
	struct spa_graph_node graph_source_node;
	struct spa_graph_node graph_sink_node;
	struct spa_graph_state graph_source_state;
	struct spa_graph_state graph_sink_state;
	struct spa_graph_port graph_source_port_0;
	struct spa_graph_port graph_sink_port_0;

	struct spa_node *source_follower_node;  // audiotestsrc
	struct spa_node *source_node;  // adapter for audiotestsrc
	struct spa_node *sink_follower_node;  // alsa-pcm-sink
	struct spa_node *sink_node;  // adapter for alsa-pcm-sink

	struct spa_io_buffers source_sink_io[1];
	struct spa_buffer *source_buffers[1];
	struct buffer source_buffer[1];
	uint8_t ctrl[1024];

	bool running;
	pthread_t thread;
};

static int load_handle(struct data *data, struct spa_handle **handle, const char *lib, const char *name)
{
	int res;
	void *hnd;
	spa_handle_factory_enum_func_t enum_func;
	uint32_t i;
	char *path;

	if ((path = spa_aprintf("%s/%s", data->plugin_dir, lib)) == NULL)
		return -ENOMEM;

	hnd = dlopen(path, RTLD_NOW);
	free(path);

	if (hnd == NULL) {
		printf("can't load %s: %s\n", lib, dlerror());
		return -ENOENT;
	}
	if ((enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		printf("can't find enum function\n");
		res = -ENOENT;
		goto exit_cleanup;
	}

	for (i = 0;;) {
		const struct spa_handle_factory *factory;

		if ((res = enum_func(&factory, &i)) <= 0) {
			if (res != 0)
				printf("can't enumerate factories: %s\n", spa_strerror(res));
			break;
		}
		if (factory->version < 1)
			continue;
		if (strcmp(factory->name, name))
			continue;

		*handle = calloc(1, spa_handle_factory_get_size(factory, NULL));
		if ((res = spa_handle_factory_init(factory, *handle,
						NULL, data->support,
						data->n_support)) < 0) {
			printf("can't make factory instance: %d\n", res);
			goto exit_cleanup;
		}
		return 0;
	}
	return -EBADF;

exit_cleanup:
	dlclose(hnd);
	return res;
}

int init_data(struct data *data)
{
	int res;
	const char *str;
	struct spa_handle *handle = NULL;
	void *iface;

	if ((str = getenv("SPA_PLUGIN_DIR")) == NULL)
		str = PLUGINDIR;
	data->plugin_dir = str;

	/* init the graph */
	spa_graph_init(&data->graph, &data->graph_state);

	/* set the default log */
	data->log = &default_log.log;
	data->support[data->n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, data->log);

	/* load and set support system */
	if ((res = load_handle(data, &handle,
			"support/libspa-support.so",
			SPA_NAME_SUPPORT_SYSTEM)) < 0)
		return res;
	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_System, &iface)) < 0) {
		printf("can't get System interface %d\n", res);
		return res;
	}
	data->system = iface;
	data->support[data->n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_System, data->system);
	data->support[data->n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataSystem, data->system);

	/* load and set support loop and loop control */
	if ((res = load_handle(data, &handle,
			"support/libspa-support.so",
			SPA_NAME_SUPPORT_LOOP)) < 0)
		return res;

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Loop, &iface)) < 0) {
		printf("can't get interface %d\n", res);
		return res;
	}
	data->loop = iface;
	data->support[data->n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Loop, data->loop);
	data->support[data->n_support++] = SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_DataLoop, data->loop);
	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_LoopControl, &iface)) < 0) {
		printf("can't get interface %d\n", res);
		return res;
	}
	data->control = iface;

	if ((str = getenv("SPA_DEBUG")))
		data->log->level = atoi(str);

	return 0;
}

static int make_node(struct data *data, struct spa_node **node, const char *lib,
    const char *name, const struct spa_dict *props)
{
	struct spa_handle *handle;
	int res = 0;
	void *hnd = NULL;
	spa_handle_factory_enum_func_t enum_func;
	uint32_t i;
	char *path;

	if ((path = spa_aprintf("%s/%s", data->plugin_dir, lib)) == NULL)
		return -ENOMEM;

	hnd = dlopen(path, RTLD_NOW);
	free(path);

	if (hnd == NULL) {
		printf("can't load %s: %s\n", lib, dlerror());
		return -ENOENT;
	}
	if ((enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		printf("can't find enum function\n");
		res = -ENOENT;
		goto exit_cleanup;
	}

	for (i = 0;;) {
		const struct spa_handle_factory *factory;
		void *iface;

		if ((res = enum_func(&factory, &i)) <= 0) {
			if (res != 0)
				printf("can't enumerate factories: %s\n", spa_strerror(res));
			break;
		}
		if (factory->version < 1)
			continue;
		if (strcmp(factory->name, name))
			continue;

		handle = calloc(1, spa_handle_factory_get_size(factory, NULL));
		if ((res =
		     spa_handle_factory_init(factory, handle, props, data->support,
					     data->n_support)) < 0) {
			printf("can't make factory instance: %d\n", res);
			goto exit_cleanup;
		}
		if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Node, &iface)) < 0) {
			printf("can't get interface %d\n", res);
			goto exit_cleanup;
		}
		*node = iface;
		return 0;
	}
	return -EBADF;

exit_cleanup:
	dlclose(hnd);
	return res;
}

static int on_sink_node_ready(void *_data, int status)
{
	struct data *data = _data;

	spa_graph_node_process(&data->graph_source_node);
	spa_graph_node_process(&data->graph_sink_node);
	return 0;
}

static int
on_sink_node_reuse_buffer(void *_data, uint32_t port_id, uint32_t buffer_id)
{
	struct data *data = _data;

	printf ("reuse_buffer: port_id=%d\n", port_id);
	data->source_sink_io[0].buffer_id = buffer_id;
	return 0;
}

static const struct spa_node_callbacks sink_node_callbacks = {
	SPA_VERSION_NODE_CALLBACKS,
	.ready = on_sink_node_ready,
	.reuse_buffer = on_sink_node_reuse_buffer
};

static int make_nodes(struct data *data, const char *device)
{
	int res = 0;
	struct spa_pod *props;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	char value[32];
	struct spa_dict_item items[1];
	struct spa_audio_info_raw info;
	struct spa_pod *param;

	/* make the source node (audiotestsrc) */
	if ((res = make_node(data, &data->source_follower_node,
				   "audiotestsrc/libspa-audiotestsrc.so",
				   "audiotestsrc",
				   NULL)) < 0) {
		printf("can't create source follower node (audiotestsrc): %d\n", res);
		return res;
	}

	/* set the format on the source */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_format_audio_raw_build(&b, 0,
			&SPA_AUDIO_INFO_RAW_INIT(
				.format = SPA_AUDIO_FORMAT_S16,
				.rate = 48000,
				.channels = 2 ));
	if ((res = spa_node_port_set_param(data->source_follower_node,
					   SPA_DIRECTION_OUTPUT, 0,
					   SPA_PARAM_Format, 0, param)) < 0) {
		printf("can't set format on follower node (audiotestsrc): %d\n", res);
		return res;
	}

	/* make the sink adapter node */
	snprintf(value, sizeof(value), "pointer:%p", data->source_follower_node);
	items[0] = SPA_DICT_ITEM_INIT("audio.adapt.follower", value);
	if ((res = make_node(data, &data->source_node,
			     "audioconvert/libspa-audioconvert.so",
			     SPA_NAME_AUDIO_ADAPT,
			     &SPA_DICT_INIT(items, 1))) < 0) {
		printf("can't create source adapter node: %d\n", res);
		return res;
	}

	/* setup the source node props */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	props = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Props, 0,
		SPA_PROP_frequency, SPA_POD_Float(600.0),
		SPA_PROP_volume,    SPA_POD_Float(0.5),
		SPA_PROP_live,	    SPA_POD_Bool(false));
	if ((res = spa_node_set_param(data->source_node, SPA_PARAM_Props, 0, props)) < 0) {
		printf("can't setup source follower node %d\n", res);
		return res;
	}

	/* setup the source node port config */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.channels = 1;
	info.rate = 48000;
	info.position[0] = SPA_AUDIO_CHANNEL_MONO;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig,	SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_OUTPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));
	if ((res = spa_node_set_param(data->source_node, SPA_PARAM_PortConfig, 0, param) < 0)) {
		printf("can't setup source node %d\n", res);
		return res;
	}

	/* make the sink follower node (alsa-pcm-sink) */
	if ((res = make_node(data, &data->sink_follower_node,
				   "alsa/libspa-alsa.so",
				   SPA_NAME_API_ALSA_PCM_SINK,
				   NULL)) < 0) {
		printf("can't create sink follower node (alsa-pcm-sink): %d\n", res);
		return res;
	}

	/* make the sink adapter node */
	snprintf(value, sizeof(value), "pointer:%p", data->sink_follower_node);
	items[0] = SPA_DICT_ITEM_INIT("audio.adapt.follower", value);
	if ((res = make_node(data, &data->sink_node,
			     "audioconvert/libspa-audioconvert.so",
			     SPA_NAME_AUDIO_ADAPT,
			     &SPA_DICT_INIT(items, 1))) < 0) {
		printf("can't create sink adapter node: %d\n", res);
		return res;
	}

	/* add sink follower node callbacks */
	spa_node_set_callbacks(data->sink_node, &sink_node_callbacks, data);

	/* setup the sink node props */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	props = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Props, 0,
		SPA_PROP_device,     SPA_POD_String(device ? device : "hw:0"),
		SPA_PROP_minLatency, SPA_POD_Int(MIN_LATENCY));
	if ((res = spa_node_set_param(data->sink_follower_node, SPA_PARAM_Props, 0, props)) < 0) {
		printf("can't setup sink follower node %d\n", res);
		return res;
	}

	/* setup the sink node port config */
	spa_zero(info);
	info.format = SPA_AUDIO_FORMAT_F32P;
	info.channels = 1;
	info.rate = 48000;
	info.position[0] = SPA_AUDIO_CHANNEL_MONO;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_format_audio_raw_build(&b, SPA_PARAM_Format, &info);
	param = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_ParamPortConfig,	SPA_PARAM_PortConfig,
		SPA_PARAM_PORT_CONFIG_direction,	SPA_POD_Id(SPA_DIRECTION_INPUT),
		SPA_PARAM_PORT_CONFIG_mode,		SPA_POD_Id(SPA_PARAM_PORT_CONFIG_MODE_dsp),
		SPA_PARAM_PORT_CONFIG_format,		SPA_POD_Pod(param));
	if ((res = spa_node_set_param(data->sink_node, SPA_PARAM_PortConfig, 0, param) < 0)) {
		printf("can't setup sink node %d\n", res);
		return res;
	}

	/* set io buffers on source and sink nodes */
	data->source_sink_io[0] = SPA_IO_BUFFERS_INIT;
	if ((res = spa_node_port_set_io(data->source_node,
			SPA_DIRECTION_OUTPUT, 0,
			SPA_IO_Buffers,
			&data->source_sink_io[0], sizeof(data->source_sink_io[0]))) < 0) {
		printf("can't set io buffers on port 0 of source node: %d\n", res);
		return res;
	}
	if ((res = spa_node_port_set_io(data->sink_node,
			  SPA_DIRECTION_INPUT, 0,
			  SPA_IO_Buffers,
			  &data->source_sink_io[0], sizeof(data->source_sink_io[0]))) < 0) {
		printf("can't set io buffers on port 0 of sink node: %d\n", res);
		return res;
	}

	/* add source node to the graph */
	spa_graph_node_init(&data->graph_source_node, &data->graph_source_state);
	spa_graph_node_set_callbacks(&data->graph_source_node, &spa_graph_node_impl_default, data->source_node);
	spa_graph_node_add(&data->graph, &data->graph_source_node);
	spa_graph_port_init(&data->graph_source_port_0, SPA_DIRECTION_OUTPUT, 0, 0);
	spa_graph_port_add(&data->graph_source_node, &data->graph_source_port_0);

	/* add sink node to the graph */
	spa_graph_node_init(&data->graph_sink_node, &data->graph_sink_state);
	spa_graph_node_set_callbacks(&data->graph_sink_node, &spa_graph_node_impl_default, data->sink_node);
	spa_graph_node_add(&data->graph, &data->graph_sink_node);
	spa_graph_port_init(&data->graph_sink_port_0, SPA_DIRECTION_INPUT, 0, 0);
	spa_graph_port_add(&data->graph_sink_node, &data->graph_sink_port_0);

	/* link source and sink nodes */
	spa_graph_port_link(&data->graph_source_port_0, &data->graph_sink_port_0);

	return res;
}

static void
init_buffer(struct data *data, struct spa_buffer **bufs, struct buffer *ba, int n_buffers,
	    size_t size)
{
	int i;

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &ba[i];
		bufs[i] = &b->buffer;

		b->buffer.metas = b->metas;
		b->buffer.n_metas = 1;
		b->buffer.datas = b->datas;
		b->buffer.n_datas = 1;

		b->header.flags = 0;
		b->header.seq = 0;
		b->header.pts = 0;
		b->header.dts_offset = 0;
		b->metas[0].type = SPA_META_Header;
		b->metas[0].data = &b->header;
		b->metas[0].size = sizeof(b->header);

		b->datas[0].type = SPA_DATA_MemPtr;
		b->datas[0].flags = 0;
		b->datas[0].fd = -1;
		b->datas[0].mapoffset = 0;
		b->datas[0].maxsize = size;
		b->datas[0].data = malloc(size);
		b->datas[0].chunk = &b->chunks[0];
		b->datas[0].chunk->offset = 0;
		b->datas[0].chunk->size = 0;
		b->datas[0].chunk->stride = 0;
	}
}

static int negotiate_formats(struct data *data)
{
	int res;
	struct spa_pod *filter = NULL, *param = NULL;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[4096];
	uint32_t state = 0;
	size_t buffer_size = 1024;

	/* get the source follower node buffer size */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	if (spa_node_port_enum_params_sync(data->source_follower_node,
			SPA_DIRECTION_OUTPUT, 0,
			SPA_PARAM_Buffers, &state, filter, &param, &b) != 1)
		return -ENOTSUP;
	spa_pod_fixate(param);
	if ((res = spa_pod_parse_object(param, SPA_TYPE_OBJECT_ParamBuffers, NULL,
		SPA_PARAM_BUFFERS_size, SPA_POD_Int(&buffer_size))) < 0)
		return res;

	/* set the sink and source formats */
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	param = spa_format_audio_dsp_build(&b, 0,
		&SPA_AUDIO_INFO_DSP_INIT(
			.format = SPA_AUDIO_FORMAT_F32P));
	if ((res = spa_node_port_set_param(data->source_node,
			SPA_DIRECTION_OUTPUT, 0, SPA_PARAM_Format, 0, param)) < 0)
		return res;
	if ((res = spa_node_port_set_param(data->sink_node,
			SPA_DIRECTION_INPUT, 0, SPA_PARAM_Format, 0, param)) < 0)
		return res;

	/* use buffers on the source and sink */
	init_buffer(data, data->source_buffers, data->source_buffer, 1, buffer_size);
	if ((res = spa_node_port_use_buffers(data->source_node,
		SPA_DIRECTION_OUTPUT, 0, 0, data->source_buffers, 1)) < 0)
		return res;
	if ((res = spa_node_port_use_buffers(data->sink_node,
		SPA_DIRECTION_INPUT, 0, 0, data->source_buffers, 1)) < 0)
		return res;

	return 0;
}

static void *loop(void *user_data)
{
	struct data *data = user_data;

	printf("enter thread\n");
	spa_loop_control_enter(data->control);

	while (data->running) {
		spa_loop_control_iterate(data->control, -1);
	}

	printf("leave thread\n");
	spa_loop_control_leave(data->control);
	return NULL;

	return NULL;
}

static void run_async_sink(struct data *data)
{
	int res, err;
	struct spa_command cmd;

	cmd = SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Start);
	if ((res = spa_node_send_command(data->source_node, &cmd)) < 0)
		printf("got error %d\n", res);
	if ((res = spa_node_send_command(data->sink_node, &cmd)) < 0)
		printf("got error %d\n", res);

	spa_loop_control_leave(data->control);

	data->running = true;
	if ((err = pthread_create(&data->thread, NULL, loop, data)) != 0) {
		printf("can't create thread: %d %s", err, strerror(err));
		data->running = false;
	}

	printf("sleeping for 1000 seconds\n");
	sleep(1000);

	if (data->running) {
		data->running = false;
		pthread_join(data->thread, NULL);
	}

	spa_loop_control_enter(data->control);

	cmd = SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Pause);
	if ((res = spa_node_send_command(data->source_node, &cmd)) < 0)
		printf("got error %d\n", res);
	if ((res = spa_node_send_command(data->sink_node, &cmd)) < 0)
		printf("got error %d\n", res);
}

int main(int argc, char *argv[])
{
	struct data data = { 0 };
	int res = 0;

	/* init data */
	if ((res = init_data(&data)) < 0) {
	  printf("can't init data: %d (%s)\n", res, spa_strerror(res));
	  return -1;
	}

	/* make the nodes (audiotestsrc and adapter with alsa-pcm-sink as follower) */
	if ((res = make_nodes(&data, argc > 1 ? argv[1] : NULL)) < 0) {
	  printf("can't make nodes: %d (%s)\n", res, spa_strerror(res));
		return -1;
	}

	/* Negotiate format */
	if ((res = negotiate_formats(&data)) < 0) {
		printf("can't negotiate nodes: %d (%s)\n", res, spa_strerror(res));
		return -1;
	}

	spa_loop_control_enter(data.control);
	run_async_sink(&data);
	spa_loop_control_leave(data.control);
}
