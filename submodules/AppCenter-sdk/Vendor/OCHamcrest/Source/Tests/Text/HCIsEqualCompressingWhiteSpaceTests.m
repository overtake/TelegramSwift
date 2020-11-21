//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsEqualCompressingWhiteSpace.h"

#import "MatcherTestCase.h"


@interface EqualToCompressingWhiteSpaceTests : MatcherTestCase
@end

@implementation EqualToCompressingWhiteSpaceTests
{
    id <HCMatcher> matcher;
}

- (void)setUp
{
    [super setUp];
    matcher = equalToCompressingWhiteSpace(@" Hello World   how\n are we? ");
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

- (void)test_matches_ifWordsAreSameButWhitespaceDiffers
{
    assertMatches(@"less whitespace", matcher, @"Hello World how are we?");
    assertMatches(@"more whitespace", matcher, @"   Hello World   how are \n\n\twe?");
}

- (void)test_doesNotMatch_ifTextOtherThanWhitespaceDiffers
{
    assertDoesNotMatch(@"wrong word", matcher, @"Hello PLANET how are we?");
    assertDoesNotMatch(@"incomplete", matcher, @"Hello World how are we");
}

- (void)test_doesNotMatch_ifWhitespaceIsAddedOrRemovedInMiddleOfWord
{
    assertDoesNotMatch(@"need whitespace between Hello and World",
                       matcher, @"HelloWorld how are we?");
    assertDoesNotMatch(@"wrong whitespace within World",
                       matcher, @"Hello Wo rld how are we?");
}

- (void)test_matcherCreation_requiresNonNilArgument
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(equalToCompressingWhiteSpace(nil), @"Should require non-nil argument");
#pragma clang diagnostic pop
}

- (void)test_doesNotMatch_ifMatchingAgainstNonString
{
    assertDoesNotMatch(@"non-string", matcher, @3);
}

- (void)test_hasReadableDescription
{
    assertDescription(@"\" Hello World   how\\n are we? \" ignoring whitespace", matcher);
}

- (void)test_successfulMatchDoesNotGenerateMismatchDescription
{
    assertNoMismatchDescription(equalToCompressingWhiteSpace(@"foo\nbar"), @"foo bar");
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
