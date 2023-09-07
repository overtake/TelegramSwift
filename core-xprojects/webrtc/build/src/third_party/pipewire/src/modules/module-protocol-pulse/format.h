/* PipeWire
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

#ifndef PULSE_SERVER_FORMAT_H
#define PULSE_SERVER_FORMAT_H

#define RATE_MAX	(48000u*8u)
#define CHANNELS_MAX	(64u)

enum sample_format {
	SAMPLE_U8,
	SAMPLE_ALAW,
	SAMPLE_ULAW,
	SAMPLE_S16LE,
	SAMPLE_S16BE,
	SAMPLE_FLOAT32LE,
	SAMPLE_FLOAT32BE,
	SAMPLE_S32LE,
	SAMPLE_S32BE,
	SAMPLE_S24LE,
	SAMPLE_S24BE,
	SAMPLE_S24_32LE,
	SAMPLE_S24_32BE,
	SAMPLE_MAX,
	SAMPLE_INVALID = -1
};

#if __BYTE_ORDER == __BIG_ENDIAN
#define SAMPLE_S16NE		SAMPLE_S16BE
#define SAMPLE_FLOAT32NE	SAMPLE_FLOAT32BE
#define SAMPLE_S32NE		SAMPLE_S32BE
#define	SAMPLE_S24NE		SAMPLE_S24BE
#define SAMPLE_S24_32NE		SAMPLE_S24_32BE
#elif __BYTE_ORDER == __LITTLE_ENDIAN
#define SAMPLE_S16NE		SAMPLE_S16LE
#define SAMPLE_FLOAT32NE	SAMPLE_FLOAT32LE
#define SAMPLE_S32NE		SAMPLE_S32LE
#define	SAMPLE_S24NE		SAMPLE_S24LE
#define SAMPLE_S24_32NE		SAMPLE_S24_32LE
#endif

struct format {
	uint32_t pa;
	uint32_t id;
	const char *name;
	uint32_t size;
};

struct sample_spec {
	uint32_t format;
	uint32_t rate;
	uint8_t channels;
};
#define SAMPLE_SPEC_INIT	(struct sample_spec) {				\
					.format = SPA_AUDIO_FORMAT_UNKNOWN,	\
					.rate = 0,				\
					.channels = 0,				\
				}

enum channel_position {
	CHANNEL_POSITION_INVALID = -1,
	CHANNEL_POSITION_MONO = 0,
	CHANNEL_POSITION_FRONT_LEFT,
	CHANNEL_POSITION_FRONT_RIGHT,
	CHANNEL_POSITION_FRONT_CENTER,

	CHANNEL_POSITION_REAR_CENTER,
	CHANNEL_POSITION_REAR_LEFT,
	CHANNEL_POSITION_REAR_RIGHT,

	CHANNEL_POSITION_LFE,
	CHANNEL_POSITION_FRONT_LEFT_OF_CENTER,
	CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER,

	CHANNEL_POSITION_SIDE_LEFT,
	CHANNEL_POSITION_SIDE_RIGHT,
	CHANNEL_POSITION_AUX0,
	CHANNEL_POSITION_AUX1,
	CHANNEL_POSITION_AUX2,
	CHANNEL_POSITION_AUX3,
	CHANNEL_POSITION_AUX4,
	CHANNEL_POSITION_AUX5,
	CHANNEL_POSITION_AUX6,
	CHANNEL_POSITION_AUX7,
	CHANNEL_POSITION_AUX8,
	CHANNEL_POSITION_AUX9,
	CHANNEL_POSITION_AUX10,
	CHANNEL_POSITION_AUX11,
	CHANNEL_POSITION_AUX12,
	CHANNEL_POSITION_AUX13,
	CHANNEL_POSITION_AUX14,
	CHANNEL_POSITION_AUX15,
	CHANNEL_POSITION_AUX16,
	CHANNEL_POSITION_AUX17,
	CHANNEL_POSITION_AUX18,
	CHANNEL_POSITION_AUX19,
	CHANNEL_POSITION_AUX20,
	CHANNEL_POSITION_AUX21,
	CHANNEL_POSITION_AUX22,
	CHANNEL_POSITION_AUX23,
	CHANNEL_POSITION_AUX24,
	CHANNEL_POSITION_AUX25,
	CHANNEL_POSITION_AUX26,
	CHANNEL_POSITION_AUX27,
	CHANNEL_POSITION_AUX28,
	CHANNEL_POSITION_AUX29,
	CHANNEL_POSITION_AUX30,
	CHANNEL_POSITION_AUX31,

	CHANNEL_POSITION_TOP_CENTER,

	CHANNEL_POSITION_TOP_FRONT_LEFT,
	CHANNEL_POSITION_TOP_FRONT_RIGHT,
	CHANNEL_POSITION_TOP_FRONT_CENTER,

	CHANNEL_POSITION_TOP_REAR_LEFT,
	CHANNEL_POSITION_TOP_REAR_RIGHT,
	CHANNEL_POSITION_TOP_REAR_CENTER,

	CHANNEL_POSITION_MAX
};

struct channel {
	uint32_t channel;
	const char *name;
};

struct channel_map {
	uint8_t channels;
	uint32_t map[CHANNELS_MAX];
};

#define CHANNEL_MAP_INIT	(struct channel_map) {				\
					.channels = 0,				\
				}

enum encoding {
	ENCODING_ANY,
	ENCODING_PCM,
	ENCODING_AC3_IEC61937,
	ENCODING_EAC3_IEC61937,
	ENCODING_MPEG_IEC61937,
	ENCODING_DTS_IEC61937,
	ENCODING_MPEG2_AAC_IEC61937,
	ENCODING_TRUEHD_IEC61937,
	ENCODING_DTSHD_IEC61937,
	ENCODING_MAX,
	ENCODING_INVALID = -1,
};

uint32_t format_pa2id(enum sample_format format);
const char *format_id2name(uint32_t format);
uint32_t format_name2id(const char *name);
uint32_t format_paname2id(const char *name, size_t size);
enum sample_format format_id2pa(uint32_t id);
const char *format_id2paname(uint32_t id);
uint32_t sample_spec_frame_size(const struct sample_spec *ss);
bool sample_spec_valid(const struct sample_spec *ss);
uint32_t channel_pa2id(enum channel_position channel);
const char *channel_id2name(uint32_t channel);
uint32_t channel_name2id(const char *name);
enum channel_position channel_id2pa(uint32_t id, uint32_t *aux);
const char *channel_id2paname(uint32_t id, uint32_t *aux);
uint32_t channel_paname2id(const char *name, size_t size);
void channel_map_to_positions(const struct channel_map *map, uint32_t *pos);
void channel_map_parse(const char *str, struct channel_map *map);
bool channel_map_valid(const struct channel_map *map);
const char *format_encoding2name(enum encoding enc);

#endif
