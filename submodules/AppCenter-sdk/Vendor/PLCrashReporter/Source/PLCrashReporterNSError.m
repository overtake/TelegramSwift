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

#import "PLCrashReporterNSError.h"

/**
 * Populate an NSError instance with the provided information.
 *
 * @param error Error instance to populate. If NULL, this method returns
 * and nothing is modified.
 * @param code The error code corresponding to this error.
 * @param description A localized error description.
 * @param cause The underlying cause, if any. May be nil.
 */
void plcrash_populate_error (NSError **error, PLCrashReporterError code, NSString *description, NSError *cause) {
    NSMutableDictionary *userInfo;
    
    if (error == NULL)
        return;
    
    /* Create the userInfo dictionary */
    userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys: description, NSLocalizedDescriptionKey, nil];
    
    /* Add the cause, if available */
    if (cause != nil)
        [userInfo setObject: cause forKey: NSUnderlyingErrorKey];
    
    *error = [NSError errorWithDomain: PLCrashReporterErrorDomain code: code userInfo: userInfo];
}

/**
 * Populate an PLCrashReporterErrorOperatingSystem NSError instance, using the provided
 * Mach error value to create the underlying error cause.
 *
 * @param error Error instance to populate. If NULL, this method returns
 * and nothing is modified.
 * @param kr The Mach return value
 * @param description A localized error description.
 */
void plcrash_populate_mach_error (NSError **error, kern_return_t kr, NSString *description) {
    NSError *cause = [NSError errorWithDomain: NSMachErrorDomain code: kr userInfo: nil];
    plcrash_populate_error(error, PLCrashReporterErrorOperatingSystem, description, cause);
}

/**
 * Populate an PLCrashReporterErrorOperatingSystem NSError instance, using the provided
 * errno error value to create the underlying error cause.
 *
 * @param error Error instance to populate. If NULL, this method returns
 * and nothing is modified.
 * @param errnoVal The OS errno value
 * @param description A localized error description.
 */
void plcrash_populate_posix_error (NSError **error, int errnoVal, NSString *description) {
    NSError *cause = [NSError errorWithDomain: NSPOSIXErrorDomain code: errnoVal userInfo: nil];
    plcrash_populate_error(error, PLCrashReporterErrorOperatingSystem, description, cause);
}

