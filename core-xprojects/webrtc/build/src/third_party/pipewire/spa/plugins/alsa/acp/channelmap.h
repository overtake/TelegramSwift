/***
  This file is part of PulseAudio.

  Copyright 2004-2006 Lennart Poettering
  Copyright 2006 Pierre Ossman <ossman@cendio.se> for Cendio AB

  PulseAudio is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published
  by the Free Software Foundation; either version 2.1 of the License,
  or (at your option) any later version.

  PulseAudio is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with PulseAudio; if not, see <http://www.gnu.org/licenses/>.
***/

#ifndef PULSE_CHANNELMAP_H
#define PULSE_CHANNELMAP_H

#ifdef __cplusplus
extern "C" {
#endif

#define PA_CHANNELS_MAX	64

#define PA_CHANNEL_MAP_SNPRINT_MAX 336

typedef enum pa_channel_map_def {
    PA_CHANNEL_MAP_AIFF,
    PA_CHANNEL_MAP_ALSA,
    PA_CHANNEL_MAP_AUX,
    PA_CHANNEL_MAP_WAVEEX,
    PA_CHANNEL_MAP_OSS,
    PA_CHANNEL_MAP_DEF_MAX,
    PA_CHANNEL_MAP_DEFAULT = PA_CHANNEL_MAP_AIFF
} pa_channel_map_def_t;

typedef enum pa_channel_position {
	PA_CHANNEL_POSITION_INVALID = -1,
	PA_CHANNEL_POSITION_MONO = 0,

	PA_CHANNEL_POSITION_FRONT_LEFT,               /**< Apple, Dolby call this 'Left' */
	PA_CHANNEL_POSITION_FRONT_RIGHT,              /**< Apple, Dolby call this 'Right' */
	PA_CHANNEL_POSITION_FRONT_CENTER,             /**< Apple, Dolby call this 'Center' */

/** \cond fulldocs */
	PA_CHANNEL_POSITION_LEFT = PA_CHANNEL_POSITION_FRONT_LEFT,
	PA_CHANNEL_POSITION_RIGHT = PA_CHANNEL_POSITION_FRONT_RIGHT,
	PA_CHANNEL_POSITION_CENTER = PA_CHANNEL_POSITION_FRONT_CENTER,
/** \endcond */

	PA_CHANNEL_POSITION_REAR_CENTER,              /**< Microsoft calls this 'Back Center', Apple calls this 'Center Surround', Dolby calls this 'Surround Rear Center' */
	PA_CHANNEL_POSITION_REAR_LEFT,                /**< Microsoft calls this 'Back Left', Apple calls this 'Left Surround' (!), Dolby calls this 'Surround Rear Left'  */
	PA_CHANNEL_POSITION_REAR_RIGHT,               /**< Microsoft calls this 'Back Right', Apple calls this 'Right Surround' (!), Dolby calls this 'Surround Rear Right'  */

	PA_CHANNEL_POSITION_LFE,                      /**< Microsoft calls this 'Low Frequency', Apple calls this 'LFEScreen' */
/** \cond fulldocs */
	PA_CHANNEL_POSITION_SUBWOOFER = PA_CHANNEL_POSITION_LFE,
/** \endcond */

	PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER,     /**< Apple, Dolby call this 'Left Center' */
	PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER,    /**< Apple, Dolby call this 'Right Center */

	PA_CHANNEL_POSITION_SIDE_LEFT,                /**< Apple calls this 'Left Surround Direct', Dolby calls this 'Surround Left' (!) */
	PA_CHANNEL_POSITION_SIDE_RIGHT,               /**< Apple calls this 'Right Surround Direct', Dolby calls this 'Surround Right' (!) */
	PA_CHANNEL_POSITION_AUX0,
	PA_CHANNEL_POSITION_AUX1,
	PA_CHANNEL_POSITION_AUX2,
	PA_CHANNEL_POSITION_AUX3,
	PA_CHANNEL_POSITION_AUX4,
	PA_CHANNEL_POSITION_AUX5,
	PA_CHANNEL_POSITION_AUX6,
	PA_CHANNEL_POSITION_AUX7,
	PA_CHANNEL_POSITION_AUX8,
	PA_CHANNEL_POSITION_AUX9,
	PA_CHANNEL_POSITION_AUX10,
	PA_CHANNEL_POSITION_AUX11,
	PA_CHANNEL_POSITION_AUX12,
	PA_CHANNEL_POSITION_AUX13,
	PA_CHANNEL_POSITION_AUX14,
	PA_CHANNEL_POSITION_AUX15,
	PA_CHANNEL_POSITION_AUX16,
	PA_CHANNEL_POSITION_AUX17,
	PA_CHANNEL_POSITION_AUX18,
	PA_CHANNEL_POSITION_AUX19,
	PA_CHANNEL_POSITION_AUX20,
	PA_CHANNEL_POSITION_AUX21,
	PA_CHANNEL_POSITION_AUX22,
	PA_CHANNEL_POSITION_AUX23,
	PA_CHANNEL_POSITION_AUX24,
	PA_CHANNEL_POSITION_AUX25,
	PA_CHANNEL_POSITION_AUX26,
	PA_CHANNEL_POSITION_AUX27,
	PA_CHANNEL_POSITION_AUX28,
	PA_CHANNEL_POSITION_AUX29,
	PA_CHANNEL_POSITION_AUX30,
	PA_CHANNEL_POSITION_AUX31,

	PA_CHANNEL_POSITION_TOP_CENTER,               /**< Apple calls this 'Top Center Surround' */

	PA_CHANNEL_POSITION_TOP_FRONT_LEFT,           /**< Apple calls this 'Vertical Height Left' */
	PA_CHANNEL_POSITION_TOP_FRONT_RIGHT,          /**< Apple calls this 'Vertical Height Right' */
	PA_CHANNEL_POSITION_TOP_FRONT_CENTER,         /**< Apple calls this 'Vertical Height Center' */

	PA_CHANNEL_POSITION_TOP_REAR_LEFT,            /**< Microsoft and Apple call this 'Top Back Left' */
	PA_CHANNEL_POSITION_TOP_REAR_RIGHT,           /**< Microsoft and Apple call this 'Top Back Right' */
	PA_CHANNEL_POSITION_TOP_REAR_CENTER,          /**< Microsoft and Apple call this 'Top Back Center' */

	PA_CHANNEL_POSITION_MAX
} pa_channel_position_t;

typedef struct pa_channel_map {
	uint8_t channels;
	pa_channel_position_t map[PA_CHANNELS_MAX];
} pa_channel_map;

static inline int pa_channels_valid(uint8_t channels)
{
    return channels > 0 && channels <= PA_CHANNELS_MAX;
}

static inline int pa_channel_map_valid(const pa_channel_map *map)
{
    unsigned c;
    if (!pa_channels_valid(map->channels))
        return 0;
    for (c = 0; c < map->channels; c++)
        if (map->map[c] < 0 || map->map[c] >= PA_CHANNEL_POSITION_MAX)
            return 0;
    return 1;
}
static inline pa_channel_map* pa_channel_map_init(pa_channel_map *m)
{
    unsigned c;
    m->channels = 0;
    for (c = 0; c < PA_CHANNELS_MAX; c++)
        m->map[c] = PA_CHANNEL_POSITION_INVALID;
    return m;
}

static inline pa_channel_map* pa_channel_map_init_auto(pa_channel_map *m, unsigned channels, pa_channel_map_def_t def)
{
	pa_assert(m);
	pa_assert(pa_channels_valid(channels));
	pa_assert(def < PA_CHANNEL_MAP_DEF_MAX);

	pa_channel_map_init(m);

	m->channels = (uint8_t) channels;

	switch (def) {
	case PA_CHANNEL_MAP_ALSA:
            switch (channels) {
                case 1:
                    m->map[0] = PA_CHANNEL_POSITION_MONO;
                    return m;
                case 8:
                    m->map[6] = PA_CHANNEL_POSITION_SIDE_LEFT;
                    m->map[7] = PA_CHANNEL_POSITION_SIDE_RIGHT;
                    /* Fall through */
                case 6:
                    m->map[5] = PA_CHANNEL_POSITION_LFE;
                    /* Fall through */
                case 5:
                    m->map[4] = PA_CHANNEL_POSITION_FRONT_CENTER;
                    /* Fall through */
                case 4:
                    m->map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
                    m->map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
                    /* Fall through */
                case 2:
                    m->map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
                    m->map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
                    return m;
                default:
                    return NULL;
            }
	default:
	    break;
	}
	return NULL;
}

static inline pa_channel_map* pa_channel_map_init_extend(pa_channel_map *m,
		unsigned channels, pa_channel_map_def_t def)
{
	unsigned i, c;
	pa_channel_map_init(m);
	for (c = channels; c > 0; c--) {
		if (pa_channel_map_init_auto(m, c, def) == NULL)
			continue;
		for (i = 0; c < channels; c++, i++)
			m->map[c] = PA_CHANNEL_POSITION_AUX0 + i;
		m->channels = (uint8_t) channels;
		return m;
	}
	return NULL;
}

static inline pa_channel_map* pa_channel_map_init_pro(pa_channel_map *m,
		unsigned channels)
{
	unsigned i;
	pa_channel_map_init(m);
	for (i = 0; i < channels; i++)
		m->map[i] = PA_CHANNEL_POSITION_INVALID;
	m->channels = (uint8_t) channels;
	return m;
}

typedef uint64_t pa_channel_position_mask_t;

#define PA_CHANNEL_POSITION_MASK(f) ((pa_channel_position_mask_t) (1ULL << (f)))

#define PA_CHANNEL_POSITION_MASK_LEFT                                   \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_LEFT)           \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_LEFT)          \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER) \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_SIDE_LEFT)          \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_LEFT)     \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_LEFT))     \

#define PA_CHANNEL_POSITION_MASK_RIGHT                                  \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_RIGHT)          \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_RIGHT)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER) \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_SIDE_RIGHT)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_RIGHT)    \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_RIGHT))

#define PA_CHANNEL_POSITION_MASK_CENTER                                 \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_CENTER)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_CENTER)        \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_CENTER)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_CENTER)   \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_CENTER))

#define PA_CHANNEL_POSITION_MASK_FRONT                                  \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_LEFT)           \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_RIGHT)        \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_CENTER)       \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER) \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER) \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_LEFT)     \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_RIGHT)    \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_CENTER))

#define PA_CHANNEL_POSITION_MASK_REAR                                   \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_LEFT)            \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_RIGHT)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_REAR_CENTER)        \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_LEFT)      \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_RIGHT)     \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_CENTER))

#define PA_CHANNEL_POSITION_MASK_LFE                                    \
	PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_LFE)

