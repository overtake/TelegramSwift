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

#include "PLCrashAsyncDwarfEncoding.hpp"
#include "PLCrashFeatureConfig.h"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_dwarf DWARF
 *
 * Implements async-safe parsing of DWARF encodings.
 * @{
 */

/**
 * Initialize a new DWARF frame reader using the provided memory object.
 *
 * @param mobj The memory object containing frame data (eh_frame or debug_frame) at the start address. This instance must
 * survive for the lifetime of the reader.
 * @param byteorder The byte order of the data referenced by @a mobj.
 * @param m64 True if the target system uses 64-bit pointers, false if it uses 32-bit pointers.
 * @param debug_frame If true, interpret the DWARF data as a debug_frame section. Otherwise, the
 * frame reader will assume eh_frame data.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or an appropriate plcrash_error_t value on error.
 */
plcrash_error_t dwarf_frame_reader::init (plcrash_async_mobject_t *mobj,
                                          const plcrash_async_byteorder_t *byteorder,
                                          bool m64,
                                          bool debug_frame)
{
    _mobj = mobj;
    _byteorder = byteorder;
    _debug_frame = debug_frame;
    _m64 = m64;
    
    return PLCRASH_ESUCCESS;
}

/**
 * Locate the frame descriptor entry for @a pc, if available.
 *
 * @param offset A section-relative offset at which the FDE search will be initiated. This is primarily useful in combination with the compact unwind
 * encoding, in cases where the unwind instructions can not be expressed, and instead a FDE offset is provided by the encoding. Pass an offset of 0
 * to begin searching at the beginning of the unwind data.
 * @param pc The PC value to search for within the frame data. Note that this value should be the absolute address at which
 * the code is loaded into the target process, as the current implementation utilizes relative addressing to perform address
 * lookups.
 * @param fde_info If the FDE is found, PLFRAME_ESUCCESS will be returned and @a fde_info will be initialized with the
 * FDE data. The caller is responsible for freeing the returned FDE record via plcrash_async_dwarf_fde_info_free().
 *
 * @return Returns PLFRAME_ESUCCCESS on success, or one of the remaining error codes if a DWARF parsing error occurs. If
 * the entry can not be found, PLFRAME_ENOTFOUND will be returned.
 */
plcrash_error_t dwarf_frame_reader::find_fde (pl_vm_off_t offset,
                                              pl_vm_address_t pc,
                                              plcrash_async_dwarf_fde_info_t *fde_info)
{
    const plcrash_async_byteorder_t *byteorder = _byteorder;
    const pl_vm_address_t base_addr = plcrash_async_mobject_base_address(_mobj);
    const pl_vm_address_t end_addr = base_addr + plcrash_async_mobject_length(_mobj);
    
    plcrash_error_t err;
    
    /* Apply the FDE offset */
    pl_vm_address_t cfi_entry = base_addr;
    if (!plcrash_async_address_apply_offset(base_addr, offset, &cfi_entry)) {
        PLCF_DEBUG("FDE offset hint overflows the mobject's base address");
        return PLCRASH_EINVAL;
    }
    
    if (cfi_entry >= end_addr) {
        PLCF_DEBUG("FDE base address + offset falls outside the mapped range");
        return PLCRASH_EINVAL;
    }
    
    /* Iterate over table entries */
    while (cfi_entry < end_addr) {
        /* Fetch the entry length (and determine wether it's 64-bit or 32-bit) */
        uint64_t length;
        pl_vm_size_t length_size;
        uint8_t dwarf_word_size;
        
        {
            uint32_t *length32 = (uint32_t *) plcrash_async_mobject_remap_address(_mobj, cfi_entry, 0x0, sizeof(uint32_t));
            if (length32 == NULL) {
                PLCF_DEBUG("The current CFI entry 0x%" PRIx64 " header lies outside the mapped range", (uint64_t) cfi_entry);
                return PLCRASH_EINVAL;
            }
            
            if (byteorder->swap32(*length32) == UINT32_MAX) {
                uint64_t *length64 = (uint64_t *) plcrash_async_mobject_remap_address(_mobj, cfi_entry, sizeof(uint32_t), sizeof(uint64_t));
                if (length64 == NULL) {
                    PLCF_DEBUG("The current CFI entry 0x%" PRIx64 " header lies outside the mapped range", (uint64_t) cfi_entry);
                    return PLCRASH_EINVAL;
                }
                
                length = byteorder->swap64(*length64);
                length_size = sizeof(uint64_t) + sizeof(uint32_t);
                dwarf_word_size = 8; // 64-bit DWARF
            } else {
                length = byteorder->swap32(*length32);
                length_size = sizeof(uint32_t);
                dwarf_word_size = 4; // 32-bit DWARF
            }
        }
        
        /*
         * APPLE EXTENSION
         * Check for end marker, as per Apple's libunwind-35.1. It's unclear if this is defined by the DWARF 3 or 4 specifications; I could not
         * find a reference to it.
         
         * Section 7.2.2 defines 0xfffffff0 - 0xffffffff as being reserved for extensions to the length
         * field relative to the DWARF 2 standard. There is no explicit reference to the use of an 0 value.
         *
         * In section 7.2.1, the value of 0 is defined as being reserved as an error value in the encodings for
         * "attribute names, attribute forms, base type encodings, location operations, languages, line number program
         * opcodes, macro information entries and tag names to represent an error condition or unknown value."
         *
         * Section 7.2.2 doesn't justify the usage of 0x0 as a termination marker, but given that Apple's code relies on it,
         * we will also do so here.
         */
        if (length == 0x0)
            return PLCRASH_ENOTFOUND;
        
        /* Calculate the next entry address; the length_size addition is known-safe, as we were able to successfully read the length from *cfi_entry */
        pl_vm_address_t next_cfi_entry;
        if (!plcrash_async_address_apply_offset(cfi_entry+length_size, (pl_vm_off_t) length, &next_cfi_entry)) {
            PLCF_DEBUG("Entry length size overflows the CFI address");
            return PLCRASH_EINVAL;
        }
        
        /* Fetch the entry id */
        uint64_t cie_id;
        
        if ((err = plcrash_async_dwarf_read_uintmax64(_mobj, byteorder, cfi_entry, length_size, dwarf_word_size, &cie_id)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("The current CFI entry 0x%" PRIx64 " cie_id lies outside the mapped range", (uint64_t) cfi_entry);
            return PLCRASH_EINVAL;
        }
        
        /* Check for (and skip) CIE entries. */
        {
            bool is_cie = false;
            
            /* debug_frame uses UINT?_MAX to denote CIE entries. */
            if (_debug_frame && ((dwarf_word_size == 8 && cie_id == UINT64_MAX) || (dwarf_word_size == 4 && cie_id == UINT32_MAX)))
                is_cie = true;
            
            /* eh_frame uses a type of 0x0 to denote CIE entries. */
            if (!_debug_frame && cie_id == 0x0)
                is_cie = true;
            
            /* If not a FDE, skip */
            if (is_cie) {
                /* Not a FDE -- skip */
                cfi_entry = next_cfi_entry;
                continue;
            }
        }
        
        /* Decode the FDE */
        if (_m64)
            err = plcrash_async_dwarf_fde_info_init<uint64_t>(fde_info, _mobj, byteorder, cfi_entry, _debug_frame);
        else
            err = plcrash_async_dwarf_fde_info_init<uint32_t>(fde_info, _mobj, byteorder, cfi_entry, _debug_frame);
        if (err != PLCRASH_ESUCCESS)
            return err;
        
        /* Check if our PC is within range */
        if (pc >= fde_info->pc_start && pc < fde_info->pc_end)
            return PLCRASH_ESUCCESS;
        
        /* Skip to the next entry */
        cfi_entry = next_cfi_entry;
    }
    
    return PLCRASH_ENOTFOUND;
}

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
