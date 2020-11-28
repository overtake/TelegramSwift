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

#import "PLCrashReportExceptionInfo.h"

/**
 * If a crash is triggered by an uncaught Objective-C exception, the exception name and reason will be made available.
 */
@implementation PLCrashReportExceptionInfo

@synthesize exceptionName = _name;
@synthesize exceptionReason = _reason;
@synthesize stackFrames = _stackFrames;

/**
 * Initialize with the given exception name and reason.
 *
 * @param name Exception name.
 * @param reason Exception reason.
 */
- (id) initWithExceptionName: (NSString *) name reason: (NSString *) reason {
    return [self initWithExceptionName: name reason: reason stackFrames: nil];
}

/**
 * Initialize with the given exception name, reason, and call stack.
 *
 * @param name Exception name.
 * @param reason Exception reason.
 * @param stackFrames The exception's original call stack, as an array of PLCrashReportStackFrameInfo instances.
 */
- (id) initWithExceptionName: (NSString *) name reason: (NSString *) reason stackFrames: (NSArray *) stackFrames {
    if ((self = [super init]) == nil)
        return nil;
    
    _name = name;
    _reason = reason;
    _stackFrames = stackFrames;
    
    return self;
}

@end
