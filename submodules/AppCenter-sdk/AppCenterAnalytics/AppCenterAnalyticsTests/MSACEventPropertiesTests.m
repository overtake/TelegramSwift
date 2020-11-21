// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACBooleanTypedProperty.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventProperties.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACStringTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+Date.h"
#import "MSACUtility.h"

@interface MSACEventPropertiesTests : XCTestCase

@end

@implementation MSACEventPropertiesTests

- (void)testInitWithStringDictionaryWhenStringDictionaryHasValues {

  // If
  NSDictionary *stringProperties = @{@"key1" : @"val1", @"key2" : @"val2"};

  // When
  MSACEventProperties *sut = [[MSACEventProperties alloc] initWithStringDictionary:stringProperties];

  // Then
  XCTAssertEqual([sut.properties count], 2);
  for (NSString *propertyKey in stringProperties) {
    XCTAssertTrue([sut.properties[propertyKey] isKindOfClass:[MSACStringTypedProperty class]]);
    XCTAssertEqualObjects(stringProperties[propertyKey], ((MSACStringTypedProperty *)sut.properties[propertyKey]).value);
    XCTAssertEqualObjects(propertyKey, sut.properties[propertyKey].name);
  }
}

- (void)testSetBoolForKey {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  BOOL value = YES;
  NSString *key = @"key";

  // When
  [sut setBool:value forKey:key];

  // Then
  MSACBooleanTypedProperty *property = (MSACBooleanTypedProperty *)sut.properties[key];
  XCTAssertEqual(property.name, key);
  XCTAssertEqual(property.value, value);
}

- (void)testSetInt64ForKey {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  int64_t value = 10;
  NSString *key = @"key";

  // When
  [sut setInt64:value forKey:key];

  // Then
  MSACLongTypedProperty *property = (MSACLongTypedProperty *)sut.properties[key];
  XCTAssertEqual(property.name, key);
  XCTAssertEqual(property.value, value);
}

- (void)testSetDoubleForKey {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  double value = 10.43e3;
  NSString *key = @"key";

  // When
  [sut setDouble:value forKey:key];

  // Then
  MSACDoubleTypedProperty *property = (MSACDoubleTypedProperty *)sut.properties[key];
  XCTAssertEqual(property.name, key);
  XCTAssertEqual(property.value, value);
}

- (void)testSetDoubleForKeyWhenValueIsInfinity {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];

  // When
  [sut setDouble:INFINITY forKey:@"key"];

  // Then
  XCTAssertEqual([sut.properties count], 0);

  // When
  [sut setDouble:-INFINITY forKey:@"key"];

  // Then
  XCTAssertEqual([sut.properties count], 0);
}

- (void)testSetDoubleForKeyWhenValueIsNaN {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];

  // When
  [sut setDouble:NAN forKey:@"key"];

  // Then
  XCTAssertEqual([sut.properties count], 0);
}

- (void)testSetStringForKey {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  NSString *value = @"value";
  NSString *key = @"key";

  // When
  [sut setString:value forKey:key];

  // Then
  MSACStringTypedProperty *property = (MSACStringTypedProperty *)sut.properties[key];
  XCTAssertEqual(property.name, key);
  XCTAssertEqual(property.value, value);
}

- (void)testSetDateForKey {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  NSDate *value = [NSDate new];
  NSString *key = @"key";

  // When
  [sut setDate:value forKey:key];

  // Then
  MSACDateTimeTypedProperty *property = (MSACDateTimeTypedProperty *)sut.properties[key];
  XCTAssertEqual(property.name, key);
  XCTAssertEqual(property.value, value);
}

