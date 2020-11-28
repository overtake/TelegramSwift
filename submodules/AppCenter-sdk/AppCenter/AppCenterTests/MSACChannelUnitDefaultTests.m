// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>
#import <objc/objc-sync.h>

#import "MSACAbstractLogInternal.h"
#import "MSACAppCenter.h"
#import "MSACChannelDelegate.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitDefault.h"
#import "MSACChannelUnitDefaultPrivate.h"
#import "MSACDevice.h"
#import "MSACHttpIngestion.h"
#import "MSACHttpTestUtil.h"
#import "MSACLogContainer.h"
#import "MSACMockUserDefaults.h"
#import "MSACServiceCommon.h"
#import "MSACStorage.h"
#import "MSACTestFrameworks.h"
#import "MSACUserIdContext.h"
#import "MSACUtility.h"

static NSTimeInterval const kMSACTestTimeout = 1.0;
static NSString *const kMSACTestGroupId = @"GroupId";

@interface MSACChannelUnitDefault (Test)

- (void)sendLogContainer:(MSACLogContainer *__nonnull)container;

@end

@interface MSACChannelUnitDefaultTests : XCTestCase

@property(nonatomic) MSACChannelUnitConfiguration *configuration;
@property(nonatomic) MSACMockUserDefaults *settingsMock;

@property(nonatomic) id storageMock;
@property(nonatomic) id ingestionMock;

/**
 * Most of the channel APIs are asynchronous, this expectation is meant to be enqueued to the data dispatch queue at the end of the test
 * before any asserts. Then it will be triggered on the next queue loop right after the channel finished its job. Wrap asserts within the
 * handler of a waitForExpectationsWithTimeout method.
 */
@property(nonatomic) XCTestExpectation *channelEndJobExpectation;

@property(nonatomic, weak) dispatch_queue_t dispatchQueue;

@end

@implementation MSACChannelUnitDefaultTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.configuration = [[MSACChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:kMSACTestGroupId];
  self.storageMock = OCMProtocolMock(@protocol(MSACStorage));
  OCMStub([self.storageMock saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsNormal]).andReturn(YES);
  OCMStub([self.storageMock saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsCritical]).andReturn(YES);
  self.ingestionMock = OCMProtocolMock(@protocol(MSACIngestionProtocol));
  OCMStub([self.ingestionMock isReadyToSend]).andReturn(YES);
  self.settingsMock = [MSACMockUserDefaults new];
}

- (void)tearDown {

  // Stop mocks.
  [self.storageMock stopMocking];
  [self.ingestionMock stopMocking];
  [self.settingsMock stopMocking];

  /*
   * Make sure that dispatch queue has been deallocated.
   * Note: the check should be done after `stopMocking` calls because it clears list of invocations that
   * keeps references to all arguments including blocks (that implicitly keeps channel "self" reference).
   */
  XCTAssertNil(self.dispatchQueue);

  [super tearDown];
}

#pragma mark - Tests

- (void)testPendingLogsStoresStartTimeWhenPaused {

  // If
  [self initChannelEndJobExpectation];
  NSObject *object = [NSObject new];
  __block NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:3000];
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel with custom interval.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:60
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:3];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  [channel pauseWithIdentifyingObjectSync:object];

  // Trigger checkPengingLogs. Should save timestamp now.
  [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 NSDate *resultDate = [self.settingsMock objectForKey:channel.oldestPendingLogTimestampKey];
                                 XCTAssertTrue([date isEqualToDate:resultDate]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [dateMock stopMocking];
}

- (void)testCustomFlushIntervalSending200Logs {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSUInteger flushInterval = 600;
  NSUInteger batchSizeLimit = 50;
  __block int currentBatchId = 1;
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
  NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:flushInterval + 100];
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:200 headers:nil];
  __block MSACSendAsyncCompletionHandler ingestionBlock;

  // Requests counter.
  __block int sendCount = 0;
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    // Get ingestion block for later call.
    [invocation retainArguments];
    [invocation getArgument:&ingestionBlock atIndex:3];
    sendCount++;
  });

  // Stub the storage load.
  NSArray<id<MSACLog>> *logs = [self getValidMockLogArrayForDate:date andCount:50];
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Get ingestion block for later call.
        [invocation getArgument:&loadCallback atIndex:5];

        // Mock load with incrementing batchId.
        loadCallback(logs, [@(currentBatchId++) stringValue]);

        // Return YES and exit the method.
        BOOL enabled = YES;
        [invocation setReturnValue:&enabled];
      });

  // Configure channel and set custom flushInterval.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:flushInterval
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:3];

  // When
  channel.itemsCount = 200;

  // Timestamp saved with time == 0.
  [self.settingsMock setObject:date forKey:channel.oldestPendingLogTimestampKey];

  // Change time. Simulate time has passed.
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date2);

  // Trigger checkPengingLogs. Should flush 3 batches now.
  [channel checkPendingLogs];

  // Try to release one batch.
  dispatch_async(channel.logsDispatchQueue, ^{
    // Check 3 batches sent.
    assertThatInt(sendCount, equalToInt(3));
    XCTAssertNotNil(ingestionBlock);
    if (ingestionBlock) {

      // Release 1 batch.
      ingestionBlock([@(1) stringValue], responseMock, nil, nil);
    }

    // Then
    dispatch_async(channel.logsDispatchQueue, ^{
      // Check 4th batch sent.
      assertThatInt(sendCount, equalToInt(4));

      [self enqueueChannelEndJobExpectation];
    });
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(0));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [dateMock stopMocking];
  [responseMock stopMocking];
}

