//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCStringContainsInOrder.h>

#import "MatcherTestCase.h"


@interface StringContainsInOrderTests : MatcherTestCase
@end

@implementation StringContainsInOrderTests
{
    id <HCMatcher> matcher;
}

- (void)setUp
{
    [super setUp];
    matcher = stringContainsInOrder(@"string one", @"string two", @"string three", nil);
}

- (void)tearDown
{
    matcher = nil;
    [super tearDown];
}

- (void)test_copesWithNilsAndUnknownTypes
{
    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifOrderIsCorrect
{
    assertMatches(@"correct order", matcher, @"string one then string two followed by string three");
}

- (void)test_arrayVariant_matchesIfOrderIsCorrect
{
    id <HCMatcher> variantMatcher = stringContainsInOrderIn(@[@"string one", @"string two", @"string three"]);

    assertMatches(@"correct order", variantMatcher, @"string one then string two followed by string three");
}

- (void)test_doesNotMatch_ifOrderIsIncorrect
{
    assertDoesNotMatch(@"incorrect order", matcher, @"string two then string one followed by string three");
}

- (void)test_doesNotMatch_ifExpectedSubstringsAreMissing
{
    assertDoesNotMatch(@"missing string one", matcher, @"string two then string three");
    assertDoesNotMatch(@"missing string two", matcher, @"string one then string three");
    assertDoesNotMatch(@"missing string three", matcher, @"string one then string two");
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(stringContainsInOrder(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_matcherCreation_requiresStringArguments
{
    XCTAssertThrows(stringContainsInOrder(@"one", @2, nil), @"Should require strings");
}

- (void)test_doesNotMatch_ifMatchingAgainstNonString
{
    assertDoesNotMatch(@"non-string", matcher, @3);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a string containing \"string one\", \"string two\", \"string three\" in order",
                      matcher);
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(matcher, @"string one then string two followed by string three");
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", matcher, @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", matcher, @"bad");
}

@end
