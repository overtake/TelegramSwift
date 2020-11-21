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
#include "PLCrashAsyncDwarfCIE.hpp"
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
    
    uint8_t augmentation[7];
    
    uint8_t address_size;
    uint8_t segment_size;
    
    uint8_t code_alignment_factor;
    uint8_t data_alignment_factor;
    uint8_t return_address_register;
    
    uint8_t augmentation_data[6];

    /* We don't supply any instructions below; this array exists to test the initial_instruction_length handling */
    uint8_t initial_instructions[4]; 
};

@interface PLCrashAsyncDwarfCIETests : PLCrashTestCase {
    struct cie_data _cie_data;
    gnu_ehptr_reader<uint64_t> *_ptr_state;
}@end

@implementation PLCrashAsyncDwarfCIETests

- (void) setUp {
    /* Set up the default pointer decode state. */
    _ptr_state = new gnu_ehptr_reader<uint64_t>(&plcrash_async_byteorder_direct);
    
    /* Set up default CIE data */
    _cie_data.length.l1 = UINT32_MAX; /* 64-bit entry flag */
    _cie_data.length.l2 = sizeof(_cie_data) - sizeof(_cie_data.length);
    
    _cie_data.cie_id = 0x0;
    _cie_data.cie_version = 4;
    
    _cie_data.augmentation[0] = 'z';
    _cie_data.augmentation[1] = 'L'; // LSDA encoding
    _cie_data.augmentation[2] = 'P'; // Personality encoding
    _cie_data.augmentation[3] = 'R'; // FDE address encoding
    _cie_data.augmentation[4] = 'S'; // Signal frame
    _cie_data.augmentation[5] = 'b'; // known-bad augmentation flag; used to test termination of parsing
    _cie_data.augmentation[6] = '\0';
    
    
    /* NOTE: This is a ULEB128 value, and thus will fail if it's not representable in the first 7 bits */
    _cie_data.augmentation_data[0] = sizeof(_cie_data.augmentation_data ) - 1 /* size, minus this field */;
    STAssertEquals((uint8_t)(_cie_data.augmentation_data[0] & 0x7f), _cie_data.augmentation_data[0], @"ULEB128 encoding will not fit in the available byte");
    
    _cie_data.augmentation_data[1] = DW_EH_PE_udata4; // LSDA encoding
    _cie_data.augmentation_data[2] = DW_EH_PE_udata2; // Personality pointer encoding
    _cie_data.augmentation_data[3] = 0xAA; // Personality udata2 pointer data
    _cie_data.augmentation_data[4] = 0xAA; // Personality udata2 pointer data
    _cie_data.augmentation_data[5] = DW_EH_PE_udata8; // FDE address pointer encoding.
    
    _cie_data.address_size = 4;
    _cie_data.segment_size = 4;
    
    _cie_data.code_alignment_factor = 1;
    _cie_data.data_alignment_factor = 2;
    _cie_data.return_address_register = 3;
    
    _cie_data.initial_instructions[0] = 0xA;
    _cie_data.initial_instructions[1] = 0xB;
    _cie_data.initial_instructions[2] = 0xC;
    _cie_data.initial_instructions[3] = 0xD;
}

- (void) tearDown {
    delete _ptr_state;
}

/**
 * Test default (standard path, no error) CIE parsing
 */
