// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAnalyticsTransmissionTarget.h"

@protocol MSACChannelGroupProtocol;

NS_ASSUME_NONNULL_BEGIN

@interface MSACAnalyticsTransmissionTarget ()

/**
 * The transmission target token corresponding to this transmission target.
 */
@property(nonatomic, copy, readonly) NSString *transmissionTargetToken;

/**
 * Initialize a transmission target with token and parent target.
 *
 * @param token A transmission target token.
 * @param parentTarget Nested parent transmission target.
 * @param channelGroup The Channel group.
 *
 * @return A transmission target instance.
 */
- (instancetype)initWithTransmissionTargetToken:(NSString *)token
                                   parentTarget:(nullable MSACAnalyticsTransmissionTarget *)parentTarget
                                   channelGroup:(nonnull id<MSACChannelGroupProtocol>)channelGroup;

@end

NS_ASSUME_NONNULL_END
