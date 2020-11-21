//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCollectionContainingInRelativeOrder.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface ContainsInRelativeOrderTests : MatcherTestCase
@end

@implementation ContainsInRelativeOrderTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = containsInRelativeOrder(@[equalTo(@"irrelevant")]);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_nonCollection
{
    id matcher = containsInRelativeOrder(@[equalTo(@"irrelevant")]);

    assertDoesNotMatch(@"Non collection", matcher, [[NSObject alloc] init]);
}

- (void)test_matches_singleItemCollection
{
    id matcher = containsInRelativeOrder(@[equalTo(@1)]);

    assertMatches(@"Single item collection", matcher, @[@1]);
}

- (void)test_matches_multipleItemCollection
{
    id matcher = containsInRelativeOrder(@[equalTo(@1), equalTo(@2), equalTo(@3)]);

    assertMatches(@"Multiple item sequence", matcher, (@[@1, @2, @3]));
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    id matcher = containsInRelativeOrder(@[@1, @2, @3]);

    assertMatches(@"Values automatically wrapped with equalTo", matcher, (@[@1, @2, @3]));
}

- (void)test_matches_withMoreElementsThanExpectedAtBeginning
{
    id matcher = containsInRelativeOrder(@[@2, @3, @4]);

    assertMatches(@"More elements at beginning", matcher, (@[@1, @2, @3, @4]));
}

- (void)test_matches_withMoreElementsThanExpectedAtEnd
{
    id matcher = containsInRelativeOrder(@[@1, @2, @3]);

    assertMatches(@"More elements at end", matcher, (@[@1, @2, @3, @4]));
}

- (void)test_matches_withMoreElementsThanExpectedInBetween
{
    id matcher = containsInRelativeOrder(@[@1, @3]);

    assertMatches(@"More elements in between", matcher, (@[@1, @2, @3]));
}

- (void)test_matches_subsection
{
    id matcher = containsInRelativeOrder(@[@2, @3]);

    assertMatches(@"Subsection of collection", matcher, (@[@1, @2, @3, @4]));
}

- (void)test_matches_withSingleGapAndNotFirstOrLast
{
    id matcher = containsInRelativeOrder(@[@2, @4]);

    assertMatches(@"Subsection with single gaps without a first or last match", matcher, (@[@1, @2, @3, @4, @5]));
}

- (void)test_matches_subsectionWithManyGaps
{
    id matcher = containsInRelativeOrder(@[@2, @4, @6]);

    assertMatches(@"Subsection with many gaps collection", matcher, (@[@1, @2, @3, @4, @5, @6, @7]));
}

- (void)test_doesNotMatch_withFewerElementsThanExpected
{
    id matcher = containsInRelativeOrder(@[@1, @2, @3]);

    assertMismatchDescription(@"<3> was not found after <2>", matcher, (@[@1, @2]));
}

- (void)test_doesNotMatch_ifSingleItemNotFound
{
    id matcher = containsInRelativeOrder(@[@4]);

    assertMismatchDescription(@"<4> was not found", matcher, (@[@3]));
}

- (void)test_doesNotMatch_ifOneOfMultipleItemsNotFound
{
    id matcher = containsInRelativeOrder(@[@1, @2, @3]);

    assertMismatchDescription(@"<3> was not found after <2>", matcher, (@[@1, @2, @4]));
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"Should not match nil", containsInRelativeOrder(@[@1]), nil);
}

- (void)test_doesNotMatch_emptyCollection
{
    assertMismatchDescription(@"<4> was not found", containsInRelativeOrder(@[@4]), @[]);
}

- (void)test_doesNotMatch_objectWithoutEnumerator
{
    assertDoesNotMatch(@"should not match object without enumerator",
                       containsInRelativeOrder(@[@1]), [[NSObject alloc] init]);
}

- (void)test_matcherCreation_requiresNonEmptyArgument
{
    XCTAssertThrows(containsInRelativeOrder(@[]), @"Should require non-empty array");
}

- (void)test_hasReadableDescription
{
    id matcher = containsInRelativeOrder(@[@1, @2]);

    assertDescription(@"a collection containing [<1>, <2>] in relative order", matcher);
}

- (void)test_describeMismatch_ofNonCollection
{
    assertDescribeMismatch(@"was non-collection nil", (containsInRelativeOrder(@[@1])), nil);
}

@end
