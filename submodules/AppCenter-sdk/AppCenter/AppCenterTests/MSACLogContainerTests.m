// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "MSACAbstractLogInternal.h"
#import "MSACLogContainer.h"
#import "MSACTestFrameworks.h"

@interface MSACLogContainerTests : XCTestCase

@end

@implementation MSACLogContainerTests

- (void)testLogContainerSerialization {

  // If
  MSACLogContainer *logContainer = [MSACLogContainer new];

  MSACAbstractLog *log1 = [MSACAbstractLog new];
  log1.sid = MSAC_UUID_STRING;
  log1.timestamp = [NSDate date];

  MSACAbstractLog *log2 = [MSACAbstractLog new];
  log2.sid = MSAC_UUID_STRING;
  log2.timestamp = [NSDate date];

  logContainer.logs = (NSArray<id<MSACLog>> *)@[ log1, log2 ];

  // When
  NSString *jsonString = [logContainer serializeLog];

  // Then
  XCTAssertTrue([jsonString length] > 0);
}

- (void)testIsValidForEmptyLogs {

  // If
  MSACLogContainer *logContainer = [MSACLogContainer new];

  XCTAssertFalse([logContainer isValid]);
}

@end
