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

#include "PLCrashAsyncThread_current_defs.h"
#include "PLCrashNamespace.h"

/*
 * plcrash_error_t plcrash_async_thread_state_current (plcrash_async_thread_state_current_callback callback,
 *                                                    void *context);
 */

/* Assembler underscore-prefixed symbol handling for use with the PLCrashNamespace.h symbol namespacing mechanism. */
#ifdef PLCRASHREPORTER_PREFIX
#define _SYM_2(_name)  _ ## _name
#define _SYM_1(_name)  _SYM_2(_name)
#define SYM(_name)     _SYM_1(_name)
#else
#define SYM(_name) _ ## _name
#endif

.text

#if __arm__ || __arm64__
.align 2
#endif

.globl SYM(plcrash_async_thread_state_current)
SYM(plcrash_async_thread_state_current):

#if __x86_64__

pushq   %rbp
movq    %rsp, %rbp
subq    $720, %rsp // Size of 712 + 8 bytes for required alignment

#define MOVQ(reg, offset) movq %##reg, offset(%rsp)

// These assumed offsets are compile-time validated in PLCrashLogWriter_trampoline.m, and are ABI-stable.
MOVQ    (rax,   16)
MOVQ    (rbx,   24);
MOVQ    (rcx,   32);
MOVQ    (rdx,   40);
MOVQ    (rdi,   48);
MOVQ    (rsi,   56);

/* ->rbp: Use our saved copy of the caller's frame pointer */
movq    (%rbp), %rcx
movq    %rcx, 64(%rsp)

/* ->rsp: Use our saved copy of the caller's stack pointer. */
MOVQ    (rbp,   72);

MOVQ    (r8,    80);
MOVQ    (r9,    88);
MOVQ    (r10,   96);
MOVQ    (r11,   104);
MOVQ    (r12,   112);
MOVQ    (r13,   120);
MOVQ    (r14,   128);
MOVQ    (r15,   136);

/* Use the return address for our RIP value */
movq    0x8(%rbp), %rcx
movq    %rcx, 144(%rsp)

/* Fetch the FLAGS state via the stack */
pushfq
popq    %rcx
movq    %rcx, 152(%rsp)

/* The segment registers are 16 bit. Zero out the rest */
/* Do this by moving it to a 64 bit register and then to memory. */
/* The move to via the 64 bit register will automatically clear out the bits */
movq    %cs, %rcx
movq    %rcx, 160(%rsp)
movq    %fs, %rcx
movq   %rcx, 168(%rsp)
movq    %gs, %rcx
movq   %rcx, 176(%rsp)

/* Move mctx to 3rd argument of plcrash_log_writer_write_curthread_stub */
movq    %rsp, %rdx

xorb	%al, %al
callq    SYM(plcrash_async_thread_state_current_stub)

addq    $720, %rsp
popq    %rbp
ret

#elif __i386__

pushl   %ebp
movl    %esp, %ebp
subl    $616, %esp // Size of 600 for context + 4 bytes for required alignment + 12 bytes for call arguments

// OFF is the offset from the top of the stack to the mctx structure
#define OFF 16
#define MOVL(reg, offset) movl %##reg, OFF+offset(%esp)

// These assumed offsets are compile-time validated in PLCrashLogWriter_trampoline.m, and are ABI-stable.

/* es */
movl    $0, 0+OFF(%esp) // trapno

/* ss */
MOVL    (eax,   12)
MOVL    (ebx,   16);
MOVL    (ecx,   20);
MOVL    (edx,   24);
MOVL    (edi,   28);
MOVL    (esi,   32);

/* ->ebp: Use our saved copy of the caller's frame pointer */
movl    (%ebp), %ecx
MOVL    (ecx,    36)

/* ->esp: Use our saved copy of the caller's stack pointer. */
MOVL    (ebp,   40);

/* ss.eflags */
pushf
pop     %eax
movl    %eax, 48+OFF(%esp)

/* Use the return address for our RIP value */
movl    0x4(%ebp), %eax
movl    %eax, 52+OFF(%esp)

/* The segment registers are 16 bit. Zero out the rest */
xorl %eax, %eax
movl %cs, %eax
movl %eax, OFF+56(%esp);
movl %ds, %eax
movl %eax, OFF+60(%esp);
movl %es, %eax
movl %eax, OFF+64(%esp);
movl %fs, %eax
movl %eax, OFF+68(%esp);
movl %gs, %eax
movl %eax, OFF+72(%esp);
#undef MOVL

