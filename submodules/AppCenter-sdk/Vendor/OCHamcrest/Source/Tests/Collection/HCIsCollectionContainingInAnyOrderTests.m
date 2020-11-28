//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCollectionContainingInAnyOrder.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface ContainsInAnyOrderTests : MatcherTestCase
@end

@implementation ContainsInAnyOrderTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = containsInAnyOrder(equalTo(@"irrelevant"), nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_nonCollection
{
    id matcher = containsInAnyOrder(equalTo(@"irrelevant"), nil);

    assertDoesNotMatch(@"Non collection", matcher, [[NSObject alloc] init]);
}

- (void)test_matches_singleItemCollection
{
    assertMatches(@"single item", (containsInAnyOrder(equalTo(@1), nil)), @[@1]);
}

- (void)test_doesNotMatch_empty
{
    id matcher = containsInAnyOrder(equalTo(@1), equalTo(@2), nil);

    assertMismatchDescription(@"no item matches: <1>, <2> in []", matcher, @[]);
}

- (void)test_matches_collectionOutOfOrder
{
    id matcher = containsInAnyOrder(equalTo(@1), equalTo(@2), nil);

    assertMatches(@"Out of order", matcher, (@[@2, @1]));
}

- (void)test_matches_collectionInOfOrder
{
    id matcher = containsInAnyOrder(equalTo(@1), equalTo(@2), nil);

    assertMatches(@"In order", matcher, (@[@1, @2]));
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    id matcher = containsInAnyOrder(@1, @2, nil);

    assertMatches(@"Values automatically wrapped with equalTo", matcher, (@[@2, @1]));
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    id matcher = containsInAnyOrderIn(@[@1, @2]);

    assertMatches(@"Values automatically wrapped with equalTo", matcher, (@[@2, @1]));
}

- (void)test_doesNotMatch_nil
{
    id matcher = containsInAnyOrder(@1, nil);

    assertMismatchDescription(@"was non-collection nil", matcher, nil);
}

- (void)test_doesNotMatch_ifOneOfMultipleItemsMismatch
{
    id matcher = containsInAnyOrder(@1, @2, @3, nil);

    assertMismatchDescription(@"not matched: <4>", matcher, (@[@1, @2, @4]));
}

- (void)test_doesNotMatch_ifThereAreMoreElementsThanMatchers
{
    id matcher = containsInAnyOrder(@1, @3, nil);

    assertMismatchDescription(@"not matched: <2>", matcher, (@[@1, @2, @3]));
}

- (void)test_doesNotMatch_ifThereAreMoreMatchersThanElements
{
    id matcher = containsInAnyOrder(@1, @2, @3, @4, nil);

    assertMismatchDescription(@"no item matches: <4> in [<1>, <2>, <3>]", matcher, (@[@1, @2, @3]));
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection over [<1>, <2>] in any order",
                      containsInAnyOrder(@1, @2, nil));
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"not matched: <3>",
                           (containsInAnyOrder(@1, @2, nil)),
                           (@[@1, @3]));
}

@end
