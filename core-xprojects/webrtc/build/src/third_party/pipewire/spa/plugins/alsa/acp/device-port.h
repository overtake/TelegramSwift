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


#ifndef PULSE_DEVICE_PORT_H
#define PULSE_DEVICE_PORT_H

#ifdef __cplusplus
extern "C" {
#else
#include <stdbool.h>
#endif

#include "compat.h"

typedef struct pa_card pa_card;
typedef struct pa_device_port pa_device_port;

/** Port type. \since 14.0 */
typedef enum pa_device_port_type {
	PA_DEVICE_PORT_TYPE_UNKNOWN = 0,
	PA_DEVICE_PORT_TYPE_AUX = 1,
	PA_DEVICE_PORT_TYPE_SPEAKER = 2,
	PA_DEVICE_PORT_TYPE_HEADPHONES = 3,
	PA_DEVICE_PORT_TYPE_LINE = 4,
	PA_DEVICE_PORT_TYPE_MIC = 5,
	PA_DEVICE_PORT_TYPE_HEADSET = 6,
	PA_DEVICE_PORT_TYPE_HANDSET = 7,
	PA_DEVICE_PORT_TYPE_EARPIECE = 8,
	PA_DEVICE_PORT_TYPE_SPDIF = 9,
	PA_DEVICE_PORT_TYPE_HDMI = 10,
	PA_DEVICE_PORT_TYPE_TV = 11,
	PA_DEVICE_PORT_TYPE_RADIO = 12,
	PA_DEVICE_PORT_TYPE_VIDEO = 13,
	PA_DEVICE_PORT_TYPE_USB = 14,
	PA_DEVICE_PORT_TYPE_BLUETOOTH = 15,
	PA_DEVICE_PORT_TYPE_PORTABLE = 16,
	PA_DEVICE_PORT_TYPE_HANDSFREE = 17,
	PA_DEVICE_PORT_TYPE_CAR = 18,
	PA_DEVICE_PORT_TYPE_HIFI = 19,
	PA_DEVICE_PORT_TYPE_PHONE = 20,
	PA_DEVICE_PORT_TYPE_NETWORK = 21,
	PA_DEVICE_PORT_TYPE_ANALOG = 22,
} pa_device_port_type_t;

struct pa_device_port {
	struct acp_port port;

	pa_card *card;

	char *name;
	char *description;
	char *preferred_profile;
	pa_device_port_type_t type;

	unsigned priority;
	pa_available_t available;         /* PA_AVAILABLE_UNKNOWN, PA_AVAILABLE_NO or PA_AVAILABLE_YES */
	char *availability_group;         /* a string identifier which determine the group of devices handling the available state simultaneously */

	pa_direction_t direction;
	int64_t latency_offset;

	pa_proplist *proplist;
	pa_hashmap *profiles;
	pa_dynarray prof;

	pa_dynarray devices;

	void (*impl_free)(struct pa_device_port *port);
	void *user_data;
};

#define PA_DEVICE_PORT_DATA(p) (p->user_data);

typedef struct pa_device_port_new_data {
	char *name;
	char *description;
	pa_available_t available;
	char *availability_group;
	pa_direction_t direction;
	pa_device_port_type_t type;
} pa_device_port_new_data;

pa_device_port_new_data *pa_device_port_new_data_init(pa_device_port_new_data *data);
void pa_device_port_new_data_set_name(pa_device_port_new_data *data, const char *name);
void pa_device_port_new_data_set_description(pa_device_port_new_data *data, const char *description);
void pa_device_port_new_data_set_available(pa_device_port_new_data *data, pa_available_t available);
void pa_device_port_new_data_set_availability_group(pa_device_port_new_data *data, const char *group);
void pa_device_port_new_data_set_direction(pa_device_port_new_data *data, pa_direction_t direction);
void pa_device_port_new_data_set_type(pa_device_port_new_data *data, pa_device_port_type_t type);
void pa_device_port_new_data_done(pa_device_port_new_data *data);

pa_device_port *pa_device_port_new(pa_core *c, pa_device_port_new_data *data, size_t extra);
void pa_device_port_free(pa_device_port *port);

void pa_device_port_set_available(pa_device_port *p, pa_available_t status);

#ifdef __cplusplus
}
#endif

#endif /* PULSE_DEVICE_PORT_H */
