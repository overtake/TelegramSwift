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

#ifndef PA_DYNARRAY_H
#define PA_DYNARRAY_H

#ifdef __cplusplus
extern "C" {
#endif

#include "array.h"

typedef struct pa_dynarray_item {
	void *ptr;
} pa_dynarray_item;

typedef struct pa_dynarray {
	pa_array array;
	pa_free_cb_t free_cb;
} pa_dynarray;

static inline void pa_dynarray_init(pa_dynarray *array, pa_free_cb_t free_cb)
{
	pa_array_init(&array->array, 16);
	array->free_cb = free_cb;
}

static inline void pa_dynarray_item_free(pa_dynarray *array, pa_dynarray_item *item)
{
	if (array->free_cb)
		array->free_cb(item->ptr);
}

static inline void pa_dynarray_clear(pa_dynarray *array)
{
	pa_dynarray_item *item;
	pa_array_for_each(item, &array->array)
		pa_dynarray_item_free(array, item);
	pa_array_clear(&array->array);
}

static inline pa_dynarray* pa_dynarray_new(pa_free_cb_t free_cb)
{
	pa_dynarray *d = calloc(1, sizeof(*d));
	pa_dynarray_init(d, free_cb);
	return d;
}

static inline void pa_dynarray_free(pa_dynarray *array)
{
	pa_dynarray_clear(array);
	free(array);
}

static inline void pa_dynarray_append(pa_dynarray *array, void *p)
{
	pa_dynarray_item *item = pa_array_add(&array->array, sizeof(*item));
	item->ptr = p;
}

static inline pa_dynarray_item *pa_dynarray_find_item(pa_dynarray *array, void *p)
{
	pa_dynarray_item *item;
	pa_array_for_each(item, &array->array) {
		if (item->ptr == p)
			return item;
	}
	return NULL;
}

static inline pa_dynarray_item *pa_dynarray_get_item(pa_dynarray *array, unsigned i)
{
	if (!pa_array_check_index(&array->array, i, pa_dynarray_item))
		return NULL;
	return pa_array_get_unchecked(&array->array, i, pa_dynarray_item);
}

static inline void *pa_dynarray_get(pa_dynarray *array, unsigned i)
{
	pa_dynarray_item *item = pa_dynarray_get_item(array, i);
	if (item == NULL)
		return NULL;
	return item->ptr;
}

static inline int pa_dynarray_insert_by_index(pa_dynarray *array, void *p, unsigned i)
{
	unsigned j, len;
        pa_dynarray_item *item;

	len = pa_array_get_len(&array->array, pa_dynarray_item);

	if (i > len)
		return -EINVAL;

	item = pa_array_add(&array->array, sizeof(*item));
	for (j = len; j > i; j--) {
		item--;
		item[1].ptr = item[0].ptr;
	}
	item->ptr = p;
	return 0;
}

static inline int pa_dynarray_remove_by_index(pa_dynarray *array, unsigned i)
{
        pa_dynarray_item *item = pa_dynarray_get_item(array, i);
	if (item == NULL)
		return -ENOENT;
	pa_dynarray_item_free(array, item);
	pa_array_remove(&array->array, item);
	return 0;
}

static inline int pa_dynarray_remove_by_data(pa_dynarray *array, void *p)
{
	pa_dynarray_item *item = pa_dynarray_find_item(array, p);
	if (item == NULL)
		return -ENOENT;
	pa_dynarray_item_free(array, item);
	pa_array_remove(&array->array, item);
	return 0;
}

static inline unsigned pa_dynarray_size(pa_dynarray *array)
{
	return pa_array_get_len(&array->array, pa_dynarray_item);
}

#define PA_DYNARRAY_FOREACH(elem, array, idx) \
    for ((idx) = 0; ((elem) = pa_dynarray_get(array, idx)); (idx)++)


#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PA_DYNARRAY_H */
