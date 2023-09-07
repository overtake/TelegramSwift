/* Spa A2DP LDAC codec
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

#include <spa/pod/parser.h>
#include <spa/param/props.h>
#include <spa/param/audio/format.h>

#include <ldacBT.h>

#ifdef ENABLE_LDAC_ABR
#include <ldacBT_abr.h>
#endif

#include "defs.h"
#include "rtp.h"
#include "a2dp-codecs.h"

#define LDACBT_EQMID_AUTO -1

#define LDAC_ABR_MAX_PACKET_NBYTES 1280

#define LDAC_ABR_INTERVAL_MS 5 /* 2 frames * 128 lsu / 48000 */

/* decrease ABR thresholds to increase stability */
#define LDAC_ABR_THRESHOLD_CRITICAL 6
#define LDAC_ABR_THRESHOLD_DANGEROUSTREND 4
#define LDAC_ABR_THRESHOLD_SAFETY_FOR_HQSQ 3

#define LDAC_ABR_SOCK_BUFFER_SIZE (LDAC_ABR_THRESHOLD_CRITICAL * LDAC_ABR_MAX_PACKET_NBYTES)


struct props {
	int eqmid;
};

struct impl {
	HANDLE_LDAC_BT ldac;
#ifdef ENABLE_LDAC_ABR
	HANDLE_LDAC_ABR ldac_abr;
#endif
	bool enable_abr;

	struct rtp_header *header;
	struct rtp_payload *payload;

	int mtu;
	int eqmid;
	int frequency;
	int fmt;
	int codesize;
	int frame_length;
	int frame_count;
};

static int codec_fill_caps(const struct a2dp_codec *codec, uint32_t flags, uint8_t caps[A2DP_MAX_CAPS_SIZE])
{
	const a2dp_ldac_t a2dp_ldac = {
		.info.vendor_id = LDAC_VENDOR_ID,
		.info.codec_id = LDAC_CODEC_ID,
		.frequency = LDACBT_SAMPLING_FREQ_044100 |
			LDACBT_SAMPLING_FREQ_048000 |
			LDACBT_SAMPLING_FREQ_088200 |
			LDACBT_SAMPLING_FREQ_096000,
		.channel_mode = LDACBT_CHANNEL_MODE_MONO |
			LDACBT_CHANNEL_MODE_DUAL_CHANNEL |
			LDACBT_CHANNEL_MODE_STEREO,
	};
	memcpy(caps, &a2dp_ldac, sizeof(a2dp_ldac));
	return sizeof(a2dp_ldac);
}

static struct a2dp_codec_config
ldac_frequencies[] = {
	{ LDACBT_SAMPLING_FREQ_044100, 44100, 3 },
	{ LDACBT_SAMPLING_FREQ_048000, 48000, 2 },
	{ LDACBT_SAMPLING_FREQ_088200, 88200, 1 },
	{ LDACBT_SAMPLING_FREQ_096000, 96000, 0 },
};

static struct a2dp_codec_config
ldac_channel_modes[] = {
	{ LDACBT_CHANNEL_MODE_STEREO,       2, 2 },
	{ LDACBT_CHANNEL_MODE_DUAL_CHANNEL, 2, 1 },
	{ LDACBT_CHANNEL_MODE_MONO,         1, 0 },
};

