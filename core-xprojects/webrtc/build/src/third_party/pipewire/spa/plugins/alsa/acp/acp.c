/* ALSA Card Profile
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

#include "acp.h"
#include "alsa-mixer.h"
#include "alsa-ucm.h"

int _acp_log_level = 1;
acp_log_func _acp_log_func;
void *_acp_log_data;

struct spa_i18n *acp_i18n;

#define VOLUME_ACCURACY (PA_VOLUME_NORM/100)  /* don't require volume adjustments to be perfectly correct. don't necessarily extend granularity in software unless the differences get greater than this level */

static const uint32_t channel_table[PA_CHANNEL_POSITION_MAX] = {
	[PA_CHANNEL_POSITION_MONO] = ACP_CHANNEL_MONO,

	[PA_CHANNEL_POSITION_FRONT_LEFT] = ACP_CHANNEL_FL,
	[PA_CHANNEL_POSITION_FRONT_RIGHT] = ACP_CHANNEL_FR,
	[PA_CHANNEL_POSITION_FRONT_CENTER] = ACP_CHANNEL_FC,

	[PA_CHANNEL_POSITION_REAR_CENTER] = ACP_CHANNEL_RC,
	[PA_CHANNEL_POSITION_REAR_LEFT] = ACP_CHANNEL_RL,
	[PA_CHANNEL_POSITION_REAR_RIGHT] = ACP_CHANNEL_RR,

	[PA_CHANNEL_POSITION_LFE] = ACP_CHANNEL_LFE,
	[PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER] = ACP_CHANNEL_FLC,
	[PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER] = ACP_CHANNEL_FRC,

	[PA_CHANNEL_POSITION_SIDE_LEFT] = ACP_CHANNEL_SL,
	[PA_CHANNEL_POSITION_SIDE_RIGHT] = ACP_CHANNEL_SR,

	[PA_CHANNEL_POSITION_AUX0] = ACP_CHANNEL_CUSTOM_START + 1,
	[PA_CHANNEL_POSITION_AUX1] = ACP_CHANNEL_CUSTOM_START + 2,
	[PA_CHANNEL_POSITION_AUX2] = ACP_CHANNEL_CUSTOM_START + 3,
	[PA_CHANNEL_POSITION_AUX3] = ACP_CHANNEL_CUSTOM_START + 4,
	[PA_CHANNEL_POSITION_AUX4] = ACP_CHANNEL_CUSTOM_START + 5,
	[PA_CHANNEL_POSITION_AUX5] = ACP_CHANNEL_CUSTOM_START + 6,
	[PA_CHANNEL_POSITION_AUX6] = ACP_CHANNEL_CUSTOM_START + 7,
	[PA_CHANNEL_POSITION_AUX7] = ACP_CHANNEL_CUSTOM_START + 8,
	[PA_CHANNEL_POSITION_AUX8] = ACP_CHANNEL_CUSTOM_START + 9,
	[PA_CHANNEL_POSITION_AUX9] = ACP_CHANNEL_CUSTOM_START + 10,
	[PA_CHANNEL_POSITION_AUX10] = ACP_CHANNEL_CUSTOM_START + 11,
	[PA_CHANNEL_POSITION_AUX11] = ACP_CHANNEL_CUSTOM_START + 12,
	[PA_CHANNEL_POSITION_AUX12] = ACP_CHANNEL_CUSTOM_START + 13,
	[PA_CHANNEL_POSITION_AUX13] = ACP_CHANNEL_CUSTOM_START + 14,
	[PA_CHANNEL_POSITION_AUX14] = ACP_CHANNEL_CUSTOM_START + 15,
	[PA_CHANNEL_POSITION_AUX15] = ACP_CHANNEL_CUSTOM_START + 16,
	[PA_CHANNEL_POSITION_AUX16] = ACP_CHANNEL_CUSTOM_START + 17,
	[PA_CHANNEL_POSITION_AUX17] = ACP_CHANNEL_CUSTOM_START + 18,
	[PA_CHANNEL_POSITION_AUX18] = ACP_CHANNEL_CUSTOM_START + 19,
	[PA_CHANNEL_POSITION_AUX19] = ACP_CHANNEL_CUSTOM_START + 20,
	[PA_CHANNEL_POSITION_AUX20] = ACP_CHANNEL_CUSTOM_START + 21,
	[PA_CHANNEL_POSITION_AUX21] = ACP_CHANNEL_CUSTOM_START + 22,
	[PA_CHANNEL_POSITION_AUX22] = ACP_CHANNEL_CUSTOM_START + 23,
	[PA_CHANNEL_POSITION_AUX23] = ACP_CHANNEL_CUSTOM_START + 24,
	[PA_CHANNEL_POSITION_AUX24] = ACP_CHANNEL_CUSTOM_START + 25,
	[PA_CHANNEL_POSITION_AUX25] = ACP_CHANNEL_CUSTOM_START + 26,
	[PA_CHANNEL_POSITION_AUX26] = ACP_CHANNEL_CUSTOM_START + 27,
	[PA_CHANNEL_POSITION_AUX27] = ACP_CHANNEL_CUSTOM_START + 28,
	[PA_CHANNEL_POSITION_AUX28] = ACP_CHANNEL_CUSTOM_START + 29,
	[PA_CHANNEL_POSITION_AUX29] = ACP_CHANNEL_CUSTOM_START + 30,
	[PA_CHANNEL_POSITION_AUX30] = ACP_CHANNEL_CUSTOM_START + 31,
	[PA_CHANNEL_POSITION_AUX31] = ACP_CHANNEL_CUSTOM_START + 32,

	[PA_CHANNEL_POSITION_TOP_CENTER] = ACP_CHANNEL_TC,

	[PA_CHANNEL_POSITION_TOP_FRONT_LEFT] = ACP_CHANNEL_TFL,
	[PA_CHANNEL_POSITION_TOP_FRONT_RIGHT] = ACP_CHANNEL_TFR,
	[PA_CHANNEL_POSITION_TOP_FRONT_CENTER] = ACP_CHANNEL_TFC,

	[PA_CHANNEL_POSITION_TOP_REAR_LEFT] = ACP_CHANNEL_TRL,
	[PA_CHANNEL_POSITION_TOP_REAR_RIGHT] = ACP_CHANNEL_TRR,
	[PA_CHANNEL_POSITION_TOP_REAR_CENTER] = ACP_CHANNEL_TRC,
};

static const char *channel_names[] = {
	[ACP_CHANNEL_UNKNOWN] = "UNK",
	[ACP_CHANNEL_NA] = "NA",
	[ACP_CHANNEL_MONO] = "MONO",
	[ACP_CHANNEL_FL] = "FL",
	[ACP_CHANNEL_FR] = "FR",
	[ACP_CHANNEL_FC] = "FC",
	[ACP_CHANNEL_LFE] = "LFE",
	[ACP_CHANNEL_SL] = "SL",
	[ACP_CHANNEL_SR] = "SR",
	[ACP_CHANNEL_FLC] = "FLC",
	[ACP_CHANNEL_FRC] = "FRC",
	[ACP_CHANNEL_RC] = "RC",
	[ACP_CHANNEL_RL] = "RL",
	[ACP_CHANNEL_RR] = "RR",
	[ACP_CHANNEL_TC] = "TC",
	[ACP_CHANNEL_TFL] = "TFL",
	[ACP_CHANNEL_TFC] = "TFC",
	[ACP_CHANNEL_TFR] = "TFR",
	[ACP_CHANNEL_TRL] = "TRL",
	[ACP_CHANNEL_TRC] = "TRC",
	[ACP_CHANNEL_TRR] = "TRR",
	[ACP_CHANNEL_RLC] = "RLC",
	[ACP_CHANNEL_RRC] = "RRC",
	[ACP_CHANNEL_FLW] = "FLW",
	[ACP_CHANNEL_FRW] = "FRW",
	[ACP_CHANNEL_LFE2] = "LFE2",
	[ACP_CHANNEL_FLH] = "FLH",
	[ACP_CHANNEL_FCH] = "FCH",
	[ACP_CHANNEL_FRH] = "FRH",
	[ACP_CHANNEL_TFLC] = "TFLC",
	[ACP_CHANNEL_TFRC] = "TFRC",
	[ACP_CHANNEL_TSL] = "TSL",
	[ACP_CHANNEL_TSR] = "TSR",
	[ACP_CHANNEL_LLFE] = "LLFE",
	[ACP_CHANNEL_RLFE] = "RLFE",
	[ACP_CHANNEL_BC] = "BC",
	[ACP_CHANNEL_BLC] = "BLC",
	[ACP_CHANNEL_BRC] = "BRC",
};

#define ACP_N_ELEMENTS(arr)	(sizeof(arr) / sizeof((arr)[0]))

static inline uint32_t channel_pa2acp(pa_channel_position_t channel)
{
	if (channel < 0 || (size_t)channel >= ACP_N_ELEMENTS(channel_table))
		return ACP_CHANNEL_UNKNOWN;
	return channel_table[channel];
}

