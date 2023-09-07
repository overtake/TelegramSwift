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

#define VOLUME_MUTED ((uint32_t) 0U)
#define VOLUME_NORM ((uint32_t) 0x10000U)
#define VOLUME_MAX ((uint32_t) UINT32_MAX/2)

#define PA_CHANNELS_MAX	(32u)

static inline uint32_t volume_from_linear(float vol)
{
	uint32_t v;
	if (vol <= 0.0f)
		v = VOLUME_MUTED;
	else
		v = SPA_CLAMP((uint64_t) lround(cbrt(vol) * VOLUME_NORM),
				VOLUME_MUTED, VOLUME_MAX);
	return v;
}

static inline float volume_to_linear(uint32_t vol)
{
	float v = ((float)vol) / VOLUME_NORM;
	return v * v * v;
}

struct str_map {
	const char *pw_str;
	const char *pa_str;
	const struct str_map *child;
};

const struct str_map media_role_map[] = {
	{ "Movie", "video", },
	{ "Music", "music", },
	{ "Game", "game", },
	{ "Notification", "event", },
	{ "Communication", "phone", },
	{ "Movie", "animation", },
	{ "Production", "production", },
	{ "Accessibility", "a11y", },
	{ "Test", "test", },
	{ NULL, NULL },
};

const struct str_map key_table[] = {
	{ PW_KEY_DEVICE_BUS_PATH, "device.bus_path" },
	{ PW_KEY_DEVICE_FORM_FACTOR, "device.form_factor" },
	{ PW_KEY_DEVICE_ICON_NAME, "device.icon_name" },
	{ PW_KEY_DEVICE_INTENDED_ROLES, "device.intended_roles" },
	{ PW_KEY_NODE_DESCRIPTION, "device.description" },
	{ PW_KEY_MEDIA_ICON_NAME, "media.icon_name" },
	{ PW_KEY_APP_ICON_NAME, "application.icon_name" },
	{ PW_KEY_APP_PROCESS_MACHINE_ID, "application.process.machine_id" },
	{ PW_KEY_APP_PROCESS_SESSION_ID, "application.process.session_id" },
	{ PW_KEY_MEDIA_ROLE, "media.role", media_role_map },
	{ NULL, NULL },
};

static inline const struct str_map *str_map_find(const struct str_map *map, const char *pw, const char *pa)
{
	uint32_t i;
	for (i = 0; map[i].pw_str; i++)
		if ((pw && strcmp(map[i].pw_str, pw) == 0) ||
		    (pa && strcmp(map[i].pa_str, pa) == 0))
			return &map[i];
	return NULL;
}

enum {
	TAG_INVALID = 0,
	TAG_STRING = 't',
	TAG_STRING_NULL = 'N',
	TAG_U32 = 'L',
	TAG_U8 = 'B',
	TAG_U64 = 'R',
	TAG_S64 = 'r',
	TAG_SAMPLE_SPEC = 'a',
	TAG_ARBITRARY = 'x',
	TAG_BOOLEAN_TRUE = '1',
	TAG_BOOLEAN_FALSE = '0',
	TAG_BOOLEAN = TAG_BOOLEAN_TRUE,
	TAG_TIMEVAL = 'T',
	TAG_USEC = 'U'  /* 64bit unsigned */,
	TAG_CHANNEL_MAP = 'm',
	TAG_CVOLUME = 'v',
	TAG_PROPLIST = 'P',
	TAG_VOLUME = 'V',
	TAG_FORMAT_INFO = 'f',
};

struct message {
	struct spa_list link;
	struct stats *stat;
	uint32_t extra[4];
	uint32_t channel;
	uint32_t allocated;
	uint32_t length;
	uint32_t offset;
	uint8_t *data;
};

static int message_get(struct message *m, ...);

static int read_u8(struct message *m, uint8_t *val)
{
	if (m->offset + 1 > m->length)
		return -ENOSPC;
	*val = m->data[m->offset];
	m->offset++;
	return 0;
}

