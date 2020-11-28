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

#import "PLCrashMacros.h"
#import "PLCrashMachExceptionPortSet.h"
#import "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

/**
 * @internal
 *
 * Represents an unordered set of PLCrashMachExceptionPortState instances.
 *
 * @par NSFastEnumeration
 *
 * This class conforms to NSFastEnumeration, which may be used to enumerate
 * the managed PLCrashMachExceptionPortState instances.
 */
@implementation PLCrashMachExceptionPortSet

@synthesize asyncSafeRepresentation = _asyncSafeRepresentation;
@synthesize set = _state_set;

/**
 * Initialize a new instance with the given @a set of PLCrashMachExceptionPortState instances.
 *
 * @param set A set of up to EXC_TYPES_COUNT PLCrashMachExceptionPortState instances.
 *
 * @warning If @a set contains more than EXC_TYPES_COUNT instances, an exception will be thrown.
 */
- (id) initWithSet: (NSSet *) set {
    if ((self = [super init]) == nil)
        return nil;

    NSAssert([set count] <= EXC_TYPES_COUNT, @"Set size of %lu exceeds EXC_TYPES_COUNT (%lu)", (unsigned long)[set count], (unsigned long)EXC_TYPES_COUNT);
    _state_set = set;

    /* Initialize the async-safe C representation (using borrowed port references) */
    plcrash_mach_exception_port_set_t port_set;
    port_set.count = 0;
    for (PLCrashMachExceptionPort *state in set) {
        port_set.ports[port_set.count] = state.server_port;
        
        port_set.masks[port_set.count] = state.mask;
        port_set.behaviors[port_set.count] = state.behavior;
        port_set.flavors[port_set.count] = state.flavor;
        port_set.count++;
    }
    _asyncSafeRepresentation = port_set;
    
    return self;
}

/**
 * Initialize a new instance with the given async-safe C representation. The receiver will assume ownership of the associated mach ports, and
 * will decrement their reference count upon deallocation.
 *
 * @param asyncSafeRepresentation An async-safe representation of the port state set (@sa plcrash_mach_exception_port_set_t)
 *
 * @warning If @a asyncSafeRepresentation contains more than EXC_TYPES_COUNT instances, an exception will be thrown.
 */
- (id) initWithAsyncSafeRepresentation: (plcrash_mach_exception_port_set_t) asyncSafeRepresentation {
    if ((self = [super init]) == nil)
        return nil;
    
    plcrash_mach_exception_port_set_t *states = &asyncSafeRepresentation;
    NSAssert(states->count <= EXC_TYPES_COUNT, @"Count of %lu exceeds EXC_TYPES_COUNT (%lu)", (unsigned long)states->count, (unsigned long)EXC_TYPES_COUNT);

    kern_return_t kt;
    NSMutableSet *stateResult = [NSMutableSet setWithCapacity: states->count];
    for (mach_msg_type_number_t i = 0; i < states->count; i++) {
        PLCrashMachExceptionPort *state = [[PLCrashMachExceptionPort alloc] initWithServerPort: states->ports[i]
                                                                                               mask: states->masks[i]
                                                                                           behavior: states->behaviors[i]
                                                                                             flavor: states->flavors[i]];
        [stateResult addObject: state];

        /* The state instance increments the refcount, and we acquire ownership of the caller's refcount */
        if ((kt = mach_port_mod_refs(mach_task_self(), states->ports[i], MACH_PORT_RIGHT_SEND, -1)) != KERN_SUCCESS) {
            PLCR_LOG("Unexpected error decrementing mach port reference: %d", kt);
        }
    }

    _state_set = stateResult;
    _asyncSafeRepresentation = asyncSafeRepresentation;

    return self;
}

// from NSFastEnumeration protocol
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) state objects: (id __unsafe_unretained _Nullable [_Nonnull]) stackbuf count: (NSUInteger) len {
    return [_state_set countByEnumeratingWithState: state objects: stackbuf count: len];
}

@end

#endif
