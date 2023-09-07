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
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <spa/utils/defs.h>

#include <jack/ringbuffer.h>

SPA_EXPORT
jack_ringbuffer_t *jack_ringbuffer_create(size_t sz)
{
	size_t power_of_two;
	jack_ringbuffer_t *rb;

	rb = calloc(1, sizeof(jack_ringbuffer_t));
	if (rb == NULL)
		return NULL;

	for (power_of_two = 1; 1u << power_of_two < sz; power_of_two++);

	rb->size = 1 << power_of_two;
	rb->size_mask = rb->size - 1;
	if ((rb->buf = calloc(1, rb->size)) == NULL) {
		free (rb);
		return NULL;
	}
	rb->mlocked = 0;

	return rb;
}

SPA_EXPORT
void jack_ringbuffer_free(jack_ringbuffer_t *rb)
{
#ifdef USE_MLOCK
	if (rb->mlocked)
		munlock (rb->buf, rb->size);
#endif /* USE_MLOCK */
	free (rb->buf);
	free (rb);
}

SPA_EXPORT
void jack_ringbuffer_get_read_vector(const jack_ringbuffer_t *rb,
                                     jack_ringbuffer_data_t *vec)
{
	size_t free_cnt;
	size_t cnt2;
	size_t w, r;

	w = rb->write_ptr;
	r = rb->read_ptr;

	if (w > r)
		free_cnt = w - r;
	else
		free_cnt = (w - r + rb->size) & rb->size_mask;

	cnt2 = r + free_cnt;

	if (cnt2 > rb->size) {
		vec[0].buf = &(rb->buf[r]);
		vec[0].len = rb->size - r;
		vec[1].buf = rb->buf;
		vec[1].len = cnt2 & rb->size_mask;
	} else {
		vec[0].buf = &(rb->buf[r]);
		vec[0].len = free_cnt;
		vec[1].len = 0;
	}
}

SPA_EXPORT
void jack_ringbuffer_get_write_vector(const jack_ringbuffer_t *rb,
                                      jack_ringbuffer_data_t *vec)
{
	size_t free_cnt;
	size_t cnt2;
	size_t w, r;

	w = rb->write_ptr;
	r = rb->read_ptr;

	if (w > r)
		free_cnt = ((r - w + rb->size) & rb->size_mask) - 1;
	else if (w < r)
		free_cnt = (r - w) - 1;
	else
		free_cnt = rb->size - 1;

	cnt2 = w + free_cnt;

	if (cnt2 > rb->size) {
		vec[0].buf = &(rb->buf[w]);
		vec[0].len = rb->size - w;
		vec[1].buf = rb->buf;
		vec[1].len = cnt2 & rb->size_mask;
	} else {
		vec[0].buf = &(rb->buf[w]);
		vec[0].len = free_cnt;
		vec[1].len = 0;
	}
}

SPA_EXPORT
size_t jack_ringbuffer_read(jack_ringbuffer_t *rb, char *dest, size_t cnt)
{
	size_t free_cnt;
	size_t cnt2;
	size_t to_read;
	size_t n1, n2;

	if ((free_cnt = jack_ringbuffer_read_space (rb)) == 0)
		return 0;

	to_read = cnt > free_cnt ? free_cnt : cnt;

	cnt2 = rb->read_ptr + to_read;

	if (cnt2 > rb->size) {
		n1 = rb->size - rb->read_ptr;
		n2 = cnt2 & rb->size_mask;
	} else {
		n1 = to_read;
		n2 = 0;
	}

	memcpy (dest, &(rb->buf[rb->read_ptr]), n1);
	rb->read_ptr = (rb->read_ptr + n1) & rb->size_mask;
	if (n2) {
		memcpy (dest + n1, &(rb->buf[rb->read_ptr]), n2);
		rb->read_ptr = (rb->read_ptr + n2) & rb->size_mask;
	}
	return to_read;
}

