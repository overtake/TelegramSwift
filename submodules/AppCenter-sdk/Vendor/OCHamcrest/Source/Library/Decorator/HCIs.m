//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIs.h"

#import "HCWrapInMatcher.h"


@interface HCIs ()
@property (nonatomic, strong, readonly) id <HCMatcher> matcher;
@end

@implementation HCIs

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher
{
    self = [super init];
    if (self)
        _matcher = matcher;
    return self;
}

- (BOOL)matches:(nullable id)item
{
    return [self.matcher matches:item];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [self.matcher describeMismatchOf:item to:mismatchDescription];
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendDescriptionOf:self.matcher];
}

@end


id HC_is(_Nullable id value)
{
    return [[HCIs alloc] initWithMatcher:HCWrapInMatcher(value)];
}
