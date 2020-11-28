/*
 * Author: Landon Fuller <landonf@plausible.coop>
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

#import "PLCrashReportProcessorInfo.h"

/**
 * Crash log processor record.
 *
 * This contains information about a specific processor type and subtype, and may be used
 * to differentiate between processor variants (eg, ARMv6 vs ARMv7).
 *
 * @par CPU Type Encodings
 *
 * The wire format maintains support for multiple CPU type encodings; it is expected that different operating
 * systems may target different processors, and the reported CPU type and subtype information may not be
 * easily or directly expressed when not using the vendor's own defined types.
 *
 * Currently, only Apple Mach CPU type/subtype information is supported by the wire protocol. These types are
 * stable, intended to be encoded in Mach-O files, and are defined in mach/machine.h on Mac OS X.
 */
@implementation PLCrashReportProcessorInfo

@synthesize typeEncoding = _typeEncoding;
@synthesize type = _type;
@synthesize subtype = _subtype;

/**
 * Initialize the processor info data object.
 *
 * @param typeEncoding The CPU type encoding.
 * @param type The CPU type.
 * @param subtype The CPU subtype
 */
- (id) initWithTypeEncoding: (PLCrashReportProcessorTypeEncoding) typeEncoding
                       type: (uint64_t) type
                    subtype: (uint64_t) subtype
{
    if ((self = [super init]) == nil)
        return nil;

    _typeEncoding = typeEncoding;
    _type = type;
    _subtype = subtype;

    return self;
}

@end
