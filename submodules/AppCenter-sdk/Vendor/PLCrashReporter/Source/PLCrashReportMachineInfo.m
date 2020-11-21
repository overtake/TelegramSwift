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

#import "PLCrashReportMachineInfo.h"

/**
 * Crash log host architecture information.
 *
 * Provides host architecture information such as the model name, processor type, and logical and hardware
 * processor counts.
 */
@implementation PLCrashReportMachineInfo

@synthesize modelName = _modelName;
@synthesize processorInfo = _processorInfo;
@synthesize processorCount = _processorCount;
@synthesize logicalProcessorCount = _logicalProcessorCount;

/**
 * Initialize a new machine info data object.
 *
 * @param modelName The hardware model name (eg, MacBookPro6,1). This may be nil.
 * @param processorInfo The processor type, or nil if unavailable.
 * @param processorCount The number of actual physical processor cores. Note that the number of active processors may be managed by the
 * operating system's power management system, and this value may not reflect the number of active
 * processors at the time of the crash.
 * @param logicalProcessorCount The number of logical processors.  Note that the number of active processors may be managed by the
 * operating system's power management system, and this value may not reflect the number of active
 * processors at the time of the crash.
 */
- (id) initWithModelName: (NSString *) modelName
           processorInfo: (PLCrashReportProcessorInfo *) processorInfo
          processorCount: (NSUInteger) processorCount
   logicalProcessorCount: (NSUInteger) logicalProcessorCount
{
    if ((self = [super init]) == nil)
        return nil;

    _modelName = modelName;
    _processorInfo = processorInfo;
    _processorCount = processorCount;
    _logicalProcessorCount = logicalProcessorCount;

    return self;
}

@end
