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
#include <fcntl.h>
#include <unistd.h>

#include "config.h"

#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include "extensions/metadata.h"

#include "media-session.h"

#define NAME		"default-nodes"
#define SESSION_KEY	"default-nodes"
#define PREFIX		"default."

#define SAVE_INTERVAL	1

#define DEFAULT_CONFIG_AUDIO_SINK_KEY	"default.configured.audio.sink"
#define DEFAULT_CONFIG_AUDIO_SOURCE_KEY	"default.configured.audio.source"
#define DEFAULT_CONFIG_VIDEO_SOURCE_KEY	"default.configured.video.source"

struct default_node {
	char *key;
	uint32_t value;
};

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;
	struct spa_source *idle_timeout;

	struct spa_hook meta_listener;

	struct default_node defaults[4];

	struct pw_properties *properties;

	unsigned int sync:1;
};

static struct default_node *find_default(struct impl *impl, const char *key)
{
	struct default_node *def;
	/* Check that the item key is a valid default key */
	for (def = impl->defaults; def->key != NULL; ++def)
		if (strcmp(key, def->key) == 0)
			return def;
	return NULL;
}

struct find_data {
	struct impl *impl;
	const char *name;
	uint32_t id;
};

static int find_name(void *data, struct sm_object *object)
{
	struct find_data *d = data;
	const char *str;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0 &&
	    object->props &&
	    (str = pw_properties_get(object->props, PW_KEY_NODE_NAME)) != NULL &&
	    strcmp(str, d->name) == 0) {
		d->id = object->id;
		return 1;
	}
	return 0;
}

static uint32_t find_id_for_name(struct impl *impl, const char *name)
{
	struct find_data d = { impl, name, SPA_ID_INVALID };
	sm_media_session_for_each_object(impl->session, find_name, &d);
	return d.id;
}

static int json_object_find(const char *obj, const char *key, char *value, size_t len)
{
	struct spa_json it[2];
	const char *v;
	char k[128];

	spa_json_init(&it[0], obj, strlen(obj));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], k, sizeof(k)-1) > 0) {
		if (strcmp(k, key) == 0) {
			if (spa_json_get_string(&it[1], value, len) <= 0)
				continue;
			return 0;
		} else {
			if (spa_json_next(&it[1], &v) <= 0)
				break;
		}
	}
	return -ENOENT;
}

static void remove_idle_timeout(struct impl *impl)
{
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);
	int res;

	if (impl->idle_timeout) {
		if ((res = sm_media_session_save_state(impl->session,
						SESSION_KEY, impl->properties)) < 0)
			pw_log_error("can't save "SESSION_KEY" state: %s", spa_strerror(res));
		pw_loop_destroy_source(main_loop, impl->idle_timeout);
		impl->idle_timeout = NULL;
	}
}

static void idle_timeout(void *data, uint64_t expirations)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: idle timeout", impl);
	remove_idle_timeout(impl);
}

static void add_idle_timeout(struct impl *impl)
{
	struct timespec value;
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);

	if (impl->idle_timeout == NULL)
		impl->idle_timeout = pw_loop_add_timer(main_loop, idle_timeout, impl);

	value.tv_sec = SAVE_INTERVAL;
	value.tv_nsec = 0;
	pw_loop_update_timer(main_loop, impl->idle_timeout, &value, NULL, false);
}

static int metadata_property(void *object, uint32_t subject,
		const char *key, const char *type, const char *value)
{
	struct impl *impl = object;
	int changed = 0;

	if (impl->sync)
		return 0;

	if (subject == PW_ID_CORE) {
		if (key == NULL) {
			pw_properties_clear(impl->properties);
			changed++;
		} else {
			uint32_t id;
			struct default_node *def;
			char name[1024];

			if ((def = find_default(impl, key)) == NULL)
				return 0;

			if (value == NULL) {
				def->value = SPA_ID_INVALID;
			} else {
				if (json_object_find(value, "name", name, sizeof(name)) < 0)
					return 0;

				if ((id = find_id_for_name(impl, name)) == SPA_ID_INVALID)
					return 0;

				def->value = id;
				changed += pw_properties_set(impl->properties,
							key, value);
			}
		}
	}
	if (changed)
		add_idle_timeout(impl);

	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	const struct spa_dict_item *item;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) != 0)
		return;

	spa_dict_for_each(item, &impl->properties->dict) {
		char name [1024] = "\0";
		struct find_data d;

		if (find_default(impl, item->key) == NULL)
			continue;

		if (json_object_find(item->value, "name", name, sizeof(name)) < 0)
			continue;

		d = (struct find_data){ impl, name, SPA_ID_INVALID };
		if (find_name(&d, object)) {
			if (impl->session->metadata != NULL) {
				pw_log_info("found %s with id:%u restore as %s",
						name, d.id, item->key);
				pw_metadata_set_property(impl->session->metadata,
					PW_ID_CORE, item->key, "Spa:String:JSON", item->value);
			}
		}
	}
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	struct default_node *def;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) != 0)
		return;

	for (def = impl->defaults; def->key != NULL; ++def) {
		if (def->value == object->id) {
			def->value = SPA_ID_INVALID;
			if (impl->session->metadata != NULL) {
				pw_metadata_set_property(impl->session->metadata,
						PW_ID_CORE, def->key, NULL, NULL);
			}
		}
	}
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	remove_idle_timeout(impl);
	spa_hook_remove(&impl->listener);
	if (impl->session->metadata)
		spa_hook_remove(&impl->meta_listener);
	pw_properties_free(impl->properties);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

int sm_default_nodes_start(struct sm_media_session *session)
{
	struct impl *impl;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	impl->defaults[0] = (struct default_node){ DEFAULT_CONFIG_AUDIO_SINK_KEY, };
	impl->defaults[1] = (struct default_node){ DEFAULT_CONFIG_AUDIO_SOURCE_KEY, };
	impl->defaults[2] = (struct default_node){ DEFAULT_CONFIG_VIDEO_SOURCE_KEY, };
	impl->defaults[3] = (struct default_node){ NULL, };

	impl->properties = pw_properties_new(NULL, NULL);
	if (impl->properties == NULL) {
		free(impl);
		return -ENOMEM;
	}

	if ((res = sm_media_session_load_state(impl->session,
					SESSION_KEY, impl->properties)) < 0)
		pw_log_info("can't load "SESSION_KEY" state: %s", spa_strerror(res));

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	if (session->metadata) {
		pw_metadata_add_listener(session->metadata,
				&impl->meta_listener,
				&metadata_events, impl);
	}
	return 0;
}
