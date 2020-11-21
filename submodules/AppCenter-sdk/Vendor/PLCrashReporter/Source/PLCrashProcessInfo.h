/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
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

#import <sys/types.h>
#import <sys/time.h>

@interface PLCrashProcessInfo : NSObject {
@private
    /** The target process identifier. */
    pid_t _processID;
    
    /** The target process name. */
    __strong NSString *_processName;
    
    /** The target process parent's process identifier. */
    pid_t _parentProcessID;

    /** The process start time. This is the timestamp at which the process was created. */
    struct timeval _startTime;

    /** If YES, a debugger is attached (eg, P_TRACED was set). */
    BOOL _traced;
}

+ (instancetype) currentProcessInfo;

- (instancetype) initWithProcessID: (pid_t) pid;

/** The process ID of the target process. */
@property(nonatomic, readonly) pid_t processID;

/** The name of the target process. This value is provided as a best-effort, and may be truncated or inaccurate. May be nil. */
@property(nonatomic, readonly, strong) NSString *processName;

/** The process ID of the parent of the target process. */
@property(nonatomic, readonly) pid_t parentProcessID;

/** The process start time. This is the timestamp at which the process was created. */
@property(nonatomic, readonly) struct timeval startTime;

/**
 * YES if the target process was being traced (eg, via a debugger).
 */
@property(nonatomic, readonly, getter = isTraced) BOOL traced;

@end
