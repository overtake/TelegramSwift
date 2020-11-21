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

#import "PLCrashSysctl.h"
#import "PLCrashHostInfo.h"

#import <sys/utsname.h>


@interface PLCrashHostInfoTests : SenTestCase {
@private
    __strong PLCrashHostInfo *_hostInfo;
}
@end

@implementation PLCrashHostInfoTests

- (void) setUp {
    _hostInfo = [PLCrashHostInfo currentHostInfo];
}

- (void) tearDown {
    _hostInfo = nil;
}

- (void) testDarwinVersion {
    PLCrashHostInfoVersion dv = _hostInfo.darwinVersion;
    struct utsname n;

    /* Extract release info */
    STAssertEquals(0, uname(&n), @"Failed to fetch uname");
    NSString *osrelease = [[NSString alloc] initWithBytes: n.release length: strlen(n.release) encoding:NSUTF8StringEncoding];
    NSArray *vcomps = [osrelease componentsSeparatedByString: @"."];
    
    STAssertTrue([vcomps count] >= 1, @"Could not parse release version");
    NSUInteger major = [[vcomps objectAtIndex: 0] integerValue];
    STAssertNotEquals((NSUInteger)0, major, @"Invalid major version of 0 (no Mac or IOS release has shipped with a major verson of 0");
    
    STAssertTrue([vcomps count] >= 2, @"Missing minor version");
    NSUInteger minor = [[vcomps objectAtIndex: 1] integerValue];
    
    STAssertTrue([vcomps count] >= 3, @"Missing revision version");
    NSUInteger revision = [[vcomps objectAtIndex: 2] integerValue];

    /* Compare against the version extracted by PLCrashHostInfo. */
    STAssertEquals(dv.major, (NSUInteger)major, @"Unexpected major version number");
    STAssertEquals(dv.minor, (NSUInteger)minor, @"Unexpected minor version number");
    STAssertEquals(dv.revision, (NSUInteger)revision, @"Unexpected revision version number");

}

@end
