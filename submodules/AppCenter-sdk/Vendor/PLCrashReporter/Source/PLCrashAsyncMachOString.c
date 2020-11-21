/*
 * Author: Mike Ash <mikeash@plausiblelabs.com>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncMachOString.h"

/**
 * @internal
 * @ingroup plcrash_async_image
 * @{
 */

/**
 * Initialize a string object from a NUL-terminated C string.
 *
 * @param string A pointer to the string object to initialize.
 * @param image The Mach-O image in which the string resides.
 * @param address The address of the string.
 * @return An error code.
 */
plcrash_error_t plcrash_async_macho_string_init (plcrash_async_macho_string_t *string, plcrash_async_macho_t *image, pl_vm_address_t address) {
    string->image = image;
    string->address = address;
    string->mobjIsInitialized = false;
    return PLCRASH_ESUCCESS;
}

/**
 * Lazily read the string contents, initializing the memory object if necessary.
 *
 * @param string The string object.
 * @return An error code.
 */
static plcrash_error_t plcrash_async_macho_string_read (plcrash_async_macho_string_t *string) {
    if (string->mobjIsInitialized)
        return PLCRASH_ESUCCESS;
    
    pl_vm_address_t cursor = string->address;

    /* Map in the page containing the string, +1 up to one additional page. Short reads are permitted, as the next page
     * may not be readable. */
    size_t page_count = 1;
    plcrash_error_t err = plcrash_async_mobject_init(&string->mobj, string->image->task, string->address, PAGE_SIZE, false);
    if (err != PLCRASH_ESUCCESS)
        return err;

    char c;
    do {
        char *p = plcrash_async_mobject_remap_address(&string->mobj, cursor, 0, 1);
        if (p == NULL) {
            /* This should pretty much never happen */
            PLCF_DEBUG("Mapped a string larger than one page! Remapping ...");
            page_count++;
            plcrash_async_mobject_free(&string->mobj);
            err = plcrash_async_mobject_init(&string->mobj, string->image->task, string->address, page_count*PAGE_SIZE, false);
            if (err != PLCRASH_ESUCCESS)
                return err;
            
            p = plcrash_async_mobject_remap_address(&string->mobj, cursor, 0, 1);
            if (p == NULL) {
                PLCF_DEBUG("Failed to remap additional space ...");
                return PLCRASH_EINVAL;
            }
        }

        c = *p;
        cursor++;
    } while(c != '\0');

    /* Compute the length of the string data and make a new memory object. */
    string->length = cursor - string->address - 1;
    string->mobjIsInitialized = true;
    return PLCRASH_ESUCCESS;
}

/**
 * Get the length of the string.
 *
 * @param string The string object.
 * @param outLength On successful return, contains the length of the string in bytes, excluding the terminating NUL.
 * @return An error code.
 */
plcrash_error_t plcrash_async_macho_string_get_length (plcrash_async_macho_string_t *string, pl_vm_size_t *outLength) {
    plcrash_error_t err = plcrash_async_macho_string_read(string);
    if (err == PLCRASH_ESUCCESS)
        *outLength = string->length;
    return err;
}

/**
 * Get a pointer to the contents of the string.
 *
 * @param string The string object.
 * @param outPointer On successful return, contains a pointer to the string data. Note that this data is not NUL terminated.
 * @return An error code.
 */
plcrash_error_t plcrash_async_macho_string_get_pointer (plcrash_async_macho_string_t *string, const char **outPointer) {
    plcrash_error_t err = plcrash_async_macho_string_read(string);
    if (err == PLCRASH_ESUCCESS) {
        *outPointer = plcrash_async_mobject_remap_address(&string->mobj, string->mobj.task_address, 0, string->mobj.length);
        if (*outPointer == NULL)
            err = PLCRASH_EACCESS;
    }
    return err;
}

/**
 * Free a string.
 *
 * @param string The string object to free.
 */
void plcrash_async_macho_string_free (plcrash_async_macho_string_t *string) {
    if (string->mobjIsInitialized)
        plcrash_async_mobject_free(&string->mobj);
}

/*
 * @}
 */
