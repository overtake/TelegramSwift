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

#include "PLCrashAsyncDwarfExpression.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

/*
 * Configure the test cases for thread states that are supported by the host.
 *
 * The primary test validates 64-bit evaluation (on hosts that only support 32-bit thread
 * states -- such as iOS/ARM -- we avoid using values that would overflow the thread state gprs,
 * allowing the tests to succeed). The _32 test case subclass variant validates 32-bit operation.
 *
 * The DWARF register numbers must be <= 31, to permit encoding with a DW_OP_bregN
 * opcode.
 */
#ifdef PLCRASH_ASYNC_THREAD_X86_SUPPORT
#    define TEST_THREAD_64_CPU CPU_TYPE_X86_64
#    define TEST_THREAD_64_DWARF_REG1 14 // r14
#    define TEST_THREAD_64_DWARF_REG_INVALID 31 // unhandled DWARF register number

#    define TEST_THREAD_32_CPU CPU_TYPE_X86
#    define TEST_THREAD_32_DWARF_REG1 8 // EIP
#    define TEST_THREAD_32_DWARF_REG_INVALID 31 // unhandled DWARF register number

#elif PLCRASH_ASYNC_THREAD_ARM_SUPPORT

#    define TEST_THREAD_64_CPU CPU_TYPE_ARM
#    define TEST_THREAD_64_DWARF_REG1 14 // LR (r14)
#    define TEST_THREAD_64_DWARF_REG_INVALID 31 // unhandled DWARF register number

#    define TEST_THREAD_32_CPU CPU_TYPE_ARM
#    define TEST_THREAD_32_DWARF_REG1 14 // LR (r14)
#    define TEST_THREAD_32_DWARF_REG_INVALID 31 // unhandled DWARF register number

#else
#    error Add support for this platform
#endif


@interface PLCrashAsyncDwarfExpressionTests : PLCrashTestCase {
@protected
    plcrash_async_thread_state_t _ts;
}

- (BOOL) is32;
- (cpu_type_t) targetCPU;
- (uint8_t) dwarfTestRegister;
- (uint8_t) dwarfBadRegister;

@end

/* Subclass that we use to trigger testing of 32-bit behavior. See also -[PLCrashAsyncDwarfExpressionTests is32]. */
@interface PLCrashAsyncDwarfExpressionTests_32 : PLCrashAsyncDwarfExpressionTests @end


@implementation PLCrashAsyncDwarfExpressionTests_32
@end

/**
 * Test DWARF expression evaluation.
 */
@implementation PLCrashAsyncDwarfExpressionTests

- (void) setUp {
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_thread_state_init(&_ts, [self targetCPU]), @"Failed to initialize thread state");
}

/**
 * Returns YES if we're testing the 32-bit evaluation case (eg, PLCrashAsyncDwarfExpressionTests_32), or NO if we're testing
 * the 64-bit case.
 */
- (BOOL) is32 {
    return [[self class] isEqual: [PLCrashAsyncDwarfExpressionTests_32 class]];
}

/**
 * Return the CPU to be used for the test thread state. This state type may vary based on whether we're testing
 * 32-bit or 64-bit target behavior.
 *
 * On some (eg, iOS/ARM), we're unable to correctly test the behavior of 64-bit evaluation with a 64-bit target, as there
 * exists no support for representing 64-bit thread state. In those cases, we still run the 64-bit evaluation tests
 * for completeness; they should pass in the standard case, as we do not use any dereferencing of values > UINT32_MAX from
 * the 32-bit thread state.
 */
- (cpu_type_t) targetCPU {
    if ([self is32])
        return TEST_THREAD_32_CPU;
    else
        return TEST_THREAD_64_CPU;
}

/**
 * Return the DWARF register number to be used for tests.
 */
- (uint8_t) dwarfTestRegister {
    if ([self is32])
        return TEST_THREAD_32_DWARF_REG1;
    else
        return TEST_THREAD_64_DWARF_REG1;
}

/**
 * Return a known-bad DWARF register to use for tests.
 */
- (uint8_t) dwarfBadRegister {
    if ([self is32])
        return TEST_THREAD_32_DWARF_REG_INVALID;
    else
        return TEST_THREAD_64_DWARF_REG_INVALID;
}

