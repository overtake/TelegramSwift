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

#import "PLCrashMacros.h"
#import "PLCrashHostInfo.h"
#import "PLCrashSysctl.h"
#import "PLCrashAsync.h"

/**
 * @internal
 * @ingroup plcrash_host
 *
 * @{
 */

/**
 * @internal
 *
 * The PLCrashHostInfo provides methods to access basic information about the current host.
 */
@implementation PLCrashHostInfo

@synthesize darwinVersion = _darwinVersion;

/**
 * Return the current process info of the calling process. If an error occurs
 * fetching the host info, nil will be returned.
 */
+ (instancetype) currentHostInfo {
    return [[self alloc] init];
}

/*
 * Best-effort parsing of major.minor.revision. Any missing or unparsable elements
 * will be defaulted to 0.
 */
static BOOL parse_osrelease (NSString *osrelease, PLCrashHostInfoVersion *version) {
    NSScanner *scanner = [NSScanner scannerWithString: osrelease];

    version->major = 0;
    version->minor = 0;
    version->revision = 0;

    if (![scanner scanInteger: (NSInteger *) &version->major])
        goto error;

    if (![scanner scanString: @"." intoString: NULL])
        goto error;
    
    if (![scanner scanInteger: (NSInteger *) &version->minor])
        goto error;
    
    if (![scanner scanString: @"." intoString: NULL])
        goto error;
    
    if (![scanner scanInteger: (NSInteger *) &version->revision])
        goto error;

    return YES;

error:
    PLCR_LOG("Unexpected kern.osrelease string format: %s", [osrelease UTF8String]);
    return NO;
}

/**
 * Initialize a new instance with the current host's information. If an error occurs
 * fetching the host info, nil will be returned.
 */
- (instancetype) init {
    if ((self = [super init]) == nil)
        return nil;

    /* Extract the Darwin version */
    char *val = plcrash_sysctl_string("kern.osrelease");
    if (val == NULL) {
        /* This should never fail; if it does, either malloc failed, or 'kern.osrelease' disappeared. */
        PLCR_LOG("Failed to fetch kern.osrelease value %d: %s", errno, strerror(errno));
        return nil;
    }
    NSString *osrelease = [[NSString alloc] initWithBytesNoCopy: val length: strlen(val) encoding: NSUTF8StringEncoding freeWhenDone: YES];

    /* Since this is best-effort, we ignore parse failures; unparseable elements will be defaulted to '0' */
    parse_osrelease(osrelease, &_darwinVersion);
    return self;
}

@end

/*
 * @}
 */
