/* Spa hsphfpd backend
 *
 * Based on previous work for pulseaudio by: Pali Rohár <pali.rohar@gmail.com>
 * Copyright © 2020 Collabora Ltd.
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

#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>

#include <dbus/dbus.h>

#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/support/dbus.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/param/audio/raw.h>

#include "defs.h"

#define NAME "hsphfpd"

struct impl {
	struct spa_bt_backend this;

	struct spa_bt_monitor *monitor;

	struct spa_log *log;
	struct spa_loop *main_loop;
	struct spa_dbus *dbus;
	DBusConnection *conn;

	struct spa_list endpoint_list;
	bool endpoints_listed;

	char *hsphfpd_service_id;

	bool acquire_in_progress;

	unsigned int filters_added:1;
	unsigned int msbc_supported:1;
};

enum hsphfpd_volume_control {
	HSPHFPD_VOLUME_CONTROL_NONE = 1,
	HSPHFPD_VOLUME_CONTROL_LOCAL,
	HSPHFPD_VOLUME_CONTROL_REMOTE,
};

enum hsphfpd_profile {
	HSPHFPD_PROFILE_HEADSET = 1,
	HSPHFPD_PROFILE_HANDSFREE,
};

enum hsphfpd_role {
	HSPHFPD_ROLE_CLIENT = 1,
	HSPHFPD_ROLE_GATEWAY,
};

struct hsphfpd_transport_data {
	char *transport_path;
	bool rx_soft_volume;
	bool tx_soft_volume;
	int rx_volume_gain;
	int tx_volume_gain;
	int max_rx_volume_gain;
	int max_tx_volume_gain;
	enum hsphfpd_volume_control rx_volume_control;
	enum hsphfpd_volume_control tx_volume_control;
};

struct hsphfpd_endpoint {
	struct spa_list link;
	char *path;
	bool valid;
	bool connected;
	char *remote_address;
	char *local_address;
	enum hsphfpd_profile profile;
	enum hsphfpd_role role;
	int air_codecs;
};

#define DBUS_INTERFACE_OBJECTMANAGER "org.freedesktop.DBus.ObjectManager"

#define HSPHFPD_APPLICATION_MANAGER_INTERFACE HSPHFPD_SERVICE ".ApplicationManager"
#define HSPHFPD_ENDPOINT_INTERFACE            HSPHFPD_SERVICE ".Endpoint"
#define HSPHFPD_AUDIO_AGENT_INTERFACE         HSPHFPD_SERVICE ".AudioAgent"
#define HSPHFPD_AUDIO_TRANSPORT_INTERFACE     HSPHFPD_SERVICE ".AudioTransport"

#define APPLICATION_OBJECT_MANAGER_PATH    "/Profile/hsphfpd/manager"
#define HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ "/Profile/hsphfpd/pcm_s16le_8khz_agent"
#define HSPHFP_AUDIO_CLIENT_MSBC           "/Profile/hsphfpd/msbc_agent"

#define HSPHFP_AIR_CODEC_CVSD           "CVSD"
#define HSPHFP_AIR_CODEC_MSBC           "mSBC"
#define HSPHFP_AGENT_CODEC_PCM          "PCM_s16le_8kHz"
#define HSPHFP_AGENT_CODEC_MSBC         "mSBC"

#define APPLICATION_OBJECT_MANAGER_INTROSPECT_XML                              \
    DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                                  \
    "<node>\n"                                                                 \
    " <interface name=\"" DBUS_INTERFACE_OBJECTMANAGER "\">\n"                 \
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
    " <interface name=\"" DBUS_INTERFACE_INTROSPECTABLE "\">\n"                \
    "  <method name=\"Introspect\">\n"                                         \
    "   <arg name=\"data\" direction=\"out\" type=\"s\"/>\n"                   \
    "  </method>\n"                                                            \
    " </interface>\n"                                                          \
    "</node>\n"

#define AUDIO_AGENT_ENDPOINT_INTROSPECT_XML                           \
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                           \
	"<node>\n"                                                          \
	" <interface name=\"" HSPHFPD_AUDIO_AGENT_INTERFACE "\">\n"         \
	"  <method name=\"NewConnection\">\n"                               \
	"   <arg name=\"audio_transport\" direction=\"in\" type=\"o\"/>\n"  \
	"   <arg name=\"fd\" direction=\"in\" type=\"h\"/>\n"               \
	"   <arg name=\"properties\" direction=\"in\" type=\"a{sv}\"/>\n"   \
	"  </method>\n"                                                     \
	"  <property name=\"AgentCodec\" type=\"s\" access=\"read\"/>\n"    \
	" </interface>\n"                                                   \
	" <interface name=\"" DBUS_INTERFACE_INTROSPECTABLE "\">\n"         \
	"  <method name=\"Introspect\">\n"                                  \
	"   <arg name=\"data\" type=\"s\" direction=\"out\"/>\n"            \
	"  </method>\n"                                                     \
	" </interface>\n"                                                   \
	"</node>\n"

#define HSPHFPD_ERROR_INVALID_ARGUMENTS   HSPHFPD_SERVICE ".Error.InvalidArguments"
#define HSPHFPD_ERROR_ALREADY_EXISTS      HSPHFPD_SERVICE ".Error.AlreadyExists"
#define HSPHFPD_ERROR_DOES_NOT_EXISTS     HSPHFPD_SERVICE ".Error.DoesNotExist"
#define HSPHFPD_ERROR_NOT_CONNECTED       HSPHFPD_SERVICE ".Error.NotConnected"
#define HSPHFPD_ERROR_ALREADY_CONNECTED   HSPHFPD_SERVICE ".Error.AlreadyConnected"
#define HSPHFPD_ERROR_IN_PROGRESS         HSPHFPD_SERVICE ".Error.InProgress"
#define HSPHFPD_ERROR_IN_USE              HSPHFPD_SERVICE ".Error.InUse"
#define HSPHFPD_ERROR_NOT_SUPPORTED       HSPHFPD_SERVICE ".Error.NotSupported"
#define HSPHFPD_ERROR_NOT_AVAILABLE       HSPHFPD_SERVICE ".Error.NotAvailable"
#define HSPHFPD_ERROR_FAILED              HSPHFPD_SERVICE ".Error.Failed"
#define HSPHFPD_ERROR_REJECTED            HSPHFPD_SERVICE ".Error.Rejected"
#define HSPHFPD_ERROR_CANCELED            HSPHFPD_SERVICE ".Error.Canceled"

static struct hsphfpd_endpoint *endpoint_find(struct impl *backend, const char *path)
{
	struct hsphfpd_endpoint *d;
	spa_list_for_each(d, &backend->endpoint_list, link)
		if (strcmp(d->path, path) == 0)
			return d;
	return NULL;
}

static void endpoint_free(struct hsphfpd_endpoint *endpoint)
{
	spa_list_remove(&endpoint->link);
	free(endpoint->path);
	if (endpoint->local_address)
		free(endpoint->local_address);
	if (endpoint->remote_address)
		free(endpoint->remote_address);
}

static bool hsphfpd_cmp_transport_path(struct spa_bt_transport *t, const void *data)
{
	struct hsphfpd_transport_data *td = t->user_data;
	if (strcmp(td->transport_path, data) == 0)
		return true;

	return false;
}

static int set_dbus_property(struct impl *backend,
                             const char *service,
                             const char *path,
                             const char *interface,
                             const char *property,
                             int type,
                             void *value)
{
	DBusMessage *m, *r;
	DBusMessageIter iter;
	DBusError err;

	m = dbus_message_new_method_call(HSPHFPD_SERVICE, path, DBUS_INTERFACE_PROPERTIES, "Set");
	if (m == NULL)
		return -ENOMEM;
	dbus_message_append_args(m, DBUS_TYPE_STRING, &interface, DBUS_TYPE_STRING, &property, DBUS_TYPE_INVALID);
	dbus_message_iter_init_append(m, &iter);
	dbus_message_iter_append_basic(&iter, type, value);

	dbus_error_init(&err);

	r = dbus_connection_send_with_reply_and_block(backend->conn, m, -1, &err);
	dbus_message_unref(m);
	m = NULL;

	if (r == NULL) {
		spa_log_error(backend->log, NAME": Transport Set() failed for transport %s (%s)", path, err.message);
		dbus_error_free(&err);
		return -EIO;
	}

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": Set() returned error: %s", dbus_message_get_error_name(r));
		return -EIO;
	}

	dbus_message_unref(r);
	return 0;
}

static inline void set_rx_volume_gain_property(const struct spa_bt_transport *transport, uint16_t gain)
{
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);
	struct hsphfpd_transport_data *transport_data = transport->user_data;

	if (transport->fd < 0 || transport_data->rx_volume_control <= HSPHFPD_VOLUME_CONTROL_NONE)
		return;
	if (set_dbus_property(backend, HSPHFPD_SERVICE, transport_data->transport_path,
	                      HSPHFPD_AUDIO_TRANSPORT_INTERFACE, "RxVolumeGain",
	                      DBUS_TYPE_UINT16, &gain))
		spa_log_error(backend->log, NAME": Changing rx volume gain to %u for transport %s failed",
		              (unsigned)gain, transport_data->transport_path);
}

static inline void set_tx_volume_gain_property(const struct spa_bt_transport *transport, uint16_t gain)
{
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);
	struct hsphfpd_transport_data *transport_data = transport->user_data;

	if (transport->fd < 0 || transport_data->tx_volume_control <= HSPHFPD_VOLUME_CONTROL_NONE)
		return;
	if (set_dbus_property(backend, HSPHFPD_SERVICE, transport_data->transport_path,
	                      HSPHFPD_AUDIO_TRANSPORT_INTERFACE, "TxVolumeGain",
	                      DBUS_TYPE_UINT16, &gain))
		spa_log_error(backend->log, NAME": Changing tx volume gain to %u for transport %s failed",
		              (unsigned)gain, transport_data->transport_path);
}

static void parse_transport_properties_values(struct impl *backend,
                                              const char *transport_path,
                                              DBusMessageIter *i,
                                              const char **endpoint_path,
                                              const char **air_codec,
                                              enum hsphfpd_volume_control *rx_volume_control,
                                              enum hsphfpd_volume_control *tx_volume_control,
                                              uint16_t *rx_volume_gain,
                                              uint16_t *tx_volume_gain,
                                              uint16_t *mtu)
{
	DBusMessageIter element_i;

	spa_assert(i);

	dbus_message_iter_recurse(i, &element_i);

	while (dbus_message_iter_get_arg_type(&element_i) == DBUS_TYPE_DICT_ENTRY) {
		DBusMessageIter dict_i, variant_i;
		const char *key;

		dbus_message_iter_recurse(&element_i, &dict_i);

		if (dbus_message_iter_get_arg_type(&dict_i) != DBUS_TYPE_STRING) {
			spa_log_error(backend->log, NAME": Received invalid property for transport %s", transport_path);
			return;
		}

		dbus_message_iter_get_basic(&dict_i, &key);

		if (!dbus_message_iter_next(&dict_i)) {
			spa_log_error(backend->log, NAME": Received invalid property for transport %s", transport_path);
			return;
		}

		if (dbus_message_iter_get_arg_type(&dict_i) != DBUS_TYPE_VARIANT) {
			spa_log_error(backend->log, NAME": Received invalid property for transport %s", transport_path);
			return;
		}

		dbus_message_iter_recurse(&dict_i, &variant_i);

		switch (dbus_message_iter_get_arg_type(&variant_i)) {
			case DBUS_TYPE_STRING:
				if (strcmp(key, "RxVolumeControl") == 0 || strcmp(key, "TxVolumeControl") == 0) {
					const char *value;
					enum hsphfpd_volume_control volume_control;

					dbus_message_iter_get_basic(&variant_i, &value);
					if (strcmp(value, "none") == 0)
						volume_control = HSPHFPD_VOLUME_CONTROL_NONE;
					else if (strcmp(value, "local") == 0)
						volume_control = HSPHFPD_VOLUME_CONTROL_LOCAL;
					else if (strcmp(value, "remote") == 0)
						volume_control = HSPHFPD_VOLUME_CONTROL_REMOTE;
					else
						volume_control = 0;

					if (!volume_control)
						spa_log_warn(backend->log, NAME": Transport %s received invalid '%s' property value '%s', ignoring", transport_path, key, value);
					else if (strcmp(key, "RxVolumeControl") == 0)
						*rx_volume_control = volume_control;
					else if (strcmp(key, "TxVolumeControl") == 0)
						*tx_volume_control = volume_control;
				} else if (strcmp(key, "AirCodec") == 0)
					dbus_message_iter_get_basic(&variant_i, air_codec);
				break;

			case DBUS_TYPE_UINT16:
				if (strcmp(key, "MTU") == 0)
					dbus_message_iter_get_basic(&variant_i, mtu);
				else if (strcmp(key, "RxVolumeGain") == 0)
					dbus_message_iter_get_basic(&variant_i, rx_volume_gain);
				else if (strcmp(key, "TxVolumeGain") == 0)
					dbus_message_iter_get_basic(&variant_i, tx_volume_gain);
				break;

			case DBUS_TYPE_OBJECT_PATH:
				if (strcmp(key, "Endpoint") == 0)
					dbus_message_iter_get_basic(&variant_i, endpoint_path);
				break;
		}

		dbus_message_iter_next(&element_i);
	}
}

static void hsphfpd_parse_transport_properties(struct impl *backend, struct spa_bt_transport *transport, DBusMessageIter *i)
{
	struct hsphfpd_transport_data *transport_data = transport->user_data;
	const char *endpoint_path = NULL;
	const char *air_codec = NULL;
	enum hsphfpd_volume_control rx_volume_control = 0;
	enum hsphfpd_volume_control tx_volume_control = 0;
	uint16_t rx_volume_gain = -1;
	uint16_t tx_volume_gain = -1;
	uint16_t mtu = 0;
	bool rx_volume_gain_changed = false;
	bool tx_volume_gain_changed = false;
	bool rx_volume_control_changed = false;
	bool tx_volume_control_changed = false;
	bool rx_soft_volume_changed = false;
	bool tx_soft_volume_changed = false;

	parse_transport_properties_values(backend, transport_data->transport_path, i, &endpoint_path,
	                                  &air_codec, &rx_volume_control, &tx_volume_control,
																		&rx_volume_gain, &tx_volume_gain, &mtu);

	if (endpoint_path)
			spa_log_warn(backend->log, NAME": Transport %s received a duplicate '%s' property, ignoring",
			             transport_data->transport_path, "Endpoint");

	if (air_codec)
			spa_log_warn(backend->log, NAME": Transport %s received a duplicate '%s' property, ignoring",
			             transport_data->transport_path, "AirCodec");

	if (mtu)
			spa_log_warn(backend->log, NAME": Transport %s received a duplicate '%s' property, ignoring",
			             transport_data->transport_path, "MTU");

	if (rx_volume_control) {
		if (!!transport_data->rx_soft_volume != !!(rx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE)) {
			spa_log_info(backend->log, NAME": Transport %s changed rx soft volume from %d to %d",
			             transport_data->transport_path, transport_data->rx_soft_volume,
			             (rx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE));
			transport_data->rx_soft_volume = (rx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE);
			rx_soft_volume_changed = true;
		}
		if (transport_data->rx_volume_control != rx_volume_control) {
			transport_data->rx_volume_control = rx_volume_control;
			rx_volume_control_changed = true;
		}
	}

	if (tx_volume_control) {
		if (!!transport_data->tx_soft_volume != !!(tx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE)) {
			spa_log_info(backend->log, NAME": Transport %s changed tx soft volume from %d to %d",
			             transport_data->transport_path, transport_data->rx_soft_volume,
			             (tx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE));
			transport_data->tx_soft_volume = (tx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE);
			tx_soft_volume_changed = true;
		}
		if (transport_data->tx_volume_control != tx_volume_control) {
			transport_data->tx_volume_control = tx_volume_control;
			tx_volume_control_changed = true;
		}
	}

	if (rx_volume_gain != (uint16_t)-1) {
		if (transport_data->rx_volume_gain != rx_volume_gain) {
			spa_log_info(backend->log, NAME": Transport %s changed rx volume gain from %u to %u",
			             transport_data->transport_path, (unsigned)transport_data->rx_volume_gain, (unsigned)rx_volume_gain);
			transport_data->rx_volume_gain = rx_volume_gain;
			rx_volume_gain_changed = true;
		}
	}

	if (tx_volume_gain != (uint16_t)-1) {
		if (transport_data->tx_volume_gain != tx_volume_gain) {
			spa_log_info(backend->log, NAME": Transport %s changed tx volume gain from %u to %u",
			             transport_data->transport_path, (unsigned)transport_data->tx_volume_gain, (unsigned)tx_volume_gain);
			transport_data->tx_volume_gain = tx_volume_gain;
			tx_volume_gain_changed = true;
		}
	}

#if 0
	if (rx_volume_gain_changed || rx_soft_volume_changed)
		pa_hook_fire(pa_bluetooth_discovery_hook(transport_data->hsphfpd->discovery, PA_BLUETOOTH_HOOK_TRANSPORT_RX_VOLUME_GAIN_CHANGED), transport);

	if (tx_volume_gain_changed || tx_soft_volume_changed)
		pa_hook_fire(pa_bluetooth_discovery_hook(transport_data->hsphfpd->discovery, PA_BLUETOOTH_HOOK_TRANSPORT_TX_VOLUME_GAIN_CHANGED), transport);
#else
	spa_log_debug(backend->log, NAME": RX volume gain changed: %d, soft volume changed: %d", rx_volume_gain_changed, rx_soft_volume_changed);
	spa_log_debug(backend->log, NAME": TX volume gain changed: %d, soft volume changed: %d", tx_volume_gain_changed, tx_soft_volume_changed);
#endif

	if (rx_volume_control_changed)
		set_rx_volume_gain_property(transport, transport_data->rx_volume_gain);

	if (tx_volume_control_changed)
		set_tx_volume_gain_property(transport, transport_data->tx_volume_gain);
}

static DBusHandlerResult audio_agent_get_property(DBusConnection *conn, DBusMessage *m, const char *path, void *userdata)
{
	const char *interface;
	const char *property;
	const char *agent_codec;
	DBusMessage *r = NULL;

	if (strcmp(dbus_message_get_signature(m), "ss") != 0) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid signature in method call");
		goto fail;
	}

	if (dbus_message_get_args(m, NULL,
	                          DBUS_TYPE_STRING, &interface,
														DBUS_TYPE_STRING, &property,
														DBUS_TYPE_INVALID) == FALSE) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid arguments in method call");
		goto fail;
	}

	if (strcmp(interface, HSPHFPD_AUDIO_AGENT_INTERFACE) != 0)
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	if (strcmp(property, "AgentCodec") != 0) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid property in method call");
		goto fail;
	}

	if (strcmp(path, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ) == 0)
		agent_codec = HSPHFP_AGENT_CODEC_PCM;
	else if (strcmp(path, HSPHFP_AUDIO_CLIENT_MSBC) == 0)
		agent_codec = HSPHFP_AGENT_CODEC_MSBC;
	else {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid path in method call");
		goto fail;
	}

	if ((r = dbus_message_new_method_return(m)) == NULL)
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	if (!dbus_message_append_args(r, DBUS_TYPE_STRING, &agent_codec, DBUS_TYPE_INVALID))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

fail:
	if (!dbus_connection_send(conn, r, NULL))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

	dbus_message_unref(r);
	return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult audio_agent_getall_properties(DBusConnection *conn, DBusMessage *m, const char *path, void *userdata)
{
	const char *interface;
	DBusMessageIter iter, array, dict, data;
	const char *agent_codec_key = "AgentCodec";
	const char *agent_codec;
	DBusMessage *r = NULL;

	if (strcmp(dbus_message_get_signature(m), "s") != 0) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid signature in method call");
		goto fail;
	}

	if (dbus_message_get_args(m, NULL,
	                          DBUS_TYPE_STRING, &interface,
	                          DBUS_TYPE_INVALID) == FALSE) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid arguments in method call");
		goto fail;
	}

	if (strcmp(path, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ) == 0)
		agent_codec = HSPHFP_AGENT_CODEC_PCM;
	else if (strcmp(path, HSPHFP_AUDIO_CLIENT_MSBC) == 0)
		agent_codec = HSPHFP_AGENT_CODEC_MSBC;
	else {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid path in method call");
		goto fail;
	}

	if (strcmp(interface, HSPHFPD_AUDIO_AGENT_INTERFACE) != 0)
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	if ((r = dbus_message_new_method_return(m)) == NULL)
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "{sv}", &array);
	dbus_message_iter_open_container(&array, DBUS_TYPE_DICT_ENTRY, NULL, &dict);
	dbus_message_iter_append_basic(&dict, DBUS_TYPE_STRING, &agent_codec_key);
	dbus_message_iter_open_container(&dict, DBUS_TYPE_VARIANT, "s", &data);
	dbus_message_iter_append_basic(&data, DBUS_TYPE_BOOLEAN, &agent_codec);
	dbus_message_iter_close_container(&dict, &data);
	dbus_message_iter_close_container(&array, &dict);
	dbus_message_iter_close_container(&iter, &array);

fail:
	if (!dbus_connection_send(conn, r, NULL))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

	dbus_message_unref(r);
	return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult hsphfpd_new_audio_connection(DBusConnection *conn, DBusMessage *m, const char *path, void *userdata)
{
	struct impl *backend = userdata;
	DBusMessageIter arg_i;
	const char *transport_path;
	int fd;
	const char *sender;
	const char *endpoint_path = NULL;
	const char *air_codec = NULL;
	enum hsphfpd_volume_control rx_volume_control = 0;
	enum hsphfpd_volume_control tx_volume_control = 0;
	uint16_t rx_volume_gain = -1;
	uint16_t tx_volume_gain = -1;
	uint16_t mtu = 0;
	unsigned int codec;
	struct hsphfpd_endpoint *endpoint;
	struct spa_bt_transport *transport;
	struct hsphfpd_transport_data *transport_data;
	DBusMessage *r = NULL;

	if (strcmp(dbus_message_get_signature(m), "oha{sv}") != 0) {
		r = dbus_message_new_error(m, DBUS_ERROR_INVALID_ARGS, "Invalid signature in method call");
		goto fail;
	}

	if (!dbus_message_iter_init(m, &arg_i))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

	dbus_message_iter_get_basic(&arg_i, &transport_path);
	dbus_message_iter_next(&arg_i);
	dbus_message_iter_get_basic(&arg_i, &fd);

	spa_log_debug(backend->log, NAME": NewConnection %s, fd %d", transport_path, fd);

	sender = dbus_message_get_sender(m);
	if (strcmp(sender, backend->hsphfpd_service_id) != 0) {
		close(fd);
		spa_log_error(backend->log, NAME": Sender '%s' is not authorized", sender);
		r = dbus_message_new_error_printf(m, HSPHFPD_ERROR_REJECTED, "Sender '%s' is not authorized", sender);
		goto fail;
	}

	if (strcmp(path, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ) == 0)
		codec = HFP_AUDIO_CODEC_CVSD;
	else if (strcmp(path, HSPHFP_AUDIO_CLIENT_MSBC) == 0)
		codec = HFP_AUDIO_CODEC_MSBC;
	else {
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "Invalid path");
		goto fail;
	}

	dbus_message_iter_next(&arg_i);
	parse_transport_properties_values(backend, transport_path, &arg_i,
	                                  &endpoint_path, &air_codec,
	                                  &rx_volume_control, &tx_volume_control,
																		&rx_volume_gain, &tx_volume_gain,
																		&mtu);

	if (!endpoint_path) {
		close(fd);
		spa_log_error(backend->log, NAME": Endpoint property was not specified");
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "Endpoint property was not specified");
		goto fail;
	}

	if (!air_codec) {
		close(fd);
		spa_log_error(backend->log, NAME": AirCodec property was not specified");
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "AirCodec property was not specified");
		goto fail;
	}

	if (!rx_volume_control) {
		close(fd);
		spa_log_error(backend->log, NAME": RxVolumeControl property was not specified");
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "RxVolumeControl property was not specified");
		goto fail;
	}

	if (!tx_volume_control) {
		close(fd);
		spa_log_error(backend->log, NAME": TxVolumeControl property was not specified");
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "TxVolumeControl property was not specified");
		goto fail;
	}

	if (rx_volume_control != HSPHFPD_VOLUME_CONTROL_NONE) {
		if (rx_volume_gain == (uint16_t)-1) {
			close(fd);
			spa_log_error(backend->log, NAME": RxVolumeGain property was not specified, but VolumeControl is not none");
			r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "RxVolumeGain property was not specified, but VolumeControl is not none");
			goto fail;
		}
	} else {
		rx_volume_gain = 15; /* No volume control, so set maximal value */
	}

	if (tx_volume_control != HSPHFPD_VOLUME_CONTROL_NONE) {
		if (tx_volume_gain == (uint16_t)-1) {
			close(fd);
			spa_log_error(backend->log, NAME": TxVolumeGain property was not specified, but VolumeControl is not none");
			r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "TxVolumeGain property was not specified, but VolumeControl is not none");
			goto fail;
		}
	} else {
		tx_volume_gain = 15; /* No volume control, so set maximal value */
	}

	if (!mtu) {
		close(fd);
		spa_log_error(backend->log, NAME": MTU property was not specified");
		r = dbus_message_new_error(m, HSPHFPD_ERROR_REJECTED, "MTU property was not specified");
		goto fail;
	}

	endpoint = endpoint_find(backend, endpoint_path);
	if (!endpoint) {
		close(fd);
		spa_log_error(backend->log, NAME": Endpoint %s does not exist", endpoint_path);
		r = dbus_message_new_error_printf(m, HSPHFPD_ERROR_REJECTED, "Endpoint %s does not exist", endpoint_path);
		goto fail;
	}

	if (!endpoint->valid) {
		close(fd);
		spa_log_error(backend->log, NAME": Endpoint %s is not valid", endpoint_path);
		r = dbus_message_new_error_printf(m, HSPHFPD_ERROR_REJECTED, "Endpoint %s is not valid", endpoint_path);
		goto fail;
	}

	transport = spa_bt_transport_find(backend->monitor, endpoint_path);
	if (!transport) {
		close(fd);
		spa_log_error(backend->log, NAME": Endpoint %s is not connected", endpoint_path);
		r = dbus_message_new_error_printf(m, HSPHFPD_ERROR_REJECTED, "Endpoint %s is not connected", endpoint_path);
		goto fail;
	}

	if (transport->codec != codec)
		spa_log_warn(backend->log, NAME": Expecting codec to be %d, got %d", transport->codec, codec);

	if (transport->fd >= 0) {
		close(fd);
		spa_log_error(backend->log, NAME": Endpoint %s has already active transport", endpoint_path);
		r = dbus_message_new_error_printf(m, HSPHFPD_ERROR_REJECTED, "Endpoint %s has already active transport", endpoint_path);
		goto fail;
	}

	transport_data = transport->user_data;
	transport_data->transport_path = strdup(transport_path);
	transport_data->rx_soft_volume = (rx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE);
	transport_data->tx_soft_volume = (tx_volume_control != HSPHFPD_VOLUME_CONTROL_REMOTE);
	transport_data->rx_volume_gain = rx_volume_gain;
	transport_data->tx_volume_gain = tx_volume_gain;
	transport_data->rx_volume_control = rx_volume_control;
	transport_data->tx_volume_control = tx_volume_control;

