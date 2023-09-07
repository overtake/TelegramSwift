/***
 This file is part of PulseAudio.

 Copyright 2011 Wolfson Microelectronics PLC
 Author Margarita Olaya <magi@slimlogic.co.uk>
 Copyright 2012 Feng Wei <wei.feng@freescale.com>, Freescale Ltd.

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

#include <ctype.h>
#include <sys/types.h>
#include <limits.h>
#include <alsa/asoundlib.h>

#ifdef HAVE_VALGRIND_MEMCHECK_H
#include <valgrind/memcheck.h>
#endif

#include "alsa-mixer.h"
#include "alsa-util.h"
#include "alsa-ucm.h"

#define PA_UCM_PRE_TAG_OUTPUT                       "[Out] "
#define PA_UCM_PRE_TAG_INPUT                        "[In] "

#define PA_UCM_PLAYBACK_PRIORITY_UNSET(device)      ((device)->playback_channels && !(device)->playback_priority)
#define PA_UCM_CAPTURE_PRIORITY_UNSET(device)       ((device)->capture_channels && !(device)->capture_priority)
#define PA_UCM_DEVICE_PRIORITY_SET(device, priority) \
    do { \
        if (PA_UCM_PLAYBACK_PRIORITY_UNSET(device)) (device)->playback_priority = (priority);   \
        if (PA_UCM_CAPTURE_PRIORITY_UNSET(device))  (device)->capture_priority = (priority);    \
    } while (0)
#define PA_UCM_IS_MODIFIER_MAPPING(m) ((pa_proplist_gets((m)->proplist, PA_ALSA_PROP_UCM_MODIFIER)) != NULL)

#ifdef HAVE_ALSA_UCM

struct ucm_type {
    const char *prefix;
    pa_device_port_type_t type;
};

struct ucm_items {
    const char *id;
    const char *property;
};

struct ucm_info {
    const char *id;
    unsigned priority;
};

static pa_alsa_jack* ucm_get_jack(pa_alsa_ucm_config *ucm, pa_alsa_ucm_device *device);
static void device_set_jack(pa_alsa_ucm_device *device, pa_alsa_jack *jack);
static void device_add_hw_mute_jack(pa_alsa_ucm_device *device, pa_alsa_jack *jack);

static pa_alsa_ucm_device *verb_find_device(pa_alsa_ucm_verb *verb, const char *device_name);


static void ucm_port_data_init(pa_alsa_ucm_port_data *port, pa_alsa_ucm_config *ucm, pa_device_port *core_port,
                               pa_alsa_ucm_device **devices, unsigned n_devices);
static void ucm_port_data_free(pa_device_port *port);
static void ucm_port_update_available(pa_alsa_ucm_port_data *port);

static struct ucm_type types[] = {
    {"None", PA_DEVICE_PORT_TYPE_UNKNOWN},
    {"Speaker", PA_DEVICE_PORT_TYPE_SPEAKER},
    {"Line", PA_DEVICE_PORT_TYPE_LINE},
    {"Mic", PA_DEVICE_PORT_TYPE_MIC},
    {"Headphones", PA_DEVICE_PORT_TYPE_HEADPHONES},
    {"Headset", PA_DEVICE_PORT_TYPE_HEADSET},
    {"Handset", PA_DEVICE_PORT_TYPE_HANDSET},
    {"Bluetooth", PA_DEVICE_PORT_TYPE_BLUETOOTH},
    {"Earpiece", PA_DEVICE_PORT_TYPE_EARPIECE},
    {"SPDIF", PA_DEVICE_PORT_TYPE_SPDIF},
    {"HDMI", PA_DEVICE_PORT_TYPE_HDMI},
    {NULL, 0}
};

static struct ucm_items item[] = {
    {"PlaybackPCM", PA_ALSA_PROP_UCM_SINK},
    {"CapturePCM", PA_ALSA_PROP_UCM_SOURCE},
    {"PlaybackCTL", PA_ALSA_PROP_UCM_PLAYBACK_CTL_DEVICE},
    {"PlaybackVolume", PA_ALSA_PROP_UCM_PLAYBACK_VOLUME},
    {"PlaybackSwitch", PA_ALSA_PROP_UCM_PLAYBACK_SWITCH},
    {"PlaybackMixer", PA_ALSA_PROP_UCM_PLAYBACK_MIXER_DEVICE},
    {"PlaybackMixerElem", PA_ALSA_PROP_UCM_PLAYBACK_MIXER_ELEM},
    {"PlaybackMasterElem", PA_ALSA_PROP_UCM_PLAYBACK_MASTER_ELEM},
    {"PlaybackMasterType", PA_ALSA_PROP_UCM_PLAYBACK_MASTER_TYPE},
    {"PlaybackPriority", PA_ALSA_PROP_UCM_PLAYBACK_PRIORITY},
    {"PlaybackRate", PA_ALSA_PROP_UCM_PLAYBACK_RATE},
    {"PlaybackChannels", PA_ALSA_PROP_UCM_PLAYBACK_CHANNELS},
    {"CaptureCTL", PA_ALSA_PROP_UCM_CAPTURE_CTL_DEVICE},
    {"CaptureVolume", PA_ALSA_PROP_UCM_CAPTURE_VOLUME},
    {"CaptureSwitch", PA_ALSA_PROP_UCM_CAPTURE_SWITCH},
    {"CaptureMixer", PA_ALSA_PROP_UCM_CAPTURE_MIXER_DEVICE},
    {"CaptureMixerElem", PA_ALSA_PROP_UCM_CAPTURE_MIXER_ELEM},
    {"CaptureMasterElem", PA_ALSA_PROP_UCM_CAPTURE_MASTER_ELEM},
    {"CaptureMasterType", PA_ALSA_PROP_UCM_CAPTURE_MASTER_TYPE},
    {"CapturePriority", PA_ALSA_PROP_UCM_CAPTURE_PRIORITY},
    {"CaptureRate", PA_ALSA_PROP_UCM_CAPTURE_RATE},
    {"CaptureChannels", PA_ALSA_PROP_UCM_CAPTURE_CHANNELS},
    {"TQ", PA_ALSA_PROP_UCM_QOS},
    {"JackCTL", PA_ALSA_PROP_UCM_JACK_DEVICE},
    {"JackControl", PA_ALSA_PROP_UCM_JACK_CONTROL},
    {"JackHWMute", PA_ALSA_PROP_UCM_JACK_HW_MUTE},
    {NULL, NULL},
};

/* UCM verb info - this should eventually be part of policy management */
static struct ucm_info verb_info[] = {
    {SND_USE_CASE_VERB_INACTIVE, 0},
    {SND_USE_CASE_VERB_HIFI, 8000},
    {SND_USE_CASE_VERB_HIFI_LOW_POWER, 7000},
    {SND_USE_CASE_VERB_VOICE, 6000},
    {SND_USE_CASE_VERB_VOICE_LOW_POWER, 5000},
    {SND_USE_CASE_VERB_VOICECALL, 4000},
    {SND_USE_CASE_VERB_IP_VOICECALL, 4000},
    {SND_USE_CASE_VERB_ANALOG_RADIO, 3000},
    {SND_USE_CASE_VERB_DIGITAL_RADIO, 3000},
    {NULL, 0}
};

/* UCM device info - should be overwritten by ucm property */
static struct ucm_info dev_info[] = {
    {SND_USE_CASE_DEV_SPEAKER, 100},
    {SND_USE_CASE_DEV_LINE, 100},
    {SND_USE_CASE_DEV_HEADPHONES, 100},
    {SND_USE_CASE_DEV_HEADSET, 300},
    {SND_USE_CASE_DEV_HANDSET, 200},
    {SND_USE_CASE_DEV_BLUETOOTH, 400},
    {SND_USE_CASE_DEV_EARPIECE, 100},
    {SND_USE_CASE_DEV_SPDIF, 100},
    {SND_USE_CASE_DEV_HDMI, 100},
    {SND_USE_CASE_DEV_NONE, 100},
    {NULL, 0}
};


static char *ucm_verb_value(
    snd_use_case_mgr_t *uc_mgr,
    const char *verb_name,
    const char *id) {

    const char *value;
    char *_id = pa_sprintf_malloc("=%s//%s", id, verb_name);
    int err = snd_use_case_get(uc_mgr, _id, &value);
    pa_xfree(_id);
    if (err < 0)
         return NULL;
    pa_log_debug("Got %s for verb %s: %s", id, verb_name, value);
    /* Use the cast here to allow free() call without casting for callers.
     * The snd_use_case_get() returns mallocated string.
     * See the Note: in use-case.h for snd_use_case_get().
     */
    return (char *)value;
}

static int ucm_device_exists(pa_idxset *idxset, pa_alsa_ucm_device *dev) {
    pa_alsa_ucm_device *d;
    uint32_t idx;

    PA_IDXSET_FOREACH(d, idxset, idx)
        if (d == dev)
            return 1;

    return 0;
}

static void ucm_add_devices_to_idxset(
        pa_idxset *idxset,
        pa_alsa_ucm_device *me,
        pa_alsa_ucm_device *devices,
        const char **dev_names,
        int n) {

    pa_alsa_ucm_device *d;

    PA_LLIST_FOREACH(d, devices) {
        const char *name;
        int i;

        if (d == me)
            continue;

        name = pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_NAME);

        for (i = 0; i < n; i++)
            if (pa_streq(dev_names[i], name))
                pa_idxset_put(idxset, d, NULL);
    }
}

/* Split a string into words. Like pa_split_spaces() but handle '' and "". */
static char *ucm_split_devnames(const char *c, const char **state) {
    const char *current = *state ? *state : c;
    char h;
    size_t l;

    if (!*current || *c == 0)
        return NULL;

    current += strspn(current, "\n\r \t");
    h = *current;
    if (h == '\'' || h =='"') {
        c = ++current;
        for (l = 0; *c && *c != h; l++) c++;
        if (*c != h)
            return NULL;
        *state = c + 1;
    } else {
        l = strcspn(current, "\n\r \t");
        *state = current+l;
    }

    return pa_xstrndup(current, l);
}


static void ucm_volume_free(pa_alsa_ucm_volume *vol) {
    pa_assert(vol);
    pa_xfree(vol->mixer_elem);
    pa_xfree(vol->master_elem);
    pa_xfree(vol->master_type);
    pa_xfree(vol);
}

