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

#include "PLCrashAsyncDwarfCFAState.hpp"
#include "PLCrashAsyncDwarfExpression.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

/* A known-invalid opcode */
#define DW_CFA_BAD_OPCODE DW_CFA_hi_user

using namespace plcrash::async;

@interface PLCrashAsyncDwarfCFAEvaluationTests : PLCrashTestCase {
    dwarf_cfa_state<uint64_t, int64_t> _stack;
    gnu_ehptr_reader<uint64_t> *_ptr_state;
    plcrash_async_dwarf_cie_info_t _cie;
}
@end

/**
 * Test DWARF CFA interpretation.
 */
@implementation PLCrashAsyncDwarfCFAEvaluationTests

- (void) setUp {
    /* Initialize required configuration for pointer dereferencing */
    _ptr_state = new gnu_ehptr_reader<uint64_t>(plcrash_async_byteorder_big_endian());

    _cie.segment_size = 0x0; // we don't use segments
    _cie.has_eh_augmentation = true;
    _cie.eh_augmentation.has_pointer_encoding = true;
    _cie.eh_augmentation.pointer_encoding = DW_EH_PE_absptr; // direct pointers
    
    _cie.code_alignment_factor = 1;
    _cie.data_alignment_factor = 1;
    
    _cie.address_size = 8;
}

- (void) tearDown {
    delete _ptr_state;
}

#pragma mark CFA Evaluation

/* Perform evaluation of the given opcodes, expecting a result of type @a type,
 * with an expected value of @a expected. The data is interpreted as big endian. */
#define PERFORM_EVAL_TEST(opcodes, pc, expected) PERFORM_EVAL_TEST_WITH_INITIAL_PC(opcodes, pc, 0x0, expected)

/* Perform evaluation of the given opcodes, expecting a result of type @a type,
 * with an expected value of @a expected. The @a pc_start value will be used
 * as the initial DW CFA location for the evaluation.
 *
 *
 * The data is interpreted as big endian. */
#define PERFORM_EVAL_TEST_WITH_INITIAL_PC(opcodes, pc, initial_pc, expected) do { \
    plcrash_async_mobject_t mobj; \
    plcrash_error_t err; \
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) &opcodes, sizeof(opcodes), true), @"Failed to initialize mobj"); \
    \
        err = _stack.eval_program(&mobj, (uint64_t)pc, (uint64_t)initial_pc, &_cie, _ptr_state, plcrash_async_byteorder_big_endian(), (pl_vm_address_t) &opcodes, 0, sizeof(opcodes)); \
        STAssertEquals(err, expected, @"Evaluation failed"); \
    \
    plcrash_async_mobject_free(&mobj); \
} while(0)

/* Validate the rule type and value of a register state in _stack */
#define TEST_REGISTER_RESULT(_regnum, _type, _expect_val) do { \
    plcrash_dwarf_cfa_reg_rule_t rule; \
    uint64_t value; \
    STAssertTrue(_stack.get_register_rule(_regnum, &rule, &value), @"Failed to fetch rule"); \
    STAssertEquals(_type, rule, @"Incorrect rule returned"); \
    STAssertEquals(_expect_val, value, @"Incorrect value returned"); \
} while (0)

