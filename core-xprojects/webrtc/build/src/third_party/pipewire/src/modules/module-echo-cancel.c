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

#include "module-echo-cancel/echo-cancel.h"

#define NAME "echo-cancel"

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "Wim Taymans <wim.taymans@gmail.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Echo Cancellation" },
	{ PW_KEY_MODULE_USAGE, " [ remote.name=<remote> ] "
				"[ node.latency=<latency as fraction> ] "
				"[ audio.rate=<sample rate> ] "
				"[ audio.channels=<number of channels> ] "
				"[ audio.position=<channel map> ] "
				"[ aec.method=<aec method> ] "
				"[ aec.args=<aec arguments> ] "
				"[ source.props=<properties> ] "
				"[ sink.props=<properties> ] " },
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

	uint32_t id;

	struct pw_core *core;
	struct spa_hook core_proxy_listener;
	struct spa_hook core_listener;

	struct spa_audio_info_raw info;

	struct pw_stream *capture;
	struct spa_hook capture_listener;
	struct pw_properties *source_props;
	struct pw_stream *source;
	struct spa_hook source_listener;

	struct pw_stream *playback;
	struct spa_hook playback_listener;
	struct pw_properties *sink_props;
	struct pw_stream *sink;
	struct spa_hook sink_listener;

	const struct echo_cancel_info *aec_info;
	void *aec;

	unsigned int capture_ready:1;
	unsigned int sink_ready:1;

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

static void process(struct impl *impl)
{
	struct pw_buffer *cin, *cout;
	struct pw_buffer *pin, *pout;
	const float *rec[SPA_AUDIO_MAX_CHANNELS];
	const float *play[SPA_AUDIO_MAX_CHANNELS];
	float *out[SPA_AUDIO_MAX_CHANNELS];
	struct spa_data *ds, *dd;
	uint32_t i, size = 0;
	int32_t stride = 0;

	if ((cin = pw_stream_dequeue_buffer(impl->capture)) == NULL)
		pw_log_warn("out of capture buffers: %m");

	if ((cout = pw_stream_dequeue_buffer(impl->source)) == NULL)
		pw_log_warn("out of source buffers: %m");

	if ((pin = pw_stream_dequeue_buffer(impl->sink)) == NULL)
		pw_log_warn("out of sink buffers: %m");

	if ((pout = pw_stream_dequeue_buffer(impl->playback)) == NULL)
		pw_log_warn("out of playback buffers: %m");

	if (cin == NULL || cout == NULL || pin == NULL || pout == NULL)
		return;

	for (i = 0; i < impl->info.channels; i++) {
		/* captured samples, with echo from sink */
		ds = &cin->buffer->datas[i];
		rec[i] = SPA_MEMBER(ds->data, ds->chunk->offset, void);

		size = ds->chunk->size;
		stride = ds->chunk->stride;

		/* filtered samples, without echo from sink */
		dd = &cout->buffer->datas[i];
		out[i] = dd->data;
		dd->chunk->offset = 0;
		dd->chunk->size = size;
		dd->chunk->stride = stride;

		/* echo from sink */
		ds = &pin->buffer->datas[i];
		play[i] = SPA_MEMBER(ds->data, ds->chunk->offset, void);

		/* output to sink, just copy */
		dd = &pout->buffer->datas[i];
		memcpy(dd->data, play[i], size);

		dd->chunk->offset = 0;
		dd->chunk->size = size;
		dd->chunk->stride = stride;
	}
	echo_cancel_run(impl->aec_info, impl->aec, rec, play, out, size / sizeof(float));

	pw_stream_queue_buffer(impl->capture, cin);
	pw_stream_queue_buffer(impl->source, cout);
	pw_stream_queue_buffer(impl->sink, pin);
	pw_stream_queue_buffer(impl->playback, pout);

	impl->sink_ready = false;
	impl->capture_ready = false;
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
	impl->capture_ready = true;
	if (impl->sink_ready)
		process(impl);
}

static const struct pw_stream_events capture_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = capture_destroy,
	.process = capture_process
};

static void source_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->source_listener);
	impl->source = NULL;
}

static const struct pw_stream_events source_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = source_destroy,
};

static void sink_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->sink_listener);
	impl->sink = NULL;
}

static void sink_process(void *d)
{
	struct impl *impl = d;
	impl->sink_ready = true;
	if (impl->capture_ready)
		process(impl);
}

static void playback_destroy(void *d)
{
	struct impl *impl = d;
	spa_hook_remove(&impl->playback_listener);
	impl->playback = NULL;
}

static const struct pw_stream_events playback_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = playback_destroy,
};
static const struct pw_stream_events sink_events = {
	PW_VERSION_STREAM_EVENTS,
	.destroy = sink_destroy,
	.process = sink_process
};