/* Get the volume identifier */
static char *ucm_get_mixer_id(
        pa_alsa_ucm_device *device,
        const char *mprop,
        const char *cprop,
        const char *cid)
{
#if SND_LIB_VERSION >= 0x10201 /* alsa-lib-1.2.1+ check */
    snd_ctl_elem_id_t *ctl;
    int err;
#endif
    const char *value;
    char *value2;
    int index;

    /* mixer element as first, if it's found, return it without modifications */
    value = pa_proplist_gets(device->proplist, mprop);
    if (value)
        return pa_xstrdup(value);
    /* fallback, get the control element identifier */
    /* and try to do some heuristic to determine the mixer element name */
    value = pa_proplist_gets(device->proplist, cprop);
    if (value == NULL)
        return NULL;
#if SND_LIB_VERSION >= 0x10201 /* alsa-lib-1.2.1+ check */
    /* The new parser may return also element index. */
    snd_ctl_elem_id_alloca(&ctl);
    err = snd_use_case_parse_ctl_elem_id(ctl, cid, value);
    if (err < 0)
        return NULL;
    value = snd_ctl_elem_id_get_name(ctl);
    index = snd_ctl_elem_id_get_index(ctl);
#else
#warning "Upgrade to alsa-lib 1.2.1!"
    index = 0;
#endif
    if (!(value2 = pa_str_strip_suffix(value, " Playback Volume")))
        if (!(value2 = pa_str_strip_suffix(value, " Capture Volume")))
            if (!(value2 = pa_str_strip_suffix(value, " Volume")))
                value2 = pa_xstrdup(value);
    if (index > 0) {
        char *mix = pa_sprintf_malloc("'%s',%d", value2, index);
        pa_xfree(value2);
        return mix;
    }
    return value2;
}

/* Get the volume identifier */
static pa_alsa_ucm_volume *ucm_get_mixer_volume(
        pa_alsa_ucm_device *device,
        const char *mprop,
        const char *cprop,
        const char *cid,
        const char *masterid,
        const char *mastertype)
{
    pa_alsa_ucm_volume *vol;
    char *mixer_elem;

    mixer_elem = ucm_get_mixer_id(device, mprop, cprop, cid);
    if (mixer_elem == NULL)
        return NULL;
    vol = pa_xnew0(pa_alsa_ucm_volume, 1);
    if (vol == NULL) {
        pa_xfree(mixer_elem);
        return NULL;
    }
    vol->mixer_elem = mixer_elem;
    vol->master_elem = pa_xstrdup(pa_proplist_gets(device->proplist, masterid));
    vol->master_type = pa_xstrdup(pa_proplist_gets(device->proplist, mastertype));
    return vol;
}

/* Get the ALSA mixer device for the UCM device */
static const char *get_mixer_device(pa_alsa_ucm_device *dev, bool is_sink)
{
    const char *dev_name;

    if (is_sink) {
        dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_PLAYBACK_MIXER_DEVICE);
        if (!dev_name)
            dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_PLAYBACK_CTL_DEVICE);
    } else {
        dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_CAPTURE_MIXER_DEVICE);
        if (!dev_name)
            dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_CAPTURE_CTL_DEVICE);
    }
    return dev_name;
}

/* Get the ALSA mixer device for the UCM jack */
static const char *get_jack_mixer_device(pa_alsa_ucm_device *dev, bool is_sink) {
    const char *dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_JACK_DEVICE);
    if (!dev_name)
        return get_mixer_device(dev, is_sink);
    return dev_name;
}

/* Create a property list for this ucm device */
static int ucm_get_device_property(
        pa_alsa_ucm_device *device,
        snd_use_case_mgr_t *uc_mgr,
        pa_alsa_ucm_verb *verb,
        const char *device_name) {

    const char *value;
    const char **devices;
    char *id, *s;
    int i;
    int err;
    uint32_t ui;
    int n_confdev, n_suppdev;
    pa_alsa_ucm_volume *vol;

    /* determine the device type */
    device->type = PA_DEVICE_PORT_TYPE_UNKNOWN;
    id = s = pa_xstrdup(device_name);
    while (s && *s && isalpha(*s)) s++;
    if (s)
        *s = '\0';
    for (i = 0; types[i].prefix; i++)
        if (pa_streq(id, types[i].prefix)) {
            device->type = types[i].type;
            break;
        }
    pa_xfree(id);

    /* set properties */
    for (i = 0; item[i].id; i++) {
        id = pa_sprintf_malloc("%s/%s", item[i].id, device_name);
        err = snd_use_case_get(uc_mgr, id, &value);
        pa_xfree(id);
        if (err < 0)
            continue;

        pa_log_debug("Got %s for device %s: %s", item[i].id, device_name, value);
        pa_proplist_sets(device->proplist, item[i].property, value);
        free((void*)value);
    }

    /* get direction and channels */
    value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_PLAYBACK_CHANNELS);
    if (value) { /* output */
        /* get channels */
        if (pa_atou(value, &ui) == 0 && pa_channels_valid(ui))
            device->playback_channels = ui;
        else
            pa_log("UCM playback channels %s for device %s out of range", value, device_name);

        /* get pcm */
        value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_SINK);
        if (!value) /* take pcm from verb playback default */
            pa_log("UCM playback device %s fetch pcm failed", device_name);
    }

    if (pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_SINK) &&
        device->playback_channels == 0) {
        pa_log_info("UCM file does not specify 'PlaybackChannels' "
                    "for device %s, assuming stereo.", device_name);
        device->playback_channels = 2;
    }

    value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_CAPTURE_CHANNELS);
    if (value) { /* input */
        /* get channels */
        if (pa_atou(value, &ui) == 0 && pa_channels_valid(ui))
            device->capture_channels = ui;
        else
            pa_log("UCM capture channels %s for device %s out of range", value, device_name);

        /* get pcm */
        value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_SOURCE);
        if (!value) /* take pcm from verb capture default */
            pa_log("UCM capture device %s fetch pcm failed", device_name);
    }

    if (pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_SOURCE) &&
        device->capture_channels == 0) {
        pa_log_info("UCM file does not specify 'CaptureChannels' "
                    "for device %s, assuming stereo.", device_name);
        device->capture_channels = 2;
    }

    /* get rate and priority of device */
    if (device->playback_channels) { /* sink device */
        /* get rate */
        if ((value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_PLAYBACK_RATE))) {
            if (pa_atou(value, &ui) == 0 && pa_sample_rate_valid(ui)) {
                pa_log_debug("UCM playback device %s rate %d", device_name, ui);
                device->playback_rate = ui;
            } else
                pa_log_debug("UCM playback device %s has bad rate %s", device_name, value);
        }

        value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_PLAYBACK_PRIORITY);
        if (value) {
            /* get priority from ucm config */
            if (pa_atou(value, &ui) == 0)
                device->playback_priority = ui;
            else
                pa_log_debug("UCM playback priority %s for device %s error", value, device_name);
        }

        vol = ucm_get_mixer_volume(device,
                                   PA_ALSA_PROP_UCM_PLAYBACK_MIXER_ELEM,
                                   PA_ALSA_PROP_UCM_PLAYBACK_VOLUME,
                                   "PlaybackVolume",
                                   PA_ALSA_PROP_UCM_PLAYBACK_MASTER_ELEM,
                                   PA_ALSA_PROP_UCM_PLAYBACK_MASTER_TYPE);
        if (vol)
            pa_hashmap_put(device->playback_volumes, pa_xstrdup(pa_proplist_gets(verb->proplist, PA_ALSA_PROP_UCM_NAME)), vol);
    }

    if (device->capture_channels) { /* source device */
        /* get rate */
        if ((value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_CAPTURE_RATE))) {
            if (pa_atou(value, &ui) == 0 && pa_sample_rate_valid(ui)) {
                pa_log_debug("UCM capture device %s rate %d", device_name, ui);
                device->capture_rate = ui;
            } else
                pa_log_debug("UCM capture device %s has bad rate %s", device_name, value);
        }

        value = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_CAPTURE_PRIORITY);
        if (value) {
            /* get priority from ucm config */
            if (pa_atou(value, &ui) == 0)
                device->capture_priority = ui;
            else
                pa_log_debug("UCM capture priority %s for device %s error", value, device_name);
        }

        vol = ucm_get_mixer_volume(device,
                                   PA_ALSA_PROP_UCM_CAPTURE_MIXER_ELEM,
                                   PA_ALSA_PROP_UCM_CAPTURE_VOLUME,
                                   "CaptureVolume",
                                   PA_ALSA_PROP_UCM_CAPTURE_MASTER_ELEM,
                                   PA_ALSA_PROP_UCM_CAPTURE_MASTER_TYPE);
        if (vol)
          pa_hashmap_put(device->capture_volumes, pa_xstrdup(pa_proplist_gets(verb->proplist, PA_ALSA_PROP_UCM_NAME)), vol);
    }

    if (PA_UCM_PLAYBACK_PRIORITY_UNSET(device) || PA_UCM_CAPTURE_PRIORITY_UNSET(device)) {
        /* get priority from static table */
        for (i = 0; dev_info[i].id; i++) {
            if (strcasecmp(dev_info[i].id, device_name) == 0) {
                PA_UCM_DEVICE_PRIORITY_SET(device, dev_info[i].priority);
                break;
            }
        }
    }

    if (PA_UCM_PLAYBACK_PRIORITY_UNSET(device)) {
        /* fall through to default priority */
        device->playback_priority = 100;
    }

    if (PA_UCM_CAPTURE_PRIORITY_UNSET(device)) {
        /* fall through to default priority */
        device->capture_priority = 100;
    }

    id = pa_sprintf_malloc("%s/%s", "_conflictingdevs", device_name);
    n_confdev = snd_use_case_get_list(uc_mgr, id, &devices);
    pa_xfree(id);

    if (n_confdev <= 0)
        pa_log_debug("No %s for device %s", "_conflictingdevs", device_name);
    else {
        device->conflicting_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        ucm_add_devices_to_idxset(device->conflicting_devices, device, verb->devices, devices, n_confdev);
        snd_use_case_free_list(devices, n_confdev);
    }

    id = pa_sprintf_malloc("%s/%s", "_supporteddevs", device_name);
    n_suppdev = snd_use_case_get_list(uc_mgr, id, &devices);
    pa_xfree(id);

    if (n_suppdev <= 0)
        pa_log_debug("No %s for device %s", "_supporteddevs", device_name);
    else {
        device->supported_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        ucm_add_devices_to_idxset(device->supported_devices, device, verb->devices, devices, n_suppdev);
        snd_use_case_free_list(devices, n_suppdev);
    }

    return 0;
};

