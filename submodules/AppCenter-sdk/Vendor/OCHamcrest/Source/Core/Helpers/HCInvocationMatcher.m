//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCInvocationMatcher.h"


@interface HCInvocationMatcher ()
@property (nonatomic, strong) NSInvocation *invocation;
@property (nonatomic, strong) id <HCMatcher> subMatcher;
@end

@implementation HCInvocationMatcher

- (instancetype)initWithInvocation:(NSInvocation *)anInvocation matching:(id <HCMatcher>)aMatcher
{
    self = [super init];
    if (self)
    {
        _invocation = anInvocation;
        _subMatcher = aMatcher;
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if ([self invocationNotSupportedForItem:item])
        return NO;

    return [self.subMatcher matches:[self invokeOn:item]];
}

- (BOOL)invocationNotSupportedForItem:(id)item
{
    return ![item respondsToSelector:self.invocation.selector];
}

- (id)invokeOn:(id)item
{
    __unsafe_unretained id result = nil;
    [self.invocation invokeWithTarget:item];
    [self.invocation getReturnValue:&result];
    return result;
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    if ([self invocationNotSupportedForItem:item])
        [super describeMismatchOf:item to:mismatchDescription];
    else
    {
        [self describeLongMismatchDescriptionOf:item to:mismatchDescription];
        [self.subMatcher describeMismatchOf:[self invokeOn:item] to:mismatchDescription];
    }
}

- (void)describeLongMismatchDescriptionOf:(id)item to:(id <HCDescription>)mismatchDescription
{
    if (!self.shortMismatchDescription)
    {
        [[[[mismatchDescription appendDescriptionOf:item]
                                appendText:@" "]
                                appendText:[self stringFromSelector]]
                                appendText:@" "];
    }
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[[description appendText:@"an object with "]
            appendText:[self stringFromSelector]]
            appendText:@" "]
            appendDescriptionOf:self.subMatcher];
}

- (NSString *)stringFromSelector
{
    return NSStringFromSelector(self.invocation.selector);
}

@end
