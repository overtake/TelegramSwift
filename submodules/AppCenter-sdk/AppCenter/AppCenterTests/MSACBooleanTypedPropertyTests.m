// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACBooleanTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACBooleanTypedPropertyTests : XCTestCase

@end

@implementation MSACBooleanTypedPropertyTests

- (void)testSerializeToDictionary {

  // If
  MSACBooleanTypedProperty *sut = [MSACBooleanTypedProperty new];
  sut.name = @"propertyName";
  sut.value = YES;

  // When
  NSDictionary *dictionary = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(dictionary[@"type"], sut.type);
  XCTAssertEqualObjects(dictionary[@"name"], sut.name);
  XCTAssertEqual([dictionary[@"value"] boolValue], sut.value);
}

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACBooleanTypedProperty *sut = [MSACBooleanTypedProperty new];
  sut.type = @"type";
  sut.name = @"name";
  sut.value = YES;

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACBooleanTypedProperty *actual = [MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACBooleanTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, sut.name);
  XCTAssertEqualObjects(actual.type, sut.type);
  XCTAssertEqual(actual.value, sut.value);
}

- (void)testPropertyTypeIsCorrectWhenPropertyIsInitialized {

  // If
  MSACBooleanTypedProperty *sut = [MSACBooleanTypedProperty new];

  // Then
  XCTAssertEqualObjects(sut.type, @"boolean");
}

@end
