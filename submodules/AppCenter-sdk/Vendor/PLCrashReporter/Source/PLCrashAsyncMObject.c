/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
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

#include "PLCrashAsyncMObject.h"

#include <stdint.h>
#include <inttypes.h>

/**
 * @internal
 * @ingroup plcrash_async
 *
 * Implements async-safe cross-task memory mapping.
 *
 * @{
 */

/**
 * Map pages starting at @a task_addr from @a task into the current process. The mapping
 * will be copy-on-write, and will be checked to ensure a minimum protection value of
 * VM_PROT_READ.
 *
 * @param task The task from which the memory will be mapped.
 * @param task_addr The task-relative address of the memory to be mapped. This is not required to fall on a page boundry.
 * @param length The total size of the mapping to create.
 * @param require_full If false, short mappings will be permitted in the case where a memory object of the requested length
 * does not exist at the target address. It is the caller's responsibility to validate the resulting length of the
 * mapping, eg, using plcrash_async_mobject_remap_address() and similar. If true, and the entire requested page range is
 * not valid, the mapping request will fail.
 * @param[out] result The in-process address at which the pages were mapped.
 * @param[out] result_length The total size, in bytes, of the mapped pages.
 *
 * @return On success, returns PLCRASH_ESUCCESS. On failure, one of the plcrash_error_t error values will be returned, and no
 * mapping will be performed.
 *
 * @note
 * This code previously used vm_remap() to perform atomic remapping of process memory. However, this appeared
 * to trigger a kernel bug (and resulting panic) on iOS 6.0 through 6.1.2, possibly fixed in 6.1.3. Note that
 * no stable release of PLCrashReporter shipped with the vm_remap() code.
 *
 * Investigation of the failure seems to show an over-release of the target vm_map and backing vm_object, leading to
 * NULL dereference, invalid memory references, and in some cases, deadlocks that result in watchdog timeouts.
 *
 * In one example case, the crash occurs in update_first_free_ll() as a NULL dereference of the vm_map_entry_t parameter.
 * Analysis of the limited reports shows that this is called via vm_map_store_update_first_free(). No backtrace is
 * available from the kernel panics, but analyzing the register state demonstrates:
 * - A reference to vm_map_store_update_first_free() remains in the link register.
 * - Of the following callers, one can be eliminated by register state:
 *     - vm_map_enter - not possible, r3 should be equal to r0
 *     - vm_map_clip_start - possible
 *     - vm_map_clip_unnest - possible
 *     - vm_map_clip_end - possible
 *
 * In the other panic seen in vm_object_reap_pages(), a value of 0x8008 is loaded and deferenced from the next pointer
 * of an element within the vm_object's resident page queue (object->memq).
 *
 * Unfortunately, our ability to investigate has been extremely constrained by the following issues;
 * - The panic is not easily or reliably reproducible
 * - Apple's does not support iOS kernel debugging
 * - There is no support for jailbreak kernel debugging against iOS 6.x devices at the time of writing.
 *
 * The work-around used here is to split the vm_remap() into distinct calls to mach_make_memory_entry_64() and
 * vm_map(); this follows a largely distinct code path from vm_remap(). In testing by a large-scale user of PLCrashReporter,
 * they were no longer able to reproduce the issue with this fix in place. Additionally, they've not been able to reproduce
 * the issue on 6.1.3 devices, or had any reports of the issue occuring on 6.1.3 devices.
 *
 * The mach_make_memory_entry_64() API may not actually return an entry for the full requested length; this requires
 * that we loop through the full range, requesting an entry for the remaining unallocated pages, and then mapping
 * the pages in question. Since this requires multiple calls to vm_map(), we pre-allocate a contigious range of pages
 * for the target mappings into which we'll insert (via overwrite) our own mappings.
 *
 * @note
 * As a work-around for bugs in Apple's Mach-O/dyld implementation, we provide the @a require_full flag; if false,
 * a successful mapping that is smaller than the requested range may be made, and will not return an error. This is necessary
 * to allow our callers to work around bugs in update_dyld_shared_cache(1), which writes out a larger Mach-O VM segment
 * size value than is actually available and mappable. See the plcrash_async_macho_map_segment() API documentation for
 * more details. This bug has been reported to Apple as rdar://13707406.
 */
