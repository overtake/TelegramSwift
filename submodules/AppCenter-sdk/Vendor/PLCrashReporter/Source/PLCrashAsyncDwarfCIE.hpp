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

#ifndef PLCRASH_ASYNC_DWARF_CIE_H
#define PLCRASH_ASYNC_DWARF_CIE_H 1

#include "PLCrashAsync.h"
#include "PLCrashAsyncMObject.h"
#include "PLCrashAsyncDwarfPrimitives.hpp"

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */

/**
 * @internal
 * DWARF Common Information Entry.
 */
typedef struct plcrash_async_dwarf_cie_info {
    /**
     * The task-relative address of the CIE record (not including the initial length field),
     * relative to the start of the eh_frame/debug_frame section base (eg, the mobj base address).
     */
    uint64_t cie_offset;
    
    /** The CIE record length, not including the initial length field. */
    uint64_t cie_length;
    
    /**
     * The CIE identifier. This will be either 4 or 8 bytes, depending on the decoded DWARF
     * format.
     *
     * @par GCC .eh_frame.
     * For GCC3 eh_frame sections, this value will always be 0.
     *
     * @par DWARF
     * For DWARF debug_frame sections, this value will always be UINT32_MAX or UINT64_MAX for
     * the DWARF 32-bit and 64-bit formats, respectively.
     */
    uint64_t cie_id;
    
    /**
     * The CIE version. Supported version numbers:
     * - GCC3 .eh_frame: 1
     * - DWARF3 debug_frame: 3
     * - DWARF4 debug_frame: 4
     */
    uint8_t cie_version;
    
    /**
     * The size in bytes of an address (or the offset portion of an address for segmented addressing) on
     * the target system. This value will only be present in DWARF4 CIE records; on non-DWARF4 records,
     * the value will be initialized to zero.
     *
     * Defined in the DWARF4 standard, Section 7.20.
     */
    uint8_t address_size;
    
    /**
     * The size in bytes of a segment selector on the target system, or 0. This value will
     * only be present in DWARF4 CIE records; on non-DWARF4 records, the value will be initialized
     * to zero.
     *
     * Defined in the DWARF4 standard, Section 7.20.
     */
    uint8_t segment_size;
    
    /**
     * Code alignment factor. A constant that is factored out of all advance location instructions; see DWARF4 Section 6.4.2.1.
     */
    uint64_t code_alignment_factor;
    
    /** Data alignment factor. A constant that is factored out of certain offset instructions; see DWARF4 Section 6.4.2.1. */
    int64_t data_alignment_factor;
    
    /** Return address register. A constant that constant that indicates which column in the rule table represents the return
     * address of the function. Note that this column might not correspond to an actual machine register. */
    uint64_t return_address_register;
    
    /** If true, the GCC eh_frame augmentation data is available. See the LSB 4.1.0 Core Standard, Section 10.6.1.1.1 */
    bool has_eh_augmentation;
    
    /** Data parsed from the GCC eh_frame augmentation data. See the LSB 4.1.0 Core Standard, Section 10.6.1.1.1. */
    struct {
        /** If true, an LSDA encoding type was supplied in the CIE augmentation data. */
        bool has_lsda_encoding;
        
        /**
         * The DW_EH_PE_t encoding to be used to decode the LSDA pointer value in the FDE, if any. This value is undefined
         * if has_lsda_encoding is not true.
         */
        uint8_t lsda_encoding;
        
        
        /** If true, a personality address value was supplied in the CIE augmentation data. */
        bool has_personality_address;
        
        /**
         * The decoded pointer value for the personality routine for this CIE. The personality routine is
         * used to handle language and vendor-specific tasks.. This value is undefined if has_personality_address
         * is not true.
         */
        uint64_t personality_address;
        
        /** If true, the FDE pointer encoding type was supplied in the CIE augmentation data. */
        bool has_pointer_encoding;
        
        /**
         * The DW_EH_PE_t encoding to be used to decode address pointer values in the FDE, if any. This value is undefined
         * if has_lsda_encoding is not true.
         */
        uint8_t pointer_encoding;
        
        /**
         * This flag is part of the GCC .eh_frame implementation, but is not defined by the LSB eh_frame specification. This
         * value designates the frame as a signal frame, which may require special handling on some architectures/ABIs. This
         * value is poorly documented, but seems to be unused on Mac OS X and iOS. The best available 'documentation' may
         * be found in GCC's bugzilla: http://gcc.gnu.org/bugzilla/show_bug.cgi?id=26208 */
        bool signal_frame;
    } eh_augmentation;
    
    /**
     * The task relative address to the sequence of rules to be interpreted to create the initial setting of
     * each column in the table during DWARF interpretation. This address is relative to the start of the
     * eh_frame/debug_frame section base (eg, the mobj base address).
     */
    pl_vm_address_t initial_instructions_offset;

    /** The size of the initial instruction data, in bytes. */
    pl_vm_size_t initial_instructions_length;
} plcrash_async_dwarf_cie_info_t;

template <typename machine_ptr>
plcrash_error_t plcrash_async_dwarf_cie_info_init (plcrash_async_dwarf_cie_info_t *info,
                                                   plcrash_async_mobject_t *mobj,
                                                   const plcrash_async_byteorder_t *byteorder,
                                                   gnu_ehptr_reader<machine_ptr> *ptr_reader,
                                                   pl_vm_address_t address);

pl_vm_address_t plcrash_async_dwarf_cie_info_initial_instructions_offset (plcrash_async_dwarf_cie_info_t *info);
pl_vm_size_t plcrash_async_dwarf_cie_info_initial_instructions_length (plcrash_async_dwarf_cie_info_t *info);

void plcrash_async_dwarf_cie_info_free (plcrash_async_dwarf_cie_info_t *info);


/*
 * @}
 */

}
PLCR_CPP_END_NS

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_CIE_H */
