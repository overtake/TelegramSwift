//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsCollectionContaining.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"
#import "Mismatchable.h"


@interface HasItemTests : MatcherTestCase
@end

@implementation HasItemTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasItem(equalTo(@"irrelevant"));

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_aCollectionThatContainsAnElementForTheGivenMatcher
{
    id matcher = hasItem(equalTo(@1));

    assertMatches(@"list containing 1", matcher, (@[@1, @2, @3]));
}

- (void)test_doesNotMatch_collectionWithoutAnElementForGivenMatcher
{
    id matcher = hasItem([Mismatchable mismatchable:@"a"]);

    assertMismatchDescription(@"mismatches were: [mismatched: b, mismatched: c]", matcher, (@[@"b", @"c"]));
    assertMismatchDescription(@"was empty", matcher, @[]);
}

- (void)test_doesNotMatch_nil
{
    assertDoesNotMatch(@"doesn't match nil", hasItem(equalTo(@1)), nil);
}

- (void)test_providesConvenientShortcutForMatchingWithEqualTo
{
    assertMatches(@"list contains '1'", hasItem(@1), ([NSSet setWithObjects:@1, @2, @3, nil]));
    assertDoesNotMatch(@"list without '1'", hasItem(@1), ([NSSet setWithObjects:@2, @3, nil]));
}

- (void)test_doesNotMatch_nonCollection
{
    assertMismatchDescription(@"was non-collection nil", hasItem(equalTo(@1)), nil);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(hasItem(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection containing <1>", hasItem(@1));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(hasItem(@1), ([NSSet setWithObjects:@1, @2, nil]));
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was non-collection \"bad\"", hasItem(@1), @"bad");
}

- (void)test_matches_multipleItemsInCollection
{
    id matcher1 = hasItems(equalTo(@1), equalTo(@2), equalTo(@3), nil);
    assertMatches(@"list containing all items", matcher1, (@[@1, @2, @3]));

    id matcher2 = hasItems(@1, @2, @3, nil);
    assertMatches(@"list containing all items (without matchers)", matcher2, (@[@1, @2, @3]));

    id matcher3 = hasItems(equalTo(@1), equalTo(@2), equalTo(@3), nil);
    assertMatches(@"list containing all items in any order", matcher3, (@[@3, @2, @1]));

    id matcher4 = hasItems(equalTo(@1), equalTo(@2), equalTo(@3), nil);
    assertMatches(@"list containing all items plus others", matcher4, (@[@5, @3, @2, @1, @4]));

    id matcher5 = hasItems(equalTo(@1), equalTo(@2), equalTo(@3), nil);
    assertDoesNotMatch(@"not match list unless it contains all items", matcher5, (@[@5, @3, @2, @4])); // '1' missing
}

- (void)test_hasItems_providesConvenientShortcutForMatchingWIthEqualTo
{
    assertMatches(@"list containing all items", hasItems(@1, @2, @3, nil), (@[ @1, @2, @3 ]));
}

- (void)test_arrayVariant_providesConvenientShortcutForMatchingWIthEqualTo
{
    assertMatches(@"list containing all items", hasItemsIn(@[@1, @2, @3]), (@[ @1, @2, @3 ]));
}

- (void)test_reportsMismatchWithAReadableDescriptionForMultipleItems
{
    id matcher = hasItems(@3, @4, nil);

    assertMismatchDescription(@"instead of a collection containing <4>, mismatches were: [was <1>, was <2>, was <3>]",
            matcher, (@[@1, @2, @3]));
}

@end
