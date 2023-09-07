/* Spa A2DP aptX codec
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

#include <openaptx.h>

#include "defs.h"
#include "rtp.h"
#include "a2dp-codecs.h"

struct impl {
	struct aptx_context *aptx;

	struct rtp_header *header;

	size_t mtu;
	int codesize;
	int frame_length;
	int frame_count;
	int max_frames;

	bool hd;
};

static inline bool codec_is_hd(const struct a2dp_codec *codec) {
	return codec->vendor.codec_id == APTX_HD_CODEC_ID
		&& codec->vendor.vendor_id == APTX_HD_VENDOR_ID;
}

static inline size_t codec_get_caps_size(const struct a2dp_codec *codec) {
	return codec_is_hd(codec) ? sizeof(a2dp_aptx_hd_t) : sizeof(a2dp_aptx_t);
}

static int codec_fill_caps(const struct a2dp_codec *codec, uint32_t flags,
		uint8_t caps[A2DP_MAX_CAPS_SIZE])
{
	size_t actual_conf_size = codec_get_caps_size(codec);
	const a2dp_aptx_t a2dp_aptx = {
		.info = codec->vendor,
		.frequency =
			APTX_SAMPLING_FREQ_16000 |
			APTX_SAMPLING_FREQ_32000 |
			APTX_SAMPLING_FREQ_44100 |
			APTX_SAMPLING_FREQ_48000,
		.channel_mode =
			APTX_CHANNEL_MODE_STEREO,
	};
	memcpy(caps, &a2dp_aptx, sizeof(a2dp_aptx));
	return actual_conf_size;
}

static struct a2dp_codec_config
aptx_frequencies[] = {
	{ APTX_SAMPLING_FREQ_48000, 48000, 3 },
	{ APTX_SAMPLING_FREQ_44100, 44100, 2 },
	{ APTX_SAMPLING_FREQ_32000, 32000, 1 },
	{ APTX_SAMPLING_FREQ_16000, 16000, 0 },
};

static int codec_select_config(const struct a2dp_codec *codec, uint32_t flags,
		const void *caps, size_t caps_size,
		const struct a2dp_codec_audio_info *info,
		const struct spa_dict *settings, uint8_t config[A2DP_MAX_CAPS_SIZE])
{
	a2dp_aptx_t conf;
	int i;
	size_t actual_conf_size = codec_get_caps_size(codec);

	if (caps_size < sizeof(conf) || actual_conf_size < sizeof(conf))
		return -EINVAL;

	memcpy(&conf, caps, sizeof(conf));

	if (codec->vendor.vendor_id != conf.info.vendor_id ||
	    codec->vendor.codec_id != conf.info.codec_id)
		return -ENOTSUP;

	if ((i = a2dp_codec_select_config(aptx_frequencies,
					  SPA_N_ELEMENTS(aptx_frequencies),
					  conf.frequency,
				    	  info ? info->rate : A2DP_CODEC_DEFAULT_RATE
				    	  )) < 0)
		return -ENOTSUP;
	conf.frequency = aptx_frequencies[i].config;

	if (conf.channel_mode & APTX_CHANNEL_MODE_STEREO)
		conf.channel_mode = APTX_CHANNEL_MODE_STEREO;
	else
		return -ENOTSUP;

	memcpy(config, &conf, sizeof(conf));

	return actual_conf_size;
}

static int codec_enum_config(const struct a2dp_codec *codec,
		const void *caps, size_t caps_size, uint32_t id, uint32_t idx,
		struct spa_pod_builder *b, struct spa_pod **param)
{
	a2dp_aptx_t conf;
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
			SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_S24),
			0);
	spa_pod_builder_prop(b, SPA_FORMAT_AUDIO_rate, 0);

	spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_None, 0);
	choice = (struct spa_pod_choice*)spa_pod_builder_frame(b, &f[1]);
	i = 0;
	if (conf.frequency & APTX_SAMPLING_FREQ_48000) {
		if (i++ == 0)
			spa_pod_builder_int(b, 48000);
		spa_pod_builder_int(b, 48000);
	}
	if (conf.frequency & APTX_SAMPLING_FREQ_44100) {
		if (i++ == 0)
			spa_pod_builder_int(b, 44100);
		spa_pod_builder_int(b, 44100);
	}
	if (conf.frequency & APTX_SAMPLING_FREQ_32000) {
		if (i++ == 0)
			spa_pod_builder_int(b, 32000);
		spa_pod_builder_int(b, 32000);
	}
	if (conf.frequency & APTX_SAMPLING_FREQ_16000) {
		if (i++ == 0)
			spa_pod_builder_int(b, 16000);
		spa_pod_builder_int(b, 16000);
	}
	if (i == 0)
		return -EINVAL;
	if (i > 1)
		choice->body.type = SPA_CHOICE_Enum;
	spa_pod_builder_pop(b, &f[1]);

	if (SPA_FLAG_IS_SET(conf.channel_mode, APTX_CHANNEL_MODE_MONO | APTX_CHANNEL_MODE_STEREO)) {
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(2, 1, 2),
				0);
	} else if (conf.channel_mode & APTX_CHANNEL_MODE_MONO) {
		position[0] = SPA_AUDIO_CHANNEL_MONO;
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(1),
				SPA_FORMAT_AUDIO_position, SPA_POD_Array(sizeof(uint32_t),
					SPA_TYPE_Id, 1, position),
				0);
	} else if (conf.channel_mode & APTX_CHANNEL_MODE_STEREO) {
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

static int codec_reduce_bitpool(void *data)
{
	return -ENOTSUP;
}

static int codec_increase_bitpool(void *data)
{
	return -ENOTSUP;
}

static int codec_get_block_size(void *data)
{
	struct impl *this = data;
	return this->codesize;
}

static void *codec_init(const struct a2dp_codec *codec, uint32_t flags,
		void *config, size_t config_len, const struct spa_audio_info *info,
		void *props, size_t mtu)
{
	struct impl *this;
	int res;

	if ((this = calloc(1, sizeof(struct impl))) == NULL)
		goto error_errno;

	this->hd = codec_is_hd(codec);

	if ((this->aptx = aptx_init(this->hd)) == NULL)
		goto error_errno;

	this->mtu = mtu;

	if (info->media_type != SPA_MEDIA_TYPE_audio ||
	    info->media_subtype != SPA_MEDIA_SUBTYPE_raw ||
	    info->info.raw.format != SPA_AUDIO_FORMAT_S24) {
		res = -EINVAL;
		goto error;
	}
	this->frame_length = this->hd ? 6 : 4;
	this->codesize = 4 * 3 * 2;

	if (this->hd)
		this->max_frames = (this->mtu - sizeof(struct rtp_header)) / this->frame_length;
	else
		this->max_frames = this->mtu / this->frame_length;

	return this;

error_errno:
	res = -errno;
	goto error;
error:
	if (this->aptx)
		aptx_finish(this->aptx);
	free(this);
	errno = -res;
	return NULL;
}

static void codec_deinit(void *data)
{
	struct impl *this = data;
	aptx_finish(this->aptx);
	free(this);
}

static int codec_abr_process (void *data, size_t unsent)
{
	return -ENOTSUP;
}

static int codec_start_encode (void *data,
		void *dst, size_t dst_size, uint16_t seqnum, uint32_t timestamp)
{
	struct impl *this = data;

	this->frame_count = 0;

	if (!this->hd)
		return 0;

	this->header = (struct rtp_header *)dst;
	memset(this->header, 0, sizeof(struct rtp_header));

	this->header->v = 2;
	this->header->pt = 1;
	this->header->sequence_number = htons(seqnum);
	this->header->timestamp = htonl(timestamp);
	return sizeof(struct rtp_header);
}

static int codec_encode(void *data,
		const void *src, size_t src_size,
		void *dst, size_t dst_size,
		size_t *dst_out, int *need_flush)
{
	struct impl *this = data;
	size_t avail_dst_size;
	int res;

	avail_dst_size = (this->max_frames - this->frame_count) * this->frame_length;
	if (SPA_UNLIKELY(dst_size < avail_dst_size)) {
		*need_flush = 1;
		return 0;
	}

	res = aptx_encode(this->aptx, src, src_size,
			dst, avail_dst_size, dst_out);
	if(SPA_UNLIKELY(res < 0))
		return -EINVAL;

	this->frame_count += *dst_out / this->frame_length;
	*need_flush = this->frame_count >= this->max_frames;
	return res;
}

static int codec_start_decode (void *data,
		const void *src, size_t src_size, uint16_t *seqnum, uint32_t *timestamp)
{
	struct impl *this = data;

	if (!this->hd)
		return 0;

	const struct rtp_header *header = src;
	size_t header_size = sizeof(struct rtp_header);

	spa_return_val_if_fail(src_size > header_size, -EINVAL);

	if (seqnum)
		*seqnum = ntohs(header->sequence_number);
	if (timestamp)
		*timestamp = ntohl(header->timestamp);
	return header_size;
}

static int codec_decode(void *data,
		const void *src, size_t src_size,
		void *dst, size_t dst_size,
		size_t *dst_out)
{
	struct impl *this = data;
	int res;

	res = aptx_decode(this->aptx, src, src_size,
			dst, dst_size, dst_out);

	return res;
}

const struct a2dp_codec a2dp_codec_aptx = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_APTX,
	.codec_id = A2DP_CODEC_VENDOR,
	.vendor = { .vendor_id = APTX_VENDOR_ID,
		.codec_id = APTX_CODEC_ID },
	.name = "aptx",
	.description = "aptX",
	.fill_caps = codec_fill_caps,
	.select_config = codec_select_config,
	.enum_config = codec_enum_config,
	.init = codec_init,
	.deinit = codec_deinit,
	.get_block_size = codec_get_block_size,
	.abr_process = codec_abr_process,
	.start_encode = codec_start_encode,
	.encode = codec_encode,
	.start_decode = codec_start_decode,
	.decode = codec_decode,
	.reduce_bitpool = codec_reduce_bitpool,
	.increase_bitpool = codec_increase_bitpool,
};


const struct a2dp_codec a2dp_codec_aptx_hd = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_APTX_HD,
	.codec_id = A2DP_CODEC_VENDOR,
	.vendor = { .vendor_id = APTX_HD_VENDOR_ID,
		.codec_id = APTX_HD_CODEC_ID },
	.name = "aptx_hd",
	.description = "aptX HD",
	.fill_caps = codec_fill_caps,
	.select_config = codec_select_config,
	.enum_config = codec_enum_config,
	.init = codec_init,
	.deinit = codec_deinit,
	.get_block_size = codec_get_block_size,
	.abr_process = codec_abr_process,
	.start_encode = codec_start_encode,
	.encode = codec_encode,
	.start_decode = codec_start_decode,
	.decode = codec_decode,
	.reduce_bitpool = codec_reduce_bitpool,
	.increase_bitpool = codec_increase_bitpool,
};
