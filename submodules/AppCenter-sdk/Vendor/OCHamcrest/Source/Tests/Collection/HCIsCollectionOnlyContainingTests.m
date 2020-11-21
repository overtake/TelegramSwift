//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCollectionOnlyContaining.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCOrderingComparison.h>

#import "MatcherTestCase.h"
#import "Mismatchable.h"


@interface OnlyContainsTests : MatcherTestCase
@end

@implementation OnlyContainsTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = onlyContains(equalTo(@"irrelevant"), nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_emptyCollection
{
    id matcher = onlyContains(equalTo(@"irrelevant"), nil);

    assertMismatchDescription(@"was empty", matcher, @[]);
}

- (void)test_reportAllElementsThatDoNotMatch
{
    id matcher = onlyContains([Mismatchable mismatchable:@"a"], nil);

    assertMismatchDescription(@"mismatches were: [was \"b\", was \"c\"]", matcher, (@[@"b", @"a", @"c"]));
}

- (void)test_doesNotMatch_nonCollection
{
    id matcher = onlyContains(equalTo(@"irrelevant"), nil);

    assertMismatchDescription(@"was non-collection nil", matcher, nil);
}

- (void)test_matches_singletonCollection
{
    assertMatches(@"singleton collection",
                  onlyContains(equalTo(@1), nil),
                  [NSSet setWithObject:@1]);
}

- (void)test_matches_allItemsWithOneMatcher
{
    assertMatches(@"one matcher",
                  onlyContains(lessThan(@4), nil),
                  (@[@1, @2, @3]));
}

- (void)test_matches_allItemsWithMultipleMatchers
{
    assertMatches(@"multiple matcher",
                  onlyContains(lessThan(@4), equalTo(@"hi"), nil),
                  (@[@1, @"hi", @2, @3]));
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"Values automatically wrapped with equal_to",
                  onlyContains(lessThan(@4), @"hi", nil),
                  (@[@1, @"hi", @2, @3]));
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"Values automatically wrapped with equal_to",
            onlyContainsIn(@[lessThan(@4), @"hi"]),
            (@[@1, @"hi", @2, @3]));
}

- (void)test_doesNotMatch_collectionWithMismatchingItem
{
    assertDoesNotMatch(@"4 is not less than 4",
                       onlyContains(lessThan(@4), nil),
                       (@[@2, @3, @4]));
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(onlyContains(nil), @"Should require non-nil list");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection containing items matching (<1> or <2>)",
                        onlyContains(@1, @2, nil));
}

@end
