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
#include <spa/pod/parser.h>
#include <spa/pod/builder.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include "extensions/metadata.h"

#include "media-session.h"

#define NAME		"restore-stream"
#define SESSION_KEY	"restore-stream"
#define PREFIX		"restore.stream."

#define SAVE_INTERVAL	1

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;
	struct spa_source *idle_timeout;

	struct pw_metadata *metadata;
	struct spa_hook metadata_listener;

	struct pw_properties *props;

	unsigned int sync:1;
};

struct stream {
	struct sm_node *obj;

	uint32_t id;
	struct impl *impl;
	char *media_class;
	char *key;
	unsigned int restored:1;

	struct spa_hook listener;
};

static void remove_idle_timeout(struct impl *impl)
{
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);
	int res;

	if (impl->idle_timeout) {
		if ((res = sm_media_session_save_state(impl->session,
						SESSION_KEY, impl->props)) < 0)
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

static void session_destroy(void *data)
{
	struct impl *impl = data;
	remove_idle_timeout(impl);
	spa_hook_remove(&impl->listener);
	pw_properties_free(impl->props);
	free(impl);
}

static uint32_t channel_from_name(const char *name)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (strcmp(name, spa_debug_type_short_name(spa_type_audio_channel[i].name)) == 0)
			return spa_type_audio_channel[i].type;
	}
	return SPA_AUDIO_CHANNEL_UNKNOWN;
}

static const char *channel_to_name(uint32_t channel)
{
	int i;
	for (i = 0; spa_type_audio_channel[i].name; i++) {
		if (spa_type_audio_channel[i].type == channel)
			return spa_debug_type_short_name(spa_type_audio_channel[i].name);
	}
	return "UNK";
}

static char *serialize_props(struct stream *str, const struct spa_pod *param)
{
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) param;
	float val = 0.0f;
	bool b = false, comma = false;
	char *ptr;
	size_t size;
	FILE *f;

        f = open_memstream(&ptr, &size);
	fprintf(f, "{ ");

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &val) < 0)
				continue;
			fprintf(f, "%s\"volume\": %f", (comma ? ", " : ""), val);
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &b) < 0)
				continue;
			fprintf(f, "%s\"mute\": %s", (comma ? ", " : ""), b ? "true" : "false");
			break;
		case SPA_PROP_channelVolumes:
		{
			uint32_t i, n_vals;
			float vals[SPA_AUDIO_MAX_CHANNELS];

			n_vals = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					vals, SPA_AUDIO_MAX_CHANNELS);
			if (n_vals == 0)
				continue;

			fprintf(f, "%s\"volumes\": [", (comma ? ", " : ""));
			for (i = 0; i < n_vals; i++)
				fprintf(f, "%s%f", (i == 0 ? " ":", "), vals[i]);
			fprintf(f, " ]");
			break;
		}
		case SPA_PROP_channelMap:
		{
			uint32_t i, n_ch;
			uint32_t map[SPA_AUDIO_MAX_CHANNELS];

			n_ch = spa_pod_copy_array(&prop->value, SPA_TYPE_Id,
					map, SPA_AUDIO_MAX_CHANNELS);
			if (n_ch == 0)
				continue;

			fprintf(f, "%s\"channels\": [", (comma ? ", " : ""));
			for (i = 0; i < n_ch; i++)
				fprintf(f, "%s\"%s\"", (i == 0 ? " ":", "), channel_to_name(map[i]));
			fprintf(f, " ]");
			break;
		}
		default:
			continue;
		}
		comma = true;
	}
	if (str->obj->target_node != NULL)
		fprintf(f, "%s\"target-node\": \"%s\"",
				(comma ? ", " : ""), str->obj->target_node);

	fprintf(f, " }");
        fclose(f);

	if (strlen(ptr) < 5) {
		free(ptr);
		ptr = NULL;
	}
	return ptr;
}

static void sync_metadata(struct impl *impl)
{
	const struct spa_dict_item *it;

	impl->sync = true;
	spa_dict_for_each(it, &impl->props->dict)
		pw_metadata_set_property(impl->metadata,
				PW_ID_CORE, it->key, "Spa:String:JSON", it->value);
	impl->sync = false;
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
			pw_properties_clear(impl->props);
			changed = 1;
		}
		else if (strstr(key, PREFIX) == key) {
			changed += pw_properties_set(impl->props, key, value);
		}
	}
	if (changed > 0)
		add_idle_timeout(impl);

	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

