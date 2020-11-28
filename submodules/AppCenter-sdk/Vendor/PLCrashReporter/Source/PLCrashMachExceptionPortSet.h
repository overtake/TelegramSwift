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

#import <Foundation/Foundation.h>

#import "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

#import <mach/mach.h>

@class PLCrashMachExceptionPort;

/**
 * @internal
 *
 * A pure C representation of the state managed by a PLCrashMachExceptionPortStateSet instance. This may
 * be used in async-safe code paths to represent Mach exception port state.
 *
 * Up to EXC_TYPES_COUNT entries may be returned. The actual count is provided via
 * plcrash_mach_exception_port_state_set::count. The values stored in the arrays correspond
 * positionally.
 */
typedef struct plcrash_mach_exception_port_set {
    /** Number of independent mask/port/behavior/flavor sets
     * (up to EXC_TYPES_COUNT). */
    mach_msg_type_number_t count;
    
    /** Exception masks. */
    exception_mask_t masks[EXC_TYPES_COUNT];
    
    /** Exception ports. */
    mach_port_t ports[EXC_TYPES_COUNT];
    
    /** Exception behaviors. */
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    
    /** Exception thread flavors. */
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
} plcrash_mach_exception_port_set_t;

@interface PLCrashMachExceptionPortSet : NSObject <NSFastEnumeration> {
@private
    /** Backing state set representation. */
    __strong NSSet *_state_set;
    
    plcrash_mach_exception_port_set_t _asyncSafeRepresentation;
}

- (id) initWithSet: (NSSet *) set;
- (id) initWithAsyncSafeRepresentation: (plcrash_mach_exception_port_set_t) asyncSafeRepresentation;

/** The set of PLCrashMachExceptionPortState instances managed by this state set. */
@property(nonatomic, readonly, strong) NSSet *set;

/** The C representation of the port state set. May be used in async-safe code paths. */
@property(nonatomic, readonly) plcrash_mach_exception_port_set_t asyncSafeRepresentation;

@end

#import "PLCrashMachExceptionPort.h"

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