#if 0
	pa_hook_fire(pa_bluetooth_discovery_hook(hsphfpd->discovery, PA_BLUETOOTH_HOOK_TRANSPORT_RX_VOLUME_GAIN_CHANGED), transport);
	pa_hook_fire(pa_bluetooth_discovery_hook(hsphfpd->discovery, PA_BLUETOOTH_HOOK_TRANSPORT_TX_VOLUME_GAIN_CHANGED), transport);
#endif

	transport->read_mtu = mtu;
	transport->write_mtu = mtu;

	transport->fd = fd;

	if ((r = dbus_message_new_method_return(m)) == NULL)
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

fail:
	if (r) {
		DBusHandlerResult res = DBUS_HANDLER_RESULT_HANDLED;
		if (!dbus_connection_send(backend->conn, r, NULL))
			res = DBUS_HANDLER_RESULT_NEED_MEMORY;
		dbus_message_unref(r);
		return res;
	}

	return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult audio_agent_endpoint_handler(DBusConnection *c, DBusMessage *m, void *userdata)
{
	struct impl *backend = userdata;
	const char *path, *interface, *member;
	DBusMessage *r;
	DBusHandlerResult res;

	path = dbus_message_get_path(m);
	interface = dbus_message_get_interface(m);
	member = dbus_message_get_member(m);

	spa_log_debug(backend->log, NAME": dbus: path=%s, interface=%s, member=%s", path, interface, member);

	if (dbus_message_is_method_call(m, "org.freedesktop.DBus.Introspectable", "Introspect")) {
		const char *xml = AUDIO_AGENT_ENDPOINT_INTROSPECT_XML;

		if ((r = dbus_message_new_method_return(m)) == NULL)
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
		if (!dbus_message_append_args(r, DBUS_TYPE_STRING, &xml, DBUS_TYPE_INVALID))
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
		if (!dbus_connection_send(backend->conn, r, NULL))
			return DBUS_HANDLER_RESULT_NEED_MEMORY;

		dbus_message_unref(r);
		res = DBUS_HANDLER_RESULT_HANDLED;
	} else if (dbus_message_is_method_call(m, DBUS_INTERFACE_PROPERTIES, "Get"))
		res = audio_agent_get_property(c, m, path, userdata);
	else if (dbus_message_is_method_call(m, DBUS_INTERFACE_PROPERTIES, "GetAll"))
		res = audio_agent_getall_properties(c, m, path, userdata);
	else if (dbus_message_is_method_call(m, HSPHFPD_AUDIO_AGENT_INTERFACE, "NewConnection"))
		res = hsphfpd_new_audio_connection(c, m, path, userdata);
	else
		res = DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	return res;
}

