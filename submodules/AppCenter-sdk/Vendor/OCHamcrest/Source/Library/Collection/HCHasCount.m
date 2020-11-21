//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCHasCount.h"

#import "HCIsEqual.h"


@interface HCHasCount ()
@property (nonatomic, strong, readonly) id <HCMatcher> countMatcher;
@end

@implementation HCHasCount

- (instancetype)initWithMatcher:(id <HCMatcher>)countMatcher
{
    self = [super init];
    if (self)
        _countMatcher = countMatcher;
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (![self itemHasCount:item])
        return NO;

    NSNumber *count = @([item count]);
    return [self.countMatcher matches:count];
}

- (BOOL)itemHasCount:(id)item
{
    return [item respondsToSelector:@selector(count)];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [mismatchDescription appendText:@"was "];
    if ([self itemHasCount:item])
    {
        [[[mismatchDescription appendText:@"count of "]
                               appendDescriptionOf:@([item count])]
                               appendText:@" with "];
    }
    [mismatchDescription appendDescriptionOf:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a collection with count of "] appendDescriptionOf:self.countMatcher];
}

@end


id HC_hasCount(id <HCMatcher> countMatcher)
{
    return [[HCHasCount alloc] initWithMatcher:countMatcher];
}

id HC_hasCountOf(NSUInteger value)
{
    return HC_hasCount(HC_equalTo(@(value)));
}