static plcrash_error_t plcrash_async_mobject_remap_pages_workaround (mach_port_t task,
                                                                     pl_vm_address_t task_addr,
                                                                     pl_vm_size_t length,
                                                                     bool require_full,
                                                                     pl_vm_address_t *result,
                                                                     pl_vm_size_t *result_length)
{
    kern_return_t kt;

    /* Compute the total required page size. */
    pl_vm_address_t base_addr = mach_vm_trunc_page(task_addr);
    pl_vm_size_t total_size = mach_vm_round_page(length + (task_addr - base_addr));
    
    /*
     * If short mappings are permitted, determine the actual mappable size of the target range. Due
     * to rdar://13707406 (update_dyld_shared_cache appears to write invalid LINKEDIT vmsize), an
     * LC_SEGMENT-reported VM size may be far larger than the actual mapped pages. This would result
     * in us making large (eg, 36MB) allocations in cases where the mappable range is actually much
     * smaller, which can trigger out-of-memory conditions on smaller devices.
     */
    if (!require_full) {
        pl_vm_size_t verified_size = 0;
        
        while (verified_size < total_size) {            
            memory_object_size_t entry_length = total_size - verified_size;
            mach_port_t mem_handle;
            
            /* Fetch an entry reference */
            kt = mach_make_memory_entry_64(task, &entry_length, base_addr + verified_size, VM_PROT_READ, &mem_handle, MACH_PORT_NULL);
            if (kt != KERN_SUCCESS) {
                /* Once we hit an unmappable page, break */
                break;
            }
            
            /* Drop the reference */
            kt = mach_port_mod_refs(mach_task_self(), mem_handle, MACH_PORT_RIGHT_SEND, -1);
            if (kt != KERN_SUCCESS) {
                PLCF_DEBUG("mach_port_mod_refs(-1) failed: %d", kt);
            }

            /* Note the size */
            verified_size += entry_length;
        }

        /* No valid page found at the task_addr */
        if (verified_size == 0) {
            PLCF_DEBUG("No mappable pages found at 0x%" PRIx64, (uint64_t) task_addr);
            return PLCRASH_ENOMEM;
        }

        /* Reduce the total size to the verified size */
        if (verified_size < total_size)
            total_size = verified_size;
    }

    /*
     * Set aside a memory range large enough for the total requested number of pages. Ideally the kernel
     * will lazy-allocate the backing physical pages so that we don't waste actual memory on this
     * pre-emptive page range reservation.
     */
    pl_vm_address_t mapping_addr = 0x0;
    pl_vm_size_t mapped_size = 0;
#ifdef PL_HAVE_MACH_VM
    kt = mach_vm_allocate(mach_task_self(), &mapping_addr, total_size, VM_FLAGS_ANYWHERE);
#else
    kt = vm_allocate(mach_task_self(), &mapping_addr, total_size, VM_FLAGS_ANYWHERE);
#endif

    if (kt != KERN_SUCCESS) {
        PLCF_DEBUG("Failed to allocate a target page range for the page remapping: %d", kt);
        return PLCRASH_EINTERNAL;
    }

    /* Map the source pages into the allocated region, overwriting the existing page mappings */
    while (mapped_size < total_size) {
        /* Create a reference to the target pages. The returned entry may be smaller than the total length. */
        memory_object_size_t entry_length = total_size - mapped_size;
        mach_port_t mem_handle;
        kt = mach_make_memory_entry_64(task, &entry_length, base_addr + mapped_size, VM_PROT_READ, &mem_handle, MACH_PORT_NULL);
        if (kt != KERN_SUCCESS) {            
            /* No pages are found at the target. When validating the total length above, we already verified the
             * availability of the requested pages; if they've now disappeared, we can treat it as an error,
             * even if !require_full was specified */
            PLCF_DEBUG("mach_make_memory_entry_64() failed: %d", kt);
            
            /* Clean up the reserved pages */
            kt = vm_deallocate(mach_task_self(), mapping_addr, total_size);
            if (kt != KERN_SUCCESS) {
                PLCF_DEBUG("vm_deallocate() failed: %d", kt);
            }
            
            /* Return error */
            return PLCRASH_ENOMEM;
        }
        
        /* Map the pages into our local task, overwriting the allocation used to reserve the target space above. */
        pl_vm_address_t target_address = mapping_addr + mapped_size;
#ifdef PL_HAVE_MACH_VM
        kt = mach_vm_map(mach_task_self(), &target_address, entry_length, 0x0, VM_FLAGS_FIXED|VM_FLAGS_OVERWRITE, mem_handle, 0x0, TRUE, VM_PROT_READ, VM_PROT_READ, VM_INHERIT_COPY);
#else
        kt = vm_map(mach_task_self(), &target_address, (vm_size_t) entry_length, 0x0, VM_FLAGS_FIXED|VM_FLAGS_OVERWRITE, mem_handle, 0x0, TRUE, VM_PROT_READ, VM_PROT_READ, VM_INHERIT_COPY);
#endif /* !PL_HAVE_MACH_VM */
        
        if (kt != KERN_SUCCESS) {
            PLCF_DEBUG("vm_map() failure: %d", kt);

            /* Clean up the reserved pages */
            kt = vm_deallocate(mach_task_self(), mapping_addr, total_size);
            if (kt != KERN_SUCCESS) {
                PLCF_DEBUG("vm_deallocate() failed: %d", kt);
            }

            /* Drop the memory handle */
            kt = mach_port_mod_refs(mach_task_self(), mem_handle, MACH_PORT_RIGHT_SEND, -1);
            if (kt != KERN_SUCCESS) {
                PLCF_DEBUG("mach_port_mod_refs(-1) failed: %d", kt);
            }
            
            return PLCRASH_ENOMEM;
        }

        /* Drop the memory handle */
        kt = mach_port_mod_refs(mach_task_self(), mem_handle, MACH_PORT_RIGHT_SEND, -1);
        if (kt != KERN_SUCCESS) {
            PLCF_DEBUG("mach_port_mod_refs(-1) failed: %d", kt);
        }
        
        /* Adjust the total mapping size */
        mapped_size += entry_length;
    }
    
    *result = mapping_addr;
    *result_length = mapped_size;

    return PLCRASH_ESUCCESS;
}