/** Test handling of the initial location state */
- (void) testInitialLoc {    
    /* Evaluation should terminate prior to the bad opcode */
    uint8_t opcodes[] = { DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST_WITH_INITIAL_PC(opcodes, 0x1, 0x1, PLCRASH_ESUCCESS);
}

/** Test evaluation of DW_CFA_set_loc */
- (void) testSetLoc {
    /* This should terminate once our PC offset is hit below; otherwise, it will execute a
     * bad CFA instruction and return falure */
    uint8_t opcodes[] = { DW_CFA_set_loc, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST(opcodes, 0x102030405060708, PLCRASH_ESUCCESS);
    
    /* Test evaluation without GNU EH agumentation data (eg, using direct word sized pointers) */
    _cie.has_eh_augmentation = false;
    PERFORM_EVAL_TEST(opcodes, 0x102030405060708, PLCRASH_ESUCCESS);
}

/** Test evaluation of DW_CFA_advance_loc */
- (void) testAdvanceLoc {
    _cie.code_alignment_factor = 2;
    
    /* Evaluation should terminate prior to the bad opcode */
    uint8_t opcodes[] = { DW_CFA_advance_loc|0x1, DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST(opcodes, 0x2, PLCRASH_ESUCCESS);
}


/** Test evaluation of DW_CFA_advance_loc1 */
- (void) testAdvanceLoc1 {
    _cie.code_alignment_factor = 2;
    
    /* Evaluation should terminate prior to the bad opcode */
    uint8_t opcodes[] = { DW_CFA_advance_loc1, 0x1, DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST(opcodes, 0x2, PLCRASH_ESUCCESS);
}

/** Test evaluation of DW_CFA_advance_loc2 */
- (void) testAdvanceLoc2 {
    _cie.code_alignment_factor = 2;
    
    /* Evaluation should terminate prior to the bad opcode */
    uint8_t opcodes[] = { DW_CFA_advance_loc2, 0x0, 0x1, DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST(opcodes, 0x2, PLCRASH_ESUCCESS);
}

/** Test evaluation of DW_CFA_advance_loc2 */
- (void) testAdvanceLoc4 {
    _cie.code_alignment_factor = 2;
    
    /* Evaluation should terminate prior to the bad opcode */
    uint8_t opcodes[] = { DW_CFA_advance_loc4, 0x0, 0x0, 0x0, 0x1, DW_CFA_advance_loc1, DW_CFA_BAD_OPCODE};
    PERFORM_EVAL_TEST(opcodes, 0x2, PLCRASH_ESUCCESS);
}

/** Test evaluation of DW_CFA_def_cfa */
- (void) testDefineCFA {
    uint8_t opcodes[] = { DW_CFA_def_cfa, 0x1, 0x2};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);

    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)1, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((uint64_t)2, _stack.get_cfa_rule().register_offset(), @"Unexpected CFA offset");
}

/** Test evaluation of DW_CFA_def_cfa_sf */
- (void) testDefineCFASF {
    /* An alignment factor to be applied to the second operand. */
    _cie.data_alignment_factor = 2;

    uint8_t opcodes[] = { DW_CFA_def_cfa_sf, 0x1, 0x7e /* -2 */};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);

    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)1, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((int64_t)-4, (int64_t)_stack.get_cfa_rule().register_offset_signed(), @"Unexpected CFA offset");
}

/** Test evaluation of DW_CFA_def_cfa_register */
- (void) testDefineCFARegister {
    uint8_t opcodes[] = { DW_CFA_def_cfa, 0x1, 0x2, DW_CFA_def_cfa_register, 10 };
    
    /* Verify modification of unsigned state */
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);

    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)10, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((uint64_t)2, _stack.get_cfa_rule().register_offset(), @"Unexpected CFA offset");
    
    /* Verify modification of signed state */
    opcodes[0] = DW_CFA_def_cfa_sf;
    opcodes[2] = 0x7e; /* -2 */
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)10, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((int64_t)-2, (int64_t)_stack.get_cfa_rule().register_offset_signed(), @"Unexpected CFA offset");
    
    /* Verify behavior when a non-register CFA rule is present */
    _stack.set_cfa_expression(0, 1);
    opcodes[0] = DW_CFA_nop;
    opcodes[1] = DW_CFA_nop;
    opcodes[2] = DW_CFA_nop;
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_EINVAL);
}

/** Test evaluation of DW_CFA_def_cfa_offset */
- (void) testDefineCFAOffset {
    uint8_t opcodes[] = { DW_CFA_def_cfa, 0x1, 0x2, DW_CFA_def_cfa_offset, 10 };    
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)1, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((uint64_t)10, _stack.get_cfa_rule().register_offset(), @"Unexpected CFA offset");

    /* Verify behavior when a non-register CFA rule is present */
    _stack.set_cfa_expression(0, 1);
    opcodes[0] = DW_CFA_nop;
    opcodes[1] = DW_CFA_nop;
    opcodes[2] = DW_CFA_nop;
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_EINVAL);
}