static int setup_streams(struct impl *impl)
{
	int res;
	uint32_t n_params;
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b;
	struct pw_properties *props;

	props = pw_properties_new(
			PW_KEY_NODE_VIRTUAL, "true",
			NULL);
	pw_properties_setf(props,
			PW_KEY_NODE_GROUP, "echo-cancel-%u", impl->id);

	impl->capture = pw_stream_new(impl->core,
			"echo-cancel capture", props);
	if (impl->capture == NULL)
		return -errno;

	pw_stream_add_listener(impl->capture,
			&impl->capture_listener,
			&capture_events, impl);

	impl->source = pw_stream_new(impl->core,
			"echo-cancel source", impl->source_props);
	impl->source_props = NULL;
	if (impl->source == NULL)
		return -errno;

	pw_stream_add_listener(impl->source,
			&impl->source_listener,
			&source_events, impl);

	impl->sink = pw_stream_new(impl->core,
			"echo-cancel sink", impl->sink_props);
	impl->sink_props = NULL;
	if (impl->sink == NULL)
		return -errno;

	pw_stream_add_listener(impl->sink,
			&impl->sink_listener,
			&sink_events, impl);

	props = pw_properties_new(
			PW_KEY_NODE_VIRTUAL, "true",
			NULL);
	pw_properties_setf(props,
			PW_KEY_NODE_GROUP, "echo-cancel-%u", impl->id);

	impl->playback = pw_stream_new(impl->core,
			"echo-cancel playback", props);
	if (impl->playback == NULL)
		return -errno;

	pw_stream_add_listener(impl->playback,
			&impl->playback_listener,
			&playback_events, impl);

	n_params = 0;
	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	params[n_params++] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
			&impl->info);

	if ((res = pw_stream_connect(impl->capture,
			PW_DIRECTION_INPUT,
			PW_ID_ANY,
			PW_STREAM_FLAG_AUTOCONNECT |
			PW_STREAM_FLAG_MAP_BUFFERS |
			PW_STREAM_FLAG_RT_PROCESS,
			params, n_params)) < 0)
		return res;

	if ((res = pw_stream_connect(impl->source,
			PW_DIRECTION_OUTPUT,
			PW_ID_ANY,
			PW_STREAM_FLAG_MAP_BUFFERS |
			PW_STREAM_FLAG_RT_PROCESS,
			params, n_params)) < 0)
		return res;

	if ((res = pw_stream_connect(impl->sink,
			PW_DIRECTION_INPUT,
			PW_ID_ANY,
			PW_STREAM_FLAG_MAP_BUFFERS |
			PW_STREAM_FLAG_RT_PROCESS,
			params, n_params)) < 0)
		return res;

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
	if (impl->source)
		pw_stream_destroy(impl->source);
	if (impl->playback)
		pw_stream_destroy(impl->playback);
	if (impl->sink)
		pw_stream_destroy(impl->sink);
	if (impl->core && impl->do_disconnect)
		pw_core_disconnect(impl->core);
	if (impl->aec)
		echo_cancel_destroy(impl->aec_info, impl->aec);
	if (impl->source_props)
		pw_properties_free(impl->source_props);
	if (impl->sink_props)
		pw_properties_free(impl->sink_props);
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
		if (pw_properties_get(impl->source_props, key) == NULL)
			pw_properties_set(impl->source_props, key, str);
		if (pw_properties_get(impl->sink_props, key) == NULL)
			pw_properties_set(impl->sink_props, key, str);
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

	impl->source_props = pw_properties_new(NULL, NULL);
	impl->sink_props = pw_properties_new(NULL, NULL);
	if (impl->source_props == NULL || impl->sink_props == NULL) {
		res = -errno;
		pw_log_error( "can't create properties: %m");
		goto error;
	}

	impl->id = id;
	impl->module = module;
	impl->context = context;
	impl->work = pw_context_get_work_queue(context);

	if (pw_properties_get(props, PW_KEY_NODE_GROUP) == NULL)
		pw_properties_setf(props, PW_KEY_NODE_GROUP, "loopback-%u", id);
	if (pw_properties_get(props, PW_KEY_NODE_VIRTUAL) == NULL)
		pw_properties_set(props, PW_KEY_NODE_VIRTUAL, "true");

	parse_audio_info(props, &impl->info);

	if (impl->info.channels == 0) {
		impl->info.channels = 2;
		impl->info.position[0] = SPA_AUDIO_CHANNEL_FL;
		impl->info.position[1] = SPA_AUDIO_CHANNEL_FR;
	}
	if (impl->info.rate == 0)
		impl->info.rate = 48000;

	if ((str = pw_properties_get(props, "source.props")) != NULL)
		pw_properties_update_string(impl->source_props, str, strlen(str));
	if ((str = pw_properties_get(props, "sink.props")) != NULL)
		pw_properties_update_string(impl->sink_props, str, strlen(str));

	if (pw_properties_get(impl->source_props, PW_KEY_MEDIA_CLASS) == NULL)
		pw_properties_set(impl->source_props, PW_KEY_MEDIA_CLASS, "Audio/Source");
	if (pw_properties_get(impl->sink_props, PW_KEY_MEDIA_CLASS) == NULL)
		pw_properties_set(impl->sink_props, PW_KEY_MEDIA_CLASS, "Audio/Sink");

	copy_props(impl, props, PW_KEY_NODE_GROUP);
	copy_props(impl, props, PW_KEY_NODE_VIRTUAL);
	copy_props(impl, props, PW_KEY_NODE_LATENCY);

	if ((str = pw_properties_get(props, "aec,method")) == NULL)
		str = "null";
	if (strcmp(str, "webrtc") == 0)
		impl->aec_info = echo_cancel_webrtc;
	else
		impl->aec_info = echo_cancel_null;

	impl->aec = echo_cancel_create(impl->aec_info, NULL, impl->info.channels);

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
