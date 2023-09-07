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

#ifndef ACP_H
#define ACP_H

#ifdef __cplusplus
extern "C" {
#else
#include <stdbool.h>
#endif

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <poll.h>

#ifdef __GNUC__
#define ACP_PRINTF_FUNC(fmt, arg1) __attribute__((format(printf, fmt, arg1)))
#else
#define ACP_PRINTF_FUNC(fmt, arg1)
#endif

#define ACP_INVALID_INDEX	((uint32_t)-1)
#define ACP_MAX_CHANNELS	64

struct acp_dict_item {
	const char *key;
	const char *value;
};
#define ACP_DICT_ITEM_INIT(key,value) (struct acp_dict_item) { key, value }

struct acp_dict {
	uint32_t flags;
	uint32_t n_items;
	const struct acp_dict_item *items;
};

enum acp_channel {
	ACP_CHANNEL_UNKNOWN,		/**< unspecified */
	ACP_CHANNEL_NA,			/**< N/A, silent */

	ACP_CHANNEL_MONO,		/**< mono stream */

	ACP_CHANNEL_FL,			/**< front left */
	ACP_CHANNEL_FR,			/**< front right */
	ACP_CHANNEL_FC,			/**< front center */
	ACP_CHANNEL_LFE,		/**< LFE */
	ACP_CHANNEL_SL,			/**< side left */
	ACP_CHANNEL_SR,			/**< side right */
	ACP_CHANNEL_FLC,		/**< front left center */
	ACP_CHANNEL_FRC,		/**< front right center */
	ACP_CHANNEL_RC,			/**< rear center */
	ACP_CHANNEL_RL,			/**< rear left */
	ACP_CHANNEL_RR,			/**< rear right */
	ACP_CHANNEL_TC,			/**< top center */
	ACP_CHANNEL_TFL,		/**< top front left */
	ACP_CHANNEL_TFC,		/**< top front center */
	ACP_CHANNEL_TFR,		/**< top front right */
	ACP_CHANNEL_TRL,		/**< top rear left */
	ACP_CHANNEL_TRC,		/**< top rear center */
	ACP_CHANNEL_TRR,		/**< top rear right */
	ACP_CHANNEL_RLC,		/**< rear left center */
	ACP_CHANNEL_RRC,		/**< rear right center */
	ACP_CHANNEL_FLW,		/**< front left wide */
	ACP_CHANNEL_FRW,		/**< front right wide */
	ACP_CHANNEL_LFE2,		/**< LFE 2 */
	ACP_CHANNEL_FLH,		/**< front left high */
	ACP_CHANNEL_FCH,		/**< front center high */
	ACP_CHANNEL_FRH,		/**< front right high */
	ACP_CHANNEL_TFLC,		/**< top front left center */
	ACP_CHANNEL_TFRC,		/**< top front right center */
	ACP_CHANNEL_TSL,		/**< top side left */
	ACP_CHANNEL_TSR,		/**< top side right */
	ACP_CHANNEL_LLFE,		/**< left LFE */
	ACP_CHANNEL_RLFE,		/**< right LFE */
	ACP_CHANNEL_BC,			/**< bottom center */
	ACP_CHANNEL_BLC,		/**< bottom left center */
	ACP_CHANNEL_BRC,		/**< bottom right center */
	ACP_CHANNEL_CUSTOM_START  = 0x10000,
};

char *acp_channel_str(char *buf, size_t len, enum acp_channel ch);

struct acp_format {
	uint32_t flags;
	uint32_t format_mask;
	uint32_t rate_mask;
	uint32_t channels;
	uint32_t map[ACP_MAX_CHANNELS];
};

#define ACP_DICT_INIT(items,n_items) (struct acp_dict) { 0, n_items, items }
#define ACP_DICT_INIT_ARRAY(items) (struct acp_dict) { 0, sizeof(items)/sizeof((items)[0]), items }

#define acp_dict_for_each(item, dict)				\
	for ((item) = (dict)->items;				\
	     (item) < &(dict)->items[(dict)->n_items];		\
	     (item)++)

enum acp_direction {
	ACP_DIRECTION_PLAYBACK = 1,
	ACP_DIRECTION_CAPTURE = 2
};

const char *acp_direction_str(enum acp_direction direction);

enum acp_available {
	ACP_AVAILABLE_UNKNOWN = 0,
	ACP_AVAILABLE_NO = 1,
	ACP_AVAILABLE_YES = 2
};

const char *acp_available_str(enum acp_available status);

#define ACP_KEY_PORT_TYPE		"port.type"		/**< a Port type, like "aux", "speaker", ... */
#define ACP_KEY_PORT_AVAILABILITY_GROUP	"port.availability-group"
		/**< An identifier for the group of ports that share their availability status with
		 * each other. This is meant especially for handling cases where one 3.5 mm connector
		 * is used for headphones, headsets and microphones, and the hardware can only tell
		 * that something was plugged in but not what exactly. In this situation the ports for
		 * all those devices share their availability status, and ACP can't tell which
		 * one is actually plugged in, and some application may ask the user what was plugged
		 * in. Such applications should get a list of all card ports and compare their
		 * `available_group` fields. Ports that have the same group are those that need
		 * input from the user to determine which device was plugged in. The application should
		 * then activate the user-chosen port.
		 *
		 * May be NULL, in which case the port is not part of any availability group (which is
		 * the same as having a group with only one member).
		 *
		 * The group identifier must be treated as an opaque identifier. The string may look
		 * like an ALSA control name, but applications must not assume any such relationship.
		 * The group naming scheme can change without a warning.
		 */

struct acp_device;

struct acp_card_events {
#define ACP_VERSION_CARD_EVENTS	0
	uint32_t version;

	void (*destroy) (void *data);

	void (*props_changed) (void *data);

	void (*profile_changed) (void *data, uint32_t old_index, uint32_t new_index);

	void (*profile_available) (void *data, uint32_t index,
			enum acp_available old, enum acp_available available);

	void (*port_changed) (void *data, uint32_t old_index, uint32_t new_index);

	void (*port_available) (void *data, uint32_t index,
			enum acp_available old, enum acp_available available);

	void (*volume_changed) (void *data, struct acp_device *dev);
	void (*mute_changed) (void *data, struct acp_device *dev);
};

struct acp_port {
	uint32_t index;			/**< unique index for this port */
#define ACP_PORT_ACTIVE		(1<<0)
#define ACP_PORT_SAVE		(1<<1)	/* if the port needs saving */
	uint32_t flags;			/**< extra port flags */

	const char *name;		/**< Name of this port */
	const char *description;	/**< Description of this port */
	uint32_t priority;		/**< The higher this value is, the more useful this port is as a default. */
	enum acp_direction direction;
	enum acp_available available;	/**< A flags (see #acp_port_available), indicating availability status of this port. */
	struct acp_dict props;		/**< extra port properties */

	uint32_t n_profiles;		/**< number of elements in profiles array */
	struct acp_card_profile **profiles;	/**< array of profiles for this port */

	uint32_t n_devices;		/**< number of elements in devices array */
	struct acp_device **devices;	/**< array of devices */
};

struct acp_device {
	uint32_t index;
#define ACP_DEVICE_ACTIVE	(1<<0)
#define ACP_DEVICE_HW_VOLUME	(1<<1)
#define ACP_DEVICE_HW_MUTE	(1<<2)
	uint32_t flags;

	const char *name;
	const char *description;
	uint32_t priority;
	enum acp_direction direction;
	struct acp_dict props;

	const char **device_strings;
	struct acp_format format;

	float base_volume;
	float volume_step;

	uint32_t n_ports;
	struct acp_port **ports;
};

struct acp_card_profile {
	uint32_t index;
#define ACP_PROFILE_ACTIVE	(1<<0)
#define ACP_PROFILE_OFF		(1<<1)		/* the Off profile */
#define ACP_PROFILE_SAVE	(1<<2)		/* if the profile needs saving */
	uint32_t flags;

	const char *name;
	const char *description;
	uint32_t priority;
	enum acp_available available;
	struct acp_dict props;

	uint32_t n_devices;
	struct acp_device **devices;
};

struct acp_card {
	uint32_t index;
	uint32_t flags;

	struct acp_dict props;

	uint32_t n_profiles;
	uint32_t active_profile_index;
	struct acp_card_profile **profiles;

	uint32_t n_devices;
	struct acp_device **devices;

	uint32_t n_ports;
	struct acp_port **ports;
	uint32_t preferred_input_port_index;
	uint32_t preferred_output_port_index;
};

struct acp_card *acp_card_new(uint32_t index, const struct acp_dict *props);

void acp_card_add_listener(struct acp_card *card,
		const struct acp_card_events *events, void *user_data);

void acp_card_destroy(struct acp_card *card);

int acp_card_poll_descriptors_count(struct acp_card *card);
int acp_card_poll_descriptors(struct acp_card *card, struct pollfd *pfds, unsigned int space);
int acp_card_poll_descriptors_revents(struct acp_card *card, struct pollfd *pfds,
		unsigned int nfds, unsigned short *revents);
int acp_card_handle_events(struct acp_card *card);

uint32_t acp_card_find_best_profile_index(struct acp_card *card, const char *name);
int acp_card_set_profile(struct acp_card *card, uint32_t profile_index, uint32_t flags);

uint32_t acp_device_find_best_port_index(struct acp_device *dev, const char *name);
int acp_device_set_port(struct acp_device *dev, uint32_t port_index, uint32_t flags);

int acp_device_set_volume(struct acp_device *dev, const float *volume, uint32_t n_volume);
int acp_device_get_soft_volume(struct acp_device *dev, float *volume, uint32_t n_volume);
int acp_device_get_volume(struct acp_device *dev, float *volume, uint32_t n_volume);
int acp_device_set_mute(struct acp_device *dev, bool mute);
int acp_device_get_mute(struct acp_device *dev, bool *mute);

typedef void (*acp_log_func) (void *data,
		int level, const char *file, int line, const char *func,
		const char *fmt, va_list arg) ACP_PRINTF_FUNC(6,0);

void acp_set_log_func(acp_log_func, void *data);
void acp_set_log_level(int level);

#ifdef __cplusplus
}
#endif

#endif /* ACP_H */
