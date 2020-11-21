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

#include <inttypes.h>

#include "dwarf_stack.hpp"
#include "dwarf_opstream.hpp"

#include "PLCrashAsyncDwarfExpression.hpp"
#include "PLCrashAsyncDwarfPrimitives.hpp"

#include "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 * @ingroup plcrash_async_dwarf
 * @{
 */

/**
 * Evaluate a DWARF expression, as defined in the DWARF 4 Specification, Section 2.5. This
 * internal implementation is templated to support 32-bit and 64-bit evaluation.
 *
 * @param mobj The memory object from which the expression opcodes will be read.
 * @param task The task from which any DWARF expression memory loads will be performed.
 * @param thread_state The thread state against which the expression will be evaluated.
 * @param byteorder The byte order of the data referenced by @a mobj and @a thread_state.
 * @param address The task-relative address within @a mobj at which the opcodes will be fetched.
 * @param offset An offset to be applied to @a address.
 * @param length The total length of the opcodes readable at @a address + @a offset.
 * @param initial_state Initial set of values to be pushed onto the evaluation stack. The values will be pushed
 * on their natural order; eg, the top of the stack will be the last value in this array. If the initial stack
 * state should be empty, this value may be NULL, and @a initial_count should be 0.
 * @param initial_count Number of values in the @a initial_state array.
 * @param[out] result On success, the evaluation result. As per DWARF 3 section 2.5.1, this will be
 * the top-most element on the evaluation stack. If the stack is empty, an error will be returned
 * and no value will be written to this parameter.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or an appropriate plcrash_error_t values
 * on failure. If an invalid opcode is detected, PLCRASH_ENOTSUP will be returned. If the stack
 * is empty upon termination of evaluation, PLCRASH_EINVAL will be returned.
 *
 * @todo Consider defining updated status codes or error handling to provide more structured
 * error data on failure.
 */
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
                                                     machine_ptr *result)
{
    // TODO: Review the use of an up-to-800 byte stack allocation; we may want to replace this with
    // use of the new async-safe allocator.
    dwarf_stack<machine_ptr, 100> stack;
    dwarf_opstream opstream;
    plcrash_error_t err;

    /* Configure the opstream */
    if ((err = opstream.init(mobj, byteorder, address, offset, length)) != PLCRASH_ESUCCESS)
        return err;
    
    /*
     * Note that the below value macros all cast data to the appropriate target machine word size.
     * This will result in overflows, as defined in the DWARF specification; the unsigned overflow
     * behavior is defined, and as per DWARF and C, the signed overflow behavior is not.
     */
    
    /* A position-advancing read macro that uses GCC/clang's compound statement value extension, returning PLCRASH_EINVAL
     * if the read extends beyond the mapped range. */
#define dw_expr_read_int(_type) ({ \
    _type v; \
    if (!opstream.read_intU<_type>(&v)) { \
        PLCF_DEBUG("Read of size %zu exceeds mapped range", sizeof(v)); \
        return PLCRASH_EINVAL; \
    } \
    v; \
})
    
    /* A position-advancing uleb128 read macro that uses GCC/clang's compound statement value extension, returning an error
     * if the read fails. */
#define dw_expr_read_uleb128() ({ \
    uint64_t v; \
    if (!opstream.read_uleb128(&v)) { \
        PLCF_DEBUG("Read of ULEB128 value failed"); \
        return PLCRASH_EINVAL; \
    } \
    (machine_ptr) v; \
})

    /* A position-advancing sleb128 read macro that uses GCC/clang's compound statement value extension, returning an error
     * if the read fails. */
#define dw_expr_read_sleb128() ({ \
    int64_t v; \
    if (!opstream.read_sleb128(&v)) { \
        PLCF_DEBUG("Read of SLEB128 value failed"); \
        return PLCRASH_EINVAL; \
    } \
    (machine_ptr_s) v; \
})

    /* Macro to fetch register valeus; handles unsupported register numbers and missing registers values */
#define dw_thread_regval(dw_regnum) ({ \
    plcrash_regnum_t rn; \
	uint64_t _dw_regnum = dw_regnum; \
    if (!plcrash_async_thread_state_map_dwarf_to_reg(thread_state, _dw_regnum, &rn)) { \
        PLCF_DEBUG("Unsupported DWARF register value of 0x%" PRIx64, _dw_regnum);\
        return PLCRASH_ENOTSUP; \
    } \
