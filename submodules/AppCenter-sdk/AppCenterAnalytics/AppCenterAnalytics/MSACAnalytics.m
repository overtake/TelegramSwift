// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalytics+Validation.h"
#import "MSACAnalyticsCategory.h"
#import "MSACAnalyticsConstants.h"
#import "MSACAnalyticsPrivate.h"
#import "MSACAnalyticsTransmissionTargetInternal.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACChannelGroupProtocol.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitProtocol.h"
#import "MSACConstants+Internal.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDeviceHistoryInfo.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventLog.h"
#import "MSACEventProperties.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACPageLog.h"
#import "MSACSessionContext.h"
#import "MSACStartSessionLog.h"
#import "MSACStringTypedProperty.h"
#import "MSACTypedProperty.h"
#import "MSACUserIdContext.h"
#import "MSACUtility+StringFormatting.h"

// Service name for initialization.
static NSString *const kMSACServiceName = @"Analytics";

// The group Id for Analytics.
static NSString *const kMSACGroupId = @"Analytics";

// Singleton
static MSACAnalytics *sharedInstance = nil;
static dispatch_once_t onceToken;

@implementation MSACAnalytics

/**
 * @discussion
 * Workaround for exporting symbols from category object files.
 * See article
 * https://medium.com/ios-os-x-development/categories-in-static-libraries-78e41f8ddb96#.aedfl1kl0
 */
__attribute__((used)) static void importCategories() { [NSString stringWithFormat:@"%@", MSACAnalyticsValidationCategory]; }

@synthesize autoPageTrackingEnabled = _autoPageTrackingEnabled;
@synthesize channelUnitConfiguration = _channelUnitConfiguration;

#pragma mark - Service initialization

- (instancetype)init {
  if ((self = [super init])) {
    [MSAC_APP_CENTER_USER_DEFAULTS migrateKeys:@{
      @"MSAppCenterAnalyticsIsEnabled" : MSACPrefixKeyFrom(@"kMSAnalyticsIsEnabledKey"), // [MSACAnalytics isEnabled]
      @"MSAppCenterPastSessions" : @"pastSessionsKey"                                    // [MSACSessionTracker init]
    }
                                    forService:kMSACServiceName];
    [MSACUtility addMigrationClasses:@{
      @"MSSessionHistoryInfo" : MSACSessionHistoryInfo.self,
      @"MSAbstractLog" : MSACAbstractLog.self,
      @"MSEventLog" : MSACEventLog.self,
      @"MSPageLog" : MSACPageLog.self,
      @"MSEventProperties" : MSACEventProperties.self,
      @"MSLogWithNameAndProperties" : MSACLogWithNameAndProperties.self,
      @"MSBooleanTypedProperty" : MSACBooleanTypedProperty.self,
      @"MSDateTimeTypedProperty" : MSACDateTimeTypedProperty.self,
      @"MSDoubleTypedProperty" : MSACDoubleTypedProperty.self,
      @"MSLongTypedProperty" : MSACLongTypedProperty.self,
      @"MSStringTypedProperty" : MSACStringTypedProperty.self,
      @"MSTypedProperty" : MSACTypedProperty.self,
      @"MSStartSessionLog" : MSACStartSessionLog.self
    }];

    // Set defaults.
    _autoPageTrackingEnabled = NO;
    _flushInterval = kMSACFlushIntervalDefault;

    // Init session tracker.
    _sessionTracker = [[MSACSessionTracker alloc] init];
    _sessionTracker.delegate = self;

    // Set up transmission target dictionary.
    _transmissionTargets = [NSMutableDictionary<NSString *, MSACAnalyticsTransmissionTarget *> new];
  }
  return self;
}

#pragma mark - MSACServiceInternal

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    if (sharedInstance == nil) {
      sharedInstance = [[MSACAnalytics alloc] init];
    }
  });
  return sharedInstance;
}

