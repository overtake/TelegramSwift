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

#include "PLCrashAsyncDwarfCFAState.hpp"

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @defgroup plcrash_async_dwarf_cfa_state DWARF CFA Register State
 * @{
 */

/**
 * Push a state onto the state stack; all existing values will be saved on the stack, and registers
 * will be set to their default state.
 *
 * @return Returns true on success, or false if insufficient space is available on the state
 * stack.
 */
template <typename machine_ptr, typename machine_ptr_s>
bool dwarf_cfa_state<machine_ptr, machine_ptr_s>::push_state (void) {
    PLCF_ASSERT(_table_depth+1 <= DWARF_CFA_STATE_MAX_STATES);
    
    if (_table_depth+1 == DWARF_CFA_STATE_MAX_STATES)
        return false;
    
    _table_depth++;
    _register_count[_table_depth] = 0;
    _cfa_value[_table_depth].set_undefined_rule();

    plcrash_async_memset(_table_stack[_table_depth], DWARF_CFA_STATE_INVALID_ENTRY_IDX, sizeof(_table_stack[0]));
    
    return true;
}

/**
 * Pop a previously saved state from the state stack. All existing values will be discarded on the stack, and registers
 * will be reinitialized from the saved state.
 *
 * @return Returns true on success, or false if no states are available on the state stack.
 */
template <typename machine_ptr, typename machine_ptr_s>
bool dwarf_cfa_state<machine_ptr, machine_ptr_s>::pop_state (void) {
    if (_table_depth == 0)
        return false;
    
    _table_depth--;
    return true;
}

/*
 * Default constructor.
 */
template <typename machine_ptr, typename machine_ptr_s>
dwarf_cfa_state<machine_ptr, machine_ptr_s>::dwarf_cfa_state (void) {
    /* The size must be smaller than the invalid entry index, which is used as a NULL flag */
    PLCR_ASSERT_STATIC(max_size, DWARF_CFA_STATE_MAX_REGISTERS < DWARF_CFA_STATE_INVALID_ENTRY_IDX);
    
    /* Initialize the free list */
    for (uint8_t i = 0; i < DWARF_CFA_STATE_MAX_REGISTERS; i++)
        _entries[i].next = i+1;
    
    /* Set the terminator flag on the last entry */
    _entries[DWARF_CFA_STATE_MAX_REGISTERS-1].next = DWARF_CFA_STATE_INVALID_ENTRY_IDX;
    
    /* First free entry is _entries[0] */
    _free_list = 0;
    
    /* Initial register count */
    _register_count[0] = 0;
    
    /* Set up the table */
    _table_depth = 0;
    plcrash_async_memset(_table_stack[0], DWARF_CFA_STATE_INVALID_ENTRY_IDX, sizeof(_table_stack[0]));
    
    /* Default CFA */
    _cfa_value[0].set_undefined_rule();
}

/**
 * Add a new register.
 *
 * @param regnum The DWARF register number.
 * @param rule The DWARF CFA rule for @a regnum.
 * @param value The data value to be used when interpreting @a rule. May either be signed or unsigned.
 */
template <typename machine_ptr, typename machine_ptr_s>
bool dwarf_cfa_state<machine_ptr, machine_ptr_s>::set_register (dwarf_cfa_state_regnum_t regnum, plcrash_dwarf_cfa_reg_rule_t rule, machine_ptr value) {
    /* Check for an existing entry, or find the target entry off which we'll chain our entry */
    unsigned int bucket = regnum % (sizeof(_table_stack[0]) / sizeof(_table_stack[0][0]));
    
    dwarf_cfa_reg_entry_t *parent = NULL;
    for (uint8_t parent_idx = _table_stack[_table_depth][bucket]; parent_idx != DWARF_CFA_STATE_INVALID_ENTRY_IDX; parent_idx = parent->next) {
        parent = &_entries[parent_idx];
        
        /* If an existing entry is found, we can re-use it directly */
        if (parent->regnum == regnum) {
            parent->value = value;
            parent->rule = rule;
            return true;
        }
        
        /* Otherwise, make sure we terminate with parent == last element */
        if (parent->next == DWARF_CFA_STATE_INVALID_ENTRY_IDX)
            break;
    }
    
    /* 'parent' now either points to the end of the list, or is NULL (in which case the table
     * slot was empty */
    dwarf_cfa_reg_entry *entry = NULL;
    uint8_t entry_idx;
    
    /* Fetch a free entry */
    if (_free_list == DWARF_CFA_STATE_INVALID_ENTRY_IDX) {
        /* No free entries */
        return false;
    }
    entry_idx = _free_list;
    entry = &_entries[entry_idx];
    _free_list = entry->next;
    
    /* Intialize the entry */
    entry->regnum = regnum;
    entry->rule = rule;
    entry->value = value;
    entry->next = DWARF_CFA_STATE_INVALID_ENTRY_IDX;
    
    /* Either insert in the parent, or insert as the first table element */
    if (parent == NULL) {
        _table_stack[_table_depth][bucket] = entry_idx;
    } else {
        parent->next = entry - _entries;
    }
    
    _register_count[_table_depth]++;
    return true;
}

/**
 * Fetch the register entry data for a given DWARF register number, returning
 * true on success, or false if no entry has been added for the register.
 *
 * @param regnum The DWARF register number.
 * @param[out] rule On success, the DWARF CFA rule for @a regnum.
 * @param[out] value On success, the data value to be used when interpreting @a rule.
 */
template <typename machine_ptr, typename machine_ptr_s>
bool dwarf_cfa_state<machine_ptr, machine_ptr_s>::get_register_rule (dwarf_cfa_state_regnum_t regnum, plcrash_dwarf_cfa_reg_rule_t *rule, machine_ptr *value) {
    /* Search for the entry */
    unsigned int bucket = regnum % (sizeof(_table_stack[0]) / sizeof(_table_stack[0][0]));
    
    dwarf_cfa_reg_entry_t *entry = NULL;
    for (uint8_t entry_idx = _table_stack[_table_depth][bucket]; entry_idx != DWARF_CFA_STATE_INVALID_ENTRY_IDX; entry_idx = entry->next) {
        entry = &_entries[entry_idx];
        
        if (entry->regnum != regnum) {
            if (entry->next == DWARF_CFA_STATE_INVALID_ENTRY_IDX)
                break;
            
            continue;
        }
        
        /* Existing entry found, we can re-use it directly */
        *value = (machine_ptr)entry->value;
        *rule = (plcrash_dwarf_cfa_reg_rule_t) entry->rule;
        return true;
    }
    
    /* Not found? */
    return false;
}

/**
 * Remove a register from the current state.
 *
 * @param regnum The DWARF register number to be removed.
 */
template <typename machine_ptr, typename machine_ptr_s>
void dwarf_cfa_state<machine_ptr, machine_ptr_s>::remove_register (dwarf_cfa_state_regnum_t regnum) {
    /* Search for the entry */
    unsigned int bucket = regnum % (sizeof(_table_stack[0]) / sizeof(_table_stack[0][0]));
    
    dwarf_cfa_reg_entry *prev = NULL;
    dwarf_cfa_reg_entry_t *entry = NULL;
    for (uint8_t entry_idx = _table_stack[_table_depth][bucket]; entry_idx != DWARF_CFA_STATE_INVALID_ENTRY_IDX; entry_idx = entry->next) {
        prev = entry;
        entry = &_entries[entry_idx];
        
        if (entry->regnum != regnum)
            continue;
        
        /* Remove from the bucket chain */
        if (prev != NULL) {
            prev->next = entry->next;
        } else {
            _table_stack[_table_depth][bucket] = entry->next;
        }
        
        /* Re-insert in the free list */
        entry->next = _free_list;
        _free_list = entry_idx;
        
        /* Decrement the register count */
        _register_count[_table_depth]--;
    }
}

/**
 * Return the number of register rules set for the current register state.
 */
template <typename machine_ptr, typename machine_ptr_s>
uint8_t dwarf_cfa_state<machine_ptr, machine_ptr_s>::get_register_count (void) {
    return _register_count[_table_depth];
}


/**
 * Set a register-based DWARF_CFA_STATE_CFA_TYPE_REGISTER rule.
 *
 * @param regnum The base register for the canonical frame address.
 * @param offset The unsigned offset.
 */
template <typename machine_ptr, typename machine_ptr_s>
void dwarf_cfa_state<machine_ptr, machine_ptr_s>::set_cfa_register (dwarf_cfa_state_regnum_t regnum, machine_ptr offset) {
    _cfa_value[_table_depth].set_register_rule(regnum, offset);
}

/**
 * Set a register-based DWARF_CFA_STATE_CFA_TYPE_REGISTER_SIGNED rule.
 *
 * @param regnum The base register for the canonical frame address.
 * @param offset The unsigned offset.
 */
template <typename machine_ptr, typename machine_ptr_s>
void dwarf_cfa_state<machine_ptr, machine_ptr_s>::set_cfa_register_signed (dwarf_cfa_state_regnum_t regnum, machine_ptr_s offset) {
    _cfa_value[_table_depth].set_register_rule_signed(regnum, offset);
}

/**
 * Set an expression-based canonical frame address rule.
 *
 * @param address Target-relative address of the expression opcode stream.
 * @param length Length in bytes of the opcode stream.
 */
template <typename machine_ptr, typename machine_ptr_s>
void dwarf_cfa_state<machine_ptr, machine_ptr_s>::set_cfa_expression (pl_vm_address_t address, pl_vm_size_t length) {
    _cfa_value[_table_depth].set_expression_rule(address, length);
}

/**
 * Return the canonical frame address rule defined for the current state.
 */
template <typename machine_ptr, typename machine_ptr_s>
dwarf_cfa_rule<machine_ptr, machine_ptr_s> dwarf_cfa_state<machine_ptr, machine_ptr_s>::get_cfa_rule (void) {
    return _cfa_value[_table_depth];
}

/**
 * Construct an iterator for @a stack. The @a stack <em>must not</em> be mutated
 * during iteration.
 *
 * @param stack The stack to be iterated.
 */
template <typename machine_ptr, typename machine_ptr_s>
dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s>::dwarf_cfa_state_iterator(dwarf_cfa_state<machine_ptr, machine_ptr_s> *stack) {
    _stack = stack;
    _bucket_idx = 0;
    _cur_entry_idx = DWARF_CFA_STATE_INVALID_ENTRY_IDX;
}

/**
 * Enumerate the next register entry. Returns true on success, or false if no additional entries are available.
 *
 * @param[out] regnum On success, the DWARF register number.
 * @param[out] rule On success, the DWARF CFA rule for @a regnum.
 * @param[out] value On success, the data value to be used when interpreting @a rule.
 */
template <typename machine_ptr, typename machine_ptr_s>
bool dwarf_cfa_state_iterator<machine_ptr, machine_ptr_s>::next (dwarf_cfa_state_regnum_t *regnum, plcrash_dwarf_cfa_reg_rule_t *rule, machine_ptr *value) {
    /* Fetch the next entry in the bucket chain */
    if (_cur_entry_idx != DWARF_CFA_STATE_INVALID_ENTRY_IDX) {
        _cur_entry_idx = _stack->_entries[_cur_entry_idx].next;
        
        /* Advance to the next bucket if we've reached the end of the current chain */
        if (_cur_entry_idx == DWARF_CFA_STATE_INVALID_ENTRY_IDX)
            _bucket_idx++;
    }
    
    /*
     * On the first iteration, or after the end of a bucket chain has been reached, find the next valid bucket chain.
     * Otherwise, we have a valid bucket chain and simply need the next entry.
     */
    if (_cur_entry_idx == DWARF_CFA_STATE_INVALID_ENTRY_IDX) {
        for (; _bucket_idx < DWARF_CFA_STATE_BUCKET_COUNT; _bucket_idx++) {
            if (_stack->_table_stack[_stack->_table_depth][_bucket_idx] != DWARF_CFA_STATE_INVALID_ENTRY_IDX) {
                _cur_entry_idx = _stack->_table_stack[_stack->_table_depth][_bucket_idx];
                break;
            }
        }
        
        /* If we get here without a valid entry, we've hit the end of all bucket chains. */
        if (_cur_entry_idx == DWARF_CFA_STATE_INVALID_ENTRY_IDX)
            return false;
    }
    
    
    typename dwarf_cfa_state<machine_ptr, machine_ptr_s>::dwarf_cfa_reg_entry_t *entry = &_stack->_entries[_cur_entry_idx];
    *regnum = entry->regnum;
    *value = (machine_ptr)entry->value;
    *rule = (plcrash_dwarf_cfa_reg_rule_t) entry->rule;
    return true;
}

/* Provide explicit 32/64-bit instantiations */
template class plcrash::async::dwarf_cfa_state<uint32_t, int32_t>;
template class plcrash::async::dwarf_cfa_state_iterator<uint32_t, int32_t>;

template class plcrash::async::dwarf_cfa_state<uint64_t, int64_t>;
template class plcrash::async::dwarf_cfa_state_iterator<uint64_t, int64_t>;

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