static int codec_select_config(const struct a2dp_codec *codec, uint32_t flags,
		const void *caps, size_t caps_size,
		const struct a2dp_codec_audio_info *info,
		const struct spa_dict *settings, uint8_t config[A2DP_MAX_CAPS_SIZE])
{
	a2dp_ldac_t conf;
	int i;

        if (caps_size < sizeof(conf))
                return -EINVAL;

	memcpy(&conf, caps, sizeof(conf));

	if (codec->vendor.vendor_id != conf.info.vendor_id ||
	    codec->vendor.codec_id != conf.info.codec_id)
		return -ENOTSUP;

	if ((i = a2dp_codec_select_config(ldac_frequencies,
					  SPA_N_ELEMENTS(ldac_frequencies),
					  conf.frequency,
				    	  info ? info->rate : A2DP_CODEC_DEFAULT_RATE
					  )) < 0)
		return -ENOTSUP;
	conf.frequency = ldac_frequencies[i].config;

	if ((i = a2dp_codec_select_config(ldac_channel_modes,
					  SPA_N_ELEMENTS(ldac_channel_modes),
				    	  conf.channel_mode,
				    	  info ? info->channels : A2DP_CODEC_DEFAULT_CHANNELS
				    	  )) < 0)
		return -ENOTSUP;
	conf.channel_mode = ldac_channel_modes[i].config;

	memcpy(config, &conf, sizeof(conf));

        return sizeof(conf);
}

static int codec_enum_config(const struct a2dp_codec *codec,
		const void *caps, size_t caps_size, uint32_t id, uint32_t idx,
		struct spa_pod_builder *b, struct spa_pod **param)
{
	a2dp_ldac_t conf;
        struct spa_pod_frame f[2];
	struct spa_pod_choice *choice;
	uint32_t i = 0;
	uint32_t position[SPA_AUDIO_MAX_CHANNELS];

	if (caps_size < sizeof(conf))
		return -EINVAL;

	memcpy(&conf, caps, sizeof(conf));

	if (idx > 0)
		return 0;

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_Format, id);
	spa_pod_builder_add(b,
			SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
			SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
			SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(5,
								SPA_AUDIO_FORMAT_F32,
								SPA_AUDIO_FORMAT_F32,
								SPA_AUDIO_FORMAT_S32,
								SPA_AUDIO_FORMAT_S24,
								SPA_AUDIO_FORMAT_S16),
			0);
	spa_pod_builder_prop(b, SPA_FORMAT_AUDIO_rate, 0);

	spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_None, 0);
	choice = (struct spa_pod_choice*)spa_pod_builder_frame(b, &f[1]);
	i = 0;
	if (conf.frequency & LDACBT_SAMPLING_FREQ_048000) {
		if (i++ == 0)
			spa_pod_builder_int(b, 48000);
		spa_pod_builder_int(b, 48000);
	}
	if (conf.frequency & LDACBT_SAMPLING_FREQ_044100) {
		if (i++ == 0)
			spa_pod_builder_int(b, 44100);
		spa_pod_builder_int(b, 44100);
	}
	if (conf.frequency & LDACBT_SAMPLING_FREQ_088200) {
		if (i++ == 0)
			spa_pod_builder_int(b, 88200);
		spa_pod_builder_int(b, 88200);
	}
	if (conf.frequency & LDACBT_SAMPLING_FREQ_096000) {
		if (i++ == 0)
			spa_pod_builder_int(b, 96000);
		spa_pod_builder_int(b, 96000);
	}
	if (i == 0)
		return -EINVAL;
	if (i > 1)
		choice->body.type = SPA_CHOICE_Enum;
	spa_pod_builder_pop(b, &f[1]);

	if (conf.channel_mode & LDACBT_CHANNEL_MODE_MONO &&
	    conf.channel_mode & (LDACBT_CHANNEL_MODE_STEREO |
		    LDACBT_CHANNEL_MODE_DUAL_CHANNEL)) {
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_CHOICE_RANGE_Int(2, 1, 2),
				0);
	} else if (conf.channel_mode & LDACBT_CHANNEL_MODE_MONO) {
		position[0] = SPA_AUDIO_CHANNEL_MONO;
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(1),
				SPA_FORMAT_AUDIO_position, SPA_POD_Array(sizeof(uint32_t),
					SPA_TYPE_Id, 1, position),
				0);
	} else {
		position[0] = SPA_AUDIO_CHANNEL_FL;
		position[1] = SPA_AUDIO_CHANNEL_FR;
		spa_pod_builder_add(b,
				SPA_FORMAT_AUDIO_channels, SPA_POD_Int(2),
				SPA_FORMAT_AUDIO_position, SPA_POD_Array(sizeof(uint32_t),
					SPA_TYPE_Id, 2, position),
				0);
	}
	*param = spa_pod_builder_pop(b, &f[0]);
	return *param == NULL ? -EIO : 1;
}

