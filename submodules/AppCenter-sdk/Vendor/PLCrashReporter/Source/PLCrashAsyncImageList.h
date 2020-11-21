/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef PLCRASH_ASYNC_IMAGE_LIST_H
#define PLCRASH_ASYNC_IMAGE_LIST_H

#include <stdint.h>
#include <stdbool.h>

#include "PLCrashAsyncMachOImage.h"

/*
 * NOTE: We keep this code C-compatible for backwards-compatibility purposes. If the entirity
 * of the codebase migrates to C/C++/Objective-C++, we can drop the C compatibility support
 * used here.
 */
#ifdef __cplusplus
#include "PLCrashAsyncLinkedList.hpp"
#endif
    
#ifdef __cplusplus
extern "C" {
#endif

typedef struct plcrash_async_image plcrash_async_image_t;

/**
 * @internal
 * @ingroup plcrash_async_image
 *
 * Async-safe binary image list element.
 */
struct plcrash_async_image {
    /** The binary image. */
    plcrash_async_macho_t macho_image;

    /** A borrowed, circular reference to the backing list node. */
#ifdef __cplusplus
    plcrash::async::async_list<plcrash_async_image_t *>::node * volatile _node;
#else
    void * volatile _node;
#endif
};

/**
 * @internal
 * @ingroup plcrash_async_image
 *
 * Async-safe binary image list. May be used to iterate over the binary images currently
 * available in-process.
 */
typedef struct plcrash_async_image_list {    
    /** The Mach task in which all Mach-O images can be found */
    mach_port_t task;

    /** The backing list */
#ifdef __cplusplus
    plcrash::async::async_list<plcrash_async_image_t *> *_list;
#else
    void *_list;
#endif
} plcrash_async_image_list_t;

void plcrash_nasync_image_list_init (plcrash_async_image_list_t *list, mach_port_t task);
void plcrash_nasync_image_list_free (plcrash_async_image_list_t *list);
void plcrash_nasync_image_list_append (plcrash_async_image_list_t *list, pl_vm_address_t header, const char *name);
void plcrash_nasync_image_list_remove (plcrash_async_image_list_t *list, pl_vm_address_t header);

void plcrash_async_image_list_set_reading (plcrash_async_image_list_t *list, bool enable);

plcrash_async_image_t *plcrash_async_image_containing_address (plcrash_async_image_list_t *list, pl_vm_address_t address);
plcrash_async_image_t *plcrash_async_image_list_next (plcrash_async_image_list_t *list, plcrash_async_image_t *current);
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_IMAGE_LIST_H */
