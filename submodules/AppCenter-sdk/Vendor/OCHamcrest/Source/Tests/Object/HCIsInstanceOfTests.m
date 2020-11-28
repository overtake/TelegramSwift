//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsInstanceOf.h>

#import "MatcherTestCase.h"
#import "SomeClassAndSubclass.h"


@interface InstanceOfTests : MatcherTestCase
@end

@implementation InstanceOfTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = instanceOf([SomeClass class]);

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsInstanceOfGivenClass
{
    SomeClass *obj = [[SomeClass alloc] init];
    assertMatches(@"same class", instanceOf([SomeClass class]), obj);
}

- (void)test_matches_ifArgumentIsSubclassOfGivenClass
{
    SomeSubclass *sub = [[SomeSubclass alloc] init];
    assertMatches(@"subclass", instanceOf([SomeClass class]), sub);
}

- (void)test_doesNotMatch_ifArgumentIsInstanceOfDifferentClass
{
    assertDoesNotMatch(@"different class", instanceOf([SomeClass class]), @"hi");
}

- (void)test_doesNotMatch_ifArgumentIsNil
{
    assertDoesNotMatch(@"nil", instanceOf([NSNumber class]), nil);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(instanceOf(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"an instance of SomeClass", instanceOf([SomeClass class]));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(instanceOf([SomeClass class]), [[SomeClass alloc] init]);
}

- (void)test_mismatchDescription_showsClassOfActualArgument
{
    assertMismatchDescription(@"was SomeClass instance <SOME_CLASS>",
                              instanceOf([NSValue class]), [[SomeClass alloc] init]);
}

- (void)test_mismatchDescription_handlesNilArgument
{
    assertMismatchDescription(@"was nil", instanceOf([NSValue class]), nil);
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was SomeClass instance <SOME_CLASS>",
                           instanceOf([NSValue class]), [[SomeClass alloc] init]);
}

@end
