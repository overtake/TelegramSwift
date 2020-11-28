// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalyticsAuthenticationProviderInternal.h"
#import "MSACAnalyticsInternal.h"
#import "MSACAnalyticsTransmissionTargetInternal.h"
#import "MSACAnalyticsTransmissionTargetPrivate.h"
#import "MSACCSExtensions.h"
#import "MSACCommonSchemaLog.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLogger.h"
#import "MSACPropertyConfiguratorInternal.h"
#import "MSACProtocolExtension.h"
#import "MSACServiceAbstractInternal.h"
#import "MSACUtility+StringFormatting.h"

@implementation MSACAnalyticsTransmissionTarget

static MSACAnalyticsAuthenticationProvider *_authenticationProvider;

- (instancetype)initWithTransmissionTargetToken:(NSString *)token
                                   parentTarget:(MSACAnalyticsTransmissionTarget *)parentTarget
                                   channelGroup:(id<MSACChannelGroupProtocol>)channelGroup {
  if ((self = [super init])) {
    _propertyConfigurator = [[MSACPropertyConfigurator alloc] initWithTransmissionTarget:self];
    _channelGroup = channelGroup;
    _parentTarget = parentTarget;
    _childTransmissionTargets = [NSMutableDictionary<NSString *, MSACAnalyticsTransmissionTarget *> new];
    _transmissionTargetToken = token;
    _isEnabledKey =
        [NSString stringWithFormat:@"%@/%@", [MSACAnalytics sharedInstance].isEnabledKey, [MSACUtility targetKeyFromTargetToken:token]];

    // Disable if ancestor is disabled.
    if (![self isImmediateParent]) {
      [MSAC_APP_CENTER_USER_DEFAULTS setObject:@NO forKey:self.isEnabledKey];
    }

    // Add property configurator to the channel group as a delegate.
    [_channelGroup addDelegate:_propertyConfigurator];

    // Add self to channel group as delegate to decorate logs with tickets.
    [_channelGroup addDelegate:self];
  }
  return self;
}

+ (void)addAuthenticationProvider:(MSACAnalyticsAuthenticationProvider *)authenticationProvider {
  @synchronized(self) {
    if (!authenticationProvider) {
      MSACLogError([MSACAnalytics logTag], @"Authentication provider may not be null.");
      return;
    }

    // No need to validate the authentication provider's properties as they are required for initialization and can't be null.
    self.authenticationProvider = authenticationProvider;

    // Request token now.
    [self.authenticationProvider acquireTokenAsync];
  }
}

- (void)trackEvent:(NSString *)eventName {
  [self trackEvent:eventName withProperties:nil];
}

- (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  [self trackEvent:eventName withProperties:properties flags:MSACFlagsDefault];
}

- (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties flags:(MSACFlags)flags {
  MSACEventProperties *eventProperties;
  if (properties) {
    eventProperties = [MSACEventProperties new];
    for (NSString *key in properties.allKeys) {
      NSString *value = properties[key];
      [eventProperties setString:value forKey:key];
    }
  }
  [self trackEvent:eventName withTypedProperties:eventProperties flags:flags];
}

- (void)trackEvent:(NSString *)eventName withTypedProperties:(nullable MSACEventProperties *)properties {
  [self trackEvent:eventName withTypedProperties:properties flags:MSACFlagsDefault];
}

- (void)trackEvent:(NSString *)eventName withTypedProperties:(nullable MSACEventProperties *)properties flags:(MSACFlags)flags {
  MSACEventProperties *mergedProperties = [MSACEventProperties new];

  // Merge properties in its ancestors.
  MSACAnalyticsTransmissionTarget *target = self;
  while (target != nil) {
    [target.propertyConfigurator mergeTypedPropertiesWith:mergedProperties];
    target = target.parentTarget;
  }

  // Override properties.
  if (properties) {
    [mergedProperties mergeEventProperties:(MSACEventProperties * __nonnull) properties];
  } else if ([mergedProperties isEmpty]) {

    // Set nil for the properties to pass nil to trackEvent.
    mergedProperties = nil;
  }
  [MSACAnalytics trackEvent:eventName withTypedProperties:mergedProperties forTransmissionTarget:self flags:flags];
}

- (MSACAnalyticsTransmissionTarget *)transmissionTargetForToken:(NSString *)token {

  // Look up for the token in the dictionary, create a new transmission target if doesn't exist.
  MSACAnalyticsTransmissionTarget *target = self.childTransmissionTargets[token];
  if (!target) {
    target = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:token
                                                                         parentTarget:self
                                                                         channelGroup:self.channelGroup];
    self.childTransmissionTargets[token] = target;
  }
  return target;
}

