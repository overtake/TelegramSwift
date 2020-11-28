//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCStringContains.h"


@implementation HCStringContains

- (BOOL)matches:(nullable id)item
{
    if (![item respondsToSelector:@selector(rangeOfString:)])
        return NO;

    return [item rangeOfString:self.substring].location != NSNotFound;
}

- (NSString *)relationship
{
    return @"containing";
}

@end


id <HCMatcher> HC_containsSubstring(NSString *substring)
{
    return [[HCStringContains alloc] initWithSubstring:substring];
}
