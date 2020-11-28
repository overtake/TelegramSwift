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


#import "PLCrashTestCase.h"

#include "PLCrashAsyncDwarfCFAState.hpp"

#include "PLCrashFeatureConfig.h"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

@interface PLCrashAsyncDwarfCFAStateTests : PLCrashTestCase {
@private
}
@end

/**
 * Test DWARF CFA stack implementation.
 */
@implementation PLCrashAsyncDwarfCFAStateTests

/**
 * Test CFA rule handling.
 */
- (void) testCFARule {
    dwarf_cfa_state<uint64_t, int64_t> stack;

    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_UNDEFINED, stack.get_cfa_rule().type(), @"Unexpected initial CFA value");
    
    stack.set_cfa_register(10, 20);
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER, stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((dwarf_cfa_state_regnum_t)10, stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((uint64_t)20, stack.get_cfa_rule().register_offset(), @"Unexpected CFA offset");
    
    stack.set_cfa_register_signed(10, -20);
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED, stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((dwarf_cfa_state_regnum_t)10, stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((int64_t)-20, (int64_t)stack.get_cfa_rule().register_offset_signed(), @"Unexpected CFA offset");
    
    stack.set_cfa_expression(25, 10);
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_EXPRESSION, stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((pl_vm_address_t)25, stack.get_cfa_rule().expression_address(), @"Unexpected CFA expression address");
    STAssertEquals((pl_vm_size_t)10, stack.get_cfa_rule().expression_length(), @"Unexpected CFA expression address");
}

/**
 * Test setting registers in the current state.
 */
- (void) testSetRegister {
    dwarf_cfa_state<uint64_t, int64_t> stack;

    /* Try using all available entries */
    for (int i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, i), @"Failed to add register");
        STAssertEquals((uint8_t)(i+1), stack.get_register_count(), @"Incorrect number of registers");
    }

    /* Ensure that additional requests fail */
    STAssertFalse(stack.set_register(DWARF_CFA_STATE_MAX_REGISTERS, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, 100), @"A register was somehow allocated from an empty free list");
    
    /* Verify that modifying an already-added register succeeds */
    STAssertTrue(stack.set_register(0, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, 0), @"Failed to modify existing register");
    STAssertEquals((uint8_t)DWARF_CFA_STATE_MAX_REGISTERS, stack.get_register_count(), @"Register count was bumped when modifying an existing register");

    /* Verify the register values that were added */
    for (uint32_t i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        plcrash_dwarf_cfa_reg_rule_t rule;
        uint64_t value;
        
        STAssertTrue(stack.get_register_rule(i, &rule, &value), @"Failed to fetch info for entry");
        STAssertEquals((uint64_t)i, value, @"Incorrect value");
        STAssertEquals(rule, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, @"Incorrect rule");
    }
}

/**
 * Test handling of unsigned values.
 */
- (void) testSetRegisterUnsigned {
    dwarf_cfa_state<uint64_t, int64_t> stack;
    plcrash_dwarf_cfa_reg_rule_t rule;
    uint64_t value;

    stack.set_register(1, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (uint64_t)INT64_MIN);
    STAssertTrue(stack.get_register_rule(1, &rule, &value), @"Failed to fetch info for entry");
    STAssertEquals((int64_t)value, INT64_MIN, @"Incorrect value");
}

/**
 * Test enumerating registers in the current state.
 */
- (void) testEnumerateRegisters {
    dwarf_cfa_state<uint64_t, int64_t> stack;
    
    STAssertTrue(DWARF_CFA_STATE_MAX_REGISTERS > 32, @"This test assumes a minimum of 32 registers");

    /* Allocate all available entries */
    for (int i = 0; i < 32; i++) {
        STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, i), @"Failed to add register");
        STAssertEquals((uint8_t)(i+1), stack.get_register_count(), @"Incorrect number of registers");
    }
    
    /* Enumerate */
    dwarf_cfa_state_iterator<uint64_t, int64_t> iter = dwarf_cfa_state_iterator<uint64_t, int64_t>(&stack);
    uint32_t found_set = UINT32_MAX;
    dwarf_cfa_state_regnum_t regnum;
    plcrash_dwarf_cfa_reg_rule_t rule;
    uint64_t value;
    
    for (int i = 0; i < 32; i++) {
        STAssertTrue(iter.next(&regnum, &rule, &value), @"Iteration failed while additional registers remain");
        STAssertEquals((uint64_t)regnum, value, @"Unexpected value");
        STAssertEquals(rule, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, @"Incorrect rule");
        
        found_set &= ~(1<<i);
    }
    
    STAssertFalse(iter.next(&regnum, &rule, &value), @"Iteration succeeded after successfully iterating all registers (got regnum=%" PRIu32 ")", regnum);
    
    STAssertEquals(found_set, (uint32_t)0, @"Did not enumerate all 32 values: 0x%" PRIx32, found_set);
}

/**
 * Test removing register values from the current state.
 */
