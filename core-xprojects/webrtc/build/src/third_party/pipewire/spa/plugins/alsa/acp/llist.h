#ifndef foollistfoo
#define foollistfoo

/***
  This file is part of PulseAudio.

  Copyright 2004-2006 Lennart Poettering

  PulseAudio is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation; either version 2.1 of the
  License, or (at your option) any later version.

  PulseAudio is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with PulseAudio; if not, see <http://www.gnu.org/licenses/>.
***/

/* Some macros for maintaining doubly linked lists */

/* The head of the linked list. Use this in the structure that shall
 * contain the head of the linked list */
#define PA_LLIST_HEAD(t,name)                                           \
    t *name

/* The pointers in the linked list's items. Use this in the item structure */
#define PA_LLIST_FIELDS(t)                                              \
    t *next, *prev

/* Initialize the list's head */
#define PA_LLIST_HEAD_INIT(t,item)                                      \
    do {                                                                \
        (item) = (t*) NULL; }                                           \
    while(0)

/* Initialize a list item */
#define PA_LLIST_INIT(t,item)                                           \
    do {                                                                \
        t *_item = (item);                                              \
        pa_assert(_item);                                               \
        _item->prev = _item->next = NULL;                               \
    } while(0)

/* Prepend an item to the list */
#define PA_LLIST_PREPEND(t,head,item)                                   \
    do {                                                                \
        t **_head = &(head), *_item = (item);                           \
        pa_assert(_item);                                               \
        if ((_item->next = *_head))                                     \
            _item->next->prev = _item;                                  \
        _item->prev = NULL;                                             \
        *_head = _item;                                                 \
    } while (0)

/* Remove an item from the list */
#define PA_LLIST_REMOVE(t,head,item)                                    \
    do {                                                                \
        t **_head = &(head), *_item = (item);                           \
        pa_assert(_item);                                               \
        if (_item->next)                                                \
            _item->next->prev = _item->prev;                            \
        if (_item->prev)                                                \
            _item->prev->next = _item->next;                            \
        else {                                                          \
            pa_assert(*_head == _item);                                 \
            *_head = _item->next;                                       \
        }                                                               \
        _item->next = _item->prev = NULL;                               \
    } while(0)

/* Find the head of the list */
#define PA_LLIST_FIND_HEAD(t,item,head)                                 \
    do {                                                                \
        t **_head = (head), *_item = (item);                            \
        *_head = _item;                                                 \
        pa_assert(_head);                                               \
        while ((*_head)->prev)                                          \
            *_head = (*_head)->prev;                                    \
    } while (0)

/* Insert an item after another one (a = where, b = what) */
#define PA_LLIST_INSERT_AFTER(t,head,a,b)                               \
    do {                                                                \
        t **_head = &(head), *_a = (a), *_b = (b);                      \
        pa_assert(_b);                                                  \
        if (!_a) {                                                      \
            if ((_b->next = *_head))                                    \
                _b->next->prev = _b;                                    \
            _b->prev = NULL;                                            \
            *_head = _b;                                                \
        } else {                                                        \
            if ((_b->next = _a->next))                                  \
                _b->next->prev = _b;                                    \
            _b->prev = _a;                                              \
            _a->next = _b;                                              \
        }                                                               \
    } while (0)

#define PA_LLIST_FOREACH(i,head)                                        \
    for (i = (head); i; i = i->next)

#define PA_LLIST_FOREACH_SAFE(i,n,head)                                 \
    for (i = (head); i && ((n = i->next), 1); i = n)

#endif
