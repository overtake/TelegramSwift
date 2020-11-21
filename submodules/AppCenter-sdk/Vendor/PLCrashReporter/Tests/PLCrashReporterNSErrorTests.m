/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
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
#import "PLCrashReporterNSError.h"

@interface PLCrashReporterNSErrorTests : SenTestCase @end

@implementation PLCrashReporterNSErrorTests

/**
 * Verify that attempts to populate a NULL error are ignored.
 */
- (void) testPopulateNULL {
    plcrash_populate_error(NULL, PLCrashReporterErrorOperatingSystem, @"desc", nil);
    plcrash_populate_posix_error(NULL, EPERM, @"desc");
}

/**
 * Test basic error population
 */
- (void) testPopulateError {
    NSError *error = nil;

    NSError *eperm = [NSError errorWithDomain: NSPOSIXErrorDomain code: EPERM userInfo: nil];
    plcrash_populate_error(&error, PLCrashReporterErrorOperatingSystem, @"desc", eperm);

    STAssertNotNil(error, @"Did not populate error");
    STAssertEqualObjects([error domain], PLCrashReporterErrorDomain, @"Incorrect error domain");
    STAssertEquals([error code], (NSInteger)PLCrashReporterErrorOperatingSystem, @"Incorrect error code");
    STAssertEqualObjects([error localizedDescription], @"desc", @"Incorrect description");

    NSError *cause = [[error userInfo] objectForKey: NSUnderlyingErrorKey];
    STAssertNotNil(cause, @"Missing error cause");
    STAssertEqualObjects([cause domain], NSPOSIXErrorDomain, @"Incorrect error domain");
    STAssertEquals([cause code], (NSInteger)EPERM, @"Incorrect error code");
}

/**
 * Test mach error population
 */
- (void) testPopulateMach {
    NSError *error = nil;
    
    plcrash_populate_mach_error(&error, KERN_INVALID_ARGUMENT, @"desc");
    STAssertNotNil(error, @"Did not populate error");
    STAssertEqualObjects([error domain], PLCrashReporterErrorDomain, @"Incorrect error domain");
    STAssertEquals([error code], (NSInteger)PLCrashReporterErrorOperatingSystem, @"Incorrect error code");
    STAssertEqualObjects([error localizedDescription], @"desc", @"Incorrect description");
    
    NSError *cause = [[error userInfo] objectForKey: NSUnderlyingErrorKey];
    STAssertNotNil(cause, @"Missing error cause");
    STAssertEqualObjects([cause domain], NSMachErrorDomain, @"Incorrect error domain");
    STAssertEquals([cause code], (NSInteger)KERN_INVALID_ARGUMENT, @"Incorrect error code");
}


/**
 * Test posix error population
 */
- (void) testPopulateErrno {
    NSError *error = nil;

    plcrash_populate_posix_error(&error, EPERM, @"desc");
    STAssertNotNil(error, @"Did not populate error");
    STAssertEqualObjects([error domain], PLCrashReporterErrorDomain, @"Incorrect error domain");
    STAssertEquals([error code], (NSInteger)PLCrashReporterErrorOperatingSystem, @"Incorrect error code");
    STAssertEqualObjects([error localizedDescription], @"desc", @"Incorrect description");

    NSError *cause = [[error userInfo] objectForKey: NSUnderlyingErrorKey];
    STAssertNotNil(cause, @"Missing error cause");
    STAssertEqualObjects([cause domain], NSPOSIXErrorDomain, @"Incorrect error domain");
    STAssertEquals([cause code], (NSInteger)EPERM, @"Incorrect error code");
}

@end