- (void)testLogsFlushedImmediatelyWhenIntervalIsOver {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  channel.itemsCount = 5;

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:600
                                                                 batchSizeLimit:1
                                                            pendingBatchesLimit:3];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:3000];
  [self.settingsMock setObject:[[NSDate alloc] initWithTimeIntervalSince1970:500] forKey:channel.oldestPendingLogTimestampKey];
  id channelUnitMock = OCMPartialMock(channel);
  OCMReject([channelUnitMock startTimer:OCMOCK_ANY]);
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  // Trigger checkPendingLogs
  [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(0));
                                 OCMVerify([channel flushQueue]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [dateMock stopMocking];
  [channelUnitMock stopMocking];
}

- (void)testLogsNotFlushedImmediatelyWhenIntervalIsCustom {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSUInteger batchSizeLimit = 4;
  int itemsToAdd = 8;
  id channelUnitMock = OCMPartialMock(channel);

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:600
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:3];

  // When
  for (NSUInteger i = 0; i < itemsToAdd; i++) {
    [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  }
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify([[channelUnitMock ignoringNonObjectArgs] startTimer:0]);
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(itemsToAdd));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [channelUnitMock stopMocking];
}

- (void)testResolveFlushIntervalTimestampNotSet {

  // If
  NSUInteger flushInterval = 2000;
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:flushInterval
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:1];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:1000];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  NSUInteger resultFlushInterval = [channel resolveFlushInterval];

  // Then
  XCTAssertEqual(resultFlushInterval, flushInterval);

  // Clear
  [dateMock stopMocking];
}

- (void)testResolveFlushIntervalTimeIsOut {

  // If
  NSUInteger flushInterval = 2000;
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:flushInterval
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:1];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:3000];
  [self.settingsMock setObject:[[NSDate alloc] initWithTimeIntervalSince1970:500] forKey:channel.oldestPendingLogTimestampKey];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  NSUInteger resultFlushInterval = [channel resolveFlushInterval];

  // Then
  XCTAssertEqual(resultFlushInterval, 0);

  // Clear
  [dateMock stopMocking];
}

- (void)testResolveFlushIntervalTimestampLaterThanNow {

  // If
  NSUInteger flushInterval = 2000;
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:flushInterval
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:1];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:1000];
  [self.settingsMock setObject:[[NSDate alloc] initWithTimeIntervalSince1970:2000] forKey:channel.oldestPendingLogTimestampKey];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  NSUInteger resultFlushInterval = [channel resolveFlushInterval];

  // Then
  XCTAssertEqual(resultFlushInterval, flushInterval);

  // Clear
  [dateMock stopMocking];
}

- (void)testResolveFlushIntervalNow {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:2000
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:1];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:4000];
  [self.settingsMock setObject:[[NSDate alloc] initWithTimeIntervalSince1970:2000] forKey:channel.oldestPendingLogTimestampKey];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  NSUInteger resultFlushInterval = [channel resolveFlushInterval];

  // Then
  XCTAssertEqual(resultFlushInterval, 0);

  // Clear
  [dateMock stopMocking];
}

- (void)testResolveFlushInterval {

  // If
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:1000];
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:2000
                                                                 batchSizeLimit:50
                                                            pendingBatchesLimit:1];
  [self.settingsMock setObject:[[NSDate alloc] initWithTimeIntervalSince1970:500] forKey:channel.oldestPendingLogTimestampKey];
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub([dateMock date]).andReturn(date);

  // When
  NSUInteger resultFlushInterval = [channel resolveFlushInterval];

  // Then
  XCTAssertEqual(resultFlushInterval, 1500);

  // Clear
  [dateMock stopMocking];
}

- (void)testNewInstanceWasInitialisedCorrectly {
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  assertThat(channel, notNilValue());
  assertThat(channel.configuration, equalTo(self.configuration));
  assertThat(channel.ingestion, equalTo(self.ingestionMock));
  assertThat(channel.storage, equalTo(self.storageMock));
  assertThatUnsignedLong(channel.itemsCount, equalToInt(0));
}

- (void)testLogsSentWithSuccess {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  __block MSACSendAsyncCompletionHandler ingestionBlock;
  __block MSACLogContainer *logContainer;
  __block NSString *expectedBatchId = @"1";
  NSUInteger batchSizeLimit = 1;
  id<MSACLog> expectedLog = [MSACAbstractLog new];
  expectedLog.sid = MSAC_UUID_STRING;

  // Init mocks.
  id<MSACLog> enqueuedLog = [self getValidMockLog];
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    // Get ingestion block for later call.
    [invocation retainArguments];
    [invocation getArgument:&logContainer atIndex:2];
    [invocation getArgument:&ingestionBlock atIndex:3];
  });
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:200 headers:nil];

  // Stub the storage load for that log.
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Get ingestion block for later call.
        [invocation getArgument:&loadCallback atIndex:5];

        // Mock load.
        loadCallback(((NSArray<id<MSACLog>> *)@[ expectedLog ]), expectedBatchId);
      });

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:1];

  [channel addDelegate:delegateMock];
  OCMReject([delegateMock channel:channel didFailSendingLog:OCMOCK_ANY withError:OCMOCK_ANY]);
  OCMExpect([delegateMock channel:channel didSucceedSendingLog:expectedLog]);
  OCMExpect([delegateMock channel:channel prepareLog:enqueuedLog]);
  OCMExpect([delegateMock channel:channel didPrepareLog:enqueuedLog internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock channel:channel didCompleteEnqueueingLog:enqueuedLog internalId:OCMOCK_ANY]);
  OCMExpect([self.storageMock deleteLogsWithBatchId:expectedBatchId groupId:kMSACTestGroupId]);

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    // Enqueue now that the delegate is set.
    [channel enqueueItem:enqueuedLog flags:MSACFlagsDefault];

    // Try to release one batch.
    dispatch_async(channel.logsDispatchQueue, ^{
      XCTAssertNotNil(ingestionBlock);
      if (ingestionBlock) {
        ingestionBlock([@(1) stringValue], responseMock, nil, nil);
      }

      // Then
      [self enqueueChannelEndJobExpectation];
    });
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Get sure it has been sent.
                                 assertThat(logContainer.batchId, is(expectedBatchId));
                                 assertThat(logContainer.logs, is(@[ expectedLog ]));
                                 assertThatBool(channel.pendingBatchQueueFull, isFalse());
                                 assertThatUnsignedLong(channel.pendingBatchIds.count, equalToUnsignedLong(0));
                                 OCMVerifyAll(delegateMock);
                                 OCMVerifyAll(self.storageMock);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  [responseMock stopMocking];
}

