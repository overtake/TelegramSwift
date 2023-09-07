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
#include <math.h>

#ifdef HAVE_VALGRIND_MEMCHECK_H
#include <valgrind/memcheck.h>
#endif

#include "conf-parser.h"
#include "alsa-mixer.h"
#include "alsa-util.h"

#ifdef HAVE_VALGRIND_MEMCHECK_H
/* These macros are workarounds for a bug in valgrind, which is not handling the
 * ALSA TLV syscalls correctly. See
 * http://valgrind.10908.n7.nabble.com/Missing-ioctl-for-SNDRV-CTL-IOCTL-TLV-READ-td42711.html */

static inline int vgfix_get_capture_dB(snd_mixer_elem_t *a, snd_mixer_selem_channel_id_t b, long *c) {
    int r = snd_mixer_selem_get_capture_dB(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

static inline int vgfix_get_playback_dB(snd_mixer_elem_t *a, snd_mixer_selem_channel_id_t b, long *c) {
    int r = snd_mixer_selem_get_playback_dB(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

static inline int vgfix_ask_capture_vol_dB(snd_mixer_elem_t *a, long b, long *c) {
    int r = snd_mixer_selem_ask_capture_vol_dB(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

static inline int vgfix_ask_playback_vol_dB(snd_mixer_elem_t *a, long b, long *c) {
    int r = snd_mixer_selem_ask_playback_vol_dB(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

static inline int vgfix_get_capture_dB_range(snd_mixer_elem_t *a, long *b, long *c) {
    int r = snd_mixer_selem_get_capture_dB_range(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(b, sizeof(*b));
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

static inline int vgfix_get_playback_dB_range(snd_mixer_elem_t *a, long *b, long *c) {
    int r = snd_mixer_selem_get_playback_dB_range(a, b, c);
    VALGRIND_MAKE_MEM_DEFINED(b, sizeof(*b));
    VALGRIND_MAKE_MEM_DEFINED(c, sizeof(*c));
    return r;
}

#define snd_mixer_selem_get_capture_dB(a, b, c) vgfix_get_capture_dB(a, b, c)
#define snd_mixer_selem_get_playback_dB(a, b, c) vgfix_get_playback_dB(a, b, c)
#define snd_mixer_selem_ask_capture_vol_dB(a, b, c) vgfix_ask_capture_vol_dB(a, b, c)
#define snd_mixer_selem_ask_playback_vol_dB(a, b, c) vgfix_ask_playback_vol_dB(a, b, c)
#define snd_mixer_selem_get_capture_dB_range(a, b, c) vgfix_get_capture_dB_range(a, b, c)
#define snd_mixer_selem_get_playback_dB_range(a, b, c) vgfix_get_playback_dB_range(a, b, c)

#endif

static int setting_select(pa_alsa_setting *s, snd_mixer_t *m);

struct description_map {
    const char *key;
    const char *description;
};

struct description2_map {
    const char *key;
    const char *description;
    pa_device_port_type_t type;
};

char *pa_alsa_mixer_id_to_string(char *dst, size_t dst_len, pa_alsa_mixer_id *id) {
    if (id->index > 0) {
        snprintf(dst, dst_len, "'%s',%d", id->name, id->index);
    } else {
        snprintf(dst, dst_len, "'%s'", id->name);
    }
    return dst;
}

static int alsa_id_decode(const char *src, char *name, int *index) {
    char *idx, c;
    int i;

    *index = 0;
    c = src[0];
    /* Strip quotes in entries such as 'Speaker',1 or "Speaker",1 */
    if (c == '\'' || c == '"') {
        strcpy(name, src + 1);
        for (i = 0; name[i] != '\0' && name[i] != c; i++);
        idx = NULL;
        if (name[i]) {
                name[i] = '\0';
                idx = strchr(name + i + 1, ',');
        }
    } else {
        strcpy(name, src);
        idx = strchr(name, ',');
    }
    if (idx == NULL)
        return 0;
    *idx = '\0';
    idx++;
    if (*idx < '0' || *idx > '9') {
        pa_log("Element %s: index value is invalid", src);
        return 1;
    }
    *index = atoi(idx);
    return 0;
}

pa_alsa_jack *pa_alsa_jack_new(pa_alsa_path *path, const char *mixer_device_name, const char *name, int index) {
    pa_alsa_jack *jack;

    pa_assert(name);

    jack = pa_xnew0(pa_alsa_jack, 1);
    jack->path = path;
    jack->mixer_device_name = pa_xstrdup(mixer_device_name);
    jack->name = pa_xstrdup(name);
    jack->alsa_id.name = pa_sprintf_malloc("%s Jack", name);
    jack->alsa_id.index = index;
    jack->state_unplugged = PA_AVAILABLE_NO;
    jack->state_plugged = PA_AVAILABLE_YES;
    jack->ucm_devices = pa_dynarray_new(NULL);
    jack->ucm_hw_mute_devices = pa_dynarray_new(NULL);

    return jack;
}

void pa_alsa_jack_free(pa_alsa_jack *jack) {
    pa_assert(jack);

    pa_dynarray_free(jack->ucm_hw_mute_devices);
    pa_dynarray_free(jack->ucm_devices);

    pa_xfree(jack->alsa_id.name);
    pa_xfree(jack->name);
    pa_xfree(jack->mixer_device_name);
    pa_xfree(jack);
}

void pa_alsa_jack_set_has_control(pa_alsa_jack *jack, bool has_control) {
    pa_alsa_ucm_device *device;
    unsigned idx;

    pa_assert(jack);

    if (has_control == jack->has_control)
        return;

    jack->has_control = has_control;

    PA_DYNARRAY_FOREACH(device, jack->ucm_hw_mute_devices, idx)
        pa_alsa_ucm_device_update_available(device);

    PA_DYNARRAY_FOREACH(device, jack->ucm_devices, idx)
        pa_alsa_ucm_device_update_available(device);
}

void pa_alsa_jack_set_plugged_in(pa_alsa_jack *jack, bool plugged_in) {
    pa_alsa_ucm_device *device;
    unsigned idx;

    pa_assert(jack);

    if (plugged_in == jack->plugged_in)
        return;

    jack->plugged_in = plugged_in;

    /* XXX: If this is a headphone jack that mutes speakers when plugged in,
     * and the headphones get unplugged, then the headphone device must be set
     * to unavailable and the speaker device must be set to unknown. So far so
     * good. But there's an ugly detail: we must first set the availability of
     * the speakers and then the headphones. We shouldn't need to care about
     * the order, but we have to, because module-switch-on-port-available gets
     * separate events for the two devices, and the intermediate state between
     * the two events is such that the second event doesn't trigger the desired
     * port switch, if the event order is "wrong".
     *
     * These are the transitions when the event order is "right":
     *
     *     speakers:   1) unavailable -> 2) unknown   -> 3) unknown
     *     headphones: 1) available   -> 2) available -> 3) unavailable
     *
     * In the 2 -> 3 transition, headphones become unavailable, and
     * module-switch-on-port-available sees that speakers can be used, so the
     * port gets changed as it should.
     *
     * These are the transitions when the event order is "wrong":
     *
     *     speakers:   1) unavailable -> 2) unavailable -> 3) unknown
     *     headphones: 1) available   -> 2) unavailable -> 3) unavailable
     *
     * In the 1 -> 2 transition, headphones become unavailable, and there are
     * no available ports to use, so no port change happens. In the 2 -> 3
     * transition, speaker availability becomes unknown, but that's not
     * a strong enough signal for module-switch-on-port-available, so it still
     * doesn't do the port switch.
     *
     * We should somehow merge the two events so that
     * module-switch-on-port-available would handle both transitions in one go.
     * If module-switch-on-port-available used a defer event to delay
     * the port availability processing, that would probably do the trick. */

    PA_DYNARRAY_FOREACH(device, jack->ucm_hw_mute_devices, idx)
        pa_alsa_ucm_device_update_available(device);

    PA_DYNARRAY_FOREACH(device, jack->ucm_devices, idx)
        pa_alsa_ucm_device_update_available(device);
}

void pa_alsa_jack_add_ucm_device(pa_alsa_jack *jack, pa_alsa_ucm_device *device) {
    pa_alsa_ucm_device *idevice;
    unsigned idx, prio, iprio;

    pa_assert(jack);
    pa_assert(device);

    /* store the ucm device with the sequence of priority from low to high. this
     * could guarantee when the jack state is changed, the device with highest
     * priority will send to the module-switch-on-port-available last */
    prio = device->playback_priority ? device->playback_priority : device->capture_priority;

    PA_DYNARRAY_FOREACH(idevice, jack->ucm_devices, idx) {
        iprio = idevice->playback_priority ? idevice->playback_priority : idevice->capture_priority;
        if (iprio > prio)
            break;
    }
    pa_dynarray_insert_by_index(jack->ucm_devices, device, idx);
}

void pa_alsa_jack_add_ucm_hw_mute_device(pa_alsa_jack *jack, pa_alsa_ucm_device *device) {
    pa_assert(jack);
    pa_assert(device);

    pa_dynarray_append(jack->ucm_hw_mute_devices, device);
}

static const char *lookup_description(const char *key, const struct description_map dm[], unsigned n) {
    unsigned i;

    if (!key)
        return NULL;

    for (i = 0; i < n; i++)
        if (pa_streq(dm[i].key, key))
            return _(dm[i].description);

    return NULL;
}

static const struct description2_map *lookup_description2(const char *key, const struct description2_map dm[], unsigned n) {
    unsigned i;

    if (!key)
        return NULL;

    for (i = 0; i < n; i++)
        if (pa_streq(dm[i].key, key))
            return &dm[i];

    return NULL;
}

void pa_alsa_mixer_use_for_poll(pa_hashmap *mixers, snd_mixer_t *mixer_handle)
{
    pa_alsa_mixer *pm;
    void *state;

    PA_HASHMAP_FOREACH(pm, mixers, state) {
        if (pm->mixer_handle == mixer_handle) {
            pm->used_for_probe_only = false;
	    pm->used_for_poll = true;
	}
    }
}

#if 0
struct pa_alsa_fdlist {
    unsigned num_fds;
    struct pollfd *fds;
    /* This is a temporary buffer used to avoid lots of mallocs */
    struct pollfd *work_fds;

    snd_mixer_t *mixer;
    snd_hctl_t *hctl;

    pa_mainloop_api *m;
    pa_defer_event *defer;
    pa_io_event **ios;

    bool polled;

    void (*cb)(void *userdata);
    void *userdata;
};

static void io_cb(pa_mainloop_api *a, pa_io_event *e, int fd, pa_io_event_flags_t events, void *userdata) {

    struct pa_alsa_fdlist *fdl = userdata;
    int err;
    unsigned i;
    unsigned short revents;

    pa_assert(a);
    pa_assert(fdl);
    pa_assert(fdl->mixer || fdl->hctl);
    pa_assert(fdl->fds);
    pa_assert(fdl->work_fds);

    if (fdl->polled)
        return;

    fdl->polled = true;

    memcpy(fdl->work_fds, fdl->fds, sizeof(struct pollfd) * fdl->num_fds);

    for (i = 0; i < fdl->num_fds; i++) {
        if (e == fdl->ios[i]) {
            if (events & PA_IO_EVENT_INPUT)
                fdl->work_fds[i].revents |= POLLIN;
            if (events & PA_IO_EVENT_OUTPUT)
                fdl->work_fds[i].revents |= POLLOUT;
            if (events & PA_IO_EVENT_ERROR)
                fdl->work_fds[i].revents |= POLLERR;
            if (events & PA_IO_EVENT_HANGUP)
                fdl->work_fds[i].revents |= POLLHUP;
            break;
        }
    }

    pa_assert(i != fdl->num_fds);

    if (fdl->hctl)
        err = snd_hctl_poll_descriptors_revents(fdl->hctl, fdl->work_fds, fdl->num_fds, &revents);
    else
        err = snd_mixer_poll_descriptors_revents(fdl->mixer, fdl->work_fds, fdl->num_fds, &revents);

    if (err < 0) {
        pa_log_error("Unable to get poll revent: %s", pa_alsa_strerror(err));
        return;
    }

    a->defer_enable(fdl->defer, 1);

    if (revents) {
        if (fdl->hctl)
            snd_hctl_handle_events(fdl->hctl);
        else
            snd_mixer_handle_events(fdl->mixer);
    }
}

static void defer_cb(pa_mainloop_api *a, pa_defer_event *e, void *userdata) {
    struct pa_alsa_fdlist *fdl = userdata;
    unsigned num_fds, i;
    int err, n;
    struct pollfd *temp;

    pa_assert(a);
    pa_assert(fdl);
    pa_assert(fdl->mixer || fdl->hctl);

    a->defer_enable(fdl->defer, 0);

    if (fdl->hctl)
        n = snd_hctl_poll_descriptors_count(fdl->hctl);
    else
        n = snd_mixer_poll_descriptors_count(fdl->mixer);

    if (n < 0) {
        pa_log("snd_mixer_poll_descriptors_count() failed: %s", pa_alsa_strerror(n));
        return;
    }
    else if (n == 0) {
        pa_log_warn("Mixer has no poll descriptors. Please control mixer from PulseAudio only.");
        return;
    }
    num_fds = (unsigned) n;

    if (num_fds != fdl->num_fds) {
        if (fdl->fds)
            pa_xfree(fdl->fds);
        if (fdl->work_fds)
            pa_xfree(fdl->work_fds);
        fdl->fds = pa_xnew0(struct pollfd, num_fds);
        fdl->work_fds = pa_xnew(struct pollfd, num_fds);
    }

    memset(fdl->work_fds, 0, sizeof(struct pollfd) * num_fds);

    if (fdl->hctl)
        err = snd_hctl_poll_descriptors(fdl->hctl, fdl->work_fds, num_fds);
    else
        err = snd_mixer_poll_descriptors(fdl->mixer, fdl->work_fds, num_fds);

    if (err < 0) {
        pa_log_error("Unable to get poll descriptors: %s", pa_alsa_strerror(err));
        return;
    }

    fdl->polled = false;

    if (memcmp(fdl->fds, fdl->work_fds, sizeof(struct pollfd) * num_fds) == 0)
        return;

    if (fdl->ios) {
        for (i = 0; i < fdl->num_fds; i++)
            a->io_free(fdl->ios[i]);

        if (num_fds != fdl->num_fds) {
            pa_xfree(fdl->ios);
            fdl->ios = NULL;
        }
    }

    if (!fdl->ios)
        fdl->ios = pa_xnew(pa_io_event*, num_fds);

    /* Swap pointers */
    temp = fdl->work_fds;
    fdl->work_fds = fdl->fds;
    fdl->fds = temp;

    fdl->num_fds = num_fds;

    for (i = 0;i < num_fds;i++)
        fdl->ios[i] = a->io_new(a, fdl->fds[i].fd,
            ((fdl->fds[i].events & POLLIN) ? PA_IO_EVENT_INPUT : 0) |
            ((fdl->fds[i].events & POLLOUT) ? PA_IO_EVENT_OUTPUT : 0),
            io_cb, fdl);
}

struct pa_alsa_fdlist *pa_alsa_fdlist_new(void) {
    struct pa_alsa_fdlist *fdl;

    fdl = pa_xnew0(struct pa_alsa_fdlist, 1);

    return fdl;
}

void pa_alsa_fdlist_free(struct pa_alsa_fdlist *fdl) {
    pa_assert(fdl);

    if (fdl->defer) {
        pa_assert(fdl->m);
        fdl->m->defer_free(fdl->defer);
    }

    if (fdl->ios) {
        unsigned i;
        pa_assert(fdl->m);
        for (i = 0; i < fdl->num_fds; i++)
            fdl->m->io_free(fdl->ios[i]);
        pa_xfree(fdl->ios);
    }

    if (fdl->fds)
        pa_xfree(fdl->fds);
    if (fdl->work_fds)
        pa_xfree(fdl->work_fds);

    pa_xfree(fdl);
}

/* We can listen to either a snd_hctl_t or a snd_mixer_t, but not both */
int pa_alsa_fdlist_set_handle(struct pa_alsa_fdlist *fdl, snd_mixer_t *mixer_handle, snd_hctl_t *hctl_handle, pa_mainloop_api *m) {
    pa_assert(fdl);
    pa_assert(hctl_handle || mixer_handle);
    pa_assert(!(hctl_handle && mixer_handle));
    pa_assert(m);
    pa_assert(!fdl->m);

    fdl->hctl = hctl_handle;
    fdl->mixer = mixer_handle;
    fdl->m = m;
    fdl->defer = m->defer_new(m, defer_cb, fdl);

    return 0;
}

struct pa_alsa_mixer_pdata {
    pa_rtpoll *rtpoll;
    pa_rtpoll_item *poll_item;
    snd_mixer_t *mixer;
};

struct pa_alsa_mixer_pdata *pa_alsa_mixer_pdata_new(void) {
    struct pa_alsa_mixer_pdata *pd;

    pd = pa_xnew0(struct pa_alsa_mixer_pdata, 1);

    return pd;
}

void pa_alsa_mixer_pdata_free(struct pa_alsa_mixer_pdata *pd) {
    pa_assert(pd);

    if (pd->poll_item) {
        pa_rtpoll_item_free(pd->poll_item);
    }

    pa_xfree(pd);
}

static int rtpoll_work_cb(pa_rtpoll_item *i) {
    struct pa_alsa_mixer_pdata *pd;
    struct pollfd *p;
    unsigned n_fds;
    unsigned short revents = 0;
    int err, ret = 0;

    pd = pa_rtpoll_item_get_work_userdata(i);
    pa_assert_fp(pd);
    pa_assert_fp(i == pd->poll_item);

    p = pa_rtpoll_item_get_pollfd(i, &n_fds);

    if ((err = snd_mixer_poll_descriptors_revents(pd->mixer, p, n_fds, &revents)) < 0) {
        pa_log_error("Unable to get poll revent: %s", pa_alsa_strerror(err));
        ret = -1;
        goto fail;
    }

    if (revents) {
        if (revents & (POLLNVAL | POLLERR)) {
            pa_log_debug("Device disconnected, stopping poll on mixer");
            goto fail;
        } else if (revents & POLLERR) {
            /* This shouldn't happen. */
            pa_log_error("Got a POLLERR (revents = %04x), stopping poll on mixer", revents);
            goto fail;
        }

        err = snd_mixer_handle_events(pd->mixer);

        if (PA_LIKELY(err >= 0)) {
            pa_rtpoll_item_free(i);
            pa_alsa_set_mixer_rtpoll(pd, pd->mixer, pd->rtpoll);
        } else {
            pa_log_error("Error handling mixer event: %s", pa_alsa_strerror(err));
            ret = -1;
            goto fail;
        }
    }

    return ret;

fail:
    pa_rtpoll_item_free(i);

    pd->poll_item = NULL;
    pd->rtpoll = NULL;
    pd->mixer = NULL;

    return ret;
}

int pa_alsa_set_mixer_rtpoll(struct pa_alsa_mixer_pdata *pd, snd_mixer_t *mixer, pa_rtpoll *rtp) {
    pa_rtpoll_item *i;
    struct pollfd *p;
    int err, n;

    pa_assert(pd);
    pa_assert(mixer);
    pa_assert(rtp);

    if ((n = snd_mixer_poll_descriptors_count(mixer)) < 0) {
        pa_log("snd_mixer_poll_descriptors_count() failed: %s", pa_alsa_strerror(n));
        return -1;
    }
    else if (n == 0) {
        pa_log_warn("Mixer has no poll descriptors. Please control mixer from PulseAudio only.");
        return 0;
    }

    i = pa_rtpoll_item_new(rtp, PA_RTPOLL_LATE, (unsigned) n);

    p = pa_rtpoll_item_get_pollfd(i, NULL);

    memset(p, 0, sizeof(struct pollfd) * n);

    if ((err = snd_mixer_poll_descriptors(mixer, p, (unsigned) n)) < 0) {
        pa_log_error("Unable to get poll descriptors: %s", pa_alsa_strerror(err));
        pa_rtpoll_item_free(i);
        return -1;
    }

    pd->rtpoll = rtp;
    pd->poll_item = i;
    pd->mixer = mixer;

    pa_rtpoll_item_set_work_callback(i, rtpoll_work_cb, pd);

    return 0;
}
#endif

static const snd_mixer_selem_channel_id_t alsa_channel_ids[PA_CHANNEL_POSITION_MAX] = {
    [PA_CHANNEL_POSITION_MONO] = SND_MIXER_SCHN_MONO, /* The ALSA name is just an alias! */

    [PA_CHANNEL_POSITION_FRONT_CENTER] = SND_MIXER_SCHN_FRONT_CENTER,
    [PA_CHANNEL_POSITION_FRONT_LEFT] = SND_MIXER_SCHN_FRONT_LEFT,
    [PA_CHANNEL_POSITION_FRONT_RIGHT] = SND_MIXER_SCHN_FRONT_RIGHT,

    [PA_CHANNEL_POSITION_REAR_CENTER] = SND_MIXER_SCHN_REAR_CENTER,
    [PA_CHANNEL_POSITION_REAR_LEFT] = SND_MIXER_SCHN_REAR_LEFT,
    [PA_CHANNEL_POSITION_REAR_RIGHT] = SND_MIXER_SCHN_REAR_RIGHT,

    [PA_CHANNEL_POSITION_LFE] = SND_MIXER_SCHN_WOOFER,

    [PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER] = SND_MIXER_SCHN_UNKNOWN,

    [PA_CHANNEL_POSITION_SIDE_LEFT] = SND_MIXER_SCHN_SIDE_LEFT,
    [PA_CHANNEL_POSITION_SIDE_RIGHT] = SND_MIXER_SCHN_SIDE_RIGHT,

    [PA_CHANNEL_POSITION_AUX0] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX1] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX2] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX3] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX4] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX5] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX6] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX7] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX8] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX9] =  SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX10] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX11] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX12] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX13] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX14] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX15] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX16] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX17] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX18] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX19] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX20] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX21] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX22] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX23] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX24] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX25] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX26] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX27] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX28] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX29] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX30] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_AUX31] = SND_MIXER_SCHN_UNKNOWN,

    [PA_CHANNEL_POSITION_TOP_CENTER] = SND_MIXER_SCHN_UNKNOWN,

    [PA_CHANNEL_POSITION_TOP_FRONT_CENTER] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_TOP_FRONT_LEFT] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_TOP_FRONT_RIGHT] = SND_MIXER_SCHN_UNKNOWN,

    [PA_CHANNEL_POSITION_TOP_REAR_CENTER] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_TOP_REAR_LEFT] = SND_MIXER_SCHN_UNKNOWN,
    [PA_CHANNEL_POSITION_TOP_REAR_RIGHT] = SND_MIXER_SCHN_UNKNOWN
};

