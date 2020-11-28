//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCloseTo.h>

#import "MatcherTestCase.h"


@interface CloseToTests : MatcherTestCase
@end

@implementation CloseToTests

- (void)test_copesWithNilsAndUnknownTypes
{
    double irrelevant = 0.1;
    id matcher = closeTo(irrelevant, irrelevant);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsEqualToADoubleValueWithinSomeError
{
    id matcher = closeTo(1.0, 0.5);

    assertMatches(@"equal", matcher, @1.0);
    assertMatches(@"less but within delta", matcher, @0.5);
    assertMatches(@"greater but within delta", matcher, @1.5);

    assertDoesNotMatch(@"too small", matcher, @0.4);
    assertDoesNotMatch(@"too big", matcher, @1.6);
}

- (void)test_doesNotMatch_nonNumber
{
    id matcher = closeTo(1.0, 0.5);

    assertDoesNotMatch(@"not a number", matcher, @"a");
    assertDoesNotMatch(@"not a number", matcher, nil);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a numeric value within <0.5> of <1>", closeTo(1.0, 0.5));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(closeTo(1.0, 0.5), (@1.0));
}

- (void)test_mismatchDescription_showsActualDeltaIfArgumentIsNumeric
{
    assertMismatchDescription(@"<1.7> differed by <0.7>",
                              (closeTo(1.0, 0.5)), @1.7);
}

- (void)test_mismatchDescription_showsActualArgumentIfNotNumeric
{
    assertMismatchDescription(@"was \"bad\"", (closeTo(1.0, 0.5)), @"bad");
}

- (void)test_describeMismatch_showsActualDeltaIfArgumentIsNumeric
{
    assertDescribeMismatch(@"<1.7> differed by <0.7>",
                           (closeTo(1.0, 0.5)), @1.7);
}

- (void)test_describeMismatch_showsActualArgumentIfNotNumeric
{
    assertDescribeMismatch(@"was \"bad\"", (closeTo(1.0, 0.5)), @"bad");
}

@end
