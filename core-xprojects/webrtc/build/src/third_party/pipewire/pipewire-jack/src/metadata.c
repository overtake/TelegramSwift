/* PipeWire
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>

#include <jack/metadata.h>
#include <jack/uuid.h>

#include <pipewire/pipewire.h>
#include <extensions/metadata.h>

static jack_description_t *find_description(jack_uuid_t subject)
{
	jack_description_t *desc;
	pw_array_for_each(desc, &globals.descriptions) {
		if (jack_uuid_compare(desc->subject, subject) == 0)
			return desc;
	}
	return NULL;
}

static void set_property(jack_property_t *prop, const char *key, const char *value, const char *type)
{
	prop->key = strdup(key);
	prop->data = strdup(value);
	prop->type = strdup(type);
}

static jack_property_t *copy_properties(jack_property_t *src, uint32_t cnt)
{
	jack_property_t *dst;
	uint32_t i;
	dst = malloc(sizeof(jack_property_t) * cnt);
	if (dst != NULL) {
		for (i = 0; i < cnt; i++)
			set_property(&dst[i], src[i].key, src[i].data, src[i].type);
	}
	return dst;
}

static int copy_description(jack_description_t *dst, jack_description_t *src)
{
	dst->properties = copy_properties(src->properties, src->property_cnt);
	if (dst->properties == NULL)
		return -errno;
	jack_uuid_copy(&dst->subject, src->subject);
	dst->property_cnt = src->property_cnt;
	dst->property_size = src->property_size;
	return dst->property_cnt;
}

static jack_description_t *add_description(jack_uuid_t subject)
{
	jack_description_t *desc;
	desc = pw_array_add(&globals.descriptions, sizeof(*desc));
	if (desc != NULL) {
		spa_zero(*desc);
		jack_uuid_copy(&desc->subject, subject);
	}
	return desc;
}

static void remove_description(jack_description_t *desc)
{
	jack_free_description(desc, false);
	pw_array_remove(&globals.descriptions, desc);
}

static jack_property_t *find_property(jack_description_t *desc, const char *key)
{
	uint32_t i;
	for (i = 0; i < desc->property_cnt; i++) {
		jack_property_t *prop = &desc->properties[i];
		if (strcmp(prop->key, key) == 0)
			return prop;
	}
	return NULL;
}

static jack_property_t *add_property(jack_description_t *desc, const char *key,
		const char *value, const char *type)
{
	jack_property_t *prop;

	if (desc->property_cnt == desc->property_size) {
		desc->property_size = desc->property_size > 0 ? desc->property_size * 2 : 8;
		desc->properties = realloc(desc->properties, sizeof(*prop) * desc->property_size);
	}
	prop = &desc->properties[desc->property_cnt++];
	set_property(prop, key, value, type);
	return prop;
}

static void clear_property(jack_property_t *prop)
{
	free((char*)prop->key);
	free((char*)prop->data);
	free((char*)prop->type);
}

static void remove_property(jack_description_t *desc, jack_property_t *prop)
{
	clear_property(prop);
	desc->property_cnt--;
        memmove(desc->properties, SPA_MEMBER(prop, sizeof(*prop), void),
                SPA_PTRDIFF(SPA_MEMBER(desc->properties, sizeof(*prop) * desc->property_cnt, void),
			prop));

	if (desc->property_cnt == 0)
		remove_description(desc);
}

static inline int strzcmp(const char *s1, const char *s2)
{
	if (s1 == s2)
		return 0;
	if (s1 == NULL || s2 == NULL)
		return 1;
	return strcmp(s1, s2);
}

static int change_property(jack_property_t *prop, const char *value, const char *type)
{
	int changed = 0;
	if (strzcmp(prop->data, value) != 0) {
		free((char*)prop->data);
		prop->data = strdup(value);
		changed++;
	}
	if (strzcmp(prop->type, type) != 0) {
		free((char*)prop->type);
		prop->type = strdup(type);
		changed++;
	}
	return changed;
}

static int update_property(struct client *c,
		      jack_uuid_t subject,
		      const char* key,
		      const char* type,
		      const char* value)
{
	jack_property_change_t change;
	jack_description_t *desc;
	int changed = 0;

	pthread_mutex_lock(&globals.lock);
	desc = find_description(subject);

	if (key == NULL) {
		if (desc != NULL) {
			remove_description(desc);
			change = PropertyDeleted;
			changed++;
		}
	} else {
		jack_property_t *prop;

		prop = desc ? find_property(desc, key) : NULL;

		if (value == NULL || type == NULL) {
			if (prop != NULL) {
				remove_property(desc, prop);
				change = PropertyDeleted;
				changed++;
			}
		} else if (prop == NULL) {
			if (desc == NULL)
				desc = add_description(subject);
			prop = add_property(desc, key, value, type);
			change = PropertyCreated;
			changed++;
		} else {
			changed = change_property(prop, value, type);
			change = PropertyChanged;
		}
	}
	pthread_mutex_unlock(&globals.lock);

	if (c->property_callback && changed)
		c->property_callback(subject, key, change, c->property_arg);

	return 0;
}


SPA_EXPORT
int jack_set_property(jack_client_t*client,
		      jack_uuid_t subject,
		      const char* key,
		      const char* value,
		      const char* type)
{
	struct client *c = (struct client *) client;
	uint32_t id;
	int res = -1;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(key != NULL, -EINVAL);
	spa_return_val_if_fail(value != NULL, -EINVAL);

	pw_thread_loop_lock(c->context.loop);
	if (c->metadata == NULL)
		goto done;

	id = jack_uuid_to_index(subject);

	if (type == NULL)
		type = "";

	pw_log_info("set id:%u (%"PRIu64") '%s' to '%s@%s'", id, subject, key, value, type);
	update_property(c, id, key, type, value);
	pw_metadata_set_property(c->metadata->proxy, id, key, type, value);
	res = 0;
done:
	pw_thread_loop_unlock(c->context.loop);

	return res;
}

SPA_EXPORT
int jack_get_property(jack_uuid_t subject,
		      const char* key,
		      char**      value,
		      char**      type)
{
	jack_description_t *desc;
	jack_property_t *prop;
	int res = -1;

	pthread_mutex_lock(&globals.lock);
	desc = find_description(subject);
	if (desc == NULL)
		goto done;

	prop = find_property(desc, key);
	if (prop == NULL)
		goto done;

	*value = strdup(prop->data);
	*type = strdup(prop->type);
	res = 0;

	pw_log_debug("subject:%"PRIu64" key:'%s' value:'%s' type:'%s'",
			subject, key, *value, *type);
done:
	pthread_mutex_unlock(&globals.lock);
	return res;
}

SPA_EXPORT
void jack_free_description (jack_description_t* desc, int free_description_itself)
{
	uint32_t n;

	for (n = 0; n < desc->property_cnt; ++n)
		clear_property(&desc->properties[n]);
	free(desc->properties);
	if (free_description_itself)
		free(desc);
}

SPA_EXPORT
int jack_get_properties (jack_uuid_t         subject,
			 jack_description_t* desc)
{
	jack_description_t *d;
	int res = -1;

	spa_return_val_if_fail(desc != NULL, -EINVAL);

	pthread_mutex_lock(&globals.lock);
	d = find_description(subject);
	if (d == NULL)
		goto done;

	res = copy_description(desc, d);
done:
	pthread_mutex_unlock(&globals.lock);
	return res;
}

SPA_EXPORT
int jack_get_all_properties (jack_description_t** result)
{
	uint32_t i;
	jack_description_t *dst, *src;
	struct pw_array *descriptions;
	uint32_t len;

	pthread_mutex_lock(&globals.lock);
	descriptions = &globals.descriptions;
	len = pw_array_get_len(descriptions, jack_description_t);
	src = descriptions->data;
	dst = malloc(descriptions->size);
	for (i = 0; i < len; i++)
		copy_description(&dst[i], &src[i]);
	*result = dst;
	pthread_mutex_unlock(&globals.lock);

	return len;
}

SPA_EXPORT
int jack_remove_property (jack_client_t* client, jack_uuid_t subject, const char* key)
{
	struct client *c = (struct client *) client;
	uint32_t id;
	int res = -1;

	spa_return_val_if_fail(c != NULL, -EINVAL);
	spa_return_val_if_fail(key != NULL, -EINVAL);

	pw_thread_loop_lock(c->context.loop);

	if (c->metadata == NULL)
		goto done;

	id = jack_uuid_to_index(subject);

	pw_log_info("remove id:%u (%"PRIu64") '%s'", id, subject, key);
	pw_metadata_set_property(c->metadata->proxy,
			id, key, NULL, NULL);
	res = 0;
done:
	pw_thread_loop_unlock(c->context.loop);

	return res;
}

SPA_EXPORT
int jack_remove_properties (jack_client_t* client, jack_uuid_t subject)
{
	struct client *c = (struct client *) client;
	uint32_t id;
	int res = -1;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	pw_thread_loop_lock(c->context.loop);
	if (c->metadata == NULL)
		goto done;

	id = jack_uuid_to_index(subject);

	pw_log_info("remove id:%u (%"PRIu64")", id, subject);
	pw_metadata_set_property(c->metadata->proxy,
			id, NULL, NULL, NULL);
	res = 0;
done:
	pw_thread_loop_unlock(c->context.loop);

	return res;
}

SPA_EXPORT
int jack_remove_all_properties (jack_client_t* client)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	pw_thread_loop_lock(c->context.loop);
	pw_metadata_clear(c->metadata->proxy);
	pw_thread_loop_unlock(c->context.loop);

	return 0;
}

SPA_EXPORT
int jack_set_property_change_callback (jack_client_t*             client,
                                       JackPropertyChangeCallback callback,
                                       void*                      arg)
{
	struct client *c = (struct client *) client;

	spa_return_val_if_fail(c != NULL, -EINVAL);

	c->property_callback = callback;
	c->property_arg = arg;
	return 0;
}
