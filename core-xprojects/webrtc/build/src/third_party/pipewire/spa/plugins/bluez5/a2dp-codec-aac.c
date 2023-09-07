/* Spa A2DP AAC codec
 *
 * Copyright © 2020 Wim Taymans
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

#include <unistd.h>
#include <stddef.h>
#include <errno.h>
#include <arpa/inet.h>

#include <spa/param/audio/format.h>

#include <fdk-aac/aacenc_lib.h>

#include "defs.h"
#include "rtp.h"
#include "a2dp-codecs.h"

#define DEFAULT_AAC_BITRATE	320000
#define MIN_AAC_BITRATE		64000

struct props {
	int bitratemode;
};

struct impl {
	HANDLE_AACENCODER aacenc;

	struct rtp_header *header;

	size_t mtu;
	int codesize;

	int max_bitrate;
	int cur_bitrate;

	uint32_t rate;
	uint32_t channels;
	int samplesize;
};

static int codec_fill_caps(const struct a2dp_codec *codec, uint32_t flags,
		uint8_t caps[A2DP_MAX_CAPS_SIZE])
{
	const a2dp_aac_t a2dp_aac = {
		.object_type =
			/* NOTE: AAC Long Term Prediction and AAC Scalable are
			 *       not supported by the FDK-AAC library. */
			AAC_OBJECT_TYPE_MPEG2_AAC_LC |
			AAC_OBJECT_TYPE_MPEG4_AAC_LC,
		AAC_INIT_FREQUENCY(
			AAC_SAMPLING_FREQ_8000 |
			AAC_SAMPLING_FREQ_11025 |
			AAC_SAMPLING_FREQ_12000 |
			AAC_SAMPLING_FREQ_16000 |
			AAC_SAMPLING_FREQ_22050 |
			AAC_SAMPLING_FREQ_24000 |
			AAC_SAMPLING_FREQ_32000 |
			AAC_SAMPLING_FREQ_44100 |
			AAC_SAMPLING_FREQ_48000 |
			AAC_SAMPLING_FREQ_64000 |
			AAC_SAMPLING_FREQ_88200 |
			AAC_SAMPLING_FREQ_96000)
		.channels =
			AAC_CHANNELS_1 |
			AAC_CHANNELS_2,
		.vbr = 1,
		AAC_INIT_BITRATE(DEFAULT_AAC_BITRATE)
	};
	memcpy(caps, &a2dp_aac, sizeof(a2dp_aac));
	return sizeof(a2dp_aac);
}

static struct a2dp_codec_config
aac_frequencies[] = {
	{ AAC_SAMPLING_FREQ_48000, 48000, 11 },
	{ AAC_SAMPLING_FREQ_44100, 44100, 10 },
	{ AAC_SAMPLING_FREQ_96000, 96000, 9 },
	{ AAC_SAMPLING_FREQ_88200, 88200, 8 },
	{ AAC_SAMPLING_FREQ_64000, 64000, 7 },
	{ AAC_SAMPLING_FREQ_32000, 32000, 6 },
	{ AAC_SAMPLING_FREQ_24000, 24000, 5 },
	{ AAC_SAMPLING_FREQ_22050, 22050, 4 },
	{ AAC_SAMPLING_FREQ_16000, 16000, 3 },
	{ AAC_SAMPLING_FREQ_12000, 12000, 2 },
	{ AAC_SAMPLING_FREQ_11025, 11025, 1 },
	{ AAC_SAMPLING_FREQ_8000,  8000,  0 },
};

static struct a2dp_codec_config
aac_channel_modes[] = {
	{ AAC_CHANNELS_2, 2, 1 },
	{ AAC_CHANNELS_1, 1, 0 },
};

static int get_valid_aac_bitrate(a2dp_aac_t *conf)
{
	if (AAC_GET_BITRATE(*conf) < MIN_AAC_BITRATE) {
		/* Unknown (0) or bogus bitrate */
		return DEFAULT_AAC_BITRATE;
	} else {
		return SPA_MIN(AAC_GET_BITRATE(*conf), DEFAULT_AAC_BITRATE);
	}
}

