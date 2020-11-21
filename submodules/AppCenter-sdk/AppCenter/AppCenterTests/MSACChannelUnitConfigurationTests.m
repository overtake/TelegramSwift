// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACChannelUnitConfiguration.h"
#import "MSACTestFrameworks.h"

@interface MSACChannelUnitConfigurationTests : XCTestCase

@end

@implementation MSACChannelUnitConfigurationTests

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // If
  NSString *groupId = @"FooBar";
  MSACPriority priority = MSACPriorityDefault;
  NSUInteger batchSizeLimit = 10;
  NSUInteger pendingBatchesLimit = 20;
  NSUInteger flushInterval = 9;

  // When
  MSACChannelUnitConfiguration *sut = [[MSACChannelUnitConfiguration alloc] initWithGroupId:groupId
                                                                                   priority:priority
                                                                              flushInterval:flushInterval
                                                                             batchSizeLimit:batchSizeLimit
                                                                        pendingBatchesLimit:pendingBatchesLimit];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.groupId, equalTo(groupId));
  XCTAssertTrue(sut.priority == priority);
  assertThatUnsignedInteger(sut.batchSizeLimit, equalToUnsignedInteger(batchSizeLimit));
  assertThatUnsignedInteger(sut.pendingBatchesLimit, equalToUnsignedInteger(pendingBatchesLimit));
  assertThatUnsignedInteger(sut.flushInterval, equalToUnsignedInteger(flushInterval));
}

- (void)testNewInstanceWithDefaultSettings {

  // If
  NSString *groupId = @"FooBar";

  // When
  MSACChannelUnitConfiguration *sut = [[MSACChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:groupId];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.groupId, equalTo(groupId));
  XCTAssertTrue(sut.priority == MSACPriorityDefault);
  assertThatUnsignedInteger(sut.batchSizeLimit, equalToUnsignedInteger(50));
  assertThatUnsignedInteger(sut.pendingBatchesLimit, equalToUnsignedInteger(3));
  assertThatUnsignedInteger(sut.flushInterval, equalToUnsignedInteger(3));
}

@end