static snd_mixer_selem_channel_id_t alsa_channel_positions[POSITION_MASK_CHANNELS] = {
    SND_MIXER_SCHN_FRONT_LEFT,
    SND_MIXER_SCHN_FRONT_RIGHT,
    SND_MIXER_SCHN_REAR_LEFT,
    SND_MIXER_SCHN_REAR_RIGHT,
    SND_MIXER_SCHN_FRONT_CENTER,
    SND_MIXER_SCHN_WOOFER,
    SND_MIXER_SCHN_SIDE_LEFT,
    SND_MIXER_SCHN_SIDE_RIGHT,
#if POSITION_MASK_CHANNELS > 8
#error "Extend alsa_channel_positions[] array (9+)"
#endif
};

static void setting_free(pa_alsa_setting *s) {
    pa_assert(s);

    if (s->options)
        pa_idxset_free(s->options, NULL);

    pa_xfree(s->name);
    pa_xfree(s->description);
    pa_xfree(s);
}

static void option_free(pa_alsa_option *o) {
    pa_assert(o);

    pa_xfree(o->alsa_name);
    pa_xfree(o->name);
    pa_xfree(o->description);
    pa_xfree(o);
}

static void decibel_fix_free(pa_alsa_decibel_fix *db_fix) {
    pa_assert(db_fix);

    pa_xfree(db_fix->name);
    pa_xfree(db_fix->db_values);

    pa_xfree(db_fix->key);
    pa_xfree(db_fix);
}

static void element_free(pa_alsa_element *e) {
    pa_alsa_option *o;
    pa_assert(e);

    while ((o = e->options)) {
        PA_LLIST_REMOVE(pa_alsa_option, e->options, o);
        option_free(o);
    }

    if (e->db_fix)
        decibel_fix_free(e->db_fix);

    pa_xfree(e->alsa_id.name);
    pa_xfree(e);
}

void pa_alsa_path_free(pa_alsa_path *p) {
    pa_alsa_jack *j;
    pa_alsa_element *e;
    pa_alsa_setting *s;

    pa_assert(p);

    while ((j = p->jacks)) {
        PA_LLIST_REMOVE(pa_alsa_jack, p->jacks, j);
        pa_alsa_jack_free(j);
    }

    while ((e = p->elements)) {
        PA_LLIST_REMOVE(pa_alsa_element, p->elements, e);
        element_free(e);
    }

    while ((s = p->settings)) {
        PA_LLIST_REMOVE(pa_alsa_setting, p->settings, s);
        setting_free(s);
    }

    pa_proplist_free(p->proplist);
    pa_xfree(p->availability_group);
    pa_xfree(p->name);
    pa_xfree(p->description);
    pa_xfree(p->description_key);
    pa_xfree(p);
}

void pa_alsa_path_set_free(pa_alsa_path_set *ps) {
    pa_assert(ps);

    if (ps->paths)
        pa_hashmap_free(ps->paths);

    pa_xfree(ps);
}

int pa_alsa_path_set_is_empty(pa_alsa_path_set *ps) {
    if (ps && !pa_hashmap_isempty(ps->paths))
        return 0;
    return 1;
}

static long to_alsa_dB(pa_volume_t v) {
    return lround(pa_sw_volume_to_dB(v) * 100.0);
}

static pa_volume_t from_alsa_dB(long v) {
    return pa_sw_volume_from_dB((double) v / 100.0);
}

static long to_alsa_volume(pa_volume_t v, long min, long max) {
    long w;

    w = (long) round(((double) v * (double) (max - min)) / PA_VOLUME_NORM) + min;
    return PA_CLAMP_UNLIKELY(w, min, max);
}

static pa_volume_t from_alsa_volume(long v, long min, long max) {
    return (pa_volume_t) round(((double) (v - min) * PA_VOLUME_NORM) / (double) (max - min));
}

#define SELEM_INIT(sid, aid)                                     \
    do {                                                     \
        snd_mixer_selem_id_alloca(&(sid));                   \
        snd_mixer_selem_id_set_name((sid), (aid)->name);     \
        snd_mixer_selem_id_set_index((sid), (aid)->index);   \
    } while(false)

static int element_get_volume(pa_alsa_element *e, snd_mixer_t *m, const pa_channel_map *cm, pa_cvolume *v) {
    snd_mixer_selem_id_t *sid;
    snd_mixer_elem_t *me;
    snd_mixer_selem_channel_id_t c;
    pa_channel_position_mask_t mask = 0;
    char buf[64];
    unsigned k;

    pa_assert(m);
    pa_assert(e);
    pa_assert(cm);
    pa_assert(v);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    pa_cvolume_mute(v, cm->channels);

    /* We take the highest volume of all channels that match */

    for (c = 0; c <= SND_MIXER_SCHN_LAST; c++) {
        int r;
        pa_volume_t f;

        if (e->has_dB) {
            long value = 0;

            if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
                if (snd_mixer_selem_has_playback_channel(me, c)) {
                    if (e->db_fix) {
                        if ((r = snd_mixer_selem_get_playback_volume(me, c, &value)) >= 0) {
                            /* If the channel volume is outside the limits set
                             * by the dB fix, we clamp the hw volume to be
                             * within the limits. */
                            if (value < e->db_fix->min_step) {
                                value = e->db_fix->min_step;
                                snd_mixer_selem_set_playback_volume(me, c, value);
                                pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
                                pa_log_debug("Playback volume for element %s channel %i was below the dB fix limit. "
                                             "Volume reset to %0.2f dB.", buf, c,
                                             e->db_fix->db_values[value - e->db_fix->min_step] / 100.0);
                            } else if (value > e->db_fix->max_step) {
                                value = e->db_fix->max_step;
                                snd_mixer_selem_set_playback_volume(me, c, value);
                                pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
                                pa_log_debug("Playback volume for element %s channel %i was over the dB fix limit. "
                                             "Volume reset to %0.2f dB.", buf, c,
                                             e->db_fix->db_values[value - e->db_fix->min_step] / 100.0);
                            }

                            /* Volume step -> dB value conversion. */
                            value = e->db_fix->db_values[value - e->db_fix->min_step];
                        }
                    } else
                        r = snd_mixer_selem_get_playback_dB(me, c, &value);
                } else
                    r = -1;
            } else {
                if (snd_mixer_selem_has_capture_channel(me, c)) {
                    if (e->db_fix) {
                        if ((r = snd_mixer_selem_get_capture_volume(me, c, &value)) >= 0) {
                            /* If the channel volume is outside the limits set
                             * by the dB fix, we clamp the hw volume to be
                             * within the limits. */
                            if (value < e->db_fix->min_step) {
                                value = e->db_fix->min_step;
                                snd_mixer_selem_set_capture_volume(me, c, value);
                                pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
                                pa_log_debug("Capture volume for element %s channel %i was below the dB fix limit. "
                                             "Volume reset to %0.2f dB.", buf, c,
                                             e->db_fix->db_values[value - e->db_fix->min_step] / 100.0);
                            } else if (value > e->db_fix->max_step) {
                                value = e->db_fix->max_step;
                                snd_mixer_selem_set_capture_volume(me, c, value);
                                pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
                                pa_log_debug("Capture volume for element %s channel %i was over the dB fix limit. "
                                             "Volume reset to %0.2f dB.", buf, c,
                                             e->db_fix->db_values[value - e->db_fix->min_step] / 100.0);
                            }

                            /* Volume step -> dB value conversion. */
                            value = e->db_fix->db_values[value - e->db_fix->min_step];
                        }
                    } else
                        r = snd_mixer_selem_get_capture_dB(me, c, &value);
                } else
                    r = -1;
            }

            if (r < 0)
                continue;

#ifdef HAVE_VALGRIND_MEMCHECK_H
                VALGRIND_MAKE_MEM_DEFINED(&value, sizeof(value));
#endif

            f = from_alsa_dB(value);

        } else {
            long value = 0;

            if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
                if (snd_mixer_selem_has_playback_channel(me, c))
                    r = snd_mixer_selem_get_playback_volume(me, c, &value);
                else
                    r = -1;
            } else {
                if (snd_mixer_selem_has_capture_channel(me, c))
                    r = snd_mixer_selem_get_capture_volume(me, c, &value);
                else
                    r = -1;
            }

            if (r < 0)
                continue;

            f = from_alsa_volume(value, e->min_volume, e->max_volume);
        }

        for (k = 0; k < cm->channels; k++)
            if (e->masks[c][e->n_channels-1] & PA_CHANNEL_POSITION_MASK(cm->map[k]))
                if (v->values[k] < f)
                    v->values[k] = f;

        mask |= e->masks[c][e->n_channels-1];
    }

    for (k = 0; k < cm->channels; k++)
        if (!(mask & PA_CHANNEL_POSITION_MASK(cm->map[k])))
            v->values[k] = PA_VOLUME_NORM;

    return 0;
}

int pa_alsa_path_get_volume(pa_alsa_path *p, snd_mixer_t *m, const pa_channel_map *cm, pa_cvolume *v) {
    pa_alsa_element *e;

    pa_assert(m);
    pa_assert(p);
    pa_assert(cm);
    pa_assert(v);

    if (!p->has_volume)
        return -1;

    pa_cvolume_reset(v, cm->channels);

    PA_LLIST_FOREACH(e, p->elements) {
        pa_cvolume ev;

        if (e->volume_use != PA_ALSA_VOLUME_MERGE)
            continue;

        pa_assert(!p->has_dB || e->has_dB);

        if (element_get_volume(e, m, cm, &ev) < 0)
            return -1;

        /* If we have no dB information all we can do is take the first element and leave */
        if (!p->has_dB) {
            *v = ev;
            return 0;
        }

        pa_sw_cvolume_multiply(v, v, &ev);
    }

    return 0;
}

static int element_get_switch(pa_alsa_element *e, snd_mixer_t *m, bool *b) {
    snd_mixer_selem_id_t *sid;
    snd_mixer_elem_t *me;
    snd_mixer_selem_channel_id_t c;
    char buf[64];

    pa_assert(m);
    pa_assert(e);
    pa_assert(b);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    /* We return muted if at least one channel is muted */

    for (c = 0; c <= SND_MIXER_SCHN_LAST; c++) {
        int r;
        int value = 0;

        if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
            if (snd_mixer_selem_has_playback_channel(me, c))
                r = snd_mixer_selem_get_playback_switch(me, c, &value);
            else
                r = -1;
        } else {
            if (snd_mixer_selem_has_capture_channel(me, c))
                r = snd_mixer_selem_get_capture_switch(me, c, &value);
            else
                r = -1;
        }

        if (r < 0)
            continue;

        if (!value) {
            *b = false;
            return 0;
        }
    }

    *b = true;
    return 0;
}

int pa_alsa_path_get_mute(pa_alsa_path *p, snd_mixer_t *m, bool *muted) {
    pa_alsa_element *e;

    pa_assert(m);
    pa_assert(p);
    pa_assert(muted);

    if (!p->has_mute)
        return -1;

    PA_LLIST_FOREACH(e, p->elements) {
        bool b;

        if (e->switch_use != PA_ALSA_SWITCH_MUTE)
            continue;

        if (element_get_switch(e, m, &b) < 0)
            return -1;

        if (!b) {
            *muted = true;
            return 0;
        }
    }

    *muted = false;
    return 0;
}

/* Finds the closest item in db_fix->db_values and returns the corresponding
 * step. *db_value is replaced with the value from the db_values table.
 * Rounding is done based on the rounding parameter: -1 means rounding down and
 * +1 means rounding up. */
static long decibel_fix_get_step(pa_alsa_decibel_fix *db_fix, long *db_value, int rounding) {
    unsigned i = 0;
    unsigned max_i = 0;

    pa_assert(db_fix);
    pa_assert(db_value);
    pa_assert(rounding != 0);

    max_i = db_fix->max_step - db_fix->min_step;

    if (rounding > 0) {
        for (i = 0; i < max_i; i++) {
            if (db_fix->db_values[i] >= *db_value)
                break;
        }
    } else {
        for (i = 0; i < max_i; i++) {
            if (db_fix->db_values[i + 1] > *db_value)
                break;
        }
    }

    *db_value = db_fix->db_values[i];

    return i + db_fix->min_step;
}

/* Alsa lib documentation says for snd_mixer_selem_set_playback_dB() direction argument,
 * that "-1 = accurate or first below, 0 = accurate, 1 = accurate or first above".
 * But even with accurate nearest dB volume step is not selected, so that is why we need
 * this function. Returns 0 and nearest selectable volume in *value_dB on success or
 * negative error code if fails. */
static int element_get_nearest_alsa_dB(snd_mixer_elem_t *me, snd_mixer_selem_channel_id_t c, pa_alsa_direction_t d, long *value_dB) {

    long alsa_val;
    long value_high;
    long value_low;
    int r = -1;

    pa_assert(me);
    pa_assert(value_dB);

    if (d == PA_ALSA_DIRECTION_OUTPUT) {
        if ((r = snd_mixer_selem_ask_playback_dB_vol(me, *value_dB, +1, &alsa_val)) >= 0)
            r = snd_mixer_selem_ask_playback_vol_dB(me, alsa_val, &value_high);

        if (r < 0)
            return r;

        if (value_high == *value_dB)
            return r;

        if ((r = snd_mixer_selem_ask_playback_dB_vol(me, *value_dB, -1, &alsa_val)) >= 0)
            r = snd_mixer_selem_ask_playback_vol_dB(me, alsa_val, &value_low);
    } else {
        if ((r = snd_mixer_selem_ask_capture_dB_vol(me, *value_dB, +1, &alsa_val)) >= 0)
            r = snd_mixer_selem_ask_capture_vol_dB(me, alsa_val, &value_high);

        if (r < 0)
            return r;

        if (value_high == *value_dB)
            return r;

        if ((r = snd_mixer_selem_ask_capture_dB_vol(me, *value_dB, -1, &alsa_val)) >= 0)
            r = snd_mixer_selem_ask_capture_vol_dB(me, alsa_val, &value_low);
    }

    if (r < 0)
        return r;

    if (labs(value_high - *value_dB) < labs(value_low - *value_dB))
        *value_dB = value_high;
    else
        *value_dB = value_low;

    return r;
}

static int element_set_volume(pa_alsa_element *e, snd_mixer_t *m, const pa_channel_map *cm, pa_cvolume *v, bool deferred_volume, bool write_to_hw) {

    snd_mixer_selem_id_t *sid;
    pa_cvolume rv;
    snd_mixer_elem_t *me;
    snd_mixer_selem_channel_id_t c;
    pa_channel_position_mask_t mask = 0;
    char buf[64];
    unsigned k;

    pa_assert(m);
    pa_assert(e);
    pa_assert(cm);
    pa_assert(v);
    pa_assert(pa_cvolume_compatible_with_channel_map(v, cm));

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    pa_cvolume_mute(&rv, cm->channels);

    for (c = 0; c <= SND_MIXER_SCHN_LAST; c++) {
        int r;
        pa_volume_t f = PA_VOLUME_MUTED;
        bool found = false;

        for (k = 0; k < cm->channels; k++)
            if (e->masks[c][e->n_channels-1] & PA_CHANNEL_POSITION_MASK(cm->map[k])) {
                found = true;
                if (v->values[k] > f)
                    f = v->values[k];
            }

        if (!found) {
            /* Hmm, so this channel does not exist in the volume
             * struct, so let's bind it to the overall max of the
             * volume. */
            f = pa_cvolume_max(v);
        }

        if (e->has_dB) {
            long value = to_alsa_dB(f);
            int rounding;

            if (e->volume_limit >= 0 && value > (e->max_dB * 100))
                value = e->max_dB * 100;

            if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
                /* If we call set_playback_volume() without checking first
                 * if the channel is available, ALSA behaves very
                 * strangely and doesn't fail the call */
                if (snd_mixer_selem_has_playback_channel(me, c)) {
                    rounding = +1;
                    if (e->db_fix) {
                        if (write_to_hw)
                            r = snd_mixer_selem_set_playback_volume(me, c, decibel_fix_get_step(e->db_fix, &value, rounding));
                        else {
                            decibel_fix_get_step(e->db_fix, &value, rounding);
                            r = 0;
                        }

                    } else {
                        if (write_to_hw) {
                            if (deferred_volume) {
                                if ((r = element_get_nearest_alsa_dB(me, c, PA_ALSA_DIRECTION_OUTPUT, &value)) >= 0)
                                    r = snd_mixer_selem_set_playback_dB(me, c, value, 0);
                            } else {
                                if ((r = snd_mixer_selem_set_playback_dB(me, c, value, rounding)) >= 0)
                                    r = snd_mixer_selem_get_playback_dB(me, c, &value);
                           }
                        } else {
                            long alsa_val;
                            if ((r = snd_mixer_selem_ask_playback_dB_vol(me, value, rounding, &alsa_val)) >= 0)
                                r = snd_mixer_selem_ask_playback_vol_dB(me, alsa_val, &value);
                        }
                    }
                } else
                    r = -1;
            } else {
                if (snd_mixer_selem_has_capture_channel(me, c)) {
                    rounding = -1;
                    if (e->db_fix) {
                        if (write_to_hw)
                            r = snd_mixer_selem_set_capture_volume(me, c, decibel_fix_get_step(e->db_fix, &value, rounding));
                        else {
                            decibel_fix_get_step(e->db_fix, &value, rounding);
                            r = 0;
                        }

                    } else {
                        if (write_to_hw) {
                            if (deferred_volume) {
                                if ((r = element_get_nearest_alsa_dB(me, c, PA_ALSA_DIRECTION_INPUT, &value)) >= 0)
                                    r = snd_mixer_selem_set_capture_dB(me, c, value, 0);
                            } else {
                                if ((r = snd_mixer_selem_set_capture_dB(me, c, value, rounding)) >= 0)
                                    r = snd_mixer_selem_get_capture_dB(me, c, &value);
                            }
                        } else {
                            long alsa_val;
                            if ((r = snd_mixer_selem_ask_capture_dB_vol(me, value, rounding, &alsa_val)) >= 0)
                                r = snd_mixer_selem_ask_capture_vol_dB(me, alsa_val, &value);
                        }
                    }
                } else
                    r = -1;
            }

            if (r < 0)
                continue;

            f = from_alsa_dB(value);

        } else {
            long value;

            value = to_alsa_volume(f, e->min_volume, e->max_volume);

            if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
                if (snd_mixer_selem_has_playback_channel(me, c)) {
                    if ((r = snd_mixer_selem_set_playback_volume(me, c, value)) >= 0)
                        r = snd_mixer_selem_get_playback_volume(me, c, &value);
                } else
                    r = -1;
            } else {
                if (snd_mixer_selem_has_capture_channel(me, c)) {
                    if ((r = snd_mixer_selem_set_capture_volume(me, c, value)) >= 0)
                        r = snd_mixer_selem_get_capture_volume(me, c, &value);
                } else
                    r = -1;
            }

            if (r < 0)
                continue;

            f = from_alsa_volume(value, e->min_volume, e->max_volume);
        }

        for (k = 0; k < cm->channels; k++)
            if (e->masks[c][e->n_channels-1] & PA_CHANNEL_POSITION_MASK(cm->map[k]))
                if (rv.values[k] < f)
                    rv.values[k] = f;

        mask |= e->masks[c][e->n_channels-1];
    }

    for (k = 0; k < cm->channels; k++)
        if (!(mask & PA_CHANNEL_POSITION_MASK(cm->map[k])))
            rv.values[k] = PA_VOLUME_NORM;

    *v = rv;
    return 0;
}

int pa_alsa_path_set_volume(pa_alsa_path *p, snd_mixer_t *m, const pa_channel_map *cm, pa_cvolume *v, bool deferred_volume, bool write_to_hw) {

    pa_alsa_element *e;
    pa_cvolume rv;

    pa_assert(m);
    pa_assert(p);
    pa_assert(cm);
    pa_assert(v);
    pa_assert(pa_cvolume_compatible_with_channel_map(v, cm));

    if (!p->has_volume)
        return -1;

    rv = *v; /* Remaining adjustment */
    pa_cvolume_reset(v, cm->channels); /* Adjustment done */

    PA_LLIST_FOREACH(e, p->elements) {
        pa_cvolume ev;

        if (e->volume_use != PA_ALSA_VOLUME_MERGE)
            continue;

        pa_assert(!p->has_dB || e->has_dB);

        ev = rv;
        if (element_set_volume(e, m, cm, &ev, deferred_volume, write_to_hw) < 0)
            return -1;

        if (!p->has_dB) {
            *v = ev;
            return 0;
        }

        pa_sw_cvolume_multiply(v, v, &ev);
        pa_sw_cvolume_divide(&rv, &rv, &ev);
    }

    return 0;
}

