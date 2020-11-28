//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt
//  Contribution by Todd Farrell

#import <OCHamcrest/HCConformsToProtocol.h>

#import "MatcherTestCase.h"


@protocol TestProtocol
@end

@interface TestClass : NSObject <TestProtocol>
@end

@implementation TestClass

+ (instancetype)test_class
{
    return [[TestClass alloc] init];
}

@end

@interface ConformsToTests : MatcherTestCase
@end

@implementation ConformsToTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = conformsTo(@protocol(TestProtocol));

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentConformsToASpecificProtocol
{
    TestClass *instance = [TestClass test_class];

    assertMatches(@"conforms to protocol", conformsTo(@protocol(TestProtocol)), instance);

    assertDoesNotMatch(@"does not conform to protocol", conformsTo(@protocol(TestProtocol)), @"hi");
    assertDoesNotMatch(@"nil", conformsTo(@protocol(TestProtocol)), nil);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(conformsTo(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_hasReadableDescription
{
    assertDescription(@"an object that conforms to TestProtocol", conformsTo(@protocol(TestProtocol)));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(conformsTo(@protocol(NSObject)), @"hi");
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", conformsTo(@protocol(TestProtocol)), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", conformsTo(@protocol(TestProtocol)), @"bad");
}

@end
