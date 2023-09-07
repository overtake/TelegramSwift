/* PipeWire - pw-cat
 *
 * Copyright © 2020 Konsulko Group

 * Author: Pantelis Antoniou <pantelis.antoniou@konsulko.com>
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
#include <errno.h>
#include <time.h>
#include <math.h>
#include <signal.h>
#include <fcntl.h>
#include <getopt.h>
#include <unistd.h>
#include <assert.h>
#include <ctype.h>

#include <sndfile.h>

#include <spa/param/audio/layout.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/audio/type-info.h>
#include <spa/param/props.h>
#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/debug/types.h>

#include <pipewire/pipewire.h>
#include <pipewire/i18n.h>
#include <extensions/metadata.h>

#include "midifile.h"

#define DEFAULT_MEDIA_TYPE	"Audio"
#define DEFAULT_MIDI_MEDIA_TYPE	"Midi"
#define DEFAULT_MEDIA_CATEGORY_PLAYBACK	"Playback"
#define DEFAULT_MEDIA_CATEGORY_RECORD	"Capture"
#define DEFAULT_MEDIA_ROLE	"Music"
#define DEFAULT_TARGET		"auto"
#define DEFAULT_LATENCY_PLAY	"100ms"
#define DEFAULT_LATENCY_REC	"none"
#define DEFAULT_RATE		48000
#define DEFAULT_CHANNELS	2
#define DEFAULT_FORMAT		"s16"
#define DEFAULT_VOLUME		1.0
#define DEFAULT_QUALITY		4

enum mode {
	mode_none,
	mode_playback,
	mode_record
};

enum unit {
	unit_none,
	unit_samples,
	unit_sec,
	unit_msec,
	unit_usec,
	unit_nsec,
};

struct data;

typedef int (*fill_fn)(struct data *d, void *dest, unsigned int n_frames);

struct target {
	struct spa_list link;
	uint32_t id;
	char *name;
	char *desc;
	int prio;
};

struct channelmap {
	int n_channels;
	int channels[SPA_AUDIO_MAX_CHANNELS];
};

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_core *core;
	struct spa_hook core_listener;
	struct pw_registry *registry;
	struct spa_hook registry_listener;
	struct pw_metadata *metadata;
	struct spa_hook metadata_listener;
	char default_sink[1024];
	char default_source[1024];

	struct pw_stream *stream;
	struct spa_hook stream_listener;

	enum mode mode;
	bool verbose;
	bool is_midi;
	const char *remote_name;
	const char *media_type;
	const char *media_category;
	const char *media_role;
	const char *channel_map;
	const char *format;
	const char *target;
	const char *latency;
	struct pw_properties *props;

	const char *filename;
	SNDFILE *file;

	unsigned int rate;
	int channels;
	struct channelmap channelmap;
	unsigned int samplesize;
	unsigned int stride;
	enum unit latency_unit;
	unsigned int latency_value;
	int quality;

	enum spa_audio_format spa_format;

	float volume;
	bool volume_is_set;

	fill_fn fill;

	uint32_t target_id;
	bool list_targets;
	bool targets_listed;
	struct spa_list targets;
	int sync;

	struct spa_io_position *position;
	bool drained;
	uint64_t clock_time;

	struct {
		struct midi_file *file;
		struct midi_file_info info;
	} midi;
};

static inline int
sf_str_to_fmt(const char *str)
{
	if (!str)
		return -1;

	if (!strcmp(str, "s8"))
		return SF_FORMAT_PCM_S8;
	if (!strcmp(str, "s16"))
		return SF_FORMAT_PCM_16;
	if (!strcmp(str, "s24"))
		return SF_FORMAT_PCM_24;
	if (!strcmp(str, "s32"))
		return SF_FORMAT_PCM_32;
	if (!strcmp(str, "f32"))
		return SF_FORMAT_FLOAT;
	if (!strcmp(str, "f64"))
		return SF_FORMAT_DOUBLE;

	return -1;
}

static inline const char *
sf_fmt_to_str(int format)
{
	int sub_type = (format & SF_FORMAT_SUBMASK);

	if (sub_type == SF_FORMAT_PCM_S8)
		return "s8";
	if (sub_type == SF_FORMAT_PCM_16)
		return "s16";
	if (sub_type == SF_FORMAT_PCM_24)
		return "s24";
	if (sub_type == SF_FORMAT_PCM_32)
		return "s32";
	if (sub_type == SF_FORMAT_FLOAT)
		return "f32";
	if (sub_type == SF_FORMAT_DOUBLE)
		return "f64";
	return "(invalid)";
}

#define STR_FMTS "(s8|s16|s32|f32|f64)"

/* 0 = native, 1 = le, 2 = be */
static inline int
sf_format_endianess(int format)
{
	return 0;		/* native */
}

static inline enum spa_audio_format
sf_format_to_pw(int format)
{
	int endianness;

	endianness = sf_format_endianess(format);
	if (endianness < 0)
		return SPA_AUDIO_FORMAT_UNKNOWN;

	switch (format & SF_FORMAT_SUBMASK) {
	case SF_FORMAT_PCM_S8:
		return SPA_AUDIO_FORMAT_S8;
	case SF_FORMAT_PCM_16:
		return endianness == 1 ? SPA_AUDIO_FORMAT_S16_LE :
		       endianness == 2 ? SPA_AUDIO_FORMAT_S16_BE :
		                         SPA_AUDIO_FORMAT_S16;
	case SF_FORMAT_PCM_24:
	case SF_FORMAT_PCM_32:
		return endianness == 1 ? SPA_AUDIO_FORMAT_S32_LE :
		       endianness == 2 ? SPA_AUDIO_FORMAT_S32_BE :
		                         SPA_AUDIO_FORMAT_S32;
	case SF_FORMAT_DOUBLE:
		return endianness == 1 ? SPA_AUDIO_FORMAT_F64_LE :
		       endianness == 2 ? SPA_AUDIO_FORMAT_F64_BE :
		                         SPA_AUDIO_FORMAT_F64;
	case SF_FORMAT_FLOAT:
	default:
		return endianness == 1 ? SPA_AUDIO_FORMAT_F32_LE :
		       endianness == 2 ? SPA_AUDIO_FORMAT_F32_BE :
		                         SPA_AUDIO_FORMAT_F32;
		break;
	}

	return SPA_AUDIO_FORMAT_UNKNOWN;
}

static inline int
sf_format_samplesize(int format)
{
	int sub_type = (format & SF_FORMAT_SUBMASK);

	switch (sub_type) {
	case SF_FORMAT_PCM_S8:
		return 1;
	case SF_FORMAT_PCM_16:
		return 2;
	case SF_FORMAT_PCM_32:
		return 4;
	case SF_FORMAT_DOUBLE:
		return 8;
	case SF_FORMAT_FLOAT:
	default:
		return 4;
	}
	return -1;
}

