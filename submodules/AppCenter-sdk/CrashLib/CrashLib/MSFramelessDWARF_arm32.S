/*
 * Extracted from PLCrashReporter's 1.2-RC2 frame unwinding test cases.
 *
 * Copyright (c) 2013-2014 Plausible Labs, Inc. All rights reserved.
 * Copyright (c) 2008-2011 Apple Inc. All rights reserved.
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 */

#ifdef __arm__
.text

.align 2
.globl _MSFramelessDWARF_test
_MSFramelessDWARF_test:
// iOS/ARM doesn't support shipping eh_frame/compact unwind data,
// so we trigger the bug here, but provide no hand-generated DWARF
// data to allow unwinding.
LT0_start:
    push    {r4, r5}
LT0_sub_sp:
    mov     r4, fp      // Save FP
    mov     r5, lr      // Save LR
    eor     lr, lr      // Zero LR
    eor     r7, r7      // Zero FP

    bl      _MSFramelessDWARF_test_crash

    mov     fp, r4      // Restore FP
    mov     lr, r5      // Restore LR
    pop     {r4, r5}
    mov     pc, lr
LT0_end:

#endif /* __arm__ */