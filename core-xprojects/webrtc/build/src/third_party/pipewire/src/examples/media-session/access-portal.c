/* PipeWire
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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>

#include "config.h"

#include <dbus/dbus.h>

#include <spa/support/dbus.h>
#include <spa/debug/dict.h>

#include "pipewire/pipewire.h"

#include "media-session.h"

#define NAME		"access-portal"
#define SESSION_KEY	"access-portal"

enum media_role {
	MEDIA_ROLE_INVALID = -1,
	MEDIA_ROLE_NONE = 0,
	MEDIA_ROLE_CAMERA = 1 << 0,
};
#define MEDIA_ROLE_ALL (MEDIA_ROLE_CAMERA)

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;

	struct spa_list client_list;

	DBusConnection *bus;
};


struct client {
	struct impl *impl;

	struct sm_client *obj;
	struct spa_hook listener;

	struct spa_list link;		/**< link in impl client_list */

	uint32_t id;
	unsigned int portal_managed:1;
	unsigned int setup_complete:1;
	unsigned int is_portal:1;
	char *app_id;
	enum media_role media_roles;
	enum media_role allowed_media_roles;
};

static void client_info_changed(struct client *client, const struct pw_client_info *info);

static enum media_role media_role_from_string(const char *media_role_str)
{
	if (strcmp(media_role_str, "Camera") == 0)
		return MEDIA_ROLE_CAMERA;
	else
		return MEDIA_ROLE_INVALID;
}

static enum media_role parse_media_roles(const char *media_types_str)
{
	enum media_role media_roles = 0;
	char *buf_orig;
	char *buf;

	buf_orig = strdup(media_types_str);
	buf = buf_orig;
	while (buf) {
		char *media_role_str;
		enum media_role media_role;

		media_role_str = buf;
		strsep(&buf, ",");

		media_role = media_role_from_string(media_role_str);
		if (media_role != MEDIA_ROLE_INVALID) {
			media_roles |= MEDIA_ROLE_CAMERA;
		}
		else {
			pw_log_debug("Client specified unknown media role '%s'",
				     media_role_str);
		}
	}
	free(buf_orig);

	return media_roles;
}

static enum media_role media_role_from_properties(const struct pw_properties *props)
{
	const char *media_class_str;
	const char *media_role_str;

	media_class_str = pw_properties_get(props, "media.class");
	media_role_str = pw_properties_get(props, "media.role");

	if (media_class_str == NULL)
		return MEDIA_ROLE_INVALID;

	if (media_role_str == NULL)
		return MEDIA_ROLE_INVALID;

	if (strcmp(media_class_str, "Video/Source") != 0)
		return MEDIA_ROLE_INVALID;

	return media_role_from_string(media_role_str);
}

