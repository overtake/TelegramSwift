//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsDictionaryContainingKey.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface HasKeyTests : MatcherTestCase
@end

@implementation HasKeyTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasKey(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_singletonDictionaryContainingKey
{
    NSDictionary *dict = @{@"a": @1};

    assertMatches(@"Matches single key", hasKey(equalTo(@"a")), dict);
}

- (void)test_matches_dictionaryContainingKey
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"Matches a", hasKey(equalTo(@"a")), dict);
    assertMatches(@"Matches c", hasKey(equalTo(@"c")), dict);
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"Matches c", hasKey(@"c"), dict);
}

- (void)test_doesNotMatch_emptyDictionary
{
    assertDoesNotMatch(@"empty", hasKey(@"Foo"), @{});
}

- (void)test_doesNotMatch_dictionaryMissingKey
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertDoesNotMatch(@"no matching key", hasKey(@"d"), dict);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasKey(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a dictionary containing key \"a\"", hasKey(@"a"));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    NSDictionary *dict = @{@"a": @1};
    assertNoMismatchDescription(hasKey(@"a"), dict);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", hasKey(@"a"), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", hasKey(@"a"), @"bad");
}

@end
