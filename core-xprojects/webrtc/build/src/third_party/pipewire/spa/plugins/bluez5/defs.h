/* Spa Bluez5 Monitor
 *
 * Copyright © 2018 Wim Taymans
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

#ifndef SPA_BLUEZ5_DEFS_H
#define SPA_BLUEZ5_DEFS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <math.h>

#include <spa/support/dbus.h>
#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/monitor/device.h>
#include <spa/utils/hook.h>

#include <dbus/dbus.h>

#include "config.h"

#define BLUEZ_SERVICE "org.bluez"
#define BLUEZ_PROFILE_MANAGER_INTERFACE BLUEZ_SERVICE ".ProfileManager1"
#define BLUEZ_PROFILE_INTERFACE BLUEZ_SERVICE ".Profile1"
#define BLUEZ_ADAPTER_INTERFACE BLUEZ_SERVICE ".Adapter1"
#define BLUEZ_DEVICE_INTERFACE BLUEZ_SERVICE ".Device1"
#define BLUEZ_MEDIA_INTERFACE BLUEZ_SERVICE ".Media1"
#define BLUEZ_MEDIA_ENDPOINT_INTERFACE BLUEZ_SERVICE ".MediaEndpoint1"
#define BLUEZ_MEDIA_TRANSPORT_INTERFACE BLUEZ_SERVICE ".MediaTransport1"
#define BLUEZ_INTERFACE_BATTERY_PROVIDER BLUEZ_SERVICE ".BatteryProvider1"
#define BLUEZ_INTERFACE_BATTERY_PROVIDER_MANAGER BLUEZ_SERVICE ".BatteryProviderManager1"

#define DBUS_INTERFACE_OBJECT_MANAGER "org.freedesktop.DBus.ObjectManager"
#define DBUS_SIGNAL_INTERFACES_ADDED "InterfacesAdded"
#define DBUS_SIGNAL_INTERFACES_REMOVED "InterfacesRemoved"
#define DBUS_SIGNAL_PROPERTIES_CHANGED "PropertiesChanged"

#define PIPEWIRE_BATTERY_PROVIDER "/org/freedesktop/pipewire/battery"

#define SPA_BT_HFP_HF_IPHONEACCEV_KEY_BATTERY	1

#define MIN_LATENCY	512
#define MAX_LATENCY	1024

#define OBJECT_MANAGER_INTROSPECT_XML                                          \
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                                  \
	"<node>\n"                                                                 \
	" <interface name=\"org.freedesktop.DBus.ObjectManager\">\n"               \
	"  <method name=\"GetManagedObjects\">\n"                                  \
	"   <arg name=\"objects\" direction=\"out\" type=\"a{oa{sa{sv}}}\"/>\n"    \
	"  </method>\n"                                                            \
	"  <signal name=\"InterfacesAdded\">\n"                                    \
	"   <arg name=\"object\" type=\"o\"/>\n"                                   \
	"   <arg name=\"interfaces\" type=\"a{sa{sv}}\"/>\n"                       \
	"  </signal>\n"                                                            \
	"  <signal name=\"InterfacesRemoved\">\n"                                  \
	"   <arg name=\"object\" type=\"o\"/>\n"                                   \
	"   <arg name=\"interfaces\" type=\"as\"/>\n"                              \
	"  </signal>\n"                                                            \
	" </interface>\n"                                                          \
	" <interface name=\"org.freedesktop.DBus.Introspectable\">\n"              \
	"  <method name=\"Introspect\">\n"                                         \
	"   <arg name=\"data\" direction=\"out\" type=\"s\"/>\n"                   \
	"  </method>\n"                                                            \
	" </interface>\n"                                                          \
	" <node name=\"A2DPSink\"/>\n"                                             \
	" <node name=\"A2DPSource\"/>\n"                                           \
	"</node>\n"

#define ENDPOINT_INTROSPECT_XML                                             \
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                           \
	"<node>"                                                            \
	" <interface name=\"" BLUEZ_MEDIA_ENDPOINT_INTERFACE "\">"          \
	"  <method name=\"SetConfiguration\">"                              \
	"   <arg name=\"transport\" direction=\"in\" type=\"o\"/>"          \
	"   <arg name=\"properties\" direction=\"in\" type=\"ay\"/>"        \
	"  </method>"                                                       \
	"  <method name=\"SelectConfiguration\">"                           \
	"   <arg name=\"capabilities\" direction=\"in\" type=\"ay\"/>"      \
	"   <arg name=\"configuration\" direction=\"out\" type=\"ay\"/>"    \
	"  </method>"                                                       \
	"  <method name=\"ClearConfiguration\">"                            \
	"   <arg name=\"transport\" direction=\"in\" type=\"o\"/>"          \
	"  </method>"                                                       \
	"  <method name=\"Release\">"                                       \
	"  </method>"                                                       \
	" </interface>"                                                     \
	" <interface name=\"org.freedesktop.DBus.Introspectable\">"         \
	"  <method name=\"Introspect\">"                                    \
	"   <arg name=\"data\" type=\"s\" direction=\"out\"/>"              \
	"  </method>"                                                       \
	" </interface>"                                                     \
	"</node>"

#define PROFILE_INTROSPECT_XML						    \
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                           \
	"<node>"                                                            \
	" <interface name=\"" BLUEZ_PROFILE_INTERFACE "\">"                 \
	"  <method name=\"Release\">"                                       \
	"  </method>"                                                       \
	"  <method name=\"RequestDisconnection\">"                          \
	"   <arg name=\"device\" direction=\"in\" type=\"o\"/>"             \
	"  </method>"                                                       \
	"  <method name=\"NewConnection\">"                                 \
	"   <arg name=\"device\" direction=\"in\" type=\"o\"/>"             \
	"   <arg name=\"fd\" direction=\"in\" type=\"h\"/>"                 \
	"   <arg name=\"opts\" direction=\"in\" type=\"a{sv}\"/>"           \
	"  </method>"                                                       \
	" </interface>"                                                     \
	" <interface name=\"org.freedesktop.DBus.Introspectable\">"         \
	"  <method name=\"Introspect\">"                                    \
	"   <arg name=\"data\" type=\"s\" direction=\"out\"/>"              \
	"  </method>"                                                       \
	" </interface>"                                                     \
	"</node>"

#define BLUEZ_ERROR_NOT_SUPPORTED "org.bluez.Error.NotSupported"

#define SPA_BT_UUID_A2DP_SOURCE "0000110A-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_A2DP_SINK   "0000110B-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_HSP_HS      "00001108-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_HSP_HS_ALT  "00001131-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_HSP_AG      "00001112-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_HFP_HF      "0000111E-0000-1000-8000-00805F9B34FB"
#define SPA_BT_UUID_HFP_AG      "0000111F-0000-1000-8000-00805F9B34FB"

#define PROFILE_HSP_AG	"/Profile/HSPAG"
#define PROFILE_HSP_HS	"/Profile/HSPHS"
#define PROFILE_HFP_AG	"/Profile/HFPAG"
#define PROFILE_HFP_HF	"/Profile/HFPHF"

#define HSP_HS_DEFAULT_CHANNEL  3

#define HFP_AUDIO_CODEC_CVSD    0x01
#define HFP_AUDIO_CODEC_MSBC    0x02

#define A2DP_OBJECT_MANAGER_PATH "/MediaEndpoint"
#define A2DP_SINK_ENDPOINT	A2DP_OBJECT_MANAGER_PATH "/A2DPSink"
#define A2DP_SOURCE_ENDPOINT	A2DP_OBJECT_MANAGER_PATH "/A2DPSource"

#define SPA_BT_UNKNOWN_DELAY			0

#define SPA_BT_NO_BATTERY			((uint8_t)255)

/* HFP uses SBC encoding with precisely defined parameters. Hence, the size
 * of the input (number of PCM samples) and output is known up front. */