static void object_update(void *data)
{
	struct client *client = data;
	struct impl *impl = client->impl;

	pw_log_debug(NAME" %p: client %p %08x", impl, client, client->obj->obj.changed);

	if (client->obj->obj.avail & SM_CLIENT_CHANGE_MASK_INFO)
		client_info_changed(client, client->obj->info);
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static int
handle_client(struct impl *impl, struct sm_object *object)
{
	struct client *client;
	const char *str;

	pw_log_debug(NAME" %p: client %u", impl, object->id);

	client = sm_object_add_data(object, SESSION_KEY, sizeof(struct client));
	client->obj = (struct sm_client*)object;
	client->id = object->id;
	client->impl = impl;
	spa_list_append(&impl->client_list, &client->link);

	client->obj->obj.mask |= SM_CLIENT_CHANGE_MASK_INFO;
	sm_object_add_listener(&client->obj->obj, &client->listener, &object_events, client);

	if (((str = pw_properties_get(client->obj->obj.props, PW_KEY_ACCESS)) != NULL ||
	    (str = pw_properties_get(client->obj->obj.props, PW_KEY_CLIENT_ACCESS)) != NULL) &&
	    strcmp(str, "portal") == 0) {
		client->portal_managed = true;
		pw_log_info(NAME " %p: portal managed client %d added",
			     impl, client->id);
	}
	return 1;
}

static int
set_global_permissions(void *data, struct sm_object *object)
{
	struct client *client = data;
	struct impl *impl = client->impl;
	struct pw_permission permissions[1];
	const struct pw_properties *props;
	int n_permissions = 0;
	bool set_permission;
	bool allowed = false;

	if ((props = object->props) == NULL)
		return 0;

	pw_log_debug(NAME" %p: object %d type:%s", impl, object->id, object->type);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Client) == 0) {
		set_permission = allowed = object->id == client->id;
	} else if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0) {
		enum media_role media_role;

		media_role = media_role_from_properties(props);

		if (media_role == MEDIA_ROLE_INVALID) {
			set_permission = false;
		}
		else if (client->allowed_media_roles & media_role) {
			set_permission = true;
			allowed = true;
		}
		else if (client->media_roles & media_role) {
			set_permission = true;
			allowed = false;
		}
		else {
			set_permission = false;
		}
	}
	else {
		set_permission = false;
	}

	if (set_permission) {
		permissions[n_permissions++] =
			PW_PERMISSION_INIT(object->id, allowed ? PW_PERM_ALL : 0);
		pw_log_info(NAME" %p: object %d allowed:%d", impl, object->id, allowed);
		pw_client_update_permissions(client->obj->obj.proxy,
				n_permissions, permissions);
	}
	return 0;
}



static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;

	pw_log_debug(NAME " %p: create global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Client) == 0) {
		handle_client(impl, object);
	} else {
		struct client *client;

		spa_list_for_each(client, &impl->client_list, link) {
			if (client->portal_managed &&
                            !client->is_portal)
				set_global_permissions(client, object);
                }
	}
}

