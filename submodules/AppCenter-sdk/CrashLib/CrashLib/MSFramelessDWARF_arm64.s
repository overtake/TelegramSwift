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

#ifdef __arm64__

.text
.align 2
.globl _MSFramelessDWARF_test
_MSFramelessDWARF_test:
    stp     x20, x19, [sp, #-16]!
LT1_sub_sp:
    mov     x19, fp     ; Save FP
    mov     x20, lr     ; Save LR
    mov     fp, xzr     ; Overwrite FP
    mov     lr, xzr     ; Overwrite LR
    bl      _MSFramelessDWARF_test_crash ; Trigger crash
    ldp     x20, x19, [sp], #16
    mov     fp, x19      ; Restore FP
    mov     lr, x20      ; Restore LR
    ret
LT1_end:

.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
; Standard CIE for our test functions
EH_frame1:
.set L$set$0,LECIE1-LSCIE1
.long L$set$0 ; Length of Common Information Entry
LSCIE1:
.long	0x0 ; CIE Identifier Tag
.byte	0x1 ; CIE Version
.ascii "zR\0" ; CIE Augmentation
.byte	0x1 ; uleb128 0x1; CIE Code Alignment Factor
.byte	0x78 ; sleb128 -8; CIE Data Alignment Factor
.byte	0x1E ; CIE RA Column
.byte	0x1 ; uleb128 0x1; Augmentation size
.byte	0x10 ; FDE Encoding (pcrel)
.byte	0xc ; DW_CFA_def_cfa
.byte	0x1F ; uleb128 31 (x31)
.byte	0x0 ; uleb128 0x0
.align 3
LECIE1:

; Generates our common FDE header for register-saved test cases.
; Arguments:
; 0 - Test number (eg, 0, 1, 2). Used to resolve local label names for
;     the given test, and to name FDE-specific labels.
; 1 - Test name (eg, x19_x20, no_reg)
; 2 - Stack size, as a uleb128 value
.macro fde_header
.globl _MSFramelessDWARF_$1.eh
_MSFramelessDWARF_$1.eh:
LSFDE$0:
.set Lset0$0,LEFDE$0-LASFDE$0
.long Lset0$0 ; FDE Length
LASFDE$0:
.long	LASFDE$0-EH_frame1 ; FDE CIE offset
.quad	_MSFramelessDWARF_$1-. ; FDE initial location
.set Lset1$0,LT$0_end-_MSFramelessDWARF_$1
.quad Lset1$0 ; FDE address range
.byte	0x0 ; uleb128 0x0; Augmentation size
.byte	0x4 ; DW_CFA_advance_loc4
.set Lset2$0,LT$0_sub_sp-_MSFramelessDWARF_$1
.long Lset2$0
.byte	0xe	; DW_CFA_def_cfa_offset
.byte	$2	; uleb128 stack offset
.endmacro

; Generates our common FDE printer
; Arguments:
; 0 - Test number (eg, 0, 1, 2).
.macro fde_footer
.align 3
LEFDE$0:
.endmacro

; DW_CFA_register rules appear to trigger an ld bug:
;   "could not create compact unwind for _MSFramelessDWARF_test: saved registers do not fit in stack size"
; We're only saving two register on the stack, so perhaps ld64 register
; counting code incorrectly assumes DW_CFA_register consumes stack space.
fde_header 1, test, 0x10
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3
.byte   0x09    ; DW_CFA_register
.byte   0x1D ; uleb128 29 (fp)
.byte   0x13 ; uleb128 13 (x19)
.byte   0x09    ; DW_CFA_register
.byte   0x1E ; uleb128 29 (lr)
.byte   0x14 ; uleb128 13 (x20)
fde_footer 1

#endif /* __arm64__ */