static int codec_reduce_bitpool(void *data)
{
#ifdef ENABLE_LDAC_ABR
	return -ENOTSUP;
#else
	struct impl *this = data;
	int res;
	if (this->eqmid == LDACBT_EQMID_BITRATE_330000 || !this->enable_abr)
		return this->eqmid;
	res = ldacBT_alter_eqmid_priority(this->ldac, LDACBT_EQMID_INC_CONNECTION);
	return res;
#endif
}

static int codec_increase_bitpool(void *data)
{
#ifdef ENABLE_LDAC_ABR
	return -ENOTSUP;
#else
	struct impl *this = data;
	int res;
	if (!this->enable_abr)
		return this->eqmid;
	res = ldacBT_alter_eqmid_priority(this->ldac, LDACBT_EQMID_INC_QUALITY);
	return res;
#endif
}

static int codec_get_block_size(void *data)
{
	struct impl *this = data;
	return this->codesize;
}

static int string_to_eqmid(const char * eqmid)
{
	if (!strcmp("auto", eqmid))
		return LDACBT_EQMID_AUTO;
	else if (!strcmp("hq", eqmid))
		return LDACBT_EQMID_HQ;
	else if (!strcmp("sq", eqmid))
		return LDACBT_EQMID_SQ;
	else if (!strcmp("mq", eqmid))
		return LDACBT_EQMID_MQ;
	else
		return LDACBT_EQMID_AUTO;
}

static void *codec_init_props(const struct a2dp_codec *codec, const struct spa_dict *settings)
{
	struct props *p = calloc(1, sizeof(struct props));
	const char *str;

	if (p == NULL)
		return NULL;

	if (settings == NULL || (str = spa_dict_lookup(settings, "bluez5.a2dp.ldac.quality")) == NULL)
		str = "auto";

	p->eqmid = string_to_eqmid(str);
	return p;
}

static void codec_clear_props(void *props)
{
	free(props);
}

static int codec_enum_props(void *props, const struct spa_dict *settings, uint32_t id, uint32_t idx,
			struct spa_pod_builder *b, struct spa_pod **param)
{
	struct props *p = props;
	struct spa_pod_frame f[2];
	switch (id) {
	case SPA_PARAM_PropInfo:
	{
		switch (idx) {
		case 0:
			spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_PropInfo, id);
			spa_pod_builder_prop(b, SPA_PROP_INFO_id, 0);
			spa_pod_builder_id(b, SPA_PROP_quality);
			spa_pod_builder_prop(b, SPA_PROP_INFO_name, 0);
			spa_pod_builder_string(b, "LDAC quality");

			spa_pod_builder_prop(b, SPA_PROP_INFO_type, 0);
			spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_Enum, 0);
			spa_pod_builder_frame(b, &f[1]);
			spa_pod_builder_int(b, p->eqmid);
			spa_pod_builder_int(b, LDACBT_EQMID_AUTO);
			spa_pod_builder_int(b, LDACBT_EQMID_HQ);
			spa_pod_builder_int(b, LDACBT_EQMID_SQ);
			spa_pod_builder_int(b, LDACBT_EQMID_MQ);
			spa_pod_builder_pop(b, &f[1]);

			spa_pod_builder_prop(b, SPA_PROP_INFO_labels, 0);
			spa_pod_builder_push_struct(b, &f[1]);
			spa_pod_builder_int(b, LDACBT_EQMID_AUTO);
			spa_pod_builder_string(b, "auto");
			spa_pod_builder_int(b, LDACBT_EQMID_HQ);
			spa_pod_builder_string(b, "hq");
			spa_pod_builder_int(b, LDACBT_EQMID_SQ);
			spa_pod_builder_string(b, "sq");
			spa_pod_builder_int(b, LDACBT_EQMID_MQ);
			spa_pod_builder_string(b, "mq");
			spa_pod_builder_pop(b, &f[1]);

			*param = spa_pod_builder_pop(b, &f[0]);
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Props:
	{
		switch (idx) {
		case 0:
			*param = spa_pod_builder_add_object(b,
				SPA_TYPE_OBJECT_Props, id,
				SPA_PROP_quality, SPA_POD_Int(p->eqmid));
			break;
		default:
			return 0;
		}
		break;
	}
	default:
		return -ENOENT;
	}
	return 1;
}

