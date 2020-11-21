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

#import "PLCrashProcessInfo.h"
#import "PLCrashAsync.h"

#import <unistd.h>

#include "PLCrashSysctl.h"
#include <sys/types.h>
#include <sys/sysctl.h>

/**
 * @internal
 * @ingroup plcrash_host
 *
 * @{
 */

/**
 * The PLCrashProcessInfo provides methods to access basic information about a target process.
 */
@implementation PLCrashProcessInfo

@synthesize processID = _processID;
@synthesize processName = _processName;
@synthesize parentProcessID = _parentProcessID;

@synthesize traced = _traced;
@synthesize startTime = _startTime;

/**
 * Return the current process info of the calling process. Note that these values
 * will be fetched once, and the returned instance is immutable.
 */
+ (instancetype) currentProcessInfo {
    return [[self alloc] initWithProcessID: getpid()];
}

/**
 * Initialize a new instance with the process info for the process with @a pid. Returns nil if
 * @a pid does not reference a valid process.
 *
 * @param pid The process identifier of the target process.
 */
- (instancetype) initWithProcessID: (pid_t) pid {
    if ((self = [super init]) == nil)
        return nil;

    /* Fetch the kinfo_proc structure for the target pid */
    int process_info_mib[] = {
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        pid
    };
    struct kinfo_proc process_info;
    size_t process_info_len = sizeof(process_info);

    /* This should always succeed unless the process is not found, or on iOS 9 and similar locked down operating systems where
     * this may return EPERM. */
    if (sysctl(process_info_mib, sizeof(process_info_mib)/sizeof(process_info_mib[0]), &process_info, &process_info_len, NULL, 0) != 0) {
        if (errno == ENOENT)
            PLCF_DEBUG("Unexpected sysctl error %d: %s", errno, strerror(errno));
        return nil;
    }
    
    /* Fetch the traced flag */
    if (process_info.kp_proc.p_flag & P_TRACED)
        _traced = true;

    /* Fetch the process name. This is a best effort attempt */
    {
        /* Clean up any UTF-8 multibyte characters truncated by the kernel -- xnu does not
         * use a UTF-8-aware strcpy when copying names to the fixed p_comm buffer */
        PLCF_ASSERT(sizeof(process_info.kp_proc.p_comm) == MAXCOMLEN+1);
        size_t valid_bytes = plcrash_sysctl_valid_utf8_bytes_max((uint8_t *) process_info.kp_proc.p_comm, MAXCOMLEN);
        
        /* If any valid data is found, try to decode the string; this will return nil if the string still contains invalid UTF-8 */
        if (valid_bytes > 0) {
            _processName = [[NSString alloc] initWithBytes: process_info.kp_proc.p_comm length: valid_bytes encoding: NSUTF8StringEncoding];
        } else {
            _processName = nil;
        }

        /* If decoding failed, the process name is not valid UTF-8, even after our attempt at cleaning up
         * any invalid multibyte sequences. */
        if (_processName == nil) {
            /* Given that HFS+ enforces UTF-8, and the p_comm value is derived from the file system execv path,
             * this should happen very rarely, if ever. */
            PLCF_DEBUG("Failed to decode p_comm for pid=%" PRIdMAX " as UTF-8!", (intmax_t) pid);
        }
    }

    _processID = pid;
    _parentProcessID = process_info.kp_eproc.e_ppid;
    _startTime = process_info.kp_proc.p_starttime;

    return self;
}

@end

/*
 * @}
 */