static int sf_playback_fill_s8(struct data *d, void *dest, unsigned int n_frames)
{
	sf_count_t rn;

	rn = sf_read_raw(d->file, dest, n_frames);
	return (int)rn;
}

static int sf_playback_fill_s16(struct data *d, void *dest, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(short) == sizeof(int16_t));
	rn = sf_readf_short(d->file, dest, n_frames);
	return (int)rn;
}

static int sf_playback_fill_s32(struct data *d, void *dest, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(int) == sizeof(int32_t));
	rn = sf_readf_int(d->file, dest, n_frames);
	return (int)rn;
}

static int sf_playback_fill_f32(struct data *d, void *dest, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(float) == 4);
	rn = sf_readf_float(d->file, dest, n_frames);
	return (int)rn;
}

static int sf_playback_fill_f64(struct data *d, void *dest, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(double) == 8);
	rn = sf_readf_double(d->file, dest, n_frames);
	return (int)rn;
}

static inline fill_fn
sf_fmt_playback_fill_fn(int format)
{
	enum spa_audio_format fmt = sf_format_to_pw(format);

	switch (fmt) {
	case SPA_AUDIO_FORMAT_S8:
		return sf_playback_fill_s8;
	case SPA_AUDIO_FORMAT_S16_LE:
	case SPA_AUDIO_FORMAT_S16_BE:
		/* sndfile check */
		if (sizeof(int16_t) != sizeof(short))
			return NULL;
		return sf_playback_fill_s16;
	case SPA_AUDIO_FORMAT_S32_LE:
	case SPA_AUDIO_FORMAT_S32_BE:
		/* sndfile check */
		if (sizeof(int32_t) != sizeof(int))
			return NULL;
		return sf_playback_fill_s32;
	case SPA_AUDIO_FORMAT_F32_LE:
	case SPA_AUDIO_FORMAT_F32_BE:
		/* sndfile check */
		if (sizeof(float) != 4)
			return NULL;
		return sf_playback_fill_f32;
	case SPA_AUDIO_FORMAT_F64_LE:
	case SPA_AUDIO_FORMAT_F64_BE:
		if (sizeof(double) != 8)
			return NULL;
		return sf_playback_fill_f64;
	default:
		break;
	}
	return NULL;
}

static int sf_record_fill_s8(struct data *d, void *src, unsigned int n_frames)
{
	sf_count_t rn;

	rn = sf_write_raw(d->file, src, n_frames);
	return (int)rn;
}

static int sf_record_fill_s16(struct data *d, void *src, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(short) == sizeof(int16_t));
	rn = sf_writef_short(d->file, src, n_frames);
	return (int)rn;
}

static int sf_record_fill_s32(struct data *d, void *src, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(int) == sizeof(int32_t));
	rn = sf_writef_int(d->file, src, n_frames);
	return (int)rn;
}

static int sf_record_fill_f32(struct data *d, void *src, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(float) == 4);
	rn = sf_writef_float(d->file, src, n_frames);
	return (int)rn;
}

static int sf_record_fill_f64(struct data *d, void *src, unsigned int n_frames)
{
	sf_count_t rn;

	assert(sizeof(double) == 8);
	rn = sf_writef_double(d->file, src, n_frames);
	return (int)rn;
}

static inline fill_fn
sf_fmt_record_fill_fn(int format)
{
	enum spa_audio_format fmt = sf_format_to_pw(format);

	switch (fmt) {
	case SPA_AUDIO_FORMAT_S8:
		return sf_record_fill_s8;
	case SPA_AUDIO_FORMAT_S16_LE:
	case SPA_AUDIO_FORMAT_S16_BE:
		/* sndfile check */
		if (sizeof(int16_t) != sizeof(short))
			return NULL;
		return sf_record_fill_s16;
	case SPA_AUDIO_FORMAT_S32_LE:
	case SPA_AUDIO_FORMAT_S32_BE:
		/* sndfile check */
		if (sizeof(int32_t) != sizeof(int))
			return NULL;
		return sf_record_fill_s32;
	case SPA_AUDIO_FORMAT_F32_LE:
	case SPA_AUDIO_FORMAT_F32_BE:
		/* sndfile check */
		if (sizeof(float) != 4)
			return NULL;
		return sf_record_fill_f32;
	case SPA_AUDIO_FORMAT_F64_LE:
	case SPA_AUDIO_FORMAT_F64_BE:
		/* sndfile check */
		if (sizeof(double) != 8)
			return NULL;
		return sf_record_fill_f64;
	default:
		break;
	}
	return NULL;
}

static int channelmap_from_sf(struct channelmap *map)
{
	static const enum spa_audio_channel table[] = {
		[SF_CHANNEL_MAP_MONO] =                  SPA_AUDIO_CHANNEL_MONO,
		[SF_CHANNEL_MAP_LEFT] =                  SPA_AUDIO_CHANNEL_FL, /* libsndfile distinguishes left and front-left, which we don't */
		[SF_CHANNEL_MAP_RIGHT] =                 SPA_AUDIO_CHANNEL_FR,
		[SF_CHANNEL_MAP_CENTER] =                SPA_AUDIO_CHANNEL_FC,
		[SF_CHANNEL_MAP_FRONT_LEFT] =            SPA_AUDIO_CHANNEL_FL,
		[SF_CHANNEL_MAP_FRONT_RIGHT] =           SPA_AUDIO_CHANNEL_FR,
		[SF_CHANNEL_MAP_FRONT_CENTER] =          SPA_AUDIO_CHANNEL_FC,
		[SF_CHANNEL_MAP_REAR_CENTER] =           SPA_AUDIO_CHANNEL_RC,
		[SF_CHANNEL_MAP_REAR_LEFT] =             SPA_AUDIO_CHANNEL_RL,
		[SF_CHANNEL_MAP_REAR_RIGHT] =            SPA_AUDIO_CHANNEL_RR,
		[SF_CHANNEL_MAP_LFE] =                   SPA_AUDIO_CHANNEL_LFE,
		[SF_CHANNEL_MAP_FRONT_LEFT_OF_CENTER] =  SPA_AUDIO_CHANNEL_FLC,
		[SF_CHANNEL_MAP_FRONT_RIGHT_OF_CENTER] = SPA_AUDIO_CHANNEL_FRC,
		[SF_CHANNEL_MAP_SIDE_LEFT] =             SPA_AUDIO_CHANNEL_SL,
		[SF_CHANNEL_MAP_SIDE_RIGHT] =            SPA_AUDIO_CHANNEL_SR,
		[SF_CHANNEL_MAP_TOP_CENTER] =            SPA_AUDIO_CHANNEL_TC,
		[SF_CHANNEL_MAP_TOP_FRONT_LEFT] =        SPA_AUDIO_CHANNEL_TFL,
		[SF_CHANNEL_MAP_TOP_FRONT_RIGHT] =       SPA_AUDIO_CHANNEL_TFR,
		[SF_CHANNEL_MAP_TOP_FRONT_CENTER] =      SPA_AUDIO_CHANNEL_TFC,
		[SF_CHANNEL_MAP_TOP_REAR_LEFT] =         SPA_AUDIO_CHANNEL_TRL,
		[SF_CHANNEL_MAP_TOP_REAR_RIGHT] =        SPA_AUDIO_CHANNEL_TRR,
		[SF_CHANNEL_MAP_TOP_REAR_CENTER] =       SPA_AUDIO_CHANNEL_TRC
	};
	int i;

	for (i = 0; i < map->n_channels; i++) {
		if (map->channels[i] >= 0 && map->channels[i] < (int) SPA_N_ELEMENTS(table))
			map->channels[i] = table[map->channels[i]];
		else
			map->channels[i] = SPA_AUDIO_CHANNEL_UNKNOWN;
	}
	return 0;
}
struct mapping {
	const char *name;
	unsigned int channels;
	unsigned int values[32];
};

