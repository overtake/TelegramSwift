//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

@import Foundation;


NS_ASSUME_NONNULL_BEGIN

@interface FakeWithCount : NSObject

@property (nonatomic, assign, readonly) NSUInteger count;

+ (instancetype)fakeWithCount:(NSUInteger)fakeCount;
- (instancetype)initWithCount:(NSUInteger)fakeCount;

@end

NS_ASSUME_NONNULL_END
