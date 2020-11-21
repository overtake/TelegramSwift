//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCArgumentCaptor.h"

#import "MatcherTestCase.h"


@interface HCArgumentCaptorTests : MatcherTestCase
@end

@implementation HCArgumentCaptorTests
{
    HCArgumentCaptor *sut;
}

- (void)setUp
{
    [super setUp];
    sut = [[HCArgumentCaptor alloc] init];
}

- (void)tearDown
{
    sut = nil;
    [super tearDown];
}

- (void)test_matcher_shouldAlwaysEvaluateToTrue
{
    assertMatches(@"nil", sut, nil);
    assertMatches(@"some object", sut, @123);
}

- (void)test_matcher_shouldHaveReadableDescription
{
    assertDescription(@"<Capturing argument>", sut);
}

- (void)test_value_shouldBeLastCapturedValue
{
    [sut matches:@"FOO"];
    [sut matches:@"BAR"];

    XCTAssertEqualObjects(sut.value, @"BAR");
}

- (void)test_value_shouldBeCopyIfItCanBeCopied
{
    NSMutableString *original = [@"FOO" mutableCopy];
    
    [sut matches:original];
    
    XCTAssertFalse(sut.value == original);
}

- (void)test_value_shouldBeOriginalIfItCannotBeCopied
{
    id original = [[NSObject alloc] init];

    [sut matches:original];

    XCTAssertTrue(sut.value == original);
}

- (void)test_value_withNothingCaptured_shouldReturnNil
{
    XCTAssertNil(sut.value);
}

- (void)test_value_givenNil_shouldReturnNSNull
{
    [sut matches:@"FOO"];
    [sut matches:nil];

    XCTAssertEqualObjects(sut.value, [NSNull null]);
}

- (void)test_allValues_shouldCaptureValuesInOrder
{
    [sut matches:@"FOO"];
    [sut matches:@"BAR"];

    XCTAssertEqual(sut.allValues.count, 2U);
    XCTAssertEqualObjects(sut.allValues[0], @"FOO");
    XCTAssertEqualObjects(sut.allValues[1], @"BAR");
}

- (void)test_allValues_turningOffCaptureEnabled_shouldNotCaptureSubsequentValues
{
    [sut matches:@"FOO"];
    sut.captureEnabled = NO;
    [sut matches:@"BAR"];
    [sut matches:@"BAZ"];

    XCTAssertEqual(sut.allValues.count, 1U);
    XCTAssertEqualObjects(sut.allValues[0], @"FOO");
}

- (void)test_allValues_turningCaptureEnabledBackOn_shouldCaptureSubsequentValues
{
    sut.captureEnabled = NO;
    [sut matches:@"FOO"];
    sut.captureEnabled = YES;
    [sut matches:@"BAR"];
    [sut matches:@"BAZ"];

    XCTAssertEqual(sut.allValues.count, 2U);
    XCTAssertEqualObjects(sut.allValues[0], @"BAR");
    XCTAssertEqualObjects(sut.allValues[1], @"BAZ");
}

- (void)test_allValues_givenNil_shouldCaptureNSNull
{
    [sut matches:nil];

    XCTAssertEqualObjects(sut.allValues[0], [NSNull null]);
}

- (void)test_allValues_shouldReturnImmutableArray
{
    [sut matches:@"FOO"];

    XCTAssertFalse([sut.allValues respondsToSelector:@selector(addObject:)]);
}

@end
