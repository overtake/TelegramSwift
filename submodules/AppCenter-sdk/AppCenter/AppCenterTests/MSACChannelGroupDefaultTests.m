// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAbstractLogInternal.h"
#import "MSACAppCenterIngestion.h"
#import "MSACChannelDelegate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACChannelGroupDefaultPrivate.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitDefault.h"
#import "MSACChannelUnitDefaultPrivate.h"
#import "MSACHttpClient.h"
#import "MSACHttpTestUtil.h"
#import "MSACHttpUtil.h"
#import "MSACIngestionProtocol.h"
#import "MSACMockLog.h"
#import "MSACStorage.h"
#import "MSACTestFrameworks.h"

@interface MSACChannelGroupDefaultTests : XCTestCase

@property(nonatomic) id ingestionMock;

@property(nonatomic) MSACChannelUnitConfiguration *validConfiguration;

@property(nonatomic) MSACChannelGroupDefault *sut;

@end

@implementation MSACChannelGroupDefaultTests

- (void)setUp {
  NSString *groupId = @"AppCenter";
  MSACPriority priority = MSACPriorityDefault;
  NSUInteger flushInterval = 3;
  NSUInteger batchSizeLimit = 10;
  NSUInteger pendingBatchesLimit = 3;
  self.ingestionMock = OCMClassMock([MSACAppCenterIngestion class]);
  self.validConfiguration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:groupId
                                                                         priority:priority
                                                                    flushInterval:flushInterval
                                                                   batchSizeLimit:batchSizeLimit
                                                              pendingBatchesLimit:pendingBatchesLimit];
  self.sut = [[MSACChannelGroupDefault alloc] initWithIngestion:self.ingestionMock];

  /*
   * dispatch_get_main_queue isn't good option for logsDispatchQueue because
   * we can't clear pending actions from it after the test. It can cause usages of stopped mocks.
   *
   * Keep the serial queue that created during the initialization.
   */
}

- (void)tearDown {
  __weak dispatch_object_t dispatchQueue = self.sut.logsDispatchQueue;
  self.sut = nil;
  XCTAssertNil(dispatchQueue);

  // Stop mocks.
  [self.ingestionMock stopMocking];
  [super tearDown];
}

#if !TARGET_OS_OSX
- (void)testAppIsKilled {

  // If
  [self.sut setEnabled:YES andDeleteDataOnDisabled:YES];
  id sut = OCMPartialMock(self.sut);

  // When
  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification object:sut];

  // Then
  OCMVerify([sut applicationWillTerminate:OCMOCK_ANY]);
  XCTAssertNotNil(self.sut.logsDispatchQueue);

  // If
  [self.sut setEnabled:NO andDeleteDataOnDisabled:YES];
  OCMReject([sut applicationWillTerminate:OCMOCK_ANY]);

  // When
  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification object:sut];

  // Then
  self.sut.logsDispatchQueue = nil;
  OCMVerifyAll(sut);
  [sut stopMocking];
}
#endif

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // Then
  assertThat(self.sut, notNilValue());
  assertThat(self.sut.logsDispatchQueue, notNilValue());
  assertThat(self.sut.channels, isEmpty());
  assertThat(self.sut.ingestion, equalTo(self.ingestionMock));
  assertThat(self.sut.storage, notNilValue());
}

- (void)testAddNewChannel {

  // Then
  assertThat(self.sut.channels, isEmpty());

  // When
  id<MSACChannelUnitProtocol> addedChannel = [self.sut addChannelUnitWithConfiguration:self.validConfiguration];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  XCTAssertTrue([self.sut.channels containsObject:addedChannel]);
  assertThat(addedChannel, notNilValue());
  XCTAssertTrue(addedChannel.configuration.priority == self.validConfiguration.priority);
  assertThatFloat(addedChannel.configuration.flushInterval, equalToFloat(self.validConfiguration.flushInterval));
  assertThatUnsignedLong(addedChannel.configuration.batchSizeLimit, equalToUnsignedLong(self.validConfiguration.batchSizeLimit));
  assertThatUnsignedLong(addedChannel.configuration.pendingBatchesLimit, equalToUnsignedLong(self.validConfiguration.pendingBatchesLimit));
}

