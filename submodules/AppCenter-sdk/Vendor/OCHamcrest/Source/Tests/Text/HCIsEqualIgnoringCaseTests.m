//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCIsEqualIgnoringCase.h>

#import "MatcherTestCase.h"


@interface IsEqualIgnoringCaseTests : MatcherTestCase
@end

@implementation IsEqualIgnoringCaseTests
{
    id <HCMatcher> matcher;
}

- (void)setUp
{
    [super setUp];
    matcher = equalToIgnoringCase(@"heLLo");
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

- (void)test_matches_ignoringCaseOfCharsInString
{
    assertMatches(@"all upper", matcher, @"HELLO");
    assertMatches(@"all lower", matcher, @"hello");
    assertMatches(@"mixed up", matcher, @"HelLo");

    assertDoesNotMatch(@"no match", matcher, @"bye");
}

- (void)test_doesNotMatch_ifAdditionalWhitespaceIsPresent
{
    assertDoesNotMatch(@"whitespace suffix", matcher, @"heLLo ");
    assertDoesNotMatch(@"whitespace prefix", matcher, @" heLLo");
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(equalToIgnoringCase(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_doesNotMatch_ifMatchingAgainstNonString
{
    assertDoesNotMatch(@"non-string", matcher, @3);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"\"heLLo\" ignoring case", matcher);
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(matcher, @"hello");
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