/* Perform evaluation of the given opcodes, expecting a result of type @a type,
 * with an expected value of @a expected. The data is interpreted as big endian,
 * as to simplify formulating multi-byte test values in the opcode stream */
#define PERFORM_EVAL_TEST(opcodes, type, expected) do { \
    plcrash_async_mobject_t mobj; \
    plcrash_error_t err; \
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &opcodes, sizeof(opcodes), true), @"Failed to initialize mobj"); \
\
    if (![self is32]) { \
        uint64_t result; \
        err = plcrash_async_dwarf_expression_eval<uint64_t, int64_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes), NULL, 0, &result); \
        STAssertEquals(err, PLCRASH_ESUCCESS, @"64-bit evaluation failed"); \
        STAssertEquals((type)result, (type)expected, @"Incorrect 64-bit result"); \
    } else { \
        uint32_t result; \
        err = plcrash_async_dwarf_expression_eval<uint32_t, int32_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes), NULL, 0, &result); \
        STAssertEquals(err, PLCRASH_ESUCCESS, @"32-bit evaluation failed"); \
        STAssertEquals((type)result, (type)expected, @"Incorrect 32-bit result"); \
    } \
\
    plcrash_async_mobject_free(&mobj); \
} while(0)

/* Perform evaluation of the given opcodes, expecting a result error of @a errval. The data is interpreted as big endian,
 * as to simplify formulating multi-byte test values in the opcode stream */
#define PERFORM_EVAL_TEST_ERROR(opcodes, errval) do { \
    plcrash_async_mobject_t mobj; \
    plcrash_error_t err; \
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &opcodes, sizeof(opcodes), true), @"Failed to initialize mobj"); \
    \
    if (![self is32]) { \
        uint64_t result; \
        err = plcrash_async_dwarf_expression_eval<uint64_t, int64_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes), NULL, 0, &result); \
        STAssertEquals(err, errval, @"64-bit evaluation did not return expected error code"); \
    } else { \
        uint32_t result; \
        err = plcrash_async_dwarf_expression_eval<uint32_t, int32_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes), NULL, 0, &result); \
        STAssertEquals(err, errval, @"32-bit evaluation did not return expected error code"); \
    } \
    \
    plcrash_async_mobject_free(&mobj); \
} while(0)


/**
 * Test evaluation of the DW_OP_litN opcodes.
 */
- (void) testLitN {
    for (uint64_t i = 0; i < (DW_OP_lit31 - DW_OP_lit0); i++) {
        uint8_t opcodes[] = {
            static_cast<uint8_t>(DW_OP_lit0 + i) // The opcodes are defined in monotonically increasing order.
        };
        
        PERFORM_EVAL_TEST(opcodes, uint64_t, i);
    }
}

/**
 * Test evaluation of the DW_OP_const1u opcode
 */
- (void) testConst1u {
    uint8_t opcodes[] = { DW_OP_const1u, 0xFF };
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0xFF);
}

/**
 * Test evaluation of the DW_OP_const1s opcode
 */
- (void) testConst1s {
    uint8_t opcodes[] = { DW_OP_const1s, 0x80 };
    PERFORM_EVAL_TEST(opcodes, int8_t, INT8_MIN);
}

/**
 * Test evaluation of the DW_OP_const2u opcode
 */
- (void) testConst2u {
    uint8_t opcodes[] = { DW_OP_const2u, 0xFF, 0xFA};
    PERFORM_EVAL_TEST(opcodes, uint16_t, 0xFFFA);
}

/**
 * Test evaluation of the DW_OP_const2s opcode
 */
- (void) testConst2s {
    uint8_t opcodes[] = { DW_OP_const2s, 0x80, 0x00 };
    PERFORM_EVAL_TEST(opcodes, int16_t, INT16_MIN);
}

/**
 * Test evaluation of the DW_OP_const4u opcode
 */
- (void) testConst4u {
    uint8_t opcodes[] = { DW_OP_const4u, 0xFF, 0xFF, 0xFF, 0xFA};
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0xFFFFFFFA);
}