- (void)testAddNewChannelWithDefaultIngestion {

  // When
  MSACChannelUnitDefault *channelUnit = (MSACChannelUnitDefault *)[self.sut addChannelUnitWithConfiguration:self.validConfiguration];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  XCTAssertEqual(self.ingestionMock, channelUnit.ingestion);
}

- (void)testAddChannelWithCustomIngestion {

  // If, We can't use class mock of MSACAppCenterIngestion because it is already class-mocked in setUp.
  // Using more than one class mock is not supported.
  MSACAppCenterIngestion *newIngestion = [MSACAppCenterIngestion new];

  // When
  MSACChannelUnitDefault *channelUnit =
      (MSACChannelUnitDefault *)[self.sut addChannelUnitWithConfiguration:[MSACChannelUnitConfiguration new] withIngestion:newIngestion];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  XCTAssertNotEqual(self.ingestionMock, channelUnit.ingestion);
  XCTAssertEqual(newIngestion, channelUnit.ingestion);
}

- (void)testDelegatesConcurrentAccess {

  // If
  MSACAbstractLog *log = [MSACAbstractLog new];
  for (int j = 0; j < 10; j++) {
    id mockDelegate = OCMProtocolMock(@protocol(MSACChannelDelegate));
    [self.sut addDelegate:mockDelegate];
  }
  id<MSACChannelUnitProtocol> addedChannel = [self.sut addChannelUnitWithConfiguration:self.validConfiguration];

  // When
  void (^block)(void) = ^{
    for (int i = 0; i < 10; i++) {
      [addedChannel enqueueItem:log flags:MSACFlagsDefault];
    }
    for (int i = 0; i < 100; i++) {
      [self.sut addDelegate:OCMProtocolMock(@protocol(MSACChannelDelegate))];
    }
  };

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  XCTAssertNoThrow(block());
}

- (void)testSetEnabled {

  // If
  id<MSACChannelUnitProtocol> channelMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelDelegate> delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];
  [self.sut.channels addObject:channelMock];

  // When
  [self.sut setEnabled:NO andDeleteDataOnDisabled:YES];

  // Then
  OCMVerify([self.ingestionMock setEnabled:NO andDeleteDataOnDisabled:YES]);
  OCMVerify([channelMock setEnabled:NO andDeleteDataOnDisabled:YES]);
  OCMVerify([delegateMock channel:self.sut didSetEnabled:NO andDeleteDataOnDisabled:YES]);
}

- (void)testResume {

  // If
  id<MSACChannelUnitProtocol> channelMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  [self.sut.channels addObject:channelMock];
  NSObject *token = [NSObject new];

  // When
  [self.sut resumeWithIdentifyingObject:token];

  // Then
  OCMVerify([self.ingestionMock setEnabled:YES andDeleteDataOnDisabled:NO]);
  OCMVerify([channelMock resumeWithIdentifyingObject:token]);
}

- (void)testPause {

  // If
  id<MSACChannelUnitProtocol> channelMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  [self.sut.channels addObject:channelMock];
  NSObject *identifyingObject = [NSObject new];

  // When
  [self.sut pauseWithIdentifyingObject:identifyingObject];

  // Then
  OCMVerify([self.ingestionMock setEnabled:NO andDeleteDataOnDisabled:NO]);
  OCMVerify([channelMock pauseWithIdentifyingObject:identifyingObject]);
}

- (void)testChannelUnitIsCorrectlyInitialized {

  // If
  id channelUnitMock = OCMClassMock([MSACChannelUnitDefault class]);
  OCMStub([channelUnitMock alloc]).andReturn(channelUnitMock);
  OCMStub([channelUnitMock initWithIngestion:OCMOCK_ANY storage:OCMOCK_ANY configuration:OCMOCK_ANY logsDispatchQueue:OCMOCK_ANY])
      .andReturn(channelUnitMock);

  // When
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([channelUnitMock addDelegate:(id<MSACChannelDelegate>)self.sut]);
  OCMVerify([channelUnitMock checkPendingLogs]);

  // Clear
  [channelUnitMock stopMocking];
}