#define MSBC_DECODED_SIZE       240
#define MSBC_ENCODED_SIZE       60  /* 2 bytes header + 57 mSBC payload + 1 byte padding */

enum spa_bt_profile {
	SPA_BT_PROFILE_NULL =		0,
	SPA_BT_PROFILE_A2DP_SINK =	(1 << 0),
	SPA_BT_PROFILE_A2DP_SOURCE =	(1 << 1),
	SPA_BT_PROFILE_HSP_HS =		(1 << 2),
	SPA_BT_PROFILE_HSP_AG =		(1 << 3),
	SPA_BT_PROFILE_HFP_HF =		(1 << 4),
	SPA_BT_PROFILE_HFP_AG =		(1 << 5),

	SPA_BT_PROFILE_A2DP_DUPLEX =	(SPA_BT_PROFILE_A2DP_SINK | SPA_BT_PROFILE_A2DP_SOURCE),
	SPA_BT_PROFILE_HEADSET_HEAD_UNIT = (SPA_BT_PROFILE_HSP_HS | SPA_BT_PROFILE_HFP_HF),
	SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY = (SPA_BT_PROFILE_HSP_AG | SPA_BT_PROFILE_HFP_AG),
	SPA_BT_PROFILE_HEADSET_AUDIO =  (SPA_BT_PROFILE_HEADSET_HEAD_UNIT | SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY),
};