- (void)testDelegateDeadlock {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  __block NSObject *lock = [NSObject new], *syncCallback = [NSObject new];

  // Needed for waiting start of background thread.
  dispatch_semaphore_t syncBackground = dispatch_semaphore_create(0);
  [self initChannelEndJobExpectation];
  __block id<MSACLog> mockLog1 = [self getValidMockLog];
  __block id<MSACLog> mockLog2 = [self getValidMockLog];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channel:channel didPrepareLog:OCMOCK_ANY internalId:OCMOCK_ANY flags:MSACFlagsDefault])
      .andDo(^(__unused NSInvocation *invocation) {
        // Notify that didPrepareLog has been called.
        objc_sync_exit(syncCallback);

        // Do something with syncronization.
        @synchronized(lock) {
        }
      });
  [channel addDelegate:delegateMock];

  // When
  objc_sync_enter(syncCallback);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @synchronized(lock) {

      // Notify that backround task has been called.
      dispatch_semaphore_signal(syncBackground);

      // Wait when callback will be called from main thread.
      @synchronized(syncCallback) {
      }

      // Enqueue item from background thread.
      [channel enqueueItem:mockLog2 flags:MSACFlagsNormal];
    }
  });

  // Make sure that backround task is started.
  dispatch_semaphore_wait(syncBackground, DISPATCH_TIME_FOREVER);

  // Enqueue item from main thread.
  [channel enqueueItem:mockLog1 flags:MSACFlagsNormal];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock saveLog:mockLog1 withGroupId:OCMOCK_ANY flags:MSACFlagsNormal]);
                                 OCMVerify([self.storageMock saveLog:mockLog2 withGroupId:OCMOCK_ANY flags:MSACFlagsNormal]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testLogsSentWithRecoverableError {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  __block MSACSendAsyncCompletionHandler ingestionBlock;
  __block MSACLogContainer *logContainer;
  __block NSString *expectedBatchId = @"1";
  NSUInteger batchSizeLimit = 1;
  id<MSACLog> expectedLog = [MSACAbstractLog new];
  expectedLog.sid = MSAC_UUID_STRING;

  // Init mocks.
  id<MSACLog> enqueuedLog = [self getValidMockLog];
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    // Get ingestion block for later call.
    [invocation retainArguments];
    [invocation getArgument:&logContainer atIndex:2];
    [invocation getArgument:&ingestionBlock atIndex:3];
  });
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:500 headers:nil];

  // Stub the storage load for that log.
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Get ingestion block for later call.
        [invocation getArgument:&loadCallback atIndex:5];

        // Mock load.
        loadCallback(((NSArray<id<MSACLog>> *)@[ expectedLog ]), expectedBatchId);
      });

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:1];
  [channel addDelegate:delegateMock];
  OCMExpect([delegateMock channel:channel didFailSendingLog:expectedLog withError:OCMOCK_ANY]);
  OCMReject([delegateMock channel:channel didSucceedSendingLog:OCMOCK_ANY]);
  OCMExpect([delegateMock channel:channel didPrepareLog:enqueuedLog internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock channel:channel didCompleteEnqueueingLog:enqueuedLog internalId:OCMOCK_ANY]);

  // The logs shouldn't be deleted after recoverable error.
  OCMReject([self.storageMock deleteLogsWithBatchId:expectedBatchId groupId:kMSACTestGroupId]);

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    // Enqueue now that the delegate is set.
    [channel enqueueItem:enqueuedLog flags:MSACFlagsDefault];

    // Try to release one batch.
    dispatch_async(channel.logsDispatchQueue, ^{
      XCTAssertNotNil(ingestionBlock);
      if (ingestionBlock) {
        ingestionBlock([@(1) stringValue], responseMock, nil, nil);
      }

      // Then
      [self enqueueChannelEndJobExpectation];
    });
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Get sure it has been sent.
                                 assertThat(logContainer.batchId, is(expectedBatchId));
                                 assertThat(logContainer.logs, is(@[ expectedLog ]));
                                 assertThatBool(channel.pendingBatchQueueFull, isFalse());
                                 assertThatBool(channel.enabled, isTrue());
                                 assertThatUnsignedLong(channel.pendingBatchIds.count, equalToUnsignedLong(0));
                                 OCMVerifyAll(delegateMock);
                                 OCMVerifyAll(self.storageMock);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  [responseMock stopMocking];
}