static const struct mapping maps[] =
{
	{ "mono",         SPA_AUDIO_LAYOUT_Mono },
	{ "stereo",       SPA_AUDIO_LAYOUT_Stereo },
	{ "surround-21",  SPA_AUDIO_LAYOUT_2_1 },
	{ "quad",         SPA_AUDIO_LAYOUT_Quad },
	{ "surround-22",  SPA_AUDIO_LAYOUT_2_2 },
	{ "surround-40",  SPA_AUDIO_LAYOUT_4_0 },
	{ "surround-31",  SPA_AUDIO_LAYOUT_3_1 },
	{ "surround-41",  SPA_AUDIO_LAYOUT_4_1 },
	{ "surround-50",  SPA_AUDIO_LAYOUT_5_0 },
	{ "surround-51",  SPA_AUDIO_LAYOUT_5_1 },
	{ "surround-51r", SPA_AUDIO_LAYOUT_5_1R },
	{ "surround-70",  SPA_AUDIO_LAYOUT_7_0 },
	{ "surround-71",  SPA_AUDIO_LAYOUT_7_1 },
};

static unsigned int find_channel(const char *name)
{
	int i;

	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static int parse_channelmap(const char *channel_map, struct channelmap *map)
{
	int i, nch;
	char **ch;

	for (i = 0; i < (int) SPA_N_ELEMENTS(maps); i++) {
		if (strcmp(maps[i].name, channel_map) == 0) {
			map->n_channels = maps[i].channels;
			spa_memcpy(map->channels, &maps[i].values,
					map->n_channels * sizeof(unsigned int));
			return 0;
		}
	}

	ch = pw_split_strv(channel_map, ",", SPA_AUDIO_MAX_CHANNELS, &nch);
	if (ch == NULL)
		return -1;

	map->n_channels = nch;
	for (i = 0; i < map->n_channels; i++) {
		int c = find_channel(ch[i]);
		map->channels[i] = c;
	}
	pw_free_strv(ch);
	return 0;
}

static int channelmap_default(struct channelmap *map, int n_channels)
{
	switch(n_channels) {
	case 1:
		parse_channelmap("mono", map);
		break;
	case 2:
		parse_channelmap("stereo", map);
		break;
	case 3:
		parse_channelmap("surround-21", map);
		break;
	case 4:
		parse_channelmap("quad", map);
		break;
	case 5:
		parse_channelmap("surround-50", map);
		break;
	case 6:
		parse_channelmap("surround-51", map);
		break;
	case 7:
		parse_channelmap("surround-70", map);
		break;
	case 8:
		parse_channelmap("surround-71", map);
		break;
	default:
		n_channels = 0;
		break;
	}
	map->n_channels = n_channels;
	return 0;
}

static void channelmap_print(struct channelmap *map)
{
	int i;

	for (i = 0; i < map->n_channels; i++) {
		const char *name = spa_debug_type_find_name(spa_type_audio_channel, map->channels[i]);
		if (name == NULL)
			name = ":UNK";
		printf("%s%s", spa_debug_type_short_name(name), i + 1 < map->n_channels ? "," : "");
	}
}

static void
target_destroy(struct target *target)
{
	if (!target)
		return;
	if (target->name)
		free(target->name);
	if (target->desc)
		free(target->desc);
	free(target);
}

static struct target *
target_create(uint32_t id, const char *name, const char *desc, int prio)
{
	struct target *target;

	target = malloc(sizeof(*target));
	if (!target)
		return NULL;
	target->id = id;
	target->name = strdup(name);
	target->desc = strdup(desc ? : "");
	target->prio = prio;

	if (!target->name || !target->desc) {
		target_destroy(target);
		return NULL;
	}
	return target;
}

static void on_core_info(void *userdata, const struct pw_core_info *info)
{
	struct data *data = userdata;

	if (data->verbose)
		fprintf(stdout, "remote %"PRIu32" is named \"%s\"\n",
				info->id, info->name);
}

static void on_core_done(void *userdata, uint32_t id, int seq)
{
	struct data *data = userdata;

	if (data->verbose)
		printf("core done\n");

	/* if we're listing targets just exist */
	if (data->sync == seq && data->list_targets) {
		data->targets_listed = true;
		pw_main_loop_quit(data->loop);
	}
}

static void on_core_error(void *userdata, uint32_t id, int seq, int res, const char *message)
{
	struct data *data = userdata;

	fprintf(stderr, "remote error: id=%"PRIu32" seq:%d res:%d (%s): %s\n",
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

static int json_object_find(const char *obj, const char *key, char *value, size_t len)
{
	struct spa_json it[2];
	const char *v;
	char k[128];

	spa_json_init(&it[0], obj, strlen(obj));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], k, sizeof(k)-1) > 0) {
		if (strcmp(k, key) == 0) {
			if (spa_json_get_string(&it[1], value, len) <= 0)
				continue;
			return 0;
		} else {
			if (spa_json_next(&it[1], &v) <= 0)
				break;
		}
	}
	return -ENOENT;
}

