//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCThrowsException.h"


static void HCRequireMatcher(id obj)
{
    if (![obj conformsToProtocol:@protocol(HCMatcher)])
    {
        @throw [NSException exceptionWithName:@"NonMatcher"
                                       reason:@"Must be matcher"
                                     userInfo:nil];
    }
}


@interface HCThrowsException()
@property (nonatomic, strong, readonly) id <HCMatcher> exceptionMatcher;
@end

@implementation HCThrowsException

- (id)initWithExceptionMatcher:(id)exceptionMatcher
{
    HCRequireMatcher(exceptionMatcher);

    self = [super init];
    if (self)
        _exceptionMatcher = exceptionMatcher;
    return self;
}

- (BOOL)matches:(nullable id)item describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    if (![self isBlock:item])
    {
        [[mismatchDescription appendText:@"was non-block "] appendDescriptionOf:item];
        return NO;
    }

    typedef void (^HCThrowsExceptionBlock)(void);
    HCThrowsExceptionBlock block = item;
    @try
    {
        block();
    }
    @catch (id exception)
    {
        BOOL match = [self.exceptionMatcher matches:exception];
        if (!match)
        {
            [mismatchDescription appendText:@"exception thrown but "];
            [self.exceptionMatcher describeMismatchOf:exception to:mismatchDescription];
        }
        return match;
    }

    [mismatchDescription appendText:@"no exception thrown"];
    return NO;
}

- (BOOL)isBlock:(id)item
{
    id block = ^{};
    Class blockClass = [block class];
    while ([blockClass superclass] != [NSObject class])
        blockClass = [blockClass superclass];
    return [item isKindOfClass:blockClass];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a block with no arguments, throwing an exception which is "]
            appendDescriptionOf:self.exceptionMatcher];
}

@end


id HC_throwsException(id exceptionMatcher)
{
    return [[HCThrowsException alloc] initWithExceptionMatcher:exceptionMatcher];
}