static int handle_props(struct stream *str, struct sm_param *p)
{
	struct impl *impl = str->impl;
	const char *key;
	int changed = 0;

	if ((key = str->key) == NULL)
		return -EBUSY;

	if (p->param) {
		char *val = serialize_props(str, p->param);
		if (val) {
			pw_log_info("stream %d: save props %s %s", str->id, key, val);
			changed += pw_properties_set(impl->props, key, val);
			free(val);
			add_idle_timeout(impl);
		}
	}
	if (changed)
		sync_metadata(impl);
	return 0;
}

static int restore_stream(struct stream *str)
{
	struct impl *impl = str->impl;
	struct spa_json it[3];
	const char *val, *value;
	char buf[1024], key[128];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	struct spa_pod_frame f[2];
	struct spa_pod *param;

	if (str->key == NULL)
		return -EBUSY;

	val = pw_properties_get(impl->props, str->key);
	if (val == NULL)
		return -ENOENT;

	pw_log_info("stream %d: restore '%s' to %s", str->id, str->key, val);

	spa_json_init(&it[0], val, strlen(val));

	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
                return -EINVAL;

	spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);

	while (spa_json_get_string(&it[1], key, sizeof(key)-1) > 0) {
		if (strcmp(key, "volume") == 0) {
			float vol;
			if (spa_json_get_float(&it[1], &vol) <= 0)
                                continue;
			spa_pod_builder_prop(&b, SPA_PROP_volume, 0);
			spa_pod_builder_float(&b, vol);
		}
		else if (strcmp(key, "mute") == 0) {
			bool mute;
			if (spa_json_get_bool(&it[1], &mute) <= 0)
                                continue;
			spa_pod_builder_prop(&b, SPA_PROP_mute, 0);
			spa_pod_builder_bool(&b, mute);
		}
		else if (strcmp(key, "volumes") == 0) {
			uint32_t n_vols;
			float vols[SPA_AUDIO_MAX_CHANNELS];

			if (spa_json_enter_array(&it[1], &it[2]) <= 0)
				continue;

			for (n_vols = 0; n_vols < SPA_AUDIO_MAX_CHANNELS; n_vols++) {
                                if (spa_json_get_float(&it[2], &vols[n_vols]) <= 0)
                                        break;
                        }
			if (n_vols == 0)
				continue;

			spa_pod_builder_prop(&b, SPA_PROP_channelVolumes, 0);
			spa_pod_builder_array(&b, sizeof(float), SPA_TYPE_Float,
					n_vols, vols);
		}
		else if (strcmp(key, "channels") == 0) {
			uint32_t n_ch;
			uint32_t map[SPA_AUDIO_MAX_CHANNELS];

			if (spa_json_enter_array(&it[1], &it[2]) <= 0)
				continue;

			for (n_ch = 0; n_ch < SPA_AUDIO_MAX_CHANNELS; n_ch++) {
				char chname[16];
                                if (spa_json_get_string(&it[2], chname, sizeof(chname)) <= 0)
                                        break;
				map[n_ch] = channel_from_name(chname);
                        }
			if (n_ch == 0)
				continue;

			spa_pod_builder_prop(&b, SPA_PROP_channelMap, 0);
			spa_pod_builder_array(&b, sizeof(uint32_t), SPA_TYPE_Id,
					n_ch, map);
		}
		else if (strcmp(key, "target-node") == 0) {
			char name[1024];

			if (spa_json_get_string(&it[1], name, sizeof(name)) <= 0)
                                continue;

			pw_log_info("stream %d: target '%s'", str->obj->obj.id, name);
			free(str->obj->target_node);
			str->obj->target_node = strdup(name);
		} else {
			if (spa_json_next(&it[1], &value) <= 0)
                                break;
		}
	}
	param = spa_pod_builder_pop(&b, &f[0]);
	if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
		spa_debug_pod(2, NULL, param);

	pw_node_set_param((struct pw_node*)str->obj->obj.proxy,
			SPA_PARAM_Props, 0, param);

	sm_media_session_schedule_rescan(str->impl->session);

	return 0;
}