/* Create a property list for this ucm modifier */
static int ucm_get_modifier_property(pa_alsa_ucm_modifier *modifier, snd_use_case_mgr_t *uc_mgr, const char *modifier_name) {
    const char *value;
    char *id;
    int i;

    for (i = 0; item[i].id; i++) {
        int err;

        id = pa_sprintf_malloc("=%s/%s", item[i].id, modifier_name);
        err = snd_use_case_get(uc_mgr, id, &value);
        pa_xfree(id);
        if (err < 0)
            continue;

        pa_log_debug("Got %s for modifier %s: %s", item[i].id, modifier_name, value);
        pa_proplist_sets(modifier->proplist, item[i].property, value);
        free((void*)value);
    }

    id = pa_sprintf_malloc("%s/%s", "_conflictingdevs", modifier_name);
    modifier->n_confdev = snd_use_case_get_list(uc_mgr, id, &modifier->conflicting_devices);
    pa_xfree(id);
    if (modifier->n_confdev < 0)
        pa_log_debug("No %s for modifier %s", "_conflictingdevs", modifier_name);

    id = pa_sprintf_malloc("%s/%s", "_supporteddevs", modifier_name);
    modifier->n_suppdev = snd_use_case_get_list(uc_mgr, id, &modifier->supported_devices);
    pa_xfree(id);
    if (modifier->n_suppdev < 0)
        pa_log_debug("No %s for modifier %s", "_supporteddevs", modifier_name);

    return 0;
};

/* Create a list of devices for this verb */
static int ucm_get_devices(pa_alsa_ucm_verb *verb, snd_use_case_mgr_t *uc_mgr) {
    const char **dev_list;
    int num_dev, i;

    num_dev = snd_use_case_get_list(uc_mgr, "_devices", &dev_list);
    if (num_dev < 0)
        return num_dev;

    for (i = 0; i < num_dev; i += 2) {
        pa_alsa_ucm_device *d = pa_xnew0(pa_alsa_ucm_device, 1);

        d->proplist = pa_proplist_new();
        pa_proplist_sets(d->proplist, PA_ALSA_PROP_UCM_NAME, pa_strnull(dev_list[i]));
        pa_proplist_sets(d->proplist, PA_ALSA_PROP_UCM_DESCRIPTION, pa_strna(dev_list[i + 1]));
        d->ucm_ports = pa_dynarray_new(NULL);
        d->hw_mute_jacks = pa_dynarray_new(NULL);
        d->available = PA_AVAILABLE_UNKNOWN;

        d->playback_volumes = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, pa_xfree,
                                                  (pa_free_cb_t) ucm_volume_free);
        d->capture_volumes = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, pa_xfree,
                                                 (pa_free_cb_t) ucm_volume_free);

        PA_LLIST_PREPEND(pa_alsa_ucm_device, verb->devices, d);
    }

    snd_use_case_free_list(dev_list, num_dev);

    return 0;
};

static int ucm_get_modifiers(pa_alsa_ucm_verb *verb, snd_use_case_mgr_t *uc_mgr) {
    const char **mod_list;
    int num_mod, i;

    num_mod = snd_use_case_get_list(uc_mgr, "_modifiers", &mod_list);
    if (num_mod < 0)
        return num_mod;

    for (i = 0; i < num_mod; i += 2) {
        pa_alsa_ucm_modifier *m;

        if (!mod_list[i]) {
            pa_log_warn("Got a modifier with a null name. Skipping.");
            continue;
        }

        m = pa_xnew0(pa_alsa_ucm_modifier, 1);
        m->proplist = pa_proplist_new();

        pa_proplist_sets(m->proplist, PA_ALSA_PROP_UCM_NAME, mod_list[i]);
        pa_proplist_sets(m->proplist, PA_ALSA_PROP_UCM_DESCRIPTION, pa_strna(mod_list[i + 1]));

        PA_LLIST_PREPEND(pa_alsa_ucm_modifier, verb->modifiers, m);
    }

    snd_use_case_free_list(mod_list, num_mod);

    return 0;
};

static void add_role_to_device(pa_alsa_ucm_device *dev, const char *dev_name, const char *role_name, const char *role) {
    const char *cur = pa_proplist_gets(dev->proplist, role_name);

    if (!cur)
        pa_proplist_sets(dev->proplist, role_name, role);
    else if (!pa_str_in_list_spaces(cur, role)) { /* does not exist */
        char *value = pa_sprintf_malloc("%s %s", cur, role);

        pa_proplist_sets(dev->proplist, role_name, value);
        pa_xfree(value);
    }

    pa_log_info("Add role %s to device %s(%s), result %s", role, dev_name, role_name, pa_proplist_gets(dev->proplist,
                role_name));
}

static void add_media_role(const char *name, pa_alsa_ucm_device *list, const char *role_name, const char *role, bool is_sink) {
    pa_alsa_ucm_device *d;

    PA_LLIST_FOREACH(d, list) {
        const char *dev_name = pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_NAME);

        if (pa_streq(dev_name, name)) {
            const char *sink = pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_SINK);
            const char *source = pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_SOURCE);

            if (is_sink && sink)
                add_role_to_device(d, dev_name, role_name, role);
            else if (!is_sink && source)
                add_role_to_device(d, dev_name, role_name, role);
            break;
        }
    }
}

static char *modifier_name_to_role(const char *mod_name, bool *is_sink) {
    char *sub = NULL, *tmp;

    *is_sink = false;

    if (pa_startswith(mod_name, "Play")) {
        *is_sink = true;
        sub = pa_xstrdup(mod_name + 4);
    } else if (pa_startswith(mod_name, "Capture"))
        sub = pa_xstrdup(mod_name + 7);

    if (!sub || !*sub) {
        pa_xfree(sub);
        pa_log_warn("Can't match media roles for modifier %s", mod_name);
        return NULL;
    }

    tmp = sub;

    do {
        *tmp = tolower(*tmp);
    } while (*(++tmp));

    return sub;
}

static void ucm_set_media_roles(pa_alsa_ucm_modifier *modifier, pa_alsa_ucm_device *list, const char *mod_name) {
    int i;
    bool is_sink = false;
    char *sub = NULL;
    const char *role_name;

    sub = modifier_name_to_role(mod_name, &is_sink);
    if (!sub)
        return;

    modifier->action_direction = is_sink ? PA_DIRECTION_OUTPUT : PA_DIRECTION_INPUT;
    modifier->media_role = sub;

    role_name = is_sink ? PA_ALSA_PROP_UCM_PLAYBACK_ROLES : PA_ALSA_PROP_UCM_CAPTURE_ROLES;
    for (i = 0; i < modifier->n_suppdev; i++) {
        /* if modifier has no specific pcm, we add role intent to its supported devices */
        if (!pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_SINK) &&
                !pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_SOURCE))
            add_media_role(modifier->supported_devices[i], list, role_name, sub, is_sink);
    }
}

static void append_lost_relationship(pa_alsa_ucm_device *dev) {
    uint32_t idx;
    pa_alsa_ucm_device *d;

    if (dev->conflicting_devices) {
        PA_IDXSET_FOREACH(d, dev->conflicting_devices, idx) {
            if (!d->conflicting_devices)
                d->conflicting_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

            if (pa_idxset_put(d->conflicting_devices, dev, NULL) == 0)
                pa_log_warn("Add lost conflicting device %s to %s",
                        pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME),
                        pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_NAME));
        }
    }

    if (dev->supported_devices) {
        PA_IDXSET_FOREACH(d, dev->supported_devices, idx) {
            if (!d->supported_devices)
                d->supported_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

            if (pa_idxset_put(d->supported_devices, dev, NULL) == 0)
                pa_log_warn("Add lost supported device %s to %s",
                        pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME),
                        pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_NAME));
        }
    }
}

int pa_alsa_ucm_query_profiles(pa_alsa_ucm_config *ucm, int card_index) {
    char *card_name;
    const char **verb_list, *value;
    int num_verbs, i, err = 0;

    /* support multiple card instances, address card directly by index */
    card_name = pa_sprintf_malloc("hw:%i", card_index);
    if (card_name == NULL)
        return -PA_ALSA_ERR_UNSPECIFIED;
    err = snd_use_case_mgr_open(&ucm->ucm_mgr, card_name);
    if (err < 0) {
        /* fallback longname: is UCM available for this card ? */
        pa_xfree(card_name);
        err = snd_card_get_name(card_index, &card_name);
        if (err < 0) {
            pa_log("Card can't get card_name from card_index %d", card_index);
            err = -PA_ALSA_ERR_UNSPECIFIED;
            goto name_fail;
        }

        err = snd_use_case_mgr_open(&ucm->ucm_mgr, card_name);
        if (err < 0) {
            pa_log_info("UCM not available for card %s", card_name);
            err = -PA_ALSA_ERR_UCM_OPEN;
            goto ucm_mgr_fail;
        }
    }

    err = snd_use_case_get(ucm->ucm_mgr, "=Linked", &value);
    if (err >= 0) {
        if (strcasecmp(value, "true") == 0 || strcasecmp(value, "1") == 0) {
            free((void *)value);
            pa_log_info("Empty (linked) UCM for card %s", card_name);
            err = -PA_ALSA_ERR_UCM_LINKED;
            goto ucm_verb_fail;
        }
        free((void *)value);
    }

    pa_log_info("UCM available for card %s", card_name);

    /* get a list of all UCM verbs (profiles) for this card */
    num_verbs = snd_use_case_verb_list(ucm->ucm_mgr, &verb_list);
    if (num_verbs < 0) {
        pa_log("UCM verb list not found for %s", card_name);
        err = -PA_ALSA_ERR_UNSPECIFIED;
        goto ucm_verb_fail;
    }

    /* get the properties of each UCM verb */
    for (i = 0; i < num_verbs; i += 2) {
        pa_alsa_ucm_verb *verb;

        /* Get devices and modifiers for each verb */
        err = pa_alsa_ucm_get_verb(ucm->ucm_mgr, verb_list[i], verb_list[i+1], &verb);
        if (err < 0) {
            pa_log("Failed to get the verb %s", verb_list[i]);
            continue;
        }

        PA_LLIST_PREPEND(pa_alsa_ucm_verb, ucm->verbs, verb);
    }

    if (!ucm->verbs) {
        pa_log("No UCM verb is valid for %s", card_name);
        err = -PA_ALSA_ERR_UCM_NO_VERB;
    }

    snd_use_case_free_list(verb_list, num_verbs);

ucm_verb_fail:
    if (err < 0) {
        snd_use_case_mgr_close(ucm->ucm_mgr);
        ucm->ucm_mgr = NULL;
    }

ucm_mgr_fail:
    pa_xfree(card_name);

name_fail:
    return err;
}

