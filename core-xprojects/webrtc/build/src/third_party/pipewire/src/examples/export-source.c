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

#include <errno.h>
#include <stdio.h>
#include <math.h>
#include <sys/mman.h>

#include <spa/utils/result.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/node/io.h>
#include <spa/node/utils.h>
#include <spa/pod/filter.h>
#include <spa/debug/format.h>

#include <pipewire/pipewire.h>

#define M_PI_M2 ( M_PI + M_PI )

#define BUFFER_SAMPLES	128

struct buffer {
	uint32_t id;
	struct spa_buffer *buffer;
	struct spa_list link;
	void *ptr;
	bool mapped;
};

struct data {
	const char *path;

	struct pw_main_loop *loop;

	struct pw_context *context;

	struct pw_core *core;
	struct spa_hook core_listener;

	uint64_t info_all;
	struct spa_port_info info;
	struct spa_dict_item items[1];
	struct spa_dict dict;
	struct spa_param_info params[5];

	struct spa_node impl_node;
	struct spa_hook_list hooks;
	struct spa_io_buffers *io;
	struct spa_io_control *io_notify;
	uint32_t io_notify_size;

	struct spa_audio_info_raw format;

	struct buffer buffers[32];
	uint32_t n_buffers;
	struct spa_list empty;

	double accumulator;
	double volume_accum;
};

static void update_volume(struct data *data)
{
	struct spa_pod_builder b = { 0, };
	struct spa_pod_frame f[2];

	if (data->io_notify == NULL)
		return;

	spa_pod_builder_init(&b, data->io_notify, data->io_notify_size);
	spa_pod_builder_push_sequence(&b, &f[0], 0);
	spa_pod_builder_control(&b, 0, SPA_CONTROL_Properties);
	spa_pod_builder_push_object(&b, &f[1], SPA_TYPE_OBJECT_Props, 0);
	spa_pod_builder_prop(&b, SPA_PROP_volume, 0);
	spa_pod_builder_float(&b, (sin(data->volume_accum) / 2.0) + 0.5);
	spa_pod_builder_pop(&b, &f[1]);
	spa_pod_builder_pop(&b, &f[0]);

        data->volume_accum += M_PI_M2 / 1000.0;
        if (data->volume_accum >= M_PI_M2)
                data->volume_accum -= M_PI_M2;
}

static int impl_send_command(void *object, const struct spa_command *command)
{
	return 0;
}

static int impl_add_listener(void *object,
		struct spa_hook *listener,
		const struct spa_node_events *events,
		void *data)
{
	struct data *d = object;
	struct spa_hook_list save;

	spa_hook_list_isolate(&d->hooks, &save, listener, events, data);

	d->info.change_mask = d->info_all;
	spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_OUTPUT, 0, &d->info);
	d->info.change_mask = 0;

	spa_hook_list_join(&d->hooks, &save);
	return 0;
}

static int impl_set_callbacks(void *object,
			      const struct spa_node_callbacks *callbacks, void *data)
{
	return 0;
}

static int impl_set_io(void *object,
			uint32_t id, void *data, size_t size)
{
	return 0;
}

static int impl_port_set_io(void *object, enum spa_direction direction, uint32_t port_id,
			    uint32_t id, void *data, size_t size)
{
	struct data *d = object;

	switch (id) {
	case SPA_IO_Buffers:
		d->io = data;
		break;
	case SPA_IO_Notify:
		d->io_notify = data;
		d->io_notify_size = size;
		break;
	default:
		return -ENOENT;
	}
	return 0;
}

