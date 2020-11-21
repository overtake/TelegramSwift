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

#include "PLCrashAsyncDwarfExpression.hpp"
#include "PLCrashAsyncDwarfPrimitives.hpp"
#include "PLCrashAsyncDwarfCFAState.hpp"

#include "PLCrashFeatureConfig.h"

#include "dwarf_opstream.hpp"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_DWARF

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */

using namespace plcrash::async;

template <typename machine_ptr, typename machine_ptr_s>
static plcrash_error_t plcrash_async_dwarf_cfa_state_apply_register (task_t task,
                                                                     const plcrash_async_thread_state_t *thread_state,
                                                                     const plcrash_async_byteorder_t *byteorder,
                                                                     plcrash_async_thread_state_t *new_thread_state,
                                                                     machine_ptr cfa_val,
                                                                     plcrash_regnum_t pl_regnum,
                                                                     plcrash_dwarf_cfa_reg_rule_t dw_rule,
                                                                     machine_ptr dw_value);
/**
 * Evaluate a DWARF CFA program, as defined in the DWARF 4 Specification, Section 6.4.2, fetching
 * any state -- and applying  any state changes -- to the target instance.
 *
 * @param mobj The memory object from which the expression opcodes will be read.
 * @param pc The PC offset at which evaluation of the CFA program should terminate. If 0, 
 * the program will be executed to completion. This value should be the absolute address at which the code is loaded
 * into the target process, as the current implementation utilizes relative addressing to perform address
 * lookups.
 * @param initial_pc_value The initial PC value to be used as the CFA location -- this should
 * generally be the PC start value as provided by the encoded FDE. This value should be adjusted/slid
 * to match the load address of the binary containing @a pc.
 * @param cie_info The CIE data for this opcode stream.
 * @param ptr_reader GNU EH pointer reader; this also provides the base addresses and other
 * information required to decode pointers in the CFA opcode stream. May be NULL if eh_frame
 * augmentation data is not available in @a cie_info.
 * @param byteorder The byte order of the data referenced by @a mobj.
 * @param address The task-relative address within @a mobj at which the opcodes will be fetched.
 * @param offset An offset to be applied to @a address.
 * @param length The total length of the opcodes readable at @a address + @a offset.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or an appropriate plcrash_error_t values
 * on failure. If an invalid opcode is detected, PLCRASH_ENOTSUP will be returned.
 *
 * @todo Consider defining updated status codes or error handling to provide more structured
 * error data on failure.
 */
template <typename machine_ptr, typename machine_ptr_s>
plcrash_error_t dwarf_cfa_state<machine_ptr, machine_ptr_s>::eval_program (plcrash_async_mobject_t *mobj,
                                                                           machine_ptr pc,
                                                                           machine_ptr initial_pc_value,
                                                                           plcrash_async_dwarf_cie_info_t *cie_info,
                                                                           gnu_ehptr_reader<machine_ptr> *ptr_reader,
                                                                           const plcrash_async_byteorder_t *byteorder,
                                                                           pl_vm_address_t address,
                                                                           pl_vm_off_t offset,
                                                                           pl_vm_size_t length)
{
    plcrash::async::dwarf_opstream opstream;
    plcrash_error_t err;
    machine_ptr location = initial_pc_value;

    /* Save the initial state; this is needed for DW_CFA_restore, et al. */
    // TODO - It would be preferrable to only allocate the number of registers actually required here.
    dwarf_cfa_state<machine_ptr, machine_ptr_s> initial_state;
    {
        dwarf_cfa_state_regnum_t regnum;
        plcrash_dwarf_cfa_reg_rule_t rule;
        machine_ptr value;

        dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s> iter = dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s>(this);
        while (iter.next(&regnum, &rule, &value)) {
            if (!initial_state.set_register(regnum, rule, value)) {
                PLCF_DEBUG("Hit register allocation limit while saving initial state");
                return PLCRASH_ENOMEM;
            }
        }
    }

    /* Default to reading as a standard machine word */
    DW_EH_PE_t gnu_eh_ptr_encoding = DW_EH_PE_absptr;
    if (cie_info->has_eh_augmentation && cie_info->eh_augmentation.has_pointer_encoding && ptr_reader != NULL) {
        gnu_eh_ptr_encoding = (DW_EH_PE_t) cie_info->eh_augmentation.pointer_encoding;
    }
    
    /* Calculate the absolute (target-relative) address of the start of the stream */
    pl_vm_address_t opstream_target_address;
    if (!plcrash_async_address_apply_offset(address, offset, &opstream_target_address)) {
        PLCF_DEBUG("Offset overflows base address");
        return PLCRASH_EINVAL;
    }

    /* Configure the opstream */
    if ((err = opstream.init(mobj, byteorder, address, offset, length)) != PLCRASH_ESUCCESS)
        return err;
    
#define dw_expr_read_int(_type) ({ \
    _type v; \
    if (!opstream.read_intU<_type>(&v)) { \
        PLCF_DEBUG("Read of size %zu exceeds mapped range", sizeof(v)); \
        return PLCRASH_EINVAL; \
    } \
    v; \
})
    
    /* A position-advancing DWARF uleb128 register read macro that uses GCC/clang's compound statement value extension, returning an error
     * if the read fails, or the register value exceeds DWARF_CFA_STATE_REGNUM_MAX */
