/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
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

#import "SenTestCompat.h"

#import "PLCrashSignalHandler.h"
#import "PLCrashProcessInfo.h"

#import <sys/mman.h>
#import <mach/mach.h>

@interface PLCrashSignalHandlerTests : SenTestCase {
}
@end

static bool crash_callback (int signal, siginfo_t *siginfo, ucontext_t *uap, void *context, PLCrashSignalHandlerCallback *next) {
    return true;
}

@implementation PLCrashSignalHandlerTests

/* Page-sized, page aligned, and allocated/deallocated with vm_allocate()/vm_deallocate via -setUp/-tearDown.
 * We use this page to test exception handler behavior by adjusting its page protections and triggering crashes. */
static uint8_t *crash_page;

- (void) setUp {
    kern_return_t kr;

    /* Ensure that handlers registered in each test are not automatically chained by the PLCrashSignalHandler. This
     * includes any saved references to previously registered signal handlers. */
    [PLCrashSignalHandler resetHandlers];


    /* Allocate a test page that can be used to test exception handler behavior by adjusting its page protections
     * and triggering crashes via read/write (or execution) into the page. */
    vm_address_t crash_page_addr;
    kr = vm_allocate(mach_task_self(), &crash_page_addr, PAGE_SIZE, VM_PROT_READ|VM_PROT_WRITE);
    STAssertEquals(KERN_SUCCESS, kr, @"Failed to allocate test page: %d", kr);
    crash_page = (uint8_t *) crash_page_addr;
}

- (void) tearDown {
    kern_return_t kr;

    /* Deallocate our test page */
    kr = vm_deallocate(mach_task_self(), (vm_address_t) crash_page, PAGE_SIZE);
    STAssertEquals(KERN_SUCCESS, kr, @"Failed to deallocate test page: %d", kr);
}

- (void) testSharedHandler {
    STAssertNotNil([PLCrashSignalHandler sharedHandler], @"Nil shared handler");
}

- (void) testRegisterSignalHandlers {
    NSError *error;
    struct sigaction action;

    /* Register the signal handler */
    STAssertTrue([[PLCrashSignalHandler sharedHandler] registerHandlerForSignal: SIGBUS
                                                                       callback: &crash_callback
                                                                        context: NULL
                                                                          error: &error], @"Could not register signal handler: %@", error);
    
    /* Check for SIGBUS registration */
    sigaction (SIGBUS, NULL, &action);
    STAssertNotEquals(action.sa_handler, SIG_DFL, @"Action not registered for SIGBUS");
}

static void sa_action_cb (int signo, siginfo_t *info, void *uapVoid) {
    /* Note that we ran */
    crash_page[1] = 0xFB;
}

static bool noop_crash_cb (int signal, siginfo_t *siginfo, ucontext_t *uap, void *context, PLCrashSignalHandlerCallback *next) {
    /* Note that we ran */
    crash_page[0] = 0xFA;
    
    // Let the original signal handler run
    return PLCrashSignalHandlerForward(next, signal, siginfo, uap);
}

/**
 * Verify that PLCrashSignalHandler correctly passes signals to the original sa_sigaction handler(s).
 */
- (void) testHandlerActionPassthrough {
    NSError *error;

    /* Register a standard POSIX handler */
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = sa_action_cb;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);

    /* Register our callback */
    STAssertTrue([[PLCrashSignalHandler sharedHandler] registerHandlerForSignal: SIGBUS
                                                                       callback: &noop_crash_cb
                                                                        context: NULL
                                                                          error: &error], @"Could not register signal handler: %@", error);

    /* Verify that the callbacks are dispatched */
    siginfo_t si;
    ucontext_t uc;
    plcrash_signal_handler(SIGBUS, &si, &uc);

    STAssertEquals(crash_page[0], (uint8_t)0xFA, @"Crash callback did not run");
    STAssertEquals(crash_page[1], (uint8_t)0xFB, @"Signal handler did not run");
}

static void sa_handler_cb (int signo) {
    /* Note that we ran. */
    crash_page[1] = 0xF0;
}

/**
 * Verify that PLCrashSignalHandler correctly passes signals to the original sa_handler handler(s).
 */
- (void) testHandlerNonActionPassthrough {
    NSError *error;
    
    /* Register a standard POSIX handler */
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sa_handler_cb;
    sigemptyset(&sa.sa_mask);
    STAssertEquals(0, sigaction(SIGBUS, &sa, NULL), @"Failed to set signal handler: %s", strerror(errno));

    /* Register our callback */
    STAssertTrue([[PLCrashSignalHandler sharedHandler] registerHandlerForSignal: SIGBUS
                                                                       callback: &noop_crash_cb
                                                                        context: NULL
                                                                          error: &error], @"Could not register signal handler: %@", error);
    
    /* Verify that the callbacks are dispatched */
    siginfo_t si;
    ucontext_t uc;
    plcrash_signal_handler(SIGBUS, &si, &uc);
    
    STAssertEquals(crash_page[0], (uint8_t)0xFA, @"Crash callback did not run");
    STAssertEquals(crash_page[1], (uint8_t)0xF0, @"Signal handler did not run");
}


@end
