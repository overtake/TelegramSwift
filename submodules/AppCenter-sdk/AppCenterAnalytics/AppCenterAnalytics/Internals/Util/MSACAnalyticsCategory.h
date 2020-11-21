// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSACAnalyticsCategory : NSObject

/**
 * Activate category for UIViewController.
 */
+ (void)activateCategory;

/**
 * Get the last missed page view name while available.
 *
 * @return the last page view name. Can be nil if no name available or the page has already been tracked.
 */
+ (nullable NSString *)missedPageViewName;

@end

NS_ASSUME_NONNULL_END
