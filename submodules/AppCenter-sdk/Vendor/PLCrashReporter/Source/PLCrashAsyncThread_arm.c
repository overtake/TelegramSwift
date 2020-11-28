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
#include "PLCrashAsync.h"

#include <signal.h>
#include <stdlib.h>
#include <assert.h>

#include <mach/thread_status.h>

#if defined(__arm__) || defined(__arm64__)

#if __DARWIN_UNIX03
#define THREAD_STATE_REG_PREFIX(name) __ ## name
#else
#define THREAD_STATE_REG_PREFIX(name) name
#endif

#define THREAD_STATE_GET(name, type, ts) (ts->arm_state. type . THREAD_STATE_REG_PREFIX(name))
#define THREAD_STATE_SET(name, type, ts, regnum, value) { \
    ts->valid_regs |= 1ULL << regnum; \
    (ts->arm_state. type . THREAD_STATE_REG_PREFIX(name)) = value; \
}

#if defined(__LP64__)

#if __DARWIN_OPAQUE_ARM_THREAD_STATE64
#define THREAD_STATE_OPAQUE_PREFIX(name) __opaque_ ## name
#define THREAD_STATE_OPAQUE_TYPE void *
#else
#define THREAD_STATE_OPAQUE_PREFIX THREAD_STATE_REG_PREFIX
#define THREAD_STATE_OPAQUE_TYPE uint64_t
#endif

/*
 * Pointer authentication codes (on arm64e for example) must be stripped out by applying ARM64_PTR_MASK bitmask.
 * See https://developer.apple.com/documentation/security/preparing_your_app_to_work_with_pointer_authentication
 *
 * Note: Even if pointer authentication (ptrauth) is not available at the compile time, the binary still can be used
 * in an environment with PAC.
 *
 * Do not use arm_thread_state64_get_* to access to specific fields because arm64e injects additional checks that can
 * prevent to get the values despite of the fact that the actual data was already read before.
 */
#define THREAD_STATE_GET_PTR(name, type, ts) ({ \
    plcrash_greg_t ptr = (plcrash_greg_t) ts->arm_state. type . THREAD_STATE_OPAQUE_PREFIX(name); \
    (ptr & ARM64_PTR_MASK); \
})
#define THREAD_STATE_GET_FPTR THREAD_STATE_GET_PTR
#define THREAD_STATE_SET_PTR(name, type, ts, regnum, value) { \
    ts->valid_regs |= 1ULL << regnum; \
    (ts->arm_state. type . THREAD_STATE_OPAQUE_PREFIX(name)) = (THREAD_STATE_OPAQUE_TYPE) value; \
}
#define THREAD_STATE_SET_FPTR THREAD_STATE_SET_PTR

#else // __LP64__

#define THREAD_STATE_GET_PTR THREAD_STATE_GET
#define THREAD_STATE_GET_FPTR THREAD_STATE_GET

#define THREAD_STATE_SET_PTR THREAD_STATE_SET
#define THREAD_STATE_SET_FPTR THREAD_STATE_SET

#endif // __LP64__

/* Mapping of DWARF register numbers to PLCrashReporter register numbers. */
struct dwarf_register_table {
    /** Standard register number. */
    plcrash_regnum_t regnum;
    
    /** DWARF register number. */
    uint64_t dwarf_value;
};

/*
 * ARM GP registers defined as callee-preserved, as per Apple's iOS ARM Function Call Guide
 */
static const plcrash_regnum_t arm_nonvolatile_registers[] = {
    PLCRASH_ARM_R4,
    PLCRASH_ARM_R5,
    PLCRASH_ARM_R6,
    PLCRASH_ARM_R7,
    PLCRASH_ARM_R8,
    PLCRASH_ARM_R10,
    PLCRASH_ARM_R11,
};

/*
 * ARM GP registers defined as callee-preserved, as per ARM's Procedure Call Standard for the
 * ARM 64-bit Architecture (AArch64), 22nd May 2013.
 */