- (void)testLogsSentWithUnrecoverableError {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  self.channelEndJobExpectation.expectedFulfillmentCount = 2;
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  __block MSACSendAsyncCompletionHandler ingestionBlock;
  __block MSACLogContainer *logContainer;
  __block NSString *expectedBatchId = @"1";
  NSUInteger batchSizeLimit = 1;
  id<MSACLog> expectedLog = [MSACAbstractLog new];
  expectedLog.sid = MSAC_UUID_STRING;

  // Init mocks.
  id<MSACLog> enqueuedLog = [self getValidMockLog];
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    // Get ingestion block for later call.
    [invocation retainArguments];
    [invocation getArgument:&logContainer atIndex:2];
    [invocation getArgument:&ingestionBlock atIndex:3];
  });
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:300 headers:nil];

  // Stub the storage load for that log.
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Get ingestion block for later call.
        [invocation getArgument:&loadCallback atIndex:5];

        // Mock load.
        loadCallback(((NSArray<id<MSACLog>> *)@[ expectedLog ]), expectedBatchId);
      });

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:1];
  [channel addDelegate:delegateMock];
  OCMStub([delegateMock channel:channel didSetEnabled:NO andDeleteDataOnDisabled:YES]).andDo(^(__unused NSInvocation *invocation) {
    [self enqueueChannelEndJobExpectation];
  });
  OCMExpect([delegateMock channel:channel didFailSendingLog:expectedLog withError:OCMOCK_ANY]);
  OCMReject([delegateMock channel:channel didSucceedSendingLog:OCMOCK_ANY]);
  OCMExpect([delegateMock channel:channel didPrepareLog:enqueuedLog internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock channel:channel didCompleteEnqueueingLog:enqueuedLog internalId:OCMOCK_ANY]);

  // The logs should be deleted after unrecoverable error.
  OCMExpect([self.storageMock deleteLogsWithBatchId:expectedBatchId groupId:kMSACTestGroupId]);

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    // Enqueue now that the delegate is set.
    [channel enqueueItem:enqueuedLog flags:MSACFlagsDefault];

    // Try to release one batch.
    dispatch_async(channel.logsDispatchQueue, ^{
      XCTAssertNotNil(ingestionBlock);
      if (ingestionBlock) {
        ingestionBlock([@(1) stringValue], responseMock, nil, nil);
      }
      [self enqueueChannelEndJobExpectation];
    });
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Make sure it has been sent.
                                 assertThat(logContainer.batchId, is(expectedBatchId));
                                 assertThat(logContainer.logs, is(@[ expectedLog ]));

                                 // Make sure channel is disabled and cleaned up logs.
                                 XCTAssertFalse(channel.enabled);
                                 OCMVerifyAll(delegateMock);
                                 OCMVerifyAll(self.storageMock);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  [responseMock stopMocking];
}

- (void)testEnqueuingItemsWillIncreaseCounter {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  MSACChannelUnitConfiguration *config = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                                      priority:MSACPriorityDefault
                                                                                 flushInterval:5
                                                                                batchSizeLimit:10
                                                                           pendingBatchesLimit:3];
  channel.configuration = config;
  int itemsToAdd = 3;

  // When
  for (int i = 1; i <= itemsToAdd; i++) {
    [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  }
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(itemsToAdd));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testNotCheckingPendingLogsOnEnqueueFailure {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:5
                                                                 batchSizeLimit:10
                                                            pendingBatchesLimit:3];
  channel.storage = self.storageMock = OCMProtocolMock(@protocol(MSACStorage));
  OCMStub([self.storageMock saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]).andReturn(NO);
  id channelUnitMock = OCMPartialMock(channel);
  OCMReject([channelUnitMock checkPendingLogs]);
  int itemsToAdd = 3;

  // When
  for (int i = 1; i <= itemsToAdd; i++) {
    [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  }
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(0));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  [channelUnitMock stopMocking];
}