/**
 * Initialize a new memory object reference, mapping @a task_addr from @a task into the current process. The mapping
 * will be copy-on-write, and will be checked to ensure a minimum protection value of VM_PROT_READ.
 *
 * @param mobj Memory object to be initialized.
 * @param task The task from which the memory will be mapped.
 * @param task_addr The task-relative address of the memory to be mapped. This is not required to fall on a page boundry.
 * @param length The total size of the mapping to create.
 * @param require_full If false, short mappings will be permitted in the case where a memory object of the requested length
 * does not exist at the target address. It is the caller's responsibility to validate the resulting length of the
 * mapping, eg, using plcrash_async_mobject_remap_address() and similar. If true, and the entire requested page range is
 * not valid, the mapping request will fail.
 *
 * @return On success, returns PLCRASH_ESUCCESS. On failure, one of the plcrash_error_t error values will be returned, and no
 * mapping will be performed.
 */
plcrash_error_t plcrash_async_mobject_init (plcrash_async_mobject_t *mobj, mach_port_t task, pl_vm_address_t task_addr, pl_vm_size_t length, bool require_full) {
    plcrash_error_t err;

    /* Perform the page mapping */
    err = plcrash_async_mobject_remap_pages_workaround(task, task_addr, length, require_full, &mobj->vm_address, &mobj->vm_length);
    if (err != PLCRASH_ESUCCESS)
        return err;

    /* Determine the offset and length of the actual data */
    mobj->address = mobj->vm_address + (task_addr - mach_vm_trunc_page(task_addr));
    mobj->length = mobj->vm_length - (mobj->address - mobj->vm_address);

    /* Ensure that the length is capped to the user's requested length, rather than the total length once rounded up
     * to a full page. The length might already be smaller than the requested length if require_full is false. */
    if (mobj->length > length)
        mobj->length = length;

    /* Determine the difference between the target and local mappings. Note that this needs to be computed on either two page
     * aligned addresses, or two non-page aligned addresses. Mixing task_addr and vm_address would return an incorrect offset. */
    mobj->vm_slide = task_addr - mobj->address;
    
    /* Save the task-relative address */
    mobj->task_address = task_addr;
    
    /* Save the task reference */
    mobj->task = task;
    mach_port_mod_refs(mach_task_self(), mobj->task, MACH_PORT_RIGHT_SEND, 1);

    return PLCRASH_ESUCCESS;
}

/**
 * Return the base (target process relative) address for this mapping.
 *
 * @param mobj An initialized memory object.
 */
pl_vm_address_t plcrash_async_mobject_base_address (plcrash_async_mobject_t *mobj) {
    return mobj->task_address;
}


/**
 * Return the length of this mapping.
 *
 * @param mobj An initialized memory object.
 */
pl_vm_address_t plcrash_async_mobject_length (plcrash_async_mobject_t *mobj) {
    return mobj->length;
}

/**
 * Return a borrowed reference to the backing task for this mapping.
 *
 * @param mobj An initialized memory object.
 */
task_t plcrash_async_mobject_task (plcrash_async_mobject_t *mobj) {
    return mobj->task;
}

/**
 * Verify that @a length bytes starting at local @a address is within @a mobj's mapped range.
 *
 * @param mobj An initialized memory object.
 * @param address An address within the current task's memory space.
 * @param offset An offset to be applied to @a address prior to verifying the address range.
 * @param length The number of bytes that should be readable at @a address + @a offset.
 */
