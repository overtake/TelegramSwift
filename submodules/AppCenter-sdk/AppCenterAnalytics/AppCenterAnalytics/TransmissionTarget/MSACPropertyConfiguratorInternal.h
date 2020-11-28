// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACChannelDelegate.h"
#import "MSACEventPropertiesInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSACPropertyConfigurator () <MSACChannelDelegate>

/**
 * Initialize property configurator with a transmission target.
 */
- (instancetype)initWithTransmissionTarget:(MSACAnalyticsTransmissionTarget *)transmissionTarget;

/**
 * Merge typed properties.
 *
 * @param mergedEventProperties The destination event properties that merges current event properties to.
 */
- (void)mergeTypedPropertiesWith:(MSACEventProperties *)mergedEventProperties;

NS_ASSUME_NONNULL_END

@end