/** Test evaluation of DW_CFA_def_cfa_offset_sf */
- (void) testDefineCFAOffsetSF {
    /* An alignment factor to be applied to the signed offset operand. */
    _cie.data_alignment_factor = 2;

    uint8_t opcodes[] = { DW_CFA_def_cfa, 0x1, 0x2, DW_CFA_def_cfa_offset_sf, 0x7e /* -2 */ };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((uint32_t)1, _stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((int64_t)-4, (int64_t)_stack.get_cfa_rule().register_offset_signed(), @"Unexpected CFA offset");
    
    /* Verify behavior when a non-register CFA rule is present */
    _stack.set_cfa_expression(0, 1);
    opcodes[0] = DW_CFA_nop;
    opcodes[1] = DW_CFA_nop;
    opcodes[2] = DW_CFA_nop;
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_EINVAL);
}

/** Test evaluation of DW_CFA_def_cfa_expression */
- (void) testDefineCFAExpression {    
    uint8_t opcodes[] = { DW_CFA_def_cfa_expression, 0x1 /* 1 byte long */, DW_OP_nop /* expression opcodes */};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_EXPRESSION, _stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((pl_vm_address_t) &opcodes[2], _stack.get_cfa_rule().expression_address(), @"Unexpected expression address");
    STAssertEquals((pl_vm_size_t) 1, _stack.get_cfa_rule().expression_length(), @"Unexpected expression length");
}

/** Test evaluation of DW_CFA_undefined */
- (void) testUndefined {
    plcrash_dwarf_cfa_reg_rule_t rule;
    uint64_t value;

    /* Define the register */
    _stack.set_register(1, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, 10);
    STAssertTrue(_stack.get_register_rule(1, &rule, &value), @"Rule should be marked as defined");

    /* Perform undef */
    uint8_t opcodes[] = { DW_CFA_undefined, 0x1 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    STAssertFalse(_stack.get_register_rule(1, &rule, &value), @"No rule should be defined for undef register");
}

/** Test evaluation of DW_CFA_same_value */
- (void) testSameValue {
    uint8_t opcodes[] = { DW_CFA_same_value, 0x1 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    plcrash_dwarf_cfa_reg_rule_t rule;
    uint64_t value;
    STAssertTrue(_stack.get_register_rule(1, &rule, &value), @"Failed to fetch rule");
    STAssertEquals(PLCRASH_DWARF_CFA_REG_RULE_SAME_VALUE, rule, @"Incorrect rule returned");
}

/** Test evaluation of DW_CFA_offset */
- (void) testOffset {
    _cie.data_alignment_factor = 2;

    // This opcode encodes the register value in the low 6 bits
    uint8_t opcodes[] = { DW_CFA_offset|0x4, 0x5 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (uint64_t)0xA);
}

/** Test evaluation of DW_CFA_offset_extended */
- (void) testOffsetExtended {
    _cie.data_alignment_factor = 2;

    uint8_t opcodes[] = { DW_CFA_offset_extended, 0x4, 0x5 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (uint64_t)0xA);
}

/** Test evaluation of DW_CFA_offset_extended_sf */
- (void) testOffsetExtendedSF {
    _cie.data_alignment_factor = -1;
    
    uint8_t opcodes[] = { DW_CFA_offset_extended_sf, 0x4, 0x4 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (uint64_t)-4);
}

/** Test evaluation of DW_CFA_val_offset */
- (void) testValOffset {
    _cie.data_alignment_factor = -1;

    uint8_t opcodes[] = { DW_CFA_val_offset, 0x4, 0x4 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET, (uint64_t)-4);
}

/** Test evaluation of DW_CFA_val_offset_sf */
- (void) testValOffsetSF {
    _cie.data_alignment_factor = -1;
    
    uint8_t opcodes[] = { DW_CFA_val_offset_sf, 0x4, 0x7e /* -2 */ };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET, (uint64_t)2);
}

/** Test evaluation of DW_CFA_register */
- (void) testRegister {
    _cie.data_alignment_factor = -1;
    
    uint8_t opcodes[] = { DW_CFA_register, 0x4, 0x5};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_REGISTER, (uint64_t)0x5);
}

/** Test evaluation of DW_CFA_expression */
- (void) testExpression {
    uint8_t opcodes[] = { DW_CFA_expression, 0x4, 0x1 /* 1 byte long */, DW_OP_nop /* expression opcodes */};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (uint64_t)&opcodes[2]);
}

