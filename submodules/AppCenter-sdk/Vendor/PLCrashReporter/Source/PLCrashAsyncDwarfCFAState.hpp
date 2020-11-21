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

#ifndef PLCRASH_ASYNC_DWARF_CFA_STATE_H
#define PLCRASH_ASYNC_DWARF_CFA_STATE_H 1

#include <cstddef>
#include <stdint.h>

#include "PLCrashAsync.h"
#include "PLCrashAsyncDwarfFDE.hpp"
#include "PLCrashAsyncDwarfCIE.hpp"
#include "PLCrashAsyncDwarfPrimitives.hpp"

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

/**
 * @internal
 * @ingroup plcrash_async_dwarf_cfa_state
 * @{
 */

PLCR_CPP_BEGIN_NS
namespace async {

/* Maximum DWARF register number supported by dwarf_cfa_state and dwarf_cfa_state_regnum_t. */
#define DWARF_CFA_STATE_REGNUM_MAX UINT32_MAX

/* Consumes around 1.65k (on 32-bit and 64-bit systems). */
#define DWARF_CFA_STATE_MAX_REGISTERS 100

template <typename machine_ptr, typename machine_ptr_s> class dwarf_cfa_state_iterator;

/** DWARF CFA-defined register number .*/
typedef uint32_t dwarf_cfa_state_regnum_t;

/**
 * Canonical Frame Address type, as defined in the DWARF 4 specification,
 * section 6.4.2.2, CFA Definition Instructions.
 */
typedef enum {
    /** CFA is undefined. */
    DWARF_CFA_STATE_CFA_TYPE_UNDEFINED = 0,
    
    /** CFA is defined by a DWARF expression. */
    DWARF_CFA_STATE_CFA_TYPE_EXPRESSION = 1,
    
    /** CFA is defined by a register value + unsigned offset. */
    DWARF_CFA_STATE_CFA_TYPE_REGISTER = 2,
    
    /** CFA is defined by a register value + signed offset. */
    DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED = 3
} dwarf_cfa_state_cfa_type_t;

/**
 * @internal
 * A CFA value rule. The rule is interpreted to derive the Canonical Frame Address, as defined in
 * DWARF section 6.4.2.2.
 *
 * The canonical frame address is generally defined to be the value of the stack pointer at the
 * call site in the previous frame, which may in fact differ from its value on entry to the current
 * frame.
 *
 * The CFA rule may be used to derive the canonical frame address from the current frame's thread state,
 * by either:
 *      - Evaluating a DWARF expression to generate the frame address, or an indirect pointer to the
 *        frame address value.
 *      - Directly appying an offset to the value of the given register in the current thread state. This
 *        requires either treating the available offset as a signed or unsigned value, depending
 *        on the specific CFA type.
 *
 * The invariants for applying a DWARF CFA rule are defined in the @a dwarf_cfa_state_cfa_type_t documentation,
 * as well as the relevant DWARF specification sections listed above.
 */
template <typename machine_ptr, typename machine_ptr_s> class dwarf_cfa_rule {
private:
    /** The CFA type */
    dwarf_cfa_state_cfa_type_t _cfa_type;
    
    union {
        /**
         * CFA register value. (CFA = register + offset). Valid if type is DWARF_CFA_STATE_CFA_TYPE_REGISTER(_SIGNED).
         */
        struct {
            /** CFA register */
            dwarf_cfa_state_regnum_t regnum;
            
            /** CFA register offset. */
            union {
                /** The unsigned offset to be used with DWARF_CFA_STATE_CFA_TYPE_REGISTER rules. */
                machine_ptr u_off;
                
                /** The signed offset to be used with DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED rules. */
                machine_ptr_s s_off;
            } offset;
        } reg;
        
        /** CFA expression (CFA = expression). Valid if type is DWARF_CFA_STATE_CFA_TYPE_EXPRESSION. */
        struct {
            /**
             * Target-relative absolute address of the expression opcode stream.
             */
            pl_vm_address_t address;
            
            /**
             * Total length of the opcode stream, in bytes.
             */
            pl_vm_size_t length;
        } expression;
    } _cfa_data;

public:
    /**
     * Configure the target as a DWARF_CFA_STATE_CFA_TYPE_REGISTER register rule.
     *
     * @param regnum The DWARF register number.
     * @param offset The unsigned register offset.
     */
    void set_register_rule (dwarf_cfa_state_regnum_t regnum, machine_ptr offset) {
        _cfa_type = DWARF_CFA_STATE_CFA_TYPE_REGISTER;
        _cfa_data.reg.regnum = regnum;
        _cfa_data.reg.offset.u_off = offset;
    }
    
    /**
     * Configure the target as a DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED register rule.
     *
     * @param regnum The DWARF register number.
     * @param offset The signed register offset.
     */
    void set_register_rule_signed (dwarf_cfa_state_regnum_t regnum, machine_ptr offset) {
        _cfa_type = DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED;
        _cfa_data.reg.regnum = regnum;
        _cfa_data.reg.offset.s_off = offset;
    }
    
    /**
     * Configure the target as a DWARF_CFA_STATE_CFA_TYPE_EXPRESSION rule.
     *
     * @param address Target-relative absolute address of the expression opcode stream.
     * @param length Total length of the opcode stream, in bytes.
     */
    void set_expression_rule (pl_vm_address_t address, pl_vm_address_t length) {
        _cfa_type = DWARF_CFA_STATE_CFA_TYPE_EXPRESSION;
        _cfa_data.expression.address = address;
        _cfa_data.expression.length = length;
    }
    
    /**
     * Configure the target as a DWARF_CFA_STATE_CFA_TYPE_UNDEFINED rule.
     */
    void set_undefined_rule (void) {
        _cfa_type = DWARF_CFA_STATE_CFA_TYPE_UNDEFINED;
    }
    
    /**
     * Return the CFA rule type.
     */
    dwarf_cfa_state_cfa_type_t type (void) {
        return _cfa_type;
    }
    
    /**
     * Return the register number for this rule. This method is only applicable to and may only be called on
     * DWARF_CFA_STATE_CFA_TYPE_REGISTER and DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED rules.
     */
    dwarf_cfa_state_regnum_t register_number (void) {
        PLCF_ASSERT(_cfa_type == DWARF_CFA_STATE_CFA_TYPE_REGISTER || _cfa_type == DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED);
        return _cfa_data.reg.regnum;
    }
    
    /**
     * Return the unsigned register offset for this rule. This method is only applicable to and may only be called on
     * DWARF_CFA_STATE_CFA_TYPE_REGISTER rules.
     */
    machine_ptr register_offset (void) {
        PLCF_ASSERT(_cfa_type == DWARF_CFA_STATE_CFA_TYPE_REGISTER);
        return _cfa_data.reg.offset.u_off;
    }
    
    /**
     * Return the signed register offset for this rule. This method is only applicable to and may only be called on
     * DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED rules.
     */
    machine_ptr_s register_offset_signed (void) {
        PLCF_ASSERT(_cfa_type == DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED);
        return _cfa_data.reg.offset.s_off;
    }
    
    
    /**
     * Return the target-relative absolute address of the expression opcode stream for this rule. This method is only applicable to and may only be called on
     * DWARF_CFA_STATE_CFA_TYPE_EXPRESSION rules.
     */
    pl_vm_address_t expression_address (void) {
        PLCF_ASSERT(_cfa_type == DWARF_CFA_STATE_CFA_TYPE_EXPRESSION);
        return _cfa_data.expression.address;
    }
    
    /**
     * Rethrn the otal length of the opcode stream, in bytes, for this rule. This method is only applicable to and may only be called on
     * DWARF_CFA_STATE_CFA_TYPE_EXPRESSION rules.
     */
    pl_vm_size_t expression_length (void) {
        PLCF_ASSERT(_cfa_type == DWARF_CFA_STATE_CFA_TYPE_EXPRESSION);
        return _cfa_data.expression.length;
    }
};

/**
 * @internal
 *
 * Manages CFA register table row, using sparsely allocated register column entries. The class represents
 * a single address-based row within the CFA register table, and supports applying deltas to the row
 * register state as required for evaluation of a CFA opcode stream.
 *
 * Register numbers are sparsely allocated in the architecture-specific extensions to the DWARF spec,
 * requiring a solution other than allocating arrays large enough to hold the largest possible register number.
 * For example, ARM allocates or has set aside register values up to 8192, with 8192–16383 reserved for additional
 * vendor co-processor allocations.
 *
 * The actual total number of supported, active registers is much smaller. This class is built to decrease the
 * total amount of fixed stack space to be allocated.
 *
 * @todo If we introduce our own async-safe heap allocator, it may be preferrable to use the heap for entries.
 */
template <typename machine_ptr, typename machine_ptr_s>
class dwarf_cfa_state {
private:
    /* Private configuration defines */
#define DWARF_CFA_STATE_MAX_STATES 6
#define DWARF_CFA_STATE_BUCKET_COUNT 14
#define DWARF_CFA_STATE_INVALID_ENTRY_IDX UINT8_MAX

