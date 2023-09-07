/* Spa oFono backend
 *
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
#include <poll.h>
#include <sys/socket.h>

#include <bluetooth/bluetooth.h>
#include <bluetooth/sco.h>

#include <dbus/dbus.h>

#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/support/dbus.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/param/audio/raw.h>

#include "defs.h"

#define NAME "oFono"

struct impl {
	struct spa_bt_backend this;

	struct spa_bt_monitor *monitor;

	struct spa_log *log;
	struct spa_loop *main_loop;
	struct spa_dbus *dbus;
	DBusConnection *conn;

	unsigned int filters_added:1;
	unsigned int msbc_supported:1;
};

struct transport_data {
	struct spa_source sco;
};

#define OFONO_HF_AUDIO_MANAGER_INTERFACE OFONO_SERVICE ".HandsfreeAudioManager"
#define OFONO_HF_AUDIO_CARD_INTERFACE OFONO_SERVICE ".HandsfreeAudioCard"
#define OFONO_HF_AUDIO_AGENT_INTERFACE OFONO_SERVICE ".HandsfreeAudioAgent"

#define OFONO_AUDIO_CLIENT	"/Profile/ofono"

#define OFONO_INTROSPECT_XML						    \
	DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE                           \
	"<node>"                                                            \
	" <interface name=\"" OFONO_HF_AUDIO_AGENT_INTERFACE "\">"                 \
	"  <method name=\"Release\">"                                       \
	"  </method>"                                                       \
	"  <method name=\"NewConnection\">"                                 \
	"   <arg name=\"card\" direction=\"in\" type=\"o\"/>"             \
	"   <arg name=\"fd\" direction=\"in\" type=\"h\"/>"                 \
	"   <arg name=\"codec\" direction=\"in\" type=\"b\"/>"           \
	"  </method>"                                                       \
	" </interface>"                                                     \
	" <interface name=\"org.freedesktop.DBus.Introspectable\">"         \
	"  <method name=\"Introspect\">"                                    \
	"   <arg name=\"data\" type=\"s\" direction=\"out\"/>"              \
	"  </method>"                                                       \
	" </interface>"                                                     \
	"</node>"

#define OFONO_ERROR_INVALID_ARGUMENTS "org.ofono.Error.InvalidArguments"
#define OFONO_ERROR_NOT_IMPLEMENTED "org.ofono.Error.NotImplemented"
#define OFONO_ERROR_IN_USE "org.ofono.Error.InUse"
#define OFONO_ERROR_FAILED "org.ofono.Error.Failed"

static void ofono_transport_get_mtu(struct impl *backend, struct spa_bt_transport *t)
{
	struct sco_options sco_opt;
	socklen_t len;

	/* Fallback values */
	t->read_mtu = 48;
	t->write_mtu = 48;

	len = sizeof(sco_opt);
	memset(&sco_opt, 0, len);

	if (getsockopt(t->fd, SOL_SCO, SCO_OPTIONS, &sco_opt, &len) < 0)
		spa_log_warn(backend->log, NAME": getsockopt(SCO_OPTIONS) failed, loading defaults");
	else {
		spa_log_debug(backend->log, NAME" : autodetected mtu = %u", sco_opt.mtu);
		t->read_mtu = sco_opt.mtu;
		t->write_mtu = sco_opt.mtu;
	}
}

static struct spa_bt_transport *_transport_create(struct impl *backend,
                                                  const char *path,
                                                  struct spa_bt_device *device,
                                                  enum spa_bt_profile profile,
                                                  int codec,
                                                  struct spa_callbacks *impl)
{
	struct spa_bt_transport *t = NULL;
	char *t_path = strdup(path);

	t = spa_bt_transport_create(backend->monitor, t_path, sizeof(struct transport_data));
	if (t == NULL) {
		spa_log_warn(backend->log, NAME": can't create transport: %m");
		free(t_path);
		goto finish;
	}
	spa_bt_transport_set_implementation(t, impl, t);

	t->device = device;
	spa_list_append(&t->device->transport_list, &t->device_link);
	t->backend = &backend->this;
	t->profile = profile;
	t->codec = codec;
	t->n_channels = 1;
	t->channels[0] = SPA_AUDIO_CHANNEL_MONO;

finish:
	return t;
}

