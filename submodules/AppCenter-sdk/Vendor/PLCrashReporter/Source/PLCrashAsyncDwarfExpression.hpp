/*
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

#ifndef PLCRASH_ASYNC_DWARF_EXPRESSION_H
#define PLCRASH_ASYNC_DWARF_EXPRESSION_H 1

#include "PLCrashAsync.h"
#include "PLCrashAsyncMObject.h"
#include "PLCrashAsyncThread.h"

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */

/**
 * DWARF expression opcodes, as defined by the DWARF 3 Specification (Section 7.7.1).
 *
 * @internal
 *
 * The table was automatically generated from the DWARF specification using the
 * following awk script.
 *
 * @code
 * /^DW_/ {
 *     opcode = $0
 * }
 *
 * !/^DW_/ {
 *     printf "    /\** %s", opcode
 *
 *     if ($2 > 1) {
 *         printf(", accepts %d operands.", $2);
 *     } else if ($2 == 1) {
 *         printf(", accepts %d operand.", $2);
 *     } else {
 *         printf(", accepts no operands.")
 *     }
 *
 *     if (NF > 2) {
 *         for (i = 3; i <= NF; i++) {
 *             printf " %s", $i
 *         }
 *     }
 *     printf " *\/\n"
 *     printf "    %s = %s,\n\n", opcode, $1
 *
 *     # Special case 'range' opcodes that are not included in the spec table
 *     if (opcode == "DW_OP_lit1") {
 *         for (i = 2; i < 31; i++) {
 *             printf("    /\* Literal %d value; see DW_OP_lit0. *\/\n", i)
 *             printf("    DW_OP_lit%d = 0x%x,\n\n", i, val+i-1)
 *         }
 *     } else if (opcode == "DW_OP_reg1") {
 *        for (i = 2; i < 31; i++) {
 *            printf("    /\* Register number; see DW_OP_reg0. *\/\n")
 *            printf("    DW_OP_reg%d = 0x%x,\n\n", i, val+i-1)
 *        }
 *    } else if (opcode == "DW_OP_breg1") {
 *        for (i = 2; i < 31; i++) {
 *            printf("    /\* Register number; see DW_OP_breg0. *\/\n")
 *            printf("    DW_OP_breg%d = 0x%x,\n\n", i, val+i-1)
 *        }
 *    }
 * }
 * @endcode
 */
