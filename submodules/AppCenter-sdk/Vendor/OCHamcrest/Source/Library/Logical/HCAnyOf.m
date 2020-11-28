//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCAnyOf.h"

#import "HCCollect.h"


@interface HCAnyOf ()
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *matchers;
@end

@implementation HCAnyOf

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)matchers
{
    self = [super init];
    if (self)
        _matchers = [matchers copy];
    return self;
}

- (BOOL)matches:(nullable id)item
{
    for (id <HCMatcher> oneMatcher in self.matchers)
        if ([oneMatcher matches:item])
            return YES;
    return NO;
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendList:self.matchers start:@"(" separator:@" or " end:@")"];
}

@end


id HC_anyOfIn(NSArray *matchers)
{
    return [[HCAnyOf alloc] initWithMatchers:HCWrapIntoMatchers(matchers)];
}

id HC_anyOf(id matchers, ...)
{
    va_list args;
    va_start(args, matchers);
    NSArray *array = HCCollectItems(matchers, args);
    va_end(args);

    return HC_anyOfIn(array);
}
