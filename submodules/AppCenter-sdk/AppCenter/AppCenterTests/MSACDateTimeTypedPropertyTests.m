// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDateTimeTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+Date.h"

@interface MSACDateTimeTypedPropertyTests : XCTestCase

@end

@implementation MSACDateTimeTypedPropertyTests

- (void)testNSCodingSerializationAndDeserialization {

  // If
  MSACDateTimeTypedProperty *sut = [MSACDateTimeTypedProperty new];
  sut.type = @"type";
  sut.name = @"name";
  sut.value = [NSDate dateWithTimeIntervalSince1970:100000];

  // When
  NSData *serializedProperty = [MSACUtility archiveKeyedData:sut];
  MSACDateTimeTypedProperty *actual = (MSACDateTimeTypedProperty *)[MSACUtility unarchiveKeyedData:serializedProperty];

  // Then
  XCTAssertNotNil(actual);
  XCTAssertTrue([actual isKindOfClass:[MSACDateTimeTypedProperty class]]);
  XCTAssertEqualObjects(actual.name, sut.name);
  XCTAssertEqualObjects(actual.type, sut.type);
  XCTAssertEqualObjects(actual.value, sut.value);
}

- (void)testSerializeToDictionary {

  // If
  MSACDateTimeTypedProperty *sut = [MSACDateTimeTypedProperty new];
  sut.name = @"propertyName";
  sut.value = [NSDate dateWithTimeIntervalSince1970:100000];

  // When
  NSDictionary *dictionary = [sut serializeToDictionary];

  // Then
  XCTAssertEqualObjects(dictionary[@"type"], sut.type);
  XCTAssertEqualObjects(dictionary[@"name"], sut.name);
  XCTAssertTrue([dictionary[@"value"] isKindOfClass:[NSString class]]);
  XCTAssertEqualObjects(dictionary[@"value"], [MSACUtility dateToISO8601:sut.value]);
}

- (void)testPropertyTypeIsCorrectWhenPropertyIsInitialized {

  // If
  MSACDateTimeTypedProperty *sut = [MSACDateTimeTypedProperty new];

  // Then
  XCTAssertEqualObjects(sut.type, @"dateTime");
}

@end
