// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACOrderedDictionaryPrivate.h"
#import "MSACTestFrameworks.h"

@interface MSACOrderedDictionaryTests : XCTestCase

@property(nonatomic) MSACOrderedDictionary *sut;

@end

@implementation MSACOrderedDictionaryTests

- (void)setUp {
  [super setUp];

  self.sut = [MSACOrderedDictionary new];
}

- (void)tearDown {
  [super tearDown];

  [self.sut removeAllObjects];
}

- (void)testInitWithCapacity {

  // When
  self.sut = [[MSACOrderedDictionary alloc] initWithCapacity:10];

  // Then
  XCTAssertNotNil(self.sut.order);
  XCTAssertNotNil(self.sut);
}

- (void)testCount {

  // When
  [self.sut setObject:@"value1" forKey:@"key1"];
  [self.sut setObject:@"value2" forKey:@"key2"];

  // Then
  XCTAssertTrue(self.sut.count == 2);
}

- (void)testRemoveAll {

  // If
  [self.sut setObject:@"value1" forKey:@"key1"];
  [self.sut setObject:@"value2" forKey:@"key2"];

  // When
  [self.sut removeAllObjects];

  // Then
  XCTAssertTrue(self.sut.count == 0);
}

- (void)testAddingOrderedObjects {

  // When
  [self.sut setObject:@"value1" forKey:@"key1"];
  [self.sut setObject:@"value2" forKey:@"key2"];

  // Then
  NSEnumerator *keyEnumerator = [self.sut keyEnumerator];
  XCTAssertTrue(self.sut.count == 2);
  XCTAssertTrue([[keyEnumerator nextObject] isEqualToString:@"key1"]);
  XCTAssertTrue([[keyEnumerator nextObject] isEqualToString:@"key2"]);
  XCTAssertNil([keyEnumerator nextObject]);
  XCTAssertEqual([self.sut objectForKey:@"key1"], @"value1");
  XCTAssertEqual([self.sut objectForKey:@"key2"], @"value2");
}

- (void)testEmptyDictionariesAreEqual {

  // If
  MSACOrderedDictionary *other = [MSACOrderedDictionary new];

  // Then
  XCTAssertTrue([self.sut isEqualToDictionary:other]);
}

- (void)testDifferentLengthDictionariesNotEqual {

  // If
  MSACOrderedDictionary *other = [MSACOrderedDictionary new];
  [other setObject:@"value" forKey:@"key"];

  // Then
  XCTAssertFalse([self.sut isEqualToDictionary:other]);
}

- (void)testDifferentKeyOrdersNotEqual {

  // If
  MSACOrderedDictionary *other = [MSACOrderedDictionary new];
  [other setObject:@"value1" forKey:@"key1"];
  [other setObject:@"value2" forKey:@"key2"];

  // When
  [self.sut setObject:@"value2" forKey:@"key2"];
  [self.sut setObject:@"value1" forKey:@"key1"];

  // Then
  XCTAssertFalse([self.sut isEqualToDictionary:other]);
}

- (void)testDifferentValuesForKeysNotEqual {

  // If
  MSACOrderedDictionary *other = [MSACOrderedDictionary new];
  [other setObject:@"value1" forKey:@"key1"];
  [other setObject:@"value2" forKey:@"key2"];

  // When
  [self.sut setObject:@"value1" forKey:@"key2"];
  [self.sut setObject:@"value2" forKey:@"key1"];

  // Then
  XCTAssertFalse([self.sut isEqualToDictionary:other]);
}

- (void)testEqualDictionaries {

  // If
  MSACOrderedDictionary *other = [MSACOrderedDictionary new];
  [other setObject:@"value1" forKey:@"key1"];
  [other setObject:@"value2" forKey:@"key2"];

  // When
  [self.sut setObject:@"value1" forKey:@"key1"];
  [self.sut setObject:@"value2" forKey:@"key2"];

  // Then
  XCTAssertTrue([self.sut isEqualToDictionary:other]);
}

- (void)testCopiedDictionariesEqual {

  // When
  [self.sut setObject:@"value1" forKey:@"key1"];
  [self.sut setObject:@"value2" forKey:@"key2"];
  MSACOrderedDictionary *other = [self.sut mutableCopy];

  // Then
  XCTAssertTrue([self.sut isEqualToDictionary:other]);
}

@end