#define PA_CHANNEL_POSITION_MASK_HFE                                    \
	(PA_CHANNEL_POSITION_MASK_REAR | PA_CHANNEL_POSITION_MASK_FRONT     \
	| PA_CHANNEL_POSITION_MASK_LEFT | PA_CHANNEL_POSITION_MASK_RIGHT   \
	| PA_CHANNEL_POSITION_MASK_CENTER)

#define PA_CHANNEL_POSITION_MASK_SIDE_OR_TOP_CENTER                     \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_SIDE_LEFT)            \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_SIDE_RIGHT)         \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_CENTER))

#define PA_CHANNEL_POSITION_MASK_TOP                                    \
	(PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_CENTER)           \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_LEFT)     \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_RIGHT)    \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_FRONT_CENTER)   \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_LEFT)      \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_RIGHT)     \
	| PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_TOP_REAR_CENTER))

#define PA_CHANNEL_POSITION_MASK_ALL            \
	((pa_channel_position_mask_t) (PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_MAX)-1))

static const char *const pa_position_table[PA_CHANNEL_POSITION_MAX] = {
	[PA_CHANNEL_POSITION_MONO] = "mono",
	[PA_CHANNEL_POSITION_FRONT_CENTER] = "front-center",
	[PA_CHANNEL_POSITION_FRONT_LEFT] = "front-left",
	[PA_CHANNEL_POSITION_FRONT_RIGHT] = "front-right",
	[PA_CHANNEL_POSITION_REAR_CENTER] = "rear-center",
	[PA_CHANNEL_POSITION_REAR_LEFT] = "rear-left",
	[PA_CHANNEL_POSITION_REAR_RIGHT] = "rear-right",
	[PA_CHANNEL_POSITION_LFE] = "lfe",
	[PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER] = "front-left-of-center",
	[PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER] = "front-right-of-center",
	[PA_CHANNEL_POSITION_SIDE_LEFT] = "side-left",
	[PA_CHANNEL_POSITION_SIDE_RIGHT] = "side-right",
	[PA_CHANNEL_POSITION_AUX0] = "aux0",
	[PA_CHANNEL_POSITION_AUX1] = "aux1",
	[PA_CHANNEL_POSITION_AUX2] = "aux2",
	[PA_CHANNEL_POSITION_AUX3] = "aux3",
	[PA_CHANNEL_POSITION_AUX4] = "aux4",
	[PA_CHANNEL_POSITION_AUX5] = "aux5",
	[PA_CHANNEL_POSITION_AUX6] = "aux6",
	[PA_CHANNEL_POSITION_AUX7] = "aux7",
	[PA_CHANNEL_POSITION_AUX8] = "aux8",
	[PA_CHANNEL_POSITION_AUX9] = "aux9",
	[PA_CHANNEL_POSITION_AUX10] = "aux10",
	[PA_CHANNEL_POSITION_AUX11] = "aux11",
	[PA_CHANNEL_POSITION_AUX12] = "aux12",
	[PA_CHANNEL_POSITION_AUX13] = "aux13",
	[PA_CHANNEL_POSITION_AUX14] = "aux14",
	[PA_CHANNEL_POSITION_AUX15] = "aux15",
	[PA_CHANNEL_POSITION_AUX16] = "aux16",
	[PA_CHANNEL_POSITION_AUX17] = "aux17",
	[PA_CHANNEL_POSITION_AUX18] = "aux18",
	[PA_CHANNEL_POSITION_AUX19] = "aux19",
	[PA_CHANNEL_POSITION_AUX20] = "aux20",
	[PA_CHANNEL_POSITION_AUX21] = "aux21",
	[PA_CHANNEL_POSITION_AUX22] = "aux22",
	[PA_CHANNEL_POSITION_AUX23] = "aux23",
	[PA_CHANNEL_POSITION_AUX24] = "aux24",
	[PA_CHANNEL_POSITION_AUX25] = "aux25",
	[PA_CHANNEL_POSITION_AUX26] = "aux26",
	[PA_CHANNEL_POSITION_AUX27] = "aux27",
	[PA_CHANNEL_POSITION_AUX28] = "aux28",
	[PA_CHANNEL_POSITION_AUX29] = "aux29",
	[PA_CHANNEL_POSITION_AUX30] = "aux30",
	[PA_CHANNEL_POSITION_AUX31] = "aux31",
	[PA_CHANNEL_POSITION_TOP_CENTER] = "top-center",
	[PA_CHANNEL_POSITION_TOP_FRONT_CENTER] = "top-front-center",
	[PA_CHANNEL_POSITION_TOP_FRONT_LEFT] = "top-front-left",
	[PA_CHANNEL_POSITION_TOP_FRONT_RIGHT] = "top-front-right",
	[PA_CHANNEL_POSITION_TOP_REAR_CENTER] = "top-rear-center",
	[PA_CHANNEL_POSITION_TOP_REAR_LEFT] = "top-rear-left",
	[PA_CHANNEL_POSITION_TOP_REAR_RIGHT] = "top-rear-right"
};