int pa_alsa_ucm_get_verb(snd_use_case_mgr_t *uc_mgr, const char *verb_name, const char *verb_desc, pa_alsa_ucm_verb **p_verb) {
    pa_alsa_ucm_device *d;
    pa_alsa_ucm_modifier *mod;
    pa_alsa_ucm_verb *verb;
    char *value;
    unsigned ui;
    int err = 0;

    *p_verb = NULL;
    pa_log_info("Set UCM verb to %s", verb_name);
    err = snd_use_case_set(uc_mgr, "_verb", verb_name);
    if (err < 0)
        return err;

    verb = pa_xnew0(pa_alsa_ucm_verb, 1);
    verb->proplist = pa_proplist_new();

    pa_proplist_sets(verb->proplist, PA_ALSA_PROP_UCM_NAME, pa_strnull(verb_name));
    pa_proplist_sets(verb->proplist, PA_ALSA_PROP_UCM_DESCRIPTION, pa_strna(verb_desc));

    value = ucm_verb_value(uc_mgr, verb_name, "Priority");
    if (value && !pa_atou(value, &ui))
        verb->priority = ui > 10000 ? 10000 : ui;
    free(value);

    err = ucm_get_devices(verb, uc_mgr);
    if (err < 0)
        pa_log("No UCM devices for verb %s", verb_name);

    err = ucm_get_modifiers(verb, uc_mgr);
    if (err < 0)
        pa_log("No UCM modifiers for verb %s", verb_name);

    PA_LLIST_FOREACH(d, verb->devices) {
        const char *dev_name = pa_proplist_gets(d->proplist, PA_ALSA_PROP_UCM_NAME);

        /* Devices properties */
        ucm_get_device_property(d, uc_mgr, verb, dev_name);
    }
    /* make conflicting or supported device mutual */
    PA_LLIST_FOREACH(d, verb->devices)
        append_lost_relationship(d);

    PA_LLIST_FOREACH(mod, verb->modifiers) {
        const char *mod_name = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_NAME);

        /* Modifier properties */
        ucm_get_modifier_property(mod, uc_mgr, mod_name);

        /* Set PA_PROP_DEVICE_INTENDED_ROLES property to devices */
        pa_log_debug("Set media roles for verb %s, modifier %s", verb_name, mod_name);
        ucm_set_media_roles(mod, verb->devices, mod_name);
    }

    *p_verb = verb;
    return 0;
}

static int pa_alsa_ucm_device_cmp(const void *a, const void *b) {
    const pa_alsa_ucm_device *d1 = *(pa_alsa_ucm_device **)a;
    const pa_alsa_ucm_device *d2 = *(pa_alsa_ucm_device **)b;

    return strcmp(pa_proplist_gets(d1->proplist, PA_ALSA_PROP_UCM_NAME), pa_proplist_gets(d2->proplist, PA_ALSA_PROP_UCM_NAME));
}

static void set_eld_devices(pa_hashmap *hash)
{
    pa_device_port *port;
    pa_alsa_ucm_port_data *data;
    pa_alsa_ucm_device *dev;
    const char *eld_mixer_device_name;
    void *state;
    int idx, eld_device;

    PA_HASHMAP_FOREACH(port, hash, state) {
        data = PA_DEVICE_PORT_DATA(port);
        eld_mixer_device_name = NULL;
        eld_device = -1;
        PA_DYNARRAY_FOREACH(dev, data->devices, idx) {
            if (dev->eld_device >= 0 && dev->eld_mixer_device_name) {
                if (eld_device >= 0 && eld_device != dev->eld_device) {
                    pa_log_error("The ELD device is already set!");
                } else if (eld_mixer_device_name && pa_streq(dev->eld_mixer_device_name, eld_mixer_device_name)) {
                    pa_log_error("The ELD mixer device is already set (%s, %s)!", dev->eld_mixer_device_name, dev->eld_mixer_device_name);
                } else {
                    eld_mixer_device_name = dev->eld_mixer_device_name;
                    eld_device = dev->eld_device;
                }
            }
        }
        data->eld_device = eld_device;
        data->eld_mixer_device_name = pa_xstrdup(eld_mixer_device_name);
    }
}

static void probe_volumes(pa_hashmap *hash, bool is_sink, snd_pcm_t *pcm_handle, pa_hashmap *mixers, bool ignore_dB) {
    pa_device_port *port;
    pa_alsa_path *path;
    pa_alsa_ucm_port_data *data;
    pa_alsa_ucm_device *dev;
    snd_mixer_t *mixer_handle;
    const char *profile, *mdev, *mdev2;
    void *state, *state2;
    int idx;

    PA_HASHMAP_FOREACH(port, hash, state) {
        data = PA_DEVICE_PORT_DATA(port);

        mdev = NULL;
        PA_DYNARRAY_FOREACH(dev, data->devices, idx) {
            mdev2 = get_mixer_device(dev, is_sink);
            if (mdev && mdev2 && !pa_streq(mdev, mdev2)) {
                pa_log_error("Two mixer device names found ('%s', '%s'), using s/w volume", mdev, mdev2);
                goto fail;
            }
            if (mdev2)
                mdev = mdev2;
        }

        if (mdev == NULL || !(mixer_handle = pa_alsa_open_mixer_by_name(mixers, mdev, true))) {
            pa_log_error("Failed to find a working mixer device (%s).", mdev);
            goto fail;
        }

        PA_HASHMAP_FOREACH_KV(profile, path, data->paths, state2) {
            if (pa_alsa_path_probe(path, NULL, mixer_handle, ignore_dB) < 0) {
                pa_log_warn("Could not probe path: %s, using s/w volume", path->name);
                pa_hashmap_remove(data->paths, profile);
            } else if (!path->has_volume) {
                pa_log_warn("Path %s is not a volume control", path->name);
                pa_hashmap_remove(data->paths, profile);
            } else
                pa_log_debug("Set up h/w volume using '%s' for %s:%s", path->name, profile, port->name);
        }
    }

    return;

fail:
    /* We could not probe the paths we created. Free them and revert to software volumes. */
    PA_HASHMAP_FOREACH(port, hash, state) {
        data = PA_DEVICE_PORT_DATA(port);
        pa_hashmap_remove_all(data->paths);
    }
}

static void ucm_add_port_combination(
        pa_hashmap *hash,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_alsa_ucm_device **pdevices,
        int num,
        pa_hashmap *ports,
        pa_card_profile *cp,
        pa_core *core) {

    pa_device_port *port;
    int i;
    unsigned priority;
    double prio2;
    char *name, *desc;
    const char *dev_name;
    const char *direction;
    const char *profile;
    pa_alsa_ucm_device *sorted[num], *dev;
    pa_alsa_ucm_port_data *data;
    pa_alsa_ucm_volume *vol;
    pa_alsa_jack *jack, *jack2;
    pa_device_port_type_t type, type2;
    void *state;

    for (i = 0; i < num; i++)
        sorted[i] = pdevices[i];

    /* Sort by alphabetical order so as to have a deterministic naming scheme
     * for combination ports */
    qsort(&sorted[0], num, sizeof(pa_alsa_ucm_device *), pa_alsa_ucm_device_cmp);

    dev = sorted[0];
    dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME);

    name = pa_sprintf_malloc("%s%s", is_sink ? PA_UCM_PRE_TAG_OUTPUT : PA_UCM_PRE_TAG_INPUT, dev_name);
    desc = num == 1 ? pa_xstrdup(pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_DESCRIPTION))
            : pa_sprintf_malloc("Combination port for %s", dev_name);

    priority = is_sink ? dev->playback_priority : dev->capture_priority;
    prio2 = (priority == 0 ? 0 : 1.0/priority);
    jack = ucm_get_jack(context->ucm, dev);
    type = dev->type;

    for (i = 1; i < num; i++) {
        char *tmp;

        dev = sorted[i];
        dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME);

        tmp = pa_sprintf_malloc("%s+%s", name, dev_name);
        pa_xfree(name);
        name = tmp;

        tmp = pa_sprintf_malloc("%s,%s", desc, dev_name);
        pa_xfree(desc);
        desc = tmp;

        priority = is_sink ? dev->playback_priority : dev->capture_priority;
        if (priority != 0 && prio2 > 0)
            prio2 += 1.0/priority;

        jack2 = ucm_get_jack(context->ucm, dev);
        if (jack2) {
            if (jack && jack != jack2)
                pa_log_warn("Multiple jacks per combined device '%s': '%s' '%s'", name, jack->name, jack2->name);
            jack = jack2;
        }

        type2 = dev->type;
        if (type2 != PA_DEVICE_PORT_TYPE_UNKNOWN) {
            if (type != PA_DEVICE_PORT_TYPE_UNKNOWN && type != type2)
                pa_log_warn("Multiple device types per combined device '%s': %d %d", name, type, type2);
            type = type2;
        }
    }

    /* Make combination ports always have lower priority, and use the formula
       1/p = 1/p1 + 1/p2 + ... 1/pn.
       This way, the result will always be less than the individual components,
       yet higher components will lead to higher result. */

    if (num > 1)
        priority = prio2 > 0 ? 1.0/prio2 : 0;

    port = pa_hashmap_get(ports, name);
    if (!port) {
        pa_device_port_new_data port_data;

        pa_device_port_new_data_init(&port_data);
        pa_device_port_new_data_set_name(&port_data, name);
        pa_device_port_new_data_set_description(&port_data, desc);
        pa_device_port_new_data_set_type(&port_data, type);
        pa_device_port_new_data_set_direction(&port_data, is_sink ? PA_DIRECTION_OUTPUT : PA_DIRECTION_INPUT);
        if (jack)
            pa_device_port_new_data_set_availability_group(&port_data, jack->name);

        port = pa_device_port_new(core, &port_data, sizeof(pa_alsa_ucm_port_data));
        pa_device_port_new_data_done(&port_data);

        data = PA_DEVICE_PORT_DATA(port);
        ucm_port_data_init(data, context->ucm, port, pdevices, num);
        port->impl_free = ucm_port_data_free;

        pa_hashmap_put(ports, port->name, port);
        pa_log_debug("Add port %s: %s", port->name, port->description);

        if (num == 1) {
            /* To keep things simple and not worry about stacking controls, we only support hardware volumes on non-combination
             * ports. */
            data = PA_DEVICE_PORT_DATA(port);

            PA_HASHMAP_FOREACH_KV(profile, vol, is_sink ? dev->playback_volumes : dev->capture_volumes, state) {
                pa_alsa_path *path = pa_alsa_path_synthesize(vol->mixer_elem,
                                                             is_sink ? PA_ALSA_DIRECTION_OUTPUT : PA_ALSA_DIRECTION_INPUT);

                if (!path)
                    pa_log_warn("Failed to set up volume control: %s", vol->mixer_elem);
                else {
                    if (vol->master_elem) {
                        pa_alsa_element *e = pa_alsa_element_get(path, vol->master_elem, false);
                        e->switch_use = PA_ALSA_SWITCH_MUTE;
                        e->volume_use = PA_ALSA_VOLUME_MERGE;
                    }

                    pa_hashmap_put(data->paths, pa_xstrdup(profile), path);

                    /* Add path also to already created empty path set */
                    dev = sorted[0];
                    if (is_sink)
                        pa_hashmap_put(dev->playback_mapping->output_path_set->paths, pa_xstrdup(vol->mixer_elem), path);
                    else
                        pa_hashmap_put(dev->capture_mapping->input_path_set->paths, pa_xstrdup(vol->mixer_elem), path);
                }
            }
        }
    }

    port->priority = priority;

    pa_xfree(name);
    pa_xfree(desc);

    direction = is_sink ? "output" : "input";
    pa_log_debug("Port %s direction %s, priority %d", port->name, direction, priority);

    if (cp) {
        pa_log_debug("Adding profile %s to port %s.", cp->name, port->name);
        pa_hashmap_put(port->profiles, cp->name, cp);
    }

    if (hash) {
        pa_hashmap_put(hash, port->name, port);
    }
}