\
    if (!plcrash_async_thread_state_has_reg(thread_state, rn)) { \
        PLCF_DEBUG("Register value of %s unavailable in the current frame.", plcrash_async_thread_state_get_reg_name(thread_state, rn)); \
        return PLCRASH_ENOTFOUND; \
    } \
\
    plcrash_greg_t val = plcrash_async_thread_state_get_reg(thread_state, rn); \
    (machine_ptr) val; \
})

    /* A push macro that handles reporting of stack overflow errors */
#define dw_expr_push(v) if (!stack.push((machine_ptr_s)v)) { \
    PLCF_DEBUG("Hit stack limit; cannot push further values"); \
    return PLCRASH_EINTERNAL; \
}
    
    /* A pop macro that handles reporting of stack underflow errors */
#define dw_expr_pop(v) if (!stack.pop(v)) { \
    PLCF_DEBUG("Pop on an empty stack"); \
    return PLCRASH_EINTERNAL; \
}
    
    /* Populate the initial state */
    for (size_t i = 0; i < initial_count; i++)
        dw_expr_push(initial_state[i]);

    uint8_t opcode;
    while (opstream.read_intU(&opcode)) {
        switch (opcode) {
            case DW_OP_lit0:
            case DW_OP_lit1:
            case DW_OP_lit2:
            case DW_OP_lit3:
            case DW_OP_lit4:
            case DW_OP_lit5:
            case DW_OP_lit6:
            case DW_OP_lit7:
            case DW_OP_lit8:
            case DW_OP_lit9:
            case DW_OP_lit10:
            case DW_OP_lit11:
            case DW_OP_lit12:
            case DW_OP_lit13:
            case DW_OP_lit14:
            case DW_OP_lit15:
            case DW_OP_lit16:
            case DW_OP_lit17:
            case DW_OP_lit18:
            case DW_OP_lit19:
            case DW_OP_lit20:
            case DW_OP_lit21:
            case DW_OP_lit22:
            case DW_OP_lit23:
            case DW_OP_lit24:
            case DW_OP_lit25:
            case DW_OP_lit26:
            case DW_OP_lit27:
            case DW_OP_lit28:
            case DW_OP_lit29:
            case DW_OP_lit30:
            case DW_OP_lit31:
                dw_expr_push(opcode-DW_OP_lit0);
                break;
                
            case DW_OP_const1u:
                dw_expr_push(dw_expr_read_int(uint8_t));
                break;

            case DW_OP_const1s:
                dw_expr_push(dw_expr_read_int(int8_t));
                break;
                
            case DW_OP_const2u:
                dw_expr_push(dw_expr_read_int(uint16_t));
                break;
                
            case DW_OP_const2s:
                dw_expr_push((int16_t)dw_expr_read_int(int16_t));
                break;
                
            case DW_OP_const4u:
                dw_expr_push(dw_expr_read_int(uint32_t));
                break;
                
            case DW_OP_const4s:
                dw_expr_push((int32_t) dw_expr_read_int(int32_t));
                break;
                
            case DW_OP_const8u:
                dw_expr_push(dw_expr_read_int(uint64_t));
                break;
                
            case DW_OP_const8s:
                dw_expr_push((int64_t) dw_expr_read_int(int64_t));
                break;
                
            case DW_OP_constu:
                dw_expr_push(dw_expr_read_uleb128());
                break;
                
            case DW_OP_consts:
                dw_expr_push(dw_expr_read_sleb128());
                break;
                
            case DW_OP_breg0:
			case DW_OP_breg1:
			case DW_OP_breg2:
			case DW_OP_breg3:
			case DW_OP_breg4:
			case DW_OP_breg5:
			case DW_OP_breg6:
			case DW_OP_breg7:
			case DW_OP_breg8:
			case DW_OP_breg9:
			case DW_OP_breg10:
			case DW_OP_breg11:
			case DW_OP_breg12:
			case DW_OP_breg13:
			case DW_OP_breg14:
			case DW_OP_breg15:
			case DW_OP_breg16:
			case DW_OP_breg17:
			case DW_OP_breg18:
			case DW_OP_breg19:
			case DW_OP_breg20:
			case DW_OP_breg21:
			case DW_OP_breg22:
			case DW_OP_breg23:
			case DW_OP_breg24:
			case DW_OP_breg25:
			case DW_OP_breg26:
			case DW_OP_breg27:
			case DW_OP_breg28:
			case DW_OP_breg29:
			case DW_OP_breg30:
			case DW_OP_breg31:
                dw_expr_push(dw_thread_regval(opcode - DW_OP_breg0) + dw_expr_read_sleb128());
                break;
                
            case DW_OP_bregx:
                dw_expr_push(dw_thread_regval(dw_expr_read_uleb128()) + dw_expr_read_sleb128());
                break;
                
            case DW_OP_dup:
                if (!stack.dup()) {
                    PLCF_DEBUG("DW_OP_dup on an empty stack");
                    return PLCRASH_EINVAL;
                }
                break;
                
            case DW_OP_drop: {
                if (!stack.drop()) {
                    PLCF_DEBUG("DW_OP_drop on an empty stack");
                    return PLCRASH_EINVAL;
                }
                break;
            }
                
            case DW_OP_pick:
                if (!stack.pick(dw_expr_read_int(uint8_t))) {
                    PLCF_DEBUG("DW_OP_pick on invalid index");
                    return PLCRASH_EINVAL;
                }
                break;

            case DW_OP_over:
                if (!stack.pick(1)) {
                    PLCF_DEBUG("DW_OP_over on stack with < 2 elements");
                    return PLCRASH_EINVAL;
                }
                break;
                
            case DW_OP_swap:
                if (!stack.swap()) {
                    PLCF_DEBUG("DW_OP_swap on stack with < 2 elements");
                    return PLCRASH_EINVAL;
                }
                break;
                
            case DW_OP_rot:
                if (!stack.rotate()) {
                    PLCF_DEBUG("DW_OP_rot on stack with < 3 elements");
                    return PLCRASH_EINVAL;
                }
                break;
            
                
            case DW_OP_xderef:
                /* This is identical to deref, except that it consumes an additional stack value
                 * containing the address space of the address. We don't support any systems with multiple
                 * address spaces, so we simply excise this value from the stack and fall through to the
                 * deref implementation */

                /* Move the address space value to the top of the stack, and then drop it */
                if (!stack.swap()) {
                    PLCF_DEBUG("DW_OP_xderef on stack with < 2 elements");
                    return PLCRASH_EINVAL;
                }
                
                /* This can't fail after the swap suceeded */
                stack.drop();
                PLCR_FALLTHROUGH;
                
            case DW_OP_deref: {
                machine_ptr addr;
                machine_ptr value;

                dw_expr_pop(&addr);
                if ((err = plcrash_async_task_memcpy(task, (pl_vm_address_t) addr, 0, &value, sizeof(value))) != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("DW_OP_deref referenced an invalid target address 0x%" PRIx64, (uint64_t) addr);
                    return err;
                }

                dw_expr_push(value);
                
                break;
            }
            case DW_OP_xderef_size:
                /* This is identical to deref_size, except that it consumes an additional stack value
                 * containing the address space of the address. We don't support any systems with multiple
                 * address spaces, so we simply excise this value from the stack and fall through to the
                 * deref implementation */
                
                /* Move the address space value to the top of the stack, and then drop it */
                if (!stack.swap()) {
                    PLCF_DEBUG("DW_OP_xderef_size on stack with < 2 elements");
                    return PLCRASH_EINVAL;
                }

                /* This can't fail after the swap suceeded */
                stack.drop();
                PLCR_FALLTHROUGH;

            case DW_OP_deref_size: {
                /* Fetch the target size */
                uint8_t size = dw_expr_read_int(uint8_t);
                if (size > sizeof(machine_ptr)) {
                    PLCF_DEBUG("DW_OP_deref_size specified a size larger than the native machine word");
                    return PLCRASH_EINVAL;
                }
                
                /* Pop the address from the stack */
                machine_ptr addr;
                dw_expr_pop(&addr);

                /* Perform the read */
                #define readval(_type) case sizeof(_type): { \
                    _type r; \
                    if ((err = plcrash_async_task_memcpy(task, (pl_vm_address_t)addr, 0, &r, sizeof(_type))) != PLCRASH_ESUCCESS) { \
                        PLCF_DEBUG("DW_OP_deref_size referenced an invalid target address 0x%" PRIx64, (uint64_t) addr); \
                        return err; \
                    } \
                    value = (machine_ptr)r; \
                    break; \
                }
                machine_ptr value = 0;
                switch (size) {
                    readval(uint8_t);
                    readval(uint16_t);
                    readval(uint32_t);
                    readval(uint64_t);

                    default:
                        PLCF_DEBUG("DW_OP_deref_size specified an unsupported size of %" PRIu8, size);
                        return PLCRASH_EINVAL;
                }
                #undef readval

                dw_expr_push(value);
                
                break;
            }
                
            case DW_OP_abs: {
                machine_ptr_s v;
                dw_expr_pop((machine_ptr *)&v);
                if (v < 0) {
                    dw_expr_push(-v);
                } else {
                    dw_expr_push(v);
                }
                break;
            }

            case DW_OP_and: {
                machine_ptr v1, v2;
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);                
                dw_expr_push(v1 & v2);
                break;
            }
                
            case DW_OP_div: {
                machine_ptr_s divisor;
                machine_ptr dividend;
                
                dw_expr_pop((machine_ptr *) &divisor);
                dw_expr_pop(&dividend);
                
                if (divisor == 0) {
                    PLCF_DEBUG("DW_OP_div attempted divide by zero");
                    return PLCRASH_EINVAL;
                }
                
                machine_ptr quotient = dividend / divisor;
                dw_expr_push(quotient);
                break;
            }
                
            case DW_OP_minus: {
                machine_ptr minuend, subtrahend;
                
                dw_expr_pop(&subtrahend);
                dw_expr_pop(&minuend);
                dw_expr_push(minuend - subtrahend);
                break;
            }
                
            case DW_OP_mod: {
                machine_ptr divisor;
                machine_ptr dividend;
                
                dw_expr_pop(&divisor);
                dw_expr_pop(&dividend);
                
                if (divisor == 0) {
                    PLCF_DEBUG("DW_OP_mod attempted divide by zero");
                    return PLCRASH_EINVAL;
                }
                
                machine_ptr remainder = dividend % divisor;
                dw_expr_push(remainder);
                break;
            }
                
            case DW_OP_mul: {
                machine_ptr v1, v2;
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                dw_expr_push(v1 * v2);
                break;
            }
                
            case DW_OP_neg: {
                machine_ptr_s svalue;
                dw_expr_pop((machine_ptr *) &svalue);
                dw_expr_push(0 - svalue);
                break;
            }
                
            case DW_OP_not: {
                machine_ptr v;
                dw_expr_pop(&v);
                dw_expr_push(~v);
                break;
            }
                
            case DW_OP_or: {
                machine_ptr v1, v2;
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                dw_expr_push(v1 | v2);
                break;
            }
                
            case DW_OP_plus: {
                machine_ptr v1, v2;
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                dw_expr_push(v1 + v2);
                break;
            }
                
            case DW_OP_plus_uconst: {
                machine_ptr v1 = dw_expr_read_uleb128();
                machine_ptr v2;
                
                dw_expr_pop(&v2);
                dw_expr_push(v1 + v2);
                break;
            }
                
            case DW_OP_shl: {
                machine_ptr shift;
                machine_ptr value;
                
                dw_expr_pop(&shift);
                dw_expr_pop(&value);
                
                dw_expr_push(value << shift);
                break;
            }
                
            case DW_OP_shr: {
                machine_ptr shift;
                machine_ptr value;
                
                dw_expr_pop(&shift);
                dw_expr_pop(&value);
                
                dw_expr_push(value >> shift);
                break;
            }
                
            case DW_OP_shra: {
                machine_ptr shift;
                machine_ptr_s value;
                
                dw_expr_pop(&shift);
                dw_expr_pop((machine_ptr *)&value);
                
                dw_expr_push(value >> shift);
                break;
            }
                
            case DW_OP_xor: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push(v1 ^ v2);
                break;
            }
                
            case DW_OP_le: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 <= v1));
                break;
            }

            case DW_OP_ge: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 >= v1));
                break;
            }
                
            case DW_OP_eq: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 == v1));
                break;
            }
    
            case DW_OP_lt: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 < v1));
                break;
            }

            case DW_OP_gt: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 > v1));
                break;
            }

            case DW_OP_ne: {
                machine_ptr v1, v2;
                
                dw_expr_pop(&v1);
                dw_expr_pop(&v2);
                
                dw_expr_push((v2 != v1));
                break;
            }
                
            case DW_OP_skip: {
                int16_t skipOffset = dw_expr_read_int(int16_t);
                if (!opstream.skip(skipOffset)) {
                    PLCF_DEBUG("DW_OP_skip offset %" PRId16 " falls outside of opcode range", skipOffset);
                    return PLCRASH_EINVAL;
                }
                break;
            }
                
            case DW_OP_bra: {
                int16_t skipOffset = dw_expr_read_int(int16_t);
                machine_ptr cond;

                dw_expr_pop(&cond);
                if (cond != 0) {
                    if (!opstream.skip(skipOffset)) {
                        PLCF_DEBUG("DW_OP_bra offset %" PRId16 " falls outside of opcode range", skipOffset);
                        return PLCRASH_EINVAL;
                    }
                }
                break;
            }

            case DW_OP_nop: // no-op
                break;
                
            // Not implemented -- fall through
            case DW_OP_fbreg:
                /* Unimplemented */
                
            case DW_OP_call2:
            case DW_OP_call4:
            case DW_OP_call_ref:
                /*
                 * As per DWARF 3, Section 6.4.2 Call Frame Instructions DW_OP_call2, DW_OP_call4 and DW_OP_call_ref operators
                 * are not meaningful in an operand of these instructions because there is no mapping from call frame information
                 * to any corresponding debugging compilation unit information, thus there is no way to interpret the call offset.
                 *
                 * If this implementation is further extended for use outside of CFI evaluation, this opcode should be implemented.
                */

            case DW_OP_push_object_address:
                /*
                 * As per DWARF 3, Section 6.4.2 Call Frame Instructions, DW_OP_push_object_address is not meaningful in an operand of these
                 * instructions because there is no object context to provide a value to push.
                 *
                 * If this implementation is further extended for use outside of CFI evaluation, this opcode should be implemented.
                 */

            case DW_OP_form_tls_address:
                /* The structure of TLS data on Darwin is implementation private. */
                
            case DW_OP_call_frame_cfa:
                /*
                 * As per DWARF 3, Section 6.4.2 Call Frame Instructions, DW_OP_call_frame_cfa is not meaningful in an operand of these
                 * instructions because its use would be circular.
                 *
                 * If this implementation is further extended for use outside of CFI evaluation, this opcode should be implemented.
                 */
                
            default:
                PLCF_DEBUG("Unsupported opcode 0x%" PRIx8, opcode);
                return PLCRASH_ENOTSUP;
        }
    }

    /* Provide the result */
    if (!stack.pop(result)) {
        PLCF_DEBUG("Expression did not provide a result value.");
        return PLCRASH_EINVAL;
    }