static inline enum spa_bt_profile spa_bt_profile_from_uuid(const char *uuid)
{
	if (strcasecmp(uuid, SPA_BT_UUID_A2DP_SOURCE) == 0)
		return SPA_BT_PROFILE_A2DP_SOURCE;
	else if (strcasecmp(uuid, SPA_BT_UUID_A2DP_SINK) == 0)
		return SPA_BT_PROFILE_A2DP_SINK;
	else if (strcasecmp(uuid, SPA_BT_UUID_HSP_HS) == 0)
		return SPA_BT_PROFILE_HSP_HS;
	else if (strcasecmp(uuid, SPA_BT_UUID_HSP_HS_ALT) == 0)
		return SPA_BT_PROFILE_HSP_HS;
	else if (strcasecmp(uuid, SPA_BT_UUID_HSP_AG) == 0)
		return SPA_BT_PROFILE_HSP_AG;
	else if (strcasecmp(uuid, SPA_BT_UUID_HFP_HF) == 0)
		return SPA_BT_PROFILE_HFP_HF;
	else if (strcasecmp(uuid, SPA_BT_UUID_HFP_AG) == 0)
		return SPA_BT_PROFILE_HFP_AG;
	else
		return 0;
}
int spa_bt_profiles_from_json_array(const char *str);

enum spa_bt_hfp_ag_feature {
	SPA_BT_HFP_AG_FEATURE_NONE =			(0),
	SPA_BT_HFP_AG_FEATURE_3WAY =			(1 << 0),
	SPA_BT_HFP_AG_FEATURE_ECNR =			(1 << 1),
	SPA_BT_HFP_AG_FEATURE_VOICE_RECOG =		(1 << 2),
	SPA_BT_HFP_AG_FEATURE_IN_BAND_RING_TONE =	(1 << 3),
	SPA_BT_HFP_AG_FEATURE_ATTACH_VOICE_TAG =	(1 << 4),
	SPA_BT_HFP_AG_FEATURE_REJECT_CALL =		(1 << 5),
	SPA_BT_HFP_AG_FEATURE_ENHANCED_CALL_STATUS =	(1 << 6),
	SPA_BT_HFP_AG_FEATURE_ENHANCED_CALL_CONTROL =	(1 << 7),
	SPA_BT_HFP_AG_FEATURE_EXTENDED_RES_CODE =	(1 << 8),
	SPA_BT_HFP_AG_FEATURE_CODEC_NEGOTIATION =	(1 << 9),
	SPA_BT_HFP_AG_FEATURE_HF_INDICATORS =		(1 << 10),
	SPA_BT_HFP_AG_FEATURE_ESCO_S4 =			(1 << 11),
};

enum spa_bt_hfp_sdp_ag_features {
	SPA_BT_HFP_SDP_AG_FEATURE_NONE =		(0),
	SPA_BT_HFP_SDP_AG_FEATURE_3WAY =		(1 << 0),
	SPA_BT_HFP_SDP_AG_FEATURE_ECNR =		(1 << 1),
	SPA_BT_HFP_SDP_AG_FEATURE_VOICE_RECOG =		(1 << 2),
	SPA_BT_HFP_SDP_AG_FEATURE_IN_BAND_RING_TONE =	(1 << 3),
	SPA_BT_HFP_SDP_AG_FEATURE_ATTACH_VOICE_TAG =	(1 << 4),
	SPA_BT_HFP_SDP_AG_FEATURE_WIDEBAND_SPEECH =	(1 << 5),
};

