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

#ifdef __i386__

.text

# Frameless, save esi, edi, ebp
.globl _MSFramelessDWARF_test
_MSFramelessDWARF_test:
LFB6:
subl	$28, %esp
LCFI17:
movl	%esi, 16(%esp)
LCFI18:
movl	%edi, 20(%esp)
LCFI19:
movl	%ebp, 24(%esp)
LCFI20:
movl	$0, %esi
movl	$0, %edi
movl	$0, %ebp

call    _MSFramelessDWARF_test_crash

movl	16(%esp), %esi
movl	20(%esp), %edi
movl	24(%esp), %ebp
addl	$28, %esp
ret
LFE6:

.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
EH_frame1:
.set L$set$0,LECIE1-LSCIE1
.long L$set$0	# Length of Common Information Entry
LSCIE1:
.long	0x0	# CIE Identifier Tag
.byte	0x1	# CIE Version
.ascii "zR\0"	# CIE Augmentation
.byte	0x1	# uleb128 0x1; CIE Code Alignment Factor
.byte	0x7c	# sleb128 -4; CIE Data Alignment Factor
.byte	0x8	# CIE RA Column
.byte	0x1	# uleb128 0x1; Augmentation size
.byte	0x10	# FDE Encoding (pcrel)
.byte	0xc	# DW_CFA_def_cfa
.byte	0x5	# uleb128 0x5
.byte	0x4	# uleb128 0x4
.byte	0x88	# DW_CFA_offset, column 0x8
.byte	0x1	# uleb128 0x1
.align 2
LECIE1:

.globl _MSFramelessDWARF_test.eh
_MSFramelessDWARF_test.eh:
LSFDE17:
.set L$set$28,LEFDE17-LASFDE17
.long L$set$28	# FDE Length
LASFDE17:
.long	LASFDE17-EH_frame1	# FDE CIE offset
.long	LFB6-.	# FDE initial location
.set L$set$29,LFE6-LFB6
.long L$set$29	# FDE address range
.byte	0x0	# uleb128 0x0; Augmentation size
.byte	0x4	# DW_CFA_advance_loc4
.set L$set$30,LCFI17-LFB6
.long L$set$30
.byte	0xe	# DW_CFA_def_cfa_offset
.byte	0x20	# uleb128 0x20
.byte	0x4	# DW_CFA_advance_loc4
.set L$set$31,LCFI20-LCFI17
.long L$set$31
.byte	0x84	# DW_CFA_offset, column 0x4
.byte	0x2	# uleb128 0x2
.byte	0x87	# DW_CFA_offset, column 0x7
.byte	0x3	# uleb128 0x3
.byte	0x86	# DW_CFA_offset, column 0x6
.byte	0x4	# uleb128 0x4
.align 2
LEFDE17:

#endif /* __i386__ */