static void append_audio_agent_object(DBusMessageIter *iter, const char *endpoint, const char *agent_codec)
{
	const char *interface_name = HSPHFPD_AUDIO_AGENT_INTERFACE;
	DBusMessageIter object, array, entry, dict, codec, data;
	char *str = "AgentCodec";

	dbus_message_iter_open_container(iter, DBUS_TYPE_DICT_ENTRY, NULL, &object);
	dbus_message_iter_append_basic(&object, DBUS_TYPE_OBJECT_PATH, &endpoint);

	dbus_message_iter_open_container(&object, DBUS_TYPE_ARRAY, "{sa{sv}}", &array);

	dbus_message_iter_open_container(&array, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
	dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &interface_name);

	dbus_message_iter_open_container(&entry, DBUS_TYPE_ARRAY, "{sv}", &dict);

	dbus_message_iter_open_container(&dict, DBUS_TYPE_DICT_ENTRY, NULL, &codec);
	dbus_message_iter_append_basic(&codec, DBUS_TYPE_STRING, &str);
	dbus_message_iter_open_container(&codec, DBUS_TYPE_VARIANT, "s", &data);
	dbus_message_iter_append_basic(&data, DBUS_TYPE_STRING, &agent_codec);
	dbus_message_iter_close_container(&codec, &data);
	dbus_message_iter_close_container(&dict, &codec);

	dbus_message_iter_close_container(&entry, &dict);
	dbus_message_iter_close_container(&array, &entry);
	dbus_message_iter_close_container(&object, &array);
	dbus_message_iter_close_container(iter, &object);
}

