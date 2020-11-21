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

#ifndef PLCRASH_ASYNC_THREAD_ARM_H
#define PLCRASH_ASYNC_THREAD_ARM_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Bitmask to strip pointer authentication (PAC).
 */
#define ARM64_PTR_MASK 0x0000000FFFFFFFFF

#if defined(__arm__) || defined(__arm64__)

// Large enough for 64-bit or 32-bit
typedef uint64_t plcrash_pdef_greg_t;
typedef uint64_t plcrash_pdef_fpreg_t;

#endif /* __arm__ */

/**
 * @internal
 * Arm registers
 */
typedef enum {
    /*
     * General
     */
    
    /** Program counter (r15) */
    PLCRASH_ARM_PC = PLCRASH_REG_IP,
    
    /** Frame pointer */
    PLCRASH_ARM_R7 = PLCRASH_REG_FP,
    
    /* stack pointer (r13) */
    PLCRASH_ARM_SP = PLCRASH_REG_SP,

    PLCRASH_ARM_R0,
    PLCRASH_ARM_R1,
    PLCRASH_ARM_R2,
    PLCRASH_ARM_R3,
    PLCRASH_ARM_R4,
    PLCRASH_ARM_R5,
    PLCRASH_ARM_R6,
    // R7 is defined above
    PLCRASH_ARM_R8,
    PLCRASH_ARM_R9,
    PLCRASH_ARM_R10,
    PLCRASH_ARM_R11,
    PLCRASH_ARM_R12,
    
    /* link register (r14) */
    PLCRASH_ARM_LR,
    
    /** Current program status register */
    PLCRASH_ARM_CPSR,
    
    /** Last register */
    PLCRASH_ARM_LAST_REG = PLCRASH_ARM_CPSR
} plcrash_arm_regnum_t;
    
/**
 * @internal
 * ARM64 registers
 */
typedef enum {
    /*
     * General
     */
    
    /** Program counter */
    PLCRASH_ARM64_PC = PLCRASH_REG_IP,
    
    /** Frame pointer (x29) */
    PLCRASH_ARM64_FP = PLCRASH_REG_FP,
    
    /* stack pointer (x31) */
    PLCRASH_ARM64_SP = PLCRASH_REG_SP,
    
    PLCRASH_ARM64_X0,
    PLCRASH_ARM64_X1,
    PLCRASH_ARM64_X2,
    PLCRASH_ARM64_X3,
    PLCRASH_ARM64_X4,
    PLCRASH_ARM64_X5,
    PLCRASH_ARM64_X6,
    PLCRASH_ARM64_X7,
    PLCRASH_ARM64_X8,
    PLCRASH_ARM64_X9,
    PLCRASH_ARM64_X10,
    PLCRASH_ARM64_X11,
    PLCRASH_ARM64_X12,
    PLCRASH_ARM64_X13,
    PLCRASH_ARM64_X14,
    PLCRASH_ARM64_X15,
    PLCRASH_ARM64_X16,
    PLCRASH_ARM64_X17,
    PLCRASH_ARM64_X18,
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

    /* link register (x30) */
    PLCRASH_ARM64_LR,
    
    /** Current program status register */
    PLCRASH_ARM64_CPSR,
    
    /** Last register */
    PLCRASH_ARM64_LAST_REG = PLCRASH_ARM64_CPSR
} plcrash_arm64_regnum_t;

#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_THREAD_ARM_H */