enum spa_bt_hfp_hf_feature {
	SPA_BT_HFP_HF_FEATURE_NONE =			(0),
	SPA_BT_HFP_HF_FEATURE_ECNR =			(1 << 0),
	SPA_BT_HFP_HF_FEATURE_3WAY =			(1 << 1),
	SPA_BT_HFP_HF_FEATURE_CLIP =			(1 << 2),
	SPA_BT_HFP_HF_FEATURE_VOICE_RECOGNITION =	(1 << 3),
	SPA_BT_HFP_HF_FEATURE_REMOTE_VOLUME_CONTROL =	(1 << 4),
	SPA_BT_HFP_HF_FEATURE_ENHANCED_CALL_STATUS =	(1 << 5),
	SPA_BT_HFP_HF_FEATURE_ENHANCED_CALL_CONTROL =	(1 << 6),
	SPA_BT_HFP_HF_FEATURE_CODEC_NEGOTIATION =	(1 << 7),
	SPA_BT_HFP_HF_FEATURE_HF_INDICATORS =		(1 << 8),
	SPA_BT_HFP_HF_FEATURE_ESCO_S4 =			(1 << 9),
};

enum spa_bt_hfp_sdp_hf_features {
	SPA_BT_HFP_SDP_HF_FEATURE_NONE =		(0),
	SPA_BT_HFP_SDP_HF_FEATURE_ECNR =		(1 << 0),
	SPA_BT_HFP_SDP_HF_FEATURE_3WAY =		(1 << 1),
	SPA_BT_HFP_SDP_HF_FEATURE_CLIP =		(1 << 2),
	SPA_BT_HFP_SDP_HF_FEATURE_VOICE_RECOGNITION =	(1 << 3),
	SPA_BT_HFP_SDP_HF_FEATURE_REMOTE_VOLUME_CONTROL =	(1 << 4),
	SPA_BT_HFP_SDP_HF_FEATURE_WIDEBAND_SPEECH =	(1 << 5),
};

static inline const char *spa_bt_profile_name (enum spa_bt_profile profile) {
      switch (profile) {
      case SPA_BT_PROFILE_A2DP_SOURCE:
        return "a2dp-source";
      case SPA_BT_PROFILE_A2DP_SINK:
        return "a2dp-sink";
      case SPA_BT_PROFILE_A2DP_DUPLEX:
        return "a2dp-duplex";
      case SPA_BT_PROFILE_HSP_HS:
      case SPA_BT_PROFILE_HFP_HF:
      case SPA_BT_PROFILE_HEADSET_HEAD_UNIT:
	return "headset-head-unit";
      case SPA_BT_PROFILE_HSP_AG:
      case SPA_BT_PROFILE_HFP_AG:
      case SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY:
	return "headset-audio-gateway";
      case SPA_BT_PROFILE_HEADSET_AUDIO:
	return "headset-audio";
      default:
        break;
      }
      return "unknown";
}

struct spa_bt_monitor;
struct spa_bt_backend;

struct spa_bt_adapter {
	struct spa_list link;
	struct spa_bt_monitor *monitor;
	char *path;
	char *alias;
	char *address;
	char *name;
	uint32_t bluetooth_class;
	uint32_t profiles;
	int powered;
	unsigned int endpoints_registered:1;
	unsigned int application_registered:1;
	unsigned int has_battery_provider;
	unsigned int battery_provider_unavailable;
};

enum spa_bt_form_factor {
	SPA_BT_FORM_FACTOR_UNKNOWN,
	SPA_BT_FORM_FACTOR_HEADSET,
	SPA_BT_FORM_FACTOR_HANDSFREE,
	SPA_BT_FORM_FACTOR_MICROPHONE,
	SPA_BT_FORM_FACTOR_SPEAKER,
	SPA_BT_FORM_FACTOR_HEADPHONE,
	SPA_BT_FORM_FACTOR_PORTABLE,
	SPA_BT_FORM_FACTOR_CAR,
	SPA_BT_FORM_FACTOR_HIFI,
	SPA_BT_FORM_FACTOR_PHONE,
};

