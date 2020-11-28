//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCHasCount.h>

#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCOrderingComparison.h>

#import "MatcherTestCase.h"
#import "FakeWithCount.h"
#import "FakeWithoutCount.h"


@interface HasCountTests : MatcherTestCase
@end

@implementation HasCountTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasCount(equalTo(@42));

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_convertsCountToNSNumberAndPassesToNestedMatcher
{
    FakeWithCount *fakeWithCount = [FakeWithCount fakeWithCount:5];

    assertMatches(@"same number", hasCount(equalTo(@5)), fakeWithCount);
    assertDoesNotMatch(@"different number", hasCount(equalTo(@6)), fakeWithCount);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection with count of a value greater than <5>",
                      hasCount(greaterThan(@(5))));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(hasCountOf(2), ([NSSet setWithObjects:@1, @2, nil]));
}

- (void)test_mismatchDescription_forItemWithWrongCount
{
    assertMismatchDescription(@"was count of <42> with <FakeWithCount>",
                              hasCount(equalTo(@1)), [FakeWithCount fakeWithCount:42]);
}

- (void)test_mismatchDescription_forItemWithoutCount
{
    assertMismatchDescription(@"was <FakeWithoutCount>",
                              hasCount(equalTo(@1)), [FakeWithoutCount fake]);
}

- (void)test_describesMismatch_forItemWithWrongCount
{
    assertDescribeMismatch(@"was count of <42> with <FakeWithCount>",
                           hasCount(equalTo(@1)), [FakeWithCount fakeWithCount:42]);
}

- (void)test_describesMismatch_forItemWithoutCount
{
    assertDescribeMismatch(@"was <FakeWithoutCount>",
                           hasCount(equalTo(@1)), [FakeWithoutCount fake]);
}

@end


@interface HasCountOfTests : MatcherTestCase
@end

@implementation HasCountOfTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasCountOf(42);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_hasCountOf_isShortcutForEqualToUnsignedInteger
{
    FakeWithCount *fakeWithCount = [FakeWithCount fakeWithCount:5];

    assertMatches(@"same number", hasCountOf(5), fakeWithCount);
    assertDoesNotMatch(@"different number", hasCountOf(6), fakeWithCount);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a collection with count of <5>", hasCountOf(5));
}

- (void)test_mismatchDescription_forItemWithWrongCount
{
    assertMismatchDescription(@"was count of <42> with <FakeWithCount>",
                              hasCountOf(1), [FakeWithCount fakeWithCount:42]);
}

- (void)test_mismatchDescription_forItemWithoutCount
{
    assertMismatchDescription(@"was <FakeWithoutCount>", hasCountOf(1), [FakeWithoutCount fake]);
}

- (void)test_describesMismatch_forItemWithWrongCount
{
    assertDescribeMismatch(@"was count of <42> with <FakeWithCount>",
                           hasCountOf(1), [FakeWithCount fakeWithCount:42]);
}

- (void)test_describesMismatch_forItemWithoutCount
{
    assertDescribeMismatch(@"was <FakeWithoutCount>", hasCountOf(1), [FakeWithoutCount fake]);
}

@end
