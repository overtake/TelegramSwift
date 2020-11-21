//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsDictionaryContaining.h"

#import "HCRequireNonNilObject.h"
#import "HCWrapInMatcher.h"


@interface HCIsDictionaryContaining ()
@property (nonatomic, strong, readonly) id <HCMatcher> keyMatcher;
@property (nonatomic, strong, readonly) id <HCMatcher> valueMatcher;
@end

@implementation HCIsDictionaryContaining

- (instancetype)initWithKeyMatcher:(id <HCMatcher>)keyMatcher
                      valueMatcher:(id <HCMatcher>)valueMatcher
{
    self = [super init];
    if (self)
    {
        _keyMatcher = keyMatcher;
        _valueMatcher = valueMatcher;
    }
    return self;
}

- (BOOL)matches:(id)dict
{
    if ([dict isKindOfClass:[NSDictionary class]])
        for (id oneKey in dict)
            if ([self.keyMatcher matches:oneKey] && [self.valueMatcher matches:dict[oneKey]])
                return YES;
    return NO;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[[[description appendText:@"a dictionary containing { "]
                     appendDescriptionOf:self.keyMatcher]
                     appendText:@" = "]
                     appendDescriptionOf:self.valueMatcher]
                     appendText:@"; }"];
}

@end


id HC_hasEntry(id keyMatcher, id valueMatcher)
{
    HCRequireNonNilObject(keyMatcher);
    HCRequireNonNilObject(valueMatcher);
    return [[HCIsDictionaryContaining alloc] initWithKeyMatcher:HCWrapInMatcher(keyMatcher)
                                                   valueMatcher:HCWrapInMatcher(valueMatcher)];
}
