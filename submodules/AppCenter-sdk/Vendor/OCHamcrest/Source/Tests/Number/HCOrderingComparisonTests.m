//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCOrderingComparison.h>

#import "MatcherTestCase.h"


@interface HCOrderingComparisonTests : MatcherTestCase
@end

@implementation HCOrderingComparisonTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = greaterThan(@1);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_comparesObjects_forGreaterThan
{
    assertMatches(@"match", greaterThan(@1), @2);
    assertDoesNotMatch(@"no match", greaterThan(@1), @1);
}

- (void)test_comparesObjects_forLessThan
{
    assertMatches(@"match", lessThan(@1), @0);
    assertDoesNotMatch(@"no match", lessThan(@1), @1);
}

- (void)test_comparesObjects_forGreaterThanOrEqualTo
{
    assertMatches(@"match", greaterThanOrEqualTo(@1), @2);
    assertMatches(@"match", greaterThanOrEqualTo(@1), @1);
    assertDoesNotMatch(@"no match", greaterThanOrEqualTo(@1), @0);
}

- (void)test_comparesObjects_forLessThanOrEqualTo
{
    assertMatches(@"match", lessThanOrEqualTo(@1), @0);
    assertMatches(@"match", lessThanOrEqualTo(@1), @1);
    assertDoesNotMatch(@"no match", lessThanOrEqualTo(@1), @2);
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"nil argument", greaterThan(@1), nil);
}

- (void)test_supportsDifferentTypesOfComparableObjects
{
    assertMatches(@"strings", greaterThan(@"bb"), @"cc");
    assertMatches(@"dates", lessThan([NSDate date]), [NSDate distantPast]);
}

- (void)test_doesNotMatch_objectThatDoesNotCompare
{
    assertDoesNotMatch(@"can't compare", lessThan(@1), [NSDate date]);
    assertDoesNotMatch(@"can't compare", greaterThan(@1), [NSDate date]);
}

- (void)test_matcherCreation_requiresObjectWithCompareMethod
{
    id object = [[NSObject alloc] init];
    XCTAssertThrows(greaterThan(object), @"object does not have -compare: method");
}

- (void)test_hasReadableDescription
{
    id one = @1;

    assertDescription(@"a value greater than <1>", greaterThan(one));
    assertDescription(@"a value greater than or equal to <1>", greaterThanOrEqualTo(one));
    assertDescription(@"a value less than <1>", lessThan(one));
    assertDescription(@"a value less than or equal to <1>", lessThanOrEqualTo(one));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    id one = @1;

    assertNoMismatchDescription(greaterThan(one), @2);
    assertNoMismatchDescription(lessThan(one), @0);
    assertNoMismatchDescription(greaterThanOrEqualTo(one), @1);
    assertNoMismatchDescription(lessThanOrEqualTo(one), @1);
}

- (void)test_mismatchDescription
{
    id one = @1;

    assertMismatchDescription(@"was <0>", greaterThan(one), @0);
    assertMismatchDescription(@"was <2>", lessThan(one), @2);
    assertMismatchDescription(@"was <0>", greaterThanOrEqualTo(one), @0);
    assertMismatchDescription(@"was <2>", lessThanOrEqualTo(one), @2);
}

- (void)test_describeMismatch
{
    id one = @1;

    assertDescribeMismatch(@"was <0>", greaterThan(one), @0);
    assertDescribeMismatch(@"was <2>", lessThan(one), @2);
    assertDescribeMismatch(@"was <0>", greaterThanOrEqualTo(one), @0);
    assertDescribeMismatch(@"was <2>", lessThanOrEqualTo(one), @2);
}

@end
