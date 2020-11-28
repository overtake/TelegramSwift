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

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

@interface PLCrashAsyncDwarfPrimativesTests : PLCrashTestCase {
}
@end

@implementation PLCrashAsyncDwarfPrimativesTests

/**
 * Test aligned pointer decoding
 */
- (void) testReadAlignedEncodedPointer {
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    uint64_t result;
    size_t size;

    /* 64-bit reader (supports both 32-bit and 64-bit test hosts) */
    gnu_ehptr_reader<uint64_t> reader(plcrash_async_byteorder_big_endian());
    
    /* Test data */
    const uint8_t aligned_data[] = { 0xab, 0xac, 0xad, 0xae, 0xaf, 0xba, 0xbb,
                                     0xbc, 0xbd, 0xbe, 0xbf, 0xc0, 0xc1, 0xc2, 0xc3 };
    
    /* Default state; 1 byte shy of 8 byte alignment. */
    reader.set_frame_section_base((uint64_t) aligned_data, (uint64_t) 1);

    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) aligned_data, sizeof(aligned_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &aligned_data[0], 0, DW_EH_PE_aligned, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode aligned value");
    
    /* The VM base is 1 byte shy of eight byte alignment. To align the pointer value, we'll have to skip 7 bytes. */
    STAssertEquals(result, (uint64_t) 0xbcbdbebfc0c1c2c3, @"Incorrect value decoded, got 0%" PRIx64, (uint64_t) result);
    STAssertEquals(size, (size_t)15, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test indirect pointer handling.
 */
- (void) testReadIndirectEncodedPointer {
    plcrash_async_mobject_t mobj;
    gnu_ehptr_reader<uint64_t> reader(&plcrash_async_byteorder_direct);
    plcrash_error_t err;
    uint64_t result;
    size_t size;
    
    /* Test data */
    struct {
        uint64_t udata8;
        uint64_t ptr;
    } test_data;
    test_data.udata8 = (uint64_t) &test_data.ptr;
    test_data.ptr = UINT32_MAX;
        
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data.udata8, 0, (DW_EH_PE_t) (DW_EH_PE_indirect|DW_EH_PE_udata8), &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode aligned value");
    
    STAssertEquals(result, (uint64_t) test_data.ptr, @"Incorrect value decoded, got 0%" PRIx32, (uint32_t) result);
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test pointer offset type handling
 */
- (void) testReadEncodedPointerOffset {
    plcrash_async_mobject_t mobj;
    gnu_ehptr_reader<uint64_t> reader(&plcrash_async_byteorder_direct);
    plcrash_error_t err;
    uint64_t result;
    size_t size;
    
    /* Test data */
    union {
        uint64_t udata8;
    } test_data;
    
    /* Default state */
#define T_TEXT_BASE 1
#define T_DATA_BASE 2
#define T_FUNC_BASE 3
    reader.set_text_base(T_TEXT_BASE);
    reader.set_data_base(T_DATA_BASE);
    reader.set_func_base(T_FUNC_BASE);
    
    /* Test absptr */
    test_data.udata8 = UINT64_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data, 0, DW_EH_PE_absptr, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)UINT64_MAX, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test pcrel */
    test_data.udata8 = 5;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data, 0, DW_EH_PE_pcrel, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode pcrel value");
    STAssertEquals(result, (uint64_t)&test_data + 5, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test textrel */
    test_data.udata8 = 5;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data, 0, DW_EH_PE_textrel, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode textrel value");
    STAssertEquals(result, (uint64_t)test_data.udata8+T_TEXT_BASE, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test datarel */
    test_data.udata8 = 5;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data, 0, DW_EH_PE_datarel, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode datarel value");
    STAssertEquals(result, (uint64_t)test_data.udata8+T_DATA_BASE, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test funcrel */
    test_data.udata8 = 5;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t) &test_data, 0, DW_EH_PE_funcrel, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode funcrel value");
    STAssertEquals(result, (uint64_t)test_data.udata8+T_FUNC_BASE, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test pointer value type decoding.
 */
- (void) testReadEncodedPointerValue {
    plcrash_async_mobject_t mobj;
    gnu_ehptr_reader<uint64_t> reader(&plcrash_async_byteorder_direct);
    plcrash_error_t err;
    uint64_t result;
    size_t size;
    
    /* Test data */
    union {
        uint8_t leb128[2];
        
        uint16_t udata2;
        uint32_t udata4;
        uint64_t udata8;
        
        int16_t sdata2;
        int16_t sdata4;
        int16_t sdata8;
    } test_data;
        
    /* We use an -1 +1 offset below to verify the address+offset handling for all data types */
    
    /* Test ULEB128 */
    test_data.leb128[0] = 2;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, DW_EH_PE_uleb128, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)1, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test udata2 */
    test_data.udata2 = UINT16_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, DW_EH_PE_udata2, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode udata2");
    STAssertEquals(result, (uint64_t)UINT16_MAX, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)2, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test udata4 */
    test_data.udata4 = UINT32_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, DW_EH_PE_udata4, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode udata4");
    STAssertEquals(result, (uint64_t)UINT32_MAX, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)4, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test udata8 */
    test_data.udata8 = UINT64_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, DW_EH_PE_udata8, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode udata8");
    STAssertEquals(result, (uint64_t)UINT64_MAX, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    
    /* Test SLEB128 (including pcrel validation to ensure that signed values are handled as offsets) */
    test_data.leb128[0] = 0x7e; // -2
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, (DW_EH_PE_t)(DW_EH_PE_pcrel|DW_EH_PE_sleb128), &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, ((uint64_t) &test_data) - 2, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)1, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test sdata2 (including pcrel validation) */
    test_data.sdata2 = -256;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, (DW_EH_PE_t)(DW_EH_PE_pcrel|DW_EH_PE_sdata2), &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode udata2");
    STAssertEquals(result, ((uint64_t) &test_data) - 256, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)2, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test sdata4 (including pcrel validation) */
    test_data.sdata4 = -256;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, (DW_EH_PE_t)(DW_EH_PE_pcrel|DW_EH_PE_sdata4), &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sdata4");
    STAssertEquals(result, ((uint64_t) &test_data) - 256, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)4, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
    
    /* Test sdata8 (including pcrel validation) */
    test_data.sdata8 = -256;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = reader.read(&mobj, (pl_vm_address_t)&test_data-1, 1, (DW_EH_PE_t)(DW_EH_PE_pcrel|DW_EH_PE_sdata8), &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode udata8");
    STAssertEquals(result, ((uint64_t) &test_data) - 256, @"Incorrect value decoded");
    STAssertEquals(size, (size_t)8, @"Incorrect byte length");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test ULEB128 parsing.
 */
- (void) testReadULEB128 {
    /* Configure test */
    uint8_t buffer[11];
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    uint64_t result;
    pl_vm_size_t size;
    
    /* Test offset handling */
    buffer[0] = 2;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer+1, -1, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);

    /* Test a single byte */
    buffer[0] = 2;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test multi-byte */
    buffer[0] = 0+0x80;
    buffer[1] = 1;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)128, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)2, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test UINT64_MAX */
    memset(buffer, 0xFF, sizeof(buffer));
    buffer[9] = 0x7F;
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)UINT64_MAX, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)10, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test handling of an integer larger than 64 bits. */
    memset(buffer, 0x80, sizeof(buffer));
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ENOTSUP, @"ULEB128 should not be decodable");
    plcrash_async_mobject_free(&mobj);
    
    /* Test end-of-buffer handling */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, 1, true), @"Failed to initialize mobj mapping");
    buffer[0] = 1+0x80;
    err = plcrash_async_dwarf_read_uleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_EINVAL, @"ULEB128 should not be decodable");
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test direct task-based reading of a ULEB128 value. This uses the same ULEB128 parser as the plcrash_async_dwarf_read_uleb128() code,
 * so we only test that the out-of-process memory read works as expected.
 */
