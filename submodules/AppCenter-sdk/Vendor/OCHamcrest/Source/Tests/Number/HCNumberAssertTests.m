//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCNumberAssert.h>

#import <OCHamcrest/HCIsEqual.h>
#import "HCTestFailure.h"
#import "InterceptingTestCase.h"


@interface HCNumberAssertTests : InterceptingTestCase
@end

@implementation HCNumberAssertTests

- (void)test_success_withBool
{
    assertThatBool(YES, equalTo([NSNumber numberWithBool:YES]));
    
    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withBool
{
    assertThatBool(YES, equalTo([NSNumber numberWithBool:NO]));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <0>, but was <1>");
}

- (void)test_success_withChar
{
    assertThatChar('A', equalTo(@'A'));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withChar
{
    assertThatChar('B', equalTo(@'A'));
    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <65>, but was <66>");
}

- (void)test_success_withDouble
{
    assertThatDouble(1.5, equalTo(@1.5));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withDouble
{
    assertThatDouble(2.5, equalTo(@1.5));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1.5>, but was <2.5>");
}

- (void)test_success_withFloat
{
    assertThatFloat(1.5f, equalTo(@1.5f));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withFloat
{
    assertThatFloat(2.5f, equalTo(@1.5f));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1.5>, but was <2.5>");
}

- (void)test_success_withInt
{
    assertThatInt(1, equalTo(@1));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withInt
{
    assertThatInt(2, equalTo(@1));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withLong
{
    assertThatLong(1L, equalTo(@1L));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withLong
{
    assertThatLong(2L, equalTo(@1L));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withLongLong
{
    assertThatLongLong(1LL, equalTo(@1LL));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withLongLong
{
    assertThatLongLong(2LL, equalTo(@1LL));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withShort
{
    assertThatShort(1, equalTo([NSNumber numberWithShort:1]));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withShort
{
    assertThatShort(2, equalTo([NSNumber numberWithShort:1]));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withUnsignedChar
{
    assertThatUnsignedChar('A', equalTo([NSNumber numberWithUnsignedChar:'A']));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedChar
{
    assertThatUnsignedChar('B', equalTo([NSNumber numberWithUnsignedChar:'A']));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <65>, but was <66>");
}

- (void)test_success_withUnsignedInt
{
    assertThatUnsignedInt(1U, equalTo(@1U));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedInt
{
    assertThatUnsignedInt(2U, equalTo(@1U));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withUnsignedLong
{
    assertThatUnsignedLong(1UL, equalTo(@1UL));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedLong
{
    assertThatUnsignedLong(2UL, equalTo(@1UL));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withUnsignedLongLong
{
    assertThatUnsignedLongLong(1ULL, equalTo(@1ULL));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedLongLong
{
    assertThatUnsignedLongLong(2ULL, equalTo(@1ULL));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withUnsignedShort
{
    assertThatUnsignedShort(1U, equalTo([NSNumber numberWithUnsignedShort:1U]));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedShort
{
    assertThatUnsignedShort(2U, equalTo([NSNumber numberWithUnsignedShort:1U]));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withInteger
{
    assertThatInteger(1, equalTo(@1));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withInteger
{
    assertThatInteger(2, equalTo(@1));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

- (void)test_success_withUnsignedInteger
{
    assertThatUnsignedInteger(1, equalTo([NSNumber numberWithUnsignedInteger:1]));

    XCTAssertNil(self.testFailure);
}

- (void)test_failure_withUnsignedInteger
{
    assertThatUnsignedInteger(2, equalTo([NSNumber numberWithUnsignedInteger:1]));

    XCTAssertEqualObjects(self.testFailure.reason, @"Expected <1>, but was <2>");
}

@end
