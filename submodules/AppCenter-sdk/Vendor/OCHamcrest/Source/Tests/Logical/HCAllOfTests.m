//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCAllOf.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCStringEndsWith.h>
#import <OCHamcrest/HCStringStartsWith.h>

#import "MatcherTestCase.h"


@interface AllOfTests : MatcherTestCase
@end

@implementation AllOfTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = allOf(equalTo(@"irrelevant"), equalTo(@"irrelevant"), nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_evaluatesToTheTheLogicalConjunctionOfTwoOtherMatchers
{
    id matcher = allOf(startsWith(@"goo"), endsWith(@"ood"), nil);

    assertMatches(@"didn't pass both sub-matchers", matcher, @"good");
    assertDoesNotMatch(@"didn't fail first sub-matcher", matcher, @"mood");
    assertDoesNotMatch(@"didn't fail second sub-matcher", matcher, @"goon");
    assertDoesNotMatch(@"didn't fail both sub-matchers", matcher, @"fred");
}

- (void)test_evaluatesToTheTheLogicalConjunctionOfManyOtherMatchers
{
    id matcher = allOf(startsWith(@"g"), startsWith(@"go"), endsWith(@"d"), startsWith(@"go"), startsWith(@"goo"), nil);

    assertMatches(@"didn't pass all sub-matchers", matcher, @"good");
    assertDoesNotMatch(@"didn't fail middle sub-matcher", matcher, @"goon");
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"both matchers", allOf(@"good", @"good", nil), @"good");
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"both matchers", allOfIn(@[@"good", @"good"]), @"good");
}

- (void)test_hasReadableDescription
{
    assertDescription(@"(\"good\" and \"bad\" and \"ugly\")",
                      allOf(equalTo(@"good"), equalTo(@"bad"), equalTo(@"ugly"), nil));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(allOf(equalTo(@"good"), equalTo(@"good"), nil),
                                @"good");
}

- (void)test_mismatchDescription_describesFirstFailingMatch
{
    assertMismatchDescription(@"instead of \"good\", was \"bad\"",
                              allOf(equalTo(@"bad"), equalTo(@"good"), nil),
                              @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"instead of \"good\", was \"bad\"",
                           allOf(equalTo(@"bad"), equalTo(@"good"), nil),
                           @"bad");
}

@end