static int impl_port_enum_params(void *object, int seq,
				 enum spa_direction direction, uint32_t port_id,
				 uint32_t id, uint32_t start, uint32_t num,
				 const struct spa_pod *filter)
{
	struct data *d = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_node_params result;
	uint32_t count = 0;

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumFormat:
		if (result.index != 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
			SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(5,
							SPA_AUDIO_FORMAT_S16,
							SPA_AUDIO_FORMAT_S16P,
							SPA_AUDIO_FORMAT_S16,
							SPA_AUDIO_FORMAT_F32P,
							SPA_AUDIO_FORMAT_F32),
			SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(2, 1, INT32_MAX),
			SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(44100, 1, INT32_MAX));
		break;

	case SPA_PARAM_Format:
		if (result.index != 0)
			return 0;
		if (d->format.format == 0)
			return 0;
		param = spa_format_audio_raw_build(&b, id, &d->format);
		break;

	case SPA_PARAM_Buffers:
		if (result.index > 0)
			return 0;

		param = spa_pod_builder_add_object(&b,
			SPA_TYPE_OBJECT_ParamBuffers, id,
			SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(1, 1, 32),
			SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
			SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(
							BUFFER_SAMPLES * sizeof(float), 32, INT32_MAX),
			SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(sizeof(float)),
			SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16));
		break;

	case SPA_PARAM_Meta:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamMeta, id,
				SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
				SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
			break;
		default:
			return 0;
		}
		break;
	case SPA_PARAM_IO:
		switch (result.index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id, SPA_POD_Id(SPA_IO_Buffers),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_buffers)));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamIO, id,
				SPA_PARAM_IO_id, SPA_POD_Id(SPA_IO_Notify),
				SPA_PARAM_IO_size, SPA_POD_Int(sizeof(struct spa_io_sequence) + 1024));
			break;
		default:
			return 0;
		}
		break;
	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_node_emit_result(&d->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int port_set_format(void *object,
			   enum spa_direction direction, uint32_t port_id,
			   uint32_t flags, const struct spa_pod *format)
{
	struct data *d = object;

	d->info.change_mask = SPA_PORT_CHANGE_MASK_PARAMS;
	if (format == NULL) {
		d->format.format = 0;
		d->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
		d->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
		spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_OUTPUT, 0, &d->info);
		return 0;
	}

	spa_debug_format(0, NULL, format);

	if (spa_format_audio_raw_parse(format, &d->format) < 0)
		return -EINVAL;

	if (d->format.format != SPA_AUDIO_FORMAT_S16 &&
	    d->format.format != SPA_AUDIO_FORMAT_F32)
		return -EINVAL;

	d->params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_READWRITE);
	d->params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, SPA_PARAM_INFO_READ);
	spa_node_emit_port_info(&d->hooks, SPA_DIRECTION_OUTPUT, 0, &d->info);

	return 0;
}

static int impl_port_set_param(void *object,
			       enum spa_direction direction, uint32_t port_id,
			       uint32_t id, uint32_t flags,
			       const struct spa_pod *param)
{
	if (id == SPA_PARAM_Format) {
		return port_set_format(object, direction, port_id, flags, param);
	}
	else
		return -ENOENT;
}

static int impl_port_use_buffers(void *object,
		enum spa_direction direction, uint32_t port_id,
		uint32_t flags,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct data *d = object;
	uint32_t i;

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b = &d->buffers[i];
		struct spa_data *datas = buffers[i]->datas;

		if (datas[0].data != NULL) {
			b->ptr = datas[0].data;
			b->mapped = false;
		}
		else if (datas[0].type == SPA_DATA_MemFd ||
			 datas[0].type == SPA_DATA_DmaBuf) {
			b->ptr = mmap(NULL, datas[0].maxsize + datas[0].mapoffset, PROT_WRITE,
				      MAP_SHARED, datas[0].fd, 0);
			if (b->ptr == MAP_FAILED) {
				pw_log_error("failed to buffer mem");
				return -errno;

			}
			b->ptr = SPA_MEMBER(b->ptr, datas[0].mapoffset, void);
			b->mapped = true;
		}
		else {
			pw_log_error("invalid buffer mem");
			return -EINVAL;
		}
		b->id = i;
		b->buffer = buffers[i];
		pw_log_debug("got buffer %d size %d", i, datas[0].maxsize);
		spa_list_append(&d->empty, &b->link);
	}
	d->n_buffers = n_buffers;
	return 0;
}

static inline void reuse_buffer(struct data *d, uint32_t id)
{
	pw_log_trace("export-source %p: recycle buffer %d", d, id);
        spa_list_append(&d->empty, &d->buffers[id].link);
}

static int impl_port_reuse_buffer(void *object, uint32_t port_id, uint32_t buffer_id)
{
	struct data *d = object;
	reuse_buffer(d, buffer_id);
	return 0;
}

static void fill_f32(struct data *d, void *dest, int avail)
{
	float *dst = dest;
	int n_samples = avail / (sizeof(float) * d->format.channels);
	int i;
	uint32_t c;

        for (i = 0; i < n_samples; i++) {
		float val;

                d->accumulator += M_PI_M2 * 440 / d->format.rate;
                if (d->accumulator >= M_PI_M2)
                        d->accumulator -= M_PI_M2;

                val = sin(d->accumulator);

                for (c = 0; c < d->format.channels; c++)
                        *dst++ = val;
        }
}

static void fill_s16(struct data *d, void *dest, int avail)
{
	int16_t *dst = dest;
	int n_samples = avail / (sizeof(int16_t) * d->format.channels);
	int i;
	uint32_t c;

        for (i = 0; i < n_samples; i++) {
                int16_t val;

                d->accumulator += M_PI_M2 * 440 / d->format.rate;
                if (d->accumulator >= M_PI_M2)
                        d->accumulator -= M_PI_M2;

                val = (int16_t) (sin(d->accumulator) * 32767.0);

                for (c = 0; c < d->format.channels; c++)
                        *dst++ = val;
        }
}

