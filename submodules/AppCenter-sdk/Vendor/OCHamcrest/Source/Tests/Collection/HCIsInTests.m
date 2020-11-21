//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsIn.h>

#import "MatcherTestCase.h"


@interface IsInTests : MatcherTestCase
@end

@implementation IsInTests


- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isIn(@[@1, @2, @3]);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsInCollection
{
    id matcher = isIn(@[@1, @2, @3]);

    assertMatches(@"has 1", matcher, @1);
    assertMatches(@"has 2", matcher, @2);
    assertMatches(@"has 3", matcher, @3);
    assertDoesNotMatch(@"no 4", matcher, @4);
}

- (void)test_matcherCreation_requiresObjectWithContainsObjectMethod
{
    id object = [[NSObject alloc] init];

    XCTAssertThrows(isIn(object), @"object does not have -containsObject: method");
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(isIn(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    id matcher = isIn(@[@1, @2, @3]);

    assertDescription(@"one of {<1>, <2>, <3>}", matcher);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", isIn(@[@1]), @"bad");
}

- (void)test_describesMismatch
{
    assertDescribeMismatch(@"was \"bad\"", isIn(@[@1]), @"bad");
}

@end
