#ifndef fooalsaucmhfoo
#define fooalsaucmhfoo

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

#ifdef HAVE_ALSA_UCM
#include <alsa/use-case.h>
#else
typedef void snd_use_case_mgr_t;
#endif

#include "compat.h"

#include "alsa-mixer.h"

/** For devices: List of verbs, devices or modifiers available */
#define PA_ALSA_PROP_UCM_NAME                       "alsa.ucm.name"

/** For devices: List of supported devices per verb*/
#define PA_ALSA_PROP_UCM_DESCRIPTION                "alsa.ucm.description"

/** For devices: Playback device name e.g PlaybackPCM */
#define PA_ALSA_PROP_UCM_SINK                       "alsa.ucm.sink"

/** For devices: Capture device name e.g CapturePCM*/
#define PA_ALSA_PROP_UCM_SOURCE                     "alsa.ucm.source"

/** For devices: Playback roles */
#define PA_ALSA_PROP_UCM_PLAYBACK_ROLES             "alsa.ucm.playback.roles"

/** For devices: Playback control device name  */
#define PA_ALSA_PROP_UCM_PLAYBACK_CTL_DEVICE        "alsa.ucm.playback.ctldev"

/** For devices: Playback control volume ID string. e.g PlaybackVolume */
#define PA_ALSA_PROP_UCM_PLAYBACK_VOLUME            "alsa.ucm.playback.volume"

/** For devices: Playback switch e.g PlaybackSwitch */
#define PA_ALSA_PROP_UCM_PLAYBACK_SWITCH            "alsa.ucm.playback.switch"

/** For devices: Playback mixer device name  */
#define PA_ALSA_PROP_UCM_PLAYBACK_MIXER_DEVICE      "alsa.ucm.playback.mixer.device"

/** For devices: Playback mixer identifier */
#define PA_ALSA_PROP_UCM_PLAYBACK_MIXER_ELEM        "alsa.ucm.playback.mixer.element"

/** For devices: Playback mixer master identifier */
#define PA_ALSA_PROP_UCM_PLAYBACK_MASTER_ELEM       "alsa.ucm.playback.master.element"

/** For devices: Playback mixer master type */
#define PA_ALSA_PROP_UCM_PLAYBACK_MASTER_TYPE       "alsa.ucm.playback.master.type"

/** For devices: Playback mixer master identifier */
#define PA_ALSA_PROP_UCM_PLAYBACK_MASTER_ID         "alsa.ucm.playback.master.id"

/** For devices: Playback mixer master type */
#define PA_ALSA_PROP_UCM_PLAYBACK_MASTER_TYPE       "alsa.ucm.playback.master.type"

/** For devices: Playback priority */
#define PA_ALSA_PROP_UCM_PLAYBACK_PRIORITY          "alsa.ucm.playback.priority"

/** For devices: Playback rate */
#define PA_ALSA_PROP_UCM_PLAYBACK_RATE              "alsa.ucm.playback.rate"

/** For devices: Playback channels */
#define PA_ALSA_PROP_UCM_PLAYBACK_CHANNELS          "alsa.ucm.playback.channels"

/** For devices: Capture roles */
#define PA_ALSA_PROP_UCM_CAPTURE_ROLES              "alsa.ucm.capture.roles"

/** For devices: Capture control device name  */
#define PA_ALSA_PROP_UCM_CAPTURE_CTL_DEVICE         "alsa.ucm.capture.ctldev"

/** For devices: Capture controls volume ID string. e.g CaptureVolume */
#define PA_ALSA_PROP_UCM_CAPTURE_VOLUME             "alsa.ucm.capture.volume"

/** For devices: Capture switch e.g CaptureSwitch */
#define PA_ALSA_PROP_UCM_CAPTURE_SWITCH             "alsa.ucm.capture.switch"

/** For devices: Capture mixer device name  */
#define PA_ALSA_PROP_UCM_CAPTURE_MIXER_DEVICE       "alsa.ucm.capture.mixer.device"

