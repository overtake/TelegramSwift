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

#ifndef PLCRASH_ASYNC_THREAD_H
#define PLCRASH_ASYNC_THREAD_H

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/ucontext.h>
#include "PLCrashAsync.h"
    
#include <Availability.h>

/**
 * @internal
 * @ingroup plcrash_async_thread
 * @{
 */

/* Configure supported targets based on the host build architecture. There's currently
 * no deployed architecture on which simultaneous support for different processor families
 * is required (or supported), but -- in theory -- such cross-architecture support could be
 * enabled by modifying these defines. */
#if defined(__i386__) || defined(__x86_64__)

/** Defined if x86-64 and x86-32 thread states are supported by the PLCrashReporter thread state API. */
#define PLCRASH_ASYNC_THREAD_X86_SUPPORT 1

#include <mach/i386/thread_state.h>

/** Host architecture mcontext_t type. */
typedef _STRUCT_MCONTEXT pl_mcontext_t;

/** Host architecture ucontext_t type. */
typedef _STRUCT_UCONTEXT pl_ucontext_t;

#endif

#if defined(__arm__) || defined(__arm64__)
    
#include <mach/arm/thread_state.h>

/** Host architecture mcontext_t type. */
typedef _STRUCT_MCONTEXT pl_mcontext_t;

/** Host architecture ucontext_t type. */
typedef _STRUCT_UCONTEXT pl_ucontext_t;

/** Defined if ARM thread states are supported by the PLCrashReporter thread state API. */
#define PLCRASH_ASYNC_THREAD_ARM_SUPPORT 1

#endif

/**
 * Stack growth direction.
 */
typedef enum {
    /** The stack grows upwards on this platform. */
    PLCRASH_ASYNC_THREAD_STACK_DIRECTION_UP = 1,
    
    /** The stack grows downwards on this platform. */
    PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN = 2
} plcrash_async_thread_stack_direction_t;

/**
 * @internal
 *
 * Target-neutral thread-state.
 *
 * The thread state maintains a set of valid registers; this may be used to implement delta
 * updates of threads' state, or otherwise express partial thread states, eg, when unwinding
 * a stack and not all registers can be restored.
 */
typedef struct plcrash_async_thread_state {
    /** Stack growth direction */
    plcrash_async_thread_stack_direction_t stack_direction;
    
    /** General purpose register size, in bytes */
    size_t greg_size;
    
    /** The set of available registers. */
    uint64_t valid_regs;

    /* Union used to hold thread state for any supported architecture */
    union {
    #ifdef PLCRASH_ASYNC_THREAD_ARM_SUPPORT
        /** Combined ARM 32/64 thread state */
        struct {
            /** ARM thread state */
            arm_unified_thread_state_t thread;
        } arm_state;
    #endif

    #ifdef PLCRASH_ASYNC_THREAD_X86_SUPPORT
        /** Combined x86 32/64 thread state */
        struct {
            /** Thread state */
            x86_thread_state_t thread;
            
            /** Exception state. */
            x86_exception_state_t exception;
        } x86_state;
    #endif
    };
} plcrash_async_thread_state_t;

/** Register number type */
typedef uint32_t plcrash_regnum_t;

/**
 * General pseudo-registers common across platforms.
 *
 * Platform registers must be allocated starting at a 0 index, with no breaks. The following pseudo-register
 * values must be assigned to the corresponding platform register values (or in the case of the invalid register,
 * the constant value must be left unused).
 */
typedef enum {
    /** Instruction pointer */
    PLCRASH_REG_IP = 0,
    
    /** Frame pointer */
    PLCRASH_REG_FP = 1,
    
    /** Stack pointer */
    PLCRASH_REG_SP = 2,

    /**
     * Invalid register. This value must not be assigned to a platform register.
     */
    PLCRASH_REG_INVALID = INT32_MAX
} plcrash_gen_regnum_t;

#include "PLCrashAsyncThread_x86.h"
#include "PLCrashAsyncThread_arm.h"

/** Platform word type */
typedef plcrash_pdef_greg_t plcrash_greg_t;