/**
 * Test evaluation of the DW_OP_const4s opcode
 */
- (void) testConst4s {
    uint8_t opcodes[] = { DW_OP_const4s, 0x80, 0x00, 0x00, 0x00 };
    PERFORM_EVAL_TEST(opcodes, int32_t, INT32_MIN);
}

/**
 * Test evaluation of the DW_OP_const8u opcode
 */
- (void) testConst8u {
    uint8_t opcodes[] = { DW_OP_const8u, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFA};

    /* Test for the expected overflow for 32-bit targets */
    if ([self is32])
        PERFORM_EVAL_TEST(opcodes, uint32_t, (uint32_t)0xFFFFFFFFFFFFFFFA);
    else
        PERFORM_EVAL_TEST(opcodes, uint64_t, 0xFFFFFFFFFFFFFFFA);
}

/**
 * Test evaluation of the DW_OP_const8s opcode
 */
- (void) testConst8s {
    uint8_t opcodes[] = { DW_OP_const8s, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    
    /*
     * Signed overflow behavior is left to the implementation by the C99 standard, and the
     * implementation is explicitly permitted to raise a signal. Since we are executing
     * potentially invalid/corrupt/untrusted bytecode, we need to be sure that evaluation
     * does not trigger this behavior.
     *
     * Our implementation will always cast signed types to unsigned types during truncation,
     * which should exhibit defined (if not particularly useful) behavior. The 32-bit
     * variation of this test serves as a rather loose smoke test for that handling, rather
     * than demonstrating any useful properties of the truncation
     */
    if ([self is32])
        PERFORM_EVAL_TEST(opcodes, int64_t , (uint32_t)INT64_MIN);
    else
        PERFORM_EVAL_TEST(opcodes, int64_t , INT64_MIN);
}


/**
 * Test evaluation of the DW_OP_constu (ULEB128 constant) opcode
 */
- (void) testConstu {
    uint8_t opcodes[] = { DW_OP_constu, 0+0x80, 0x1 };
    PERFORM_EVAL_TEST(opcodes, uint8_t, 128);
}

/**
 * Test evaluation of the DW_OP_consts (SLEB128 constant) opcode
 */
- (void) testConsts {
    uint8_t opcodes[] = { DW_OP_consts, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x7f};
    
    /*
     * Signed overflow behavior is left to the implementation by the C99 standard, and the
     * implementation is explicitly permitted to raise a signal. Since we are executing
     * potentially invalid/corrupt/untrusted bytecode, we need to be sure that evaluation
     * does not trigger this undefined behavior.
     *
     * Our implementation will always cast signed types to unsigned types during truncation,
     * which should exhibit defined (if not particularly useful) behavior. The 32-bit
     * variation of this test serves as a rather loose smoke test for that handling, rather
     * than demonstrating any useful properties of the truncation
     */
    if ([self is32])
        PERFORM_EVAL_TEST(opcodes, uint32_t, (uint32_t)INT64_MIN);
    else
        PERFORM_EVAL_TEST(opcodes, int64_t, INT64_MIN);
}

/**
 * Test evaluation of DW_OP_bregN opcodes.
 */
- (void) testBreg {
    STAssertTrue([self dwarfTestRegister] <= 31, @"Registers > 31 can't be encoded with DW_OP_bregN");

    /* Set up the thread state */
    plcrash_regnum_t regnum;
    STAssertTrue(plcrash_async_thread_state_map_dwarf_to_reg(&_ts, [self dwarfTestRegister], &regnum), @"Failed to map DWARF register");
    plcrash_async_thread_state_set_reg(&_ts, regnum, 0xFF);

    /* Should evaluate to value of the TEST_THREAD_DWARF_REG1 register, plus 5 (the value is sleb128 encoded) */
    uint8_t opcodes[] = { static_cast<uint8_t>(DW_OP_breg0 + [self dwarfTestRegister]), 0x5 };
    PERFORM_EVAL_TEST(opcodes, uint64_t, 0xFF+5);
    
    /* Should evaluate to value of the TEST_THREAD_DWARF_REG1 register, minus 2 (the value is sleb128 encoded)*/
    uint8_t opcodes_negative[] = { static_cast<uint8_t>(DW_OP_breg0 + [self dwarfTestRegister]), 0x7e };
    PERFORM_EVAL_TEST(opcodes_negative, uint64_t, 0xFF-2);
}

/**
 * Test evaluation of DW_OP_bregx opcode.
 */
- (void) testBregx {
    STAssertTrue([self dwarfTestRegister] <= 0x7F, @"Register won't fit in 7 bits, you need a real ULEB128 encoder here");
    
    /* Set up the thread state */
    plcrash_regnum_t regnum;
    STAssertTrue(plcrash_async_thread_state_map_dwarf_to_reg(&_ts, [self dwarfTestRegister], &regnum), @"Failed to map DWARF register");
    plcrash_async_thread_state_set_reg(&_ts, regnum, 0xFF);

    /* Should evaluate to value of the TEST_THREAD_DWARF_REG1 register, plus 5 (the value is sleb128 encoded) */
    uint8_t opcodes[] = { DW_OP_bregx, [self dwarfTestRegister], 0x5 };
    PERFORM_EVAL_TEST(opcodes, uint64_t, 0xFF+5);
    
    /* Should evaluate to value of the TEST_THREAD_DWARF_REG1 register, minus 2 (the value is sleb128 encoded)*/
    uint8_t opcodes_negative[] = { DW_OP_bregx, [self dwarfTestRegister], 0x7e };
    PERFORM_EVAL_TEST(opcodes_negative, uint64_t, 0xFF-2);
}

/** Test evaluation of DW_OP_dup */
- (void) testDup {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_dup };
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x5);
}

