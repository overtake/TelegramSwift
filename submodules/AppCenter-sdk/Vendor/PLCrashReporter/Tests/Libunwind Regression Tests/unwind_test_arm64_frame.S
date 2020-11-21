/*
 Copyright (c) 2013 Plausible Labs, Inc. All rights reserved.
 Copyright (c) 2008-2011 Apple Inc. All rights reserved.
 
 Ported from the x86-64 tests to arm64 by Plausible Labs.

 This file contains Original Code and/or Modifications of Original Code
 as defined in and that are subject to the Apple Public Source License
 Version 2.0 (the 'License'). You may not use this file except in
 compliance with the License. Please obtain a copy of the License at
 http://www.opensource.apple.com/apsl/ and read it before using this
 file.
 
 The Original Code and all software distributed under the License are
 distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 Please see the License for the specific language governing rights and
 limitations under the License.
 */

#ifdef __arm64__

.data
.globl _unwind_tester_list_arm64_frame
_unwind_tester_list_arm64_frame:
.quad   _unwind_test_arm64_frame_no_reg
.quad   _unwind_test_arm64_frame_x19_x20
.quad   _unwind_test_arm64_frame_x19_x20_x21_x22
.quad   _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24
.quad   _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26
.quad   _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28
.quad	0


.text
.align 2
.globl _unwind_test_arm64_frame_no_reg
_unwind_test_arm64_frame_no_reg:
    stp	fp, lr, [sp, #-16]!
LT1_stp:
    mov	fp, sp
LT1_fp:
LT1_pushed_regs:
    bl _uwind_to_main
    mov	sp, fp
    ldp	fp, lr, [sp], #16
    ret	lr
LT1_end:

.align 2
.globl _unwind_test_arm64_frame_x19_x20
_unwind_test_arm64_frame_x19_x20:
    stp	fp, lr, [sp, #-16]!
LT2_stp:
    mov	fp, sp
LT2_fp:
    stp	x20, x19, [sp, #-16]!
LT2_pushed_regs:
    mov x19, xzr
    mov x20, xzr
    bl _uwind_to_main
    mov	sp, fp
    ldp     x20, x19, [sp], #16
    ldp	fp, lr, [sp], #16
    ret	lr
LT2_end:

.align 2
.globl _unwind_test_arm64_frame_x19_x20_x21_x22
_unwind_test_arm64_frame_x19_x20_x21_x22:
    stp	fp, lr, [sp, #-16]!
LT3_stp:
    mov	fp, sp
LT3_fp:
    stp	x20, x19, [sp, #-16]!
    stp	x22, x21, [sp, #-16]!
LT3_pushed_regs:
    mov x19, xzr
    mov x20, xzr
    mov x21, xzr
    mov x22, xzr
    bl _uwind_to_main
    mov	sp, fp
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ldp	fp, lr, [sp], #16
    ret	lr
LT3_end:

.align 2
.globl _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24
_unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24:
    stp	fp, lr, [sp, #-16]!
LT4_stp:
    mov	fp, sp
LT4_fp:
    stp	x20, x19, [sp, #-16]!
    stp	x22, x21, [sp, #-16]!
    stp	x24, x23, [sp, #-16]!
LT4_pushed_regs:
    mov x19, xzr
    mov x20, xzr
    mov x21, xzr
    mov x22, xzr
    mov x23, xzr
    mov x24, xzr
    bl _uwind_to_main
    mov	sp, fp
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ldp	fp, lr, [sp], #16
    ret	lr
LT4_end:

.align 2
.globl _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26
_unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26:
    stp	fp, lr, [sp, #-16]!
LT5_stp:
    mov	fp, sp
LT5_fp:
    stp	x20, x19, [sp, #-16]!
    stp	x22, x21, [sp, #-16]!
    stp	x24, x23, [sp, #-16]!
    stp	x26, x25, [sp, #-16]!
LT5_pushed_regs:
    mov x19, xzr
    mov x20, xzr
    mov x21, xzr
    mov x22, xzr
    mov x23, xzr
    mov x24, xzr
    mov x25, xzr
    mov x26, xzr
    bl _uwind_to_main
    mov	sp, fp
    ldp     x26, x25, [sp], #16
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ldp	fp, lr, [sp], #16
    ret	lr
LT5_end:

.align 2
.globl _unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28
_unwind_test_arm64_frame_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28:
    stp	fp, lr, [sp, #-16]!
LT6_stp:
    mov	fp, sp
LT6_fp:
    stp	x20, x19, [sp, #-16]!
    stp	x22, x21, [sp, #-16]!
    stp	x24, x23, [sp, #-16]!
    stp	x26, x25, [sp, #-16]!
    stp	x28, x27, [sp, #-16]!
LT6_pushed_regs:
    mov x19, xzr
    mov x20, xzr
    mov x21, xzr
    mov x22, xzr
    mov x23, xzr
    mov x24, xzr
    mov x25, xzr
    mov x26, xzr
    mov x27, xzr
    mov x28, xzr
    bl _uwind_to_main
    mov	sp, fp
    ldp     x26, x25, [sp], #16
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ldp	fp, lr, [sp], #16
    ret	lr
LT6_end:

.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
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
.macro fde_header
.globl _unwind_test_arm64_frame_$1.eh
_unwind_test_arm64_frame_$1.eh:
LSFDE$0:
.set Lset0$0,LEFDE$0-LASFDE$0
.long Lset0$0 ; FDE Length
LASFDE$0:
.long	LASFDE$0-EH_frame1 ; FDE CIE offset
.quad	_unwind_test_arm64_frame_$1-. ; FDE initial location
.set Lset1$0,LT$0_end-_unwind_test_arm64_frame_$1
.quad Lset1$0 ; FDE address range
.byte	0x0 ; uleb128 0x0; Augmentation size
.byte	0x4 ; DW_CFA_advance_loc4
.set Lset2$0,LT$0_stp-_unwind_test_arm64_frame_$1
.long Lset2$0
.byte	0xe ; DW_CFA_def_cfa_offset
.byte	0x10 ; uleb128 0x10
.byte	0x9D ; DW_CFA_offset, column 0x1D
.byte	0x2 ; uleb128 0x2
.byte	0x9E ; DW_CFA_offset, column 0x1E
.byte	0x1	; uleb128 0x1
.byte	0x4 ; DW_CFA_advance_loc4
.set Lset3$0,LT$0_fp-LT$0_stp
.long Lset3$0
.byte	0xd ; DW_CFA_def_cfa_register
.byte	0x1D ; uleb128 0x1D
.byte	0x4 ; DW_CFA_advance_loc4
.set Lset4$0,LT$0_pushed_regs-LT$0_fp
.long Lset4$0
.endmacro

; Generates our common FDE printer
; Arguments:
; 0 - Test number (eg, 0, 1, 2).
.macro fde_footer
.align 3
LEFDE$0:
.endmacro

fde_header 1, no_reg
fde_footer 1

fde_header 2, x19_x20
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x3	; uleb128 0x3
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x4	; uleb128 0x4
fde_footer 2

fde_header 3, x19_x20_x21_x22
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x3	; uleb128 0x3
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x4	; uleb128 0x4

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x5	; uleb128 0x5
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x6	; uleb128 0x6
fde_footer 3

fde_header 4, x19_x20_x21_x22_x23_x24
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x3	; uleb128 0x3
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x4	; uleb128 0x4

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x5	; uleb128 0x5
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x6	; uleb128 0x6

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x7	; uleb128 0x7
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x8	; uleb128 0x8
fde_footer 4

fde_header 5, x19_x20_x21_x22_x23_x24_x25_x26
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x3	; uleb128 0x3
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x4	; uleb128 0x4

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x5	; uleb128 0x5
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x6	; uleb128 0x6

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x7	; uleb128 0x7
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x8	; uleb128 0x8

.byte	0x99	; DW_CFA_offset, column 0x19
.byte	0x9	; uleb128 0x9
.byte	0x9A	; DW_CFA_offset, column 0x1A
.byte	0xA	; uleb128 0xA
fde_footer 5

fde_header 6, x19_x20_x21_x22_x23_x24_x25_x26_x27_x28
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x3	; uleb128 0x3
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x4	; uleb128 0x4

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x5	; uleb128 0x5
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x6	; uleb128 0x6

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x7	; uleb128 0x7
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x8	; uleb128 0x8

.byte	0x99	; DW_CFA_offset, column 0x19
.byte	0x9	; uleb128 0x9
.byte	0x9A	; DW_CFA_offset, column 0x1A
.byte	0xA	; uleb128 0xA

.byte	0x9B	; DW_CFA_offset, column 0x1B
.byte	0xB	; uleb128 0xB
.byte	0x9C	; DW_CFA_offset, column 0x1C
.byte	0xC	; uleb128 0xC
fde_footer 6

#endif /* __arm64__ */