static int codec_select_config(const struct a2dp_codec *codec, uint32_t flags,
		const void *caps, size_t caps_size,
		const struct a2dp_codec_audio_info *info,
		const struct spa_dict *settings, uint8_t config[A2DP_MAX_CAPS_SIZE])
{
	a2dp_aac_t conf;
	int i;

	if (caps_size < sizeof(conf))
		return -EINVAL;

	conf = *(a2dp_aac_t*)caps;

	if (conf.object_type & AAC_OBJECT_TYPE_MPEG2_AAC_LC)
		conf.object_type = AAC_OBJECT_TYPE_MPEG2_AAC_LC;
	else if (conf.object_type & AAC_OBJECT_TYPE_MPEG4_AAC_LC)
		conf.object_type = AAC_OBJECT_TYPE_MPEG4_AAC_LC;
	else if (conf.object_type & AAC_OBJECT_TYPE_MPEG4_AAC_LTP)
		return -ENOTSUP;  /* Not supported by FDK-AAC */
	else if (conf.object_type & AAC_OBJECT_TYPE_MPEG4_AAC_SCA)
		return -ENOTSUP;  /* Not supported by FDK-AAC */
	else
		return -ENOTSUP;

	if ((i = a2dp_codec_select_config(aac_frequencies,
					  SPA_N_ELEMENTS(aac_frequencies),
					  AAC_GET_FREQUENCY(conf),
				    	  info ? info->rate : A2DP_CODEC_DEFAULT_RATE
				    	  )) < 0)
		return -ENOTSUP;
	AAC_SET_FREQUENCY(conf, aac_frequencies[i].config);

	if ((i = a2dp_codec_select_config(aac_channel_modes,
					  SPA_N_ELEMENTS(aac_channel_modes),
					  conf.channels,
				    	  info ? info->channels : A2DP_CODEC_DEFAULT_CHANNELS
				    	  )) < 0)
		return -ENOTSUP;
	conf.channels = aac_channel_modes[i].config;

	AAC_SET_BITRATE(conf, get_valid_aac_bitrate(&conf));

	memcpy(config, &conf, sizeof(conf));

	return sizeof(conf);
}

static int codec_enum_config(const struct a2dp_codec *codec,
		const void *caps, size_t caps_size, uint32_t id, uint32_t idx,
		struct spa_pod_builder *b, struct spa_pod **param)
{
	a2dp_aac_t conf;
	struct spa_pod_frame f[2];
	struct spa_pod_choice *choice;
	uint32_t position[SPA_AUDIO_MAX_CHANNELS];
	uint32_t i = 0;

	if (caps_size < sizeof(conf))
		return -EINVAL;

	memcpy(&conf, caps, sizeof(conf));

	if (idx > 0)
		return 0;

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_Format, id);
	spa_pod_builder_add(b,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
			SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_S16),
			0);
	spa_pod_builder_prop(b, SPA_FORMAT_AUDIO_rate, 0);

	spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_None, 0);
	choice = (struct spa_pod_choice*)spa_pod_builder_frame(b, &f[1]);
	i = 0;
	for (size_t j = 0; j < SPA_N_ELEMENTS(aac_frequencies); j++) {
		if (AAC_GET_FREQUENCY(conf) & aac_frequencies[j].config) {
			if (i++ == 0)
				spa_pod_builder_int(b, aac_frequencies[j].value);
			spa_pod_builder_int(b, aac_frequencies[j].value);
		}
	}
	if (i == 0)
		return -EINVAL;
	if (i > 1)
		choice->body.type = SPA_CHOICE_Enum;
	spa_pod_builder_pop(b, &f[1]);


	if (SPA_FLAG_IS_SET(conf.channels, AAC_CHANNELS_1 | AAC_CHANNELS_2)) {
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(2, 1, 2),
				0);
	} else if (conf.channels & AAC_CHANNELS_1) {
		position[0] = SPA_AUDIO_CHANNEL_MONO;
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(1),
				SPA_FORMAT_AUDIO_position, SPA_POD_Array(sizeof(uint32_t),
					SPA_TYPE_Id, 1, position),
				0);
	} else if (conf.channels & AAC_CHANNELS_2) {
		position[0] = SPA_AUDIO_CHANNEL_FL;
		position[1] = SPA_AUDIO_CHANNEL_FR;
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(2),
				SPA_FORMAT_AUDIO_position, SPA_POD_Array(sizeof(uint32_t),
					SPA_TYPE_Id, 2, position),
				0);
	} else
		return -EINVAL;

	*param = spa_pod_builder_pop(b, &f[0]);
	return *param == NULL ? -EIO : 1;
}