typedef enum DW_OP {
    /** DW_OP_addr, accepts 1 operand. constant address (size target specific) */
    DW_OP_addr = 0x03,
    
    /** DW_OP_deref, accepts no operands. */
    DW_OP_deref = 0x06,
    
    /** DW_OP_const1u, accepts 1 operand. 1-byte constant */
    DW_OP_const1u = 0x08,
    
    /** DW_OP_const1s, accepts 1 operand. 1-byte constant */
    DW_OP_const1s = 0x09,
    
    /** DW_OP_const2u, accepts 1 operand. 2-byte constant */
    DW_OP_const2u = 0x0a,
    
    /** DW_OP_const2s, accepts 1 operand. 2-byte constant */
    DW_OP_const2s = 0x0b,
    
    /** DW_OP_const4u, accepts 1 operand. 4-byte constant */
    DW_OP_const4u = 0x0c,
    
    /** DW_OP_const4s, accepts 1 operand. 4-byte constant */
    DW_OP_const4s = 0x0d,
    
    /** DW_OP_const8u, accepts 1 operand. 8-byte constant */
    DW_OP_const8u = 0x0e,
    
    /** DW_OP_const8s, accepts 1 operand. 8-byte constant */
    DW_OP_const8s = 0x0f,
    
    /** DW_OP_constu, accepts 1 operand. ULEB128 constant */
    DW_OP_constu = 0x10,
    
    /** DW_OP_consts, accepts 1 operand. SLEB128 constant */
    DW_OP_consts = 0x11,
    
    /** DW_OP_dup, accepts no operands. */
    DW_OP_dup = 0x12,
    
    /** DW_OP_drop, accepts no operands. */
    DW_OP_drop = 0x13,
    
    /** DW_OP_over, accepts no operands. */
    DW_OP_over = 0x14,
    
    /** DW_OP_pick, accepts 1 operand. 1-byte stack index */
    DW_OP_pick = 0x15,
    
    /** DW_OP_swap, accepts no operands. */
    DW_OP_swap = 0x16,
    
    /** DW_OP_rot, accepts no operands. */
    DW_OP_rot = 0x17,
    
    /** DW_OP_xderef, accepts no operands. */
    DW_OP_xderef = 0x18,
    
    /** DW_OP_abs, accepts no operands. */
    DW_OP_abs = 0x19,
    
    /** DW_OP_and, accepts no operands. */
    DW_OP_and = 0x1a,
    
    /** DW_OP_div, accepts no operands. */
    DW_OP_div = 0x1b,
    
    /** DW_OP_minus, accepts no operands. */
    DW_OP_minus = 0x1c,
    
    /** DW_OP_mod, accepts no operands. */
    DW_OP_mod = 0x1d,
    
    /** DW_OP_mul, accepts no operands. */
    DW_OP_mul = 0x1e,
    
    /** DW_OP_neg, accepts no operands. */
    DW_OP_neg = 0x1f,
    
    /** DW_OP_not, accepts no operands. */
    DW_OP_not = 0x20,
    
    /** DW_OP_or, accepts no operands. */
    DW_OP_or = 0x21,
    
    /** DW_OP_plus, accepts no operands. */
    DW_OP_plus = 0x22,
    
    /** DW_OP_plus_uconst, accepts 1 operand. ULEB128 addend */
    DW_OP_plus_uconst = 0x23,
    
    /** DW_OP_shl, accepts no operands. */
    DW_OP_shl = 0x24,
    
    /** DW_OP_shr, accepts no operands. */
    DW_OP_shr = 0x25,
    
    /** DW_OP_shra, accepts no operands. */
    DW_OP_shra = 0x26,
    
    /** DW_OP_xor, accepts no operands. */
    DW_OP_xor = 0x27,
    
    /** DW_OP_skip, accepts 1 operand. signed 2-byte constant */
    DW_OP_skip = 0x2f,
    
    /** DW_OP_bra, accepts 1 operand. signed 2-byte constant */
    DW_OP_bra = 0x28,
    
    /** DW_OP_eq, accepts no operands. */
    DW_OP_eq = 0x29,
    
    /** DW_OP_ge, accepts no operands. */
    DW_OP_ge = 0x2a,
    
    /** DW_OP_gt, accepts no operands. */
    DW_OP_gt = 0x2b,
    
    /** DW_OP_le, accepts no operands. */
    DW_OP_le = 0x2c,
    
    /** DW_OP_lt, accepts no operands. */
    DW_OP_lt = 0x2d,
    
    /** DW_OP_ne, accepts no operands. */
    DW_OP_ne = 0x2e,
    
    /** DW_OP_lit0, accepts no operands. literals 0..31 = (DW_OP_lit0 + literal) */
    DW_OP_lit0 = 0x30,
    
    /** DW_OP_lit1, accepts no operands. ... */
    DW_OP_lit1 = 0x31,
    
    /* Literal 2 value; see DW_OP_lit0. */
    DW_OP_lit2 = 0x32,
    
    /* Literal 3 value; see DW_OP_lit0. */
    DW_OP_lit3 = 0x33,
    
    /* Literal 4 value; see DW_OP_lit0. */
    DW_OP_lit4 = 0x34,
    
    /* Literal 5 value; see DW_OP_lit0. */
    DW_OP_lit5 = 0x35,
    
    /* Literal 6 value; see DW_OP_lit0. */
    DW_OP_lit6 = 0x36,
    
    /* Literal 7 value; see DW_OP_lit0. */
    DW_OP_lit7 = 0x37,
    
    /* Literal 8 value; see DW_OP_lit0. */
    DW_OP_lit8 = 0x38,
    
    /* Literal 9 value; see DW_OP_lit0. */
    DW_OP_lit9 = 0x39,
    
    /* Literal 10 value; see DW_OP_lit0. */
    DW_OP_lit10 = 0x3a,
    
    /* Literal 11 value; see DW_OP_lit0. */
    DW_OP_lit11 = 0x3b,
    
    /* Literal 12 value; see DW_OP_lit0. */
    DW_OP_lit12 = 0x3c,
    
    /* Literal 13 value; see DW_OP_lit0. */
    DW_OP_lit13 = 0x3d,
    
    /* Literal 14 value; see DW_OP_lit0. */
    DW_OP_lit14 = 0x3e,
    
    /* Literal 15 value; see DW_OP_lit0. */
    DW_OP_lit15 = 0x3f,
    
    /* Literal 16 value; see DW_OP_lit0. */
    DW_OP_lit16 = 0x40,
    
    /* Literal 17 value; see DW_OP_lit0. */
    DW_OP_lit17 = 0x41,
    
    /* Literal 18 value; see DW_OP_lit0. */
    DW_OP_lit18 = 0x42,
    
    /* Literal 19 value; see DW_OP_lit0. */
    DW_OP_lit19 = 0x43,
    
    /* Literal 20 value; see DW_OP_lit0. */
    DW_OP_lit20 = 0x44,
    
    /* Literal 21 value; see DW_OP_lit0. */
    DW_OP_lit21 = 0x45,
    
    /* Literal 22 value; see DW_OP_lit0. */
    DW_OP_lit22 = 0x46,
    
    /* Literal 23 value; see DW_OP_lit0. */
    DW_OP_lit23 = 0x47,
    
    /* Literal 24 value; see DW_OP_lit0. */
    DW_OP_lit24 = 0x48,
    
    /* Literal 25 value; see DW_OP_lit0. */
    DW_OP_lit25 = 0x49,
    
    /* Literal 26 value; see DW_OP_lit0. */
    DW_OP_lit26 = 0x4a,
    
    /* Literal 27 value; see DW_OP_lit0. */
    DW_OP_lit27 = 0x4b,
    
    /* Literal 28 value; see DW_OP_lit0. */
    DW_OP_lit28 = 0x4c,
    
    /* Literal 29 value; see DW_OP_lit0. */
    DW_OP_lit29 = 0x4d,
    
    /* Literal 30 value; see DW_OP_lit0. */
    DW_OP_lit30 = 0x4e,
    
    /** DW_OP_lit31, accepts no operands. */
    DW_OP_lit31 = 0x4f,
    
    /** DW_OP_reg0, accepts no operands. reg 0..31 = (DW_OP_reg0 + regnum) */
    DW_OP_reg0 = 0x50,
    
    /** DW_OP_reg1, accepts no operands. ... */
    DW_OP_reg1 = 0x51,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg2 = 0x52,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg3 = 0x53,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg4 = 0x54,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg5 = 0x55,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg6 = 0x56,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg7 = 0x57,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg8 = 0x58,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg9 = 0x59,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg10 = 0x5a,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg11 = 0x5b,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg12 = 0x5c,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg13 = 0x5d,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg14 = 0x5e,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg15 = 0x5f,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg16 = 0x60,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg17 = 0x61,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg18 = 0x62,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg19 = 0x63,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg20 = 0x64,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg21 = 0x65,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg22 = 0x66,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg23 = 0x67,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg24 = 0x68,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg25 = 0x69,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg26 = 0x6a,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg27 = 0x6b,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg28 = 0x6c,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg29 = 0x6d,
    
    /* Register number; see DW_OP_reg0. */
    DW_OP_reg30 = 0x6e,
    
    /** DW_OP_reg31, accepts no operands. */
    DW_OP_reg31 = 0x6f,
    
    /** DW_OP_breg0, accepts 1 operand. SLEB128 offset base register 0..31 = (DW_OP_breg0 + regnum) */
    DW_OP_breg0 = 0x70,
    
    /** DW_OP_breg1, accepts 1 operand. ... */
    DW_OP_breg1 = 0x71,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg2 = 0x72,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg3 = 0x73,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg4 = 0x74,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg5 = 0x75,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg6 = 0x76,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg7 = 0x77,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg8 = 0x78,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg9 = 0x79,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg10 = 0x7a,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg11 = 0x7b,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg12 = 0x7c,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg13 = 0x7d,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg14 = 0x7e,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg15 = 0x7f,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg16 = 0x80,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg17 = 0x81,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg18 = 0x82,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg19 = 0x83,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg20 = 0x84,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg21 = 0x85,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg22 = 0x86,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg23 = 0x87,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg24 = 0x88,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg25 = 0x89,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg26 = 0x8a,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg27 = 0x8b,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg28 = 0x8c,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg29 = 0x8d,
    
    /* Register number; see DW_OP_breg0. */
    DW_OP_breg30 = 0x8e,
    
    /** DW_OP_breg31, accepts 1 operand. */
    DW_OP_breg31 = 0x8f,
    
    /** DW_OP_regx, accepts 1 operand. ULEB128 register */
    DW_OP_regx = 0x90,
    
    /** DW_OP_fbreg, accepts 1 operand. SLEB128 offset */
    DW_OP_fbreg = 0x91,
    
    /** DW_OP_bregx, accepts 2 operands. ULEB128 register followed by SLEB128 offset */
    DW_OP_bregx = 0x92,
    
    /** DW_OP_piece, accepts 1 operand. ULEB128 size of piece addressed */
    DW_OP_piece = 0x93,
    
    /** DW_OP_deref_size, accepts 1 operand. 1-byte size of data retrieved */
    DW_OP_deref_size = 0x94,
    
    /** DW_OP_xderef_size, accepts 1 operand. 1-byte size of data retrieved */
    DW_OP_xderef_size = 0x95,
    
    /** DW_OP_nop, accepts no operands. */
    DW_OP_nop = 0x96,
    
    /** DW_OP_push_object_address, accepts no operands. */
    DW_OP_push_object_address = 0x97,
    
    /** DW_OP_call2, accepts 1 operand. 2-byte offset of DIE */
    DW_OP_call2 = 0x98,
    
    /** DW_OP_call4, accepts 1 operand. 4-byte offset of DIE */
    DW_OP_call4 = 0x99,
    
    /** DW_OP_call_ref, accepts 1 operand. 4- or 8-byte offset of DIE */
    DW_OP_call_ref = 0x9a,
    
    /** DW_OP_form_tls_address, accepts no operands. */
    DW_OP_form_tls_address = 0x9b,
    
    /** DW_OP_call_frame_cfa, accepts no operands. */
    DW_OP_call_frame_cfa = 0x9c,
    
    /** DW_OP_bit_piece, accepts 2 operands. */
    DW_OP_bit_piece = 0x9d,
    
    /** DW_OP_lo_user, accepts no operands. */
    DW_OP_lo_user = 0xe0,
    
    /** DW_OP_hi_user, accepts no operands. */
    DW_OP_hi_user = 0xff,
} DW_OP_t;

template <typename machine_ptr, typename machine_ptr_s>
plcrash_error_t plcrash_async_dwarf_expression_eval (plcrash_async_mobject_t *mobj,
                                                     task_t task,
                                                     const plcrash_async_thread_state_t *thread_state,
                                                     const plcrash_async_byteorder_t *byteorder,
                                                     pl_vm_address_t address,
                                                     pl_vm_off_t offset,
                                                     pl_vm_size_t length,
                                                     machine_ptr initial_state[],
                                                     size_t initial_count,
                                                     machine_ptr *result);

/*
 * @}
 */

}
PLCR_CPP_END_NS

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_CFA_H */