static int _audio_acquire(struct impl *backend, const char *path, uint8_t *codec)
{
	DBusMessage *m, *r;
	DBusError err;
	int ret = 0;

	m = dbus_message_new_method_call(OFONO_SERVICE, path,
	                                 OFONO_HF_AUDIO_CARD_INTERFACE,
	                                 "Acquire");
	if (m == NULL)
		return -ENOMEM;

	dbus_error_init(&err);

	r = dbus_connection_send_with_reply_and_block(backend->conn, m, -1, &err);
	dbus_message_unref(m);
	m = NULL;

	if (r == NULL) {
		spa_log_error(backend->log, NAME": Transport Acquire() failed for transport %s (%s)",
		              path, err.message);
		dbus_error_free(&err);
		return -EIO;
	}

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": Acquire returned error: %s", dbus_message_get_error_name(r));
		ret = -EIO;
		goto finish;
	}

	if (!dbus_message_get_args(r, &err,
	                           DBUS_TYPE_UNIX_FD, &ret,
	                           DBUS_TYPE_BYTE, codec,
	                           DBUS_TYPE_INVALID)) {
		spa_log_error(backend->log, NAME": Failed to parse Acquire() reply: %s", err.message);
		dbus_error_free(&err);
		ret = -EIO;
		goto finish;
	}

finish:
	dbus_message_unref(r);
	return ret;
}

static int ofono_audio_acquire(void *data, bool optional)
{
	struct spa_bt_transport *transport = data;
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);
	uint8_t codec;
	int ret = 0;

	if (transport->fd >= 0)
		goto finish;

	ret = _audio_acquire(backend, transport->path, &codec);
	if (ret < 0)
		goto finish;

	transport->fd = ret;

	if (transport->codec != codec) {
		struct spa_bt_transport *t = NULL;

		spa_log_warn(backend->log, NAME": Acquired codec (%d) differs from transport one (%d)",
		             codec, transport->codec);

		/* shutdown to make sure connection is dropped immediately */
		shutdown(transport->fd, SHUT_RDWR);
		close(transport->fd);
		transport->fd = -1;

		/* Create a new transport which differs only for codec */
		t = _transport_create(backend, transport->path, transport->device,
		                      transport->profile, codec, &transport->impl);

		spa_bt_transport_free(transport);
		spa_bt_device_connect_profile(t->device, t->profile);

		ret = -EIO;
		goto finish;
	}

	spa_log_debug(backend->log, NAME": transport %p: Acquire %s, fd %d codec %d", transport,
			transport->path, transport->fd, transport->codec);

	ofono_transport_get_mtu(backend, transport);
	ret = 0;

finish:
	return ret;
}

static int ofono_audio_release(void *data)
{
	struct spa_bt_transport *transport = data;
	struct impl *backend = SPA_CONTAINER_OF(transport->backend, struct impl, this);

	spa_log_debug(backend->log, NAME": transport %p: Release %s",
			transport, transport->path);

	if (transport->sco_io) {
		spa_bt_sco_io_destroy(transport->sco_io);
		transport->sco_io = NULL;
	}

	/* shutdown to make sure connection is dropped immediately */
	shutdown(transport->fd, SHUT_RDWR);
	close(transport->fd);
	transport->fd = -1;

	return 0;
}

static DBusHandlerResult ofono_audio_card_removed(struct impl *backend, const char *path)
{
	struct spa_bt_transport *transport;

	spa_assert(backend);
	spa_assert(path);

	spa_log_debug(backend->log, NAME": card removed: %s", path);

	transport = spa_bt_transport_find(backend->monitor, path);

	if (transport != NULL) {
		struct spa_bt_device *device = transport->device;

		spa_log_debug(backend->log, NAME" :transport %p: free %s",
			transport, transport->path);

		spa_bt_transport_free(transport);
		if (device != NULL)
			spa_bt_device_check_profiles(device, false);
	}

	return DBUS_HANDLER_RESULT_HANDLED;
}

static const struct spa_bt_transport_implementation ofono_transport_impl = {
	SPA_VERSION_BT_TRANSPORT_IMPLEMENTATION,
	.acquire = ofono_audio_acquire,
	.release = ofono_audio_release,
};