static int read_u32(struct message *m, uint32_t *val)
{
	if (m->offset + 4 > m->length)
		return -ENOSPC;
	memcpy(val, &m->data[m->offset], 4);
	*val = ntohl(*val);
	m->offset += 4;
	return 0;
}
static int read_u64(struct message *m, uint64_t *val)
{
	uint32_t tmp;
	int res;
	if ((res = read_u32(m, &tmp)) < 0)
		return res;
	*val = ((uint64_t)tmp) << 32;
	if ((res = read_u32(m, &tmp)) < 0)
		return res;
	*val |= tmp;
	return 0;
}

static int read_sample_spec(struct message *m, struct sample_spec *ss)
{
	int res;
	uint8_t tmp;
	if ((res = read_u8(m, &tmp)) < 0)
		return res;
	ss->format = format_pa2id(tmp);
	if ((res = read_u8(m, &ss->channels)) < 0)
		return res;
	return read_u32(m, &ss->rate);
}

static int read_props(struct message *m, struct pw_properties *props, bool remap)
{
	int res;

	while (true) {
		const char *key;
		const void *data;
		uint32_t length;
		size_t size;
		const struct str_map *map;

		if ((res = message_get(m,
				TAG_STRING, &key,
				TAG_INVALID)) < 0)
			return res;

		if (key == NULL)
			break;

		if ((res = message_get(m,
				TAG_U32, &length,
				TAG_INVALID)) < 0)
			return res;
		if (length > MAX_TAG_SIZE)
			return -EINVAL;

		if ((res = message_get(m,
				TAG_ARBITRARY, &data, &size,
				TAG_INVALID)) < 0)
			return res;

		if (remap && (map = str_map_find(key_table, NULL, key)) != NULL) {
			key = map->pw_str;
			if (map->child != NULL &&
			    (map = str_map_find(map->child, NULL, data)) != NULL)
				data = map->pw_str;
		}
		pw_properties_set(props, key, data);
	}
	return 0;
}

static int read_arbitrary(struct message *m, const void **val, size_t *length)
{
	uint32_t len;
	int res;
	if ((res = read_u32(m, &len)) < 0)
		return res;
	if (m->offset + len > m->length)
		return -ENOSPC;
	*val = m->data + m->offset;
	m->offset += len;
	if (length)
		*length = len;
	return 0;
}

static int read_string(struct message *m, char **str)
{
	uint32_t n, maxlen = m->length - m->offset;
	n = strnlen(SPA_MEMBER(m->data, m->offset, char), maxlen);
	if (n == maxlen)
		return -EINVAL;
	*str = SPA_MEMBER(m->data, m->offset, char);
	m->offset += n + 1;
	return 0;
}

static int read_timeval(struct message *m, struct timeval *tv)
{
	int res;
	uint32_t tmp;

	if ((res = read_u32(m, &tmp)) < 0)
		return res;
	tv->tv_sec = tmp;
	if ((res = read_u32(m, &tmp)) < 0)
		return res;
	tv->tv_usec = tmp;
	return 0;
}

static int read_channel_map(struct message *m, struct channel_map *map)
{
	int res;
	uint8_t i, tmp;

	if ((res = read_u8(m, &map->channels)) < 0)
		return res;
	if (map->channels > CHANNELS_MAX)
		return -EINVAL;
	for (i = 0; i < map->channels; i ++) {
		if ((res = read_u8(m, &tmp)) < 0)
			return res;
		map->map[i] = channel_pa2id(tmp);
	}
	return 0;
}
static int read_volume(struct message *m, float *vol)
{
	int res;
	uint32_t v;
	if ((res = read_u32(m, &v)) < 0)
		return res;
	*vol = volume_to_linear(v);
	return 0;
}

static int read_cvolume(struct message *m, struct volume *vol)
{
	int res;
	uint8_t i;

	if ((res = read_u8(m, &vol->channels)) < 0)
		return res;
	if (vol->channels > CHANNELS_MAX)
		return -EINVAL;
	for (i = 0; i < vol->channels; i ++) {
		if ((res = read_volume(m, &vol->values[i])) < 0)
			return res;
	}
	return 0;
}

