/* Spa ALSA Sink
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

#ifndef SPA_ALSA_UTILS_H
#define SPA_ALSA_UTILS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <math.h>

#include <alsa/asoundlib.h>

#include <spa/support/plugin.h>
#include <spa/support/loop.h>
#include <spa/support/log.h>
#include <spa/utils/list.h>
#include <spa/utils/json.h>

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/node/io.h>
#include <spa/debug/types.h>
#include <spa/param/param.h>
#include <spa/param/audio/format-utils.h>

#include "dll.h"

#define MIN_LATENCY	16
#define MAX_LATENCY	8192

#define DEFAULT_RATE		48000u
#define DEFAULT_CHANNELS	2u
#define DEFAULT_USE_CHMAP	false

struct props {
	char device[64];
	char device_name[128];
	char card_name[128];
	uint32_t min_latency;
	uint32_t max_latency;
	bool use_chmap;
};

#define MAX_BUFFERS 32

struct buffer {
	uint32_t id;
#define BUFFER_FLAG_OUT	(1<<0)
	uint32_t flags;
	struct spa_buffer *buf;
	struct spa_meta_header *h;
	struct spa_list link;
};

#define BW_MAX		0.128
#define BW_MED		0.064
#define BW_MIN		0.016
#define BW_PERIOD	(3 * SPA_NSEC_PER_SEC)

struct channel_map {
	uint32_t channels;
	uint32_t pos[SPA_AUDIO_MAX_CHANNELS];
};
struct state {
	struct spa_handle handle;
	struct spa_node node;

	struct spa_log *log;
	struct spa_system *data_system;
	struct spa_loop *data_loop;

	snd_pcm_stream_t stream;
	snd_output_t *output;

	struct spa_hook_list hooks;
	struct spa_callbacks callbacks;

	uint64_t info_all;
	struct spa_node_info info;
	struct spa_param_info params[8];
	struct props props;

	bool opened;
	snd_pcm_t *hndl;
	int card;

	bool have_format;
	struct spa_audio_info current_format;

	uint32_t default_period_size;
	uint32_t default_headroom;
	uint32_t default_start_delay;
	uint32_t default_format;
	unsigned int default_channels;
	unsigned int default_rate;
	struct channel_map default_pos;
	unsigned int disable_mmap;
	unsigned int disable_batch;

	snd_pcm_uframes_t buffer_frames;
	snd_pcm_uframes_t period_frames;
	snd_pcm_format_t format;
	int rate;
	int channels;
	size_t frame_size;
	int blocks;
	int rate_denom;
	uint32_t delay;
	uint32_t read_size;

	uint64_t port_info_all;
	struct spa_port_info port_info;
	struct spa_param_info port_params[8];
	struct spa_io_buffers *io;
	struct spa_io_clock *clock;
	struct spa_io_position *position;
	struct spa_io_rate_match *rate_match;

	struct buffer buffers[MAX_BUFFERS];
	unsigned int n_buffers;

	struct spa_list free;
	struct spa_list ready;

	size_t ready_offset;

	bool started;
	struct spa_source source;
	int timerfd;
	uint32_t threshold;
	uint32_t last_threshold;
	uint32_t headroom;
	uint32_t start_delay;

	uint32_t duration;
	uint32_t last_duration;
	uint64_t last_position;
	unsigned int alsa_started:1;
	unsigned int alsa_sync:1;
	unsigned int alsa_recovering:1;
	unsigned int following:1;
	unsigned int matching:1;
	unsigned int resample:1;
	unsigned int use_mmap:1;
	unsigned int planar:1;

	int64_t sample_count;

	int64_t sample_time;
	uint64_t current_time;
	uint64_t next_time;
	uint64_t base_time;

	uint64_t underrun;

	struct spa_dll dll;
	double max_error;
};

int
spa_alsa_enum_format(struct state *state, int seq,
		     uint32_t start, uint32_t num,
		     const struct spa_pod *filter);

int spa_alsa_set_format(struct state *state, struct spa_audio_info *info, uint32_t flags);

int spa_alsa_open(struct state *state);
int spa_alsa_start(struct state *state);
int spa_alsa_reassign_follower(struct state *state);
int spa_alsa_pause(struct state *state);
int spa_alsa_close(struct state *state);

int spa_alsa_write(struct state *state);
int spa_alsa_read(struct state *state, snd_pcm_uframes_t silence);

void spa_alsa_recycle_buffer(struct state *state, uint32_t buffer_id);

static inline uint32_t spa_alsa_format_from_name(const char *name, size_t len)
{
	int i;
	for (i = 0; spa_type_audio_format[i].name; i++) {
		if (strncmp(name, spa_debug_type_short_name(spa_type_audio_format[i].name), len) == 0)
			return spa_type_audio_format[i].type;
	}
	return SPA_AUDIO_FORMAT_UNKNOWN;
}

static inline uint32_t spa_alsa_channel_from_name(const char *name)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static inline void spa_alsa_parse_position(struct channel_map *map, const char *val, size_t len)
{
	struct spa_json it[2];
	char v[256];

	spa_json_init(&it[0], val, len);
        if (spa_json_enter_array(&it[0], &it[1]) <= 0)
                spa_json_init(&it[1], val, len);

	map->channels = 0;
	while (spa_json_get_string(&it[1], v, sizeof(v)) > 0 &&
	    map->channels < SPA_AUDIO_MAX_CHANNELS) {
		map->pos[map->channels++] = spa_alsa_channel_from_name(v);
	}
}

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* SPA_ALSA_UTILS_H */
