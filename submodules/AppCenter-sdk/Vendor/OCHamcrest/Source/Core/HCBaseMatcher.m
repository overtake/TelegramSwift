//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCBaseMatcher.h"

#import "HCStringDescription.h"


@implementation HCBaseMatcher

- (NSString *)description
{
    return [HCStringDescription stringFrom:self];
}

- (BOOL)matches:(nullable id)item
{
    HC_ABSTRACT_METHOD;
    return NO;
}

- (BOOL)matches:(nullable id)item describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    BOOL matchResult = [self matches:item];
    if (!matchResult)
        [self describeMismatchOf:item to:mismatchDescription];
    return matchResult;
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [[mismatchDescription appendText:@"was "] appendDescriptionOf:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    HC_ABSTRACT_METHOD;
}

- (void)subclassResponsibility:(SEL)command
{
    NSString *className = NSStringFromClass([self class]);
    [NSException raise:NSGenericException
                format:@"-[%@  %@] not implemented", className, NSStringFromSelector(command)];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