static DBusHandlerResult ofono_audio_card_found(struct impl *backend, char *path, DBusMessageIter *props_i)
{
	const char *remote_address = NULL;
	const char *local_address = NULL;
	struct spa_bt_device *d;
	struct spa_bt_transport *t;
	enum spa_bt_profile profile = SPA_BT_PROFILE_HFP_AG;
	uint8_t codec = HFP_AUDIO_CODEC_CVSD;

	spa_assert(backend);
	spa_assert(path);
	spa_assert(props_i);

	spa_log_debug(backend->log, NAME": new card: %s", path);

	while (dbus_message_iter_get_arg_type(props_i) != DBUS_TYPE_INVALID) {
		DBusMessageIter i, value_i;
		const char *key, *value;
		char c;

		dbus_message_iter_recurse(props_i, &i);

		dbus_message_iter_get_basic(&i, &key);
		dbus_message_iter_next(&i);
		dbus_message_iter_recurse(&i, &value_i);

		if ((c = dbus_message_iter_get_arg_type(&value_i)) != DBUS_TYPE_STRING) {
			spa_log_error(backend->log, NAME": Invalid properties for %s: expected 's', received '%c'", path, c);
			return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
		}

		dbus_message_iter_get_basic(&value_i, &value);

		if (strcmp(key, "RemoteAddress") == 0) {
			remote_address = value;
		} else if (strcmp(key, "LocalAddress") == 0) {
			local_address = value;
		} else if (strcmp(key, "Type") == 0) {
			if (strcmp(value, "gateway") == 0)
				profile = SPA_BT_PROFILE_HFP_HF;
		}

		spa_log_debug(backend->log, NAME": %s: %s", key, value);

		dbus_message_iter_next(props_i);
	}

	/*
	 * Acquire and close immediately to figure out the codec.
	 * This is necessary if we are in HF mode, because we need to emit
	 * nodes and the advertised sample rate of the node depends on the codec.
	 * For AG mode, we delay the emission of the nodes, so it is not necessary
	 * to know the codec in advance
	 */
	if (profile == SPA_BT_PROFILE_HFP_HF) {
		int fd = _audio_acquire(backend, path, &codec);
		if (fd < 0) {
			spa_log_error(backend->log, NAME": Failed to retrieve codec for %s", path);
			return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
		}
		/* shutdown to make sure connection is dropped immediately */
		shutdown(fd, SHUT_RDWR);
		close(fd);
	}

	if (!remote_address || !local_address) {
		spa_log_error(backend->log, NAME": Missing addresses for %s", path);
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
	}

	d = spa_bt_device_find_by_address(backend->monitor, remote_address, local_address);
	if (!d) {
		spa_log_error(backend->log, NAME": Device doesn’t exist for %s", path);
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
	}

	t = _transport_create(backend, path, d, profile, codec, (struct spa_callbacks *)&ofono_transport_impl);

	spa_bt_device_connect_profile(t->device, profile);

	spa_log_debug(backend->log, NAME": Transport %s available, codec %d", t->path, t->codec);

	return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult ofono_release(DBusConnection *conn, DBusMessage *m, void *userdata)
{
	struct impl *backend = userdata;
	DBusMessage *r;

	spa_log_warn(backend->log, NAME": release");

	r = dbus_message_new_error(m, OFONO_HF_AUDIO_AGENT_INTERFACE ".Error.NotImplemented",
                                            "Method not implemented");
	if (r == NULL)
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	if (!dbus_connection_send(conn, r, NULL))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;

	dbus_message_unref(r);
	return DBUS_HANDLER_RESULT_HANDLED;
}

static void sco_event(struct spa_source *source)
{
	struct spa_bt_transport *t = source->data;
	struct impl *backend = SPA_CONTAINER_OF(t->backend, struct impl, this);

	if (source->rmask & (SPA_IO_HUP | SPA_IO_ERR)) {
		spa_log_debug(backend->log, NAME": transport %p: error on SCO socket: %s", t, strerror(errno));
		if (t->fd >= 0) {
			if (source->loop)
				spa_loop_remove_source(source->loop, source);
			shutdown(t->fd, SHUT_RDWR);
			close (t->fd);
			t->fd = -1;
			spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_IDLE);
		}
	}
}