static int read_format_info(struct message *m, struct format_info *info)
{
	int res;
	uint8_t tag, encoding;

	spa_zero(*info);
	if ((res = read_u8(m, &tag)) < 0)
		return res;
	if (tag != TAG_U8)
		return -EPROTO;
	if ((res = read_u8(m, &encoding)) < 0)
		return res;
	info->encoding = encoding;

	if ((res = read_u8(m, &tag)) < 0)
		return res;
	if (tag != TAG_PROPLIST)
		return -EPROTO;

	info->props = pw_properties_new(NULL, NULL);
	if (info->props == NULL)
		return -errno;
	if ((res = read_props(m, info->props, false)) < 0)
		format_info_clear(info);
	return res;
}

static int message_get(struct message *m, ...)
{
	va_list va;
	int res = 0;

	va_start(va, m);

	while (true) {
		int tag = va_arg(va, int);
		uint8_t dtag;
		if (tag == TAG_INVALID)
			break;

		if ((res = read_u8(m, &dtag)) < 0)
			goto done;

		switch (dtag) {
		case TAG_STRING:
			if (tag != TAG_STRING)
				goto invalid;
			if ((res = read_string(m, va_arg(va, char**))) < 0)
				goto done;
			break;
		case TAG_STRING_NULL:
			if (tag != TAG_STRING)
				goto invalid;
			*va_arg(va, char**) = NULL;
			break;
		case TAG_U8:
			if (dtag != tag)
				goto invalid;
			if ((res = read_u8(m, va_arg(va, uint8_t*))) < 0)
				goto done;
			break;
		case TAG_U32:
			if (dtag != tag)
				goto invalid;
			if ((res = read_u32(m, va_arg(va, uint32_t*))) < 0)
				goto done;
			break;
		case TAG_S64:
		case TAG_U64:
		case TAG_USEC:
			if (dtag != tag)
				goto invalid;
			if ((res = read_u64(m, va_arg(va, uint64_t*))) < 0)
				goto done;
			break;
		case TAG_SAMPLE_SPEC:
			if (dtag != tag)
				goto invalid;
			if ((res = read_sample_spec(m, va_arg(va, struct sample_spec*))) < 0)
				goto done;
			break;
		case TAG_ARBITRARY:
		{
			const void **val = va_arg(va, const void**);
			size_t *len = va_arg(va, size_t*);
			if (dtag != tag)
				goto invalid;
			if ((res = read_arbitrary(m, val, len)) < 0)
				goto done;
			break;
		}
		case TAG_BOOLEAN_TRUE:
			if (tag != TAG_BOOLEAN)
				goto invalid;
			*va_arg(va, bool*) = true;
			break;
		case TAG_BOOLEAN_FALSE:
			if (tag != TAG_BOOLEAN)
				goto invalid;
			*va_arg(va, bool*) = false;
			break;
		case TAG_TIMEVAL:
			if (dtag != tag)
				goto invalid;
			if ((res = read_timeval(m, va_arg(va, struct timeval*))) < 0)
				goto done;
			break;
		case TAG_CHANNEL_MAP:
			if (dtag != tag)
				goto invalid;
			if ((res = read_channel_map(m, va_arg(va, struct channel_map*))) < 0)
				goto done;
			break;
		case TAG_CVOLUME:
			if (dtag != tag)
				goto invalid;
			if ((res = read_cvolume(m, va_arg(va, struct volume*))) < 0)
				goto done;
			break;
		case TAG_PROPLIST:
			if (dtag != tag)
				goto invalid;
			if ((res = read_props(m, va_arg(va, struct pw_properties*), true)) < 0)
				goto done;
			break;
		case TAG_VOLUME:
			if (dtag != tag)
				goto invalid;
			if ((res = read_volume(m, va_arg(va, float*))) < 0)
				goto done;
			break;
		case TAG_FORMAT_INFO:
			if (dtag != tag)
				goto invalid;
			if ((res = read_format_info(m, va_arg(va, struct format_info*))) < 0)
				goto done;
			break;
		}
	}
	res = 0;
	goto done;

invalid:
	res = -EINVAL;

done:
	va_end(va);

	return res;
}

static int ensure_size(struct message *m, uint32_t size)
{
	uint32_t alloc, diff;
	void *data;

	if (m->length + size <= m->allocated)
		return size;

	alloc = SPA_ROUND_UP_N(SPA_MAX(m->allocated + size, 4096u), 4096u);
	diff = alloc - m->allocated;
	if ((data = realloc(m->data, alloc)) == NULL)
		return -errno;
	m->stat->allocated += diff;
	m->stat->accumulated += diff;
	m->data = data;
	m->allocated = alloc;
	return size;
}

