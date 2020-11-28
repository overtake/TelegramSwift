//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

    // System under test
#import <OCHamcrest/HCIsTrueFalse.h>

#import "MatcherTestCase.h"


@interface IsTrueTests : MatcherTestCase
@end

@implementation IsTrueTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isTrue();

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_nonZero
{
    assertMatches(@"boolean YES", isTrue(), @YES);
    assertMatches(@"non-zero", isTrue(), @123);
}

- (void)test_doesNotMatch_zero
{
    assertDoesNotMatch(@"boolean NO", isTrue(), @NO);
    assertDoesNotMatch(@"zero is false", isTrue(), @0);
}

- (void)test_doesNotMatch_nonNumber
{
    assertDoesNotMatch(@"non-number", isTrue(), [[NSObject alloc] init]);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"true (non-zero)", isTrue());
}

- (void)test_describesMismatch_ofDifferentNumber
{
    assertMismatchDescription(@"was <0>", isTrue(), @0);
}

- (void)test_describesMismatch_ofNonNumber
{
    assertMismatchDescriptionPrefix(@"was <NSObject:", isTrue(), [[NSObject alloc] init]);
}

@end

#pragma mark -

@interface IsFalseTests : MatcherTestCase
@end

@implementation IsFalseTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isFalse();

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_zero
{
    assertMatches(@"boolean NO", isFalse(), @NO);
    assertMatches(@"zero is false", isFalse(), @0);
}

- (void)test_doesNotMatch_nonZero
{
    assertDoesNotMatch(@"boolean YES", isFalse(), @YES);
    assertDoesNotMatch(@"non-zero is true", isFalse(), @123);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"false (zero)", isFalse());
}

- (void)test_describesMismatch_ofDifferentNumber
{
    assertMismatchDescription(@"was <123>", isFalse(), @123);
}

- (void)test_describesMismatch_ofNonNumber
{
    assertMismatchDescriptionPrefix(@"was <NSObject:", isFalse(), [[NSObject alloc] init]);
}

@end
