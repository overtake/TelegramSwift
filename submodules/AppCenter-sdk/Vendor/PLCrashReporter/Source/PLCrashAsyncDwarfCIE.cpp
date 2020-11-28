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

#pragma mark CIE Parser

/**
 * Parse a new DWARF CIE record using the provided memory object and initialize @a info.
 *
 * Any resources held by a successfully initialized instance must be freed via plcrash_async_dwarf_cie_info_free();
 *
 * @param info The CIE info instance to initialize.
 * @param mobj The memory object containing frame data (eh_frame or debug_frame) at the start address.
 * @param byteorder The byte order of the data referenced by @a mobj.
 * @param ptr_reader The pointer reader to be used when decoding GNU eh_frame pointer values.
 * @param address The task-relative address within @a mobj of the CIE to be decoded.
 */
template <typename machine_ptr>
plcrash_error_t plcrash_async_dwarf_cie_info_init (plcrash_async_dwarf_cie_info_t *info,
                                                                   plcrash_async_mobject_t *mobj,
                                                                   const plcrash_async_byteorder_t *byteorder,
                                                                   gnu_ehptr_reader<machine_ptr> *ptr_reader,
                                                                   pl_vm_address_t address)
{
    pl_vm_address_t base_addr = plcrash_async_mobject_base_address(mobj);
    pl_vm_address_t offset = 0;
    plcrash_error_t err;
    
    /* Default initialization */
    plcrash_async_memset(info, 0, sizeof(*info));
    
    /* Extract and save the FDE length */
    bool m64;
    pl_vm_size_t length_size;
    {
        uint32_t length32;
        
        if (plcrash_async_mobject_read_uint32(mobj, byteorder, address, 0x0, &length32) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE 0x%" PRIx64 " header lies outside the mapped range", (uint64_t) address);
            return PLCRASH_EINVAL;
        }
        
        if (length32 == UINT32_MAX) {
            if ((err = plcrash_async_mobject_read_uint64(mobj, byteorder, address, sizeof(uint32_t), &info->cie_length)) != PLCRASH_ESUCCESS)
                return err;
            
            length_size = sizeof(uint64_t) + sizeof(uint32_t);
            m64 = true;
        } else {
            info->cie_length = length32;
            length_size = sizeof(uint32_t);
            m64 = false;
        }
    }
    
    /* Save the CIE offset; this is the CIE address, relative to the section base address, not including
     * the CIE initial length. */
    PLCF_ASSERT(address >= base_addr);
    info->cie_offset = (address - base_addr) + length_size;
    offset += length_size;
    
    /* Fetch the cie_id. This is either 32-bit or 64-bit */
    if (m64) {
        if ((err = plcrash_async_mobject_read_uint64(mobj, byteorder, address, offset, &info->cie_id)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE id could not be read");
            return err;
        }
        
        offset += sizeof(uint64_t);
    } else {
        uint32_t u32;
        if ((err = plcrash_async_mobject_read_uint32(mobj, byteorder, address, offset, &u32)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE id could not be read");
            return err;
        }
        info->cie_id = u32;
        offset += sizeof(uint32_t);
    }
    
    /* Sanity check the CIE id; it should always be 0 (eh_frame) or UINT?_MAX (debug_frame) */
    if (info->cie_id != 0 && ((!m64 && info->cie_id != UINT32_MAX) || (m64 && info->cie_id != UINT64_MAX)))  {
        PLCF_DEBUG("CIE id is not one of 0 (eh_frame) or UINT?_MAX (debug_frame): %" PRIx64, info->cie_id);
        return PLCRASH_EINVAL;
    }
    
    
    /* Fetch and sanity check the version; it should either be 1 (eh_frame), 3 (DWARF3 debug_frame), or 4 (DWARF4 debug_frame) */
    if ((err = plcrash_async_mobject_read_uint8(mobj, address, offset, &info->cie_version)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("CIE version could not be read");
        return err;
    }
    
    if (info->cie_version != 1 && info->cie_version != 3 && info->cie_version != 4) {
        PLCF_DEBUG("CIE version is not one of 1 (eh_frame) or 3 (DWARF3) or 4 (DWARF4): %" PRIu8, info->cie_version);
        return PLCRASH_EINVAL;
    }
    
    offset += sizeof(uint8_t);
    
    /* Save the start and end of the augmentation data; we'll parse the string below. */
    pl_vm_address_t augment_offset = offset;
    pl_vm_size_t augment_size = 0;
    {
        uint8_t augment_char;
        while (augment_size < PL_VM_SIZE_MAX && (err = plcrash_async_mobject_read_uint8(mobj, address, augment_offset+augment_size, &augment_char)) == PLCRASH_ESUCCESS) {
            /* Check for an unknown augmentation string. See the parsing section below for more details. If the augmentation
             * string is not of the expected format (or empty), we can't parse a useful subset of the CIE */
            if (augment_size == 0) {
                if (augment_char == 'z') {
                    info->has_eh_augmentation = true;
                } else if (augment_char != '\0') {
                    PLCF_DEBUG("Unknown augmentation string prefix of %c, cannot parse CIE", augment_char);
                    return PLCRASH_ENOTSUP;
                }
            }
            
            /* Adjust the calculated size */
            augment_size++;
            
            /* Check for completion */
            if (augment_char == '\0')
                break;
        }
        
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE augmentation string could not be read");
            return err;
        }
        
        if (augment_size == PL_VM_SIZE_MAX) {
            /* This is pretty much impossible */
            PLCF_DEBUG("CIE augmentation string was too long");
            return err;
        }
        
        offset += augment_size;
    }
    // pl_vm_address_t augment_end = augment_offset + augment_size;
    
    /* Fetch the DWARF 4-only fields. */
    if (info->cie_version == 4) {
        if ((err = plcrash_async_mobject_read_uint8(mobj, address, offset, &info->address_size)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE address_size could not be read");
            return err;
        }
        offset += sizeof(uint8_t);
        
        if ((err = plcrash_async_mobject_read_uint8(mobj, address, offset, &info->segment_size)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("CIE segment_size could not be read");
            return err;
        }
        offset += sizeof(uint8_t);
    }
    
    /* Fetch the code alignment factor */
    pl_vm_size_t leb_size;
    if ((err = plcrash_async_dwarf_read_uleb128(mobj, address, offset, &info->code_alignment_factor, &leb_size)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to read CIE code alignment value");
        return err;
    }
    
    offset += leb_size;
    
    /* Fetch the data alignment factor */
    if ((err = plcrash_async_dwarf_read_sleb128(mobj, address, offset, &info->data_alignment_factor, &leb_size)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to read CIE data alignment value");
        return err;
    }
    
    offset += leb_size;
    
    /* Fetch the return address register */
    if ((err = plcrash_async_dwarf_read_uleb128(mobj, address, offset, &info->return_address_register, &leb_size)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to read CIE return address register");
        return err;
    }
    
    offset += leb_size;
    
    /*
     * Parse the augmentation string (and associated data); the definition of the augmentation string is left to implementors. Most
     * entities, including Apple, use the augmentation values defined by GCC and documented in the the LSB Core Standard -- we document
     * the supported flags here, but refer to LSB 4.1.0 Section 10.6.1.1.1 for more details.
     *
     * According to the DWARF specification (see DWARF4, Section 6.4.1), only a few fields are readable if an unknown augmentation
     * string is parsed. Since the augmentation string may define additional fields or data values in the CIE/FDE, the inclusion
     * of an unknown value makes most of the structure unparsable. However, GCC has defined an additional augmentation value, which,
     * if included as the first byte in the augmentation string, will define the total length of associated augmentation data; in
     * that case, one could skip over the full set of augmentation data, and safely parse the remainder of the structure.
     *
     * That said, an unknown augmentation flag will prevent reading of the remainder of the augmentation field, which
     * may result in the CIE being unusable. Ideally, future toolchains will only append new flag types to the end of the
     * string, allowing all known data to be read first. Given this, we terminate parsing upon hitting an unknown string
     * and leave the remainder of the augmentation data flags unset in our parsed info record.
     *
     * Supported augmentation flags (as defined by the LSB 4.1.0 Section 10.6.1.1.1):
     *
     *  'z': If present as the first character of the string, the the GCC Augmentation Data shall be present and the augmentation
     *       string and data be interpreted according to the LSB specification. The first field of the augmentation data will be
     *       a ULEB128 length value, allowing our parser to skip over the entire augmentation data field. In the case of
     *       unknown augmentation flags, the parser may still safely read past the entire Augmentation Data field, and the
     *       field constraints of DWARF4 Section 6.4.1 no longer apply.
     *
     *       If this value is not present, no other LSB-defined augmentation values may be parsed.
     *
     *  'L': May be present at any position after the first character of the augmentation string, but only if 'z' is
     *       the first character of the string. If present, it indicates the presence of one argument in the Augmentation Data
     *       of the CIE, and a corresponding argument in the Augmentation Data of the FDE. The argument in the Augmentation Data
     *       of the CIE is 1-byte and represents the pointer encoding used for the argument in the Augmentation Data of the FDE,
     *       which is the address of a language-specific data area (LSDA). The size of the LSDA pointer is specified by the pointer
     *       encoding used.
     *
     *  'P': May be present at any position after the first character of the augmentation string, but only if 'z' is
     *       the first character of the string. If present, it indicates the presence of two arguments in the Augmentation
     *       Data of the CIE. The first argument is 1-byte and represents the pointer encoding used for the second argument,
     *       which is the address of a personality routine handler. The personality routine is used to handle language and
     *       vendor-specific tasks. The system unwind library interface accesses the language-specific exception handling
     *       semantics via the pointer to the personality routine. The personality routine does not have an ABI-specific name.
     *       The size of the personality routine pointer is specified by the pointer encoding used.
     *
     *  'R': May be present at any position after the first character of the augmentation string, but only if 'z' is
     *       the first character of the string. If present, The Augmentation Data shall include a 1 byte argument that
     *       represents the pointer encoding for the address pointers used in the FDE.
     *
     *  'S': This is not documented by the LSB eh_frame specification. This value designates the frame as a signal
     *       frame, which may require special handling on some architectures/ABIs. This value is poorly documented, but
     *       seems to be unused on Mac OS X and iOS. The best available 'documentation' may be found in GCC's bugzilla:
     *         http://gcc.gnu.org/bugzilla/show_bug.cgi?id=26208
     */
    uint64_t augment_data_size = 0;
    if (info->has_eh_augmentation) {
        /* Fetch the total augmentation data size */
        if ((err = plcrash_async_dwarf_read_uleb128(mobj, address, offset, &augment_data_size, &leb_size)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to read the augmentation data uleb128 length");
            return err;
        }
        
        /* Determine the read position for the augmentation data */
        offset += leb_size;
        pl_vm_size_t data_offset = offset;
        
        /* Iterate the entries, skipping the initial 'z' */
        for (pl_vm_size_t i = 1; i < augment_size; i++) {
            bool terminate = false;
            
            /* Fetch the next flag */
            uint8_t uc;
            if ((err = plcrash_async_mobject_read_uint8(mobj, address, augment_offset+i, &uc)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read CIE augmentation data");
                return err;
            }
            
            switch (uc) {
                case 'L':
                    /* Read the LSDA encoding */
                    if ((err = plcrash_async_mobject_read_uint8(mobj, address, data_offset, &info->eh_augmentation.lsda_encoding)) != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to read the LSDA encoding value");
                        return err;
                    }
                    
                    info->eh_augmentation.has_lsda_encoding = true;
                    data_offset += sizeof(uint8_t);
                    break;
                    
                case 'P': {
                    machine_ptr value;
                    uint8_t ptr_enc;
                    size_t size;
                    
                    /* Read the personality routine pointer encoding */
                    if ((err = plcrash_async_mobject_read_uint8(mobj, address, data_offset, &ptr_enc)) != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to read the personality routine encoding value");
                        return err;
                    }
                    
                    data_offset += sizeof(uint8_t);
                    
                    /* Read the actual pointer value */
                    err = ptr_reader->read(mobj, address, data_offset, (DW_EH_PE_t) ptr_enc, &value, &size);
                    if (err != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to read the personality routine pointer value");
                        return err;
                    }

                    info->eh_augmentation.personality_address = value;
                    info->eh_augmentation.has_personality_address = true;
                    data_offset += size;
                    break;
                }
                    
                case 'R':
                    /* Read the pointer encoding */
                    if ((err = plcrash_async_mobject_read_uint8(mobj, address, data_offset, &info->eh_augmentation.pointer_encoding)) != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to read the LSDA encoding value");
                        return err;
                    }
                    
                    info->eh_augmentation.has_pointer_encoding = true;
                    data_offset += sizeof(uint8_t);
                    break;
                    break;
                    
                case 'S':
                    info->eh_augmentation.signal_frame = true;
                    break;
                    
                case '\0':
                    break;
                    
                default:
                    PLCF_DEBUG("Unknown augmentation entry of %c; terminating parsing early", uc);
                    terminate = true;
                    break;
            }
            
            if (terminate)
                break;
        }
    }
    
    /* Skip all (possibly partially parsed) augmentation data */
    offset += augment_data_size;
    
    /* Save the initial instructions offset and length. We compute this based on the current offset from the start of the CIE
     * value, not including the initial length field.
     *
     * We also validate the lengths/offsets here to prevent overflow/underflow. By this point, offset + cie_offset
     * must be valid, as well as offset >= lengthsize, or the read would have failed. It's possible that the declared
     * CIE length is short, however, which we validate here.
     */
    info->initial_instructions_offset = (pl_vm_address_t) info->cie_offset + (offset - length_size);
    
    if (info->cie_length < (info->initial_instructions_offset - info->cie_offset)) {
        PLCF_DEBUG("CIE length of 0x%" PRIu64 " declared to be less than the actual read length of 0x%" PRIu64, (uint64_t) info->cie_length,
                   (uint64_t)(info->initial_instructions_offset - info->cie_offset));
        return PLCRASH_EINVAL;
    }

    info->initial_instructions_length = (pl_vm_size_t)(info->cie_length - (info->initial_instructions_offset - info->cie_offset));
    
    return PLCRASH_ESUCCESS;
}

/**
 * Return the task relative address to the sequence of rules to be interpreted to create the initial setting of
 * each column in the table during DWARF interpretation. This address is relative to the start of the
 * eh_frame/debug_frame section base (eg, the mobj base address).
 *
 * @param info The CIE info for which the initial instruction offset should be returned.
 */
pl_vm_address_t plcrash_async_dwarf_cie_info_initial_instructions_offset (plcrash_async_dwarf_cie_info_t *info) {
    return info->initial_instructions_offset;
}

/**
 * Return the size of the initial instruction data, in bytes.
 *
 * @param info The CIE info for which the initial instruction length should be returned.
 */
pl_vm_size_t plcrash_async_dwarf_cie_info_initial_instructions_length (plcrash_async_dwarf_cie_info_t *info) {
    return info->initial_instructions_length;
}

/**
 * Free all resources associated with @a info.
 *
 * @param info A previously initialized info instance.
 */
void plcrash_async_dwarf_cie_info_free (plcrash_async_dwarf_cie_info_t *info) {
    // No-op
}

/* Provide explicit 32/64-bit instantiations */
template
plcrash_error_t plcrash_async_dwarf_cie_info_init<uint32_t> (plcrash_async_dwarf_cie_info_t *info,
                                                                             plcrash_async_mobject_t *mobj,
                                                                             const plcrash_async_byteorder_t *byteorder,
                                                                             gnu_ehptr_reader<uint32_t> *ptr_reader,
                                                                             pl_vm_address_t address);

template
plcrash_error_t plcrash_async_dwarf_cie_info_init<uint64_t> (plcrash_async_dwarf_cie_info_t *info,
                                                                             plcrash_async_mobject_t *mobj,
                                                                             const plcrash_async_byteorder_t *byteorder,
                                                                             gnu_ehptr_reader<uint64_t> *ptr_reader,
                                                                             pl_vm_address_t address);

/*
 * @}
 */

}
PLCR_CPP_END_NS

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
