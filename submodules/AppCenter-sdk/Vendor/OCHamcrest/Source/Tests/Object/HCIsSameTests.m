//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsSame.h>

#import <OCHamcrest/HCAssertThat.h>
#import <OCHamcrest/HCIsNot.h>
#import <OCHamcrest/HCStringDescription.h>

#import "MatcherTestCase.h"


@interface SameInstanceTests : MatcherTestCase
@end

@implementation SameInstanceTests

- (void)test_copesWithNilsAndUnknownTypes
{
    id matcher = sameInstance(@"irrelevant");

    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentIsReferenceToSpecifiedObject
{
    id o1 = [[NSObject alloc] init];
    id o2 = [[NSObject alloc] init];

    assertThat(o1, sameInstance(o1));
    assertThat(o2, isNot(sameInstance(o1)));
}

- (void)test_doesNotMatch_equalObjects
{
    NSString *string1 = @"foobar";
    NSString *string2 = [@"foo" stringByAppendingString:@"bar"];

    assertDoesNotMatch(@"not the same object", sameInstance(string1), string2);
}

- (void)test_descriptionIncludesMemoryAddress
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    NSPredicate *expected = [NSPredicate predicateWithFormat:
                             @"SELF MATCHES 'same instance as 0x[0-9a-fA-F]+ \"abc\"'"];

    [description appendDescriptionOf:sameInstance(@"abc")];
    XCTAssertTrue([expected evaluateWithObject:description.description]);
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    id o1 = [[NSObject alloc] init];
    assertNoMismatchDescription(sameInstance(o1), o1);
}

- (void)test_mismatchDescription_showsActualArgumentAddress
{
    id matcher = sameInstance(@"foo");
    HCStringDescription *description = [HCStringDescription stringDescription];
    NSPredicate *expected = [NSPredicate predicateWithFormat:
                             @"SELF MATCHES 'was 0x[0-9a-fA-F]+ \"hi\"'"];

    BOOL result = [matcher matches:@"hi" describingMismatchTo:description];
    XCTAssertFalse(result, @"Precondition: Matcher should not match item");
    XCTAssertTrue([expected evaluateWithObject:description.description]);
}

- (void)test_mismatchDescription_withNilShouldNotIncludeAddress
{
    assertMismatchDescription(@"was nil", sameInstance(@"foo"), nil);
}

- (void)test_describeMismatch
{
    id matcher = sameInstance(@"foo");
    HCStringDescription *description = [HCStringDescription stringDescription];
    NSPredicate *expected = [NSPredicate predicateWithFormat:
                             @"SELF MATCHES 'was 0x[0-9a-fA-F]+ \"hi\"'"];

    [matcher describeMismatchOf:@"hi" to:description];
    XCTAssertTrue([expected evaluateWithObject:description.description]);
}

- (void)test_describeMismatch_withNilShouldNotIncludeAddress
{
    assertDescribeMismatch(@"was nil", sameInstance(@"foo"), nil);
}

@end
