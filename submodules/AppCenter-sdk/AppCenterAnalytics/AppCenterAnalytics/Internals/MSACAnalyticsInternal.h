// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalytics.h"
#import "MSACAnalyticsDelegate.h"
#import "MSACAnalyticsTransmissionTarget.h"
#import "MSACChannelDelegate.h"
#import "MSACServiceInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSACAnalytics () <MSACServiceInternal, MSACChannelDelegate>

/**
 * Track an event with typed properties.
 *
 * @param eventName  Event name.
 * @param properties The typed event properties.
 * @param transmissionTarget  The transmission target to associate to this event.
 * @param flags      Optional flags. Events tracked with the MSACFlagsCritical flag will take precedence over all other events in
 * storage. An event tracked with this option will only be dropped if storage must make room for a newer event that is also marked with the
 * MSACFlagsCritical flag.
 */
+ (void)trackEvent:(NSString *)eventName
      withTypedProperties:(nullable MSACEventProperties *)properties
    forTransmissionTarget:(nullable MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags;

// Temporarily hiding tracking page feature.
/**
 * Track a page.
 *
 * @param pageName  page name.
 */
+ (void)trackPage:(NSString *)pageName;

/**
 * Track a page.
 *
 * @param pageName  page name.
 * @param properties dictionary of properties.
 */
+ (void)trackPage:(NSString *)pageName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties;

/**
 * Set the page auto-tracking property.
 *
 * @param isEnabled is page tracking enabled or disabled.
 */
+ (void)setAutoPageTrackingEnabled:(BOOL)isEnabled;

/**
 * Indicate if auto page tracking is enabled or not.
 *
 * @return YES if page tracking is enabled and NO if disabled.
 */
+ (BOOL)isAutoPageTrackingEnabled;

/**
 * Set the MSACAnalyticsDelegate object.
 *
 * @param delegate The delegate to be set.
 */
+ (void)setDelegate:(nullable id<MSACAnalyticsDelegate>)delegate;

/**
 * Pause transmission target for the given token.
 *
 * @param token The token of the transmission target.
 */
+ (void)pauseTransmissionTargetForToken:(NSString *)token;

/**
 * Resume transmission target for the given token.
 *
 * @param token The token of the transmission target.
 */
+ (void)resumeTransmissionTargetForToken:(NSString *)token;

@end

NS_ASSUME_NONNULL_END