static int ucm_port_contains(const char *port_name, const char *dev_name, bool is_sink) {
    int ret = 0;
    const char *r;
    const char *state = NULL;
    size_t len;

    if (!port_name || !dev_name)
        return false;

    port_name += is_sink ? strlen(PA_UCM_PRE_TAG_OUTPUT) : strlen(PA_UCM_PRE_TAG_INPUT);

    while ((r = pa_split_in_place(port_name, "+", &len, &state))) {
        if (strlen(dev_name) == len && !strncmp(r, dev_name, len)) {
            ret = 1;
            break;
        }
    }

    return ret;
}

static int ucm_check_conformance(
        pa_alsa_ucm_mapping_context *context,
        pa_alsa_ucm_device **pdevices,
        int dev_num,
        pa_alsa_ucm_device *dev) {

    uint32_t idx;
    pa_alsa_ucm_device *d;
    int i;

    pa_assert(dev);

    pa_log_debug("Check device %s conformance with %d other devices",
            pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME), dev_num);
    if (dev_num == 0) {
        pa_log_debug("First device in combination, number 1");
        return 1;
    }

    if (dev->conflicting_devices) { /* the device defines conflicting devices */
        PA_IDXSET_FOREACH(d, dev->conflicting_devices, idx) {
            for (i = 0; i < dev_num; i++) {
                if (pdevices[i] == d) {
                    pa_log_debug("Conflicting device found");
                    return 0;
                }
            }
        }
    } else if (dev->supported_devices) { /* the device defines supported devices */
        for (i = 0; i < dev_num; i++) {
            if (!ucm_device_exists(dev->supported_devices, pdevices[i])) {
                pa_log_debug("Supported device not found");
                return 0;
            }
        }
    } else { /* not support any other devices */
        pa_log_debug("Not support any other devices");
        return 0;
    }

    pa_log_debug("Device added to combination, number %d", dev_num + 1);
    return 1;
}

static inline pa_alsa_ucm_device *get_next_device(pa_idxset *idxset, uint32_t *idx) {
    pa_alsa_ucm_device *dev;

    if (*idx == PA_IDXSET_INVALID)
        dev = pa_idxset_first(idxset, idx);
    else
        dev = pa_idxset_next(idxset, idx);

    return dev;
}

static void ucm_add_ports_combination(
        pa_hashmap *hash,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_alsa_ucm_device **pdevices,
        int dev_num,
        uint32_t map_index,
        pa_hashmap *ports,
        pa_card_profile *cp,
        pa_core *core) {

    pa_alsa_ucm_device *dev;
    uint32_t idx = map_index;

    if ((dev = get_next_device(context->ucm_devices, &idx)) == NULL)
        return;

    /* check if device at map_index can combine with existing devices combination */
    if (ucm_check_conformance(context, pdevices, dev_num, dev)) {
        /* add device at map_index to devices combination */
        pdevices[dev_num] = dev;
        /* add current devices combination as a new port */
        ucm_add_port_combination(hash, context, is_sink, pdevices, dev_num + 1, ports, cp, core);
        /* try more elements combination */
        ucm_add_ports_combination(hash, context, is_sink, pdevices, dev_num + 1, idx, ports, cp, core);
    }

    /* try other device with current elements number */
    ucm_add_ports_combination(hash, context, is_sink, pdevices, dev_num, idx, ports, cp, core);
}

static char* merge_roles(const char *cur, const char *add) {
    char *r, *ret;
    const char *state = NULL;

    if (add == NULL)
        return pa_xstrdup(cur);
    else if (cur == NULL)
        return pa_xstrdup(add);

    ret = pa_xstrdup(cur);

    while ((r = pa_split_spaces(add, &state))) {
        char *value;

        if (!pa_str_in_list_spaces(ret, r))
            value = pa_sprintf_malloc("%s %s", ret, r);
        else {
            pa_xfree(r);
            continue;
        }

        pa_xfree(ret);
        ret = value;
        pa_xfree(r);
    }

    return ret;
}

void pa_alsa_ucm_add_ports_combination(
        pa_hashmap *p,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_hashmap *ports,
        pa_card_profile *cp,
        pa_core *core) {

    pa_alsa_ucm_device **pdevices;

    pa_assert(context->ucm_devices);

    if (pa_idxset_size(context->ucm_devices) > 0) {
        pdevices = pa_xnew(pa_alsa_ucm_device *, pa_idxset_size(context->ucm_devices));
        ucm_add_ports_combination(p, context, is_sink, pdevices, 0, PA_IDXSET_INVALID, ports, cp, core);
        pa_xfree(pdevices);
    }

    /* ELD devices */
    set_eld_devices(ports);
}

void pa_alsa_ucm_add_ports(
        pa_hashmap **p,
        pa_proplist *proplist,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_card *card,
        snd_pcm_t *pcm_handle,
        bool ignore_dB) {

    uint32_t idx;
    char *merged_roles;
    const char *role_name = is_sink ? PA_ALSA_PROP_UCM_PLAYBACK_ROLES : PA_ALSA_PROP_UCM_CAPTURE_ROLES;
    pa_alsa_ucm_device *dev;
    pa_alsa_ucm_modifier *mod;
    char *tmp;

    pa_assert(p);
    pa_assert(*p);

    /* add ports first */
    pa_alsa_ucm_add_ports_combination(*p, context, is_sink, card->ports, NULL, card->core);

    /* now set up volume paths if any */
    probe_volumes(*p, is_sink, pcm_handle, context->ucm->mixers, ignore_dB);

    /* then set property PA_PROP_DEVICE_INTENDED_ROLES */
    merged_roles = pa_xstrdup(pa_proplist_gets(proplist, PA_PROP_DEVICE_INTENDED_ROLES));
    PA_IDXSET_FOREACH(dev, context->ucm_devices, idx) {
        const char *roles = pa_proplist_gets(dev->proplist, role_name);
        tmp = merge_roles(merged_roles, roles);
        pa_xfree(merged_roles);
        merged_roles = tmp;
    }

    if (context->ucm_modifiers)
        PA_IDXSET_FOREACH(mod, context->ucm_modifiers, idx) {
            tmp = merge_roles(merged_roles, mod->media_role);
            pa_xfree(merged_roles);
            merged_roles = tmp;
        }

    if (merged_roles)
        pa_proplist_sets(proplist, PA_PROP_DEVICE_INTENDED_ROLES, merged_roles);

    pa_log_info("ALSA device %s roles: %s", pa_proplist_gets(proplist, PA_PROP_DEVICE_STRING), pa_strnull(merged_roles));
    pa_xfree(merged_roles);
}

/* Change UCM verb and device to match selected card profile */
int pa_alsa_ucm_set_profile(pa_alsa_ucm_config *ucm, pa_card *card, const char *new_profile, const char *old_profile) {
    int ret = 0;
    const char *profile;
    pa_alsa_ucm_verb *verb;
    pa_device_port *port;
    pa_alsa_ucm_port_data *data;
    void *state;

    if (new_profile == old_profile)
        return ret;
    else if (new_profile == NULL || old_profile == NULL)
        profile = new_profile ? new_profile : SND_USE_CASE_VERB_INACTIVE;
    else if (!pa_streq(new_profile, old_profile))
        profile = new_profile;
    else
        return ret;

    /* change verb */
    pa_log_info("Set UCM verb to %s", profile);
    if ((ret = snd_use_case_set(ucm->ucm_mgr, "_verb", profile)) < 0) {
        pa_log("Failed to set verb %s: %s", profile, snd_strerror(ret));
    }

    /* find active verb */
    ucm->active_verb = NULL;
    PA_LLIST_FOREACH(verb, ucm->verbs) {
        const char *verb_name;
        verb_name = pa_proplist_gets(verb->proplist, PA_ALSA_PROP_UCM_NAME);
        if (pa_streq(verb_name, profile)) {
            ucm->active_verb = verb;
            break;
        }
    }

    /* select volume controls on ports */
    PA_HASHMAP_FOREACH(port, card->ports, state) {
        data = PA_DEVICE_PORT_DATA(port);
        data->path = pa_hashmap_get(data->paths, profile);
    }

    return ret;
}

int pa_alsa_ucm_set_port(pa_alsa_ucm_mapping_context *context, pa_device_port *port, bool is_sink) {
    int i;
    int ret = 0;
    pa_alsa_ucm_config *ucm;
    const char **enable_devs;
    int enable_num = 0;
    uint32_t idx;
    pa_alsa_ucm_device *dev;

    pa_assert(context && context->ucm);

    ucm = context->ucm;
    pa_assert(ucm->ucm_mgr);

    enable_devs = pa_xnew(const char *, pa_idxset_size(context->ucm_devices));

    /* first disable then enable */
    PA_IDXSET_FOREACH(dev, context->ucm_devices, idx) {
        const char *dev_name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME);

        if (ucm_port_contains(port->name, dev_name, is_sink))
            enable_devs[enable_num++] = dev_name;
        else {
            pa_log_debug("Disable ucm device %s", dev_name);
            if (snd_use_case_set(ucm->ucm_mgr, "_disdev", dev_name) > 0) {
                pa_log("Failed to disable ucm device %s", dev_name);
                ret = -1;
                break;
            }
        }
    }

    for (i = 0; i < enable_num; i++) {
        pa_log_debug("Enable ucm device %s", enable_devs[i]);
        if (snd_use_case_set(ucm->ucm_mgr, "_enadev", enable_devs[i]) < 0) {
            pa_log("Failed to enable ucm device %s", enable_devs[i]);
            ret = -1;
            break;
        }
    }

    pa_xfree(enable_devs);

    return ret;
}

static void ucm_add_mapping(pa_alsa_profile *p, pa_alsa_mapping *m) {

    pa_alsa_path_set *ps;

    /* create empty path set for the future path additions */
    ps = pa_xnew0(pa_alsa_path_set, 1);
    ps->direction = m->direction;
    ps->paths = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

    switch (m->direction) {
        case PA_ALSA_DIRECTION_ANY:
            pa_idxset_put(p->output_mappings, m, NULL);
            pa_idxset_put(p->input_mappings, m, NULL);
            m->output_path_set = ps;
            m->input_path_set = ps;
            break;
        case PA_ALSA_DIRECTION_OUTPUT:
            pa_idxset_put(p->output_mappings, m, NULL);
            m->output_path_set = ps;
            break;
        case PA_ALSA_DIRECTION_INPUT:
            pa_idxset_put(p->input_mappings, m, NULL);
            m->input_path_set = ps;
            break;
    }
}

