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

#include <stdio.h>
#include <stdarg.h>
#include <spa/utils/json.h>

#include "pipewire/array.h"
#include "pipewire/utils.h"
#include "pipewire/properties.h"

/** \cond */
struct properties {
	struct pw_properties this;

	struct pw_array items;
};
/** \endcond */

static int add_func(struct pw_properties *this, char *key, char *value)
{
	struct spa_dict_item *item;
	struct properties *impl = SPA_CONTAINER_OF(this, struct properties, this);

	item = pw_array_add(&impl->items, sizeof(struct spa_dict_item));
	if (item == NULL) {
		free(key);
		free(value);
		return -errno;
	}

	item->key = key;
	item->value = value;

	this->dict.items = impl->items.data;
	this->dict.n_items++;
	return 0;
}

static void clear_item(struct spa_dict_item *item)
{
	free((char *) item->key);
	free((char *) item->value);
}

static int find_index(const struct pw_properties *this, const char *key)
{
	const struct spa_dict_item *item;
	item = spa_dict_lookup_item(&this->dict, key);
	if (item == NULL)
		return -1;
	return item - this->dict.items;
}

static struct properties *properties_new(int prealloc)
{
	struct properties *impl;

	impl = calloc(1, sizeof(struct properties));
	if (impl == NULL)
		return NULL;

	pw_array_init(&impl->items, 16);
	pw_array_ensure_size(&impl->items, sizeof(struct spa_dict_item) * prealloc);

	return impl;
}

/** Make a new properties object
 *
 * \param key a first key
 * \param ... value and more keys NULL terminated
 * \return a newly allocated properties object
 *
 * \memberof pw_properties
 */
SPA_EXPORT
struct pw_properties *pw_properties_new(const char *key, ...)
{
	struct properties *impl;
	va_list varargs;
	const char *value;

	impl = properties_new(16);
	if (impl == NULL)
		return NULL;

	va_start(varargs, key);
	while (key != NULL) {
		value = va_arg(varargs, char *);
		if (value && key[0])
			add_func(&impl->this, strdup(key), strdup(value));
		key = va_arg(varargs, char *);
	}
	va_end(varargs);

	return &impl->this;
}

/** Make a new properties object from the given dictionary
 *
 * \param dict a dictionary. keys and values are copied
 * \return a new properties object
 *
 * \memberof pw_properties
 */
SPA_EXPORT
struct pw_properties *pw_properties_new_dict(const struct spa_dict *dict)
{
	uint32_t i;
	struct properties *impl;

	impl = properties_new(SPA_ROUND_UP_N(dict->n_items, 16));
	if (impl == NULL)
		return NULL;

	for (i = 0; i < dict->n_items; i++) {
		const struct spa_dict_item *it = &dict->items[i];
		if (it->key != NULL && it->key[0] && it->value != NULL)
			add_func(&impl->this, strdup(it->key),
				 strdup(it->value));
	}

	return &impl->this;
}

SPA_EXPORT
int pw_properties_update_string(struct pw_properties *props, const char *str, size_t size)
{
	struct properties *impl = SPA_CONTAINER_OF(props, struct properties, this);
	struct spa_json it[2];
	char key[1024], *val;
	int count = 0;

	spa_json_init(&it[0], str, size);
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		spa_json_init(&it[1], str, size);

	while (spa_json_get_string(&it[1], key, sizeof(key)-1)) {
		int len;
		const char *value;

		if ((len = spa_json_next(&it[1], &value)) <= 0)
			break;

		if (key[0] == '#')
			continue;
		if (spa_json_is_null(value, len))
			val = NULL;
		else {
			if (spa_json_is_container(value, len))
				len = spa_json_container_len(&it[1], value, len);

			if ((val = malloc(len+1)) != NULL)
				spa_json_parse_string(value, len, val);
		}
		count += pw_properties_set(&impl->this, key, val);
		free(val);
	}
	return count;
}

/** Make a new properties object from the given str
 *
 * \a str should be a whitespace separated list of key=value
 * strings or a json object.
 *
 * \param args a property description
 * \return a new properties object
 *
 * \memberof pw_properties
 */
