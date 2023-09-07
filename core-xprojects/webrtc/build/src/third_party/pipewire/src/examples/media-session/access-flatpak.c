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

#include "pipewire/pipewire.h"

#include "media-session.h"

#define NAME		"access-flatpak"
#define SESSION_KEY	"access-flatpak"

struct impl {
	struct sm_media_session *session;
	struct spa_hook listener;

	struct spa_list client_list;
};

struct client {
	struct sm_client *obj;

	uint32_t id;
	struct impl *impl;

	struct spa_list link;		/**< link in impl client_list */

	struct spa_hook listener;
	unsigned int active:1;
};

static void object_update(void *data)
{
	struct client *client = data;
	struct impl *impl = client->impl;
	const char *str;

	pw_log_debug(NAME" %p: client %p %08x", impl, client, client->obj->obj.changed);

	if (client->obj->obj.avail & SM_CLIENT_CHANGE_MASK_INFO &&
	    !client->active) {
		struct pw_permission permissions[1];
		uint32_t perms;

		if (client->obj->info == NULL || client->obj->info->props == NULL ||
		    (str = spa_dict_lookup(client->obj->info->props, PW_KEY_ACCESS)) == NULL ||
		    strcmp(str, "flatpak") != 0)
			return;

		if ((str = spa_dict_lookup(client->obj->info->props, PW_KEY_MEDIA_CATEGORY)) != NULL &&
		    (strcmp(str, "Manager") == 0)) {
			/* FIXME, use permission store to check if this app is allowed to
			 * be a manager app */
			perms = PW_PERM_ALL;
		} else {
			/* limited access for everything else */
			perms = PW_PERM_R | PW_PERM_X;
		}

		pw_log_info(NAME" %p: flatpak client %d granted 0x%08x permissions"
				, impl, client->id, perms);
		permissions[0] = PW_PERMISSION_INIT(PW_ID_ANY, perms);
		pw_client_update_permissions(client->obj->obj.proxy,
				1, permissions);
		client->active = true;
	}
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static int
handle_client(struct impl *impl, struct sm_object *object)
{
	struct client *client;

	pw_log_debug(NAME" %p: client", impl);

	client = sm_object_add_data(object, SESSION_KEY, sizeof(struct client));
	client->obj = (struct sm_client*)object;
	client->id = object->id;
	client->impl = impl;
	spa_list_append(&impl->client_list, &client->link);

	client->obj->obj.mask |= SM_CLIENT_CHANGE_MASK_INFO;
	sm_object_add_listener(&client->obj->obj, &client->listener, &object_events, client);

	return 1;
}

static void destroy_client(struct impl *impl, struct client *client)
{
	spa_list_remove(&client->link);
	spa_hook_remove(&client->listener);
	sm_object_remove_data((struct sm_object*)client->obj, SESSION_KEY);
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	pw_log_debug(NAME " %p: create global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Client) == 0)
		res = handle_client(impl, object);
	else
		res = 0;

	if (res < 0)
		pw_log_warn(NAME" %p: can't handle global %d", impl, object->id);
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

int sm_access_flatpak_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;

	spa_list_init(&impl->client_list);

	sm_media_session_add_listener(impl->session,
			&impl->listener,
			&session_events, impl);
	return 0;
}
