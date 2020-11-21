//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt
//  Contribution by Sergio Padrino


#import <OCHamcrest/HCAssertThat.h>

#import <OCHamcrest/HCIsEqual.h>

#import "InterceptingTestCase.h"

#import <mach/mach_time.h>

static NSTimeInterval const TIME_ERROR_MARGIN = 0.1f;


static NSTimeInterval machTimeInSeconds(void)
{
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t machTime = mach_absolute_time();
    
    if (sTimebaseInfo.denom == 0) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    
    NSTimeInterval ratio = (NSTimeInterval)sTimebaseInfo.numer / sTimebaseInfo.denom;
    return ratio * machTime / NSEC_PER_SEC;
}


@interface AssertWithTimeoutTests : InterceptingTestCase
@end


@implementation AssertWithTimeoutTests

- (void)test_shouldBeSilentOnSuccessfulMatch_withTimeoutZero
{
    assertWithTimeout(0, thatEventually(@"foo"), equalTo(@"foo"));

    XCTAssertNil(self.testFailure);
}

- (void)test_shouldBeSilentOnSuccessfulMatch_withTimeoutGreaterThanZero
{
    assertWithTimeout(5, thatEventually(@"foo"), equalTo(@"foo"));

    XCTAssertNil(self.testFailure);
}

- (void)test_failsImmediately_withTimeoutZero
{
    NSTimeInterval maxTime = 0;
    NSTimeInterval waitTime = [self timeExecutingBlock:^{
        assertWithTimeout(maxTime, thatEventually(@"foo"), equalTo(@"bar"));
    }];

    XCTAssertEqualWithAccuracy(waitTime, maxTime, TIME_ERROR_MARGIN,
            @"Assert should have failed immediately");
}

- (void)test_fails_afterTimeoutGreaterThanZero
{
    NSTimeInterval maxTime = 0.2;
    NSTimeInterval waitTime = [self timeExecutingBlock:^{
        assertWithTimeout(maxTime, thatEventually(@"foo"), equalTo(@"bar"));
    }];

    XCTAssertEqualWithAccuracy(waitTime, maxTime, TIME_ERROR_MARGIN,
            @"Assert should have failed after %f seconds", maxTime);
}

- (void)test_assertWithTimeoutGreaterThanZero_shouldSucceedNotImmediatelyButBeforeTimeout
{
    NSTimeInterval maxTime = 1.0;
    NSTimeInterval succeedTime = 0.2;
    __block NSString *futureBar = @"foo";
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(succeedTime * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        futureBar = @"bar";
    });

    NSTimeInterval waitTime = [self timeExecutingBlock:^{
        assertWithTimeout(maxTime, thatEventually(futureBar), equalTo(@"bar"));
    }];

    XCTAssertTrue(waitTime > succeedTime - 0.01, @"Expect assert to terminate after value is changed, but was %lf", waitTime);
    XCTAssertTrue(waitTime < maxTime, @"Expect assert to terminate before timeout, but was %lf", waitTime);
}

- (NSTimeInterval)timeExecutingBlock:(void (^)(void))block
{
    NSTimeInterval start = machTimeInSeconds();
    block();
    return machTimeInSeconds() - start;
}

- (void)assertThatResultString:(NSString *)resultString containsExpectedString:(NSString *)expectedString
{
    XCTAssertNotNil(resultString);
    XCTAssertTrue([resultString rangeOfString:expectedString].location != NSNotFound);
}

- (void)test_assertionError_shouldDescribeExpectedAndActual
{
    NSString *expected = @"EXPECTED";
    NSString *actual = @"ACTUAL";
    NSString *expectedMessage = @"Expected \"EXPECTED\", but was \"ACTUAL\"";
    NSTimeInterval irrelevantMaxTime = 0;

    assertWithTimeout(irrelevantMaxTime, thatEventually(actual), equalTo(expected));

    [self assertThatResultString:self.testFailure.reason containsExpectedString:expectedMessage];
}

@end