static int enable_sco_socket(int sock)
{
	char c;
	struct pollfd pfd;

	if (sock < 0)
		return ENOTCONN;

	memset(&pfd, 0, sizeof(pfd));
	pfd.fd = sock;
	pfd.events = POLLOUT;

	if (poll(&pfd, 1, 0) < 0)
		return errno;

	/*
	 * If socket already writable then it is not in defer setup state,
	 * otherwise it needs to be read to authorize the connection.
	 */
	if ((pfd.revents & POLLOUT))
		return 0;

	/* Enable socket by reading 1 byte */
	if (read(sock, &c, 1) < 0)
		return errno;

	return 0;
}

static DBusHandlerResult ofono_new_audio_connection(DBusConnection *conn, DBusMessage *m, void *userdata)
{
	struct impl *backend = userdata;
	const char *path;
	int fd;
	uint8_t codec;
	struct spa_bt_transport *t;
	struct transport_data *td;
	DBusMessage *r = NULL;

	if (dbus_message_get_args(m, NULL,
	                          DBUS_TYPE_OBJECT_PATH, &path,
	                          DBUS_TYPE_UNIX_FD, &fd,
	                          DBUS_TYPE_BYTE, &codec,
	                          DBUS_TYPE_INVALID) == FALSE) {
		r = dbus_message_new_error(m, OFONO_ERROR_INVALID_ARGUMENTS, "Invalid arguments in method call");
		goto fail;
	}

	t = spa_bt_transport_find(backend->monitor, path);
	if (t && (t->profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY)) {
		int err;

		err = enable_sco_socket(fd);
		if (err) {
			spa_log_error(backend->log, NAME": transport %p: Couldn't authorize SCO connection: %s", t, strerror(err));
			r = dbus_message_new_error(m, OFONO_ERROR_FAILED, "SCO authorization failed");
			shutdown(fd, SHUT_RDWR);
			close(fd);
			goto fail;
		}

		t->fd = fd;
		t->codec = codec;

		spa_log_debug(backend->log, NAME": transport %p: NewConnection %s, fd %d codec %d",
						t, t->path, t->fd, t->codec);

		td = t->user_data;
		td->sco.func = sco_event;
		td->sco.data = t;
		td->sco.fd = fd;
		td->sco.mask = SPA_IO_HUP | SPA_IO_ERR;
		td->sco.rmask = 0;
		spa_loop_add_source(backend->main_loop, &td->sco);

		ofono_transport_get_mtu(backend, t);
		spa_bt_transport_set_state (t, SPA_BT_TRANSPORT_STATE_PENDING);
	}
	else if (fd) {
		spa_log_debug(backend->log, NAME": ignoring NewConnection");
		r = dbus_message_new_error(m, OFONO_ERROR_NOT_IMPLEMENTED, "Method not implemented");
		shutdown(fd, SHUT_RDWR);
		close(fd);
	}

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

static DBusHandlerResult ofono_handler(DBusConnection *c, DBusMessage *m, void *userdata)
{
	struct impl *backend = userdata;
	const char *path, *interface, *member;
	DBusMessage *r;
	DBusHandlerResult res;

	path = dbus_message_get_path(m);
	interface = dbus_message_get_interface(m);
	member = dbus_message_get_member(m);

	spa_log_debug(backend->log, NAME": path=%s, interface=%s, member=%s", path, interface, member);

	if (dbus_message_is_method_call(m, "org.freedesktop.DBus.Introspectable", "Introspect")) {
		const char *xml = OFONO_INTROSPECT_XML;

		if ((r = dbus_message_new_method_return(m)) == NULL)
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
		if (!dbus_message_append_args(r, DBUS_TYPE_STRING, &xml, DBUS_TYPE_INVALID))
			return DBUS_HANDLER_RESULT_NEED_MEMORY;
		if (!dbus_connection_send(backend->conn, r, NULL))
			return DBUS_HANDLER_RESULT_NEED_MEMORY;

		dbus_message_unref(r);
		res = DBUS_HANDLER_RESULT_HANDLED;
	}
	else if (dbus_message_is_method_call(m, OFONO_HF_AUDIO_AGENT_INTERFACE, "Release"))
		res = ofono_release(c, m, userdata);
	else if (dbus_message_is_method_call(m, OFONO_HF_AUDIO_AGENT_INTERFACE, "NewConnection"))
		res = ofono_new_audio_connection(c, m, userdata);
	else
		res = DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	return res;
}

static void ofono_getcards_reply(DBusPendingCall *pending, void *user_data)
{
	struct impl *backend = user_data;
	DBusMessage *r;
	DBusMessageIter i, array_i, struct_i, props_i;

	r = dbus_pending_call_steal_reply(pending);
	if (r == NULL)
		return;

	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": Failed to get a list of handsfree audio cards: %s",
				dbus_message_get_error_name(r));
		goto finish;
	}

	if (!dbus_message_iter_init(r, &i) || strcmp(dbus_message_get_signature(r), "a(oa{sv})") != 0) {
		spa_log_error(backend->log, NAME": Invalid arguments in GetCards() reply");
		goto finish;
	}

	dbus_message_iter_recurse(&i, &array_i);
	while (dbus_message_iter_get_arg_type(&array_i) != DBUS_TYPE_INVALID) {
			char *path;

			dbus_message_iter_recurse(&array_i, &struct_i);
			dbus_message_iter_get_basic(&struct_i, &path);
			dbus_message_iter_next(&struct_i);

			dbus_message_iter_recurse(&struct_i, &props_i);

			ofono_audio_card_found(backend, path, &props_i);

			dbus_message_iter_next(&array_i);
	}