plcrash_error_t plcrash_async_thread_state_init (plcrash_async_thread_state_t *thread_state, cpu_type_t cpu_type);
void plcrash_async_thread_state_mcontext_init (plcrash_async_thread_state_t *thread_state, pl_mcontext_t *mctx);
plcrash_error_t plcrash_async_thread_state_mach_thread_init (plcrash_async_thread_state_t *thread_state, thread_t thread);

/**
 * Callback function called by plcrash_log_writer_write_curthread().
 *
 * @param state The thread state fetched by plcrash_log_writer_write_curthread().
 * @param context Caller-provided context value.
 */
typedef plcrash_error_t (*plcrash_async_thread_state_current_callback)(plcrash_async_thread_state_t *state, void *context);

/**
 * Fetch the calling thread's state and pass it to the given @a callback.
 *
 * @param callback Function to be called with the calling thread's state.
 * @param context Context value to be passed to @a callback.
 *
 * @note This is implemented with an assembly trampoline that fetches the current thread state to be passed to the @a callback. Solutions such
 * as getcontext() are not viable here, as returning from getcontext() mutates the state of the stack.
 */
plcrash_error_t plcrash_async_thread_state_current (plcrash_async_thread_state_current_callback callback, void *context);

void plcrash_async_thread_state_copy (plcrash_async_thread_state_t *dest, const plcrash_async_thread_state_t *src);

plcrash_async_thread_stack_direction_t plcrash_async_thread_state_get_stack_direction (const plcrash_async_thread_state_t *thread_state);
size_t plcrash_async_thread_state_get_greg_size (const plcrash_async_thread_state_t *thread_state);

bool plcrash_async_thread_state_has_reg (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum);
void plcrash_async_thread_state_clear_reg (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum);
void plcrash_async_thread_state_clear_all_regs (plcrash_async_thread_state_t *thread_state);

/* Platform specific funtions */

/**
 * Get a register's name.
 */
char const *plcrash_async_thread_state_get_reg_name (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum);

/**
 * Get the total number of registers supported by @a thread_state.
 *
 * @param thread_state The target thread state.
 */
size_t plcrash_async_thread_state_get_reg_count (const plcrash_async_thread_state_t *thread_state);

/**
 * Get a register value.
 */
plcrash_greg_t plcrash_async_thread_state_get_reg (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum);

/**
 * Set a register value.
 */
void plcrash_async_thread_state_set_reg (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum, plcrash_greg_t reg);

/**
 * Clear all non-callee saved volatile registers in @a thread_state. The exact registers preserved depend on the target ABI.
 *
 * @param thread_state The thread state to clear.
 */
void plcrash_async_thread_state_clear_volatile_regs (plcrash_async_thread_state_t *thread_state);

/**
 * Map a plcrash_regnum_t to its corresponding DWARF register value. Returns true if a mapping is available
 * for @a regnum, or false if no DWARF register value is available for @a regnum.
 *
 * @warning This API may require changes in the future to support specifying the register mapping type; eg, DWARF debug_frame
 * vs eh_frame, or similar.
 *
 *
 * @param thread_state The thread state to be used for performing the mapping.
 * @param regnum The register number to be mapped.
 * @param[out] dwarf_reg The mapped DWARF register value.
 */
bool plcrash_async_thread_state_map_reg_to_dwarf (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum, uint64_t *dwarf_reg);

/**
 * Map a DWARF register number to its plcrash_regnum_t representation. Returns true if a mapping is available
 * for @a dwarf_reg, or false if the mapping for @a dwarf_reg is unknown.
 *
 * @warning This API may require changes in the future to support specifying the register mapping type; eg, DWARF debug_frame
 * vs eh_frame, or similar.
 *
 * @param thread_state The thread state to be used for performing the mapping.
 * @param dwarf_reg The DWARF register number to be mapped.
 * @param[out] regnum The mapped register number.
 */
bool plcrash_async_thread_state_map_dwarf_to_reg (const plcrash_async_thread_state_t *thread_state, uint64_t dwarf_reg, plcrash_regnum_t *regnum);

/*
 * @}
 */
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_THREAD_H */