- (void)testEnqueueCriticalItem {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACLog> mockLog = [self getValidMockLog];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsCritical];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock saveLog:mockLog withGroupId:OCMOCK_ANY flags:MSACFlagsCritical]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testEnqueueNonCriticalItem {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACLog> mockLog = [self getValidMockLog];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsNormal];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock saveLog:mockLog withGroupId:OCMOCK_ANY flags:MSACFlagsNormal]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testEnqueueItemWithFlagsDefault {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACLog> mockLog = [self getValidMockLog];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock saveLog:mockLog withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testQueueFlushedAfterBatchSizeReached {
  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:3
                                                            pendingBatchesLimit:3];
  int itemsToAdd = 3;
  XCTestExpectation *expectation = [self expectationWithDescription:@"All items enqueued"];
  id<MSACLog> mockLog = [self getValidMockLog];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channel:channel didCompleteEnqueueingLog:mockLog internalId:OCMOCK_ANY])
      .andDo(^(__unused NSInvocation *invocation) {
        static int count = 0;
        count++;
        if (count == itemsToAdd) {
          [expectation fulfill];
        }
      });
  [channel addDelegate:delegateMock];

  // When
  for (int i = 0; i < itemsToAdd; ++i) {
    [channel enqueueItem:mockLog flags:MSACFlagsCritical];
  }
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.itemsCount, equalToInt(0));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testBatchQueueLimit {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSUInteger batchSizeLimit = 1;
  __block int currentBatchId = 1;
  __block NSMutableArray<NSString *> *sentBatchIds = [NSMutableArray new];
  __block MSACLogContainer *container;
  __block MSACSendAsyncCompletionHandler ingestionBlock;
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:200 headers:nil];
  NSUInteger expectedMaxPendingBatched = 2;
  id<MSACLog> expectedLog = [MSACAbstractLog new];
  expectedLog.sid = MSAC_UUID_STRING;

  // Set up mock and stubs.
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    [invocation retainArguments];
    [invocation getArgument:&container atIndex:2];
    [invocation getArgument:&ingestionBlock atIndex:3];
    if (container) {
      [sentBatchIds addObject:container.batchId];
    }
  });
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Mock load.
        [invocation getArgument:&loadCallback atIndex:5];
        loadCallback(((NSArray<id<MSACLog>> *)@[ expectedLog ]), [@(currentBatchId++) stringValue]);
      });
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:expectedMaxPendingBatched];

  // When
  for (NSUInteger i = 1; i <= expectedMaxPendingBatched + 1; i++) {
    [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
  }

  // Try to release one batch. It should trigger sending the last one.
  dispatch_async(channel.logsDispatchQueue, ^{
    XCTAssertNotNil(ingestionBlock);
    if (ingestionBlock) {
      ingestionBlock([@(1) stringValue], responseMock, nil, nil);
    }
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatUnsignedLong(channel.pendingBatchIds.count, equalToUnsignedLong(expectedMaxPendingBatched));
                                 assertThatUnsignedLong(sentBatchIds.count, equalToUnsignedLong(expectedMaxPendingBatched + 1));
                                 assertThat(sentBatchIds[0], is(@"1"));
                                 assertThat(sentBatchIds[1], is(@"2"));
                                 assertThat(sentBatchIds[2], is(@"3"));
                                 assertThatBool(channel.pendingBatchQueueFull, isTrue());
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  [responseMock stopMocking];
}

- (void)testNextBatchSentIfPendingQueueGotRoomAgain {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  XCTestExpectation *oneLogSentExpectation = [self expectationWithDescription:@"One log sent"];
  __block MSACSendAsyncCompletionHandler ingestionBlock;
  __block MSACLogContainer *lastBatchLogContainer;
  __block int currentBatchId = 1;
  NSUInteger batchSizeLimit = 1;
  id<MSACLog> expectedLog = [MSACAbstractLog new];
  expectedLog.sid = MSAC_UUID_STRING;

  // Init mocks.
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    // Get ingestion block for later call.
    [invocation retainArguments];
    [invocation getArgument:&lastBatchLogContainer atIndex:2];
    [invocation getArgument:&ingestionBlock atIndex:3];
  });
  __block id responseMock = [MSACHttpTestUtil createMockResponseForStatusCode:200 headers:nil];

  // Stub the storage load for that log.
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSACLoadDataCompletionHandler loadCallback;

        // Get ingestion block for later call.
        [invocation getArgument:&loadCallback atIndex:5];

        // Mock load.
        loadCallback(((NSArray<id<MSACLog>> *)@[ expectedLog ]), [@(currentBatchId) stringValue]);
      });

  // Configure channel.
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:1];

  // When
  [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];

  // Try to release one batch.
  dispatch_async(channel.logsDispatchQueue, ^{
    XCTAssertNotNil(ingestionBlock);
    if (ingestionBlock) {
      ingestionBlock([@(1) stringValue], responseMock, nil, nil);
    }

    // Then
    dispatch_async(channel.logsDispatchQueue, ^{
      // Batch queue should not be full;
      assertThatBool(channel.pendingBatchQueueFull, isFalse());
      [oneLogSentExpectation fulfill];

      // When
      // Send another batch.
      currentBatchId++;
      [channel enqueueItem:[self getValidMockLog] flags:MSACFlagsDefault];
      [self enqueueChannelEndJobExpectation];
    });
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Get sure it has been sent.
                                 assertThat(lastBatchLogContainer.batchId, is([@(currentBatchId) stringValue]));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  [responseMock stopMocking];
}

- (void)testDontForwardLogsToIngestionOnDisabled {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSUInteger batchSizeLimit = 1;
  id mockLog = [self getValidMockLog];
  OCMReject([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]);
  OCMStub([self.ingestionMock sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]);
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:([OCMArg invokeBlockWithArgs:((NSArray<id<MSACLog>> *)@[ mockLog ]), @"1", nil])]);
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:10];

  // When
  [channel setEnabled:NO andDeleteDataOnDisabled:NO];
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerifyAll(self.ingestionMock);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDeleteDataOnDisabled {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSUInteger batchSizeLimit = 1;
  id mockLog = [self getValidMockLog];
  OCMStub([self.storageMock loadLogsWithGroupId:kMSACTestGroupId
                                          limit:batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:([OCMArg invokeBlockWithArgs:((NSArray<id<MSACLog>> *)@[ mockLog ]), @"1", nil])]);
  channel.configuration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACTestGroupId
                                                                       priority:MSACPriorityDefault
                                                                  flushInterval:0.0
                                                                 batchSizeLimit:batchSizeLimit
                                                            pendingBatchesLimit:10];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];
  [channel setEnabled:NO andDeleteDataOnDisabled:YES];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Check that logs as been requested for
                                 // deletion and that there is no batch left.
                                 OCMVerify([self.storageMock deleteLogsWithGroupId:kMSACTestGroupId]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDontSaveLogsWhileDisabledWithDataDeletion {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id mockLog = [self getValidMockLog];
  OCMReject([self.storageMock saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channel:channel didCompleteEnqueueingLog:mockLog internalId:OCMOCK_ANY])
      .andDo(^(__unused NSInvocation *invocation) {
        [self enqueueChannelEndJobExpectation];
      });
  [channel addDelegate:delegateMock];

  // When
  [channel setEnabled:NO andDeleteDataOnDisabled:YES];
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatBool(channel.discardLogs, isTrue());
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testSaveLogsAfterReEnabled {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  [channel setEnabled:NO andDeleteDataOnDisabled:YES];
  id<MSACLog> mockLog = [self getValidMockLog];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channel:channel didCompleteEnqueueingLog:mockLog internalId:OCMOCK_ANY])
      .andDo(^(__unused NSInvocation *invocation) {
        [self enqueueChannelEndJobExpectation];
      });
  [channel addDelegate:delegateMock];

  // When
  [channel setEnabled:YES andDeleteDataOnDisabled:NO];
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatBool(channel.discardLogs, isFalse());
                                 OCMVerify([self.storageMock saveLog:mockLog withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // If
  [self initChannelEndJobExpectation];
  id<MSACLog> otherMockLog = [self getValidMockLog];
  [channel setEnabled:NO andDeleteDataOnDisabled:NO];
  OCMStub([delegateMock channel:channel didCompleteEnqueueingLog:otherMockLog internalId:OCMOCK_ANY])
      .andDo(^(__unused NSInvocation *invocation) {
        [self enqueueChannelEndJobExpectation];
      });

  // When
  [channel setEnabled:YES andDeleteDataOnDisabled:NO];
  [channel enqueueItem:otherMockLog flags:MSACFlagsDefault];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatBool(channel.discardLogs, isFalse());
                                 OCMVerify([self.storageMock saveLog:mockLog withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testPauseOnDisabled {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  [channel setEnabled:YES andDeleteDataOnDisabled:NO];

  // When
  [channel setEnabled:NO andDeleteDataOnDisabled:NO];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatBool(channel.enabled, isFalse());
                                 assertThatBool(channel.paused, isTrue());
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testResumeOnEnabled {

  // If
  __block BOOL result1, result2;
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACIngestionProtocol> ingestionMock = OCMProtocolMock(@protocol(MSACIngestionProtocol));
  channel.ingestion = ingestionMock;

  // When
  [channel setEnabled:NO andDeleteDataOnDisabled:NO];
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel resumeWithIdentifyingObject:self];
  });
  [channel setEnabled:YES andDeleteDataOnDisabled:NO];
  dispatch_async(channel.logsDispatchQueue, ^{
    result1 = channel.paused;
  });
  [channel setEnabled:NO andDeleteDataOnDisabled:NO];
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel pauseWithIdentifyingObject:self];
    dispatch_async(channel.logsDispatchQueue, ^{
      [channel setEnabled:YES andDeleteDataOnDisabled:NO];
    });
    dispatch_async(channel.logsDispatchQueue, ^{
      result2 = channel.paused;
    });
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 assertThatBool(result1, isFalse());
                                 assertThatBool(result2, isTrue());
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDelegateAfterChannelDisabled {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  id mockLog = [self getValidMockLog];

  // When
  [channel addDelegate:delegateMock];
  [channel setEnabled:NO andDeleteDataOnDisabled:YES];

  // Enqueue now that the delegate is set.
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel enqueueItem:mockLog flags:MSACFlagsDefault];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Check the callbacks were invoked for logs.
                                 OCMVerify([delegateMock channel:channel
                                                   didPrepareLog:mockLog
                                                      internalId:OCMOCK_ANY
                                                           flags:MSACFlagsDefault]);
                                 OCMVerify([delegateMock channel:channel didCompleteEnqueueingLog:mockLog internalId:OCMOCK_ANY]);
                                 OCMVerify([delegateMock channel:channel willSendLog:mockLog]);
                                 OCMVerify([delegateMock channel:channel didFailSendingLog:mockLog withError:anything()]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDelegateAfterChannelPaused {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  NSObject *identifyingObject = [NSObject new];
  [self initChannelEndJobExpectation];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));

  // When
  [channel addDelegate:delegateMock];

  // Pause now that the delegate is set.
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel pauseWithIdentifyingObject:identifyingObject];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Check the callbacks were invoked for logs.
                                 OCMVerify([delegateMock channel:channel didPauseWithIdentifyingObject:identifyingObject]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDelegateAfterChannelResumed {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  NSObject *identifyingObject = [NSObject new];
  [self initChannelEndJobExpectation];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));

  // When
  [channel addDelegate:delegateMock];

  // Resume now that the delegate is set.
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel resumeWithIdentifyingObject:identifyingObject];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 // Check the callbacks were invoked for logs.
                                 OCMVerify([delegateMock channel:channel didResumeWithIdentifyingObject:identifyingObject]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDeviceAndTimestampAreAddedOnEnqueuing {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  id<MSACLog> mockLog = [self getValidMockLog];
  mockLog.device = nil;
  mockLog.timestamp = nil;
  [self initChannelEndJobExpectation];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];

  // Then
  XCTAssertNotNil(mockLog.device);
  XCTAssertNotNil(mockLog.timestamp);
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDeviceAndTimestampAreNotOverwrittenOnEnqueuing {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  id<MSACLog> mockLog = [self getValidMockLog];
  MSACDevice *device = mockLog.device = [MSACDevice new];
  NSDate *timestamp = mockLog.timestamp = [NSDate new];
  [self initChannelEndJobExpectation];

  // When
  [channel enqueueItem:mockLog flags:MSACFlagsDefault];

  // Then
  XCTAssertEqual(mockLog.device, device);
  XCTAssertEqual(mockLog.timestamp, timestamp);
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testEnqueuingLogDoesNotPersistFilteredLogs {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  OCMReject([self.storageMock saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);

  id<MSACLog> log = [self getValidMockLog];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channelUnit:channel shouldFilterLog:log]).andReturn(YES);
  id delegateMock2 = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock2 channelUnit:channel shouldFilterLog:log]).andReturn(NO);
  OCMExpect([delegateMock channel:channel prepareLog:log]);
  OCMExpect([delegateMock2 channel:channel prepareLog:log]);
  OCMExpect([delegateMock channel:channel didPrepareLog:log internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock2 channel:channel didPrepareLog:log internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock channel:channel didCompleteEnqueueingLog:log internalId:OCMOCK_ANY]);
  OCMExpect([delegateMock2 channel:channel didCompleteEnqueueingLog:log internalId:OCMOCK_ANY]);
  [channel addDelegate:delegateMock];
  [channel addDelegate:delegateMock2];

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    // Enqueue now that the delegate is set.
    [channel enqueueItem:log flags:MSACFlagsDefault];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerifyAll(delegateMock);
                                 OCMVerifyAll(delegateMock2);
                                 OCMVerifyAll(self.storageMock);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testEnqueuingLogPersistsUnfilteredLogs {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACLog> log = [self getValidMockLog];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));
  OCMStub([delegateMock channelUnit:channel shouldFilterLog:log]).andReturn(NO);
  OCMExpect([delegateMock channel:channel didPrepareLog:log internalId:OCMOCK_ANY flags:MSACFlagsDefault]);
  OCMExpect([delegateMock channel:channel didCompleteEnqueueingLog:log internalId:OCMOCK_ANY]);
  [channel addDelegate:delegateMock];

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    // Enqueue now that the delegate is set.
    [channel enqueueItem:log flags:MSACFlagsDefault];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerifyAll(delegateMock);
                                 OCMVerify([self.storageMock saveLog:log withGroupId:OCMOCK_ANY flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDoesntResumeWhenNotAllPauseObjectsResumed {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSObject *object1 = [NSObject new];
  NSObject *object2 = [NSObject new];
  NSObject *object3 = [NSObject new];
  [channel pauseWithIdentifyingObject:object1];
  [channel pauseWithIdentifyingObject:object2];
  [channel pauseWithIdentifyingObject:object3];

  // When
  [channel resumeWithIdentifyingObject:object1];
  [channel resumeWithIdentifyingObject:object3];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertTrue(channel.paused);
                               }];
}

