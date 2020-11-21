//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "MatcherTestCase.h"

#import <OCHamcrest/HCMatcher.h>
#import <OCHamcrest/HCStringDescription.h>


static NSString *mismatchDescription(id <HCMatcher> matcher, id arg)
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    [matcher describeMismatchOf:arg to:description];
    return description.description;
}


@implementation MatcherTestCase

- (void)failWithMessage:(NSString *)message
        inFile:(char const *)fileName atLine:(NSUInteger)lineNumber
{
    [self recordFailureWithDescription:message inFile:@(fileName) atLine:lineNumber expected:YES];
}

- (void)failEqualityBetweenObject:(id)left andObject:(id)right withMessage:(NSString *)message
        inFile:(char const *)fileName atLine:(NSUInteger)lineNumber
{
    [self recordFailureWithDescription:message inFile:@(fileName) atLine:lineNumber expected:YES];
}

- (void)assertMatcherSafeWithNil:(id <HCMatcher>)matcher
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    @try
    {
        [matcher matches:nil];
    }
    @catch (NSException *e)
    {
        [self failWithMessage:@"Matcher was not nil safe"
                       inFile:fileName atLine:lineNumber];
    }
}

- (void)assertMatcherSafeWithUnknownType:(id <HCMatcher>)matcher
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    @try
    {
        [matcher matches:[[NSObject alloc] init]];
    }
    @catch (NSException *e)
    {
        [self failWithMessage:@"Matcher was not unknown type safe"
                       inFile:fileName atLine:lineNumber];
    }
}

- (void)assertMatcher:(id <HCMatcher>)matcher matches:(nullable id)arg message:(NSString *)expectation
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    if (![matcher matches:arg])
    {
        NSString *message = [NSString stringWithFormat:@"%@ because '%@'",
                                                    expectation, mismatchDescription(matcher, arg)];
        [self failWithMessage:message inFile:fileName atLine:lineNumber];
    }
}

- (void)assertTrue:(BOOL)condition message:(NSString *)message
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    if (!condition)
    {
        [self failWithMessage:message inFile:fileName atLine:lineNumber];
    }
}

- (void)assertFalse:(BOOL)condition message:(NSString *)message
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    [self assertTrue:!condition message:message inFile:fileName atLine:lineNumber];
}

- (void)assertString:(NSString *)str1 equalsString:(NSString *)str2 message:(NSString *)message
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    if (![str1 isEqualToString:str2])
    {
        [self failEqualityBetweenObject:str1 andObject:str2 withMessage:message
                                 inFile:fileName atLine:lineNumber];
    }
}

- (void)assertDescription:(HCStringDescription *)description matches:(NSString *)expected
                   inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    NSString *actual = description.description;
    NSString *message = [NSString stringWithFormat:@"Expected description '%@' but got '%@", expected, actual];
    [self assertString:expected equalsString:actual message:message
                inFile:fileName atLine:lineNumber];
}

- (void)assertMatcher:(id <HCMatcher>)matcher hasDescription:(NSString *)expected
               inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    [description appendDescriptionOf:matcher];
    [self assertDescription:description matches:expected inFile:fileName atLine:lineNumber];
}

- (void)assertMatcher:(id <HCMatcher>)matcher hasNoMismatchDescriptionFor:(nullable id)arg
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    [self assertTrue:[matcher matches:arg] message:@"Precondition: Matcher should match item"
              inFile:fileName atLine:lineNumber];
    if (description.description.length != 0)
    {
        [self failWithMessage:@"Expected no mismatch description"
                       inFile:fileName atLine:lineNumber];
    }
}

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg yieldsMismatchDescription:(NSString *)expected
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    // Make sure matcher has been called before, like assertThat would have done.
    [matcher matches:arg];
    [self assertFalse:[matcher matches:arg describingMismatchTo:description]
              message:@"Precondition: Matcher should not match item"
               inFile:fileName atLine:lineNumber];
    [self assertDescription:description matches:expected inFile:fileName atLine:lineNumber];
}

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg
        yieldsMismatchDescriptionPrefix:(NSString *)expectedPrefix
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    // Make sure matcher has been called before, like assertThat would have done.
    [matcher matches:arg];
    [self assertFalse:[matcher matches:arg describingMismatchTo:description]
              message:@"Precondition: Matcher should not match item"
               inFile:fileName atLine:lineNumber];
    NSString *actual = description.description;
    if (![actual hasPrefix:expectedPrefix])
    {
        [self failEqualityBetweenObject:actual andObject:expectedPrefix
                            withMessage:@"Expected mismatch description prefix match"
                                 inFile:fileName atLine:lineNumber];
    }
}

- (void)assertMatcher:(id <HCMatcher>)matcher matching:(nullable id)arg describesMismatch:(NSString *)expected
        inFile:(const char *)fileName atLine:(NSUInteger)lineNumber
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    [matcher describeMismatchOf:arg to:description];
    [self assertDescription:description matches:expected inFile:fileName atLine:lineNumber];
}

@end
