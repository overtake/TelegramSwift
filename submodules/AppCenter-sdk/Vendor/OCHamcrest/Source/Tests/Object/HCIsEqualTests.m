//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface FakeArgument : NSObject
@end

@implementation FakeArgument
- (NSString *)description  { return @"ARGUMENT DESCRIPTION"; }
@end


@interface AlwaysEqual : NSObject
@end

@implementation AlwaysEqual
- (BOOL)isEqual:(id)anObject  { return YES; }
@end


@interface NeverEqual : NSObject
@end

@implementation NeverEqual
- (BOOL)isEqual:(id)anObject  { return NO; }
@end


@interface EqualToTests : MatcherTestCase
@end

@implementation EqualToTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = equalTo(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_comparesObjectsUsingIsEqualMethod
{
    assertMatches(@"equal strings", equalTo(@"hi"), @"hi");
    assertDoesNotMatch(@"unequal strings", equalTo(@"hi"), @"bye");
}

- (void)test_canCompareNilValues
{
    assertMatches(@"nil equals nil", equalTo(nil), nil);

    assertDoesNotMatch(@"nil as argument", equalTo(@"hi"), nil);
    assertDoesNotMatch(@"nil in equalTo", equalTo(nil), @"hi");
}

- (void)test_honorsIsEqualImplementationEvenWithNilValues
{
    assertMatches(@"always equal", equalTo(nil), [[AlwaysEqual alloc] init]);
    assertDoesNotMatch(@"never equal", equalTo(nil), [[NeverEqual alloc] init]);
}

- (void)test_includesTheResultOfCallingDescriptionOnItsArgumentInTheDescription
{
    assertDescription(@"<ARGUMENT DESCRIPTION>", equalTo([[FakeArgument alloc] init]));
}

- (void)test_returnsAnObviousDescriptionIfCreatedWithANestedMatcherByMistake
{
    id innerMatcher = equalTo(@"NestedMatcher");
    assertDescription(([@[@"<", [innerMatcher description], @">"]
                      componentsJoinedByString:@""]),
                      equalTo(innerMatcher));
}

- (void)test_returnsGoodDescriptionIfCreatedWithNilReference
{
    assertDescription(@"nil", equalTo(nil));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(equalTo(@"hi"), @"hi");
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", equalTo(@"good"), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", equalTo(@"good"), @"bad");
}

@end