- (void)testResumesWhenAllPauseObjectsResumed {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSObject *object1 = [NSObject new];
  NSObject *object2 = [NSObject new];
  NSObject *object3 = [NSObject new];
  [channel pauseWithIdentifyingObject:object1];
  [channel pauseWithIdentifyingObject:object2];
  [channel pauseWithIdentifyingObject:object3];

  // When
  [channel resumeWithIdentifyingObject:object1];
  [channel resumeWithIdentifyingObject:object2];
  [channel resumeWithIdentifyingObject:object3];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertFalse(channel.paused);
                               }];
}

- (void)testResumeWhenOnlyPausedObjectIsDeallocated {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  __weak NSObject *weakObject = nil;
  @autoreleasepool {

// Ignore warning on weak variable usage in this scope to simulate dealloc.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-unsafe-retained-assign"
    weakObject = [NSObject new];
#pragma clang diagnostic pop
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    [channel pauseWithIdentifyingObjectSync:weakObject];
#pragma clang diagnostic pop
  }

  // Then
  XCTAssertTrue(channel.paused);

  // When
  [channel resumeWithIdentifyingObjectSync:[NSObject new]];

  // Then
  XCTAssertFalse(channel.paused);
}

- (void)testResumeWithObjectThatDoesNotExistDoesNotResumeIfCurrentlyPaused {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSObject *object1 = [NSObject new];
  NSObject *object2 = [NSObject new];
  [channel pauseWithIdentifyingObject:object1];

  // When
  [channel resumeWithIdentifyingObject:object2];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertTrue(channel.paused);
                               }];
}