char *acp_channel_str(char *buf, size_t len, enum acp_channel ch)
{
	if (ch >= ACP_CHANNEL_CUSTOM_START) {
		snprintf(buf, len, "AUX%d", ch - ACP_CHANNEL_CUSTOM_START);
	} else if (ch >= ACP_CHANNEL_UNKNOWN && ch <= ACP_CHANNEL_BRC) {
		snprintf(buf, len, "%s", channel_names[ch]);
	} else {
		snprintf(buf, len, "UNK");
	}
	return buf;
}


const char *acp_available_str(enum acp_available status)
{
	switch (status) {
	case ACP_AVAILABLE_UNKNOWN:
		return "unknown";
	case ACP_AVAILABLE_NO:
		return "no";
	case ACP_AVAILABLE_YES:
		return "yes";
	}
	return "error";
}

const char *acp_direction_str(enum acp_direction direction)
{
	switch (direction) {
	case ACP_DIRECTION_CAPTURE:
		return "capture";
	case ACP_DIRECTION_PLAYBACK:
		return "playback";
	}
	return "error";
}

static void port_free(void *data)
{
	pa_device_port *dp = data;
	pa_dynarray_clear(&dp->devices);
	pa_dynarray_clear(&dp->prof);
	pa_device_port_free(dp);
}

static void device_free(void *data)
{
	pa_alsa_device *dev = data;
	pa_dynarray_clear(&dev->port_array);
	pa_proplist_free(dev->proplist);
	pa_hashmap_free(dev->ports);
}

static void init_device(pa_card *impl, pa_alsa_device *dev, pa_alsa_direction_t direction,
		pa_alsa_mapping *m, uint32_t index)
{
	uint32_t i;

	dev->card = impl;
	dev->mapping = m;
	dev->device.index = index;
	dev->device.name = m->name;
	dev->device.description = m->description;
	dev->device.priority = m->priority;
	dev->device.device_strings = (const char **)m->device_strings;
	dev->device.format.format_mask = m->sample_spec.format;
	dev->device.format.rate_mask = m->sample_spec.rate;
	dev->device.format.channels = m->channel_map.channels;
	pa_cvolume_reset(&dev->real_volume, m->channel_map.channels);
	for (i = 0; i < m->channel_map.channels; i++)
		dev->device.format.map[i]= channel_pa2acp(m->channel_map.map[i]);
	dev->direction = direction;
	dev->proplist = pa_proplist_new();
	pa_proplist_update(dev->proplist, PA_UPDATE_REPLACE, m->proplist);
	if (direction == PA_ALSA_DIRECTION_OUTPUT) {
		dev->mixer_path_set = m->output_path_set;
		dev->pcm_handle = m->output_pcm;
		dev->device.direction = ACP_DIRECTION_PLAYBACK;
		pa_proplist_update(dev->proplist, PA_UPDATE_REPLACE, m->output_proplist);
	} else {
		dev->mixer_path_set = m->input_path_set;
		dev->pcm_handle = m->input_pcm;
		dev->device.direction = ACP_DIRECTION_CAPTURE;
		pa_proplist_update(dev->proplist, PA_UPDATE_REPLACE, m->input_proplist);
	}
	pa_proplist_sets(dev->proplist, PA_PROP_DEVICE_PROFILE_NAME, m->name);
	pa_proplist_sets(dev->proplist, PA_PROP_DEVICE_PROFILE_DESCRIPTION, m->description);
	pa_proplist_setf(dev->proplist, "card.profile.device", "%u", index);
	pa_proplist_as_dict(dev->proplist, &dev->device.props);

	dev->ports = pa_hashmap_new(pa_idxset_string_hash_func,
			pa_idxset_string_compare_func);
	if (m->ucm_context.ucm)
		dev->ucm_context = &m->ucm_context;
	pa_dynarray_init(&dev->port_array, NULL);
}

static int compare_profile(const void *a, const void *b)
{
	const pa_hashmap_item *i1 = a;
	const pa_hashmap_item *i2 = b;
	const pa_alsa_profile *p1, *p2;
	if (i1->key == NULL || i2->key == NULL)
		return 0;
	p1 = i1->value;
	p2 = i2->value;
	if (p1->profile.priority == 0 || p2->profile.priority == 0)
		return 0;
	return p2->profile.priority - p1->profile.priority;
}

static void profile_free(void *data)
{
	pa_alsa_profile *ap = data;
	pa_dynarray_clear(&ap->out.devices);
	if (ap->profile.flags & ACP_PROFILE_OFF) {
		free(ap->name);
		free(ap->description);
		free(ap);
	}
}

static int add_pro_profile(pa_card *impl, uint32_t index)
{
	snd_ctl_t *ctl_hndl;
	int err, dev, count = 0;
	pa_alsa_profile *ap;
	pa_alsa_profile_set *ps = impl->profile_set;
	pa_alsa_mapping *m;
	char *device;
	snd_pcm_info_t *pcminfo;
	pa_sample_spec ss;
	snd_pcm_uframes_t try_period_size, try_buffer_size;

	ss.format = PA_SAMPLE_S32LE;
	ss.rate = 48000;
	ss.channels = 64;

	ap = pa_xnew0(pa_alsa_profile, 1);
	ap->profile_set = ps;
	ap->profile.name = ap->name = pa_xstrdup("pro-audio");
	ap->profile.description = ap->description = pa_xstrdup(_("Pro Audio"));
	ap->profile.available = ACP_AVAILABLE_YES;
	ap->output_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
	ap->input_mappings = pa_idxset_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);
	pa_hashmap_put(ps->profiles, ap->name, ap);

	ap->output_name = pa_xstrdup("pro-output");
	ap->input_name = pa_xstrdup("pro-input");
	ap->priority = 1;

	pa_assert_se(asprintf(&device, "hw:%d", index) >= 0);

	if ((err = snd_ctl_open(&ctl_hndl, device, 0)) < 0) {
		pa_log_error("can't open control for card %s: %s",
				device, snd_strerror(err));
		return err;
	}

	snd_pcm_info_alloca(&pcminfo);

	dev = -1;
	while (1) {
		char desc[128], devstr[128], *name;

		if ((err = snd_ctl_pcm_next_device(ctl_hndl, &dev)) < 0) {
			pa_log_error("error iterating devices: %s", snd_strerror(err));
			break;
		}
		if (dev < 0)
			break;

		snd_pcm_info_set_device(pcminfo, dev);
		snd_pcm_info_set_subdevice(pcminfo, 0);

		snprintf(devstr, sizeof(devstr), "hw:%d,%d", index, dev);
		if (count++ == 0)
			snprintf(desc, sizeof(desc), "Pro");
		else
			snprintf(desc, sizeof(desc), "Pro %d", dev);

		snd_pcm_info_set_stream(pcminfo, SND_PCM_STREAM_PLAYBACK);
		if ((err = snd_ctl_pcm_info(ctl_hndl, pcminfo)) < 0) {
			if (err != -ENOENT)
				pa_log_error("error pcm info: %s", snd_strerror(err));
		}
		if (err >= 0) {
			pa_assert_se(asprintf(&name, "Mapping pro-output-%d", dev) >= 0);
			m = pa_alsa_mapping_get(ps, name);
			m->description = pa_xstrdup(desc);
			m->device_strings = pa_split_spaces_strv(devstr);

			try_period_size = 1024;
			try_buffer_size = 1024 * 64;
			m->sample_spec = ss;

			if ((m->output_pcm = pa_alsa_open_by_template(m->device_strings,
							devstr, NULL, &m->sample_spec,
							&m->channel_map, SND_PCM_STREAM_PLAYBACK,
							&try_period_size, &try_buffer_size,
							0, NULL, NULL, false))) {
				pa_alsa_init_proplist_pcm(NULL, m->output_proplist, m->output_pcm);
				snd_pcm_close(m->output_pcm);
				m->output_pcm = NULL;
				m->supported = true;
				pa_channel_map_init_pro(&m->channel_map, m->sample_spec.channels);
			}
			pa_idxset_put(ap->output_mappings, m, NULL);
			free(name);
		}

		snd_pcm_info_set_stream(pcminfo, SND_PCM_STREAM_CAPTURE);
		if ((err = snd_ctl_pcm_info(ctl_hndl, pcminfo)) < 0) {
			if (err != -ENOENT)
				pa_log_error("error pcm info: %s", snd_strerror(err));
		}
		if (err >= 0) {
			pa_assert_se(asprintf(&name, "Mapping pro-input-%d", dev) >= 0);
			m = pa_alsa_mapping_get(ps, name);
			m->description = pa_xstrdup(desc);
			m->device_strings = pa_split_spaces_strv(devstr);

			try_period_size = 1024;
			try_buffer_size = 1024 * 64;
			m->sample_spec = ss;

			if ((m->input_pcm = pa_alsa_open_by_template(m->device_strings,
							devstr, NULL, &m->sample_spec,
							&m->channel_map, SND_PCM_STREAM_CAPTURE,
							&try_period_size, &try_buffer_size,
							0, NULL, NULL, false))) {
				pa_alsa_init_proplist_pcm(NULL, m->input_proplist, m->input_pcm);
				snd_pcm_close(m->input_pcm);
				m->input_pcm = NULL;
				m->supported = true;
				pa_channel_map_init_pro(&m->channel_map, m->sample_spec.channels);
			}
			pa_idxset_put(ap->input_mappings, m, NULL);
			free(name);
		}
	}
	snd_ctl_close(ctl_hndl);

	return 0;
}


