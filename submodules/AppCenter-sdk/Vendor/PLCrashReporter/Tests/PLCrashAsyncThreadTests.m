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

#import "SenTestCompat.h"

#import "PLCrashAsyncThread.h"
#import "PLCrashTestThread.h"

#import <pthread.h>

@interface PLCrashAsyncThreadTests : SenTestCase {
@private
    plcrash_test_thread_t _thr_args;
}

@end

@implementation PLCrashAsyncThreadTests


- (void) setUp {
    plcrash_test_thread_spawn(&_thr_args);
}

- (void) tearDown {
    plcrash_test_thread_stop(&_thr_args);
}

- (void) testGetRegName {
    plcrash_async_thread_state_t ts;
    plcrash_async_thread_state_mach_thread_init(&ts, pthread_mach_thread_np(_thr_args.thread));
    
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&ts); i++) {
        const char *name = plcrash_async_thread_state_get_reg_name(&ts, i);
        STAssertNotNULL(name, @"Register name for %d is NULL", i);
        STAssertNotEquals((size_t)0, strlen(name), @"Register name for %d is 0 length", i);
        STAssertNotEquals((uint32_t)PLCRASH_REG_INVALID, (uint32_t)i, @"Register name is assigned to invalid pseudo-register");
    }
}

- (void) testClearVolatileRegisters {
    plcrash_async_thread_state_t ts;
    plcrash_async_thread_state_mach_thread_init(&ts, pthread_mach_thread_np(_thr_args.thread));

    /* Verify that clearing volatile registers clears some, but not all, registers */
    size_t live_count = 0;
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&ts); i++) {
        if (plcrash_async_thread_state_has_reg(&ts, i))
            live_count++;
    };
    
    plcrash_async_thread_state_clear_volatile_regs(&ts);

    size_t nv_count = 0;
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&ts); i++) {
        if (plcrash_async_thread_state_has_reg(&ts, i))
            nv_count++;
    };
    
    /* In theory, these tests could fail if ALL or NONE registers are callee-preserved. I can't think of an ABI
     * on the planet where that is true, but in such a case, this test will fail and require updating */
    STAssertLessThan(nv_count, live_count, @"Failed to clear any registers");
    STAssertGreaterThan(nv_count, (size_t)0, @"Cleared all registers");
    
#define REQ_REG(_reg) STAssertTrue(plcrash_async_thread_state_has_reg(&ts, _reg), @"Missing required register");
    
#if defined(__arm64__)
    REQ_REG(PLCRASH_ARM64_X19);
    REQ_REG(PLCRASH_ARM64_X20);
    REQ_REG(PLCRASH_ARM64_X21);
    REQ_REG(PLCRASH_ARM64_X22);
    REQ_REG(PLCRASH_ARM64_X23);
    REQ_REG(PLCRASH_ARM64_X24);
    REQ_REG(PLCRASH_ARM64_X25);
    REQ_REG(PLCRASH_ARM64_X26);
    REQ_REG(PLCRASH_ARM64_X27);
    REQ_REG(PLCRASH_ARM64_X28);
#ifdef __APPLE__
    REQ_REG(PLCRASH_ARM64_FP);
#else
#error Define OS frame pointer behavior as per AAPCS64 Section 5.2.3
#endif
    STAssertEquals((size_t)11, nv_count, @"Incorrect number of registers preserved");
#elif defined(__arm__)
    REQ_REG(PLCRASH_ARM_R4);
    REQ_REG(PLCRASH_ARM_R5);
    REQ_REG(PLCRASH_ARM_R6);
    REQ_REG(PLCRASH_ARM_R7);
    REQ_REG(PLCRASH_ARM_R8);
    REQ_REG(PLCRASH_ARM_R10);
    REQ_REG(PLCRASH_ARM_R11);
    STAssertEquals((size_t)7, nv_count, @"Incorrect number of registers preserved");
#elif defined(__i386__)
    REQ_REG(PLCRASH_X86_EBX);
    REQ_REG(PLCRASH_X86_EBP);
    REQ_REG(PLCRASH_X86_ESI);
    REQ_REG(PLCRASH_X86_EDI);
    REQ_REG(PLCRASH_X86_ESP);
    STAssertEquals((size_t)5, nv_count, @"Incorrect number of registers preserved");