- (void) testRemoveRegister {
    dwarf_cfa_state<uint64_t, int64_t> stack;
    
    /* Insert rules for all entries */
    for (int i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, i), @"Failed to add register");
        STAssertEquals((uint8_t)(i+1), stack.get_register_count(), @"Incorrect number of registers");
    }

    /* Remove a quarter of the entries */
    uint8_t remove_count = 0;
    for (int i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        if (i % 2) {
            stack.remove_register(i);
            remove_count++;
        }
    }

    STAssertEquals(stack.get_register_count(), (uint8_t)(100-remove_count), @"Register count was not correctly updated");
    
    /* Verify the full set of registers (including verifying that the removed registers were, in fact, removed) */
    for (uint32_t i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        plcrash_dwarf_cfa_reg_rule_t rule;
        uint64_t value;
        
        if (i % 2) {
            STAssertFalse(stack.get_register_rule(i, &rule, &value), @"Register info was returned for a removed register");
        } else {
            STAssertTrue(stack.get_register_rule(i, &rule, &value), @"Failed to fetch info for entry");
            STAssertEquals((uint64_t)i, value, @"Incorrect value");
            STAssertEquals(rule, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, @"Incorrect rule");
        }
    }
    
    /* Re-add the missing registers (verifying that they were correctly added to the free list) */
    for (int i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        if (i % 2)
            STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, i), @"Failed to add register");
    }
    
    STAssertEquals(stack.get_register_count(), (uint8_t)100, @"Register count was not correctly updated");
    
    /* Ensure that additional requests fail */
    STAssertFalse(stack.set_register(DWARF_CFA_STATE_MAX_REGISTERS+1, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, DWARF_CFA_STATE_MAX_REGISTERS+1), @"A register was somehow allocated from an empty free list");
    
    /* Verify the register values that were added */
    for (uint32_t i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++) {
        plcrash_dwarf_cfa_reg_rule_t rule;
        uint64_t value;
        
        STAssertTrue(stack.get_register_rule(i, &rule, &value), @"Failed to fetch info for entry");
        STAssertEquals((uint64_t)i, value, @"Incorrect value");
        STAssertEquals(rule, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, @"Incorrect rule");
    }
}

/**
 * Test pushing and popping of register state.
 */
- (void) testPushPopState {
    dwarf_cfa_state<uint64_t, int64_t> stack;

    /* Validate initial CFA state */
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_UNDEFINED, stack.get_cfa_rule().type(), @"Unexpected initial CFA value");

    /* Verify that popping an empty stack returns an error */
    STAssertFalse(stack.pop_state(), @"Popping succeeded on an empty state stack");
    
    /* Configure initial test state */
    for (int i = 0; i < (DWARF_CFA_STATE_MAX_REGISTERS/4); i++) {
        STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, DWARF_CFA_STATE_MAX_REGISTERS-i), @"Failed to add register");
        STAssertEquals((uint8_t)(i+1), stack.get_register_count(), @"Incorrect number of registers");
    }

    stack.set_cfa_register(10, 20);
    
    /* Try pushing and initializing new state */
    STAssertTrue(stack.push_state(), @"Failed to push a new state");
    STAssertEquals((uint8_t)0, stack.get_register_count(), @"New state should have a register count of 0");

    for (int i = 0; i < (DWARF_CFA_STATE_MAX_REGISTERS/4); i++) {
        STAssertTrue(stack.set_register(i, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, i), @"Failed to add register");
        STAssertEquals((uint8_t)(i+1), stack.get_register_count(), @"Incorrect number of registers");
    }

    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_UNDEFINED, stack.get_cfa_rule().type(), @"Unexpected initial CFA value");
    
    /* Pop the state, verify that our original state was saved */
    STAssertTrue(stack.pop_state(), @"Failed to pop current state");
    for (uint32_t i = 0; i < (DWARF_CFA_STATE_MAX_REGISTERS/4); i++) {
        plcrash_dwarf_cfa_reg_rule_t rule;
        uint64_t value;
        
        STAssertTrue(stack.get_register_rule(i, &rule, &value), @"Failed to fetch info for entry");
        STAssertEquals((uint64_t)(DWARF_CFA_STATE_MAX_REGISTERS-i), value, @"Incorrect value");
        STAssertEquals(rule, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, @"Incorrect rule");
    }
    
    STAssertEquals(DWARF_CFA_STATE_CFA_TYPE_REGISTER, stack.get_cfa_rule().type(), @"Unexpected CFA type");
    STAssertEquals((dwarf_cfa_state_regnum_t)10, stack.get_cfa_rule().register_number(), @"Unexpected CFA register");
    STAssertEquals((uint64_t)20, stack.get_cfa_rule().register_offset(), @"Unexpected CFA offset");

    /* Validate state overflow checking; an implicit state already exists at the top of the stack, so we
     * start iteration at 1. */
    for (uint8_t i = 1; i < DWARF_CFA_STATE_MAX_STATES; i++) {
        STAssertTrue(stack.push_state(), @"Failed to push a new state");
    }
    STAssertFalse(stack.push_state(), @"Pushing succeeded on a full state stack");
}

@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