static int element_set_switch(pa_alsa_element *e, snd_mixer_t *m, bool b) {
    snd_mixer_elem_t *me;
    snd_mixer_selem_id_t *sid;
    char buf[64];
    int r;

    pa_assert(m);
    pa_assert(e);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
        r = snd_mixer_selem_set_playback_switch_all(me, b);
    else
        r = snd_mixer_selem_set_capture_switch_all(me, b);

    if (r < 0) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Failed to set switch of %s: %s", buf, pa_alsa_strerror(errno));
    }

    return r;
}

int pa_alsa_path_set_mute(pa_alsa_path *p, snd_mixer_t *m, bool muted) {
    pa_alsa_element *e;

    pa_assert(m);
    pa_assert(p);

    if (!p->has_mute)
        return -1;

    PA_LLIST_FOREACH(e, p->elements) {

        if (e->switch_use != PA_ALSA_SWITCH_MUTE)
            continue;

        if (element_set_switch(e, m, !muted) < 0)
            return -1;
    }

    return 0;
}

/* Depending on whether e->volume_use is _OFF, _ZERO or _CONSTANT, this
 * function sets all channels of the volume element to e->min_volume, 0 dB or
 * e->constant_volume. */
static int element_set_constant_volume(pa_alsa_element *e, snd_mixer_t *m) {
    snd_mixer_elem_t *me = NULL;
    snd_mixer_selem_id_t *sid = NULL;
    int r = 0;
    long volume = -1;
    bool volume_set = false;
    char buf[64];

    pa_assert(m);
    pa_assert(e);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    switch (e->volume_use) {
        case PA_ALSA_VOLUME_OFF:
            volume = e->min_volume;
            volume_set = true;
            break;

        case PA_ALSA_VOLUME_ZERO:
            if (e->db_fix) {
                long dB = 0;

                volume = decibel_fix_get_step(e->db_fix, &dB, (e->direction == PA_ALSA_DIRECTION_OUTPUT ? +1 : -1));
                volume_set = true;
            }
            break;

        case PA_ALSA_VOLUME_CONSTANT:
            volume = e->constant_volume;
            volume_set = true;
            break;

        default:
            pa_assert_not_reached();
    }

    if (volume_set) {
        if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
            r = snd_mixer_selem_set_playback_volume_all(me, volume);
        else
            r = snd_mixer_selem_set_capture_volume_all(me, volume);
    } else {
        pa_assert(e->volume_use == PA_ALSA_VOLUME_ZERO);
        pa_assert(!e->db_fix);

        if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
            r = snd_mixer_selem_set_playback_dB_all(me, 0, +1);
        else
            r = snd_mixer_selem_set_capture_dB_all(me, 0, -1);
    }

    if (r < 0) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Failed to set volume of %s: %s", buf, pa_alsa_strerror(errno));
    }

    return r;
}

int pa_alsa_path_select(pa_alsa_path *p, pa_alsa_setting *s, snd_mixer_t *m, bool device_is_muted) {
    pa_alsa_element *e;
    int r = 0;

    pa_assert(m);
    pa_assert(p);

    pa_log_info("Activating path %s", p->name);
    pa_alsa_path_dump(p);

    /* First turn on hw mute if available, to avoid noise
     * when setting the mixer controls. */
    if (p->mute_during_activation) {
        PA_LLIST_FOREACH(e, p->elements) {
            if (e->switch_use == PA_ALSA_SWITCH_MUTE)
                /* If the muting fails here, that's not a critical problem for
                 * selecting a path, so we ignore the return value.
                 * element_set_switch() will print a warning anyway, so this
                 * won't be a silent failure either. */
                (void) element_set_switch(e, m, false);
        }
    }

    PA_LLIST_FOREACH(e, p->elements) {

        switch (e->switch_use) {
            case PA_ALSA_SWITCH_OFF:
                r = element_set_switch(e, m, false);
                break;

            case PA_ALSA_SWITCH_ON:
                r = element_set_switch(e, m, true);
                break;

            case PA_ALSA_SWITCH_MUTE:
            case PA_ALSA_SWITCH_IGNORE:
            case PA_ALSA_SWITCH_SELECT:
                r = 0;
                break;
        }

        if (r < 0)
            return -1;

        switch (e->volume_use) {
            case PA_ALSA_VOLUME_OFF:
            case PA_ALSA_VOLUME_ZERO:
            case PA_ALSA_VOLUME_CONSTANT:
                r = element_set_constant_volume(e, m);
                break;

            case PA_ALSA_VOLUME_MERGE:
            case PA_ALSA_VOLUME_IGNORE:
                r = 0;
                break;
        }

        if (r < 0)
            return -1;
    }

    if (s)
        setting_select(s, m);

    /* Finally restore hw mute to the device mute status. */
    if (p->mute_during_activation) {
        PA_LLIST_FOREACH(e, p->elements) {
            if (e->switch_use == PA_ALSA_SWITCH_MUTE) {
                if (element_set_switch(e, m, !device_is_muted) < 0)
                    return -1;
            }
        }
    }

    return 0;
}

static int check_required(pa_alsa_element *e, snd_mixer_elem_t *me) {
    bool has_switch;
    bool has_enumeration;
    bool has_volume;

    pa_assert(e);
    pa_assert(me);

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
        has_switch =
            snd_mixer_selem_has_playback_switch(me) ||
            (e->direction_try_other && snd_mixer_selem_has_capture_switch(me));
    } else {
        has_switch =
            snd_mixer_selem_has_capture_switch(me) ||
            (e->direction_try_other && snd_mixer_selem_has_playback_switch(me));
    }

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
        has_volume =
            snd_mixer_selem_has_playback_volume(me) ||
            (e->direction_try_other && snd_mixer_selem_has_capture_volume(me));
    } else {
        has_volume =
            snd_mixer_selem_has_capture_volume(me) ||
            (e->direction_try_other && snd_mixer_selem_has_playback_volume(me));
    }

    has_enumeration = snd_mixer_selem_is_enumerated(me);

    if ((e->required == PA_ALSA_REQUIRED_SWITCH && !has_switch) ||
        (e->required == PA_ALSA_REQUIRED_VOLUME && !has_volume) ||
        (e->required == PA_ALSA_REQUIRED_ENUMERATION && !has_enumeration))
        return -1;

    if (e->required == PA_ALSA_REQUIRED_ANY && !(has_switch || has_volume || has_enumeration))
        return -1;

    if ((e->required_absent == PA_ALSA_REQUIRED_SWITCH && has_switch) ||
        (e->required_absent == PA_ALSA_REQUIRED_VOLUME && has_volume) ||
        (e->required_absent == PA_ALSA_REQUIRED_ENUMERATION && has_enumeration))
        return -1;

    if (e->required_absent == PA_ALSA_REQUIRED_ANY && (has_switch || has_volume || has_enumeration))
        return -1;

    if (e->required_any != PA_ALSA_REQUIRED_IGNORE) {
        switch (e->required_any) {
            case PA_ALSA_REQUIRED_VOLUME:
                e->path->req_any_present |= (e->volume_use != PA_ALSA_VOLUME_IGNORE);
                break;
            case PA_ALSA_REQUIRED_SWITCH:
                e->path->req_any_present |= (e->switch_use != PA_ALSA_SWITCH_IGNORE);
                break;
            case PA_ALSA_REQUIRED_ENUMERATION:
                e->path->req_any_present |= (e->enumeration_use != PA_ALSA_ENUMERATION_IGNORE);
                break;
            case PA_ALSA_REQUIRED_ANY:
                e->path->req_any_present |=
                    (e->volume_use != PA_ALSA_VOLUME_IGNORE) ||
                    (e->switch_use != PA_ALSA_SWITCH_IGNORE) ||
                    (e->enumeration_use != PA_ALSA_ENUMERATION_IGNORE);
                break;
            default:
                pa_assert_not_reached();
        }
    }

    if (e->enumeration_use == PA_ALSA_ENUMERATION_SELECT) {
        pa_alsa_option *o;
        PA_LLIST_FOREACH(o, e->options) {
            e->path->req_any_present |= (o->required_any != PA_ALSA_REQUIRED_IGNORE) &&
                (o->alsa_idx >= 0);
            if (o->required != PA_ALSA_REQUIRED_IGNORE && o->alsa_idx < 0)
                return -1;
            if (o->required_absent != PA_ALSA_REQUIRED_IGNORE && o->alsa_idx >= 0)
                return -1;
        }
    }

    return 0;
}

static int element_ask_vol_dB(snd_mixer_elem_t *me, pa_alsa_direction_t dir, long value, long *dBvalue) {
    if (dir == PA_ALSA_DIRECTION_OUTPUT)
        return snd_mixer_selem_ask_playback_vol_dB(me, value, dBvalue);
    else
        return snd_mixer_selem_ask_capture_vol_dB(me, value, dBvalue);
}

static bool element_probe_volume(pa_alsa_element *e, snd_mixer_elem_t *me) {

    long min_dB = 0, max_dB = 0;
    int r;
    bool is_mono;
    pa_channel_position_t p;
    char buf[64];

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {
        if (!snd_mixer_selem_has_playback_volume(me)) {
            if (e->direction_try_other && snd_mixer_selem_has_capture_volume(me))
                e->direction = PA_ALSA_DIRECTION_INPUT;
            else
                return false;
        }
    } else {
        if (!snd_mixer_selem_has_capture_volume(me)) {
            if (e->direction_try_other && snd_mixer_selem_has_playback_volume(me))
                e->direction = PA_ALSA_DIRECTION_OUTPUT;
            else
                return false;
        }
    }

    e->direction_try_other = false;

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
        r = snd_mixer_selem_get_playback_volume_range(me, &e->min_volume, &e->max_volume);
    else
        r = snd_mixer_selem_get_capture_volume_range(me, &e->min_volume, &e->max_volume);

    if (r < 0) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Failed to get volume range of %s: %s", buf, pa_alsa_strerror(r));
        return false;
    }

    if (e->min_volume >= e->max_volume) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Your kernel driver is broken for element %s: it reports a volume range from %li to %li which makes no sense.",
                    buf, e->min_volume, e->max_volume);
        return false;
    }
    if (e->volume_use == PA_ALSA_VOLUME_CONSTANT && (e->min_volume > e->constant_volume || e->max_volume < e->constant_volume)) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Constant volume %li configured for element %s, but the available range is from %li to %li.",
                    e->constant_volume, buf, e->min_volume, e->max_volume);
        return false;
    }


    if (e->db_fix && ((e->min_volume > e->db_fix->min_step) || (e->max_volume < e->db_fix->max_step))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("The step range of the decibel fix for element %s (%li-%li) doesn't fit to the "
                    "real hardware range (%li-%li). Disabling the decibel fix.", buf,
                    e->db_fix->min_step, e->db_fix->max_step, e->min_volume, e->max_volume);

        decibel_fix_free(e->db_fix);
        e->db_fix = NULL;
    }

    if (e->db_fix) {
        e->has_dB = true;
        e->min_volume = e->db_fix->min_step;
        e->max_volume = e->db_fix->max_step;
        min_dB = e->db_fix->db_values[0];
        max_dB = e->db_fix->db_values[e->db_fix->max_step - e->db_fix->min_step];
    } else if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
        e->has_dB = snd_mixer_selem_get_playback_dB_range(me, &min_dB, &max_dB) >= 0;
    else
        e->has_dB = snd_mixer_selem_get_capture_dB_range(me, &min_dB, &max_dB) >= 0;

    /* Assume decibel data to be incorrect if max_dB is negative. */
    if (e->has_dB && max_dB < 0 && !e->db_fix) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("The decibel volume range for element %s (%li dB - %li dB) has negative maximum. "
                    "Disabling the decibel range.", buf, min_dB, max_dB);
        e->has_dB = false;
    }

    /* Check that the kernel driver returns consistent limits with
     * both _get_*_dB_range() and _ask_*_vol_dB(). */
    if (e->has_dB && !e->db_fix) {
        long min_dB_checked = 0;
        long max_dB_checked = 0;

        if (element_ask_vol_dB(me, e->direction, e->min_volume, &min_dB_checked) < 0) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Failed to query the dB value for %s at volume level %li", buf, e->min_volume);
            return false;
        }

        if (element_ask_vol_dB(me, e->direction, e->max_volume, &max_dB_checked) < 0) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Failed to query the dB value for %s at volume level %li", buf, e->max_volume);
            return false;
        }

        if (min_dB != min_dB_checked || max_dB != max_dB_checked) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Your kernel driver is broken: the reported dB range for %s (from %0.2f dB to %0.2f dB) "
                        "doesn't match the dB values at minimum and maximum volume levels: %0.2f dB at level %li, "
                        "%0.2f dB at level %li.", buf, min_dB / 100.0, max_dB / 100.0,
                        min_dB_checked / 100.0, e->min_volume, max_dB_checked / 100.0, e->max_volume);
            return false;
        }
    }

    if (e->has_dB) {
        e->min_dB = ((double) min_dB) / 100.0;
        e->max_dB = ((double) max_dB) / 100.0;

        if (min_dB >= max_dB) {
            pa_assert(!e->db_fix);
            pa_log_warn("Your kernel driver is broken: it reports a volume range from %0.2f dB to %0.2f dB which makes no sense.",
                        e->min_dB, e->max_dB);
            e->has_dB = false;
        }
    }

    if (e->volume_limit >= 0) {
        if (e->volume_limit <= e->min_volume || e->volume_limit > e->max_volume) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Volume limit for element %s of path %s is invalid: %li isn't within the valid range "
                        "%li-%li. The volume limit is ignored.",
                        buf, e->path->name, e->volume_limit, e->min_volume + 1, e->max_volume);
        } else {
            e->max_volume = e->volume_limit;

            if (e->has_dB) {
                if (e->db_fix) {
                    e->db_fix->max_step = e->max_volume;
                    e->max_dB = ((double) e->db_fix->db_values[e->db_fix->max_step - e->db_fix->min_step]) / 100.0;
                } else if (element_ask_vol_dB(me, e->direction, e->max_volume, &max_dB) < 0) {
                    pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
                    pa_log_warn("Failed to get dB value of %s: %s", buf, pa_alsa_strerror(r));
                    e->has_dB = false;
                } else
                    e->max_dB = ((double) max_dB) / 100.0;
            }
        }
    }

    if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
        is_mono = snd_mixer_selem_is_playback_mono(me) > 0;
    else
        is_mono = snd_mixer_selem_is_capture_mono(me) > 0;

    if (is_mono) {
        e->n_channels = 1;

        if ((e->override_map & (1 << (e->n_channels-1))) && e->masks[SND_MIXER_SCHN_MONO][e->n_channels-1] == 0) {
            pa_log_warn("Override map for mono element %s is invalid, ignoring override map", e->path->name);
            e->override_map &= ~(1 << (e->n_channels-1));
        }
        if (!(e->override_map & (1 << (e->n_channels-1)))) {
            for (p = PA_CHANNEL_POSITION_FRONT_LEFT; p < PA_CHANNEL_POSITION_MAX; p++) {
                if (alsa_channel_ids[p] == SND_MIXER_SCHN_UNKNOWN)
                    continue;
                e->masks[alsa_channel_ids[p]][e->n_channels-1] = 0;
            }
            e->masks[SND_MIXER_SCHN_MONO][e->n_channels-1] = PA_CHANNEL_POSITION_MASK_ALL;
        }
        e->merged_mask = e->masks[SND_MIXER_SCHN_MONO][e->n_channels-1];
        return true;
    }

    e->n_channels = 0;
    for (p = PA_CHANNEL_POSITION_FRONT_LEFT; p < PA_CHANNEL_POSITION_MAX; p++) {
        if (alsa_channel_ids[p] == SND_MIXER_SCHN_UNKNOWN)
            continue;

        if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
            e->n_channels += snd_mixer_selem_has_playback_channel(me, alsa_channel_ids[p]) > 0;
        else
            e->n_channels += snd_mixer_selem_has_capture_channel(me, alsa_channel_ids[p]) > 0;
    }

    if (e->n_channels <= 0) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Volume element %s with no channels?", buf);
        return false;
    } else if (e->n_channels > POSITION_MASK_CHANNELS) {
        /* FIXME: In some places code like this is used:
         *
         *     e->masks[alsa_channel_ids[p]][e->n_channels-1]
         *
         * The definition of e->masks is
         *
         *     pa_channel_position_mask_t masks[SND_MIXER_SCHN_LAST + 1][POSITION_MASK_CHANNELS];
         *
         * Since the array size is fixed at POSITION_MASK_CHANNELS, we obviously
         * don't support elements with more than POSITION_MASK_CHANNELS
         * channels... */
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Volume element %s has %u channels. That's too much! I can't handle that!", buf, e->n_channels);
        return false;
    }

retry:
    if (!(e->override_map & (1 << (e->n_channels-1)))) {
        for (p = PA_CHANNEL_POSITION_FRONT_LEFT; p < PA_CHANNEL_POSITION_MAX; p++) {
            bool has_channel;

            if (alsa_channel_ids[p] == SND_MIXER_SCHN_UNKNOWN)
                continue;

            if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
                has_channel = snd_mixer_selem_has_playback_channel(me, alsa_channel_ids[p]) > 0;
            else
                has_channel = snd_mixer_selem_has_capture_channel(me, alsa_channel_ids[p]) > 0;

            e->masks[alsa_channel_ids[p]][e->n_channels-1] = has_channel ? PA_CHANNEL_POSITION_MASK(p) : 0;
        }
    }

    e->merged_mask = 0;
    for (p = PA_CHANNEL_POSITION_FRONT_LEFT; p < PA_CHANNEL_POSITION_MAX; p++) {
        if (alsa_channel_ids[p] == SND_MIXER_SCHN_UNKNOWN)
            continue;

        e->merged_mask |= e->masks[alsa_channel_ids[p]][e->n_channels-1];
    }

    if (e->merged_mask == 0) {
        if (!(e->override_map & (1 << (e->n_channels-1)))) {
            pa_log_warn("Channel map for element %s is invalid", e->path->name);
            return false;
        }
        pa_log_warn("Override map for element %s has empty result, ignoring override map", e->path->name);
        e->override_map &= ~(1 << (e->n_channels-1));
        goto retry;
    }

    return true;
}

static int element_probe(pa_alsa_element *e, snd_mixer_t *m) {
    snd_mixer_selem_id_t *sid;
    snd_mixer_elem_t *me;

    pa_assert(m);
    pa_assert(e);
    pa_assert(e->path);

    SELEM_INIT(sid, &e->alsa_id);

    if (!(me = snd_mixer_find_selem(m, sid))) {

        if (e->required != PA_ALSA_REQUIRED_IGNORE)
            return -1;

        e->switch_use = PA_ALSA_SWITCH_IGNORE;
        e->volume_use = PA_ALSA_VOLUME_IGNORE;
        e->enumeration_use = PA_ALSA_ENUMERATION_IGNORE;

        return 0;
    }

    if (e->switch_use != PA_ALSA_SWITCH_IGNORE) {
        if (e->direction == PA_ALSA_DIRECTION_OUTPUT) {

            if (!snd_mixer_selem_has_playback_switch(me)) {
                if (e->direction_try_other && snd_mixer_selem_has_capture_switch(me))
                    e->direction = PA_ALSA_DIRECTION_INPUT;
                else
                    e->switch_use = PA_ALSA_SWITCH_IGNORE;
            }

        } else {

            if (!snd_mixer_selem_has_capture_switch(me)) {
                if (e->direction_try_other && snd_mixer_selem_has_playback_switch(me))
                    e->direction = PA_ALSA_DIRECTION_OUTPUT;
                else
                    e->switch_use = PA_ALSA_SWITCH_IGNORE;
            }
        }

        if (e->switch_use != PA_ALSA_SWITCH_IGNORE)
            e->direction_try_other = false;
    }

    if (!element_probe_volume(e, me))
        e->volume_use = PA_ALSA_VOLUME_IGNORE;

    if (e->switch_use == PA_ALSA_SWITCH_SELECT) {
        pa_alsa_option *o;

        PA_LLIST_FOREACH(o, e->options)
            o->alsa_idx = pa_streq(o->alsa_name, "on") ? 1 : 0;
    } else if (e->enumeration_use == PA_ALSA_ENUMERATION_SELECT) {
        int n;
        pa_alsa_option *o;

        if ((n = snd_mixer_selem_get_enum_items(me)) < 0) {
            pa_log("snd_mixer_selem_get_enum_items() failed: %s", pa_alsa_strerror(n));
            return -1;
        }

        PA_LLIST_FOREACH(o, e->options) {
            int i;

            for (i = 0; i < n; i++) {
                char buf[128];

                if (snd_mixer_selem_get_enum_item_name(me, i, sizeof(buf), buf) < 0)
                    continue;

                if (!pa_streq(buf, o->alsa_name))
                    continue;

                o->alsa_idx = i;
            }
        }
    }

    if (check_required(e, me) < 0)
        return -1;

    return 0;
}