static int metadata_property(void *object,
		uint32_t subject, const char *key, const char *type, const char *value)
{
	struct data *data = object;

	if (subject == PW_ID_CORE) {
		if (key == NULL || strcmp(key, "default.audio.sink") == 0) {
			if (value == NULL ||
			    json_object_find(value, "name",
					data->default_sink, sizeof(data->default_sink)) < 0)
				data->default_sink[0] = '\0';
		}
		if (key == NULL || strcmp(key, "default.audio.source") == 0) {
			if (value == NULL ||
			    json_object_find(value, "name",
					data->default_source, sizeof(data->default_source)) < 0)
				data->default_source[0] = '\0';
		}
	}
	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

static void registry_event_global(void *userdata, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	struct data *data = userdata;
	const struct spa_dict_item *item;
	const char *name, *desc, *media_class, *prio_session;
	int prio;
	enum mode mode = mode_none;
	struct target *target;

	/* only once */
	if (data->targets_listed)
		return;

	/* must be listing targets and interface must be a node */
	if (!data->list_targets)
		return;

	if (strcmp(type, PW_TYPE_INTERFACE_Metadata) == 0) {
		if (data->metadata != NULL)
			return;

		data->metadata = pw_registry_bind(data->registry,
				id, type, PW_VERSION_METADATA, 0);
		pw_metadata_add_listener(data->metadata,
				&data->metadata_listener,
				&metadata_events, data);

		data->sync = pw_core_sync(data->core, 0, data->sync);

	} else if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		name = spa_dict_lookup(props, PW_KEY_NODE_NAME);
		desc = spa_dict_lookup(props, PW_KEY_NODE_DESCRIPTION);
		media_class = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS);
		prio_session = spa_dict_lookup(props, PW_KEY_PRIORITY_SESSION);

		/* name and media class must exist */
		if (!name || !media_class)
			return;

		/* get allowed mode from the media class */
		/* TODO extend to something else besides Audio/Source|Sink */
		if (!strcmp(media_class, "Audio/Source"))
			mode = mode_record;
		else if (!strcmp(media_class, "Audio/Sink"))
			mode = mode_playback;

		/* modes must match */
		if (mode != data->mode)
			return;

		prio = prio_session ? atoi(prio_session) : -1;

		if (data->verbose) {
			printf("registry: id=%"PRIu32" type=%s name=\"%s\" media_class=\"%s\" desc=\"%s\" prio=%d\n",
					id, type, name, media_class, desc ? : "", prio);

			spa_dict_for_each(item, props) {
				fprintf(stdout, "\t\t%s = \"%s\"\n", item->key, item->value);
			}
		}

		target = target_create(id, name, desc, prio);
		if (target)
			spa_list_append(&data->targets, &target->link);
	}
}

static void registry_event_global_remove(void *userdata, uint32_t id)
{
	struct data *data = userdata;

	if (data->verbose)
		printf("registry: remove id=%"PRIu32"\n", id);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
	.global_remove = registry_event_global_remove,
};

static void
on_state_changed(void *userdata, enum pw_stream_state old,
		 enum pw_stream_state state, const char *error)
{
	struct data *data = userdata;
	int ret;

	if (data->verbose)
		printf("stream state changed %s -> %s\n",
				pw_stream_state_as_string(old),
				pw_stream_state_as_string(state));

	if (state == PW_STREAM_STATE_STREAMING && !data->volume_is_set) {

		ret = pw_stream_set_control(data->stream,
				SPA_PROP_volume, 1, &data->volume,
				0);
		if (data->verbose)
			printf("set stream volume to %.3f - %s\n", data->volume,
					ret == 0 ? "success" : "FAILED");

		data->volume_is_set = true;

	}

	if (state == PW_STREAM_STATE_STREAMING) {
		if (data->verbose)
			printf("stream node %"PRIu32"\n",
				pw_stream_get_node_id(data->stream));
	}
	if (state == PW_STREAM_STATE_ERROR) {
		printf("stream node %"PRIu32" error: %s\n",
				pw_stream_get_node_id(data->stream),
				error);
		pw_main_loop_quit(data->loop);
	}
}

static void
on_io_changed(void *userdata, uint32_t id, void *data, uint32_t size)
{
	struct data *d = userdata;

	switch (id) {
	case SPA_IO_Position:
		d->position = data;
		break;
	default:
		break;
	}
}

static void
on_param_changed(void *userdata, uint32_t id, const struct spa_pod *format)
{
	struct data *data = userdata;

	if (data->verbose)
		printf("stream param change: id=%"PRIu32"\n",
				id);
}

static void on_process(void *userdata)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;
	struct spa_data *d;
	int n_frames, n_fill_frames;
	uint8_t *p;
	bool have_data;
	uint32_t offset, size;

	if ((b = pw_stream_dequeue_buffer(data->stream)) == NULL)
		return;

	buf = b->buffer;
	d = &buf->datas[0];

	have_data = false;

	if ((p = d->data) == NULL)
		return;

	if (data->mode == mode_playback) {

		n_frames = d->maxsize / data->stride;

		n_fill_frames = data->fill(data, p, n_frames);

		if (n_fill_frames > 0) {
			d->chunk->offset = 0;
			d->chunk->stride = data->stride;
			d->chunk->size = n_fill_frames * data->stride;
			have_data = true;
		} else if (n_fill_frames < 0)
			fprintf(stderr, "fill error %d\n", n_fill_frames);
	} else {
		offset = SPA_MIN(d->chunk->offset, d->maxsize);
		size = SPA_MIN(d->chunk->size, d->maxsize - offset);

		p += offset;

		n_frames = size / data->stride;

		n_fill_frames = data->fill(data, p, n_frames);

		have_data = true;
	}

	if (have_data) {
		pw_stream_queue_buffer(data->stream, b);
		return;
	}

	if (data->mode == mode_playback)
		pw_stream_flush(data->stream, true);
}

static void on_drained(void *userdata)
{
	struct data *data = userdata;

	if (data->verbose)
		printf("stream drained\n");

	data->drained = true;
	pw_main_loop_quit(data->loop);
}

static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.state_changed = on_state_changed,
	.io_changed = on_io_changed,
	.param_changed = on_param_changed,
	.process = on_process,
	.drained = on_drained
};

static void do_quit(void *userdata, int signal_number)
{
	struct data *data = userdata;
	pw_main_loop_quit(data->loop);
}

static void do_print_delay(void *userdata, uint64_t expirations)
{
	struct data *data = userdata;
	struct pw_time time;
	pw_stream_get_time(data->stream, &time);
	printf("now=%li rate=%u/%u ticks=%lu delay=%li queued=%lu\n",
		time.now,
		time.rate.num, time.rate.denom,
		time.ticks, time.delay, time.queued);
}

enum {
	OPT_VERSION = 1000,
	OPT_MEDIA_TYPE,
	OPT_MEDIA_CATEGORY,
	OPT_MEDIA_ROLE,
	OPT_TARGET,
	OPT_LATENCY,
	OPT_RATE,
	OPT_CHANNELS,
	OPT_CHANNELMAP,
	OPT_FORMAT,
	OPT_VOLUME,
	OPT_LIST_TARGETS,
};

