//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCEvery.h"

#import "HCRequireNonNilObject.h"


@implementation HCEvery

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher
{
    HCRequireNonNilObject(matcher);

    self = [super init];
    if (self)
        _matcher = matcher;
    return self;
}

- (BOOL)matches:(id)collection describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    if (![collection conformsToProtocol:@protocol(NSFastEnumeration)])
    {
        [[mismatchDescription appendText:@"was non-collection "] appendDescriptionOf:collection];
        return NO;
    }

    if ([collection count] == 0)
    {
        [mismatchDescription appendText:@"was empty"];
        return NO;
    }

    for (id item in collection)
    {
        if (![self.matcher matches:item])
        {
            [self describeAllMismatchesInCollection:collection to:mismatchDescription];
            return NO;
        }
    }
    return YES;
}

- (void)describeAllMismatchesInCollection:(id)collection to:(id <HCDescription>)mismatchDescription
{
    [mismatchDescription appendText:@"mismatches were: ["];
    BOOL isPastFirst = NO;
    for (id item in collection)
    {
        if (![self.matcher matches:item])
        {
            if (isPastFirst)
                [mismatchDescription appendText:@", "];
            [self.matcher describeMismatchOf:item to:mismatchDescription];
            isPastFirst = YES;
        }
    }
    [mismatchDescription appendText:@"]"];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"every item is "] appendDescriptionOf:self.matcher];
}

@end


id HC_everyItem(id <HCMatcher> itemMatcher)
{
    return [[HCEvery alloc] initWithMatcher:itemMatcher];
}