static inline const char *spa_bt_form_factor_name(enum spa_bt_form_factor ff)
{
	switch (ff) {
	case SPA_BT_FORM_FACTOR_HEADSET:
		return "headset";
	case SPA_BT_FORM_FACTOR_HANDSFREE:
		return "hands-free";
	case SPA_BT_FORM_FACTOR_MICROPHONE:
		return "microphone";
	case SPA_BT_FORM_FACTOR_SPEAKER:
		return "speaker";
	case SPA_BT_FORM_FACTOR_HEADPHONE:
		return "headphone";
	case SPA_BT_FORM_FACTOR_PORTABLE:
		return "portable";
	case SPA_BT_FORM_FACTOR_CAR:
		return "car";
	case SPA_BT_FORM_FACTOR_HIFI:
		return "hifi";
	case SPA_BT_FORM_FACTOR_PHONE:
		return "phone";
	case SPA_BT_FORM_FACTOR_UNKNOWN:
	default:
		return "unknown";
	}
}

static inline enum spa_bt_form_factor spa_bt_form_factor_from_class(uint32_t bluetooth_class)
{
	uint32_t major, minor;
	/* See Bluetooth Assigned Numbers:
	 * https://www.bluetooth.org/Technical/AssignedNumbers/baseband.htm */
	major = (bluetooth_class >> 8) & 0x1F;
	minor = (bluetooth_class >> 2) & 0x3F;

	switch (major) {
	case 2:
		return SPA_BT_FORM_FACTOR_PHONE;
	case 4:
		switch (minor) {
		case 1:
			return SPA_BT_FORM_FACTOR_HEADSET;
		case 2:
			return SPA_BT_FORM_FACTOR_HANDSFREE;
		case 4:
			return SPA_BT_FORM_FACTOR_MICROPHONE;
		case 5:
			return SPA_BT_FORM_FACTOR_SPEAKER;
		case 6:
			return SPA_BT_FORM_FACTOR_HEADPHONE;
		case 7:
			return SPA_BT_FORM_FACTOR_PORTABLE;
		case 8:
			return SPA_BT_FORM_FACTOR_CAR;
		case 10:
			return SPA_BT_FORM_FACTOR_HIFI;
		}
	}
	return SPA_BT_FORM_FACTOR_UNKNOWN;
}

struct spa_bt_a2dp_codec_switch;
struct spa_bt_transport;

struct spa_bt_device_events {
#define SPA_VERSION_BT_DEVICE_EVENTS	0
	uint32_t version;

	/** Device connection status */
	void (*connected) (void *data, bool connected);

	/** Codec switching completed */
	void (*codec_switched) (void *data, int status);

	/** Profile configuration changed */
	void (*profiles_changed) (void *data, uint32_t prev_profiles, uint32_t prev_connected);

	/** Device freed */
	void (*destroy) (void *data);
};

struct spa_bt_device {
	struct spa_list link;
	struct spa_bt_monitor *monitor;
	struct spa_bt_adapter *adapter;
	uint32_t id;
	char *path;
	char *alias;
	char *address;
	char *adapter_path;
	char *battery_path;
	char *name;
	char *icon;
	uint32_t bluetooth_class;
	uint16_t appearance;
	uint16_t RSSI;
	int paired;
	int trusted;
	int connected;
	int blocked;
	uint32_t profiles;
	uint32_t connected_profiles;
	uint32_t reconnect_profiles;
	int reconnect_state;
	struct spa_source timer;
	struct spa_list remote_endpoint_list;
	struct spa_list transport_list;
	struct spa_list codec_switch_list;
	uint8_t battery;
	int has_battery;

	uint32_t hw_volume_profiles;
	/* Even though A2DP volume is exposed on transport interface, the
	 * volume activation info would not be variate between transports
	 * under same device. So it's safe to cache activation info here. */
	bool a2dp_volume_active[2];

	struct spa_hook_list listener_list;
	bool added;

	const struct spa_dict *settings;

	DBusPendingCall *battery_pending_call;
};

struct a2dp_codec;

