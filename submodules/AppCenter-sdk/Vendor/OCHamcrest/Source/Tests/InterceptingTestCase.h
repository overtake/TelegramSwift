//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

@import XCTest;

#import "HCTestFailure.h"   // Convenience import


NS_ASSUME_NONNULL_BEGIN

@interface InterceptingTestCase : XCTestCase
@property (nonatomic, strong) HCTestFailure *testFailure;
@end

NS_ASSUME_NONNULL_END