static void alsa_mapping_add_ucm_device(pa_alsa_mapping *m, pa_alsa_ucm_device *device) {
    char *cur_desc;
    const char *new_desc, *mdev;
    bool is_sink = m->direction == PA_ALSA_DIRECTION_OUTPUT;

    pa_idxset_put(m->ucm_context.ucm_devices, device, NULL);

    new_desc = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_DESCRIPTION);
    cur_desc = m->description;
    if (cur_desc)
        m->description = pa_sprintf_malloc("%s + %s", cur_desc, new_desc);
    else
        m->description = pa_xstrdup(new_desc);
    pa_xfree(cur_desc);

    /* walk around null case */
    m->description = m->description ? m->description : pa_xstrdup("");

    /* save mapping to ucm device */
    if (is_sink)
        device->playback_mapping = m;
    else
        device->capture_mapping = m;

    mdev = get_mixer_device(device, is_sink);
    if (mdev)
        pa_proplist_sets(m->proplist, "alsa.mixer_device", mdev);
}

static void alsa_mapping_add_ucm_modifier(pa_alsa_mapping *m, pa_alsa_ucm_modifier *modifier) {
    char *cur_desc;
    const char *new_desc, *mod_name, *channel_str;
    uint32_t channels = 0;

    pa_idxset_put(m->ucm_context.ucm_modifiers, modifier, NULL);

    new_desc = pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_DESCRIPTION);
    cur_desc = m->description;
    if (cur_desc)
        m->description = pa_sprintf_malloc("%s + %s", cur_desc, new_desc);
    else
        m->description = pa_xstrdup(new_desc);
    pa_xfree(cur_desc);

    m->description = m->description ? m->description : pa_xstrdup("");

    /* Modifier sinks should not be routed to by default */
    m->priority = 0;

    mod_name = pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_NAME);
    pa_proplist_sets(m->proplist, PA_ALSA_PROP_UCM_MODIFIER, mod_name);

    /* save mapping to ucm modifier */
    if (m->direction == PA_ALSA_DIRECTION_OUTPUT) {
        modifier->playback_mapping = m;
        channel_str = pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_PLAYBACK_CHANNELS);
    } else {
        modifier->capture_mapping = m;
        channel_str = pa_proplist_gets(modifier->proplist, PA_ALSA_PROP_UCM_CAPTURE_CHANNELS);
    }

    if (channel_str) {
        /* FIXME: channel_str is unsanitized input from the UCM configuration,
         * we should do proper error handling instead of asserting.
         * https://bugs.freedesktop.org/show_bug.cgi?id=71823 */
        pa_assert_se(pa_atou(channel_str, &channels) == 0 && pa_channels_valid(channels));
        pa_log_debug("Got channel count %" PRIu32 " for modifier", channels);
    }

    if (channels)
        pa_channel_map_init_extend(&m->channel_map, channels, PA_CHANNEL_MAP_ALSA);
    else
        pa_channel_map_init(&m->channel_map);
}

static int ucm_create_mapping_direction(
        pa_alsa_ucm_config *ucm,
        pa_alsa_profile_set *ps,
        pa_alsa_profile *p,
        pa_alsa_ucm_device *device,
        const char *verb_name,
        const char *device_name,
        const char *device_str,
        bool is_sink) {

    pa_alsa_mapping *m;
    char *mapping_name;
    unsigned priority, rate, channels;

    mapping_name = pa_sprintf_malloc("Mapping %s: %s: %s", verb_name, device_str, is_sink ? "sink" : "source");

    m = pa_alsa_mapping_get(ps, mapping_name);
    if (!m) {
        pa_log("No mapping for %s", mapping_name);
        pa_xfree(mapping_name);
        return -1;
    }
    pa_log_debug("UCM mapping: %s dev %s", mapping_name, device_name);
    pa_xfree(mapping_name);

    priority = is_sink ? device->playback_priority : device->capture_priority;
    rate = is_sink ? device->playback_rate : device->capture_rate;
    channels = is_sink ? device->playback_channels : device->capture_channels;

    if (!m->ucm_context.ucm_devices) {   /* new mapping */
        m->ucm_context.ucm_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        m->ucm_context.ucm = ucm;
        m->ucm_context.direction = is_sink ? PA_DIRECTION_OUTPUT : PA_DIRECTION_INPUT;

        m->device_strings = pa_xnew0(char*, 2);
        m->device_strings[0] = pa_xstrdup(device_str);
        m->direction = is_sink ? PA_ALSA_DIRECTION_OUTPUT : PA_ALSA_DIRECTION_INPUT;

        ucm_add_mapping(p, m);
        if (rate)
            m->sample_spec.rate = rate;
        pa_channel_map_init_extend(&m->channel_map, channels, PA_CHANNEL_MAP_ALSA);
    }

    /* mapping priority is the highest one of ucm devices */
    if (priority > m->priority)
        m->priority = priority;

    /* mapping channels is the lowest one of ucm devices */
    if (channels < m->channel_map.channels)
        pa_channel_map_init_extend(&m->channel_map, channels, PA_CHANNEL_MAP_ALSA);

    alsa_mapping_add_ucm_device(m, device);

    return 0;
}

static int ucm_create_mapping_for_modifier(
        pa_alsa_ucm_config *ucm,
        pa_alsa_profile_set *ps,
        pa_alsa_profile *p,
        pa_alsa_ucm_modifier *modifier,
        const char *verb_name,
        const char *mod_name,
        const char *device_str,
        bool is_sink) {

    pa_alsa_mapping *m;
    char *mapping_name;

    mapping_name = pa_sprintf_malloc("Mapping %s: %s: %s", verb_name, device_str, is_sink ? "sink" : "source");

    m = pa_alsa_mapping_get(ps, mapping_name);
    if (!m) {
        pa_log("no mapping for %s", mapping_name);
        pa_xfree(mapping_name);
        return -1;
    }
    pa_log_info("ucm mapping: %s modifier %s", mapping_name, mod_name);
    pa_xfree(mapping_name);

    if (!m->ucm_context.ucm_devices && !m->ucm_context.ucm_modifiers) {   /* new mapping */
        m->ucm_context.ucm_devices = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        m->ucm_context.ucm_modifiers = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
        m->ucm_context.ucm = ucm;
        m->ucm_context.direction = is_sink ? PA_DIRECTION_OUTPUT : PA_DIRECTION_INPUT;

        m->device_strings = pa_xnew0(char*, 2);
        m->device_strings[0] = pa_xstrdup(device_str);
        m->direction = is_sink ? PA_ALSA_DIRECTION_OUTPUT : PA_ALSA_DIRECTION_INPUT;
        /* Modifier sinks should not be routed to by default */
        m->priority = 0;

        ucm_add_mapping(p, m);
    } else if (!m->ucm_context.ucm_modifiers) /* share pcm with device */
        m->ucm_context.ucm_modifiers = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

    alsa_mapping_add_ucm_modifier(m, modifier);

    return 0;
}

static int ucm_create_mapping(
        pa_alsa_ucm_config *ucm,
        pa_alsa_profile_set *ps,
        pa_alsa_profile *p,
        pa_alsa_ucm_device *device,
        const char *verb_name,
        const char *device_name,
        const char *sink,
        const char *source) {

    int ret = 0;

    if (!sink && !source) {
        pa_log("No sink and source at %s: %s", verb_name, device_name);
        return -1;
    }

    if (sink)
        ret = ucm_create_mapping_direction(ucm, ps, p, device, verb_name, device_name, sink, true);
    if (ret == 0 && source)
        ret = ucm_create_mapping_direction(ucm, ps, p, device, verb_name, device_name, source, false);

    return ret;
}

static pa_alsa_jack* ucm_get_jack(pa_alsa_ucm_config *ucm, pa_alsa_ucm_device *device) {
    pa_alsa_jack *j;
    const char *device_name;
    const char *jack_control;
    const char *mixer_device_name;
    char *name;

    pa_assert(ucm);
    pa_assert(device);

    device_name = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_NAME);

    jack_control = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_JACK_CONTROL);
    if (jack_control) {
#if SND_LIB_VERSION >= 0x10201
        snd_ctl_elem_id_t *ctl;
        int err, index;
        snd_ctl_elem_id_alloca(&ctl);
        err = snd_use_case_parse_ctl_elem_id(ctl, "JackControl", jack_control);
        if (err < 0)
            return NULL;
        jack_control = snd_ctl_elem_id_get_name(ctl);
        index = snd_ctl_elem_id_get_index(ctl);
        if (index > 0) {
            pa_log("[%s] Invalid JackControl index value: \"%s\",%d", device_name, jack_control, index);
            return NULL;
        }
#else
#warning "Upgrade to alsa-lib 1.2.1!"
#endif
        if (!pa_endswith(jack_control, " Jack")) {
            pa_log("[%s] Invalid JackControl value: \"%s\"", device_name, jack_control);
            return NULL;
        }

        /* pa_alsa_jack_new() expects a jack name without " Jack" at the
         * end, so drop the trailing " Jack". */
        name = pa_xstrndup(jack_control, strlen(jack_control) - 5);
    } else {
        /* The jack control hasn't been explicitly configured, fail. */
        return NULL;
    }

    PA_LLIST_FOREACH(j, ucm->jacks)
        if (pa_streq(j->name, name))
            goto finish;

    mixer_device_name = get_jack_mixer_device(device, true);
    if (!mixer_device_name)
        mixer_device_name = get_jack_mixer_device(device, false);
    if (!mixer_device_name) {
        pa_log("[%s] No mixer device name for JackControl \"%s\"", device_name, jack_control);
        j = NULL;
        goto finish;
    }
    j = pa_alsa_jack_new(NULL, mixer_device_name, name, 0);
    PA_LLIST_PREPEND(pa_alsa_jack, ucm->jacks, j);

finish:
    pa_xfree(name);

    return j;
}