/** Test evaluation of DW_OP_drop */
- (void) testDrop {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_const1u, 0x10, DW_OP_drop };
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x5);
}

/** Test evaluation of DW_OP_pick */
- (void) testPick {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_const1u, 0x10, DW_OP_pick, 1};
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x5);
}

/** Test evaluation of DW_OP_over */
- (void) testOver {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_const1u, 0x10, DW_OP_over};
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x5);
}

/** Test evaluation of DW_OP_swap */
- (void) testSwap {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_const1u, 0x10, DW_OP_swap };
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x5);
}

/** Test evaluation of DW_OP_rot */
- (void) testRotate {
    uint8_t opcodes[] = { DW_OP_const1u, 0x5, DW_OP_const1u, 0x10, DW_OP_const1u, 0x15, DW_OP_rot};
    PERFORM_EVAL_TEST(opcodes, uint8_t, 0x10);
}

/** Test evaluation of DW_OP_xderef */
- (void) testXDereference {
    /* An opcode stream that can be repurposed for 4 or 8 byte address sizes. */
    uint8_t opcodes[] = { DW_OP_const1u, 0x0, DW_OP_const4u, 0x0, 0x0, 0x0, 0x0, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_xderef };

    if ([self is32]) {
        uint32_t testval = UINT32_MAX;
        
        /* We can only test the 32-bit case when our addresses are within the 32-bit
         * addressable range. This is always true on 32-bit hosts, and may be true on 64-bit hosts
         * depending on where the stack is allocated */
        if ((uintptr_t)&testval < UINT32_MAX) {
            uintptr_t addr = (uintptr_t) &testval;
            
            /* Write out the address to our test value as a big-endian const4u value */
            opcodes[3] = addr >> 24;
            opcodes[4] = (addr >> 16) & 0xFF;
            opcodes[5] = (addr >> 8) & 0xFF;
            opcodes[6] = (addr) & 0xFF;
            
            PERFORM_EVAL_TEST(opcodes, uint32_t, UINT32_MAX);
        }
    } else {
        uint64_t testval = UINT64_MAX;
        uint64_t addr = (uintptr_t) &testval;
        
        /* Write out the address to our test value as a big-endian const8u value */
        opcodes[2] = DW_OP_const8u;
        opcodes[3] = addr >> 56;
        opcodes[4] = (addr >> 48) & 0xFF;
        opcodes[5] = (addr >> 40) & 0xFF;
        opcodes[6] = (addr >> 32) & 0xFF;
        opcodes[7] = (addr >> 24) & 0xFF;
        opcodes[8] = (addr >> 16) & 0xFF;
        opcodes[9] = (addr >> 8) & 0xFF;
        opcodes[10] = (addr) & 0xFF;
        
        PERFORM_EVAL_TEST(opcodes, uint64_t, UINT64_MAX);
    }
}