static void destroy_client(struct impl *impl, struct client *client)
{
	spa_list_remove(&client->link);
	spa_hook_remove(&client->listener);
	free(client->app_id);
	sm_object_remove_data((struct sm_object*)client->obj, SESSION_KEY);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: remove global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Client) == 0) {
		struct client *client;

		if ((client = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_client(impl, client);
	}
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	struct client *client;

	spa_list_consume(client, &impl->client_list, link)
		destroy_client(impl, client);

	spa_hook_remove(&impl->listener);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

static bool
check_permission_allowed(DBusMessageIter *iter)
{
	bool allowed = false;

	while (dbus_message_iter_get_arg_type (iter) != DBUS_TYPE_INVALID) {
		const char *permission_value;

		dbus_message_iter_get_basic(iter, &permission_value);

		if (strcmp(permission_value, "yes") == 0) {
			allowed = true;
			break;
		}
		dbus_message_iter_next(iter);
	}

	return allowed;
}

static void do_permission_store_check(struct client *client)
{
	struct impl *impl = client->impl;
	DBusMessage *m = NULL, *r = NULL;
	DBusError error;
	DBusMessageIter msg_iter;
	const char *table;
	const char *id;
	DBusMessageIter r_iter;
	DBusMessageIter permissions_iter;

	if (client->app_id == NULL) {
		pw_log_debug("Ignoring portal check for broken portal managed client %p",
			     client);
		goto err_not_allowed;
	}

	if (client->media_roles == 0) {
		pw_log_debug("Ignoring portal check for portal client %p with static permissions",
			     client);
		sm_media_session_for_each_object(impl->session,
					set_global_permissions,
					client);
		return;
	}

	if (strcmp(client->app_id, "") == 0) {
		pw_log_debug("Ignoring portal check for non-sandboxed portal client %p",
			     client);
		client->allowed_media_roles = MEDIA_ROLE_ALL;
		sm_media_session_for_each_object(impl->session,
					set_global_permissions,
					client);
		return;
	}
	if (impl->bus == NULL) {
		pw_log_debug("Ignoring portal check for client %p: dbus disabled",
			     client);
		client->allowed_media_roles = MEDIA_ROLE_ALL;
		sm_media_session_for_each_object(impl->session,
					set_global_permissions,
					client);
		return;
	}

	client->allowed_media_roles = MEDIA_ROLE_NONE;

	dbus_error_init(&error);

	m = dbus_message_new_method_call("org.freedesktop.impl.portal.PermissionStore",
					 "/org/freedesktop/impl/portal/PermissionStore",
					 "org.freedesktop.impl.portal.PermissionStore",
					 "Lookup");

	dbus_message_iter_init_append(m, &msg_iter);
	table = "devices";
	dbus_message_iter_append_basic(&msg_iter, DBUS_TYPE_STRING, &table);
	id = "camera";
	dbus_message_iter_append_basic(&msg_iter, DBUS_TYPE_STRING, &id);

	if (!(r = dbus_connection_send_with_reply_and_block(impl->bus, m, -1, &error))) {
		pw_log_error("Failed to call permission store: %s", error.message);
		dbus_error_free(&error);
		goto err_not_allowed;
	}

	dbus_message_unref(m);

	dbus_message_iter_init(r, &r_iter);
	dbus_message_iter_recurse(&r_iter, &permissions_iter);
	while (dbus_message_iter_get_arg_type(&permissions_iter) !=
	       DBUS_TYPE_INVALID) {
		DBusMessageIter permissions_entry_iter;
		const char *app_id;
		DBusMessageIter permission_values_iter;
		bool camera_allowed;

		dbus_message_iter_recurse(&permissions_iter,
					  &permissions_entry_iter);
		dbus_message_iter_get_basic(&permissions_entry_iter, &app_id);

		pw_log_info("permissions %s", app_id);
		if (strcmp(app_id, client->app_id) != 0) {
			dbus_message_iter_next(&permissions_iter);
			continue;
		}

		dbus_message_iter_next(&permissions_entry_iter);
		dbus_message_iter_recurse(&permissions_entry_iter,
					  &permission_values_iter);

		camera_allowed = check_permission_allowed(&permission_values_iter);
		pw_log_info("allowed %d", camera_allowed);
		client->allowed_media_roles |=
			camera_allowed ? MEDIA_ROLE_CAMERA : MEDIA_ROLE_NONE;

		sm_media_session_for_each_object(impl->session,
					set_global_permissions,
					client);
		break;
	}

	dbus_message_unref(r);

	return;

err_not_allowed:
	return;
}

static void client_info_changed(struct client *client, const struct pw_client_info *info)
{
	struct impl *impl = client->impl;
	const struct spa_dict *props;
	const char *is_portal;
	const char *app_id;
	const char *media_roles;

	if (!client->portal_managed || client->is_portal)
		return;

	if (client->setup_complete)
		return;

	if ((props = info->props) == NULL) {
		pw_log_error("Portal managed client didn't have any properties");
		return;
	}

	is_portal = spa_dict_lookup(props, "pipewire.access.portal.is_portal");
	if (is_portal != NULL &&
	    (strcmp(is_portal, "yes") == 0 || pw_properties_parse_bool(is_portal))) {
		pw_log_info(NAME " %p: client %d is the portal itself",
			     impl, client->id);
		client->is_portal = true;
		return;
	};

	app_id = spa_dict_lookup(props, "pipewire.access.portal.app_id");
	if (app_id == NULL) {
		pw_log_error(NAME" %p: Portal managed client %d didn't set app_id",
				impl, client->id);
		return;
	}
	media_roles = spa_dict_lookup(props, "pipewire.access.portal.media_roles");
	if (media_roles == NULL) {
		pw_log_error(NAME" %p: Portal managed client %d didn't set media_roles",
				impl, client->id);
		return;
	}

	client->app_id = strdup(app_id);
	client->media_roles = parse_media_roles(media_roles);

	pw_log_info(NAME" %p: client %d with app_id '%s' set to portal access",
			impl, client->id, client->app_id);

	do_permission_store_check(client);

	client->setup_complete = true;
}

static DBusHandlerResult permission_store_changed_handler(DBusConnection *connection,
							  DBusMessage *message,
							  void *user_data)
{
	struct impl *impl = user_data;
	struct client *client;
	DBusMessageIter iter;
	const char *table;
	const char *id;
	dbus_bool_t deleted;
	DBusMessageIter permissions_iter;

	if (!dbus_message_is_signal(message, "org.freedesktop.impl.portal.PermissionStore",
				   "Changed"))
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

	spa_list_for_each(client, &impl->client_list, link) {
		if (!client->portal_managed)
			continue;

		client->allowed_media_roles = MEDIA_ROLE_NONE;
	}

	dbus_message_iter_init(message, &iter);
	dbus_message_iter_get_basic(&iter, &table);

	dbus_message_iter_next(&iter);
	dbus_message_iter_get_basic(&iter, &id);

	if (strcmp(table, "devices") != 0 || strcmp(id, "camera") != 0)
		return DBUS_HANDLER_RESULT_HANDLED;

	dbus_message_iter_next(&iter);
	dbus_message_iter_get_basic(&iter, &deleted);

	dbus_message_iter_next(&iter);
	/* data variant (ignored) */

	dbus_message_iter_next(&iter);
	dbus_message_iter_recurse(&iter, &permissions_iter);
	while (dbus_message_iter_get_arg_type(&permissions_iter) !=
	       DBUS_TYPE_INVALID) {
		DBusMessageIter permissions_entry_iter;
		const char *app_id;
		DBusMessageIter permission_values_iter;
		bool camera_allowed;

		dbus_message_iter_recurse(&permissions_iter,
					  &permissions_entry_iter);
		dbus_message_iter_get_basic(&permissions_entry_iter, &app_id);

		dbus_message_iter_next(&permissions_entry_iter);
		dbus_message_iter_recurse(&permissions_entry_iter,
					  &permission_values_iter);

		camera_allowed = check_permission_allowed(&permission_values_iter);

		spa_list_for_each(client, &impl->client_list, link) {
			if (!client->portal_managed)
				continue;

			if (client->is_portal)
				continue;

			if (client->app_id == NULL ||
			    strcmp(client->app_id, app_id) != 0)
				continue;

			if (!(client->media_roles & MEDIA_ROLE_CAMERA))
				continue;

			if (camera_allowed)
				client->allowed_media_roles |= MEDIA_ROLE_CAMERA;

			sm_media_session_for_each_object(impl->session,
						set_global_permissions,
						client);
		}

		dbus_message_iter_next(&permissions_iter);
	}

	return DBUS_HANDLER_RESULT_HANDLED;
}

static int init_dbus_connection(struct impl *impl)
{
	DBusError error;

	if (impl->bus == NULL)
		return 0;

	dbus_error_init(&error);

	dbus_bus_add_match(impl->bus,
			   "type='signal',\
			   sender='org.freedesktop.impl.portal.PermissionStore',\
			   interface='org.freedesktop.impl.portal.PermissionStore',\
			   member='Changed'",
			   &error);
	if (dbus_error_is_set(&error)) {
		pw_log_error("Failed to add permission store changed listener: %s",
			     error.message);
		dbus_error_free(&error);
		return -1;
	}

	dbus_connection_add_filter(impl->bus, permission_store_changed_handler,
				   impl, NULL);

	return 0;
}

int sm_access_portal_start(struct sm_media_session *session)
{
	struct impl *impl;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	spa_list_init(&impl->client_list);

	impl->session = session;

	if (session->dbus_connection)
		impl->bus = spa_dbus_connection_get(session->dbus_connection);
	if (impl->bus == NULL)
		pw_log_warn("no dbus connection, portal access disabled");
	else
		pw_log_debug("got dbus connection %p", impl->bus);

	if ((res = init_dbus_connection(impl)) < 0)
		goto error_free;

	sm_media_session_add_listener(impl->session,
			&impl->listener,
			&session_events, impl);
	return 0;

error_free:
	free(impl);
	return res;
}