bool plcrash_async_mobject_verify_local_pointer (plcrash_async_mobject_t *mobj, uintptr_t address, pl_vm_off_t offset, size_t length) {
    /* Verify that the offset value won't overrun a native pointer */
    if (offset > 0 && UINTPTR_MAX - offset < address) {
        return false;
    } else if (offset < 0 && (offset * -1) > address) {
        return false;
    }

    /* Adjust the address using the verified offset */
    address += offset;

    /* Verify that the address starts within range */
    if (address < mobj->address) {
        // PLCF_DEBUG("Address %" PRIx64 " < base address %" PRIx64 "", (uint64_t) address, (uint64_t) mobj->address);
        return false;
    }

    /* Verify that the address value won't overrun */
    if (UINTPTR_MAX - length < address)
        return false;
    
    /* Check that the block ends within range */
    if (mobj->address + mobj->length < address + length) {
        // PLCF_DEBUG("Address %" PRIx64 " out of range %" PRIx64 " + %" PRIx64, (uint64_t) address, (uint64_t) mobj->address, (uint64_t) mobj->length);
        return false;
    }

    return true;
}

/**
 * Validate a target process' address pointer's availability via @a mobj, verifying that @a length bytes can be read
 * from @a mobj at @a address, and return the pointer from which a @a length read may be performed.
 *
 * @param mobj An initialized memory object.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address prior to verifying the address range.
 * @param length The total number of bytes that should be readable at @a address.
 *
 * @return Returns the validated pointer, or NULL if the requested bytes are not within @a mobj's range.
 */
void *plcrash_async_mobject_remap_address (plcrash_async_mobject_t *mobj, pl_vm_address_t address, pl_vm_off_t offset, size_t length) {
    /* Map into our memory space */
    pl_vm_address_t remapped = address - (pl_vm_address_t) mobj->vm_slide;

    if (!plcrash_async_mobject_verify_local_pointer(mobj, (uintptr_t) remapped, offset, length))
        return NULL;

    return (void *) (remapped + offset);
}

/**
 * Read a single byte from @a mobj.
 *
 * @param mobj Memory object from which to read the value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_mobject_read_uint8 (plcrash_async_mobject_t *mobj, pl_vm_address_t address, pl_vm_off_t offset, uint8_t *result) {
    uint8_t *input = plcrash_async_mobject_remap_address(mobj, address, offset, sizeof(uint8_t));
    if (input == NULL)
        return PLCRASH_EINVAL;
    
    *result = *input;
    return PLCRASH_ESUCCESS;
}

/**
 * Read a 16-bit value from @a mobj.
 *
 * @param mobj Memory object from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_mobject_read_uint16 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint16_t *result)
{
    uint16_t *input = plcrash_async_mobject_remap_address(mobj, address, offset, sizeof(uint16_t));
    if (input == NULL)
        return PLCRASH_EINVAL;
    
    *result = byteorder->swap16(*input);
    return PLCRASH_ESUCCESS;
}


/**
 * Read a 32-bit value from @a mobj.
 *
 * @param mobj Memory object from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_mobject_read_uint32 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint32_t *result)
{
    uint32_t *input = plcrash_async_mobject_remap_address(mobj, address, offset, sizeof(uint32_t));
    if (input == NULL)
        return PLCRASH_EINVAL;
    
    *result = byteorder->swap32(*input);
    return PLCRASH_ESUCCESS;
}

/**
 * Read a 64-bit value from @a mobj.
 *
 * @param mobj Memory object from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_mobject_read_uint64 (plcrash_async_mobject_t *mobj, const plcrash_async_byteorder_t *byteorder,
                                                   pl_vm_address_t address, pl_vm_off_t offset, uint64_t *result)
{
    uint64_t *input = plcrash_async_mobject_remap_address(mobj, address, offset, sizeof(uint64_t));
    if (input == NULL)
        return PLCRASH_EINVAL;
    
    *result = byteorder->swap64(*input);
    return PLCRASH_ESUCCESS;
}

/**
 * Free the memory mapping.
 *
 * @note Unlike most free() functions in this API, this function is async-safe.
 */
void plcrash_async_mobject_free (plcrash_async_mobject_t *mobj) {
    kern_return_t kt;
    
#ifdef PL_HAVE_MACH_VM
    kt = mach_vm_deallocate(mach_task_self(), mobj->vm_address, mobj->vm_length);
#else
    kt = vm_deallocate(mach_task_self(), mobj->vm_address, mobj->vm_length);
#endif
    
    if (kt != KERN_SUCCESS)
        PLCF_DEBUG("vm_deallocate() failure: %d", kt);

    /* Decrement our task refcount */
    mach_port_mod_refs(mach_task_self(), mobj->task, MACH_PORT_RIGHT_SEND, -1);
}

/*
 * @} plcrash_async
 */
