// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACBooleanTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACTypedPropertyTests : XCTestCase

@end

@implementation MSACTypedPropertyTests

- (void)testNSCodingSerializationAndDeserialization {

  // If
  NSString *propertyType = @"propertyType";
  NSString *propertyName = @"propertyName";
  MSACTypedProperty *sut = [MSACTypedProperty new];
  sut.type = propertyType;
  sut.name = propertyName;

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACTypedProperty *actual = (MSACTypedProperty *)[MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, propertyName);
  XCTAssertEqualObjects(actual.type, propertyType);
}

- (void)testSerializingTypedPropertyToDictionary {

  // If
  NSString *propertyType = @"propertyType";
  NSString *propertyName = @"propertyName";
  MSACTypedProperty *sut = [MSACTypedProperty new];
  sut.type = propertyType;
  sut.name = propertyName;

  // When
  NSMutableDictionary *actual = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(actual[@"type"], sut.type);
  XCTAssertEqualObjects(actual[@"name"], sut.name);
}

@end
