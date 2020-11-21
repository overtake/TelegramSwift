/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
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

/*
 * Minimal compatibility shims to support existing tests written against the SenTestCase (aka OCUnit) API. This
 * allows us to support Apple's new XCTest framework without polluting existing test cases with spurious changes.
 *
 * The APIs are nearly identical, and can be aliased directly.
 */

#import <XCTest/XCTest.h>

@compatibility_alias SenTestCase XCTestCase;
@compatibility_alias SenTestSuite XCTestSuite;

#define STAssertNil(a1, description, ...)                                               XCTAssertNil(a1, description, ##__VA_ARGS__)
#define STAssertNotNil(a1, description, ...)                                            XCTAssertNotNil(a1, description, ##__VA_ARGS__)
#define STAssertTrue(expression, description, ...)                                      XCTAssertTrue(expression, description, ##__VA_ARGS__)
#define STAssertFalse(expression, description, ...)                                     XCTAssertFalse(expression, description, ##__VA_ARGS__)
#define STAssertEqualObjects(a1, a2, description, ...)                                  XCTAssertEqualObjects(a1, a2, description, ##__VA_ARGS__)
#define STAssertEquals(a1, a2, description, ...)                                        XCTAssertEqual(a1, a2, description, ##__VA_ARGS__)
#define STAssertEqualsWithAccuracy(left, right, accuracy, description, ...)             XCTAssertEqualsWithAccuracy(left, right, accuracy, description, ##__VA_ARGS__)
#define STAssertThrows(expression, description, ...)                                    XCTAssertThrows(expression, description, ##__VA_ARGS__)
#define STAssertThrowsSpecific(expression, specificException, description, ...)         XCTAssertThrowsSpecific(expression, specificException, description, ##__VA_ARGS__)
#define STAssertThrowsSpecificNamed(expr, specificException, aName, description, ...)   XCTAssertThrowsSpecificNamed(expr, specificException, aName, description, ##__VA_ARGS__)
#define STAssertNoThrow(expression, description, ...)                                   XCTAssertNoThrow(expression, description, ##__VA_ARGS__)
#define STAssertNoThrowSpecific(expression, specificException, description, ...)        XCTAssertNoThrowSpecific(expression, specificException, description, ##__VA_ARGS__)
#define STAssertNoThrowSpecificNamed(expr, specificException, aName, description, ...)  XCTAssertNoThrowSpecificNamed(expr, specificException, aName, description, ##__VA_ARGS__)
#define STFail(description, ...)                                                        XCTFail(description, ##__VA_ARGS__)
#define STAssertTrueNoThrow(expression, description, ...)                               XCTAssertTrueNoThrow(expression, description, ##__VA_ARGS__)
#define STAssertFalseNoThrow(expression, description, ...)                              XCTAssertFalseNoThrow(expression, description, ##__VA_ARGS__)

/* The following assertions re-implement extensions that were provided by Google's GTM library, which were used throughout the PLCrashReporter tests */
#define STAssertNotEquals(a1, a2, description, ...)                                     XCTAssertNotEqual(a1, a2, description, ##__VA_ARGS__)
#define STAssertEqualStrings(a1, a2, description, ...)                                  XCTAssertEqualObjects(a1, a2, description, ##__VA_ARGS__)
#define STAssertLessThan(a1, a2, description, ...)                                      XCTAssertLessThan(a1, a2, description, ##__VA_ARGS__)
#define STAssertGreaterThan(a1, a2, description, ...)                                   XCTAssertGreaterThan(a1, a2, description, ##__VA_ARGS__)

#define STAssertEqualCStrings(a1, a2, description, ...) do { \
    if (!a1 || !a2 || strcmp(a1, a2) != 0) { \
        NSString *msg = [NSString stringWithFormat: description, ##__VA_ARGS__]; \
        XCTFail(@"%s == %s: %@", "" #a1, "" #a2, msg); \
    } \
} while(0)

#define STAssertNotEqualCStrings(a1, a2, description, ...) do { \
    if (strcmp(a1, a2) == 0) { \
        NSString *msg = [NSString stringWithFormat: description, ##__VA_ARGS__]; \
        XCTFail(@"%s != %s: %@", "" #a1, "" #a2, msg); \
    } \
} while(0)

#define STAssertNotNULL(a1, description, ...) do { \
    const void *expressionValue = a1; \
    if (expressionValue == NULL) { \
        NSString *msg = [NSString stringWithFormat: description, ##__VA_ARGS__]; \
        XCTFail(@"%s != NULL: %@", "" #a1, msg); \
    } \
} while(0)

#define STAssertNULL(a1, description, ...) do { \
    const void *expressionValue = a1; \
    if (expressionValue != NULL) { \
        NSString *msg = [NSString stringWithFormat: description, ##__VA_ARGS__]; \
        XCTFail(@"%s == NULL: %@", "" #a1, msg); \
    } \
} while(0)