static int codec_set_props(void *props, const struct spa_pod *param)
{
	struct props *p = props;
	const int prev_eqmid = p->eqmid;
	if (param == NULL) {
		p->eqmid = LDACBT_EQMID_AUTO;
	} else {
		spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_Props, NULL,
				SPA_PROP_quality, SPA_POD_OPT_Int(&p->eqmid));
		if (p->eqmid != LDACBT_EQMID_AUTO &&
			(p->eqmid < LDACBT_EQMID_HQ || p->eqmid > LDACBT_EQMID_MQ))
			p->eqmid = prev_eqmid;
	}

	return prev_eqmid != p->eqmid;
}

static void *codec_init(const struct a2dp_codec *codec, uint32_t flags,
		void *config, size_t config_len, const struct spa_audio_info *info,
		void *props, size_t mtu)
{
	struct impl *this;
	a2dp_ldac_t *conf = config;
	int res;
	struct props *p = props;

	this = calloc(1, sizeof(struct impl));
	if (this == NULL)
		goto error_errno;

	this->ldac = ldacBT_get_handle();
	if (this->ldac == NULL)
		goto error_errno;

#ifdef ENABLE_LDAC_ABR
	this->ldac_abr = ldac_ABR_get_handle();
	if (this->ldac_abr == NULL)
		goto error_errno;
#endif

	if (p == NULL || p->eqmid == LDACBT_EQMID_AUTO) {
		this->eqmid = LDACBT_EQMID_SQ;
		this->enable_abr = true;
	} else {
		this->eqmid = p->eqmid;
		this->enable_abr = false;
	}

	this->mtu = mtu;
	this->frequency = info->info.raw.rate;
	this->codesize = info->info.raw.channels * LDACBT_ENC_LSU;

	switch (info->info.raw.format) {
	case SPA_AUDIO_FORMAT_F32:
		this->fmt = LDACBT_SMPL_FMT_F32;
		this->codesize *= 4;
		break;
	case SPA_AUDIO_FORMAT_S32:
		this->fmt = LDACBT_SMPL_FMT_S32;
		this->codesize *= 4;
		break;
	case SPA_AUDIO_FORMAT_S24:
		this->fmt = LDACBT_SMPL_FMT_S24;
		this->codesize *= 3;
		break;
	case SPA_AUDIO_FORMAT_S16:
		this->fmt = LDACBT_SMPL_FMT_S16;
		this->codesize *= 2;
		break;
	default:
		res = -EINVAL;
		goto error;
	}

	res = ldacBT_init_handle_encode(this->ldac,
			this->mtu,
			this->eqmid,
			conf->channel_mode,
			this->fmt,
			this->frequency);
	if (res < 0)
		goto error;

#ifdef ENABLE_LDAC_ABR
	res = ldac_ABR_Init(this->ldac_abr, LDAC_ABR_INTERVAL_MS);
	if (res < 0)
		goto error;

	res = ldac_ABR_set_thresholds(this->ldac_abr,
		LDAC_ABR_THRESHOLD_CRITICAL,
		LDAC_ABR_THRESHOLD_DANGEROUSTREND,
		LDAC_ABR_THRESHOLD_SAFETY_FOR_HQSQ);
	if (res < 0)
		goto error;
#endif

	return this;

error_errno:
	res = -errno;
error:
	if (this->ldac)
		ldacBT_free_handle(this->ldac);
#ifdef ENABLE_LDAC_ABR
	if (this->ldac_abr)
		ldac_ABR_free_handle(this->ldac_abr);
#endif
	free(this);
	errno = -res;
	return NULL;
}