/** Test evaluation of DW_OP_deref */
- (void) testDereference {
    /* An opcode stream that can be repurposed for 4 or 8 byte address sizes. */
    uint8_t opcodes[] = { DW_OP_const4u, 0x0, 0x0, 0x0, 0x0, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_deref };

    if ([self is32]) {
        uint32_t testval = UINT32_MAX;

        /* We can only test the 32-bit case when our addresses are within the 32-bit
         * addressable range. This is always true on 32-bit hosts, and may be true on 64-bit hosts
         * depending on where the stack is allocated */
        if ((uintptr_t)&testval < UINT32_MAX) {
            uintptr_t addr = (uintptr_t) &testval;

            /* Write out the address to our test value as a big-endian const4u value */
            opcodes[1] = addr >> 24;
            opcodes[2] = (addr >> 16) & 0xFF;
            opcodes[3] = (addr >> 8) & 0xFF;
            opcodes[4] = (addr) & 0xFF;
            
            PERFORM_EVAL_TEST(opcodes, uint32_t, UINT32_MAX);
        }
    } else {
        uint64_t testval = UINT64_MAX;
        uint64_t addr = (uint64_t) &testval;
        
        /* Write out the address to our test value as a big-endian const8u value */
        opcodes[0] = DW_OP_const8u;
        opcodes[1] = addr >> 56;
        opcodes[2] = (addr >> 48) & 0xFF;
        opcodes[3] = (addr >> 40) & 0xFF;
        opcodes[4] = (addr >> 32) & 0xFF;
        opcodes[5] = (addr >> 24) & 0xFF;
        opcodes[6] = (addr >> 16) & 0xFF;
        opcodes[7] = (addr >> 8) & 0xFF;
        opcodes[8] = (addr) & 0xFF;
        
        PERFORM_EVAL_TEST(opcodes, uint64_t, UINT64_MAX);
    }
}

/** Test evaluation of DW_OP_deref_size */
- (void) testDereferenceSize {
    /* An opcode stream that can be repurposed for 4 or 8 byte address sizes. */
    uint8_t opcodes[] = { DW_OP_const4u, 0x0, 0x0, 0x0, 0x0, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_deref_size, 0x1 };

    if ([self is32]) {
        /* We can only test the 32-bit case when our addresses are within the 32-bit
         * addressable range. This is always true on 32-bit hosts, and may be true on 64-bit hosts
         * depending on where the stack is allocated */
        if ((uintptr_t)&opcodes < UINT32_MAX) {
            uintptr_t addr = (uintptr_t) &opcodes;
            
            /* Write out the address to our test value as a big-endian const4u value */
            opcodes[1] = addr >> 24;
            opcodes[2] = (addr >> 16) & 0xFF;
            opcodes[3] = (addr >> 8) & 0xFF;
            opcodes[4] = (addr) & 0xFF;
            
            PERFORM_EVAL_TEST(opcodes, uint32_t, DW_OP_const4u);
        }
    } else {
        uint64_t addr = (uint64_t) &opcodes;
        
        /* Write out the address to our test value as a big-endian const8u value */
        opcodes[0] = DW_OP_const8u;
        opcodes[1] = addr >> 56;
        opcodes[2] = (addr >> 48) & 0xFF;
        opcodes[3] = (addr >> 40) & 0xFF;
        opcodes[4] = (addr >> 32) & 0xFF;
        opcodes[5] = (addr >> 24) & 0xFF;
        opcodes[6] = (addr >> 16) & 0xFF;
        opcodes[7] = (addr >> 8) & 0xFF;
        opcodes[8] = (addr) & 0xFF;
        
        PERFORM_EVAL_TEST(opcodes, uint64_t, DW_OP_const8u);
    }
}

