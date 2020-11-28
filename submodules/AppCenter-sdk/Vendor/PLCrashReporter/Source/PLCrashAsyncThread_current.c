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

#include <mach/mach.h>
#include <stddef.h>

#include "PLCrashAsyncThread.h"
#include "PLCrashAsyncThread_current_defs.h"

#include "PLCrashMacros.h"

/*
 * Implements the interior function called by plcrash_async_thread_state_current()
 * after it has populated the mctx thread state.
 */
plcrash_error_t plcrash_async_thread_state_current_stub (plcrash_async_thread_state_current_callback callback,
                                                        void *context,
                                                        pl_mcontext_t *mctx)
{
    /* Zero unsupported thread states */
    plcrash_async_memset(&mctx->__es, 0, sizeof(mctx->__es));
#ifdef __arm64__
    /* On arm64, NEON state is named _ns instead of _fs. */
    plcrash_async_memset(&mctx->__ns, 0, sizeof(mctx->__ns));
#else
    plcrash_async_memset(&mctx->__fs, 0, sizeof(mctx->__fs));
#endif
    
    /* Convert to standard thread state */
    plcrash_async_thread_state_t thread_state;
    plcrash_async_thread_state_mcontext_init(&thread_state, mctx);

    /* Write the report */
    return callback(&thread_state, context);
}


/*
 * Compile time structure sanity checking of our assumed
 * structure layouts. The layouts are ABI-stable.
 */

/* Provides compile-time validation */
#define VALIDATE_2(name, cond, line)    typedef int cc_validate_##name##line [(cond) ? 1 : -1]
#define VALIDATE_1(name, cond, line)    VALIDATE_2(name, cond, line)
#define VALIDATE(name, cond)            VALIDATE_1(name, cond, __LINE__)

/* 
 * Validate non-architecture specific constraints
 */

/* sizeof(struct mcontext) */
VALIDATE(MCONTEXT_SIZE, sizeof(pl_mcontext_t) == PL_MCONTEXT_SIZE);

/* VOFF() is used to assert the structure offsets as required by our assembly trampoline */
#define OFF(struct, reg, offset) (offsetof(pl_mcontext_t, __##struct.__##reg) == offset)
#define VOFF(struct, reg, offset) VALIDATE(MCONTEXT_SS_OFFSET_##reg##_, OFF(struct, reg, offset))

#if __x86_64__

/* There's a hard-coded dependency on this size in the trampoline assembly, so we explicitly validate it here. */
VALIDATE(MCONTEXT_SIZE, sizeof(_STRUCT_MCONTEXT) == 712);

/* Verify the expected offsets */
VOFF(ss, rax, 16);
VOFF(ss, rbx, 24);
VOFF(ss, rcx, 32);
VOFF(ss, rdx, 40);
VOFF(ss, rdi, 48);
VOFF(ss, rsi, 56);
VOFF(ss, rbp, 64);
VOFF(ss, rsp, 72);
VOFF(ss, r8, 80);
VOFF(ss, r9, 88);
VOFF(ss, r10, 96);
VOFF(ss, r11, 104);
VOFF(ss, r12, 112);
VOFF(ss, r13, 120);
VOFF(ss, r14, 128);
VOFF(ss, r15, 136);
VOFF(ss, rip, 144);
VOFF(ss, rflags, 152);
VOFF(ss, cs, 160);
VOFF(ss, fs, 168);
VOFF(ss, gs, 176);

#elif __i386__

/* There's a hard-coded dependency on this size in the trampoline assembly, so we explicitly validate it here. */
VALIDATE(MCONTEXT_SIZE, sizeof(_STRUCT_MCONTEXT) == 600);

VOFF(ss, eax, 12);
VOFF(ss, ebx, 16);
VOFF(ss, ecx, 20);
VOFF(ss, edx, 24);
VOFF(ss, edi, 28);
VOFF(ss, esi, 32);
VOFF(ss, ebp, 36);
VOFF(ss, esp, 40);
// ss
VOFF(ss, eflags, 48);
VOFF(ss, eip, 52);
VOFF(ss, cs, 56);
VOFF(ss, ds, 60);
VOFF(ss, es, 64);
VOFF(ss, fs, 68);
VOFF(ss, gs, 72);

VOFF(es, trapno, 0);

#elif __DARWIN_OPAQUE_ARM_THREAD_STATE64

/* There's a hard-coded dependency on this size in the trampoline assembly, so we explicitly validate it here. */
PLCR_ASSERT_STATIC(MCONTEXT_SIZE, sizeof(pl_mcontext_t) == 816);

/* Verify the expected offsets */
VOFF(ss, x, 16);
VOFF(ss, opaque_fp, 248);
VOFF(ss, opaque_lr, 256);
VOFF(ss, opaque_sp, 264);
VOFF(ss, opaque_pc, 272);
VOFF(ss, cpsr, 280);

#elif defined(__arm64__)

/* There's a hard-coded dependency on this size in the trampoline assembly, so we explicitly validate it here. */
PLCR_ASSERT_STATIC(MCONTEXT_SIZE, sizeof(pl_mcontext_t) == 816);

/* Verify the expected offsets */
VOFF(ss, x, 16);
VOFF(ss, fp, 248);
VOFF(ss, lr, 256);
VOFF(ss, sp, 264);
VOFF(ss, pc, 272);
VOFF(ss, cpsr, 280);

#elif defined(__arm__)

/* There's a hard-coded dependency on this size in the trampoline assembly, so we explicitly validate it here. */
VALIDATE(MCONTEXT_SIZE, sizeof(_STRUCT_MCONTEXT) == 340);

/* Verify the expected offsets */
VOFF(ss, r, 12);
VOFF(ss, sp, 64);
VOFF(ss, lr, 68);
VOFF(ss, pc, 72);
VOFF(ss, cpsr, 76);

#else

#error Unimplemented on this architecture

#endif
