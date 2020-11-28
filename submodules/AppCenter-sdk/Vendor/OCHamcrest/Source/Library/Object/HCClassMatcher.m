//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCClassMatcher.h"

#import "HCRequireNonNilObject.h"


@interface HCClassMatcher (SubclassResponsibility)
- (NSString *)expectation;
@end


@implementation HCClassMatcher

- (instancetype)initWithClass:(Class)aClass
{
    HCRequireNonNilObject(aClass);

    self = [super init];
    if (self)
        _theClass = aClass;
    return self;
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:[self expectation]]
                  appendText:NSStringFromClass(self.theClass)];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [mismatchDescription appendText:@"was "];
    if (item)
    {
        [[mismatchDescription appendText:NSStringFromClass([item class])]
                              appendText:@" instance "];
    }
    [mismatchDescription appendDescriptionOf:item];
}

@end