static void add_profiles(pa_card *impl)
{
	pa_alsa_profile *ap;
	void *state;
	struct acp_card_profile *cp;
	pa_device_port *dp;
	pa_alsa_device *dev;
	int n_profiles, n_ports, n_devices;
	uint32_t idx;

	n_devices = 0;
	pa_dynarray_init(&impl->out.devices, device_free);

	ap = pa_xnew0(pa_alsa_profile, 1);
	ap->profile.name = ap->name = pa_xstrdup("off");
	ap->profile.description = ap->description = pa_xstrdup(_("Off"));
	ap->profile.available = ACP_AVAILABLE_YES;
	ap->profile.flags = ACP_PROFILE_OFF;
	pa_hashmap_put(impl->profiles, ap->name, ap);

	if (!impl->use_ucm)
		add_pro_profile(impl, impl->card.index);

	PA_HASHMAP_FOREACH(ap, impl->profile_set->profiles, state) {
		pa_alsa_mapping *m;

		cp = &ap->profile;
		cp->name = ap->name;
		cp->description = ap->description;
		cp->priority = ap->priority ? ap->priority : 1;

		pa_dynarray_init(&ap->out.devices, NULL);

		if (ap->output_mappings) {
			PA_IDXSET_FOREACH(m, ap->output_mappings, idx) {
				dev = &m->output;
				if (dev->mapping == NULL) {
					init_device(impl, dev, PA_ALSA_DIRECTION_OUTPUT, m, n_devices++);
					pa_dynarray_append(&impl->out.devices, dev);
				}
				if (impl->use_ucm) {
					pa_alsa_ucm_add_ports_combination(NULL, &m->ucm_context,
						true, impl->ports, ap, NULL);
					pa_alsa_ucm_add_ports(&dev->ports, m->proplist, &m->ucm_context,
						true, impl, dev->pcm_handle, impl->profile_set->ignore_dB);
				}
				else
					pa_alsa_path_set_add_ports(m->output_path_set, ap, impl->ports,
							dev->ports, NULL);

				pa_dynarray_append(&ap->out.devices, dev);
			}
		}

		if (ap->input_mappings) {
			PA_IDXSET_FOREACH(m, ap->input_mappings, idx) {
				dev = &m->input;
				if (dev->mapping == NULL) {
					init_device(impl, dev, PA_ALSA_DIRECTION_INPUT, m, n_devices++);
					pa_dynarray_append(&impl->out.devices, dev);
				}

				if (impl->use_ucm) {
					pa_alsa_ucm_add_ports_combination(NULL, &m->ucm_context,
						false, impl->ports, ap, NULL);
					pa_alsa_ucm_add_ports(&dev->ports, m->proplist, &m->ucm_context,
						false, impl, dev->pcm_handle, impl->profile_set->ignore_dB);
				} else
					pa_alsa_path_set_add_ports(m->input_path_set, ap, impl->ports,
							dev->ports, NULL);

				pa_dynarray_append(&ap->out.devices, dev);
			}
		}
		cp->n_devices = pa_dynarray_size(&ap->out.devices);
		cp->devices = ap->out.devices.array.data;
		pa_hashmap_put(impl->profiles, ap->name, cp);
	}

	pa_dynarray_init(&impl->out.ports, NULL);
	n_ports = 0;
	PA_HASHMAP_FOREACH(dp, impl->ports, state) {
		void *state2;
		dp->card = impl;
		dp->port.index = n_ports++;
		dp->port.priority = dp->priority;
		pa_dynarray_init(&dp->prof, NULL);
		pa_dynarray_init(&dp->devices, NULL);
		n_profiles = 0;
		PA_HASHMAP_FOREACH(cp, dp->profiles, state2) {
			pa_dynarray_append(&dp->prof, cp);
			n_profiles++;
		}
		dp->port.n_profiles = n_profiles;
		dp->port.profiles = dp->prof.array.data;

		pa_proplist_setf(dp->proplist, "card.profile.port", "%u", dp->port.index);
		pa_proplist_as_dict(dp->proplist, &dp->port.props);
		pa_dynarray_append(&impl->out.ports, dp);
	}
	PA_DYNARRAY_FOREACH(dev, &impl->out.devices, idx) {
		PA_HASHMAP_FOREACH(dp, dev->ports, state) {
			pa_dynarray_append(&dev->port_array, dp);
			pa_dynarray_append(&dp->devices, dev);
		}
		dev->device.ports = dev->port_array.array.data;
		dev->device.n_ports = pa_dynarray_size(&dev->port_array);
	}
	PA_HASHMAP_FOREACH(dp, impl->ports, state) {
		dp->port.devices = dp->devices.array.data;
		dp->port.n_devices = pa_dynarray_size(&dp->devices);
	}

	pa_hashmap_sort(impl->profiles, compare_profile);

	n_profiles = 0;
	pa_dynarray_init(&impl->out.profiles, NULL);
	PA_HASHMAP_FOREACH(cp, impl->profiles, state) {
		cp->index = n_profiles++;
		pa_dynarray_append(&impl->out.profiles, cp);
	}
}

static pa_available_t calc_port_state(pa_device_port *p, pa_card *impl)
{
	void *state;
	pa_alsa_jack *jack;
	pa_available_t pa = PA_AVAILABLE_UNKNOWN;
	pa_device_port *port;

	PA_HASHMAP_FOREACH(jack, impl->jacks, state) {
		pa_available_t cpa;

		if (impl->use_ucm)
			port = pa_hashmap_get(impl->ports, jack->name);
		else {
			if (jack->path)
				port = jack->path->port;
			else
				continue;
		}

		if (p != port)
			continue;

		cpa = jack->plugged_in ? jack->state_plugged : jack->state_unplugged;

		if (cpa == PA_AVAILABLE_NO) {
			/* If a plugged-in jack causes the availability to go to NO, it
			* should override all other availability information (like a
			* blacklist) so set and bail */
			if (jack->plugged_in) {
				pa = cpa;
				break;
			}

			/* If the current availability is unknown go the more precise no,
			* but otherwise don't change state */
			if (pa == PA_AVAILABLE_UNKNOWN)
				pa = cpa;
		} else if (cpa == PA_AVAILABLE_YES) {
			/* Output is available through at least one jack, so go to that
			* level of availability. We still need to continue iterating through
			* the jacks in case a jack is plugged in that forces the state to no
			*/
			pa = cpa;
		}
	}
	return pa;
}

static void profile_set_available(pa_card *impl, uint32_t index,
		enum acp_available status, bool emit)
{
	struct acp_card_profile *p = impl->card.profiles[index];
	enum acp_available old = p->available;

	if (old != status)
		pa_log_info("Profile %s available %s -> %s", p->name,
				acp_available_str(old), acp_available_str(status));

	p->available = status;

	if (emit && impl->events && impl->events->profile_available)
		impl->events->profile_available(impl->user_data, index,
				old, status);
}

struct temp_port_avail {
	pa_device_port *port;
	pa_available_t avail;
};