#elif defined(__x86_64__)
    REQ_REG(PLCRASH_X86_64_RBX);
    REQ_REG(PLCRASH_X86_64_RSP);
    REQ_REG(PLCRASH_X86_64_RBP);
    REQ_REG(PLCRASH_X86_64_R12);
    REQ_REG(PLCRASH_X86_64_R13);
    REQ_REG(PLCRASH_X86_64_R14);
    REQ_REG(PLCRASH_X86_64_R15);
    STAssertEquals((size_t)7, nv_count, @"Incorrect number of registers preserved");
#else
#error Add architecture support
#endif
    
#undef REQ_REG
}

- (void) testGetSetRegister {
    plcrash_async_thread_state_t ts;
    plcrash_async_thread_state_mach_thread_init(&ts, pthread_mach_thread_np(_thr_args.thread));
    size_t regcount = plcrash_async_thread_state_get_reg_count(&ts);

    /* Verify that all registers are marked as available */
    STAssertTrue(__builtin_popcountl(ts.valid_regs) >= regcount, @"Incorrect number of 1 bits");
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&ts); i++) {
        STAssertTrue(plcrash_async_thread_state_has_reg(&ts, i), @"Register should be marked as set");
    }

    /* Clear all registers */
    plcrash_async_thread_state_clear_all_regs(&ts);
    STAssertEquals(ts.valid_regs, (uint64_t)0, @"Registers not marked as clear");

    /* Now set+get each individually */
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&ts); i++) {
        plcrash_greg_t reg;
        
        plcrash_async_thread_state_set_reg(&ts, i, 5);
        reg = plcrash_async_thread_state_get_reg(&ts, i);
        STAssertEquals(reg, (plcrash_greg_t)5, @"Unexpected register value");
        
        STAssertTrue(plcrash_async_thread_state_has_reg(&ts, i), @"Register should be marked as set");
        STAssertEquals(__builtin_popcountl(ts.valid_regs), i+1, @"Incorrect number of 1 bits");
    }
}

/**
 * Test mapping of DWARF register values.
 */
- (void) testMapDwarfRegister {
    plcrash_async_thread_state_t ts;
    
#define CHECKREG(plreg, dwreg) do { \
    plcrash_regnum_t regnum; \
    STAssertTrue(plcrash_async_thread_state_map_dwarf_to_reg(&ts, dwreg, &regnum), @"Failed to map DWARF register"); \
    STAssertEquals((plcrash_regnum_t)plreg, regnum, @"Incorrect register mapping for " # plreg); \
\
    uint64_t dw_result; \
    STAssertTrue(plcrash_async_thread_state_map_reg_to_dwarf(&ts, plreg, &dw_result), @"Failed to map register to DWARF"); \
    STAssertEquals((uint64_t)dwreg, dw_result, @"Native register number does not map back to the expected DWARF register number"); \
} while (0)

#if PLCRASH_ASYNC_THREAD_X86_SUPPORT
    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_X86), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    CHECKREG(PLCRASH_X86_EAX, 0);
    CHECKREG(PLCRASH_X86_ECX, 1);
    CHECKREG(PLCRASH_X86_EDX, 2);
    CHECKREG(PLCRASH_X86_EBX, 3);
    CHECKREG(PLCRASH_X86_EBP, 4);
    CHECKREG(PLCRASH_X86_ESP, 5);
    CHECKREG(PLCRASH_X86_ESI, 6);
    CHECKREG(PLCRASH_X86_EDI, 7);
    CHECKREG(PLCRASH_X86_EIP, 8);

    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_X86_64), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    CHECKREG(PLCRASH_X86_64_RAX, 0);
    CHECKREG(PLCRASH_X86_64_RDX, 1);
    CHECKREG(PLCRASH_X86_64_RCX, 2);
    CHECKREG(PLCRASH_X86_64_RBX, 3);
    CHECKREG(PLCRASH_X86_64_RSI, 4);
    CHECKREG(PLCRASH_X86_64_RDI, 5);
    CHECKREG(PLCRASH_X86_64_RBP, 6);
    CHECKREG(PLCRASH_X86_64_RSP, 7);

    CHECKREG(PLCRASH_X86_64_R8, 8);
    CHECKREG(PLCRASH_X86_64_R9, 9);
    CHECKREG(PLCRASH_X86_64_R10, 10);
    CHECKREG(PLCRASH_X86_64_R11, 11);
    CHECKREG(PLCRASH_X86_64_R12, 12);
    CHECKREG(PLCRASH_X86_64_R13, 13);
    CHECKREG(PLCRASH_X86_64_R14, 14);
    CHECKREG(PLCRASH_X86_64_R15, 15);
    
    CHECKREG(PLCRASH_X86_64_RFLAGS, 49);

    CHECKREG(PLCRASH_X86_64_CS, 51);
    CHECKREG(PLCRASH_X86_64_FS, 54);
    CHECKREG(PLCRASH_X86_64_GS, 55);

