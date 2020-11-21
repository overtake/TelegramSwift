//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCReturnValueGetter.h"


@interface HCReturnValueGetter (SubclassResponsibility)
- (id)returnValueFromInvocation:(NSInvocation *)invocation;
@end

@interface HCReturnValueGetter ()
@property (nonatomic, assign, readonly) char const *handlerType;
@property (nullable, nonatomic, strong, readonly) HCReturnValueGetter *successor;
@end

@implementation HCReturnValueGetter

- (instancetype)initWithType:(char const *)handlerType successor:(nullable HCReturnValueGetter *)successor
{
    self = [super init];
    if (self)
    {
        _handlerType = handlerType;
        _successor = successor;
    }
    return self;
}

- (BOOL)handlesReturnType:(char const *)returnType
{
    return strcmp(returnType, self.handlerType) == 0;
}

- (id)returnValueOfType:(char const *)type fromInvocation:(NSInvocation *)invocation
{
    if ([self handlesReturnType:type])
        return [self returnValueFromInvocation:invocation];

    return [self.successor returnValueOfType:type fromInvocation:invocation];
}

@end