#undef dw_expr_read
#undef dw_expr_push
    return PLCRASH_ESUCCESS;
}

/* Provide explicit 32/64-bit instantiations */
template plcrash_error_t plcrash_async_dwarf_expression_eval<uint32_t, int32_t> (plcrash_async_mobject_t *mobj,
                                                                                 task_t task,
                                                                                 const plcrash_async_thread_state_t *thread_state,
                                                                                 const plcrash_async_byteorder_t *byteorder,
                                                                                 pl_vm_address_t address,
                                                                                 pl_vm_off_t offset,
                                                                                 pl_vm_size_t length,
                                                                                 uint32_t initial_state[],
                                                                                 size_t initial_count,
                                                                                 uint32_t *result);

template plcrash_error_t plcrash_async_dwarf_expression_eval<uint64_t, int64_t> (plcrash_async_mobject_t *mobj,
                                                                                 task_t task,
                                                                                 const plcrash_async_thread_state_t *thread_state,
                                                                                 const plcrash_async_byteorder_t *byteorder,
                                                                                 pl_vm_address_t address,
                                                                                 pl_vm_off_t offset,
                                                                                 pl_vm_size_t length,
                                                                                 uint64_t initial_state[],
                                                                                 size_t initial_count,
                                                                                 uint64_t *result);
/*
 * @}
 */
    
}
PLCR_CPP_END_NS

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
