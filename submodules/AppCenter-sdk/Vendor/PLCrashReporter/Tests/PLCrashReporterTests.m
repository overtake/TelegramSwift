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

#import "PLCrashReport.h"
#import "PLCrashReporter.h"
#import "PLCrashFrameWalker.h"
#import "PLCrashTestThread.h"

@interface PLCrashReporterTests : SenTestCase
@end

@implementation PLCrashReporterTests

- (void) testSingleton {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    STAssertNotNil([PLCrashReporter sharedReporter], @"Returned nil singleton instance");
    STAssertTrue([PLCrashReporter sharedReporter] == [PLCrashReporter sharedReporter], @"Crash reporter did not return singleton instance");
#pragma clang diagnostic pop
}

/**
 * Test generation of a 'live' crash report for a specific thread.
 */
- (void) testGenerateLiveReportWithThread {
    NSError *error;
    NSData *reportData;
    plcrash_test_thread_t thr;

    /* Spawn a thread and generate a report for it */
    plcrash_test_thread_spawn(&thr);
    PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
    reportData = [reporter generateLiveReportWithThread: pthread_mach_thread_np(thr.thread)
                                                  error: &error];
    plcrash_test_thread_stop(&thr);
    STAssertNotNil(reportData, @"Failed to generate live report: %@", error);

    /* Try parsing the result */
    PLCrashReport *report = [[PLCrashReport alloc] initWithData: reportData error: &error];
    STAssertNotNil(report, @"Could not parse geneated live report: %@", error);

    /* Sanity check the signal info */
    if (report) {
        STAssertEqualStrings([[report signalInfo] name], @"SIGTRAP", @"Incorrect signal name");
        STAssertEqualStrings([[report signalInfo] code], @"TRAP_TRACE", @"Incorrect signal code");
    }
}

/**
 * Test generation of a 'live' crash report.
 */
- (void) testGenerateLiveReport {
    NSError *error;
    PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
    NSData *reportData = [reporter generateLiveReportAndReturnError: &error];
    STAssertNotNil(reportData, @"Failed to generate live report: %@", error);
    
    PLCrashReport *report = [[PLCrashReport alloc] initWithData: reportData error: &error];
    STAssertNotNil(report, @"Could not parse geneated live report: %@", error);

    STAssertEqualStrings([[report signalInfo] name], @"SIGTRAP", @"Incorrect signal name");
    STAssertEqualStrings([[report signalInfo] code], @"TRAP_TRACE", @"Incorrect signal code");
}

@end
