//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsCloseTo.h"


@interface HCIsCloseTo ()
@property (nonatomic, assign, readonly) double value;
@property (nonatomic, assign, readonly) double delta;
@end

@implementation HCIsCloseTo

- (id)initWithValue:(double)value delta:(double)delta
{
    self = [super init];
    if (self)
    {
        _value = value;
        _delta = delta;
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if ([self itemIsNotNumber:item])
        return NO;

    return [self actualDelta:item] <= self.delta;
}

- (double)actualDelta:(id)item
{
    return fabs([item doubleValue] - self.value);
}

- (BOOL)itemIsNotNumber:(id)item
{
    return ![item isKindOfClass:[NSNumber class]];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    if ([self itemIsNotNumber:item])
        [super describeMismatchOf:item to:mismatchDescription];
    else
    {
        [[[mismatchDescription appendDescriptionOf:item]
                               appendText:@" differed by "]
                               appendDescriptionOf:@([self actualDelta:item])];
    }
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[[description appendText:@"a numeric value within "]
                    appendDescriptionOf:@(self.delta)]
                    appendText:@" of "]
                    appendDescriptionOf:@(self.value)];
}

@end


id HC_closeTo(double value, double delta)
{
    return [[HCIsCloseTo alloc] initWithValue:value delta:delta];
}