static int report_jack_state(snd_mixer_elem_t *melem, unsigned int mask)
{
	pa_card *impl = snd_mixer_elem_get_callback_private(melem);
	snd_hctl_elem_t *elem = snd_mixer_elem_get_private(melem);
	snd_ctl_elem_value_t *elem_value;
	bool plugged_in;
	void *state;
	pa_alsa_jack *jack;
	struct temp_port_avail *tp, *tports;
	pa_alsa_profile *profile;
	enum acp_available active_available = ACP_AVAILABLE_UNKNOWN;
	size_t size;

#if 0
	/* Changing the jack state may cause a port change, and a port change will
	 * make the sink or source change the mixer settings. If there are multiple
	 * users having pulseaudio running, the mixer changes done by inactive
	 * users may mess up the volume settings for the active users, because when
	 * the inactive users change the mixer settings, those changes are picked
	 * up by the active user's pulseaudio instance and the changes are
	 * interpreted as if the active user changed the settings manually e.g.
	 * with alsamixer. Even single-user systems suffer from this, because gdm
	 * runs its own pulseaudio instance.
	 *
	 * We rerun this function when being unsuspended to catch up on jack state
	 * changes */
	if (u->card->suspend_cause & PA_SUSPEND_SESSION)
		return 0;
#endif

	if (mask == SND_CTL_EVENT_MASK_REMOVE)
		return 0;

	snd_ctl_elem_value_alloca(&elem_value);
	if (snd_hctl_elem_read(elem, elem_value) < 0) {
		pa_log_warn("Failed to read jack detection from '%s'", pa_strnull(snd_hctl_elem_get_name(elem)));
		return 0;
	}

	plugged_in = !!snd_ctl_elem_value_get_boolean(elem_value, 0);

	pa_log_debug("Jack '%s' is now %s", pa_strnull(snd_hctl_elem_get_name(elem)),
			plugged_in ? "plugged in" : "unplugged");

	size = sizeof(struct temp_port_avail) * (pa_hashmap_size(impl->jacks)+1);
	tports = tp = alloca(size);
	memset(tports, 0, size);

	PA_HASHMAP_FOREACH(jack, impl->jacks, state)
		if (jack->melem == melem) {
			pa_alsa_jack_set_plugged_in(jack, plugged_in);

			if (impl->use_ucm) {
				/* When using UCM, pa_alsa_jack_set_plugged_in() maps the jack
				 * state to port availability. */
				continue;
			}

			/* When not using UCM, we have to do the jack state -> port
			 * availability mapping ourselves. */
			pa_assert_se(tp->port = jack->path->port);
			tp->avail = calc_port_state(tp->port, impl);
			tp++;
		}

	/* Report available ports before unavailable ones: in case port 1
	 * becomes available when port 2 becomes unavailable,
	 * this prevents an unnecessary switch port 1 -> port 3 -> port 2 */

	for (tp = tports; tp->port; tp++)
		if (tp->avail != PA_AVAILABLE_NO)
			pa_device_port_set_available(tp->port, tp->avail);
	for (tp = tports; tp->port; tp++)
		if (tp->avail == PA_AVAILABLE_NO)
			pa_device_port_set_available(tp->port, tp->avail);

	for (tp = tports; tp->port; tp++) {
		pa_alsa_port_data *data;

		data = PA_DEVICE_PORT_DATA(tp->port);

		if (!data->suspend_when_unavailable)
			continue;

#if 0
		pa_sink *sink;
		uint32_t idx;
		PA_IDXSET_FOREACH(sink, u->core->sinks, idx) {
			if (sink->active_port == tp->port)
				pa_sink_suspend(sink, tp->avail == PA_AVAILABLE_NO, PA_SUSPEND_UNAVAILABLE);
		}
#endif
	}

	/* Update profile availabilities. Ideally we would mark all profiles
	 * unavailable that contain unavailable devices. We can't currently do that
	 * in all cases, because if there are multiple sinks in a profile, and the
	 * profile contains a mix of available and unavailable ports, we don't know
	 * how the ports are distributed between the different sinks. It's possible
	 * that some sinks contain only unavailable ports, in which case we should
	 * mark the profile as unavailable, but it's also possible that all sinks
	 * contain at least one available port, in which case we should mark the
	 * profile as available. Until the data structures are improved so that we
	 * can distinguish between these two cases, we mark the problematic cases
	 * as available (well, "unknown" to be precise, but there's little
	 * practical difference).
	 *
	 * When all output ports are unavailable, we know that all sinks are
	 * unavailable, and therefore the profile is marked unavailable as well.
	 * The same applies to input ports as well, of course.
	 *
	 * If there are no output ports at all, but the profile contains at least
	 * one sink, then the output is considered to be available. */
	if (impl->card.active_profile_index != ACP_INVALID_INDEX)
		active_available = impl->card.profiles[impl->card.active_profile_index]->available;

	PA_HASHMAP_FOREACH(profile, impl->profiles, state) {
		pa_device_port *port;
		void *state2;
		bool has_input_port = false;
		bool has_output_port = false;
		bool found_available_input_port = false;
		bool found_available_output_port = false;
		enum acp_available available = ACP_AVAILABLE_UNKNOWN;

		if (profile->profile.flags & ACP_PROFILE_OFF)
			continue;

		PA_HASHMAP_FOREACH(port, impl->ports, state2) {
			if (!pa_hashmap_get(port->profiles, profile->profile.name))
				continue;

			if (port->port.direction == ACP_DIRECTION_CAPTURE) {
				has_input_port = true;
				if (port->port.available != ACP_AVAILABLE_NO)
					found_available_input_port = true;
			} else {
				has_output_port = true;
				if (port->port.available != ACP_AVAILABLE_NO)
					found_available_output_port = true;
			}
		}

		if ((has_input_port && !found_available_input_port) ||
		    (has_output_port && !found_available_output_port))
			available = ACP_AVAILABLE_NO;

		if (has_input_port && !has_output_port && found_available_input_port)
			available = ACP_AVAILABLE_YES;
		if (has_output_port && !has_input_port && found_available_output_port)
			available = ACP_AVAILABLE_YES;
		if (has_output_port && has_input_port && found_available_output_port && found_available_input_port)
			available = ACP_AVAILABLE_YES;

		/* We want to update the active profile's status last, so logic that
		 * may change the active profile based on profile availability status
		 * has an updated view of all profiles' availabilities. */
		if (profile->profile.index == impl->card.active_profile_index)
			active_available = available;
		else
			profile_set_available(impl, profile->profile.index, available, false);
	}

	if (impl->card.active_profile_index != ACP_INVALID_INDEX)
		profile_set_available(impl, impl->card.active_profile_index, active_available, true);

	return 0;
}

static void init_jacks(pa_card *impl)
{
	void *state;
	pa_alsa_path* path;
	pa_alsa_jack* jack;
	char buf[64];

	impl->jacks = pa_hashmap_new(pa_idxset_trivial_hash_func, pa_idxset_trivial_compare_func);

	if (impl->use_ucm) {
		PA_LLIST_FOREACH(jack, impl->ucm.jacks)
			if (jack->has_control)
				pa_hashmap_put(impl->jacks, jack, jack);
	} else {
		/* See if we have any jacks */
		if (impl->profile_set->output_paths)
			PA_HASHMAP_FOREACH(path, impl->profile_set->output_paths, state)
				PA_LLIST_FOREACH(jack, path->jacks)
					if (jack->has_control)
						pa_hashmap_put(impl->jacks, jack, jack);

		if (impl->profile_set->input_paths)
			PA_HASHMAP_FOREACH(path, impl->profile_set->input_paths, state)
				PA_LLIST_FOREACH(jack, path->jacks)
					if (jack->has_control)
						pa_hashmap_put(impl->jacks, jack, jack);
	}

	pa_log_debug("Found %d jacks.", pa_hashmap_size(impl->jacks));

	if (pa_hashmap_size(impl->jacks) == 0)
		return;

	PA_HASHMAP_FOREACH(jack, impl->jacks, state) {
		if (!jack->mixer_device_name) {
			jack->mixer_handle = pa_alsa_open_mixer(impl->ucm.mixers, impl->card.index, false);
			if (!jack->mixer_handle) {
				pa_log("Failed to open mixer for card %d for jack detection", impl->card.index);
				continue;
			}
		} else {
			jack->mixer_handle = pa_alsa_open_mixer_by_name(impl->ucm.mixers, jack->mixer_device_name, false);
			if (!jack->mixer_handle) {
				pa_log("Failed to open mixer '%s' for jack detection", jack->mixer_device_name);
				continue;
			}
		}

		pa_alsa_mixer_use_for_poll(impl->ucm.mixers, jack->mixer_handle);
		jack->melem = pa_alsa_mixer_find_card(jack->mixer_handle, &jack->alsa_id, 0);
		if (!jack->melem) {
			pa_alsa_mixer_id_to_string(buf, sizeof(buf), &jack->alsa_id);
			pa_log_warn("Jack '%s' seems to have disappeared.", buf);
			pa_alsa_jack_set_has_control(jack, false);
			continue;
		}
		snd_mixer_elem_set_callback(jack->melem, report_jack_state);
		snd_mixer_elem_set_callback_private(jack->melem, impl);
		report_jack_state(jack->melem, 0);
	}
}
static pa_device_port* find_port_with_eld_device(pa_card *impl, int device)
{
	void *state;
	pa_device_port *p;

	if (impl->use_ucm) {
		PA_HASHMAP_FOREACH(p, impl->ports, state) {
			pa_alsa_ucm_port_data *data = PA_DEVICE_PORT_DATA(p);
			pa_assert(data->eld_mixer_device_name);
			if (device == data->eld_device)
				return p;
		}
	} else {
		PA_HASHMAP_FOREACH(p, impl->ports, state) {
			pa_alsa_port_data *data = PA_DEVICE_PORT_DATA(p);
			pa_assert(data->path);
			if (device == data->path->eld_device)
				return p;
		}
	}
	return NULL;
}