static const plcrash_regnum_t arm64_nonvolatile_registers[] = {
    PLCRASH_ARM64_X19,
    PLCRASH_ARM64_X20,
    PLCRASH_ARM64_X21,
    PLCRASH_ARM64_X22,
    PLCRASH_ARM64_X23,
    PLCRASH_ARM64_X24,
    PLCRASH_ARM64_X25,
    PLCRASH_ARM64_X26,
    PLCRASH_ARM64_X27,
    PLCRASH_ARM64_X28,

#ifdef __APPLE__
    // AAPCS 64 Section 5.2.3 allows an implementation to define the minimum
    // level of conformance with respect to maintaining frame records.
    //
    // Apple's ARM64 Function Calling Conventions states:
    // The frame pointer register (x29) must always address a valid frame record, although some functions—such
    // as leaf functions or tail calls—may elect not to create an entry in this list. As a result, stack traces will
    // always be meaningful, even without debug information.
    PLCRASH_ARM64_FP,
#else
#error Define OS frame pointer behavior as per AAPCS64 Section 5.2.3
#endif
};

/**
 * DWARF register mappings as defined in ARM's "DWARF for the ARM Architecture", ARM IHI 0040B,
 * issued November 30th, 2012.
 *
 * Note that not all registers have DWARF register numbers allocated, eg, the ARM standard states
 * in Section 3.1:
 *
 *   The CPSR, VFP and FPA control registers are not allocated a numbering above. It is
 *   considered unlikely that these will be needed for producing a stack back-trace in a
 *   debugger.
 */
static const struct dwarf_register_table arm_dwarf_table [] = {
    { PLCRASH_ARM_R0, 0 },
    { PLCRASH_ARM_R1, 1 },
    { PLCRASH_ARM_R2, 2 },
    { PLCRASH_ARM_R3, 3 },
    { PLCRASH_ARM_R4, 4 },
    { PLCRASH_ARM_R5, 5 },
    { PLCRASH_ARM_R6, 6 },
    { PLCRASH_ARM_R7, 7 },
    { PLCRASH_ARM_R8, 8 },
    { PLCRASH_ARM_R9, 9 },
    { PLCRASH_ARM_R10, 10 },
    { PLCRASH_ARM_R11, 11 },
    { PLCRASH_ARM_R12, 12 },
    { PLCRASH_ARM_SP, 13 },
    { PLCRASH_ARM_LR, 14 },
    { PLCRASH_ARM_PC, 15 }
};

/**
 * DWARF register mappings as defined in ARM's "DWARF for the ARM 64-bit Architecture (AArch64)", ARM IHI 0057B,
 * issued May 22nd, 2013.
 *
 * Note that not all registers have DWARF register numbers allocated, eg, the ARM standard states
 * in Section 3.1:
 *
 *   The CPSR, VFP and FPA control registers are not allocated a numbering above. It is
 *   considered unlikely that these will be needed for producing a stack back-trace in a
 *   debugger.
 */
static const struct dwarf_register_table arm64_dwarf_table [] = {
    // TODO_ARM64: These should be validated against actual arm64 DWARF data.
    { PLCRASH_ARM64_X0, 0 },
    { PLCRASH_ARM64_X1, 1 },
    { PLCRASH_ARM64_X2, 2 },
    { PLCRASH_ARM64_X3, 3 },
    { PLCRASH_ARM64_X4, 4 },
    { PLCRASH_ARM64_X5, 5 },
    { PLCRASH_ARM64_X6, 6 },
    { PLCRASH_ARM64_X7, 7 },
    { PLCRASH_ARM64_X8, 8 },
    { PLCRASH_ARM64_X9, 9 },
    { PLCRASH_ARM64_X10, 10 },
    { PLCRASH_ARM64_X11, 11 },
    { PLCRASH_ARM64_X12, 12 },
    { PLCRASH_ARM64_X13, 13 },
    { PLCRASH_ARM64_X14, 14 },
    { PLCRASH_ARM64_X15, 15 },
    { PLCRASH_ARM64_X16, 16 },
    { PLCRASH_ARM64_X17, 17 },
    { PLCRASH_ARM64_X18, 18 },
    { PLCRASH_ARM64_X19, 19 },
    { PLCRASH_ARM64_X20, 20 },
    { PLCRASH_ARM64_X21, 21 },
    { PLCRASH_ARM64_X22, 22 },
    { PLCRASH_ARM64_X23, 23 },
    { PLCRASH_ARM64_X24, 24 },
    { PLCRASH_ARM64_X25, 25 },
    { PLCRASH_ARM64_X26, 26 },
    { PLCRASH_ARM64_X27, 27 },
    { PLCRASH_ARM64_X28, 28 },
    { PLCRASH_ARM64_FP, 29 },
    { PLCRASH_ARM64_LR, 30 },
    
    { PLCRASH_ARM64_SP,  31 },
};

