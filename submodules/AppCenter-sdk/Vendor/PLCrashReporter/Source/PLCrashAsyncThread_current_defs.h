/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
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

#ifndef PLCRASH_ASYNC_THREAD_CURRENT_DEFS_H
#define PLCRASH_ASYNC_THREAD_CURRENT_DEFS_H

#ifdef __cplusplus
extern "C" {
#endif

#if __x86_64__

/* sizeof(struct mcontext) */
#define PL_MCONTEXT_SIZE 712

#elif __i386__

/* sizeof(struct mcontext) */
#define PL_MCONTEXT_SIZE 600
    
#elif defined(__arm64__)

/* sizeof(struct mcontext64) */
#define PL_MCONTEXT_SIZE 816

#elif defined(__arm__)

/* sizeof(struct mcontext) */
#define PL_MCONTEXT_SIZE 340

#else

#error Unsupported Platform

#endif

#ifndef __ASSEMBLER__
plcrash_error_t plcrash_async_thread_state_current_stub (plcrash_async_thread_state_current_callback callback,
                                                        void *context,
                                                        pl_mcontext_t *mctx);
#endif

#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_THREAD_CURRENT_DEFS_H */
