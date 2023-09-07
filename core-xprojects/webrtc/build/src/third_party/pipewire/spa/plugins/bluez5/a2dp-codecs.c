/*
 * BlueALSA - bluez-a2dp.c
 * Copyright (c) 2016-2017 Arkadiusz Bokowy
 *
 * This file is a part of bluez-alsa.
 *
 * This project is licensed under the terms of the MIT license.
 *
 */

#include "a2dp-codecs.h"

int a2dp_codec_select_config(const struct a2dp_codec_config configs[], size_t n,
			     uint32_t cap, int preferred_value)
{
	size_t i;
	int *scores, res;
	unsigned int max_priority;

	if (n == 0)
		return -EINVAL;

	scores = calloc(n, sizeof(int));
	if (scores == NULL)
		return -errno;

	max_priority = configs[0].priority;
	for (i = 1; i < n; ++i) {
		if (configs[i].priority > max_priority)
			max_priority = configs[i].priority;
	}

	for (i = 0; i < n; ++i) {
		if (!(configs[i].config & cap)) {
			scores[i] = -1;
			continue;
		}
		if (configs[i].value == preferred_value)
			scores[i] = 100 * (max_priority + 1);
		else if (configs[i].value > preferred_value)
			scores[i] = 10 * (max_priority + 1);
		else
			scores[i] = 1;

		scores[i] *= configs[i].priority + 1;
	}

	res = 0;
	for (i = 1; i < n; ++i) {
		if (scores[i] > scores[res])
			res = i;
	}

	if (scores[res] < 0)
		res = -EINVAL;

	free(scores);
	return res;
}

bool a2dp_codec_check_caps(const struct a2dp_codec *codec, unsigned int codec_id,
			   const void *caps, size_t caps_size,
			   const struct a2dp_codec_audio_info *info)
{
	uint8_t config[A2DP_MAX_CAPS_SIZE];
	int res;

	if (codec_id != codec->codec_id)
		return false;

	if (caps == NULL)
		return false;

	res = codec->select_config(codec, 0, caps, caps_size, info, NULL, config);
	if (res < 0)
		return false;

	return ((size_t)res == caps_size);
}

#if ENABLE_MP3
const a2dp_mpeg_t bluez_a2dp_mpeg = {
	.layer =
		MPEG_LAYER_MP1 |
		MPEG_LAYER_MP2 |
		MPEG_LAYER_MP3,
	.crc = 1,
	.channel_mode =
		MPEG_CHANNEL_MODE_MONO |
		MPEG_CHANNEL_MODE_DUAL_CHANNEL |
		MPEG_CHANNEL_MODE_STEREO |
		MPEG_CHANNEL_MODE_JOINT_STEREO,
	.mpf = 1,
	.frequency =
		MPEG_SAMPLING_FREQ_16000 |
		MPEG_SAMPLING_FREQ_22050 |
		MPEG_SAMPLING_FREQ_24000 |
		MPEG_SAMPLING_FREQ_32000 |
		MPEG_SAMPLING_FREQ_44100 |
		MPEG_SAMPLING_FREQ_48000,
	.bitrate =
		MPEG_BIT_RATE_VBR |
		MPEG_BIT_RATE_320000 |
		MPEG_BIT_RATE_256000 |
		MPEG_BIT_RATE_224000 |
		MPEG_BIT_RATE_192000 |
		MPEG_BIT_RATE_160000 |
		MPEG_BIT_RATE_128000 |
		MPEG_BIT_RATE_112000 |
		MPEG_BIT_RATE_96000 |
		MPEG_BIT_RATE_80000 |
		MPEG_BIT_RATE_64000 |
		MPEG_BIT_RATE_56000 |
		MPEG_BIT_RATE_48000 |
		MPEG_BIT_RATE_40000 |
		MPEG_BIT_RATE_32000 |
		MPEG_BIT_RATE_FREE,
};
#endif

extern struct a2dp_codec a2dp_codec_sbc;
extern struct a2dp_codec a2dp_codec_sbc_xq;
#if ENABLE_LDAC
extern struct a2dp_codec a2dp_codec_ldac;
#endif
#if ENABLE_AAC
extern struct a2dp_codec a2dp_codec_aac;
#endif
#if ENABLE_MP3
extern struct a2dp_codec a2dp_codec_mpeg;
#endif
#if ENABLE_APTX
extern struct a2dp_codec a2dp_codec_aptx;
extern struct a2dp_codec a2dp_codec_aptx_hd;
#endif

const struct a2dp_codec *a2dp_codec_list[] = {
#if ENABLE_LDAC
	&a2dp_codec_ldac,
#endif
#if ENABLE_APTX
	&a2dp_codec_aptx_hd,
	&a2dp_codec_aptx,
#endif
#if ENABLE_AAC
	&a2dp_codec_aac,
#endif
#if ENABLE_MP3
	&a2dp_codec_mpeg,
#endif
	&a2dp_codec_sbc_xq,
	&a2dp_codec_sbc,
	NULL,
};
const struct a2dp_codec **a2dp_codecs = a2dp_codec_list;
