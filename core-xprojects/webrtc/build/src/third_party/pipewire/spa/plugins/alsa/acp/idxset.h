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

#ifndef PA_IDXSET_H
#define PA_IDXSET_H

#ifdef __cplusplus
extern "C" {
#endif

#include "array.h"

#define PA_IDXSET_INVALID ((uint32_t) -1)

typedef unsigned (*pa_hash_func_t)(const void *p);
typedef int (*pa_compare_func_t)(const void *a, const void *b);

typedef struct pa_idxset_item {
	void *ptr;
} pa_idxset_item;

typedef struct pa_idxset {
	pa_array array;
	pa_hash_func_t hash_func;
	pa_compare_func_t compare_func;
} pa_idxset;

static inline unsigned pa_idxset_trivial_hash_func(const void *p)
{
	return PA_PTR_TO_UINT(p);
}

static inline int pa_idxset_trivial_compare_func(const void *a, const void *b)
{
	return a < b ? -1 : (a > b ? 1 : 0);
}

static inline unsigned pa_idxset_string_hash_func(const void *p)
{
	unsigned hash = 0;
	const char *c;
	for (c = p; *c; c++)
		hash = 31 * hash + (unsigned) *c;
	return hash;
}

static inline int pa_idxset_string_compare_func(const void *a, const void *b)
{
	return strcmp(a, b);
}

static inline pa_idxset *pa_idxset_new(pa_hash_func_t hash_func, pa_compare_func_t compare_func)
{
        pa_idxset *s = calloc(1, sizeof(pa_idxset));
        pa_array_init(&s->array, 16);
	s->hash_func = hash_func;
	s->compare_func = compare_func;
	return s;
}

static inline void pa_idxset_free(pa_idxset *s, pa_free_cb_t free_cb)
{
	if (free_cb) {
		pa_idxset_item *item;
		pa_array_for_each(item, &s->array)
			free_cb(item->ptr);
	}
	pa_array_clear(&s->array);
	free(s);
}

static inline pa_idxset_item* pa_idxset_find(const pa_idxset *s, const void *ptr)
{
	pa_idxset_item *item;
	pa_array_for_each(item, &s->array) {
		if (item->ptr == ptr)
			return item;
	}
	return NULL;
}

static inline int pa_idxset_put(pa_idxset*s, void *p, uint32_t *idx)
{
	pa_idxset_item *item = pa_idxset_find(s, p);
	int res = item ? -1 : 0;
	if (item == NULL) {
		item = pa_idxset_find(s, NULL);
		if (item == NULL)
			item = pa_array_add(&s->array, sizeof(*item));
		item->ptr = p;
	}
	if (idx)
		*idx = item - (pa_idxset_item*)s->array.data;
	return res;
}

static inline pa_idxset *pa_idxset_copy(pa_idxset *s, pa_copy_func_t copy_func)
{
	pa_idxset_item *item;
	pa_idxset *copy = pa_idxset_new(s->hash_func, s->compare_func);
	pa_array_for_each(item, &s->array) {
		if (item->ptr)
			pa_idxset_put(copy, copy_func ? copy_func(item->ptr) : item->ptr, NULL);
	}
	return copy;
}

static inline bool pa_idxset_isempty(const pa_idxset *s)
{
	pa_idxset_item *item;
	pa_array_for_each(item, &s->array)
		if (item->ptr != NULL)
			return false;
	return true;
}
static inline unsigned pa_idxset_size(pa_idxset*s)
{
	unsigned count = 0;
	pa_idxset_item *item;
	pa_array_for_each(item, &s->array)
		if (item->ptr != NULL)
			count++;
	return count;
}

static inline void *pa_idxset_search(pa_idxset *s, uint32_t *idx)
{
        pa_idxset_item *item;
	for (item = pa_array_get_unchecked(&s->array, *idx, pa_idxset_item);
	     pa_array_check(&s->array, item); item++, (*idx)++) {
		if (item->ptr != NULL)
			return item->ptr;
	}
	*idx = PA_IDXSET_INVALID;
	return NULL;
}

static inline void *pa_idxset_next(pa_idxset *s, uint32_t *idx)
{
	(*idx)++;;
	return pa_idxset_search(s, idx);
}

static inline void* pa_idxset_first(pa_idxset *s, uint32_t *idx)
{
	uint32_t i = 0;
	void *ptr = pa_idxset_search(s, &i);
	if (idx)
		*idx = i;
	return ptr;
}

static inline void* pa_idxset_get_by_data(pa_idxset*s, const void *p, uint32_t *idx)
{
	pa_idxset_item *item = pa_idxset_find(s, p);
	if (item == NULL)
		return NULL;
	if (idx)
		*idx = item - (pa_idxset_item*)s->array.data;
	return item->ptr;
}

static inline void* pa_idxset_get_by_index(pa_idxset*s, uint32_t idx)
{
        pa_idxset_item *item;
	if (!pa_array_check_index(&s->array, idx, pa_idxset_item))
		return NULL;
	item = pa_array_get_unchecked(&s->array, idx, pa_idxset_item);
	return item->ptr;
}

#define PA_IDXSET_FOREACH(e, s, idx) \
	for ((e) = pa_idxset_first((s), &(idx)); (e); (e) = pa_idxset_next((s), &(idx)))

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PA_IDXSET_H */
