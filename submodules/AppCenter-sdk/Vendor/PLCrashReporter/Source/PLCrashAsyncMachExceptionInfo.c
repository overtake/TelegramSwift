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

#include "PLCrashAsyncMachExceptionInfo.h"
#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

/**
 * @ingroup plcrash_async_mach_exception_info
 * @{
 */

/**
 * @internal
 *
 * Map a Mach exception to its BSD signal representation.
 *
 * @param exception_type Mach exception type.
 * @param codes Mach exception codes.
 * @param code_count The number of codes provided.
 * @param cpu_type The target architecture on which the exception was generated, encoded as a Mach-O CPU type. Interpreting Mach exception data is
 * architecture-specific. If the CPU type is unknown, CPU_TYPE_ANY may be provided.
 * @param siginfo The siginfo structure to be initialized.
 *
 * @warning Mapping to BSD signal information is primarily supported to maintain backwards compatibility with existing report handlers
 * that expect to receive BSD signal data, rather than Mach exception data. Note, however, that the returned signal info may not exactly match the
 * kernel exception-to-signal mappings implemented in xnu. As such, when Mach exception data is available, its use should be preferred.
 */
bool plcrash_async_mach_exception_get_siginfo (exception_type_t exception_type, mach_exception_data_t codes, mach_msg_type_number_t code_count, cpu_type_t cpu_type, siginfo_t *siginfo) {
    if (code_count < 2) {
        PLCF_DEBUG("Unexpected Mach code count of %u; can't map to UNIX exception", code_count);
        return false;
    }
    
    mach_exception_code_t code = codes[0];
    mach_exception_subcode_t subcode = codes[1];

    /* Set the si_signo and si_addr */
    switch (exception_type) { 
        case EXC_BAD_ACCESS:
            /*
             * XXX: Stack overflow should result in a SIGSEGV, but a guard page access will trigger KERN_PROTECTION_FAILURE (SIGBUS).
             * To map to SIGSEGV in this case, we would need to know whether the faulting address is within the stack guard pages --
             * since this is not available, we'll map to the incorrect SIGBUS.
             */
            if (code == KERN_INVALID_ADDRESS) {
                siginfo->si_signo = SIGSEGV;
            } else {
                siginfo->si_signo = SIGBUS;
            }

            siginfo->si_addr = (void *)subcode;
            break;
            
        case EXC_BAD_INSTRUCTION:
            siginfo->si_signo = SIGILL;
            siginfo->si_addr = (void *)subcode;
            break;
            
        case EXC_ARITHMETIC:
            siginfo->si_signo = SIGFPE;
            siginfo->si_addr = (void *)subcode;
            break;
            
        case EXC_EMULATION:
            siginfo->si_signo = SIGEMT;
            siginfo->si_addr = (void *)subcode;
            break;
            
        case EXC_SOFTWARE:
            switch (code) {
                case EXC_UNIX_BAD_SYSCALL:
                    siginfo->si_signo = SIGSYS;
                    break;
                    
                case EXC_UNIX_BAD_PIPE:
                    siginfo->si_signo = SIGPIPE;
                    break;
                    
                case EXC_UNIX_ABORT:
                    siginfo->si_signo = SIGABRT;
                    break;
                case EXC_SOFT_SIGNAL:
                    siginfo->si_signo = SIGKILL;
                    break;

                default:
                    PLCF_DEBUG("Unexpected EXC_SOFTWARE code of %lld", code);
                    siginfo->si_signo = SIGABRT;
                    break;
            }

            siginfo->si_addr = (void *)subcode;
            break;
            
        case EXC_BREAKPOINT:
            siginfo->si_signo = SIGTRAP;
            siginfo->si_addr = (void *)subcode;
            break;
            
        default:
            return false;
    }
    
    /* Set the si_code */
    switch (siginfo->si_signo) {
        case SIGSEGV:
            switch (code) {
                case KERN_PROTECTION_FAILURE:
                    siginfo->si_code = SEGV_ACCERR;
                    break;
                    
                case KERN_INVALID_ADDRESS:
                    siginfo->si_code = SEGV_MAPERR;
                    break;
                    
                default:
                    siginfo->si_code = SEGV_NOOP;
                    break;
            }
            break;
        case SIGBUS:
            siginfo->si_code = BUS_ADRERR;
            break;
            
        case SIGILL:
            siginfo->si_code = ILL_NOOP;
            break;
            
        case SIGFPE:
            siginfo->si_code = FPE_NOOP;
            break;
            
        case SIGTRAP:
            siginfo->si_code = TRAP_BRKPT;
            break;

        case SIGEMT:
        case SIGSYS:
        case SIGPIPE:
        case SIGABRT:
        case SIGKILL:
            siginfo->si_code = 0x0;
            break;

        default:
            return false;
    }
    
    return true;
}

/**
 * @} plcrash_async_mach_exception_info
 */

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
