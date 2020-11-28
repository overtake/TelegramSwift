//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsDictionaryContainingEntries.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface HasEntriesTests : MatcherTestCase
@end

@implementation HasEntriesTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasEntries(@"irrelevant", @"irrelevant", nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matcherCreation_requiresEvenNumberOfArgs
{
    XCTAssertThrows(hasEntries(@"a", nil), @"Should require pairs of arguments");
}

- (void)test_doesNotMatch_nonDictionary
{
    id object = [[NSObject alloc] init];
    assertDoesNotMatch(@"not dictionary", hasEntries(@"a", equalTo(@1), nil), object);
}

- (void)test_matches_dictionaryContainingSingleKeyWithMatchingValue
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2};

    assertMatches(@"has a:1", hasEntries(@"a", equalTo(@1), nil), dict);
    assertMatches(@"has b:2", hasEntries(@"b", equalTo(@2), nil), dict);
    assertDoesNotMatch(@"no b:3", hasEntries(@"b", equalTo(@3), nil), dict);
    assertDoesNotMatch(@"no c:2", hasEntries(@"c", equalTo(@2), nil), dict);
}

- (void)test_matches_dictionaryContainingMultipleKeysWithMatchingValues
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"has a & b", hasEntries(@"a", equalTo(@1), @"b", equalTo(@2), nil), dict);
    assertMatches(@"has c & a", hasEntries(@"c", equalTo(@3), @"a", equalTo(@1), nil), dict);
    assertDoesNotMatch(@"no d:3", hasEntries(@"d", equalTo(@3), nil), dict);
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    NSDictionary *dict = @{@"a": @1,
                           @"b": @2,
                           @"c": @3};

    assertMatches(@"has a & b", hasEntries(@"a", @1, @"b", @2, nil), dict);
    assertMatches(@"has c & a", hasEntries(@"c", @3, @"a", @1, nil), dict);
    assertDoesNotMatch(@"no d:3", hasEntries(@"d", @3, nil), dict);
}

- (void)test_dictionaryVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    NSDictionary *dict = @{@"a": @1,
            @"b": @2,
            @"c": @3};

    assertMatches(@"has a & b", hasEntriesIn(@{@"a": @1, @"b": @2}), dict);
    assertMatches(@"has c & a", hasEntriesIn(@{@"c": @3, @"a": @1}), dict);
    assertDoesNotMatch(@"no d:3", hasEntriesIn(@{@"d": @3}), dict);
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"nil", hasEntries(@"a", @1, nil), nil);
}

- (void)test_matcherCreation_requiresNonNilArguments
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasEntries(nil, @"value", nil), @"Should require non-nil argument");
    XCTAssertThrows(hasEntries(@"key", nil, nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a dictionary containing { \"a\" = <1>; \"b\" = <2>; }",
                      hasEntries(@"a", @1, @"b", @2, nil));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    NSDictionary *dict = @{@"a": @1};
    assertNoMismatchDescription(hasEntries(@"a", @1, nil), dict);
}

- (void)test_mismatchDescription_ofNonDictionary_showsActualArgument
{
    assertMismatchDescription(@"was non-dictionary \"bad\"", hasEntries(@"a", @1, nil), @"bad");
}

- (void)test_mismatchDescription_ofDictionaryWithoutKey
{
    NSDictionary *dict = @{@"a": @1, @"c": @3};
    assertMismatchDescription(@"no \"b\" key in <{\n    a = 1;\n    c = 3;\n}>",
                              hasEntries(@"a", @1, @"b", @2, nil), dict);
}

- (void)test_mismatchDescription_ofDictionaryWithNonMatchingValue
{
    NSDictionary *dict = @{@"a": @2};
    assertMismatchDescription(@"value for \"a\" was <2>", hasEntries(@"a", @1, nil), dict);
}

- (void)test_describeMismatch_ofNonDictionaryShowsActualArgument
{
    assertDescribeMismatch(@"was non-dictionary \"bad\"", hasEntries(@"a", @1, nil), @"bad");
}

- (void)test_describeMismatch_ofDictionaryWithoutKey
{
    NSDictionary *dict = @{@"a": @1, @"c": @3};
    assertDescribeMismatch(@"no \"b\" key in <{\n    a = 1;\n    c = 3;\n}>",
                           hasEntries(@"a", @1, @"b", @2, nil), dict);
}

- (void)test_describeMismatch_ofDictionaryWithNonMatchingValue
{
    NSDictionary *dict = @{@"a": @2};
    assertDescribeMismatch(@"value for \"a\" was <2>", hasEntries(@"a", @1, nil), dict);
}

@end
