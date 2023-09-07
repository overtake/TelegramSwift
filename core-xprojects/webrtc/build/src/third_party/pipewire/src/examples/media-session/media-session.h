/* PipeWire
 *
 * Copyright © 2019 Wim Taymans
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


#ifndef SM_MEDIA_SESSION_H
#define SM_MEDIA_SESSION_H

#include <spa/monitor/device.h>
#include <pipewire/impl.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SM_TYPE_MEDIA_SESSION	PW_TYPE_INFO_OBJECT_BASE "SessionManager"

#define SM_MAX_PARAMS 32

struct sm_media_session;

struct sm_object_events {
#define SM_VERSION_OBJECT_EVENTS	0
	uint32_t version;

	void (*update) (void *data);
	void (*destroy) (void *data);
	void (*free) (void *data);
};

struct sm_object_methods {
#define SM_VERSION_OBJECT_METHODS	0
	uint32_t version;

	int (*acquire) (void *data);
	int (*release) (void *data);
};

struct sm_object {
	uint32_t id;
	const char *type;

	struct spa_list link;
	struct sm_media_session *session;

#define SM_OBJECT_CHANGE_MASK_LISTENER		(1<<1)
#define SM_OBJECT_CHANGE_MASK_PROPERTIES	(1<<2)
#define SM_OBJECT_CHANGE_MASK_BIND		(1<<3)
#define SM_OBJECT_CHANGE_MASK_LAST		(1<<8)
	uint32_t mask;			/**< monitored info */
	uint32_t avail;			/**< available info */
	uint32_t changed;		/**< changed since last update */
	struct pw_properties *props;	/**< global properties */

	struct pw_proxy *proxy;
	struct spa_hook proxy_listener;
	struct spa_hook object_listener;
	pw_destroy_t destroy;
	int pending;

	struct pw_proxy *handle;
	struct spa_hook handle_listener;
	struct spa_hook_list hooks;

	struct spa_callbacks methods;

	struct spa_list data;

	unsigned int monitor_global:1;	/**< whether handle is from monitor core */
	unsigned int destroyed:1;	/**< whether proxies have been destroyed */
	unsigned int discarded:1;	/**< whether monitors hold no references */
};

int sm_object_add_listener(struct sm_object *obj, struct spa_hook *listener,
		const struct sm_object_events *events, void *data);

#define sm_object_call(o,...)		spa_callbacks_call(&(o)->methods, struct sm_object_methods, __VA_ARGS__)
#define sm_object_call_res(o,...)	spa_callbacks_call_res(&(o)->methods, struct sm_object_methods, 0, __VA_ARGS__)

#define sm_object_acquire(o)		sm_object_call(o, acquire, 0)
#define sm_object_release(o)		sm_object_call(o, release, 0)

struct sm_param {
	uint32_t id;
	struct spa_list link;		/**< link in param_list */
	struct spa_pod *param;
};

/** get user data with \a id and \a size to an object */
void *sm_object_add_data(struct sm_object *obj, const char *id, size_t size);
void *sm_object_get_data(struct sm_object *obj, const char *id);
int sm_object_remove_data(struct sm_object *obj, const char *id);

int sm_object_sync_update(struct sm_object *obj);

int sm_object_destroy(struct sm_object *obj);

#define sm_object_discard(o)	do { (o)->discarded = true; } while (0)

struct sm_client {
	struct sm_object obj;

#define SM_CLIENT_CHANGE_MASK_INFO		(SM_OBJECT_CHANGE_MASK_LAST<<0)
#define SM_CLIENT_CHANGE_MASK_PERMISSIONS	(SM_OBJECT_CHANGE_MASK_LAST<<1)
	struct pw_client_info *info;
};

struct sm_device {
	struct sm_object obj;

	unsigned int locked:1;		/**< if the device is locked by someone else right now */

#define SM_DEVICE_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
#define SM_DEVICE_CHANGE_MASK_PARAMS	(SM_OBJECT_CHANGE_MASK_LAST<<1)
#define SM_DEVICE_CHANGE_MASK_NODES	(SM_OBJECT_CHANGE_MASK_LAST<<2)
	uint32_t n_params;
	struct spa_list param_list;	/**< list of sm_param */
	int param_seq[SM_MAX_PARAMS];
	struct pw_device_info *info;
	struct spa_list node_list;
};

struct sm_node {
	struct sm_object obj;

	struct sm_device *device;	/**< optional device */
	struct spa_list link;		/**< link in device node_list */

#define SM_NODE_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
#define SM_NODE_CHANGE_MASK_PARAMS	(SM_OBJECT_CHANGE_MASK_LAST<<1)
#define SM_NODE_CHANGE_MASK_PORTS	(SM_OBJECT_CHANGE_MASK_LAST<<2)
	uint32_t n_params;
	struct spa_list param_list;	/**< list of sm_param */
	int param_seq[SM_MAX_PARAMS];
	struct pw_node_info *info;
	struct spa_list port_list;

	char *target_node;		/** desired target node from stored
					  * preferences */
};

struct sm_port {
	struct sm_object obj;

	enum pw_direction direction;
#define SM_PORT_TYPE_UNKNOWN	0
#define SM_PORT_TYPE_DSP_AUDIO	1
#define SM_PORT_TYPE_DSP_MIDI	2
	uint32_t type;
	uint32_t channel;
	struct sm_node *node;
	struct spa_list link;		/**< link in node port_list */

#define SM_PORT_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
	struct pw_port_info *info;