#endif /* PLCRASH_ASYNC_THREAD_X86_SUPPORT */

#if PLCRASH_ASYNC_THREAD_ARM_SUPPORT
    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_ARM), PLCRASH_ESUCCESS, @"Failed to initialize thread state");

    CHECKREG(PLCRASH_ARM_R0, 0);
    CHECKREG(PLCRASH_ARM_R1, 1);
    CHECKREG(PLCRASH_ARM_R2, 2);
    CHECKREG(PLCRASH_ARM_R3, 3);
    CHECKREG(PLCRASH_ARM_R4, 4);
    CHECKREG(PLCRASH_ARM_R5, 5);
    CHECKREG(PLCRASH_ARM_R6, 6);
    CHECKREG(PLCRASH_ARM_R7, 7);
    CHECKREG(PLCRASH_ARM_R8, 8);
    CHECKREG(PLCRASH_ARM_R9, 9);
    CHECKREG(PLCRASH_ARM_R10, 10);
    CHECKREG(PLCRASH_ARM_R11, 11);
    CHECKREG(PLCRASH_ARM_R12, 12);
    CHECKREG(PLCRASH_ARM_SP, 13);
    CHECKREG(PLCRASH_ARM_LR, 14);
    CHECKREG(PLCRASH_ARM_PC, 15);
#endif
    
#undef CHECKREG
}

/* Test plcrash_async_thread_state_init() */
- (void) testEmptyInit {
    plcrash_async_thread_state_t ts;

#if PLCRASH_ASYNC_THREAD_X86_SUPPORT
    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_X86), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    STAssertEquals(ts.x86_state.thread.tsh.count, (int)x86_THREAD_STATE32_COUNT, @"Incorrect count");
    STAssertEquals(ts.x86_state.thread.tsh.flavor, x86_THREAD_STATE32, @"Incorrect flavor");
    STAssertEquals(ts.x86_state.exception.esh.count, (int)x86_EXCEPTION_STATE32_COUNT, @"Incorrect count");
    STAssertEquals(ts.x86_state.exception.esh.flavor, x86_EXCEPTION_STATE32, @"Incorrect flavor");
    STAssertEquals(ts.stack_direction, PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN, @"Incorrect stack direction");
    STAssertEquals(ts.greg_size, (size_t)4, @"Incorrect gpreg size");

    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_X86_64), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    STAssertEquals(ts.x86_state.thread.tsh.count, (int)x86_THREAD_STATE64_COUNT, @"Incorrect count");
    STAssertEquals(ts.x86_state.thread.tsh.flavor, x86_THREAD_STATE64, @"Incorrect flavor");
    STAssertEquals(ts.x86_state.exception.esh.count, (int)x86_EXCEPTION_STATE64_COUNT, @"Incorrect count");
    STAssertEquals(ts.x86_state.exception.esh.flavor, x86_EXCEPTION_STATE64, @"Incorrect flavor");
    STAssertEquals(ts.stack_direction, PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN, @"Incorrect stack direction");
    STAssertEquals(ts.greg_size, (size_t)8, @"Incorrect gpreg size");
#endif /* PLCRASH_ASYNC_THREAD_X86_SUPPORT */

#if PLCRASH_ASYNC_THREAD_ARM_SUPPORT
    STAssertEquals(plcrash_async_thread_state_init(&ts, CPU_TYPE_ARM), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    STAssertEquals(ts.stack_direction, PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN, @"Incorrect stack direction");
    STAssertEquals(ts.greg_size, (size_t)4, @"Incorrect gpreg size");
#endif
}