struct spa_bt_device *spa_bt_device_find(struct spa_bt_monitor *monitor, const char *path);
struct spa_bt_device *spa_bt_device_find_by_address(struct spa_bt_monitor *monitor, const char *remote_address, const char *local_address);
int spa_bt_device_connect_profile(struct spa_bt_device *device, enum spa_bt_profile profile);
int spa_bt_device_check_profiles(struct spa_bt_device *device, bool force);
int spa_bt_device_ensure_a2dp_codec(struct spa_bt_device *device, const struct a2dp_codec **codecs);
bool spa_bt_device_supports_a2dp_codec(struct spa_bt_device *device, const struct a2dp_codec *codec);
const struct a2dp_codec **spa_bt_device_get_supported_a2dp_codecs(struct spa_bt_device *device, size_t *count);
int spa_bt_device_ensure_hfp_codec(struct spa_bt_device *device, unsigned int codec);
int spa_bt_device_supports_hfp_codec(struct spa_bt_device *device, unsigned int codec);
int spa_bt_device_release_transports(struct spa_bt_device *device);
int spa_bt_device_report_battery_level(struct spa_bt_device *device, uint8_t percentage);

#define spa_bt_device_emit(d,m,v,...)			spa_hook_list_call(&(d)->listener_list, \
								struct spa_bt_device_events,	\
								m, v, ##__VA_ARGS__)
#define spa_bt_device_emit_connected(d,...)	        spa_bt_device_emit(d, connected, 0, __VA_ARGS__)
#define spa_bt_device_emit_codec_switched(d,...)	spa_bt_device_emit(d, codec_switched, 0, __VA_ARGS__)
#define spa_bt_device_emit_profiles_changed(d,...)	spa_bt_device_emit(d, profiles_changed, 0, __VA_ARGS__)
#define spa_bt_device_emit_destroy(d)			spa_bt_device_emit(d, destroy, 0)
#define spa_bt_device_add_listener(d,listener,events,data)           \
	spa_hook_list_append(&(d)->listener_list, listener, events, data)

struct spa_bt_sco_io;

struct spa_bt_sco_io *spa_bt_sco_io_create(struct spa_loop *data_loop, int fd, uint16_t write_mtu, uint16_t read_mtu);
void spa_bt_sco_io_destroy(struct spa_bt_sco_io *io);
void spa_bt_sco_io_set_source_cb(struct spa_bt_sco_io *io, int (*source_cb)(void *userdata, uint8_t *data, int size), void *userdata);
void spa_bt_sco_io_set_sink_cb(struct spa_bt_sco_io *io, int (*sink_cb)(void *userdata), void *userdata);
int spa_bt_sco_io_write(struct spa_bt_sco_io *io, uint8_t *data, int size);

#define SPA_BT_VOLUME_ID_RX	0
#define SPA_BT_VOLUME_ID_TX	1
#define SPA_BT_VOLUME_ID_TERM	2

#define SPA_BT_VOLUME_INVALID	-1
#define SPA_BT_VOLUME_HS_MAX	15
#define SPA_BT_VOLUME_A2DP_MAX	127

enum spa_bt_transport_state {
        SPA_BT_TRANSPORT_STATE_IDLE,
        SPA_BT_TRANSPORT_STATE_PENDING,
        SPA_BT_TRANSPORT_STATE_ACTIVE,
};

struct spa_bt_transport_events {
#define SPA_VERSION_BT_TRANSPORT_EVENTS	0
	uint32_t version;

	void (*destroy) (void *data);
	void (*state_changed) (void *data, enum spa_bt_transport_state old,
			enum spa_bt_transport_state state);
	void (*volume_changed) (void *data);
};

struct spa_bt_transport_implementation {
#define SPA_VERSION_BT_TRANSPORT_IMPLEMENTATION	0
	uint32_t version;

	int (*acquire) (void *data, bool optional);
	int (*release) (void *data);
	int (*set_volume) (void *data, int id, float volume);
	int (*destroy) (void *data);
};

struct spa_bt_transport_volume {
	bool active;
	float volume;
	int hw_volume_max;

	/* XXX: items below should be put to user_data */
	int hw_volume;
	int new_hw_volume;
};

