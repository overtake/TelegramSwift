//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsDictionaryContainingValue.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface HasValueTests : MatcherTestCase
@end

@implementation HasValueTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasValue(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_singletonDictionaryContainingValue
{
    NSDictionary *dict = @{@"a": @1};

    assertMatches(@"same single value", hasValue(equalTo(@1)), dict);
}

- (void)test_matches_dictionaryContainingValue
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"Matches 1", hasValue(equalTo(@1)), dict);
    assertMatches(@"Matches 3", hasValue(equalTo(@3)), dict);
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"Matches 3", hasValue(@3), dict);
}

- (void)test_doesNotMatch_emptyDictionary
{
    assertDoesNotMatch(@"Empty dictionary", hasValue(@"Foo"), @{});
}

- (void)test_doesNotMatch_dictionaryMissingValue
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertDoesNotMatch(@"no matching value", hasValue(@4), dict);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasValue(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a dictionary containing value <1>", hasValue(@1));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    NSDictionary *dict = @{@"a": @1};
    assertNoMismatchDescription(hasValue(@1), dict);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", hasValue(@1), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", hasValue(@1), @"bad");
}

@end
