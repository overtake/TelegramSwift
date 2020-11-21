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

#import "PLCrashTestCase.h"

#include "PLCrashAsyncDwarfEncoding.hpp"
#include "PLCrashAsyncDwarfPrimitives.hpp"
#include "PLCrashAsyncDwarfFDE.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

struct __attribute__((packed)) cie_data {
    struct __attribute__((packed)) {
        uint32_t l1;
        uint64_t l2;
    } length;
    
    uint64_t cie_id;
    uint8_t cie_version;
    
    uint8_t augmentation[3];
    
    uint8_t code_alignment_factor;
    uint8_t data_alignment_factor;
    uint8_t return_address_register;
    
    struct __attribute__((packed)) {
        uint8_t length;
        uint8_t ptr_encoding;
    } augmentation_data;

    uint8_t initial_instructions[0];
};

struct __attribute__((packed)) fde_data {
    struct __attribute__((packed)) {
        uint32_t l1;
        uint64_t l2;
    } length;
    
    uint64_t cie_ptr;
    
    uint64_t pc_start;
    uint64_t pc_length;

    uint8_t instructions;
};

@interface PLCrashAsyncDwarfFDETests : PLCrashTestCase {
    struct __attribute__((packed)) {
        struct cie_data cie;
        struct fde_data fde;
        uint64_t indirect_pc_target;
    } _data;
}
@end

@implementation PLCrashAsyncDwarfFDETests

- (void) setUp {
    /* Set up default CIE data */
    _data.cie.length.l1 = UINT32_MAX; /* 64-bit entry flag */
    _data.cie.length.l2 = sizeof(_data.cie) - sizeof(_data.cie.length);
    
    _data.cie.cie_id = 0x0;
    _data.cie.cie_version = 3;
    
    _data.cie.augmentation[0] = 'z';
    _data.cie.augmentation[1] = 'R'; // FDE address encoding
    _data.cie.augmentation[2] = '\0';
    
    /* NOTE: This is a ULEB128 value, and thus will fail if it's not representable in the first 7 bits */
    _data.cie.augmentation_data.length = sizeof(_data.cie.augmentation_data) - 1; /* size of the augmentation data, minus the actual length field */
    STAssertEquals((uint8_t)(_data.cie.augmentation_data.length & 0x7f), _data.cie.augmentation_data.length, @"ULEB128 encoding will not fit in the available byte");
    
    _data.cie.augmentation_data.ptr_encoding = DW_EH_PE_udata8; // FDE address pointer encoding.
    
    _data.cie.code_alignment_factor = 0;
    _data.cie.data_alignment_factor = 0;
    _data.cie.return_address_register = 0;


    /* Set up the default FDE data */
    _data.fde.length.l1 = UINT32_MAX; /* 64-bit entry flag */
    _data.fde.length.l2 = sizeof(_data.fde) - sizeof(_data.fde.length);

    _data.fde.cie_ptr = 0; // offset from the start of our 'eh_frame'
    
    _data.fde.pc_start = 0xFF;
    _data.fde.pc_length = 0xAB;
}

- (void) tearDown {
}

/**
 * Test default (standard path, no error) FDE parsing
 */
- (void) testParseFDE {
    plcrash_async_dwarf_fde_info_t info;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    /* Set up test data */
    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_data, sizeof(_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize memory mapping");

    /* Test decoding */
    err = plcrash_async_dwarf_fde_info_init<uint64_t>(&info, &mobj, &plcrash_async_byteorder_direct, (pl_vm_address_t) &_data.fde, true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to parse DWARF info");

    STAssertEquals(info.fde_offset, (pl_vm_address_t) ((uintptr_t)&_data.fde - (uintptr_t)&_data + sizeof(_data.fde.length)), @"Incorrect FDE offset");
    STAssertEquals(info.fde_length, (uint64_t) (sizeof(_data.fde) - sizeof(_data.fde.length)), @"Incorrect FDE length");

    STAssertEquals(info.cie_offset, (pl_vm_address_t) ((uintptr_t)&_data.cie - (uintptr_t)&_data), @"Incorrect CIE offset");
    
    STAssertEquals(info.pc_start, _data.fde.pc_start, @"Incorrect PC start value");
    STAssertEquals(info.pc_end, (uint64_t)_data.fde.pc_start + _data.fde.pc_length, @"Incorrect PC end value");
    
    STAssertEquals(plcrash_async_dwarf_fde_info_instructions_offset(&info), (pl_vm_address_t) ((uint64_t)&_data.fde.instructions - (uint64_t)&_data), @"Incorrect instruction offset");
    STAssertEquals(plcrash_async_dwarf_fde_info_instructions_length(&info), (pl_vm_size_t) sizeof(_data.fde.instructions), @"Incorrect instruction offset");

    /* Clean up */
    plcrash_async_dwarf_fde_info_free(&info);
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test FDE pointer encoding handling.
 */
- (void) testParseFDEPointerEncoding {
    plcrash_async_dwarf_fde_info_t info;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    /* Set up test data; we enable indirect encoding as to verify that the specified encoding is used. */
    _data.indirect_pc_target = 0xFF;
    _data.fde.pc_start = (uint64_t) &_data.indirect_pc_target;
    _data.cie.augmentation_data.ptr_encoding = DW_EH_PE_indirect|DW_EH_PE_absptr;

    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_data, sizeof(_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize memory mapping");

    /* Test decoding */
    err = plcrash_async_dwarf_fde_info_init<uint64_t>(&info, &mobj, &plcrash_async_byteorder_direct, (pl_vm_address_t) &_data.fde, true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to parse DWARF info");
    
    STAssertEquals(info.pc_start, (uint64_t)0xFF, @"Incorrect PC start value");
    STAssertEquals(info.pc_end, (uint64_t)0xFF + _data.fde.pc_length, @"Incorrect PC end value");

    /* Clean up */
    plcrash_async_dwarf_fde_info_free(&info);
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test handling of eh_frame decoding (as opposed to the default debug_frame test case).
 */
- (void) testParseFDEEHFrame {
    plcrash_async_dwarf_fde_info_t info;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    /* Set up test data; we enable indirect encoding as to verify that the specified encoding is used. */
    _data.fde.cie_ptr = (uintptr_t)&_data.fde.cie_ptr - (uintptr_t)&_data; // use an eh_frame-style offset.

    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_data, sizeof(_data), false);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize memory mapping");
    
    /* Test decoding; if it succeeds, it means the CIE was correctly dereferenced using the ehframe CIE
     * offset rules. */
    err = plcrash_async_dwarf_fde_info_init<uint64_t>(&info, &mobj, &plcrash_async_byteorder_direct, (pl_vm_address_t) &_data.fde, false);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to parse DWARF info");
        
    /* Clean up */
    plcrash_async_dwarf_fde_info_free(&info);
    plcrash_async_mobject_free(&mobj);
}

@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
