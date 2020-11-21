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


#import "SenTestCompat.h"
#import "PLCrashFrameCompactUnwind.h"
#import "PLCrashFeatureConfig.h"

#if PLCRASH_FEATURE_UNWIND_COMPACT

/**
 * @internal
 *
 * This code tests compact frame unwinding.
 */
@interface PLCrashFrameCompactUnwindTests : SenTestCase {
@private
    plcrash_async_image_list_t _image_list;
}

@end

@implementation PLCrashFrameCompactUnwindTests

- (void) setUp {
    plcrash_nasync_image_list_init(&_image_list, mach_task_self());
}

- (void) tearDown {
    plcrash_nasync_image_list_free(&_image_list);
}

- (void) testMissingIP {
    plframe_stackframe_t frame;
    plframe_stackframe_t next;
    plframe_error_t err;

    plcrash_async_thread_state_clear_all_regs(&frame.thread_state);
    err = plframe_cursor_read_compact_unwind(mach_task_self(), &_image_list, &frame, NULL, &next);
    STAssertEquals(err, PLFRAME_EBADFRAME, @"Unexpected result for a frame missing a valid PC");
}

- (void) testMissingImage {
    plframe_stackframe_t frame;
    plframe_stackframe_t next;
    plframe_error_t err;
    
    plcrash_async_thread_state_clear_all_regs(&frame.thread_state);
    plcrash_async_thread_state_set_reg(&frame.thread_state, PLCRASH_REG_IP, (plcrash_greg_t) NULL);
    
    err = plframe_cursor_read_compact_unwind(mach_task_self(), &_image_list, &frame, NULL, &next);
    STAssertEquals(err, PLFRAME_ENOTSUP, @"Unexpected result for a frame missing a valid image");
}

@end

#endif /* PLCRASH_FEATURE_UNWIND_COMPACT */