#define dw_expr_read_uleb128_regnum() ({ \
    uint64_t v; \
    if (!opstream.read_uleb128(&v)) { \
        PLCF_DEBUG("Read of ULEB128 value failed"); \
        return PLCRASH_EINVAL; \
    } \
    if (v > DWARF_CFA_STATE_REGNUM_MAX) { \
        PLCF_DEBUG("Register number %" PRIu64 " exceeds DWARF_CFA_STATE_REGNUM_MAX", v); \
        return PLCRASH_ENOTSUP; \
    } \
    (uint32_t) v; \
})
    
    /* A position-advancing uleb128 read macro that uses GCC/clang's compound statement value extension, returning an error
     * if the read fails. */
#define dw_expr_read_uleb128() ({ \
    uint64_t v; \
    if (!opstream.read_uleb128(&v)) { \
        PLCF_DEBUG("Read of ULEB128 value failed"); \
        return PLCRASH_EINVAL; \
    } \
    v; \
})

    /* A position-advancing sleb128 read macro that uses GCC/clang's compound statement value extension, returning an error
     * if the read fails. */
#define dw_expr_read_sleb128() ({ \
    int64_t v; \
    if (!opstream.read_sleb128(&v)) { \
        PLCF_DEBUG("Read of SLEB128 value failed"); \
        return PLCRASH_EINVAL; \
    } \
    v; \
})
    
    /* Handle error checking when setting a register on the CFA state */
