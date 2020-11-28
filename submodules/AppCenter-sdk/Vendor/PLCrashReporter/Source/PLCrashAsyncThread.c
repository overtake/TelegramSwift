/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncThread.h"
#include "PLCrashMacros.h"

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_thread Thread State Handling
 *
 * An async-safe and architecture neutral API for introspecting and permuting thread state.
 * @{
 */

/**
 * Initialize an empty @a thread_state with the given @a cpu_type. Not all CPU types are supported, in which case
 * PLCRASH_ENOTSUP will be returned.
 *
 * All registers will be marked as unavailable.
 *
 * @param thread_state The thread state to be initialized.
 * @param cpu_type The target thread CPU type.
 */
plcrash_error_t plcrash_async_thread_state_init (plcrash_async_thread_state_t *thread_state, cpu_type_t cpu_type) {
    memset(thread_state, 0, sizeof(*thread_state));

    switch (cpu_type) {
#if PLCRASH_ASYNC_THREAD_X86_SUPPORT
        case CPU_TYPE_X86:
            thread_state->x86_state.thread.tsh.count = x86_THREAD_STATE32_COUNT;
            thread_state->x86_state.thread.tsh.flavor = x86_THREAD_STATE32;
            thread_state->x86_state.exception.esh.count = x86_EXCEPTION_STATE32_COUNT;
            thread_state->x86_state.exception.esh.flavor = x86_EXCEPTION_STATE32;
            
            thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
            thread_state->greg_size = 4;
            break;

        case CPU_TYPE_X86_64:
            thread_state->x86_state.thread.tsh.count = x86_THREAD_STATE64_COUNT;
            thread_state->x86_state.thread.tsh.flavor = x86_THREAD_STATE64;            
            thread_state->x86_state.exception.esh.count = x86_EXCEPTION_STATE64_COUNT;
            thread_state->x86_state.exception.esh.flavor = x86_EXCEPTION_STATE64;
            
            thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
            thread_state->greg_size = 8;
            break;
#endif /* PLCRASH_ASYNC_THREAD_X86_SUPPORT */

#if PLCRASH_ASYNC_THREAD_ARM_SUPPORT
        case CPU_TYPE_ARM:
            thread_state->arm_state.thread.ash.flavor = ARM_THREAD_STATE32;
            thread_state->arm_state.thread.ash.count = ARM_THREAD_STATE32_COUNT;
            thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
            thread_state->greg_size = 4;
            break;

        case CPU_TYPE_ARM64:
            thread_state->arm_state.thread.ash.flavor = ARM_THREAD_STATE64;
            thread_state->arm_state.thread.ash.count = ARM_THREAD_STATE64_COUNT;
            thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
            thread_state->greg_size = 8;
            break;
#endif /* PLCRASH_ASYNC_THREAD_ARM_SUPPORT */
            
        default:
            return PLCRASH_ENOTSUP;
    }

    plcrash_async_thread_state_clear_all_regs(thread_state);
    return PLCRASH_ESUCCESS;
}

/**
 * Initialize the @a thread_state using the provided context.
 *
 * @param thread_state The thread state to be initialized.
 * @param mctx The context to use for cursor initialization.
 *
 * All registers will be marked as available.
 */
void plcrash_async_thread_state_mcontext_init (plcrash_async_thread_state_t *thread_state, pl_mcontext_t *mctx) {
    /*
     * Copy in the thread state. Unlike the mach thread variants, mcontext_t may only represent
     * the thread state of the host process, and we may assume that the compilation target matches the mcontext_t
     * thread type.
     */
    
#if defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT) && defined(__LP64__)
    plcrash_async_thread_state_init(thread_state, CPU_TYPE_ARM64);
    
    /* Sanity check. */
    PLCF_ASSERT(sizeof(mctx->__ss) == sizeof(thread_state->arm_state.thread.ts_64));
    
    plcrash_async_memcpy(&thread_state->arm_state.thread.ts_64, &mctx->__ss, sizeof(thread_state->arm_state.thread.ts_64));

#elif defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT)
    plcrash_async_thread_state_init(thread_state, CPU_TYPE_ARM);

    /* Sanity check. */
    PLCF_ASSERT(sizeof(mctx->__ss) == sizeof(thread_state->arm_state.thread.ts_32));

    plcrash_async_memcpy(&thread_state->arm_state.thread.ts_32, &mctx->__ss, sizeof(thread_state->arm_state.thread.ts_32));
    
#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT) && defined(__LP64__)
    plcrash_async_thread_state_init(thread_state, CPU_TYPE_X86_64);

    /* Sanity check. */
    PLCF_ASSERT(sizeof(mctx->__ss) == sizeof(thread_state->x86_state.thread.uts.ts64));
    PLCF_ASSERT(sizeof(mctx->__es) == sizeof(thread_state->x86_state.exception.ues.es64));
    
    plcrash_async_memcpy(&thread_state->x86_state.thread.uts.ts64, &mctx->__ss, sizeof(thread_state->x86_state.thread.uts.ts64));
    plcrash_async_memcpy(&thread_state->x86_state.exception.ues.es64, &mctx->__es, sizeof(thread_state->x86_state.exception.ues.es64));

#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT)
    plcrash_async_thread_state_init(thread_state, CPU_TYPE_X86);

    /* Sanity check. */
    PLCF_ASSERT(sizeof(mctx->__ss) == sizeof(thread_state->x86_state.thread.uts.ts32));
    PLCF_ASSERT(sizeof(mctx->__es) == sizeof(thread_state->x86_state.exception.ues.es32));

    plcrash_async_memcpy(&thread_state->x86_state.thread.uts.ts32, &mctx->__ss, sizeof(thread_state->x86_state.thread.uts.ts32));
    plcrash_async_memcpy(&thread_state->x86_state.exception.ues.es32, &mctx->__es, sizeof(thread_state->x86_state.exception.ues.es32));
#else
#error Add platform support
#endif

    /* Mark all registers as available */
    memset(&thread_state->valid_regs, 0xFF, sizeof(thread_state->valid_regs));
}

/**
 * Initialize the @a thread_state using thread state fetched from the given mach @a thread. If the thread is not
 * suspended, the fetched state may be inconsistent.
 *
 * All registers will be marked as available.
 *
 * @param thread_state The thread state to be initialized.
 * @param thread The thread from which to fetch thread state.
 *
 * @return Returns PLFRAME_ESUCCESS on success, or standard plframe_error_t code if an error occurs.
 */
plcrash_error_t plcrash_async_thread_state_mach_thread_init (plcrash_async_thread_state_t *thread_state, thread_t thread) {
    mach_msg_type_number_t state_count;
    kern_return_t kr;
    
#if defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT)
    /* Fetch the thread state */
    state_count = ARM_UNIFIED_THREAD_STATE_COUNT;
    kr = thread_get_state(thread, ARM_UNIFIED_THREAD_STATE, (thread_state_t) &thread_state->arm_state.thread, &state_count);
    if (kr != KERN_SUCCESS) {
        PLCF_DEBUG("Fetch of ARM thread state failed with Mach error: %d", kr);
        return PLCRASH_EINTERNAL;
    }
    
    /* Platform meta-data */
    thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE64) {
        thread_state->greg_size = 8;
    } else {
        thread_state->greg_size = 4;
    }

#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT)
    /* Fetch the thread state */
    state_count = x86_THREAD_STATE_COUNT;
    kr = thread_get_state(thread, x86_THREAD_STATE, (thread_state_t) &thread_state->x86_state.thread, &state_count);
    if (kr != KERN_SUCCESS) {
        PLCF_DEBUG("Fetch of x86 thread state failed with Mach error: %d", kr);
        return PLCRASH_EINTERNAL;
    }
    
    /* Fetch the exception state */
    state_count = x86_EXCEPTION_STATE_COUNT;
    kr = thread_get_state(thread, x86_EXCEPTION_STATE, (thread_state_t) &thread_state->x86_state.exception, &state_count);
    if (kr != KERN_SUCCESS) {
        PLCF_DEBUG("Fetch of x86 exception state failed with Mach error: %d", kr);
        return PLCRASH_EINTERNAL;
    }
    
    /* Platform meta-data */
    thread_state->stack_direction = PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN;
    if (thread_state->x86_state.thread.tsh.flavor == x86_THREAD_STATE64) {
        thread_state->greg_size = 8;
    } else {
        thread_state->greg_size = 4;
    }

#else
#error Add platform support
#endif

    /* Mark all registers as available */
    memset(&thread_state->valid_regs, 0xFF, sizeof(thread_state->valid_regs));

    return PLCRASH_ESUCCESS;
}

