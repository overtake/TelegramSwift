// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDevice.h"
#import "MSACDeviceHistoryInfo.h"
#import "MSACTestFrameworks.h"

@interface MSACDeviceHistoryInfoTests : XCTestCase

@end

@implementation MSACDeviceHistoryInfoTests

- (void)testCreationWorks {

  // When
  MSACDeviceHistoryInfo *expected = [MSACDeviceHistoryInfo new];

  // Then
  XCTAssertNotNil(expected);

  // When
  NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:42];
  MSACDevice *aDevice = [MSACDevice new];
  expected = [[MSACDeviceHistoryInfo alloc] initWithTimestamp:timestamp andDevice:aDevice];

  // Then
  XCTAssertNotNil(expected);
  XCTAssertTrue([expected.timestamp isEqual:timestamp]);
  XCTAssertTrue([expected.device isEqual:aDevice]);
}

@end
