//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsDictionaryContainingKey.h"

#import "HCRequireNonNilObject.h"
#import "HCWrapInMatcher.h"


@interface HCIsDictionaryContainingKey ()
@property (nonatomic, strong, readonly) id <HCMatcher> keyMatcher;
@end

@implementation HCIsDictionaryContainingKey

- (instancetype)initWithKeyMatcher:(id <HCMatcher>)keyMatcher
{
    self = [super init];
    if (self)
        _keyMatcher = keyMatcher;
    return self;
}

- (BOOL)matches:(id)dict
{
    if ([dict isKindOfClass:[NSDictionary class]])
        for (id oneKey in dict)
            if ([self.keyMatcher matches:oneKey])
                return YES;
    return NO;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a dictionary containing key "]
                  appendDescriptionOf:self.keyMatcher];
}

@end


id HC_hasKey(id keyMatcher)
{
    HCRequireNonNilObject(keyMatcher);
    return [[HCIsDictionaryContainingKey alloc] initWithKeyMatcher:HCWrapInMatcher(keyMatcher)];
}