struct spa_bt_transport {
	struct spa_list link;
	struct spa_bt_monitor *monitor;
	struct spa_bt_backend *backend;
	char *path;
	struct spa_bt_device *device;
	struct spa_list device_link;
	enum spa_bt_profile profile;
	enum spa_bt_transport_state state;
	const struct a2dp_codec *a2dp_codec;
	unsigned int codec;
	void *configuration;
	int configuration_len;

	uint32_t n_channels;
	uint32_t channels[64];

	struct spa_bt_transport_volume volumes[SPA_BT_VOLUME_ID_TERM];

	int acquire_refcount;
	int fd;
	uint16_t read_mtu;
	uint16_t write_mtu;
	uint16_t delay;

	struct spa_bt_sco_io *sco_io;

	struct spa_source volume_timer;
	struct spa_source release_timer;

	struct spa_hook_list listener_list;
	struct spa_callbacks impl;

	/* user_data must be the last item in the struct */
	void *user_data;
};

struct spa_bt_transport *spa_bt_transport_create(struct spa_bt_monitor *monitor, char *path, size_t extra);
void spa_bt_transport_free(struct spa_bt_transport *transport);
void spa_bt_transport_set_state(struct spa_bt_transport *transport, enum spa_bt_transport_state state);
struct spa_bt_transport *spa_bt_transport_find(struct spa_bt_monitor *monitor, const char *path);
struct spa_bt_transport *spa_bt_transport_find_full(struct spa_bt_monitor *monitor,
                                                    bool (*callback) (struct spa_bt_transport *t, const void *data),
                                                    const void *data);
int64_t spa_bt_transport_get_delay_nsec(struct spa_bt_transport *transport);
bool spa_bt_transport_volume_enabled(struct spa_bt_transport *transport);

int spa_bt_transport_acquire(struct spa_bt_transport *t, bool optional);
int spa_bt_transport_release(struct spa_bt_transport *t);
int spa_bt_transport_ensure_sco_io(struct spa_bt_transport *t, struct spa_loop *data_loop);

#define spa_bt_transport_emit(t,m,v,...)		spa_hook_list_call(&(t)->listener_list, \
								struct spa_bt_transport_events,	\
								m, v, ##__VA_ARGS__)
#define spa_bt_transport_emit_destroy(t)		spa_bt_transport_emit(t, destroy, 0)
#define spa_bt_transport_emit_state_changed(t,...)	spa_bt_transport_emit(t, state_changed, 0, __VA_ARGS__)
#define spa_bt_transport_emit_volume_changed(t)		spa_bt_transport_emit(t, volume_changed, 0)

#define spa_bt_transport_add_listener(t,listener,events,data) \
        spa_hook_list_append(&(t)->listener_list, listener, events, data)

#define spa_bt_transport_set_implementation(t,_impl,_data) \
			(t)->impl = SPA_CALLBACKS_INIT(_impl, _data)

