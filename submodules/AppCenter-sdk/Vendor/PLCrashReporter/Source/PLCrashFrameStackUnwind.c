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

#include "PLCrashFrameStackUnwind.h"
#include "PLCrashAsync.h"

/**
 * Fetch the next frame, assuming a valid frame pointer in @a cursor's current frame.
 *
 * @param task The task containing the target frame stack.
 * @param current_frame The current stack frame.
 * @param previous_frame The previous stack frame, or NULL if this is the first frame.
 * @param next_frame The new frame to be initialized.
 *
 * @return Returns PLFRAME_ESUCCESS on success, PLFRAME_ENOFRAME is no additional frames are available, or a standard plframe_error_t code if an error occurs.
 */
plframe_error_t plframe_cursor_read_frame_ptr (task_t task,
                                               plcrash_async_image_list_t *image_list,
                                               const plframe_stackframe_t *current_frame,
                                               const plframe_stackframe_t *previous_frame,
                                               plframe_stackframe_t *next_frame)
{
    /* Determine the appropriate type width for the target thread */
    bool x64 = plcrash_async_thread_state_get_greg_size(&current_frame->thread_state) == sizeof(uint64_t);
    union {
        uint64_t greg64[2];
        uint32_t greg32[2];
    } regs;
    void *dest;
    size_t len;

    if (x64) {
        dest = regs.greg64;
        len = sizeof(regs.greg64);
    } else {
        dest = regs.greg32;
        len = sizeof(regs.greg32);
    }

    /* Verify that we have a frame pointer to work with */
    if (!plcrash_async_thread_state_has_reg(&current_frame->thread_state, PLCRASH_REG_FP)) {
        PLCF_DEBUG("The frame pointer is unavailable, can't read saved register.")
        return PLFRAME_EBADFRAME;
    }

    /* Fetch the current frame's frame pointer */
    plcrash_greg_t fp = plcrash_async_thread_state_get_reg(&current_frame->thread_state, PLCRASH_REG_FP);
    
    /* A NULL FP means a terminated frame */
    if (fp == 0x0)
        return PLFRAME_ENOFRAME;
    
    /* Verify that the stack is growing in the right direction. */
    if (previous_frame != NULL && plcrash_async_thread_state_has_reg(&previous_frame->thread_state, PLCRASH_REG_FP)) {
        plcrash_greg_t prev_fp = plcrash_async_thread_state_get_reg(&previous_frame->thread_state, PLCRASH_REG_FP);

        plcrash_async_thread_stack_direction_t stack_direction = plcrash_async_thread_state_get_stack_direction(&current_frame->thread_state);
        if ((stack_direction == PLCRASH_ASYNC_THREAD_STACK_DIRECTION_DOWN && fp < prev_fp) ||
            (stack_direction == PLCRASH_ASYNC_THREAD_STACK_DIRECTION_UP && fp > prev_fp))
        {
            PLCF_DEBUG("Stack growing in wrong direction, terminating stack walk");
            return PLFRAME_EBADFRAME;
        }
    }

    /* Read the registers off the stack via the frame pointer */
    plcrash_greg_t new_fp;
    plcrash_greg_t new_pc;
    plcrash_error_t err;
    
    err = plcrash_async_task_memcpy(task, (pl_vm_address_t) fp, 0, dest, len);
    if (err != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to read frame: %d", err);
        return PLFRAME_EBADFRAME;
    }

    if (x64) {
        new_fp = regs.greg64[0];
        new_pc = regs.greg64[1];
    } else {
        new_fp = regs.greg32[0];
        new_pc = regs.greg32[1];
    }

    /* Initialize the new frame, deriving state from the previous frame. */
    *next_frame = *current_frame;

    plcrash_async_thread_state_clear_all_regs(&next_frame->thread_state);
    plcrash_async_thread_state_set_reg(&next_frame->thread_state, PLCRASH_REG_FP, new_fp);
    plcrash_async_thread_state_set_reg(&next_frame->thread_state, PLCRASH_REG_IP, new_pc);

    return PLFRAME_ESUCCESS;
}