- (void)testResumeWithObjectThatDoesNotExistDoesNotPauseIfPreviouslyResumed {

  // When
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [channel resumeWithIdentifyingObjectSync:[NSObject new]];

  // Then
  XCTAssertFalse(channel.paused);
}

- (void)testResumeTwiceInARowResumesWhenPaused {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  NSObject *object = [NSObject new];
  [channel pauseWithIdentifyingObjectSync:object];

  // When
  [channel resumeWithIdentifyingObjectSync:object];
  [channel resumeWithIdentifyingObjectSync:object];

  // Then
  XCTAssertFalse(channel.paused);
}

- (void)testResumeOnceResumesWhenPausedTwiceWithSingleObject {

  // If
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  NSObject *object = [NSObject new];
  [channel pauseWithIdentifyingObjectSync:object];
  [channel pauseWithIdentifyingObjectSync:object];

  // When
  [channel resumeWithIdentifyingObjectSync:object];

  // Then
  XCTAssertFalse(channel.paused);
}

- (void)testPausedTargetKeysNotAlteredWhenChannelUnitPaused {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSObject *object = [NSObject new];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  [channel pauseSendingLogsWithToken:token];

  // When
  [channel pauseWithIdentifyingObjectSync:object];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(1));
                                 XCTAssertTrue([channel.pausedTargetKeys containsObject:targetKey]);
                               }];
}

- (void)testPausedTargetKeysNotAlteredWhenChannelUnitResumed {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSObject *object = [NSObject new];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  [channel pauseSendingLogsWithToken:token];
  [channel pauseWithIdentifyingObject:object];

  // When
  [channel resumeWithIdentifyingObject:object];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(1));
                                 XCTAssertTrue([channel.pausedTargetKeys containsObject:targetKey]);
                               }];
}

- (void)testNoLogsRetrievedFromStorageWhenTargetKeyIsPaused {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  __block NSArray *excludedKeys;
  OCMStub([self.storageMock loadLogsWithGroupId:channel.configuration.groupId
                                          limit:channel.configuration.batchSizeLimit
                             excludedTargetKeys:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&excludedKeys atIndex:4];
      });
  [channel pauseSendingLogsWithToken:token];

  // When
  dispatch_async(channel.logsDispatchQueue, ^{
    [channel flushQueue];
    [self enqueueChannelEndJobExpectation];
  });

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(excludedKeys.count, equalToUnsignedLong(1));
                                 XCTAssertTrue([excludedKeys containsObject:targetKey]);
                               }];
}

- (void)testLogsStoredWhenTargetKeyIsPaused {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  [channel pauseSendingLogsWithToken:token];
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  [log addTransmissionTargetToken:token];
  log.ver = @"3.0";
  log.name = @"test";
  log.iKey = targetKey;

  // When
  [channel enqueueItem:log flags:MSACFlagsDefault];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 OCMVerify([self.storageMock saveLog:log withGroupId:channel.configuration.groupId flags:MSACFlagsDefault]);
                               }];
}