static int hdmi_eld_changed(snd_mixer_elem_t *melem, unsigned int mask)
{
	pa_card *impl = snd_mixer_elem_get_callback_private(melem);
	snd_hctl_elem_t *elem = snd_mixer_elem_get_private(melem);
	int device = snd_hctl_elem_get_device(elem);
	const char *old_monitor_name;
	pa_device_port *p;
	pa_hdmi_eld eld;
	bool changed = false;

	if (mask == SND_CTL_EVENT_MASK_REMOVE)
		return 0;

	p = find_port_with_eld_device(impl, device);
	if (p == NULL) {
		pa_log_error("Invalid device changed in ALSA: %d", device);
		return 0;
	}

	if (pa_alsa_get_hdmi_eld(elem, &eld) < 0)
		memset(&eld, 0, sizeof(eld));

	old_monitor_name = pa_proplist_gets(p->proplist, PA_PROP_DEVICE_PRODUCT_NAME);
	if (eld.monitor_name[0] == '\0') {
		changed |= old_monitor_name != NULL;
		pa_proplist_unset(p->proplist, PA_PROP_DEVICE_PRODUCT_NAME);
	} else {
		changed |= (old_monitor_name == NULL) || (strcmp(old_monitor_name, eld.monitor_name) != 0);
		pa_proplist_sets(p->proplist, PA_PROP_DEVICE_PRODUCT_NAME, eld.monitor_name);
	}
	pa_proplist_as_dict(p->proplist, &p->port.props);

	if (changed && mask != 0 && impl->events && impl->events->props_changed)
		impl->events->props_changed(impl->user_data);
	return 0;
}

static void init_eld_ctls(pa_card *impl)
{
	void *state;
	pa_device_port *port;

	/* The code in this function expects ports to have a pa_alsa_port_data
	* struct as their data, but in UCM mode ports don't have any data. Hence,
	* the ELD controls can't currently be used in UCM mode. */
	PA_HASHMAP_FOREACH(port, impl->ports, state) {
		snd_mixer_t *mixer_handle;
		snd_mixer_elem_t* melem;
		int device;

		if (impl->use_ucm) {
			pa_alsa_ucm_port_data *data = PA_DEVICE_PORT_DATA(port);
			device = data->eld_device;
			if (device < 0 || !data->eld_mixer_device_name)
				continue;

			mixer_handle = pa_alsa_open_mixer_by_name(impl->ucm.mixers, data->eld_mixer_device_name, true);
		} else {
			pa_alsa_port_data *data = PA_DEVICE_PORT_DATA(port);

			pa_assert(data->path);

			device = data->path->eld_device;
			if (device < 0)
				continue;

			mixer_handle = pa_alsa_open_mixer(impl->ucm.mixers, impl->card.index, true);
		}

		if (!mixer_handle)
			continue;

		melem = pa_alsa_mixer_find_pcm(mixer_handle, "ELD", device);
		if (melem) {
			pa_alsa_mixer_use_for_poll(impl->ucm.mixers, mixer_handle);
			snd_mixer_elem_set_callback(melem, hdmi_eld_changed);
			snd_mixer_elem_set_callback_private(melem, impl);
			hdmi_eld_changed(melem, 0);
			pa_log_info("ELD device found for port %s (%d).", port->port.name, device);
		}
		else
			pa_log_debug("No ELD device found for port %s (%d).", port->port.name, device);
	}
}

uint32_t acp_card_find_best_profile_index(struct acp_card *card, const char *name)
{
	uint32_t i;
	uint32_t best, best2, off;
	struct acp_card_profile **profiles = card->profiles;

	best = best2 = ACP_INVALID_INDEX;
	off = 0;

	for (i = 0; i < card->n_profiles; i++) {
		struct acp_card_profile *p = profiles[i];

		if (name) {
			if (strcmp(name, p->name) == 0)
				best = i;
		} else if (p->flags & ACP_PROFILE_OFF) {
			off = i;
		} else if (p->available == ACP_AVAILABLE_YES) {
			if (best == ACP_INVALID_INDEX || p->priority > profiles[best]->priority)
				best = i;
		} else if (p->available != ACP_AVAILABLE_NO) {
			if (best2 == ACP_INVALID_INDEX || p->priority > profiles[best2]->priority)
				best2 = i;
		}
	}
	if (best == ACP_INVALID_INDEX)
		best = best2;
	if (best == ACP_INVALID_INDEX)
		best = off;
	return best;
}

static void find_mixer(pa_card *impl, pa_alsa_device *dev, const char *element, bool ignore_dB)
{
	const char *mdev;
	pa_alsa_mapping *mapping = dev->mapping;

	if (!mapping && !element)
		return;

	if (!element && mapping && pa_alsa_path_set_is_empty(dev->mixer_path_set))
		return;

	mdev = pa_proplist_gets(mapping->proplist, "alsa.mixer_device");
	if (mdev) {
		dev->mixer_handle = pa_alsa_open_mixer_by_name(impl->ucm.mixers, mdev, true);
	} else {
		dev->mixer_handle = pa_alsa_open_mixer(impl->ucm.mixers, impl->card.index, true);
	}
	if (!dev->mixer_handle) {
		pa_log_info("Failed to find a working mixer device.");
		return;
	}

	if (element) {
		if (!(dev->mixer_path = pa_alsa_path_synthesize(element, dev->direction)))
			goto fail;

		if (pa_alsa_path_probe(dev->mixer_path, NULL, dev->mixer_handle, ignore_dB) < 0)
			goto fail;

		pa_log_debug("Probed mixer path %s:", dev->mixer_path->name);
		pa_alsa_path_dump(dev->mixer_path);
	}
	return;

fail:
	if (dev->mixer_path) {
		pa_alsa_path_free(dev->mixer_path);
		dev->mixer_path = NULL;
	}
	dev->mixer_handle = NULL;
}

static int mixer_callback(snd_mixer_elem_t *elem, unsigned int mask)
{
	pa_alsa_device *dev = snd_mixer_elem_get_callback_private(elem);

	if (mask == SND_CTL_EVENT_MASK_REMOVE)
		return 0;

	pa_log_info("%p mixer changed %d", dev, mask);

	if (mask & SND_CTL_EVENT_MASK_VALUE) {
		if (dev->read_volume)
			dev->read_volume(dev);
		if (dev->read_mute)
			dev->read_mute(dev);
	}
	return 0;
}

static int read_volume(pa_alsa_device *dev)
{
	pa_card *impl = dev->card;
	pa_cvolume r;
	uint32_t i;
	int res;

	if ((res = pa_alsa_path_get_volume(dev->mixer_path, dev->mixer_handle, &dev->mapping->channel_map, &r)) < 0)
		return res;

	/* Shift down by the base volume, so that 0dB becomes maximum volume */
	pa_sw_cvolume_multiply_scalar(&r, &r, dev->base_volume);

	if (pa_cvolume_equal(&dev->real_volume, &r))
		return 0;

	dev->real_volume = r;
	pa_log_info("New hardware volume:");
	for (i = 0; i < r.channels; i++)
		pa_log_debug("  %d: %d", i, r.values[i]);

	if (impl->events && impl->events->volume_changed)
		impl->events->volume_changed(impl->user_data, &dev->device);

	return 0;
}

static void set_volume(pa_alsa_device *dev, const pa_cvolume *v)
{
	pa_cvolume r;

	dev->real_volume = *v;

	/* Shift up by the base volume */
	pa_sw_cvolume_divide_scalar(&r, &dev->real_volume, dev->base_volume);

	if (pa_alsa_path_set_volume(dev->mixer_path, dev->mixer_handle, &dev->mapping->channel_map,
			&r, false, true) < 0)
		return;

	/* Shift down by the base volume, so that 0dB becomes maximum volume */
	pa_sw_cvolume_multiply_scalar(&r, &r, dev->base_volume);

	dev->hardware_volume = r;

	if (dev->mixer_path->has_dB) {
		pa_cvolume new_soft_volume;
		bool accurate_enough;

		/* Match exactly what the user requested by software */
		pa_sw_cvolume_divide(&new_soft_volume, &dev->real_volume, &dev->hardware_volume);

		/* If the adjustment to do in software is only minimal we
		 * can skip it. That saves us CPU at the expense of a bit of
		 * accuracy */
		accurate_enough =
			(pa_cvolume_min(&new_soft_volume) >= (PA_VOLUME_NORM - VOLUME_ACCURACY)) &&
			(pa_cvolume_max(&new_soft_volume) <= (PA_VOLUME_NORM + VOLUME_ACCURACY));

		pa_log_debug("Requested volume: %d", pa_cvolume_max(&dev->real_volume));
		pa_log_debug("Got hardware volume: %d", pa_cvolume_max(&dev->hardware_volume));
		pa_log_debug("Calculated software volume: %d (accurate-enough=%s)",
				pa_cvolume_max(&new_soft_volume),
				pa_yes_no(accurate_enough));

		if (accurate_enough)
			pa_cvolume_reset(&new_soft_volume, new_soft_volume.channels);

		dev->soft_volume = new_soft_volume;
	} else {
		pa_log_debug("Wrote hardware volume: %d", pa_cvolume_max(&r));
		/* We can't match exactly what the user requested, hence let's
		 * at least tell the user about it */
		dev->real_volume = r;
	}
}

static int read_mute(pa_alsa_device *dev)
{
	pa_card *impl = dev->card;
	bool mute;
	int res;

	if ((res = pa_alsa_path_get_mute(dev->mixer_path, dev->mixer_handle, &mute)) < 0)
		return res;

	if (mute == dev->muted)
		return 0;

	dev->muted = mute;
	pa_log_info("New hardware muted: %d", mute);

	if (impl->events && impl->events->mute_changed)
		impl->events->mute_changed(impl->user_data, &dev->device);

	return 0;
}