/* Set up our argument stack: writer (arg0), image_list, file, siginfo, mctx */
/* Set up our argument stack: callback (arg0), context, mctx */
movl    8(%ebp), %eax   // arg0: callback
movl    %eax,  (%esp)

movl    12(%ebp), %eax  // arg1: context
movl    %eax, 4(%esp)

movl    %esp, %eax      // arg3: mctx
addl    $OFF, %eax
movl    %eax, 8(%esp)

call    SYM(plcrash_async_thread_state_current_stub)

addl    $616, %esp
popl    %ebp
ret

#elif defined(__arm64__)

stp     fp, lr, [sp, #-16]!
add     fp, sp, 0
sub     sp, sp, #816 // Size of 816 for context

// These assumed offsets are compile-time validated in PLCrashLogWriter_trampoline.m, and are ABI-stable.

/* Save x0 before we stomp it. The destination address is our SP + 16 (offset to x[] array) */
str     x0, [sp, #16]

/* Save the mcontext_t pointer */
mov     x0, sp

/* Write out GP registers. The base offset of x[1] is SP + 24. */
add     x0, x0, #24

stp     x1, x2, [x0], #16
stp     x3, x4, [x0], #16
stp     x5, x6, [x0], #16
stp     x7, x8, [x0], #16
stp     x9, x10, [x0], #16
stp     x11, x12, [x0], #16
stp     x13, x14, [x0], #16
stp     x15, x16, [x0], #16
stp     x17, x18, [x0], #16
stp     x19, x20, [x0], #16
stp     x21, x22, [x0], #16
stp     x23, x24, [x0], #16
stp     x25, x26, [x0], #16
stp     x27, x28, [x0], #16

/* Fetch caller's frame pointer, save to fp */
ldr     x2, [fp]
str     x2, [x0], #8

/* Fetch the link register from our caller's frame */
ldr     x1, [x2, #8]
str     x1, [x0], #8

/* Use the caller's SP value */
add     x1, fp, #16      // account for the 16 byte push in prologue
str     x1, [x0], #8

/* Use the return address as the PC value */
ldr     x1, [fp, #8]
str     x1, [x0], #8

/* Fetch CPSR */
// mrs     x1, spsr_el1 // TODO_ARM64: The architecture manual says we can read CPSR bits individually,
// str     x1, [x0], #8 // but we still need to figure out how.
str     wzr, [x0], #8   // In the meantime, just zero out the 32-bit value.

/* Restore the r0-r1 argument values. The source address is our SP + 16 (offset to r[] array). */
ldr     x0, [sp, #16];
ldr     x1, [sp, #24];

/* Provide arg 3 (mctx) */
mov     x2, sp

bl      SYM(plcrash_async_thread_state_current_stub)
add	sp, fp, 0
ldp	fp, lr, [sp], #16
ret	lr

#elif defined(__arm__)
.arm

push    {r7, lr}
mov     r7, sp
sub     sp, sp, #340 // Size of 340 for context

// These assumed offsets are compile-time validated in PLCrashLogWriter_trampoline.m, and are ABI-stable.

/* Save r0 before we stomp it. The destination address is our SP + 12 (offset to r[] array) */
str     r0, [sp, #12]

/* Save the mcontext_t pointer */
mov     r0, sp

/* Write out GP registers. The offset is r[1]. */
add     r0, r0, #16
stmia   r0, {r1-r12}

/* Fetch our caller's frame pointer */
ldr     r2, [r7]

/* Overwrite r[7] with the caller's fp value */
str     r2, [r0, #24]

/* Use the caller's SP value */
add     r1, r7, #8    // account for the 2 byte push in prologue
str     r1, [r0, #48] // 64 - 16 byte offset to r[1]

/* Fetch the link register from our caller's frame */
ldr     r1, [r2, #4]
str     r1, [r0, #52] // 68 - 16 byte offset to r[1]

/* Use the return address for our PC value */
ldr     r1, [r7, #4]
str     r1, [r0, #56] // 72 - 16 byte offset to r[1]

/* Fetch CPSR */
mrs     r1, cpsr
str     r1, [r0, #60] // 76 - 16 byte offset to r[1]

/* Restore the r0-r1 argument values. The source address is our SP + 12 (offset to r[] array). */
ldr     r0, [sp, #12];
ldr     r1, [sp, #16];

/* Provide arg 3 (mctx) */
mov     r2, sp

bl      SYM(plcrash_async_thread_state_current_stub)
mov     sp, r7
pop     {r7, pc}

#else

#error Unsupported Platform

#endif
