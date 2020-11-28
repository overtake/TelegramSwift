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

#include "dwarf_opstream.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

@interface dwarf_opstream_tests : PLCrashTestCase {
@private
}
@end

/**
 * Test DWARF stack handling.
 */
@implementation dwarf_opstream_tests

/**
 * Test integer read (and byteswapping) from an opcode stream.
 */
- (void) testReadIntU {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1, 0x2, 0x3 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    uint16_t val1;
    uint8_t val2;
    STAssertTrue(stream.read_intU(&val1), @"Failed to read");
    STAssertTrue(stream.read_intU(&val2), @"Failed to read");
    STAssertFalse(stream.read_intU(&val2), @"Read off the end of the opcode stream");

    STAssertEquals(val1, (uint16_t)0x102, @"Incorrect 16 byte value read");
    STAssertEquals(val2, (uint8_t)0x3, @"Incorrect 8 byte value read");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test uintmax64 read from an opcode stream.
 */
- (void) testReadMax64 {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1, 0x2, 0x3 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    uint64_t val1;
    uint64_t val2;
    STAssertTrue(stream.read_uintmax64(2, &val1), @"Failed to read");
    STAssertEquals(val1, (uint64_t)0x102, @"Incorrect 16 byte value read");

    STAssertTrue(stream.read_uintmax64(1, &val2), @"Failed to read");
    STAssertEquals(val2, (uint64_t)0x3, @"Incorrect 8 byte value read");

    STAssertFalse(stream.read_uintmax64(1, &val2), @"Read off the end of the opcode stream");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test uleb128 read from an opcode stream.
 */
- (void) testReadULEB128 {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    uint64_t val;
    STAssertTrue(stream.read_uleb128(&val), @"Failed to read");    
    STAssertEquals(val, (uint64_t)0x1, @"Incorrect value read");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test sleb128 read from an opcode stream.
 */
- (void) testReadSLEB128 {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    int64_t val;
    STAssertTrue(stream.read_sleb128(&val), @"Failed to read");
    STAssertEquals(val, (int64_t)0x1, @"Incorrect value read");
    
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test pointer read from an opcode stream.
 */
- (void) testReadGNUEHPointer {
    plcrash_async_mobject_t mobj;

    /* Set up an opcode stream with a 4 byte 'pointer' value */
    uint8_t opcodes[] = { 0x1, 0x2, 0x3, 0x4 };
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");

    /* Configure the stream */
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    /* Configure the pointer state */
    uint32_t result;
    gnu_ehptr_reader<uint32_t> ptr_state(plcrash_async_byteorder_big_endian());
    
    /* Test the read handling */
    STAssertTrue(stream.read_gnueh_ptr(&ptr_state, DW_EH_PE_absptr, &result), @"Failed to read the pointer");
    STAssertEquals(result, (uint32_t)0x1020304, @"Incorrect pointer value read");
    
    /* Test overshoot handling */
    STAssertTrue(stream.skip(-1), @"Failed to rewind stream");
    STAssertFalse(stream.read_gnueh_ptr(&ptr_state, DW_EH_PE_absptr, &result), @"Succeeded when attempting to read past the end of the mapped opcode stream");    
}

/**
 * Test skip handling.
 */
- (void) testSkip {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1, 0x2, 0x3 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");

    /* Skip one, verify read */
    uint8_t val;
    STAssertTrue(stream.skip(1), @"Failed to skip within bounds");
    STAssertTrue(stream.read_intU(&val), @"Failed to read");
    STAssertEquals(val, (uint8_t)0x2, @"Incorrect byte value read");

    /* Test bounds checking */
    STAssertTrue(stream.skip(1), @"Failed to skip to end of stream");
    STAssertFalse(stream.skip(1), @"Skipped past end of stream");
    
    STAssertTrue(stream.skip(-3), @"Failed to skip to beginning of stream");
    STAssertFalse(stream.skip(-1), @"Skipped past beginning of stream");

    plcrash_async_mobject_free(&mobj);
}

/**
 * Test position getter.
 */
- (void) testGetPosition {
    plcrash_async_mobject_t mobj;
    uint8_t opcodes[] = { 0x1, 0x2 };
    
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)&opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");
    
    dwarf_opstream stream;
    STAssertEquals(PLCRASH_ESUCCESS, stream.init(&mobj, plcrash_async_byteorder_big_endian(), (pl_vm_address_t)&opcodes, 0, sizeof(opcodes)), @"Failed to initialize opcode stream");
    
    /* Position smoke test. */
    STAssertEquals(stream.get_position(), (uintptr_t)0, @"Incorrect position");
    STAssertTrue(stream.skip(1), @"Failed to skip within bounds");
    STAssertEquals(stream.get_position(), (uintptr_t)1, @"Incorrect position");
    
    plcrash_async_mobject_free(&mobj);
}


@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
