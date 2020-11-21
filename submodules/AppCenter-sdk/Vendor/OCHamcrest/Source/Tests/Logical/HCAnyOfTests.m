//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCAnyOf.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCStringEndsWith.h>
#import <OCHamcrest/HCStringStartsWith.h>

#import "MatcherTestCase.h"


@interface AnyOfTests : MatcherTestCase
@end

@implementation AnyOfTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = anyOf(equalTo(@"irrelevant"), nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_evaluatesToTheTheLogicalDisjunctionOfTwoOtherMatchers
{
    id matcher = anyOf(startsWith(@"goo"), endsWith(@"ood"), nil);

    assertMatches(@"didn't pass both sub-matchers", matcher, @"good");
    assertMatches(@"didn't pass second sub-matcher", matcher, @"mood");
    assertMatches(@"didn't pass first sub-matcher", matcher, @"goon");
    assertDoesNotMatch(@"didn't fail both sub-matchers", matcher, @"flan");
}

- (void)test_evaluatesToTheTheLogicalDisjunctionOfManyOtherMatchers
{
    id matcher = anyOf(startsWith(@"g"), startsWith(@"go"), endsWith(@"d"), startsWith(@"go"), startsWith(@"goo"), nil);

    assertMatches(@"didn't pass middle sub-matcher", matcher, @"vlad");
    assertDoesNotMatch(@"didn't fail all sub-matchers", matcher, @"flan");
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"first matcher", anyOf(@"good", @"bad", nil), @"good");
    assertMatches(@"second matcher", anyOf(@"bad", @"good", nil), @"good");
    assertMatches(@"both matchers", anyOf(@"good", @"good", nil), @"good");
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"first matcher", anyOfIn(@[@"good", @"bad"]), @"good");
    assertMatches(@"second matcher", anyOfIn(@[@"bad", @"good"]), @"good");
    assertMatches(@"both matchers", anyOfIn(@[@"good", @"good"]), @"good");
}

- (void)test_hasReadableDescription
{
    assertDescription(@"(\"good\" or \"bad\" or \"ugly\")",
                      anyOf(equalTo(@"good"), equalTo(@"bad"), equalTo(@"ugly"), nil));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(anyOf(equalTo(@"good"), equalTo(@"good"), nil),
                                @"good");
}

- (void)test_mismatchDescription_describesFirstFailingMatch
{
    assertMismatchDescription(@"was \"ugly\"",
                              anyOf(equalTo(@"bad"), equalTo(@"good"), nil),
                              @"ugly");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"ugly\"",
                           anyOf(equalTo(@"bad"), equalTo(@"good"), nil),
                           @"ugly");
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(anyOf(nil), @"Should require non-nil list");
#pragma clang diagnostic pop
}

@end
