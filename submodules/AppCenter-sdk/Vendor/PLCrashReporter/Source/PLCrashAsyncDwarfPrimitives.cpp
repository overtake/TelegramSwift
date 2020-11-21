/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncDwarfPrimitives.hpp"
#include "PLCrashAsyncDwarfEncoding.hpp"

#include "PLCrashFeatureConfig.h"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */

/**
 * Default reader constructor.
 *
 * @param byteorder The pointer encoding byte order. This value must remain valid throughout the lifetime of the new
 * reader instance.
 */
template <typename machine_ptr> gnu_ehptr_reader<machine_ptr>::gnu_ehptr_reader (const plcrash_async_byteorder_t *byteorder) {
    _byteorder = byteorder;
    _has_frame_section_base = false;
    _text_base.valid = false;
    _data_base.valid = false;
    _func_base.valid = false;
}

/**
 * Set the DW_EH_PE_aligned base addresses.
 *
 * @param frame_section_base The base address (in-memory) of the loaded debug_frame or eh_frame section. This is
 * used to calculate the offset of DW_EH_PE_aligned from the start of the frame section. This address should be the
 * actual base address at which the section has been mapped.
 *
 * @param frame_section_vm_addr The base VM address of the eh_frame or debug_frame section.
 * This is used to calculate alignment for DW_EH_PE_aligned-encoded values. This address should be the aligned base VM
 * address at which the section will (or has been loaded) during execution, and will be used to calculate
 * DW_EH_PE_aligned alignment.
 */
template <typename machine_ptr> void gnu_ehptr_reader<machine_ptr>::set_frame_section_base (machine_ptr frame_section_base, machine_ptr frame_section_vm_addr) {
    _has_frame_section_base = true;
    _frame_section_base = frame_section_base;
    _frame_section_vm_addr = frame_section_vm_addr;
}

/**
 * Set the DW_EH_PE_textrel base address.
 *
 * @param text_base The base address of the text segment to be applied to DW_EH_PE_textrel offsets.
 */
template <typename machine_ptr> void gnu_ehptr_reader<machine_ptr>::set_text_base (machine_ptr text_base) {
    _text_base.valid = true;
    _text_base.address = text_base;
}

/**
 * Set the DW_EH_PE_datarel base address.
 *
 * @param data_base The base address of the data segment to be applied to DW_EH_PE_datarel offsets.
 */
template <typename machine_ptr> void gnu_ehptr_reader<machine_ptr>::set_data_base (machine_ptr data_base) {
    _data_base.valid = true;
    _data_base.address = data_base;
}

/**
 * Set the DW_EH_PE_funcrel base address.
 *
 * @param func_base The base address of the function to be applied to DW_EH_PE_funcrel offsets.
 */
template <typename machine_ptr> void gnu_ehptr_reader<machine_ptr>::set_func_base (machine_ptr func_base) {
    _func_base.valid = true;
    _func_base.address = func_base;
}

/**
 * Read a GNU DWARF encoded pointer value from @a location within @a mobj. The encoding format is defined in
 * the Linux Standard Base Core Specification 4.1, section 10.5, DWARF Extensions.
 *
 * @param mobj The memory object from which the pointer data (including TEXT/DATA-relative values) will be read. This
 * should map the full binary that may be read; the pointer value may reference data that is relative to the binary
 * sections, depending on the base addresses supplied via @a state.
 * @param location A task-relative location within @a mobj.
 * @param offset An offset to apply to @a location.
 * @param encoding The encoding method to be used to decode the target pointer. If the encoding requires
 * a base address that has not previously been set, PLCRASH_ENOTSUP will be returned.
 * @param result On success, the pointer value.
 * @param size On success, will be set to the total size of the pointer data read at @a location, in bytes.
 */