/* Test plcrash_async_thread_state_ucontext_init() */
- (void) testThreadStateContextInit {
    plcrash_async_thread_state_t thr_state;
    pl_mcontext_t mctx;

    memset(&mctx, 'A', sizeof(mctx));
    
    plcrash_async_thread_state_mcontext_init(&thr_state, &mctx);
    
    /* Verify that all registers are marked as available */
    size_t regcount = plcrash_async_thread_state_get_reg_count(&thr_state);
    STAssertTrue(__builtin_popcountl(thr_state.valid_regs) >= regcount, @"Incorrect number of 1 bits");
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&thr_state); i++) {
        STAssertTrue(plcrash_async_thread_state_has_reg(&thr_state, i), @"Register should be marked as set");
    }
    
#if defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT) && defined(__LP64__)
    STAssertTrue(memcmp(&thr_state.arm_state.thread.ts_64, &mctx.__ss, sizeof(thr_state.arm_state.thread.ts_64)) == 0, @"Incorrectly copied");

#elif defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT)
    STAssertTrue(memcmp(&thr_state.arm_state.thread.ts_32, &mctx.__ss, sizeof(thr_state.arm_state.thread.ts_32)) == 0, @"Incorrectly copied");
    
#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT) && defined(__LP64__)
    STAssertEquals(thr_state.x86_state.thread.tsh.count, (int)x86_THREAD_STATE64_COUNT, @"Incorrect thread state count for a 64-bit system");
    STAssertEquals(thr_state.x86_state.thread.tsh.flavor, (int)x86_THREAD_STATE64, @"Incorrect thread state flavor for a 64-bit system");
    STAssertTrue(memcmp(&thr_state.x86_state.thread.uts.ts64, &mctx.__ss, sizeof(thr_state.x86_state.thread.uts.ts64)) == 0, @"Incorrectly copied");
    
    STAssertEquals(thr_state.x86_state.exception.esh.count, (int) x86_EXCEPTION_STATE64_COUNT, @"Incorrect thread state count for a 64-bit system");
    STAssertEquals(thr_state.x86_state.exception.esh.flavor, (int) x86_EXCEPTION_STATE64, @"Incorrect thread state flavor for a 64-bit system");
    STAssertTrue(memcmp(&thr_state.x86_state.exception.ues.es64, &mctx.__es, sizeof(thr_state.x86_state.exception.ues.es64)) == 0, @"Incorrectly copied");
#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT)
    STAssertEquals(thr_state.x86_state.thread.tsh.count, (int)x86_THREAD_STATE32_COUNT, @"Incorrect thread state count for a 32-bit system");
    STAssertEquals(thr_state.x86_state.thread.tsh.flavor, (int)x86_THREAD_STATE32, @"Incorrect thread state flavor for a 32-bit system");
    STAssertTrue(memcmp(&thr_state.x86_state.thread.uts.ts32, &mctx.__ss, sizeof(thr_state.x86_state.thread.uts.ts32)) == 0, @"Incorrectly copied");
    
    STAssertEquals(thr_state.x86_state.exception.esh.count, (int)x86_EXCEPTION_STATE32_COUNT, @"Incorrect thread state count for a 32-bit system");
    STAssertEquals(thr_state.x86_state.exception.esh.flavor, (int)x86_EXCEPTION_STATE32, @"Incorrect thread state flavor for a 32-bit system");
    STAssertTrue(memcmp(&thr_state.x86_state.exception.ues.es32, &mctx.__es, sizeof(thr_state.x86_state.exception.ues.es32)) == 0, @"Incorrectly copied");
#else
#error Add platform support
#endif
}

