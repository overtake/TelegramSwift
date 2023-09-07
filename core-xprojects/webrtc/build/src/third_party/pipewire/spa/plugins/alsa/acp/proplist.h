/* ALSA Card Profile
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

#ifndef PA_PROPLIST_H
#define PA_PROPLIST_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

#include "array.h"
#include "acp.h"

#define PA_PROP_DEVICE_DESCRIPTION             "device.description"

#define PA_PROP_DEVICE_CLASS                   "device.class"

#define PA_PROP_DEVICE_FORM_FACTOR             "device.form_factor"

#define PA_PROP_DEVICE_INTENDED_ROLES          "device.intended_roles"

#define PA_PROP_DEVICE_PROFILE_NAME            "device.profile.name"

#define PA_PROP_DEVICE_STRING                  "device.string"

#define PA_PROP_DEVICE_API                     "device.api"

#define PA_PROP_DEVICE_PRODUCT_NAME            "device.product.name"

#define PA_PROP_DEVICE_PROFILE_DESCRIPTION     "device.profile.description"

typedef struct pa_proplist_item {
	char *key;
	char *value;
} pa_proplist_item;

typedef struct pa_proplist {
	struct pa_array array;
} pa_proplist;

static inline pa_proplist* pa_proplist_new(void)
{
	pa_proplist *p = calloc(1, sizeof(*p));
	pa_array_init(&p->array, 16);
	return p;
}
static inline pa_proplist_item* pa_proplist_item_find(const pa_proplist *p, const void *key)
{
	pa_proplist_item *item;
	pa_array_for_each(item, &p->array) {
		if (strcmp(key, item->key) == 0)
			return item;
	}
	return NULL;
}

static inline void pa_proplist_item_free(pa_proplist_item* it)
{
	free(it->key);
	free(it->value);
}

static inline void pa_proplist_clear(pa_proplist* p)
{
	pa_proplist_item *item;
	pa_array_for_each(item, &p->array)
		pa_proplist_item_free(item);
	pa_array_reset(&p->array);
}

static inline void pa_proplist_free(pa_proplist* p)
{
	pa_proplist_clear(p);
	pa_array_clear(&p->array);
	free(p);
}

static inline unsigned pa_proplist_size(const pa_proplist *p)
{
	return pa_array_get_len(&p->array, pa_proplist_item);
}

static inline int pa_proplist_contains(const pa_proplist *p, const char *key)
{
	return pa_proplist_item_find(p, key) ? 1 : 0;
}

static inline int pa_proplist_sets(pa_proplist *p, const char *key, const char *value)
{
	pa_proplist_item *item = pa_proplist_item_find(p, key);
	if (item != NULL)
		pa_proplist_item_free(item);
        else
                item = pa_array_add(&p->array, sizeof(*item));
	item->key = strdup(key);
	item->value = strdup(value);
	return 0;
}

static inline int pa_proplist_unset(pa_proplist *p, const char *key)
{
	pa_proplist_item *item = pa_proplist_item_find(p, key);
	if (item == NULL)
		return -ENOENT;
	pa_proplist_item_free(item);
	pa_array_remove(&p->array, item);
	return 0;
}

static PA_PRINTF_FUNC(3,4) inline int pa_proplist_setf(pa_proplist *p, const char *key, const char *format, ...)
{
	pa_proplist_item *item = pa_proplist_item_find(p, key);
	va_list args;
	int res;

	va_start(args, format);
	if (item != NULL)
		pa_proplist_item_free(item);
        else
                item = pa_array_add(&p->array, sizeof(*item));
	item->key = strdup(key);
	if ((res = vasprintf(&item->value, format, args)) < 0)
		res = -errno;
	va_end(args);
	return res;
}

static inline const char *pa_proplist_gets(const pa_proplist *p, const char *key)
{
	pa_proplist_item *item = pa_proplist_item_find(p, key);
	return item ? item->value : NULL;
}

typedef enum pa_update_mode {
    PA_UPDATE_SET
    /**< Replace the entire property list with the new one. Don't keep
     *  any of the old data around. */,
    PA_UPDATE_MERGE
    /**< Merge new property list into the existing one, not replacing
     *  any old entries if they share a common key with the new
     *  property list. */,
    PA_UPDATE_REPLACE
    /**< Merge new property list into the existing one, replacing all
     *  old entries that share a common key with the new property
     *  list. */
} pa_update_mode_t;


static inline void pa_proplist_update(pa_proplist *p, pa_update_mode_t mode, const pa_proplist *other)
{
	pa_proplist_item *item;

	if (mode == PA_UPDATE_SET)
		pa_proplist_clear(p);

	pa_array_for_each(item, &other->array) {
		if (mode == PA_UPDATE_MERGE && pa_proplist_contains(p, item->key))
			continue;
		pa_proplist_sets(p, item->key, item->value);
	}
}

static inline pa_proplist* pa_proplist_new_dict(const struct acp_dict *dict)
{
	pa_proplist *p = pa_proplist_new();
	if (dict) {
		const struct acp_dict_item *item;
		struct acp_dict_item *it;
		acp_dict_for_each(item, dict) {
			it = pa_array_add(&p->array, sizeof(*it));
			it->key = strdup(item->key);
			it->value = strdup(item->value);
		}
	}
	return p;
}

static inline void pa_proplist_as_dict(const pa_proplist *p, struct acp_dict *dict)
{
	dict->n_items = pa_proplist_size(p);
	dict->items = p->array.data;
}

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PA_PROPLIST_H */
