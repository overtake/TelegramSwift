// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "AppCenter+Internal.h"
#import "MSACSessionHistoryInfo.h"
#import "MSACSessionTrackerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSACSessionTracker : NSObject <MSACChannelDelegate>

/**
 * Session tracker delegate.
 */
@property(nonatomic) id<MSACSessionTrackerDelegate> delegate;

/**
 * Session timeout time.
 */
@property(nonatomic) NSTimeInterval sessionTimeout;

/**
 * Timestamp of the last created log.
 */
@property(nonatomic) NSDate *lastCreatedLogTime;

/**
 * Timestamp of the last time that the app entered foreground.
 */
@property(nonatomic) NSDate *lastEnteredForegroundTime;

/**
 * Timestamp of the last time that the app entered background.
 */
@property(nonatomic) NSDate *lastEnteredBackgroundTime;

/**
 * Start session tracking.
 */
- (void)start;

/**
 * Stop session tracking.
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
