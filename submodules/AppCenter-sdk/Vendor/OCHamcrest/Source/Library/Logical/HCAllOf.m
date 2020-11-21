//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCAllOf.h"

#import "HCCollect.h"


@interface HCAllOf ()
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *matchers;
@end

@implementation HCAllOf

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)matchers
{
    self = [super init];
    if (self)
        _matchers = [matchers copy];
    return self;
}

- (BOOL)matches:(nullable id)item describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    for (id <HCMatcher> oneMatcher in self.matchers)
    {
        if (![oneMatcher matches:item])
        {
            [[[mismatchDescription appendText:@"instead of "]
                                   appendDescriptionOf:oneMatcher]
                                   appendText:@", "];
            [oneMatcher describeMismatchOf:item to:mismatchDescription];
            return NO;
        }
    }
    return YES;
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendList:self.matchers start:@"(" separator:@" and " end:@")"];
}

@end


id HC_allOfIn(NSArray *matchers)
{
    return [[HCAllOf alloc] initWithMatchers:HCWrapIntoMatchers(matchers)];
}

id HC_allOf(id matchers, ...)
{
    va_list args;
    va_start(args, matchers);
    NSArray *array = HCCollectItems(matchers, args);
    va_end(args);

    return HC_allOfIn(array);
}
