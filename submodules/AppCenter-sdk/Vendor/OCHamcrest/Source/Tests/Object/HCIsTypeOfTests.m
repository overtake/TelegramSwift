//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsTypeOf.h>

#import "MatcherTestCase.h"
#import "SomeClassAndSubclass.h"


@interface HCIsTypeOfTests : MatcherTestCase
@end

@implementation HCIsTypeOfTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = isA([SomeClass class]);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsInstanceOfGivenClass
{
    SomeClass *obj = [[SomeClass alloc] init];
    assertMatches(@"same class", isA([SomeClass class]), obj);
}

- (void)test_doesNotMatch_ifArgumentIsSubclassOfGivenClass
{
    SomeSubclass *sub = [[SomeSubclass alloc] init];
    assertDoesNotMatch(@"subclass", isA([SomeClass class]), sub);
}

- (void)test_doesNotMatch_ifArgumentIsInstanceOfDifferentClass
{
    assertDoesNotMatch(@"different class", isA([SomeClass class]), @"hi");
}

- (void)test_doesNotMatch_ifArgumentIsNil
{
    assertDoesNotMatch(@"nil", isA([NSNumber class]), nil);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(isA(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"an exact instance of SomeClass", isA([SomeClass class]));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(isA([SomeClass class]), [[SomeClass alloc] init]);
}

- (void)test_mismatchDescription_showsClassOfActualArgument
{
    assertMismatchDescription(@"was SomeSubclass instance <SOME_SUBCLASS>",
                              isA([SomeClass class]), [[SomeSubclass alloc] init]);
}

- (void)test_mismatchDescription_handlesNilArgument
{
    assertMismatchDescription(@"was nil", isA([SomeClass class]), nil);
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was SomeSubclass instance <SOME_SUBCLASS>",
                           isA([SomeClass class]), [[SomeSubclass alloc] init]);
}

@end
