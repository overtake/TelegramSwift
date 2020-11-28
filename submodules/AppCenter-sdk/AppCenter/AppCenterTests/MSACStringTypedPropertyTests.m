// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACStringTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACStringTypedPropertyTests : XCTestCase

@end

@implementation MSACStringTypedPropertyTests

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACStringTypedProperty *sut = [MSACStringTypedProperty new];
  sut.type = @"type";
  sut.name = @"name";
  sut.value = @"value";

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACStringTypedProperty *actual = (MSACStringTypedProperty *)[MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACStringTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, sut.name);
  XCTAssertEqualObjects(actual.type, sut.type);
  XCTAssertEqualObjects(actual.value, sut.value);
}

- (void)testSerializeToDictionary {

  // If
  MSACStringTypedProperty *sut = [MSACStringTypedProperty new];
  sut.name = @"propertyName";
  sut.value = @"value";

  // When
  NSDictionary *dictionary = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(dictionary[@"type"], sut.type);
  XCTAssertEqualObjects(dictionary[@"name"], sut.name);
  XCTAssertEqualObjects(dictionary[@"value"], sut.value);
}

- (void)testPropertyTypeIsCorrectWhenPropertyIsInitialized {

  // If
  MSACStringTypedProperty *sut = [MSACStringTypedProperty new];

  // Then
  XCTAssertEqualObjects(sut.type, @"string");
}

@end
