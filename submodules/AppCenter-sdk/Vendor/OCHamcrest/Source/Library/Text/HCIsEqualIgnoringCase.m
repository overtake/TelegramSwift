//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsEqualIgnoringCase.h"

#import "HCRequireNonNilObject.h"


@interface HCIsEqualIgnoringCase ()
@property (nonatomic, copy, readonly) NSString *string;
@end

@implementation HCIsEqualIgnoringCase

- (instancetype)initWithString:(NSString *)string
{
    HCRequireNonNilObject(string);

    self = [super init];
    if (self)
        _string = [string copy];
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (![item isKindOfClass:[NSString class]])
        return NO;

    return [self.string caseInsensitiveCompare:item] == NSOrderedSame;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendDescriptionOf:self.string]
                  appendText:@" ignoring case"];
}

@end


id HC_equalToIgnoringCase(NSString *expectedString)
{
    return [[HCIsEqualIgnoringCase alloc] initWithString:expectedString];
}