static int impl_node_process(void *object)
{
	struct data *d = object;
	struct buffer *b;
	int avail;
        struct spa_io_buffers *io = d->io;
	uint32_t maxsize, index = 0;
	uint32_t filled, offset;
	struct spa_data *od;

	if (io->buffer_id < d->n_buffers) {
		reuse_buffer(d, io->buffer_id);
		io->buffer_id = SPA_ID_INVALID;
	}
	if (spa_list_is_empty(&d->empty)) {
                pw_log_error("export-source %p: out of buffers", d);
                return -EPIPE;
        }
        b = spa_list_first(&d->empty, struct buffer, link);
        spa_list_remove(&b->link);

	od = b->buffer->datas;

	maxsize = od[0].maxsize;

	filled = 0;
	index = 0;
	avail = maxsize - filled;
	offset = index % maxsize;

	if (offset + avail > maxsize)
		avail = maxsize - offset;

	if (d->format.format == SPA_AUDIO_FORMAT_S16)
		fill_s16(d, SPA_MEMBER(b->ptr, offset, void), avail);
	else if (d->format.format == SPA_AUDIO_FORMAT_F32)
		fill_f32(d, SPA_MEMBER(b->ptr, offset, void), avail);

	od[0].chunk->offset = 0;
	od[0].chunk->size = avail;
	od[0].chunk->stride = 0;

	io->buffer_id = b->id;
	io->status = SPA_STATUS_HAVE_DATA;

	update_volume(d);

	return SPA_STATUS_HAVE_DATA;
}

static const struct spa_node_methods impl_node = {
	SPA_VERSION_NODE_METHODS,
	.add_listener = impl_add_listener,
	.set_callbacks = impl_set_callbacks,
	.set_io = impl_set_io,
	.send_command = impl_send_command,
	.port_set_io = impl_port_set_io,
	.port_enum_params = impl_port_enum_params,
	.port_set_param = impl_port_set_param,
	.port_use_buffers = impl_port_use_buffers,
	.port_reuse_buffer = impl_port_reuse_buffer,
	.process = impl_node_process,
};

static void make_node(struct data *data)
{
	struct pw_properties *props;

	props = pw_properties_new(PW_KEY_NODE_AUTOCONNECT, "true",
				  PW_KEY_NODE_EXCLUSIVE, "true",
				  PW_KEY_MEDIA_TYPE, "Audio",
				  PW_KEY_MEDIA_CATEGORY, "Playback",
				  PW_KEY_MEDIA_ROLE, "Music",
				  NULL);
	if (data->path)
		pw_properties_set(props, PW_KEY_NODE_TARGET, data->path);

	data->impl_node.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Node,
			SPA_VERSION_NODE,
			&impl_node, data);
	pw_core_export(data->core, SPA_TYPE_INTERFACE_Node,
			&props->dict, &data->impl_node, 0);
	pw_properties_free(props);
}

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	struct data *d = data;

	pw_log_error("error id:%u seq:%d res:%d (%s): %s",
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE)
		pw_main_loop_quit(d->loop);
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.error = on_core_error,
};

int main(int argc, char *argv[])
{
	struct data data = { 0, };

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL);
	data.context = pw_context_new(pw_main_loop_get_loop(data.loop), NULL, 0);
	data.path = argc > 1 ? argv[1] : NULL;

	data.info_all = SPA_PORT_CHANGE_MASK_FLAGS |
		SPA_PORT_CHANGE_MASK_PROPS |
		SPA_PORT_CHANGE_MASK_PARAMS;
	data.info = SPA_PORT_INFO_INIT();
	data.info.flags = 0;
	data.items[0] = SPA_DICT_ITEM_INIT(PW_KEY_FORMAT_DSP, "32 bit float mono audio");
	data.dict = SPA_DICT_INIT_ARRAY(data.items);
	data.info.props = &data.dict;
	data.params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumFormat, SPA_PARAM_INFO_READ);
	data.params[1] = SPA_PARAM_INFO(SPA_PARAM_Meta, SPA_PARAM_INFO_READ);
	data.params[2] = SPA_PARAM_INFO(SPA_PARAM_IO, SPA_PARAM_INFO_READ);
	data.params[3] = SPA_PARAM_INFO(SPA_PARAM_Format, SPA_PARAM_INFO_WRITE);
	data.params[4] = SPA_PARAM_INFO(SPA_PARAM_Buffers, 0);
	data.info.params = data.params;
	data.info.n_params = 5;

	spa_list_init(&data.empty);
	spa_hook_list_init(&data.hooks);

	if ((data.core = pw_context_connect(data.context, NULL, 0)) == NULL) {
		printf("can't connect: %m\n");
		return -1;
	}

	pw_core_add_listener(data.core, &data.core_listener, &core_events, &data);

	make_node(&data);

	pw_main_loop_run(data.loop);

	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	return 0;
}
