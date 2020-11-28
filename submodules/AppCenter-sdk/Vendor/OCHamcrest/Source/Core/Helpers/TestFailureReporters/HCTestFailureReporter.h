//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <Foundation/Foundation.h>

@class HCTestFailure;


NS_ASSUME_NONNULL_BEGIN

/*!
 Chain-of-responsibility for handling test failures.
 */
@interface HCTestFailureReporter : NSObject

@property (nullable, nonatomic, strong) HCTestFailureReporter *successor;

/*!
 Handle test failure at specific location, or pass to successor.
 */
- (void)handleFailure:(HCTestFailure *)failure;

@end

NS_ASSUME_NONNULL_END
