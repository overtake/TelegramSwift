/* PipeWire
 *
 * Copyright © 2021 Wim Taymans
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
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "config.h"

#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/param/profiler.h>
#include <spa/debug/pod.h>

#include <pipewire/private.h>
#include <pipewire/impl.h>
#include <extensions/profiler.h>

#define NAME "loopback"

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Create loopback streams" },
	{ PW_KEY_MODULE_USAGE, " [ remote.name=<remote> ] "
				"[ node.latency=<latency as fraction> ] "
				"[ node.name=<name of the nodes> ] "
				"[ node.description=<description of the nodes> ] "
				"[ audio.rate=<sample rate> ] "
				"[ audio.channels=<number of channels> ] "
				"[ audio.position=<channel map> ] "
				"[ capture.props=<properties> ] "
				"[ playback.props=<properties> ] " },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

#include <stdlib.h>
#include <signal.h>
#include <getopt.h>
#include <limits.h>
#include <math.h>

#include <spa/pod/builder.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/audio/raw.h>

#include <pipewire/pipewire.h>

struct impl {
	struct pw_context *context;

	struct pw_impl_module *module;
	struct pw_work_queue *work;

	struct spa_hook module_listener;

	struct pw_core *core;
	struct spa_hook core_proxy_listener;
	struct spa_hook core_listener;

	struct pw_properties *capture_props;
	struct pw_stream *capture;
	struct spa_hook capture_listener;
	struct spa_audio_info_raw capture_info;

	struct pw_properties *playback_props;
	struct pw_stream *playback;
	struct spa_hook playback_listener;
	struct spa_audio_info_raw playback_info;

	unsigned int do_disconnect:1;
	unsigned int unloading:1;
};

static void do_unload_module(void *obj, void *data, int res, uint32_t id)
{
	struct impl *impl = data;
	pw_impl_module_destroy(impl->module);
}
static void unload_module(struct impl *impl)
{
	if (!impl->unloading) {
		impl->unloading = true;
		pw_work_queue_add(impl->work, impl, 0, do_unload_module, impl);
	}
}

static void capture_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->capture_listener);
	impl->capture = NULL;
}

static void capture_process(void *d)
{
	struct impl *impl = d;
	struct pw_buffer *in, *out;
	uint32_t i;

	if ((in = pw_stream_dequeue_buffer(impl->capture)) == NULL)
		pw_log_warn("out of capture buffers: %m");

	if ((out = pw_stream_dequeue_buffer(impl->playback)) == NULL)
		pw_log_warn("out of playback buffers: %m");

	if (in != NULL && out != NULL) {
		uint32_t size = 0;
		int32_t stride = 0;

		for (i = 0; i < out->buffer->n_datas; i++) {
			struct spa_data *ds, *dd;

			dd = &out->buffer->datas[i];

			if (i < in->buffer->n_datas) {
				ds = &in->buffer->datas[i];

				memcpy(dd->data,
					SPA_MEMBER(ds->data, ds->chunk->offset, void),
					ds->chunk->size);

				size = SPA_MAX(size, ds->chunk->size);
				stride = SPA_MAX(stride, ds->chunk->stride);
			} else {
				memset(dd->data, 0, size);
			}
			dd->chunk->offset = 0;
			dd->chunk->size = size;
			dd->chunk->stride = stride;
		}
	}

	if (in != NULL)
		pw_stream_queue_buffer(impl->capture, in);
	if (out != NULL)
		pw_stream_queue_buffer(impl->playback, out);
}

static const struct pw_stream_events in_stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = capture_destroy,
	.process = capture_process
};

static void playback_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->playback_listener);
	impl->playback = NULL;
}

static const struct pw_stream_events out_stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = playback_destroy
};

static int setup_streams(struct impl *impl)
{
	int res;
	uint32_t n_params;
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b;

	impl->capture = pw_stream_new(impl->core,
			"loopback capture", impl->capture_props);
	impl->capture_props = NULL;
	if (impl->capture == NULL)
		return -errno;

	pw_stream_add_listener(impl->capture,
			&impl->capture_listener,
			&in_stream_events, impl);

	impl->playback = pw_stream_new(impl->core,
			"loopback playback", impl->playback_props);
	impl->playback_props = NULL;
	if (impl->playback == NULL)
		return -errno;

	pw_stream_add_listener(impl->playback,
			&impl->playback_listener,
			&out_stream_events, impl);

	n_params = 0;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	params[n_params++] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
			&impl->capture_info);

	if ((res = pw_stream_connect(impl->capture,
			PW_DIRECTION_INPUT,
			PW_ID_ANY,
			PW_STREAM_FLAG_AUTOCONNECT |
			PW_STREAM_FLAG_MAP_BUFFERS |
			PW_STREAM_FLAG_RT_PROCESS,
			params, n_params)) < 0)
		return res;

	n_params = 0;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	params[n_params++] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
			&impl->playback_info);

	if ((res = pw_stream_connect(impl->playback,
			PW_DIRECTION_OUTPUT,
			PW_ID_ANY,
			PW_STREAM_FLAG_AUTOCONNECT |
			PW_STREAM_FLAG_MAP_BUFFERS |
			PW_STREAM_FLAG_RT_PROCESS,
			params, n_params)) < 0)
		return res;

	return 0;
}

static void core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct impl *impl = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE && res == -EPIPE)
		unload_module(impl);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = core_error,
};

static void core_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->core_listener);
	impl->core = NULL;
	unload_module(impl);
}

static const struct pw_proxy_events core_proxy_events = {
	.destroy = core_destroy,
};

static void impl_destroy(struct impl *impl)
{
	if (impl->capture)
		pw_stream_destroy(impl->capture);
	if (impl->playback)
		pw_stream_destroy(impl->playback);
	if (impl->core && impl->do_disconnect)
		pw_core_disconnect(impl->core);
	if (impl->capture_props)
		pw_properties_free(impl->capture_props);
	if (impl->playback_props)
		pw_properties_free(impl->playback_props);
	pw_work_queue_cancel(impl->work, impl, SPA_ID_INVALID);
	free(impl);
}

static void module_destroy(void *data)
{
	struct impl *impl = data;
	impl->unloading = true;
	spa_hook_remove(&impl->module_listener);
	impl_destroy(impl);
}

static const struct pw_impl_module_events module_events = {
	PW_VERSION_IMPL_MODULE_EVENTS,
	.destroy = module_destroy,
};

static uint32_t channel_from_name(const char *name)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static void parse_position(struct spa_audio_info_raw *info, const char *val, size_t len)
{
	struct spa_json it[2];
	char v[256];

	spa_json_init(&it[0], val, len);
        if (spa_json_enter_array(&it[0], &it[1]) <= 0)
                spa_json_init(&it[1], val, len);

	info->channels = 0;
	while (spa_json_get_string(&it[1], v, sizeof(v)) > 0 &&
	    info->channels < SPA_AUDIO_MAX_CHANNELS) {
		info->position[info->channels++] = channel_from_name(v);
	}
}

static void parse_audio_info(struct pw_properties *props, struct spa_audio_info_raw *info)
{
	const char *str;

	*info = SPA_AUDIO_INFO_RAW_INIT(
			.format = SPA_AUDIO_FORMAT_F32P);
	if ((str = pw_properties_get(props, PW_KEY_AUDIO_RATE)) != NULL)
		info->rate = atoi(str);
	if ((str = pw_properties_get(props, PW_KEY_AUDIO_CHANNELS)) != NULL)
		info->channels = atoi(str);
	if ((str = pw_properties_get(props, SPA_KEY_AUDIO_POSITION)) != NULL)
		parse_position(info, str, strlen(str));
}

static void copy_props(struct impl *impl, struct pw_properties *props, const char *key)
{
	const char *str;
	if ((str = pw_properties_get(props, key)) != NULL) {
		if (pw_properties_get(impl->capture_props, key) == NULL)
			pw_properties_set(impl->capture_props, key, str);
		if (pw_properties_get(impl->playback_props, key) == NULL)
			pw_properties_set(impl->playback_props, key, str);
	}
}

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	struct pw_properties *props;
	struct impl *impl;
	uint32_t id = pw_global_get_id(pw_impl_module_get_global(module));
	const char *str;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	pw_log_debug("module %p: new %s", impl, args);

	if (args)
		props = pw_properties_new_string(args);
	else
		props = pw_properties_new(NULL, NULL);
	if (props == NULL) {
		res = -errno;
		pw_log_error( "can't create properties: %m");
		goto error;
	}

	impl->capture_props = pw_properties_new(NULL, NULL);
	impl->playback_props = pw_properties_new(NULL, NULL);
	if (impl->capture_props == NULL || impl->playback_props == NULL) {
		res = -errno;
		pw_log_error( "can't create properties: %m");
		goto error;
	}

	impl->module = module;
	impl->context = context;
	impl->work = pw_context_get_work_queue(context);

	if (pw_properties_get(props, PW_KEY_NODE_GROUP) == NULL)
		pw_properties_setf(props, PW_KEY_NODE_GROUP, "loopback-%u", id);
	if (pw_properties_get(props, PW_KEY_NODE_VIRTUAL) == NULL)
		pw_properties_set(props, PW_KEY_NODE_VIRTUAL, "true");

	if ((str = pw_properties_get(props, "capture.props")) != NULL)
		pw_properties_update_string(impl->capture_props, str, strlen(str));
	if ((str = pw_properties_get(props, "playback.props")) != NULL)
		pw_properties_update_string(impl->playback_props, str, strlen(str));

	copy_props(impl, props, PW_KEY_AUDIO_RATE);
	copy_props(impl, props, PW_KEY_AUDIO_CHANNELS);
	copy_props(impl, props, SPA_KEY_AUDIO_POSITION);
	copy_props(impl, props, PW_KEY_NODE_NAME);
	copy_props(impl, props, PW_KEY_NODE_DESCRIPTION);
	copy_props(impl, props, PW_KEY_NODE_GROUP);
	copy_props(impl, props, PW_KEY_NODE_LATENCY);
	copy_props(impl, props, PW_KEY_NODE_VIRTUAL);

	parse_audio_info(impl->capture_props, &impl->capture_info);
	parse_audio_info(impl->playback_props, &impl->playback_info);

	impl->core = pw_context_get_object(impl->context, PW_TYPE_INTERFACE_Core);
	if (impl->core == NULL) {
		str = pw_properties_get(props, PW_KEY_REMOTE_NAME);
		impl->core = pw_context_connect(impl->context,
				pw_properties_new(
					PW_KEY_REMOTE_NAME, str,
					NULL),
				0);
		impl->do_disconnect = true;
	}
	if (impl->core == NULL) {
		res = -errno;
		pw_log_error("can't connect: %m");
		goto error;
	}

	pw_properties_free(props);

	pw_proxy_add_listener((struct pw_proxy*)impl->core,
			&impl->core_proxy_listener,
			&core_proxy_events, impl);
	pw_core_add_listener(impl->core,
			&impl->core_listener,
			&core_events, impl);

	setup_streams(impl);

	pw_impl_module_add_listener(module, &impl->module_listener, &module_events, impl);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	return 0;

error:
	if (props)
		pw_properties_free(props);
	impl_destroy(impl);
	return res;
}
