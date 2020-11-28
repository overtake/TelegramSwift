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

#ifndef PLCRASH_ASYNC_MACHO_STRING_H
#define PLCRASH_ASYNC_MACHO_STRING_H

#ifdef __cplusplus
extern "C" {
#endif
    
/**
 * @internal
 * @ingroup plcrash_async_image
 * @{
 */

#include "PLCrashAsyncMachOImage.h"
#include "PLCrashAsyncMObject.h"


typedef struct plcrash_async_macho_string {
    /** The Mach-O image the string is found in. */
    plcrash_async_macho_t *image;
    
    /** The address of the start of the string. */
    pl_vm_address_t address;
    
    /** The memory object for the string contents. */
    plcrash_async_mobject_t mobj;

    /** Whether the memory object is initialized. */
    bool mobjIsInitialized;

    /** The string's length, in bytes, not counting the terminating NUL. */
    pl_vm_size_t length;
} plcrash_async_macho_string_t;


plcrash_error_t plcrash_async_macho_string_init (plcrash_async_macho_string_t *string, plcrash_async_macho_t *image, pl_vm_address_t address);

plcrash_error_t plcrash_async_macho_string_get_length (plcrash_async_macho_string_t *string, pl_vm_size_t *outLength);

plcrash_error_t plcrash_async_macho_string_get_pointer (plcrash_async_macho_string_t *string, const char **outPointer);

void plcrash_async_macho_string_free (plcrash_async_macho_string_t *string);
    
/*
 * @}
 */
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_MACHO_STRING_H */
