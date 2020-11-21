//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIs.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"
#import "NeverMatch.h"


@interface IsTests : MatcherTestCase
@end

@implementation IsTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = is(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_delegatesMatchingToNestedMatcher
{
    assertMatches(@"should match", is(equalTo(@"A")), @"A");
    assertMatches(@"should match", is(equalTo(@"B")), @"B");
    assertDoesNotMatch(@"should not match", is(equalTo(@"A")), @"B");
    assertDoesNotMatch(@"should not match", is(equalTo(@"B")), @"A");
}

- (void)test_descriptionShouldPassThrough
{
    assertDescription(@"\"A\"", is(equalTo(@"A")));
}

- (void)test_providesConvenientShortcutForIsEqualTo
{
    assertMatches(@"should match", is(@"A"), @"A");
    assertMatches(@"should match", is(@"B"), @"B");
    assertDoesNotMatch(@"should not match", is(@"A"), @"B");
    assertDoesNotMatch(@"should not match", is(@"B"), @"A");
    assertDescription(@"\"A\"", is(@"A"));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(is(@"A"), @"A");
}

- (void)test_delegatesMismatchDescriptionToNestedMatcher
{
    assertMismatchDescription([NeverMatch mismatchDescription],
                              is([NeverMatch neverMatch]),
                              @"hi");
}

- (void)test_delegatesDescribeMismatchToNestedMatcher
{
    assertDescribeMismatch([NeverMatch mismatchDescription],
                           is([NeverMatch neverMatch]),
                           @"hi");
}

@end