static void set_mute(pa_alsa_device *dev, bool mute)
{
	dev->muted = mute;
	pa_alsa_path_set_mute(dev->mixer_path, dev->mixer_handle, mute);
}

static void mixer_volume_init(pa_card *impl, pa_alsa_device *dev)
{
	pa_assert(dev);

	if (impl->soft_mixer || !dev->mixer_path || !dev->mixer_path->has_volume) {
		dev->read_volume = NULL;
		dev->set_volume = NULL;
		pa_log_info("Driver does not support hardware volume control, "
				"falling back to software volume control.");
		dev->base_volume = PA_VOLUME_NORM;
		dev->n_volume_steps = PA_VOLUME_NORM+1;
		dev->device.flags &= ~ACP_DEVICE_HW_VOLUME;
	} else {
		dev->read_volume = read_volume;
		dev->set_volume = set_volume;
		dev->device.flags |= ACP_DEVICE_HW_VOLUME;

#if 0
		if (u->mixer_path->has_dB && u->deferred_volume) {
			pa_sink_set_write_volume_callback(u->sink, sink_write_volume_cb);
			pa_log_info("Successfully enabled deferred volume.");
		} else
			pa_sink_set_write_volume_callback(u->sink, NULL);
#endif

		if (dev->mixer_path->has_dB) {
			dev->decibel_volume = true;
			pa_log_info("Hardware volume ranges from %0.2f dB to %0.2f dB.",
					dev->mixer_path->min_dB, dev->mixer_path->max_dB);

			dev->base_volume = pa_sw_volume_from_dB(-dev->mixer_path->max_dB);
			dev->n_volume_steps = PA_VOLUME_NORM+1;

			pa_log_info("Fixing base volume to %0.2f dB", pa_sw_volume_to_dB(dev->base_volume));
		} else {
			dev->decibel_volume = false;
			pa_log_info("Hardware volume ranges from %li to %li.",
					dev->mixer_path->min_volume, dev->mixer_path->max_volume);
			dev->base_volume = PA_VOLUME_NORM;
			dev->n_volume_steps = dev->mixer_path->max_volume - dev->mixer_path->min_volume + 1;
		}
		pa_log_info("Using hardware volume control. Hardware dB scale %s.",
				dev->mixer_path->has_dB ? "supported" : "not supported");
	}
	dev->device.base_volume = pa_sw_volume_to_linear(dev->base_volume);;
	dev->device.volume_step = 1.0f / dev->n_volume_steps;

	if (impl->soft_mixer || !dev->mixer_path || !dev->mixer_path->has_mute) {
		dev->read_mute = NULL;
		dev->set_mute = NULL;
		pa_log_info("Driver does not support hardware mute control, falling back to software mute control.");
		dev->device.flags &= ~ACP_DEVICE_HW_MUTE;
	} else {
		dev->read_mute = read_mute;
		dev->set_mute = set_mute;
		pa_log_info("Using hardware mute control.");
		dev->device.flags |= ACP_DEVICE_HW_MUTE;
	}
}


static int setup_mixer(pa_card *impl, pa_alsa_device *dev, bool ignore_dB)
{
	int res;
	bool need_mixer_callback = false;

	/* This code is before the u->mixer_handle check, because if the UCM
	* configuration doesn't specify volume or mute controls, u->mixer_handle
	* will be NULL, but the UCM device enable sequence will still need to be
	* executed. */
	if (dev->active_port && dev->ucm_context) {
		if ((res = pa_alsa_ucm_set_port(dev->ucm_context, dev->active_port,
					dev->direction == PA_ALSA_DIRECTION_OUTPUT)) < 0)
			return res;
	}

	if (!dev->mixer_handle)
		return 0;

	if (dev->active_port) {
		if (!impl->use_ucm) {
			pa_alsa_port_data *data;

			/* We have a list of supported paths, so let's activate the
			 * one that has been chosen as active */
			data = PA_DEVICE_PORT_DATA(dev->active_port);
			dev->mixer_path = data->path;

			pa_alsa_path_select(data->path, data->setting, dev->mixer_handle, dev->muted);
		} else {
			pa_alsa_ucm_port_data *data;

			data = PA_DEVICE_PORT_DATA(dev->active_port);

			/* Now activate volume controls, if any */
			if (data->path) {
				dev->mixer_path = data->path;
				pa_alsa_path_select(dev->mixer_path, NULL, dev->mixer_handle, dev->muted);
			}
		}
	} else {
		if (!dev->mixer_path && dev->mixer_path_set)
			dev->mixer_path = pa_hashmap_first(dev->mixer_path_set->paths);

		if (dev->mixer_path) {
			/* Hmm, we have only a single path, then let's activate it */
			pa_alsa_path_select(dev->mixer_path, dev->mixer_path->settings,
					dev->mixer_handle, dev->muted);
		} else
			return 0;
	}

	mixer_volume_init(impl, dev);

	/* Will we need to register callbacks? */
	if (dev->mixer_path_set && dev->mixer_path_set->paths) {
		pa_alsa_path *p;
		void *state;

		PA_HASHMAP_FOREACH(p, dev->mixer_path_set->paths, state) {
			if (p->has_volume || p->has_mute)
				need_mixer_callback = true;
		}
	}
	else if (dev->mixer_path)
		need_mixer_callback = dev->mixer_path->has_volume || dev->mixer_path->has_mute;

	if (!impl->soft_mixer && need_mixer_callback) {
		pa_alsa_mixer_use_for_poll(impl->ucm.mixers, dev->mixer_handle);
		if (dev->mixer_path_set)
			pa_alsa_path_set_set_callback(dev->mixer_path_set, dev->mixer_handle, mixer_callback, dev);
		else
			pa_alsa_path_set_callback(dev->mixer_path, dev->mixer_handle, mixer_callback, dev);
	}
	return 0;
}

static int device_disable(pa_card *impl, pa_alsa_mapping *mapping, pa_alsa_device *dev)
{
	dev->device.flags &= ~ACP_DEVICE_ACTIVE;
	if (dev->active_port) {
		dev->active_port->port.flags &= ~ACP_PORT_ACTIVE;
		dev->active_port = NULL;
	}
	return 0;
}

static int device_enable(pa_card *impl, pa_alsa_mapping *mapping, pa_alsa_device *dev)
{
	const char *mod_name;
	bool ignore_dB = false;
	uint32_t i, port_index;
	int res;

	if (impl->use_ucm &&
	    (mod_name = pa_proplist_gets(mapping->proplist, PA_ALSA_PROP_UCM_MODIFIER))) {
		if (snd_use_case_set(impl->ucm.ucm_mgr, "_enamod", mod_name) < 0)
			pa_log("Failed to enable ucm modifier %s", mod_name);
		else
			pa_log_debug("Enabled ucm modifier %s", mod_name);
	}

	pa_log_info("Device: %s mapping '%s' (%s).", dev->device.description,
			mapping->description, mapping->name);

	dev->device.flags |= ACP_DEVICE_ACTIVE;

	find_mixer(impl, dev, NULL, ignore_dB);

	/* Synchronize priority values, as it may have changed when setting the profile */
	for (i = 0; i < impl->card.n_ports; i++) {
		pa_device_port *p = (pa_device_port *)impl->card.ports[i];
		p->port.priority = p->priority;
	}

	if (impl->auto_port)
		port_index = acp_device_find_best_port_index(&dev->device, NULL);
	else
		port_index = ACP_INVALID_INDEX;

	if (port_index == ACP_INVALID_INDEX)
		dev->active_port = NULL;
	else
		dev->active_port = (pa_device_port*)impl->card.ports[port_index];

	if (dev->active_port)
		dev->active_port->port.flags |= ACP_PORT_ACTIVE;

	if ((res = setup_mixer(impl, dev, ignore_dB)) < 0)
		return res;

	if (dev->read_volume)
		dev->read_volume(dev);
	if (dev->read_mute)
		dev->read_mute(dev);
	return 0;
}

