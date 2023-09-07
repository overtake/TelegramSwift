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

#define EXT_STREAM_RESTORE_VERSION	1

static const struct extension_sub ext_stream_restore[];

static int do_extension_stream_restore_test(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct message *reply;

	reply = reply_new(client, tag);
	message_put(reply,
			TAG_U32, EXT_STREAM_RESTORE_VERSION,
			TAG_INVALID);
	return send_message(client, reply);
}

static int key_from_name(const char *name, char *key, size_t maxlen)
{
	const char *media_class, *select, *str;

	if (strstr(name, "sink-input-") == name)
		media_class = "Output/Audio";
	else if (strstr(name, "source-output-") == name)
		media_class = "Input/Audio";
	else
		return -1;

	if ((str = strstr(name, "-by-media-role:")) != NULL) {
		const struct str_map *map;
		str += strlen("-by-media-role:");
		map = str_map_find(media_role_map, NULL, str);
		str = map ? map->pw_str : str;
		select = "media.role";
	}
	else if ((str = strstr(name, "-by-application-id:")) != NULL) {
		str += strlen("-by-application-id:");
		select = "application.id";
	}
	else if ((str = strstr(name, "-by-application-name:")) != NULL) {
		str += strlen("-by-application-name:");
		select = "application.name";
	}
	else if ((str = strstr(name, "-by-media-name:")) != NULL) {
		str += strlen("-by-media-name:");
		select = "media.name";
	} else
		return -1;

	snprintf(key, maxlen, "restore.stream.%s.%s:%s",
				media_class, select, str);
	return 0;
}

static int key_to_name(const char *key, char *name, size_t maxlen)
{
	const char *type, *select, *str;

	if (strstr(key, "restore.stream.Output/Audio.") == key)
		type = "sink-input";
	else if (strstr(key, "restore.stream.Input/Audio.") == key)
		type = "source-output";
	else
		type = "stream";

	if ((str = strstr(key, ".media.role:")) != NULL) {
		const struct str_map *map;
		str += strlen(".media.role:");
		map = str_map_find(media_role_map, str, NULL);
		select = "media-role";
		str = map ? map->pa_str : str;
	}
	else if ((str = strstr(key, ".application.id:")) != NULL) {
		str += strlen(".application.id:");
		select = "application-id";
	}
	else if ((str = strstr(key, ".application.name:")) != NULL) {
		str += strlen(".application.name:");
		select = "application-name";
	}
	else if ((str = strstr(key, ".media.name:")) != NULL) {
		str += strlen(".media.name:");
		select = "media-name";
	}
	else
		return -1;

	snprintf(name, maxlen, "%s-by-%s:%s", type, select, str);
	return 0;

}

static int do_extension_stream_restore_read(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	struct message *reply;
	const struct spa_dict_item *item;

	reply = reply_new(client, tag);

	spa_dict_for_each(item, &client->routes->dict) {
		struct spa_json it[3];
		const char *value;
		char name[1024], key[128];
		char device_name[1024] = "\0";
		bool mute = false;
		struct volume vol = VOLUME_INIT;
		struct channel_map map = CHANNEL_MAP_INIT;
		float volume = 0.0f;

		if (key_to_name(item->key, name, sizeof(name)) < 0)
			continue;

		pw_log_debug("%s -> %s: %s", item->key, name, item->value);

		spa_json_init(&it[0], item->value, strlen(item->value));
		if (spa_json_enter_object(&it[0], &it[1]) <= 0)
			continue;

		while (spa_json_get_string(&it[1], key, sizeof(key)-1) > 0) {
			if (strcmp(key, "volume") == 0) {
				if (spa_json_get_float(&it[1], &volume) <= 0)
					continue;
			}
			else if (strcmp(key, "mute") == 0) {
				if (spa_json_get_bool(&it[1], &mute) <= 0)
					continue;
			}
			else if (strcmp(key, "volumes") == 0) {
				vol = VOLUME_INIT;
				if (spa_json_enter_array(&it[1], &it[2]) <= 0)
					continue;

				for (vol.channels = 0; vol.channels < CHANNELS_MAX; vol.channels++) {
					if (spa_json_get_float(&it[2], &vol.values[vol.channels]) <= 0)
						break;
				}
			}
			else if (strcmp(key, "channels") == 0) {
				if (spa_json_enter_array(&it[1], &it[2]) <= 0)
					continue;

				for (map.channels = 0; map.channels < CHANNELS_MAX; map.channels++) {
					char chname[16];
	                                if (spa_json_get_string(&it[2], chname, sizeof(chname)) <= 0)
						break;
					map.map[map.channels] = channel_name2id(chname);
				}
			}
			else if (strcmp(key, "target-node") == 0) {
				if (spa_json_get_string(&it[1], device_name, sizeof(device_name)) <= 0)
					continue;
			}
			else if (spa_json_next(&it[1], &value) <= 0)
				break;
		}
		message_put(reply,
			TAG_STRING, name,
			TAG_CHANNEL_MAP, &map,
			TAG_CVOLUME, &vol,
			TAG_STRING, device_name[0] ? device_name : NULL,
			TAG_BOOLEAN, mute,
			TAG_INVALID);
	}
	return send_message(client, reply);
}