- (void) testParseCIE {
    plcrash_async_dwarf_cie_info_t cie;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_cie_data, sizeof(_cie_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize mobj");
    
    
    /* Try to parse the CIE */
    pl_vm_size_t cie_length = sizeof(_cie_data) - sizeof(_cie_data.length);
    err = plcrash_async_dwarf_cie_info_init(&cie, &mobj, &plcrash_async_byteorder_direct, _ptr_state, (pl_vm_address_t) &_cie_data);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize CIE info");
    STAssertEquals(cie.cie_offset, (uint64_t)sizeof(_cie_data.length), @"Incorrect offset");
    STAssertEquals(cie.cie_length, (uint64_t)cie_length, @"Incorrect length");
    
    /* Test basics */
    STAssertEquals(cie.cie_id, _cie_data.cie_id, @"Incorrect ID");
    STAssertEquals(cie.cie_version, _cie_data.cie_version, @"Incorrect version");
    
    /* DWARF4 fields */
    STAssertEquals(cie.address_size, _cie_data.address_size, @"Incorrect address size");
    STAssertEquals(cie.segment_size, _cie_data.segment_size, @"Incorrect segment size");
    
    /* Alignment and return address fields */
    STAssertEquals(cie.code_alignment_factor, (uint64_t)_cie_data.code_alignment_factor, @"Incorrect code alignment factor");
    STAssertEquals(cie.data_alignment_factor, (int64_t)_cie_data.data_alignment_factor, @"Incorrect data alignment factor");
    STAssertEquals(cie.return_address_register, (uint64_t)_cie_data.return_address_register, @"Incorrect return address register");
    
    /* Augmentation handling */
    STAssertTrue(cie.has_eh_augmentation, @"No augmentation data was found");
    
    STAssertTrue(cie.eh_augmentation.has_lsda_encoding, @"No LSDA data was found");
    STAssertEquals(cie.eh_augmentation.lsda_encoding, (uint8_t)DW_EH_PE_udata4, @"Incorrect LSDA encoding");
    
    STAssertTrue(cie.eh_augmentation.has_personality_address, @"No personality data was found");
    STAssertEquals(cie.eh_augmentation.personality_address, (uint64_t)0xAAAA, @"Incorrect personality address");
    
    STAssertTrue(cie.eh_augmentation.has_pointer_encoding, @"No pointer encoding was found");
    STAssertEquals(cie.eh_augmentation.pointer_encoding, (uint8_t)DW_EH_PE_udata8, @"Incorrect pointer encoding");
    
    STAssertTrue(cie.eh_augmentation.signal_frame, @"Did not parse signal frame flag");
    
    /* Instructions */
    STAssertEquals(plcrash_async_dwarf_cie_info_initial_instructions_offset(&cie), ((pl_vm_address_t)_cie_data.initial_instructions) - (pl_vm_address_t) &_cie_data, @"Incorrect initial instruction offset");
    STAssertEquals(plcrash_async_dwarf_cie_info_initial_instructions_length(&cie), (pl_vm_size_t) sizeof(_cie_data.initial_instructions), @"Incorrect instruction length");
    for (int i = 0; i < sizeof(_cie_data.initial_instructions) / sizeof(_cie_data.initial_instructions[0]); i++) {
        uint8_t opcode;
        STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_read_uint8(&mobj, (pl_vm_address_t) &_cie_data, plcrash_async_dwarf_cie_info_initial_instructions_offset(&cie)+i, &opcode), @"Failed to read instruction");
        STAssertEquals((uint8_t)(0xA+i), opcode, @"Incorrect opcode");
    }

    /* Clean up */
    plcrash_async_dwarf_cie_info_free(&cie);
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test parsing of a CIE entry with an unknown augmentation string
 */
- (void) testParseCIEBadAugmentation {
    plcrash_async_dwarf_cie_info_t cie;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    _cie_data.augmentation[0] = 'P';
    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_cie_data, sizeof(_cie_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize mobj");
    
    /* Try to parse the CIE, verify failure */
    err = plcrash_async_dwarf_cie_info_init(&cie, &mobj, &plcrash_async_byteorder_direct, _ptr_state, (pl_vm_address_t) &_cie_data);
    STAssertNotEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize CIE info");
    
    /* Clean up */
    plcrash_async_dwarf_cie_info_free(&cie);
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test parsing of a CIE entry with a bad identifier.
 */
- (void) testParseCIEBadIdentifier {
    plcrash_async_dwarf_cie_info_t cie;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    _cie_data.cie_id = 5; // invalid id
    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_cie_data, sizeof(_cie_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize mobj");
    
    /* Try to parse the CIE, verify failure */
    err = plcrash_async_dwarf_cie_info_init(&cie, &mobj, &plcrash_async_byteorder_direct, _ptr_state, (pl_vm_address_t) &_cie_data);
    STAssertNotEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize CIE info");
    
    /* Clean up */
    plcrash_async_dwarf_cie_info_free(&cie);
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test parsing of a CIE entry with a bad version.
 */
- (void) testParseCIEBadVersion {
    plcrash_async_dwarf_cie_info_t cie;
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    _cie_data.cie_version = (uint8_t)9999; // invalid version
    err = plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &_cie_data, sizeof(_cie_data), true);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize mobj");
    
    /* Try to parse the CIE, verify failure */
    err = plcrash_async_dwarf_cie_info_init(&cie, &mobj, &plcrash_async_byteorder_direct, _ptr_state, (pl_vm_address_t) &_cie_data);
    STAssertNotEquals(err, PLCRASH_ESUCCESS, @"Failed to initialize CIE info");
    
    /* Clean up */
    plcrash_async_dwarf_cie_info_free(&cie);
    plcrash_async_mobject_free(&mobj);
}

@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
