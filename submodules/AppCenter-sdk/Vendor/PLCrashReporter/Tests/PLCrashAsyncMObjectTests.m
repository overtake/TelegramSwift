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
#import "PLCrashAsyncMObject.h"

@interface PLCrashAsyncMObjectTests : SenTestCase {
@private
}

@end


@implementation PLCrashAsyncMObjectTests

- (void) test_mapMobj {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Create a map target */
    memset_pattern4(template, (const uint8_t[]){ 0xC, 0xA, 0xF, 0xE }, size);
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    
    /* Verify the mapped data */
    STAssertTrue(memcmp((void *)mobj.address, template, size) == 0, @"Mapping appears to be incorrect");
    
    /* Verify the vm_slide */
    STAssertEquals((pl_vm_address_t)template, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Incorrect slide value!");
    
    /* Sanity check the length */
    STAssertEquals(mobj.length, (pl_vm_size_t)size, @"Incorrect length");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

- (void) testBaseAddress {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    STAssertEquals((pl_vm_address_t)template, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Incorrect slide value!");
    
    /* Test base address accessor */
    STAssertEquals((pl_vm_address_t) &template, plcrash_async_mobject_base_address(&mobj), @"Incorrect base address");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

- (void) testLength {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    STAssertEquals((pl_vm_address_t)template, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Incorrect slide value!");
    
    /* Test length accessor; this must be the user-requested length, not the page length. */
    STAssertEquals((pl_vm_size_t)size, plcrash_async_mobject_length(&mobj), @"Incorrect mapping length");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}


/**
 * Test mapped object pointer validation.
 */
- (void) test_mapMobj_map_address {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    STAssertEquals((pl_vm_address_t)template, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Incorrect slide value!");
    
    /* Test slide handling */
    STAssertEquals((void*)mobj.address+1, plcrash_async_mobject_remap_address(&mobj, (pl_vm_address_t) template, 1, 0), @"Mapped to incorrect address");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test negative offset handling
 */
- (void) test_mapMobj_map_negative_offset {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    STAssertEquals((pl_vm_address_t)template, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Incorrect slide value!");
    
    /* Test slide handling */
    STAssertEquals((void*)mobj.address+1, plcrash_async_mobject_remap_address(&mobj, (pl_vm_address_t) template+2, -1, 0), @"Mapped to incorrect address");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test mapped object pointer validation.
 */
- (void) test_mapMobj_pointer {
    size_t size = vm_page_size+1;
    uint8_t template[size];
    
    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t)template, size, true), @"Failed to initialize mapping");
    
    /* Test the address offset validation */
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, -1, 2), @"Returned pointer for a range that starts before our memory object");
    STAssertTrue(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address+1, -1, 1), @"Failed to return pointer for a valid range at the start of our memory object");

    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, mobj.length-1, 2), @"Returned pointer for a range that ends after our memory object");
    STAssertTrue(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, mobj.length-1, 1), @"Failed to return pointer for a valid range at the tail of our memory object");

    /* Test the address length validation */
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address - 1, 0, 10), @"Returned pointer for a range that starts before our memory object");
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address + mobj.length - 1, 0, 10), @"Returned pointer for a range that ends after our memory object");
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address - 10, 0, 5), @"Returned pointer for a range that is entirely outside our memory object");
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address + mobj.length, 0, 1), @"Returned pointer for a range that starts the end of our memory object");
    STAssertFalse(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, 0, size + 1), @"Returned pointer for a range that ends just past our memory object");
    
    STAssertTrue(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, 0, size), @"Returned false for a range that comprises our entire memory object");
    STAssertTrue(plcrash_async_mobject_verify_local_pointer(&mobj, mobj.address, 0, size - 1), @"Returned false for a range entirely within our memory object");
    
    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

/**
 * Test byte/multibyte read routines.
 */
- (void) testReadHandling {
    uint8_t test_bytes[] = { 0x00, 0x01, 0x02, 0x03 , 0x04, 0x05, 0x06, 0x07 };
    
    /* Use big endian byte order to simplify determining the expected value in the below tests; it will always be the first N bytes
     * of the test bytes, in order. */
    const plcrash_async_byteorder_t *byteorder = plcrash_async_byteorder_big_endian();

    /* Map the memory */
    plcrash_async_mobject_t mobj;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_init(&mobj, mach_task_self(), (pl_vm_address_t) test_bytes, sizeof(test_bytes), true), @"Failed to initialize mapping");
    
    /* uint8 */
    uint8_t u8;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_read_uint8(&mobj, (pl_vm_address_t)(test_bytes-1), 1, &u8), @"Failed to read data");
    STAssertEquals(u8, (uint8_t) 0x0, @"Incorrect data");
    
    /* uint16 */
    uint16_t u16;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_read_uint16(&mobj, byteorder, (pl_vm_address_t) (test_bytes-1), 1, &u16), @"Failed to read data");
    STAssertEquals(u16, (uint16_t) 0x0001, @"Incorrect data");
    
    /* uint32 */
    uint32_t u32;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_read_uint32(&mobj, byteorder, (pl_vm_address_t) (test_bytes-1), 1, &u32), @"Failed to read data");
    STAssertEquals(u32, (uint32_t) 0x00010203, @"Incorrect data");
    
    /* uint64 */
    uint64_t u64;
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_mobject_read_uint64(&mobj, byteorder, (pl_vm_address_t) (test_bytes-1), 1, &u64), @"Failed to read data");
    STAssertEquals(u64, (uint64_t) 0x0001020304050607ULL, @"Incorrect data");

    /* Clean up */
    plcrash_async_mobject_free(&mobj);
}

@end
