//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsCollectionContainingInRelativeOrder.h"

#import "HCCollect.h"


static void HCRequireNonEmptyArray(NSArray *array)
{
    if (!array.count)
    {
        @throw [NSException exceptionWithName:@"EmptyArray"
                                       reason:@"Must be non-empty array"
                                     userInfo:nil];
    }
}


@interface HCMatchSequenceInRelativeOrder : NSObject
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *matchers;
@property (nonatomic, strong, readonly) id <HCDescription> mismatchDescription;
@property (nonatomic, assign) NSUInteger nextMatchIndex;
@property (nonatomic, strong) id lastMatchedItem;
@end

@implementation HCMatchSequenceInRelativeOrder

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)itemMatchers
             mismatchDescription:(id <HCDescription>)description
{
    self = [super init];
    if (self)
    {
        _matchers = [itemMatchers copy];
        _mismatchDescription = description;
    }
    return self;
}

- (void)processItems:(NSArray *)sequence
{
    for (id item in sequence)
    {
        if (self.nextMatchIndex < self.matchers.count)
        {
            id <HCMatcher> matcher = self.matchers[self.nextMatchIndex];
            if ([matcher matches:item])
            {
                self.lastMatchedItem = item;
                self.nextMatchIndex += 1;
            }
        }
    }
}

- (BOOL)isFinished
{
    if (self.nextMatchIndex < self.matchers.count)
    {
        [[self.mismatchDescription
                appendDescriptionOf:self.matchers[self.nextMatchIndex]]
                appendText:@" was not found"];
        if (self.lastMatchedItem != nil)
        {
            [[self.mismatchDescription
                    appendText:@" after "]
                    appendDescriptionOf:self.lastMatchedItem];
        }
        return NO;
    }
    return YES;
}

@end


@interface HCIsCollectionContainingInRelativeOrder ()
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *matchers;
@end

@implementation HCIsCollectionContainingInRelativeOrder

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)itemMatchers
{
    HCRequireNonEmptyArray(itemMatchers);

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

    HCMatchSequenceInRelativeOrder *matchSequenceInRelativeOrder =
            [[HCMatchSequenceInRelativeOrder alloc] initWithMatchers:self.matchers
                                                 mismatchDescription:mismatchDescription];
    [matchSequenceInRelativeOrder processItems:collection];
    return [matchSequenceInRelativeOrder isFinished];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[description
            appendText:@"a collection containing "]
            appendList:self.matchers start:@"[" separator:@", " end:@"]"]
            appendText:@" in relative order"];
}

@end


id HC_containsInRelativeOrder(NSArray *itemMatchers)
{
    NSArray *matchers = HCWrapIntoMatchers(itemMatchers);
    return [[HCIsCollectionContainingInRelativeOrder alloc] initWithMatchers:matchers];
}