int acp_card_set_profile(struct acp_card *card, uint32_t new_index, uint32_t flags)
{
	pa_card *impl = (pa_card *)card;
	pa_alsa_mapping *am;
	uint32_t old_index = impl->card.active_profile_index;
	struct acp_card_profile **profiles = card->profiles;
	pa_alsa_profile *op, *np;
	uint32_t idx;
	int res;

	if (new_index >= card->n_profiles)
		return -EINVAL;

	op = old_index != ACP_INVALID_INDEX ? (pa_alsa_profile*)profiles[old_index] : NULL;
	np = (pa_alsa_profile*)profiles[new_index];

	if (op == np)
		return 0;

	pa_log_info("activate profile: %s (%d)", np->profile.name, new_index);

	if (op && op->output_mappings) {
		PA_IDXSET_FOREACH(am, op->output_mappings, idx) {
			if (np->output_mappings &&
			    pa_idxset_get_by_data(np->output_mappings, am, NULL))
				continue;

			device_disable(impl, am, &am->output);
		}
	}
	if (op && op->input_mappings) {
		PA_IDXSET_FOREACH(am, op->input_mappings, idx) {
			if (np->input_mappings &&
			    pa_idxset_get_by_data(np->input_mappings, am, NULL))
				continue;

			device_disable(impl, am, &am->input);
		}
	}

	/* if UCM is available for this card then update the verb */
	if (impl->use_ucm) {
		if ((res = pa_alsa_ucm_set_profile(&impl->ucm, impl,
		    np->profile.flags & ACP_PROFILE_OFF ? NULL : np->profile.name,
		    op ? op->profile.name : NULL)) < 0) {
			return res;
		}
	}

	if (np->output_mappings) {
		PA_IDXSET_FOREACH(am, np->output_mappings, idx) {
			if (impl->use_ucm)
				/* Update ports priorities */
				pa_alsa_ucm_add_ports_combination(am->output.ports, &am->ucm_context,
					true, impl->ports, np, NULL);
			device_enable(impl, am, &am->output);
		}
	}

	if (np->input_mappings) {
		PA_IDXSET_FOREACH(am, np->input_mappings, idx) {
			if (impl->use_ucm)
				/* Update ports priorities */
				pa_alsa_ucm_add_ports_combination(am->input.ports, &am->ucm_context,
					false, impl->ports, np, NULL);
			device_enable(impl, am, &am->input);
		}
	}
	if (op)
		op->profile.flags &= ~(ACP_PROFILE_ACTIVE | ACP_PROFILE_SAVE);
	np->profile.flags |= ACP_PROFILE_ACTIVE | flags;
	impl->card.active_profile_index = new_index;

	if (impl->events && impl->events->profile_changed)
		impl->events->profile_changed(impl->user_data, old_index,
				new_index);
	return 0;
}

static void prune_singleton_availability_groups(pa_hashmap *ports) {
    pa_device_port *p;
    pa_hashmap *group_counts;
    void *state, *count;
    const char *group;

    /* Collect groups and erase those that don't have more than 1 path */
    group_counts = pa_hashmap_new(pa_idxset_string_hash_func, pa_idxset_string_compare_func);

    PA_HASHMAP_FOREACH(p, ports, state) {
        if (p->availability_group) {
            count = pa_hashmap_get(group_counts, p->availability_group);
            pa_hashmap_remove(group_counts, p->availability_group);
            pa_hashmap_put(group_counts, p->availability_group, PA_UINT_TO_PTR(PA_PTR_TO_UINT(count) + 1));
        }
    }

    /* Now we have an availability_group -> count map, let's drop all groups
     * that have only one member */
    PA_HASHMAP_FOREACH_KV(group, count, group_counts, state) {
        if (count == PA_UINT_TO_PTR(1))
            pa_hashmap_remove(group_counts, group);
    }

    PA_HASHMAP_FOREACH(p, ports, state) {
        if (p->availability_group && !pa_hashmap_get(group_counts, p->availability_group)) {
            pa_log_debug("Pruned singleton availability group %s from port %s", p->availability_group, p->name);
            pa_xfree(p->availability_group);
            p->availability_group = NULL;
        }
    }

    pa_hashmap_free(group_counts);
}

static const char *acp_dict_lookup(const struct acp_dict *dict, const char *key)
{
	const struct acp_dict_item *it;
	acp_dict_for_each(it, dict) {
		if (strcmp(key, it->key) == 0)
			return it->value;
	}
	return NULL;
}

struct acp_card *acp_card_new(uint32_t index, const struct acp_dict *props)
{
	pa_card *impl;
	struct acp_card *card;
	const char *s, *profile_set = NULL, *profile = NULL;
	char device_id[16];
	bool ignore_dB = false;
	uint32_t profile_index;
	int res;

	impl = calloc(1, sizeof(*impl));
	if (impl == NULL)
		return NULL;

	pa_alsa_refcnt_inc();

	snprintf(device_id, sizeof(device_id), "%d", index);

	impl->proplist = pa_proplist_new_dict(props);

	card = &impl->card;
	card->index = index;
	card->active_profile_index = ACP_INVALID_INDEX;

	impl->use_ucm = true;
	impl->auto_profile = true;
	impl->auto_port = true;

	if (props) {
		if ((s = acp_dict_lookup(props, "api.alsa.use-ucm")) != NULL)
			impl->use_ucm = (strcmp(s, "true") == 0 || atoi(s) == 1);
		if ((s = acp_dict_lookup(props, "api.alsa.soft-mixer")) != NULL)
			impl->soft_mixer = (strcmp(s, "true") == 0 || atoi(s) == 1);
		if ((s = acp_dict_lookup(props, "api.alsa.ignore-dB")) != NULL)
			ignore_dB = (strcmp(s, "true") == 0 || atoi(s) == 1);
		if ((s = acp_dict_lookup(props, "device.profile-set")) != NULL)
			profile_set = s;
		if ((s = acp_dict_lookup(props, "device.profile")) != NULL)
			profile = s;
		if ((s = acp_dict_lookup(props, "api.acp.auto-profile")) != NULL)
			impl->auto_profile = (strcmp(s, "true") == 0 || atoi(s) == 1);
		if ((s = acp_dict_lookup(props, "api.acp.auto-port")) != NULL)
			impl->auto_port = (strcmp(s, "true") == 0 || atoi(s) == 1);
	}

	impl->ucm.default_sample_spec.format = PA_SAMPLE_S16NE;
	impl->ucm.default_sample_spec.rate = 44100;
	impl->ucm.default_sample_spec.channels = 2;
	pa_channel_map_init_extend(&impl->ucm.default_channel_map,
			impl->ucm.default_sample_spec.channels, PA_CHANNEL_MAP_ALSA);
	impl->ucm.default_n_fragments = 4;
	impl->ucm.default_fragment_size_msec = 25;

	impl->ucm.mixers = pa_hashmap_new_full(pa_idxset_string_hash_func,
			pa_idxset_string_compare_func,
			pa_xfree, (pa_free_cb_t) pa_alsa_mixer_free);
	impl->profiles = pa_hashmap_new_full(pa_idxset_string_hash_func,
			pa_idxset_string_compare_func, NULL,
			(pa_free_cb_t) profile_free);
	impl->ports = pa_hashmap_new_full(pa_idxset_string_hash_func,
			pa_idxset_string_compare_func, NULL,
			(pa_free_cb_t) port_free);

	snd_config_update_free_global();

	res = impl->use_ucm ? pa_alsa_ucm_query_profiles(&impl->ucm, card->index) : -1;
	if (res == -PA_ALSA_ERR_UCM_LINKED) {
		res = -ENOENT;
		goto error;
	}
	if (res == 0) {
		pa_log_info("Found UCM profiles");
		impl->profile_set = pa_alsa_ucm_add_profile_set(&impl->ucm, &impl->ucm.default_channel_map);
	} else {
		impl->use_ucm = false;
		impl->profile_set = pa_alsa_profile_set_new(profile_set, &impl->ucm.default_channel_map);
	}
	if (impl->profile_set == NULL) {
		res = -ENOTSUP;
		goto error;
	}

	impl->profile_set->ignore_dB = ignore_dB;

	pa_alsa_profile_set_probe(impl->profile_set, impl->ucm.mixers,
			device_id,
			&impl->ucm.default_sample_spec,
			impl->ucm.default_n_fragments,
			impl->ucm.default_fragment_size_msec);

	pa_alsa_init_proplist_card(NULL, impl->proplist, impl->card.index);
	pa_proplist_sets(impl->proplist, PA_PROP_DEVICE_STRING, device_id);
	pa_alsa_init_description(impl->proplist, NULL);

	add_profiles(impl);
	prune_singleton_availability_groups(impl->ports);

	card->n_profiles = pa_dynarray_size(&impl->out.profiles);
	card->profiles = impl->out.profiles.array.data;

	card->n_ports = pa_dynarray_size(&impl->out.ports);
	card->ports = impl->out.ports.array.data;

	card->n_devices = pa_dynarray_size(&impl->out.devices);
	card->devices = impl->out.devices.array.data;

	pa_proplist_as_dict(impl->proplist, &card->props);

	init_jacks(impl);

	if (!impl->auto_profile && profile == NULL)
		profile = "off";

	profile_index = acp_card_find_best_profile_index(&impl->card, profile);
	acp_card_set_profile(&impl->card, profile_index, 0);

	init_eld_ctls(impl);

	return &impl->card;
error:
	pa_alsa_refcnt_dec();
	free(impl);
	errno = -res;
	return NULL;
}

void acp_card_add_listener(struct acp_card *card,
		const struct acp_card_events *events, void *user_data)
{
	pa_card *impl = (pa_card *)card;
	impl->events = events;
	impl->user_data = user_data;
}