SPA_EXPORT
size_t jack_ringbuffer_peek(jack_ringbuffer_t *rb, char *dest, size_t cnt)
{
	size_t free_cnt;
	size_t cnt2;
	size_t to_read;
	size_t n1, n2;
	size_t tmp_read_ptr;

	tmp_read_ptr = rb->read_ptr;

	if ((free_cnt = jack_ringbuffer_read_space (rb)) == 0)
		return 0;

	to_read = cnt > free_cnt ? free_cnt : cnt;

	cnt2 = tmp_read_ptr + to_read;

	if (cnt2 > rb->size) {
		n1 = rb->size - tmp_read_ptr;
		n2 = cnt2 & rb->size_mask;
	} else {
		n1 = to_read;
		n2 = 0;
	}

	memcpy (dest, &(rb->buf[tmp_read_ptr]), n1);
	tmp_read_ptr = (tmp_read_ptr + n1) & rb->size_mask;

	if (n2)
		memcpy (dest + n1, &(rb->buf[tmp_read_ptr]), n2);

	return to_read;
}

SPA_EXPORT
void jack_ringbuffer_read_advance(jack_ringbuffer_t *rb, size_t cnt)
{
	size_t tmp = (rb->read_ptr + cnt) & rb->size_mask;
	rb->read_ptr = tmp;
}

SPA_EXPORT
size_t jack_ringbuffer_read_space(const jack_ringbuffer_t *rb)
{
	size_t w, r;

	w = rb->write_ptr;
	r = rb->read_ptr;

	if (w > r)
		return w - r;
	else
		return (w - r + rb->size) & rb->size_mask;
}

SPA_EXPORT
int jack_ringbuffer_mlock(jack_ringbuffer_t *rb)
{
#ifdef USE_MLOCK
	if (mlock (rb->buf, rb->size))
                return -1;
#endif /* USE_MLOCK */
	rb->mlocked = 1;
	return 0;
}

SPA_EXPORT
void jack_ringbuffer_reset(jack_ringbuffer_t *rb)
{
	rb->read_ptr = 0;
	rb->write_ptr = 0;
	memset(rb->buf, 0, rb->size);
}

SPA_EXPORT
void jack_ringbuffer_reset_size (jack_ringbuffer_t * rb, size_t sz)
{
	rb->size = sz;
	rb->size_mask = rb->size - 1;
	rb->read_ptr = 0;
	rb->write_ptr = 0;
}

SPA_EXPORT
size_t jack_ringbuffer_write(jack_ringbuffer_t *rb, const char *src,
                             size_t cnt)
{
	size_t free_cnt;
	size_t cnt2;
	size_t to_write;
	size_t n1, n2;

	if ((free_cnt = jack_ringbuffer_write_space (rb)) == 0)
		return 0;

	to_write = cnt > free_cnt ? free_cnt : cnt;

	cnt2 = rb->write_ptr + to_write;

	if (cnt2 > rb->size) {
		n1 = rb->size - rb->write_ptr;
		n2 = cnt2 & rb->size_mask;
	} else {
		n1 = to_write;
		n2 = 0;
	}

	memcpy (&(rb->buf[rb->write_ptr]), src, n1);
	rb->write_ptr = (rb->write_ptr + n1) & rb->size_mask;
	if (n2) {
		memcpy (&(rb->buf[rb->write_ptr]), src + n1, n2);
		rb->write_ptr = (rb->write_ptr + n2) & rb->size_mask;
	}
	return to_write;
}

SPA_EXPORT
void jack_ringbuffer_write_advance(jack_ringbuffer_t *rb, size_t cnt)
{
	size_t tmp = (rb->write_ptr + cnt) & rb->size_mask;
	rb->write_ptr = tmp;
}

SPA_EXPORT
size_t jack_ringbuffer_write_space(const jack_ringbuffer_t *rb)
{
	size_t w, r;

	w = rb->write_ptr;
	r = rb->read_ptr;

	if (w > r)
		return ((r - w + rb->size) & rb->size_mask) - 1;
	else if (w < r)
		return (r - w) - 1;
	else
		return rb->size - 1;
}
