//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsIn.h"


@interface HCIsIn ()
@property (nonatomic, strong, readonly) id collection;
@end

@implementation HCIsIn

- (instancetype)initWithCollection:(id)collection
{
    if (![collection respondsToSelector:@selector(containsObject:)])
    {
        @throw [NSException exceptionWithName:@"NotAContainer"
                                       reason:@"Object must respond to -containsObject:"
                                     userInfo:nil];
    }

    self = [super init];
    if (self)
        _collection = collection;
    return self;
}

- (BOOL)matches:(nullable id)item
{
    return [self.collection containsObject:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"one of "]
                  appendList:self.collection start:@"{" separator:@", " end:@"}"];
}

@end


id HC_isIn(id aCollection)
{
    return [[HCIsIn alloc] initWithCollection:aCollection];
}
