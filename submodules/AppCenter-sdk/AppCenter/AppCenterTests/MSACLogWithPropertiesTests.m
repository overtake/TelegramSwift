// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAbstractLogInternal.h"
#import "MSACLogWithProperties.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACLogWithPropertiesTests : XCTestCase

@property(nonatomic) MSACLogWithProperties *sut;

@end

@implementation MSACLogWithPropertiesTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.sut = [MSACLogWithProperties new];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Tests

- (void)testSerializingDeviceToDictionaryWorks {

  // If
  NSDictionary *properties = @{@"key1" : @"value1", @"key2" : @"value"};
  self.sut.properties = properties;

  // When
  NSMutableDictionary *actual = [self.sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"properties"], equalTo(properties));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  NSDictionary *properties = @{@"key1" : @"value1", @"key2" : @"value"};
  self.sut.properties = properties;

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACLogWithProperties class]));

  MSACLogWithProperties *actualLogWithProperties = actual;
  assertThat(actualLogWithProperties.properties, equalTo(properties));
}

- (void)testIsEqual {

  // If
  NSDictionary *properties = @{@"key1" : @"value1", @"key2" : @"value"};
  self.sut.properties = properties;

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];
  MSACLogWithProperties *actualLogWithProperties = actual;

  // then
  XCTAssertTrue([self.sut.properties isEqual:actualLogWithProperties.properties]);
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([self.sut isEqual:nil]);
}

@end