- (void) readTaskULEB128 {
    /* Configure test */
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    uint64_t result;
    pl_vm_size_t size;
    
    /* Test offset handling */
    uint8_t buffer[] = { 2 };
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_task_uleb128(mach_task_self(), (pl_vm_address_t) buffer+1, -1, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uleb128");
    STAssertEquals(result, (uint64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test uintmax64 reading.
 */
- (void) testReadUintMax64 {
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    uint64_t result;

    /* Test data */
    union {
        uint8_t udata1;
        uint16_t udata2;
        uint32_t udata4;
        uint64_t udata8;
    } test_data;
    
    /* uint8_t */
    test_data.udata1 = UINT8_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uintmax64(&mobj, &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 1, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint8_t");
    STAssertEquals(result, (uint64_t)UINT8_MAX, @"Incorrect value decoded");

    plcrash_async_mobject_free(&mobj);
    
    /* uint16_t */
    test_data.udata2 = UINT16_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uintmax64(&mobj, &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 2, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint16_t");
    STAssertEquals(result, (uint64_t)UINT16_MAX, @"Incorrect value decoded");
    plcrash_async_mobject_free(&mobj);

    /* uint32_t */
    test_data.udata4 = UINT32_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uintmax64(&mobj, &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 4, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint32_t");
    STAssertEquals(result, (uint64_t)UINT32_MAX, @"Incorrect value decoded");
    plcrash_async_mobject_free(&mobj);
    
    /* uint64_t */
    test_data.udata8 = UINT64_MAX;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_uintmax64(&mobj, &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 8, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint64_t");
    STAssertEquals(result, (uint64_t)UINT64_MAX, @"Incorrect value decoded");
    plcrash_async_mobject_free(&mobj);
    
    /* Invalid size */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &test_data, sizeof(test_data), true), @"Failed to initialize mobj mapping");
    err = plcrash_async_dwarf_read_uintmax64(&mobj, &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 3, &result);
    STAssertNotEquals(err, PLCRASH_ESUCCESS, @"Expected error with invalid byte size of 3");
    
    plcrash_async_mobject_free(&mobj);
    
}

/**
 * Test task-based uintmax64 reading.
 */
- (void) testReadTaskUintMax64 {
    plcrash_error_t err;
    uint64_t result;
    
    /* Test data */
    union {
        uint8_t udata1;
        uint16_t udata2;
        uint32_t udata4;
        uint64_t udata8;
    } test_data;
    
    /* uint8_t */
    test_data.udata1 = UINT8_MAX;    
    err = plcrash_async_dwarf_read_task_uintmax64(mach_task_self(), &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 1, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint8_t");
    STAssertEquals(result, (uint64_t)UINT8_MAX, @"Incorrect value decoded");
        
    /* uint16_t */
    test_data.udata2 = UINT16_MAX;    
    err = plcrash_async_dwarf_read_task_uintmax64(mach_task_self(), &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 2, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint16_t");
    STAssertEquals(result, (uint64_t)UINT16_MAX, @"Incorrect value decoded");
    
    /* uint32_t */
    test_data.udata4 = UINT32_MAX;    
    err = plcrash_async_dwarf_read_task_uintmax64(mach_task_self(), &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 4, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint32_t");
    STAssertEquals(result, (uint64_t)UINT32_MAX, @"Incorrect value decoded");
    
    /* uint64_t */
    test_data.udata8 = UINT64_MAX;    
    err = plcrash_async_dwarf_read_task_uintmax64(mach_task_self(), &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 8, &result);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode uint64_t");
    STAssertEquals(result, (uint64_t)UINT64_MAX, @"Incorrect value decoded");
    
    /* Invalid size */
    err = plcrash_async_dwarf_read_task_uintmax64(mach_task_self(), &plcrash_async_byteorder_direct, ((pl_vm_address_t)&test_data)-1, 1, 3, &result);
    STAssertNotEquals(err, PLCRASH_ESUCCESS, @"Expected error with invalid byte size of 3");
}

/**
 * Test SLEB128 parsing.
 */
- (void) testReadSLEB128 {
    /* Configure test */
    uint8_t buffer[11];
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    int64_t result;
    pl_vm_size_t size;
    
    /* Test offset handling */
    buffer[0] = 2;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer+1, -1, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, (int64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test a single byte */
    buffer[0] = 2;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, (int64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test single (negative) byte */
    buffer[0] = 0x7e;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, (int64_t)-2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test multi-byte */
    buffer[0] = 0+0x80;
    buffer[1] = 1;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, (int64_t)128, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)2, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test -INT64_MAX */
    memset(buffer, 0x80, sizeof(buffer));
    buffer[9] = 0x7f;
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, INT64_MIN, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)10, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
    
    /* Test handling of an integer larger than 64 bits. */
    memset(buffer, 0x80, sizeof(buffer));
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_ENOTSUP, @"SLEB128 should not be decodable");
    plcrash_async_mobject_free(&mobj);
    
    /* Test end-of-buffer handling */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, 1, true), @"Failed to initialize mobj mapping");
    buffer[0] = 1+0x80;
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer, 0, &result, &size);
    STAssertEquals(err, PLCRASH_EINVAL, @"SLEB128 should not be decodable");
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test direct task-based reading of a SLEB128 value. This uses the same SLEB128 parser as the plcrash_async_dwarf_read_sleb128() code,
 * so we only test that the out-of-process memory read works as expected.
 */
- (void) readTaskSLEB128 {
    /* Configure test */
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    int64_t result;
    pl_vm_size_t size;
    
    /* Test offset handling */
    uint8_t buffer[] = { 2 };
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) buffer, sizeof(buffer), true), @"Failed to initialize mobj mapping");
    
    err = plcrash_async_dwarf_read_sleb128(&mobj, (pl_vm_address_t) buffer+1, -1, &result, &size);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to decode sleb128");
    STAssertEquals(result, (int64_t)2, @"Incorrect value decoded");
    STAssertEquals(size, (pl_vm_size_t)1, @"Incorrect byte length");
    plcrash_async_mobject_free(&mobj);
}


@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
