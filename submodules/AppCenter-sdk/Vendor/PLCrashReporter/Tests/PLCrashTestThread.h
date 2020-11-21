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

#ifndef PLCRASH_ASYNC_TEST_THREAD_H
#define PLCRASH_ASYNC_TEST_THREAD_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @internal
 * @ingroup plcrash_test_thread
 * @{
 */

#include <pthread.h>

/**
 * @internal
 * State for test threads */
typedef struct plcrash_test_thread {
    /** Running test thread */
    pthread_t thread;
    
    /** Thread signaling lock */
    pthread_mutex_t lock;
    
    /** Thread signaling (used to inform waiting callee that thread is active) */
    pthread_cond_t cond;
} plcrash_test_thread_t;


void plcrash_test_thread_spawn (plcrash_test_thread_t *thread);
void plcrash_test_thread_stop (plcrash_test_thread_t *thread);

/*
 * @}
 */
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_TEST_THREAD_H */
