/* Metadata API
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

#include "pipewire/pipewire.h"
#include "pipewire/array.h"

#include <extensions/metadata.h>

#include "media-session.h"

#define NAME "metadata"

#define pw_metadata_emit(hooks,method,version,...)			\
	spa_hook_list_call_simple(hooks, struct pw_metadata_events,	\
				method, version, ##__VA_ARGS__)

#define pw_metadata_emit_property(hooks,...)	pw_metadata_emit(hooks,property, 0, ##__VA_ARGS__)

struct item {
	uint32_t subject;
	char *key;
	char *type;
	char *value;
};

static void clear_item(struct item *item)
{
	free(item->key);
	free(item->type);
	free(item->value);
	spa_zero(*item);
}

static void set_item(struct item *item, uint32_t subject, const char *key, const char *type, const char *value)
{
	item->subject = subject;
	item->key = strdup(key);
	item->type = type ? strdup(type) : NULL;
	item->value = strdup(value);
}

static inline int strzcmp(const char *s1, const char *s2)
{
	if (s1 == s2)
		return 0;
	if (s1 == NULL || s2 == NULL)
		return 1;
	return strcmp(s1, s2);
}

static int change_item(struct item *item, const char *type, const char *value)
{
	int changed = 0;
	if (strzcmp(item->type, type) != 0) {
		free((char*)item->type);
		item->type = type ? strdup(type) : NULL;
		changed++;
	}
	if (strzcmp(item->value, value) != 0) {
		free((char*)item->value);
		item->value = value ? strdup(value) : NULL;
		changed++;
	}
	return changed;
}

struct metadata {
	struct spa_interface iface;

	struct spa_hook_list hooks;
	struct pw_array metadata;

	struct sm_media_session *session;
	struct spa_hook session_listener;
	struct pw_proxy *proxy;

	unsigned int shutdown:1;
};

static void emit_properties(struct metadata *this)
{
	struct item *item;
	pw_array_for_each(item, &this->metadata) {
		pw_log_debug("metadata %p: %d %s %s %s",
				this, item->subject, item->key, item->type, item->value);
		pw_metadata_emit_property(&this->hooks,
				item->subject,
				item->key,
				item->type,
				item->value);
	}
}

static int impl_add_listener(void *object,
		struct spa_hook *listener,
		const struct pw_metadata_events *events,
		void *data)
{
	struct metadata *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	pw_log_debug("metadata %p:", this);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	emit_properties(this);

	spa_hook_list_join(&this->hooks, &save);

        return 0;
}

static struct item *find_item(struct metadata *this, uint32_t subject, const char *key)
{
	struct item *item;

	pw_array_for_each(item, &this->metadata) {
		if (item->subject == subject && (key == NULL || !strcmp(item->key, key)))
			return item;
	}
	return NULL;
}

static int clear_subjects(struct metadata *this, uint32_t subject)
{
	struct item *item;
	uint32_t removed = 0;

	while (true) {
		item = find_item(this, subject, NULL);
		if (item == NULL)
			break;

		pw_log_debug(NAME" %p: remove id:%d key:%s", this, subject, item->key);

		clear_item(item);
		pw_array_remove(&this->metadata, item);
		removed++;
	}
	if (removed > 0 && !this->shutdown)
		pw_metadata_emit_property(&this->hooks, subject, NULL, NULL, NULL);
	return 0;
}

static void clear_items(struct metadata *this)
{
	struct item *item;
	pw_array_consume(item, &this->metadata)
		clear_subjects(this, item->subject);
	pw_array_reset(&this->metadata);
}

static int impl_set_property(void *object,
			uint32_t subject,
			const char *key,
			const char *type,
			const char *value)
{
	struct metadata *this = object;
	struct item *item = NULL;
	int changed = 0;

	pw_log_debug(NAME" %p: id:%d key:%s type:%s value:%s", this, subject, key, type, value);

	if (key == NULL)
		return clear_subjects(this, subject);

	item = find_item(this, subject, key);
	if (value == NULL) {
		if (item != NULL) {
			clear_item(item);
			pw_array_remove(&this->metadata, item);
			type = NULL;
			changed++;
			pw_log_info(NAME" %p: remove id:%d key:%s", this,
					subject, key);
		}
	} else if (item == NULL) {
		item = pw_array_add(&this->metadata, sizeof(*item));
		if (item == NULL)
			return -errno;
		set_item(item, subject, key, type, value);
		changed++;
		pw_log_info(NAME" %p: add id:%d key:%s type:%s value:%s", this,
				subject, key, type, value);
	} else {
		if (type == NULL)
			type = item->type;
		changed = change_item(item, type, value);
		if (changed)
			pw_log_info(NAME" %p: change id:%d key:%s type:%s value:%s", this,
				subject, key, type, value);
	}

	if (changed)
		pw_metadata_emit_property(&this->hooks,
					subject, key, type, value);
	return 0;
}

static int impl_clear(void *object)
{
	struct metadata *this = object;
	clear_items(this);
	return 0;
}

static const struct pw_metadata_methods impl_metadata = {
	PW_VERSION_METADATA_METHODS,
	.add_listener = impl_add_listener,
	.set_property = impl_set_property,
	.clear = impl_clear,
};

static void session_remove(void *data, struct sm_object *object)
{
	struct metadata *this = data;
	clear_subjects(this, object->id);
}

static void session_shutdown(void *data)
{
	struct metadata *this = data;
	this->shutdown = true;
}

static void session_destroy(void *data)
{
	struct metadata *this = data;

	spa_hook_remove(&this->session_listener);
	pw_proxy_destroy(this->proxy);

	clear_items(this);
	pw_array_clear(&this->metadata);
	free(this);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.shutdown = session_shutdown,
	.destroy = session_destroy,
	.remove = session_remove,
};

struct pw_metadata *sm_media_session_export_metadata(struct sm_media_session *sess,
		const char *name)
{
	struct metadata *this;
	int res;
	struct spa_dict_item items[1];

	this = calloc(1, sizeof(*this));
	if (this == NULL)
		goto error_errno;

	pw_array_init(&this->metadata, 4096);

	this->iface = SPA_INTERFACE_INIT(
			PW_TYPE_INTERFACE_Metadata,
			PW_VERSION_METADATA,
			&impl_metadata, this);
        spa_hook_list_init(&this->hooks);

	items[0] = SPA_DICT_ITEM_INIT(PW_KEY_METADATA_NAME, name);

	this->session = sess;
	this->proxy = sm_media_session_export(sess,
			PW_TYPE_INTERFACE_Metadata,
			&SPA_DICT_INIT_ARRAY(items),
			&this->iface,
			0);
	if (this->proxy == NULL)
		goto error_errno;

	sm_media_session_add_listener(sess, &this->session_listener,
			&session_events, this);

	return (struct pw_metadata*)&this->iface;

error_errno:
	res = -errno;
	goto error_free;
error_free:
	free(this);
	errno = -res;
	return NULL;
}
