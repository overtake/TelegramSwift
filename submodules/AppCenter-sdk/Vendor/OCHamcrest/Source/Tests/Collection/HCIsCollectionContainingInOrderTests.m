//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCollectionContainingInOrder.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


@interface ContainsTests : MatcherTestCase
@end

@implementation ContainsTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = contains(equalTo(@"irrelevant"), nil);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_doesNotMatch_nonCollection
{
    id matcher = contains(equalTo(@"irrelevant"), nil);

    assertDoesNotMatch(@"Non collection", matcher, [[NSObject alloc] init]);
}

- (void)test_matches_singleItemCollection
{
    id matcher = contains(equalTo(@1), nil);

    assertMatches(@"Single item collection", matcher, @[@1]);
}

- (void)test_matches_multipleItemCollection
{
    id matcher = contains(equalTo(@1), equalTo(@2), equalTo(@3), nil);

    assertMatches(@"Multiple item sequence", matcher, (@[@1, @2, @3]));
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    id matcher = contains(@1, @2, @3, nil);

    assertMatches(@"Values automatically wrapped with equalTo", matcher, (@[@1, @2, @3]));
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWithEqualTo
{
    id matcher = containsIn(@[@1, @2, @3]);

    assertMatches(@"Values automatically wrapped with equalTo", matcher, (@[@1, @2, @3]));
}

- (void)test_doesNotMatch_withMoreElementsThanExpected
{
    id matcher = contains(@1, @2, @3, nil);

    assertMismatchDescription(@"exceeded count of 3 with item <999>", matcher, (@[@1, @2, @3, @999]));
}

- (void)test_doesNotMatch_withFewerElementsThanExpected
{
    id matcher = contains(@1, @2, @3, nil);

    assertMismatchDescription(@"no item was <3>", matcher, (@[@1, @2]));
}

- (void)test_doesNotMatch_ifSingleItemMismatches
{
    id matcher = contains(@4, nil);

    assertMismatchDescription(@"item 0: was <3>", matcher, @[@3]);
}

- (void)test_doesNotMatch_ifOneOfMultipleItemsMismatch
{
    id matcher = contains(@1, @2, @3, nil);

    assertMismatchDescription(@"item 2: was <4>", matcher, (@[@1, @2, @4]));
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"Should not match nil", contains(@1, nil), nil);
}

- (void)test_doesNotMatch_emptyCollection
{
    assertMismatchDescription(@"no item was <4>", (contains(@4, nil)), @[]);
}

- (void)test_doesNotMatch_objectWithoutEnumerator
{
    assertDoesNotMatch(@"should not match object without enumerator",
                       contains(@1, nil), [[NSObject alloc] init]);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection containing [<1>, <2>]", contains(@1, @2, nil));
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"item 1: was <3>",
                           (contains(@1, @2, nil)),
                           (@[@1, @3]));
}

- (void)test_describeMismatch_ofNonCollection
{
    assertDescribeMismatch(@"was non-collection nil", (contains(@1, @2, nil)), nil);
}

@end