static inline plcrash_greg_t plcrash_async_thread_state_get_reg_32 (const plcrash_async_thread_state_t *ts, plcrash_regnum_t regnum) {
    switch (regnum) {
        case PLCRASH_ARM_R0: return THREAD_STATE_GET(r[0], thread.ts_32, ts);
        case PLCRASH_ARM_R1: return THREAD_STATE_GET(r[1], thread.ts_32, ts);
        case PLCRASH_ARM_R2: return THREAD_STATE_GET(r[2], thread.ts_32, ts);
        case PLCRASH_ARM_R3: return THREAD_STATE_GET(r[3], thread.ts_32, ts);
        case PLCRASH_ARM_R4: return THREAD_STATE_GET(r[4], thread.ts_32, ts);
        case PLCRASH_ARM_R5: return THREAD_STATE_GET(r[5], thread.ts_32, ts);
        case PLCRASH_ARM_R6: return THREAD_STATE_GET(r[6], thread.ts_32, ts);
        case PLCRASH_ARM_R7: return THREAD_STATE_GET(r[7], thread.ts_32, ts);
        case PLCRASH_ARM_R8: return THREAD_STATE_GET(r[8], thread.ts_32, ts);
        case PLCRASH_ARM_R9: return THREAD_STATE_GET(r[9], thread.ts_32, ts);
        case PLCRASH_ARM_R10: return THREAD_STATE_GET(r[10], thread.ts_32, ts);
        case PLCRASH_ARM_R11: return THREAD_STATE_GET(r[11], thread.ts_32, ts);
        case PLCRASH_ARM_R12: return THREAD_STATE_GET(r[12], thread.ts_32, ts);
        case PLCRASH_ARM_SP: return THREAD_STATE_GET(sp, thread.ts_32, ts);
        case PLCRASH_ARM_LR: return THREAD_STATE_GET(lr, thread.ts_32, ts);
        case PLCRASH_ARM_PC: return THREAD_STATE_GET(pc, thread.ts_32, ts);
        case PLCRASH_ARM_CPSR: return THREAD_STATE_GET(cpsr, thread.ts_32, ts);
        default: __builtin_trap();
    }
}

static inline plcrash_greg_t plcrash_async_thread_state_get_reg_64 (const plcrash_async_thread_state_t *ts, plcrash_regnum_t regnum) {
    switch (regnum) {
        case PLCRASH_ARM64_X0: return THREAD_STATE_GET(x[0], thread.ts_64, ts);
        case PLCRASH_ARM64_X1: return THREAD_STATE_GET(x[1], thread.ts_64, ts);
        case PLCRASH_ARM64_X2: return THREAD_STATE_GET(x[2], thread.ts_64, ts);
        case PLCRASH_ARM64_X3: return THREAD_STATE_GET(x[3], thread.ts_64, ts);
        case PLCRASH_ARM64_X4: return THREAD_STATE_GET(x[4], thread.ts_64, ts);
        case PLCRASH_ARM64_X5: return THREAD_STATE_GET(x[5], thread.ts_64, ts);
        case PLCRASH_ARM64_X6: return THREAD_STATE_GET(x[6], thread.ts_64, ts);
        case PLCRASH_ARM64_X7: return THREAD_STATE_GET(x[7], thread.ts_64, ts);
        case PLCRASH_ARM64_X8: return THREAD_STATE_GET(x[8], thread.ts_64, ts);
        case PLCRASH_ARM64_X9: return THREAD_STATE_GET(x[9], thread.ts_64, ts);
        case PLCRASH_ARM64_X10: return THREAD_STATE_GET(x[10], thread.ts_64, ts);
        case PLCRASH_ARM64_X11: return THREAD_STATE_GET(x[11], thread.ts_64, ts);
        case PLCRASH_ARM64_X12: return THREAD_STATE_GET(x[12], thread.ts_64, ts);
        case PLCRASH_ARM64_X13: return THREAD_STATE_GET(x[13], thread.ts_64, ts);
        case PLCRASH_ARM64_X14: return THREAD_STATE_GET(x[14], thread.ts_64, ts);
        case PLCRASH_ARM64_X15: return THREAD_STATE_GET(x[15], thread.ts_64, ts);
        case PLCRASH_ARM64_X16: return THREAD_STATE_GET(x[16], thread.ts_64, ts);
        case PLCRASH_ARM64_X17: return THREAD_STATE_GET(x[17], thread.ts_64, ts);
        case PLCRASH_ARM64_X18: return THREAD_STATE_GET(x[18], thread.ts_64, ts);
        case PLCRASH_ARM64_X19: return THREAD_STATE_GET(x[19], thread.ts_64, ts);
        case PLCRASH_ARM64_X20: return THREAD_STATE_GET(x[20], thread.ts_64, ts);
        case PLCRASH_ARM64_X21: return THREAD_STATE_GET(x[21], thread.ts_64, ts);
        case PLCRASH_ARM64_X22: return THREAD_STATE_GET(x[22], thread.ts_64, ts);
        case PLCRASH_ARM64_X23: return THREAD_STATE_GET(x[23], thread.ts_64, ts);
        case PLCRASH_ARM64_X24: return THREAD_STATE_GET(x[24], thread.ts_64, ts);
        case PLCRASH_ARM64_X25: return THREAD_STATE_GET(x[25], thread.ts_64, ts);
        case PLCRASH_ARM64_X26: return THREAD_STATE_GET(x[26], thread.ts_64, ts);
        case PLCRASH_ARM64_X27: return THREAD_STATE_GET(x[27], thread.ts_64, ts);
        case PLCRASH_ARM64_X28: return THREAD_STATE_GET(x[28], thread.ts_64, ts);
        case PLCRASH_ARM64_FP: return THREAD_STATE_GET_PTR(fp, thread.ts_64, ts);
        case PLCRASH_ARM64_SP: return THREAD_STATE_GET_PTR(sp, thread.ts_64, ts);
        case PLCRASH_ARM64_LR: return THREAD_STATE_GET_FPTR(lr, thread.ts_64, ts);
        case PLCRASH_ARM64_PC: return THREAD_STATE_GET_FPTR(pc, thread.ts_64, ts);
        case PLCRASH_ARM64_CPSR: return THREAD_STATE_GET(cpsr, thread.ts_64, ts);
        default: __builtin_trap();
    }
}