    /** A single register entry */
    typedef struct dwarf_cfa_reg_entry {
        /**
         * Associated rule value. Must be cast to a uint64_t value when evalating PLCRASH_DWARF_CFA_REG_RULE_EXPRESSION and
         * PLCRASH_DWARF_CFA_REG_RULE_VAL_EXPRESSION rules.
         */
        int64_t value;

        /** The DWARF register number */
        dwarf_cfa_state_regnum_t regnum;

        /** DWARF register rule */
        plcrash_dwarf_cfa_reg_rule_t rule;
        
        /** Next entry in the list, or NULL */
        uint8_t next;
    } dwarf_cfa_reg_entry_t;
    
    /** Current call frame value configuration. */
    dwarf_cfa_rule<machine_ptr,machine_ptr_s> _cfa_value[DWARF_CFA_STATE_MAX_STATES];
    
    /** Current number of defined register entries */
    uint8_t _register_count[DWARF_CFA_STATE_MAX_STATES];

    /**
     * Active entry lookup table. Maps from regnum to a table index. Most architectures
     * define <20 valid register numbers.
     *
     * This provides a maximum of MAX_STATES saved states (DW_CFA_remember_state), with BUCKET_COUNT register
     * buckets available in each stack entry. Each bucket may hold multiple register entries; the
     * maximum number of register entries depends on the configured size of _entries.
     *
     * The pre-allocated entry set is shared between each saved state, as to decrease total
     * memory cost of unused states.
     */
    uint8_t _table_stack[DWARF_CFA_STATE_MAX_STATES][DWARF_CFA_STATE_BUCKET_COUNT];