template <typename machine_ptr> plcrash_error_t gnu_ehptr_reader<machine_ptr>::read (plcrash_async_mobject_t *mobj,
                                                                                     pl_vm_address_t location,
                                                                                     pl_vm_off_t offset,
                                                                                     DW_EH_PE_t encoding,
                                                                                     machine_ptr *result,
                                                                                     size_t *size)
{
    plcrash_error_t err;
    
    /* Skip DW_EH_pe_omit -- as per LSB 4.1.0, this signifies that no value is present */
    if (encoding == DW_EH_PE_omit) {
        PLCF_DEBUG("Skipping decoding of DW_EH_PE_omit pointer");
        return PLCRASH_ENOTFOUND;
    }
    
    /* Initialize the output size; we apply offsets to this size to allow for aligning the
     * address prior to reading the pointer data, etc. */
    *size = 0;
    
    /* Calculate the base address; bits 5-8 are used to specify the relative offset type */
    machine_ptr base;
    switch (encoding & 0x70) {
        case DW_EH_PE_pcrel:
            /*
             * Set the ptr PC relative base to our current read offset. The LSB specification does not define what value should
             * be used for the DW_EH_PE_pcrel base address; reviewing the available implementations demonstrates that
             * the current read buffer position should be used.
             */
            base = (machine_ptr)(location + offset);
            break;
            
        case DW_EH_PE_absptr:
            /* No flags are set */
            base = 0x0;
            break;
            
        case DW_EH_PE_textrel:
            if (!_text_base.valid) {
                PLCF_DEBUG("Cannot decode DW_EH_PE_textrel value with PLCRASH_ASYNC_DWARF_INVALID_BASE_ADDR text_addr");
                return PLCRASH_ENOTSUP;
            }
            base = _text_base.address;
            break;
            
        case DW_EH_PE_datarel:
            if (!_data_base.valid) {
                PLCF_DEBUG("Cannot decode DW_EH_PE_datarel value with PLCRASH_ASYNC_DWARF_INVALID_BASE_ADDR data_base");
                return PLCRASH_ENOTSUP;
            }
            base = _data_base.address;
            break;
            
        case DW_EH_PE_funcrel:
            if (!_func_base.valid) {
                PLCF_DEBUG("Cannot decode DW_EH_PE_funcrel value with PLCRASH_ASYNC_DWARF_INVALID_BASE_ADDR func_base");
                return PLCRASH_ENOTSUP;
            }
            
            base = _func_base.address;
            break;
            
        case DW_EH_PE_aligned: {
            /* Verify availability of required base addresses */
            if (!_has_frame_section_base) {
                PLCF_DEBUG("Cannot decode DW_EH_PE_aligned value without a valid frame section base configured");
                return PLCRASH_ENOTSUP;
            }
            
            /* Compute the offset+alignment relative to the section base */
            PLCF_ASSERT(location >= _frame_section_base);
            machine_ptr locationOffset = (machine_ptr)location - _frame_section_base;
            
            /* Apply to the VM load address for the section. */
            machine_ptr vm_addr = _frame_section_vm_addr + locationOffset;
            machine_ptr vm_aligned = (vm_addr + (sizeof(machine_ptr)-1)) & ~(sizeof(machine_ptr)-1);
            
            /* Apply the new offset to the actual load address */
            location += (vm_aligned - vm_addr);
            
            /* Set the base size to the number of bytes skipped */
            base = 0x0;
            *size = (size_t)(vm_aligned - vm_addr);
            break;
        }
            
        default:
            PLCF_DEBUG("Unsupported pointer base encoding of 0x%x", encoding);
            return PLCRASH_ENOTSUP;
    }
    
    /*
     * Decode and return the pointer value [+ offset].
     *
     * TODO: This code permits overflow to occur under the assumption that the failure will be caught
     * when safely dereferencing the resulting address. This should only occur when either bad data is presented,
     * or due to an implementation flaw in this code path -- in those cases, it would be preferable to
     * detect overflow early.
     */
    switch (encoding & 0x0F) {
        case DW_EH_PE_absptr: {
            machine_ptr value;
            
            if ((err = plcrash_async_dwarf_read_uintmax64(mobj, _byteorder, location, offset, sizeof(machine_ptr), &value)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = value + base;
            *size += sizeof(machine_ptr);
            break;
        }
            
        case DW_EH_PE_uleb128: {
            uint64_t ulebv;
            pl_vm_size_t uleb_size;
            
            if ((err = plcrash_async_dwarf_read_uleb128(mobj, location, offset, &ulebv, &uleb_size)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read uleb128 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = (machine_ptr)(ulebv + base);
            *size += uleb_size;
            break;
        }
            
        case DW_EH_PE_udata2: {
            uint16_t udata2;
            if ((err = plcrash_async_mobject_read_uint16(mobj, _byteorder, location, offset, &udata2)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read udata2 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = udata2 + base;
            *size += 2;
            break;
        }
            
        case DW_EH_PE_udata4: {
            uint32_t udata4;
            if ((err = plcrash_async_mobject_read_uint32(mobj, _byteorder, location, offset, &udata4)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read udata4 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = udata4 + base;
            *size += 4;
            break;
        }
            
        case DW_EH_PE_udata8: {
            uint64_t udata8;
            if ((err = plcrash_async_mobject_read_uint64(mobj, _byteorder, location, offset, &udata8)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read udata8 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = (machine_ptr)(udata8 + base);
            *size += 8;
            break;
        }
            
        case DW_EH_PE_sleb128: {
            int64_t slebv;
            pl_vm_size_t sleb_size;
            
            if ((err = plcrash_async_dwarf_read_sleb128(mobj, location, offset, &slebv, &sleb_size)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read sleb128 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = (machine_ptr)(slebv + base);
            *size += sleb_size;
            break;
        }
            
        case DW_EH_PE_sdata2: {
            int16_t sdata2;
            
            if ((err = plcrash_async_mobject_read_uint16(mobj, _byteorder, location, offset, (uint16_t *) &sdata2)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read sdata2 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = sdata2 + base;
            *size += 2;
            break;
        }
            
        case DW_EH_PE_sdata4: {
            int32_t sdata4;
            if ((err = plcrash_async_mobject_read_uint32(mobj, _byteorder, location, offset, (uint32_t *) &sdata4)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read sdata4 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = sdata4 + base;
            *size += 4;
            break;
        }
            
        case DW_EH_PE_sdata8: {
            int64_t sdata8;
            if ((err = plcrash_async_mobject_read_uint64(mobj, _byteorder, location, offset, (uint64_t *) &sdata8)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read sdata8 value at 0x%" PRIx64, (uint64_t) location);
                return err;
            }
            
            *result = (machine_ptr)(sdata8 + base);
            *size += 8;
            break;
        }
            
        default:
            PLCF_DEBUG("Unknown pointer encoding of type 0x%x", encoding);
            return PLCRASH_ENOTSUP;
    }
    
    /* Handle indirection; the target value may only be an absptr; there is no way to define an
     * encoding for the indirected target. */
    if (encoding & DW_EH_PE_indirect) {
        /*
         * An indirect read may refer to memory outside of the eh_frame/debug_section; as such, we use task-based reading to handle
         * indirect reads.
         *
         * TODO: This implementation should provide a resolvable GNUEHPtr value, rather than requiring resolution occur here.
         */
        return plcrash_async_dwarf_read_task_uintmax64(plcrash_async_mobject_task(mobj), _byteorder, (pl_vm_address_t) *result, 0, sizeof(machine_ptr), result);
    }
    
    return PLCRASH_ESUCCESS;

}

#pragma mark Primitive Type Decoding

/**
 * Read a SLEB128 value directly from @a location within @a task.
 *
 * @param task The task from which the LEB128 data will be read.
 * @param location A task-relative location within @a mobj.
 * @param offset Offset to be applied to @a location.
 * @param result On success, the ULEB128 value.
 * @param size On success, will be set to the total size of the decoded LEB128 value at @a location, in bytes.
 *
 * @warning Reading directly from the task requires performing memory remapping, and will incurs a higher runtime overhead
 * than plcrash_async_dwarf_read_sleb128().
 */
plcrash_error_t plcrash::async::plcrash_async_dwarf_read_task_sleb128 (task_t task, pl_vm_address_t location, pl_vm_off_t offset, int64_t *result, pl_vm_size_t *size) {
    pl_vm_address_t target;
    plcrash_error_t err;
    
    /* Calculate the absolute target */
    if (!plcrash_async_address_apply_offset(location, offset, &target)) {
        PLCF_DEBUG("Applying the  offset of 0x%" PRId64 " to base address %" PRIx64 " exceeds PL_VM_ADDRESS_MAX", (int64_t) offset, (uint64_t) location);
        return PLCRASH_EINVAL;
    }
    
    /*
     * Map up to PAGE_SIZE of bytes; we allow for shorter allocations, and rely on the sleb128 reader code to determine whether
     * the mapping is short. We use a page mapping, rather than reading data per-byte, to avoid per-byte syscall overhead.
     */
    plcrash_async_mobject_t mobj;
    if ((err = plcrash_async_mobject_init(&mobj, task, target, PAGE_SIZE, false)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to map uleb128 page");
        return err;
    }
    
    /* Perform the actual read */
    err = plcrash_async_dwarf_read_sleb128(&mobj, target, 0x0, result, size);
    
    /* Clean up our mapping */
    plcrash_async_mobject_free(&mobj);
    
    return err;
}

/**
 * Read a ULEB128 value directly from @a location within @a task.
 *
 * @param task The task from which the LEB128 data will be read.
 * @param location A task-relative location within @a mobj.
 * @param offset Offset to be applied to @a location.
 * @param result On success, the ULEB128 value.
 * @param size On success, will be set to the total size of the decoded LEB128 value at @a location, in bytes.
 *
 * @warning Reading directly from the task requires performing memory remapping, and will incurs a higher runtime overhead
 * than plcrash_async_dwarf_read_sleb128().
 */
plcrash_error_t plcrash::async::plcrash_async_dwarf_read_task_uleb128 (task_t task, pl_vm_address_t location, pl_vm_off_t offset, uint64_t *result, pl_vm_size_t *size) {
    pl_vm_address_t target;
    plcrash_error_t err;

    /* Calculate the absolute target */
    if (!plcrash_async_address_apply_offset(location, offset, &target)) {
        PLCF_DEBUG("Applying the  offset of 0x%" PRId64 " to base address %" PRIx64 " exceeds PL_VM_ADDRESS_MAX", (int64_t) offset, (uint64_t) location);
        return PLCRASH_EINVAL;
    }

    /*
     * Map up to PAGE_SIZE of bytes; we allow for shorter allocations, and rely on the uleb128 reader code to determine whether
     * the mapping is short. We use a page mapping, rather than reading data per-byte, to avoid per-byte syscall overhead.
     */
    plcrash_async_mobject_t mobj;
    if ((err = plcrash_async_mobject_init(&mobj, task, target, PAGE_SIZE, false)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to map uleb128 page");
        return err;
    }

    /* Perform the actual read */
    err = plcrash_async_dwarf_read_uleb128(&mobj, target, 0x0, result, size);

    /* Clean up our mapping */
    plcrash_async_mobject_free(&mobj);
    
    return err;
}

/**
 * Read a ULEB128 value from @a location within @a mobj.
 *
 * @param mobj The memory object from which the LEB128 data will be read.
 * @param location A task-relative location within @a mobj.
 * @param offset Offset to be applied to @a location.
 * @param result On success, the ULEB128 value.
 * @param size On success, will be set to the total size of the decoded LEB128 value at @a location, in bytes.
 */
plcrash_error_t plcrash::async::plcrash_async_dwarf_read_uleb128 (plcrash_async_mobject_t *mobj, pl_vm_address_t location, pl_vm_off_t offset, uint64_t *result, pl_vm_size_t *size) {
    unsigned int shift = 0;
    pl_vm_off_t position = 0;
    *result = 0;
    
    uint8_t *p;
    while ((p = (uint8_t *) plcrash_async_mobject_remap_address(mobj, location, position + offset, 1)) != NULL) {
        /* LEB128 uses 7 bits for the number, the final bit to signal completion */
        uint8_t byte = *p;
        *result |= ((uint64_t) (byte & 0x7f)) << shift;
        shift += 7;
        
        /* This is used to track length, so we must set it before
         * potentially terminating the loop below */
        position++;
        
        /* Check for terminating bit */
        if ((byte & 0x80) == 0)
            break;
        
        /* Check for a ULEB128 larger than 64-bits */
        if (shift >= 64) {
            PLCF_DEBUG("ULEB128 is larger than the maximum supported size of 64 bits");
            return PLCRASH_ENOTSUP;
        }
    }
    
    if (p == NULL) {
        PLCF_DEBUG("ULEB128 value did not terminate within mapped memory range");
        return PLCRASH_EINVAL;
    }
    
    *size = position;
    return PLCRASH_ESUCCESS;
}

/**
 * Read a SLEB128 value from @a location within @a mobj.
 *
 * @param mobj The memory object from which the LEB128 data will be read.
 * @param location A task-relative location within @a mobj.
 * @param offset Offset to be applied to @a location.
 * @param result On success, the ULEB128 value.
 * @param size On success, will be set to the total size of the decoded LEB128 value, in bytes.
 */
plcrash_error_t plcrash::async::plcrash_async_dwarf_read_sleb128 (plcrash_async_mobject_t *mobj, pl_vm_address_t location, pl_vm_off_t offset, int64_t *result, pl_vm_size_t *size) {
    unsigned int shift = 0;
    pl_vm_off_t position = 0;
    *result = 0;
    
    uint8_t *p;
    while ((p = (uint8_t *) plcrash_async_mobject_remap_address(mobj, location, position + offset, 1)) != NULL) {
        /* LEB128 uses 7 bits for the number, the final bit to signal completion */
        uint8_t byte = *p;
        *result |= ((uint64_t) (byte & 0x7f)) << shift;
        shift += 7;
        
        /* This is used to track length, so we must set it before
         * potentially terminating the loop below */
        position++;
        
        /* Check for terminating bit */
        if ((byte & 0x80) == 0)
            break;
        
        /* Check for a ULEB128 larger than 64-bits */
        if (shift >= 64) {
            PLCF_DEBUG("ULEB128 is larger than the maximum supported size of 64 bits");
            return PLCRASH_ENOTSUP;
        }
    }
    
    if (p == NULL) {
        PLCF_DEBUG("ULEB128 value did not terminate within mapped memory range");
        return PLCRASH_EINVAL;
    }
    
    /* Sign bit is 2nd high order bit */
    if (shift < 64 && (*p & 0x40))
        *result |= -(1ULL << shift);
    
    *size = position;
    return PLCRASH_ESUCCESS;
}

/* Provide explicit 32/64-bit instantiations */
template class plcrash::async::gnu_ehptr_reader<uint32_t>;
template class plcrash::async::gnu_ehptr_reader<uint64_t>;


/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
