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

#include "PLCrashAsyncDwarfFDE.hpp"
#include "PLCrashAsyncDwarfCIE.hpp"

#include "PLCrashFeatureConfig.h"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */


/**
 * Decode FDE info at target-relative @a address.
 *
 * Any resources held by a successfully initialized instance must be freed via plcrash_async_dwarf_fde_info_free();
 *
 * @param info The FDE record to be initialized.
 * @param mobj The memory object containing frame data (eh_frame or debug_frame) at the start address.
 * @param byteorder The byte order of the data referenced by @a mobj.
 * @param fde_address The target-relative address containing the FDE data to be decoded. This must include
 * the length field of the FDE.
 * @param debug_frame If true, interpret the DWARF data as a debug_frame section. Otherwise, the
 * frame reader will assume eh_frame data.
 */
template <typename machine_ptr>
plcrash_error_t plcrash_async_dwarf_fde_info_init (plcrash_async_dwarf_fde_info_t *info,
                                                                   plcrash_async_mobject_t *mobj,
                                                                   const plcrash_async_byteorder_t *byteorder,
                                                                   pl_vm_address_t fde_address,
                                                                   bool debug_frame)
{
    const pl_vm_address_t sect_addr = plcrash_async_mobject_base_address(mobj);
    plcrash_error_t err;
    pl_vm_size_t offset = 0;
    
    /* Extract and save the FDE length */
    uint8_t dwarf_word_size;
    pl_vm_size_t length_size;
    {
        uint32_t length32;
        
        if (plcrash_async_mobject_read_uint32(mobj, byteorder, fde_address, offset, &length32) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("The current FDE entry 0x%" PRIx64 " header lies outside the mapped range", (uint64_t) fde_address);
            return PLCRASH_EINVAL;
        }
        
        offset += sizeof(uint32_t);
        
        if (length32 == UINT32_MAX) {
            if ((err = plcrash_async_mobject_read_uint64(mobj, byteorder, fde_address, sizeof(uint32_t), &info->fde_length)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read FDE 64-bit length value value; FDE entry lies outside the mapped range");
                return err;
            }
            
            length_size = sizeof(uint64_t) + sizeof(uint32_t);
            offset += sizeof(uint64_t);
            dwarf_word_size = 8; // 64-bit DWARF
        } else {
            info->fde_length = length32;
            length_size = sizeof(uint32_t);
            dwarf_word_size = 4; // 32-bit DWARF
        }
    }
    
    /* Save the FDE offset; this is the FDE address, relative to the mobj base address, not including
     * the FDE initial length. */
    info->fde_offset = (fde_address - sect_addr) + length_size;
    
    /*
     * Calculate the the offset to the CIE entry.
     */
    pl_vm_address_t cie_target_address;
    {
        uint64_t raw_offset;
        
        if ((err = plcrash_async_dwarf_read_uintmax64(mobj, byteorder, fde_address, offset, dwarf_word_size, &raw_offset)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("FDE instruction offset falls outside the mapped range");
            return err;
        }
        offset += dwarf_word_size;
        
        /* In a .debug_frame, the CIE offset is already relative to the start of the section;
         * In a .eh_frame, the CIE offset is negative, relative to the current offset of the the FDE. */
        if (debug_frame) {
            info->cie_offset = (pl_vm_address_t) raw_offset;
            
            /* (Safely) calculate the absolute, task-relative address */
            if (raw_offset > PL_VM_OFF_MAX || !plcrash_async_address_apply_offset(sect_addr, (pl_vm_address_t) raw_offset, &cie_target_address)) {
                PLCF_DEBUG("CIE offset of 0x%" PRIx64 " overflows representable range of pl_vm_address_t", raw_offset);
                return PLCRASH_EINVAL;
            }
        } else {
            /* First, verify that the below subtraction won't overflow */
            if (raw_offset > (fde_address+length_size)) {
                PLCF_DEBUG("CIE offset 0x%" PRIx64 " would place the CIE value outside of the .eh_frame section", raw_offset);
                return PLCRASH_EINVAL;
            }
            
            cie_target_address = (fde_address+length_size) - (pl_vm_address_t) raw_offset;
            info->cie_offset = cie_target_address - sect_addr;
        }
        
    }
    
    /*
     * Set up default pointer state. TODO: Mac OS X and iOS do not currently use any relative-based encodings other
     * than pcrel. This matches libunwind-35.1, but we should ammend our API to support supplying the remainder of
     * the supported base addresses.
     */
    gnu_ehptr_reader<machine_ptr> ptr_reader(byteorder);
    
    /* Parse the CIE */
    plcrash_async_dwarf_cie_info_t cie;
    if ((err = plcrash_async_dwarf_cie_info_init(&cie, mobj, byteorder, &ptr_reader, cie_target_address)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to parse CFE for FDE");
        return err;
    }
    
    /*
     * Fetch the address range described by this entry
     */
    {
        machine_ptr value;
        size_t ptr_size;
        
        /* Determine the correct encoding to use. This will either be encoded using the standard plaform
         * pointer size (as per DWARF), or using the encoding defined in the augmentation string
         * (as per the LSB 4.1.0 eh_frame specification). */
        DW_EH_PE_t pc_encoding = DW_EH_PE_absptr;
        if (cie.has_eh_augmentation && cie.eh_augmentation.has_pointer_encoding)
            pc_encoding = (DW_EH_PE_t) cie.eh_augmentation.pointer_encoding;

        /* Fetch the base PC address */
        if ((err = ptr_reader.read(mobj, fde_address, offset, pc_encoding, &value, &ptr_size)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to read FDE initial_location");
            return err;
        }

        info->pc_start = value;
        offset += ptr_size;
        
        /* Fetch the PC length. In DWARF 3&4 specifications, this value is defined to use the standard platform pointer size. The
         * LSB 4.1.0 specification does not define the expected format, but a review of GNU's GDB implementation (along with
         * other independent implementations), demonstrates that this value uses the FDE pointer encoding with all indirection
         * flags cleared. */
        machine_ptr pc_length;
        if ((err = ptr_reader.read(mobj, fde_address, offset, (DW_EH_PE_t) (pc_encoding & DW_EH_PE_MASK_ENCODING), &pc_length, &ptr_size))) {
            PLCF_DEBUG("Failed to read FDE address_length");
            return err;
        }
        
        if (UINT64_MAX - pc_length < info->pc_start) {
            PLCF_DEBUG("FDE address_length + initial_location exceeds UINT64_MAX");
            return PLCRASH_EINVAL;
        }
        
        info->pc_end = info->pc_start + pc_length;
        offset += ptr_size;
    }
    
    /* The remainder of the FDE data is comprised of call frame instructions; we calculate the offset to the instructions,
     * as well as their length.
     *
     * This requires validating the lengths/offsets here to prevent overflow/underflow. Most values here have been calculated
     * as part of reading the data, and must be valid; hoever, it's possible that the declared FDE length itself short,
     * however, which we validate here.
     */
    info->instructions_offset = (fde_address+offset) - sect_addr;

    if (info->fde_length < (info->instructions_offset - info->fde_offset)) {
        PLCF_DEBUG("FDE length of 0x%" PRIu64 "declared to be less than the actual read length of 0x%" PRIu64, (uint64_t) info->fde_length,
                   (uint64_t)(info->instructions_offset - info->fde_offset));
        return PLCRASH_EINVAL;
    }

    info->instructions_length = (pl_vm_size_t) info->fde_length - (info->instructions_offset - info->fde_offset);

    /* Clean up */
    plcrash_async_dwarf_cie_info_free(&cie);
    
    return PLCRASH_ESUCCESS;
}

/**
 * Return the offset of the FDE instructions, relative to the eh_frame/debug_frame section base.
 *
 * @param info The FDE info record for which the instruction offset should be returned.
 */
pl_vm_address_t plcrash_async_dwarf_fde_info_instructions_offset (plcrash_async_dwarf_fde_info_t *info) {
    return info->instructions_offset;
}

/**
 * The length, in bytes, of the FDE instructions referenced by plcrash_async_dwarf_fde_info_instructions_length().
 *
 * @param info The FDE info record for which the instruction length should be returned.
 */
pl_vm_size_t plcrash_async_dwarf_fde_info_instructions_length (plcrash_async_dwarf_fde_info_t *info) {
    return info->instructions_length;
}

/**
 * Free all resources associated with @a fde_info.
 *
 * @param fde_info A previously initialized FDE info instance.
 */
void plcrash_async_dwarf_fde_info_free (plcrash_async_dwarf_fde_info_t *fde_info) {
    // noop
}

/* Provide explicit 32/64-bit instantiations */
template
plcrash_error_t plcrash_async_dwarf_fde_info_init<uint32_t> (plcrash_async_dwarf_fde_info_t *info,
                                                                             plcrash_async_mobject_t *mobj,
                                                                             const plcrash_async_byteorder_t *byteorder,
                                                                             pl_vm_address_t fde_address,
                                                                             bool debug_frame);

template
plcrash_error_t plcrash_async_dwarf_fde_info_init<uint64_t> (plcrash_async_dwarf_fde_info_t *info,
                                                                             plcrash_async_mobject_t *mobj,
                                                                             const plcrash_async_byteorder_t *byteorder,
                                                                             pl_vm_address_t fde_address,
                                                                             bool debug_frame);

/*
 * @}
 */

}
PLCR_CPP_END_NS

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
