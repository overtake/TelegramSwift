// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACLongTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACLongTypedPropertyTests : XCTestCase

@end

@implementation MSACLongTypedPropertyTests

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACLongTypedProperty *sut = [MSACLongTypedProperty new];
  sut.type = @"type";
  sut.name = @"name";
  sut.value = 12;

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACLongTypedProperty *actual = (MSACLongTypedProperty *)[MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACLongTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, sut.name);
  XCTAssertEqualObjects(actual.type, sut.type);
  XCTAssertEqual(actual.value, sut.value);
}

- (void)testSerializeToDictionary {

  // If
  MSACLongTypedProperty *sut = [MSACLongTypedProperty new];
  sut.name = @"propertyName";
  sut.value = 12;

  // When
  NSDictionary *dictionary = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(dictionary[@"type"], sut.type);
  XCTAssertEqualObjects(dictionary[@"name"], sut.name);
  XCTAssertEqual([dictionary[@"value"] longLongValue], sut.value);
}

- (void)testPropertyTypeIsCorrectWhenPropertyIsInitialized {

  // If
  MSACLongTypedProperty *sut = [MSACLongTypedProperty new];

  // Then
  XCTAssertEqualObjects(sut.type, @"long");
}

@end
