/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
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

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

#import "SenTestCompat.h"
#import "PLCrashMachExceptionPortSet.h"

@interface PLCrashMachExceptionPortSetTests : SenTestCase {
    
}
@end

@implementation PLCrashMachExceptionPortSetTests

- (void) testInitWithStruct {
    plcrash_mach_exception_port_set_t state_set;
    state_set.count = 2;
    state_set.masks[0] = EXC_MASK_BAD_ACCESS;
    state_set.behaviors[0] = EXCEPTION_DEFAULT;
    state_set.ports[0] = MACH_PORT_DEAD;
    state_set.flavors[0] = MACHINE_THREAD_STATE;
    
    state_set.masks[1] = EXC_MASK_BAD_INSTRUCTION;
    state_set.behaviors[1] = EXCEPTION_STATE;
    state_set.ports[1] = MACH_PORT_NULL;
    state_set.flavors[1] = MACHINE_THREAD_STATE;
    
    PLCrashMachExceptionPortSet *stateSet = [[PLCrashMachExceptionPortSet alloc] initWithAsyncSafeRepresentation: state_set];
    exception_mask_t found = 0;
    
    /* Test basic initialization; This also tests fast enumeration pass-through */
    for (PLCrashMachExceptionPort *state in stateSet) {
        if (found & state.mask)
            STFail(@"State was enumerated twice");
        
        if (state.mask == EXC_MASK_BAD_ACCESS) {
            STAssertEquals(state.behavior, EXCEPTION_DEFAULT, @"Incorrect behavior");
            STAssertEquals(state.server_port, (mach_port_t)MACH_PORT_DEAD, @"Incorrect port");
            STAssertEquals(state.flavor, MACHINE_THREAD_STATE, @"Incorrect flavor");
            
        } else if (state.mask == EXC_MASK_BAD_INSTRUCTION) {
            STAssertEquals(state.behavior, EXCEPTION_STATE, @"Incorrect behavior");
            STAssertEquals(state.server_port, (mach_port_t)MACH_PORT_NULL, @"Incorrect port");
            STAssertEquals(state.flavor, MACHINE_THREAD_STATE, @"Incorrect flavor");
        } else {
            STFail(@"Unexpected state mask");
        }

        found |= state.mask;
    }
    
    STAssertTrue((found & EXC_MASK_BAD_ACCESS), @"Did not return EXC_BAD_ACCESS state");
    STAssertTrue((found & EXC_MASK_BAD_INSTRUCTION), @"Did not return EXC_BAD_INSTRUCTION state");
    
    /* Test the async-safe representation */
    found = 0;
    plcrash_mach_exception_port_set_t state = stateSet.asyncSafeRepresentation;
    for (mach_msg_type_number_t i = 0; i < state.count; i++) {
        if (found & state.masks[i])
            STFail(@"State was enumerated twice");
        
        if (state.masks[i] == EXC_MASK_BAD_ACCESS) {
            STAssertEquals(state.behaviors[i], EXCEPTION_DEFAULT, @"Incorrect behavior");
            STAssertEquals(state.ports[i], (mach_port_t)MACH_PORT_DEAD, @"Incorrect port");
            STAssertEquals(state.flavors[i], MACHINE_THREAD_STATE, @"Incorrect flavor");
            
        } else if (state.masks[i] == EXC_MASK_BAD_INSTRUCTION) {
            STAssertEquals(state.behaviors[i], EXCEPTION_STATE, @"Incorrect behavior");
            STAssertEquals(state.ports[i], (mach_port_t)MACH_PORT_NULL, @"Incorrect port");
            STAssertEquals(state.flavors[i], MACHINE_THREAD_STATE, @"Incorrect flavor");
        } else {
            STFail(@"Unexpected state mask");
        }
        
        found |= state.masks[i];
    }

    STAssertTrue((found & EXC_MASK_BAD_ACCESS), @"Did not return EXC_BAD_ACCESS state");
    STAssertTrue((found & EXC_MASK_BAD_INSTRUCTION), @"Did not return EXC_BAD_INSTRUCTION state");
    
    STAssertEquals((NSUInteger)2, [stateSet.set count], @"Incorrect state count");
}

