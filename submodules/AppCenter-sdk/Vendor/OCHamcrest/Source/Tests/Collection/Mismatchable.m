//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "Mismatchable.h"


@interface Mismatchable ()
@property (nonatomic, copy, readonly) NSString *string;
@end

@implementation Mismatchable

+ (instancetype)mismatchable:(NSString *)string
{
    return [[self alloc] initMismatchableString:string];
}

- (instancetype)initMismatchableString:(NSString *)string
{
    self = [super init];
    if (self)
        _string = [string copy];
    return self;
}

- (BOOL)matches:(nullable id)item
{
    return [self.string isEqualToString:item];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [[mismatchDescription appendText:@"mismatched: "] appendText:item];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"mismatchable: "] appendText:self.string];
}

@end
