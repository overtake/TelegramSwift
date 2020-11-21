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
.globl _unwind_tester_target_ip ; IP that we'll unwind to
_unwind_tester_target_ip:
.quad	Ltester_target_ip

;
; This is a generic function to test that restoring registers during unwinding work correctly.
;
.text
.align 2
.globl _unwind_tester
_unwind_tester:
LFB3:
stp	fp, lr, [sp, #-16]!
LCFI45:
mov	fp, sp
LCFI46:
stp	x20, x19, [sp, #-16]!
LCFI47:
stp	x22, x21, [sp, #-16]!
LCFI48:
stp	x24, x23, [sp, #-16]!
LCFI49:
stp	x26, x25, [sp, #-16]!
LCFI50:
stp	x28, x27, [sp, #-16]!
LCFI52:

.macro lit64
movz    $0, #$1, lsl #48
movk    $0, #$2, lsl #32
movk    $0, #$3, lsl #16
movk    $0, #$4
.endmacro

lit64   x19, 0x1234, 0x5678, 0x8765, 0x4321
lit64   x20, 0x0246, 0x8ACE, 0xECA8, 0x6420
lit64   x21, 0x1357, 0x9BDF, 0xFDB9, 0x7531
lit64   x22, 0x1122, 0x3344, 0x5566, 0x7788
lit64   x23, 0x0022, 0x4466, 0x88AA, 0xCCEE

lit64   x24, 0x0033, 0x5577, 0x99BB, 0xDDFF
lit64   x25, 0x0044, 0x6688, 0xAACC, 0xEE00
lit64   x26, 0x0066, 0x88AA, 0xCCEE, 0xFF11
lit64   x27, 0x0088, 0xAACC, 0xEEFF, 0x1133
lit64   x28, 0xCAFE, 0xDEAD, 0xF00D, 0xBEEF

; save the SP value for use by our tests.
mov     x2, sp
str     x2, [x1]
; call test function which will invoke unwinder which "returns" here
blr     x0
Ltester_target_ip: ; IP that we'll unwind to

; verify that non-volatile registers still contain magic values
.macro cmp64
lit64   x1, $1, $2, $3, $4
cmp     x1, x$0
b.eq    Leq$0
mov     x0, #$0
b       L2
Leq$0:
.endmacro

cmp64   19, 0x1234, 0x5678, 0x8765, 0x4321
cmp64   20, 0x0246, 0x8ACE, 0xECA8, 0x6420
cmp64   21, 0x1357, 0x9BDF, 0xFDB9, 0x7531
cmp64   22, 0x1122, 0x3344, 0x5566, 0x7788
cmp64   23, 0x0022, 0x4466, 0x88AA, 0xCCEE

cmp64   24, 0x0033, 0x5577, 0x99BB, 0xDDFF
cmp64   25, 0x0044, 0x6688, 0xAACC, 0xEE00
cmp64   26, 0x0066, 0x88AA, 0xCCEE, 0xFF11
cmp64   27, 0x0088, 0xAACC, 0xEEFF, 0x1133
cmp64   28, 0xCAFE, 0xDEAD, 0xF00D, 0xBEEF

mov     x0, #0
L2:
ldp     x28, x27, [sp], #16
ldp     x26, x25, [sp], #16
ldp     x24, x23, [sp], #16
ldp     x22, x21, [sp], #16
ldp     x20, x19, [sp], #16
ldp     fp, lr, [sp], #16
ret
Lunwind_tester_end:

.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
EH_frame1:
.set L$set$0,LECIE1-LSCIE1
.long L$set$0	; Length of Common Information Entry
LSCIE1:
.long	0x0	; CIE Identifier Tag
.byte	0x1	; CIE Version
.ascii "zR\0"	; CIE Augmentation
.byte	0x1	; uleb128 0x1; CIE Code Alignment Factor
.byte	0x78	; sleb128 -8; CIE Data Alignment Factor
.byte	0x1E	; CIE RA Column
.byte	0x1	; uleb128 0x1; Augmentation size
.byte	0x10	; FDE Encoding (pcrel)
.byte	0xc	; DW_CFA_def_cfa
.byte	0x1F	; uleb128 31 (x31)
.byte	0x0	; uleb128 0x0
.align 3
LECIE1:

.globl _unwind_tester.eh
_unwind_tester.eh:
LSFDE23:
.set L$set$52,LEFDE23-LASFDE23
.long L$set$52	; FDE Length
LASFDE23:
.long	LASFDE23-EH_frame1	; FDE CIE offset
.quad	LFB3-.	; FDE initial location
.set L$set$53,Lunwind_tester_end-LFB3
.quad L$set$53	; FDE address range
.byte	0x0	; uleb128 0x0; Augmentation size
.byte	0x4	; DW_CFA_advance_loc4
.set L$set$54,LCFI45-LFB3
.long L$set$54
.byte	0xe	; DW_CFA_def_cfa_offset
.byte	0x10	; uleb128 0x10
.byte	0x9D	; DW_CFA_offset, column 0x1D
.byte	0x2	; uleb128 0x2
.byte	0x9E	; DW_CFA_offset, column 0x1E
.byte	0x1	; uleb128 0x1
.byte	0x4	; DW_CFA_advance_loc4
.set L$set$55,LCFI46-LCFI45
.long L$set$55
.byte	0xd	; DW_CFA_def_cfa_register
.byte	0x1D	; uleb128 0x1D
.byte	0x4	; DW_CFA_advance_loc4
.set L$set$56,LCFI52-LCFI46
.long L$set$56
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
.align 3
LEFDE23:

#endif /* __arm64__ */