void acp_card_destroy(struct acp_card *card)
{
	pa_card *impl = (pa_card *)card;
	if (impl->profiles)
		pa_hashmap_free(impl->profiles);
	if (impl->ports)
		pa_hashmap_free(impl->ports);
	pa_dynarray_clear(&impl->out.devices);
	pa_dynarray_clear(&impl->out.profiles);
	pa_dynarray_clear(&impl->out.ports);
	if (impl->ucm.mixers)
		pa_hashmap_free(impl->ucm.mixers);
	if (impl->jacks)
		pa_hashmap_free(impl->jacks);
	if (impl->profile_set)
		pa_alsa_profile_set_free(impl->profile_set);
	pa_alsa_ucm_free(&impl->ucm);
	pa_proplist_free(impl->proplist);
	pa_alsa_refcnt_dec();
	free(impl);
}

int acp_card_poll_descriptors_count(struct acp_card *card)
{
	pa_card *impl = (pa_card *)card;
	void *state;
	pa_alsa_mixer *pm;
	int n, count = 0;

	PA_HASHMAP_FOREACH(pm, impl->ucm.mixers, state) {
		if (!pm->used_for_poll)
			continue;
		n = snd_mixer_poll_descriptors_count(pm->mixer_handle);
		if (n < 0)
			return n;
		count += n;
	}
	return count;
}

int acp_card_poll_descriptors(struct acp_card *card, struct pollfd *pfds, unsigned int space)
{
	pa_card *impl = (pa_card *)card;
	void *state;
	pa_alsa_mixer *pm;
	int n, count = 0;

	PA_HASHMAP_FOREACH(pm, impl->ucm.mixers, state) {
		if (!pm->used_for_poll)
			continue;

		n = snd_mixer_poll_descriptors(pm->mixer_handle, pfds, space);
		if (n < 0)
			return n;
		if (space >= (unsigned int) n) {
			count += n;
			space -= n;
			pfds += n;
		} else
			space = 0;
	}
	return count;
}

int acp_card_poll_descriptors_revents(struct acp_card *card, struct pollfd *pfds,
		unsigned int nfds, unsigned short *revents)
{
	unsigned int idx;
	unsigned short res;
	if (nfds == 0)
		return -EINVAL;
	res = 0;
	for (idx = 0; idx < nfds; idx++, pfds++)
		res |= pfds->revents & (POLLIN|POLLERR|POLLNVAL);
	*revents = res;
	return 0;
}

int acp_card_handle_events(struct acp_card *card)
{
	pa_card *impl = (pa_card *)card;
	void *state;
	pa_alsa_mixer *pm;
	int n, count = 0;

	PA_HASHMAP_FOREACH(pm, impl->ucm.mixers, state) {
		if (!pm->used_for_poll)
			continue;

		n = snd_mixer_handle_events(pm->mixer_handle);
		if (n < 0)
			return n;
		count += n;
	}
	return count;
}

static void sync_mixer(pa_alsa_device *d, pa_device_port *port)
{
	pa_alsa_setting *setting = NULL;

	if (!d->mixer_path)
		return;

	/* port may be NULL, because if we use a synthesized mixer path, then the
	 * sink has no ports. */
	if (port && !d->ucm_context) {
		pa_alsa_port_data *data;
		data = PA_DEVICE_PORT_DATA(port);
		setting = data->setting;
	}

	pa_alsa_path_select(d->mixer_path, setting, d->mixer_handle, d->muted);

	if (d->set_mute)
		d->set_mute(d, d->muted);
	if (d->set_volume)
		d->set_volume(d, &d->real_volume);
}


uint32_t acp_device_find_best_port_index(struct acp_device *dev, const char *name)
{
	uint32_t i;
	uint32_t best, best2, best3;
	struct acp_port **ports = dev->ports;

	best = best2 = best3 = ACP_INVALID_INDEX;

	for (i = 0; i < dev->n_ports; i++) {
		struct acp_port *p = ports[i];

		if (name) {
			if (strcmp(name, p->name) == 0)
				best = i;
		} else if (p->available == ACP_AVAILABLE_YES) {
			if (best == ACP_INVALID_INDEX || p->priority > ports[best]->priority)
				best = i;
		} else if (p->available != ACP_AVAILABLE_NO) {
			if (best2 == ACP_INVALID_INDEX || p->priority > ports[best2]->priority)
				best2 = i;
		} else {
			if (best3 == ACP_INVALID_INDEX || p->priority > ports[best3]->priority)
				best3 = i;
		}
	}
	if (best == ACP_INVALID_INDEX)
		best = best2;
	if (best == ACP_INVALID_INDEX)
		best = best3;
	if (best == ACP_INVALID_INDEX)
		best = 0;
	if (best < dev->n_ports)
		return ports[best]->index;
	else
		return ACP_INVALID_INDEX;
}

int acp_device_set_port(struct acp_device *dev, uint32_t port_index, uint32_t flags)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	pa_card *impl = d->card;
	pa_device_port *p, *old = d->active_port;
	int res;

	if (port_index >= impl->card.n_ports)
		return -EINVAL;

	p = (pa_device_port*)impl->card.ports[port_index];
	if (!pa_hashmap_get(d->ports, p->name))
		return -EINVAL;

	p->port.flags = ACP_PORT_ACTIVE | flags;
	if (p == old)
		return 0;
	if (old)
		old->port.flags &= ~(ACP_PORT_ACTIVE | ACP_PORT_SAVE);
	d->active_port = p;

	if (impl->use_ucm) {
		pa_alsa_ucm_port_data *data;

		data = PA_DEVICE_PORT_DATA(p);
		d->mixer_path = data->path;
		mixer_volume_init(impl, d);

		sync_mixer(d, p);
		res = pa_alsa_ucm_set_port(d->ucm_context, p,
					dev->direction == ACP_DIRECTION_PLAYBACK);
	} else {
		pa_alsa_port_data *data;

		data = PA_DEVICE_PORT_DATA(p);
		d->mixer_path = data->path;
		mixer_volume_init(impl, d);

		sync_mixer(d, p);
		res = 0;
#if 0
		if (data->suspend_when_unavailable && p->available == PA_AVAILABLE_NO)
			pa_sink_suspend(s, true, PA_SUSPEND_UNAVAILABLE);
		else
			pa_sink_suspend(s, false, PA_SUSPEND_UNAVAILABLE);
#endif
	}
	if (impl->events && impl->events->port_changed)
		impl->events->port_changed(impl->user_data,
				old ? old->port.index : 0, p->port.index);
	return res;
}

int acp_device_set_volume(struct acp_device *dev, const float *volume, uint32_t n_volume)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	pa_card *impl = d->card;
	uint32_t i;
	pa_cvolume v, old_volume;

	if (n_volume == 0)
		return -EINVAL;

	old_volume = d->real_volume;

	v.channels = d->mapping->channel_map.channels;
	for (i = 0; i < v.channels; i++)
		v.values[i] = pa_sw_volume_from_linear(volume[i % n_volume]);;

	pa_log_info("Set %s volume: %d", d->set_volume ? "hardware" : "software", pa_cvolume_max(&v));
	for (i = 0; i < v.channels; i++)
		pa_log_debug("  %d: %d", i, v.values[i]);

	if (d->set_volume) {
		d->set_volume(d, &v);
	} else {
		d->real_volume = v;
		d->soft_volume = v;
	}
	if (!pa_cvolume_equal(&d->real_volume, &old_volume))
		if (impl->events && impl->events->volume_changed)
			impl->events->volume_changed(impl->user_data, dev);
	return 0;
}

static int get_volume(pa_cvolume *v, float *volume, uint32_t n_volume)
{
	uint32_t i;
	if (v->channels == 0)
		return -EIO;
	for (i = 0; i < n_volume; i++)
		volume[i] = pa_sw_volume_to_linear(v->values[i % v->channels]);
	return 0;
}

int acp_device_get_soft_volume(struct acp_device *dev, float *volume, uint32_t n_volume)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	return get_volume(&d->soft_volume, volume, n_volume);
}

int acp_device_get_volume(struct acp_device *dev, float *volume, uint32_t n_volume)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	return get_volume(&d->real_volume, volume, n_volume);
}

int acp_device_set_mute(struct acp_device *dev, bool mute)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	pa_card *impl = d->card;
	bool old_muted = d->muted;

	if (old_muted == mute)
		return 0;

	pa_log_info("Set %s mute: %d", d->set_mute ? "hardware" : "software", mute);

	if (d->set_mute) {
		d->set_mute(d, mute);
	} else  {
		d->muted = mute;
	}
	if (old_muted != mute)
		if (impl->events && impl->events->mute_changed)
			impl->events->mute_changed(impl->user_data, dev);

	return 0;
}

int acp_device_get_mute(struct acp_device *dev, bool *mute)
{
	pa_alsa_device *d = (pa_alsa_device*)dev;
	*mute = d->muted;
	return 0;
}

void acp_set_log_func(acp_log_func func, void *data)
{
	_acp_log_func = func;
	_acp_log_data = data;
}
void acp_set_log_level(int level)
{
	_acp_log_level = level;
}
