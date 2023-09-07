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

#ifndef PA_VOLUME_H
#define PA_VOLUME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <math.h>

typedef uint32_t pa_volume_t;

#define PA_VOLUME_MUTED ((pa_volume_t) 0U)
#define PA_VOLUME_NORM ((pa_volume_t) 0x10000U)
#define PA_VOLUME_MAX ((pa_volume_t) UINT32_MAX/2)

#ifdef INFINITY
#define PA_DECIBEL_MININFTY ((double) -INFINITY)
#else
#define PA_DECIBEL_MININFTY ((double) -200.0)
#endif

#define PA_CLAMP_VOLUME(v) (PA_CLAMP_UNLIKELY((v), PA_VOLUME_MUTED, PA_VOLUME_MAX))

typedef struct pa_cvolume {
	uint32_t channels;                     /**< Number of channels */
	pa_volume_t values[PA_CHANNELS_MAX];  /**< Per-channel volume */
} pa_cvolume;

static inline double pa_volume_linear_to_dB(double v)
{
	return 20.0 * log10(v);
}

static inline double pa_sw_volume_to_linear(pa_volume_t v)
{
	double f;
	if (v <= PA_VOLUME_MUTED)
		return 0.0;
	if (v == PA_VOLUME_NORM)
		return 1.0;
	f = ((double) v / PA_VOLUME_NORM);
	return f*f*f;
}

static inline double pa_sw_volume_to_dB(pa_volume_t v)
{
	if (v <= PA_VOLUME_MUTED)
		return PA_DECIBEL_MININFTY;
	return pa_volume_linear_to_dB(pa_sw_volume_to_linear(v));
}

static inline double pa_volume_dB_to_linear(double v)
{
    return pow(10.0, v / 20.0);
}

static inline pa_volume_t pa_sw_volume_from_linear(double v)
{
    if (v <= 0.0)
        return PA_VOLUME_MUTED;
    return (pa_volume_t) PA_CLAMP_VOLUME((uint64_t) lround(cbrt(v) * PA_VOLUME_NORM));
}

static inline pa_volume_t pa_sw_volume_from_dB(double dB)
{
    if (isinf(dB) < 0 || dB <= PA_DECIBEL_MININFTY)
        return PA_VOLUME_MUTED;
    return pa_sw_volume_from_linear(pa_volume_dB_to_linear(dB));
}

static inline pa_cvolume* pa_cvolume_set(pa_cvolume *a, unsigned channels, pa_volume_t v)
{
	uint32_t i;
	a->channels = (uint8_t) channels;
	for (i = 0; i < a->channels; i++)
		a->values[i] = PA_CLAMP_VOLUME(v);
	return a;
}

static inline int pa_cvolume_equal(const pa_cvolume *a, const pa_cvolume *b)
{
	uint32_t i;
	if (PA_UNLIKELY(a == b))
		return 1;
	if (a->channels != b->channels)
		return 0;
	for (i = 0; i < a->channels; i++)
		if (a->values[i] != b->values[i])
			return 0;
	return 1;
}

static inline pa_volume_t pa_sw_volume_multiply(pa_volume_t a, pa_volume_t b)
{
	uint64_t result;
	result = ((uint64_t) a * (uint64_t) b + (uint64_t) PA_VOLUME_NORM / 2ULL) /
		(uint64_t) PA_VOLUME_NORM;
	if (result > (uint64_t)PA_VOLUME_MAX)
		pa_log_warn("pa_sw_volume_multiply: Volume exceeds maximum allowed value and will be clipped. Please check your volume settings.");
	return (pa_volume_t) PA_CLAMP_VOLUME(result);
}

static inline pa_cvolume *pa_sw_cvolume_multiply(pa_cvolume *dest,
		const pa_cvolume *a, const pa_cvolume *b)
{
	unsigned i;
	dest->channels = PA_MIN(a->channels, b->channels);
	for (i = 0; i < dest->channels; i++)
		dest->values[i] = pa_sw_volume_multiply(a->values[i], b->values[i]);
	return dest;
}

static inline pa_cvolume *pa_sw_cvolume_multiply_scalar(pa_cvolume *dest,
		const pa_cvolume *a, pa_volume_t b)
{
	unsigned i;
	for (i = 0; i < a->channels; i++)
		dest->values[i] = pa_sw_volume_multiply(a->values[i], b);
	dest->channels = (uint8_t) i;
	return dest;
}

static inline pa_volume_t pa_sw_volume_divide(pa_volume_t a, pa_volume_t b)
{
    uint64_t result;
    if (b <= PA_VOLUME_MUTED)
        return 0;
    result = ((uint64_t) a * (uint64_t) PA_VOLUME_NORM + (uint64_t) b / 2ULL) / (uint64_t) b;
    if (result > (uint64_t)PA_VOLUME_MAX)
        pa_log_warn("pa_sw_volume_divide: Volume exceeds maximum allowed value and will be clipped. Please check your volume settings.");
    return (pa_volume_t) PA_CLAMP_VOLUME(result);
}

static inline pa_cvolume *pa_sw_cvolume_divide_scalar(pa_cvolume *dest,
		const pa_cvolume *a, pa_volume_t b) {
    unsigned i;
    for (i = 0; i < a->channels; i++)
        dest->values[i] = pa_sw_volume_divide(a->values[i], b);
    dest->channels = (uint8_t) i;
    return dest;
}

static inline pa_cvolume *pa_sw_cvolume_divide(pa_cvolume *dest,
		const pa_cvolume *a, const pa_cvolume *b)
{
    unsigned i;
    dest->channels = PA_MIN(a->channels, b->channels);
    for (i = 0; i < dest->channels; i++)
        dest->values[i] = pa_sw_volume_divide(a->values[i], b->values[i]);
    return dest;
}

#define pa_cvolume_reset(a, n) pa_cvolume_set((a), (n), PA_VOLUME_NORM)
#define pa_cvolume_mute(a, n) pa_cvolume_set((a), (n), PA_VOLUME_MUTED)

static inline int pa_cvolume_compatible_with_channel_map(const pa_cvolume *v,
		const pa_channel_map *cm)
{
    return v->channels == cm->channels;
}

static inline pa_volume_t pa_cvolume_max(const pa_cvolume *a)
{
	pa_volume_t m = PA_VOLUME_MUTED;
	unsigned c;
	for (c = 0; c < a->channels; c++)
	        if (a->values[c] > m)
			m = a->values[c];
	return m;
}

static inline pa_volume_t pa_cvolume_min(const pa_cvolume *a)
{
	pa_volume_t m = PA_VOLUME_MAX;
	unsigned c;
	for (c = 0; c < a->channels; c++)
		if (a->values[c] < m)
			m = a->values[c];
	return m;
}


#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PA_VOLUME_H */
