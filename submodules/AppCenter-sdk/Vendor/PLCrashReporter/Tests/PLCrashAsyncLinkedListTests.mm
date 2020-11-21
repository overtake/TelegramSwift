/*
 * Author: Landon Fuller <landonf@plausible.coop>
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

#import "PLCrashAsyncLinkedList.hpp"

using namespace plcrash::async;


@interface PLCrashAsyncLinkedListTests : SenTestCase {
    async_list<int> _list;
}
@end

/**
 * Tests for the async_list implementation.
 */
@implementation PLCrashAsyncLinkedListTests

- (void) testPrependItem {
    _list.nasync_prepend(0);
    
    // head/tail are marked private
    // STAssertNotNULL(_list.head, @"List HEAD should be set to our new entry");
    // STAssertEquals(_list.head, _list.tail, @"The list head and tail should be equal for the first entry");
    
    _list.nasync_prepend(1);
    _list.nasync_prepend(2);
    _list.nasync_prepend(3);
    _list.nasync_prepend(4);
    
    /* Verify the prepended elements */
    async_list<int>::node *item = NULL;
    
    _list.set_reading(true);
    for (int i = 0; i <= 5; i++) {
        /* Fetch the next item */
        item = _list.next(item);
        if (i <= 4) {
            STAssertNotNULL(item, @"Item should not be NULL");
        } else {
            STAssertNULL(item, @"Item should be NULL");
            break;
        }
        
        /* Validate its value */
        STAssertEquals(item->value(), (4-i), @"Incorrect value");
    }
    _list.set_reading(false);
    
    _list.assert_list_valid();
}

- (void) testAppendItem {
    _list.nasync_append(0);
    
    // head/tail are marked private
    // STAssertNotNULL(_list.head, @"List HEAD should be set to our new entry");
    // STAssertEquals(_list.head, _list.tail, @"The list head and tail should be equal for the first entry");
    
    _list.nasync_append(1);
    _list.nasync_append(2);
    _list.nasync_append(3);
    _list.nasync_append(4);
    
    /* Verify the appended elements */
    async_list<int>::node *item = NULL;
    
    _list.set_reading(true);
    for (int i = 0; i <= 5; i++) {
        /* Fetch the next item */
        item = _list.next(item);
        if (i <= 4) {
            STAssertNotNULL(item, @"Item should not be NULL");
        } else {
            STAssertNULL(item, @"Item should be NULL");
            break;
        }
        
        /* Validate its value */
        STAssertEquals(item->value(), i, @"Incorrect value");
    }
    _list.set_reading(false);
    
    _list.assert_list_valid();
}


/* Test removing the last item in the list. */
- (void) testRemoveLastItem {
    _list.nasync_append(0x0);

    /* Trigger free list handling by enabling read mode */
    _list.set_reading(true);
    _list.nasync_remove_first_value(0x0);
    _list.set_reading(false);
    
    // head/tail are marked private
    // STAssertNULL(_list.head, @"List HEAD should now be NULL");
    // STAssertNULL(_list.tail, @"List TAIL should now be NULL");
    
    _list.assert_list_valid();
}

- (void) testRemoveItem {
    /* We need at least entries for this test. */
    _list.nasync_append(0);
    _list.nasync_append(1);
    _list.nasync_append(2);
    _list.nasync_append(3);
    _list.nasync_append(4);
    
    /* Try a non-existent item */
    _list.nasync_remove_first_value(0x42);
    
    /* Remove real items */
    _list.nasync_remove_first_value(1);
    _list.nasync_remove_first_value(3);
    
    /* Verify the contents of the list */
    async_list<int>::node *item = NULL;
    int val = 0x0;
    
    _list.set_reading(true);
    for (int i = 0; i <= 3; i++) {
        /* Fetch the next item */
        item = _list.next(item);
        if (i <= 2) {
            STAssertNotNULL(item, @"Item should not be NULL");
        } else {
            STAssertNULL(item, @"Item should be NULL");
            break;
        }
        
        /* Validate its value */
        STAssertEquals(item->value(), val, @"Incorrect value for %d", val);
        val += 0x2;
    }
    _list.set_reading(false);

    _list.assert_list_valid();
}

@end
