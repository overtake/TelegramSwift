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
.globl _unwind_tester_list_arm64_frameless
_unwind_tester_list_arm64_frameless:
.quad   _unwind_test_arm64_frameless_no_reg
.quad   _unwind_test_arm64_frameless_x19_x20
.quad   _unwind_test_arm64_frameless_x19_x20_x21_x22
.quad   _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24
.quad   _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26
.quad   _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28
.quad	0

.text
; A trampoline that uses DWARF encoded unwind info to save/restore the link
; register on behalf of its caller. This allows us to test compact unwind
; encoding for our callers (which doesn't support save/restore of LR).
.align 2
.globl _unwind_test_arm64_frameless_trampoline
_unwind_test_arm64_frameless_trampoline:
    stp	fp, x0, [sp, #-16]! ; Set up our frame
Ltr_stp:
    mov	fp, sp
Ltr_fp:
    str	lr, [sp, #-16]! ; Save our actual LR
Ltr_pushed_regs:
    bl _uwind_to_main
    ldr lr, [sp], #16
    mov	sp, fp
    ldp	fp, x0, [sp], #16
    ret	lr
Ltr_end:

.align 2
.globl _unwind_test_arm64_frameless_no_reg
_unwind_test_arm64_frameless_no_reg:
    sub     sp, sp, #16
LT1_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    ; The following is skipped during unwind, in which case we rely on the trampoline DWARF correctly
    ; restoring our original LR value.
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    add     sp, sp, #16
    ret
LT1_end:

.align 2
.globl _unwind_test_arm64_frameless_x19_x20
_unwind_test_arm64_frameless_x19_x20:
    stp     x20, x19, [sp, #-16]!
    mov     x19, xzr
    mov     x20, xzr
LT2_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    ldp     x20, x19, [sp], #16
    ret
LT2_end:

.align 2
.globl _unwind_test_arm64_frameless_x19_x20_x21_x22
_unwind_test_arm64_frameless_x19_x20_x21_x22:
    stp     x20, x19, [sp, #-16]!
    stp     x22, x21, [sp, #-16]!
    mov     x19, xzr
    mov     x20, xzr
    mov     x21, xzr
    mov     x22, xzr
LT3_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ret
LT3_end:

.align 2
.globl _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24
_unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24:
    stp     x20, x19, [sp, #-16]!
    stp     x22, x21, [sp, #-16]!
    stp     x24, x23, [sp, #-16]!
    mov     x19, xzr
    mov     x20, xzr
    mov     x21, xzr
    mov     x22, xzr
    mov     x23, xzr
    mov     x24, xzr
LT4_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ret
LT4_end:

.align 2
.globl _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26
_unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26:
    stp     x20, x19, [sp, #-16]!
    stp     x22, x21, [sp, #-16]!
    stp     x24, x23, [sp, #-16]!
    stp     x26, x25, [sp, #-16]!
    mov     x19, xzr
    mov     x20, xzr
    mov     x21, xzr
    mov     x22, xzr
    mov     x23, xzr
    mov     x24, xzr
    mov     x24, xzr
    mov     x26, xzr
LT5_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    ldp     x26, x25, [sp], #16
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ret
LT5_end:

.align 2
.globl _unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28
_unwind_test_arm64_frameless_x19_x20_x21_x22_x23_x24_x25_x26_x27_x28:
    stp     x20, x19, [sp, #-16]!
    stp     x22, x21, [sp, #-16]!
    stp     x24, x23, [sp, #-16]!
    stp     x26, x25, [sp, #-16]!
    stp     x28, x27, [sp, #-16]!
    mov     x19, xzr
    mov     x20, xzr
    mov     x21, xzr
    mov     x22, xzr
    mov     x23, xzr
    mov     x24, xzr
    mov     x24, xzr
    mov     x26, xzr
    mov     x27, xzr
    mov     x28, xzr
LT6_sub_sp:
    mov     x0, lr ; Pass our link register to the trampoline for preservation
    bl      _unwind_test_arm64_frameless_trampoline
    mov     lr, x0 ; Restore the link register that was saved and returned by our trampoline
    ldp     x28, x27, [sp], #16
    ldp     x26, x25, [sp], #16
    ldp     x24, x23, [sp], #16
    ldp     x22, x21, [sp], #16
    ldp     x20, x19, [sp], #16
    ret
LT6_end:


; Custom DWARF unwind data that allows us to unwind from our trampoline while restoring
; the *caller's* link register. This allows us to implement 'leaf' functions that actually
; call out to uwind_to_main via the trampoline.
.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
LEH_frame0:
.set L$set_c1,LECIE0-LSCIE0
.long L$set_c1 ; Length of Common Information Entry
LSCIE0:
.long	0x0 ; CIE Identifier Tag
.byte	0x1 ; CIE Version
.ascii "zR\0" ; CIE Augmentation
.byte	0x1 ; uleb128 0x1; CIE Code Alignment Factor
.byte	0x78 ; sleb128 -8; CIE Data Alignment Factor
.byte	0x0 ; CIE RA Column -- we restore the actual LR to x0
.byte	0x1 ; uleb128 0x1; Augmentation size
.byte	0x10 ; FDE Encoding (pcrel)
.byte	0xc ; DW_CFA_def_cfa
.byte	0x1F ; uleb128 31 (x31)
.byte	0x0 ; uleb128 0x0
.align 3
LECIE0:

.globl _unwind_test_arm64_frameless_trampoline.eh
_unwind_test_arm64_frameless_trampoline.eh:
LSFDE0:
.set LsetT0,LEFDE0-LASFDE0
.long LsetT0 ; FDE Length
LASFDE0:
.long	LASFDE0-LEH_frame0 ; FDE CIE offset
.quad	_unwind_test_arm64_frameless_trampoline-. ; FDE initial location
.set LsetT1,Ltr_end-_unwind_test_arm64_frameless_trampoline
.quad LsetT1 ; FDE address range
.byte	0x0 ; uleb128 0x0; Augmentation size
.byte	0x4 ; DW_CFA_advance_loc4
.set LsetT2,Ltr_stp-_unwind_test_arm64_frameless_trampoline
.long LsetT2
.byte	0xe ; DW_CFA_def_cfa_offset
.byte	0x10 ; uleb128 0x10
.byte	0x9D ; DW_CFA_offset, column 0x1D
.byte	0x2 ; uleb128 0x2
.byte	0x9E ; DW_CFA_offset, column 0x1E
.byte	0x1	; uleb128 0x1
.byte	0x4 ; DW_CFA_advance_loc4
.set LsetT3,Ltr_fp-Ltr_stp
.long LsetT3
.byte	0xd ; DW_CFA_def_cfa_register
.byte	0x1D ; uleb128 0x1D
.byte	0x4 ; DW_CFA_advance_loc4
.set LsetT4,Ltr_pushed_regs-Ltr_fp
.long LsetT4
.byte	0x80 ; DW_CFA_offset, column 0x0 (x0)
.byte	0x4	; uleb128 0x4
LEFDE0:


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
.globl _unwind_test_arm64_frameless_$1.eh
_unwind_test_arm64_frameless_$1.eh:
LSFDE$0:
.set Lset0$0,LEFDE$0-LASFDE$0
.long Lset0$0 ; FDE Length
LASFDE$0:
.long	LASFDE$0-EH_frame1 ; FDE CIE offset
.quad	_unwind_test_arm64_frameless_$1-. ; FDE initial location
.set Lset1$0,LT$0_end-_unwind_test_arm64_frameless_$1
.quad Lset1$0 ; FDE address range
.byte	0x0 ; uleb128 0x0; Augmentation size
.byte	0x4 ; DW_CFA_advance_loc4
.set Lset2$0,LT$0_sub_sp-_unwind_test_arm64_frameless_$1
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

fde_header 1, no_reg, 0x10
fde_footer 1

fde_header 2, x19_x20, 0x10
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3
fde_footer 2

fde_header 3, x19_x20_x21_x22, 0x20
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3
.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x4	; uleb128 0x4
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x5	; uleb128 0x5
fde_footer 3

fde_header 4, x19_x20_x21_x22_x23_x24, 0x30
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x4	; uleb128 0x4
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x5	; uleb128 0x5

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x6	; uleb128 0x6
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x7	; uleb128 0x7
fde_footer 4

fde_header 5, x19_x20_x21_x22_x23_x24_x25_x26, 0x40
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x4	; uleb128 0x4
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x5	; uleb128 0x5

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x6	; uleb128 0x6
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x7	; uleb128 0x7

.byte	0x99	; DW_CFA_offset, column 0x19
.byte	0x8	; uleb128 0x6
.byte	0x9A	; DW_CFA_offset, column 0x1A
.byte	0x9	; uleb128 0x7
fde_footer 5

fde_header 6, x19_x20_x21_x22_x23_x24_x25_x26_x27_x28, 0x50
.byte	0x93	; DW_CFA_offset, column 0x13
.byte	0x2	; uleb128 0x2
.byte	0x94	; DW_CFA_offset, column 0x14
.byte	0x3	; uleb128 0x3

.byte	0x95	; DW_CFA_offset, column 0x15
.byte	0x4	; uleb128 0x4
.byte	0x96	; DW_CFA_offset, column 0x16
.byte	0x5	; uleb128 0x5

.byte	0x97	; DW_CFA_offset, column 0x17
.byte	0x6	; uleb128 0x6
.byte	0x98	; DW_CFA_offset, column 0x18
.byte	0x7	; uleb128 0x7

.byte	0x99	; DW_CFA_offset, column 0x19
.byte	0x8	; uleb128 0x8
.byte	0x9A	; DW_CFA_offset, column 0x1A
.byte	0x9	; uleb128 0x9

.byte	0x9B	; DW_CFA_offset, column 0x1B
.byte	0xA	; uleb128 0xA
.byte	0x9C	; DW_CFA_offset, column 0x1C
.byte	0xB	; uleb128 0xB
fde_footer 6

#endif /* __arm64__ */
