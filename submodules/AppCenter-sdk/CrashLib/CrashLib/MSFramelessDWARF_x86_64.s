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

#ifdef __x86_64__

.text
.globl _MSFramelessDWARF_test
_MSFramelessDWARF_test:
# Frameless, saved rbx and rbp
LFB7:
movq	%rbx, -16(%rsp)
LCFI8:
movq	%rbp, -8(%rsp)
LCFI9:
subq	$24, %rsp
LCFI10:
movq	$0, %rbp
movq	$0, %rbx
call    _MSFramelessDWARF_test_crash
movq	8(%rsp), %rbx
movq	16(%rsp), %rbp
addq	$24, %rsp
ret
LFE7:

.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
EH_frame1:
.set L$set$0,LECIE1-LSCIE1
.long L$set$0	# Length of Common Information Entry
LSCIE1:
.long	0x0	# CIE Identifier Tag
.byte	0x1	# CIE Version
.ascii "zR\0"	# CIE Augmentation
.byte	0x1	# uleb128 0x1; CIE Code Alignment Factor
.byte	0x78	# sleb128 -8; CIE Data Alignment Factor
.byte	0x10	# CIE RA Column
.byte	0x1	# uleb128 0x1; Augmentation size
.byte	0x10	# FDE Encoding (pcrel)
.byte	0xc	# DW_CFA_def_cfa
.byte	0x7	# uleb128 0x7
.byte	0x8	# uleb128 0x8
.byte	0x90	# DW_CFA_offset, column 0x10
.byte	0x1	# uleb128 0x1
.align 3
LECIE1:

.globl _MSFramelessDWARF_test.eh
_MSFramelessDWARF_test.eh:
LSFDE14:
.set L$set$21,LEFDE14-LASFDE14
.long L$set$21	# FDE Length
LASFDE14:
.long	LASFDE14-EH_frame1	# FDE CIE offset
.quad	LFB7-.	# FDE initial location
.set L$set$22,LFE7-LFB7
.quad L$set$22	# FDE address range
.byte	0x0	# uleb128 0x0; Augmentation size
.byte	0x4	# DW_CFA_advance_loc4
.set L$set$23,LCFI10-LFB7
.long L$set$23
.byte	0xe	# DW_CFA_def_cfa_offset
.byte	0x20	# uleb128 0x20
.byte	0x86	# DW_CFA_offset, column 0x6
.byte	0x2	# uleb128 0x2
.byte	0x83	# DW_CFA_offset, column 0x3
.byte	0x3	# uleb128 0x3
.align 3
LEFDE14:

#endif /* __x86_64__ */