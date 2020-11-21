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

#import "PLCrashAsyncSignalInfo.h"

@interface PLCrashAsyncSignalInfoTests : SenTestCase @end


@implementation PLCrashAsyncSignalInfoTests

- (void) testInvalidSignalMapping {
    STAssertNULL(plcrash_async_signal_signame(NSIG + 1), @"Invalid signal should return NULL");
}

- (void) testValidSignalMapping {
    STAssertTrue(strcmp(plcrash_async_signal_signame(SIGSEGV), "SIGSEGV") == 0, @"Incorrect mapping performed");
}

- (void) testInvalidCodeMapping {
    STAssertNULL(plcrash_async_signal_sigcode(SIGIOT, 42), @"Invalid signal/code should return NULL");
}

- (void) testValidCodeMapping {
    STAssertTrue(strcmp(plcrash_async_signal_sigcode(SIGSEGV, SEGV_NOOP), "SEGV_NOOP") == 0, @"Incorrect mapping performed");
}


@end