/** Test evaluation of DW_OP_xderef_size */
- (void) testXDereferenceSize {
    /* An opcode stream that can be repurposed for 4 or 8 byte address sizes. */
    uint8_t opcodes[] = { DW_OP_const1u, 0x0, DW_OP_const4u, 0x0, 0x0, 0x0, 0x0, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_nop, DW_OP_xderef_size, 1};
    
    if ([self is32]) {        
        /* We can only test the 32-bit case when our addresses are within the 32-bit
         * addressable range. This is always true on 32-bit hosts, and may be true on 64-bit hosts
         * depending on where the stack is allocated */
        if ((uintptr_t)&opcodes < UINT32_MAX) {
            uintptr_t addr = (uintptr_t) &opcodes;
            
            /* Write out the address to our test value as a big-endian const4u value */
            opcodes[3] = addr >> 24;
            opcodes[4] = (addr >> 16) & 0xFF;
            opcodes[5] = (addr >> 8) & 0xFF;
            opcodes[6] = (addr) & 0xFF;
            
            PERFORM_EVAL_TEST(opcodes, uint32_t, DW_OP_const1u);
        }
    } else {
        uint64_t addr = (uint64_t) &opcodes;
        
        /* Write out the address to our test value as a big-endian const8u value */
        opcodes[2] = DW_OP_const8u;
        opcodes[3] = addr >> 56;
        opcodes[4] = (addr >> 48) & 0xFF;
        opcodes[5] = (addr >> 40) & 0xFF;
        opcodes[6] = (addr >> 32) & 0xFF;
        opcodes[7] = (addr >> 24) & 0xFF;
        opcodes[8] = (addr >> 16) & 0xFF;
        opcodes[9] = (addr >> 8) & 0xFF;
        opcodes[10] = (addr) & 0xFF;
        
        PERFORM_EVAL_TEST(opcodes, uint64_t, DW_OP_const1u);
    }
}

/** Test evaluation of DW_OP_abs */
- (void) testAbs {
    uint8_t opcodes[] = { DW_OP_const1s, 0x80, DW_OP_abs };
    PERFORM_EVAL_TEST(opcodes, int32_t, 128);
    
    /* Check positive number handling, too */
    opcodes[0] = DW_OP_const1u;
    PERFORM_EVAL_TEST(opcodes, int32_t, 128);
}

/** Test evaluation of DW_OP_and */
- (void) testAnd {
    uint8_t opcodes[] = { DW_OP_const1u, 0x7, DW_OP_const1u, 0x3, DW_OP_and };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x3);
}

/** Test evaluation of DW_OP_div */
- (void) testDiv {
    uint8_t opcodes[] = { DW_OP_const1u, 10, DW_OP_const1u, 5, DW_OP_div };
    PERFORM_EVAL_TEST(opcodes, int32_t, 2);

    /* Test 0 divisor handling */
    opcodes[3] = 0;
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_EINVAL);
    
}

/** Test evaluation of DW_OP_minus */
- (void) testMinus {
    uint8_t opcodes[] = { DW_OP_const1u, 10, DW_OP_const1u, 5, DW_OP_minus };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 5);
}

/** Test evaluation of DW_OP_mod */
- (void) testMod {
    uint8_t opcodes[] = { DW_OP_const1u, 10, DW_OP_const1u, 6, DW_OP_mod };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 4);

    /* Test 0 divisor handling */
    opcodes[3] = 0;
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_EINVAL);
}

/** Test evaluation of DW_OP_mul */
- (void) testMul {
    uint8_t opcodes[] = { DW_OP_const1u, 10, DW_OP_const1u, 5, DW_OP_mul };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 50);
}

/** Test evaluation of DW_OP_neg */
- (void) testNeg {
    uint8_t opcodes[] = { DW_OP_const1u, 10, DW_OP_neg };
    PERFORM_EVAL_TEST(opcodes, int32_t, -10);
    opcodes[0] = DW_OP_const1s;
    opcodes[1] = -10;
    PERFORM_EVAL_TEST(opcodes, int32_t, 10);
}

/** Test evaluation of DW_OP_not */
- (void) testNot {
    uint8_t opcodes[] = { DW_OP_const1u, 0x10, DW_OP_not };
    PERFORM_EVAL_TEST(opcodes, uint32_t, ~0x10);
}

