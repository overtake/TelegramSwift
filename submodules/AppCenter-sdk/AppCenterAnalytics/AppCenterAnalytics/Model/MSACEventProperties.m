// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACEventProperties.h"
#import "MSACAnalyticsInternal.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLogger.h"
#import "MSACLongTypedProperty.h"
#import "MSACStringTypedProperty.h"

@implementation MSACEventProperties

- (instancetype)init {
  if ((self = [super init])) {
    _properties = [NSMutableDictionary new];
  }
  return self;
}

- (instancetype)initWithStringDictionary:(NSDictionary<NSString *, NSString *> *)properties {
  if ((self = [self init])) {
    for (NSString *propertyKey in properties) {
      MSACStringTypedProperty *stringProperty = [MSACStringTypedProperty new];
      stringProperty.name = propertyKey;
      stringProperty.value = properties[propertyKey];
      _properties[propertyKey] = stringProperty;
    }
  }
  return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
  @synchronized(self.properties) {
    [coder encodeObject:self.properties];
  }
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  if ((self = [self init])) {
    _properties = (NSMutableDictionary *)[coder decodeObject];
  }
  return self;
}

#pragma mark - Public methods

- (instancetype)setString:(NSString *)value forKey:(NSString *)key {
  if ([MSACEventProperties validateKey:key] && [MSACEventProperties validateValue:value]) {
    MSACStringTypedProperty *stringProperty = [MSACStringTypedProperty new];
    stringProperty.name = key;
    stringProperty.value = value;
    @synchronized(self.properties) {
      self.properties[key] = stringProperty;
    }
  }
  return self;
}

- (instancetype)setDouble:(double)value forKey:(NSString *)key {
  if ([MSACEventProperties validateKey:key]) {

    // NaN returns false for all statements, so the only way to check if value is NaN is by value != value.
    if (value == (double)INFINITY || value == -(double)INFINITY || value != value) {
      MSACLogError([MSACAnalytics logTag], @"Double value for property '%@' must be finite (cannot be INFINITY or NAN).", key);
      return self;
    }
    MSACDoubleTypedProperty *doubleProperty = [MSACDoubleTypedProperty new];
    doubleProperty.name = key;
    doubleProperty.value = value;
    @synchronized(self.properties) {
      self.properties[key] = doubleProperty;
    }
  }
  return self;
}

- (instancetype)setInt64:(int64_t)value forKey:(NSString *)key {
  if ([MSACEventProperties validateKey:key]) {
    MSACLongTypedProperty *longProperty = [MSACLongTypedProperty new];
    longProperty.name = key;
    longProperty.value = value;
    @synchronized(self.properties) {
      self.properties[key] = longProperty;
    }
  }
  return self;
}

- (instancetype)setBool:(BOOL)value forKey:(NSString *)key {
  if ([MSACEventProperties validateKey:key]) {
    MSACBooleanTypedProperty *boolProperty = [MSACBooleanTypedProperty new];
    boolProperty.name = key;
    boolProperty.value = value;
    @synchronized(self.properties) {
      self.properties[key] = boolProperty;
    }
  }
  return self;
}

- (instancetype)setDate:(NSDate *)value forKey:(NSString *)key {
  if ([MSACEventProperties validateKey:key] && [MSACEventProperties validateValue:value]) {
    MSACDateTimeTypedProperty *dateTimeProperty = [MSACDateTimeTypedProperty new];
    dateTimeProperty.name = key;
    dateTimeProperty.value = value;
    @synchronized(self.properties) {
      self.properties[key] = dateTimeProperty;
    }
  }
  return self;
}

#pragma mark - Internal methods

- (NSMutableArray *)serializeToArray {
  NSMutableArray *propertiesArray = [NSMutableArray new];
  @synchronized(self.properties) {
    for (MSACTypedProperty *typedProperty in [self.properties objectEnumerator]) {
      [propertiesArray addObject:[typedProperty serializeToDictionary]];
    }
  }
  return propertiesArray;
}

- (BOOL)isEmpty {
  return [self.properties count] == 0;
}

- (BOOL)isEqual:(id)object {
  if (![(NSObject *)object isKindOfClass:[MSACEventProperties class]]) {
    return NO;
  }
  MSACEventProperties *properties = (MSACEventProperties *)object;
  return ((!self.properties && !properties.properties) || [self.properties isEqualToDictionary:properties.properties]);
}

#pragma mark - Helper methods

+ (BOOL)validateKey:(NSString *)key {
  if (!key) {
    MSACLogError([MSACAnalytics logTag], @"Key cannot be null. Property will not be added.");
    return NO;
  }
  return YES;
}

+ (BOOL)validateValue:(NSObject *)value {
  if (!value) {
    MSACLogError([MSACAnalytics logTag], @"Value cannot be null. Property will not be added.");
    return NO;
  }
  return YES;
}

- (void)mergeEventProperties:(MSACEventProperties *__nonnull)eventProperties {
  [self.properties addEntriesFromDictionary:(NSDictionary<NSString *, MSACTypedProperty *> *)eventProperties.properties];
}

@end