static DBusHandlerResult application_object_manager_handler(DBusConnection *c, DBusMessage *m, void *userdata)
{
	struct impl *backend = userdata;
	const char *path, *interface, *member;
	DBusMessage *r;

	path = dbus_message_get_path(m);
	interface = dbus_message_get_interface(m);
	member = dbus_message_get_member(m);

	spa_log_debug(backend->log, NAME": dbus: path=%s, interface=%s, member=%s", path, interface, member);

	if (dbus_message_is_method_call(m, "org.freedesktop.DBus.Introspectable", "Introspect")) {
		const char *xml = APPLICATION_OBJECT_MANAGER_INTROSPECT_XML;

		if ((r = dbus_message_new_method_return(m)) == NULL)
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
		if (!dbus_message_append_args(r, DBUS_TYPE_STRING, &xml, DBUS_TYPE_INVALID))
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
	} else if (dbus_message_is_method_call(m, DBUS_INTERFACE_OBJECTMANAGER, "GetManagedObjects")) {
		DBusMessageIter iter, array;

		if ((r = dbus_message_new_method_return(m)) == NULL)
			return DBUS_HANDLER_RESULT_NEED_MEMORY;

		dbus_message_iter_init_append(r, &iter);
		dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "{oa{sa{sv}}}", &array);

		append_audio_agent_object(&array, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ, HSPHFP_AGENT_CODEC_PCM);
		if (backend->msbc_supported)
			append_audio_agent_object(&array, HSPHFP_AUDIO_CLIENT_MSBC, HSPHFP_AGENT_CODEC_MSBC);

		dbus_message_iter_close_container(&iter, &array);
	} else
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	if (!dbus_connection_send(backend->conn, r, NULL))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	dbus_message_unref(r);

  return DBUS_HANDLER_RESULT_HANDLED;
}

