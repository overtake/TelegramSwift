// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <IOKit/IOKitLib.h>
#else
#import <UIKit/UIKit.h>
#endif

#import "MSACAnalyticsInternal.h"
#import "MSACAnalyticsTransmissionTargetInternal.h"
#import "MSACAnalyticsTransmissionTargetPrivate.h"
#import "MSACAppExtension.h"
#import "MSACCSExtensions.h"
#import "MSACCommonSchemaLog.h"
#import "MSACConstants+Internal.h"
#import "MSACDeviceExtension.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLogger.h"
#import "MSACPropertyConfiguratorPrivate.h"
#import "MSACStringTypedProperty.h"
#import "MSACUserExtension.h"
#import "MSACUserIdContext.h"

@implementation MSACPropertyConfigurator

#if TARGET_OS_OSX
static const char deviceIdPrefix = 'u';
#else
static const char deviceIdPrefix = 'i';
#endif

- (instancetype)initWithTransmissionTarget:(MSACAnalyticsTransmissionTarget *)transmissionTarget {
  if ((self = [super init])) {
    _transmissionTarget = transmissionTarget;
    _eventProperties = [MSACEventProperties new];
  }
  return self;
}

- (void)setAppVersion:(NSString *)appVersion {
  _appVersion = appVersion;
}

- (void)setAppName:(NSString *)appName {
  _appName = appName;
}

- (void)setAppLocale:(NSString *)appLocale {
  _appLocale = appLocale;
}

- (void)setUserId:(NSString *)userId {
  if ([MSACUserIdContext isUserIdValidForOneCollector:userId]) {
    NSString *prefixedUserId = [MSACUserIdContext prefixedUserIdFromUserId:userId];
    _userId = prefixedUserId;
  }
}

- (void)setEventPropertyString:(NSString *)propertyValue forKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    [self.eventProperties setString:propertyValue forKey:propertyKey];
  }
}

- (void)setEventPropertyDouble:(double)propertyValue forKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    [self.eventProperties setDouble:propertyValue forKey:propertyKey];
  }
}

- (void)setEventPropertyInt64:(int64_t)propertyValue forKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    [self.eventProperties setInt64:propertyValue forKey:propertyKey];
  }
}

- (void)setEventPropertyBool:(BOOL)propertyValue forKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    [self.eventProperties setBool:propertyValue forKey:propertyKey];
  }
}

- (void)setEventPropertyDate:(NSDate *)propertyValue forKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    [self.eventProperties setDate:propertyValue forKey:propertyKey];
  }
}

- (void)removeEventPropertyForKey:(NSString *)propertyKey {
  @synchronized([MSACAnalytics sharedInstance]) {
    if (!propertyKey) {
      MSACLogError([MSACAnalytics logTag], @"Event property key to remove cannot be nil.");
      return;
    }
    [self.eventProperties.properties removeObjectForKey:propertyKey];
  }
}

- (void)collectDeviceId {
  self.deviceId = [MSACPropertyConfigurator getDeviceIdentifier];
}

#pragma mark - MSACChannelDelegate

- (void)channel:(id<MSACChannelProtocol>)__unused channel prepareLog:(id<MSACLog>)log {
  MSACAnalyticsTransmissionTarget *target = self.transmissionTarget;
  if (target && [log isKindOfClass:[MSACCommonSchemaLog class]] && target.enabled && [log.tag isEqual:target]) {

    // Override the application version.
    while (target) {
      if (target.propertyConfigurator.appVersion) {
        ((MSACCommonSchemaLog *)log).ext.appExt.ver = target.propertyConfigurator.appVersion;
        break;
      }
      target = target.parentTarget;
    }

    // Override the application name.
    target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.appName) {
        ((MSACCommonSchemaLog *)log).ext.appExt.name = target.propertyConfigurator.appName;
        break;
      }
      target = target.parentTarget;
    }

    // Override the application locale.
    target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.appLocale) {
        ((MSACCommonSchemaLog *)log).ext.appExt.locale = target.propertyConfigurator.appLocale;
        break;
      }
      target = target.parentTarget;
    }

    // Override the userId.
    target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.userId) {
        ((MSACCommonSchemaLog *)log).ext.userExt.localId = target.propertyConfigurator.userId;
        break;
      }
      target = target.parentTarget;
    }

    // The device ID must not be inherited from parent transmission targets.
    [((MSACCommonSchemaLog *)log) ext].deviceExt.localId = self.deviceId;
  }
}

#pragma mark - Helper methods

+ (NSString *)getDeviceIdentifier {
  NSString *baseIdentifier;
#if TARGET_OS_OSX

  io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
  CFStringRef platformUUIDAsCFString = NULL;
  if (platformExpert) {
    platformUUIDAsCFString =
        (CFStringRef)IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(platformExpert);
  }
  NSString *platformUUIDAsNSString = nil;
  if (platformUUIDAsCFString) {
    platformUUIDAsNSString = [NSString stringWithString:(__bridge NSString *)platformUUIDAsCFString];
    CFRelease(platformUUIDAsCFString);
  }
  baseIdentifier = platformUUIDAsNSString;

#else
  baseIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
#endif
  return [NSString stringWithFormat:@"%c:%@", deviceIdPrefix, baseIdentifier];
}

- (void)mergeTypedPropertiesWith:(MSACEventProperties *)mergedEventProperties {
  @synchronized([MSACAnalytics sharedInstance]) {
    for (NSString *key in self.eventProperties.properties) {
      if (!mergedEventProperties.properties[key]) {
        mergedEventProperties.properties[key] = self.eventProperties.properties[key];
      }
    }
  }
}

@end
