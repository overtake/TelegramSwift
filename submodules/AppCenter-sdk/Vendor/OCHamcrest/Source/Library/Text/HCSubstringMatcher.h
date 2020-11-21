//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

@interface HCSubstringMatcher : HCBaseMatcher

@property (nonatomic, copy, readonly) NSString *substring;

- (instancetype)initWithSubstring:(NSString *)substring NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