	unsigned int visited:1;
};

struct sm_session {
	struct sm_object obj;

#define SM_SESSION_CHANGE_MASK_INFO		(SM_OBJECT_CHANGE_MASK_LAST<<0)
#define SM_SESSION_CHANGE_MASK_ENDPOINTS	(SM_OBJECT_CHANGE_MASK_LAST<<1)
	struct pw_session_info *info;
	struct spa_list endpoint_list;
};

struct sm_endpoint {
	struct sm_object obj;

	int32_t priority;

	struct sm_session *session;
	struct spa_list link;		/**< link in session endpoint_list */

#define SM_ENDPOINT_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
#define SM_ENDPOINT_CHANGE_MASK_STREAMS	(SM_OBJECT_CHANGE_MASK_LAST<<1)
	struct pw_endpoint_info *info;
	struct spa_list stream_list;
};

struct sm_endpoint_stream {
	struct sm_object obj;

	int32_t priority;

	struct sm_endpoint *endpoint;
	struct spa_list link;		/**< link in endpoint stream_list */

	struct spa_list link_list;	/**< list of links */

#define SM_ENDPOINT_STREAM_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
	struct pw_endpoint_stream_info *info;
};

struct sm_endpoint_link {
	struct sm_object obj;

	struct spa_list link;		/**< link in session link_list */

	struct spa_list output_link;
	struct sm_endpoint_stream *output;
	struct spa_list input_link;
	struct sm_endpoint_stream *input;

#define SM_ENDPOINT_LINK_CHANGE_MASK_INFO	(SM_OBJECT_CHANGE_MASK_LAST<<0)
	struct pw_endpoint_link_info *info;
};

struct sm_media_session_events {
#define SM_VERSION_MEDIA_SESSION_EVENTS	0
	uint32_t version;

	void (*info) (void *data, const struct pw_core_info *info);

	void (*create) (void *data, struct sm_object *object);
	void (*remove) (void *data, struct sm_object *object);

	void (*rescan) (void *data, int seq);
	void (*shutdown) (void *data);
	void (*destroy) (void *data);

	void (*seat_active) (void *data, bool active);
};

struct sm_media_session {
	struct sm_session *session;	/** session object managed by this session */

	struct pw_properties *props;

	uint32_t session_id;
	struct pw_client_session *client_session;

	struct pw_loop *loop;		/** the main loop */
	struct pw_context *context;

	struct spa_dbus_connection *dbus_connection;
	struct pw_metadata *metadata;

	struct pw_core_info *info;
};

int sm_media_session_add_listener(struct sm_media_session *sess, struct spa_hook *listener,
		const struct sm_media_session_events *events, void *data);

int sm_media_session_roundtrip(struct sm_media_session *sess);

int sm_media_session_sync(struct sm_media_session *sess,
		void (*callback) (void *data), void *data);

struct sm_object *sm_media_session_find_object(struct sm_media_session *sess, uint32_t id);
int sm_media_session_destroy_object(struct sm_media_session *sess, uint32_t id);

int sm_media_session_for_each_object(struct sm_media_session *sess,
                            int (*callback) (void *data, struct sm_object *object),
                            void *data);

int sm_media_session_schedule_rescan(struct sm_media_session *sess);

struct pw_metadata *sm_media_session_export_metadata(struct sm_media_session *sess,
		const char *name);
struct pw_proxy *sm_media_session_export(struct sm_media_session *sess,
		const char *type, const struct spa_dict *props,
		void *object, size_t user_data_size);

struct sm_node *sm_media_session_export_node(struct sm_media_session *sess,
		const struct spa_dict *props, struct pw_impl_node *node);
struct sm_device *sm_media_session_export_device(struct sm_media_session *sess,
		const struct spa_dict *props, struct spa_device *device);

struct pw_proxy *sm_media_session_create_object(struct sm_media_session *sess,
		const char *factory_name, const char *type, uint32_t version,
		const struct spa_dict *props, size_t user_data_size);

struct sm_node *sm_media_session_create_node(struct sm_media_session *sess,
		const char *factory_name, const struct spa_dict *props);

int sm_media_session_create_links(struct sm_media_session *sess,
		const struct spa_dict *dict);
int sm_media_session_remove_links(struct sm_media_session *sess,
		const struct spa_dict *dict);

int sm_media_session_load_conf(struct sm_media_session *sess,
		const char *name, struct pw_properties *conf);

int sm_media_session_load_state(struct sm_media_session *sess,
		const char *name, struct pw_properties *props);
int sm_media_session_save_state(struct sm_media_session *sess,
		const char *name, const struct pw_properties *props);

int sm_media_session_match_rules(const char *rules, size_t size,
		struct pw_properties *props);

char *sm_media_session_sanitize_name(char *name, int size, char sub,
		const char *fmt, ...) SPA_PRINTF_FUNC(4, 5);
char *sm_media_session_sanitize_description(char *name, int size, char sub,
		const char *fmt, ...) SPA_PRINTF_FUNC(4, 5);

int sm_media_session_seat_active_changed(struct sm_media_session *sess, bool active);

#ifdef __cplusplus
}
#endif

#endif
