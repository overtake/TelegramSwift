// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "MSACAnalyticsConstants.h"
#import "MSACAnalyticsInternal.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACConstants+Internal.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventLogPrivate.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACMetadataExtension.h"
#import "MSACStringTypedProperty.h"

static NSString *const kMSACTypeEvent = @"event";

static NSString *const kMSACId = @"id";

static NSString *const kMSACTypedProperties = @"typedProperties";

@implementation MSACEventLog

- (instancetype)init {
  if ((self = [super init])) {
    self.type = kMSACTypeEvent;
    _metadataTypeIdMapping = @{
      kMSACLongTypedPropertyType : @(kMSACLongMetadataTypeId),
      kMSACDoubleTypedPropertyType : @(kMSACDoubleMetadataTypeId),
      kMSACDateTimeTypedPropertyType : @(kMSACDateTimeMetadataTypeId)
    };
  }
  return self;
}

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary];
  if (self.eventId) {
    dict[kMSACId] = self.eventId;
  }
  if (self.typedProperties) {
    dict[kMSACTypedProperties] = [self.typedProperties serializeToArray];
  }
  return dict;
}

- (BOOL)isValid {
  return [super isValid] && MSACLOG_VALIDATE_NOT_NIL(eventId);
}

- (BOOL)isEqual:(id)object {
  if (![(NSObject *)object isKindOfClass:[MSACEventLog class]] || ![super isEqual:object]) {
    return NO;
  }
  MSACEventLog *eventLog = (MSACEventLog *)object;
  return ((!self.eventId && !eventLog.eventId) || [self.eventId isEqualToString:eventLog.eventId]);
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _eventId = [coder decodeObjectForKey:kMSACId];
    _typedProperties = [coder decodeObjectForKey:kMSACTypedProperties];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.eventId forKey:kMSACId];
  [coder encodeObject:self.typedProperties forKey:kMSACTypedProperties];
}

#pragma mark - MSACAbstractLog

- (MSACCommonSchemaLog *)toCommonSchemaLogForTargetToken:(NSString *)token flags:(MSACFlags)flags {
  MSACCommonSchemaLog *csLog = [super toCommonSchemaLogForTargetToken:token flags:flags];

  // Event name goes to part A.
  csLog.name = self.name;

  // Metadata extension must accompany data.
  // Event properties goes to part C.
  [self setPropertiesAndMetadataForCSLog:csLog];
  csLog.tag = self.tag;
  return csLog;
}

#pragma mark - Helper

- (void)setPropertiesAndMetadataForCSLog:(MSACCommonSchemaLog *)csLog {
  NSMutableDictionary *csProperties;
  NSMutableDictionary *metadata;
  if (self.typedProperties) {
    csProperties = [NSMutableDictionary new];
    metadata = [NSMutableDictionary new];
    NSString *baseTypePrefix = [NSString stringWithFormat:@"%@.", kMSACDataBaseType];
    NSString *baseDataPrefix = [NSString stringWithFormat:@"%@.", kMSACDataBaseData];

    // If baseType is set and valid, make sure it's paired with at least 1 "baseData.*" property.
    if ([self.typedProperties.properties[kMSACDataBaseType] isKindOfClass:[MSACStringTypedProperty class]]) {
      BOOL foundBaseData = NO;
      for (NSString *key in [self.typedProperties.properties allKeys]) {
        if ([key hasPrefix:baseDataPrefix]) {
          foundBaseData = YES;
          break;
        }
      }
      if (!foundBaseData) {
        MSACLogWarning([MSACAnalytics logTag], @"baseType was set but baseData is missing.");
        [self.typedProperties.properties removeObjectForKey:kMSACDataBaseType];
      }
    }

    // If there is no valid "baseType" property, there must not be any "baseData.*" property.
    else {
      BOOL removedBaseData = NO;
      for (NSString *key in [self.typedProperties.properties allKeys]) {
        if ([key hasPrefix:baseDataPrefix]) {
          [self.typedProperties.properties removeObjectForKey:key];
          removedBaseData = YES;
        }
      }
      if (removedBaseData) {
        MSACLogWarning([MSACAnalytics logTag], @"baseData was set but baseType is missing or invalid.");
      }

      // Base type might be set but invalid, so remove it.
      [self.typedProperties.properties removeObjectForKey:kMSACDataBaseType];
    }

    // Add typed properties and metadata to the common schema log fields.
    for (MSACTypedProperty *typedProperty in [self.typedProperties.properties objectEnumerator]) {

      // Validate baseType is not an object, meaning it should not have dot.
      if ([[typedProperty name] hasPrefix:baseTypePrefix]) {
        MSACLogWarning([MSACAnalytics logTag], @"baseType must not be an object.");
        continue;
      }

      // Validate baseData is an object, meaning it has at least 1 dot.
      if ([[typedProperty name] isEqualToString:kMSACDataBaseData]) {
        MSACLogWarning([MSACAnalytics logTag], @"baseData must be an object.");
        continue;
      }

      // Convert property.
      [self addTypedProperty:typedProperty toCSMetadata:metadata andCSProperties:csProperties];
    }
  }
  if (csProperties.count != 0) {
    csLog.data = [MSACCSData new];
    csLog.data.properties = csProperties;
  }
  if (metadata.count != 0) {
    csLog.ext.metadataExt = [MSACMetadataExtension new];
    csLog.ext.metadataExt.metadata = metadata;
  }
}

