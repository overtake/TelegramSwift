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

#ifndef PLCRASH_ASYNC_DWARF_ENCODING_H
#define PLCRASH_ASYNC_DWARF_ENCODING_H 1

#include "PLCrashAsync.h"
#include "PLCrashAsyncImageList.h"
#include "PLCrashAsyncThread.h"

#include "PLCrashAsyncDwarfPrimitives.hpp"
#include "PLCrashAsyncDwarfFDE.hpp"

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
 *
 * A DWARF frame reader. Performs DWARF eh_frame/debug_frame parsing from a backing memory object.
 */
class dwarf_frame_reader {
public:
    plcrash_error_t init (plcrash_async_mobject_t *mobj,
                          const plcrash_async_byteorder_t *byteorder,
                          bool m64,
                          bool debug_frame);
    
    plcrash_error_t find_fde (pl_vm_off_t offset,
                              pl_vm_address_t pc,
                              plcrash_async_dwarf_fde_info_t *fde_info);

private:
    /** A memory object containing the DWARF data at the starting address. */
    plcrash_async_mobject_t *_mobj;
    
    /** The byte order of the encoded data. */
    const plcrash_async_byteorder_t *_byteorder;

    /** True if the target system uses 64-bit pointers, false if it uses 32-bit pointers. */
    bool _m64;
    
    /** True if this is a debug_frame section */
    bool _debug_frame;
};
    
PLCR_CPP_END_NS
}

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_ENCODING_H */
