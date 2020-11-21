// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACStartServiceLog.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACStartServiceLogTests : XCTestCase

@property(nonatomic, strong) MSACStartServiceLog *sut;

@end

@implementation MSACStartServiceLogTests

@synthesize sut = _sut;

#pragma mark - Setup

- (void)setUp {
  [super setUp];
  self.sut = [MSACStartServiceLog new];
}

#pragma mark - Tests

- (void)testSerializingEventToDictionaryWorks {

  // If
  NSArray<NSString *> *services = @[ @"Service0", @"Service1", @"Service2" ];
  self.sut.services = services;

  // When
  NSMutableDictionary *actual = [self.sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  NSArray *actualServices = actual[@"services"];
  XCTAssertEqual(actualServices.count, services.count);
  for (NSUInteger i = 0; i < actualServices.count; ++i) {
    assertThat(actualServices[i], equalTo(services[i]));
  }
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  NSArray<NSString *> *services = @[ @"Service0", @"Service1", @"Service2" ];
  self.sut.services = services;

  // When
  NSData *serializedLog = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedLog];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACStartServiceLog class]));
  XCTAssertTrue([actual isEqual:self.sut]);

  MSACStartServiceLog *log = actual;
  NSArray *actualServices = log.services;
  XCTAssertEqual(actualServices.count, services.count);
  for (NSUInteger i = 0; i < actualServices.count; ++i) {
    assertThat(actualServices[i], equalTo(services[i]));
  }
}

- (void)testIsNotEqual {

  // Then
  XCTAssertFalse([self.sut isEqual:[MSACAbstractLog new]]);
}

@end
