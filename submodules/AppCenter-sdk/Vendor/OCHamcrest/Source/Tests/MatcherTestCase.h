//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

@import XCTest;

@protocol HCMatcher;


NS_ASSUME_NONNULL_BEGIN

@interface MatcherTestCase : XCTestCase

- (void)assertMatcherSafeWithNil:(id <HCMatcher>)matcher
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcherSafeWithUnknownType:(id <HCMatcher>)matcher
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher matches:(nullable id)arg message:(NSString *)expectation
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertFalse:(BOOL)condition message:(NSString *)message
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher hasDescription:(NSString *)expected
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher hasNoMismatchDescriptionFor:(nullable id)arg
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg yieldsMismatchDescription:(NSString *)expected
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg
        yieldsMismatchDescriptionPrefix:(NSString *)expectedPrefix
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg describesMismatch:(NSString *)expected
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber;

@end

#define assertNilSafe(matcher)  \
    [self assertMatcherSafeWithNil:matcher inFile:__FILE__ atLine:__LINE__]

#define assertUnknownTypeSafe(matcher)  \
    [self assertMatcherSafeWithUnknownType:matcher inFile:__FILE__ atLine:__LINE__]

#define assertMatches(aMessage, matcher, arg)    \
    [self assertMatcher:matcher matches:arg message:aMessage inFile:__FILE__ atLine:__LINE__]

#define assertDoesNotMatch(aMessage, matcher, arg)    \
    [self assertFalse:[matcher matches:arg] message:aMessage inFile:__FILE__ atLine:__LINE__]

#define assertDescription(expected, matcher)    \
    [self assertMatcher:matcher hasDescription:expected inFile:__FILE__ atLine:__LINE__]

#define assertNoMismatchDescription(matcher, arg)   \
    [self assertMatcher:matcher hasNoMismatchDescriptionFor:arg inFile:__FILE__ atLine:__LINE__]

#define assertMismatchDescription(expected, matcher, arg)   \
    [self assertMatcher:matcher matching:arg yieldsMismatchDescription:expected inFile:__FILE__ atLine:__LINE__]

#define assertMismatchDescriptionPrefix(expectedPrefix, matcher, arg)   \
    [self assertMatcher:matcher matching:arg yieldsMismatchDescriptionPrefix:expectedPrefix inFile:__FILE__ atLine:__LINE__]

#define assertDescribeMismatch(expected, matcher, arg)  \
    [self assertMatcher:matcher matching:arg describesMismatch:expected inFile:__FILE__ atLine:__LINE__]

NS_ASSUME_NONNULL_END