static void hsphfpd_audio_acquire_reply(DBusPendingCall *pending, void *user_data)
{
	struct impl *backend = user_data;
	DBusMessage *r;
	const char *transport_path;
	const char *service_id;
	const char *agent_path;
	DBusError error;

	dbus_error_init(&error);

	backend->acquire_in_progress = false;

	r = dbus_pending_call_steal_reply(pending);
	if (r == NULL)
		return;

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": RegisterApplication() failed: %s",
				dbus_message_get_error_name(r));
		goto finish;
	}

	if (strcmp(dbus_message_get_sender(r), backend->hsphfpd_service_id) != 0) {
		spa_log_error(backend->log, NAME": Reply for " HSPHFPD_ENDPOINT_INTERFACE ".ConnectAudio() from invalid sender");
		goto finish;
	}

	if (strcmp(dbus_message_get_signature(r), "oso") != 0) {
		spa_log_error(backend->log, NAME": Invalid reply signature for " HSPHFPD_ENDPOINT_INTERFACE ".ConnectAudio()");
		goto finish;
	}

	if (dbus_message_get_args(r, &error,
	                          DBUS_TYPE_OBJECT_PATH, &transport_path,
	                          DBUS_TYPE_STRING, &service_id,
	                          DBUS_TYPE_OBJECT_PATH, &agent_path,
	                          DBUS_TYPE_INVALID) == FALSE) {
		spa_log_error(backend->log, NAME": Failed to parse " HSPHFPD_ENDPOINT_INTERFACE ".ConnectAudio() reply: %s", error.message);
		goto finish;
	}

	if (strcmp(service_id, dbus_bus_get_unique_name(backend->conn)) != 0) {
		spa_log_warn(backend->log, HSPHFPD_ENDPOINT_INTERFACE ".ConnectAudio() failed: Other audio application took audio socket");
		goto finish;
	}

	spa_log_debug(backend->log, NAME": hsphfpd audio acquired");

finish:
	dbus_message_unref(r);
	dbus_pending_call_unref(pending);
}

static int hsphfpd_audio_acquire(void *data, bool optional)
{
	struct spa_bt_transport *transport = data;
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);
	DBusMessage *m;
	const char *air_codec = HSPHFP_AIR_CODEC_CVSD;
	const char *agent_codec = HSPHFP_AGENT_CODEC_PCM;
	DBusPendingCall *call;
	DBusError err;

	spa_log_debug(backend->log, NAME": transport %p: Acquire %s",
			transport, transport->path);

	if (backend->acquire_in_progress)
		return -EINPROGRESS;

	if (transport->codec == HFP_AUDIO_CODEC_MSBC) {
		air_codec = HSPHFP_AIR_CODEC_MSBC;
		agent_codec = HSPHFP_AGENT_CODEC_MSBC;
	}

	m = dbus_message_new_method_call(HSPHFPD_SERVICE,
					 transport->path,
					 HSPHFPD_ENDPOINT_INTERFACE,
					 "ConnectAudio");
	if (m == NULL)
		return -ENOMEM;
	dbus_message_append_args(m, DBUS_TYPE_STRING, &air_codec, DBUS_TYPE_STRING, &agent_codec, DBUS_TYPE_INVALID);

	dbus_error_init(&err);

	dbus_connection_send_with_reply(backend->conn, m, &call, -1);
	dbus_pending_call_set_notify(call, hsphfpd_audio_acquire_reply, backend, NULL);
	dbus_message_unref(m);

	/* The ConnectAudio method triggers Introspect and NewConnection calls,
	   which will set the fd to use for the SCO data.
	   We need to run the DBus loop to be able to reply to those method calls */
	backend->acquire_in_progress = true;
	while (backend->acquire_in_progress && dbus_connection_read_write_dispatch(backend->conn, -1))
		; // empty loop body

	return 0;
}

