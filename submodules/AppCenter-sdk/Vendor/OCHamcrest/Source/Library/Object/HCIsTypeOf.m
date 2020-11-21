//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsTypeOf.h"


@implementation HCIsTypeOf

- (BOOL)matches:(nullable id)item
{
    return [item isMemberOfClass:self.theClass];
}

- (NSString *)expectation
{
    return @"an exact instance of ";
}

@end


id HC_isA(Class expectedClass)
{
    return [[HCIsTypeOf alloc] initWithClass:expectedClass];
}
