/***
  This file is part of PulseAudio.

  Copyright 2004-2009 Lennart Poettering
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/types.h>
#include <alsa/asoundlib.h>

#include "alsa-util.h"
#include "alsa-mixer.h"

#ifdef HAVE_UDEV
#include <modules/udev-util.h>
#endif

static int set_format(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams, pa_sample_format_t *f) {

    static const snd_pcm_format_t format_trans[] = {
        [PA_SAMPLE_U8] = SND_PCM_FORMAT_U8,
        [PA_SAMPLE_ALAW] = SND_PCM_FORMAT_A_LAW,
        [PA_SAMPLE_ULAW] = SND_PCM_FORMAT_MU_LAW,
        [PA_SAMPLE_S16LE] = SND_PCM_FORMAT_S16_LE,
        [PA_SAMPLE_S16BE] = SND_PCM_FORMAT_S16_BE,
        [PA_SAMPLE_FLOAT32LE] = SND_PCM_FORMAT_FLOAT_LE,
        [PA_SAMPLE_FLOAT32BE] = SND_PCM_FORMAT_FLOAT_BE,
        [PA_SAMPLE_S32LE] = SND_PCM_FORMAT_S32_LE,
        [PA_SAMPLE_S32BE] = SND_PCM_FORMAT_S32_BE,
        [PA_SAMPLE_S24LE] = SND_PCM_FORMAT_S24_3LE,
        [PA_SAMPLE_S24BE] = SND_PCM_FORMAT_S24_3BE,
        [PA_SAMPLE_S24_32LE] = SND_PCM_FORMAT_S24_LE,
        [PA_SAMPLE_S24_32BE] = SND_PCM_FORMAT_S24_BE,
    };

    static const pa_sample_format_t try_order[] = {
        PA_SAMPLE_FLOAT32NE,
        PA_SAMPLE_FLOAT32RE,
        PA_SAMPLE_S32NE,
        PA_SAMPLE_S32RE,
        PA_SAMPLE_S24_32NE,
        PA_SAMPLE_S24_32RE,
        PA_SAMPLE_S24NE,
        PA_SAMPLE_S24RE,
        PA_SAMPLE_S16NE,
        PA_SAMPLE_S16RE,
        PA_SAMPLE_ALAW,
        PA_SAMPLE_ULAW,
        PA_SAMPLE_U8
    };

    unsigned i;
    int ret;

    pa_assert(pcm_handle);
    pa_assert(hwparams);
    pa_assert(f);

    if ((ret = snd_pcm_hw_params_set_format(pcm_handle, hwparams, format_trans[*f])) >= 0)
        return ret;

    pa_log_debug("snd_pcm_hw_params_set_format(%s) failed: %s",
                 snd_pcm_format_description(format_trans[*f]),
                 pa_alsa_strerror(ret));

    if (*f == PA_SAMPLE_FLOAT32BE)
        *f = PA_SAMPLE_FLOAT32LE;
    else if (*f == PA_SAMPLE_FLOAT32LE)
        *f = PA_SAMPLE_FLOAT32BE;
    else if (*f == PA_SAMPLE_S24BE)
        *f = PA_SAMPLE_S24LE;
    else if (*f == PA_SAMPLE_S24LE)
        *f = PA_SAMPLE_S24BE;
    else if (*f == PA_SAMPLE_S24_32BE)
        *f = PA_SAMPLE_S24_32LE;
    else if (*f == PA_SAMPLE_S24_32LE)
        *f = PA_SAMPLE_S24_32BE;
    else if (*f == PA_SAMPLE_S16BE)
        *f = PA_SAMPLE_S16LE;
    else if (*f == PA_SAMPLE_S16LE)
        *f = PA_SAMPLE_S16BE;
    else if (*f == PA_SAMPLE_S32BE)
        *f = PA_SAMPLE_S32LE;
    else if (*f == PA_SAMPLE_S32LE)
        *f = PA_SAMPLE_S32BE;
    else
        goto try_auto;

    if ((ret = snd_pcm_hw_params_set_format(pcm_handle, hwparams, format_trans[*f])) >= 0)
        return ret;

    pa_log_debug("snd_pcm_hw_params_set_format(%s) failed: %s",
                 snd_pcm_format_description(format_trans[*f]),
                 pa_alsa_strerror(ret));

try_auto:

    for (i = 0; i < PA_ELEMENTSOF(try_order); i++) {
        *f = try_order[i];

        if ((ret = snd_pcm_hw_params_set_format(pcm_handle, hwparams, format_trans[*f])) >= 0)
            return ret;

        pa_log_debug("snd_pcm_hw_params_set_format(%s) failed: %s",
                     snd_pcm_format_description(format_trans[*f]),
                     pa_alsa_strerror(ret));
    }

    return -1;
}

static int set_period_size(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams, snd_pcm_uframes_t size) {
    snd_pcm_uframes_t s;
    int d, ret;

    pa_assert(pcm_handle);
    pa_assert(hwparams);

    s = size;
    d = 0;
    if (snd_pcm_hw_params_set_period_size_near(pcm_handle, hwparams, &s, &d) < 0) {
        s = size;
        d = -1;
        if (snd_pcm_hw_params_set_period_size_near(pcm_handle, hwparams, &s, &d) < 0) {
            s = size;
            d = 1;
            if ((ret = snd_pcm_hw_params_set_period_size_near(pcm_handle, hwparams, &s, &d)) < 0) {
                pa_log_info("snd_pcm_hw_params_set_period_size_near() failed: %s", pa_alsa_strerror(ret));
                return ret;
            }
        }
    }

    return 0;
}

static int set_buffer_size(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams, snd_pcm_uframes_t size) {
    int ret;

    pa_assert(pcm_handle);
    pa_assert(hwparams);

    if ((ret = snd_pcm_hw_params_set_buffer_size_near(pcm_handle, hwparams, &size)) < 0) {
        pa_log_info("snd_pcm_hw_params_set_buffer_size_near() failed: %s", pa_alsa_strerror(ret));
        return ret;
    }

    return 0;
}

static void check_access(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams, bool use_mmap) {
    if ((use_mmap && !snd_pcm_hw_params_test_access(pcm_handle, hwparams, SND_PCM_ACCESS_MMAP_INTERLEAVED)) ||
        !snd_pcm_hw_params_test_access(pcm_handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED))
        pa_log_error("Weird, PCM claims to support interleaved access, but snd_pcm_hw_params_set_access() failed.");

    if ((use_mmap && !snd_pcm_hw_params_test_access(pcm_handle, hwparams, SND_PCM_ACCESS_MMAP_NONINTERLEAVED)) ||
        !snd_pcm_hw_params_test_access(pcm_handle, hwparams, SND_PCM_ACCESS_RW_NONINTERLEAVED))
        pa_log_debug("PCM seems to support non-interleaved access, but PA doesn't.");
    else if (use_mmap && !snd_pcm_hw_params_test_access(pcm_handle, hwparams, SND_PCM_ACCESS_MMAP_COMPLEX)) {
        pa_log_debug("PCM seems to support mmapped complex access, but PA doesn't.");
    }
}

/* Set the hardware parameters of the given ALSA device. Returns the
 * selected fragment settings in *buffer_size and *period_size. Determine
 * whether mmap and tsched mode can be enabled. */