- (void)addTypedProperty:(MSACTypedProperty *)typedProperty
            toCSMetadata:(NSMutableDictionary *)csMetadata
         andCSProperties:(NSMutableDictionary *)csProperties {
  NSNumber *typeId = self.metadataTypeIdMapping[typedProperty.type];

  // If the key contains a '.' then it's nested objects (i.e: "a.b":"value" => {"a":{"b":"value"}}).
  NSArray *csKeys = [typedProperty.name componentsSeparatedByString:@"."];
  NSMutableDictionary *propertyTree = csProperties;
  NSMutableDictionary *metadataTree = csMetadata;

  /*
   * Keep track of the subtree that contains all the metadata levels added in the for loop.
   * Thus if it needs to be removed, a second traversal is not needed.
   * The metadata should be cleaned up if the property is not added due to a key collision.
   */
  NSMutableDictionary *metadataSubtreeParent = nil;
  for (NSUInteger i = 0; i < csKeys.count - 1; i++) {
    id key = csKeys[i];
    if (![(NSObject *)propertyTree[key] isKindOfClass:[NSMutableDictionary class]]) {
      if (propertyTree[key]) {
        propertyTree = nil;
        break;
      }
      propertyTree[key] = [NSMutableDictionary new];
    }
    propertyTree = propertyTree[key];
    if (typeId) {
      if (!metadataTree[kMSACFieldDelimiter]) {
        metadataTree[kMSACFieldDelimiter] = [NSMutableDictionary new];
        metadataSubtreeParent = metadataSubtreeParent ?: metadataTree;
      }
      if (!metadataTree[kMSACFieldDelimiter][key]) {
        metadataTree[kMSACFieldDelimiter][key] = [NSMutableDictionary new];
      }
      metadataTree = metadataTree[kMSACFieldDelimiter][key];
    }
  }
  id lastKey = csKeys.lastObject;
  BOOL didAddTypedProperty = [self addTypedProperty:typedProperty toPropertyTree:propertyTree withKey:lastKey];
  if (typeId && didAddTypedProperty) {
    if (!metadataTree[kMSACFieldDelimiter]) {
      metadataTree[kMSACFieldDelimiter] = [NSMutableDictionary new];
    }
    metadataTree[kMSACFieldDelimiter][lastKey] = typeId;
  } else if (metadataSubtreeParent) {
    [metadataSubtreeParent removeObjectForKey:kMSACFieldDelimiter];
  }
}

- (BOOL)addTypedProperty:(MSACTypedProperty *)typedProperty toPropertyTree:(NSMutableDictionary *)propertyTree withKey:(NSString *)key {
  if (!propertyTree || propertyTree[key]) {
    MSACLogWarning(MSACAnalytics.logTag, @"Property key '%@' already has a value, choosing one.", key);
    return NO;
  }
  if ([typedProperty isKindOfClass:[MSACStringTypedProperty class]]) {
    MSACStringTypedProperty *stringProperty = (MSACStringTypedProperty *)typedProperty;
    propertyTree[key] = stringProperty.value;
  } else if ([typedProperty isKindOfClass:[MSACBooleanTypedProperty class]]) {
    MSACBooleanTypedProperty *boolProperty = (MSACBooleanTypedProperty *)typedProperty;
    propertyTree[key] = @(boolProperty.value);
  } else if ([typedProperty isKindOfClass:[MSACLongTypedProperty class]]) {
    MSACLongTypedProperty *longProperty = (MSACLongTypedProperty *)typedProperty;
    propertyTree[key] = @(longProperty.value);
  } else if ([typedProperty isKindOfClass:[MSACDoubleTypedProperty class]]) {
    MSACDoubleTypedProperty *doubleProperty = (MSACDoubleTypedProperty *)typedProperty;
    propertyTree[key] = @(doubleProperty.value);
  } else if ([typedProperty isKindOfClass:[MSACDateTimeTypedProperty class]]) {
    MSACDateTimeTypedProperty *dateProperty = (MSACDateTimeTypedProperty *)typedProperty;
    propertyTree[key] = [MSACUtility dateToISO8601:dateProperty.value];
  }
  return YES;
}

@end