static int jack_probe(pa_alsa_jack *j, pa_alsa_mapping *mapping, snd_mixer_t *m) {
    bool has_control;

    pa_assert(j);
    pa_assert(j->path);

    if (j->append_pcm_to_name) {
        char *new_name;

        if (!mapping) {
            /* This could also be an assertion, because this should never
             * happen. At the time of writing, mapping can only be NULL when
             * module-alsa-sink/source synthesizes a path, and those
             * synthesized paths never have any jacks, so jack_probe() should
             * never be called with a NULL mapping. */
            pa_log("Jack %s: append_pcm_to_name is set, but mapping is NULL. Can't use this jack.", j->name);
            return -1;
        }

        new_name = pa_sprintf_malloc("%s,pcm=%i Jack", j->name, mapping->hw_device_index);
        pa_xfree(j->alsa_id.name);
        j->alsa_id.name = new_name;
        j->append_pcm_to_name = false;
    }

    has_control = pa_alsa_mixer_find_card(m, &j->alsa_id, 0) != NULL;
    pa_alsa_jack_set_has_control(j, has_control);

    if (j->has_control) {
        if (j->required_absent != PA_ALSA_REQUIRED_IGNORE)
            return -1;
        if (j->required_any != PA_ALSA_REQUIRED_IGNORE)
            j->path->req_any_present = true;
    } else {
        if (j->required != PA_ALSA_REQUIRED_IGNORE)
            return -1;
    }

    return 0;
}

pa_alsa_element * pa_alsa_element_get(pa_alsa_path *p, const char *section, bool prefixed) {
    pa_alsa_element *e;
    char *name;
    int index;

    pa_assert(p);
    pa_assert(section);

    if (prefixed) {
        if (!pa_startswith(section, "Element "))
            return NULL;

        section += 8;
    }

    /* This is not an element section, but an enum section? */
    if (strchr(section, ':'))
        return NULL;

    name = alloca(strlen(section) + 1);
    if (alsa_id_decode(section, name, &index))
        return NULL;

    if (p->last_element && pa_streq(p->last_element->alsa_id.name, name) &&
        p->last_element->alsa_id.index == index)
        return p->last_element;

    PA_LLIST_FOREACH(e, p->elements)
        if (pa_streq(e->alsa_id.name, name) && e->alsa_id.index == index)
            goto finish;

    e = pa_xnew0(pa_alsa_element, 1);
    e->path = p;
    e->alsa_id.name = pa_xstrdup(name);
    e->alsa_id.index = index;
    e->direction = p->direction;
    e->volume_limit = -1;

    PA_LLIST_INSERT_AFTER(pa_alsa_element, p->elements, p->last_element, e);

finish:
    p->last_element = e;
    return e;
}

static pa_alsa_jack* jack_get(pa_alsa_path *p, const char *section) {
    pa_alsa_jack *j;
    char *name;
    int index;

    if (!pa_startswith(section, "Jack "))
        return NULL;
    section += 5;

    name = alloca(strlen(section) + 1);
    if (alsa_id_decode(section, name, &index))
        return NULL;

    if (p->last_jack && pa_streq(p->last_jack->name, name) &&
        p->last_jack->alsa_id.index == index)
        return p->last_jack;

    PA_LLIST_FOREACH(j, p->jacks)
        if (pa_streq(j->name, name) && j->alsa_id.index == index)
            goto finish;

    j = pa_alsa_jack_new(p, NULL, name, index);
    PA_LLIST_INSERT_AFTER(pa_alsa_jack, p->jacks, p->last_jack, j);

finish:
    p->last_jack = j;
    return j;
}

static pa_alsa_option* option_get(pa_alsa_path *p, const char *section) {
    char *en, *name;
    const char *on;
    pa_alsa_option *o;
    pa_alsa_element *e;
    size_t len;
    int index;

    if (!pa_startswith(section, "Option "))
        return NULL;

    section += 7;

    /* This is not an enum section, but an element section? */
    if (!(on = strchr(section, ':')))
        return NULL;

    len = on - section;
    en = alloca(len + 1);
    strncpy(en, section, len);
    en[len] = '\0';

    name = alloca(strlen(en) + 1);
    if (alsa_id_decode(en, name, &index))
        return NULL;

    on++;

    if (p->last_option &&
        pa_streq(p->last_option->element->alsa_id.name, name) &&
        p->last_option->element->alsa_id.index == index &&
        pa_streq(p->last_option->alsa_name, on)) {
        return p->last_option;
    }

    pa_assert_se(e = pa_alsa_element_get(p, en, false));

    PA_LLIST_FOREACH(o, e->options)
        if (pa_streq(o->alsa_name, on))
            goto finish;

    o = pa_xnew0(pa_alsa_option, 1);
    o->element = e;
    o->alsa_name = pa_xstrdup(on);
    o->alsa_idx = -1;

    if (p->last_option && p->last_option->element == e)
        PA_LLIST_INSERT_AFTER(pa_alsa_option, e->options, p->last_option, o);
    else
        PA_LLIST_PREPEND(pa_alsa_option, e->options, o);

finish:
    p->last_option = o;
    return o;
}

