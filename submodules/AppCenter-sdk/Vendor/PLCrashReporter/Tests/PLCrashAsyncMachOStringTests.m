/*
 * Author: Mike Ash <mikeash@plausiblelabs.com>
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

#import "SenTestCompat.h"

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>

#import "PLCrashAsyncMachOImage.h"
#import "PLCrashAsyncMachOString.h"


@interface PLCrashAsyncMachOStringTests : SenTestCase {
    /** The image containing our class. */
    plcrash_async_macho_t _image;
}
@end

@implementation PLCrashAsyncMachOStringTests

- (void) setUp {
    /* Fetch our containing image's dyld info */
    Dl_info info;
    STAssertTrue(dladdr((__bridge void *)([self class]), &info) > 0, @"Could not fetch dyld info for %p", [self class]);
    
    /* Look up the vmaddr slide for our image */
    pl_vm_off_t vmaddr_slide = 0;
    bool found_image = false;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) == info.dli_fbase) {
            vmaddr_slide = _dyld_get_image_vmaddr_slide(i);
            found_image = true;
            break;
        }
    }
    STAssertTrue(found_image, @"Could not find dyld image record");
    
    plcrash_nasync_macho_init(&_image, mach_task_self(), info.dli_fname, (pl_vm_address_t) info.dli_fbase);
    
    /* Basic test of the initializer */
    STAssertEqualCStrings(_image.name, info.dli_fname, @"Incorrect name");
    STAssertEquals(_image.header_addr, (pl_vm_address_t) info.dli_fbase, @"Incorrect header address");
    STAssertEquals(_image.vmaddr_slide, (pl_vm_off_t) vmaddr_slide, @"Incorrect vmaddr_slide value");
    
    unsigned long text_size;
    STAssertNotNULL(getsegmentdata(info.dli_fbase, SEG_TEXT, &text_size), @"Failed to find segment");
    STAssertEquals(_image.text_size, (pl_vm_size_t) text_size, @"Incorrect text segment size computed");
}

- (void) tearDown {
    plcrash_nasync_macho_free(&_image);
}

- (void) testStringReading {
    char *str = "one two three four five";
    
    plcrash_error_t err;
    
    plcrash_async_macho_string_t strObj;
    err = plcrash_async_macho_string_init(&strObj, &_image, (pl_vm_address_t)str);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Error initializing string object. (How did you even manage to pull that off?)");
    
    pl_vm_size_t len;
    const char *ptr;
    err = plcrash_async_macho_string_get_length(&strObj, &len);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Error getting string length");
    
    err = plcrash_async_macho_string_get_pointer(&strObj, &ptr);
    STAssertEquals(err, PLCRASH_ESUCCESS, @"Error getting string pointer");
    
    STAssertEquals(strlen(str), (unsigned long)len, @"String length does not match");
    STAssertEquals(strncmp(str, ptr, len), 0, @"String contents do not match");
}

@end
