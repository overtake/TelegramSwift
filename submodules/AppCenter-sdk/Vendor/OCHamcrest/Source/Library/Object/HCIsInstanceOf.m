//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsInstanceOf.h"


@implementation HCIsInstanceOf

- (BOOL)matches:(nullable id)item
{
    return [item isKindOfClass:self.theClass];
}

- (NSString *)expectation
{
    return @"an instance of ";
}

@end


id HC_instanceOf(Class expectedClass)
{
    return [[HCIsInstanceOf alloc] initWithClass:expectedClass];
}
