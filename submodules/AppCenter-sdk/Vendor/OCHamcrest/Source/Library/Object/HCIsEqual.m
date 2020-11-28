//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsEqual.h"


@interface HCIsEqual ()
@property (nullable, nonatomic, strong, readonly) id expectedValue;
@end

@implementation HCIsEqual

- (instancetype)initEqualTo:(nullable id)expectedValue
{
    self = [super init];
    if (self)
        _expectedValue = expectedValue;
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (item == nil)
        return self.expectedValue == nil;
    return [item isEqual:self.expectedValue];
}

- (void)describeTo:(id <HCDescription>)description
{
    if ([self.expectedValue conformsToProtocol:@protocol(HCMatcher)])
    {
        [[[description appendText:@"<"]
                appendDescriptionOf:self.expectedValue]
                       appendText:@">"];
    }
    else
        [description appendDescriptionOf:self.expectedValue];
}

@end


id HC_equalTo(_Nullable id operand)
{
    return [[HCIsEqual alloc] initEqualTo:operand];
}