/* Test plframe_thread_state_thread_init() */
- (void) testThreadStateThreadInit {
    plcrash_async_thread_state_t thr_state;
    mach_msg_type_number_t state_count;
    thread_t thr;
    
    /* Spawn a test thread */
    thr = pthread_mach_thread_np(_thr_args.thread);
    thread_suspend(thr);

    /* Fetch the thread state */
    STAssertEquals(plcrash_async_thread_state_mach_thread_init(&thr_state, thr), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    
    /* Verify that all registers are marked as available */
    size_t regcount = plcrash_async_thread_state_get_reg_count(&thr_state);
    STAssertTrue(__builtin_popcountl(thr_state.valid_regs) >= regcount, @"Incorrect number of 1 bits");
    for (int i = 0; i < plcrash_async_thread_state_get_reg_count(&thr_state); i++) {
        STAssertTrue(plcrash_async_thread_state_has_reg(&thr_state, i), @"Register should be marked as set");
    }

    /* Test the results */
#if defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT) && defined(__LP64__)
    arm_thread_state64_t local_thr_state;
    state_count = ARM_THREAD_STATE64_COUNT;
    
    STAssertEquals(thread_get_state(thr, ARM_THREAD_STATE64, (thread_state_t) &local_thr_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.arm_state.thread.ts_64, &local_thr_state, sizeof(thr_state.arm_state.thread.ts_64)) == 0, @"Incorrectly copied");

#elif defined(PLCRASH_ASYNC_THREAD_ARM_SUPPORT)
    arm_thread_state_t local_thr_state;
    state_count = ARM_THREAD_STATE_COUNT;
    
    STAssertEquals(thread_get_state(thr, ARM_THREAD_STATE, (thread_state_t) &local_thr_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.arm_state.thread.ts_32, &local_thr_state, sizeof(thr_state.arm_state.thread.ts_32)) == 0, @"Incorrectly copied");
    
#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT) && defined(__LP64__)
    state_count = x86_THREAD_STATE64_COUNT;
    x86_thread_state64_t local_thr_state;
    STAssertEquals(thread_get_state(thr, x86_THREAD_STATE64, (thread_state_t) &local_thr_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.x86_state.thread.uts.ts64, &local_thr_state, sizeof(thr_state.x86_state.thread.uts.ts64)) == 0, @"Incorrectly copied");
    STAssertEquals(thr_state.x86_state.thread.tsh.count, (int)x86_THREAD_STATE64_COUNT, @"Incorrect thread state count for a 64-bit system");
    STAssertEquals(thr_state.x86_state.thread.tsh.flavor, (int)x86_THREAD_STATE64, @"Incorrect thread state flavor for a 64-bit system");
    
    state_count = x86_EXCEPTION_STATE64_COUNT;
    x86_exception_state64_t local_exc_state;
    STAssertEquals(thread_get_state(thr, x86_EXCEPTION_STATE64, (thread_state_t) &local_exc_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.x86_state.exception.ues.es64, &local_exc_state, sizeof(thr_state.x86_state.exception.ues.es64)) == 0, @"Incorrectly copied");
    STAssertEquals(thr_state.x86_state.exception.esh.count, (int) x86_EXCEPTION_STATE64_COUNT, @"Incorrect thread state count for a 64-bit system");
    STAssertEquals(thr_state.x86_state.exception.esh.flavor, (int) x86_EXCEPTION_STATE64, @"Incorrect thread state flavor for a 64-bit system");
    
#elif defined(PLCRASH_ASYNC_THREAD_X86_SUPPORT)
    state_count = x86_THREAD_STATE32_COUNT;
    x86_thread_state32_t local_thr_state;
    STAssertEquals(thread_get_state(thr, x86_THREAD_STATE32, (thread_state_t) &local_thr_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.x86_state.thread.uts.ts32, &local_thr_state, sizeof(thr_state.x86_state.thread.uts.ts32)) == 0, @"Incorrectly copied");
    STAssertEquals(thr_state.x86_state.thread.tsh.count, (int)x86_THREAD_STATE32_COUNT, @"Incorrect thread state count for a 64-bit system");
    STAssertEquals(thr_state.x86_state.thread.tsh.flavor, (int)x86_THREAD_STATE32, @"Incorrect thread state flavor for a 32-bit system");
    
    state_count = x86_EXCEPTION_STATE32_COUNT;
    x86_exception_state32_t local_exc_state;
    STAssertEquals(thread_get_state(thr, x86_EXCEPTION_STATE32, (thread_state_t) &local_exc_state, &state_count), KERN_SUCCESS, @"Failed to fetch thread state");
    STAssertTrue(memcmp(&thr_state.x86_state.exception.ues.es32, &local_exc_state, sizeof(thr_state.x86_state.exception.ues.es32)) == 0, @"Incorrectly copied");
    STAssertEquals(thr_state.x86_state.exception.esh.count, (int) x86_EXCEPTION_STATE32_COUNT, @"Incorrect thread state count for a 32-bit system");
    STAssertEquals(thr_state.x86_state.exception.esh.flavor, (int) x86_EXCEPTION_STATE32, @"Incorrect thread state flavor for a 32-bit system");
#else
#error Add platform support
#endif
    
    /* Verify the platform metadata */
#ifdef __LP64__
    STAssertEquals(plcrash_async_thread_state_get_greg_size(&thr_state), (size_t)8, @"Incorrect greg size");
#else
    STAssertEquals(plcrash_async_thread_state_get_greg_size(&thr_state), (size_t)4, @"Incorrect greg size");
#endif

#if defined(__arm64__) || defined(__arm__) || defined(__i386__) || defined(__x86_64__)
    // This is true on just about every modern platform
    STAssertEquals(plcrash_async_thread_state_get_stack_direction(&thr_state), PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN, @"Incorrect stack growth direction");
#else
#error Add platform support!
#endif

    /* Clean up */
    thread_resume(thr);
}

__attribute__ ((noinline)) static uintptr_t getPC () {
    return (uintptr_t) __builtin_return_address(0);
}

static plcrash_error_t write_current_thread_callback (plcrash_async_thread_state_t *state, void *context) {
    plcrash_async_thread_state_t *result = context;
    plcrash_async_thread_state_copy(result, state);
    return PLCRASH_ESUCCESS;
}

/**
 * Test fetching the current thread's state
 */
- (void) testFetchCurrentThreadState {
    /* Write the crash report */
    plcrash_async_thread_state_t thr_state;
    plcrash_error_t ret = plcrash_async_thread_state_current(write_current_thread_callback, &thr_state);
    uintptr_t expectedPC = getPC();
    
    STAssertEquals(PLCRASH_ESUCCESS, ret, @"Crash log failed");
    
    /* Validate PC. This check is inexact and fragile, as otherwise we would need to carefully instrument the
     * call to plcrash_log_writer_write_curthread() in order to determine the exact PC value. */
    STAssertTrue(expectedPC - plcrash_async_thread_state_get_reg(&thr_state, PLCRASH_REG_IP) <= 40, @"PC value not within reasonable range");
    
    /* Fetch stack info for validation */
    uint8_t *stackaddr = pthread_get_stackaddr_np(pthread_self());
    size_t stacksize = pthread_get_stacksize_np(pthread_self());
    
    /* Verify that the stack pointer is sane */
    plcrash_greg_t sp = plcrash_async_thread_state_get_reg(&thr_state, PLCRASH_REG_SP);
    if (plcrash_async_thread_state_get_stack_direction(&thr_state) == PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN) {
        STAssertTrue((uint8_t *)sp < stackaddr && (uint8_t *) sp >= stackaddr-stacksize, @"Stack pointer outside of stack range");
    } else {
        STAssertTrue((uint8_t *)sp > stackaddr && (uint8_t *) sp < stackaddr+stacksize, @"Stack pointer outside of stack range");
    }
    
    /* Architecture-specific validations */
#if __arm__ || __arm64__
#  if __arm__
    plcrash_regnum_t lrnum = PLCRASH_ARM_LR;
#  else
    plcrash_regnum_t lrnum = PLCRASH_ARM64_LR;
#  endif
    
    /* Validate LR */
    void *retaddr = __builtin_return_address(0);
    uintptr_t lr = plcrash_async_thread_state_get_reg(&thr_state, lrnum);
    STAssertEquals(retaddr, (void *)lr, @"Incorrect lr: %p", (void *) lr);
#endif
}

/**
 * Test copying of a thread state.
 */
- (void) testThreadStateCopy {
    plcrash_async_thread_state_t thr_state;
    thread_t thr;
    
    /* Spawn a test thread */
    thr = pthread_mach_thread_np(_thr_args.thread);
    thread_suspend(thr);
    
    /* Fetch the thread state */
    STAssertEquals(plcrash_async_thread_state_mach_thread_init(&thr_state, thr), PLCRASH_ESUCCESS, @"Failed to initialize thread state");
    
    /* Try a copy */
    plcrash_async_thread_state_t thr_copy;
    plcrash_async_thread_state_copy(&thr_copy, &thr_state);
    STAssertEquals(memcmp(&thr_copy, &thr_state, sizeof(thr_copy)), 0, @"Did not correctly copy thread state");
    
    /* Clean up */
    thread_resume(thr);
}

@end
