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

#ifndef PA_HASHMAP_H
#define PA_HASHMAP_H

#ifdef __cplusplus
extern "C" {
#endif

#include "array.h"

typedef unsigned (*pa_hash_func_t)(const void *p);
typedef int (*pa_compare_func_t)(const void *a, const void *b);

typedef struct pa_hashmap_item {
	void *key;
	void *value;
} pa_hashmap_item;

typedef struct pa_hashmap {
	pa_array array;
	pa_hash_func_t hash_func;
	pa_compare_func_t compare_func;
	pa_free_cb_t key_free_func;
	pa_free_cb_t value_free_func;
} pa_hashmap;

static inline pa_hashmap *pa_hashmap_new(pa_hash_func_t hash_func, pa_compare_func_t compare_func)
{
        pa_hashmap *m = calloc(1, sizeof(pa_hashmap));
        pa_array_init(&m->array, 16);
	m->hash_func = hash_func;
	m->compare_func = compare_func;
	return m;
}

static inline pa_hashmap *pa_hashmap_new_full(pa_hash_func_t hash_func, pa_compare_func_t compare_func,
		pa_free_cb_t key_free_func, pa_free_cb_t value_free_func)
{
	pa_hashmap *m = pa_hashmap_new(hash_func, compare_func);
	m->key_free_func = key_free_func;
	m->value_free_func = value_free_func;
	return m;
}

static inline void pa_hashmap_item_free(pa_hashmap *h, pa_hashmap_item *item)
{
	if (h->key_free_func && item->key)
		h->key_free_func(item->key);
	if (h->value_free_func && item->value)
		h->value_free_func(item->value);
}

static inline void pa_hashmap_remove_all(pa_hashmap *h)
{
	pa_hashmap_item *item;
	pa_array_for_each(item, &h->array)
		pa_hashmap_item_free(h, item);
	pa_array_reset(&h->array);
}

static inline void pa_hashmap_free(pa_hashmap *h)
{
	pa_hashmap_remove_all(h);
	pa_array_clear(&h->array);
	free(h);
}

static inline pa_hashmap_item* pa_hashmap_find_free(pa_hashmap *h)
{
	pa_hashmap_item *item;
	pa_array_for_each(item, &h->array) {
		if (item->key == NULL)
			return item;
	}
	return pa_array_add(&h->array, sizeof(*item));
}

static inline pa_hashmap_item* pa_hashmap_find(const pa_hashmap *h, const void *key)
{
	pa_hashmap_item *item = NULL;
	pa_array_for_each(item, &h->array) {
		if (item->key != NULL && h->compare_func(item->key, key) == 0)
			return item;
	}
	return NULL;
}

static inline void* pa_hashmap_get(const pa_hashmap *h, const void *key)
{
	const pa_hashmap_item *item = pa_hashmap_find(h, key);
	if (item == NULL)
		return NULL;
	return item->value;
}

static inline int pa_hashmap_put(pa_hashmap *h, void *key, void *value)
{
	pa_hashmap_item *item = pa_hashmap_find(h, key);
	if (item != NULL)
		return -1;
	item = pa_hashmap_find_free(h);
	item->key = key;
	item->value = value;
	return 0;
}

static inline void* pa_hashmap_remove(pa_hashmap *h, const void *key)
{
	pa_hashmap_item *item = pa_hashmap_find(h, key);
	void *value;
	if (item == NULL)
		return NULL;
	value = item->value;
	if (h->key_free_func)
		h->key_free_func(item->key);
	item->key = NULL;
	item->value = NULL;
	return value;
}

static inline int pa_hashmap_remove_and_free(pa_hashmap *h, const void *key)
{
	void *val = pa_hashmap_remove(h, key);
	if (val && h->value_free_func)
		h->value_free_func(val);
	return val ? 0 : -1;
}

static inline void *pa_hashmap_first(const pa_hashmap *h)
{
	pa_hashmap_item *item;
	pa_array_for_each(item, &h->array) {
		if (item->key != NULL)
			return item->value;
	}
	return NULL;
}

static inline void *pa_hashmap_iterate(const pa_hashmap *h, void **state, const void **key)
{
	pa_hashmap_item *it = *state;
	if (it == NULL)
		*state = pa_array_first(&h->array);
	do {
		it = *state;
		if (!pa_array_check(&h->array, it))
			return NULL;
		*state = it + 1;
	} while (it->key == NULL);
	if (key)
		*key = it->key;
	return it->value;
}

static inline bool pa_hashmap_isempty(const pa_hashmap *h)
{
	pa_hashmap_item *item;
	pa_array_for_each(item, &h->array)
		if (item->key != NULL)
			return false;
	return true;
}

static inline unsigned pa_hashmap_size(const pa_hashmap *h)
{
	unsigned count = 0;
	pa_hashmap_item *item;
	pa_array_for_each(item, &h->array)
		if (item->key != NULL)
			count++;
	return count;
}

static inline void pa_hashmap_sort(pa_hashmap *h,
		int (*compar)(const void *, const void *))
{
        qsort((void*)h->array.data,
			pa_array_get_len(&h->array, pa_hashmap_item),
			sizeof(pa_hashmap_item), compar);
}

#define PA_HASHMAP_FOREACH(e, h, state) \
	for ((state) = NULL, (e) = pa_hashmap_iterate((h), &(state), NULL);	\
	    (e); (e) = pa_hashmap_iterate((h), &(state), NULL))

/* A macro to ease iteration through all key, value pairs */
#define PA_HASHMAP_FOREACH_KV(k, e, h, state) \
	for ((state) = NULL, (e) = pa_hashmap_iterate((h), &(state), (const void **) &(k));	\
	    (e); (e) = pa_hashmap_iterate((h), &(state), (const void **) &(k)))


#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PA_HASHMAP_H */
