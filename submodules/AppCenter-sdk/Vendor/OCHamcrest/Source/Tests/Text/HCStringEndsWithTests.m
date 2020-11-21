//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCStringEndsWith.h>

#import "MatcherTestCase.h"

static NSString *EXCERPT = @"EXCERPT";


@interface EndsWithTests : MatcherTestCase
@end

@implementation EndsWithTests
{
    id <HCMatcher> matcher;
}

- (void)setUp
{
    [super setUp];
    matcher = endsWith(EXCERPT);
}

- (void)tearDown
{
    matcher = nil;
    [super tearDown];
}

- (void)test_copesWithNilsAndUnknownTypes
{
    assertNilSafe(matcher);
    assertUnknownTypeSafe(matcher);
}

- (void)test_matches_ifArgumentContainsSpecifiedSubstring
{
    assertDoesNotMatch(@"excerpt at beginning", matcher, [EXCERPT stringByAppendingString:@"END"]);
    assertMatches(@"excerpt at end", matcher, [@"START" stringByAppendingString:EXCERPT]);
    assertDoesNotMatch(@"excerpt in middle", matcher,
                  [[@"START" stringByAppendingString:EXCERPT] stringByAppendingString:@"END"]);
    assertMatches(@"excerpt repeated", matcher, [EXCERPT stringByAppendingString:EXCERPT]);

    assertDoesNotMatch(@"excerpt not in string", matcher, @"whatever");
    assertDoesNotMatch(@"only part of excerpt", matcher, [EXCERPT substringFromIndex:1]);
}

- (void)test_matches_ifArgumentIsEqualToSubstring
{
    assertMatches(@"excerpt is entire string", matcher, EXCERPT);
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(endsWith(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_doesNotMatch_ifMatchingAgainstNonString
{
    assertDoesNotMatch(@"non-string", matcher, @3);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"a string ending with \"EXCERPT\"", matcher);
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(matcher, EXCERPT);
}

- (void)test_mismatchDescription_showsActualArgument
{
    assertMismatchDescription(@"was \"bad\"", matcher, @"bad");
}

- (void)test_describeMismatch
{
    assertDescribeMismatch(@"was \"bad\"", matcher, @"bad");
}

@end