/** For devices: Capture mixer identifier */
#define PA_ALSA_PROP_UCM_CAPTURE_MIXER_ELEM         "alsa.ucm.capture.mixer.element"

/** For devices: Capture mixer identifier */
#define PA_ALSA_PROP_UCM_CAPTURE_MASTER_ELEM        "alsa.ucm.capture.master.element"

/** For devices: Capture mixer identifier */
#define PA_ALSA_PROP_UCM_CAPTURE_MASTER_TYPE        "alsa.ucm.capture.master.type"

/** For devices: Capture mixer identifier */
#define PA_ALSA_PROP_UCM_CAPTURE_MASTER_ID          "alsa.ucm.capture.master.id"

/** For devices: Capture mixer identifier */
#define PA_ALSA_PROP_UCM_CAPTURE_MASTER_TYPE        "alsa.ucm.capture.master.type"

/** For devices: Capture priority */
#define PA_ALSA_PROP_UCM_CAPTURE_PRIORITY           "alsa.ucm.capture.priority"

/** For devices: Capture rate */
#define PA_ALSA_PROP_UCM_CAPTURE_RATE               "alsa.ucm.capture.rate"

/** For devices: Capture channels */
#define PA_ALSA_PROP_UCM_CAPTURE_CHANNELS           "alsa.ucm.capture.channels"

/** For devices: Quality of Service */
#define PA_ALSA_PROP_UCM_QOS                        "alsa.ucm.qos"

/** For devices: The modifier (if any) that this device corresponds to */
#define PA_ALSA_PROP_UCM_MODIFIER "alsa.ucm.modifier"

/* Corresponds to the "JackCTL" UCM value. */
#define PA_ALSA_PROP_UCM_JACK_DEVICE		    "alsa.ucm.jack_device"

/* Corresponds to the "JackControl" UCM value. */
#define PA_ALSA_PROP_UCM_JACK_CONTROL               "alsa.ucm.jack_control"

/* Corresponds to the "JackHWMute" UCM value. */
#define PA_ALSA_PROP_UCM_JACK_HW_MUTE               "alsa.ucm.jack_hw_mute"

typedef struct pa_alsa_ucm_verb pa_alsa_ucm_verb;
typedef struct pa_alsa_ucm_modifier pa_alsa_ucm_modifier;
typedef struct pa_alsa_ucm_device pa_alsa_ucm_device;
typedef struct pa_alsa_ucm_config pa_alsa_ucm_config;
typedef struct pa_alsa_ucm_mapping_context pa_alsa_ucm_mapping_context;
typedef struct pa_alsa_ucm_port_data pa_alsa_ucm_port_data;
typedef struct pa_alsa_ucm_volume pa_alsa_ucm_volume;

int pa_alsa_ucm_query_profiles(pa_alsa_ucm_config *ucm, int card_index);
pa_alsa_profile_set* pa_alsa_ucm_add_profile_set(pa_alsa_ucm_config *ucm, pa_channel_map *default_channel_map);
int pa_alsa_ucm_set_profile(pa_alsa_ucm_config *ucm, pa_card *card, const char *new_profile, const char *old_profile);

int pa_alsa_ucm_get_verb(snd_use_case_mgr_t *uc_mgr, const char *verb_name, const char *verb_desc, pa_alsa_ucm_verb **p_verb);

void pa_alsa_ucm_add_ports(
        pa_hashmap **hash,
        pa_proplist *proplist,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_card *card,
        snd_pcm_t *pcm_handle,
        bool ignore_dB);
void pa_alsa_ucm_add_ports_combination(
        pa_hashmap *hash,
        pa_alsa_ucm_mapping_context *context,
        bool is_sink,
        pa_hashmap *ports,
        pa_card_profile *cp,
        pa_core *core);
int pa_alsa_ucm_set_port(pa_alsa_ucm_mapping_context *context, pa_device_port *port, bool is_sink);

void pa_alsa_ucm_free(pa_alsa_ucm_config *ucm);
void pa_alsa_ucm_mapping_context_free(pa_alsa_ucm_mapping_context *context);

