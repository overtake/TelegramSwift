//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsNot.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCHasCount.h>

#import "MatcherTestCase.h"
#import "HCIsInstanceOf.h"


@interface IsNotTests : MatcherTestCase
@end

@implementation IsNotTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isNot(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_evaluatesToTheTheLogicalNegationOfAnotherMatcher
{
    id matcher = isNot(equalTo(@"A"));

    assertMatches(@"invert mismatch", matcher, @"B");
    assertDoesNotMatch(@"invert match", matcher, @"A");
}

- (void)test_providesConvenientShortcutForNotEqualTo
{
    id matcher = isNot(@"A");

    assertMatches(@"invert mismatch", matcher, @"B");
    assertDoesNotMatch(@"invert match", matcher, @"A");
}

- (void)test_usesDescriptionOfNegatedMatcherWithPrefix
{
    assertDescription(@"not an instance of NSString", isNot(instanceOf([NSString class])));
    assertDescription(@"not \"A\"", isNot(@"A"));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(isNot(@"A"), @"B");
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"A\"", isNot(@"A"), @"A");
}

- (void)test_mismatchDescription_showsActualSubMatcherDescription
{
    NSArray *item = @[@"A", @"B"];
    NSString *expected = [NSString stringWithFormat:@"was count of <2> with <%@>", item];
    assertMismatchDescription(expected, isNot(hasCountOf(item.count)), item);
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"A\"", isNot(@"A"), @"A");
}

@end
