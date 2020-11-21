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

#ifndef PLCRASH_ASYNC_DWARF_OPSTREAM_H
#define PLCRASH_ASYNC_DWARF_OPSTREAM_H

#include <cstddef>

#include "PLCrashAsync.h"
#include "PLCrashAsyncMObject.h"
#include "PLCrashAsyncDwarfPrimitives.hpp"

#include "PLCrashMacros.h"
#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

/**
 * @ingroup plcrash_async_dwarf_private_opstream
 * @internal
 * @{
 */

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 * A simple opcode stream reader for use with DWARF opcode/CFA evaluation.
 */
class dwarf_opstream {
    /** Current position within the op stream */
    void *_p;
    
    /** Backing memory object */
    plcrash_async_mobject_t *_mobj;
    
    /** Target-relative starting address within the memory object */
    pl_vm_address_t _start;
    
    /** Target-relative end address within the memory object */
    pl_vm_address_t _end;

    /** Locally mapped starting address. */
    void *_instr;

    /** Locally mapped ending address. */
    void *_instr_max;
    
    /** Byte order for the byte stream */
    const plcrash_async_byteorder_t *_byteorder;
    
public:
    plcrash_error_t init (plcrash_async_mobject_t *mobj,
                          const plcrash_async_byteorder_t *byteorder,
                          pl_vm_address_t address,
                          pl_vm_off_t offset,
                          pl_vm_size_t length);
    
    template <typename V> inline bool read_intU (V *result);
    inline bool read_uintmax64 (uint8_t data_size, uint64_t *result);
    inline bool read_uleb128 (uint64_t *result);
    inline bool read_sleb128 (int64_t *result);
    template <typename machine_ptr> inline bool read_gnueh_ptr (gnu_ehptr_reader<machine_ptr> *reader, DW_EH_PE_t encoding, machine_ptr *result);
    inline bool skip (pl_vm_off_t offset);
    inline uintptr_t get_position (void);
};


/**
 * Read a value of type and size @a V from the stream, verifying that the read will not overrun
 * the mapped range and advancing the stream position past the read value.
 *
 * @warning Multi-byte values (either 2, 4, or 8 bytes in size) will be byte swapped.
 *
 * @param result The destination to which the result will be written.
 *
 * @return Returns true on success, or false if the read would exceed the boundry specified by @a maxpos.
 */
template <typename V> inline bool dwarf_opstream::read_intU (V *result) {
    if (_p < _instr)
        return false;

    if ((uint8_t *)_instr_max - (uint8_t *)_p < sizeof(V)) {
        return false;
    }
    
    *result = *((V *)_p);
    
    switch (sizeof(V)) {
        case 2:
            *result = _byteorder->swap16(*result);
            break;
        case 4:
            *result = _byteorder->swap32(*result);
            break;
        case 8:
            *result = _byteorder->swap64(*result);
            break;
        default:
            break;
    }
    
    _p = ((uint8_t *)_p) + sizeof(V);
    return true;
}
    
/**
 * @internal
 *
 * Read a value that is either 1, 2, 4, or 8 bytes in size, applying byte swapping. Verifies that the read
 * will not overrun the mapped range and advancing the stream position past the read value.
 *
 * @param data_size The size of the value to be read. If an unsupported size is supplied, false will be returned.
 * @param result The destination to which the result will be written.
 *
 * @return Returns true on success, or false if the read would exceed the boundry specified by @a maxpos.
 */