- (void)testSendingPendingLogsOnResume {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  id channelUnitMock = OCMPartialMock(channel);
  [channel pauseSendingLogsWithToken:token];
  OCMStub([self.storageMock countLogs]).andReturn(60);

  // When
  [channel resumeSendingLogsWithToken:token];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 OCMVerify([self.storageMock countLogs]);
                                 OCMVerify([channelUnitMock checkPendingLogs]);

                                 // The count should be 0 since the logs were sent and not in pending state anymore.
                                 XCTAssertEqual(channel.itemsCount, 0);
                               }];
  [channelUnitMock stopMocking];
}

- (void)testTargetKeyRemainsPausedWhenPausedASecondTime {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  [channel pauseSendingLogsWithToken:token];

  // When
  [channel pauseSendingLogsWithToken:token];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(1));
                                 XCTAssertTrue([channel.pausedTargetKeys containsObject:targetKey]);
                               }];
}

- (void)testTargetKeyRemainsResumedWhenResumedASecondTime {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  NSString *targetKey = @"targetKey";
  NSString *token = [NSString stringWithFormat:@"%@-secret", targetKey];
  [channel pauseSendingLogsWithToken:token];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(1));
                                 XCTAssertTrue([channel.pausedTargetKeys containsObject:targetKey]);
                               }];

  // If
  [self initChannelEndJobExpectation];

  // When
  [channel resumeSendingLogsWithToken:token];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(0));
                               }];

  // If
  [self initChannelEndJobExpectation];

  // When
  [channel resumeSendingLogsWithToken:token];
  [self enqueueChannelEndJobExpectation];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 assertThatUnsignedLong(channel.pausedTargetKeys.count, equalToUnsignedLong(0));
                               }];
}

- (void)testEnqueueItemDoesNotSetUserIdWhenItAlreadyHasOne {

  // If
  __block MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  [self initChannelEndJobExpectation];
  id<MSACLog> enqueuedLog = [self getValidMockLog];
  NSString *expectedUserId = @"Fake-UserId";
  __block MSACAbstractLog *log;
  id userIdContextMock = OCMClassMock([MSACUserIdContext class]);
  OCMStub([userIdContextMock sharedInstance]).andReturn(userIdContextMock);
  OCMStub([userIdContextMock userId]).andReturn(@"SomethingElse");
  channel.storage = self.storageMock = OCMProtocolMock(@protocol(MSACStorage));
  OCMStub([channel.storage saveLog:OCMOCK_ANY withGroupId:OCMOCK_ANY flags:MSACFlagsNormal])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&log atIndex:2];
        [self enqueueChannelEndJobExpectation];
      })
      .andReturn(YES);

  // When
  enqueuedLog.userId = expectedUserId;
  [channel enqueueItem:enqueuedLog flags:MSACFlagsDefault];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(log.userId, expectedUserId);
                               }];
  [userIdContextMock stopMocking];
}

- (void)testAddRemoveDelegate {

  // If
  XCTestExpectation *addDelegateExpectation = [self expectationWithDescription:@"Add a channel delegate"];
  XCTestExpectation *removeDelegateExpectation = [self expectationWithDescription:@"Remove a channel delegate"];
  MSACChannelUnitDefault *channel = [self createChannelUnitDefault];
  id delegateMock = OCMProtocolMock(@protocol(MSACChannelDelegate));

  // When
  [channel addDelegate:delegateMock];
  dispatch_async(channel.logsDispatchQueue, ^{
    // Then
    XCTAssertEqual(channel.delegates.count, 1);
    XCTAssertTrue([channel.delegates containsObject:delegateMock]);
    [addDelegateExpectation fulfill];
  });
  [channel removeDelegate:delegateMock];
  dispatch_async(channel.logsDispatchQueue, ^{
    // Then
    XCTAssertEqual(channel.delegates.count, 0);
    [removeDelegateExpectation fulfill];
  });

  // Then
  [self waitForExpectations:@[ addDelegateExpectation, removeDelegateExpectation ] timeout:kMSACTestTimeout enforceOrder:YES];
}

#pragma mark - Helper

- (void)initChannelEndJobExpectation {
  self.channelEndJobExpectation = [self expectationWithDescription:@"Channel job should be finished"];
}

- (void)enqueueChannelEndJobExpectation {

  // Enqueue end job expectation on channel's queue to detect when channel
  // finished processing.
  dispatch_async(self.dispatchQueue, ^{
    [self.channelEndJobExpectation fulfill];
  });
}

- (NSArray<id<MSACLog>> *)getValidMockLogArrayForDate:(NSDate *)date andCount:(NSUInteger)count {
  NSMutableArray<id<MSACLog>> *logs = [NSMutableArray<id<MSACLog>> new];
  for (NSUInteger i = 0; i < count; i++) {
    [logs addObject:[self getValidMockLogWithDate:[date dateByAddingTimeInterval:i]]];
  }
  return logs;
}

- (id)getValidMockLog {
  id mockLog = OCMPartialMock([MSACAbstractLog new]);
  OCMStub([mockLog isValid]).andReturn(YES);
  return mockLog;
}

- (id)getValidMockLogWithDate:(NSDate *)date {
  id<MSACLog> mockLog = OCMPartialMock([MSACAbstractLog new]);
  OCMStub([mockLog timestamp]).andReturn(date);
  OCMStub([mockLog isValid]).andReturn(YES);
  return mockLog;
}

- (MSACChannelUnitDefault *)createChannelUnitDefault {
  dispatch_queue_t queue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL);
  self.dispatchQueue = queue;
  return [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                   storage:self.storageMock
                                             configuration:self.configuration
                                         logsDispatchQueue:queue];
}

@end