static void write_8(struct message *m, uint8_t val)
{
	if (ensure_size(m, 1) > 0)
		m->data[m->length] = val;
	m->length++;
}

static void write_32(struct message *m, uint32_t val)
{
	val = htonl(val);
	if (ensure_size(m, 4) > 0)
		memcpy(m->data + m->length, &val, 4);
	m->length += 4;
}

static void write_string(struct message *m, const char *s)
{
	write_8(m, s ? TAG_STRING : TAG_STRING_NULL);
	if (s != NULL) {
		int len = strlen(s) + 1;
		if (ensure_size(m, len) > 0)
			strcpy(SPA_MEMBER(m->data, m->length, char), s);
		m->length += len;
	}
}
static void write_u8(struct message *m, uint8_t val)
{
	write_8(m, TAG_U8);
	write_8(m, val);
}

static void write_u32(struct message *m, uint32_t val)
{
	write_8(m, TAG_U32);
	write_32(m, val);
}

static void write_64(struct message *m, uint8_t tag, uint64_t val)
{
	write_8(m, tag);
	write_32(m, val >> 32);
	write_32(m, val);
}

static void write_sample_spec(struct message *m, struct sample_spec *ss)
{
	uint32_t channels = SPA_MIN(ss->channels, PA_CHANNELS_MAX);
	write_8(m, TAG_SAMPLE_SPEC);
	write_8(m, format_id2pa(ss->format));
	write_8(m, channels);
	write_32(m, ss->rate);
}

static void write_arbitrary(struct message *m, const void *p, size_t length)
{
	write_8(m, TAG_ARBITRARY);
	write_32(m, length);
	if (ensure_size(m, length) > 0)
		memcpy(m->data + m->length, p, length);
	m->length += length;
}

static void write_boolean(struct message *m, bool val)
{
	write_8(m, val ? TAG_BOOLEAN_TRUE : TAG_BOOLEAN_FALSE);
}

static void write_timeval(struct message *m, struct timeval *tv)
{
	write_8(m, TAG_TIMEVAL);
	write_32(m, tv->tv_sec);
	write_32(m, tv->tv_usec);
}

static void write_channel_map(struct message *m, struct channel_map *map)
{
	uint8_t i;
	uint32_t aux = 0, channels = SPA_MIN(map->channels, PA_CHANNELS_MAX);
	write_8(m, TAG_CHANNEL_MAP);
	write_8(m, channels);
	for (i = 0; i < channels; i ++)
		write_8(m, channel_id2pa(map->map[i], &aux));
}

static void write_volume(struct message *m, float vol)
{
	write_8(m, TAG_VOLUME);
	write_32(m, volume_from_linear(vol));
}

static void write_cvolume(struct message *m, struct volume *vol)
{
	uint8_t i;
	uint32_t channels = SPA_MIN(vol->channels, PA_CHANNELS_MAX);
	write_8(m, TAG_CVOLUME);
	write_8(m, channels);
	for (i = 0; i < channels; i ++)
		write_32(m, volume_from_linear(vol->values[i]));
}

static void add_stream_group(struct message *m, struct spa_dict *dict, const char *key,
		const char *media_class, const char *media_role)
{
	const char *str, *fmt, *prefix;
	char *b;
	int l;

	if (media_class == NULL)
		return;
	if (strcmp(media_class, "Stream/Output/Audio") == 0)
		prefix = "sink-input";
	else if (strcmp(media_class, "Stream/Input/Audio") == 0)
		prefix = "source-output";
	else
		return;

	if ((str = media_role) != NULL)
		fmt = "%s-by-media-role:%s";
	else if ((str = spa_dict_lookup(dict, PW_KEY_APP_ID)) != NULL)
		fmt = "%s-by-application-id:%s";
	else if ((str = spa_dict_lookup(dict, PW_KEY_APP_NAME)) != NULL)
		fmt = "%s-by-application-name:%s";
	else if ((str = spa_dict_lookup(dict, PW_KEY_MEDIA_NAME)) != NULL)
		fmt = "%s-by-media-name:%s";
	else
		return;

	write_string(m, key);
	l = strlen(fmt) + strlen(prefix) + strlen(str) - 3;
	b = alloca(l);
	snprintf(b, l, fmt, prefix, str);
	write_u32(m, l);
	write_arbitrary(m, b, l);
}

