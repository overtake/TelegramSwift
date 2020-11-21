/*
 * Author: Landon Fuller <landonf@plausible.coop>
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

#import "PLCrashReportSymbolInfo.h"

/**
 * Crash log symbol information.
 */
@implementation PLCrashReportSymbolInfo

@synthesize symbolName = _symbolName;
@synthesize startAddress = _startAddress;
@synthesize endAddress = _endAddress;

/**
 * Initialize with the provided symbol info.
 *
 * @param symbolName The symbol name.
 * @param startAddress The symbol start address.
 * @param endAddress The symbol end address, if available; otherwise, 0. This must only be provided if it has been
 * explicitly defined by the available debugging info, and should not be derived from best-guess heuristics.
 */
- (id) initWithSymbolName: (NSString *) symbolName
             startAddress: (uint64_t) startAddress
               endAddress: (uint64_t) endAddress
{
    if ((self = [super init]) == nil)
        return nil;

    _symbolName = symbolName;
    _startAddress = startAddress;
    _endAddress = endAddress;

    return self;
}

@end