+ (NSString *)serviceName {
  return kMSACServiceName;
}

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup
                    appSecret:(nullable NSString *)appSecret
      transmissionTargetToken:(nullable NSString *)token
              fromApplication:(BOOL)fromApplication {

  // Init channel configuration.
  self.channelUnitConfiguration = [[MSACChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:[self groupId]
                                                                                              flushInterval:self.flushInterval];
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:token fromApplication:fromApplication];
  if (token) {

    /*
     * Don't use [self transmissionTargetForToken] because that will add the default transmission target to the cache, but it should be
     * separate.
     */
    self.defaultTransmissionTarget = [self createTransmissionTargetForToken:token];
  }

  // Add extra channel for critical events.
  NSString *criticalGroupId = [NSString stringWithFormat:@"%@_%@", kMSACGroupId, kMSACCriticalChannelSuffix];
  MSACChannelUnitConfiguration *channelUnitConfiguration =
      [[MSACChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:criticalGroupId];
  self.criticalChannelUnit = [self.channelGroup addChannelUnitWithConfiguration:channelUnitConfiguration];

  // TODO: Uncomment when auto page tracking will be supported.
  // Set up swizzling for auto page tracking.
  // [MSACAnalyticsCategory activateCategory];
  MSACLogVerbose([MSACAnalytics logTag], @"Started Analytics service.");
}

+ (NSString *)logTag {
  return @"AppCenterAnalytics";
}

- (NSString *)groupId {
  return kMSACGroupId;
}

#pragma mark - MSACServiceAbstract

- (void)setEnabled:(BOOL)isEnabled {
  [super setEnabled:isEnabled];

  // Propagate to transmission targets.
  for (NSString *token in self.transmissionTargets) {
    [self.transmissionTargets[token] setEnabled:isEnabled];
  }
  [self.defaultTransmissionTarget setEnabled:isEnabled];
}

- (void)applyEnabledState:(BOOL)isEnabled {
  [super applyEnabledState:isEnabled];
  [self.criticalChannelUnit setEnabled:isEnabled andDeleteDataOnDisabled:YES];
  if (isEnabled) {
    if (self.startedFromApplication) {
      [self resume];

      // Start session tracker.
      [self.sessionTracker start];

      // Add delegates to log manager.
      [self.channelGroup addDelegate:self.sessionTracker];
      [self.channelGroup addDelegate:self];

      // Report current page while auto page tracking is on.
      if (self.autoPageTrackingEnabled) {

        // Track on the main queue to avoid race condition with page swizzling.
        dispatch_async(dispatch_get_main_queue(), ^{
          if ([[MSACAnalyticsCategory missedPageViewName] length] > 0) {
            [[self class] trackPage:(NSString *)[MSACAnalyticsCategory missedPageViewName]];
          }
        });
      }
    }

    MSACLogInfo([MSACAnalytics logTag], @"Analytics service has been enabled.");
  } else {
    if (self.startedFromApplication) {
      [self.channelGroup removeDelegate:self.sessionTracker];
      [self.channelGroup removeDelegate:self];
      [self.sessionTracker stop];
      [[MSACSessionContext sharedInstance] clearSessionHistoryAndKeepCurrentSession:NO];
    }
    MSACLogInfo([MSACAnalytics logTag], @"Analytics service has been disabled.");
  }
}

- (BOOL)isAppSecretRequired {
  return NO;
}

- (void)updateConfigurationWithAppSecret:(NSString *)appSecret transmissionTargetToken:(NSString *)token {
  [super updateConfigurationWithAppSecret:appSecret transmissionTargetToken:token];

  // Create the default target if not already created in start.
  if (token && !self.defaultTransmissionTarget) {

    /*
     * Don't use [self transmissionTargetForToken] because that will add the default transmission target to the cache, but it should be
     * separate.
     */
    self.defaultTransmissionTarget = [self createTransmissionTargetForToken:token];
  }
}

#pragma mark - Service methods

+ (void)trackEvent:(NSString *)eventName {
  [self trackEvent:eventName withProperties:nil];
}

+ (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  [self trackEvent:eventName withProperties:properties flags:MSACFlagsDefault];
}

+ (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties flags:(MSACFlags)flags {
  [self trackEvent:eventName withProperties:properties forTransmissionTarget:nil flags:flags];
}

+ (void)trackEvent:(NSString *)eventName withTypedProperties:(nullable MSACEventProperties *)properties {
  [self trackEvent:eventName withTypedProperties:properties flags:MSACFlagsDefault];
}

+ (void)trackEvent:(NSString *)eventName withTypedProperties:(nullable MSACEventProperties *)properties flags:(MSACFlags)flags {
  [self trackEvent:eventName withTypedProperties:properties forTransmissionTarget:nil flags:flags];
}

+ (void)trackEvent:(NSString *)eventName
           withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties
    forTransmissionTarget:(nullable MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags {
  [[MSACAnalytics sharedInstance] trackEvent:eventName withProperties:properties forTransmissionTarget:transmissionTarget flags:flags];
}

+ (void)trackEvent:(NSString *)eventName
      withTypedProperties:(nullable MSACEventProperties *)properties
    forTransmissionTarget:(nullable MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags {
  [[MSACAnalytics sharedInstance] trackEvent:eventName withTypedProperties:properties forTransmissionTarget:transmissionTarget flags:flags];
}

+ (void)trackPage:(NSString *)pageName {
  [self trackPage:pageName withProperties:nil];
}

+ (void)trackPage:(NSString *)pageName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  [[MSACAnalytics sharedInstance] trackPage:pageName withProperties:properties];
}

+ (void)pause {
  [[MSACAnalytics sharedInstance] pause];
}

+ (void)resume {
  [[MSACAnalytics sharedInstance] resume];
}

+ (void)setAutoPageTrackingEnabled:(BOOL)isEnabled {
  [MSACAnalytics sharedInstance].autoPageTrackingEnabled = isEnabled;
}

+ (BOOL)isAutoPageTrackingEnabled {
  return [MSACAnalytics sharedInstance].autoPageTrackingEnabled;
}

+ (NSUInteger)transmissionInterval {
  return [MSACAnalytics sharedInstance].flushInterval;
}

+ (void)setTransmissionInterval:(NSUInteger)interval {
  [[MSACAnalytics sharedInstance] setTransmissionInterval:interval];
}

#pragma mark - Transmission Target

+ (MSACAnalyticsTransmissionTarget *)transmissionTargetForToken:(NSString *)token {
  return [[MSACAnalytics sharedInstance] transmissionTargetForToken:token];
}

+ (void)pauseTransmissionTargetForToken:(NSString *)token {
  [[MSACAnalytics sharedInstance] pauseTransmissionTargetForToken:token];
}

+ (void)resumeTransmissionTargetForToken:(NSString *)token {
  [[MSACAnalytics sharedInstance] resumeTransmissionTargetForToken:token];
}

#pragma mark - Private methods

- (void)trackEvent:(NSString *)eventName
           withProperties:(NSDictionary<NSString *, NSString *> *)properties
    forTransmissionTarget:(MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags {
  NSDictionary *validProperties = [self removeInvalidProperties:properties];
  MSACEventProperties *eventProperties = [[MSACEventProperties alloc] initWithStringDictionary:validProperties];
  [self trackEvent:eventName withTypedProperties:eventProperties forTransmissionTarget:transmissionTarget flags:flags];
}

- (void)trackEvent:(NSString *)eventName
      withTypedProperties:(MSACEventProperties *)properties
    forTransmissionTarget:(MSACAnalyticsTransmissionTarget *)transmissionTarget
                    flags:(MSACFlags)flags {
  @synchronized(self) {
    if (![self canBeUsed] || ![self isEnabled]) {
      return;
    }

    // Use default transmission target if no transmission target was provided.
    if (transmissionTarget == nil) {
      transmissionTarget = self.defaultTransmissionTarget;
    }

    // Validate flags.
    MSACFlags persistenceFlag = flags & kMSACPersistenceFlagsMask;
    if (persistenceFlag != MSACFlagsNormal && persistenceFlag != MSACFlagsCritical) {
      MSACLogWarning([MSACAnalytics logTag], @"Invalid flags (%u) received, using normal as a default.", (unsigned int)persistenceFlag);
      persistenceFlag = MSACFlagsNormal;
    }

    // Create an event log.
    MSACEventLog *log = [MSACEventLog new];

    // Add transmission target token.
    if (transmissionTarget) {
      if (transmissionTarget.isEnabled) {
        [log addTransmissionTargetToken:[transmissionTarget transmissionTargetToken]];
        log.tag = transmissionTarget;
        if (transmissionTarget == self.defaultTransmissionTarget) {
          log.userId = [[MSACUserIdContext sharedInstance] userId];
        }
      } else {
        MSACLogError([MSACAnalytics logTag], @"This transmission target is disabled.");
        return;
      }
    } else {
      properties = [self validateAppCenterEventProperties:properties];
    }

    // Set properties of the event log.
    log.name = eventName;
    log.eventId = MSAC_UUID_STRING;
    log.typedProperties = [properties isEmpty] ? nil : properties;

    // Send log to channel.
    [self sendLog:log flags:persistenceFlag];
  }
}

- (void)pause {
  @synchronized(self) {
    if ([self canBeUsed]) {
      [self.channelUnit pauseWithIdentifyingObject:self];
      [self.criticalChannelUnit pauseWithIdentifyingObject:self];
    }
  }
}

- (void)resume {
  @synchronized(self) {
    if ([self canBeUsed]) {
      [self.channelUnit resumeWithIdentifyingObject:self];
      [self.criticalChannelUnit resumeWithIdentifyingObject:self];
    }
  }
}

- (NSDictionary<NSString *, NSString *> *)removeInvalidProperties:(NSDictionary<NSString *, NSString *> *)properties {
  NSMutableDictionary<NSString *, id> *validProperties = [NSMutableDictionary new];
  for (NSString *key in properties) {
    if (![key isKindOfClass:[NSString class]]) {
      MSACLogWarning([MSACAnalytics logTag], @"Event property contains an invalid key, dropping the property.");
      continue;
    }

    // We have a valid key, so let's validate the value.
    id value = properties[key];
    if (value) {

      // Not checking for empty string, as values can be empty strings.
      if ([(NSObject *)value isKindOfClass:[NSString class]]) {
        [validProperties setValue:value forKey:key];
      }
    } else {
      MSACLogWarning([MSACAnalytics logTag], @"Event property contains an invalid value for key %@, dropping the property.", key);
    }
  }

  return validProperties;
}

- (void)trackPage:(NSString *)pageName withProperties:(NSDictionary<NSString *, NSString *> *)properties {
  @synchronized(self) {
    if (![self canBeUsed] || ![self isEnabled]) {
      return;
    }

    // Create an event log.
    MSACPageLog *log = [MSACPageLog new];

    // Set properties of the event log.
    log.name = pageName;
    if (properties && properties.count > 0) {
      log.properties = [self removeInvalidProperties:properties];
    }

    // Send log to log manager.
    [self sendLog:log flags:MSACFlagsDefault];
  }
}

- (void)sendLog:(id<MSACLog>)log flags:(MSACFlags)flags {
  if ((flags & MSACFlagsCritical) != 0) {
    [self.criticalChannelUnit enqueueItem:log flags:flags];
  } else {
    [self.channelUnit enqueueItem:log flags:flags];
  }
}

- (void)setTransmissionInterval:(NSUInteger)interval {
  if (self.started) {
    MSACLogError([MSACAnalytics logTag], @"The transmission interval should be set before the MSACAnalytics service is started.");
    return;
  }
  if (interval > kMSACFlushIntervalMaximum || interval < kMSACFlushIntervalMinimum) {
    MSACLogError([MSACAnalytics logTag],
                 @"The transmission interval is not valid, it should be between %u second(s) and %u second(s) (%u day).",
                 (unsigned int)kMSACFlushIntervalMinimum, (unsigned int)kMSACFlushIntervalMaximum,
                 (unsigned int)(kMSACFlushIntervalMaximum / 86400));
    return;
  }
  self.flushInterval = interval;
  MSACLogDebug([MSACAnalytics logTag], @"Transmission interval set to %u second(s)", (unsigned int)interval);
}

- (MSACAnalyticsTransmissionTarget *)transmissionTargetForToken:(NSString *)transmissionTargetToken {
  MSACAnalyticsTransmissionTarget *transmissionTarget = self.transmissionTargets[transmissionTargetToken];
  if (transmissionTarget) {
    MSACLogDebug([MSACAnalytics logTag], @"Returning transmission target found with id %@.",
                 [MSACUtility targetKeyFromTargetToken:transmissionTargetToken]);
    return transmissionTarget;
  }
  transmissionTarget = [self createTransmissionTargetForToken:transmissionTargetToken];
  self.transmissionTargets[transmissionTargetToken] = transmissionTarget;

  // TODO: Start service if not already.
  // Scenario: getTransmissionTarget gets called before App Center has an app
  // secret or transmission target but start has been called for this service.
  return transmissionTarget;
}

- (MSACAnalyticsTransmissionTarget *)createTransmissionTargetForToken:(NSString *)transmissionTargetToken {
  MSACAnalyticsTransmissionTarget *target = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:transmissionTargetToken
                                                                                                        parentTarget:nil
                                                                                                        channelGroup:self.channelGroup];
  MSACLogDebug([MSACAnalytics logTag], @"Created transmission target with target key %@.",
               [MSACUtility targetKeyFromTargetToken:transmissionTargetToken]);
  return target;
}

- (void)pauseTransmissionTargetForToken:(NSString *)token {
  [self.oneCollectorChannelUnit pauseSendingLogsWithToken:token];
  [self.oneCollectorCriticalChannelUnit pauseSendingLogsWithToken:token];
}

- (void)resumeTransmissionTargetForToken:(NSString *)token {
  [self.oneCollectorChannelUnit resumeSendingLogsWithToken:token];
  [self.oneCollectorCriticalChannelUnit resumeSendingLogsWithToken:token];
}

- (id<MSACChannelUnitProtocol>)oneCollectorChannelUnit {
  if (!_oneCollectorChannelUnit) {
    NSString *oneCollectorGroupId = [NSString stringWithFormat:@"%@%@", self.groupId, kMSACOneCollectorGroupIdSuffix];
    self.oneCollectorChannelUnit = [self.channelGroup channelUnitForGroupId:oneCollectorGroupId];
  }
  return _oneCollectorChannelUnit;
}

- (id<MSACChannelUnitProtocol>)oneCollectorCriticalChannelUnit {
  if (!_oneCollectorCriticalChannelUnit) {
    NSString *oneCollectorCriticalGroupId =
        [NSString stringWithFormat:@"%@_%@%@", self.groupId, kMSACCriticalChannelSuffix, kMSACOneCollectorGroupIdSuffix];
    self.oneCollectorCriticalChannelUnit = [self.channelGroup channelUnitForGroupId:oneCollectorCriticalGroupId];
  }
  return _oneCollectorCriticalChannelUnit;
}

+ (void)resetSharedInstance {

  // Clean existing instance by stopping session tracker, it'll remove its observers.
  [sharedInstance.sessionTracker stop];

  // Resets the once_token so dispatch_once will run again.
  onceToken = 0;
  sharedInstance = nil;
}

#pragma mark - MSACSessionTracker

- (void)sessionTracker:(id)sessionTracker processLog:(id<MSACLog>)log {
  (void)sessionTracker;
  [self sendLog:log flags:MSACFlagsDefault];
}

+ (void)setDelegate:(nullable id<MSACAnalyticsDelegate>)delegate {
  [[MSACAnalytics sharedInstance] setDelegate:delegate];
}

#pragma mark - MSACChannelDelegate

- (void)channel:(id<MSACChannelProtocol>)channel willSendLog:(id<MSACLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  id<MSACAnalyticsDelegate> delegate = self.delegate;
  if ([logObject isKindOfClass:[MSACEventLog class]] && [delegate respondsToSelector:@selector(analytics:willSendEventLog:)]) {
    MSACEventLog *eventLog = (MSACEventLog *)log;
    [delegate analytics:self willSendEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSACPageLog class]] && [delegate respondsToSelector:@selector(analytics:willSendPageLog:)]) {
    MSACPageLog *pageLog = (MSACPageLog *)log;
    [delegate analytics:self willSendPageLog:pageLog];
  }
}

- (void)channel:(id<MSACChannelProtocol>)channel didSucceedSendingLog:(id<MSACLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSACEventLog class]] && [self.delegate respondsToSelector:@selector(analytics:
                                                                                              didSucceedSendingEventLog:)]) {
    MSACEventLog *eventLog = (MSACEventLog *)log;
    [self.delegate analytics:self didSucceedSendingEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSACPageLog class]] && [self.delegate respondsToSelector:@selector(analytics:
                                                                                                    didSucceedSendingPageLog:)]) {
    MSACPageLog *pageLog = (MSACPageLog *)log;
    [self.delegate analytics:self didSucceedSendingPageLog:pageLog];
  }
}

- (void)channel:(id<MSACChannelProtocol>)channel didFailSendingLog:(id<MSACLog>)log withError:(NSError *)error {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  id<MSACAnalyticsDelegate> delegate = self.delegate;
  if ([logObject isKindOfClass:[MSACEventLog class]] && [delegate respondsToSelector:@selector(analytics:
                                                                                         didFailSendingEventLog:withError:)]) {
    MSACEventLog *eventLog = (MSACEventLog *)log;
    [delegate analytics:self didFailSendingEventLog:eventLog withError:error];
  } else if ([logObject isKindOfClass:[MSACPageLog class]] && [delegate respondsToSelector:@selector(analytics:
                                                                                               didFailSendingPageLog:withError:)]) {
    MSACPageLog *pageLog = (MSACPageLog *)log;
    [delegate analytics:self didFailSendingPageLog:pageLog withError:error];
  }
}

@end