static int hsphfpd_audio_release(void *data)
{
	struct spa_bt_transport *transport = data;
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);
	struct hsphfpd_transport_data *transport_data = transport->user_data;

	spa_log_debug(backend->log, NAME": transport %p: Release %s",
			transport, transport->path);

	if (transport->sco_io) {
		spa_bt_sco_io_destroy(transport->sco_io);
		transport->sco_io = NULL;
	}

	/* shutdown to make sure connection is dropped immediately */
	shutdown(transport->fd, SHUT_RDWR);
	close(transport->fd);
	if (transport_data->transport_path) {
		free(transport_data->transport_path);
		transport_data->transport_path = NULL;
	}
	transport->fd = -1;

	return 0;
}

static int hsphfpd_audio_destroy(void *data)
{
	struct spa_bt_transport *transport = data;
	struct hsphfpd_transport_data *transport_data = transport->user_data;

	if (transport_data->transport_path) {
		free(transport_data->transport_path);
		transport_data->transport_path = NULL;
	}

	return 0;
}

static const struct spa_bt_transport_implementation hsphfpd_transport_impl = {
	SPA_VERSION_BT_TRANSPORT_IMPLEMENTATION,
	.acquire = hsphfpd_audio_acquire,
	.release = hsphfpd_audio_release,
	.destroy = hsphfpd_audio_destroy,
};

static DBusHandlerResult hsphfpd_parse_endpoint_properties(struct impl *backend, struct hsphfpd_endpoint *endpoint, DBusMessageIter *i)
{
	DBusMessageIter element_i;
	struct spa_bt_device *d;
	struct spa_bt_transport *t;

	dbus_message_iter_recurse(i, &element_i);
	while (dbus_message_iter_get_arg_type(&element_i) == DBUS_TYPE_DICT_ENTRY) {
		DBusMessageIter dict_i, value_i;
		const char *key;

		dbus_message_iter_recurse(&element_i, &dict_i);
		dbus_message_iter_get_basic(&dict_i, &key);
		dbus_message_iter_next(&dict_i);
		dbus_message_iter_recurse(&dict_i, &value_i);
		switch (dbus_message_iter_get_arg_type(&value_i)) {
			case DBUS_TYPE_STRING:
				{
					const char *value;
					dbus_message_iter_get_basic(&value_i, &value);
					if (strcmp(key, "RemoteAddress") == 0)
						endpoint->remote_address = strdup(value);
					else if (strcmp(key, "LocalAddress") == 0)
						endpoint->local_address = strdup(value);
					else if (strcmp(key, "Profile") == 0) {
						if (endpoint->profile)
							spa_log_warn(backend->log, NAME": Endpoint %s received a duplicate '%s' property, ignoring", endpoint->path, key);
						else if (strcmp(value, "headset") == 0)
							endpoint->profile = HSPHFPD_PROFILE_HEADSET;
						else if (strcmp(value, "handsfree") == 0)
							endpoint->profile = HSPHFPD_PROFILE_HANDSFREE;
						else
							spa_log_warn(backend->log, NAME": Endpoint %s received invalid '%s' property value '%s', ignoring", endpoint->path, key, value);
					} else if (strcmp(key, "Role") == 0) {
						if (endpoint->role)
							spa_log_warn(backend->log, NAME": Endpoint %s received a duplicate '%s' property, ignoring", endpoint->path, key);
						else if (strcmp(value, "client") == 0)
							endpoint->role = HSPHFPD_ROLE_CLIENT;
						else if (strcmp(value, "gateway") == 0)
							endpoint->role = HSPHFPD_ROLE_GATEWAY;
						else
							spa_log_warn(backend->log, NAME": Endpoint %s received invalid '%s' property value '%s', ignoring", endpoint->path, key, value);
					}
					spa_log_trace(backend->log, NAME":   %s: %s (%p)", key, value, endpoint);
				}
				break;

			case DBUS_TYPE_BOOLEAN:
				{
					bool value;
					dbus_message_iter_get_basic(&value_i, &value);
					if (strcmp(key, "Connected") == 0)
						endpoint->connected = value;
					spa_log_trace(backend->log, NAME":   %s: %d", key, value);
				}
				break;

			case DBUS_TYPE_ARRAY:
				{
					if (strcmp(key, "AudioCodecs") == 0) {
						DBusMessageIter array_i;
						const char *value;

						endpoint->air_codecs = 0;
						dbus_message_iter_recurse(&value_i, &array_i);
						while (dbus_message_iter_get_arg_type(&array_i) != DBUS_TYPE_INVALID) {
							dbus_message_iter_get_basic(&array_i, &value);
							if (strcmp(value, HSPHFP_AIR_CODEC_CVSD) == 0)
								endpoint->air_codecs |= HFP_AUDIO_CODEC_CVSD;
							if (strcmp(value, HSPHFP_AIR_CODEC_MSBC) == 0)
								endpoint->air_codecs |= HFP_AUDIO_CODEC_MSBC;
							dbus_message_iter_next(&array_i);
						}
					}
				}
				break;
		}

		dbus_message_iter_next(&element_i);
	}

	if (!endpoint->valid && endpoint->local_address && endpoint->remote_address && endpoint->profile && endpoint->role)
		endpoint->valid = true;

	if (!endpoint->remote_address || !endpoint->local_address) {
		spa_log_debug(backend->log, NAME": Missing addresses for %s", endpoint->path);
		return DBUS_HANDLER_RESULT_HANDLED;
	}

	d = spa_bt_device_find_by_address(backend->monitor, endpoint->remote_address, endpoint->local_address);
	if (!d) {
		spa_log_debug(backend->log, NAME": No device for %s", endpoint->path);
		return DBUS_HANDLER_RESULT_HANDLED;
	}

	if ((t = spa_bt_transport_find(backend->monitor, endpoint->path)) != NULL) {
		/* Release transport on disconnection, or when mSBC is supported if there
		   is an update of the remote codecs */
		if (!endpoint->connected || (backend->msbc_supported && (endpoint->air_codecs & HFP_AUDIO_CODEC_MSBC) && t->codec == HFP_AUDIO_CODEC_CVSD)) {
			spa_bt_transport_free(t);
			spa_bt_device_check_profiles(d, false);
			spa_log_debug(backend->log, NAME": Transport released for %s", endpoint->path);
		} else {
			spa_log_debug(backend->log, NAME": Transport already configured for %s", endpoint->path);
			return DBUS_HANDLER_RESULT_HANDLED;
		}
	}

	if (!endpoint->valid || !endpoint->connected)
		return DBUS_HANDLER_RESULT_HANDLED;

	char *t_path = strdup(endpoint->path);
	t = spa_bt_transport_create(backend->monitor, t_path, sizeof(struct hsphfpd_transport_data));
	if (t == NULL) {
		spa_log_warn(backend->log, NAME": can't create transport: %m");
		free(t_path);
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	}
	spa_bt_transport_set_implementation(t, &hsphfpd_transport_impl, t);

	t->device = d;
	spa_list_append(&t->device->transport_list, &t->device_link);
	t->backend = &backend->this;
	t->profile = SPA_BT_PROFILE_NULL;
	if (endpoint->profile == HSPHFPD_PROFILE_HEADSET) {
		if (endpoint->role == HSPHFPD_ROLE_CLIENT)
			t->profile = SPA_BT_PROFILE_HSP_HS;
		else if (endpoint->role == HSPHFPD_ROLE_GATEWAY)
			t->profile = SPA_BT_PROFILE_HSP_AG;
	} else if (endpoint->profile == HSPHFPD_PROFILE_HANDSFREE) {
		if (endpoint->role == HSPHFPD_ROLE_CLIENT)
			t->profile = SPA_BT_PROFILE_HFP_HF;
		else if (endpoint->role == HSPHFPD_ROLE_GATEWAY)
			t->profile = SPA_BT_PROFILE_HFP_AG;
	}
	if (backend->msbc_supported && (endpoint->air_codecs & HFP_AUDIO_CODEC_MSBC))
		t->codec = HFP_AUDIO_CODEC_MSBC;
	else
		t->codec = HFP_AUDIO_CODEC_CVSD;

	t->n_channels = 1;
	t->channels[0] = SPA_AUDIO_CHANNEL_MONO;

	spa_bt_device_connect_profile(t->device, t->profile);

	spa_log_debug(backend->log, NAME": Transport %s available for hsphfpd", endpoint->path);

	return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult hsphfpd_parse_interfaces(struct impl *backend, DBusMessageIter *dict_i)
{
	DBusMessageIter element_i;
	const char *path;

	spa_assert(backend);
	spa_assert(dict_i);

	dbus_message_iter_get_basic(dict_i, &path);
	dbus_message_iter_next(dict_i);
	dbus_message_iter_recurse(dict_i, &element_i);

	while (dbus_message_iter_get_arg_type(&element_i) == DBUS_TYPE_DICT_ENTRY) {
		DBusMessageIter iface_i;
		const char *interface;

		dbus_message_iter_recurse(&element_i, &iface_i);
		dbus_message_iter_get_basic(&iface_i, &interface);
		dbus_message_iter_next(&iface_i);

		if (strcmp(interface, HSPHFPD_ENDPOINT_INTERFACE) == 0) {
			struct hsphfpd_endpoint *endpoint;

			endpoint = endpoint_find(backend, path);
			if (!endpoint) {
				endpoint = calloc(1, sizeof(struct hsphfpd_endpoint));
				endpoint->path = strdup(path);
				spa_list_append(&backend->endpoint_list, &endpoint->link);
				spa_log_debug(backend->log, NAME": Found endpoint %s", path);
			}
			hsphfpd_parse_endpoint_properties(backend, endpoint, &iface_i);
		} else
			spa_log_debug(backend->log, NAME": Unknown interface %s found, skipping", interface);

		dbus_message_iter_next(&element_i);
	}

	return DBUS_HANDLER_RESULT_HANDLED;
}

static void hsphfpd_get_endpoints_reply(DBusPendingCall *pending, void *user_data)
{
	struct impl *backend = user_data;
	DBusMessage *r;
	DBusMessageIter i, array_i;

	r = dbus_pending_call_steal_reply(pending);
	if (r == NULL)
		return;

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": Failed to get a list of endpoints from hsphfpd: %s",
				dbus_message_get_error_name(r));
		goto finish;
	}

	if (strcmp(dbus_message_get_sender(r), backend->hsphfpd_service_id) != 0) {
		spa_log_error(backend->log, NAME": Reply for GetManagedObjects() from invalid sender");
		goto finish;
	}

	if (!dbus_message_iter_init(r, &i) || strcmp(dbus_message_get_signature(r), "a{oa{sa{sv}}}") != 0) {
		spa_log_error(backend->log, NAME": Invalid arguments in GetManagedObjects() reply");
		goto finish;
	}

	dbus_message_iter_recurse(&i, &array_i);
	while (dbus_message_iter_get_arg_type(&array_i) != DBUS_TYPE_INVALID) {
			DBusMessageIter dict_i;

			dbus_message_iter_recurse(&array_i, &dict_i);
			hsphfpd_parse_interfaces(backend, &dict_i);
			dbus_message_iter_next(&array_i);
	}

	backend->endpoints_listed = true;

