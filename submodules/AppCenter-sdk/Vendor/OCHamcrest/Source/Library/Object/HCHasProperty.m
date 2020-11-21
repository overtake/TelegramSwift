//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt
//  Contribution by Justin Shacklette

#import "HCHasProperty.h"

#import "HCRequireNonNilObject.h"
#import "HCWrapInMatcher.h"
#import "NSInvocation+OCHamcrest.h"


@interface HCHasProperty ()
@property (nonatomic, copy, readonly) NSString *propertyName;
@property (nonatomic, strong, readonly) id <HCMatcher> valueMatcher;
@end

@implementation HCHasProperty

- (instancetype)initWithProperty:(NSString *)propertyName value:(id <HCMatcher>)valueMatcher
{
    HCRequireNonNilObject(propertyName);

    self = [super init];
    if (self != nil)
    {
        _propertyName = [propertyName copy];
        _valueMatcher = valueMatcher;
    }
    return self;
}

- (BOOL)matches:(nullable id)item describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    SEL propertyGetter = NSSelectorFromString(self.propertyName);
    if (![item respondsToSelector:propertyGetter])
    {
        [[[[mismatchDescription appendText:@"no "]
                                appendText:self.propertyName]
                                appendText:@" on "]
                                appendDescriptionOf:item];
        return NO;
    }

    NSInvocation *getterInvocation = [NSInvocation och_invocationWithTarget:item selector:propertyGetter];
    id propertyValue = [getterInvocation och_invoke];
    BOOL match =  [self.valueMatcher matches:propertyValue];
    if (!match)
    {
        [[[[[mismatchDescription appendText:self.propertyName]
                                 appendText:@" was "]
                                 appendDescriptionOf:propertyValue]
                                 appendText:@" on "]
                                 appendDescriptionOf:item];
    }
    return match;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[[[description appendText:@"an object with "]
                    appendText:self.propertyName]
                    appendText:@" "]
                    appendDescriptionOf:self.valueMatcher];
}
@end


id HC_hasProperty(NSString *propertyName, _Nullable id valueMatcher)
{
    return [[HCHasProperty alloc] initWithProperty:propertyName value:HCWrapInMatcher(valueMatcher)];
}
