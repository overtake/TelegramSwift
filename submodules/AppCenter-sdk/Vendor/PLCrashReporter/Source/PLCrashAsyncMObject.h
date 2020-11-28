/*
 * Author: Landon Fuller <landonf@plausible.coop>
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

#ifndef PLCRASH_ASYNC_MOBJECT_H
#define PLCRASH_ASYNC_MOBJECT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "PLCrashAsync.h"

/**
 * @ingroup plcrash_async
 * @internal
 *
 * An async-accessible memory mapped object.
 */
typedef struct plcrash_async_mobject {
    /** The task from which the memory was mapped */
    task_t task;

    /** The in-memory address at which the target address has been mapped. This address is offset
     * from the actual starting address, to account for the rounding of mappings to whole pages. */
    uintptr_t address;

    /** The task-relative address of the mapped memory. */
    pl_vm_address_t task_address;

    /** The total requested length of the mapping. This value is the literal requested length, and is not rounded up to
     * the actual page size. */
    pl_vm_size_t length;

    /** The slide difference between the target's mapping and our in-memory mapping. This can be used to compute
     * the in-memory address of target pointers. */
    int64_t vm_slide;

    /** The actual mapping start address. This may differ from the address pointer, as it must be
     * page-aligned. */
    pl_vm_address_t vm_address;
    
    /** The actual mapping size. This may differ from the user-requested size, as the base address has been page-aligned */
    pl_vm_size_t vm_length;
} plcrash_async_mobject_t;

plcrash_error_t plcrash_async_mobject_init (plcrash_async_mobject_t *mobj, mach_port_t task, pl_vm_address_t task_addr, pl_vm_size_t length, bool require_full);

pl_vm_address_t plcrash_async_mobject_base_address (plcrash_async_mobject_t *mobj);
pl_vm_address_t plcrash_async_mobject_length (plcrash_async_mobject_t *mobj);

task_t plcrash_async_mobject_task (plcrash_async_mobject_t *mobj);

bool plcrash_async_mobject_verify_local_pointer (plcrash_async_mobject_t *mobj, uintptr_t address, pl_vm_off_t offset, size_t length);
void *plcrash_async_mobject_remap_address (plcrash_async_mobject_t *mobj, pl_vm_address_t address, pl_vm_off_t offset, size_t length);

plcrash_error_t plcrash_async_mobject_read_uint8 (plcrash_async_mobject_t *mobj, pl_vm_address_t address, pl_vm_off_t offset, uint8_t *result);
plcrash_error_t plcrash_async_mobject_read_uint16 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint16_t *result);
plcrash_error_t plcrash_async_mobject_read_uint32 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint32_t *result);
plcrash_error_t plcrash_async_mobject_read_uint64 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint64_t *result);

void plcrash_async_mobject_free (plcrash_async_mobject_t *mobj);
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_MOBJECT_H */
