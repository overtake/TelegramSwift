//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCReturnValueGetter.h"


NS_ASSUME_NONNULL_BEGIN

@interface HCFloatReturnGetter : HCReturnValueGetter

- (instancetype)initWithSuccessor:(nullable HCReturnValueGetter *)successor NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithType:(char const *)handlerType successor:(nullable HCReturnValueGetter *)successor NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
