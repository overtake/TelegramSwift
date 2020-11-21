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

#import "SenTestCompat.h"

#import "PLCrashAsyncMachExceptionInfo.h"
#import "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

@interface PLCrashAsyncMachExceptionInfoTests : SenTestCase @end


@implementation PLCrashAsyncMachExceptionInfoTests

#define TEST_ME(cpu, exc_type, code, subcode, signo, sicode, siaddr) do { \
    siginfo_t siginfo; \
    mach_exception_data_type_t codes[] = { \
        code, \
        subcode \
    }; \
\
    STAssertTrue(plcrash_async_mach_exception_get_siginfo(exc_type, codes, 2, cpu, &siginfo), @"Failed to map exception to siginfo"); \
    STAssertEquals(signo, siginfo.si_signo, @"Incorrect si_signo value"); \
    STAssertEquals(sicode, siginfo.si_code, @"Incorrect si_code value"); \
    STAssertEquals((void *)siaddr, siginfo.si_addr, @"Incorrect si_addr value"); \
} while(0)

- (void) testBadAccess {
    TEST_ME(CPU_TYPE_ANY, EXC_BAD_ACCESS, KERN_PROTECTION_FAILURE, 0x4, SIGBUS, BUS_ADRERR, 0x4);
    TEST_ME(CPU_TYPE_ANY, EXC_BAD_ACCESS, KERN_INVALID_ADDRESS, 0x4, SIGSEGV, SEGV_MAPERR, 0x4);
}

- (void) testBadInstruction {
    TEST_ME(CPU_TYPE_ANY, EXC_BAD_INSTRUCTION, KERN_PROTECTION_FAILURE, 0x4, SIGILL, ILL_NOOP, 0x4);
}

- (void) testArithmetic {
    TEST_ME(CPU_TYPE_ANY, EXC_ARITHMETIC, KERN_PROTECTION_FAILURE, 0x4, SIGFPE, FPE_NOOP, 0x4);
}

- (void) testEmulation {
    TEST_ME(CPU_TYPE_ANY, EXC_EMULATION, KERN_PROTECTION_FAILURE, 0x4, SIGEMT, 0, 0x4);
}

- (void) testSoftware {
    TEST_ME(CPU_TYPE_ANY, EXC_SOFTWARE, EXC_UNIX_BAD_SYSCALL, 0x4, SIGSYS, 0, 0x4);
    TEST_ME(CPU_TYPE_ANY, EXC_SOFTWARE, EXC_UNIX_BAD_PIPE, 0x4, SIGPIPE, 0, 0x4);
    TEST_ME(CPU_TYPE_ANY, EXC_SOFTWARE, EXC_UNIX_ABORT, 0x4, SIGABRT, 0, 0x4);
    TEST_ME(CPU_TYPE_ANY, EXC_SOFTWARE, EXC_SOFT_SIGNAL, 0x4, SIGKILL, 0, 0x4);
}

- (void) testBreakpoint {
    TEST_ME(CPU_TYPE_ANY, EXC_BREAKPOINT, KERN_INVALID_ADDRESS, 0x4, SIGTRAP, TRAP_BRKPT, 0x4);
}

@end

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
