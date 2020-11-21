//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCThrowsException.h>

#import <OCHamcrest/HCHasProperty.h>
#import <OCHamcrest/HCIsAnything.h>
#import <OCHamcrest/HCIsSame.h>

#import "MatcherTestCase.h"


@interface ThrowsExceptionTests : MatcherTestCase
@end

@implementation ThrowsExceptionTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = throwsException(anything());

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_blockNotThrowingException
{
    id matcher = throwsException(anything());

    assertDoesNotMatch(@"does not throw", matcher, ^{});
}

- (void)test_matches_blockThrowingExceptionSatisfyingMatcher
{
    NSException *exception = [NSException exceptionWithName:@"" reason:@"" userInfo:nil];
    id matcher = throwsException(sameInstance(exception));

    assertMatches(@"throws matching exception", matcher, ^{ @throw exception; });
}

- (void)test_doesNotMatch_blockThrowingExceptionNotSatisfyingMatcher
{
    id matcher = throwsException(hasProperty(@"name", @"FOO"));

    assertDoesNotMatch(@"throws non-matching exception", matcher,
            ^{ @throw [NSException exceptionWithName:@"BAR" reason:@"" userInfo:nil]; });
}

- (void)test_doesNotMatch_nonBlock
{
    id matcher = throwsException(anything());

    assertDoesNotMatch(@"not a block", matcher, [[NSObject alloc] init]);
}

- (void)test_matcherCreation_requiresMatcherArgument
{
    XCTAssertThrows(throwsException([[NSObject alloc] init]), @"Should require matcher argument");
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a block with no arguments, throwing an exception which is an object with name \"FOO\"",
            throwsException(hasProperty(@"name", @"FOO")));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    id matcher = throwsException(anything());

    assertNoMismatchDescription(matcher,
            ^{ @throw [NSException exceptionWithName:@"" reason:@"" userInfo:nil]; });
}

- (void)test_mismatchDescription_OnNonBlock_shouldSayNeedABlock
{
    id matcher = throwsException(anything());

    assertMismatchDescription(@"was non-block nil", matcher, nil);
}

- (void)test_mismatchDescription_OnBlockNotThrowingException_shouldSayNoThrow
{
    id matcher = throwsException(anything());

    assertMismatchDescription(@"no exception thrown", matcher, ^{});
}

- (void)test_mismatchDescription_OnBlockThrowingExceptionNotSatisfyingMatcher
{
    id matcher = throwsException(hasProperty(@"name", @"FOO"));

    assertMismatchDescriptionPrefix(@"exception thrown but name was \"BAR\" on <NSException:",
            matcher, ^{ @throw [NSException exceptionWithName:@"BAR" reason:@"" userInfo:nil]; });
}

@end
