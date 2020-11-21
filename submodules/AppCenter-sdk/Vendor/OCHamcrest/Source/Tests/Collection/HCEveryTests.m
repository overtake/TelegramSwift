//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCEvery.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCOrderingComparison.h>

#import "MatcherTestCase.h"
#import "Mismatchable.h"


@interface EveryItemTests : MatcherTestCase
@end

@implementation EveryItemTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = everyItem(equalTo(@"irrelevant"));

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_emptyCollection
{
    id matcher = everyItem(equalTo(@"irrelevant"));

    assertMismatchDescription(@"was empty", matcher, @[]);
}

- (void)test_reportAllElementsThatDoNotMatch
{
    id matcher = everyItem([Mismatchable mismatchable:@"a"]);

    assertMismatchDescription(@"mismatches were: [mismatched: b, mismatched: c]", matcher, (@[@"b", @"a", @"c"]));
}

- (void)test_doesNotMatch_nonCollection
{
    id matcher = everyItem(equalTo(@"irrelevant"));

    assertMismatchDescription(@"was non-collection nil", matcher, nil);
}

- (void)test_matches_singletonCollection
{
    assertMatches(@"singleton collection", everyItem(equalTo(@1)), [NSSet setWithObject:@1]);
}

- (void)test_matches_allItemsWithOneMatcher
{
    assertMatches(@"one matcher", everyItem(lessThan(@4)), (@[@1, @2, @3]));
}

- (void)test_doesNotMatch_collectionWithMismatchingItem
{
    assertDoesNotMatch(@"4 is not less than 4", everyItem(lessThan(@4)), (@[@2, @3, @4]));
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(everyItem(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"every item is a value less than <4>", everyItem(lessThan(@4)));
}

@end