#define spa_bt_transport_impl(t,m,v,...)		\
({							\
	int res = 0;					\
	spa_callbacks_call_res(&(t)->impl,		\
		struct spa_bt_transport_implementation,	\
		res, m, v, ##__VA_ARGS__);		\
	res;						\
})

#define spa_bt_transport_destroy(t)		spa_bt_transport_impl(t, destroy, 0)
#define spa_bt_transport_set_volume(t,...)	spa_bt_transport_impl(t, set_volume, 0, __VA_ARGS__)

static inline enum spa_bt_transport_state spa_bt_transport_state_from_string(const char *value)
{
	if (strcasecmp("idle", value) == 0)
		return SPA_BT_TRANSPORT_STATE_IDLE;
	else if (strcasecmp("pending", value) == 0)
		return SPA_BT_TRANSPORT_STATE_PENDING;
	else if (strcasecmp("active", value) == 0)
		return SPA_BT_TRANSPORT_STATE_ACTIVE;
	else
		return SPA_BT_TRANSPORT_STATE_IDLE;
}

#define DEFAULT_AG_VOLUME	1.0f
#define DEFAULT_RX_VOLUME	1.0f
#define DEFAULT_TX_VOLUME	0.064f /* pa_sw_volume_to_linear(0.4 * PA_VOLUME_NORM) */

#define PA_VOLUME_MUTED	((uint32_t) 0u)
#define PA_VOLUME_NORM	((uint32_t) 0x10000u)
#define PA_VOLUME_MAX	((uint32_t) UINT32_MAX/2)

static inline uint32_t pa_sw_volume_from_linear(double v)
{
    	if (v <= 0.0)
        	return PA_VOLUME_MUTED;
    	return SPA_CLAMP(
	    	(uint64_t) lround(cbrt(v) * PA_VOLUME_NORM),
		PA_VOLUME_MUTED, PA_VOLUME_MAX);
}

static inline double pa_sw_volume_to_linear(uint32_t v)
{
	double f;
	if (v <= PA_VOLUME_MUTED)
		return 0.0;
	if (v == PA_VOLUME_NORM)
		return 1.0;
	f = ((double) v / PA_VOLUME_NORM);
	return f*f*f;
}

/* AVRCP/HSP volume is considered as percentage, so map it to pulseaudio volume. */
static inline uint32_t spa_bt_volume_linear_to_hw(double v, uint32_t hw_volume_max)
{
	return SPA_CLAMP(
		pa_sw_volume_from_linear(v) * hw_volume_max / PA_VOLUME_NORM,
		0u, hw_volume_max);
}

static inline double spa_bt_volume_hw_to_linear(uint32_t v, uint32_t hw_volume_max)
{
	return SPA_CLAMP(
		pa_sw_volume_to_linear(v * PA_VOLUME_NORM / hw_volume_max),
		0.0, 1.0);
}

struct spa_bt_backend_implementation {
#define SPA_VERSION_BT_BACKEND_IMPLEMENTATION	0
	uint32_t version;

	int (*free) (void *data);
	int (*register_profiles) (void *data);
	int (*unregister_profiles) (void *data);
	int (*unregistered) (void *data);
	int (*add_filters) (void *data);
	int (*ensure_codec) (void *data, struct spa_bt_device *device, unsigned int codec);
	int (*supports_codec) (void *data, struct spa_bt_device *device, unsigned int codec);
};

struct spa_bt_backend {
	struct spa_callbacks impl;
};

#define spa_bt_backend_set_implementation(b,_impl,_data) \
			(b)->impl = SPA_CALLBACKS_INIT(_impl, _data)

#define spa_bt_backend_impl(b,m,v,...)				\
({								\
	int res = -ENOTSUP;					\
	if (b)							\
		spa_callbacks_call_res(&(b)->impl,		\
			struct spa_bt_backend_implementation,	\
			res, m, v, ##__VA_ARGS__);		\
	res;							\
})

#define spa_bt_backend_free(b)			spa_bt_backend_impl(b, free, 0)
#define spa_bt_backend_register_profiles(b)	spa_bt_backend_impl(b, register_profiles, 0)
#define spa_bt_backend_unregister_profiles(b)	spa_bt_backend_impl(b, unregister_profiles, 0)
#define spa_bt_backend_unregistered(b)		spa_bt_backend_impl(b, unregistered, 0)
#define spa_bt_backend_add_filters(b)		spa_bt_backend_impl(b, add_filters, 0)
#define spa_bt_backend_ensure_codec(b,...)	spa_bt_backend_impl(b, ensure_codec, 0, __VA_ARGS__)
#define spa_bt_backend_supports_codec(b,...)	spa_bt_backend_impl(b, supports_codec, 0, __VA_ARGS__)

static inline struct spa_bt_backend *dummy_backend_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
		uint32_t n_support)
{
	return NULL;
}

#ifdef HAVE_BLUEZ_5_BACKEND_NATIVE
struct spa_bt_backend *backend_native_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
		uint32_t n_support);
#else
#define backend_native_new	dummy_backend_new
#endif

#define OFONO_SERVICE "org.ofono"
#ifdef HAVE_BLUEZ_5_BACKEND_OFONO
struct spa_bt_backend *backend_ofono_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
		uint32_t n_support);
#else
#define backend_ofono_new	dummy_backend_new
#endif

#define HSPHFPD_SERVICE "org.hsphfpd"
#ifdef HAVE_BLUEZ_5_BACKEND_HSPHFPD
struct spa_bt_backend *backend_hsphfpd_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
		uint32_t n_support);
#else
#define backend_hsphfpd_new	dummy_backend_new
#endif

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* SPA_BLUEZ5_DEFS_H */
