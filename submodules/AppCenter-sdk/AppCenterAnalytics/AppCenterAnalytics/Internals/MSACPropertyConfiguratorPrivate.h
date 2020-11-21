// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAnalyticsTransmissionTarget.h"

@class MSACTypedProperty;

NS_ASSUME_NONNULL_BEGIN

@interface MSACPropertyConfigurator ()

/**
 * The transmission target which will have overwritten properties.
 */
@property(nonatomic, weak) MSACAnalyticsTransmissionTarget *transmissionTarget;

/**
 * Event properties attached to events tracked by this target.
 */
@property(nonatomic) MSACEventProperties *eventProperties;

/**
 * The device id to send with common schema logs. If nil, nothing is sent.
 */
@property(nonatomic, copy) NSString *deviceId;

@end

NS_ASSUME_NONNULL_END