SPA_EXPORT
struct pw_properties *
pw_properties_new_string(const char *object)
{
	struct properties *impl;
	int res;

	impl = properties_new(16);
	if (impl == NULL)
		return NULL;

	if ((res = pw_properties_update_string(&impl->this, object, strlen(object))) < 0)
		goto error;

	return &impl->this;
error:
	pw_properties_free(&impl->this);
	errno = -res;
	return NULL;
}

/** Copy a properties object
 *
 * \param properties properties to copy
 * \return a new properties object
 *
 * \memberof pw_properties
 */
SPA_EXPORT
struct pw_properties *pw_properties_copy(const struct pw_properties *properties)
{
	return pw_properties_new_dict(&properties->dict);
}

/** Copy multiple keys from one property to another
 *
 * \param src properties to copy from
 * \param dst properties to copy to
 * \param keys a NULL terminated list of keys to copy
 * \return the number of keys changed in \a dest
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_update_keys(struct pw_properties *props,
		const struct spa_dict *dict, const char *keys[])
{
	int i, changed = 0;
	const char *str;

	for (i = 0; keys[i]; i++) {
		if ((str = spa_dict_lookup(dict, keys[i])) != NULL)
			changed += pw_properties_set(props, keys[i], str);
	}
	return changed;
}

static bool has_key(const char *keys[], const char *key)
{
	int i;
	for (i = 0; keys[i]; i++) {
		if (strcmp(keys[i], key) == 0)
			return true;
	}
	return false;
}

SPA_EXPORT
int pw_properties_update_ignore(struct pw_properties *props,
		const struct spa_dict *dict, const char *ignore[])
{
	const struct spa_dict_item *it;
	int changed = 0;

	spa_dict_for_each(it, dict) {
		if (ignore == NULL || !has_key(ignore, it->key))
			changed += pw_properties_set(props, it->key, it->value);
	}
	return changed;
}

/** Clear a properties object
 *
 * \param properties properties to clear
 *
 * \memberof pw_properties
 */
SPA_EXPORT
void pw_properties_clear(struct pw_properties *properties)
{
	struct properties *impl = SPA_CONTAINER_OF(properties, struct properties, this);
	struct spa_dict_item *item;

	pw_array_for_each(item, &impl->items)
		clear_item(item);
	pw_array_reset(&impl->items);
	properties->dict.n_items = 0;
}

/** Update properties
 *
 * \param props properties to update
 * \param dict new properties
 * \return the number of changed properties
 *
 * The properties in \a props are updated with \a dict. Keys in \a dict
 * with NULL values are removed from \a props.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_update(struct pw_properties *props,
		         const struct spa_dict *dict)
{
	const struct spa_dict_item *it;
	int changed = 0;

	spa_dict_for_each(it, dict)
		changed += pw_properties_set(props, it->key, it->value);

	return changed;
}

/** Add properties
 *
 * \param props properties to add
 * \param dict new properties
 * \return the number of added properties
 *
 * The properties from \a dict that are not yet in \a props are added.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_add(struct pw_properties *props,
		         const struct spa_dict *dict)
{
	uint32_t i;
	int added = 0;

	for (i = 0; i < dict->n_items; i++) {
		if (pw_properties_get(props, dict->items[i].key) == NULL)
			added += pw_properties_set(props, dict->items[i].key, dict->items[i].value);
	}
	return added;
}

/** Add keys
 *
 * \param props properties to add
 * \param dict new properties
 * \param keys a NULL terminated list of keys to add
 * \return the number of added properties
 *
 * The properties with \a keys from \a dict that are not yet
 * in \a props are added.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_add_keys(struct pw_properties *props,
		const struct spa_dict *dict, const char *keys[])
{
	uint32_t i;
	int added = 0;
	const char *str;

	for (i = 0; keys[i]; i++) {
		if ((str = spa_dict_lookup(dict, keys[i])) == NULL)
			continue;
		if (pw_properties_get(props, keys[i]) == NULL)
			added += pw_properties_set(props, keys[i], str);
	}
	return added;
}

/** Free a properties object
 *
 * \param properties the properties to free
 *
 * \memberof pw_properties
 */
SPA_EXPORT
void pw_properties_free(struct pw_properties *properties)
{
	struct properties *impl = SPA_CONTAINER_OF(properties, struct properties, this);
	pw_properties_clear(properties);
	pw_array_clear(&impl->items);
	free(impl);
}

