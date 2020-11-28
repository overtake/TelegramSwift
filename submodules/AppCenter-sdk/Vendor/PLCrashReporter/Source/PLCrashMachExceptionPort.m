/*
 * Author: Landon Fuller <landonf@bikemonkey.org>
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

#import "PLCrashMachExceptionPort.h"
#import "PLCrashReporterNSError.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS


/**
 * @internal
 *
 * This class manages a reference to a Mach exception server port, and the associated
 * mask, behavior, and thread state flavor expected by the given Mach exception server.
 */
@implementation PLCrashMachExceptionPort

@synthesize server_port = _port;
@synthesize mask = _mask;
@synthesize behavior = _behavior;
@synthesize flavor = _flavor;

/**
 * Return the current PLCrashMachExceptionPortState set registered for a @a task and @a mask.
 *
 * @param task The task for which exception port state will be retrieved.
 * @param mask The exception mask for which exception port state will be retrieved.
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object indicating why the Mach exception port state could not be fetched. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 *
 * @return Returns the set of registered port states on success, or nil on failure.
 */
+ (PLCrashMachExceptionPortSet *) exceptionPortsForTask: (task_t) task mask: (exception_mask_t) mask error: (NSError **) outError {
    plcrash_mach_exception_port_set_t states;
    
    kern_return_t kr;

    /* Fetch the current ports */
    kr = task_get_exception_ports(task,
                                  mask,
                                  states.masks,
                                  &states.count,
                                  states.ports,
                                  states.behaviors,
                                  states.flavors);
    
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to fetch mach exception ports");
        return nil;
    }
    
    return [[PLCrashMachExceptionPortSet alloc] initWithAsyncSafeRepresentation: states];
}

/**
 * Return the current PLCrashMachExceptionPortState set registered for a @a thread and @a mask.
 *
 * @param thread The thread for which exception port state will be retrieved.
 * @param mask The exception mask for which exception port state will be retrieved.
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object indicating why the Mach exception port state could not be fetched. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 *
 * @return Returns the set of registered port states on success, or nil on failure.
 */
+ (PLCrashMachExceptionPortSet *) exceptionPortsForThread: (thread_t) thread mask: (exception_mask_t) mask error: (NSError **) outError {
    plcrash_mach_exception_port_set_t states;
    
    kern_return_t kr;
    
    /* Fetch the current ports */
    kr = thread_get_exception_ports(thread,
                                    mask,
                                    states.masks,
                                    &states.count,
                                    states.ports,
                                    states.behaviors,
                                    states.flavors);
    
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to swap mach exception ports");
        return nil;
    }
    
    return [[PLCrashMachExceptionPortSet alloc] initWithAsyncSafeRepresentation: states];
}

/**
 * Initialize a new instance.
 *
 * @param port The Mach exception server's port, for which a MACH_PORT_RIGHT_SEND will be retained (and released on dealloc). MACH_PORT_NULL may be specified.
 * @param mask The exception masks for which @a port should be (or was) registered.
 * @param behavior The exception behavior expected by the server on @a port.
 * @param flavor The thread flavor expected by the server on @a port.
 */
- (instancetype) initWithServerPort: (mach_port_t) port
                               mask: (exception_mask_t) mask
                           behavior: (exception_behavior_t) behavior
                             flavor: (thread_state_flavor_t) flavor
{
    kern_return_t kt;

    if ((self = [super init]) == nil)
        return nil;
    
    _port = port;
    _mask = mask;
    _behavior = behavior;
    _flavor = flavor;
    
    /* Retain the port if it's not MACH_PORT_(NULL|INVALID) */
    if (MACH_PORT_VALID(_port) && (kt = mach_port_mod_refs(mach_task_self(), _port, MACH_PORT_RIGHT_SEND, 1)) != KERN_SUCCESS) {
        PLCR_LOG("Unexpected error incrementing mach port reference: %d", kt);
    }

    return self;
}

- (void) dealloc {
    kern_return_t kt;

    /* Release the port if it's not MACH_PORT_(NULL|INVALID) */
    if (MACH_PORT_VALID(_port) && (kt = mach_port_mod_refs(mach_task_self(), _port, MACH_PORT_RIGHT_SEND, -1)) != KERN_SUCCESS) {
        PLCR_LOG("Unexpected error incrementing mach port reference: %d", kt);
    }
}

/**
 * Atomically set the Mach exception server port managed by the receiver as the @a task's Mach exception server, returning
 * the previously configured ports in @a portStates.
 *
 * @param task The task for which the Mach exception server should be set.
 * @param ports On success, will contain a set of previously registered ports for the exception masks claimed
 * by the receiver. If NULL, the previous ports will not be provided.
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object indicating why the Mach exception port could not be registered. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 * @return YES if the mach exception port state was successfully registered for @a task, NO on error.
 */
- (BOOL) registerForTask: (task_t) task previousPortSet: (__strong PLCrashMachExceptionPortSet **) ports error: (NSError **) outError {
    plcrash_mach_exception_port_set_t prev;
    
    kern_return_t kr;
    kr = task_swap_exception_ports(task,
                                   _mask,
                                   _port,
                                   _behavior,
                                   _flavor,
                                   prev.masks,
                                   &prev.count,
                                   prev.ports,
                                   prev.behaviors,
                                   prev.flavors);
    
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to swap mach exception ports");
        return NO;
    }

    if (ports != NULL)
        *ports = [[PLCrashMachExceptionPortSet alloc] initWithAsyncSafeRepresentation: prev];
    return YES;
}

/**
 * Atomically set the Mach exception server port managed by the receiver as the @a thread's Mach exception server, returning
 * the previously configured ports in @a portStates.
 *
 * @param thread The thread for which the Mach exception server should be set.
 * @param ports On success, will contain a set of previously registered ports for the exception masks claimed
 * by the receiver.
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object indicating why the Mach exception port could not be registered. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 * @return YES if the mach exception port state was successfully registered for @a thread, NO on error.
 */
- (BOOL) registerForThread: (thread_t) thread previousPortSet: (__strong PLCrashMachExceptionPortSet **) ports error: (NSError **) outError {
    plcrash_mach_exception_port_set_t prev;
    
    kern_return_t kr;
    kr = thread_swap_exception_ports(thread,
                                     _mask,
                                     _port,
                                     _behavior,
                                     _flavor,
                                     prev.masks,
                                     &prev.count,
                                     prev.ports,
                                     prev.behaviors,
                                     prev.flavors);
    
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to swap mach exception ports");
        return NO;
    }
    
    if (ports != NULL)
        *ports = [[PLCrashMachExceptionPortSet alloc] initWithAsyncSafeRepresentation: prev];
    
    return YES;
}

@end

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
