//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsCollectionContainingInAnyOrder.h"

#import "HCCollect.h"


@interface HCMatchingInAnyOrder : NSObject
@property (nonatomic, copy, readonly) NSMutableArray<id <HCMatcher>> *matchers;
@property (nonatomic, strong, readonly) id <HCDescription> mismatchDescription;
@end

@implementation HCMatchingInAnyOrder

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)itemMatchers
             mismatchDescription:(id <HCDescription>)description
{
    self = [super init];
    if (self)
    {
        _matchers = [itemMatchers mutableCopy];
        _mismatchDescription = description;
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    NSUInteger index = 0;
    for (id <HCMatcher> matcher in self.matchers)
    {
        if ([matcher matches:item])
        {
            [self.matchers removeObjectAtIndex:index];
            return YES;
        }
        ++index;
    }
    [[self.mismatchDescription appendText:@"not matched: "]
                               appendDescriptionOf:item];
    return NO;
}

- (BOOL)isFinishedWith:(NSArray *)collection
{
    if (self.matchers.count == 0)
        return YES;

    [[[[self.mismatchDescription appendText:@"no item matches: "]
                                 appendList:self.matchers start:@"" separator:@", " end:@""]
                                 appendText:@" in "]
                                 appendList:collection start:@"[" separator:@", " end:@"]"];
    return NO;
}

@end


@interface HCIsCollectionContainingInAnyOrder ()
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *matchers;
@end

@implementation HCIsCollectionContainingInAnyOrder

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)itemMatchers
{
    self = [super init];
    if (self)
        _matchers = [itemMatchers copy];
    return self;
}

- (BOOL)matches:(id)collection describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    if (![collection conformsToProtocol:@protocol(NSFastEnumeration)])
    {
        [[mismatchDescription appendText:@"was non-collection "] appendDescriptionOf:collection];
        return NO;
    }

    HCMatchingInAnyOrder *matchSequence =
        [[HCMatchingInAnyOrder alloc] initWithMatchers:self.matchers
                                   mismatchDescription:mismatchDescription];
    for (id item in collection)
        if (![matchSequence matches:item])
            return NO;

    return [matchSequence isFinishedWith:collection];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[description appendText:@"a collection over "]
                   appendList:self.matchers start:@"[" separator:@", " end:@"]"]
                   appendText:@" in any order"];
}

@end


id HC_containsInAnyOrderIn(NSArray *itemMatchers)
{
    return [[HCIsCollectionContainingInAnyOrder alloc] initWithMatchers:HCWrapIntoMatchers(itemMatchers)];
}

id HC_containsInAnyOrder(id itemMatchers, ...)
{
    va_list args;
    va_start(args, itemMatchers);
    NSArray *array = HCCollectItems(itemMatchers, args);
    va_end(args);

    return HC_containsInAnyOrderIn(array);
}