/** Test evaluation of DW_CFA_val_expression */
- (void) testValExpression {
    uint8_t opcodes[] = { DW_CFA_val_expression, 0x4, 0x1 /* 1 byte long */, DW_OP_nop /* expression opcodes */};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION, (uint64_t)&opcodes[2]);
}

/** Test evaluation of DW_CFA_restore */
- (void) testRestore {
    _stack.set_register(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, 0x20);
    uint8_t opcodes[] = { DW_CFA_val_offset, 0x4, 0x4, DW_CFA_restore|0x4};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (uint64_t)0x20);
}

/** Test evaluation of DW_CFA_restore_extended */
- (void) testRestoreExtended {
    _stack.set_register(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, 0x20);
    uint8_t opcodes[] = { DW_CFA_val_offset, 0x4, 0x4, DW_CFA_restore_extended, 0x4};
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (uint64_t)0x20);
}

/** Test evaluation of DW_CFA_remember_state */
- (void) testRememberState {
    /* Set up an initial state that the opcodes can push */
    _stack.set_register(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, 0x20);

    /* Push our current state, and then tweak register state (to verify that a new state is actually in place). */
    uint8_t opcodes[] = { DW_CFA_remember_state, DW_CFA_undefined, 0x4 };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);

    /* Restore our previous state and verify that it is unchanged */
    STAssertTrue(_stack.pop_state(), @"No new state was pushed");
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (uint64_t)0x20);
}

/** Test evaluation of DW_CFA_restore_state */
- (void) testRestoreState {
    /* Set up an initial state that the opcodes can pop */
    _stack.set_register(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, 0x20);
    STAssertTrue(_stack.push_state(), @"Insufficient allocation to push new state");

    /* Tweak register state (to verify that a new state is actually in place), and then restore previous state */
    uint8_t opcodes[] = { DW_CFA_undefined, 0x4, DW_CFA_restore_state };
    PERFORM_EVAL_TEST(opcodes, 0x0, PLCRASH_ESUCCESS);
    
    /* Our previous state should have been restored by our CFA program; verify that it is unchanged */
    TEST_REGISTER_RESULT(0x4, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (uint64_t)0x20);
}

- (void) testBadOpcode {
    uint8_t opcodes[] = { DW_CFA_BAD_OPCODE };
    PERFORM_EVAL_TEST(opcodes, 0, PLCRASH_ENOTSUP);
}

/** Test basic evaluation of a NOP. */
- (void) testNop {
    uint8_t opcodes[] = { DW_CFA_nop, };
    
    PERFORM_EVAL_TEST(opcodes, 0, PLCRASH_ESUCCESS);
}

#pragma mark CFA Application

/**
 * Walk the given thread state, searching for a valid general purpose register (eg, neither
 * the FP, SP, or IP, and defined by DWARF) that can be used for test purposes.
 *
 * The idea here is to keep this test code non-architecture specific, relying on the thread state
 * API for any architecture-specific handling.
 *
 * @param ts The thread-state to use for register name lookups.
 * @param skip The number of valid registers to skip before returning a register. This may be used to fetch
 * multiple general purpose registers.
 */
- (plcrash_regnum_t) findTestRegister: (plcrash_async_thread_state_t *) ts skip: (NSUInteger) skip {
    size_t count = plcrash_async_thread_state_get_reg_count(ts);

    /* Find a valid general purpose register for which there is also a corresponding DWARF register
     * name. */
    plcrash_regnum_t reg;
    for (reg = (plcrash_regnum_t)0; reg < count; reg++) {
        if (reg != PLCRASH_REG_FP && reg != PLCRASH_REG_SP && reg != PLCRASH_REG_IP) {
            uint64_t dw;
            if (plcrash_async_thread_state_map_reg_to_dwarf(ts, reg, &dw)) {
                if (skip-- != 0)
                    continue;

                return reg;
            }
        }
    }

    STFail(@"Could not find register");
    __builtin_trap();
}

/**
 * Return the DWARF register value for the register returned by -testRegister:
 *
 * @param ts The thread-state to use for register name lookups.
 * @param skip The number of valid registers to skip before returning a register. This may be used to fetch
 * multiple general purpose registers.
 */
