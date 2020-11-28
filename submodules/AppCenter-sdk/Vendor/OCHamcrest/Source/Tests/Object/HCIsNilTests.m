//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsNil.h>

#import "MatcherTestCase.h"


@interface NilValueTests : MatcherTestCase
@end

@implementation NilValueTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = nilValue();

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsNil
{
    assertMatches(@"nil", nilValue(), nil);
}

- (void)test_doesNotMatch_ifArgumentIsNotNil
{
    id ANY_NON_NULL_ARGUMENT = [[NSObject alloc] init];

    assertDoesNotMatch(@"not nil", nilValue(), ANY_NON_NULL_ARGUMENT);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"nil", nilValue());
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(nilValue(), nil);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", nilValue(), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", nilValue(), @"bad");
}

@end


@interface NotNilValueTests : MatcherTestCase
@end

@implementation NotNilValueTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = notNilValue();

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsNotNil
{
    id ANY_NON_NULL_ARGUMENT = [[NSObject alloc] init];

    assertMatches(@"not nil", notNilValue(), ANY_NON_NULL_ARGUMENT);
}

- (void)test_doesNotMatch_ifArgumentIsNil
{
    assertDoesNotMatch(@"nil", notNilValue(), nil);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"not nil", notNilValue());
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(notNilValue(), @"hi");
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was nil", notNilValue(), nil);
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was nil", notNilValue(), nil);
}

@end