static const struct option long_options[] = {
	{ "help",		no_argument,	   NULL, 'h' },
	{ "version",		no_argument,	   NULL, OPT_VERSION},
	{ "verbose",		no_argument,	   NULL, 'v' },

	{ "record",		no_argument,	   NULL, 'r' },
	{ "playback",		no_argument,	   NULL, 'p' },
	{ "midi",		no_argument,	   NULL, 'm' },

	{ "remote",		required_argument, NULL, 'R' },

	{ "media-type",		required_argument, NULL, OPT_MEDIA_TYPE },
	{ "media-category",	required_argument, NULL, OPT_MEDIA_CATEGORY },
	{ "media-role",		required_argument, NULL, OPT_MEDIA_ROLE },
	{ "target",		required_argument, NULL, OPT_TARGET },
	{ "latency",		required_argument, NULL, OPT_LATENCY },

	{ "rate",		required_argument, NULL, OPT_RATE },
	{ "channels",		required_argument, NULL, OPT_CHANNELS },
	{ "channel-map",	required_argument, NULL, OPT_CHANNELMAP },
	{ "format",		required_argument, NULL, OPT_FORMAT },
	{ "volume",		required_argument, NULL, OPT_VOLUME },
	{ "quality",		required_argument, NULL, 'q' },

	{ "list-targets",	no_argument, NULL, OPT_LIST_TARGETS },

	{ NULL, 0, NULL, 0 }
};

static void show_usage(const char *name, bool is_error)
{
	FILE *fp;

	fp = is_error ? stderr : stdout;

        fprintf(fp,
	   _("%s [options] <file>\n"
             "  -h, --help                            Show this help\n"
             "      --version                         Show version\n"
             "  -v, --verbose                         Enable verbose operations\n"
	     "\n"), name);

	fprintf(fp,
           _("  -R, --remote                          Remote daemon name\n"
             "      --media-type                      Set media type (default %s)\n"
             "      --media-category                  Set media category (default %s)\n"
             "      --media-role                      Set media role (default %s)\n"
             "      --target                          Set node target (default %s)\n"
	     "                                          0 means don't link\n"
             "      --latency                         Set node latency (default %s)\n"
	     "                                          Xunit (unit = s, ms, us, ns)\n"
	     "                                          or direct samples (256)\n"
	     "                                          the rate is the one of the source file\n"
	     "      --list-targets                    List available targets for --target\n"
	     "\n"),
	     DEFAULT_MEDIA_TYPE,
	     DEFAULT_MEDIA_CATEGORY_PLAYBACK,
	     DEFAULT_MEDIA_ROLE,
	     DEFAULT_TARGET, DEFAULT_LATENCY_PLAY);

	fprintf(fp,
           _("      --rate                            Sample rate (req. for rec) (default %u)\n"
             "      --channels                        Number of channels (req. for rec) (default %u)\n"
             "      --channel-map                     Channel map\n"
	     "                                            one of: \"stereo\", \"surround-51\",... or\n"
	     "                                            comma separated list of channel names: eg. \"FL,FR\"\n"
             "      --format                          Sample format %s (req. for rec) (default %s)\n"
	     "      --volume                          Stream volume 0-1.0 (default %.3f)\n"
	     "  -q  --quality                         Resampler quality (0 - 15) (default %d)\n"
	     "\n"),
	     DEFAULT_RATE,
	     DEFAULT_CHANNELS,
	     STR_FMTS, DEFAULT_FORMAT,
	     DEFAULT_VOLUME,
	     DEFAULT_QUALITY);

	if (!strcmp(name, "pw-cat")) {
		fputs(
		   _("  -p, --playback                        Playback mode\n"
		     "  -r, --record                          Recording mode\n"
		     "  -m, --midi                            Midi mode\n"
		     "\n"), fp);
	}
}

static int midi_play(struct data *d, void *src, unsigned int n_frames)
{
	int res;
	struct spa_pod_builder b;
	struct spa_pod_frame f;
	uint32_t first_frame, last_frame;
	bool have_data = false;

	spa_zero(b);
	spa_pod_builder_init(&b, src, n_frames);

        spa_pod_builder_push_sequence(&b, &f, 0);

	first_frame = d->clock_time;
	last_frame = first_frame + d->position->clock.duration;
	d->clock_time = last_frame;

	while (1) {
		uint32_t frame;
		struct midi_event ev;

		res = midi_file_next_time(d->midi.file, &ev.sec);
		if (res <= 0) {
			if (have_data)
				break;
			return res;
		}

		frame = ev.sec * d->position->clock.rate.denom;
		if (frame < first_frame)
			frame = 0;
		else if (frame < last_frame)
			frame -= first_frame;
		else
			break;

		midi_file_read_event(d->midi.file, &ev);

		if (d->verbose)
			midi_file_dump_event(stdout, &ev);

		if (ev.data[0] == 0xff)
			continue;

		spa_pod_builder_control(&b, frame, SPA_CONTROL_Midi);
		spa_pod_builder_bytes(&b, ev.data, ev.size);
		have_data = true;
	}
	spa_pod_builder_pop(&b, &f);

	return b.state.offset;
}

static int midi_record(struct data *d, void *src, unsigned int n_frames)
{
	struct spa_pod *pod;
	struct spa_pod_control *c;
	uint32_t frame;

	frame = d->clock_time;
	d->clock_time += d->position->clock.duration;

	if ((pod = spa_pod_from_data(src, n_frames, 0, n_frames)) == NULL)
		return 0;
	if (!spa_pod_is_sequence(pod))
		return 0;

	SPA_POD_SEQUENCE_FOREACH((struct spa_pod_sequence*)pod, c) {
		struct midi_event ev;

		if (c->type != SPA_CONTROL_Midi)
			continue;

		ev.track = 0;
		ev.sec = (frame + c->offset) / (float) d->position->clock.rate.denom;
		ev.data = SPA_POD_BODY(&c->value),
		ev.size = SPA_POD_BODY_SIZE(&c->value);

		if (d->verbose)
			midi_file_dump_event(stdout, &ev);

		midi_file_write_event(d->midi.file, &ev);
	}
	return 0;
}

static int setup_midifile(struct data *data)
{
	if (data->mode == mode_record) {
		spa_zero(data->midi.info);
		data->midi.info.format = 0;
		data->midi.info.ntracks = 1;
		data->midi.info.division = 0;
	}

	data->midi.file = midi_file_open(data->filename,
			data->mode == mode_playback ? "r" : "w",
			&data->midi.info);
	if (data->midi.file == NULL) {
		fprintf(stderr, "error: can't read midi file '%s': %m\n", data->filename);
		return -errno;
	}

	if (data->verbose)
		printf("opened file \"%s\" format %08x ntracks:%d div:%d\n",
				data->filename,
				data->midi.info.format, data->midi.info.ntracks,
				data->midi.info.division);

	data->fill = data->mode == mode_playback ?  midi_play : midi_record;
	data->stride = 1;

	return 0;
}