/** Test evaluation of DW_OP_or */
- (void) testOr {
    uint8_t opcodes[] = { DW_OP_const1u, 0x10, DW_OP_const1u, 0x20, DW_OP_or };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x10 | 0x20);
}

/** Test evaluation of DW_OP_plus */
- (void) testPlus {
    uint8_t opcodes[] = { DW_OP_const1u, 0x10, DW_OP_const1u, 0x20, DW_OP_plus };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x10 + 0x20);
}

/** Test evaluation of DW_OP_plus_uconst */
- (void) testPlusUConst {
    uint8_t opcodes[] = { DW_OP_const1u, 0x10, DW_OP_plus_uconst, 0x01 };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x10 + 0x01);

}

/** Test evaluation of DW_OP_shl */
- (void) testShiftLeft {
    uint8_t opcodes[] = { DW_OP_const1u, 0x1, DW_OP_const1u, 0x10, DW_OP_shl };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x1 << 0x10);
}

/** Test evaluation of DW_OP_shr */
- (void) testShiftRight {
    uint8_t opcodes[] = { DW_OP_const1u, 0x80, DW_OP_const1u, 0x1, DW_OP_shr };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x40);
}

/** Test evaluation of DW_OP_shra */
- (void) testShiftRightArithmetic {
    uint8_t opcodes[] = { DW_OP_const1s, static_cast<uint8_t>(-10), DW_OP_const1u, 0x1, DW_OP_shra };
    PERFORM_EVAL_TEST(opcodes, int32_t, -10>>1);
}

/** Test evaluation of DW_OP_xor */
- (void) testXor {
    uint8_t opcodes[] = { DW_OP_const1u, 0x80, DW_OP_const1u, 0xC0, DW_OP_xor };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x80^0xC0);
}

/** Test evaluation of the comparison opcodes - DW_OP_le, DW_OP_ge, DW_OP_eq, DW_OP_lt, DW_OP_gt, DW_OP_ne */
- (void) testComparison {
    #define COMPARE(opcode, value1, value2, expected) do { \
        uint8_t opcodes[] = { DW_OP_const1u, value1, DW_OP_const1u, value2, opcode }; \
        PERFORM_EVAL_TEST(opcodes, uint32_t, expected); \
    } while(0)
    
    COMPARE(DW_OP_le, 39, 40, 1);
    COMPARE(DW_OP_le, 40, 40, 1);
    COMPARE(DW_OP_le, 41, 40, 0);
    
    COMPARE(DW_OP_ge, 39, 40, 0);
    COMPARE(DW_OP_ge, 40, 40, 1);
    COMPARE(DW_OP_ge, 41, 40, 1);
    
    COMPARE(DW_OP_eq, 40, 40, 1);
    COMPARE(DW_OP_eq, 41, 40, 0);
    
    COMPARE(DW_OP_lt, 41, 40, 0);
    COMPARE(DW_OP_lt, 40, 40, 0);
    COMPARE(DW_OP_lt, 39, 40, 1);
    
    COMPARE(DW_OP_gt, 41, 40, 1);
    COMPARE(DW_OP_gt, 40, 40, 0);
    COMPARE(DW_OP_gt, 39, 40, 0);
    
    COMPARE(DW_OP_ne, 40, 40, 0);
    COMPARE(DW_OP_ne, 39, 40, 1);

#undef COMPARE
}

/** Test evaluation of DW_OP_skip */
- (void) testSkip {
    uint8_t opcodes[] = {
        DW_OP_const1u, 0x10,

        // Skip the bad opcode
        DW_OP_skip, 0x0, 0x1,

        // Arbitrarily selected bad instruction value.
        // This -could- be allocated to an opcode in the future, but
        // then our test will fail and we can pick another one.
        0x0,
        
        DW_OP_const1u, 0x20
    };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x20);
}

/** Test bounds checking in evaluation of DW_OP_skip */
- (void) testSkipBounds {
    uint8_t opcodes[] = { DW_OP_skip, 0x0, 0x1 };
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_EINVAL);
}

