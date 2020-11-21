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

#import "PLCrashSysctl.h"

#include <sys/mman.h>
#include <mach/mach.h>

@interface PLCrashSysctlTests : SenTestCase @end

@implementation PLCrashSysctlTests

/* Test fetch of a string value */
- (void) testSysctlString {
    char *string = plcrash_sysctl_string("kern.ostype");
    STAssertNotNULL(string, @"Failed to fetch string value");

    // This is a bit fragile 
    STAssertEqualCStrings(string, "Darwin", @"Did not fetch expected OS type");

    free(string);
}

/* Test fetch of an integer value */
- (void) testSysctlInteger {
    int result;

    STAssertTrue(plcrash_sysctl_int("hw.logicalcpu_max", &result), @"Failed to fetch int value");
    STAssertEquals(result, (int)[[NSProcessInfo processInfo] processorCount], @"Incorrect count");
}

/**
 * @internal
 *
 * Internal implementation of the MAX_LEN_UTF8() and LEN_UTF8() macros used in PLCrashSysctlTests::testValidUTF8Strlen.
 *
 * Handles writing of the test data at the end of the first page within @a test_pages, where
 * an overrun will trigger an access violation, and then returning the result of calling
 * plcrash_sysctl_valid_utf8_bytes() or plcrash_sysctl_valid_utf8_bytes_max() on the written data.
 *
 * We could also implement this using GCC's non-standard statement exprs, rather than using an additional function.
 *
 * @param test_pages Page-aligned allocation of size PAGE_SIZE*2. The second page should be set PROT_NONE to ensure
 * that over-read triggers an access violation.
 * @param test_data The test data to write at the end of the first page within @a test_pages.
 * @param test_data_len The length of @a test_data in bytes.
 * @param maxvariant If true, plcrash_sysctl_valid_utf8_bytes_max() will be called. If false, plcrash_sysctl_valid_utf8_bytes().
 * @param maxlen The maxlen value to be passed to plcrash_sysctl_valid_utf8_bytes_max().
 */
static size_t utf8_test_data_strlen_max (uint8_t *test_pages, uint8_t *test_data, size_t test_data_len, BOOL maxvariant, size_t maxlen) {
    assert(test_data_len < PAGE_SIZE);

    uint8_t *target = test_pages + (PAGE_SIZE - test_data_len);
    memcpy(target, test_data, test_data_len);
    
    if (maxvariant) {
        return plcrash_sysctl_valid_utf8_bytes_max(target, maxlen);
    } else {
        return plcrash_sysctl_valid_utf8_bytes(target);
    }
}