finish:
	dbus_message_unref(r);
	dbus_pending_call_unref(pending);
}

static int backend_hsphfpd_register(void *data)
{
	struct impl *backend = data;
	DBusMessage *m, *r;
	const char *path = APPLICATION_OBJECT_MANAGER_PATH;
	DBusPendingCall *call;
	DBusError err;
	int res;

	spa_log_debug(backend->log, NAME": Registering to hsphfpd");

	m = dbus_message_new_method_call(HSPHFPD_SERVICE, "/",
			HSPHFPD_APPLICATION_MANAGER_INTERFACE, "RegisterApplication");
	if (m == NULL)
		return -ENOMEM;

	dbus_message_append_args(m, DBUS_TYPE_OBJECT_PATH, &path, DBUS_TYPE_INVALID);

	dbus_error_init(&err);

	r = dbus_connection_send_with_reply_and_block(backend->conn, m, -1, &err);
	dbus_message_unref(m);

	if (r == NULL) {
		if (dbus_error_has_name(&err, "org.freedesktop.DBus.Error.ServiceUnknown")) {
			spa_log_info(backend->log, NAME": hsphfpd not available: %s",
					err.message);
			res = -ENOTSUP;
		} else {
			spa_log_warn(backend->log, NAME": Registering application %s failed: %s (%s)",
					path, err.message, err.name);
			res = -EIO;
		}
		dbus_error_free(&err);
		return res;
	}

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": RegisterApplication() failed: %s",
				dbus_message_get_error_name(r));
		goto finish;
	}
	dbus_message_unref(r);

	backend->hsphfpd_service_id = strdup(dbus_message_get_sender(r));

	spa_log_debug(backend->log, NAME": Registered to hsphfpd");

	m = dbus_message_new_method_call(HSPHFPD_SERVICE, "/",
			DBUS_INTERFACE_OBJECTMANAGER, "GetManagedObjects");
	if (m == NULL)
		goto finish;

	dbus_connection_send_with_reply(backend->conn, m, &call, -1);
	dbus_pending_call_set_notify(call, hsphfpd_get_endpoints_reply, backend, NULL);
	dbus_message_unref(m);

	return 0;

finish:
	dbus_message_unref(r);
	return -EIO;
}

static int backend_hsphfpd_unregistered(void *data)
{
	struct impl *backend = data;
	struct hsphfpd_endpoint *endpoint;

	if (backend->hsphfpd_service_id) {
		free(backend->hsphfpd_service_id);
		backend->hsphfpd_service_id = NULL;
	}
	backend->endpoints_listed = false;
	spa_list_consume(endpoint, &backend->endpoint_list, link)
		endpoint_free(endpoint);

	return 0;
}