- (dwarf_cfa_state_regnum_t) findTestDwarfRegister: (plcrash_async_thread_state_t *) ts skip: (NSUInteger) skip {
    uint64_t dw;
    STAssertTrue(plcrash_async_thread_state_map_reg_to_dwarf(ts, [self findTestRegister: ts skip: skip], &dw), @"Failed to map to dwarf register");
    return (dwarf_cfa_state_regnum_t) dw;
}

/**
 * Test applying a valid register as the return register.
 */
- (void) testApplyReturnRegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    uint8_t opcodes[] = { 1, DW_OP_lit15 };

    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];

    /* Set up required CFA register rule */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 20);
    cfa_state.set_cfa_register(dw_regnum, 10);

    /* Use opcode to generate a register value, and mark that register as the return address register. */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION, (int64_t) &opcodes);
    _cie.return_address_register = dw_regnum;

    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The register value was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    STAssertEquals((plcrash_greg_t)15, result, @"Incorrect register value");
    
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_IP), @"The IP was not set");
    result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_IP);
    STAssertEquals((plcrash_greg_t)15, result, @"Incorrect IP value");
}

/**
 * Test applying a invalid pseudo-register as the return register.
 */
- (void) testApplyPseudoReturnRegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    uint8_t opcodes[] = { 1, DW_OP_lit15 };


    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Find an invalid DWARF register to abuse as our pseudo register */
    dwarf_cfa_state_regnum_t dw_invalid_regnum;
    for (uint32_t i = 0; i < UINT32_MAX; i++) {
        plcrash_regnum_t ignored_regnum;
        if (!plcrash_async_thread_state_map_dwarf_to_reg(&prev_ts, i, &ignored_regnum)) {
            dw_invalid_regnum = i;
            break;
        }
    }
    
    /* Set up required CFA register rule */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 20);
    cfa_state.set_cfa_register(dw_regnum, 10);
    
    /* Use opcode to generate a register value, and mark the register as the return address register. */
    cfa_state.set_register(dw_invalid_regnum, PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION, (int64_t) &opcodes);
    _cie.return_address_register = dw_invalid_regnum;
    
    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_IP), @"The IP was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_IP);
    STAssertEquals((plcrash_greg_t)15, result, @"Incorrect IP value");
}

/**
 * Test applying a register from the current frame as the return register (eg, 
 * use the current value of 'lr' in an ARM leaf function as the return address).
 */
- (void) testApplySameValueReturnRegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Set up required CFA register rule */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 20);
    cfa_state.set_cfa_register(dw_regnum, 10);
    
    /* Mark a register as the return address register, without adding a register rule. The register
     * should instead be populated from the existing register state. */
    dwarf_cfa_state_regnum_t dw_ret_regnum = [self findTestDwarfRegister: &prev_ts skip: 1];
    plcrash_regnum_t pl_ret_regnum = [self findTestRegister: &prev_ts skip: 1];
    
    plcrash_async_thread_state_set_reg(&prev_ts, pl_ret_regnum, 15);
    _cie.return_address_register = dw_ret_regnum;
    
    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */    
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_IP), @"The IP was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_IP);
    STAssertEquals((plcrash_greg_t)15, result, @"Incorrect IP value");
}

/**
 * Verify that a missing return register value triggers an appropriate error.
 */
- (void) testApplyMissingReturnRegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Set up required CFA register rule */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 20);
    cfa_state.set_cfa_register(dw_regnum, 10);
    
    /* Mark a register as the return address register, without adding a register rule. The register
     * should instead be populated from the existing register state. */
    dwarf_cfa_state_regnum_t dw_ret_regnum = [self findTestDwarfRegister: &prev_ts skip: 1];
    plcrash_regnum_t pl_ret_regnum = [self findTestRegister: &prev_ts skip: 1];

    plcrash_async_thread_state_clear_reg(&prev_ts, pl_ret_regnum);
    _cie.return_address_register = dw_ret_regnum;
    
    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_EINVAL, @"Attempt to apply an CFA state with a missing return_address_register did not return EINVAL");
}

/**
 * Test handling of an undefined CFA value.
 */
