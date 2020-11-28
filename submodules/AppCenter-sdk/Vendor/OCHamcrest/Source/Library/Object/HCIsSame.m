//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsSame.h"


@interface HCIsSame ()
@property (nonatomic, strong, readonly) id object;
@end

@implementation HCIsSame

- (instancetype)initSameAs:(nullable id)object
{
    self = [super init];
    if (self)
        _object = object;
    return self;
}

- (BOOL)matches:(nullable id)item
{
    return item == self.object;
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [mismatchDescription appendText:@"was "];
    if (item)
        [mismatchDescription appendText:[NSString stringWithFormat:@"%p ", (__bridge void *)item]];
    [mismatchDescription appendDescriptionOf:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:[NSString stringWithFormat:@"same instance as %p ", (__bridge void *)self.object]]
                  appendDescriptionOf:self.object];
}

@end


id HC_sameInstance(_Nullable id expectedInstance)
{
    return [[HCIsSame alloc] initSameAs:expectedInstance];
}
