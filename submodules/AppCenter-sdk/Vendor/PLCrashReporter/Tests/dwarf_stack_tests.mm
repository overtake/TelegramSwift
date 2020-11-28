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
#include "dwarf_stack.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

@interface dwarf_stack_tests : PLCrashTestCase {
@private
    dwarf_stack<int, 10> _stack;
}
@end

/**
 * Test DWARF stack handling.
 */
@implementation dwarf_stack_tests

#define assert_push(v) STAssertTrue(_stack.push(v), @"push failed")
#define assert_pop(v) STAssertTrue(_stack.pop(v), @"pop failed")

/** Test basic push/pop handling. */
- (void) testPushPop {
    int v;
    
    assert_push(1);
    assert_push(2);

    assert_pop(&v);
    STAssertEquals(2, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(1, v, @"Incorrect value popped");
}

/** Test peek */
- (void) testPeek {
    int v;
    
    assert_push(10);
    
    STAssertTrue(_stack.peek(&v), @"Peek failed");
    STAssertEquals(10, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(10, v, @"Incorrect value popped");
}

/** Test drop */
- (void) testDrop {
    int v;
    
    assert_push(1);
    assert_push(2);
    assert_push(3);
    
    STAssertTrue(_stack.drop(), @"Drop failed");

    assert_pop(&v);
    STAssertEquals(2, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(1, v, @"Incorrect value popped");
    
    STAssertFalse(_stack.peek(&v), @"Stack should be empty");
    STAssertFalse(_stack.drop(), @"Drop should fail on an empty stack");
}

/** Test dup */
- (void) testDup {
    int v;

    _stack.push(10);
    _stack.push(5);
    _stack.dup();

    assert_pop(&v);
    STAssertEquals(5, v, @"Incorrect value popped");

    assert_pop(&v);
    STAssertEquals(5, v, @"Incorrect value popped");

}

/** Test pick */
- (void) testPick {
    int v;
    
    _stack.push(10);
    _stack.push(5);

    /* Pick the two existing values in reverse order */
    STAssertTrue(_stack.pick(0), @"Pick failed");
    STAssertTrue(_stack.pick(2), @"Pick failed");

    /* Verify the order */
    assert_pop(&v);
    STAssertEquals(10, v, @"Incorrect value picked");

    assert_pop(&v);
    STAssertEquals(5, v, @"Incorrect value picked");
    
    /* Verify bounds checking (there should only be 2 items on the stack) */
    STAssertFalse(_stack.pick(2), @"Invalid pick succeeded");
    STAssertFalse(_stack.pick(3), @"Invalid pick succeeded");
}

/** Test swap */
- (void) testSwap {
    int v;
    
    assert_push(1);
    assert_push(2);
    
    STAssertTrue(_stack.swap(), @"Swap failed");
    
    assert_pop(&v);
    STAssertEquals(1, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(2, v, @"Incorrect value popped");
    
    STAssertFalse(_stack.swap(), @"Swap on empty stack without two elements should fail");
    assert_push(1);
    STAssertFalse(_stack.swap(), @"Swap on empty stack without two elements should fail");
}

/** Test rotate */
- (void) testRotate {
    int v;
    
    assert_push(3);
    assert_push(2);
    assert_push(1);

    STAssertTrue(_stack.rotate(), @"Rotate failed");

    assert_pop(&v);
    STAssertEquals(2, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(3, v, @"Incorrect value popped");
    
    assert_pop(&v);
    STAssertEquals(1, v, @"Incorrect value popped");
    
    STAssertFalse(_stack.rotate(), @"Rotate on empty stack without three elements should fail");
    assert_push(1);
    assert_push(2);
    STAssertFalse(_stack.rotate(), @"Rotate on empty stack without three elements should fail");
}

/**
 * Test a pop on an empty stack.
 */
- (void) testPopEmpty {
    dwarf_stack<int, 1> stack;
    int v;
    STAssertFalse(stack.pop(&v), @"pop should have failed on empty stack");
}

/**
 * Test a push on a full stack.
 */
- (void) testPushFull {
    dwarf_stack<int, 2> stack;
    STAssertTrue(stack.push(1), @"push failed");
    STAssertTrue(stack.push(2), @"push failed");
    STAssertFalse(stack.push(3), @"push succeeded on a full stack");
}

@end

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