static int fill_properties(struct data *data)
{
	static const char* table[] = {
		[SF_STR_TITLE] = PW_KEY_MEDIA_TITLE,
		[SF_STR_COPYRIGHT] = PW_KEY_MEDIA_COPYRIGHT,
		[SF_STR_SOFTWARE] = PW_KEY_MEDIA_SOFTWARE,
		[SF_STR_ARTIST] = PW_KEY_MEDIA_ARTIST,
		[SF_STR_COMMENT] = PW_KEY_MEDIA_COMMENT,
		[SF_STR_DATE] = PW_KEY_MEDIA_DATE
	};
	SF_INFO sfi;
	SF_FORMAT_INFO fi;
	int res;
	unsigned c;
	const char *s, *t;

	for (c = 0; c < SPA_N_ELEMENTS(table); c++) {
		if (table[c] == NULL)
			continue;

		if ((s = sf_get_string(data->file, c)) == NULL ||
		    *s == '\0')
			continue;

		pw_properties_set(data->props, table[c], s);
	}

	spa_zero(sfi);
	if ((res = sf_command(data->file, SFC_GET_CURRENT_SF_INFO, &sfi, sizeof(sfi)))) {
		pw_log_error("sndfile: %s", sf_error_number(res));
		return -EIO;
	}

	spa_zero(fi);
	fi.format = sfi.format;
	if (sf_command(data->file, SFC_GET_FORMAT_INFO, &fi, sizeof(fi)) == 0 && fi.name)
		pw_properties_set(data->props, PW_KEY_MEDIA_FORMAT, fi.name);

	s = pw_properties_get(data->props, PW_KEY_MEDIA_TITLE);
	t = pw_properties_get(data->props, PW_KEY_MEDIA_ARTIST);
	if (s && t)
		pw_properties_setf(data->props, PW_KEY_MEDIA_NAME,
				"'%s' / '%s'", s, t);

	return 0;
}

