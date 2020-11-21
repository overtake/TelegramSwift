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

#include "PLCrashAsync.h"
#include "PLCrashAsyncImageList.h"
#include "PLCrashAsyncLinkedList.hpp"

#include <stdlib.h>
#include <string.h>
#include <assert.h>

using namespace plcrash::async;

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_image Binary Image Handling
 *
 * Maintains a linked list of binary images with support for async-safe iteration. Writing may occur concurrently with
 * async-safe reading, but is not async-safe.
 *
 * Atomic compare and swap is used to ensure a consistent view of the list for readers. To simplify implementation, a
 * write mutex is held for all updates; the implementation is not designed for efficiency in the face of contention
 * between readers and writers, and it's assumed that no contention should realistically occur.
 * @{
 */


/**
 * Initialize a new binary image list and issue a memory barrier
 *
 * @param list The list structure to be initialized.
 * @param task The mach task from which all images will be mapped.
 *
 * @warning This method is not async safe.
 */
void plcrash_nasync_image_list_init (plcrash_async_image_list_t *list, mach_port_t task) {
    memset(list, 0, sizeof(*list));

    list->_list = new async_list<plcrash_async_image_t *>();
    list->task = task;
    mach_port_mod_refs(mach_task_self(), list->task, MACH_PORT_RIGHT_SEND, 1);
}

/**
 * Free any binary image list resources.
 *
 * @warning This method is not async safe.
 */
void plcrash_nasync_image_list_free (plcrash_async_image_list_t *list) {
    /* Clean up the image structures */
    list->_list->set_reading(true);
    async_list<plcrash_async_image_t *>::node *next = NULL;
    while ((next = list->_list->next(next)) != NULL) {
        plcrash_async_image_t *image = next->value();
        
        /* Deallocate the Mach-O reference. */
        plcrash_nasync_macho_free(&image->macho_image);
        
        /* Deallocate the actual image value */
        free(image);
    }
    list->_list->set_reading(false);

    /* Free the backing list */
    delete list->_list;
    
    mach_port_mod_refs(mach_task_self(), list->task, MACH_PORT_RIGHT_SEND, -1);
}

/**
 * Append a new binary image record to @a list.
 *
 * @param list The list to which the image record should be appended.
 * @param header The image's header address.
 * @param name The image's name.
 *
 * @warning This method is not async safe.
 */
void plcrash_nasync_image_list_append (plcrash_async_image_list_t *list, pl_vm_address_t header, const char *name) {
    plcrash_error_t ret;

    /* Initialize the new entry. */
    plcrash_async_image_t *new_entry = (plcrash_async_image_t *) calloc(1, sizeof(plcrash_async_image_t));
    if ((ret = plcrash_nasync_macho_init(&new_entry->macho_image, list->task, name, header)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Unexpected failure initializing Mach-O structure for %s: %d", name, ret);
        free(new_entry);
        return;
    }

    /* Append */
    list->_list->nasync_append(new_entry);
}

/**
 * Remove a binary image record from @a list.
 *
 * @param header The header address of the record to be removed. The first record matching this address will be removed. If no matching
 * header is found, the request will be ignored.
 *
 * @warning This method is not async safe.
 */
void plcrash_nasync_image_list_remove (plcrash_async_image_list_t *list, pl_vm_address_t header) {
    list->_list->set_reading(true); {
        /* Find a matching entry */
        async_list<plcrash_async_image_t *>::node *found = NULL;
        async_list<plcrash_async_image_t *>::node *next = NULL;
        while ((next = list->_list->next(next)) != NULL) {
            if (next->value()->macho_image.header_addr == header) {
                found = next;
                break;
            }
        }

        /* If not found, nothing to do */
        if (found == NULL) {
            PLCF_DEBUG("Can't find header addr=%llu in Mach-O image list.", (uint64_t)header);
            list->_list->set_reading(false);
            return;
        }

        /* Delete the entry */
        list->_list->nasync_remove_node(found);
    } list->_list->set_reading(false);
}

/**
 * Retain or release the list for reading. This method is async-safe.
 *
 * This must be issued prior to attempting to iterate the list, and must called again once reads have completed.
 *
 * @param list The list to be be retained or released for reading.
 * @param enable If true, the list will be retained. If false, released.
 */
void plcrash_async_image_list_set_reading (plcrash_async_image_list_t *list, bool enable) {
    list->_list->set_reading(enable);
}

/**
 * Return the image containing the given @a address within its TEXT segment. This method is async-safe.
 * If image is found, NULL will be returned.
 *
 * @param list The list to be iterated.
 * @param address The address to be searched for.
 *
 * @warning The list must be retained for reading via plcrash_async_image_list_set_reading() before calling this function.
 */
plcrash_async_image_t *plcrash_async_image_containing_address (plcrash_async_image_list_t *list, pl_vm_address_t address) {
    plcrash_async_image_t *image = NULL;
    while ((image = plcrash_async_image_list_next(list, image)) != NULL) {
        if (plcrash_async_macho_contains_address(&image->macho_image, address))
            return image;
    }

    /* Not found */
    return NULL;
}

/**
 * Return the next image record. This method is async-safe. If no additional images are available, will return NULL;
 *
 * @param list The list to be iterated.
 * @param current The current image record, or NULL to start iteration.
 *
 * @warning The list must be retained for reading via plcrash_async_image_list_set_reading() before calling this function.
 */
plcrash_async_image_t *plcrash_async_image_list_next (plcrash_async_image_list_t *list, plcrash_async_image_t *current) {
    /* We can assume that the caller enabled reading here; we can't gaurantee proper behavior otherwise. */
    async_list<plcrash_async_image_t *>::node *node;

    /* Fetch the next node */
    if (current != NULL) {
        node = list->_list->next(current->_node);
    } else {
        node = list->_list->next(NULL);
    }

    /* Handle end of list */
    if (node == NULL)
        return NULL;
    
    /* Lazily swap in the cyclic node reference. This is pessimestic, but there's really not a better time to do it. */
    plcrash_async_image_t *image = node->value();
    image->_node = node;

    return node->value();
}

/*
 * @}
 */
