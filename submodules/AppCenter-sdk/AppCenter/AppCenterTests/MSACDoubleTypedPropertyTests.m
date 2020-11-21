// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDoubleTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACDoubleTypedPropertyTests : XCTestCase

@end

@implementation MSACDoubleTypedPropertyTests

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACDoubleTypedProperty *sut = [MSACDoubleTypedProperty new];
  sut.type = @"type";
  sut.name = @"name";
  sut.value = 12.23432;

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACDoubleTypedProperty *actual = (MSACDoubleTypedProperty *)[MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACDoubleTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, sut.name);
  XCTAssertEqualObjects(actual.type, sut.type);
  XCTAssertEqual(actual.value, sut.value);
}

- (void)testSerializeToDictionary {

  // If
  MSACDoubleTypedProperty *sut = [MSACDoubleTypedProperty new];
  sut.name = @"propertyName";
  sut.value = 0.123;

  // When
  NSDictionary *dictionary = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(dictionary[@"type"], sut.type);
  XCTAssertEqualObjects(dictionary[@"name"], sut.name);
  XCTAssertEqual([dictionary[@"value"] doubleValue], sut.value);
}

- (void)testPropertyTypeIsCorrectWhenPropertyIsInitialized {

  // If
  MSACDoubleTypedProperty *sut = [MSACDoubleTypedProperty new];

  // Then
  XCTAssertEqualObjects(sut.type, @"double");
}

@end
