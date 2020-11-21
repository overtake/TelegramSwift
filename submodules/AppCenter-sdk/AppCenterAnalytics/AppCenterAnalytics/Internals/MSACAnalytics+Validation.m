// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "MSACAnalytics+Validation.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACConstants+Internal.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventLog.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACPageLog.h"
#import "MSACStringTypedProperty.h"

// Events values limitations
static const int kMSACMinEventNameLength = 1;
static const int kMSACMaxEventNameLength = 256;

/*
 * Workaround for exporting symbols from category object files.
 */
NSString *MSACAnalyticsValidationCategory;

@implementation MSACAnalytics (Validation)

- (BOOL)channelUnit:(id<MSACChannelUnitProtocol>)__unused channelUnit shouldFilterLog:(id<MSACLog>)log {
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSACEventLog class]]) {
    return ![self validateLog:(MSACEventLog *)log];
  } else if ([logObject isKindOfClass:[MSACPageLog class]]) {
    return ![self validateLog:(MSACPageLog *)log];
  }
  return NO;
}

- (BOOL)validateLog:(MSACLogWithNameAndProperties *)log {

  // Validate event name.
  NSString *validName = [self validateEventName:log.name forLogType:log.type];
  if (!validName) {
    return NO;
  }
  log.name = validName;

  // Send only valid properties.
  log.properties = [self validateProperties:log.properties forLogName:log.name andType:log.type];
  return YES;
}

- (nullable NSString *)validateEventName:(NSString *)eventName forLogType:(NSString *)logType {
  if (!eventName || [eventName length] < kMSACMinEventNameLength) {
    MSACLogError([MSACAnalytics logTag], @"%@ name cannot be null or empty", logType);
    return nil;
  }
  if ([eventName length] > kMSACMaxEventNameLength) {
    MSACLogWarning([MSACAnalytics logTag],
                   @"%@ '%@' : name length cannot be longer than %d characters. "
                   @"Name will be truncated.",
                   logType, eventName, kMSACMaxEventNameLength);
    eventName = [eventName substringToIndex:kMSACMaxEventNameLength];
  }
  return eventName;
}

- (NSDictionary<NSString *, NSString *> *)validateProperties:(NSDictionary<NSString *, NSString *> *)properties
                                                  forLogName:(NSString *)logName
                                                     andType:(NSString *)logType {

  // Keeping this method body in MSACAnalytics to use it in unit tests.
  return [MSACUtility validateProperties:properties forLogName:logName type:logType];
}

- (MSACEventProperties *)validateAppCenterEventProperties:(MSACEventProperties *)eventProperties {
  MSACEventProperties *validCopy = [MSACEventProperties new];
  for (NSString *propertyKey in eventProperties.properties) {
    if ([validCopy.properties count] == kMSACMaxPropertiesPerLog) {
      MSACLogWarning([MSACAnalytics logTag], @"Typed properties cannot contain more than %d items. Skipping other properties.",
                     kMSACMaxPropertiesPerLog);
      break;
    }
    MSACTypedProperty *property = eventProperties.properties[propertyKey];
    MSACTypedProperty *validProperty = [self validateAppCenterTypedProperty:property];
    if (validProperty) {
      validCopy.properties[validProperty.name] = validProperty;
    }
  }
  return validCopy;
}

- (MSACTypedProperty *)validateAppCenterTypedProperty:(MSACTypedProperty *)typedProperty {
  MSACTypedProperty *validProperty;
  if ([typedProperty isKindOfClass:[MSACStringTypedProperty class]]) {
    MSACStringTypedProperty *originalStringProperty = (MSACStringTypedProperty *)typedProperty;
    MSACStringTypedProperty *validStringProperty = [MSACStringTypedProperty new];
    validStringProperty.value = [self validateAppCenterStringTypedPropertyValue:originalStringProperty.value];
    validProperty = validStringProperty;
  } else if ([typedProperty isKindOfClass:[MSACBooleanTypedProperty class]]) {
    validProperty = [MSACBooleanTypedProperty new];
    ((MSACBooleanTypedProperty *)validProperty).value = ((MSACBooleanTypedProperty *)typedProperty).value;
  } else if ([typedProperty isKindOfClass:[MSACLongTypedProperty class]]) {
    validProperty = [MSACLongTypedProperty new];
    ((MSACLongTypedProperty *)validProperty).value = ((MSACLongTypedProperty *)typedProperty).value;
  } else if ([typedProperty isKindOfClass:[MSACDoubleTypedProperty class]]) {
    validProperty = [MSACDoubleTypedProperty new];
    ((MSACDoubleTypedProperty *)validProperty).value = ((MSACDoubleTypedProperty *)typedProperty).value;
  } else if ([typedProperty isKindOfClass:[MSACDateTimeTypedProperty class]]) {
    validProperty = [MSACDateTimeTypedProperty new];
    ((MSACDateTimeTypedProperty *)validProperty).value = ((MSACDateTimeTypedProperty *)typedProperty).value;
  }
  validProperty.name = [self validateAppCenterPropertyName:typedProperty.name];
  return validProperty;
}

- (NSString *)validateAppCenterPropertyName:(NSString *)propertyKey {
  if ([propertyKey length] > kMSACMaxPropertyKeyLength) {
    MSACLogWarning([MSACAnalytics logTag],
                   @"Typed property '%@': key length cannot exceed %d characters. Property value will be truncated.", propertyKey,
                   kMSACMaxPropertyKeyLength);
    return [propertyKey substringToIndex:(kMSACMaxPropertyKeyLength - 1)];
  }
  return propertyKey;
}

- (NSString *)validateAppCenterStringTypedPropertyValue:(NSString *)value {
  if ([value length] > kMSACMaxPropertyValueLength) {
    MSACLogWarning([MSACAnalytics logTag], @"Typed property value length cannot exceed %d characters. Property value will be truncated.",
                   kMSACMaxPropertyValueLength);
    return [value substringToIndex:(kMSACMaxPropertyValueLength - 1)];
  }
  return value;
}

@end
