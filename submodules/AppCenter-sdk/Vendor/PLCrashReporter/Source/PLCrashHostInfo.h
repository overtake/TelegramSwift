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

/**
 * @ingroup plcrash_host
 * @{
 */

/**
 * A major.minor.revision version number.
 */
typedef struct PLCrashHostInfoVersion {
    /** The major version number. */
    NSUInteger major;

    /** The minor version numer. */
    NSUInteger minor;

    /** The revision number */
    NSUInteger revision;
} PLCrashHostInfoVersion;

/** The Darwin kernel major version for Mac OS X 10.9 */
#define PLCRASH_HOST_MAC_OS_X_DARWIN_MAJOR_VERSION_10_9 13

/** The Darwin kernel major version for iOS 9 */
#define PLCRASH_HOST_IOS_DARWIN_MAJOR_VERSION_9 15

@interface PLCrashHostInfo : NSObject {
@private
    /** The Darwin (xnu) release version (eg, kern.osversion) */
    PLCrashHostInfoVersion _darwinVersion;
}

+ (instancetype) currentHostInfo;

/**
 * The Darwin (xnu) release version (eg, kern.osversion). This value is parsed from its string representation,
 * and may not be accurate. Clients should fail safely in the case of encountering an unexpected version value.
 */
@property(nonatomic, readonly) PLCrashHostInfoVersion darwinVersion;

@end

/**
 * @}
 */