- (void)testSerializeToArray {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  MSACTypedProperty *property = OCMPartialMock([MSACTypedProperty new]);
  NSDictionary *serializedProperty = [NSDictionary new];
  OCMStub([property serializeToDictionary]).andReturn(serializedProperty);
  NSString *propertyKey = @"key";
  sut.properties[propertyKey] = property;

  // When
  NSArray *propertiesArray = [sut serializeToArray];

  // Then
  XCTAssertEqual([propertiesArray count], 1);
  XCTAssertEqualObjects(propertiesArray[0], serializedProperty);
}

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  [sut setString:@"stringVal" forKey:@"stringKey"];
  [sut setBool:YES forKey:@"boolKey"];
  [sut setDouble:1.4 forKey:@"doubleKey"];
  [sut setInt64:8589934592ll forKey:@"intKey"];
  [sut setDate:[NSDate new] forKey:@"dateKey"];

  // When
  NSData *serializedSut = [MSACUtility archiveKeyedData:sut];
  MSACEventProperties *deserializedSut = (MSACEventProperties *)[MSACUtility unarchiveKeyedData:serializedSut];

  // Then
  XCTAssertNotNil(deserializedSut);
  XCTAssertTrue([deserializedSut isKindOfClass:[MSACEventProperties class]]);
  for (NSString *key in sut.properties) {
    MSACTypedProperty *sutProperty = sut.properties[key];
    MSACTypedProperty *deserializedSutProperty = deserializedSut.properties[key];
    XCTAssertEqualObjects(sutProperty.name, deserializedSutProperty.name);
    XCTAssertEqualObjects(sutProperty.type, deserializedSutProperty.type);
    if ([deserializedSutProperty isKindOfClass:[MSACStringTypedProperty class]]) {
      MSACStringTypedProperty *deserializedProperty = (MSACStringTypedProperty *)deserializedSutProperty;
      MSACStringTypedProperty *originalProperty = (MSACStringTypedProperty *)sutProperty;
      XCTAssertEqualObjects(originalProperty.value, deserializedProperty.value);
    } else if ([deserializedSutProperty isKindOfClass:[MSACBooleanTypedProperty class]]) {
      MSACBooleanTypedProperty *deserializedProperty = (MSACBooleanTypedProperty *)deserializedSutProperty;
      MSACBooleanTypedProperty *originalProperty = (MSACBooleanTypedProperty *)sutProperty;
      XCTAssertEqual(originalProperty.value, deserializedProperty.value);
    } else if ([deserializedSutProperty isKindOfClass:[MSACLongTypedProperty class]]) {
      MSACLongTypedProperty *deserializedProperty = (MSACLongTypedProperty *)deserializedSutProperty;
      MSACLongTypedProperty *originalProperty = (MSACLongTypedProperty *)sutProperty;
      XCTAssertEqual(originalProperty.value, deserializedProperty.value);
    } else if ([deserializedSutProperty isKindOfClass:[MSACDoubleTypedProperty class]]) {
      MSACDoubleTypedProperty *deserializedProperty = (MSACDoubleTypedProperty *)deserializedSutProperty;
      MSACDoubleTypedProperty *originalProperty = (MSACDoubleTypedProperty *)sutProperty;
      XCTAssertEqual(originalProperty.value, deserializedProperty.value);
    } else if ([deserializedSutProperty isKindOfClass:[MSACDateTimeTypedProperty class]]) {
      MSACDateTimeTypedProperty *deserializedProperty = (MSACDateTimeTypedProperty *)deserializedSutProperty;
      MSACDateTimeTypedProperty *originalProperty = (MSACDateTimeTypedProperty *)sutProperty;
      NSString *originalDateString = [MSACUtility dateToISO8601:originalProperty.value];
      NSString *deserializedDateString = [MSACUtility dateToISO8601:deserializedProperty.value];
      XCTAssertEqualObjects(originalDateString, deserializedDateString);
    }
  }
}

- (void)testIsEmptyReturnsTrueWhenContainsNoProperties {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];

  // When
  BOOL isEmpty = [sut isEmpty];

  // Then
  XCTAssertTrue(isEmpty);
}

- (void)testIsNoWhenEqualsWrongClass {

  // If
  NSObject *invalidEvent = [NSObject new];

  // When
  BOOL result = [MSACEventProperties isEqual:invalidEvent];

  // Then
  XCTAssertFalse(result);
}

- (void)testIsEmptyReturnsFalseWhenContainsProperties {

  // If
  MSACEventProperties *sut = [MSACEventProperties new];
  [sut setBool:YES forKey:@"key"];

  // When
  BOOL isEmpty = [sut isEmpty];

  // Then
  XCTAssertFalse(isEmpty);
}

@end
