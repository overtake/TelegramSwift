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
#import "PLCrashFrameStackUnwind.h"

struct stack_frame {
    uintptr_t fp;
    uintptr_t pc;
} __attribute__((packed));

/**
 * @internal
 *
 * This code tests stack-based frame unwinding. It currently assumes that the stack grows down (which is
 * true on the architectures we currently support, but TODO: this should be direction-neutral).
 */
@interface PLCrashFrameStackUnwindTests : SenTestCase {
@private
    plcrash_async_image_list_t _image_list;
}

@end

@implementation PLCrashFrameStackUnwindTests

- (void) setUp {
    plcrash_nasync_image_list_init(&_image_list, mach_task_self());
}

- (void) tearDown {
    plcrash_nasync_image_list_free(&_image_list);
}

/**
 * Verify that walking terminates with a NULL frame address.
 */
- (void) testNULLFrame {
    /* Set up test stack */
    struct stack_frame frames[] = {
        { .fp = (uintptr_t) &frames[1], .pc = 0x1 },
        { .fp = (uintptr_t) &frames[2], .pc = 0x2 },
        { .fp = (uintptr_t) 0x0,        .pc = 0x3 },
    };
    size_t frame_count = sizeof(frames) / sizeof(frames[0]);

    /* Configure thread state */
    plcrash_async_thread_state_t state;
    plcrash_async_thread_state_mach_thread_init(&state, pl_mach_thread_self());
    plcrash_async_thread_state_set_reg(&state, PLCRASH_REG_FP, frames[0].fp);
    plcrash_async_thread_state_set_reg(&state, PLCRASH_REG_IP, frames[0].pc);

    /* Let the plframe cursor API initialize our first frame */
    plframe_cursor_t cursor;
    plframe_cursor_init(&cursor, mach_task_self(), &state, &_image_list);
    
    /* Try walking the stack */
    plframe_stackframe_t new_frame;
    plframe_stackframe_t prev_frame;
    plframe_stackframe_t frame = cursor.frame;
    for (int i = 0; i < frame_count; i++) {
        if (i > 0) {
            plframe_stackframe_t *has_prev_frame = NULL;
            if (i >= 2) // the 1st frame doesn't have a previous frame
                has_prev_frame = &prev_frame;

            /* Fetch the next frame */
            STAssertEquals(plframe_cursor_read_frame_ptr(cursor.task, &_image_list, &frame, has_prev_frame, &new_frame), PLFRAME_ESUCCESS, @"Failed to read next frame");
            prev_frame = frame;
            frame = new_frame;
        }

        /* Verify the frame's PC value */
        STAssertTrue(plcrash_async_thread_state_has_reg(&frame.thread_state, PLCRASH_REG_IP), @"Did not mark IP as readable");
        plcrash_greg_t pc = plcrash_async_thread_state_get_reg(&frame.thread_state, PLCRASH_REG_IP);
        STAssertEquals(pc, (plcrash_greg_t)frames[i].pc, @"Incorrect IP for index %d", i);
    }

    /* Ensure that the final frame's NULL fp triggers an ENOFRAME */
    STAssertEquals(plframe_cursor_read_frame_ptr(cursor.task, &_image_list, &frame, &prev_frame, &new_frame), PLFRAME_ENOFRAME, @"Expected to hit end of frames");
}

/**
 * Verify that walking terminates with frame address greater than the current frame address.
 */
- (void) testStackDirection {
    /* Set up test stack */
    struct stack_frame frames[] = {
        { .fp = (uintptr_t) &frames[1], .pc = 0x1 },
        { .fp = (uintptr_t) &frames[2], .pc = 0x2 },
        { .fp = (uintptr_t) &frames[0], .pc = 0x3 },
    };
    size_t frame_count = sizeof(frames) / sizeof(frames[0]);
    
    /* Configure thread state */
    plcrash_async_thread_state_t state;
    plcrash_async_thread_state_mach_thread_init(&state, pl_mach_thread_self());
    plcrash_async_thread_state_set_reg(&state, PLCRASH_REG_FP, frames[0].fp);
    plcrash_async_thread_state_set_reg(&state, PLCRASH_REG_IP, frames[0].pc);
    
    /* Let the plframe cursor API initialize our first frame */
    plframe_cursor_t cursor;
    plframe_cursor_init(&cursor, mach_task_self(), &state, &_image_list);
    
    /* Try walking the stack */
    plframe_stackframe_t new_frame;
    plframe_stackframe_t prev_frame;
    plframe_stackframe_t frame = cursor.frame;
    
    for (size_t i = 0; i < frame_count; i++) {
        if (i > 0) {
            plframe_stackframe_t *has_prev_frame = NULL;
            if (i >= 2) // the 1st frame doesn't have a previous frame
                has_prev_frame = &prev_frame;
            
            /* Fetch the next frame */
            STAssertEquals(plframe_cursor_read_frame_ptr(cursor.task, &_image_list, &frame, has_prev_frame, &new_frame), PLFRAME_ESUCCESS, @"Failed to read next frame");
            prev_frame = frame;
            frame = new_frame;
        }

        /* Verify the frame's PC value */
        STAssertTrue(plcrash_async_thread_state_has_reg(&frame.thread_state, PLCRASH_REG_IP), @"Did not mark IP as readable");
        plcrash_greg_t pc = plcrash_async_thread_state_get_reg(&frame.thread_state, PLCRASH_REG_IP);
        STAssertEquals(pc, (plcrash_greg_t)frames[i].pc, @"Incorrect IP for index %zd", i);
    }

    /* Ensure that the final frame's bad fp triggers an EBADFRAME */
    STAssertEquals(plframe_cursor_read_frame_ptr(cursor.task, &_image_list, &frame, &prev_frame, &new_frame), PLFRAME_EBADFRAME, @"Expected to hit end of frames");
}

@end