finish:
	dbus_message_unref(r);
	dbus_pending_call_unref(pending);
}

static int backend_ofono_register(void *data)
{
	struct impl *backend = data;

	DBusMessage *m, *r;
	const char *path = OFONO_AUDIO_CLIENT;
	uint8_t codecs[2];
	const uint8_t *pcodecs = codecs;
	int ncodecs = 0, res;
	DBusPendingCall *call;
	DBusError err;

	spa_log_debug(backend->log, NAME": Registering");

	m = dbus_message_new_method_call(OFONO_SERVICE, "/",
			OFONO_HF_AUDIO_MANAGER_INTERFACE, "Register");
	if (m == NULL)
		return -ENOMEM;

	codecs[ncodecs++] = HFP_AUDIO_CODEC_CVSD;
	if (backend->msbc_supported)
		codecs[ncodecs++] = HFP_AUDIO_CODEC_MSBC;

	dbus_message_append_args(m, DBUS_TYPE_OBJECT_PATH, &path,
                                          DBUS_TYPE_ARRAY, DBUS_TYPE_BYTE, &pcodecs, ncodecs,
                                          DBUS_TYPE_INVALID);

	dbus_error_init(&err);

	r = dbus_connection_send_with_reply_and_block(backend->conn, m, -1, &err);
	dbus_message_unref(m);

	if (r == NULL) {
		if (dbus_error_has_name(&err, "org.freedesktop.DBus.Error.ServiceUnknown")) {
			spa_log_info(backend->log, NAME": oFono not available: %s",
					err.message);
			res = -ENOTSUP;
		} else {
			spa_log_warn(backend->log, NAME": Registering Profile %s failed: %s (%s)",
					path, err.message, err.name);
			res = -EIO;
		}
		dbus_error_free(&err);
		return res;
	}

	if (dbus_message_is_error(r, OFONO_ERROR_INVALID_ARGUMENTS)) {
		spa_log_warn(backend->log, NAME": invalid arguments");
		goto finish;
	}
	if (dbus_message_is_error(r, OFONO_ERROR_IN_USE)) {
		spa_log_warn(backend->log, NAME": already in use");
		goto finish;
	}
	if (dbus_message_is_error(r, DBUS_ERROR_UNKNOWN_METHOD)) {
		spa_log_warn(backend->log, NAME": Error registering profile");
		goto finish;
	}
	if (dbus_message_is_error(r, DBUS_ERROR_SERVICE_UNKNOWN)) {
		spa_log_info(backend->log, NAME": oFono not available, disabling");
		goto finish;
	}
	if (dbus_message_get_type(r) == DBUS_MESSAGE_TYPE_ERROR) {
		spa_log_error(backend->log, NAME": Register() failed: %s",
				dbus_message_get_error_name(r));
		goto finish;
	}
	dbus_message_unref(r);

	spa_log_debug(backend->log, NAME": registered");

	m = dbus_message_new_method_call(OFONO_SERVICE, "/",
			OFONO_HF_AUDIO_MANAGER_INTERFACE, "GetCards");
	if (m == NULL)
		goto finish;

	dbus_connection_send_with_reply(backend->conn, m, &call, -1);
	dbus_pending_call_set_notify(call, ofono_getcards_reply, backend, NULL);
	dbus_message_unref(m);

	return 0;

finish:
	dbus_message_unref(r);
	return -EIO;
}