static int do_extension_stream_restore_write(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	int res;
	uint32_t mode;
	bool apply;

	if ((res = message_get(m,
			TAG_U32, &mode,
			TAG_BOOLEAN, &apply,
			TAG_INVALID)) < 0)
		return -EPROTO;

	while (m->offset < m->length) {
		const char *name, *device_name = NULL;
		struct channel_map map;
		struct volume vol;
		bool mute = false;
		uint32_t i;
		FILE *f;
		char *ptr;
		size_t size;
		char key[1024];

		spa_zero(map);
		spa_zero(vol);

		if (message_get(m,
				TAG_STRING, &name,
				TAG_CHANNEL_MAP, &map,
				TAG_CVOLUME, &vol,
				TAG_STRING, &device_name,
				TAG_BOOLEAN, &mute,
				TAG_INVALID) < 0)
			return -EPROTO;

		if (name == NULL || name[0] == '\0')
			return -EPROTO;

		f = open_memstream(&ptr, &size);
		fprintf(f, "{");
		fprintf(f, " \"mute\": %s", mute ? "true" : "false");
		if (vol.channels > 0) {
			fprintf(f, ", \"volumes\": [");
			for (i = 0; i < vol.channels; i++)
				fprintf(f, "%s%f", (i == 0 ? " ":", "), vol.values[i]);
			fprintf(f, " ]");
		}
		if (map.channels > 0) {
			fprintf(f, ", \"channels\": [");
			for (i = 0; i < map.channels; i++)
				fprintf(f, "%s\"%s\"", (i == 0 ? " ":", "), channel_id2name(map.map[i]));
			fprintf(f, " ]");
		}
		if (device_name != NULL && device_name[0] &&
		    (client->default_source == NULL || strcmp(device_name, client->default_source) != 0) &&
		    (client->default_sink == NULL || strcmp(device_name, client->default_sink) != 0))
			fprintf(f, ", \"target-node\": \"%s\"", device_name);
		fprintf(f, " }");
		fclose(f);

		if (key_from_name(name, key, sizeof(key)) >= 0) {
			pw_log_debug("%s -> %s: %s", name, key, ptr);
			if (pw_manager_set_metadata(client->manager,
							client->metadata_routes,
							PW_ID_CORE, key, "Spa:String:JSON", "%s", ptr) < 0)
				pw_log_warn(NAME ": failed to set metadata %s = %s", key, ptr);
		}
		free(ptr);
	}

	return reply_simple_ack(client, tag);
}

static int do_extension_stream_restore_delete(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	return reply_simple_ack(client, tag);
}

static int do_extension_stream_restore_subscribe(struct client *client, uint32_t command, uint32_t tag, struct message *m)
{
	return reply_simple_ack(client, tag);
}

static const struct extension_sub ext_stream_restore[] = {
	{ "TEST", 0, do_extension_stream_restore_test, },
	{ "READ", 1, do_extension_stream_restore_read, },
	{ "WRITE", 2, do_extension_stream_restore_write, },
	{ "DELETE", 3, do_extension_stream_restore_delete, },
	{ "SUBSCRIBE", 4, do_extension_stream_restore_subscribe, },
	{ "EVENT", 5, },
};

static int do_extension_stream_restore(struct client *client, uint32_t tag, struct message *m)
{
	struct impl *impl = client->impl;
	uint32_t command;
	int res;

	if ((res = message_get(m,
			TAG_U32, &command,
			TAG_INVALID)) < 0)
		return -EPROTO;

	if (command >= SPA_N_ELEMENTS(ext_stream_restore))
		return -ENOTSUP;
	if (ext_stream_restore[command].process == NULL)
		return -EPROTO;

	pw_log_info(NAME" %p: [%s] EXT_STREAM_RESTORE_%s tag:%u", impl,
			client->name, ext_stream_restore[command].name, tag);

	return ext_stream_restore[command].process(client, command, tag, m);
}