static int ucm_create_profile(
        pa_alsa_ucm_config *ucm,
        pa_alsa_profile_set *ps,
        pa_alsa_ucm_verb *verb,
        const char *verb_name,
        const char *verb_desc) {

    pa_alsa_profile *p;
    pa_alsa_ucm_device *dev;
    pa_alsa_ucm_modifier *mod;
    int i = 0;
    const char *name, *sink, *source;
    unsigned int priority;

    pa_assert(ps);

    if (pa_hashmap_get(ps->profiles, verb_name)) {
        pa_log("Verb %s already exists", verb_name);
        return -1;
    }

    p = pa_xnew0(pa_alsa_profile, 1);
    p->profile_set = ps;
    p->name = pa_xstrdup(verb_name);
    p->description = pa_xstrdup(verb_desc);

    p->output_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
    p->input_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

    p->supported = true;
    pa_hashmap_put(ps->profiles, p->name, p);

    /* TODO: get profile priority from policy management */
    priority = verb->priority;

    if (priority == 0) {
        char *verb_cmp, *c;
        c = verb_cmp = pa_xstrdup(verb_name);
        while (*c) {
            if (*c == '_') *c = ' ';
            c++;
        }
        for (i = 0; verb_info[i].id; i++) {
            if (strcasecmp(verb_info[i].id, verb_cmp) == 0) {
                priority = verb_info[i].priority;
                break;
            }
        }
        pa_xfree(verb_cmp);
    }

    p->priority = priority;

    PA_LLIST_FOREACH(dev, verb->devices) {
        pa_alsa_jack *jack;
        const char *jack_hw_mute;

        name = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_NAME);

        sink = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_SINK);
        source = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_SOURCE);

        ucm_create_mapping(ucm, ps, p, dev, verb_name, name, sink, source);

        jack = ucm_get_jack(ucm, dev);
        if (jack)
            device_set_jack(dev, jack);

        /* JackHWMute contains a list of device names. Each listed device must
         * be associated with the jack object that we just created. */
        jack_hw_mute = pa_proplist_gets(dev->proplist, PA_ALSA_PROP_UCM_JACK_HW_MUTE);
        if (jack_hw_mute && !jack) {
            pa_log("[%s] JackHWMute set, but JackControl is missing", name);
            jack_hw_mute = NULL;
        }
        if (jack_hw_mute) {
            char *hw_mute_device_name;
            const char *state = NULL;

            while ((hw_mute_device_name = ucm_split_devnames(jack_hw_mute, &state))) {
                pa_alsa_ucm_verb *verb2;
                bool device_found = false;

                /* Search the referenced device from all verbs. If there are
                 * multiple verbs that have a device with this name, we add the
                 * hw mute association to each of those devices. */
                PA_LLIST_FOREACH(verb2, ucm->verbs) {
                    pa_alsa_ucm_device *hw_mute_device;

                    hw_mute_device = verb_find_device(verb2, hw_mute_device_name);
                    if (hw_mute_device) {
                        device_found = true;
                        device_add_hw_mute_jack(hw_mute_device, jack);
                    }
                }

                if (!device_found)
                    pa_log("[%s] JackHWMute references an unknown device: %s", name, hw_mute_device_name);

                pa_xfree(hw_mute_device_name);
            }
        }
    }

    /* Now find modifiers that have their own PlaybackPCM and create
     * separate sinks for them. */
    PA_LLIST_FOREACH(mod, verb->modifiers) {
        name = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_NAME);

        sink = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_SINK);
        source = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_SOURCE);

        if (sink)
            ucm_create_mapping_for_modifier(ucm, ps, p, mod, verb_name, name, sink, true);
        else if (source)
            ucm_create_mapping_for_modifier(ucm, ps, p, mod, verb_name, name, source, false);
    }

    pa_alsa_profile_dump(p);

    return 0;
}

static void mapping_init_eld(pa_alsa_mapping *m, snd_pcm_t *pcm)
{
    pa_alsa_ucm_mapping_context *context = &m->ucm_context;
    pa_alsa_ucm_device *dev;
    uint32_t idx;
    char *mdev;
    snd_pcm_info_t *info;
    int pcm_card, pcm_device;

    snd_pcm_info_alloca(&info);
    if (snd_pcm_info(pcm, info) < 0)
        return;

    if ((pcm_card = snd_pcm_info_get_card(info)) < 0)
        return;
    if ((pcm_device = snd_pcm_info_get_device(info)) < 0)
        return;

    PA_IDXSET_FOREACH(dev, context->ucm_devices, idx) {
       mdev = pa_sprintf_malloc("hw:%i", pcm_card);
       if (mdev == NULL)
           continue;
       dev->eld_mixer_device_name = mdev;
       dev->eld_device = pcm_device;
    }
}

static snd_pcm_t* mapping_open_pcm(pa_alsa_ucm_config *ucm, pa_alsa_mapping *m, int mode) {
    snd_pcm_t* pcm;
    pa_sample_spec try_ss = ucm->default_sample_spec;
    pa_channel_map try_map;
    snd_pcm_uframes_t try_period_size, try_buffer_size;
    bool exact_channels = m->channel_map.channels > 0;

    if (exact_channels) {
        try_map = m->channel_map;
        try_ss.channels = try_map.channels;
    } else
        pa_channel_map_init_extend(&try_map, try_ss.channels, PA_CHANNEL_MAP_ALSA);

    try_period_size =
        pa_usec_to_bytes(ucm->default_fragment_size_msec * PA_USEC_PER_MSEC, &try_ss) /
        pa_frame_size(&try_ss);
    try_buffer_size = ucm->default_n_fragments * try_period_size;

    pcm = pa_alsa_open_by_device_string(m->device_strings[0], NULL, &try_ss,
            &try_map, mode, &try_period_size, &try_buffer_size, 0, NULL, NULL, exact_channels);

    if (pcm) {
        if (!exact_channels)
            m->channel_map = try_map;
        mapping_init_eld(m, pcm);
    }

    return pcm;
}

static void profile_finalize_probing(pa_alsa_profile *p) {
    pa_alsa_mapping *m;
    uint32_t idx;

    PA_IDXSET_FOREACH(m, p->output_mappings, idx) {
        if (p->supported)
            m->supported++;

        if (!m->output_pcm)
            continue;

        pa_alsa_init_proplist_pcm(NULL, m->output_proplist, m->output_pcm);
        snd_pcm_close(m->output_pcm);
        m->output_pcm = NULL;
    }

    PA_IDXSET_FOREACH(m, p->input_mappings, idx) {
        if (p->supported)
            m->supported++;

        if (!m->input_pcm)
            continue;

        pa_alsa_init_proplist_pcm(NULL, m->input_proplist, m->input_pcm);
        snd_pcm_close(m->input_pcm);
        m->input_pcm = NULL;
    }
}

static void ucm_mapping_jack_probe(pa_alsa_mapping *m, pa_hashmap *mixers) {
    snd_mixer_t *mixer_handle;
    pa_alsa_ucm_mapping_context *context = &m->ucm_context;
    pa_alsa_ucm_device *dev;
    uint32_t idx;

    PA_IDXSET_FOREACH(dev, context->ucm_devices, idx) {
        bool has_control;

        if (!dev->jack || !dev->jack->mixer_device_name)
            continue;

        mixer_handle = pa_alsa_open_mixer_by_name(mixers, dev->jack->mixer_device_name, true);
        if (!mixer_handle) {
            pa_log_error("Unable to determine open mixer device '%s' for jack %s", dev->jack->mixer_device_name, dev->jack->name);
            continue;
        }

        has_control = pa_alsa_mixer_find_card(mixer_handle, &dev->jack->alsa_id, 0) != NULL;
        pa_alsa_jack_set_has_control(dev->jack, has_control);
        pa_log_info("UCM jack %s has_control=%d", dev->jack->name, dev->jack->has_control);
    }
}

static void ucm_probe_profile_set(pa_alsa_ucm_config *ucm, pa_alsa_profile_set *ps) {
    void *state;
    pa_alsa_profile *p;
    pa_alsa_mapping *m;
    uint32_t idx;

    PA_HASHMAP_FOREACH(p, ps->profiles, state) {
        /* change verb */
        pa_log_info("Set ucm verb to %s", p->name);

        if ((snd_use_case_set(ucm->ucm_mgr, "_verb", p->name)) < 0) {
            pa_log("Failed to set verb %s", p->name);
            p->supported = false;
            continue;
        }

        PA_IDXSET_FOREACH(m, p->output_mappings, idx) {
            if (PA_UCM_IS_MODIFIER_MAPPING(m)) {
                /* Skip jack probing on modifier PCMs since we expect this to
                 * only be controlled on the main device/verb PCM. */
                continue;
            }

            m->output_pcm = mapping_open_pcm(ucm, m, SND_PCM_STREAM_PLAYBACK);
            if (!m->output_pcm) {
                p->supported = false;
                break;
            }
        }

        if (p->supported) {
            PA_IDXSET_FOREACH(m, p->input_mappings, idx) {
                if (PA_UCM_IS_MODIFIER_MAPPING(m)) {
                    /* Skip jack probing on modifier PCMs since we expect this to
                     * only be controlled on the main device/verb PCM. */
                    continue;
                }

                m->input_pcm = mapping_open_pcm(ucm, m, SND_PCM_STREAM_CAPTURE);
                if (!m->input_pcm) {
                    p->supported = false;
                    break;
                }
            }
        }

        if (!p->supported) {
            profile_finalize_probing(p);
            continue;
        }

        pa_log_debug("Profile %s supported.", p->name);

        PA_IDXSET_FOREACH(m, p->output_mappings, idx)
            if (!PA_UCM_IS_MODIFIER_MAPPING(m))
                ucm_mapping_jack_probe(m, ucm->mixers);

        PA_IDXSET_FOREACH(m, p->input_mappings, idx)
            if (!PA_UCM_IS_MODIFIER_MAPPING(m))
                ucm_mapping_jack_probe(m, ucm->mixers);

        profile_finalize_probing(p);
    }

    /* restore ucm state */
    snd_use_case_set(ucm->ucm_mgr, "_verb", SND_USE_CASE_VERB_INACTIVE);

    pa_alsa_profile_set_drop_unsupported(ps);
}

pa_alsa_profile_set* pa_alsa_ucm_add_profile_set(pa_alsa_ucm_config *ucm, pa_channel_map *default_channel_map) {
    pa_alsa_ucm_verb *verb;
    pa_alsa_profile_set *ps;

    ps = pa_xnew0(pa_alsa_profile_set, 1);
    ps->mappings = pa_hashmap_new(pa_idxset_string_hash_func, pa_idxset_string_compare_func);
    ps->profiles = pa_hashmap_new(pa_idxset_string_hash_func, pa_idxset_string_compare_func);
    ps->decibel_fixes = pa_hashmap_new(pa_idxset_string_hash_func, pa_idxset_string_compare_func);

    /* create a profile for each verb */
    PA_LLIST_FOREACH(verb, ucm->verbs) {
        const char *verb_name;
        const char *verb_desc;

        verb_name = pa_proplist_gets(verb->proplist, PA_ALSA_PROP_UCM_NAME);
        verb_desc = pa_proplist_gets(verb->proplist, PA_ALSA_PROP_UCM_DESCRIPTION);
        if (verb_name == NULL) {
            pa_log("Verb with no name");
            continue;
        }

        ucm_create_profile(ucm, ps, verb, verb_name, verb_desc);
    }

    ucm_probe_profile_set(ucm, ps);
    ps->probed = true;

    return ps;
}