static int save_stream(struct stream *str)
{
	struct sm_param *p;
	spa_list_for_each(p, &str->obj->param_list, link) {
		if (pw_log_level_enabled(SPA_LOG_LEVEL_DEBUG))
			spa_debug_pod(2, NULL, p->param);

		switch (p->id) {
		case SPA_PARAM_Props:
			handle_props(str, p);
			break;
		default:
			break;
		}
	}
	return 0;
}

static void update_stream(struct stream *str)
{
	struct impl *impl = str->impl;
	uint32_t i;
	const char *p;
	char *key;
	struct sm_object *obj = &str->obj->obj;
	const char *keys[] = {
		PW_KEY_MEDIA_ROLE,
		PW_KEY_APP_ID,
		PW_KEY_APP_NAME,
		PW_KEY_MEDIA_NAME,
		PW_KEY_NODE_NAME,
	};

	key = NULL;
	for (i = 0; i < SPA_N_ELEMENTS(keys); i++) {
		if ((p = pw_properties_get(obj->props, keys[i]))) {
			key = spa_aprintf(PREFIX"%s.%s:%s", str->media_class, keys[i], p);
			break;
		}
	}
	if (key == NULL)
		return;

	pw_log_debug(NAME " %p: stream %p key '%s'", impl, str, key);
	free(str->key);
	str->key = key;

	if (!str->restored) {
		restore_stream(str);
		str->restored = true;
	} else {
		save_stream(str);
	}
}

static void object_update(void *data)
{
	struct stream *str = data;
	struct impl *impl = str->impl;

	pw_log_info(NAME" %p: stream %p %08x/%08x", impl, str,
			str->obj->obj.changed, str->obj->obj.avail);

	if (str->obj->obj.changed & SM_NODE_CHANGE_MASK_PARAMS)
		update_stream(str);
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	struct stream *str;
	const char *media_class, *routes;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) != 0 ||
	    object->props == NULL ||
	    (media_class = pw_properties_get(object->props, PW_KEY_MEDIA_CLASS)) == NULL)
		return;

	if (strstr(media_class, "Stream/") == media_class) {
		media_class += strlen("Stream/");
		pw_log_debug(NAME " %p: add stream '%d' %s", impl, object->id, media_class);
	} else if (strstr(media_class, "Audio/") == media_class &&
	    ((routes = pw_properties_get(object->props, "device.routes")) == NULL ||
	    atoi(routes) == 0)) {
		pw_log_debug(NAME " %p: add node '%d' %s", impl, object->id, media_class);
	} else {
		return;
	}

	str = sm_object_add_data(object, SESSION_KEY, sizeof(struct stream));
	str->obj = (struct sm_node*)object;
	str->id = object->id;
	str->impl = impl;
	str->media_class = strdup(media_class);

	str->obj->obj.mask |= SM_OBJECT_CHANGE_MASK_PROPERTIES | SM_NODE_CHANGE_MASK_PARAMS;
	sm_object_add_listener(&str->obj->obj, &str->listener, &object_events, str);
}

static void destroy_stream(struct impl *impl, struct stream *str)
{
	remove_idle_timeout(impl);
	spa_hook_remove(&str->listener);
	free(str->media_class);
	free(str->key);
	sm_object_remove_data((struct sm_object*)str->obj, SESSION_KEY);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	struct stream *str;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) != 0)
		return;

	pw_log_debug(NAME " %p: remove node '%d'", impl, object->id);

	if ((str = sm_object_get_data(object, SESSION_KEY)) != NULL)
		destroy_stream(impl, str);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

int sm_restore_stream_start(struct sm_media_session *session)
{
	struct impl *impl;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	impl->props = pw_properties_new(NULL, NULL);
	if (impl->props == NULL)
		goto exit_errno;

	impl->metadata = sm_media_session_export_metadata(session, "route-settings");
	if (impl->metadata == NULL)
		goto exit_errno;

	pw_metadata_add_listener(impl->metadata, &impl->metadata_listener,
			&metadata_events, impl);

	if ((res = sm_media_session_load_state(impl->session,
					SESSION_KEY, impl->props)) < 0)
		pw_log_info("can't load "SESSION_KEY" state: %s", spa_strerror(res));

	sync_metadata(impl);

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	return 0;

exit_errno:
	res = -errno;
	if (impl->props)
		pw_properties_free(impl->props);
	free(impl);
	return res;
}
