//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "NeverMatch.h"


@implementation NeverMatch

+ (id)neverMatch
{
    return [[self alloc] init];
}

+ (NSString *)mismatchDescription
{
    return @"NEVERMATCH";
}

- (BOOL)matches:(nullable id)item
{
    return NO;
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [mismatchDescription appendText:[NeverMatch mismatchDescription]];
}

@end