static inline pa_channel_position_t pa_channel_position_from_string(const char *p)
{
    pa_channel_position_t i;
    /* Some special aliases */
    if (pa_streq(p, "left"))
        return PA_CHANNEL_POSITION_LEFT;
    else if (pa_streq(p, "right"))
        return PA_CHANNEL_POSITION_RIGHT;
    else if (pa_streq(p, "center"))
        return PA_CHANNEL_POSITION_CENTER;
    else if (pa_streq(p, "subwoofer"))
        return PA_CHANNEL_POSITION_SUBWOOFER;
    for (i = 0; i < PA_CHANNEL_POSITION_MAX; i++)
        if (pa_streq(p, pa_position_table[i]))
            return i;
    return PA_CHANNEL_POSITION_INVALID;
}

static inline pa_channel_map *pa_channel_map_parse(pa_channel_map *rmap, const char *s)
{
    const char *state;
    pa_channel_map map;
    char *p;
    pa_channel_map_init(&map);
    if (pa_streq(s, "stereo")) {
        map.channels = 2;
        map.map[0] = PA_CHANNEL_POSITION_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_RIGHT;
        goto finish;
    } else if (pa_streq(s, "surround-21")) {
        map.channels = 3;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_LFE;
        goto finish;
    } else if (pa_streq(s, "surround-40")) {
        map.channels = 4;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
        map.map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
        goto finish;
    } else if (pa_streq(s, "surround-41")) {
        map.channels = 5;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
        map.map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
        map.map[4] = PA_CHANNEL_POSITION_LFE;
        goto finish;
    } else if (pa_streq(s, "surround-50")) {
        map.channels = 5;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
        map.map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
        map.map[4] = PA_CHANNEL_POSITION_FRONT_CENTER;
        goto finish;
    } else if (pa_streq(s, "surround-51")) {
        map.channels = 6;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
        map.map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
        map.map[4] = PA_CHANNEL_POSITION_FRONT_CENTER;
        map.map[5] = PA_CHANNEL_POSITION_LFE;
        goto finish;
    } else if (pa_streq(s, "surround-71")) {
        map.channels = 8;
        map.map[0] = PA_CHANNEL_POSITION_FRONT_LEFT;
        map.map[1] = PA_CHANNEL_POSITION_FRONT_RIGHT;
        map.map[2] = PA_CHANNEL_POSITION_REAR_LEFT;
        map.map[3] = PA_CHANNEL_POSITION_REAR_RIGHT;
        map.map[4] = PA_CHANNEL_POSITION_FRONT_CENTER;
        map.map[5] = PA_CHANNEL_POSITION_LFE;
        map.map[6] = PA_CHANNEL_POSITION_SIDE_LEFT;
        map.map[7] = PA_CHANNEL_POSITION_SIDE_RIGHT;
        goto finish;
    }
    state = NULL;
    map.channels = 0;
    while ((p = pa_split(s, ",", &state))) {
        pa_channel_position_t f;

        if (map.channels >= PA_CHANNELS_MAX) {
            pa_xfree(p);
            return NULL;
        }
        if ((f = pa_channel_position_from_string(p)) == PA_CHANNEL_POSITION_INVALID) {
            pa_xfree(p);
            return NULL;
        }
        map.map[map.channels++] = f;
        pa_xfree(p);
    }
finish:
    if (!pa_channel_map_valid(&map))
        return NULL;
    *rmap = map;
    return rmap;
}

