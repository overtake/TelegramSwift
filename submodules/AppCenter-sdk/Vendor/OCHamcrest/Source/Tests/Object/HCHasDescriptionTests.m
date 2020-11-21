//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCHasDescription.h>

#import <OCHamcrest/HCIsEqual.h>

#import "MatcherTestCase.h"


static NSString *fakeDescription = @"DESCRIPTION";

@interface FakeWithDescription : NSObject
@end

@implementation FakeWithDescription
+ (instancetype)fake  { return [[self alloc] init]; }
- (NSString *)description  { return fakeDescription; }
@end


@interface HasDescriptionTests : MatcherTestCase
@end

@implementation HasDescriptionTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = hasDescription(equalTo(@"irrelevant"));

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_passesResultOfDescriptionToNestedMatcher
{
    FakeWithDescription* fake = [FakeWithDescription fake];
    assertMatches(@"equal", hasDescription(equalTo(fakeDescription)), fake);
    assertDoesNotMatch(@"unequal", hasDescription(equalTo(@"foo")), fake);
}

- (void)test_providesConvenientShortcutForDescriptionEqualTo
{
    FakeWithDescription* fake = [FakeWithDescription fake];
    assertMatches(@"equal", hasDescription(fakeDescription), fake);
    assertDoesNotMatch(@"unequal", hasDescription(@"foo"), fake);
}

- (void)test_mismatchDoesNotRepeatTheDescription
{
    FakeWithDescription* fake = [FakeWithDescription fake];
    assertMismatchDescription(@"was \"DESCRIPTION\"", hasDescription(@"foo"), fake);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"an object with description \"foo\"", hasDescription(@"foo"));
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(hasDescription(@"DESCRIPTION"), [FakeWithDescription fake]);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", hasDescription(@"foo"), @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", hasDescription(@"foo"), @"bad");
}

@end