static int setup_sndfile(struct data *data)
{
	SF_INFO info;
	const char *s;
	unsigned int nom = 0;

	spa_zero(info);
	/* for record, you fill in the info first */
	if (data->mode == mode_record) {
		if (data->format == NULL)
			data->format = DEFAULT_FORMAT;
		if (data->channels == 0)
			data->channels = DEFAULT_CHANNELS;
		if (data->rate == 0)
			data->rate = DEFAULT_RATE;
		if (data->channelmap.n_channels == 0)
			channelmap_default(&data->channelmap, data->channels);

		memset(&info, 0, sizeof(info));
		info.samplerate = data->rate;
		info.channels = data->channels;
		info.format = sf_str_to_fmt(data->format);
		if (info.format == -1) {
			fprintf(stderr, "error: unknown format \"%s\"\n", data->format);
			return -EINVAL;
		}
		info.format |= SF_FORMAT_WAV;
#if __BYTE_ORDER == __BIG_ENDIAN
		info.format |= SF_ENDIAN_BIG;
#else
		info.format |= SF_ENDIAN_LITTLE;
#endif
	}

	data->file = sf_open(data->filename,
			data->mode == mode_playback ? SFM_READ : SFM_WRITE,
			&info);
	if (!data->file) {
		fprintf(stderr, "error: failed to open audio file \"%s\": %s\n",
				data->filename, sf_strerror(NULL));
		return -EIO;
	}

	if (data->verbose)
		printf("opened file \"%s\" format %08x channels:%d rate:%d\n",
				data->filename, info.format, info.channels, info.samplerate);
	if (data->channels > 0 && info.channels != data->channels) {
		printf("given channels (%u) don't match file channels (%d)\n",
				data->channels, info.channels);
		return -EINVAL;
	}

	data->rate = info.samplerate;
	data->channels = info.channels;

	if (data->mode == mode_playback) {
		if (data->channelmap.n_channels == 0) {
			bool def = false;

			if (sf_command(data->file, SFC_GET_CHANNEL_MAP_INFO,
					data->channelmap.channels,
					sizeof(data->channelmap.channels[0]) * data->channels)) {
				data->channelmap.n_channels = data->channels;
				if (channelmap_from_sf(&data->channelmap) < 0)
					data->channelmap.n_channels = 0;
			}
			if (data->channelmap.n_channels == 0) {
				channelmap_default(&data->channelmap, data->channels);
				def = true;
			}
			if (data->verbose) {
				printf("using %s channel map: ", def ? "default" : "file");
				channelmap_print(&data->channelmap);
				printf("\n");
			}
		}
		fill_properties(data);
	}
	data->samplesize = sf_format_samplesize(info.format);
	data->stride = data->samplesize * data->channels;
	data->spa_format = sf_format_to_pw(info.format);
	data->fill = data->mode == mode_playback ?
			sf_fmt_playback_fill_fn(info.format) :
			sf_fmt_record_fill_fn(info.format);

	data->latency_unit = unit_none;

	s = data->latency;
	while (*s && isdigit(*s))
		s++;
	if (!*s)
		data->latency_unit = unit_samples;
	else if (!strcmp(s, "none"))
		data->latency_unit = unit_none;
	else if (!strcmp(s, "s") || !strcmp(s, "sec") || !strcmp(s, "secs"))
		data->latency_unit = unit_sec;
	else if (!strcmp(s, "ms") || !strcmp(s, "msec") || !strcmp(s, "msecs"))
		data->latency_unit = unit_msec;
	else if (!strcmp(s, "us") || !strcmp(s, "usec") || !strcmp(s, "usecs"))
		data->latency_unit = unit_usec;
	else if (!strcmp(s, "ns") || !strcmp(s, "nsec") || !strcmp(s, "nsecs"))
		data->latency_unit = unit_nsec;
	else {
		fprintf(stderr, "error: bad latency value %s (bad unit)\n", data->latency);
		return -EINVAL;
	}
	data->latency_value = atoi(data->latency);
	if (!data->latency_value && data->latency_unit != unit_none) {
		fprintf(stderr, "error: bad latency value %s (is zero)\n", data->latency);
		return -EINVAL;
	}

	switch (data->latency_unit) {
	case unit_sec:
		nom = data->latency_value * data->rate;
		break;
	case unit_msec:
		nom = nearbyint((data->latency_value * data->rate) / 1000.0);
		break;
	case unit_usec:
		nom = nearbyint((data->latency_value * data->rate) / 1000000.0);
		break;
	case unit_nsec:
		nom = nearbyint((data->latency_value * data->rate) / 1000000000.0);
		break;
	case unit_samples:
		nom = data->latency_value;
		break;
	default:
		nom = 0;
		break;
	}

	if (data->verbose)
		printf("rate=%u channels=%u fmt=%s samplesize=%u stride=%u latency=%u (%.3fs)\n",
				data->rate, data->channels,
				sf_fmt_to_str(info.format),
				data->samplesize,
				data->stride, nom, (double)nom/data->rate);
	if (nom)
		pw_properties_setf(data->props, PW_KEY_NODE_LATENCY, "%u/%u", nom, data->rate);

	if (data->quality >= 0)
		pw_properties_setf(data->props, "resample.quality", "%d", data->quality);

	return 0;
}

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	struct pw_loop *l;
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
	const char *prog;
	int exit_code = EXIT_FAILURE, c, ret;
	enum pw_stream_flags flags = 0;

	pw_init(&argc, &argv);

	flags |= PW_STREAM_FLAG_AUTOCONNECT;

	prog = argv[0];
	if ((prog = strrchr(argv[0], '/')) != NULL)
		prog++;
	else
		prog = argv[0];

	/* prime the mode from the program name */
	if (!strcmp(prog, "pw-play"))
		data.mode = mode_playback;
	else if (!strcmp(prog, "pw-record"))
		data.mode = mode_record;
	else if (!strcmp(prog, "pw-midiplay")) {
		data.mode = mode_playback;
		data.is_midi = true;
	} else if (!strcmp(prog, "pw-midirecord")) {
		data.mode = mode_record;
		data.is_midi = true;
	} else
		data.mode = mode_none;

	/* negative means no volume adjustment */
	data.volume = -1.0;
	data.quality = -1;

	/* initialize list every time */
	spa_list_init(&data.targets);

	while ((c = getopt_long(argc, argv, "hvprmR:q:", long_options, NULL)) != -1) {

		switch (c) {

		case 'h':
			show_usage(prog, false);
			return EXIT_SUCCESS;

		case OPT_VERSION:
			fprintf(stdout, "%s\n"
				"Compiled with libpipewire %s\n"
				"Linked with libpipewire %s\n",
				prog,
				pw_get_headers_version(),
				pw_get_library_version());
			return 0;

		case 'v':
			data.verbose = true;
			break;

		case 'p':
			data.mode = mode_playback;
			break;

		case 'r':
			data.mode = mode_record;
			break;

		case 'm':
			data.is_midi = true;
			break;

		case 'R':
			data.remote_name = optarg;
			break;

		case 'q':
			data.quality = atoi(optarg);
			break;

		case OPT_MEDIA_TYPE:
			data.media_type = optarg;
			break;

		case OPT_MEDIA_CATEGORY:
			data.media_category = optarg;
			break;

		case OPT_MEDIA_ROLE:
			data.media_role = optarg;
			break;

		case OPT_TARGET:
			data.target = optarg;
			if (!strcmp(optarg, "auto")) {
				data.target_id = PW_ID_ANY;
				break;
			}
			if (!isdigit(optarg[0])) {
				fprintf(stderr, "error: bad target option \"%s\"\n", optarg);
				goto error_usage;
			}
			data.target_id = atoi(optarg);
			if (data.target_id == 0) {
				data.target_id = PW_ID_ANY;
				flags &= ~PW_STREAM_FLAG_AUTOCONNECT;
			}
			break;

		case OPT_LATENCY:
			data.latency = optarg;
			break;

		case OPT_RATE:
			ret = atoi(optarg);
			if (ret <= 0) {
				fprintf(stderr, "error: bad rate %d\n", ret);
				goto error_usage;
			}
			data.rate = (unsigned int)ret;
			break;

		case OPT_CHANNELS:
			ret = atoi(optarg);
			if (ret <= 0) {
				fprintf(stderr, "error: bad channels %d\n", ret);
				goto error_usage;
			}
			data.channels = (unsigned int)ret;
			break;

		case OPT_CHANNELMAP:
			data.channel_map = optarg;
			break;

		case OPT_FORMAT:
			data.format = optarg;
			break;

		case OPT_VOLUME:
			data.volume = atof(optarg);
			break;

		case OPT_LIST_TARGETS:
			data.list_targets = true;
			break;

		default:
			fprintf(stderr, "error: unknown option '%c'\n", c);
			goto error_usage;
		}
	}

	if (data.mode == mode_none) {
		fprintf(stderr, "error: one of the playback/record options must be provided\n");
		goto error_usage;
	}

	if (!data.media_type) {
		if (data.is_midi)
			data.media_type = DEFAULT_MIDI_MEDIA_TYPE;
		else
			data.media_type = DEFAULT_MEDIA_TYPE;
	}
	if (!data.media_category)
		data.media_category = data.mode == mode_playback ?
					DEFAULT_MEDIA_CATEGORY_PLAYBACK :
					DEFAULT_MEDIA_CATEGORY_RECORD;
	if (!data.media_role)
		data.media_role = DEFAULT_MEDIA_ROLE;
	if (!data.target) {
		data.target = DEFAULT_TARGET;
		data.target_id = PW_ID_ANY;
	}
	if (!data.latency)
		data.latency = data.mode == mode_playback ?
			DEFAULT_LATENCY_PLAY :
			DEFAULT_LATENCY_REC;
	if (data.channel_map != NULL) {
		if (parse_channelmap(data.channel_map, &data.channelmap) < 0) {
			fprintf(stderr, "error: can parse channel-map \"%s\"\n", data.channel_map);
			goto error_usage;

		} else {
			if (data.channels > 0 && data.channelmap.n_channels != data.channels) {
				fprintf(stderr, "error: channels and channel-map incompatible\n");
				goto error_usage;
			}
			data.channels = data.channelmap.n_channels;
		}
	}
	if (data.volume < 0)
		data.volume = DEFAULT_VOLUME;

	if (!data.list_targets && optind >= argc) {
		fprintf(stderr, "error: filename argument missing\n");
		goto error_usage;
	}
	data.filename = argv[optind++];

	data.props = pw_properties_new(
			PW_KEY_MEDIA_TYPE, data.media_type,
			PW_KEY_MEDIA_CATEGORY, data.media_category,
			PW_KEY_MEDIA_ROLE, data.media_role,
			PW_KEY_APP_NAME, prog,
			PW_KEY_MEDIA_FILENAME, data.filename,
			PW_KEY_MEDIA_NAME, data.filename,
			PW_KEY_NODE_NAME, prog,
			NULL);

	if (data.props == NULL) {
		fprintf(stderr, "error: pw_properties_new() failed: %m\n");
		goto error_no_props;
	}

	/* make a main loop. If you already have another main loop, you can add
	 * the fd of this pipewire mainloop to it. */
	data.loop = pw_main_loop_new(NULL);
	if (!data.loop) {
		fprintf(stderr, "error: pw_main_loop_new() failed: %m\n");
		goto error_no_main_loop;
	}

	l = pw_main_loop_get_loop(data.loop);
	pw_loop_add_signal(l, SIGINT, do_quit, &data);
	pw_loop_add_signal(l, SIGTERM, do_quit, &data);

	data.context = pw_context_new(l,
			pw_properties_new(
				PW_KEY_CONFIG_NAME, "client-rt.conf",
				NULL),
			0);
	if (!data.context) {
		fprintf(stderr, "error: pw_context_new() failed: %m\n");
		goto error_no_context;
	}

	data.core = pw_context_connect(data.context,
			pw_properties_new(
				PW_KEY_REMOTE_NAME, data.remote_name,
				NULL),
			0);
	if (!data.core) {
		fprintf(stderr, "error: pw_context_connect() failed: %m\n");
		goto error_ctx_connect_failed;
	}
	pw_core_add_listener(data.core, &data.core_listener, &core_events, &data);

	data.registry = pw_core_get_registry(data.core, PW_VERSION_REGISTRY, 0);
	if (!data.registry) {
		fprintf(stderr, "error: pw_core_get_registry() failed: %m\n");
		goto error_no_registry;
	}
	pw_registry_add_listener(data.registry, &data.registry_listener, &registry_events, &data);

	data.sync = pw_core_sync(data.core, 0, data.sync);

	if (!data.list_targets) {
		struct spa_audio_info_raw info;

		if (data.is_midi)
			ret = setup_midifile(&data);
		else
			ret = setup_sndfile(&data);

		if (ret < 0) {
			fprintf(stderr, "error: open failed: %s\n", spa_strerror(ret));
			switch (ret) {
			case -EIO:
				goto error_bad_file;
			case -EINVAL:
			default:
				goto error_usage;
			}
		}

		if (!data.is_midi) {
			info = SPA_AUDIO_INFO_RAW_INIT(
				.flags = data.channelmap.n_channels ? 0 : SPA_AUDIO_FLAG_UNPOSITIONED,
				.format = data.spa_format,
				.rate = data.rate,
				.channels = data.channels);

			if (data.channelmap.n_channels)
				memcpy(info.position, data.channelmap.channels, data.channels * sizeof(int));

			params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info);
		} else {
			params[0] = spa_pod_builder_add_object(&b,
					SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
					SPA_FORMAT_mediaType,		SPA_POD_Id(SPA_MEDIA_TYPE_application),
					SPA_FORMAT_mediaSubtype,	SPA_POD_Id(SPA_MEDIA_SUBTYPE_control));

			pw_properties_set(data.props, PW_KEY_FORMAT_DSP, "8 bit raw midi");
		}

		data.stream = pw_stream_new(data.core, prog, data.props);
		data.props = NULL;

		if (data.stream == NULL) {
			fprintf(stderr, "error: failed to create stream: %m\n");
			goto error_no_stream;
		}
		pw_stream_add_listener(data.stream, &data.stream_listener, &stream_events, &data);

		if (data.verbose)
			printf("connecting %s stream; target_id=%"PRIu32"\n",
					data.mode == mode_playback ? "playback" : "record",
					data.target_id);

		if (data.verbose) {
			struct timespec timeout = {0, 1}, interval = {1, 0};
			struct spa_source *timer = pw_loop_add_timer(l, do_print_delay, &data);
			pw_loop_update_timer(l, timer, &timeout, &interval, false);
		}

		ret = pw_stream_connect(data.stream,
				  data.mode == mode_playback ? PW_DIRECTION_OUTPUT : PW_DIRECTION_INPUT,
				  data.target_id,
				  flags |
				  PW_STREAM_FLAG_MAP_BUFFERS,
				  params, 1);
		if (ret < 0) {
			fprintf(stderr, "error: failed connect: %s\n", spa_strerror(ret));
			goto error_connect_fail;
		}

		if (data.verbose) {
			const struct pw_properties *props;
			void *pstate;
			const char *key, *val;

			if ((props = pw_stream_get_properties(data.stream)) != NULL) {
				printf("stream properties:\n");
				pstate = NULL;
				while ((key = pw_properties_iterate(props, &pstate)) != NULL &&
					(val = pw_properties_get(props, key)) != NULL) {
					printf("\t%s = \"%s\"\n", key, val);
				}
			}
		}
	}

	/* and wait while we let things run */
	pw_main_loop_run(data.loop);

	/* we're returning OK only if got to the point to drain */
	if (!data.list_targets) {
		if (data.drained)
			exit_code = EXIT_SUCCESS;
	} else {
		if (data.targets_listed) {
			struct target *target, *target_default;
			char *default_name;

			default_name = (data.mode == mode_record) ?
				data.default_source : data.default_sink;

			exit_code = EXIT_SUCCESS;

			/* first find the highest priority */
			target_default = NULL;
			spa_list_for_each(target, &data.targets, link) {
				if (target_default == NULL ||
				    strcmp(default_name, target->name) == 0 ||
				    (default_name[0] == '\0' &&
				     target->prio > target_default->prio))
					target_default = target;
			}
			printf("Available targets (\"*\" denotes default): %s\n", default_name);
			spa_list_for_each(target, &data.targets, link) {
				printf("%s\t%"PRIu32": description=\"%s\" prio=%d\n",
				       target == target_default ? "*" : "",
				       target->id, target->desc, target->prio);
			}
		}
	}

	/* destroy targets */
	while (!spa_list_is_empty(&data.targets)) {
		struct target *target;
		target = spa_list_last(&data.targets, struct target, link);
		spa_list_remove(&target->link);
		target_destroy(target);
	}

error_connect_fail:
	if (data.stream)
		pw_stream_destroy(data.stream);
error_no_stream:
	if (data.metadata)
		pw_proxy_destroy((struct pw_proxy*)data.metadata);
	if (data.registry)
		pw_proxy_destroy((struct pw_proxy*)data.registry);
error_no_registry:
	pw_core_disconnect(data.core);
error_ctx_connect_failed:
	pw_context_destroy(data.context);
error_no_context:
	pw_main_loop_destroy(data.loop);
error_no_props:
error_no_main_loop:
error_bad_file:
	if (data.props)
		pw_properties_free(data.props);
	if (data.file)
		sf_close(data.file);
	if (data.midi.file)
		midi_file_close(data.midi.file);
	pw_deinit();
	return exit_code;

error_usage:
	show_usage(prog, true);
	return EXIT_FAILURE;
}
