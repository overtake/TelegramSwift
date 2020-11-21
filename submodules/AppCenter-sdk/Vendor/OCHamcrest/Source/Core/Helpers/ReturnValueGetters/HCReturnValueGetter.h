//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Chain-of-responsibility for handling NSInvocation return types.
 */
@interface HCReturnValueGetter : NSObject

- (instancetype)initWithType:(char const *)handlerType successor:(nullable HCReturnValueGetter *)successor NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (id)returnValueOfType:(char const *)type fromInvocation:(NSInvocation *)invocation;

@end

NS_ASSUME_NONNULL_END