/**
 * Copy thread state @a source to @a dest.
 *
 * @param dest The destination to which the thread state will be copied.
 * @param source The thread state to be copied.
 *
 * @note If @a dest and @a source overlap, behavior is undefined.
 */
void plcrash_async_thread_state_copy (plcrash_async_thread_state_t *dest, const plcrash_async_thread_state_t *source) {
    plcrash_async_memcpy(dest, source, sizeof(*dest));
}

/**
 * Return true if @a regnum is set in @a thread_state, false otherwise.
 *
 * @param thread_state The thread state to test.
 * @param regnum The register number to test for.
 */
bool plcrash_async_thread_state_has_reg (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum) {
    if ((thread_state->valid_regs & (1ULL<<regnum)) != 0)
        return true;
    
    return false;
}

/**
 * Clear @a regnum in @a thread_state.
 *
 * @param thread_state The thread state to modify.
 * @param regnum The register to unset.
 */
void plcrash_async_thread_state_clear_reg (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum) {
    thread_state->valid_regs &= ~(1ULL<<regnum);
}


/**
 * Clear all registers in @a thread_state.
 *
 * @param thread_state The thread state to modify.
 */
void plcrash_async_thread_state_clear_all_regs (plcrash_async_thread_state_t *thread_state) {
    thread_state->valid_regs = 0x0;
}

/**
 * Return the direction used for stack growth by @a thread_state.
 *
 * @param thread_state The target thread state.
 */
plcrash_async_thread_stack_direction_t plcrash_async_thread_state_get_stack_direction (const plcrash_async_thread_state_t *thread_state) {
    return thread_state->stack_direction;
}

/**
 * Return the size (in bytes) of @a thread_state's general purpose registers. This value will be used to determine the
 * size of general purpose registers pushed/popped from the target thread's stack.
 *
 * @param thread_state The target thread state.
 */
size_t plcrash_async_thread_state_get_greg_size (const plcrash_async_thread_state_t *thread_state) {
    return thread_state->greg_size;
}

/*
 * @}
 */
