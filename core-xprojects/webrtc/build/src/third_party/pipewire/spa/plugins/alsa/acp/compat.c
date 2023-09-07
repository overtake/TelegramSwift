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

#include "compat.h"
#include "device-port.h"
#include "alsa-mixer.h"

static const char *port_types[] = {
	[PA_DEVICE_PORT_TYPE_UNKNOWN] = "unknown",
	[PA_DEVICE_PORT_TYPE_AUX] = "aux",
	[PA_DEVICE_PORT_TYPE_SPEAKER] = "speaker",
	[PA_DEVICE_PORT_TYPE_HEADPHONES] = "headphones",
	[PA_DEVICE_PORT_TYPE_LINE] = "line",
	[PA_DEVICE_PORT_TYPE_MIC] = "mic",
	[PA_DEVICE_PORT_TYPE_HEADSET] = "headset",
	[PA_DEVICE_PORT_TYPE_HANDSET] = "handset",
	[PA_DEVICE_PORT_TYPE_EARPIECE] = "earpiece",
	[PA_DEVICE_PORT_TYPE_SPDIF] = "spdif",
	[PA_DEVICE_PORT_TYPE_HDMI] = "hdmi",
	[PA_DEVICE_PORT_TYPE_TV] = "tv",
	[PA_DEVICE_PORT_TYPE_RADIO] = "radio",
	[PA_DEVICE_PORT_TYPE_VIDEO] = "video",
	[PA_DEVICE_PORT_TYPE_USB] = "usb",
	[PA_DEVICE_PORT_TYPE_BLUETOOTH] = "bluetooth",
	[PA_DEVICE_PORT_TYPE_PORTABLE] = "portable",
	[PA_DEVICE_PORT_TYPE_HANDSFREE] = "handsfree",
	[PA_DEVICE_PORT_TYPE_CAR] = "car",
	[PA_DEVICE_PORT_TYPE_HIFI] = "hifi",
	[PA_DEVICE_PORT_TYPE_PHONE] = "phone",
	[PA_DEVICE_PORT_TYPE_NETWORK] = "network",
	[PA_DEVICE_PORT_TYPE_ANALOG] = "analog",
};

static const char *str_port_type(pa_device_port_type_t type)
{
	int idx = (type >= 0 && type < PA_ELEMENTSOF(port_types)) ? type : 0;
	return port_types[idx];
}

pa_device_port_new_data *pa_device_port_new_data_init(pa_device_port_new_data *data)
{
	pa_assert(data);
	pa_zero(*data);
	data->type = PA_DEVICE_PORT_TYPE_UNKNOWN;
	data->available = PA_AVAILABLE_UNKNOWN;
	return data;
}

void pa_device_port_new_data_set_name(pa_device_port_new_data *data, const char *name)
{
	pa_assert(data);
	pa_xfree(data->name);
	data->name = pa_xstrdup(name);
}

void pa_device_port_new_data_set_description(pa_device_port_new_data *data, const char *description)
{
	pa_assert(data);
	pa_xfree(data->description);
	data->description = pa_xstrdup(description);
}

void pa_device_port_new_data_set_available(pa_device_port_new_data *data, pa_available_t available)
{
	pa_assert(data);
	data->available = available;
}

void pa_device_port_new_data_set_availability_group(pa_device_port_new_data *data, const char *group)
{
	pa_assert(data);
	pa_xfree(data->availability_group);
	data->availability_group = pa_xstrdup(group);
}

void pa_device_port_new_data_set_direction(pa_device_port_new_data *data, pa_direction_t direction)
{
	pa_assert(data);
	data->direction = direction;
}

void pa_device_port_new_data_set_type(pa_device_port_new_data *data, pa_device_port_type_t type)
{
	pa_assert(data);
	data->type = type;
}

void pa_device_port_new_data_done(pa_device_port_new_data *data)
{
	pa_assert(data);
	pa_xfree(data->name);
	pa_xfree(data->description);
	pa_xfree(data->availability_group);
}

pa_device_port *pa_device_port_new(pa_core *c, pa_device_port_new_data *data, size_t extra)
{
	pa_device_port *p;

	pa_assert(data);
	pa_assert(data->name);
	pa_assert(data->description);
	pa_assert(data->direction == PA_DIRECTION_OUTPUT || data->direction == PA_DIRECTION_INPUT);

	p = calloc(1, sizeof(pa_device_port) + extra);

	p->port.name = p->name = data->name;
	data->name = NULL;
	p->port.description = p->description = data->description;
	data->description = NULL;
	p->priority = p->port.priority = 0;
	p->available = data->available;
	p->port.available = (enum acp_available) data->available;
	p->availability_group = data->availability_group;
	data->availability_group = NULL;
	p->profiles = pa_hashmap_new(pa_idxset_string_hash_func, pa_idxset_string_compare_func);
	p->direction = data->direction;
	p->port.direction = data->direction == PA_DIRECTION_OUTPUT ?
		ACP_DIRECTION_PLAYBACK : ACP_DIRECTION_CAPTURE;
	p->type = data->type;

	p->proplist = pa_proplist_new();
	pa_proplist_sets(p->proplist, ACP_KEY_PORT_TYPE, str_port_type(data->type));
	if (p->availability_group)
		pa_proplist_sets(p->proplist, ACP_KEY_PORT_AVAILABILITY_GROUP, p->availability_group);

	p->user_data = (void*)((uint8_t*)p + sizeof(pa_device_port));

	return p;
}

void pa_device_port_free(pa_device_port *port)
{
	pa_xfree(port->name);
	pa_xfree(port->description);
	pa_xfree(port->availability_group);
	pa_hashmap_free(port->profiles);
	pa_proplist_free(port->proplist);
	free(port);
}

void pa_device_port_set_available(pa_device_port *p, pa_available_t status)
{
	pa_available_t old = p->available;

	if (old == status)
		return;
	p->available = status;
	p->port.available = (enum acp_available) status;

	if (p->card && p->card->events && p->card->events->port_available)
		p->card->events->port_available(p->card->user_data, p->port.index,
				(enum acp_available)old, p->port.available);
}

bool pa_alsa_device_init_description(pa_proplist *p, pa_card *card) {
    const char *s, *d = NULL, *k;
    pa_assert(p);

    if (pa_proplist_contains(p, PA_PROP_DEVICE_DESCRIPTION))
        return true;

    if (card)
        if ((s = pa_proplist_gets(card->proplist, PA_PROP_DEVICE_DESCRIPTION)))
            d = s;

    if (!d)
        if ((s = pa_proplist_gets(p, PA_PROP_DEVICE_FORM_FACTOR)))
            if (pa_streq(s, "internal"))
                d = _("Built-in Audio");

    if (!d)
        if ((s = pa_proplist_gets(p, PA_PROP_DEVICE_CLASS)))
            if (pa_streq(s, "modem"))
                d = _("Modem");

    if (!d)
        d = pa_proplist_gets(p, PA_PROP_DEVICE_PRODUCT_NAME);

    if (!d)
        return false;

    k = pa_proplist_gets(p, PA_PROP_DEVICE_PROFILE_DESCRIPTION);

    if (d && k)
        pa_proplist_setf(p, PA_PROP_DEVICE_DESCRIPTION, "%s %s", d, k);
    else if (d)
        pa_proplist_sets(p, PA_PROP_DEVICE_DESCRIPTION, d);

    return true;
}