static void codec_deinit(void *data)
{
	struct impl *this = data;
	if (this->ldac)
		ldacBT_free_handle(this->ldac);
#ifdef ENABLE_LDAC_ABR
	if (this->ldac_abr)
		ldac_ABR_free_handle(this->ldac_abr);
#endif
	free(this);
}

static int codec_update_props(void *data, void *props)
{
	struct impl *this = data;
	struct props *p = props;
	int res;

	if (p == NULL)
		return 0;

	if (p->eqmid == LDACBT_EQMID_AUTO) {
		this->eqmid = LDACBT_EQMID_SQ;
		this->enable_abr = true;
	} else {
		this->eqmid = p->eqmid;
		this->enable_abr = false;
	}

	if ((res = ldacBT_set_eqmid(this->ldac, this->eqmid)) < 0)
		goto error;
	return 0;
error:
	return res;
}

static int codec_abr_process(void *data, size_t unsent)
{
#ifdef ENABLE_LDAC_ABR
	struct impl *this = data;
	int res;
	res = ldac_ABR_Proc(this->ldac, this->ldac_abr,
			unsent / LDAC_ABR_MAX_PACKET_NBYTES, this->enable_abr);
	return res;
#else
	return -ENOTSUP;
#endif
}

static int codec_start_encode (void *data,
		void *dst, size_t dst_size, uint16_t seqnum, uint32_t timestamp)
{
	struct impl *this = data;

	this->header = (struct rtp_header *)dst;
	this->payload = SPA_MEMBER(dst, sizeof(struct rtp_header), struct rtp_payload);
	memset(this->header, 0, sizeof(struct rtp_header)+sizeof(struct rtp_payload));

	this->payload->frame_count = 0;
	this->header->v = 2;
	this->header->pt = 1;
	this->header->sequence_number = htons(seqnum);
	this->header->timestamp = htonl(timestamp);
	this->header->ssrc = htonl(1);
	return sizeof(struct rtp_header) + sizeof(struct rtp_payload);
}

static int codec_encode(void *data,
		const void *src, size_t src_size,
		void *dst, size_t dst_size,
		size_t *dst_out, int *need_flush)
{
	struct impl *this = data;
	int res, src_used, dst_used, frame_num = 0;

	src_used = src_size;
	dst_used = dst_size;

	res = ldacBT_encode(this->ldac, (void*)src, &src_used, dst, &dst_used, &frame_num);
	if (SPA_UNLIKELY(res < 0))
		return -EINVAL;

	*dst_out = dst_used;

	this->payload->frame_count += frame_num;
	*need_flush = this->payload->frame_count > 0;

	return src_used;
}

const struct a2dp_codec a2dp_codec_ldac = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_LDAC,
	.codec_id = A2DP_CODEC_VENDOR,
	.vendor = { .vendor_id = LDAC_VENDOR_ID,
		.codec_id = LDAC_CODEC_ID },
	.name = "ldac",
	.description = "LDAC",
#ifdef ENABLE_LDAC_ABR
	.send_buf_size = LDAC_ABR_SOCK_BUFFER_SIZE,
#endif
	.fill_caps = codec_fill_caps,
	.select_config = codec_select_config,
	.enum_config = codec_enum_config,
	.init_props = codec_init_props,
	.enum_props = codec_enum_props,
	.set_props = codec_set_props,
	.clear_props = codec_clear_props,
	.init = codec_init,
	.deinit = codec_deinit,
	.update_props = codec_update_props,
	.get_block_size = codec_get_block_size,
	.abr_process = codec_abr_process,
	.start_encode = codec_start_encode,
	.encode = codec_encode,
	.reduce_bitpool = codec_reduce_bitpool,
	.increase_bitpool = codec_increase_bitpool,
};
