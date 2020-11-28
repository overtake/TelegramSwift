//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsCollectionContaining.h"

#import "HCAllOf.h"
#import "HCCollect.h"
#import "HCRequireNonNilObject.h"
#import "HCWrapInMatcher.h"


@interface HCIsCollectionContaining ()
@property (nonatomic, strong, readonly) id <HCMatcher> elementMatcher;
@end

@implementation HCIsCollectionContaining

- (instancetype)initWithMatcher:(id <HCMatcher>)elementMatcher
{
    self = [super init];
    if (self)
        _elementMatcher = elementMatcher;
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
        if ([self.elementMatcher matches:item])
            return YES;

    [mismatchDescription appendText:@"mismatches were: ["];
    BOOL isPastFirst = NO;
    for (id item in collection)
    {
        if (isPastFirst)
            [mismatchDescription appendText:@", "];
        [self.elementMatcher describeMismatchOf:item to:mismatchDescription];
        isPastFirst = YES;
    }
    [mismatchDescription appendText:@"]"];
    return NO;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a collection containing "]
                  appendDescriptionOf:self.elementMatcher];
}

@end


id HC_hasItem(id itemMatcher)
{
    HCRequireNonNilObject(itemMatcher);
    return [[HCIsCollectionContaining alloc] initWithMatcher:HCWrapInMatcher(itemMatcher)];
}

id HC_hasItemsIn(NSArray *itemMatchers)
{
    NSMutableArray *matchers = [[NSMutableArray alloc] init];
    for (id itemMatcher in itemMatchers)
        [matchers addObject:HC_hasItem(itemMatcher)];
    return HC_allOfIn(matchers);
}

id HC_hasItems(id itemMatchers, ...)
{
    va_list args;
    va_start(args, itemMatchers);
    NSArray *array = HCCollectItems(itemMatchers, args);
    va_end(args);

    return HC_hasItemsIn(array);
}
