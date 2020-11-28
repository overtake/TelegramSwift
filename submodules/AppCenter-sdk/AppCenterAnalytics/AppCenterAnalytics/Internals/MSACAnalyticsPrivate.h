// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalytics.h"
#import "MSACAnalyticsDelegate.h"
#import "MSACAnalyticsTransmissionTarget.h"
#import "MSACServiceInternal.h"
#import "MSACSessionTracker.h"
#import "MSACSessionTrackerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

// The Id suffix for critical events.
static NSString *const kMSACCriticalChannelSuffix = @"critical";

@interface MSACAnalytics () <MSACSessionTrackerDelegate>

/**
 * Session tracking component.
 */
@property(nonatomic) MSACSessionTracker *sessionTracker;

@property(atomic, getter=isAutoPageTrackingEnabled) BOOL autoPageTrackingEnabled;

@property(nonatomic, nullable) id<MSACAnalyticsDelegate> delegate;

@property(nonatomic) NSUInteger flushInterval;

/**
 * Transmission targets.
 */
@property(nonatomic) NSMutableDictionary<NSString *, MSACAnalyticsTransmissionTarget *> *transmissionTargets;

/**
 * Default transmission target.
 */
@property(nonatomic) MSACAnalyticsTransmissionTarget *defaultTransmissionTarget;

/**
 * The channel unit for common schema logs.
 */
@property(nonatomic, nullable) id<MSACChannelUnitProtocol> oneCollectorChannelUnit;

/**
 * The channel unit for critical common schema logs.
 */
@property(nonatomic, nullable) id<MSACChannelUnitProtocol> oneCollectorCriticalChannelUnit;

/**
 * Critical events channel unit.
 */
@property(nonatomic) id<MSACChannelUnitProtocol> criticalChannelUnit;

/**
 * Track an event.
 *
 * @param eventName  Event name.
 * @param properties Dictionary of properties.
 * @param transmissionTarget Transmission target to associate with the event.
 * @param flags      Optional flags. Events tracked with the MSACFlagsCritical flag will take precedence over all other events in
 * storage. An event tracked with this option will only be dropped if storage must make room for a newer event that is also marked with the
 * MSACFlagsCritical flag.
 */
- (void)trackEvent:(NSString *)eventName
           withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties
    forTransmissionTarget:(nullable MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags;

/**
 * Track an event with typed properties.
 *
 * @param eventName  Event name.
 * @param properties Typed properties.
 * @param transmissionTarget Transmission target to associate with the event.
 * @param flags      Optional flags. Events tracked with the MSACFlagsCritical flag will take precedence over all other events in
 * storage. An event tracked with this option will only be dropped if storage must make room for a newer event that is also marked with the
 * MSACFlagsCritical flag.
 */
- (void)trackEvent:(NSString *)eventName
      withTypedProperties:(nullable MSACEventProperties *)properties
    forTransmissionTarget:(nullable MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags;

/**
 * Track a page.
 *
 * @param pageName  Page name.
 * @param properties Dictionary of properties.
 */
- (void)trackPage:(NSString *)pageName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties;

/**
 * Get a transmissionTarget.
 *
 * @param token The token of the transmission target to retrieve.
 *
 * @returns The transmission target object.
 */
- (MSACAnalyticsTransmissionTarget *)transmissionTargetForToken:(NSString *)token;

/**
 * Method to reset the singleton when running unit tests only. So calling sharedInstance returns a fresh instance.
 */
+ (void)resetSharedInstance;

/**
 * Removes properties with keys that are not a string or that have non-string values.
 *
 * @param properties A dictionary of properties.
 *
 * @returns A dictionary of valid properties or an empty dictionay.
 */
- (NSDictionary<NSString *, NSString *> *)removeInvalidProperties:(NSDictionary<NSString *, NSString *> *)properties;

@end

NS_ASSUME_NONNULL_END