inline bool dwarf_opstream::read_uintmax64 (uint8_t data_size, uint64_t *result) {
    pl_vm_off_t offset = ((uint8_t *)_p - (uint8_t *)_instr);
    plcrash_error_t err;

    if ((err = plcrash_async_dwarf_read_uintmax64(_mobj, _byteorder, _start, offset, data_size, result)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Read of integer value failed with %u", err);
        return false;
    }
    
    /* Advance the position */
    if (!skip(data_size)) {
        PLCF_DEBUG("Integer value extends past end of opstream");
        return false;
    }

    return true;
}
    
/**
 * Read a ULEB128 value from the stream, verifying that the read will not overrun
 * the mapped range and advancing the stream position past the read value.
 *
 * @param result The destination to which the result will be written.
 *
 * @return Returns true on success, or false if the read would exceed the boundry specified by @a maxpos.
 */
inline bool dwarf_opstream::read_uleb128 (uint64_t *result) {
    plcrash_error_t err;
    pl_vm_off_t offset = ((uint8_t *)_p - (uint8_t *)_instr);
    pl_vm_size_t lebsize;

    if ((err = plcrash_async_dwarf_read_uleb128(_mobj, _start, offset, result, &lebsize)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Read of ULEB128 value failed with %u", err);
        return false;
    }

    /* Advance the position */
    if (!skip(lebsize)) {
        PLCF_DEBUG("ULEB128 value extends past end of opstream");
        return false;
    }
    return true;
}

/**
 * Read a SLEB128 value from the stream, verifying that the read will not overrun
 * the mapped range and advancing the stream position past the read value.
 *
 * @param result The destination to which the result will be written.
 *
 * @return Returns true on success, or false if the read would exceed the boundry specified by @a maxpos.
 */
inline bool dwarf_opstream::read_sleb128 (int64_t *result) {
    plcrash_error_t err;
    pl_vm_off_t offset = ((uint8_t *)_p - (uint8_t *)_instr);
    pl_vm_size_t lebsize;
    
    if ((err = plcrash_async_dwarf_read_sleb128(_mobj, _start, offset, result, &lebsize)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Read of ULEB128 value failed with %u", err);
        return false;
    }
    
    /* Advance the position */
    if (!skip(lebsize)) {
        PLCF_DEBUG("SLEB128 value extends past end of opstream");
        return false;
    }
    return true;
}

/**
 * Read a GNU DWARF encoded pointer value from the stream, verifying that the read does not overrun
 * the mapped range and advancing the stream position past the read value.
 *
 * @param reader The GNU eh_frame pointer reader to be used for reading.
 * @param encoding The pointer encoding to use when decoding the pointer value.
 * @param result On success, the pointer value.
 *
 * @tparam machine_ptr The native pointer word size of the target.
 */
template <typename machine_ptr>
inline bool dwarf_opstream::read_gnueh_ptr (gnu_ehptr_reader<machine_ptr> *reader, DW_EH_PE_t encoding, machine_ptr *result)
{
    pl_vm_off_t offset = ((uint8_t *)_p - (uint8_t *)_instr);
    plcrash_error_t err;
    size_t size;

    /* Perform the read; this will safely handle the case where the target falls outside
     * of the maximum range */
    if ((err = reader->read(_mobj, _start, offset, encoding, result, &size)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Read of GNU EH pointer value failed with %u", err);
        return false;
    }

    /* Sanity check the size; this should never occur */
    // This issue triggers clang's new 'tautological' warnings on some host platforms with some types of pl_vm_off_t.
    // Testing tautological correctness and *documenting* the issue is the whole point of the check, even though it
    // may always be true on some hosts.
    // Since older versions of clang do not support -Wtautological, we have to enable -Wunknown-pragmas first
    PLCR_PRAGMA_CLANG("clang diagnostic push");
    PLCR_PRAGMA_CLANG("clang diagnostic ignored \"-Wunknown-pragmas\"");
    PLCR_PRAGMA_CLANG("clang diagnostic ignored \"-Wtautological-constant-out-of-range-compare\"");
    if (size > PL_VM_OFF_MAX) {
        PLCF_DEBUG("GNU EH pointer size exceeds our maximum supported offset size");
        return false;
    }
    PLCR_PRAGMA_CLANG("clang diagnostic pop");

    /* Advance the position */
    if (!skip(size)) {
        PLCF_DEBUG("GNU EH pointer value extends past end of opstream");
        return false;
    }
    
    return true;
}

/**
 * Apply the given offset to the instruction position, returning false
 * if the position falls outside of the bounds of the mapped region.
 */
inline bool dwarf_opstream::skip (pl_vm_off_t offset) {
    void *p = ((uint8_t *)_p) + offset;
    if (p < _instr || p > _instr_max)
        return false;

    _p = p;
    return true;
}

/**
 * Return the current pointer position within the opcode stream, relative
 * to the start of the stream.
 */
inline uintptr_t dwarf_opstream::get_position (void) {
    return ((uintptr_t)_p) - ((uintptr_t) _instr);
}
    
PLCR_CPP_END_NS
}
    
/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_OPSTREAM_H */