- (void) testInitWithSet {
    PLCrashMachExceptionPort *firstState = [[PLCrashMachExceptionPort alloc] initWithServerPort: MACH_PORT_DEAD
                                                                                                mask: EXC_MASK_BAD_ACCESS
                                                                                            behavior: EXCEPTION_DEFAULT
                                                                                              flavor: MACHINE_THREAD_STATE];
    PLCrashMachExceptionPort *secondState = [[PLCrashMachExceptionPort alloc] initWithServerPort: MACH_PORT_NULL
                                                                                                 mask: EXC_MASK_BAD_INSTRUCTION
                                                                                             behavior: EXCEPTION_STATE
                                                                                               flavor: MACHINE_THREAD_STATE];
    NSSet *set = [NSSet setWithObjects: firstState, secondState, nil];
    
    PLCrashMachExceptionPortSet *stateSet = [[PLCrashMachExceptionPortSet alloc] initWithSet: set];
    exception_mask_t found = 0;
    
    /* Test basic initialization; This also tests fast enumeration pass-through */
    for (PLCrashMachExceptionPort *state in stateSet) {
        if (found & state.mask)
            STFail(@"State was enumerated twice");
        
        if (state.mask == EXC_MASK_BAD_ACCESS) {
            STAssertEquals(state.behavior, EXCEPTION_DEFAULT, @"Incorrect behavior");
            STAssertEquals(state.server_port, (mach_port_t)MACH_PORT_DEAD, @"Incorrect port");
            STAssertEquals(state.flavor, MACHINE_THREAD_STATE, @"Incorrect flavor");
            
        } else if (state.mask == EXC_MASK_BAD_INSTRUCTION) {
            STAssertEquals(state.behavior, EXCEPTION_STATE, @"Incorrect behavior");
            STAssertEquals(state.server_port, (mach_port_t)MACH_PORT_NULL, @"Incorrect port");
            STAssertEquals(state.flavor, MACHINE_THREAD_STATE, @"Incorrect flavor");
        } else {
            STFail(@"Unexpected state mask");
        }
        
        found |= state.mask;
    }
    
    STAssertTrue((found & EXC_MASK_BAD_ACCESS), @"Did not return EXC_BAD_ACCESS state");
    STAssertTrue((found & EXC_MASK_BAD_INSTRUCTION), @"Did not return EXC_BAD_INSTRUCTION state");
    
    /* Test the async-safe representation */
    found = 0;
    plcrash_mach_exception_port_set_t state = stateSet.asyncSafeRepresentation;
    for (mach_msg_type_number_t i = 0; i < state.count; i++) {
        if (found & state.masks[i])
            STFail(@"State was enumerated twice");
        
        if (state.masks[i] == EXC_MASK_BAD_ACCESS) {
            STAssertEquals(state.behaviors[i], EXCEPTION_DEFAULT, @"Incorrect behavior");
            STAssertEquals(state.ports[i], (mach_port_t)MACH_PORT_DEAD, @"Incorrect port");
            STAssertEquals(state.flavors[i], MACHINE_THREAD_STATE, @"Incorrect flavor");
            
        } else if (state.masks[i] == EXC_MASK_BAD_INSTRUCTION) {
            STAssertEquals(state.behaviors[i], EXCEPTION_STATE, @"Incorrect behavior");
            STAssertEquals(state.ports[i], (mach_port_t)MACH_PORT_NULL, @"Incorrect port");
            STAssertEquals(state.flavors[i], MACHINE_THREAD_STATE, @"Incorrect flavor");
        } else {
            STFail(@"Unexpected state mask");
        }
        
        found |= state.masks[i];
    }
    
    STAssertTrue((found & EXC_MASK_BAD_ACCESS), @"Did not return EXC_BAD_ACCESS state");
    STAssertTrue((found & EXC_MASK_BAD_INSTRUCTION), @"Did not return EXC_BAD_INSTRUCTION state");
    
    STAssertEquals((NSUInteger)2, [stateSet.set count], @"Incorrect state count");
}

@end

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
