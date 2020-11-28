//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsDictionaryContaining.h>

#import <OCHamcrest/HCIsAnything.h>
#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface HasEntryTests : MatcherTestCase
@end

@implementation HasEntryTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasEntry(@"irrelevant", @"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_dictionaryContainingMatchingKeyAndValue
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2};

    assertMatches(@"has a:1", hasEntry(equalTo(@"a"), equalTo(@1)), dict);
    assertMatches(@"has b:2", hasEntry(equalTo(@"b"), equalTo(@2)), dict);
    assertDoesNotMatch(@"no c:3", hasEntry(equalTo(@"c"), equalTo(@3)), dict);
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2};

    assertMatches(@"has a:1", hasEntry(@"a", equalTo(@1)), dict);
    assertMatches(@"has b:2", hasEntry(equalTo(@"b"), @2), dict);
    assertDoesNotMatch(@"no c:3", hasEntry(@"c", @3), dict);
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"nil", hasEntry(anything(), anything()), nil);
}

- (void)test_matcherCreation_requiresNonNilArguments
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasEntry(nil, @"value"), @"Should require non-nil argument");
    XCTAssertThrows(hasEntry(@"key", nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a dictionary containing { \"a\" = <1>; }", hasEntry(@"a", @1));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    NSDictionary *dict = @{@"a": @1};
    assertNoMismatchDescription(hasEntry(@"a", @1), dict);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", hasEntry(@"a", @1), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", hasEntry(@"a", @1), @"bad");
}

@end
