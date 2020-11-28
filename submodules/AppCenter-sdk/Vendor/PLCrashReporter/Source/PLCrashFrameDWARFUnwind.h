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

#ifndef PLCRASH_FRAME_DWARF_UNWIND_H
#define PLCRASH_FRAME_DWARF_UNWIND_H

#include "PLCrashFeatureConfig.h"
#include "PLCrashFrameWalker.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

#ifdef __cplusplus
extern "C" {
#endif


plframe_error_t plframe_cursor_read_dwarf_unwind (task_t task,
                                                  plcrash_async_image_list_t *image_list,
                                                  const plframe_stackframe_t *current_frame,
                                                  const plframe_stackframe_t *previous_frame,
                                                  plframe_stackframe_t *next_frame);

    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_FRAME_DWARF_UNWIND_H */