    /** Current position in the table stack */
    uint8_t _table_depth;

    /** Free list of entries. These are unused records from the entries table. */
    uint8_t _free_list;

    /**
     * Statically allocated set of entries; these will be inserted into the free
     * list upon construction, and then moved into the entry table as registers
     * are set.
     */
    dwarf_cfa_reg_entry_t _entries[DWARF_CFA_STATE_MAX_REGISTERS];

public:
    dwarf_cfa_state (void);
    
    plcrash_error_t eval_program (plcrash_async_mobject_t *mobj,
                                  machine_ptr pc,
                                  machine_ptr initial_pc_value,
                                  plcrash_async_dwarf_cie_info_t *cie_info,
                                  gnu_ehptr_reader<machine_ptr> *ptr_reader,
                                  const plcrash_async_byteorder_t *byteorder,
                                  pl_vm_address_t address,
                                  pl_vm_off_t offset,
                                  pl_vm_size_t length);
    
    plcrash_error_t apply_state (task_t task,
                                 plcrash_async_dwarf_cie_info_t *cie_info,
                                 const plcrash_async_thread_state_t *thread_state,
                                 const plcrash_async_byteorder_t *byteorder,
                                 plcrash_async_thread_state_t *new_thread_state);
    
    bool set_register (dwarf_cfa_state_regnum_t regnum, plcrash_dwarf_cfa_reg_rule_t rule, machine_ptr value);
    bool get_register_rule (dwarf_cfa_state_regnum_t regnum, plcrash_dwarf_cfa_reg_rule_t *rule, machine_ptr *value);

    void remove_register (dwarf_cfa_state_regnum_t regnum);
    uint8_t get_register_count (void);
    
    void set_cfa_register (dwarf_cfa_state_regnum_t regnum, machine_ptr offset);
    void set_cfa_register_signed (dwarf_cfa_state_regnum_t regnum, machine_ptr_s offset);
    void set_cfa_expression (pl_vm_address_t address, pl_vm_size_t length);
    dwarf_cfa_rule<machine_ptr,machine_ptr_s> get_cfa_rule (void);

    bool push_state (void);
    bool pop_state (void);
    
    friend class dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s>;
};

/**
 * @internal
 *
 * A dwarf_cfa_state iterator; iterates DWARF CFA register records. The target stack must
 * not be modified while iteration is performed.
 */
template <typename machine_ptr, typename machine_ptr_s>
class dwarf_cfa_state_iterator {
private:
    /** Current bucket index */
    uint8_t _bucket_idx;
    
    /** Current entry index, or DWARF_CFA_STATE_INVALID_ENTRY_IDX if iteration has not started */
    uint8_t _cur_entry_idx;
    
    /** Borrowed reference to the backing DWARF CFA state */
    dwarf_cfa_state<machine_ptr, machine_ptr_s> *_stack;
    
public:
    dwarf_cfa_state_iterator(dwarf_cfa_state<machine_ptr, machine_ptr_s> *stack);
    bool next (dwarf_cfa_state_regnum_t *regnum, plcrash_dwarf_cfa_reg_rule_t *rule, machine_ptr *value);
};

PLCR_CPP_END_NS
}

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_STACK_H */