/* Test handling of truncated UTF-8 strings */
- (void) testValidUTF8Strlen {
    /*
     * For our tests, we set up a custom two-page allocation to detect read overruns.
     *
     * The first page has R|W permissions, while the second page is set to PROT_NONE; by
     * positioning our test data on the trailing edge of the first page, we let the second
     * page trigger an access violation.
     *
     * The allocation is cleaned up at the bottom of this method.
     */
    uint8_t *test_pages;
    {
        /* Allocate the two pages */
        test_pages = mmap(NULL, PAGE_SIZE*2, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
        STAssertNotEquals((void *)test_pages, MAP_FAILED, @"Failed to mmap() pages: %s", strerror(errno));
        
        /* Mark the second page as non-writable, non-readable */
        STAssertEquals(0, mprotect(test_pages+PAGE_SIZE, PAGE_SIZE, PROT_NONE), @"Failed to set page protections: %s", strerror(errno));
    }

    /* Position the given bytes within our test_pages buffer, returning the result of plcrash_sysctl_valid_utf8_bytes_max(). */
#define MAX_LEN_UTF8(maxlen, ...) \
    utf8_test_data_strlen_max(test_pages, (uint8_t[]){ __VA_ARGS__ }, sizeof((uint8_t[]){ __VA_ARGS__ }), true, maxlen)

    /* Test handling (and interaction) of maxlen and NUL termination */
    {
        STAssertEquals(MAX_LEN_UTF8(100, 'a', '\0'), (size_t)1, @"String iteration ignored NUL terminator in favor of maxlen");

        STAssertEquals(MAX_LEN_UTF8(1, 'a', 'a', '\0'), (size_t)1, @"String iteration ignored maxlen in favor of NUL");
    }
    
    /* Test handling (and interaction) of maxlen and multibyte validation */
    {
        /* This is a valid multibyte sequences; we use maxlen to terminate in the middle of it */
        STAssertEquals(MAX_LEN_UTF8(2, 'a', 0xC2, 0x80, '\0'), (size_t)1, @"Multibyte validation ignored maxlen");
        
        /* Verify that maxlen doesn't trigger *early* termination. This also sanity-checks the above test,
         * asserting that had maxlen not been set too low, the characters would have been correctly validated */
        STAssertEquals(MAX_LEN_UTF8(3, 'a', 0xC2, 0x80, '\0'), (size_t)3, @"Maxlen value triggered incorrect early termination of multibyte validation");
    }

#define LEN_UTF8(...) \
    utf8_test_data_strlen_max(test_pages, (uint8_t[]){ __VA_ARGS__ }, sizeof((uint8_t[]){ __VA_ARGS__ }), false, 0)

    /* Test BOM handling. BOM is not useful or recommended for UTF-8 encoding, but it's still necessary to support. */
    {
        STAssertEquals(LEN_UTF8(0xEF, 0xBB, 0xBF, 'a', '\0'), (size_t)4, @"0 continutation rejected in-range byte");
    }
    
    /* Test handling of a 0-length string. */
    STAssertEquals(LEN_UTF8('\0'), (size_t)0, @"0 length NULL terminated string should return 0");
    
    /* Test handling of a 0-length maxlen on a non-zero length string. */
    STAssertEquals(MAX_LEN_UTF8(0, 'a', '\0'), (size_t)0,
                   @"String iteration ignored maxlen of a zero length string");
    
    /* Test handling of strings that start with invalid UTF-8 byte(s) */
    {
        /* Invalid single byte character */
        STAssertEquals(LEN_UTF8(128, '\0'), (size_t)0, @"Length should be zero on a string starting with invalid UTF-8");
        
        /* Missing continuation */
        STAssertEquals(LEN_UTF8(0xC0, '\0'), (size_t)0, @"Length should be zero on a string starting with invalid UTF-8");
    }

    /* Test 0 continuation sequence */
    {
        STAssertEquals(LEN_UTF8('a', 127, '\0'), (size_t)2, @"Rejected in-range byte");
        STAssertEquals(LEN_UTF8('a', 128, '\0'), (size_t)1, @"Accepted out-of-range byte");
    }

    /* Test 1 byte continuation of 2 byte sequence */
    {
        /* Verify that bytes that fall within the expected range are accepted */
        STAssertEquals(LEN_UTF8('a', 0xC2, 0x80, '\0'), (size_t)3, @"Rejected in-range byte (128)");
        STAssertEquals(LEN_UTF8('a', 0xDF, 0xBF, '\0'), (size_t)3, @"Rejected in-range byte (2047)");

        /* Verify that a missing byte in a 2 byte sequence is considered an error */
        STAssertEquals(LEN_UTF8('a', 0xC0, '\0'), (size_t)1, @"Accepted leading byte with missing continuation");

        /* Verify that an invalid 2nd byte in a 2 byte sequence is considered an error */
        STAssertEquals(LEN_UTF8('a', 0xC0, 0x00, '\0'), (size_t)1, @"Accepted leading byte with invalid continuation");
    }
    
    /* Test 2 byte continuation of 3 byte sequence */
    {
        /* Verify that bytes that fall within the expected range are accepted */
        STAssertEquals(LEN_UTF8('a', 0xE0, 0xA0, 0x80, '\0'), (size_t)4, @"Rejected in-range byte (2048)");
        STAssertEquals(LEN_UTF8('a', 0xEF, 0xBF, 0xBF, '\0'), (size_t)4, @"Rejected in-range byte (65535)");
        
        /* Verify that missing trailing bytes in a 3 byte sequence are considered an error */
        STAssertEquals(LEN_UTF8('a', 0xE0, '\0'), (size_t)1, @"Accepted leading byte with missing continuations");
        STAssertEquals(LEN_UTF8('a', 0xE0, 0x80, '\0'), (size_t)1, @"Accepted leading byte with missing continuations");
        STAssertEquals(LEN_UTF8('a', 0xE0, 0x80, 0x80, '\0'), (size_t)4, @"Rejected sequence containing full byte allotment");

        /* Verify that invalid trailing bytes in a 3 byte sequence are considered an error */
        STAssertEquals(LEN_UTF8('a', 0xE0, 0x00, '\0'), (size_t)1, @"Accepted leading byte with invalid continuation");
        STAssertEquals(LEN_UTF8('a', 0xE0, 0x80, 0x0, '\0'), (size_t)1, @"Accepted leading bytes with invalid continuation");
    }
    
    /* Test 3 byte continuation of 4 byte sequence */
    {
        /* Verify that bytes that fall within the expected range are accepted */
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x90, 0x80, 0x80, '\0'), (size_t)5, @"Rejected in-range byte (65536)");
        STAssertEquals(LEN_UTF8('a', 0xF4, 0x8F, 0xBF, 0xBF, '\0'), (size_t)5, @"Rejected in-range byte (1114111)");
        
        /* Verify that missing trailing bytes in a 4 byte sequence are considered an error */
        STAssertEquals(LEN_UTF8('a', 0xF0, '\0'), (size_t)1, @"Accepted leading byte with missing continuations");
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x80, '\0'), (size_t)1, @"Accepted leading byte with missing continuations");
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x80, 0x80, 0x80, '\0'), (size_t)5, @"Rejected sequence containing full byte allotment");
        
        /* Verify that invalid trailing bytes in a 4 byte sequence are considered an error */
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x00, '\0'), (size_t)1, @"Accepted leading byte with invalid continuation");
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x80, 0x0, '\0'), (size_t)1, @"Accepted leading bytes with invalid continuation");
        STAssertEquals(LEN_UTF8('a', 0xF0, 0x80, 0x80, 0x0, '\0'), (size_t)1, @"Accepted leading bytes with invalid continuation");

    }
    
    /* Verify that the implementation correctly resets its internal state after fully parsing a UTF-8 code
     * point; this is just a test of its behavior with a multiple codepoint string */
    {
        STAssertEquals(LEN_UTF8('a', 0xC2, 0x80, 0xC2, 0x80, '\0'), (size_t)5, @"Rejected valid UTF-8 string");
        
        /* This should return the length of the valid bytes, ignoring the invalid trailing multibyte sequence */
        STAssertEquals(LEN_UTF8('a', 0xC2, 0x80, /* Invalid */ 0xC2, '\0'), (size_t)3, @"Lost valid UTF-8 prefix when rejecting trailing bytes");
    }

#undef LEN_UTF8
#undef MAX_LEN_UTF8
    
    /* Clean up */
    munmap(test_pages, PAGE_SIZE*2);
}

@end
