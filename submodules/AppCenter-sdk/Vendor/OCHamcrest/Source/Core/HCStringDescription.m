//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCStringDescription.h"

#import "HCSelfDescribing.h"


@interface HCStringDescription ()
@property (nonatomic, strong) NSMutableString *accumulator;
@end

@implementation HCStringDescription

+ (NSString *)stringFrom:(id <HCSelfDescribing>)selfDescribing
{
    HCStringDescription *description = [HCStringDescription stringDescription];
    [description appendDescriptionOf:selfDescribing];
    return description.description;
}

+ (instancetype)stringDescription
{
    return [[HCStringDescription alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _accumulator = [[NSMutableString alloc] init];
    return self;
}

- (NSString *)description
{
    return self.accumulator;
}

- (void)append:(NSString *)str
{
    [self.accumulator appendString:str];
}

@end