static DBusHandlerResult hsphfpd_filter_cb(DBusConnection *bus, DBusMessage *m, void *user_data)
{
	const char *sender;
	struct impl *backend = user_data;
	DBusError err;

	dbus_error_init(&err);

	sender = dbus_message_get_sender(m);

	if (backend->hsphfpd_service_id && strcmp(sender, backend->hsphfpd_service_id) == 0) {
		if (dbus_message_is_signal(m, DBUS_INTERFACE_OBJECTMANAGER, "InterfacesAdded")) {
			DBusMessageIter arg_i;

			spa_log_warn(backend->log, NAME": sender: %s", dbus_message_get_sender(m));

			if (!backend->endpoints_listed)
				goto finish;

			if (!dbus_message_iter_init(m, &arg_i) || strcmp(dbus_message_get_signature(m), "oa{sa{sv}}") != 0) {
					spa_log_error(backend->log, NAME": Invalid signature found in InterfacesAdded");
					goto finish;
			}

			hsphfpd_parse_interfaces(backend, &arg_i);
		} else if (dbus_message_is_signal(m, DBUS_INTERFACE_OBJECTMANAGER, "InterfacesRemoved")) {
			const char *path;
			DBusMessageIter arg_i, element_i;

			if (!backend->endpoints_listed)
				goto finish;

			if (!dbus_message_iter_init(m, &arg_i) || strcmp(dbus_message_get_signature(m), "oas") != 0) {
					spa_log_error(backend->log, NAME": Invalid signature found in InterfacesRemoved");
					goto finish;
			}

			dbus_message_iter_get_basic(&arg_i, &path);
			dbus_message_iter_next(&arg_i);
			dbus_message_iter_recurse(&arg_i, &element_i);

			while (dbus_message_iter_get_arg_type(&element_i) == DBUS_TYPE_STRING) {
					const char *iface;

					dbus_message_iter_get_basic(&element_i, &iface);

					if (strcmp(iface, HSPHFPD_ENDPOINT_INTERFACE) == 0) {
							struct hsphfpd_endpoint *endpoint;
							struct spa_bt_transport *transport = spa_bt_transport_find(backend->monitor, path);

							if (transport)
								spa_bt_transport_free(transport);

							spa_log_debug(backend->log, NAME": Remove endpoint %s", path);
							endpoint = endpoint_find(backend, path);
							if (endpoint)
								endpoint_free(endpoint);
					}

					dbus_message_iter_next(&element_i);
			}
		} else if (dbus_message_is_signal(m, DBUS_INTERFACE_PROPERTIES, "PropertiesChanged")) {
			DBusMessageIter arg_i;
			const char *iface;
			const char *path;

			if (!backend->endpoints_listed)
				goto finish;

			if (!dbus_message_iter_init(m, &arg_i) || strcmp(dbus_message_get_signature(m), "sa{sv}as") != 0) {
					spa_log_error(backend->log, NAME": Invalid signature found in PropertiesChanged");
					goto finish;
			}

			dbus_message_iter_get_basic(&arg_i, &iface);
			dbus_message_iter_next(&arg_i);

			path = dbus_message_get_path(m);

			if (strcmp(iface, HSPHFPD_ENDPOINT_INTERFACE) == 0) {
				struct hsphfpd_endpoint *endpoint = endpoint_find(backend, path);
				if (!endpoint) {
					spa_log_warn(backend->log, NAME": Properties changed on unknown endpoint %s", path);
					goto finish;
				}
				spa_log_debug(backend->log, NAME": Properties changed on endpoint %s", path);
				hsphfpd_parse_endpoint_properties(backend, endpoint, &arg_i);
			} else if (strcmp(iface, HSPHFPD_AUDIO_TRANSPORT_INTERFACE) == 0) {
				struct spa_bt_transport *transport = spa_bt_transport_find_full(backend->monitor,
				                                                                hsphfpd_cmp_transport_path,
				                                                                (const void *)path);
				if (!transport) {
					spa_log_warn(backend->log, NAME": Properties changed on unknown transport %s", path);
					goto finish;
				}
				spa_log_debug(backend->log, NAME": Properties changed on transport %s", path);
				hsphfpd_parse_transport_properties(backend, transport, &arg_i);
			}
		}
	}

finish:
	return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

static int backend_hsphfpd_add_filters(void *data)
{
	struct impl *backend = data;
	DBusError err;

	if (backend->filters_added)
		return 0;

	dbus_error_init(&err);

	if (!dbus_connection_add_filter(backend->conn, hsphfpd_filter_cb, backend, NULL)) {
		spa_log_error(backend->log, NAME": failed to add filter function");
		goto fail;
	}

	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" HSPHFPD_SERVICE "',"
			"interface='" DBUS_INTERFACE_OBJECTMANAGER "',member='InterfacesAdded'", &err);
	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" HSPHFPD_SERVICE "',"
			"interface='" DBUS_INTERFACE_OBJECTMANAGER "',member='InterfacesRemoved'", &err);
	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" HSPHFPD_SERVICE "',"
			"interface='" DBUS_INTERFACE_PROPERTIES "',member='PropertiesChanged',"
			"arg0='" HSPHFPD_ENDPOINT_INTERFACE "'", &err);
	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" HSPHFPD_SERVICE "',"
			"interface='" DBUS_INTERFACE_PROPERTIES "',member='PropertiesChanged',"
			"arg0='" HSPHFPD_AUDIO_TRANSPORT_INTERFACE "'", &err);

	backend->filters_added = true;

	return 0;

fail:
	dbus_error_free(&err);
	return -EIO;
}

static int backend_hsphfpd_free(void *data)
{
	struct impl *backend = data;
	struct hsphfpd_endpoint *endpoint;

	if (backend->filters_added) {
		dbus_connection_remove_filter(backend->conn, hsphfpd_filter_cb, backend);
		backend->filters_added = false;
	}

	if (backend->msbc_supported)
		dbus_connection_unregister_object_path(backend->conn, HSPHFP_AUDIO_CLIENT_MSBC);
	dbus_connection_unregister_object_path(backend->conn, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ);
	dbus_connection_unregister_object_path(backend->conn, APPLICATION_OBJECT_MANAGER_PATH);

	spa_list_consume(endpoint, &backend->endpoint_list, link)
		endpoint_free(endpoint);

	free(backend);

	return 0;
}

static const struct spa_bt_backend_implementation backend_impl = {
	SPA_VERSION_BT_BACKEND_IMPLEMENTATION,
	.free = backend_hsphfpd_free,
	.register_profiles = backend_hsphfpd_register,
	.unregistered = backend_hsphfpd_unregistered,
	.add_filters = backend_hsphfpd_add_filters,
};

struct spa_bt_backend *backend_hsphfpd_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *backend;
	const char *str;
	static const DBusObjectPathVTable vtable_application_object_manager = {
		.message_function = application_object_manager_handler,
	};
	static const DBusObjectPathVTable vtable_audio_agent_endpoint = {
		.message_function = audio_agent_endpoint_handler,
	};

	backend = calloc(1, sizeof(struct impl));
	if (backend == NULL)
		return NULL;

	spa_bt_backend_set_implementation(&backend->this, &backend_impl, backend);

	backend->monitor = monitor;
	backend->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);
	backend->dbus = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_DBus);
	backend->main_loop = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Loop);
	backend->conn = dbus_connection;
	if (info && (str = spa_dict_lookup(info, "bluez5.msbc-support")))
		backend->msbc_supported = strcmp(str, "true") == 0 || atoi(str) == 1;
	else
		backend->msbc_supported = false;

	spa_list_init(&backend->endpoint_list);

	if (!dbus_connection_register_object_path(backend->conn,
	            APPLICATION_OBJECT_MANAGER_PATH,
	            &vtable_application_object_manager, backend)) {
		free(backend);
		return NULL;
	}

	if (!dbus_connection_register_object_path(backend->conn,
	            HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ,
	            &vtable_audio_agent_endpoint, backend)) {
		dbus_connection_unregister_object_path(backend->conn, APPLICATION_OBJECT_MANAGER_PATH);
		free(backend);
		return NULL;
	}

	if (backend->msbc_supported && !dbus_connection_register_object_path(backend->conn,
	            HSPHFP_AUDIO_CLIENT_MSBC,
	            &vtable_audio_agent_endpoint, backend)) {
		dbus_connection_unregister_object_path(backend->conn, HSPHFP_AUDIO_CLIENT_PCM_S16LE_8KHZ);
		dbus_connection_unregister_object_path(backend->conn, APPLICATION_OBJECT_MANAGER_PATH);
		free(backend);
		return NULL;
	}

	return &backend->this;
}
