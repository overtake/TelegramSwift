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

#import "PLCrashAsyncImageList.h"

#import <mach-o/dyld.h>

#import <dlfcn.h>
#import <execinfo.h>

#import <objc/runtime.h>

@interface PLCrashAsyncImageTests : SenTestCase {
    plcrash_async_image_list_t _list;
}
@end

// XXX TODO: Decouple the async image list from the Mach-O parsing, such that
// we can properly test it independently of Mach-O.
//
// Some work on this has been done in the bitstadium-upstream branch, but
// no tests were written for the changes.
@implementation PLCrashAsyncImageTests

- (void) setUp {
    plcrash_nasync_image_list_init(&_list, mach_task_self());
}

- (void) tearDown {
    plcrash_nasync_image_list_free(&_list);
}

- (void) testAppendImage {
    // XXX - This is required due to the tight coupling with the Mach-O parser
    uint32_t count = _dyld_image_count();
    STAssertTrue(count >= 5, @"We need at least five Mach-O images for this test. This should not be a problem on a modern system.");
    
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(0), _dyld_get_image_name(0));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(1), _dyld_get_image_name(1));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(2), _dyld_get_image_name(2));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(3), _dyld_get_image_name(3));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(4), _dyld_get_image_name(4));
    
    /* Verify the appended elements */
    plcrash_async_image_t *item = NULL;
    
    plcrash_async_image_list_set_reading(&_list, true);
    for (uint32_t i = 0; i <= 5; i++) {
        /* Fetch the next item */
        item = plcrash_async_image_list_next(&_list, item);
        if (i <= 4) {
            STAssertNotNULL(item, @"Item should not be NULL");
        } else {
            STAssertNULL(item, @"Item should be NULL");
            break;
        }

        /* Validate its value */
        STAssertEquals((pl_vm_address_t) _dyld_get_image_header(i), item->macho_image.header_addr, @"Incorrect header value");
        STAssertEquals((pl_vm_off_t)_dyld_get_image_vmaddr_slide(i), item->macho_image.vmaddr_slide, @"Incorrect slide value");
        STAssertEqualCStrings(_dyld_get_image_name(i), item->macho_image.name, @"Incorrect name value");
    }
    plcrash_async_image_list_set_reading(&_list, false);

}


/* Test removing the last image in the list. */
- (void) testRemoveLastImage {
    plcrash_nasync_image_list_append(&_list, 0x0, "image_name");
    plcrash_nasync_image_list_remove(&_list, 0x0);

    plcrash_async_image_list_set_reading(&_list, true);
    STAssertNULL(plcrash_async_image_list_next(&_list, NULL), @"List should be empty");
    plcrash_async_image_list_set_reading(&_list, false);
}

- (void) testRemoveImage {
    // XXX - This is required due to the tight coupling with the Mach-O parser
    uint32_t count = _dyld_image_count();
    STAssertTrue(count >= 5, @"We need at least five Mach-O images for this test. This should not be a problem on a modern system.");

    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(0), _dyld_get_image_name(0));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(1), _dyld_get_image_name(1));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(2), _dyld_get_image_name(2));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(3), _dyld_get_image_name(3));
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) _dyld_get_image_header(4), _dyld_get_image_name(4));

    /* Try a non-existent item */
    plcrash_nasync_image_list_remove(&_list, 0x42);

    /* Remove real items */
    plcrash_nasync_image_list_remove(&_list, (pl_vm_address_t) _dyld_get_image_header(1));
    plcrash_nasync_image_list_remove(&_list, (pl_vm_address_t) _dyld_get_image_header(3));

    /* Verify the contents of the list */
    plcrash_async_image_t *item = NULL;
    plcrash_async_image_list_set_reading(&_list, true);
    int val = 0x0;
    for (int i = 0; i <= 3; i++) {
        /* Fetch the next item */
        item = plcrash_async_image_list_next(&_list, item);
        if (i <= 2) {
            STAssertNotNULL(item, @"Item should not be NULL");
        } else {
            STAssertNULL(item, @"Item should be NULL");
            break;
        }
        
        /* Validate its value */
        STAssertEquals((pl_vm_address_t) _dyld_get_image_header(val), item->macho_image.header_addr, @"Incorrect header value for %d", val);
        STAssertEquals((pl_vm_off_t)_dyld_get_image_vmaddr_slide(val), item->macho_image.vmaddr_slide, @"Incorrect slide value for %d", val);
        STAssertEqualCStrings(_dyld_get_image_name(val), item->macho_image.name, @"Incorrect name value for %d", val);
        val += 0x2;
    }
    plcrash_async_image_list_set_reading(&_list, false);
}

- (void) testFindImageForAddress {    
    /* Fetch the our IMP address and symbolicate it using dladdr(). */
    IMP localIMP = class_getMethodImplementation([self class], _cmd);
    Dl_info dli;
    STAssertTrue(dladdr((void *)localIMP, &dli) != 0, @"Failed to look up symbol");
    
    /* Look up the vmaddr slide for our image */
    pl_vm_off_t vmaddr_slide = 0;
    bool found_image = false;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) == dli.dli_fbase) {
            vmaddr_slide = _dyld_get_image_vmaddr_slide(i);
            found_image = true;
            break;
        }
    }
    STAssertTrue(found_image, @"Could not find dyld image record");

    /* Initialize our image list using our discovered image */
    plcrash_nasync_image_list_append(&_list, (pl_vm_address_t) dli.dli_fbase, dli.dli_fname);

    plcrash_async_image_list_set_reading(&_list, true); {
        /* Verify that image_base-1 returns NULL */
        STAssertNULL(plcrash_async_image_containing_address(&_list, (pl_vm_address_t) dli.dli_fbase-1), @"Should not return an image for invalid address");

        /* Verify that image_base returns a valid value */
        plcrash_async_image_t *image;
        image = plcrash_async_image_containing_address(&_list, (pl_vm_address_t) dli.dli_fbase);
        STAssertNotNULL(image, @"Failed to return valid image");
        STAssertEquals(image->macho_image.header_addr, (pl_vm_address_t)dli.dli_fbase, @"Incorrect Mach-O header address");
        STAssertEquals(image->macho_image.vmaddr_slide, vmaddr_slide, @"Incorrect slide value");

        /* Verify that image_base+image_length-1 returns a valid value */
        STAssertNotNULL(plcrash_async_image_containing_address(&_list, (pl_vm_address_t) dli.dli_fbase+image->macho_image.text_size-1), @"Should not return an image for invalid address");

        /* Verify that image_base+image_length returns NULL */
        STAssertNULL(plcrash_async_image_containing_address(&_list, (pl_vm_address_t) dli.dli_fbase+image->macho_image.text_size), @"Should not return an image for invalid address");
    } plcrash_async_image_list_set_reading(&_list, false);

}

@end
