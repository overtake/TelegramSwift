// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACLogWithNameAndProperties.h"

@class MSACEventProperties;
@class MSACMetadataExtension;

NS_SWIFT_NAME(EventLog)
@interface MSACEventLog : MSACLogWithNameAndProperties

/**
 * Unique identifier for this event.
 */
@property(nonatomic, copy) NSString *eventId;

/**
 * Event properties.
 */
@property(nonatomic, strong) MSACEventProperties *typedProperties;

@end