- (void)testDelegateCalledWhenAddingNewChannelUnit {

  // Test that delegates are called whenever a new channel unit is added to the
  // channel group.

  // If
  id channelUnitMock = OCMClassMock([MSACChannelUnitDefault class]);
  OCMStub([channelUnitMock alloc]).andReturn(channelUnitMock);
  OCMStub([channelUnitMock initWithIngestion:OCMOCK_ANY storage:OCMOCK_ANY configuration:OCMOCK_ANY logsDispatchQueue:OCMOCK_ANY])
      .andReturn(channelUnitMock);
  id delegateMock1 = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMExpect([delegateMock1 channelGroup:self.sut didAddChannelUnit:channelUnitMock]);
  id delegateMock2 = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMExpect([delegateMock2 channelGroup:self.sut didAddChannelUnit:channelUnitMock]);
  [self.sut addDelegate:delegateMock1];
  [self.sut addDelegate:delegateMock2];

  // When
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerifyAll(delegateMock1);
  OCMVerifyAll(delegateMock2);

  // Clear
  [channelUnitMock stopMocking];
}

- (void)testDelegateCalledWhenChannelUnitPaused {

  // If
  NSObject *identifyingObject = [NSObject new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didPauseWithIdentifyingObject:identifyingObject];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didPauseWithIdentifyingObject:identifyingObject]);
}

- (void)testDelegateCalledWhenChannelUnitResumed {

  // If
  NSObject *identifyingObject = [NSObject new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didResumeWithIdentifyingObject:identifyingObject];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didResumeWithIdentifyingObject:identifyingObject]);
}

- (void)testDelegateCalledWhenChannelUnitPreparesLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut prepareLog:mockLog];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut prepareLog:mockLog]);
}

- (void)testDelegateCalledWhenChannelUnitDidPrepareLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  NSString *internalId = @"mockId";
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didPrepareLog:mockLog internalId:internalId flags:MSACFlagsDefault];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didPrepareLog:mockLog internalId:internalId flags:MSACFlagsDefault]);
}

- (void)testDelegateCalledWhenChannelUnitDidCompleteEnqueueingLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  NSString *internalId = @"mockId";
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didCompleteEnqueueingLog:mockLog internalId:internalId];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didCompleteEnqueueingLog:mockLog internalId:internalId]);
}

- (void)testDelegateCalledWhenChannelUnitWillSendLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut willSendLog:mockLog];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut willSendLog:mockLog]);
}

- (void)testDelegateCalledWhenChannelUnitDidSucceedSendingLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didSucceedSendingLog:mockLog];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didSucceedSendingLog:mockLog]);
}

- (void)testDelegateCalledWhenChannelUnitDidSetEnabled {

  // If
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didSetEnabled:YES andDeleteDataOnDisabled:YES];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didSetEnabled:YES andDeleteDataOnDisabled:YES]);
}

- (void)testDelegateCalledWhenChannelUnitDidFailSendingLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  NSError *error = [NSError new];
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channel:self.sut didFailSendingLog:mockLog withError:error];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channel:self.sut didFailSendingLog:mockLog withError:error]);
}

- (void)testDelegateCalledWhenChannelUnitShouldFilterLog {

  // If
  id<MSACLog> mockLog = [MSACMockLog new];
  id channelUnitMock = OCMClassMock([MSACChannelUnitDefault class]);
  OCMStub([channelUnitMock alloc]).andReturn(channelUnitMock);
  OCMStub([channelUnitMock initWithIngestion:OCMOCK_ANY storage:OCMOCK_ANY configuration:OCMOCK_ANY logsDispatchQueue:OCMOCK_ANY])
      .andReturn(channelUnitMock);
  [self.sut addChannelUnitWithConfiguration:self.validConfiguration];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut channelUnit:channelUnitMock shouldFilterLog:mockLog];

  // This test will use a real channel unit object which runs `checkPendingLogs` in the log dispatch queue.
  // We should make sure the test method is not finished before `checkPendingLogs` method call is finished to avoid object retain issue.
  [self waitForLogsDispatchQueue];

  // Then
  OCMVerify([delegateMock channelUnit:channelUnitMock shouldFilterLog:mockLog]);

  // Clear
  [channelUnitMock stopMocking];
}

#pragma mark - Helper

- (void)waitForLogsDispatchQueue {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Logs dispatch queue"];
  dispatch_async(self.sut.logsDispatchQueue, ^{
    [expectation fulfill];
  });
  [self waitForExpectations:@[ expectation ] timeout:1];
}

@end