static void write_dict(struct message *m, struct spa_dict *dict, bool remap)
{
	const struct spa_dict_item *it;

	write_8(m, TAG_PROPLIST);
	if (dict != NULL) {
		const char *media_class = NULL, *media_role = NULL;
		spa_dict_for_each(it, dict) {
			const char *key = it->key;
			const char *val = it->value;
			int l;
			const struct str_map *map;

			if (remap && (map = str_map_find(key_table, key, NULL)) != NULL) {
				key = map->pa_str;
				if (map->child != NULL &&
				    (map = str_map_find(map->child, val, NULL)) != NULL)
					val = map->pa_str;
			}
			if (strcmp(key, "media.class") == 0)
				media_class = val;
			if (strcmp(key, "media.role") == 0)
				media_role = val;

			write_string(m, key);
			l = strlen(val) + 1;
			write_u32(m, l);
			write_arbitrary(m, val, l);

		}
		if (remap)
			add_stream_group(m, dict, "module-stream-restore.id",
					media_class, media_role);
	}
	write_string(m, NULL);
}

static void write_format_info(struct message *m, struct format_info *info)
{
	write_8(m, TAG_FORMAT_INFO);
	write_u8(m, (uint8_t) info->encoding);
	write_dict(m, info->props ? &info->props->dict : NULL, false);
}

static int message_put(struct message *m, ...)
{
	va_list va;

	if (m == NULL)
		return -EINVAL;

	va_start(va, m);

	while (true) {
		int tag = va_arg(va, int);
		if (tag == TAG_INVALID)
			break;

		switch (tag) {
		case TAG_STRING:
			write_string(m, va_arg(va, const char *));
			break;
		case TAG_U8:
			write_u8(m, (uint8_t)va_arg(va, int));
			break;
		case TAG_U32:
			write_u32(m, (uint32_t)va_arg(va, uint32_t));
			break;
		case TAG_S64:
		case TAG_U64:
		case TAG_USEC:
			write_64(m, tag, va_arg(va, uint64_t));
			break;
		case TAG_SAMPLE_SPEC:
			write_sample_spec(m, va_arg(va, struct sample_spec*));
			break;
		case TAG_ARBITRARY:
		{
			const void *p = va_arg(va, const void*);
			size_t length = va_arg(va, size_t);
			write_arbitrary(m, p, length);
			break;
		}
		case TAG_BOOLEAN:
			write_boolean(m, va_arg(va, int));
			break;
		case TAG_TIMEVAL:
			write_timeval(m, va_arg(va, struct timeval*));
			break;
		case TAG_CHANNEL_MAP:
			write_channel_map(m, va_arg(va, struct channel_map*));
			break;
		case TAG_CVOLUME:
			write_cvolume(m, va_arg(va, struct volume*));
			break;
		case TAG_PROPLIST:
			write_dict(m, va_arg(va, struct spa_dict*), true);
			break;
		case TAG_VOLUME:
			write_volume(m, va_arg(va, double));
			break;
		case TAG_FORMAT_INFO:
			write_format_info(m, va_arg(va, struct format_info*));
			break;
		}
	}
	va_end(va);

	if (m->length > m->allocated)
		return -ENOMEM;

	return 0;
}

