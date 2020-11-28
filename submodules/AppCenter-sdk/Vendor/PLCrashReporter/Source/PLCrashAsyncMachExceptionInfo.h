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

#ifndef PLCRASH_ASYNC_MACH_EXCEPTION_INFO_H
#define PLCRASH_ASYNC_MACH_EXCEPTION_INFO_H

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

PLCR_C_BEGIN_DECLS

#include <stdbool.h>
#include <mach/mach.h>
#include <signal.h>
    
#include "PLCrashAsync.h"
    
/**
 * @internal
 *
 * @defgroup plcrash_async_mach_exception_info Mach Exception Information
 * @ingroup plcrash_async
 *
 * Provides mapping of Mach exception types and codes to BSD signals and
 * string representations
 *
 * @{
 */
    
/*
 * The following values are considered unsupported (and are #ifdef'd __APPLE_API_UNSTABLE in
 * unpublished xnu headers), but are required for interpreting EXC_SOFTWARE appropriately.
 *
 * @internal
 * This is exactly why operating at the Mach exception layer is generally a bad idea.
 */
#ifndef EXC_UNIX_BAD_SYSCALL
#define EXC_UNIX_BAD_SYSCALL    0x10000     /* SIGSYS */
#endif
    
#ifndef EXC_UNIX_BAD_PIPE
#define EXC_UNIX_BAD_PIPE       0x10001     /* SIGPIPE */
#endif
    
#ifndef EXC_UNIX_ABORT
#define EXC_UNIX_ABORT          0x10002     /* SIGABRT */
#endif

bool plcrash_async_mach_exception_get_siginfo (exception_type_t exception_type, mach_exception_data_t codes, mach_msg_type_number_t code_count, cpu_type_t cpu_type, siginfo_t *siginfo);

/*
 * @} plcrash_async_mach_exception_info
 */

PLCR_C_END_DECLS

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
#endif /* PLCRASH_ASYNC_MACH_EXCEPTION_INFO_H */