static void *codec_init_props(const struct a2dp_codec *codec, const struct spa_dict *settings)
{
	struct props *p = calloc(1, sizeof(struct props));
	const char *str;

	if (p == NULL)
		return NULL;

	if (settings == NULL || (str = spa_dict_lookup(settings, "bluez5.a2dp.aac.bitratemode")) == NULL)
		str = "0";

	p->bitratemode = SPA_CLAMP(atoi(str), 0, 5);
	return p;
}

static void codec_clear_props(void *props)
{
	free(props);
}

static void *codec_init(const struct a2dp_codec *codec, uint32_t flags,
		void *config, size_t config_len, const struct spa_audio_info *info,
		void *props, size_t mtu)
{
	struct impl *this;
	a2dp_aac_t *conf = config;
	struct props *p = props;
	UINT bitratemode;
	int res;

	this = calloc(1, sizeof(struct impl));
	if (this == NULL) {
		res = -errno;
		goto error;
	}
	this->mtu = mtu;
	this->rate = info->info.raw.rate;
	this->channels = info->info.raw.channels;

	if (info->media_type != SPA_MEDIA_TYPE_audio ||
	    info->media_subtype != SPA_MEDIA_SUBTYPE_raw ||
	    info->info.raw.format != SPA_AUDIO_FORMAT_S16) {
		res = -EINVAL;
		goto error;
	}
	this->samplesize = 2;

	bitratemode = p ? p->bitratemode : 0;

	res = aacEncOpen(&this->aacenc, 0, this->channels);
	if (res != AACENC_OK)
		goto error;

	if (conf->object_type != AAC_OBJECT_TYPE_MPEG2_AAC_LC &&
	    conf->object_type != AAC_OBJECT_TYPE_MPEG4_AAC_LC) {
		res = -EINVAL;
		goto error;
	}
	res = aacEncoder_SetParam(this->aacenc, AACENC_AOT, AOT_AAC_LC);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_SAMPLERATE, this->rate);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_CHANNELMODE, this->channels);
	if (res != AACENC_OK)
		goto error;

	if (conf->vbr) {
		res = aacEncoder_SetParam(this->aacenc, AACENC_BITRATEMODE,
				bitratemode);
		if (res != AACENC_OK)
			goto error;
	}

	res = aacEncoder_SetParam(this->aacenc, AACENC_AUDIOMUXVER, 2);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_SIGNALING_MODE, 1);
	if (res != AACENC_OK)
		goto error;

	// Fragmentation is not implemented yet,
	// so make sure every encoded AAC frame fits in (mtu - header)
	this->max_bitrate = ((this->mtu - sizeof(struct rtp_header)) * 8 * this->rate) / 1024;
	this->max_bitrate = SPA_MIN(this->max_bitrate, get_valid_aac_bitrate(conf));
	this->cur_bitrate = this->max_bitrate;

	res = aacEncoder_SetParam(this->aacenc, AACENC_BITRATE, this->cur_bitrate);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_PEAK_BITRATE, this->max_bitrate);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_TRANSMUX, TT_MP4_LATM_MCP1);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_HEADER_PERIOD, 1);
	if (res != AACENC_OK)
		goto error;

	res = aacEncoder_SetParam(this->aacenc, AACENC_AFTERBURNER, 1);
	if (res != AACENC_OK)
		goto error;

	res = aacEncEncode(this->aacenc, NULL, NULL, NULL, NULL);
	if (res != AACENC_OK)
		goto error;

	AACENC_InfoStruct enc_info = {};
	res = aacEncInfo(this->aacenc, &enc_info);
	if (res != AACENC_OK)
		goto error;

	this->codesize = enc_info.frameLength * this->channels * this->samplesize;

	return this;

error:
	if (this->aacenc)
		aacEncClose(&this->aacenc);
	free(this);
	errno = -res;
	return NULL;
}

