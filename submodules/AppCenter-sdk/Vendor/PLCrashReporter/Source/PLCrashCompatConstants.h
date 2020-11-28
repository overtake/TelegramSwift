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

#ifndef PLCRASH_COMPAT_CONSTANTS_H
#define PLCRASH_COMPAT_CONSTANTS_H 1

#include <AvailabilityMacros.h>

#include <mach/machine.h>

/*
 * ARM64 compact unwind constants; Since these values are fixed by the ABI, we can safely include them directly here.
 *
 * These are not defined on OS X, and they are defined as enums on iOS, preventing a stable #ifdef check. As such,
 * we always define these values on any Mac OS X target, potentially overriding the existing enum identifiers. To
 * ensure this doesn't break inclusion of the header in which the enum identifiers may be defined, we explicitly
 * include the compact unwind header.
 */
#if TARGET_OS_MAC && !TARGET_OS_IPHONE || TARGET_OS_MACCATALYST
#include <mach-o/compact_unwind_encoding.h>
#define UNWIND_ARM64_MODE_MASK                  0x0F000000
#define UNWIND_ARM64_MODE_FRAMELESS             0x02000000
#define UNWIND_ARM64_MODE_DWARF                 0x03000000
#define UNWIND_ARM64_MODE_FRAME                 0x04000000
#define UNWIND_ARM64_FRAME_X19_X20_PAIR         0x00000001
#define UNWIND_ARM64_FRAME_X21_X22_PAIR         0x00000002
#define UNWIND_ARM64_FRAME_X23_X24_PAIR         0x00000004
#define UNWIND_ARM64_FRAME_X25_X26_PAIR         0x00000008
#define UNWIND_ARM64_FRAME_X27_X28_PAIR         0x00000010
#define UNWIND_ARM64_FRAMELESS_STACK_SIZE_MASK  0x00FFF000
#define UNWIND_ARM64_DWARF_SECTION_OFFSET       0x00FFFFFF
#endif

/*
 * OSAtomic* and OSSpinLock are deprecated since macOS 10.12, iOS 10.0 and tvOS 10.0, but suggested replacement
 * for OSSpinLock is missed at runtime on older versions, so we must use it until we support older versions.
 */
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_12 || \
    __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0 || \
    __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_10_0 || \
    __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_3_0
#include <os/lock.h>
#define PLCR_COMPAT_LOCK_TYPE           os_unfair_lock
#define PLCR_COMPAT_LOCK_INIT           OS_UNFAIR_LOCK_INIT
#define PLCR_COMPAT_LOCK_LOCK(lock)     os_unfair_lock_lock(lock)
#define PLCR_COMPAT_LOCK_UNLOCK(lock)   os_unfair_lock_unlock(lock)
#else
#include <libkern/OSAtomic.h>
#define PLCR_COMPAT_LOCK_TYPE           OSSpinLock
#define PLCR_COMPAT_LOCK_INIT           OS_SPINLOCK_INIT
#define PLCR_COMPAT_LOCK_LOCK(lock)     OSSpinLockLock(lock)
#define PLCR_COMPAT_LOCK_UNLOCK(lock)   OSSpinLockUnlock(lock)
#endif

#endif /* PLCRASH_COMPAT_CONSTANTS_H */
