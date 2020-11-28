/*
 * Author: Damian Morris <damian@moso.com.au>
 *
 * Copyright (c) 2010 MOSO Corporation, Pty Ltd.
 * Copyright (c) 2010-2013 Plausible Labs Cooperative, Inc.
 *
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

#import "PLCrashReportProcessInfo.h"

/**
 * Crash log process data.
 *
 * Provides the process name, ID, path, parent process name and ID for the crashed
 * application process.
 */
@implementation PLCrashReportProcessInfo

/**
 * Initialize with the provided process details.
 *
 * @param processName Process name. May be nil.
 * @param processID Process PID.
 * @param processPath Full path to the process' binary. May be nil.
 * @param processStartTime Date and time that the crashing process was started. May be nil.
 * @param parentProcessName Parent process' name. May be nil.
 * @param parentProcessID Parent process' PID.
 * @param native Flag designating whether this process is native. If false, the process is being run via process-level
 * CPU emulation (such as Rosetta).
 */
- (id) initWithProcessName: (NSString *) processName
                 processID: (NSUInteger) processID
               processPath: (NSString *) processPath
          processStartTime: (NSDate *) processStartTime
         parentProcessName: (NSString *) parentProcessName
           parentProcessID: (NSUInteger) parentProcessID
                    native: (BOOL) native
{
    if ((self = [super init]) == nil)
        return nil;
    
    _processName = processName;
    _processID = processID;
    _processPath = processPath;
    _processStartTime = processStartTime;
    _parentProcessName = parentProcessName;
    _parentProcessID = parentProcessID;
    _native = native;

    return self;
}

@synthesize processName = _processName;
@synthesize processID = _processID;
@synthesize processPath = _processPath;
@synthesize processStartTime = _processStartTime;
@synthesize parentProcessName = _parentProcessName;
@synthesize parentProcessID = _parentProcessID;
@synthesize native = _native;

@end