static DBusHandlerResult ofono_filter_cb(DBusConnection *bus, DBusMessage *m, void *user_data)
{
	struct impl *backend = user_data;
	DBusError err;

	dbus_error_init(&err);

	if (dbus_message_is_signal(m, OFONO_HF_AUDIO_MANAGER_INTERFACE, "CardAdded")) {
			char *p;
			DBusMessageIter arg_i, props_i;

			if (!dbus_message_iter_init(m, &arg_i) || strcmp(dbus_message_get_signature(m), "oa{sv}") != 0) {
					spa_log_error(backend->log, NAME": Failed to parse org.ofono.HandsfreeAudioManager.CardAdded");
					goto fail;
			}

			dbus_message_iter_get_basic(&arg_i, &p);

			dbus_message_iter_next(&arg_i);
			spa_assert(dbus_message_iter_get_arg_type(&arg_i) == DBUS_TYPE_ARRAY);

			dbus_message_iter_recurse(&arg_i, &props_i);

			return ofono_audio_card_found(backend, p, &props_i);
	} else if (dbus_message_is_signal(m, OFONO_HF_AUDIO_MANAGER_INTERFACE, "CardRemoved")) {
			const char *p;

			if (!dbus_message_get_args(m, &err, DBUS_TYPE_OBJECT_PATH, &p, DBUS_TYPE_INVALID)) {
					spa_log_error(backend->log, NAME": Failed to parse org.ofono.HandsfreeAudioManager.CardRemoved: %s", err.message);
					goto fail;
			}

			return ofono_audio_card_removed(backend, p);
	}

fail:
	return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

static int backend_ofono_add_filters(void *data)
{
	struct impl *backend = data;

	DBusError err;

	if (backend->filters_added)
		return 0;

	dbus_error_init(&err);

	if (!dbus_connection_add_filter(backend->conn, ofono_filter_cb, backend, NULL)) {
		spa_log_error(backend->log, NAME": failed to add filter function");
		goto fail;
	}

	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" OFONO_SERVICE "',"
			"interface='" OFONO_HF_AUDIO_MANAGER_INTERFACE "',member='CardAdded'", &err);
	dbus_bus_add_match(backend->conn,
			"type='signal',sender='" OFONO_SERVICE "',"
			"interface='" OFONO_HF_AUDIO_MANAGER_INTERFACE "',member='CardRemoved'", &err);

	backend->filters_added = true;

	return 0;

fail:
	dbus_error_free(&err);
	return -EIO;
}

static int backend_ofono_free(void *data)
{
	struct impl *backend = data;

	if (backend->filters_added) {
		dbus_connection_remove_filter(backend->conn, ofono_filter_cb, backend);
		backend->filters_added = false;
	}

	dbus_connection_unregister_object_path(backend->conn, OFONO_AUDIO_CLIENT);

	free(backend);

	return 0;
}

static const struct spa_bt_backend_implementation backend_impl = {
	SPA_VERSION_BT_BACKEND_IMPLEMENTATION,
	.free = backend_ofono_free,
	.register_profiles = backend_ofono_register,
	.add_filters = backend_ofono_add_filters,
};

struct spa_bt_backend *backend_ofono_new(struct spa_bt_monitor *monitor,
		void *dbus_connection,
		const struct spa_dict *info,
		const struct spa_support *support,
		uint32_t n_support)
{
	struct impl *backend;
	const char *str;
	static const DBusObjectPathVTable vtable_profile = {
		.message_function = ofono_handler,
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

	if (!dbus_connection_register_object_path(backend->conn,
						  OFONO_AUDIO_CLIENT,
						  &vtable_profile, backend)) {
		free(backend);
		return NULL;
	}

	return &backend->this;
}