static void codec_deinit(void *data)
{
	struct impl *this = data;
	if (this->aacenc)
		aacEncClose(&this->aacenc);
	free(this);
}

static int codec_get_block_size(void *data)
{
	struct impl *this = data;
	return this->codesize;
}

static int codec_start_encode (void *data,
		void *dst, size_t dst_size, uint16_t seqnum, uint32_t timestamp)
{
	struct impl *this = data;

	this->header = (struct rtp_header *)dst;
	memset(this->header, 0, sizeof(struct rtp_header));

	this->header->v = 2;
	this->header->pt = 96;
	this->header->sequence_number = htons(seqnum);
	this->header->timestamp = htonl(timestamp);
	this->header->ssrc = htonl(1);
	return sizeof(struct rtp_header);
}

static int codec_encode(void *data,
		const void *src, size_t src_size,
		void *dst, size_t dst_size,
		size_t *dst_out, int *need_flush)
{
	struct impl *this = data;
	int res;

	void *in_bufs[] = {(void *) src};
	int in_buf_ids[] = {IN_AUDIO_DATA};
	int in_buf_sizes[] = {src_size};
	int in_buf_el_sizes[] = {this->samplesize};
	AACENC_BufDesc in_buf_desc = {
		.numBufs = 1,
		.bufs = in_bufs,
		.bufferIdentifiers = in_buf_ids,
		.bufSizes = in_buf_sizes,
		.bufElSizes = in_buf_el_sizes,
	};
	AACENC_InArgs in_args = {
		.numInSamples = src_size / this->samplesize,
	};

	void *out_bufs[] = {dst};
	int out_buf_ids[] = {OUT_BITSTREAM_DATA};
	int out_buf_sizes[] = {dst_size};
	int out_buf_el_sizes[] = {this->samplesize};
	AACENC_BufDesc out_buf_desc = {
		.numBufs = 1,
		.bufs = out_bufs,
		.bufferIdentifiers = out_buf_ids,
		.bufSizes = out_buf_sizes,
		.bufElSizes = out_buf_el_sizes,
	};
	AACENC_OutArgs out_args = {};

	res = aacEncEncode(this->aacenc, &in_buf_desc, &out_buf_desc, &in_args, &out_args);
	if (res != AACENC_OK)
		return -EINVAL;

	*dst_out = out_args.numOutBytes;
	*need_flush = 1;

	/* RFC6416: It is set to 1 to indicate that the RTP packet contains a complete
   	 * audioMuxElement or the last fragment of an audioMuxElement */
	this->header->m = 1;

	return out_args.numInSamples * this->samplesize;
}

static int codec_abr_process (void *data, size_t unsent)
{
	return -ENOTSUP;
}

static int codec_change_bitrate(struct impl *this, int new_bitrate)
{
	int res;

	new_bitrate = SPA_MIN(new_bitrate, this->max_bitrate);
	new_bitrate = SPA_MAX(new_bitrate, 64000);

	if (new_bitrate == this->cur_bitrate)
		return 0;

	this->cur_bitrate = new_bitrate;

	res = aacEncoder_SetParam(this->aacenc, AACENC_BITRATE, this->cur_bitrate);
	if (res != AACENC_OK)
		return -EINVAL;

	return 0;
}

static int codec_reduce_bitpool(void *data)
{
	struct impl *this = data;
	return codec_change_bitrate(this, (this->cur_bitrate * 2) / 3);
}

static int codec_increase_bitpool(void *data)
{
	struct impl *this = data;
	return codec_change_bitrate(this, (this->cur_bitrate * 4) / 3);
}

const struct a2dp_codec a2dp_codec_aac = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_AAC,
	.codec_id = A2DP_CODEC_MPEG24,
	.name = "aac",
	.description = "AAC",
	.fill_caps = codec_fill_caps,
	.select_config = codec_select_config,
	.enum_config = codec_enum_config,
	.init_props = codec_init_props,
	.clear_props = codec_clear_props,
	.init = codec_init,
	.deinit = codec_deinit,
	.get_block_size = codec_get_block_size,
	.start_encode = codec_start_encode,
	.encode = codec_encode,
	.abr_process = codec_abr_process,
	.reduce_bitpool = codec_reduce_bitpool,
	.increase_bitpool = codec_increase_bitpool,
};