static inline const char* pa_channel_position_to_string(pa_channel_position_t pos) {

    if (pos < 0 || pos >= PA_CHANNEL_POSITION_MAX)
        return NULL;
    return pa_position_table[pos];
}

static inline int pa_channel_map_equal(const pa_channel_map *a, const pa_channel_map *b)
{
    unsigned c;
    if (PA_UNLIKELY(a == b))
        return 1;
    if (a->channels != b->channels)
        return 0;
    for (c = 0; c < a->channels; c++)
        if (a->map[c] != b->map[c])
            return 0;
    return 1;
}

static inline char* pa_channel_map_snprint(char *s, size_t l, const pa_channel_map *map) {
    unsigned channel;
    bool first = true;
    char *e;
    if (!pa_channel_map_valid(map)) {
        pa_snprintf(s, l, "%s", _("(invalid)"));
        return s;
    }
    *(e = s) = 0;
    for (channel = 0; channel < map->channels && l > 1; channel++) {
        l -= pa_snprintf(e, l, "%s%s",
                      first ? "" : ",",
                      pa_channel_position_to_string(map->map[channel]));
        e = strchr(e, 0);
        first = false;
    }

    return s;
}

#ifdef __cplusplus
}
#endif

#endif /* PULSE_CHANNELMAP_H */