- (void) testApplyCFAUndefined {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_EINVAL, @"Attempt to apply an incomplete CFA state did not return EINVAL");
}

/**
 * Test derivation of the CFA value from the given register + unsigned offset.
 */
- (void) testApplyCFARegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;

    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());

    /* Set the CFA-required register and associated CFA rule; we use a negative value here intentionally, and verify
     * that it actually is interpreted as an */
    plcrash_async_thread_state_set_reg(&prev_ts, [self findTestRegister: &prev_ts skip: 0], 30);
    cfa_state.set_cfa_register([self findTestDwarfRegister: &prev_ts skip: 0], 10);

    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");

    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_SP), @"No stack pointer was set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_SP);
    STAssertEquals((plcrash_greg_t)40, result, @"Incorrect stack pointer");
}


/**
 * Test derivation of the CFA value from the given register + signed offset.
 */
- (void) testApplyCFARegisterUnsigned {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    /* Set the CFA-required register and associated CFA rule; we use a negative value here intentionally, and verify
     * that it actually is interpreted as an */
    plcrash_async_thread_state_set_reg(&prev_ts, [self findTestRegister: &prev_ts skip: 0], 30);
    cfa_state.set_cfa_register_signed([self findTestDwarfRegister: &prev_ts skip: 0], -10);
    
    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_SP), @"No stack pointer was set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_SP);
    STAssertEquals((plcrash_greg_t)20, result, @"Incorrect stack pointer");
}

/**
 * Test deriviation of the CFA value from a DWARF expression.
 */
- (void) testApplyCFAExpression {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    uint8_t opcodes = { DW_OP_lit15 };

    /* Populate initial state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    /* Target our sample opcodes */
    cfa_state.set_cfa_expression((pl_vm_address_t)&opcodes, sizeof(opcodes));
    
    /* Try to apply the state change */
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, PLCRASH_REG_SP), @"No stack pointer was set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, PLCRASH_REG_SP);
    STAssertEquals((plcrash_greg_t)15, result, @"Incorrect stack pointer");
}


/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_OFFSET register value.
 */
- (void) testApplyRegisterSignedOffset {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;

    /* Target value large enough for 64-bit operation */
    union {
        uint64_t u64;
        uint32_t u32;
    } target_val;
    target_val.u64 = 0xABABABABABABABABULL;

    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Populate the CFA with the address of 'target_val' +20. We use this combined with signed offset
     * of -20 below to test signed offset handling. */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, (plcrash_greg_t) &target_val);
    cfa_state.set_cfa_register(dw_regnum, 20);

    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, -20);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    
    if (plcrash_async_thread_state_get_greg_size(&new_ts) == 8)
        STAssertEquals((plcrash_greg_t)target_val.u64, result, @"Incorrect register value");
    else
        STAssertEquals((plcrash_greg_t)target_val.u32, result, @"Incorrect register value");
}

/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET register value.
 */
- (void) testApplyRegisterSignedOffsetValue {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Populate the CFA with a test address. */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, (plcrash_greg_t) 30);
    cfa_state.set_cfa_register(dw_regnum, 0);
    
    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET, -20);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);

    STAssertEquals((plcrash_greg_t)10, result, @"Incorrect register value");
}

/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_REGISTER register value.
 */
- (void) testApplyRegisterFromRegister {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    
    /* Find a set of two GP registers for the target architecture */
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    dwarf_cfa_state_regnum_t dw_regnum_src = [self findTestDwarfRegister: &prev_ts skip: 1];
    plcrash_regnum_t pl_regnum_src = [self findTestRegister: &prev_ts skip: 1];

    /* Populate the required CFA rule; the value doesn't matter for this test. We use
     * 'dw_regnum_src' as the CFA register, but this value does not matter for our test. */
    cfa_state.set_cfa_register(dw_regnum, dw_regnum_src);

    /*
     * Populate the source register value from which the rule will fetch  the target
     * register's value.
     */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum_src, 30);

    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_REGISTER, dw_regnum_src);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    STAssertEquals((plcrash_greg_t)30, result, @"Incorrect register value");
}

/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION register value.
 */