void pa_alsa_ucm_roled_stream_begin(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir);
void pa_alsa_ucm_roled_stream_end(pa_alsa_ucm_config *ucm, const char *role, pa_direction_t dir);

/* UCM - Use Case Manager is available on some audio cards */

struct pa_alsa_ucm_device {
    PA_LLIST_FIELDS(pa_alsa_ucm_device);

    pa_proplist *proplist;

    pa_device_port_type_t type;

    unsigned playback_priority;
    unsigned capture_priority;

    unsigned playback_rate;
    unsigned capture_rate;

    unsigned playback_channels;
    unsigned capture_channels;

    /* These may be different per verb, so we store this as a hashmap of verb -> volume_control. We might eventually want to
     * make this a hashmap of verb -> per-verb-device-properties-struct. */
    pa_hashmap *playback_volumes;
    pa_hashmap *capture_volumes;

    pa_alsa_mapping *playback_mapping;
    pa_alsa_mapping *capture_mapping;

    pa_idxset *conflicting_devices;
    pa_idxset *supported_devices;

    /* One device may be part of multiple ports, since each device has
     * a dedicated port, and in addition to that we sometimes generate ports
     * that represent combinations of devices. */
    pa_dynarray *ucm_ports; /* struct ucm_port */

    pa_alsa_jack *jack;
    pa_dynarray *hw_mute_jacks; /* pa_alsa_jack */
    pa_available_t available;

    char *eld_mixer_device_name;
    int eld_device;
};

void pa_alsa_ucm_device_update_available(pa_alsa_ucm_device *device);

struct pa_alsa_ucm_modifier {
    PA_LLIST_FIELDS(pa_alsa_ucm_modifier);

    pa_proplist *proplist;

    int n_confdev;
    int n_suppdev;

    const char **conflicting_devices;
    const char **supported_devices;

    pa_direction_t action_direction;

    char *media_role;

    /* Non-NULL if the modifier has its own PlaybackPCM/CapturePCM */
    pa_alsa_mapping *playback_mapping;
    pa_alsa_mapping *capture_mapping;

    /* Count how many role matched streams are running */
    int enabled_counter;
};

struct pa_alsa_ucm_verb {
    PA_LLIST_FIELDS(pa_alsa_ucm_verb);

    pa_proplist *proplist;
    unsigned priority;

    PA_LLIST_HEAD(pa_alsa_ucm_device, devices);
    PA_LLIST_HEAD(pa_alsa_ucm_modifier, modifiers);
};

struct pa_alsa_ucm_config {
    pa_sample_spec default_sample_spec;
    pa_channel_map default_channel_map;
    unsigned default_fragment_size_msec;
    unsigned default_n_fragments;

    snd_use_case_mgr_t *ucm_mgr;
    pa_alsa_ucm_verb *active_verb;

    pa_hashmap *mixers;
    PA_LLIST_HEAD(pa_alsa_ucm_verb, verbs);
    PA_LLIST_HEAD(pa_alsa_jack, jacks);
};

struct pa_alsa_ucm_mapping_context {
    pa_alsa_ucm_config *ucm;
    pa_direction_t direction;

    pa_idxset *ucm_devices;
    pa_idxset *ucm_modifiers;
};

struct pa_alsa_ucm_port_data {
    pa_alsa_ucm_config *ucm;
    pa_device_port *core_port;

    /* A single port will be associated with multiple devices if it represents
     * a combination of devices. */
    pa_dynarray *devices; /* pa_alsa_ucm_device */

    /* profile name -> pa_alsa_path for volume control */
    pa_hashmap *paths;
    /* Current path, set when activating profile */
    pa_alsa_path *path;

    /* ELD info */
    char *eld_mixer_device_name;
    int eld_device; /* PCM device number */
};

struct pa_alsa_ucm_volume {
    char *mixer_elem;	/* mixer element identifier */
    char *master_elem;	/* master mixer element identifier */
    char *master_type;
};

#endif