static int do_replace(struct pw_properties *properties, const char *key, char *value, bool copy)
{
	struct properties *impl = SPA_CONTAINER_OF(properties, struct properties, this);
	int index;

	if (key == NULL || key[0] == 0)
		goto exit_noupdate;

	index = find_index(properties, key);

	if (index == -1) {
		if (value == NULL)
			return 0;
		add_func(properties, strdup(key), copy ? strdup(value) : value);
		SPA_FLAG_CLEAR(properties->dict.flags, SPA_DICT_FLAG_SORTED);
	} else {
		struct spa_dict_item *item =
		    pw_array_get_unchecked(&impl->items, index, struct spa_dict_item);

		if (value && strcmp(item->value, value) == 0)
			goto exit_noupdate;

		if (value == NULL) {
			struct spa_dict_item *last = pw_array_get_unchecked(&impl->items,
						     pw_array_get_len(&impl->items, struct spa_dict_item) - 1,
						     struct spa_dict_item);
			clear_item(item);
			item->key = last->key;
			item->value = last->value;
			impl->items.size -= sizeof(struct spa_dict_item);
			properties->dict.n_items--;
			SPA_FLAG_CLEAR(properties->dict.flags, SPA_DICT_FLAG_SORTED);
		} else {
			free((char *) item->value);
			item->value = copy ? strdup(value) : value;
		}
	}
	return 1;
exit_noupdate:
	if (!copy)
		free(value);
	return 0;
}

/** Set a property value
 *
 * \param properties the properties to change
 * \param key a key
 * \param value a value or NULL to remove the key
 * \return 1 if the properties were changed. 0 if nothing was changed because
 *  the property already existed with the same value or because the key to remove
 *  did not exist.
 *
 * Set the property in \a properties with \a key to \a value. Any previous value
 * of \a key will be overwritten. When \a value is NULL, the key will be
 * removed.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_set(struct pw_properties *properties, const char *key, const char *value)
{
	return do_replace(properties, key, (char*)value, true);
}

SPA_EXPORT
int pw_properties_setva(struct pw_properties *properties,
		   const char *key, const char *format, va_list args)
{
	char *value = NULL;
	if (format != NULL) {
		if (vasprintf(&value, format, args) < 0)
			return -errno;
	}
	return do_replace(properties, key, value, false);
}

/** Set a property value by format
 *
 * \param properties a \ref pw_properties
 * \param key a key
 * \param format a value
 * \param ... extra arguments
 * \return 1 if the property was changed. 0 if nothing was changed because
 *  the property already existed with the same value or because the key to remove
 *  did not exist.
 *
 * Set the property in \a properties with \a key to the value in printf style \a format
 * Any previous value of \a key will be overwritten.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
int pw_properties_setf(struct pw_properties *properties, const char *key, const char *format, ...)
{
	int res;
	va_list varargs;

	va_start(varargs, format);
	res = pw_properties_setva(properties, key, format, varargs);
	va_end(varargs);

	return res;
}

/** Get a property
 *
 * \param properties a \ref pw_properties
 * \param key a key
 * \return the property for \a key or NULL when the key was not found
 *
 * Get the property in \a properties with \a key.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
const char *pw_properties_get(const struct pw_properties *properties, const char *key)
{
	struct properties *impl = SPA_CONTAINER_OF(properties, struct properties, this);
	int index = find_index(properties, key);

	if (index == -1)
		return NULL;

	return pw_array_get_unchecked(&impl->items, index, struct spa_dict_item)->value;
}

/** Iterate property values
 *
 * \param properties a \ref pw_properties
 * \param state state
 * \return The next key or NULL when there are no more keys to iterate.
 *
 * Iterate over \a properties, returning each key in turn. \a state should point
 * to a pointer holding NULL to get the first element and will be updated
 * after each iteration. When NULL is returned, all elements have been
 * iterated.
 *
 * \memberof pw_properties
 */
SPA_EXPORT
const char *pw_properties_iterate(const struct pw_properties *properties, void **state)
{
	struct properties *impl = SPA_CONTAINER_OF(properties, struct properties, this);
	uint32_t index;

	if (*state == NULL)
		index = 0;
	else
		index = SPA_PTR_TO_INT(*state);

	if (!pw_array_check_index(&impl->items, index, struct spa_dict_item))
		 return NULL;

	*state = SPA_INT_TO_PTR(index + 1);

	return pw_array_get_unchecked(&impl->items, index, struct spa_dict_item)->key;
}
