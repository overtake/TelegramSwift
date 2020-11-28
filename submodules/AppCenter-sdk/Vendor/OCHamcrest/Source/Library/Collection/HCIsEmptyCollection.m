//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsEmptyCollection.h"

#import "HCIsEqual.h"


@implementation HCIsEmptyCollection

- (instancetype)init
{
    self = [super initWithMatcher:HC_equalTo(@0)];
    return self;
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [[mismatchDescription appendText:@"was "] appendDescriptionOf:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendText:@"empty collection"];
}

@end


FOUNDATION_EXPORT id HC_isEmpty(void)
{
    return [[HCIsEmptyCollection alloc] init];
}