// PLCrashAsyncThread API
plcrash_greg_t plcrash_async_thread_state_get_reg (const plcrash_async_thread_state_t *ts, plcrash_regnum_t regnum) {
    if (ts->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        return plcrash_async_thread_state_get_reg_32(ts, regnum);
    } else {
        return plcrash_async_thread_state_get_reg_64(ts, regnum);
    }
}

static inline void plcrash_async_thread_state_set_reg_32 (plcrash_async_thread_state_t *ts, plcrash_regnum_t regnum, plcrash_greg_t reg) {
    switch (regnum) {
        case PLCRASH_ARM_R0: THREAD_STATE_SET(r[0], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R1: THREAD_STATE_SET(r[1], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R2: THREAD_STATE_SET(r[2], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R3: THREAD_STATE_SET(r[3], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R4: THREAD_STATE_SET(r[4], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R5: THREAD_STATE_SET(r[5], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R6: THREAD_STATE_SET(r[6], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R7: THREAD_STATE_SET(r[7], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R8: THREAD_STATE_SET(r[8], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R9: THREAD_STATE_SET(r[9], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R10: THREAD_STATE_SET(r[10], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R11: THREAD_STATE_SET(r[11], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_R12: THREAD_STATE_SET(r[12], thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_SP: THREAD_STATE_SET(sp, thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_LR: THREAD_STATE_SET(lr, thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_PC: THREAD_STATE_SET(pc, thread.ts_32, ts, regnum, (uint32_t)reg); break;
        case PLCRASH_ARM_CPSR: THREAD_STATE_SET(cpsr, thread.ts_32, ts, regnum, (uint32_t)reg); break;
        default: __builtin_trap(); // Unsupported register
    }
}

static inline void plcrash_async_thread_state_set_reg_64 (plcrash_async_thread_state_t *ts, plcrash_regnum_t regnum, plcrash_greg_t reg) {
    switch (regnum) {
        case PLCRASH_ARM64_X0: THREAD_STATE_SET(x[0], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X1: THREAD_STATE_SET(x[1], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X2: THREAD_STATE_SET(x[2], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X3: THREAD_STATE_SET(x[3], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X4: THREAD_STATE_SET(x[4], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X5: THREAD_STATE_SET(x[5], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X6: THREAD_STATE_SET(x[6], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X7: THREAD_STATE_SET(x[7], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X8: THREAD_STATE_SET(x[8], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X9: THREAD_STATE_SET(x[9], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X10: THREAD_STATE_SET(x[10], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X11: THREAD_STATE_SET(x[11], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X12: THREAD_STATE_SET(x[12], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X13: THREAD_STATE_SET(x[13], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X14: THREAD_STATE_SET(x[14], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X15: THREAD_STATE_SET(x[15], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X16: THREAD_STATE_SET(x[16], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X17: THREAD_STATE_SET(x[17], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X18: THREAD_STATE_SET(x[18], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X19: THREAD_STATE_SET(x[19], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X20: THREAD_STATE_SET(x[20], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X21: THREAD_STATE_SET(x[21], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X22: THREAD_STATE_SET(x[22], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X23: THREAD_STATE_SET(x[23], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X24: THREAD_STATE_SET(x[24], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X25: THREAD_STATE_SET(x[25], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X26: THREAD_STATE_SET(x[26], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X27: THREAD_STATE_SET(x[27], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_X28: THREAD_STATE_SET(x[28], thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_FP: THREAD_STATE_SET_PTR(fp, thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_SP: THREAD_STATE_SET_PTR(sp, thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_LR: THREAD_STATE_SET_FPTR(lr, thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_PC: THREAD_STATE_SET_FPTR(pc, thread.ts_64, ts, regnum, reg); break;
        case PLCRASH_ARM64_CPSR: THREAD_STATE_SET(cpsr, thread.ts_64, ts, regnum, (uint32_t)reg); break;
        default: __builtin_trap();
    }
}

// PLCrashAsyncThread API
void plcrash_async_thread_state_set_reg (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum, plcrash_greg_t reg) {
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        plcrash_async_thread_state_set_reg_32(thread_state, regnum, reg);
    } else {
        plcrash_async_thread_state_set_reg_64(thread_state, regnum, reg);
    }
}

// PLCrashAsyncThread API
size_t plcrash_async_thread_state_get_reg_count (const plcrash_async_thread_state_t *thread_state) {
    /* Last is an index value, so increment to get the count */
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        return PLCRASH_ARM_LAST_REG+1;
    } else {
        return PLCRASH_ARM64_LAST_REG+1;
    }
}

static inline char const *plcrash_async_thread_state_get_reg_name_32 (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum) {
    switch ((plcrash_arm_regnum_t) regnum) {
        case PLCRASH_ARM_R0: return "r0";
        case PLCRASH_ARM_R1: return "r1";
        case PLCRASH_ARM_R2: return "r2";
        case PLCRASH_ARM_R3: return "r3";
        case PLCRASH_ARM_R4: return "r4";
        case PLCRASH_ARM_R5: return "r5";
        case PLCRASH_ARM_R6: return "r6";
        case PLCRASH_ARM_R7: return "r7";
        case PLCRASH_ARM_R8: return "r8";
        case PLCRASH_ARM_R9: return "r9";
        case PLCRASH_ARM_R10: return "r10";
        case PLCRASH_ARM_R11: return "r11";
        case PLCRASH_ARM_R12: return "r12";
        case PLCRASH_ARM_SP: return "sp";
        case PLCRASH_ARM_LR: return "lr";
        case PLCRASH_ARM_PC: return "pc";
        case PLCRASH_ARM_CPSR: return "cpsr";
    }

    /* Unsupported register is an implementation error (checked in unit tests) */
    PLCF_DEBUG("Missing register name for register id: %d", regnum);
    abort();
}

static inline char const *plcrash_async_thread_state_get_reg_name_64 (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum) {
    switch ((plcrash_arm64_regnum_t) regnum) {
        case PLCRASH_ARM64_X0: return "x0";
        case PLCRASH_ARM64_X1: return "x1";
        case PLCRASH_ARM64_X2: return "x2";
        case PLCRASH_ARM64_X3: return "x3";
        case PLCRASH_ARM64_X4: return "x4";
        case PLCRASH_ARM64_X5: return "x5";
        case PLCRASH_ARM64_X6: return "x6";
        case PLCRASH_ARM64_X7: return "x7";
        case PLCRASH_ARM64_X8: return "x8";
        case PLCRASH_ARM64_X9: return "x9";
        case PLCRASH_ARM64_X10: return "x10";
        case PLCRASH_ARM64_X11: return "x11";
        case PLCRASH_ARM64_X12: return "x12";
        case PLCRASH_ARM64_X13: return "x13";
        case PLCRASH_ARM64_X14: return "x14";
        case PLCRASH_ARM64_X15: return "x15";
        case PLCRASH_ARM64_X16: return "x16";
        case PLCRASH_ARM64_X17: return "x17";
        case PLCRASH_ARM64_X18: return "x18";
        case PLCRASH_ARM64_X19: return "x19";
        case PLCRASH_ARM64_X20: return "x20";
        case PLCRASH_ARM64_X21: return "x21";
        case PLCRASH_ARM64_X22: return "x22";
        case PLCRASH_ARM64_X23: return "x23";
        case PLCRASH_ARM64_X24: return "x24";
        case PLCRASH_ARM64_X25: return "x25";
        case PLCRASH_ARM64_X26: return "x26";
        case PLCRASH_ARM64_X27: return "x27";
        case PLCRASH_ARM64_X28: return "x28";
        case PLCRASH_ARM64_FP: return "fp";
        case PLCRASH_ARM64_SP: return "sp";
        case PLCRASH_ARM64_LR: return "lr";
        case PLCRASH_ARM64_PC: return "pc";
        case PLCRASH_ARM64_CPSR: return "cpsr";
    }

    /* Unsupported register is an implementation error (checked in unit tests) */
    PLCF_DEBUG("Missing register name for register id: %d", regnum);
    abort();
}

// PLCrashAsyncThread API
char const *plcrash_async_thread_state_get_reg_name (const plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum) {
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        return plcrash_async_thread_state_get_reg_name_32(thread_state, regnum);
    } else {
        return plcrash_async_thread_state_get_reg_name_64(thread_state, regnum);
    }
}

// PLCrashAsyncThread API
void plcrash_async_thread_state_clear_volatile_regs (plcrash_async_thread_state_t *thread_state) {
    const plcrash_regnum_t *table;
    size_t table_count = 0;
    
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        table = arm_nonvolatile_registers;
        table_count = sizeof(arm_nonvolatile_registers) / sizeof(arm_nonvolatile_registers[0]);
    } else {
        table = arm64_nonvolatile_registers;
        table_count = sizeof(arm64_nonvolatile_registers) / sizeof(arm64_nonvolatile_registers[0]);
    }
    
    size_t reg_count = plcrash_async_thread_state_get_reg_count(thread_state);
    for (size_t reg = 0; reg < reg_count; reg++) {
        /* Skip unset registers */
        if (!plcrash_async_thread_state_has_reg(thread_state, (uint32_t)reg))
            continue;
        
        /* Check for the register in the preservation table */
        bool preserved = false;
        for (size_t i = 0; i < table_count; i++) {
            if (table[i] == reg) {
                preserved = true;
                break;
            }
        }
        
        /* If not preserved, clear */
        if (!preserved)
            plcrash_async_thread_state_clear_reg(thread_state, (uint32_t)reg);
    }
}

// PLCrashAsyncThread API
bool plcrash_async_thread_state_map_reg_to_dwarf (plcrash_async_thread_state_t *thread_state, plcrash_regnum_t regnum, uint64_t *dwarf_reg) {
    const struct dwarf_register_table *table;
    size_t table_count = 0;
    
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        table = arm_dwarf_table;
        table_count = sizeof(arm_dwarf_table) / sizeof(arm_dwarf_table[0]);
    } else {
        table = arm64_dwarf_table;
        table_count = sizeof(arm64_dwarf_table) / sizeof(arm64_dwarf_table[0]);
    }
    
    for (size_t i = 0; i < table_count; i++) {
        if (table[i].regnum == regnum) {
            *dwarf_reg = table[i].dwarf_value;
            return true;
        }
    }
    
    /* Unknown register.  */
    return false;
}

// PLCrashAsyncThread API
bool plcrash_async_thread_state_map_dwarf_to_reg (const plcrash_async_thread_state_t *thread_state, uint64_t dwarf_reg, plcrash_regnum_t *regnum) {
    const struct dwarf_register_table *table;
    size_t table_count = 0;
    
    if (thread_state->arm_state.thread.ash.flavor == ARM_THREAD_STATE32) {
        table = arm_dwarf_table;
        table_count = sizeof(arm_dwarf_table) / sizeof(arm_dwarf_table[0]);
    } else {
        table = arm64_dwarf_table;
        table_count = sizeof(arm64_dwarf_table) / sizeof(arm64_dwarf_table[0]);
    }
    
    for (size_t i = 0; i < table_count; i++) {
        if (table[i].dwarf_value == dwarf_reg) {
            *regnum = table[i].regnum;
            return true;
        }
    }
    
    /* Unknown DWARF register.  */
    return false;
}

#endif /* __arm__ || __arm64__ */
