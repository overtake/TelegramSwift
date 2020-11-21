//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@NS_ASSUME_NONNULL_BEGIN

interface Mismatchable : HCBaseMatcher

+ (instancetype)mismatchable:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
