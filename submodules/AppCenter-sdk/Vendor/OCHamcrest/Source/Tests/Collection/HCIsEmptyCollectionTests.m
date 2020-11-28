//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsEmptyCollection.h>

#import "MatcherTestCase.h"
#import "FakeWithCount.h"
#import "FakeWithoutCount.h"


@interface IsEmptyTests : MatcherTestCase
@end


@implementation IsEmptyTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isEmpty();

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_nonCollection
{
    assertDoesNotMatch(@"Non collection", isEmpty(), [[NSObject alloc] init]);
}

- (void)test_matches_emptyCollection
{
    assertMatches(@"empty", isEmpty(), [FakeWithCount fakeWithCount:0]);
}

- (void)test_doesNotMatchesNonEmptyCollection
{
    assertDoesNotMatch(@"non-empty", isEmpty(), [FakeWithCount fakeWithCount:1]);
}

- (void)test_doesNotMatch_itemWithoutCount
{
    assertDoesNotMatch(@"no count", isEmpty(), [FakeWithoutCount fake]);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"empty collection", isEmpty());
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", isEmpty(), @"bad");
}

- (void)test_describesMismatch
{
    assertDescribeMismatch(@"was <FakeWithCount>", isEmpty(), [FakeWithCount fakeWithCount:1]);
}

@end