static int message_dump(enum spa_log_level level, struct message *m)
{
	int res;
	uint32_t i, offset = m->offset, o;

	pw_log(level, "message: len:%d alloc:%u", m->length, m->allocated);
	while (true) {
		uint8_t tag;

		o = m->offset;
		if (read_u8(m, &tag) < 0)
			break;

		switch (tag) {
		case TAG_STRING:
		{
			char *val;
			if ((res = read_string(m, &val)) < 0)
				return res;
			pw_log(level, "%u: string: '%s'", o, val);
			break;
			}
		case TAG_STRING_NULL:
			pw_log(level, "%u: string: NULL", o);
			break;
		case TAG_U8:
		{
			uint8_t val;
			if ((res = read_u8(m, &val)) < 0)
				return res;
			pw_log(level, "%u: u8: %u", o, val);
			break;
		}
		case TAG_U32:
		{
			uint32_t val;
			if ((res = read_u32(m, &val)) < 0)
				return res;
			pw_log(level, "%u: u32: %u", o, val);
			break;
		}
		case TAG_S64:
		{
			uint64_t val;
			if ((res = read_u64(m, &val)) < 0)
				return res;
			pw_log(level, "%u: s64: %"PRIi64"", o, (int64_t)val);
			break;
		}
		case TAG_U64:
		{
			uint64_t val;
			if ((res = read_u64(m, &val)) < 0)
				return res;
			pw_log(level, "%u: u64: %"PRIu64"", o, val);
			break;
		}
		case TAG_USEC:
		{
			uint64_t val;
			if ((res = read_u64(m, &val)) < 0)
				return res;
			pw_log(level, "%u: u64: %"PRIu64"", o, val);
			break;
		}
		case TAG_SAMPLE_SPEC:
		{
			struct sample_spec ss;
			if ((res = read_sample_spec(m, &ss)) < 0)
				return res;
			pw_log(level, "%u: ss: format:%s rate:%d channels:%u", o,
					format_id2name(ss.format), ss.rate,
					ss.channels);
			break;
		}
		case TAG_ARBITRARY:
		{
			const void *mem;
			size_t len;
			if ((res = read_arbitrary(m, &mem, &len)) < 0)
				return res;
			spa_debug_mem(0, mem, len);
			break;
		}
		case TAG_BOOLEAN_TRUE:
			pw_log(level, "%u: bool: true", o);
			break;
		case TAG_BOOLEAN_FALSE:
			pw_log(level, "%u: bool: false", o);
			break;
		case TAG_TIMEVAL:
		{
			struct timeval tv;
			if ((res = read_timeval(m, &tv)) < 0)
				return res;
			pw_log(level, "%u: timeval: %lu:%lu", o, tv.tv_sec, tv.tv_usec);
			break;
		}
		case TAG_CHANNEL_MAP:
		{
			struct channel_map map;
			if ((res = read_channel_map(m, &map)) < 0)
				return res;
			pw_log(level, "%u: channelmap: channels:%u", o, map.channels);
			for (i = 0; i < map.channels; i++)
				pw_log(level, "    %d: %s", i, channel_id2name(map.map[i]));
			break;
		}
		case TAG_CVOLUME:
		{
			struct volume vol;
			if ((res = read_cvolume(m, &vol)) < 0)
				return res;
			pw_log(level, "%u: cvolume: channels:%u", o, vol.channels);
			for (i = 0; i < vol.channels; i++)
				pw_log(level, "    %d: %f", i, vol.values[i]);
			break;
		}
		case TAG_PROPLIST:
		{
			struct pw_properties *props = pw_properties_new(NULL, NULL);
			const struct spa_dict_item *it;
			res = read_props(m, props, false);
			if (res >= 0) {
				pw_log(level, "%u: props: n_items:%u", o, props->dict.n_items);
				spa_dict_for_each(it, &props->dict)
					pw_log(level, "     '%s': '%s'", it->key, it->value);
			}
			pw_properties_free(props);
			if (res < 0)
				return res;
			break;
		}
		case TAG_VOLUME:
		{
			float vol;
			if ((res = read_volume(m, &vol)) < 0)
				return res;
			pw_log(level, "%u: volume: %f", o, vol);
			break;
		}
		case TAG_FORMAT_INFO:
		{
			struct format_info info;
			const struct spa_dict_item *it;
			if ((res = read_format_info(m, &info)) < 0)
				return res;
			pw_log(level, "%u: format-info: enc:%s n_items:%u",
					o, format_encoding2name(info.encoding),
					info.props->dict.n_items);
			spa_dict_for_each(it, &info.props->dict)
				pw_log(level, "     '%s': '%s'", it->key, it->value);
			break;
		}
		}
	}
	m->offset = offset;

	return 0;
}