static void free_verb(pa_alsa_ucm_verb *verb) {
    pa_alsa_ucm_device *di, *dn;
    pa_alsa_ucm_modifier *mi, *mn;

    PA_LLIST_FOREACH_SAFE(di, dn, verb->devices) {
        PA_LLIST_REMOVE(pa_alsa_ucm_device, verb->devices, di);

        if (di->hw_mute_jacks)
            pa_dynarray_free(di->hw_mute_jacks);

        if (di->ucm_ports)
            pa_dynarray_free(di->ucm_ports);

        if (di->playback_volumes)
            pa_hashmap_free(di->playback_volumes);
        if (di->capture_volumes)
            pa_hashmap_free(di->capture_volumes);

        pa_proplist_free(di->proplist);

        if (di->conflicting_devices)
            pa_idxset_free(di->conflicting_devices, NULL);
        if (di->supported_devices)
            pa_idxset_free(di->supported_devices, NULL);

        pa_xfree(di->eld_mixer_device_name);

        pa_xfree(di);
    }

    PA_LLIST_FOREACH_SAFE(mi, mn, verb->modifiers) {
        PA_LLIST_REMOVE(pa_alsa_ucm_modifier, verb->modifiers, mi);
        pa_proplist_free(mi->proplist);
        if (mi->n_suppdev > 0)
            snd_use_case_free_list(mi->supported_devices, mi->n_suppdev);
        if (mi->n_confdev > 0)
            snd_use_case_free_list(mi->conflicting_devices, mi->n_confdev);
        pa_xfree(mi->media_role);
        pa_xfree(mi);
    }
    pa_proplist_free(verb->proplist);
    pa_xfree(verb);
}

static pa_alsa_ucm_device *verb_find_device(pa_alsa_ucm_verb *verb, const char *device_name) {
    pa_alsa_ucm_device *device;

    pa_assert(verb);
    pa_assert(device_name);

    PA_LLIST_FOREACH(device, verb->devices) {
        const char *name;

        name = pa_proplist_gets(device->proplist, PA_ALSA_PROP_UCM_NAME);
        if (pa_streq(name, device_name))
            return device;
    }

    return NULL;
}

void pa_alsa_ucm_free(pa_alsa_ucm_config *ucm) {
    pa_alsa_ucm_verb *vi, *vn;
    pa_alsa_jack *ji, *jn;

    PA_LLIST_FOREACH_SAFE(vi, vn, ucm->verbs) {
        PA_LLIST_REMOVE(pa_alsa_ucm_verb, ucm->verbs, vi);
        free_verb(vi);
    }
    PA_LLIST_FOREACH_SAFE(ji, jn, ucm->jacks) {
        PA_LLIST_REMOVE(pa_alsa_jack, ucm->jacks, ji);
        pa_alsa_jack_free(ji);
    }
    if (ucm->ucm_mgr) {
        snd_use_case_mgr_close(ucm->ucm_mgr);
        ucm->ucm_mgr = NULL;
    }
}

void pa_alsa_ucm_mapping_context_free(pa_alsa_ucm_mapping_context *context) {
    pa_alsa_ucm_device *dev;
    pa_alsa_ucm_modifier *mod;
    uint32_t idx;

    if (context->ucm_devices) {
        /* clear ucm device pointer to mapping */
        PA_IDXSET_FOREACH(dev, context->ucm_devices, idx) {
            if (context->direction == PA_DIRECTION_OUTPUT)
                dev->playback_mapping = NULL;
            else
                dev->capture_mapping = NULL;
        }

        pa_idxset_free(context->ucm_devices, NULL);
    }

    if (context->ucm_modifiers) {
        PA_IDXSET_FOREACH(mod, context->ucm_modifiers, idx) {
            if (context->direction == PA_DIRECTION_OUTPUT)
                mod->playback_mapping = NULL;
            else
                mod->capture_mapping = NULL;
        }

        pa_idxset_free(context->ucm_modifiers, NULL);
    }
}

/* Enable the modifier when the first stream with matched role starts */
void pa_alsa_ucm_roled_stream_begin(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir) {
    pa_alsa_ucm_modifier *mod;

    if (!ucm->active_verb)
        return;

    PA_LLIST_FOREACH(mod, ucm->active_verb->modifiers) {
        if ((mod->action_direction == dir) && (pa_streq(mod->media_role, role))) {
            if (mod->enabled_counter == 0) {
                const char *mod_name = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_NAME);

                pa_log_info("Enable ucm modifier %s", mod_name);
                if (snd_use_case_set(ucm->ucm_mgr, "_enamod", mod_name) < 0) {
                    pa_log("Failed to enable ucm modifier %s", mod_name);
                }
            }

            mod->enabled_counter++;
            break;
        }
    }
}

/* Disable the modifier when the last stream with matched role ends */
void pa_alsa_ucm_roled_stream_end(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir) {
    pa_alsa_ucm_modifier *mod;

    if (!ucm->active_verb)
        return;

    PA_LLIST_FOREACH(mod, ucm->active_verb->modifiers) {
        if ((mod->action_direction == dir) && (pa_streq(mod->media_role, role))) {

            mod->enabled_counter--;
            if (mod->enabled_counter == 0) {
                const char *mod_name = pa_proplist_gets(mod->proplist, PA_ALSA_PROP_UCM_NAME);

                pa_log_info("Disable ucm modifier %s", mod_name);
                if (snd_use_case_set(ucm->ucm_mgr, "_dismod", mod_name) < 0) {
                    pa_log("Failed to disable ucm modifier %s", mod_name);
                }
            }

            break;
        }
    }
}

static void device_add_ucm_port(pa_alsa_ucm_device *device, pa_alsa_ucm_port_data *port) {
    pa_assert(device);
    pa_assert(port);

    pa_dynarray_append(device->ucm_ports, port);
}

static void device_set_jack(pa_alsa_ucm_device *device, pa_alsa_jack *jack) {
    pa_assert(device);
    pa_assert(jack);

    device->jack = jack;
    pa_alsa_jack_add_ucm_device(jack, device);

    pa_alsa_ucm_device_update_available(device);
}

static void device_add_hw_mute_jack(pa_alsa_ucm_device *device, pa_alsa_jack *jack) {
    pa_assert(device);
    pa_assert(jack);

    pa_dynarray_append(device->hw_mute_jacks, jack);
    pa_alsa_jack_add_ucm_hw_mute_device(jack, device);

    pa_alsa_ucm_device_update_available(device);
}

static void device_set_available(pa_alsa_ucm_device *device, pa_available_t available) {
    pa_alsa_ucm_port_data *port;
    unsigned idx;

    pa_assert(device);

    if (available == device->available)
        return;

    device->available = available;

    PA_DYNARRAY_FOREACH(port, device->ucm_ports, idx)
        ucm_port_update_available(port);
}

void pa_alsa_ucm_device_update_available(pa_alsa_ucm_device *device) {
    pa_available_t available = PA_AVAILABLE_UNKNOWN;
    pa_alsa_jack *jack;
    unsigned idx;

    pa_assert(device);

    if (device->jack && device->jack->has_control)
        available = device->jack->plugged_in ? PA_AVAILABLE_YES : PA_AVAILABLE_NO;

    PA_DYNARRAY_FOREACH(jack, device->hw_mute_jacks, idx) {
        if (jack->plugged_in) {
            available = PA_AVAILABLE_NO;
            break;
        }
    }

    device_set_available(device, available);
}

static void ucm_port_data_init(pa_alsa_ucm_port_data *port, pa_alsa_ucm_config *ucm, pa_device_port *core_port,
                               pa_alsa_ucm_device **devices, unsigned n_devices) {
    unsigned i;

    pa_assert(ucm);
    pa_assert(core_port);
    pa_assert(devices);

    port->ucm = ucm;
    port->core_port = core_port;
    port->devices = pa_dynarray_new(NULL);
    port->eld_device = -1;

    for (i = 0; i < n_devices; i++) {
        pa_dynarray_append(port->devices, devices[i]);
        device_add_ucm_port(devices[i], port);
    }

    port->paths = pa_hashmap_new_full(pa_idxset_string_hash_func, pa_idxset_string_compare_func, pa_xfree,
                                      (pa_free_cb_t) pa_alsa_path_free);

    ucm_port_update_available(port);
}

static void ucm_port_data_free(pa_device_port *port) {
    pa_alsa_ucm_port_data *ucm_port;

    pa_assert(port);

    ucm_port = PA_DEVICE_PORT_DATA(port);

    if (ucm_port->devices)
        pa_dynarray_free(ucm_port->devices);

    if (ucm_port->paths)
        pa_hashmap_free(ucm_port->paths);

    pa_xfree(ucm_port->eld_mixer_device_name);
}

static void ucm_port_update_available(pa_alsa_ucm_port_data *port) {
    pa_alsa_ucm_device *device;
    unsigned idx;
    pa_available_t available = PA_AVAILABLE_YES;

    pa_assert(port);

    PA_DYNARRAY_FOREACH(device, port->devices, idx) {
        if (device->available == PA_AVAILABLE_UNKNOWN)
            available = PA_AVAILABLE_UNKNOWN;
        else if (device->available == PA_AVAILABLE_NO) {
            available = PA_AVAILABLE_NO;
            break;
        }
    }

    pa_device_port_set_available(port->core_port, available);
}

#else /* HAVE_ALSA_UCM */

/* Dummy functions for systems without UCM support */

int pa_alsa_ucm_query_profiles(pa_alsa_ucm_config *ucm, int card_index) {
        pa_log_info("UCM not available.");
        return -1;
}

pa_alsa_profile_set* pa_alsa_ucm_add_profile_set(pa_alsa_ucm_config *ucm, pa_channel_map *default_channel_map) {
    return NULL;
}

int pa_alsa_ucm_set_profile(pa_alsa_ucm_config *ucm, pa_card *card, const char *new_profile, const char *old_profile) {
    return -1;
}

int pa_alsa_ucm_get_verb(snd_use_case_mgr_t *uc_mgr, const char *verb_name, const char *verb_desc, pa_alsa_ucm_verb **p_verb) {
    return -1;
}

void pa_alsa_ucm_add_ports(
        pa_hashmap **hash,
        pa_proplist *proplist,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_card *card,
        snd_pcm_t *pcm_handle,
        bool ignore_dB) {
}

void pa_alsa_ucm_add_ports_combination(
        pa_hashmap *hash,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_hashmap *ports,
        pa_card_profile *cp,
        pa_core *core) {
}

int pa_alsa_ucm_set_port(pa_alsa_ucm_mapping_context *context, pa_device_port *port, bool is_sink) {
    return -1;
}

void pa_alsa_ucm_free(pa_alsa_ucm_config *ucm) {
}

void pa_alsa_ucm_mapping_context_free(pa_alsa_ucm_mapping_context *context) {
}

void pa_alsa_ucm_roled_stream_begin(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir) {
}

void pa_alsa_ucm_roled_stream_end(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir) {
}

#endif