/** Test evaluation of DW_OP_bra */
- (void) testBranch {
    /* This should count down from 5, returning 0 */
    uint8_t opcodes[] = { DW_OP_lit5, DW_OP_lit1, DW_OP_minus, DW_OP_dup, DW_OP_bra, 0xFF, 0xFA /* -6; jump to decrement */ };
    PERFORM_EVAL_TEST(opcodes, uint32_t, 0x0);
}

/** Test bounds checking in evaluation of DW_OP_bra */
- (void) testBranchBounds {
    uint8_t opcodes[] = { DW_OP_lit1, DW_OP_bra, 1, 0x0 };
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_EINVAL);
}

/** Test basic evaluation of a NOP. */
- (void) testNop {
    uint8_t opcodes[] = {
        DW_OP_nop,
        DW_OP_lit31 // at least one result must be available
    };
    
    PERFORM_EVAL_TEST(opcodes, uint64_t, 31);
}

/**
 * Test handling of registers for which a value is not available.
 */
- (void) testFetchUnavailableRegister {
    STAssertTrue([self dwarfTestRegister] <= 0x7F, @"Register won't fit in 7 bits, you need a real ULEB128 encoder here");
    
    uint8_t opcodes[] = { DW_OP_breg0, 0x01 };
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_ENOTFOUND);
}

/**
 * Test handling of unknown DWARF register values
 */
- (void) testBadRegister {
    STAssertTrue([self dwarfBadRegister] <= 0x7F, @"Register won't fit in 7 bits, you need a real ULEB128 encoder here");
    
    uint8_t opcodes[] = { DW_OP_bregx, [self dwarfBadRegister], 0x01 };
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_ENOTSUP);
}

/**
 * Test population of an initial stack.
 */
- (void) testInitialState {
    plcrash_async_mobject_t mobj;
    plcrash_error_t err;
    
    /*
     * For this test, we populate the stack with an initial state of two items, and then issue a DW_OP_swap,
     * verifying that the initial_state[0] value has been swapped to the top of the stack. This verifies both that the
     * state is correctly populated, and that ordering is implemented as defined in the API documentation (eg,
     * that the array of initial state is pushed, in order, such that the last element is at the top of the stack).
     */

    uint8_t opcodes[] = { DW_OP_swap };
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &opcodes, sizeof(opcodes), true), @"Failed to initialize mobj");

    if (![self is32]) {
        uint64_t result;
        uint64_t initial_state[] = { 0xFA, 0xAF };
        size_t initial_count = sizeof(initial_state) / sizeof(initial_state[0]);
        
        err = plcrash_async_dwarf_expression_eval<uint64_t, int64_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes),
                                                                     initial_state, initial_count, &result);
        STAssertEquals(err, PLCRASH_ESUCCESS, @"64-bit evaluation failed");
        STAssertEquals((uint64_t)0xFA, result, @"Incorrect 64-bit result");
    } else {
        uint32_t result;
        uint32_t initial_state[] = { 0xFA, 0xAF };
        size_t initial_count = sizeof(initial_state) / sizeof(initial_state[0]);
        
        err = plcrash_async_dwarf_expression_eval<uint32_t, int32_t>(&mobj, mach_task_self(), &_ts, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes),
                                                                     initial_state, initial_count, &result);
        STAssertEquals(err, PLCRASH_ESUCCESS, @"32-bit evaluation failed");
        STAssertEquals((uint32_t)0xFA, result, @"Incorrect 32-bit result");
    }

    plcrash_async_mobject_free(&mobj);
}

/**
 * Test handling of an empty result.
 */
- (void) testEmptyStackResult {
    uint8_t opcodes[] = { DW_OP_nop /* push nothing onto the stack */ };
    
    /* Evaluation of a no-result expression should fail with EINVAL */
    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_EINVAL);
}

/**
 * Test invalid opcode handling
 */
- (void) testInvalidOpcode {
    uint8_t opcodes[] = {
        // Arbitrarily selected bad instruction value.
        // This -could- be allocated to an opcode in the future, but
        // then our test will fail and we can pick another one.
        0x0 
    };

    PERFORM_EVAL_TEST_ERROR(opcodes, PLCRASH_ENOTSUP);
}


@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