static int element_parse_switch(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Switch makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "ignore"))
        e->switch_use = PA_ALSA_SWITCH_IGNORE;
    else if (pa_streq(state->rvalue, "mute"))
        e->switch_use = PA_ALSA_SWITCH_MUTE;
    else if (pa_streq(state->rvalue, "off"))
        e->switch_use = PA_ALSA_SWITCH_OFF;
    else if (pa_streq(state->rvalue, "on"))
        e->switch_use = PA_ALSA_SWITCH_ON;
    else if (pa_streq(state->rvalue, "select"))
        e->switch_use = PA_ALSA_SWITCH_SELECT;
    else {
        pa_log("[%s:%u] Switch invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int element_parse_volume(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Volume makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "ignore"))
        e->volume_use = PA_ALSA_VOLUME_IGNORE;
    else if (pa_streq(state->rvalue, "merge"))
        e->volume_use = PA_ALSA_VOLUME_MERGE;
    else if (pa_streq(state->rvalue, "off"))
        e->volume_use = PA_ALSA_VOLUME_OFF;
    else if (pa_streq(state->rvalue, "zero"))
        e->volume_use = PA_ALSA_VOLUME_ZERO;
    else {
        uint32_t constant;

        if (pa_atou(state->rvalue, &constant) >= 0) {
            e->volume_use = PA_ALSA_VOLUME_CONSTANT;
            e->constant_volume = constant;
        } else {
            pa_log("[%s:%u] Volume invalid of '%s'", state->filename, state->lineno, state->section);
            return -1;
        }
    }

    return 0;
}

static int element_parse_enumeration(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Enumeration makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "ignore"))
        e->enumeration_use = PA_ALSA_ENUMERATION_IGNORE;
    else if (pa_streq(state->rvalue, "select"))
        e->enumeration_use = PA_ALSA_ENUMERATION_SELECT;
    else {
        pa_log("[%s:%u] Enumeration invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int parse_type(pa_config_parser_state *state) {
    struct device_port_types {
        const char *name;
        pa_device_port_type_t type;
    } device_port_types[] = {
        { "unknown",      PA_DEVICE_PORT_TYPE_UNKNOWN },
        { "aux",          PA_DEVICE_PORT_TYPE_AUX },
        { "speaker",      PA_DEVICE_PORT_TYPE_SPEAKER },
        { "headphones",   PA_DEVICE_PORT_TYPE_HEADPHONES },
        { "line",         PA_DEVICE_PORT_TYPE_LINE },
        { "mic",          PA_DEVICE_PORT_TYPE_MIC },
        { "headset",      PA_DEVICE_PORT_TYPE_HEADSET },
        { "handset",      PA_DEVICE_PORT_TYPE_HANDSET },
        { "earpiece",     PA_DEVICE_PORT_TYPE_EARPIECE },
        { "spdif",        PA_DEVICE_PORT_TYPE_SPDIF },
        { "hdmi",         PA_DEVICE_PORT_TYPE_HDMI },
        { "tv",           PA_DEVICE_PORT_TYPE_TV },
        { "radio",        PA_DEVICE_PORT_TYPE_RADIO },
        { "video",        PA_DEVICE_PORT_TYPE_VIDEO },
        { "usb",          PA_DEVICE_PORT_TYPE_USB },
        { "bluetooth",    PA_DEVICE_PORT_TYPE_BLUETOOTH },
        { "portable",     PA_DEVICE_PORT_TYPE_PORTABLE },
        { "handsfree",    PA_DEVICE_PORT_TYPE_HANDSFREE },
        { "car",          PA_DEVICE_PORT_TYPE_CAR },
        { "hifi",         PA_DEVICE_PORT_TYPE_HIFI },
        { "phone",        PA_DEVICE_PORT_TYPE_PHONE },
        { "network",      PA_DEVICE_PORT_TYPE_NETWORK },
        { "analog",       PA_DEVICE_PORT_TYPE_ANALOG },
    };
    pa_alsa_path *path;
    unsigned int idx;

    path = state->userdata;

    for (idx = 0; idx < PA_ELEMENTSOF(device_port_types); idx++)
        if (pa_streq(state->rvalue, device_port_types[idx].name)) {
            path->device_port_type = device_port_types[idx].type;
            return 0;
        }

    pa_log("[%s:%u] Invalid value for option 'type': %s", state->filename, state->lineno, state->rvalue);
    return -1;
}

static int parse_eld_device(pa_config_parser_state *state) {
    pa_alsa_path *path;
    uint32_t eld_device;

    path = state->userdata;

    if (pa_atou(state->rvalue, &eld_device) >= 0) {
        path->autodetect_eld_device = false;
        path->eld_device = eld_device;
        return 0;
    }

    if (pa_streq(state->rvalue, "auto")) {
        path->autodetect_eld_device = true;
        path->eld_device = -1;
        return 0;
    }

    pa_log("[%s:%u] Invalid value for option 'eld-device': %s", state->filename, state->lineno, state->rvalue);
    return -1;
}

static int option_parse_priority(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_option *o;
    uint32_t prio;

    pa_assert(state);

    p = state->userdata;

    if (!(o = option_get(p, state->section))) {
        pa_log("[%s:%u] Priority makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_atou(state->rvalue, &prio) < 0) {
        pa_log("[%s:%u] Priority invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    o->priority = prio;
    return 0;
}

static int option_parse_name(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_option *o;

    pa_assert(state);

    p = state->userdata;

    if (!(o = option_get(p, state->section))) {
        pa_log("[%s:%u] Name makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    pa_xfree(o->name);
    o->name = pa_xstrdup(state->rvalue);

    return 0;
}

static int element_parse_required(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;
    pa_alsa_option *o;
    pa_alsa_jack *j;
    pa_alsa_required_t req;

    pa_assert(state);

    p = state->userdata;

    e = pa_alsa_element_get(p, state->section, true);
    o = option_get(p, state->section);
    j = jack_get(p, state->section);
    if (!e && !o && !j) {
        pa_log("[%s:%u] Required makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "ignore"))
        req = PA_ALSA_REQUIRED_IGNORE;
    else if (pa_streq(state->rvalue, "switch") && e)
        req = PA_ALSA_REQUIRED_SWITCH;
    else if (pa_streq(state->rvalue, "volume") && e)
        req = PA_ALSA_REQUIRED_VOLUME;
    else if (pa_streq(state->rvalue, "enumeration"))
        req = PA_ALSA_REQUIRED_ENUMERATION;
    else if (pa_streq(state->rvalue, "any"))
        req = PA_ALSA_REQUIRED_ANY;
    else {
        pa_log("[%s:%u] Required invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->lvalue, "required-absent")) {
        if (e)
            e->required_absent = req;
        if (o)
            o->required_absent = req;
        if (j)
            j->required_absent = req;
    }
    else if (pa_streq(state->lvalue, "required-any")) {
        if (e) {
            e->required_any = req;
            e->path->has_req_any |= (req != PA_ALSA_REQUIRED_IGNORE);
        }
        if (o) {
            o->required_any = req;
            o->element->path->has_req_any |= (req != PA_ALSA_REQUIRED_IGNORE);
        }
        if (j) {
            j->required_any = req;
            j->path->has_req_any |= (req != PA_ALSA_REQUIRED_IGNORE);
        }

    }
    else {
        if (e)
            e->required = req;
        if (o)
            o->required = req;
        if (j)
            j->required = req;
    }

    return 0;
}

static int element_parse_direction(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Direction makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "playback"))
        e->direction = PA_ALSA_DIRECTION_OUTPUT;
    else if (pa_streq(state->rvalue, "capture"))
        e->direction = PA_ALSA_DIRECTION_INPUT;
    else {
        pa_log("[%s:%u] Direction invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int element_parse_direction_try_other(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;
    int yes;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Direction makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if ((yes = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] Direction invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    e->direction_try_other = !!yes;
    return 0;
}

static int element_parse_volume_limit(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;
    long volume_limit;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] volume-limit makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_atol(state->rvalue, &volume_limit) < 0 || volume_limit < 0) {
        pa_log("[%s:%u] Invalid value for volume-limit", state->filename, state->lineno);
        return -1;
    }

    e->volume_limit = volume_limit;
    return 0;
}

static unsigned int parse_channel_position(const char *m)
{
    pa_channel_position_t p;

    if ((p = pa_channel_position_from_string(m)) == PA_CHANNEL_POSITION_INVALID)
        return SND_MIXER_SCHN_UNKNOWN;

    return alsa_channel_ids[p];
}

static pa_channel_position_mask_t parse_mask(const char *m) {
    pa_channel_position_mask_t v;

    if (pa_streq(m, "all-left"))
        v = PA_CHANNEL_POSITION_MASK_LEFT;
    else if (pa_streq(m, "all-right"))
        v = PA_CHANNEL_POSITION_MASK_RIGHT;
    else if (pa_streq(m, "all-center"))
        v = PA_CHANNEL_POSITION_MASK_CENTER;
    else if (pa_streq(m, "all-front"))
        v = PA_CHANNEL_POSITION_MASK_FRONT;
    else if (pa_streq(m, "all-rear"))
        v = PA_CHANNEL_POSITION_MASK_REAR;
    else if (pa_streq(m, "all-side"))
        v = PA_CHANNEL_POSITION_MASK_SIDE_OR_TOP_CENTER;
    else if (pa_streq(m, "all-top"))
        v = PA_CHANNEL_POSITION_MASK_TOP;
    else if (pa_streq(m, "all-no-lfe"))
        v = PA_CHANNEL_POSITION_MASK_ALL ^ PA_CHANNEL_POSITION_MASK(PA_CHANNEL_POSITION_LFE);
    else if (pa_streq(m, "all"))
        v = PA_CHANNEL_POSITION_MASK_ALL;
    else {
        pa_channel_position_t p;

        if ((p = pa_channel_position_from_string(m)) == PA_CHANNEL_POSITION_INVALID)
            return 0;

        v = PA_CHANNEL_POSITION_MASK(p);
    }

    return v;
}

static int element_parse_override_map(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_element *e;
    const char *split_state = NULL;
    char *s;
    unsigned i = 0;
    int channel_count = 0;
    char *n;

    pa_assert(state);

    p = state->userdata;

    if (!(e = pa_alsa_element_get(p, state->section, true))) {
        pa_log("[%s:%u] Override map makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    s = strstr(state->lvalue, ".");
    if (s) {
        pa_atoi(s + 1, &channel_count);
        if (channel_count < 1 || channel_count > POSITION_MASK_CHANNELS) {
            pa_log("[%s:%u] Override map index '%s' invalid in '%s'", state->filename, state->lineno, state->lvalue, state->section);
            return 0;
        }
    } else {
        pa_log("[%s:%u] Invalid override map syntax '%s' in '%s'", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    while ((n = pa_split(state->rvalue, ",", &split_state))) {
        pa_channel_position_mask_t m;
        snd_mixer_selem_channel_id_t channel_position;

        if (i >= (unsigned)channel_count) {
            pa_log("[%s:%u] Invalid override map size (>%d) in '%s'", state->filename, state->lineno, channel_count, state->section);
            return -1;
        }
        channel_position = alsa_channel_positions[i];

        if (!*n)
            m = 0;
        else {
            s = strstr(n, ":");
            if (s) {
                *s = '\0';
                s++;
                channel_position = parse_channel_position(n);
                if (channel_position == SND_MIXER_SCHN_UNKNOWN) {
                    pa_log("[%s:%u] Override map position '%s' invalid in '%s'", state->filename, state->lineno, n, state->section);
                    pa_xfree(n);
                    return -1;
                }
            }
            if ((m = parse_mask(s ? s : n)) == 0) {
                pa_log("[%s:%u] Override map '%s' invalid in '%s'", state->filename, state->lineno, s ? s : n, state->section);
                pa_xfree(n);
                return -1;
            }
        }

        if (e->masks[channel_position][channel_count-1]) {
            pa_log("[%s:%u] Override map '%s' duplicate position '%s' in '%s'", state->filename, state->lineno, s ? s : n, snd_mixer_selem_channel_name(channel_position), state->section);
            pa_xfree(n);
            return -1;
        }
        e->override_map |= (1 << (channel_count - 1));
        e->masks[channel_position][channel_count-1] = m;
        pa_xfree(n);
        i++;
    }

    return 0;
}

static int jack_parse_state(pa_config_parser_state *state) {
    pa_alsa_path *p;
    pa_alsa_jack *j;
    pa_available_t pa;

    pa_assert(state);

    p = state->userdata;

    if (!(j = jack_get(p, state->section))) {
        pa_log("[%s:%u] state makes no sense in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "yes"))
        pa = PA_AVAILABLE_YES;
    else if (pa_streq(state->rvalue, "no"))
        pa = PA_AVAILABLE_NO;
    else if (pa_streq(state->rvalue, "unknown"))
        pa = PA_AVAILABLE_UNKNOWN;
    else {
        pa_log("[%s:%u] state must be 'yes', 'no' or 'unknown' in '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->lvalue, "state.unplugged"))
        j->state_unplugged = pa;
    else {
        j->state_plugged = pa;
        pa_assert(pa_streq(state->lvalue, "state.plugged"));
    }

    return 0;
}

static int jack_parse_append_pcm_to_name(pa_config_parser_state *state) {
    pa_alsa_path *path;
    pa_alsa_jack *jack;
    int b;

    pa_assert(state);

    path = state->userdata;
    if (!(jack = jack_get(path, state->section))) {
        pa_log("[%s:%u] Option 'append_pcm_to_name' not expected in section '%s'",
               state->filename, state->lineno, state->section);
        return -1;
    }

    b = pa_parse_boolean(state->rvalue);
    if (b < 0) {
        pa_log("[%s:%u] Invalid value for 'append_pcm_to_name': %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    jack->append_pcm_to_name = b;
    return 0;
}

static int element_set_option(pa_alsa_element *e, snd_mixer_t *m, int alsa_idx) {
    snd_mixer_selem_id_t *sid;
    snd_mixer_elem_t *me;
    char buf[64];
    int r;

    pa_assert(e);
    pa_assert(m);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return -1;
    }

    if (e->switch_use == PA_ALSA_SWITCH_SELECT) {

        if (e->direction == PA_ALSA_DIRECTION_OUTPUT)
            r = snd_mixer_selem_set_playback_switch_all(me, alsa_idx);
        else
            r = snd_mixer_selem_set_capture_switch_all(me, alsa_idx);

        if (r < 0) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Failed to set switch of %s: %s", buf, pa_alsa_strerror(errno));
        }

    } else {
        pa_assert(e->enumeration_use == PA_ALSA_ENUMERATION_SELECT);

        if ((r = snd_mixer_selem_set_enum_item(me, 0, alsa_idx)) < 0) {
            pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
            pa_log_warn("Failed to set enumeration of %s: %s", buf, pa_alsa_strerror(errno));
        }
    }

    return r;
}

static int setting_select(pa_alsa_setting *s, snd_mixer_t *m) {
    pa_alsa_option *o;
    uint32_t idx;

    pa_assert(s);
    pa_assert(m);

    PA_IDXSET_FOREACH(o, s->options, idx)
        element_set_option(o->element, m, o->alsa_idx);

    return 0;
}

static int option_verify(pa_alsa_option *o) {
    static const struct description_map well_known_descriptions[] = {
        { "input",                     N_("Input") },
        { "input-docking",             N_("Docking Station Input") },
        { "input-docking-microphone",  N_("Docking Station Microphone") },
        { "input-docking-linein",      N_("Docking Station Line In") },
        { "input-linein",              N_("Line In") },
        { "input-microphone",          N_("Microphone") },
        { "input-microphone-front",    N_("Front Microphone") },
        { "input-microphone-rear",     N_("Rear Microphone") },
        { "input-microphone-external", N_("External Microphone") },
        { "input-microphone-internal", N_("Internal Microphone") },
        { "input-radio",               N_("Radio") },
        { "input-video",               N_("Video") },
        { "input-agc-on",              N_("Automatic Gain Control") },
        { "input-agc-off",             N_("No Automatic Gain Control") },
        { "input-boost-on",            N_("Boost") },
        { "input-boost-off",           N_("No Boost") },
        { "output-amplifier-on",       N_("Amplifier") },
        { "output-amplifier-off",      N_("No Amplifier") },
        { "output-bass-boost-on",      N_("Bass Boost") },
        { "output-bass-boost-off",     N_("No Bass Boost") },
        { "output-speaker",            N_("Speaker") },
        { "output-headphones",         N_("Headphones") }
    };
    char buf[64];

    pa_assert(o);

    if (!o->name) {
        pa_log("No name set for option %s", o->alsa_name);
        return -1;
    }

    if (o->element->enumeration_use != PA_ALSA_ENUMERATION_SELECT &&
        o->element->switch_use != PA_ALSA_SWITCH_SELECT) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &o->element->alsa_id);
        pa_log("Element %s of option %s not set for select.", buf, o->name);
        return -1;
    }

    if (o->element->switch_use == PA_ALSA_SWITCH_SELECT &&
        !pa_streq(o->alsa_name, "on") &&
        !pa_streq(o->alsa_name, "off")) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &o->element->alsa_id);
        pa_log("Switch %s options need be named off or on ", buf);
        return -1;
    }

    if (!o->description)
        o->description = pa_xstrdup(lookup_description(o->name,
                                                       well_known_descriptions,
                                                       PA_ELEMENTSOF(well_known_descriptions)));
    if (!o->description)
        o->description = pa_xstrdup(o->name);

    return 0;
}

static int element_verify(pa_alsa_element *e) {
    pa_alsa_option *o;
    char buf[64];

    pa_assert(e);

//    pa_log_debug("Element %s, path %s: r=%d, r-any=%d, r-abs=%d", e->alsa_name, e->path->name, e->required, e->required_any, e->required_absent);
    if ((e->required != PA_ALSA_REQUIRED_IGNORE && e->required == e->required_absent) ||
        (e->required_any != PA_ALSA_REQUIRED_IGNORE && e->required_any == e->required_absent) ||
        (e->required_absent == PA_ALSA_REQUIRED_ANY && e->required_any != PA_ALSA_REQUIRED_IGNORE) ||
        (e->required_absent == PA_ALSA_REQUIRED_ANY && e->required != PA_ALSA_REQUIRED_IGNORE)) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log("Element %s cannot be required and absent at the same time.", buf);
        return -1;
    }

    if (e->switch_use == PA_ALSA_SWITCH_SELECT && e->enumeration_use == PA_ALSA_ENUMERATION_SELECT) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log("Element %s cannot set select for both switch and enumeration.", buf);
        return -1;
    }

    PA_LLIST_FOREACH(o, e->options)
        if (option_verify(o) < 0)
            return -1;

    return 0;
}

static int path_verify(pa_alsa_path *p) {
    static const struct description2_map well_known_descriptions[] = {
        { "analog-input",                     N_("Analog Input"),                 PA_DEVICE_PORT_TYPE_ANALOG },
        { "analog-input-microphone",          N_("Microphone"),                   PA_DEVICE_PORT_TYPE_MIC },
        { "analog-input-microphone-front",    N_("Front Microphone"),             PA_DEVICE_PORT_TYPE_MIC },
        { "analog-input-microphone-rear",     N_("Rear Microphone"),              PA_DEVICE_PORT_TYPE_MIC },
        { "analog-input-microphone-dock",     N_("Dock Microphone"),              PA_DEVICE_PORT_TYPE_MIC },
        { "analog-input-microphone-internal", N_("Internal Microphone"),          PA_DEVICE_PORT_TYPE_MIC },
        { "analog-input-microphone-headset",  N_("Headset Microphone"),           PA_DEVICE_PORT_TYPE_HEADSET },
        { "analog-input-linein",              N_("Line In"),                      PA_DEVICE_PORT_TYPE_LINE },
        { "analog-input-radio",               N_("Radio"),                        PA_DEVICE_PORT_TYPE_RADIO },
        { "analog-input-video",               N_("Video"),                        PA_DEVICE_PORT_TYPE_VIDEO },
        { "analog-output",                    N_("Analog Output"),                PA_DEVICE_PORT_TYPE_ANALOG },
        { "analog-output-headphones",         N_("Headphones"),                   PA_DEVICE_PORT_TYPE_HEADPHONES },
        { "analog-output-headphones-2",       N_("Headphones 2"),                 PA_DEVICE_PORT_TYPE_HEADPHONES },
        { "analog-output-headphones-mono",    N_("Headphones Mono Output"),       PA_DEVICE_PORT_TYPE_HEADPHONES },
        { "analog-output-lineout",            N_("Line Out"),                     PA_DEVICE_PORT_TYPE_LINE },
        { "analog-output-mono",               N_("Analog Mono Output"),           PA_DEVICE_PORT_TYPE_ANALOG },
        { "analog-output-speaker",            N_("Speakers"),                     PA_DEVICE_PORT_TYPE_SPEAKER },
        { "hdmi-output",                      N_("HDMI / DisplayPort"),           PA_DEVICE_PORT_TYPE_HDMI },
        { "iec958-stereo-output",             N_("Digital Output (S/PDIF)"),      PA_DEVICE_PORT_TYPE_SPDIF },
        { "iec958-stereo-input",              N_("Digital Input (S/PDIF)"),       PA_DEVICE_PORT_TYPE_SPDIF },
        { "multichannel-input",               N_("Multichannel Input"),           PA_DEVICE_PORT_TYPE_LINE },
        { "multichannel-output",              N_("Multichannel Output"),          PA_DEVICE_PORT_TYPE_LINE },
        { "steelseries-arctis-output-game-common", N_("Game Output"),             PA_DEVICE_PORT_TYPE_HEADSET },
        { "steelseries-arctis-output-chat-common", N_("Chat Output"),             PA_DEVICE_PORT_TYPE_HEADSET },
        { "analog-chat-output",               N_("Chat Output"),                  PA_DEVICE_PORT_TYPE_HEADSET },
        { "analog-chat-input",                N_("Chat Input"),                   PA_DEVICE_PORT_TYPE_HEADSET },
        { "virtual-surround-7.1",             N_("Virtual Surround 7.1"),         PA_DEVICE_PORT_TYPE_HEADPHONES },
    };

    pa_alsa_element *e;
    const char *key = p->description_key ? p->description_key : p->name;
    const struct description2_map *map = lookup_description2(key,
                                                             well_known_descriptions,
                                                             PA_ELEMENTSOF(well_known_descriptions));

    pa_assert(p);

    PA_LLIST_FOREACH(e, p->elements)
        if (element_verify(e) < 0)
            return -1;

    if (map) {
        if (p->device_port_type == PA_DEVICE_PORT_TYPE_UNKNOWN)
            p->device_port_type = map->type;
        if (!p->description)
            p->description = pa_xstrdup(_(map->description));
    }

    if (!p->description) {
        if (p->description_key)
            pa_log_warn("Path %s: Unrecognized description key: %s", p->name, p->description_key);

        p->description = pa_xstrdup(p->name);
    }

    return 0;
}

static const char *get_default_paths_dir(void) {
    const char *str;
#ifdef HAVE_RUNNING_FROM_BUILD_TREE
    if (pa_run_from_build_tree())
        return PA_SRCDIR "mixer/paths";
    else
#endif
    if (getenv("ACP_BUILDDIR") != NULL)
        return "mixer/paths";
    if ((str = getenv("ACP_PATHS_DIR")) != NULL)
        return str;
    return PA_ALSA_PATHS_DIR;
}

pa_alsa_path* pa_alsa_path_new(const char *paths_dir, const char *fname, pa_alsa_direction_t direction) {
    pa_alsa_path *p;
    char *fn;
    int r;
    const char *n;
    bool mute_during_activation = false;

    pa_config_item items[] = {
        /* [General] */
        { "priority",            pa_config_parse_unsigned,          NULL, "General" },
        { "description-key",     pa_config_parse_string,            NULL, "General" },
        { "description",         pa_config_parse_string,            NULL, "General" },
        { "mute-during-activation", pa_config_parse_bool,           NULL, "General" },
        { "type",                parse_type,                        NULL, "General" },
        { "eld-device",          parse_eld_device,                  NULL, "General" },

        /* [Option ...] */
        { "priority",            option_parse_priority,             NULL, NULL },
        { "name",                option_parse_name,                 NULL, NULL },

        /* [Jack ...] */
        { "state.plugged",       jack_parse_state,                  NULL, NULL },
        { "state.unplugged",     jack_parse_state,                  NULL, NULL },
        { "append-pcm-to-name",  jack_parse_append_pcm_to_name,     NULL, NULL },

        /* [Element ...] */
        { "switch",              element_parse_switch,              NULL, NULL },
        { "volume",              element_parse_volume,              NULL, NULL },
        { "enumeration",         element_parse_enumeration,         NULL, NULL },
        { "override-map.1",      element_parse_override_map,        NULL, NULL },
        { "override-map.2",      element_parse_override_map,        NULL, NULL },
        { "override-map.3",      element_parse_override_map,        NULL, NULL },
        { "override-map.4",      element_parse_override_map,        NULL, NULL },
        { "override-map.5",      element_parse_override_map,        NULL, NULL },
        { "override-map.6",      element_parse_override_map,        NULL, NULL },
        { "override-map.7",      element_parse_override_map,        NULL, NULL },
        { "override-map.8",      element_parse_override_map,        NULL, NULL },
#if POSITION_MASK_CHANNELS > 8
#error "Add override-map.9+ definitions"
#endif
        /* ... later on we might add override-map.3 and so on here ... */
        { "required",            element_parse_required,            NULL, NULL },
        { "required-any",        element_parse_required,            NULL, NULL },
        { "required-absent",     element_parse_required,            NULL, NULL },
        { "direction",           element_parse_direction,           NULL, NULL },
        { "direction-try-other", element_parse_direction_try_other, NULL, NULL },
        { "volume-limit",        element_parse_volume_limit,        NULL, NULL },
        { NULL, NULL, NULL, NULL }
    };

    pa_assert(fname);

    p = pa_xnew0(pa_alsa_path, 1);
    n = pa_path_get_filename(fname);
    p->name = pa_xstrndup(n, strcspn(n, "."));
    p->proplist = pa_proplist_new();
    p->direction = direction;
    p->eld_device = -1;

    items[0].data = &p->priority;
    items[1].data = &p->description_key;
    items[2].data = &p->description;
    items[3].data = &mute_during_activation;

    if (!paths_dir)
        paths_dir = get_default_paths_dir();

    fn = pa_maybe_prefix_path(fname, paths_dir);

    r = pa_config_parse(fn, NULL, items, p->proplist, false, p);
    pa_xfree(fn);

    if (r < 0)
        goto fail;

    p->mute_during_activation = mute_during_activation;

    if (path_verify(p) < 0)
        goto fail;

    if (p->description) {
	    char *tmp = p->description;
	    p->description = pa_xstrdup(_(tmp));
	    free(tmp);
    }

    return p;

fail:
    pa_alsa_path_free(p);
    return NULL;
}

pa_alsa_path *pa_alsa_path_synthesize(const char *element, pa_alsa_direction_t direction) {
    pa_alsa_path *p;
    pa_alsa_element *e;
    char *name;
    int index;

    pa_assert(element);

    name = alloca(strlen(element) + 1);
    if (alsa_id_decode(element, name, &index))
        return NULL;

    p = pa_xnew0(pa_alsa_path, 1);
    p->name = pa_xstrdup(element);
    p->direction = direction;
    p->proplist = pa_proplist_new();

    e = pa_xnew0(pa_alsa_element, 1);
    e->path = p;
    e->alsa_id.name = pa_xstrdup(name);
    e->alsa_id.index = index;
    e->direction = direction;
    e->volume_limit = -1;

    e->switch_use = PA_ALSA_SWITCH_MUTE;
    e->volume_use = PA_ALSA_VOLUME_MERGE;

    PA_LLIST_PREPEND(pa_alsa_element, p->elements, e);
    p->last_element = e;
    return p;
}

static bool element_drop_unsupported(pa_alsa_element *e) {
    pa_alsa_option *o, *n;

    pa_assert(e);

    for (o = e->options; o; o = n) {
        n = o->next;

        if (o->alsa_idx < 0) {
            PA_LLIST_REMOVE(pa_alsa_option, e->options, o);
            option_free(o);
        }
    }

    return
        e->switch_use != PA_ALSA_SWITCH_IGNORE ||
        e->volume_use != PA_ALSA_VOLUME_IGNORE ||
        e->enumeration_use != PA_ALSA_ENUMERATION_IGNORE;
}

static void path_drop_unsupported(pa_alsa_path *p) {
    pa_alsa_element *e, *n;

    pa_assert(p);

    for (e = p->elements; e; e = n) {
        n = e->next;

        if (!element_drop_unsupported(e)) {
            PA_LLIST_REMOVE(pa_alsa_element, p->elements, e);
            element_free(e);
        }
    }
}

static void path_make_options_unique(pa_alsa_path *p) {
    pa_alsa_element *e;
    pa_alsa_option *o, *u;

    PA_LLIST_FOREACH(e, p->elements) {
        PA_LLIST_FOREACH(o, e->options) {
            unsigned i;
            char *m;

            for (u = o->next; u; u = u->next)
                if (pa_streq(u->name, o->name))
                    break;

            if (!u)
                continue;

            m = pa_xstrdup(o->name);

            /* OK, this name is not unique, hence let's rename */
            for (i = 1, u = o; u; u = u->next) {
                char *nn, *nd;

                if (!pa_streq(u->name, m))
                    continue;

                nn = pa_sprintf_malloc("%s-%u", m, i);
                pa_xfree(u->name);
                u->name = nn;

                nd = pa_sprintf_malloc("%s %u", u->description, i);
                pa_xfree(u->description);
                u->description = nd;

                i++;
            }

            pa_xfree(m);
        }
    }
}

static bool element_create_settings(pa_alsa_element *e, pa_alsa_setting *template) {
    pa_alsa_option *o;

    for (; e; e = e->next)
        if (e->switch_use == PA_ALSA_SWITCH_SELECT ||
            e->enumeration_use == PA_ALSA_ENUMERATION_SELECT)
            break;

    if (!e)
        return false;

    for (o = e->options; o; o = o->next) {
        pa_alsa_setting *s;

        if (template) {
            s = pa_xnewdup(pa_alsa_setting, template, 1);
            s->options = pa_idxset_copy(template->options, NULL);
            s->name = pa_sprintf_malloc("%s+%s", template->name, o->name);
            s->description =
                (template->description[0] && o->description[0])
                ? pa_sprintf_malloc("%s / %s", template->description, o->description)
                : (template->description[0]
                   ? pa_xstrdup(template->description)
                   : pa_xstrdup(o->description));

            s->priority = PA_MAX(template->priority, o->priority);
        } else {
            s = pa_xnew0(pa_alsa_setting, 1);
            s->options = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
            s->name = pa_xstrdup(o->name);
            s->description = pa_xstrdup(o->description);
            s->priority = o->priority;
        }

        pa_idxset_put(s->options, o, NULL);

        if (element_create_settings(e->next, s))
            /* This is not a leaf, so let's get rid of it */
            setting_free(s);
        else {
            /* This is a leaf, so let's add it */
            PA_LLIST_INSERT_AFTER(pa_alsa_setting, e->path->settings, e->path->last_setting, s);

            e->path->last_setting = s;
        }
    }

    return true;
}

static void path_create_settings(pa_alsa_path *p) {
    pa_assert(p);

    element_create_settings(p->elements, NULL);
}

int pa_alsa_path_probe(pa_alsa_path *p, pa_alsa_mapping *mapping, snd_mixer_t *m, bool ignore_dB) {
    pa_alsa_element *e;
    pa_alsa_jack *j;
    double min_dB[PA_CHANNEL_POSITION_MAX], max_dB[PA_CHANNEL_POSITION_MAX];
    pa_channel_position_t t;
    pa_channel_position_mask_t path_volume_channels = 0;
    bool min_dB_set, max_dB_set;
    char buf[64];

    pa_assert(p);
    pa_assert(m);

    if (p->probed)
        return p->supported ? 0 : -1;
    p->probed = true;

    pa_zero(min_dB);
    pa_zero(max_dB);

    pa_log_debug("Probing path '%s'", p->name);

    PA_LLIST_FOREACH(j, p->jacks) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &j->alsa_id);
        if (jack_probe(j, mapping, m) < 0) {
            p->supported = false;
            pa_log_debug("Probe of jack %s failed.", buf);
            return -1;
        }
        pa_log_debug("Probe of jack %s succeeded (%s)", buf, j->has_control ? "found!" : "not found");
    }

    PA_LLIST_FOREACH(e, p->elements) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        if (element_probe(e, m) < 0) {
            p->supported = false;
            pa_log_debug("Probe of element %s failed.", buf);
            return -1;
        }
        pa_log_debug("Probe of element %s succeeded (volume=%d, switch=%d, enumeration=%d, has_dB=%d).", buf, e->volume_use, e->switch_use, e->enumeration_use, e->has_dB);

        if (ignore_dB)
            e->has_dB = false;

        if (e->volume_use == PA_ALSA_VOLUME_MERGE) {

            if (!p->has_volume) {
                p->min_volume = e->min_volume;
                p->max_volume = e->max_volume;
            }

            if (e->has_dB) {
                if (!p->has_volume) {
                    for (t = 0; t < PA_CHANNEL_POSITION_MAX; t++)
                        if (PA_CHANNEL_POSITION_MASK(t) & e->merged_mask) {
                            min_dB[t] = e->min_dB;
                            max_dB[t] = e->max_dB;
                            path_volume_channels |= PA_CHANNEL_POSITION_MASK(t);
                        }

                    p->has_dB = true;
                } else {

                    if (p->has_dB) {
                        for (t = 0; t < PA_CHANNEL_POSITION_MAX; t++)
                            if (PA_CHANNEL_POSITION_MASK(t) & e->merged_mask) {
                                min_dB[t] += e->min_dB;
                                max_dB[t] += e->max_dB;
                                path_volume_channels |= PA_CHANNEL_POSITION_MASK(t);
                            }
                    } else {
                        /* Hmm, there's another element before us
                         * which cannot do dB volumes, so we we need
                         * to 'neutralize' this slider */
                        e->volume_use = PA_ALSA_VOLUME_ZERO;
                        pa_log_info("Zeroing volume of %s on path '%s'", buf, p->name);
                    }
                }
            } else if (p->has_volume) {
                /* We can't use this volume, so let's ignore it */
                e->volume_use = PA_ALSA_VOLUME_IGNORE;
                pa_log_info("Ignoring volume of %s on path '%s' (missing dB info)", buf, p->name);
            }
            p->has_volume = true;
        }

        if (e->switch_use == PA_ALSA_SWITCH_MUTE)
            p->has_mute = true;
    }

    if (p->has_req_any && !p->req_any_present) {
        p->supported = false;
        pa_log_debug("Skipping path '%s', none of required-any elements preset.", p->name);
        return -1;
    }

    path_drop_unsupported(p);
    path_make_options_unique(p);
    path_create_settings(p);

    p->supported = true;

    p->min_dB = INFINITY;
    min_dB_set = false;
    p->max_dB = -INFINITY;
    max_dB_set = false;

    for (t = 0; t < PA_CHANNEL_POSITION_MAX; t++) {
        if (path_volume_channels & PA_CHANNEL_POSITION_MASK(t)) {
            if (p->min_dB > min_dB[t]) {
                p->min_dB = min_dB[t];
                min_dB_set = true;
            }

            if (p->max_dB < max_dB[t]) {
                p->max_dB = max_dB[t];
                max_dB_set = true;
            }
        }
    }

    /* this is probably a wrong prediction, but it should be safe */
    if (!min_dB_set)
        p->min_dB = -INFINITY;
    if (!max_dB_set)
        p->max_dB = 0;

    return 0;
}

void pa_alsa_setting_dump(pa_alsa_setting *s) {
    pa_assert(s);

    pa_log_debug("Setting %s (%s) priority=%u",
                 s->name,
                 pa_strnull(s->description),
                 s->priority);
}

void pa_alsa_jack_dump(pa_alsa_jack *j) {
    pa_assert(j);

    pa_log_debug("Jack %s, alsa_name='%s', index='%d', detection %s", j->name, j->alsa_id.name, j->alsa_id.index, j->has_control ? "possible" : "unavailable");
}

void pa_alsa_option_dump(pa_alsa_option *o) {
    pa_assert(o);

    pa_log_debug("Option %s (%s/%s) index=%i, priority=%u",
                 o->alsa_name,
                 pa_strnull(o->name),
                 pa_strnull(o->description),
                 o->alsa_idx,
                 o->priority);
}

void pa_alsa_element_dump(pa_alsa_element *e) {
    char buf[64];

    pa_alsa_option *o;
    pa_assert(e);

    pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
    pa_log_debug("Element %s, direction=%i, switch=%i, volume=%i, volume_limit=%li, enumeration=%i, required=%i, required_any=%i, required_absent=%i, mask=0x%llx, n_channels=%u, override_map=%02x",
                 buf,
                 e->direction,
                 e->switch_use,
                 e->volume_use,
                 e->volume_limit,
                 e->enumeration_use,
                 e->required,
                 e->required_any,
                 e->required_absent,
                 (long long unsigned) e->merged_mask,
                 e->n_channels,
                 e->override_map);

    PA_LLIST_FOREACH(o, e->options)
        pa_alsa_option_dump(o);
}

void pa_alsa_path_dump(pa_alsa_path *p) {
    pa_alsa_element *e;
    pa_alsa_jack *j;
    pa_alsa_setting *s;
    pa_assert(p);

    pa_log_debug("Path %s (%s), direction=%i, priority=%u, probed=%s, supported=%s, has_mute=%s, has_volume=%s, "
                 "has_dB=%s, min_volume=%li, max_volume=%li, min_dB=%g, max_dB=%g",
                 p->name,
                 pa_strnull(p->description),
                 p->direction,
                 p->priority,
                 pa_yes_no(p->probed),
                 pa_yes_no(p->supported),
                 pa_yes_no(p->has_mute),
                 pa_yes_no(p->has_volume),
                 pa_yes_no(p->has_dB),
                 p->min_volume, p->max_volume,
                 p->min_dB, p->max_dB);

    PA_LLIST_FOREACH(e, p->elements)
        pa_alsa_element_dump(e);

    PA_LLIST_FOREACH(j, p->jacks)
        pa_alsa_jack_dump(j);

    PA_LLIST_FOREACH(s, p->settings)
        pa_alsa_setting_dump(s);
}

static void element_set_callback(pa_alsa_element *e, snd_mixer_t *m, snd_mixer_elem_callback_t cb, void *userdata) {
    snd_mixer_selem_id_t *sid;
    snd_mixer_elem_t *me;
    char buf[64];

    pa_assert(e);
    pa_assert(m);
    pa_assert(cb);

    SELEM_INIT(sid, &e->alsa_id);
    if (!(me = snd_mixer_find_selem(m, sid))) {
        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &e->alsa_id);
        pa_log_warn("Element %s seems to have disappeared.", buf);
        return;
    }

    snd_mixer_elem_set_callback(me, cb);
    snd_mixer_elem_set_callback_private(me, userdata);
}

void pa_alsa_path_set_callback(pa_alsa_path *p, snd_mixer_t *m, snd_mixer_elem_callback_t cb, void *userdata) {
    pa_alsa_element *e;

    pa_assert(p);
    pa_assert(m);
    pa_assert(cb);

    PA_LLIST_FOREACH(e, p->elements)
        element_set_callback(e, m, cb, userdata);
}

void pa_alsa_path_set_set_callback(pa_alsa_path_set *ps, snd_mixer_t *m, snd_mixer_elem_callback_t cb, void *userdata) {
    pa_alsa_path *p;
    void *state;

    pa_assert(ps);
    pa_assert(m);
    pa_assert(cb);

    PA_HASHMAP_FOREACH(p, ps->paths, state)
        pa_alsa_path_set_callback(p, m, cb, userdata);
}

static pa_alsa_path *profile_set_get_path(pa_alsa_profile_set *ps, const char *path_name) {
    pa_alsa_path *path;

    pa_assert(ps);
    pa_assert(path_name);

    if ((path = pa_hashmap_get(ps->output_paths, path_name)))
        return path;

    return pa_hashmap_get(ps->input_paths, path_name);
}

static void profile_set_add_path(pa_alsa_profile_set *ps, pa_alsa_path *path) {
    pa_assert(ps);
    pa_assert(path);

    switch (path->direction) {
        case PA_ALSA_DIRECTION_OUTPUT:
            pa_assert_se(pa_hashmap_put(ps->output_paths, path->name, path) >= 0);
            break;

        case PA_ALSA_DIRECTION_INPUT:
            pa_assert_se(pa_hashmap_put(ps->input_paths, path->name, path) >= 0);
            break;

        default:
            pa_assert_not_reached();
    }
}

pa_alsa_path_set *pa_alsa_path_set_new(pa_alsa_mapping *m, pa_alsa_direction_t direction, const char *paths_dir) {
    pa_alsa_path_set *ps;
    char **pn = NULL, **en = NULL, **ie;
    pa_alsa_decibel_fix *db_fix;
    void *state, *state2;
    char name[64];
    int index;

    pa_assert(m);
    pa_assert(m->profile_set);
    pa_assert(m->profile_set->decibel_fixes);
    pa_assert(direction == PA_ALSA_DIRECTION_OUTPUT || direction == PA_ALSA_DIRECTION_INPUT);

    if (m->direction != PA_ALSA_DIRECTION_ANY && m->direction != direction)
        return NULL;

    ps = pa_xnew0(pa_alsa_path_set, 1);
    ps->direction = direction;
    ps->paths = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

    if (direction == PA_ALSA_DIRECTION_OUTPUT)
        pn = m->output_path_names;
    else
        pn = m->input_path_names;

    if (pn) {
        char **in;

        for (in = pn; *in; in++) {
            pa_alsa_path *p = NULL;
            bool duplicate = false;
            char **kn;

            for (kn = pn; kn < in; kn++)
                if (pa_streq(*kn, *in)) {
                    duplicate = true;
                    break;
                }

            if (duplicate)
                continue;

            p = profile_set_get_path(m->profile_set, *in);

            if (p && p->direction != direction) {
                pa_log("Configuration error: Path %s is used both as an input and as an output path.", p->name);
                goto fail;
            }

            if (!p) {
                char *fn = pa_sprintf_malloc("%s.conf", *in);
                p = pa_alsa_path_new(paths_dir, fn, direction);
                pa_xfree(fn);
                if (p)
                    profile_set_add_path(m->profile_set, p);
            }

            if (p)
                pa_hashmap_put(ps->paths, p, p);

        }

        goto finish;
    }

    if (direction == PA_ALSA_DIRECTION_OUTPUT)
        en = m->output_element;
    else
        en = m->input_element;

    if (!en)
        goto fail;

    for (ie = en; *ie; ie++) {
        char **je;
        pa_alsa_path *p;

        p = pa_alsa_path_synthesize(*ie, direction);

        /* Mark all other passed elements for require-absent */
        for (je = en; *je; je++) {
            pa_alsa_element *e;

            if (je == ie)
                continue;

            if (strlen(*je) + 1 >= sizeof(name)) {
                pa_log("Element identifier %s is too long!", *je);
                continue;
            }

            if (alsa_id_decode(*je, name, &index))
                continue;

            e = pa_xnew0(pa_alsa_element, 1);
            e->path = p;
            e->alsa_id.name = pa_xstrdup(name);
            e->alsa_id.index = index;
            e->direction = direction;
            e->required_absent = PA_ALSA_REQUIRED_ANY;
            e->volume_limit = -1;

            PA_LLIST_INSERT_AFTER(pa_alsa_element, p->elements, p->last_element, e);
            p->last_element = e;
        }

        pa_hashmap_put(ps->paths, *ie, p);
    }

finish:
    /* Assign decibel fixes to elements. */
    PA_HASHMAP_FOREACH(db_fix, m->profile_set->decibel_fixes, state) {
        pa_alsa_path *p;

        PA_HASHMAP_FOREACH(p, ps->paths, state2) {
            pa_alsa_element *e;

            PA_LLIST_FOREACH(e, p->elements) {
                if (e->volume_use != PA_ALSA_VOLUME_IGNORE && pa_streq(db_fix->name, e->alsa_id.name) &&
                    db_fix->index == e->alsa_id.index) {
                    /* The profile set that contains the dB fix may be freed
                     * before the element, so we have to copy the dB fix
                     * object. */
                    e->db_fix = pa_xnewdup(pa_alsa_decibel_fix, db_fix, 1);
                    e->db_fix->profile_set = NULL;
                    e->db_fix->name = pa_xstrdup(db_fix->name);
                    e->db_fix->db_values = pa_xmemdup(db_fix->db_values, (db_fix->max_step - db_fix->min_step + 1) * sizeof(long));
                }
            }
        }
    }

    return ps;

fail:
    if (ps)
        pa_alsa_path_set_free(ps);

    return NULL;
}

void pa_alsa_path_set_dump(pa_alsa_path_set *ps) {
    pa_alsa_path *p;
    void *state;
    pa_assert(ps);

    pa_log_debug("Path Set %p, direction=%i",
                 (void*) ps,
                 ps->direction);

    PA_HASHMAP_FOREACH(p, ps->paths, state)
        pa_alsa_path_dump(p);
}

static bool options_have_option(pa_alsa_option *options, const char *alsa_name) {
    pa_alsa_option *o;

    pa_assert(options);
    pa_assert(alsa_name);

    PA_LLIST_FOREACH(o, options) {
        if (pa_streq(o->alsa_name, alsa_name))
            return true;
    }
    return false;
}

static bool enumeration_is_subset(pa_alsa_option *a_options, pa_alsa_option *b_options) {
    pa_alsa_option *oa, *ob;

    if (!a_options) return true;
    if (!b_options) return false;

    /* If there is an option A offers that B does not, then A is not a subset of B. */
    PA_LLIST_FOREACH(oa, a_options) {
        bool found = false;
        PA_LLIST_FOREACH(ob, b_options) {
            if (pa_streq(oa->alsa_name, ob->alsa_name)) {
                found = true;
                break;
            }
        }
        if (!found)
            return false;
    }
    return true;
}

/**
 *  Compares two elements to see if a is a subset of b
 */
static bool element_is_subset(pa_alsa_element *a, pa_alsa_element *b, snd_mixer_t *m) {
    char buf[64];

    pa_assert(a);
    pa_assert(b);
    pa_assert(m);

    /* General rules:
     * Every state is a subset of itself (with caveats for volume_limits and options)
     * IGNORE is a subset of every other state */

    /* Check the volume_use */
    if (a->volume_use != PA_ALSA_VOLUME_IGNORE) {

        /* "Constant" is subset of "Constant" only when their constant values are equal */
        if (a->volume_use == PA_ALSA_VOLUME_CONSTANT && b->volume_use == PA_ALSA_VOLUME_CONSTANT && a->constant_volume != b->constant_volume)
            return false;

        /* Different volume uses when b is not "Merge" means we are definitely not a subset */
        if (a->volume_use != b->volume_use && b->volume_use != PA_ALSA_VOLUME_MERGE)
            return false;

        /* "Constant" is a subset of "Merge", if there is not a "volume-limit" in "Merge" below the actual constant.
         * "Zero" and "Off" are just special cases of "Constant" when comparing to "Merge"
         * "Merge" with a "volume-limit" is a subset of "Merge" without a "volume-limit" or with a higher "volume-limit" */
        if (b->volume_use == PA_ALSA_VOLUME_MERGE && b->volume_limit >= 0) {
            long a_limit;

            if (a->volume_use == PA_ALSA_VOLUME_CONSTANT)
                a_limit = a->constant_volume;
            else if (a->volume_use == PA_ALSA_VOLUME_ZERO) {
                long dB = 0;

                if (a->db_fix) {
                    int rounding = (a->direction == PA_ALSA_DIRECTION_OUTPUT ? +1 : -1);
                    a_limit = decibel_fix_get_step(a->db_fix, &dB, rounding);
                } else {
                    snd_mixer_selem_id_t *sid;
                    snd_mixer_elem_t *me;

                    SELEM_INIT(sid, &a->alsa_id);
                    if (!(me = snd_mixer_find_selem(m, sid))) {
                        pa_alsa_mixer_id_to_string(buf, sizeof(buf), &a->alsa_id);
                        pa_log_warn("Element %s seems to have disappeared.", buf);
                        return false;
                    }

                    if (a->direction == PA_ALSA_DIRECTION_OUTPUT) {
                        if (snd_mixer_selem_ask_playback_dB_vol(me, dB, +1, &a_limit) < 0)
                            return false;
                    } else {
                        if (snd_mixer_selem_ask_capture_dB_vol(me, dB, -1, &a_limit) < 0)
                            return false;
                    }
                }
            } else if (a->volume_use == PA_ALSA_VOLUME_OFF)
                a_limit = a->min_volume;
            else if (a->volume_use == PA_ALSA_VOLUME_MERGE)
                a_limit = a->volume_limit;
            else
                pa_assert_not_reached();

            if (a_limit > b->volume_limit)
                return false;
        }

        if (a->volume_use == PA_ALSA_VOLUME_MERGE) {
            int s;
            /* If override-maps are different, they're not subsets */
            if (a->n_channels != b->n_channels)
                return false;
            for (s = 0; s <= SND_MIXER_SCHN_LAST; s++)
                if (a->masks[s][a->n_channels-1] != b->masks[s][b->n_channels-1]) {
                    pa_alsa_mixer_id_to_string(buf, sizeof(buf), &a->alsa_id);
                    pa_log_debug("Element %s is not a subset - mask a: 0x%" PRIx64 ", mask b: 0x%" PRIx64 ", at channel %d",
                                 buf, a->masks[s][a->n_channels-1], b->masks[s][b->n_channels-1], s);
                    return false;
               }
        }
    }

    if (a->switch_use != PA_ALSA_SWITCH_IGNORE) {
        /* "On" is a subset of "Mute".
         * "Off" is a subset of "Mute".
         * "On" is a subset of "Select", if there is an "Option:On" in B.
         * "Off" is a subset of "Select", if there is an "Option:Off" in B.
         * "Select" is a subset of "Select", if they have the same options (is this always true?). */

        if (a->switch_use != b->switch_use) {

            if (a->switch_use == PA_ALSA_SWITCH_SELECT || a->switch_use == PA_ALSA_SWITCH_MUTE
                || b->switch_use == PA_ALSA_SWITCH_OFF || b->switch_use == PA_ALSA_SWITCH_ON)
                return false;

            if (b->switch_use == PA_ALSA_SWITCH_SELECT) {
                if (a->switch_use == PA_ALSA_SWITCH_ON) {
                    if (!options_have_option(b->options, "on"))
                        return false;
                } else if (a->switch_use == PA_ALSA_SWITCH_OFF) {
                    if (!options_have_option(b->options, "off"))
                        return false;
                }
            }
        } else if (a->switch_use == PA_ALSA_SWITCH_SELECT) {
            if (!enumeration_is_subset(a->options, b->options))
                return false;
        }
    }

    if (a->enumeration_use != PA_ALSA_ENUMERATION_IGNORE) {
        if (b->enumeration_use == PA_ALSA_ENUMERATION_IGNORE)
            return false;
        if (!enumeration_is_subset(a->options, b->options))
            return false;
    }

    return true;
}

static void path_set_condense(pa_alsa_path_set *ps, snd_mixer_t *m) {
    pa_alsa_path *p;
    void *state;

    pa_assert(ps);
    pa_assert(m);

    /* If we only have one path, then don't bother */
    if (pa_hashmap_size(ps->paths) < 2)
        return;

    PA_HASHMAP_FOREACH(p, ps->paths, state) {
        pa_alsa_path *p2;
        void *state2;

        PA_HASHMAP_FOREACH(p2, ps->paths, state2) {
            pa_alsa_element *ea, *eb;
            pa_alsa_jack *ja, *jb;
            bool is_subset = true;

            if (p == p2)
                continue;

            /* If a has a jack that b does not have, a is not a subset */
            PA_LLIST_FOREACH(ja, p->jacks) {
                bool exists = false;

                if (!ja->has_control)
                    continue;

                PA_LLIST_FOREACH(jb, p2->jacks) {
                    if (jb->has_control && pa_streq(ja->alsa_id.name, jb->alsa_id.name) &&
                       (ja->alsa_id.index == jb->alsa_id.index) &&
                       (ja->state_plugged == jb->state_plugged) &&
                       (ja->state_unplugged == jb->state_unplugged)) {
                        exists = true;
                        break;
                    }
                }

                if (!exists) {
                    is_subset = false;
                    break;
                }
            }

            /* Compare the elements of each set... */
            PA_LLIST_FOREACH(ea, p->elements) {
                bool found_matching_element = false;

                if (!is_subset)
                    break;

                PA_LLIST_FOREACH(eb, p2->elements) {
                    if (pa_streq(ea->alsa_id.name, eb->alsa_id.name) &&
                        ea->alsa_id.index == eb->alsa_id.index) {
                        found_matching_element = true;
                        is_subset = element_is_subset(ea, eb, m);
                        break;
                    }
                }

                if (!found_matching_element)
                    is_subset = false;
            }

            if (is_subset) {
                pa_log_debug("Removing path '%s' as it is a subset of '%s'.", p->name, p2->name);
                pa_hashmap_remove(ps->paths, p);
                break;
            }
        }
    }
}

static pa_alsa_path* path_set_find_path_by_description(pa_alsa_path_set *ps, const char* description, pa_alsa_path *ignore) {
    pa_alsa_path* p;
    void *state;

    PA_HASHMAP_FOREACH(p, ps->paths, state)
        if (p != ignore && pa_streq(p->description, description))
            return p;

    return NULL;
}

static void path_set_make_path_descriptions_unique(pa_alsa_path_set *ps) {
    pa_alsa_path *p, *q;
    void *state, *state2;

    PA_HASHMAP_FOREACH(p, ps->paths, state) {
        unsigned i;
        char *old_description;

        q = path_set_find_path_by_description(ps, p->description, p);

        if (!q)
            continue;

        old_description = pa_xstrdup(p->description);

        /* OK, this description is not unique, hence let's rename */
        i = 1;
        PA_HASHMAP_FOREACH(q, ps->paths, state2) {
            char *new_description;

            if (!pa_streq(q->description, old_description))
                continue;

            new_description = pa_sprintf_malloc("%s %u", q->description, i);
            pa_xfree(q->description);
            q->description = new_description;

            i++;
        }

        pa_xfree(old_description);
    }
}

static void mapping_free(pa_alsa_mapping *m) {
    pa_assert(m);

    pa_xfree(m->name);
    pa_xfree(m->description);
    pa_xfree(m->description_key);

    pa_proplist_free(m->proplist);

    pa_xstrfreev(m->device_strings);
    pa_xstrfreev(m->input_path_names);
    pa_xstrfreev(m->output_path_names);
    pa_xstrfreev(m->input_element);
    pa_xstrfreev(m->output_element);
    if (m->input_path_set)
        pa_alsa_path_set_free(m->input_path_set);
    if (m->output_path_set)
        pa_alsa_path_set_free(m->output_path_set);

    pa_proplist_free(m->input_proplist);
    pa_proplist_free(m->output_proplist);

    pa_assert(!m->input_pcm);
    pa_assert(!m->output_pcm);

    pa_alsa_ucm_mapping_context_free(&m->ucm_context);

    pa_xfree(m);
}

static void profile_free(pa_alsa_profile *p) {
    pa_assert(p);

    pa_xfree(p->name);
    pa_xfree(p->description);
    pa_xfree(p->description_key);
    pa_xfree(p->input_name);
    pa_xfree(p->output_name);

    pa_xstrfreev(p->input_mapping_names);
    pa_xstrfreev(p->output_mapping_names);

    if (p->input_mappings)
        pa_idxset_free(p->input_mappings, NULL);

    if (p->output_mappings)
        pa_idxset_free(p->output_mappings, NULL);

    pa_xfree(p);
}

void pa_alsa_profile_set_free(pa_alsa_profile_set *ps) {
    pa_assert(ps);

    if (ps->input_paths)
        pa_hashmap_free(ps->input_paths);

    if (ps->output_paths)
        pa_hashmap_free(ps->output_paths);

    if (ps->profiles)
        pa_hashmap_free(ps->profiles);

    if (ps->mappings)
        pa_hashmap_free(ps->mappings);

    if (ps->decibel_fixes)
        pa_hashmap_free(ps->decibel_fixes);

    pa_xfree(ps);
}

pa_alsa_mapping *pa_alsa_mapping_get(pa_alsa_profile_set *ps, const char *name) {
    pa_alsa_mapping *m;

    if (!pa_startswith(name, "Mapping "))
        return NULL;

    name += 8;

    if ((m = pa_hashmap_get(ps->mappings, name)))
        return m;

    m = pa_xnew0(pa_alsa_mapping, 1);
    m->profile_set = ps;
    m->exact_channels = true;
    m->name = pa_xstrdup(name);
    pa_sample_spec_init(&m->sample_spec);
    pa_channel_map_init(&m->channel_map);
    m->proplist = pa_proplist_new();
    m->hw_device_index = -1;
    m->input_proplist = pa_proplist_new();
    m->output_proplist = pa_proplist_new();

    pa_hashmap_put(ps->mappings, m->name, m);

    return m;
}

static pa_alsa_profile *profile_get(pa_alsa_profile_set *ps, const char *name) {
    pa_alsa_profile *p;

    if (!pa_startswith(name, "Profile "))
        return NULL;

    name += 8;

    if ((p = pa_hashmap_get(ps->profiles, name)))
        return p;

    p = pa_xnew0(pa_alsa_profile, 1);
    p->profile_set = ps;
    p->name = pa_xstrdup(name);

    pa_hashmap_put(ps->profiles, p->name, p);

    return p;
}

static pa_alsa_decibel_fix *decibel_fix_get(pa_alsa_profile_set *ps, const char *alsa_id) {
    pa_alsa_decibel_fix *db_fix;
    char *name;
    int index;

    if (!pa_startswith(alsa_id, "DecibelFix "))
        return NULL;

    alsa_id += 11;

    if ((db_fix = pa_hashmap_get(ps->decibel_fixes, alsa_id)))
        return db_fix;

    name = alloca(strlen(alsa_id) + 1);
    if (alsa_id_decode(alsa_id, name, &index))
        return NULL;

    db_fix = pa_xnew0(pa_alsa_decibel_fix, 1);
    db_fix->profile_set = ps;
    db_fix->name = pa_xstrdup(name);
    db_fix->index = index;
    db_fix->key = pa_xstrdup(alsa_id);

    pa_hashmap_put(ps->decibel_fixes, db_fix->key, db_fix);

    return db_fix;
}

static int mapping_parse_device_strings(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    pa_xstrfreev(m->device_strings);
    if (!(m->device_strings = pa_split_spaces_strv(state->rvalue))) {
        pa_log("[%s:%u] Device string list empty of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int mapping_parse_channel_map(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if (!(pa_channel_map_parse(&m->channel_map, state->rvalue))) {
        pa_log("[%s:%u] Channel map invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int mapping_parse_paths(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if (pa_streq(state->lvalue, "paths-input")) {
        pa_xstrfreev(m->input_path_names);
        m->input_path_names = pa_split_spaces_strv(state->rvalue);
    } else {
        pa_xstrfreev(m->output_path_names);
        m->output_path_names = pa_split_spaces_strv(state->rvalue);
    }

    return 0;
}

static int mapping_parse_exact_channels(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;
    int b;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if ((b = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] %s has invalid value '%s'", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    m->exact_channels = b;

    return 0;
}

static int mapping_parse_element(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if (pa_streq(state->lvalue, "element-input")) {
        pa_xstrfreev(m->input_element);
        m->input_element = pa_split_spaces_strv(state->rvalue);
    } else {
        pa_xstrfreev(m->output_element);
        m->output_element = pa_split_spaces_strv(state->rvalue);
    }

    return 0;
}

static int mapping_parse_direction(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] Section name %s invalid.", state->filename, state->lineno, state->section);
        return -1;
    }

    if (pa_streq(state->rvalue, "input"))
        m->direction = PA_ALSA_DIRECTION_INPUT;
    else if (pa_streq(state->rvalue, "output"))
        m->direction = PA_ALSA_DIRECTION_OUTPUT;
    else if (pa_streq(state->rvalue, "any"))
        m->direction = PA_ALSA_DIRECTION_ANY;
    else {
        pa_log("[%s:%u] Direction %s invalid.", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    return 0;
}

static int mapping_parse_description(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if ((m = pa_alsa_mapping_get(ps, state->section))) {
        pa_xfree(m->description);
        m->description = pa_xstrdup(_(state->rvalue));
    } else if ((p = profile_get(ps, state->section))) {
        pa_xfree(p->description);
        p->description = pa_xstrdup(_(state->rvalue));
    } else {
        pa_log("[%s:%u] Section name %s invalid.", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int mapping_parse_description_key(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if ((m = pa_alsa_mapping_get(ps, state->section))) {
        pa_xfree(m->description_key);
        m->description_key = pa_xstrdup(state->rvalue);
    } else if ((p = profile_get(ps, state->section))) {
        pa_xfree(p->description_key);
        p->description_key = pa_xstrdup(state->rvalue);
    } else {
        pa_log("[%s:%u] Section name %s invalid.", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}


static int mapping_parse_priority(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    uint32_t prio;

    pa_assert(state);

    ps = state->userdata;

    if (pa_atou(state->rvalue, &prio) < 0) {
        pa_log("[%s:%u] Priority invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if ((m = pa_alsa_mapping_get(ps, state->section)))
        m->priority = prio;
    else if ((p = profile_get(ps, state->section)))
        p->priority = prio;
    else {
        pa_log("[%s:%u] Section name %s invalid.", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int mapping_parse_fallback(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    int k;

    pa_assert(state);

    ps = state->userdata;

    if ((k = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] Fallback invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    if ((m = pa_alsa_mapping_get(ps, state->section)))
        m->fallback = k;
    else if ((p = profile_get(ps, state->section)))
        p->fallback_input = p->fallback_output = k;
    else {
        pa_log("[%s:%u] Section name %s invalid.", state->filename, state->lineno, state->section);
        return -1;
    }

    return 0;
}

static int mapping_parse_intended_roles(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_mapping *m;

    pa_assert(state);

    ps = state->userdata;

    if (!(m = pa_alsa_mapping_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    pa_proplist_sets(m->proplist, PA_PROP_DEVICE_INTENDED_ROLES, state->rvalue);

    return 0;
}


static int profile_parse_mappings(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;

    pa_assert(state);

    ps = state->userdata;

    if (!(p = profile_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if (pa_streq(state->lvalue, "input-mappings")) {
        pa_xstrfreev(p->input_mapping_names);
        p->input_mapping_names = pa_split_spaces_strv(state->rvalue);
    } else {
        pa_xstrfreev(p->output_mapping_names);
        p->output_mapping_names = pa_split_spaces_strv(state->rvalue);
    }

    return 0;
}

static int profile_parse_skip_probe(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    int b;

    pa_assert(state);

    ps = state->userdata;

    if (!(p = profile_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if ((b = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] Skip probe invalid of '%s'", state->filename, state->lineno, state->section);
        return -1;
    }

    p->supported = b;

    return 0;
}

static int decibel_fix_parse_db_values(pa_config_parser_state *state) {
    pa_alsa_profile_set *ps;
    pa_alsa_decibel_fix *db_fix;
    char **items;
    char *item;
    long *db_values;
    unsigned n = 8; /* Current size of the db_values table. */
    unsigned min_step = 0;
    unsigned max_step = 0;
    unsigned i = 0; /* Index to the items table. */
    unsigned prev_step = 0;
    double prev_db = 0;

    pa_assert(state);

    ps = state->userdata;

    if (!(db_fix = decibel_fix_get(ps, state->section))) {
        pa_log("[%s:%u] %s invalid in section %s", state->filename, state->lineno, state->lvalue, state->section);
        return -1;
    }

    if (!(items = pa_split_spaces_strv(state->rvalue))) {
        pa_log("[%s:%u] Value missing", state->filename, state->lineno);
        return -1;
    }

    db_values = pa_xnew(long, n);

    while ((item = items[i++])) {
        char *s = item; /* Step value string. */
        char *d = item; /* dB value string. */
        uint32_t step;
        double db;

        /* Move d forward until it points to a colon or to the end of the item. */
        for (; *d && *d != ':'; ++d);

        if (d == s) {
            /* item started with colon. */
            pa_log("[%s:%u] No step value found in %s", state->filename, state->lineno, item);
            goto fail;
        }

        if (!*d || !*(d + 1)) {
            /* No colon found, or it was the last character in item. */
            pa_log("[%s:%u] No dB value found in %s", state->filename, state->lineno, item);
            goto fail;
        }

        /* pa_atou() needs a null-terminating string. Let's replace the colon
         * with a zero byte. */
        *d++ = '\0';

        if (pa_atou(s, &step) < 0) {
            pa_log("[%s:%u] Invalid step value: %s", state->filename, state->lineno, s);
            goto fail;
        }

        if (pa_atod(d, &db) < 0) {
            pa_log("[%s:%u] Invalid dB value: %s", state->filename, state->lineno, d);
            goto fail;
        }

        if (step <= prev_step && i != 1) {
            pa_log("[%s:%u] Step value %u not greater than the previous value %u", state->filename, state->lineno, step, prev_step);
            goto fail;
        }

        if (db < prev_db && i != 1) {
            pa_log("[%s:%u] Decibel value %0.2f less than the previous value %0.2f", state->filename, state->lineno, db, prev_db);
            goto fail;
        }

        if (i == 1) {
            min_step = step;
            db_values[0] = (long) (db * 100.0);
            prev_step = step;
            prev_db = db;
        } else {
            /* Interpolate linearly. */
            double db_increment = (db - prev_db) / (step - prev_step);

            for (; prev_step < step; ++prev_step, prev_db += db_increment) {

                /* Reallocate the db_values table if it's about to overflow. */
                if (prev_step + 1 - min_step == n) {
                    n *= 2;
                    db_values = pa_xrenew(long, db_values, n);
                }

                db_values[prev_step + 1 - min_step] = (long) ((prev_db + db_increment) * 100.0);
            }
        }

        max_step = step;
    }

    db_fix->min_step = min_step;
    db_fix->max_step = max_step;
    pa_xfree(db_fix->db_values);
    db_fix->db_values = db_values;

    pa_xstrfreev(items);

    return 0;

fail:
    pa_xstrfreev(items);
    pa_xfree(db_values);

    return -1;
}

/* the logic is simple: if we see the jack in multiple paths */
/* assign all those paths to one availability_group */
static void profile_set_set_availability_groups(pa_alsa_profile_set *ps) {
    pa_dynarray *paths;
    pa_alsa_path *p;
    void *state;
    unsigned idx1;
    uint32_t num = 1;

    /* Merge ps->input_paths and ps->output_paths into one dynarray. */
    paths = pa_dynarray_new(NULL);
    PA_HASHMAP_FOREACH(p, ps->input_paths, state)
        pa_dynarray_append(paths, p);
    PA_HASHMAP_FOREACH(p, ps->output_paths, state)
        pa_dynarray_append(paths, p);

    PA_DYNARRAY_FOREACH(p, paths, idx1) {
        pa_alsa_jack *j;
        const char *found = NULL;
        bool has_control = false;

        PA_LLIST_FOREACH(j, p->jacks) {
            pa_alsa_path *p2;
            unsigned idx2;

            if (!j->has_control || j->state_plugged == PA_AVAILABLE_NO)
                continue;
            has_control = true;
            PA_DYNARRAY_FOREACH(p2, paths, idx2) {
                pa_alsa_jack *j2;

                if (p2 == p)
                    break;
                PA_LLIST_FOREACH(j2, p2->jacks) {
                    if (!j2->has_control || j2->state_plugged == PA_AVAILABLE_NO)
                        continue;
                    if (pa_streq(j->alsa_id.name, j2->alsa_id.name) &&
                        j->alsa_id.index == j2->alsa_id.index) {
                        j->state_plugged = PA_AVAILABLE_UNKNOWN;
                        j2->state_plugged = PA_AVAILABLE_UNKNOWN;
                        found = p2->availability_group;
                        break;
                    }
                }
            }
            if (found)
                break;
        }
        if (!has_control)
            continue;
        if (!found) {
            p->availability_group = pa_sprintf_malloc("Legacy %d", num);
        } else {
            p->availability_group = pa_xstrdup(found);
        }
        if (!found)
            num++;
    }

    pa_dynarray_free(paths);
}

static void mapping_paths_probe(pa_alsa_mapping *m, pa_alsa_profile *profile,
                                pa_alsa_direction_t direction, pa_hashmap *used_paths,
                                pa_hashmap *mixers) {

    pa_alsa_path *p;
    void *state;
    snd_pcm_t *pcm_handle;
    pa_alsa_path_set *ps;
    snd_mixer_t *mixer_handle;

    if (direction == PA_ALSA_DIRECTION_OUTPUT) {
        if (m->output_path_set)
            return; /* Already probed */
        m->output_path_set = ps = pa_alsa_path_set_new(m, direction, NULL); /* FIXME: Handle paths_dir */
        pcm_handle = m->output_pcm;
    } else {
        if (m->input_path_set)
            return; /* Already probed */
        m->input_path_set = ps = pa_alsa_path_set_new(m, direction, NULL); /* FIXME: Handle paths_dir */
        pcm_handle = m->input_pcm;
    }

    if (!ps)
        return; /* No paths */

    pa_assert(pcm_handle);

    mixer_handle = pa_alsa_open_mixer_for_pcm(mixers, pcm_handle, true);
    if (!mixer_handle) {
        /* Cannot open mixer, remove all entries */
        pa_hashmap_remove_all(ps->paths);
        return;
    }

    PA_HASHMAP_FOREACH(p, ps->paths, state) {
        if (p->autodetect_eld_device)
            p->eld_device = m->hw_device_index;

        if (pa_alsa_path_probe(p, m, mixer_handle, m->profile_set->ignore_dB) < 0)
            pa_hashmap_remove(ps->paths, p);
    }

    path_set_condense(ps, mixer_handle);
    path_set_make_path_descriptions_unique(ps);

    PA_HASHMAP_FOREACH(p, ps->paths, state)
        pa_hashmap_put(used_paths, p, p);

    pa_log_debug("Available mixer paths (after tidying):");
    pa_alsa_path_set_dump(ps);
}

static int mapping_verify(pa_alsa_mapping *m, const pa_channel_map *bonus) {

    static const struct description_map well_known_descriptions[] = {
        { "analog-mono",            N_("Analog Mono") },
        { "analog-mono-left",       N_("Analog Mono (Left)") },
        { "analog-mono-right",      N_("Analog Mono (Right)") },
        { "analog-stereo",          N_("Analog Stereo") },
        { "mono-fallback",          N_("Mono") },
        { "stereo-fallback",        N_("Stereo") },
        /* Note: Not translated to "Analog Stereo Input", because the source
         * name gets "Input" appended to it automatically, so adding "Input"
         * here would lead to the source name to become "Analog Stereo Input
         * Input". The same logic applies to analog-stereo-output,
         * multichannel-input and multichannel-output. */
        { "analog-stereo-input",    N_("Analog Stereo") },
        { "analog-stereo-output",   N_("Analog Stereo") },
        { "analog-stereo-headset",  N_("Headset") },
        { "analog-stereo-speakerphone",  N_("Speakerphone") },
        { "multichannel-input",     N_("Multichannel") },
        { "multichannel-output",    N_("Multichannel") },
        { "analog-surround-21",     N_("Analog Surround 2.1") },
        { "analog-surround-30",     N_("Analog Surround 3.0") },
        { "analog-surround-31",     N_("Analog Surround 3.1") },
        { "analog-surround-40",     N_("Analog Surround 4.0") },
        { "analog-surround-41",     N_("Analog Surround 4.1") },
        { "analog-surround-50",     N_("Analog Surround 5.0") },
        { "analog-surround-51",     N_("Analog Surround 5.1") },
        { "analog-surround-61",     N_("Analog Surround 6.0") },
        { "analog-surround-61",     N_("Analog Surround 6.1") },
        { "analog-surround-70",     N_("Analog Surround 7.0") },
        { "analog-surround-71",     N_("Analog Surround 7.1") },
        { "iec958-stereo",          N_("Digital Stereo (IEC958)") },
        { "iec958-ac3-surround-40", N_("Digital Surround 4.0 (IEC958/AC3)") },
        { "iec958-ac3-surround-51", N_("Digital Surround 5.1 (IEC958/AC3)") },
        { "iec958-dts-surround-51", N_("Digital Surround 5.1 (IEC958/DTS)") },
        { "hdmi-stereo",            N_("Digital Stereo (HDMI)") },
        { "hdmi-surround-51",       N_("Digital Surround 5.1 (HDMI)") },
        { "gaming-headset-chat",    N_("Chat") },
        { "gaming-headset-game",    N_("Game") },
    };
    const char *description_key = m->description_key ? m->description_key : m->name;

    pa_assert(m);

    if (!pa_channel_map_valid(&m->channel_map)) {
        pa_log("Mapping %s is missing channel map.", m->name);
        return -1;
    }

    if (!m->device_strings) {
        pa_log("Mapping %s is missing device strings.", m->name);
        return -1;
    }

    if ((m->input_path_names && m->input_element) ||
        (m->output_path_names && m->output_element)) {
        pa_log("Mapping %s must have either mixer path or mixer element, not both.", m->name);
        return -1;
    }

    if (!m->description)
        m->description = pa_xstrdup(lookup_description(description_key,
                                                       well_known_descriptions,
                                                       PA_ELEMENTSOF(well_known_descriptions)));

    if (!m->description)
        m->description = pa_xstrdup(m->name);

    if (bonus) {
        if (pa_channel_map_equal(&m->channel_map, bonus))
            m->priority += 50;
        else if (m->channel_map.channels == bonus->channels)
            m->priority += 30;
    }

    return 0;
}

void pa_alsa_mapping_dump(pa_alsa_mapping *m) {
    char cm[PA_CHANNEL_MAP_SNPRINT_MAX];

    pa_assert(m);

    pa_log_debug("Mapping %s (%s), priority=%u, channel_map=%s, supported=%s, direction=%i",
                 m->name,
                 pa_strnull(m->description),
                 m->priority,
                 pa_channel_map_snprint(cm, sizeof(cm), &m->channel_map),
                 pa_yes_no(m->supported),
                 m->direction);
}

static void profile_set_add_auto_pair(
        pa_alsa_profile_set *ps,
        pa_alsa_mapping *m, /* output */
        pa_alsa_mapping *n  /* input */) {

    char *name;
    pa_alsa_profile *p;

    pa_assert(ps);
    pa_assert(m || n);

    if (m && m->direction == PA_ALSA_DIRECTION_INPUT)
        return;

    if (n && n->direction == PA_ALSA_DIRECTION_OUTPUT)
        return;

    if (m && n)
        name = pa_sprintf_malloc("output:%s+input:%s", m->name, n->name);
    else if (m)
        name = pa_sprintf_malloc("output:%s", m->name);
    else
        name = pa_sprintf_malloc("input:%s", n->name);

    if (pa_hashmap_get(ps->profiles, name)) {
        pa_xfree(name);
        return;
    }

    p = pa_xnew0(pa_alsa_profile, 1);
    p->profile_set = ps;
    p->name = name;

    if (m) {
        p->output_name = pa_xstrdup(m->name);
        p->output_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        pa_idxset_put(p->output_mappings, m, NULL);
        p->priority += m->priority * 100;
        p->fallback_output = m->fallback;
    }

    if (n) {
        p->input_name = pa_xstrdup(n->name);
        p->input_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        pa_idxset_put(p->input_mappings, n, NULL);
        p->priority += n->priority;
        p->fallback_input = n->fallback;
    }

    pa_hashmap_put(ps->profiles, p->name, p);
}

static void profile_set_add_auto(pa_alsa_profile_set *ps) {
    pa_alsa_mapping *m, *n;
    void *m_state, *n_state;

    pa_assert(ps);

    /* The order is important here:
       1) try single inputs and outputs before trying their
          combination, because if the half-duplex test failed, we don't have
          to try full duplex.
       2) try the output right before the input combinations with
          that output, because then the output_pcm is not closed between tests.
    */
    PA_HASHMAP_FOREACH(n, ps->mappings, n_state)
        profile_set_add_auto_pair(ps, NULL, n);

    PA_HASHMAP_FOREACH(m, ps->mappings, m_state) {
        profile_set_add_auto_pair(ps, m, NULL);

        PA_HASHMAP_FOREACH(n, ps->mappings, n_state)
            profile_set_add_auto_pair(ps, m, n);
    }

}

static int profile_verify(pa_alsa_profile *p) {

    static const struct description_map well_known_descriptions[] = {
        { "output:analog-mono+input:analog-mono",     N_("Analog Mono Duplex") },
        { "output:analog-stereo+input:analog-stereo", N_("Analog Stereo Duplex") },
        { "output:analog-stereo-headset+input:analog-stereo-headset", N_("Headset") },
        { "output:analog-stereo-speakerphone+input:analog-stereo-speakerphone", N_("Speakerphone") },
        { "output:iec958-stereo+input:iec958-stereo", N_("Digital Stereo Duplex (IEC958)") },
        { "output:multichannel-output+input:multichannel-input", N_("Multichannel Duplex") },
        { "output:unknown-stereo+input:unknown-stereo", N_("Stereo Duplex") },
        { "output:analog-output-surround71+output:analog-output-chat+input:analog-input", N_("Mono Chat + 7.1 Surround") },
        { "off",                                      N_("Off") }
    };
    const char *description_key = p->description_key ? p->description_key : p->name;

    pa_assert(p);

    /* Replace the output mapping names by the actual mappings */
    if (p->output_mapping_names) {
        char **name;

        pa_assert(!p->output_mappings);
        p->output_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

        for (name = p->output_mapping_names; *name; name++) {
            pa_alsa_mapping *m;
            char **in;
            bool duplicate = false;

            for (in = name + 1; *in; in++)
                if (pa_streq(*name, *in)) {
                    duplicate = true;
                    break;
                }

            if (duplicate)
                continue;

            if (!(m = pa_hashmap_get(p->profile_set->mappings, *name)) || m->direction == PA_ALSA_DIRECTION_INPUT) {
                pa_log("Profile '%s' refers to nonexistent mapping '%s'.", p->name, *name);
                return -1;
            }

            pa_idxset_put(p->output_mappings, m, NULL);

            if (p->supported)
                m->supported++;
        }

        pa_xstrfreev(p->output_mapping_names);
        p->output_mapping_names = NULL;
    }

    /* Replace the input mapping names by the actual mappings */
    if (p->input_mapping_names) {
        char **name;

        pa_assert(!p->input_mappings);
        p->input_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

        for (name = p->input_mapping_names; *name; name++) {
            pa_alsa_mapping *m;
            char **in;
            bool duplicate = false;

            for (in = name + 1; *in; in++)
                if (pa_streq(*name, *in)) {
                    duplicate = true;
                    break;
                }

            if (duplicate)
                continue;

            if (!(m = pa_hashmap_get(p->profile_set->mappings, *name)) || m->direction == PA_ALSA_DIRECTION_OUTPUT) {
                pa_log("Profile '%s' refers to nonexistent mapping '%s'.", p->name, *name);
                return -1;
            }

            pa_idxset_put(p->input_mappings, m, NULL);

            if (p->supported)
                m->supported++;
        }

        pa_xstrfreev(p->input_mapping_names);
        p->input_mapping_names = NULL;
    }

    if (!p->input_mappings && !p->output_mappings) {
        pa_log("Profile '%s' lacks mappings.", p->name);
        return -1;
    }

    if (!p->description)
        p->description = pa_xstrdup(lookup_description(description_key,
                                                       well_known_descriptions,
                                                       PA_ELEMENTSOF(well_known_descriptions)));

    if (!p->description) {
        uint32_t idx;
        pa_alsa_mapping *m;
	char *ptr;
	size_t size;
	FILE *f;
	int count = 0;

	f = open_memstream(&ptr, &size);

        if (p->output_mappings)
            PA_IDXSET_FOREACH(m, p->output_mappings, idx) {
                if (count++ > 0)
                    fprintf(f, " + ");
                fprintf(f, _("%s Output"), m->description);
            }

        if (p->input_mappings)
            PA_IDXSET_FOREACH(m, p->input_mappings, idx) {
                if (count++ > 0)
                    fprintf(f, " + ");
                fprintf(f, _("%s Input"), m->description);
            }

	fclose(f);
        p->description = ptr;
    }

    return 0;
}

void pa_alsa_profile_dump(pa_alsa_profile *p) {
    uint32_t idx;
    pa_alsa_mapping *m;
    pa_assert(p);

    pa_log_debug("Profile %s (%s), input=%s, output=%s priority=%u, supported=%s n_input_mappings=%u, n_output_mappings=%u",
                 p->name,
                 pa_strnull(p->description),
                 pa_strnull(p->input_name),
                 pa_strnull(p->output_name),
                 p->priority,
                 pa_yes_no(p->supported),
                 p->input_mappings ? pa_idxset_size(p->input_mappings) : 0,
                 p->output_mappings ? pa_idxset_size(p->output_mappings) : 0);

    if (p->input_mappings)
        PA_IDXSET_FOREACH(m, p->input_mappings, idx)
            pa_log_debug("Input %s", m->name);

    if (p->output_mappings)
        PA_IDXSET_FOREACH(m, p->output_mappings, idx)
            pa_log_debug("Output %s", m->name);
}

static int decibel_fix_verify(pa_alsa_decibel_fix *db_fix) {
    pa_assert(db_fix);

    /* Check that the dB mapping has been configured. Since "db-values" is
     * currently the only option in the DecibelFix section, and decibel fix
     * objects don't get created if a DecibelFix section is empty, this is
     * actually a redundant check. Having this may prevent future bugs,
     * however. */
    if (!db_fix->db_values) {
        pa_log("Decibel fix for element %s lacks the dB values.", db_fix->name);
        return -1;
    }

    return 0;
}

void pa_alsa_decibel_fix_dump(pa_alsa_decibel_fix *db_fix) {
    char *db_values = NULL;

    pa_assert(db_fix);

    if (db_fix->db_values) {
        unsigned long i, nsteps;
	FILE *f;
	char *ptr;
	size_t size;

	f = open_memstream(&ptr, &size);

        pa_assert(db_fix->min_step <= db_fix->max_step);
        nsteps = db_fix->max_step - db_fix->min_step + 1;

        for (i = 0; i < nsteps; ++i)
            fprintf(f, "[%li]:%0.2f ", i + db_fix->min_step, db_fix->db_values[i] / 100.0);

	fclose(f);
        db_values = ptr;
    }

    pa_log_debug("Decibel fix %s, min_step=%li, max_step=%li, db_values=%s",
                 db_fix->name, db_fix->min_step, db_fix->max_step, pa_strnull(db_values));

    pa_xfree(db_values);
}

static const char *get_default_profile_dir(void) {
    const char *str;
#ifdef HAVE_RUNNING_FROM_BUILD_TREE
    if (pa_run_from_build_tree())
        return PA_SRCDIR "mixer/profile-sets";
    else
#endif
    if (getenv("ACP_BUILDDIR") != NULL)
        return "mixer/profile-sets";
    if ((str = getenv("ACP_PROFILES_DIR")) != NULL)
        return str;
    return PA_ALSA_PROFILE_SETS_DIR;
}

pa_alsa_profile_set* pa_alsa_profile_set_new(const char *fname, const pa_channel_map *bonus) {
    pa_alsa_profile_set *ps;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    pa_alsa_decibel_fix *db_fix;
    char *fn;
    int r;
    void *state;

    static pa_config_item items[] = {
        /* [General] */
        { "auto-profiles",          pa_config_parse_bool,         NULL, "General" },

        /* [Mapping ...] */
        { "device-strings",         mapping_parse_device_strings, NULL, NULL },
        { "channel-map",            mapping_parse_channel_map,    NULL, NULL },
        { "paths-input",            mapping_parse_paths,          NULL, NULL },
        { "paths-output",           mapping_parse_paths,          NULL, NULL },
        { "element-input",          mapping_parse_element,        NULL, NULL },
        { "element-output",         mapping_parse_element,        NULL, NULL },
        { "direction",              mapping_parse_direction,      NULL, NULL },
        { "exact-channels",         mapping_parse_exact_channels, NULL, NULL },
        { "intended-roles",         mapping_parse_intended_roles, NULL, NULL },

        /* Shared by [Mapping ...] and [Profile ...] */
        { "description",            mapping_parse_description,    NULL, NULL },
        { "description-key",        mapping_parse_description_key,NULL, NULL },
        { "priority",               mapping_parse_priority,       NULL, NULL },
        { "fallback",               mapping_parse_fallback,       NULL, NULL },

        /* [Profile ...] */
        { "input-mappings",         profile_parse_mappings,       NULL, NULL },
        { "output-mappings",        profile_parse_mappings,       NULL, NULL },
        { "skip-probe",             profile_parse_skip_probe,     NULL, NULL },

        /* [DecibelFix ...] */
        { "db-values",              decibel_fix_parse_db_values,  NULL, NULL },
        { NULL, NULL, NULL, NULL }
    };

    ps = pa_xnew0(pa_alsa_profile_set, 1);
    ps->mappings = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, NULL, (pa_free_cb_t) mapping_free);
    ps->profiles = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, NULL, (pa_free_cb_t) profile_free);
    ps->decibel_fixes = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, NULL, (pa_free_cb_t) decibel_fix_free);
    ps->input_paths = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, NULL, (pa_free_cb_t) pa_alsa_path_free);
    ps->output_paths = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, NULL, (pa_free_cb_t) pa_alsa_path_free);

    items[0].data = &ps->auto_profiles;

    fn = pa_maybe_prefix_path(fname ? fname : "default.conf",
		    get_default_profile_dir());
    if ((r = access(fn, R_OK)) != 0) {
        if (fname != NULL) {
            pa_log_warn("profile-set '%s' can't be accessed: %m", fn);
            fn = pa_maybe_prefix_path("default.conf",
			    get_default_profile_dir());
            r = access(fn, R_OK);
	}
	if (r != 0) {
            pa_log_warn("profile-set '%s' can't be accessed: %m", fn);
	}
    }
    r = pa_config_parse(fn, NULL, items, NULL, false, ps);
    pa_xfree(fn);

    if (r < 0)
        goto fail;

    PA_HASHMAP_FOREACH(m, ps->mappings, state)
        if (mapping_verify(m, bonus) < 0)
            goto fail;

    if (ps->auto_profiles)
        profile_set_add_auto(ps);

    PA_HASHMAP_FOREACH(p, ps->profiles, state)
        if (profile_verify(p) < 0)
            goto fail;

    PA_HASHMAP_FOREACH(db_fix, ps->decibel_fixes, state)
        if (decibel_fix_verify(db_fix) < 0)
            goto fail;

    return ps;

fail:
    pa_alsa_profile_set_free(ps);
    return NULL;
}

static void profile_finalize_probing(pa_alsa_profile *to_be_finalized, pa_alsa_profile *next) {
    pa_alsa_mapping *m;
    uint32_t idx;

    if (!to_be_finalized)
        return;

    if (to_be_finalized->output_mappings)
        PA_IDXSET_FOREACH(m, to_be_finalized->output_mappings, idx) {

            if (!m->output_pcm)
                continue;

            if (to_be_finalized->supported)
                m->supported++;

            /* If this mapping is also in the next profile, we won't close the
             * pcm handle here, because it would get immediately reopened
             * anyway. */
            if (next && next->output_mappings && pa_idxset_get_by_data(next->output_mappings, m, NULL))
                continue;

            pa_alsa_init_proplist_pcm(NULL, m->output_proplist, m->output_pcm);
            snd_pcm_close(m->output_pcm);
            m->output_pcm = NULL;
        }

    if (to_be_finalized->input_mappings)
        PA_IDXSET_FOREACH(m, to_be_finalized->input_mappings, idx) {

            if (!m->input_pcm)
                continue;

            if (to_be_finalized->supported)
                m->supported++;

            /* If this mapping is also in the next profile, we won't close the
             * pcm handle here, because it would get immediately reopened
             * anyway. */
            if (next && next->input_mappings && pa_idxset_get_by_data(next->input_mappings, m, NULL))
                continue;

            pa_alsa_init_proplist_pcm(NULL, m->input_proplist, m->input_pcm);
            snd_pcm_close(m->input_pcm);
            m->input_pcm = NULL;
        }
}

static snd_pcm_t* mapping_open_pcm(pa_alsa_mapping *m,
                                   const pa_sample_spec *ss,
                                   const char *dev_id,
                                   bool exact_channels,
                                   int mode,
                                   unsigned default_n_fragments,
                                   unsigned default_fragment_size_msec) {

    snd_pcm_t* handle;
    pa_sample_spec try_ss = *ss;
    pa_channel_map try_map = m->channel_map;
    snd_pcm_uframes_t try_period_size, try_buffer_size;

    try_ss.channels = try_map.channels;

    try_period_size =
        pa_usec_to_bytes(default_fragment_size_msec * PA_USEC_PER_MSEC, &try_ss) /
        pa_frame_size(&try_ss);
    try_buffer_size = default_n_fragments * try_period_size;

    handle = pa_alsa_open_by_template(
                              m->device_strings, dev_id, NULL, &try_ss,
                              &try_map, mode, &try_period_size,
                              &try_buffer_size, 0, NULL, NULL, exact_channels);
    if (handle && !exact_channels && m->channel_map.channels != try_map.channels) {
        char buf[PA_CHANNEL_MAP_SNPRINT_MAX];
        pa_log_debug("Channel map for mapping '%s' permanently changed to '%s'", m->name,
                     pa_channel_map_snprint(buf, sizeof(buf), &try_map));
        m->channel_map = try_map;
    }
    return handle;
}

static void paths_drop_unused(pa_hashmap* h, pa_hashmap *keep) {

    void* state = NULL;
    const void* key;
    pa_alsa_path* p;

    pa_assert(h);
    pa_assert(keep);

    p = pa_hashmap_iterate(h, &state, &key);
    while (p) {
        if (pa_hashmap_get(keep, p) == NULL)
            pa_hashmap_remove_and_free(h, key);
        p = pa_hashmap_iterate(h, &state, &key);
    }
}

static int add_profiles_to_probe(
        pa_alsa_profile **list,
        pa_hashmap *profiles,
        bool fallback_output,
        bool fallback_input) {

    int i = 0;
    void *state;
    pa_alsa_profile *p;
    PA_HASHMAP_FOREACH(p, profiles, state)
        if (p->fallback_input == fallback_input && p->fallback_output == fallback_output) {
            *list = p;
            list++;
            i++;
        }
    return i;
}

static void mapping_query_hw_device(pa_alsa_mapping *mapping, snd_pcm_t *pcm) {
    int r;
    snd_pcm_info_t* pcm_info;
    snd_pcm_info_alloca(&pcm_info);

    r = snd_pcm_info(pcm, pcm_info);
    if (r < 0) {
        pa_log("Mapping %s: snd_pcm_info() failed %s: ", mapping->name, pa_alsa_strerror(r));
        return;
    }

    /* XXX: It's not clear what snd_pcm_info_get_device() does if the device is
     * not backed by a hw device or if it's backed by multiple hw devices. We
     * only use hw_device_index for HDMI devices, however, and for those the
     * return value is expected to be always valid, so this shouldn't be a
     * significant problem. */
    mapping->hw_device_index = snd_pcm_info_get_device(pcm_info);
}

void pa_alsa_profile_set_probe(
        pa_alsa_profile_set *ps,
        pa_hashmap *mixers,
        const char *dev_id,
        const pa_sample_spec *ss,
        unsigned default_n_fragments,
        unsigned default_fragment_size_msec) {

    bool found_output = false, found_input = false;

    pa_alsa_profile *p, *last = NULL;
    pa_alsa_profile **pp, **probe_order;
    pa_alsa_mapping *m;
    pa_hashmap *broken_inputs, *broken_outputs, *used_paths;
    pa_alsa_mapping *selected_fallback_input = NULL, *selected_fallback_output = NULL;

    pa_assert(ps);
    pa_assert(dev_id);
    pa_assert(ss);

    if (ps->probed)
        return;

    broken_inputs = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
    broken_outputs = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
    used_paths = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
    pp = probe_order = pa_xnew0(pa_alsa_profile *, pa_hashmap_size(ps->profiles) + 1);

    pp += add_profiles_to_probe(pp, ps->profiles, false, false);
    pp += add_profiles_to_probe(pp, ps->profiles, false, true);
    pp += add_profiles_to_probe(pp, ps->profiles, true, false);
    pp += add_profiles_to_probe(pp, ps->profiles, true, true);

    for (pp = probe_order; *pp; pp++) {
        uint32_t idx;
        p = *pp;

        /* Skip if fallback and already found something, but still probe already selected fallbacks.
         * If UCM is used then both fallback_input and fallback_output flags are false.
         * If UCM is not used then there will be only a single entry in mappings.
         */
        if (found_input && p->fallback_input)
            if (selected_fallback_input == NULL || pa_idxset_get_by_index(p->input_mappings, 0) != selected_fallback_input)
                continue;
        if (found_output && p->fallback_output)
            if (selected_fallback_output == NULL || pa_idxset_get_by_index(p->output_mappings, 0) != selected_fallback_output)
                continue;

        /* Skip if this is already marked that it is supported (i.e. from the config file) */
        if (!p->supported) {

            profile_finalize_probing(last, p);
            p->supported = true;

            if (p->output_mappings) {
                PA_IDXSET_FOREACH(m, p->output_mappings, idx) {
                    if (pa_hashmap_get(broken_outputs, m) == m) {
                        pa_log_debug("Skipping profile %s - will not be able to open output:%s", p->name, m->name);
                        p->supported = false;
                        break;
                    }
                }
            }

            if (p->input_mappings && p->supported) {
                PA_IDXSET_FOREACH(m, p->input_mappings, idx) {
                    if (pa_hashmap_get(broken_inputs, m) == m) {
                        pa_log_debug("Skipping profile %s - will not be able to open input:%s", p->name, m->name);
                        p->supported = false;
                        break;
                    }
                }
            }

            if (p->supported)
                pa_log_debug("Looking at profile %s", p->name);

            /* Check if we can open all new ones */
            if (p->output_mappings && p->supported)
                PA_IDXSET_FOREACH(m, p->output_mappings, idx) {

                    if (m->output_pcm)
                        continue;

                    pa_log_debug("Checking for playback on %s (%s)", m->description, m->name);
                    if (!(m->output_pcm = mapping_open_pcm(m, ss, dev_id, m->exact_channels,
                                                           SND_PCM_STREAM_PLAYBACK,
                                                           default_n_fragments,
                                                           default_fragment_size_msec))) {
                        p->supported = false;
                        if (pa_idxset_size(p->output_mappings) == 1 &&
                            ((!p->input_mappings) || pa_idxset_size(p->input_mappings) == 0)) {
                            pa_log_debug("Caching failure to open output:%s", m->name);
                            pa_hashmap_put(broken_outputs, m, m);
                        }
                        break;
                    }

                    if (m->hw_device_index < 0)
                        mapping_query_hw_device(m, m->output_pcm);
                }

            if (p->input_mappings && p->supported)
                PA_IDXSET_FOREACH(m, p->input_mappings, idx) {

                    if (m->input_pcm)
                        continue;

                    pa_log_debug("Checking for recording on %s (%s)", m->description, m->name);
                    if (!(m->input_pcm = mapping_open_pcm(m, ss, dev_id, m->exact_channels,
                                                          SND_PCM_STREAM_CAPTURE,
                                                          default_n_fragments,
                                                          default_fragment_size_msec))) {
                        p->supported = false;
                        if (pa_idxset_size(p->input_mappings) == 1 &&
                            ((!p->output_mappings) || pa_idxset_size(p->output_mappings) == 0)) {
                            pa_log_debug("Caching failure to open input:%s", m->name);
                            pa_hashmap_put(broken_inputs, m, m);
                        }
                        break;
                    }

                    if (m->hw_device_index < 0)
                        mapping_query_hw_device(m, m->input_pcm);
                }

            last = p;

            if (!p->supported)
                continue;
        }

        pa_log_debug("Profile %s supported.", p->name);

        if (p->output_mappings)
            PA_IDXSET_FOREACH(m, p->output_mappings, idx)
                if (m->output_pcm) {
                    found_output = true;
                    if (p->fallback_output && selected_fallback_output == NULL) {
                        selected_fallback_output = m;
                    }
                    mapping_paths_probe(m, p, PA_ALSA_DIRECTION_OUTPUT, used_paths, mixers);
                }

        if (p->input_mappings)
            PA_IDXSET_FOREACH(m, p->input_mappings, idx)
                if (m->input_pcm) {
                    found_input = true;
                    if (p->fallback_input && selected_fallback_input == NULL) {
                        selected_fallback_input = m;
                    }
                    mapping_paths_probe(m, p, PA_ALSA_DIRECTION_INPUT, used_paths, mixers);
                }
    }

    /* Clean up */
    profile_finalize_probing(last, NULL);

    pa_alsa_profile_set_drop_unsupported(ps);

    paths_drop_unused(ps->input_paths, used_paths);
    paths_drop_unused(ps->output_paths, used_paths);
    pa_hashmap_free(broken_inputs);
    pa_hashmap_free(broken_outputs);
    pa_hashmap_free(used_paths);
    pa_xfree(probe_order);

    profile_set_set_availability_groups(ps);

    ps->probed = true;
}

void pa_alsa_profile_set_dump(pa_alsa_profile_set *ps) {
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    pa_alsa_decibel_fix *db_fix;
    void *state;

    pa_assert(ps);

    pa_log_debug("Profile set %p, auto_profiles=%s, probed=%s, n_mappings=%u, n_profiles=%u, n_decibel_fixes=%u",
                 (void*)
                 ps,
                 pa_yes_no(ps->auto_profiles),
                 pa_yes_no(ps->probed),
                 pa_hashmap_size(ps->mappings),
                 pa_hashmap_size(ps->profiles),
                 pa_hashmap_size(ps->decibel_fixes));

    PA_HASHMAP_FOREACH(m, ps->mappings, state)
        pa_alsa_mapping_dump(m);

    PA_HASHMAP_FOREACH(p, ps->profiles, state)
        pa_alsa_profile_dump(p);

    PA_HASHMAP_FOREACH(db_fix, ps->decibel_fixes, state)
        pa_alsa_decibel_fix_dump(db_fix);
}

void pa_alsa_profile_set_drop_unsupported(pa_alsa_profile_set *ps) {
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    void *state;

    PA_HASHMAP_FOREACH(p, ps->profiles, state) {
        if (!p->supported)
            pa_hashmap_remove_and_free(ps->profiles, p->name);
    }

    PA_HASHMAP_FOREACH(m, ps->mappings, state) {
        if (m->supported <= 0)
            pa_hashmap_remove_and_free(ps->mappings, m->name);
    }
}

static pa_device_port* device_port_alsa_init(pa_hashmap *ports, /* card ports */
    const char* name,
    const char* description,
    pa_alsa_path *path,
    pa_alsa_setting *setting,
    pa_card_profile *cp,
    pa_hashmap *extra, /* sink/source ports */
    pa_core *core) {

    pa_device_port *p;

    pa_assert(path);

    p = pa_hashmap_get(ports, name);

    if (!p) {
        pa_alsa_port_data *data;
        pa_device_port_new_data port_data;

        pa_device_port_new_data_init(&port_data);
        pa_device_port_new_data_set_name(&port_data, name);
        pa_device_port_new_data_set_description(&port_data, description);
        pa_device_port_new_data_set_direction(&port_data, path->direction == PA_ALSA_DIRECTION_OUTPUT ? PA_DIRECTION_OUTPUT : PA_DIRECTION_INPUT);
        pa_device_port_new_data_set_type(&port_data, path->device_port_type);
        pa_device_port_new_data_set_availability_group(&port_data, path->availability_group);

        p = pa_device_port_new(core, &port_data, sizeof(pa_alsa_port_data));
        pa_device_port_new_data_done(&port_data);
        pa_assert(p);
        pa_hashmap_put(ports, p->name, p);
        pa_proplist_update(p->proplist, PA_UPDATE_REPLACE, path->proplist);

        data = PA_DEVICE_PORT_DATA(p);
        /* Ownership of the path and setting is not transferred to the port data, so we don't deal with freeing them */
        data->path = path;
        data->setting = setting;
        path->port = p;
    }

    if (cp)
        pa_hashmap_put(p->profiles, cp->name, cp);

    if (extra) {
        pa_hashmap_put(extra, p->name, p);
    }

    return p;
}

void pa_alsa_path_set_add_ports(
        pa_alsa_path_set *ps,
        pa_card_profile *cp,
        pa_hashmap *ports, /* card ports */
        pa_hashmap *extra, /* sink/source ports */
        pa_core *core) {

    pa_alsa_path *path;
    void *state;

    pa_assert(ports);

    if (!ps)
        return;

    PA_HASHMAP_FOREACH(path, ps->paths, state) {
        if (!path->settings || !path->settings->next) {
            /* If there is no or just one setting we only need a
             * single entry */
            pa_device_port *port = device_port_alsa_init(ports, path->name,
                path->description, path, path->settings, cp, extra, core);
            port->priority = path->priority * 100;

        } else {
            pa_alsa_setting *s;
            PA_LLIST_FOREACH(s, path->settings) {
                pa_device_port *port;
                char *n, *d;

                n = pa_sprintf_malloc("%s;%s", path->name, s->name);

                if (s->description[0])
                    d = pa_sprintf_malloc("%s / %s", path->description, s->description);
                else
                    d = pa_xstrdup(path->description);

                port = device_port_alsa_init(ports, n, d, path, s, cp, extra, core);
                port->priority = path->priority * 100 + s->priority;

                pa_xfree(n);
                pa_xfree(d);
            }
        }
    }
}

void pa_alsa_add_ports(pa_hashmap *ports, pa_alsa_path_set *ps, pa_card *card) {
    pa_assert(ps);

    if (ps->paths && pa_hashmap_size(ps->paths) > 0) {
        pa_assert(card);
        pa_alsa_path_set_add_ports(ps, NULL, card->ports, ports, card->core);
    }

    pa_log_debug("Added %u ports", pa_hashmap_size(ports));
}
