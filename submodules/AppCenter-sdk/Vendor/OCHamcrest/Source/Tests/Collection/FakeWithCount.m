//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "FakeWithCount.h"


@implementation FakeWithCount

+ (instancetype)fakeWithCount:(NSUInteger)fakeCount
{
    return [[self alloc] initWithCount:fakeCount];
}

- (instancetype)initWithCount:(NSUInteger)fakeCount
{
    self = [super init];
    if (self)
        _count = fakeCount;
    return self;
}

- (NSString *)description
{
    return @"FakeWithCount";
}

@end
