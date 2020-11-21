// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAnalyticsTransmissionTarget.h"
#import "MSACChannelDelegate.h"
#import "MSACChannelGroupProtocol.h"
#import "MSACUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSACAnalyticsTransmissionTarget () <MSACChannelDelegate>

/**
 * Parent transmission target of this target.
 */
@property(nonatomic, nullable) MSACAnalyticsTransmissionTarget *parentTarget;

/**
 * Child transmission targets nested to this transmission target.
 */
@property(nonatomic) NSMutableDictionary<NSString *, MSACAnalyticsTransmissionTarget *> *childTransmissionTargets;

/**
 * isEnabled value storage key.
 */
@property(nonatomic, readonly) NSString *isEnabledKey;

/**
 * The channel group.
 */
@property(nonatomic, readonly) id<MSACChannelGroupProtocol> channelGroup;

/**
 * Authentication provider.
 */
@property(class, nonatomic) MSACAnalyticsAuthenticationProvider *authenticationProvider;

@end

NS_ASSUME_NONNULL_END