int pa_alsa_set_hw_params(
        snd_pcm_t *pcm_handle,
        pa_sample_spec *ss,
        snd_pcm_uframes_t *period_size,
        snd_pcm_uframes_t *buffer_size,
        snd_pcm_uframes_t tsched_size,
        bool *use_mmap,
        bool *use_tsched,
        bool require_exact_channel_number) {

    int ret = -1;
    snd_pcm_hw_params_t *hwparams, *hwparams_copy;
    int dir;
    snd_pcm_uframes_t _period_size = period_size ? *period_size : 0;
    snd_pcm_uframes_t _buffer_size = buffer_size ? *buffer_size : 0;
    bool _use_mmap = use_mmap && *use_mmap;
    bool _use_tsched = use_tsched && *use_tsched;
    pa_sample_spec _ss = *ss;

    pa_assert(pcm_handle);
    pa_assert(ss);

    snd_pcm_hw_params_alloca(&hwparams);
    snd_pcm_hw_params_alloca(&hwparams_copy);

    if ((ret = snd_pcm_hw_params_any(pcm_handle, hwparams)) < 0) {
        pa_log_debug("snd_pcm_hw_params_any() failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

    if ((ret = snd_pcm_hw_params_set_rate_resample(pcm_handle, hwparams, 0)) < 0) {
        pa_log_debug("snd_pcm_hw_params_set_rate_resample() failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

    if (_use_mmap) {

        if (snd_pcm_hw_params_set_access(pcm_handle, hwparams, SND_PCM_ACCESS_MMAP_INTERLEAVED) < 0) {

            /* mmap() didn't work, fall back to interleaved */

            if ((ret = snd_pcm_hw_params_set_access(pcm_handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED)) < 0) {
                pa_log_debug("snd_pcm_hw_params_set_access() failed: %s", pa_alsa_strerror(ret));
                check_access(pcm_handle, hwparams, true);
                goto finish;
            }

            _use_mmap = false;
        }

    } else if ((ret = snd_pcm_hw_params_set_access(pcm_handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED)) < 0) {
        pa_log_debug("snd_pcm_hw_params_set_access() failed: %s", pa_alsa_strerror(ret));
        check_access(pcm_handle, hwparams, false);
        goto finish;
    }

    if (!_use_mmap)
        _use_tsched = false;

    if (!pa_alsa_pcm_is_hw(pcm_handle))
        _use_tsched = false;

    /* The PCM pointer is only updated with period granularity */
    if (snd_pcm_hw_params_is_batch(hwparams)) {
        bool is_usb = false;
        const char *id;
        snd_pcm_info_t* pcm_info;
        snd_pcm_info_alloca(&pcm_info);

        if (snd_pcm_info(pcm_handle, pcm_info) == 0 &&
            (id = snd_pcm_info_get_id(pcm_info))) {
            /* This horrible hack makes sure we don't disable tsched on USB
             * devices, which have a low enough transfer size for timer-based
             * scheduling to work. This can go away when the ALSA API supports
             * querying the block transfer size. */
            if (pa_streq(id, "USB Audio"))
                is_usb = true;
        }

        if (!is_usb) {
            pa_log_info("Disabling tsched mode since BATCH flag is set");
            _use_tsched = false;
        }
    }

#if (SND_LIB_VERSION >= ((1<<16)|(0<<8)|24)) /* API additions in 1.0.24 */
    if (_use_tsched) {

        /* try to disable period wakeups if hardware can do so */
        if (snd_pcm_hw_params_can_disable_period_wakeup(hwparams)) {

            if ((ret = snd_pcm_hw_params_set_period_wakeup(pcm_handle, hwparams, false)) < 0)
                /* don't bail, keep going with default mode with period wakeups */
                pa_log_debug("snd_pcm_hw_params_set_period_wakeup() failed: %s", pa_alsa_strerror(ret));
            else
                pa_log_info("Trying to disable ALSA period wakeups, using timers only");
        } else
            pa_log_info("Cannot disable ALSA period wakeups");
    }
#endif

    if ((ret = set_format(pcm_handle, hwparams, &_ss.format)) < 0)
        goto finish;

    if ((ret = snd_pcm_hw_params_set_rate_near(pcm_handle, hwparams, &_ss.rate, NULL)) < 0) {
        pa_log_debug("snd_pcm_hw_params_set_rate_near() failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

    /* We ignore very small sampling rate deviations */
    if (_ss.rate >= ss->rate*.95 && _ss.rate <= ss->rate*1.05)
        _ss.rate = ss->rate;

    if (require_exact_channel_number) {
        if ((ret = snd_pcm_hw_params_set_channels(pcm_handle, hwparams, _ss.channels)) < 0) {
            pa_log_debug("snd_pcm_hw_params_set_channels(%u) failed: %s", _ss.channels, pa_alsa_strerror(ret));
            goto finish;
        }
    } else {
        unsigned int c = _ss.channels;

        if ((ret = snd_pcm_hw_params_set_channels_near(pcm_handle, hwparams, &c)) < 0) {
            pa_log_debug("snd_pcm_hw_params_set_channels_near(%u) failed: %s", _ss.channels, pa_alsa_strerror(ret));
            goto finish;
        }

        _ss.channels = c;
    }

    if (_use_tsched && tsched_size > 0) {
        _buffer_size = (snd_pcm_uframes_t) (((uint64_t) tsched_size * _ss.rate) / ss->rate);
        _period_size = _buffer_size;
    } else {
        _period_size = (snd_pcm_uframes_t) (((uint64_t) _period_size * _ss.rate) / ss->rate);
        _buffer_size = (snd_pcm_uframes_t) (((uint64_t) _buffer_size * _ss.rate) / ss->rate);
    }

    if (_buffer_size > 0 || _period_size > 0) {
        snd_pcm_uframes_t max_frames = 0;

        if ((ret = snd_pcm_hw_params_get_buffer_size_max(hwparams, &max_frames)) < 0)
            pa_log_warn("snd_pcm_hw_params_get_buffer_size_max() failed: %s", pa_alsa_strerror(ret));
        else
            pa_log_debug("Maximum hw buffer size is %lu ms", (long unsigned) (max_frames * PA_MSEC_PER_SEC / _ss.rate));

        /* Some ALSA drivers really don't like if we set the buffer
         * size first and the number of periods second (which would
         * make a lot more sense to me). So, try a few combinations
         * before we give up. */

        if (_buffer_size > 0 && _period_size > 0) {
            snd_pcm_hw_params_copy(hwparams_copy, hwparams);

            /* First try: set buffer size first, followed by period size */
            if (set_buffer_size(pcm_handle, hwparams_copy, _buffer_size) >= 0 &&
                set_period_size(pcm_handle, hwparams_copy, _period_size) >= 0 &&
                snd_pcm_hw_params(pcm_handle, hwparams_copy) >= 0) {
                pa_log_debug("Set buffer size first (to %lu samples), period size second (to %lu samples).", (unsigned long) _buffer_size, (unsigned long) _period_size);
                goto success;
            }

            snd_pcm_hw_params_copy(hwparams_copy, hwparams);
            /* Second try: set period size first, followed by buffer size */
            if (set_period_size(pcm_handle, hwparams_copy, _period_size) >= 0 &&
                set_buffer_size(pcm_handle, hwparams_copy, _buffer_size) >= 0 &&
                snd_pcm_hw_params(pcm_handle, hwparams_copy) >= 0) {
                pa_log_debug("Set period size first (to %lu samples), buffer size second (to %lu samples).", (unsigned long) _period_size, (unsigned long) _buffer_size);
                goto success;
            }
        }

        if (_buffer_size > 0) {
            snd_pcm_hw_params_copy(hwparams_copy, hwparams);

            /* Third try: set only buffer size */
            if (set_buffer_size(pcm_handle, hwparams_copy, _buffer_size) >= 0 &&
                snd_pcm_hw_params(pcm_handle, hwparams_copy) >= 0) {
                pa_log_debug("Set only buffer size (to %lu samples).", (unsigned long) _buffer_size);
                goto success;
            }
        }

        if (_period_size > 0) {
            snd_pcm_hw_params_copy(hwparams_copy, hwparams);

            /* Fourth try: set only period size */
            if (set_period_size(pcm_handle, hwparams_copy, _period_size) >= 0 &&
                snd_pcm_hw_params(pcm_handle, hwparams_copy) >= 0) {
                pa_log_debug("Set only period size (to %lu samples).", (unsigned long) _period_size);
                goto success;
            }
        }
    }

    pa_log_debug("Set neither period nor buffer size.");

    /* Last chance, set nothing */
    if ((ret = snd_pcm_hw_params(pcm_handle, hwparams)) < 0) {
        pa_log_info("snd_pcm_hw_params failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

success:

    if (ss->rate != _ss.rate)
        pa_log_info("Device %s doesn't support %u Hz, changed to %u Hz.", snd_pcm_name(pcm_handle), ss->rate, _ss.rate);

    if (ss->channels != _ss.channels)
        pa_log_info("Device %s doesn't support %u channels, changed to %u.", snd_pcm_name(pcm_handle), ss->channels, _ss.channels);

    if (ss->format != _ss.format)
        pa_log_info("Device %s doesn't support sample format %s, changed to %s.", snd_pcm_name(pcm_handle), pa_sample_format_to_string(ss->format), pa_sample_format_to_string(_ss.format));

    if ((ret = snd_pcm_hw_params_current(pcm_handle, hwparams)) < 0) {
        pa_log_info("snd_pcm_hw_params_current() failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

    if ((ret = snd_pcm_hw_params_get_period_size(hwparams, &_period_size, &dir)) < 0 ||
        (ret = snd_pcm_hw_params_get_buffer_size(hwparams, &_buffer_size)) < 0) {
        pa_log_info("snd_pcm_hw_params_get_{period|buffer}_size() failed: %s", pa_alsa_strerror(ret));
        goto finish;
    }

#if (SND_LIB_VERSION >= ((1<<16)|(0<<8)|24)) /* API additions in 1.0.24 */
    if (_use_tsched) {
        unsigned int no_wakeup;
        /* see if period wakeups were disabled */
        snd_pcm_hw_params_get_period_wakeup(pcm_handle, hwparams, &no_wakeup);
        if (no_wakeup == 0)
            pa_log_info("ALSA period wakeups disabled");
        else
            pa_log_info("ALSA period wakeups were not disabled");
    }
#endif

    ss->rate = _ss.rate;
    ss->channels = _ss.channels;
    ss->format = _ss.format;

    pa_assert(_period_size > 0);
    pa_assert(_buffer_size > 0);

    if (buffer_size)
        *buffer_size = _buffer_size;

    if (period_size)
        *period_size = _period_size;

    if (use_mmap)
        *use_mmap = _use_mmap;

    if (use_tsched)
        *use_tsched = _use_tsched;

    ret = 0;

finish:

    return ret;
}

int pa_alsa_set_sw_params(snd_pcm_t *pcm, snd_pcm_uframes_t avail_min, bool period_event) {
    snd_pcm_sw_params_t *swparams;
    snd_pcm_uframes_t boundary;
    int err;

    pa_assert(pcm);

    snd_pcm_sw_params_alloca(&swparams);

    if ((err = snd_pcm_sw_params_current(pcm, swparams)) < 0) {
        pa_log_warn("Unable to determine current swparams: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_set_period_event(pcm, swparams, period_event)) < 0) {
        pa_log_warn("Unable to disable period event: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_set_tstamp_mode(pcm, swparams, SND_PCM_TSTAMP_ENABLE)) < 0) {
        pa_log_warn("Unable to enable time stamping: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_get_boundary(swparams, &boundary)) < 0) {
        pa_log_warn("Unable to get boundary: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_set_stop_threshold(pcm, swparams, boundary)) < 0) {
        pa_log_warn("Unable to set stop threshold: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_set_start_threshold(pcm, swparams, (snd_pcm_uframes_t) -1)) < 0) {
        pa_log_warn("Unable to set start threshold: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params_set_avail_min(pcm, swparams, avail_min)) < 0) {
        pa_log_error("snd_pcm_sw_params_set_avail_min() failed: %s", pa_alsa_strerror(err));
        return err;
    }

    if ((err = snd_pcm_sw_params(pcm, swparams)) < 0) {
        pa_log_warn("Unable to set sw params: %s", pa_alsa_strerror(err));
        return err;
    }

    return 0;
}

#if 0
snd_pcm_t *pa_alsa_open_by_device_id_auto(
        const char *dev_id,
        char **dev,
        pa_sample_spec *ss,
        pa_channel_map* map,
        int mode,
        snd_pcm_uframes_t *period_size,
        snd_pcm_uframes_t *buffer_size,
        snd_pcm_uframes_t tsched_size,
        bool *use_mmap,
        bool *use_tsched,
        pa_alsa_profile_set *ps,
        pa_alsa_mapping **mapping) {

    char *d;
    snd_pcm_t *pcm_handle;
    void *state;
    pa_alsa_mapping *m;

    pa_assert(dev_id);
    pa_assert(dev);
    pa_assert(ss);
    pa_assert(map);
    pa_assert(ps);

    /* First we try to find a device string with a superset of the
     * requested channel map. We iterate through our device table from
     * top to bottom and take the first that matches. If we didn't
     * find a working device that way, we iterate backwards, and check
     * all devices that do not provide a superset of the requested
     * channel map.*/

    PA_HASHMAP_FOREACH(m, ps->mappings, state) {
        if (!pa_channel_map_superset(&m->channel_map, map))
            continue;

        pa_log_debug("Checking for superset %s (%s)", m->name, m->device_strings[0]);

        pcm_handle = pa_alsa_open_by_device_id_mapping(
                dev_id,
                dev,
                ss,
                map,
                mode,
                period_size,
                buffer_size,
                tsched_size,
                use_mmap,
                use_tsched,
                m);

        if (pcm_handle) {
            if (mapping)
                *mapping = m;

            return pcm_handle;
        }
    }

    PA_HASHMAP_FOREACH_BACKWARDS(m, ps->mappings, state) {
        if (pa_channel_map_superset(&m->channel_map, map))
            continue;

        pa_log_debug("Checking for subset %s (%s)", m->name, m->device_strings[0]);

        pcm_handle = pa_alsa_open_by_device_id_mapping(
                dev_id,
                dev,
                ss,
                map,
                mode,
                period_size,
                buffer_size,
                tsched_size,
                use_mmap,
                use_tsched,
                m);

        if (pcm_handle) {
            if (mapping)
                *mapping = m;

            return pcm_handle;
        }
    }

    /* OK, we didn't find any good device, so let's try the raw hw: stuff */
    d = pa_sprintf_malloc("hw:%s", dev_id);
    pa_log_debug("Trying %s as last resort...", d);
    pcm_handle = pa_alsa_open_by_device_string(
            d,
            dev,
            ss,
            map,
            mode,
            period_size,
            buffer_size,
            tsched_size,
            use_mmap,
            use_tsched,
            false);
    pa_xfree(d);

    if (pcm_handle && mapping)
        *mapping = NULL;

    return pcm_handle;
}
#endif

snd_pcm_t *pa_alsa_open_by_device_id_mapping(
        const char *dev_id,
        char **dev,
        pa_sample_spec *ss,
        pa_channel_map* map,
        int mode,
        snd_pcm_uframes_t *period_size,
        snd_pcm_uframes_t *buffer_size,
        snd_pcm_uframes_t tsched_size,
        bool *use_mmap,
        bool *use_tsched,
        pa_alsa_mapping *m) {

    snd_pcm_t *pcm_handle;
    pa_sample_spec try_ss;
    pa_channel_map try_map;

    pa_assert(dev_id);
    pa_assert(dev);
    pa_assert(ss);
    pa_assert(map);
    pa_assert(m);

    try_ss.channels = m->channel_map.channels;
    try_ss.rate = ss->rate;
    try_ss.format = ss->format;
    try_map = m->channel_map;

    pcm_handle = pa_alsa_open_by_template(
            m->device_strings,
            dev_id,
            dev,
            &try_ss,
            &try_map,
            mode,
            period_size,
            buffer_size,
            tsched_size,
            use_mmap,
            use_tsched,
            pa_channel_map_valid(&m->channel_map) /* Query the channel count if we don't know what we want */);

    if (!pcm_handle)
        return NULL;

    *ss = try_ss;
    *map = try_map;
    pa_assert(map->channels == ss->channels);

    return pcm_handle;
}

snd_pcm_t *pa_alsa_open_by_device_string(
        const char *device,
        char **dev,
        pa_sample_spec *ss,
        pa_channel_map* map,
        int mode,
        snd_pcm_uframes_t *period_size,
        snd_pcm_uframes_t *buffer_size,
        snd_pcm_uframes_t tsched_size,
        bool *use_mmap,
        bool *use_tsched,
        bool require_exact_channel_number) {

    int err;
    char *d;
    snd_pcm_t *pcm_handle;
    bool reformat = false;

    pa_assert(device);
    pa_assert(ss);
    pa_assert(map);

    d = pa_xstrdup(device);

    for (;;) {
        pa_log_debug("Trying %s %s SND_PCM_NO_AUTO_FORMAT ...", d, reformat ? "without" : "with");

        if ((err = snd_pcm_open(&pcm_handle, d, mode,
                                SND_PCM_NONBLOCK|
                                SND_PCM_NO_AUTO_RESAMPLE|
                                SND_PCM_NO_AUTO_CHANNELS|
                                (reformat ? 0 : SND_PCM_NO_AUTO_FORMAT))) < 0) {
            pa_log_info("Error opening PCM device %s: %s", d, pa_alsa_strerror(err));
            goto fail;
        }

        pa_log_debug("Managed to open %s", d);

        if ((err = pa_alsa_set_hw_params(
                     pcm_handle,
                     ss,
                     period_size,
                     buffer_size,
                     tsched_size,
                     use_mmap,
                     use_tsched,
                     require_exact_channel_number)) < 0) {

            if (!reformat) {
                reformat = true;

                snd_pcm_close(pcm_handle);
                continue;
            }

            /* Hmm, some hw is very exotic, so we retry with plug, if without it didn't work */
            if (!pa_startswith(d, "plug:") && !pa_startswith(d, "plughw:")) {
                char *t;

                t = pa_sprintf_malloc("plug:SLAVE='%s'", d);
                pa_xfree(d);
                d = t;

                reformat = false;

                snd_pcm_close(pcm_handle);
                continue;
            }

            pa_log_info("Failed to set hardware parameters on %s: %s", d, pa_alsa_strerror(err));
            snd_pcm_close(pcm_handle);

            goto fail;
        }

        if (ss->channels > PA_CHANNELS_MAX) {
            pa_log("Device %s has %u channels, but PulseAudio supports only %u channels. Unable to use the device.",
                   d, ss->channels, PA_CHANNELS_MAX);
            snd_pcm_close(pcm_handle);
            goto fail;
        }

        if (dev)
            *dev = d;
        else
            pa_xfree(d);

        if (ss->channels != map->channels)
            pa_channel_map_init_extend(map, ss->channels, PA_CHANNEL_MAP_ALSA);

        return pcm_handle;
    }

fail:
    pa_xfree(d);

    return NULL;
}

snd_pcm_t *pa_alsa_open_by_template(
        char **template,
        const char *dev_id,
        char **dev,
        pa_sample_spec *ss,
        pa_channel_map* map,
        int mode,
        snd_pcm_uframes_t *period_size,
        snd_pcm_uframes_t *buffer_size,
        snd_pcm_uframes_t tsched_size,
        bool *use_mmap,
        bool *use_tsched,
        bool require_exact_channel_number) {

    snd_pcm_t *pcm_handle;
    char **i;

    for (i = template; *i; i++) {
        char *d;

        d = pa_replace(*i, "%f", dev_id);

        pcm_handle = pa_alsa_open_by_device_string(
                d,
                dev,
                ss,
                map,
                mode,
                period_size,
                buffer_size,
                tsched_size,
                use_mmap,
                use_tsched,
                require_exact_channel_number);

        pa_xfree(d);

        if (pcm_handle)
            return pcm_handle;
    }

    return NULL;
}

void pa_alsa_dump(pa_log_level_t level, snd_pcm_t *pcm) {
    int err;
    snd_output_t *out;

    pa_assert(pcm);

    pa_assert_se(snd_output_buffer_open(&out) == 0);

    if ((err = snd_pcm_dump(pcm, out)) < 0)
        pa_logl(level, "snd_pcm_dump(): %s", pa_alsa_strerror(err));
    else {
        char *s = NULL;
        snd_output_buffer_string(out, &s);
        pa_logl(level, "snd_pcm_dump():\n%s", pa_strnull(s));
    }

    pa_assert_se(snd_output_close(out) == 0);
}

#if 0
void pa_alsa_dump_status(snd_pcm_t *pcm) {
    int err;
    snd_output_t *out;
    snd_pcm_status_t *status;
    char *s = NULL;

    pa_assert(pcm);

    snd_pcm_status_alloca(&status);

    if ((err = snd_output_buffer_open(&out)) < 0) {
        pa_log_debug("snd_output_buffer_open() failed: %s", pa_cstrerror(err));
        return;
    }

    if ((err = snd_pcm_status(pcm, status)) < 0) {
        pa_log_debug("snd_pcm_status() failed: %s", pa_cstrerror(err));
        goto finish;
    }

    if ((err = snd_pcm_status_dump(status, out)) < 0) {
        pa_log_debug("snd_pcm_status_dump(): %s", pa_alsa_strerror(err));
        goto finish;
    }

    snd_output_buffer_string(out, &s);
    pa_log_debug("snd_pcm_status_dump():\n%s", pa_strnull(s));

finish:

    snd_output_close(out);
}
#endif

static PA_PRINTF_FUNC(5,6) void alsa_error_handler(const char *file, int line, const char *function, int err, const char *fmt,...) {
    va_list ap;
//    char *alsa_file;

//    alsa_file = pa_sprintf_malloc("(alsa-lib)%s", file);

    va_start(ap, fmt);

    pa_log_levelv_meta(PA_LOG_INFO, file, line, function, fmt, ap);

    va_end(ap);

//    pa_xfree(alsa_file);
}

static int n_error_handler_installed = 0;

typedef void (*snd_lib2_error_handler_t)(const char *file, int line, const char *function, int err, const char *fmt, ...) PA_PRINTF_FUNC(5,6) /* __attribute__ ((format (printf, 5, 6))) */;

extern int snd_lib_error_set_handler(snd_lib2_error_handler_t handler);

void pa_alsa_refcnt_inc(void) {
    /* This is not really thread safe, but we do our best */
   if (n_error_handler_installed++ == 0)
        snd_lib_error_set_handler(alsa_error_handler);
}

void pa_alsa_refcnt_dec(void) {
    int r;

    pa_assert_se((r = n_error_handler_installed--) >= 1);

    if (r == 1) {
        snd_lib_error_set_handler(NULL);
        snd_config_update_free_global();
    }
}

bool pa_alsa_init_description(pa_proplist *p, pa_card *card) {
    const char *d, *k;
    pa_assert(p);

    if (pa_alsa_device_init_description(p, card))
        return true;

    if (!(d = pa_proplist_gets(p, "alsa.card_name")))
        d = pa_proplist_gets(p, "alsa.name");

    if (!d)
        return false;

    k = pa_proplist_gets(p, PA_PROP_DEVICE_PROFILE_DESCRIPTION);

    if (d && k)
        pa_proplist_setf(p, PA_PROP_DEVICE_DESCRIPTION, "%s %s", d, k);
    else if (d)
        pa_proplist_sets(p, PA_PROP_DEVICE_DESCRIPTION, d);

    return false;
}

void pa_alsa_init_proplist_card(pa_core *c, pa_proplist *p, int card) {
    char *cn, *lcn, *dn;

    pa_assert(p);
    pa_assert(card >= 0);

    pa_proplist_setf(p, "alsa.card", "%i", card);

    if (snd_card_get_name(card, &cn) >= 0) {
        pa_proplist_sets(p, "alsa.card_name", pa_strip(cn));
        free(cn);
    }

    if (snd_card_get_longname(card, &lcn) >= 0) {
        pa_proplist_sets(p, "alsa.long_card_name", pa_strip(lcn));
        free(lcn);
    }

    if ((dn = pa_alsa_get_driver_name(card))) {
        pa_proplist_sets(p, "alsa.driver_name", dn);
        pa_xfree(dn);
    }

#ifdef HAVE_UDEV
    pa_udev_get_info(card, p);
#endif
}

void pa_alsa_init_proplist_pcm_info(pa_core *c, pa_proplist *p, snd_pcm_info_t *pcm_info) {

    static const char * const alsa_class_table[SND_PCM_CLASS_LAST+1] = {
        [SND_PCM_CLASS_GENERIC] = "generic",
        [SND_PCM_CLASS_MULTI] = "multi",
        [SND_PCM_CLASS_MODEM] = "modem",
        [SND_PCM_CLASS_DIGITIZER] = "digitizer"
    };
    static const char * const class_table[SND_PCM_CLASS_LAST+1] = {
        [SND_PCM_CLASS_GENERIC] = "sound",
        [SND_PCM_CLASS_MULTI] = NULL,
        [SND_PCM_CLASS_MODEM] = "modem",
        [SND_PCM_CLASS_DIGITIZER] = NULL
    };
    static const char * const alsa_subclass_table[SND_PCM_SUBCLASS_LAST+1] = {
        [SND_PCM_SUBCLASS_GENERIC_MIX] = "generic-mix",
        [SND_PCM_SUBCLASS_MULTI_MIX] = "multi-mix"
    };

    snd_pcm_class_t class;
    snd_pcm_subclass_t subclass;
    const char *n, *id, *sdn;
    int card;

    pa_assert(p);
    pa_assert(pcm_info);

    pa_proplist_sets(p, PA_PROP_DEVICE_API, "alsa");

    if ((class = snd_pcm_info_get_class(pcm_info)) <= SND_PCM_CLASS_LAST) {
        if (class_table[class])
            pa_proplist_sets(p, PA_PROP_DEVICE_CLASS, class_table[class]);
        if (alsa_class_table[class])
            pa_proplist_sets(p, "alsa.class", alsa_class_table[class]);
    }

    if ((subclass = snd_pcm_info_get_subclass(pcm_info)) <= SND_PCM_SUBCLASS_LAST)
        if (alsa_subclass_table[subclass])
            pa_proplist_sets(p, "alsa.subclass", alsa_subclass_table[subclass]);

    if ((n = snd_pcm_info_get_name(pcm_info))) {
        char *t = pa_xstrdup(n);
        pa_proplist_sets(p, "alsa.name", pa_strip(t));
        pa_xfree(t);
    }

    if ((id = snd_pcm_info_get_id(pcm_info)))
        pa_proplist_sets(p, "alsa.id", id);

    pa_proplist_setf(p, "alsa.subdevice", "%u", snd_pcm_info_get_subdevice(pcm_info));
    if ((sdn = snd_pcm_info_get_subdevice_name(pcm_info)))
        pa_proplist_sets(p, "alsa.subdevice_name", sdn);

    pa_proplist_setf(p, "alsa.device", "%u", snd_pcm_info_get_device(pcm_info));

    if ((card = snd_pcm_info_get_card(pcm_info)) >= 0)
        pa_alsa_init_proplist_card(c, p, card);
}

void pa_alsa_init_proplist_pcm(pa_core *c, pa_proplist *p, snd_pcm_t *pcm) {
    snd_pcm_hw_params_t *hwparams;
    snd_pcm_info_t *info;
    int bits, err;

    snd_pcm_hw_params_alloca(&hwparams);
    snd_pcm_info_alloca(&info);

    if ((err = snd_pcm_hw_params_current(pcm, hwparams)) < 0)
        pa_log_warn("Error fetching hardware parameter info: %s", pa_alsa_strerror(err));
    else {

        if ((bits = snd_pcm_hw_params_get_sbits(hwparams)) >= 0)
            pa_proplist_setf(p, "alsa.resolution_bits", "%i", bits);
    }

    if ((err = snd_pcm_info(pcm, info)) < 0)
        pa_log_warn("Error fetching PCM info: %s", pa_alsa_strerror(err));
    else
        pa_alsa_init_proplist_pcm_info(c, p, info);
}

#if 0
void pa_alsa_init_proplist_ctl(pa_proplist *p, const char *name) {
    int err;
    snd_ctl_t *ctl;
    snd_ctl_card_info_t *info;
    const char *t;

    pa_assert(p);

    snd_ctl_card_info_alloca(&info);

    if ((err = snd_ctl_open(&ctl, name, 0)) < 0) {
        pa_log_warn("Error opening low-level control device '%s': %s", name, snd_strerror(err));
        return;
    }

    if ((err = snd_ctl_card_info(ctl, info)) < 0) {
        pa_log_warn("Control device %s card info: %s", name, snd_strerror(err));
        snd_ctl_close(ctl);
        return;
    }

    if ((t = snd_ctl_card_info_get_mixername(info)) && *t)
        pa_proplist_sets(p, "alsa.mixer_name", t);

    if ((t = snd_ctl_card_info_get_components(info)) && *t)
        pa_proplist_sets(p, "alsa.components", t);

    snd_ctl_close(ctl);
}

int pa_alsa_recover_from_poll(snd_pcm_t *pcm, int revents) {
    snd_pcm_state_t state;
    snd_pcm_hw_params_t *hwparams;
    int err;

    pa_assert(pcm);

    if (revents & POLLERR)
        pa_log_debug("Got POLLERR from ALSA");
    if (revents & POLLNVAL)
        pa_log_warn("Got POLLNVAL from ALSA");
    if (revents & POLLHUP)
        pa_log_warn("Got POLLHUP from ALSA");
    if (revents & POLLPRI)
        pa_log_warn("Got POLLPRI from ALSA");
    if (revents & POLLIN)
        pa_log_debug("Got POLLIN from ALSA");
    if (revents & POLLOUT)
        pa_log_debug("Got POLLOUT from ALSA");

    state = snd_pcm_state(pcm);
    pa_log_debug("PCM state is %s", snd_pcm_state_name(state));

    /* Try to recover from this error */

    switch (state) {

        case SND_PCM_STATE_DISCONNECTED:
            /* Do not try to recover */
            pa_log_info("Device disconnected.");
            return -1;

        case SND_PCM_STATE_XRUN:
            if ((err = snd_pcm_recover(pcm, -EPIPE, 1)) != 0) {
                pa_log_warn("Could not recover from POLLERR|POLLNVAL|POLLHUP and XRUN: %s", pa_alsa_strerror(err));
                return -1;
            }
            break;

        case SND_PCM_STATE_SUSPENDED:
            snd_pcm_hw_params_alloca(&hwparams);

            if ((err = snd_pcm_hw_params_any(pcm, hwparams)) < 0) {
		pa_log_debug("snd_pcm_hw_params_any() failed: %s", pa_alsa_strerror(err));
		return -1;
            }

            if (snd_pcm_hw_params_can_resume(hwparams)) {
                /* Retry resume 3 times before giving up, then fallback to restarting the stream. */
                for (int i = 0; i < 3; i++) {
                    if ((err = snd_pcm_resume(pcm)) == 0)
                        return 0;
                    if (err != -EAGAIN)
                        break;
                    pa_msleep(25);
                }
                pa_log_warn("Could not recover alsa device from SUSPENDED state, trying to restart PCM");
	    }
	    /* Fall through */

        default:

            snd_pcm_drop(pcm);
            return 1;
    }

    return 0;
}

pa_rtpoll_item* pa_alsa_build_pollfd(snd_pcm_t *pcm, pa_rtpoll *rtpoll) {
    int n, err;
    struct pollfd *pollfd;
    pa_rtpoll_item *item;

    pa_assert(pcm);

    if ((n = snd_pcm_poll_descriptors_count(pcm)) < 0) {
        pa_log("snd_pcm_poll_descriptors_count() failed: %s", pa_alsa_strerror(n));
        return NULL;
    }

    item = pa_rtpoll_item_new(rtpoll, PA_RTPOLL_NEVER, (unsigned) n);
    pollfd = pa_rtpoll_item_get_pollfd(item, NULL);

    if ((err = snd_pcm_poll_descriptors(pcm, pollfd, (unsigned) n)) < 0) {
        pa_log("snd_pcm_poll_descriptors() failed: %s", pa_alsa_strerror(err));
        pa_rtpoll_item_free(item);
        return NULL;
    }

    return item;
}

snd_pcm_sframes_t pa_alsa_safe_avail(snd_pcm_t *pcm, size_t hwbuf_size, const pa_sample_spec *ss) {
    snd_pcm_sframes_t n;
    size_t k;

    pa_assert(pcm);
    pa_assert(hwbuf_size > 0);
    pa_assert(ss);

    /* Some ALSA driver expose weird bugs, let's inform the user about
     * what is going on */

    n = snd_pcm_avail(pcm);

    if (n <= 0)
        return n;

    k = (size_t) n * pa_frame_size(ss);

    if (PA_UNLIKELY(k >= hwbuf_size * 5 ||
                    k >= pa_bytes_per_second(ss)*10)) {

        PA_ONCE_BEGIN {
            char *dn = pa_alsa_get_driver_name_by_pcm(pcm);
            pa_log_debug(ngettext("snd_pcm_avail() returned a value that is exceptionally large: %lu byte (%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            "snd_pcm_avail() returned a value that is exceptionally large: %lu bytes (%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            (unsigned long) k),
                   (unsigned long) k,
                   (unsigned long) (pa_bytes_to_usec(k, ss) / PA_USEC_PER_MSEC),
                   pa_strnull(dn));
            pa_xfree(dn);
            pa_alsa_dump(PA_LOG_DEBUG, pcm);
        } PA_ONCE_END;

        /* Mhmm, let's try not to fail completely */
        n = (snd_pcm_sframes_t) (hwbuf_size / pa_frame_size(ss));
    }

    return n;
}

int pa_alsa_safe_delay(snd_pcm_t *pcm, snd_pcm_status_t *status, snd_pcm_sframes_t *delay, size_t hwbuf_size, const pa_sample_spec *ss,
                       bool capture) {
    ssize_t k;
    size_t abs_k;
    int err;
    snd_pcm_sframes_t avail = 0;
#if (SND_LIB_VERSION >= ((1<<16)|(1<<8)|0)) /* API additions in 1.1.0 */
    snd_pcm_audio_tstamp_config_t tstamp_config;
#endif

    pa_assert(pcm);
    pa_assert(delay);
    pa_assert(hwbuf_size > 0);
    pa_assert(ss);

    /* Some ALSA driver expose weird bugs, let's inform the user about
     * what is going on. We're going to get both the avail and delay values so
     * that we can compare and check them for capture.
     * This is done with snd_pcm_status() which provides
     * avail, delay and timestamp values in a single kernel call to improve
     * timer-based scheduling */

#if (SND_LIB_VERSION >= ((1<<16)|(1<<8)|0)) /* API additions in 1.1.0 */

    /* The time stamp configuration needs to be set so that the
     * ALSA code will use the internal delay reported by the driver.
     * The time stamp configuration was introduced in alsa version 1.1.0. */
    tstamp_config.type_requested = 1; /* ALSA default time stamp type */
    tstamp_config.report_delay = 1;
    snd_pcm_status_set_audio_htstamp_config(status, &tstamp_config);
#endif

    if ((err = snd_pcm_status(pcm, status)) < 0)
        return err;

    avail = snd_pcm_status_get_avail(status);
    *delay = snd_pcm_status_get_delay(status);

    k = (ssize_t) *delay * (ssize_t) pa_frame_size(ss);

    abs_k = k >= 0 ? (size_t) k : (size_t) -k;

    if (PA_UNLIKELY(abs_k >= hwbuf_size * 5 ||
                    abs_k >= pa_bytes_per_second(ss)*10)) {

        PA_ONCE_BEGIN {
            char *dn = pa_alsa_get_driver_name_by_pcm(pcm);
            pa_log_debug(ngettext("snd_pcm_delay() returned a value that is exceptionally large: %li byte (%s%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            "snd_pcm_delay() returned a value that is exceptionally large: %li bytes (%s%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            (signed long) k),
                   (signed long) k,
                   k < 0 ? "-" : "",
                   (unsigned long) (pa_bytes_to_usec(abs_k, ss) / PA_USEC_PER_MSEC),
                   pa_strnull(dn));
            pa_xfree(dn);
            pa_alsa_dump(PA_LOG_DEBUG, pcm);
        } PA_ONCE_END;

        /* Mhmm, let's try not to fail completely */
        if (k < 0)
            *delay = -(snd_pcm_sframes_t) (hwbuf_size / pa_frame_size(ss));
        else
            *delay = (snd_pcm_sframes_t) (hwbuf_size / pa_frame_size(ss));
    }

    if (capture) {
        abs_k = (size_t) avail * pa_frame_size(ss);

        if (PA_UNLIKELY(abs_k >= hwbuf_size * 5 ||
                        abs_k >= pa_bytes_per_second(ss)*10)) {

            PA_ONCE_BEGIN {
                char *dn = pa_alsa_get_driver_name_by_pcm(pcm);
                pa_log_debug(ngettext("snd_pcm_avail() returned a value that is exceptionally large: %lu byte (%lu ms).\n"
                                "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                                "snd_pcm_avail() returned a value that is exceptionally large: %lu bytes (%lu ms).\n"
                                "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                                (unsigned long) k),
                       (unsigned long) k,
                       (unsigned long) (pa_bytes_to_usec(k, ss) / PA_USEC_PER_MSEC),
                       pa_strnull(dn));
                pa_xfree(dn);
                pa_alsa_dump(PA_LOG_DEBUG, pcm);
            } PA_ONCE_END;

            /* Mhmm, let's try not to fail completely */
            avail = (snd_pcm_sframes_t) (hwbuf_size / pa_frame_size(ss));
        }

        if (PA_UNLIKELY(*delay < avail)) {
            PA_ONCE_BEGIN {
                char *dn = pa_alsa_get_driver_name_by_pcm(pcm);
                pa_log(_("snd_pcm_avail_delay() returned strange values: delay %lu is less than avail %lu.\n"
                         "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers."),
                       (unsigned long) *delay,
                       (unsigned long) avail,
                       pa_strnull(dn));
                pa_xfree(dn);
                pa_alsa_dump(PA_LOG_ERROR, pcm);
            } PA_ONCE_END;

            /* try to fixup */
            *delay = avail;
        }
    }

    return 0;
}

int pa_alsa_safe_mmap_begin(snd_pcm_t *pcm, const snd_pcm_channel_area_t **areas, snd_pcm_uframes_t *offset, snd_pcm_uframes_t *frames, size_t hwbuf_size, const pa_sample_spec *ss) {
    int r;
    snd_pcm_uframes_t before;
    size_t k;

    pa_assert(pcm);
    pa_assert(areas);
    pa_assert(offset);
    pa_assert(frames);
    pa_assert(hwbuf_size > 0);
    pa_assert(ss);

    before = *frames;

    r = snd_pcm_mmap_begin(pcm, areas, offset, frames);

    if (r < 0)
        return r;

    k = (size_t) *frames * pa_frame_size(ss);

    if (PA_UNLIKELY(*frames > before ||
                    k >= hwbuf_size * 3 ||
                    k >= pa_bytes_per_second(ss)*10))
        PA_ONCE_BEGIN {
            char *dn = pa_alsa_get_driver_name_by_pcm(pcm);
            pa_log_debug(ngettext("snd_pcm_mmap_begin() returned a value that is exceptionally large: %lu byte (%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            "snd_pcm_mmap_begin() returned a value that is exceptionally large: %lu bytes (%lu ms).\n"
                            "Most likely this is a bug in the ALSA driver '%s'. Please report this issue to the ALSA developers.",
                            (unsigned long) k),
                   (unsigned long) k,
                   (unsigned long) (pa_bytes_to_usec(k, ss) / PA_USEC_PER_MSEC),
                   pa_strnull(dn));
            pa_xfree(dn);
            pa_alsa_dump(PA_LOG_DEBUG, pcm);
        } PA_ONCE_END;

    return r;
}
#endif

char *pa_alsa_get_driver_name(int card) {
    char *t, *m, *n;

    pa_assert(card >= 0);

    t = pa_sprintf_malloc("/sys/class/sound/card%i/device/driver/module", card);
    m = pa_readlink(t);
    pa_xfree(t);

    if (!m)
        return NULL;

    n = pa_xstrdup(pa_path_get_filename(m));
    pa_xfree(m);

    return n;
}

char *pa_alsa_get_driver_name_by_pcm(snd_pcm_t *pcm) {
    int card;
    snd_pcm_info_t* info;
    snd_pcm_info_alloca(&info);

    pa_assert(pcm);

    if (snd_pcm_info(pcm, info) < 0)
        return NULL;

    if ((card = snd_pcm_info_get_card(info)) < 0)
        return NULL;

    return pa_alsa_get_driver_name(card);
}

#if 0
char *pa_alsa_get_reserve_name(const char *device) {
    const char *t;
    int i;

    pa_assert(device);

    if ((t = strchr(device, ':')))
        device = t+1;

    if ((i = snd_card_get_index(device)) < 0) {
        int32_t k;

        if (pa_atoi(device, &k) < 0)
            return NULL;

        i = (int) k;
    }

    return pa_sprintf_malloc("Audio%i", i);
}

unsigned int *pa_alsa_get_supported_rates(snd_pcm_t *pcm, unsigned int fallback_rate) {
    static unsigned int all_rates[] = { 8000, 11025, 12000,
                                        16000, 22050, 24000,
                                        32000, 44100, 48000,
                                        64000, 88200, 96000,
                                        128000, 176400, 192000,
                                        384000 };
    bool supported[PA_ELEMENTSOF(all_rates)] = { false, };
    snd_pcm_hw_params_t *hwparams;
    unsigned int i, j, n, *rates = NULL;
    int ret;

    snd_pcm_hw_params_alloca(&hwparams);

    if ((ret = snd_pcm_hw_params_any(pcm, hwparams)) < 0) {
        pa_log_debug("snd_pcm_hw_params_any() failed: %s", pa_alsa_strerror(ret));
        return NULL;
    }

    for (i = 0, n = 0; i < PA_ELEMENTSOF(all_rates); i++) {
        if (snd_pcm_hw_params_test_rate(pcm, hwparams, all_rates[i], 0) == 0) {
            supported[i] = true;
            n++;
        }
    }

    if (n > 0) {
        rates = pa_xnew(unsigned int, n + 1);

        for (i = 0, j = 0; i < PA_ELEMENTSOF(all_rates); i++) {
            if (supported[i])
                rates[j++] = all_rates[i];
        }

        rates[j] = 0;
    } else {
        rates = pa_xnew(unsigned int, 2);

        rates[0] = fallback_rate;
        if ((ret = snd_pcm_hw_params_set_rate_near(pcm, hwparams, &rates[0], NULL)) < 0) {
            pa_log_debug("snd_pcm_hw_params_set_rate_near() failed: %s", pa_alsa_strerror(ret));
            pa_xfree(rates);
            return NULL;
        }

        rates[1] = 0;
    }

    return rates;
}

pa_sample_format_t *pa_alsa_get_supported_formats(snd_pcm_t *pcm, pa_sample_format_t fallback_format) {
    static const snd_pcm_format_t format_trans_to_pa[] = {
        [SND_PCM_FORMAT_U8] = PA_SAMPLE_U8,
        [SND_PCM_FORMAT_A_LAW] = PA_SAMPLE_ALAW,
        [SND_PCM_FORMAT_MU_LAW] = PA_SAMPLE_ULAW,
        [SND_PCM_FORMAT_S16_LE] = PA_SAMPLE_S16LE,
        [SND_PCM_FORMAT_S16_BE] = PA_SAMPLE_S16BE,
        [SND_PCM_FORMAT_FLOAT_LE] = PA_SAMPLE_FLOAT32LE,
        [SND_PCM_FORMAT_FLOAT_BE] = PA_SAMPLE_FLOAT32BE,
        [SND_PCM_FORMAT_S32_LE] = PA_SAMPLE_S32LE,
        [SND_PCM_FORMAT_S32_BE] = PA_SAMPLE_S32BE,
        [SND_PCM_FORMAT_S24_3LE] = PA_SAMPLE_S24LE,
        [SND_PCM_FORMAT_S24_3BE] = PA_SAMPLE_S24BE,
        [SND_PCM_FORMAT_S24_LE] = PA_SAMPLE_S24_32LE,
        [SND_PCM_FORMAT_S24_BE] = PA_SAMPLE_S24_32BE,
    };
    static const snd_pcm_format_t all_formats[] = {
        SND_PCM_FORMAT_U8,
        SND_PCM_FORMAT_A_LAW,
        SND_PCM_FORMAT_MU_LAW,
        SND_PCM_FORMAT_S16_LE,
        SND_PCM_FORMAT_S16_BE,
        SND_PCM_FORMAT_FLOAT_LE,
        SND_PCM_FORMAT_FLOAT_BE,
        SND_PCM_FORMAT_S32_LE,
        SND_PCM_FORMAT_S32_BE,
        SND_PCM_FORMAT_S24_3LE,
        SND_PCM_FORMAT_S24_3BE,
        SND_PCM_FORMAT_S24_LE,
        SND_PCM_FORMAT_S24_BE,
    };
    bool supported[PA_ELEMENTSOF(all_formats)] = {
        false,
    };
    snd_pcm_hw_params_t *hwparams;
    unsigned int i, j, n;
    pa_sample_format_t *formats = NULL;
    int ret;

    snd_pcm_hw_params_alloca(&hwparams);

    if ((ret = snd_pcm_hw_params_any(pcm, hwparams)) < 0) {
        pa_log_debug("snd_pcm_hw_params_any() failed: %s", pa_alsa_strerror(ret));
        return NULL;
    }

    for (i = 0, n = 0; i < PA_ELEMENTSOF(all_formats); i++) {
        if (snd_pcm_hw_params_test_format(pcm, hwparams, all_formats[i]) == 0) {
            supported[i] = true;
            n++;
        }
    }

    if (n > 0) {
        formats = pa_xnew(pa_sample_format_t, n + 1);

        for (i = 0, j = 0; i < PA_ELEMENTSOF(all_formats); i++) {
            if (supported[i])
                formats[j++] = format_trans_to_pa[all_formats[i]];
        }

        formats[j] = PA_SAMPLE_MAX;
    } else {
        formats = pa_xnew(pa_sample_format_t, 2);

        formats[0] = fallback_format;
        if ((ret = snd_pcm_hw_params_set_format(pcm, hwparams, format_trans_to_pa[formats[0]])) < 0) {
            pa_log_debug("snd_pcm_hw_params_set_format() failed: %s", pa_alsa_strerror(ret));
            pa_xfree(formats);
            return NULL;
        }

        formats[1] = PA_SAMPLE_MAX;
    }

    return formats;
}
#endif

bool pa_alsa_pcm_is_hw(snd_pcm_t *pcm) {
    snd_pcm_info_t* info;
    snd_pcm_info_alloca(&info);

    pa_assert(pcm);

    if (snd_pcm_info(pcm, info) < 0)
        return false;

    return snd_pcm_info_get_card(info) >= 0;
}

bool pa_alsa_pcm_is_modem(snd_pcm_t *pcm) {
    snd_pcm_info_t* info;
    snd_pcm_info_alloca(&info);

    pa_assert(pcm);

    if (snd_pcm_info(pcm, info) < 0)
        return false;

    return snd_pcm_info_get_class(info) == SND_PCM_CLASS_MODEM;
}

const char* pa_alsa_strerror(int errnum) {
    return snd_strerror(errnum);
}

#if 0
bool pa_alsa_may_tsched(bool want) {

    if (!want)
        return false;

    if (!pa_rtclock_hrtimer()) {
        /* We cannot depend on being woken up in time when the timers
        are inaccurate, so let's fallback to classic IO based playback
        then. */
        pa_log_notice("Disabling timer-based scheduling because high-resolution timers are not available from the kernel.");
        return false; }

    if (pa_running_in_vm()) {
        /* We cannot depend on being woken up when we ask for in a VM,
         * so let's fallback to classic IO based playback then. */
        pa_log_notice("Disabling timer-based scheduling because running inside a VM.");
        return false;
    }

    return true;
}
#endif

#define SND_MIXER_ELEM_PULSEAUDIO (SND_MIXER_ELEM_LAST + 10)

static snd_mixer_elem_t *pa_alsa_mixer_find(snd_mixer_t *mixer,
                                            snd_ctl_elem_iface_t iface,
                                            const char *name,
                                            unsigned int index,
                                            unsigned int device) {
    snd_mixer_elem_t *elem;

    for (elem = snd_mixer_first_elem(mixer); elem; elem = snd_mixer_elem_next(elem)) {
        snd_hctl_elem_t *helem;
        if (snd_mixer_elem_get_type(elem) != SND_MIXER_ELEM_PULSEAUDIO)
            continue;
        helem = snd_mixer_elem_get_private(elem);
        if (snd_hctl_elem_get_interface(helem) != iface)
            continue;
        if (!pa_streq(snd_hctl_elem_get_name(helem), name))
            continue;
        if (snd_hctl_elem_get_index(helem) != index)
            continue;
        if (snd_hctl_elem_get_device(helem) != device)
            continue;
        return elem;
    }
    return NULL;
}

snd_mixer_elem_t *pa_alsa_mixer_find_card(snd_mixer_t *mixer, struct pa_alsa_mixer_id *alsa_id, unsigned int device) {
    return pa_alsa_mixer_find(mixer, SND_CTL_ELEM_IFACE_CARD, alsa_id->name, alsa_id->index, device);
}

snd_mixer_elem_t *pa_alsa_mixer_find_pcm(snd_mixer_t *mixer, const char *name, unsigned int device) {
    return pa_alsa_mixer_find(mixer, SND_CTL_ELEM_IFACE_PCM, name, 0, device);
}

static int mixer_class_compare(const snd_mixer_elem_t *c1, const snd_mixer_elem_t *c2)
{
    /* Dummy compare function */
    return c1 == c2 ? 0 : (c1 > c2 ? 1 : -1);
}

static int mixer_class_event(snd_mixer_class_t *class, unsigned int mask,
			snd_hctl_elem_t *helem, snd_mixer_elem_t *melem)
{
    int err;
    const char *name = snd_hctl_elem_get_name(helem);
    if (mask & SND_CTL_EVENT_MASK_ADD) {
        snd_ctl_elem_iface_t iface = snd_hctl_elem_get_interface(helem);
        if (iface == SND_CTL_ELEM_IFACE_CARD || iface == SND_CTL_ELEM_IFACE_PCM) {
            snd_mixer_elem_t *new_melem;

            /* Put the hctl pointer as our private data - it will be useful for callbacks */
            if ((err = snd_mixer_elem_new(&new_melem, SND_MIXER_ELEM_PULSEAUDIO, 0, helem, NULL)) < 0) {
                pa_log_warn("snd_mixer_elem_new failed: %s", pa_alsa_strerror(err));
                return 0;
            }

            if ((err = snd_mixer_elem_attach(new_melem, helem)) < 0) {
                pa_log_warn("snd_mixer_elem_attach failed: %s", pa_alsa_strerror(err));
		snd_mixer_elem_free(melem);
                return 0;
            }

            if ((err = snd_mixer_elem_add(new_melem, class)) < 0) {
                pa_log_warn("snd_mixer_elem_add failed: %s", pa_alsa_strerror(err));
                return 0;
            }
        }
    }
    else if (mask & SND_CTL_EVENT_MASK_VALUE) {
        snd_mixer_elem_value(melem); /* Calls the element callback */
        return 0;
    }
    else
        pa_log_info("Got an unknown mixer class event for %s: mask 0x%x", name, mask);

    return 0;
}

static int prepare_mixer(snd_mixer_t *mixer, const char *dev) {
    int err;
    snd_mixer_class_t *class;

    pa_assert(mixer);
    pa_assert(dev);

    if ((err = snd_mixer_attach(mixer, dev)) < 0) {
        pa_log_info("Unable to attach to mixer %s: %s", dev, pa_alsa_strerror(err));
        return -1;
    }

    if (snd_mixer_class_malloc(&class)) {
        pa_log_info("Failed to allocate mixer class for %s", dev);
        return -1;
    }
    snd_mixer_class_set_event(class, mixer_class_event);
    snd_mixer_class_set_compare(class, mixer_class_compare);
    if ((err = snd_mixer_class_register(class, mixer)) < 0) {
        pa_log_info("Unable register mixer class for %s: %s", dev, pa_alsa_strerror(err));
        snd_mixer_class_free(class);
        return -1;
    }
    /* From here on, the mixer class is deallocated by alsa on snd_mixer_close/free. */

    if ((err = snd_mixer_selem_register(mixer, NULL, NULL)) < 0) {
        pa_log_warn("Unable to register mixer: %s", pa_alsa_strerror(err));
        return -1;
    }

    if ((err = snd_mixer_load(mixer)) < 0) {
        pa_log_warn("Unable to load mixer: %s", pa_alsa_strerror(err));
        return -1;
    }

    pa_log_info("Successfully attached to mixer '%s'", dev);
    return 0;
}

snd_mixer_t *pa_alsa_open_mixer(pa_hashmap *mixers, int alsa_card_index, bool probe) {
    char *md = pa_sprintf_malloc("hw:%i", alsa_card_index);
    snd_mixer_t *m = pa_alsa_open_mixer_by_name(mixers, md, probe);
    pa_xfree(md);
    return m;
}

snd_mixer_t *pa_alsa_open_mixer_by_name(pa_hashmap *mixers, const char *dev, bool probe) {
    int err;
    snd_mixer_t *m;
    pa_alsa_mixer *pm;
    char *dev2;
    void *state;

    pa_assert(mixers);
    pa_assert(dev);

    pm = pa_hashmap_get(mixers, dev);

    /* The quick card number/index lookup (hw:#)
     * We already know the card number/index, thus use the mixer
     * from the cache at first.
     */
    if (!pm && pa_strneq(dev, "hw:", 3)) {
        const char *s = dev + 3;
        int card_index;
        while (*s && *s >= '0' && *s <= '9') s++;
        if (*s == '\0' && pa_atoi(dev + 3, &card_index) >= 0) {
            PA_HASHMAP_FOREACH_KV(dev2, pm, mixers, state) {
                if (pm->card_index == card_index) {
                    dev = dev2;
                    pm = pa_hashmap_get(mixers, dev);
                    break;
                }
            }
        }
    }

    if (pm) {
        if (!probe)
            pm->used_for_probe_only = false;
        return pm->mixer_handle;
    }

    if ((err = snd_mixer_open(&m, 0)) < 0) {
        pa_log("Error opening mixer: %s", pa_alsa_strerror(err));
        return NULL;
    }

    if (prepare_mixer(m, dev) >= 0) {
        pm = pa_xnew0(pa_alsa_mixer, 1);
        if (pm) {
            snd_hctl_t *hctl;
            pm->card_index = -1;
            /* determine the ALSA card number (index) and store it to card_index */
            err = snd_mixer_get_hctl(m, dev, &hctl);
            if (err >= 0) {
                snd_ctl_card_info_t *info;
                snd_ctl_card_info_alloca(&info);
                err = snd_ctl_card_info(snd_hctl_ctl(hctl), info);
                if (err >= 0)
                    pm->card_index = snd_ctl_card_info_get_card(info);
            }
            pm->used_for_probe_only = probe;
            pm->mixer_handle = m;
            pa_hashmap_put(mixers, pa_xstrdup(dev), pm);
            return m;
        }
    }

    snd_mixer_close(m);
    return NULL;
}

snd_mixer_t *pa_alsa_open_mixer_for_pcm(pa_hashmap *mixers, snd_pcm_t *pcm, bool probe) {
    snd_pcm_info_t* info;
    snd_pcm_info_alloca(&info);

    pa_assert(pcm);

    if (snd_pcm_info(pcm, info) >= 0) {
        int card_idx;

        if ((card_idx = snd_pcm_info_get_card(info)) >= 0)
            return pa_alsa_open_mixer(mixers, card_idx, probe);
    }

    return NULL;
}

#if 0
void pa_alsa_mixer_set_fdlist(pa_hashmap *mixers, snd_mixer_t *mixer_handle, pa_mainloop_api *ml)
{
    pa_alsa_mixer *pm;
    void *state;

    PA_HASHMAP_FOREACH(pm, mixers, state)
        if (pm->mixer_handle == mixer_handle) {
            pm->used_for_probe_only = false;
            if (!pm->fdl) {
                pm->fdl = pa_alsa_fdlist_new();
                if (pm->fdl)
                    pa_alsa_fdlist_set_handle(pm->fdl, pm->mixer_handle, NULL, ml);
            }
        }
}
#endif

void pa_alsa_mixer_free(pa_alsa_mixer *mixer)
{
    if (mixer->mixer_handle)
        snd_mixer_close(mixer->mixer_handle);
    pa_xfree(mixer);
}

int pa_alsa_get_hdmi_eld(snd_hctl_elem_t *elem, pa_hdmi_eld *eld) {

    /* The ELD format is specific to HDA Intel sound cards and defined in the
       HDA specification: http://www.intel.com/content/www/us/en/standards/high-definition-audio-specification.html */
    int err;
    snd_ctl_elem_info_t *info;
    snd_ctl_elem_value_t *value;
    uint8_t *elddata;
    unsigned int eldsize, mnl;
    unsigned int device;

    pa_assert(eld != NULL);
    pa_assert(elem != NULL);

    /* Does it have any contents? */
    snd_ctl_elem_info_alloca(&info);
    snd_ctl_elem_value_alloca(&value);
    if ((err = snd_hctl_elem_info(elem, info)) < 0 ||
       (err = snd_hctl_elem_read(elem, value)) < 0) {
        pa_log_warn("Accessing ELD control failed with error %s", snd_strerror(err));
        return -1;
    }

    device = snd_hctl_elem_get_device(elem);
    eldsize = snd_ctl_elem_info_get_count(info);
    elddata = (unsigned char *) snd_ctl_elem_value_get_bytes(value);
    if (elddata == NULL || eldsize == 0) {
        pa_log_debug("ELD info empty (for device=%d)", device);
        return -1;
    }
    if (eldsize < 20 || eldsize > 256) {
        pa_log_debug("ELD info has wrong size (for device=%d)", device);
        return -1;
    }

    /* Try to fetch monitor name */
    mnl = elddata[4] & 0x1f;
    if (mnl == 0 || mnl > 16 || 20 + mnl > eldsize) {
        pa_log_debug("No monitor name in ELD info (for device=%d)", device);
        mnl = 0;
    }
    memcpy(eld->monitor_name, &elddata[20], mnl);
    eld->monitor_name[mnl] = '\0';
    if (mnl)
        pa_log_debug("Monitor name in ELD info is '%s' (for device=%d)", eld->monitor_name, device);

    return 0;
}
