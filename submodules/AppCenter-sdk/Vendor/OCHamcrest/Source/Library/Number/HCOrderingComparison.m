//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCOrderingComparison.h"


@interface HCOrderingComparison ()
@property (nonatomic, strong, readonly) id expected;
@property (nonatomic, assign, readonly) NSComparisonResult minCompare;
@property (nonatomic, assign, readonly) NSComparisonResult maxCompare;
@property (nonatomic, copy, readonly) NSString *comparisonDescription;
@end

@implementation HCOrderingComparison

- (instancetype)initComparing:(id)expectedValue
                   minCompare:(NSComparisonResult)min
                   maxCompare:(NSComparisonResult)max
        comparisonDescription:(NSString *)description
{
    if (![expectedValue respondsToSelector:@selector(compare:)])
    {
        @throw [NSException exceptionWithName: @"UncomparableObject"
                                       reason: @"Object must respond to compare:"
                                     userInfo: nil];
    }

    self = [super init];
    if (self)
    {
        _expected = expectedValue;
        _minCompare = min;
        _maxCompare = max;
        _comparisonDescription = [description copy];
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (item == nil)
        return NO;

    NSComparisonResult compare;
    @try
    {
        compare = [self.expected compare:item];
    }
    @catch (NSException *e)
    {
        return NO;
    }
    return self.minCompare <= compare && compare <= self.maxCompare;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[[description appendText:@"a value "]
                    appendText:self.comparisonDescription]
                    appendText:@" "]
                    appendDescriptionOf:self.expected];
}

@end


id HC_greaterThan(id value)
{
    return [[HCOrderingComparison alloc] initComparing:value
                                            minCompare:NSOrderedAscending
                                            maxCompare:NSOrderedAscending
                                 comparisonDescription:@"greater than"];
}

id HC_greaterThanOrEqualTo(id value)
{
    return [[HCOrderingComparison alloc] initComparing:value
                                            minCompare:NSOrderedAscending
                                            maxCompare:NSOrderedSame
                                 comparisonDescription:@"greater than or equal to"];
}

id HC_lessThan(id value)
{
    return [[HCOrderingComparison alloc] initComparing:value
                                            minCompare:NSOrderedDescending
                                            maxCompare:NSOrderedDescending
                                 comparisonDescription:@"less than"];
}

id HC_lessThanOrEqualTo(id value)
{
    return [[HCOrderingComparison alloc] initComparing:value
                                            minCompare:NSOrderedSame
                                            maxCompare:NSOrderedDescending
                                 comparisonDescription:@"less than or equal to"];
}
