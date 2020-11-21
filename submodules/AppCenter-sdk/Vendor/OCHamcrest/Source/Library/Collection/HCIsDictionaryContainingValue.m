//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsDictionaryContainingValue.h"

#import "HCRequireNonNilObject.h"
#import "HCWrapInMatcher.h"


@interface HCIsDictionaryContainingValue ()
@property (nonatomic, strong, readonly) id <HCMatcher> valueMatcher;
@end

@implementation HCIsDictionaryContainingValue

- (instancetype)initWithValueMatcher:(id <HCMatcher>)valueMatcher
{
    self = [super init];
    if (self)
        _valueMatcher = valueMatcher;
    return self;
}

- (BOOL)matches:(id)dict
{
    if ([dict respondsToSelector:@selector(allValues)])
        for (id oneValue in [dict allValues])
            if ([self.valueMatcher matches:oneValue])
                return YES;
    return NO;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a dictionary containing value "]
                  appendDescriptionOf:self.valueMatcher];
}

@end


id HC_hasValue(id valueMatcher)
{
    HCRequireNonNilObject(valueMatcher);
    return [[HCIsDictionaryContainingValue alloc] initWithValueMatcher:HCWrapInMatcher(valueMatcher)];
}
