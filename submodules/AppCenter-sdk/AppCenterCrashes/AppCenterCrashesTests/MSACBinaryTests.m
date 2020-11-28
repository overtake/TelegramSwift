// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACBinary.h"
#import "MSACTestFrameworks.h"

@interface MSACBinaryTests : XCTestCase

@end

@implementation MSACBinaryTests

#pragma mark - Tests

- (void)testSerializingBinaryToDictionaryWorks {

  // If
  MSACBinary *sut = [self binary];

  // When
  NSMutableDictionary *actual = [sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"id"], equalTo(sut.binaryId));
  assertThat(actual[@"startAddress"], equalTo(sut.startAddress));
  assertThat(actual[@"endAddress"], equalTo(sut.endAddress));
  assertThat(actual[@"name"], equalTo(sut.name));
  assertThat(actual[@"path"], equalTo(sut.path));
  assertThat(actual[@"architecture"], equalTo(sut.architecture));
  assertThat(actual[@"primaryArchitectureId"], equalTo(sut.primaryArchitectureId));
  assertThat(actual[@"architectureVariantId"], equalTo(sut.architectureVariantId));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  MSACBinary *sut = [self binary];

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACBinary class]));

  MSACBinary *actualBinary = actual;
  assertThat(actualBinary, equalTo(actual));
  assertThat(actualBinary.binaryId, equalTo(sut.binaryId));
  assertThat(actualBinary.startAddress, equalTo(sut.startAddress));
  assertThat(actualBinary.endAddress, equalTo(sut.endAddress));
  assertThat(actualBinary.name, equalTo(sut.name));
  assertThat(actualBinary.path, equalTo(sut.path));
  assertThat(actualBinary.architecture, equalTo(sut.architecture));
  assertThat(actualBinary.primaryArchitectureId, equalTo(sut.primaryArchitectureId));
  assertThat(actualBinary.architectureVariantId, equalTo(sut.architectureVariantId));
}

- (void)testIsValid {

  // If
  MSACBinary *sut = [MSACBinary new];

  // Then
  XCTAssertFalse([sut isValid]);

  // When
  sut.binaryId = @"binaryId";

  // Then
  XCTAssertFalse([sut isValid]);

  // When
  sut.startAddress = @"startAddress";

  // Then
  XCTAssertFalse([sut isValid]);

  // When
  sut.endAddress = @"endAddress";

  // Then
  XCTAssertFalse([sut isValid]);

  // When
  sut.name = @"name";

  // Then
  XCTAssertFalse([sut isValid]);

  // When
  sut.path = @"path";

  // Then
  XCTAssertTrue([sut isValid]);
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([[MSACBinary new] isEqual:nil]);
}

#pragma mark - Helper

- (MSACBinary *)binary {
  MSACBinary *binary = [MSACBinary new];
  binary.binaryId = @"binaryId";
  binary.startAddress = @"startAddress";
  binary.endAddress = @"endAddress";
  binary.name = @"name";
  binary.path = @"path";
  binary.architecture = @"architecture";
  binary.primaryArchitectureId = @12;
  binary.architectureVariantId = @23;

  return binary;
}

@end