- (BOOL)isEnabled {
  @synchronized([MSACAnalytics sharedInstance]) {

    // Get isEnabled value from persistence. No need to cache the value in a property, user settings already have their cache mechanism.
    NSNumber *isEnabledNumber = [MSAC_APP_CENTER_USER_DEFAULTS objectForKey:self.isEnabledKey];

    // Return the persisted value otherwise it's enabled by default.
    return (isEnabledNumber) ? [isEnabledNumber boolValue] : YES;
  }
}

- (void)setEnabled:(BOOL)isEnabled {
  @synchronized([MSACAnalytics sharedInstance]) {
    if (self.isEnabled != isEnabled) {

      // Don't enable if the immediate parent is disabled.
      if (isEnabled && ![self isImmediateParent]) {
        MSACLogWarning([MSACAnalytics logTag], @"Can't enable; parent transmission "
                                               @"target and/or Analytics service "
                                               @"is disabled.");
        return;
      }

      // Persist the enabled status.
      [MSAC_APP_CENTER_USER_DEFAULTS setObject:@(isEnabled) forKey:self.isEnabledKey];

      if (isEnabled) {

        // Resume the target on enable
        [self resume];
      }
    }

    // Propagate to nested transmission targets.
    for (NSString *token in self.childTransmissionTargets) {
      [self.childTransmissionTargets[token] setEnabled:isEnabled];
    }
  }
}

- (void)pause {
  if (self.isEnabled) {
    [MSACAnalytics pauseTransmissionTargetForToken:self.transmissionTargetToken];
  } else {
    MSACLogError([MSACAnalytics logTag], @"This transmission target is disabled.");
  }
}

- (void)resume {
  if (self.isEnabled) {
    [MSACAnalytics resumeTransmissionTargetForToken:self.transmissionTargetToken];
  } else {
    MSACLogError([MSACAnalytics logTag], @"This transmission target is disabled.");
  }
}

#pragma mark - ChannelDelegate callbacks

- (void)channel:(id<MSACChannelProtocol>)__unused channel prepareLog:(id<MSACLog>)log {

  // Only set ticketKey for owned target. Not strictly necessary but this avoids setting the ticketKeyHash multiple times for a log.
  if (![log.transmissionTargetTokens containsObject:self.transmissionTargetToken]) {
    return;
  }
  if ([log isKindOfClass:[MSACCommonSchemaLog class]] && [self isEnabled]) {
    if (MSACAnalyticsTransmissionTarget.authenticationProvider) {
      NSString *ticketKeyHash = MSACAnalyticsTransmissionTarget.authenticationProvider.ticketKeyHash;
      ((MSACCommonSchemaLog *)log).ext.protocolExt.ticketKeys = @[ ticketKeyHash ];
      [MSACAnalyticsTransmissionTarget.authenticationProvider checkTokenExpiry];
    }
  }
}

#pragma mark - Private methods

+ (MSACAnalyticsAuthenticationProvider *)authenticationProvider {
  @synchronized(self) {
    return _authenticationProvider;
  }
}

+ (void)setAuthenticationProvider:(MSACAnalyticsAuthenticationProvider *)authenticationProvider {
  @synchronized(self) {
    _authenticationProvider = authenticationProvider;
  }
}

/**
 * Check ancestor enabled state, the ancestor is either the immediate target parent if there is one or Analytics.
 *
 * @return YES if the immediate ancestor is enabled.
 */
- (BOOL)isImmediateParent {
  return self.parentTarget ? self.parentTarget.isEnabled : [MSACAnalytics isEnabled];
}

@end
