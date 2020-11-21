//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsTrueFalse.h"


@implementation HCIsTrue

- (BOOL)matches:(nullable id)item
{
    if (![item isKindOfClass:[NSNumber class]])
        return NO;

    return [item boolValue];
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendText:@"true (non-zero)"];
}

@end


FOUNDATION_EXPORT id HC_isTrue(void)
{
    return [[HCIsTrue alloc] init];
}


#pragma mark -

@implementation HCIsFalse

- (BOOL)matches:(nullable id)item
{
    if (![item isKindOfClass:[NSNumber class]])
        return NO;

    return ![item boolValue];
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendText:@"false (zero)"];
}

@end


FOUNDATION_EXPORT id HC_isFalse(void)
{
    return [[HCIsFalse alloc] init];
}