- (void) testApplyRegisterFromExpression {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Target value for 32-bit/64-bit dereferencing */
    union {
        uint64_t u64;
        uint32_t u32;
    } target_val;
    target_val.u64 = 0xABABABABABABABABULL;
    
    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());    
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];

    /* Populate the CFA rule; since the CFA is pushed onto the expression stack, we'll exploit
     * this fact to push the address of our target_val into an expression-accessible location. To verify
     * that the expression is actually evaluated, we apply an offset that we'll remove in the opcode
     * stream. */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, ((intptr_t) &target_val) + sizeof(target_val));
    cfa_state.set_cfa_register(dw_regnum, 0);
    
    /*
     * Configure the register rule to use our expression opcodes. Note that the first opcode value is the uleb128-encoded
     * size of the opcode stream.
     *
     * This opcode stream will take the CFA value on the stack, subtract the sizeof(target_val) that was added to it
     * above, and push the result back onto the expression stack. The result of evaluation will be a pointer to our
     * target_val data.
     */
    STAssertTrue(sizeof(target_val) <= UINT8_MAX, @"The offset can't be encoded in a single byte");
    uint8_t opcodes[] = { 3 /* uleb128 expression length */, DW_OP_const1u, sizeof(target_val), DW_OP_minus };

    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (int64_t) opcodes);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    
    if (plcrash_async_thread_state_get_greg_size(&new_ts) == 8)
        STAssertEquals((plcrash_greg_t)target_val.u64, result, @"Incorrect register value");
    else
        STAssertEquals((plcrash_greg_t)target_val.u32, result, @"Incorrect register value");
}

/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION register value.
 */
- (void) testApplyRegisterValueFromExpression {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    
    /* Populate the CFA rule; since the CFA is pushed onto the expression stack, we store a test
     * value here that we'll then modify as part of our expression. This allows us to verify that the CFA
     * value was correctly pushed onto the stack. */
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 10);
    cfa_state.set_cfa_register(dw_regnum, 0);
    
    /*
     * Configure the register rule to use our expression opcodes. Note that the first opcode value is the uleb128-encoded
     * size of the opcode stream.
     *
     * This opcode stream will take the CFA value on the stack, add 10, and push the result back onto the expression
     * stack. The target register will be set to the result of our evaluation.
     */
    uint8_t opcodes[] = { 2 /* uleb128 expression length */, DW_OP_lit10, DW_OP_plus };
    
    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION, (int64_t) opcodes);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    STAssertEquals((plcrash_greg_t)20 /* CFA + 10 */, result, @"Incorrect register value");
}

/**
 * Test deriviation of a PLCRASH_DWARF_CFA_REG_RULE_SAME_VALUE register value.
 */
- (void) testApplyRegisterSameValue {
    plcrash_async_thread_state_t prev_ts;
    plcrash_async_thread_state_t new_ts;
    dwarf_cfa_state<uint64_t, int64_t> cfa_state;
    plcrash_error_t err;
    
    /* Initial thread state */
    plcrash_async_thread_state_mach_thread_init(&prev_ts, pl_mach_thread_self());
    dwarf_cfa_state_regnum_t dw_regnum = [self findTestDwarfRegister: &prev_ts skip: 0];
    plcrash_regnum_t pl_regnum = [self findTestRegister: &prev_ts skip: 0];
    plcrash_async_thread_state_set_reg(&prev_ts, pl_regnum, 20);

    /* Populate an (unused) CFA rule */
    cfa_state.set_cfa_register(dw_regnum, 0);
    
    /* Set the register rule and apply the state change  */
    cfa_state.set_register(dw_regnum, PLCRASH_DWARF_CFA_REG_RULE_SAME_VALUE, 0);
    err = cfa_state.apply_state(mach_task_self(), &_cie, &prev_ts, &plcrash_async_byteorder_direct, &new_ts);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Failed to apply CFA state");
    
    /* Verify the result */
    STAssertTrue(plcrash_async_thread_state_has_reg(&new_ts, pl_regnum), @"The target register was not set");
    plcrash_greg_t result = plcrash_async_thread_state_get_reg(&new_ts, pl_regnum);
    STAssertEquals((plcrash_greg_t)20, result, @"Incorrect register value");
}


@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