#define dw_expr_set_register(_regnum, _rule, _value) do { \
    if (!set_register(_regnum, _rule, _value)) { \
        PLCF_DEBUG("Exhausted available register slots while evaluating CFA opcodes"); \
        return PLCRASH_ENOMEM; \
    } \
} while (0)

    /* Iterate the opcode stream until the pc_offset is hit */
    uint8_t opcode;
    while ((pc == 0 || location <= pc) && opstream.read_intU(&opcode)) {
        uint8_t const_operand = 0;

        /* Check for opcodes encoded in the top two bits, with an operand
         * in the bottom 6 bits. */
        
        if ((opcode & 0xC0) != 0) {
            const_operand = opcode & 0x3F;
            opcode &= 0xC0;
        }
        
        switch (opcode) {
            case DW_CFA_set_loc:
                if (cie_info->segment_size != 0) {
                    PLCF_DEBUG("Segment support has not been implemented");
                    return PLCRASH_ENOTSUP;
                }

                /* Try reading an eh_frame encoded pointer */
                if (!opstream.read_gnueh_ptr(ptr_reader, gnu_eh_ptr_encoding, &location)) {
                    PLCF_DEBUG("DW_CFA_set_loc failed to read the target pointer value");
                    return PLCRASH_EINVAL;
                }
                break;
                
            case DW_CFA_advance_loc:
                location += const_operand * cie_info->code_alignment_factor;
                break;
                
            case DW_CFA_advance_loc1:
                location += dw_expr_read_int(uint8_t) * cie_info->code_alignment_factor;
                break;
                
            case DW_CFA_advance_loc2:
                location += dw_expr_read_int(uint16_t) * cie_info->code_alignment_factor;
                break;
                
            case DW_CFA_advance_loc4:
                location += dw_expr_read_int(uint32_t) * cie_info->code_alignment_factor;
                break;
                
            case DW_CFA_def_cfa:
                set_cfa_register(dw_expr_read_uleb128_regnum(), (machine_ptr)dw_expr_read_uleb128());
                break;
                
            case DW_CFA_def_cfa_sf:
                set_cfa_register_signed(dw_expr_read_uleb128_regnum(), (machine_ptr_s)(dw_expr_read_sleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_def_cfa_register: {
                dwarf_cfa_rule<machine_ptr, machine_ptr_s> rule = get_cfa_rule();
                
                switch (rule.type()) {
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER:
                        set_cfa_register(dw_expr_read_uleb128_regnum(), rule.register_offset());
                        break;
                        
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED:
                        set_cfa_register_signed(dw_expr_read_uleb128_regnum(), rule.register_offset_signed());
                        break;
                        
                    case DWARF_CFA_STATE_CFA_TYPE_EXPRESSION:
                    case DWARF_CFA_STATE_CFA_TYPE_UNDEFINED:
                        PLCF_DEBUG("DW_CFA_def_cfa_register emitted for a non-register CFA rule state");
                        return PLCRASH_EINVAL;
                }
                break;
            }
                
            case DW_CFA_def_cfa_offset: {
                dwarf_cfa_rule<machine_ptr, machine_ptr_s> rule = get_cfa_rule();
                switch (rule.type()) {
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER:
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED:
                        /* Our new offset is unsigned, so all register rules are converted to unsigned here */
                        set_cfa_register(rule.register_number(), (machine_ptr)dw_expr_read_uleb128());
                        break;
                        
                    case DWARF_CFA_STATE_CFA_TYPE_EXPRESSION:
                    case DWARF_CFA_STATE_CFA_TYPE_UNDEFINED:
                        PLCF_DEBUG("DW_CFA_def_cfa_register emitted for a non-register CFA rule state");
                        return PLCRASH_EINVAL;
                }
                break;
            }
                
                
            case DW_CFA_def_cfa_offset_sf: {
                dwarf_cfa_rule<machine_ptr, machine_ptr_s> rule = get_cfa_rule();
                switch (rule.type()) {
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER:
                    case DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED:
                        /* Our new offset is signed, so all register rules are converted to signed here */
                        set_cfa_register_signed(rule.register_number(), (machine_ptr_s)(dw_expr_read_sleb128() * cie_info->data_alignment_factor));
                        break;

                    case DWARF_CFA_STATE_CFA_TYPE_EXPRESSION:
                    case DWARF_CFA_STATE_CFA_TYPE_UNDEFINED:
                        PLCF_DEBUG("DW_CFA_def_cfa_register emitted for a non-register CFA rule state");
                        return PLCRASH_EINVAL;
                }
                break;
            }

            case DW_CFA_def_cfa_expression: {                
                /* Fetch the DW_FORM_block length header; we need this to skip the over the DWARF expression. */
                uint64_t blockLength = dw_expr_read_uleb128();
                
                /* Fetch the opstream position of the DWARF expression */
                uintptr_t pos = opstream.get_position();

                /* The returned sizes should always fit within the VM types in valid DWARF data; if they don't, how
                 * are we debugging the target? */
                if (blockLength > PL_VM_SIZE_MAX || blockLength > PL_VM_OFF_MAX) {
                    PLCF_DEBUG("DWARF expression length exceeds PL_VM_SIZE_MAX/PL_VM_OFF_MAX in DW_CFA_def_cfa_expression operand");
                    return PLCRASH_ENOTSUP;
                }
                
                // This issue triggers clang's new 'tautological' warnings on some host platforms with some types of pl_vm_off_t/pl_vm_address_t.
                // Testing tautological correctness and *documenting* the issue is the whole point of the check, even though it
                // may always be true on some hosts.
                // Since older versions of clang do not support -Wtautological, we have to enable -Wunknown-pragmas first
                PLCR_PRAGMA_CLANG("clang diagnostic push");
                PLCR_PRAGMA_CLANG("clang diagnostic ignored \"-Wunknown-pragmas\"");
                PLCR_PRAGMA_CLANG("clang diagnostic ignored \"-Wtautological-constant-out-of-range-compare\"");
                if (pos > PL_VM_ADDRESS_MAX || pos > PL_VM_OFF_MAX) {
                    PLCF_DEBUG("DWARF expression position exceeds PL_VM_ADDRESS_MAX/PL_VM_OFF_MAX in CFA opcode stream");
                    return PLCRASH_ENOTSUP;
                }
                PLCR_PRAGMA_CLANG("clang diagnostic pop");
                
                /* Calculate the absolute address of the expression opcodes. */
                pl_vm_address_t abs_addr;
                if (!plcrash_async_address_apply_offset(opstream_target_address, pos, &abs_addr)) {
                    PLCF_DEBUG("Offset overflows base address");
                    return PLCRASH_EINVAL;
                }

                /* Save the position */
                set_cfa_expression(abs_addr, (pl_vm_size_t) blockLength);
                
                /* Skip the expression opcodes */
                opstream.skip((pl_vm_off_t) blockLength);
                break;
            }
                
            case DW_CFA_undefined:
                remove_register(dw_expr_read_uleb128_regnum());
                break;
                
            case DW_CFA_same_value:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_SAME_VALUE, 0);
                break;
                
            case DW_CFA_offset:
                dw_expr_set_register(const_operand, PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (machine_ptr)(dw_expr_read_uleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_offset_extended:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (machine_ptr)(dw_expr_read_uleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_offset_extended_sf:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_OFFSET, (machine_ptr)(dw_expr_read_sleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_val_offset:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET, (machine_ptr)(dw_expr_read_uleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_val_offset_sf:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET, (machine_ptr)(dw_expr_read_sleb128() * cie_info->data_alignment_factor));
                break;
                
            case DW_CFA_register:
                dw_expr_set_register(dw_expr_read_uleb128_regnum(), PLCRASH_DWARF_CFA_REG_RULE_REGISTER, (machine_ptr)dw_expr_read_uleb128());
                break;
            
            case DW_CFA_expression:
            case DW_CFA_val_expression: {
                dwarf_cfa_state_regnum_t regnum = dw_expr_read_uleb128_regnum();
                uintptr_t pos = opstream.get_position();
                
                /* Fetch the DW_FORM_BLOCK length header; we need this to skip the over the DWARF expression. */
                uint64_t blockLength = dw_expr_read_uleb128();

                /* Calculate the absolute address of the expression opcodes (including verifying that pos won't overflow when applying the offset). */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wtautological-constant-out-of-range-compare"
                if (pos > PL_VM_ADDRESS_MAX || pos > PL_VM_OFF_MAX) {
                    PLCF_DEBUG("DWARF expression position exceeds PL_VM_ADDRESS_MAX/PL_VM_OFF_MAX in DW_CFA_expression evaluation");
                    return PLCRASH_ENOTSUP;
                }
#pragma clang diagnostic pop
                
                pl_vm_address_t abs_addr;
                if (!plcrash_async_address_apply_offset(opstream_target_address, pos, &abs_addr)) {
                    PLCF_DEBUG("Offset overflows base address");
                    return PLCRASH_EINVAL;
                }
                
                /* Save the position */
                if (opcode == DW_CFA_expression) {
                    dw_expr_set_register(regnum, PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION, (machine_ptr)abs_addr);
                } else {
                    PLCF_ASSERT(opcode == DW_CFA_val_expression); // If not _expression, must be _val_expression.
                    dw_expr_set_register(regnum, PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION, (machine_ptr)abs_addr);
                }

                /* Skip the expression opcodes */
                opstream.skip((pl_vm_off_t) blockLength);
                break;
            }
                
            case DW_CFA_restore: {
                plcrash_dwarf_cfa_reg_rule_t rule;
                machine_ptr value;
                
                /* Either restore the value specified in the initial state, or remove the register
                 * if the initial state has no associated value */
                if (initial_state.get_register_rule(const_operand, &rule, &value)) {
                    dw_expr_set_register(const_operand, rule, value);
                } else {
                    remove_register(const_operand);
                }
        
                break;
            }
                
            case DW_CFA_restore_extended: {
                dwarf_cfa_state_regnum_t regnum = dw_expr_read_uleb128_regnum();
                plcrash_dwarf_cfa_reg_rule_t rule;
                machine_ptr value;
                
                /* Either restore the value specified in the initial state, or remove the register
                 * if the initial state has no associated value */
                if (initial_state.get_register_rule(regnum, &rule, &value)) {
                    dw_expr_set_register(regnum, rule, value);
                } else {
                    remove_register(const_operand);
                }
                
                break;
            }
                
            case DW_CFA_remember_state:
                if (!push_state()) {
                    PLCF_DEBUG("DW_CFA_remember_state exeeded the allocated CFA stack size");
                    return PLCRASH_ENOMEM;
                }
                break;
                
            case DW_CFA_restore_state:
                if (!pop_state()) {
                    PLCF_DEBUG("DW_CFA_restore_state was issued on an empty CFA stack");
                    return PLCRASH_EINVAL;
                }
                break;

            case DW_CFA_nop:
                break;
                
            default:
                PLCF_DEBUG("Unsupported opcode 0x%" PRIx8, opcode);
                return PLCRASH_ENOTSUP;
        }
    }

    return PLCRASH_ESUCCESS;
}

/**
 * Apply the CFA state to @a thread_state, fetching data from @a task, and
 * populate @a new_thread_state with the result.
 *
 * @param task The task containing any data referenced by @a thread_state.
 * @param cie_info The CIE from which @a cfa_state was derived.
 * @param thread_state The current thread state corresponding to @a entry.
 * @param byteorder The target's byte order.
 * @param new_thread_state The new thread state to be initialized.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or a standard pclrash_error_t code if an error occurs.
 */
template <typename machine_ptr, typename machine_ptr_s>
plcrash_error_t dwarf_cfa_state<machine_ptr, machine_ptr_s>::apply_state (task_t task,
                                                                          plcrash_async_dwarf_cie_info_t *cie_info,
                                                                          const plcrash_async_thread_state_t *thread_state,
                                                                          const plcrash_async_byteorder_t *byteorder,
                                                                          plcrash_async_thread_state_t *new_thread_state)
{
    plcrash_error_t err;

    /* Initialize the new thread state */
    plcrash_async_thread_state_copy(new_thread_state, thread_state);
    plcrash_async_thread_state_clear_volatile_regs(new_thread_state);

    /*
     * Restore the canonical frame address
     */
    dwarf_cfa_rule<machine_ptr, machine_ptr_s> cfa_rule = get_cfa_rule();
    machine_ptr cfa_val;

    switch (cfa_rule.type()) {
        case DWARF_CFA_STATE_CFA_TYPE_UNDEFINED:
            /** Missing canonical frame address! */
            PLCF_DEBUG("No canonical frame address specified in the CFA state; can't apply state");
            return PLCRASH_EINVAL;

        case DWARF_CFA_STATE_CFA_TYPE_REGISTER:
        case DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED: {
            plcrash_regnum_t regnum;
            
            /* Map to a plcrash register number */
            if (!plcrash_async_thread_state_map_dwarf_to_reg(thread_state, cfa_rule.register_number(), &regnum)) {
                PLCF_DEBUG("CFA rule references an unsupported DWARF register: 0x%" PRIx32, cfa_rule.register_number());
                return PLCRASH_ENOTSUP;
            }
            
            /* Verify that the requested register is available */
            if (!plcrash_async_thread_state_has_reg(thread_state, regnum)) {
                PLCF_DEBUG("CFA rule references a register that is not available from the current thread state: %s", plcrash_async_thread_state_get_reg_name(thread_state, regnum));
                return PLCRASH_ENOTFOUND;
            }

            /* Fetch the current value, apply the offset, and save as the new thread's CFA. */
            cfa_val = (machine_ptr) plcrash_async_thread_state_get_reg(thread_state, regnum);
            if (cfa_rule.type() == DWARF_CFA_STATE_CFA_TYPE_REGISTER)
                cfa_val += cfa_rule.register_offset();
            else
                cfa_val += cfa_rule.register_offset_signed();
            break;
        }

        case DWARF_CFA_STATE_CFA_TYPE_EXPRESSION: {
            plcrash_async_mobject_t mobj;
            if ((err = plcrash_async_mobject_init(&mobj, task, cfa_rule.expression_address(), cfa_rule.expression_length(), true)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Could not map CFA expression range");
                return err;
            }
            
            if ((err = plcrash_async_dwarf_expression_eval<machine_ptr, machine_ptr_s>(&mobj, task, thread_state, byteorder, cfa_rule.expression_address(), 0x0, cfa_rule.expression_length(), NULL, 0, &cfa_val)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("CFA eval_64 failed");
                return err;
            }
            
            break;
        }
    }
    
    /* Apply the CFA to the new state */
    plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_SP, cfa_val);
    
    /*
     * Restore register values
     */
    dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s> iter = dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s>(this);
    dwarf_cfa_state_regnum_t dw_regnum;
    plcrash_dwarf_cfa_reg_rule_t dw_rule;
    machine_ptr dw_value;
    
    while (iter.next(&dw_regnum, &dw_rule, &dw_value)) {
        /* Map the register number */
        plcrash_regnum_t pl_regnum;
        if (!plcrash_async_thread_state_map_dwarf_to_reg(thread_state, dw_regnum, &pl_regnum)) {
            /* Some DWARF ABIs (such as x86-64) define the return address using a pseudo-register. In that case, the
             * register will not have a vaid DWARF -> PLCrashReporter mapping; we simply target the IP in this case,
             * which results in the expected behavior of setting the IP in the new thread state. */
            if (cie_info->return_address_register == dw_regnum) {
                pl_regnum = PLCRASH_REG_IP;
            } else {
                PLCF_DEBUG("Register rule references an unsupported DWARF register: 0x%" PRIx64, (uint64_t) dw_regnum);
                return PLCRASH_EINVAL;
            }
        }
        
        /* Apply the register rule */
        if ((err = plcrash_async_dwarf_cfa_state_apply_register<machine_ptr, machine_ptr_s>(task, thread_state, byteorder, new_thread_state, cfa_val, pl_regnum, dw_rule, dw_value)) != PLCRASH_ESUCCESS)
            return err;
        
        /* If the target register is defined as the return address (and is not already the IP), copy the value to the IP.  */
        if (cie_info->return_address_register == dw_regnum && pl_regnum != PLCRASH_REG_IP) {
            PLCF_ASSERT(plcrash_async_thread_state_has_reg(new_thread_state, pl_regnum));
            plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, plcrash_async_thread_state_get_reg(new_thread_state, pl_regnum));
        }
    }

    /*
     * If the IP was not restored via a saved register above, the CIE's return_address_register may reference a live register in the
     * current thread state. This will occur in leaf frames on platforms where lr has not been saved to the stack.
     */
    if (!plcrash_async_thread_state_has_reg(new_thread_state, PLCRASH_REG_IP)) {
        /* Map the return_address_register number */
        plcrash_regnum_t pl_regnum;
        if (!plcrash_async_thread_state_map_dwarf_to_reg(thread_state, cie_info->return_address_register, &pl_regnum)) {
            PLCF_DEBUG("Return address register value references an unsupported DWARF register: 0x%" PRIx64, (uint64_t) cie_info->return_address_register);
            return PLCRASH_EINVAL;
        }
        
        /* Verify that the register is available */
        if (!plcrash_async_thread_state_has_reg(thread_state, pl_regnum)) {
            PLCF_DEBUG("CIE return_address_register references a register that is not available from the current thread state: %s", plcrash_async_thread_state_get_reg_name(thread_state, pl_regnum));
            return PLCRASH_EINVAL;
        }

        /* Copy the value to the new state's IP. */
        plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, plcrash_async_thread_state_get_reg(thread_state, pl_regnum));
    }

    return PLCRASH_ESUCCESS;
}

/**
 * Apply a single register rule to @a new_thread_state.
 *
 * @param task The task containing any data referenced by @a thread_state.
 * @param thread_state The current thread state corresponding to @a entry.
 * @param byteorder The target's byte order.
 * @param new_thread_state The new thread state to be initialized.
 * @param cfa_val The base canonical frame address to be used when applying @a dw_rule
 * @param pl_regnum The register to which @a dw_rule and @a dw_value will be applied.
 * @param dw_rule The DWARF register rule to be used to derive the value for @a pl_regnum.
 * @param dw_value The DWARF value to be used with @a dw_rule
 *
 * @return Returns PLCRASH_ESUCCESS on success, or a standard pclrash_error_t code if an error occurs.
 */
template <typename machine_ptr, typename machine_ptr_s>
static plcrash_error_t plcrash_async_dwarf_cfa_state_apply_register (task_t task,
                                                                     const plcrash_async_thread_state_t *thread_state,
                                                                     const plcrash_async_byteorder_t *byteorder,
                                                                     plcrash_async_thread_state_t *new_thread_state,
                                                                     machine_ptr cfa_val,
                                                                     plcrash_regnum_t pl_regnum,
                                                                     plcrash_dwarf_cfa_reg_rule_t dw_rule,
                                                                     machine_ptr dw_value)
{
    plcrash_error_t err;
    uint8_t greg_size = plcrash_async_thread_state_get_greg_size(thread_state);
    bool m64 = (greg_size == 8);
    
    union {
        uint32_t v32;
        uint64_t v64;
    } rvalue;
    void *vptr = &rvalue;
    
    /* Apply the rule */
    switch (dw_rule) {
        case PLCRASH_DWARF_CFA_REG_RULE_OFFSET: {
            if ((err = plcrash_async_task_memcpy(task, (pl_vm_address_t) cfa_val, (pl_vm_off_t) dw_value, vptr, greg_size)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read offset(N) register value: %d", err);
                return err;
            }
            
            if (m64) {
                plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, rvalue.v64);
            } else {
                plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, rvalue.v32);
            }
            
            break;
        }
            
        case PLCRASH_DWARF_CFA_REG_RULE_VAL_OFFSET:
            plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, cfa_val + ((machine_ptr_s) dw_value));
            break;
            
        case PLCRASH_DWARF_CFA_REG_RULE_REGISTER: {
            /* The previous value of this register is stored in another register numbered R. */
            plcrash_regnum_t src_pl_regnum;
            if (!plcrash_async_thread_state_map_dwarf_to_reg(thread_state, dw_value, &src_pl_regnum)) {
                PLCF_DEBUG("Register rule references an unsupported DWARF register: 0x%" PRIx64, (uint64_t) dw_value);
                return PLCRASH_EINVAL;
            }
            
            if (!plcrash_async_thread_state_has_reg(thread_state, src_pl_regnum)) {
                PLCF_DEBUG("Register rule references a register that is not available from the current thread state: %s", plcrash_async_thread_state_get_reg_name(thread_state, src_pl_regnum));
                return PLCRASH_ENOTFOUND;
            }
            
            plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, plcrash_async_thread_state_get_reg(thread_state, src_pl_regnum));
            break;
        }
            
        case PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION:
        case PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION: {
            pl_vm_address_t expr_addr = (pl_vm_address_t) dw_value;
            /* Fetch the expression's length */
            uint64_t expr_len;
            pl_vm_size_t uleb128_len;
            if ((err = plcrash_async_dwarf_read_task_uleb128(task, expr_addr, 0, &expr_len, &uleb128_len)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read uleb128 length header for rule expression");
                return err;
            }
            
            /* Skip the ULEB128 length header; expr_addr will not point at the expression opcodes. */
            if (!plcrash_async_address_apply_offset(expr_addr, uleb128_len, &expr_addr)) {
                PLCF_DEBUG("Overflow applying the ULEB128 length to our expression base address");
                return PLCRASH_EINVAL;
            }
            
            /* Map the expression data  */
            plcrash_async_mobject_t mobj;
            if ((err = plcrash_async_mobject_init(&mobj, task, expr_addr, (pl_vm_size_t) expr_len, true)) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Could not map CFA expression range");
                return err;
            }
            
            /* Perform the evaluation */
            plcrash_greg_t regval;
            if (m64) {
                uint64_t initial_state[] = { cfa_val };
                if ((err = plcrash_async_dwarf_expression_eval<uint64_t, int64_t>(&mobj, task, thread_state, byteorder, expr_addr, 0, (pl_vm_size_t) expr_len, initial_state, 1, &rvalue.v64)) != PLCRASH_ESUCCESS) {
                    plcrash_async_mobject_free(&mobj);
                    PLCF_DEBUG("CFA eval_64 failed");
                    return err;
                }
                
                regval = rvalue.v64;
            } else {
                uint32_t initial_state[] = { static_cast<uint32_t>(cfa_val) };
                if ((err = plcrash_async_dwarf_expression_eval<uint32_t, int32_t>(&mobj, task, thread_state, byteorder, expr_addr, 0, (pl_vm_size_t) expr_len, initial_state, 1, &rvalue.v32)) != PLCRASH_ESUCCESS) {
                    plcrash_async_mobject_free(&mobj);
                    PLCF_DEBUG("CFA eval_32 failed");
                    return err;
                }
                
                regval = rvalue.v32;
            }
            
            /* Clean up the memory mapping */
            plcrash_async_mobject_free(&mobj);
            
            /* Dereference the target address, if using the non-value EXPRESSION rule */
            if (dw_rule == PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION) {
                if ((err = plcrash_async_task_memcpy(task, (pl_vm_address_t) regval, 0, vptr, greg_size)) != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("Failed to read register value from expression result: %d", err);
                    return err;
                }
                
                if (m64) {
                    regval = rvalue.v64;
                } else {
                    regval = rvalue.v32;
                }
            }
            
            plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, regval);
            break;
        }
            
        case PLCRASH_DWARF_CFA_REG_RULE_SAME_VALUE:
            /* This register has not been modified from the previous frame. (By convention, it is preserved by the callee, but
             * the callee has not modified it.)
             *
             * The register's value may be found in the frame's thread state. For frames other than the first, the
             * register may not have been restored, and thus may be unavailable. */
            if (!plcrash_async_thread_state_has_reg(thread_state, pl_regnum)) {
                PLCF_DEBUG("Same-value rule references a register that is not available from the current thread state");
                return PLCRASH_ENOTFOUND;
            }
            
            /* Copy the register value from the previous state */
            plcrash_async_thread_state_set_reg(new_thread_state, pl_regnum, plcrash_async_thread_state_get_reg(thread_state, pl_regnum));
            break;
    }
    
    return PLCRASH_ESUCCESS;
}

/* Provide explicit 32/64-bit instantiations */
template class plcrash::async::dwarf_cfa_state<uint32_t, int32_t>;
template class plcrash::async::dwarf_cfa_state<uint64_t, int64_t>;

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
