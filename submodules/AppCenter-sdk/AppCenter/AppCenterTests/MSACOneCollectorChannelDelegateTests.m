// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACChannelGroupProtocol.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitDefault.h"
#import "MSACCommonSchemaLog.h"
#import "MSACHttpClient.h"
#import "MSACIngestionProtocol.h"
#import "MSACMockLogObject.h"
#import "MSACMockLogWithConversion.h"
#import "MSACOneCollectorChannelDelegatePrivate.h"
#import "MSACOneCollectorIngestion.h"
#import "MSACSDKExtension.h"
#import "MSACStorage.h"
#import "MSACTestFrameworks.h"

static NSString *const kMSACBaseGroupId = @"baseGroupId";
static NSString *const kMSACOneCollectorGroupId = @"baseGroupId/one";

// This is to get rid of warnings in the test that a method takes `nil` as its parameter even though it is marked as `nonnull`.
// Do not convert it to const.
static NSString *kMSACNilString = nil;

@interface MSACOneCollectorChannelDelegateTests : XCTestCase

@property(nonatomic) MSACOneCollectorChannelDelegate *sut;
@property(nonatomic) id<MSACIngestionProtocol> ingestionMock;
@property(nonatomic) id<MSACStorage> storageMock;
@property(nonatomic) dispatch_queue_t logsDispatchQueue;
@property(nonatomic) MSACChannelUnitConfiguration *baseUnitConfig;
@property(nonatomic) MSACChannelUnitConfiguration *oneCollectorUnitConfig;

@end

@implementation MSACOneCollectorChannelDelegateTests

- (void)setUp {
  [super setUp];
  self.sut = [[MSACOneCollectorChannelDelegate alloc] initWithHttpClient:[MSACHttpClient new]
                                                               installId:[NSUUID new]
                                                                 baseUrl:kMSACNilString];
  self.ingestionMock = OCMProtocolMock(@protocol(MSACIngestionProtocol));
  self.storageMock = OCMProtocolMock(@protocol(MSACStorage));
  self.logsDispatchQueue = dispatch_get_main_queue();
  self.baseUnitConfig = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACBaseGroupId
                                                                     priority:MSACPriorityDefault
                                                                flushInterval:3.0
                                                               batchSizeLimit:1024
                                                          pendingBatchesLimit:60];
  self.oneCollectorUnitConfig = [[MSACChannelUnitConfiguration alloc] initWithGroupId:kMSACOneCollectorGroupId
                                                                             priority:MSACPriorityDefault
                                                                        flushInterval:3.0
                                                                       batchSizeLimit:1024
                                                                  pendingBatchesLimit:60];
}

- (void)testDidAddChannelUnitWithBaseGroupId {

  // Test adding a base channel unit on MSACChannelGroupDefault will also add a One Collector channel unit.

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  __block id<MSACChannelUnitProtocol> expectedChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  __block MSACChannelUnitConfiguration *oneCollectorChannelConfig = nil;
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    [invocation retainArguments];
    [invocation getArgument:&oneCollectorChannelConfig atIndex:2];
    [invocation setReturnValue:&expectedChannelUnitMock];
  });

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];

  // Then
  XCTAssertNotNil(self.sut.oneCollectorChannels[kMSACBaseGroupId]);
  XCTAssertTrue([self.sut.oneCollectorChannels count] == 1);
  XCTAssertEqual(expectedChannelUnitMock, self.sut.oneCollectorChannels[kMSACBaseGroupId]);
  XCTAssertTrue([oneCollectorChannelConfig.groupId isEqualToString:kMSACOneCollectorGroupId]);
  OCMVerifyAll(channelGroupMock);
}

- (void)testDidAddChannelUnitWithOneCollectorGroupId {

  /*
   * Test adding an One Collector channel unit on MSACChannelGroupDefault won't do anything on MSACOneCollectorChannelDelegate because it's
   * already an One Collector group Id.
   */

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.oneCollectorUnitConfig);
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMReject([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];

  // Then
  XCTAssertNotNil(self.sut.oneCollectorChannels);
  XCTAssertTrue([self.sut.oneCollectorChannels count] == 0);
  OCMVerifyAll(channelGroupMock);
}

- (void)testOneCollectorChannelUnitIsPausedWhenBaseChannelUnitIsPaused {

  // If
  NSObject *token = [NSObject new];
  MSACChannelUnitDefault *channelUnitMock = [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                                                      storage:self.storageMock
                                                                                configuration:self.baseUnitConfig
                                                                            logsDispatchQueue:self.logsDispatchQueue];
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPauseWithIdentifyingObject:token];

  // Then
  OCMVerify([oneCollectorChannelUnitMock pauseWithIdentifyingObject:token]);
}

- (void)testOneCollectorChannelUnitIsNotPausedWhenNonBaseChannelUnitIsPaused {

  // If
  NSObject *token = [NSObject new];
  MSACChannelUnitDefault *channelUnitMock = [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                                                      storage:self.storageMock
                                                                                configuration:self.baseUnitConfig
                                                                            logsDispatchQueue:self.logsDispatchQueue];
  id oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id otherOneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  self.sut.oneCollectorChannels[kMSACBaseGroupId] = oneCollectorChannelUnitMock;
  self.sut.oneCollectorChannels[@"someOtherGroupId"] = otherOneCollectorChannelUnitMock;

  // Then
  OCMReject([otherOneCollectorChannelUnitMock pauseWithIdentifyingObject:token]);

  // When
  [self.sut channel:channelUnitMock didPauseWithIdentifyingObject:token];
}

- (void)testOneCollectorChannelUnitIsResumedWhenBaseChannelUnitIsResumed {

  // If
  NSObject *token = [NSObject new];
  MSACChannelUnitDefault *channelUnitMock = [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                                                      storage:self.storageMock
                                                                                configuration:self.baseUnitConfig
                                                                            logsDispatchQueue:self.logsDispatchQueue];
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didResumeWithIdentifyingObject:token];

  // Then
  OCMVerify([oneCollectorChannelUnitMock resumeWithIdentifyingObject:token]);
}

- (void)testOneCollectorChannelUnitIsNotResumedWhenNonBaseChannelUnitIsResumed {

  // If
  NSObject *token = [NSObject new];
  MSACChannelUnitDefault *channelUnitMock = [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                                                      storage:self.storageMock
                                                                                configuration:self.baseUnitConfig
                                                                            logsDispatchQueue:self.logsDispatchQueue];
  id oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id otherOneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  self.sut.oneCollectorChannels[kMSACBaseGroupId] = oneCollectorChannelUnitMock;
  self.sut.oneCollectorChannels[@"someOtherGroupId"] = otherOneCollectorChannelUnitMock;

  // Then
  OCMReject([otherOneCollectorChannelUnitMock resumeWithIdentifyingObject:token]);

  // When
  [self.sut channel:channelUnitMock didResumeWithIdentifyingObject:token];
}

- (void)testDidSetEnabledAndDeleteDataOnDisabled {

  /*
   * Test base channel unit's logs are cleared when the base channel unit is disabled. First, add a base channel unit to the channel group.
   * Then, disable the base channel unit. Lastly, verify the storage deletion is called for the base channel group id.
   */

  // If
  MSACChannelUnitDefault *channelUnit = [[MSACChannelUnitDefault alloc] initWithIngestion:self.ingestionMock
                                                                                  storage:self.storageMock
                                                                            configuration:self.baseUnitConfig
                                                                        logsDispatchQueue:self.logsDispatchQueue];
  MSACChannelUnitDefault *oneCollectorChannelUnit = [[MSACChannelUnitDefault alloc] initWithIngestion:self.sut.oneCollectorIngestion
                                                                                              storage:self.storageMock
                                                                                        configuration:self.oneCollectorUnitConfig
                                                                                    logsDispatchQueue:self.logsDispatchQueue];
  [channelUnit addDelegate:self.sut];
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:self.sut.oneCollectorIngestion])
      .andReturn(oneCollectorChannelUnit);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnit];
  [channelUnit setEnabled:NO andDeleteDataOnDisabled:YES];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock deleteLogsWithGroupId:kMSACBaseGroupId]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 OCMVerify([self.storageMock deleteLogsWithGroupId:kMSACOneCollectorGroupId]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDidEnqueueLogToOneCollectorChannelWhenLogHasTargetTokensAndLogIsNotCommonSchemaLog {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub(oneCollectorChannelUnitMock.logsDispatchQueue).andReturn(self.logsDispatchQueue);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  [transmissionTargetTokens addObject:@"fake-transmission-target-token"];
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  id<MSACMockLogWithConversion> mockLog = OCMProtocolMock(@protocol(MSACMockLogWithConversion));
  OCMStub([mockLog toCommonSchemaLogsWithFlags:MSACFlagsDefault]).andReturn(@[ commonSchemaLog ]);
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:mockLog internalId:@"fake-id" flags:MSACFlagsDefault];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 OCMVerify([oneCollectorChannelUnitMock enqueueItem:commonSchemaLog flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDidEnqueueLogToOneCollectorChannelSynchronously {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub(oneCollectorChannelUnitMock.logsDispatchQueue).andReturn(self.logsDispatchQueue);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  [transmissionTargetTokens addObject:@"fake-transmission-target-token"];
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  id<MSACMockLogWithConversion> mockLog = OCMProtocolMock(@protocol(MSACMockLogWithConversion));
  OCMStub([mockLog toCommonSchemaLogsWithFlags:MSACFlagsDefault]).andReturn(@[ commonSchemaLog ]);
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);

  /*
   * Make sure that the common schema log is enqueued synchronously by putting a task on the log queue that won't return
   * by the time verify is called.
   */
  dispatch_async(oneCollectorChannelUnitMock.logsDispatchQueue, ^{
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
  });

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:mockLog internalId:@"fake-id" flags:MSACFlagsDefault];

  // Then
  OCMVerify([oneCollectorChannelUnitMock enqueueItem:commonSchemaLog flags:MSACFlagsDefault]);
  dispatch_semaphore_signal(sem);
}

- (void)testDidNotEnqueueLogToOneCollectorChannelWhenLogDoesNotConformToMSACLogConversionProtocol {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  [transmissionTargetTokens addObject:@"fake-transmission-target-token"];
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  id<MSACMockLogObject> mockLog = OCMProtocolMock(@protocol(MSACMockLogObject));
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);

  // Then
  OCMReject([oneCollectorChannelUnitMock enqueueItem:commonSchemaLog flags:MSACFlagsDefault]);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:mockLog internalId:@"fake-id" flags:MSACFlagsDefault];
}

- (void)testReEnqueueLogWhenCommonSchemaLogIsPrepared {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub(oneCollectorChannelUnitMock.logsDispatchQueue).andReturn(self.logsDispatchQueue);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  [transmissionTargetTokens addObject:@"fake-transmission-target-token"];
  id commonSchemaLog = OCMPartialMock([MSACCommonSchemaLog new]);
  OCMStub([commonSchemaLog transmissionTargetTokens]).andReturn(transmissionTargetTokens);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:commonSchemaLog internalId:@"fake-id" flags:MSACFlagsDefault];

  // Then
  [self enqueueChannelEndJobExpectation];
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 OCMVerify([oneCollectorChannelUnitMock enqueueItem:commonSchemaLog flags:MSACFlagsDefault]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDidNotEnqueueLogWhenLogHasNoTargetTokens {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  id<MSACMockLogWithConversion> mockLog = OCMProtocolMock(@protocol(MSACMockLogWithConversion));
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);
  OCMStub([mockLog toCommonSchemaLogsWithFlags:MSACFlagsDefault]).andReturn(@ [[MSACCommonSchemaLog new]]);

  // Then
  OCMReject([oneCollectorChannelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:mockLog internalId:@"fake-id" flags:MSACFlagsDefault];
}

- (void)testDidNotEnqueueLogWhenLogHasNilTargetTokens {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  id<MSACMockLogWithConversion> mockLog = OCMProtocolMock(@protocol(MSACMockLogWithConversion));
  OCMStub(mockLog.transmissionTargetTokens).andReturn(nil);
  OCMStub([mockLog toCommonSchemaLogsWithFlags:MSACFlagsDefault]).andReturn(@ [[MSACCommonSchemaLog new]]);

  // Then
  OCMReject([oneCollectorChannelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);

  // When
  [self.sut channelGroup:channelGroupMock didAddChannelUnit:channelUnitMock];
  [self.sut channel:channelUnitMock didPrepareLog:mockLog internalId:@"fake-id" flags:MSACFlagsDefault];
}

- (void)testDoesNotFilterValidCommonSchemaLogs {

  // If
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([oneCollectorChannelUnitMock configuration]).andReturn(self.oneCollectorUnitConfig);
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.name = @"avalidname";

  // When
  BOOL shouldFilter = [self.sut channelUnit:oneCollectorChannelUnitMock shouldFilterLog:log];

  // Then
  XCTAssertFalse(shouldFilter);
}

- (void)testFiltersInvalidCommonSchemaLogs {

  // If
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([oneCollectorChannelUnitMock configuration]).andReturn(self.oneCollectorUnitConfig);
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.name = nil;

  // When
  BOOL shouldFilter = [self.sut channelUnit:oneCollectorChannelUnitMock shouldFilterLog:log];

  // Then
  XCTAssertTrue(shouldFilter);
}

- (void)testDoesNotFilterLogFromNonOneCollectorChannelWhenLogHasNoTargetTokens {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  id<MSACLog> mockLog = OCMProtocolMock(@protocol(MSACLog));
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);

  // When
  BOOL shouldFilter = [self.sut channelUnit:channelUnitMock shouldFilterLog:mockLog];

  // Then
  XCTAssertFalse(shouldFilter);
}

- (void)testDoesNotFilterLogFromNonOneCollectorChannelWhenLogHasNilTargetTokenSet {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACLog> mockLog = OCMProtocolMock(@protocol(MSACLog));
  OCMStub(mockLog.transmissionTargetTokens).andReturn(nil);

  // When
  BOOL shouldFilter = [self.sut channelUnit:channelUnitMock shouldFilterLog:mockLog];

  // Then
  XCTAssertFalse(shouldFilter);
}

- (void)testFiltersNonOneCollectorLogWhenLogHasTargetTokens {

  // If
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnitMock configuration]).andReturn(self.baseUnitConfig);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY withIngestion:OCMOCK_ANY]).andReturn(oneCollectorChannelUnitMock);
  NSMutableSet *transmissionTargetTokens = [NSMutableSet new];
  [transmissionTargetTokens addObject:@"fake-transmission-target-token"];
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  id<MSACMockLogWithConversion> mockLog = OCMProtocolMock(@protocol(MSACMockLogWithConversion));
  OCMStub([mockLog toCommonSchemaLogsWithFlags:MSACFlagsDefault]).andReturn(@[ commonSchemaLog ]);
  OCMStub(mockLog.transmissionTargetTokens).andReturn(transmissionTargetTokens);

  // When
  BOOL shouldFilter = [self.sut channelUnit:channelUnitMock shouldFilterLog:mockLog];

  // Then
  XCTAssertTrue(shouldFilter);
}

- (void)testValidateLog {

  // If
  // Valid name.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.name = @"valid.CS.event.name";

  // Then
  XCTAssertTrue([self.sut validateLog:log]);

  // If
  // Invalid name.
  log.name = nil;

  // Then
  XCTAssertFalse([self.sut validateLog:log]);

  // If
  // Valid data.
  log.name = @"valid.CS.event.name";
  log.data = [MSACCSData new];
  log.data.properties = @{@"validkey" : @"validvalue"};

  // Then
  XCTAssertTrue([self.sut validateLog:log]);
}

- (void)testValidateLogName {
  const int maxNameLength = 100;

  // If
  NSString *validName = @"valid.CS.event.name";
  NSString *shortName = @"e";
  NSString *name100 = [@"" stringByPaddingToLength:maxNameLength withString:@"logName100" startingAtIndex:0];
  NSString *nilLogName = nil;
  NSString *emptyName = @"";
  NSString *tooLongName = [@"" stringByPaddingToLength:(maxNameLength + 1) withString:@"tooLongLogName" startingAtIndex:0];
  NSString *periodAndUnderscoreName = @"hello.world_mamamia";
  NSString *leadingPeriodName = @".hello.world";
  NSString *trailingPeriodName = @"hello.world.";
  NSString *consecutivePeriodName = @"hello..world";
  NSString *headingUnderscoreName = @"_hello.world";
  NSString *specialCharactersOtherThanPeriodAndUnderscore = @"hello%^&world";

  // Then
  XCTAssertTrue([self.sut validateLogName:validName]);
  XCTAssertFalse([self.sut validateLogName:shortName]);
  XCTAssertTrue([self.sut validateLogName:name100]);
  XCTAssertFalse([self.sut validateLogName:nilLogName]);
  XCTAssertFalse([self.sut validateLogName:emptyName]);
  XCTAssertFalse([self.sut validateLogName:tooLongName]);
  XCTAssertTrue([self.sut validateLogName:periodAndUnderscoreName]);
  XCTAssertFalse([self.sut validateLogName:leadingPeriodName]);
  XCTAssertFalse([self.sut validateLogName:trailingPeriodName]);
  XCTAssertFalse([self.sut validateLogName:consecutivePeriodName]);
  XCTAssertFalse([self.sut validateLogName:headingUnderscoreName]);
  XCTAssertFalse([self.sut validateLogName:specialCharactersOtherThanPeriodAndUnderscore]);
}

- (void)testLogNameRegex {

  // If
  NSError *error = nil;

  // When
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kMSACLogNameRegex options:0 error:&error];

  // Then
  XCTAssertNotNil(regex);
  XCTAssertNil(error);
}

- (void)testPrepareLogForSDKExtension {

  // If
  NSUUID *installId = [NSUUID new];
  self.sut = [[MSACOneCollectorChannelDelegate alloc] initWithHttpClient:[MSACHttpClient new] installId:installId baseUrl:kMSACNilString];
  id channelMock = OCMProtocolMock(@protocol(MSACChannelProtocol));
  MSACCommonSchemaLog *csLogMock = OCMPartialMock([MSACCommonSchemaLog new]);
  csLogMock.iKey = @"o:81439696f7164d7599d543f9bf37abb7";
  MSACCSExtensions *ext = OCMPartialMock([MSACCSExtensions new]);
  MSACSDKExtension *sdkExt = OCMPartialMock([MSACSDKExtension new]);
  ext.sdkExt = sdkExt;
  csLogMock.ext = ext;
  OCMStub([csLogMock isValid]).andReturn(YES);

  // When
  [self.sut channel:channelMock prepareLog:csLogMock];

  // Then
  XCTAssertEqualObjects(installId, csLogMock.ext.sdkExt.installId);
  XCTAssertNotNil(csLogMock.ext.sdkExt.epoch);
  XCTAssertEqual(csLogMock.ext.sdkExt.seq, 1);
  XCTAssertNotNil(self.sut.epochsAndSeqsByIKey);
  XCTAssertTrue(self.sut.epochsAndSeqsByIKey.count == 1);
}

- (void)testResetEpochAndSeq {

  // If
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  MSACCommonSchemaLog *csLogMock = OCMPartialMock([MSACCommonSchemaLog new]);
  csLogMock.iKey = @"o:81439696f7164d7599d543f9bf37abb7";
  MSACCSExtensions *ext = OCMPartialMock([MSACCSExtensions new]);
  MSACSDKExtension *sdkExt = OCMPartialMock([MSACSDKExtension new]);
  ext.sdkExt = sdkExt;
  csLogMock.ext = ext;
  OCMStub([csLogMock isValid]).andReturn(YES);

  // When
  [self.sut channel:channelGroupMock prepareLog:csLogMock];

  // Then
  XCTAssertNotNil(self.sut.epochsAndSeqsByIKey);
  XCTAssertTrue(self.sut.epochsAndSeqsByIKey.count == 1);

  // When
  [self.sut channel:channelGroupMock didSetEnabled:NO andDeleteDataOnDisabled:YES];

  // Then
  XCTAssertTrue(self.sut.epochsAndSeqsByIKey.count == 0);
}

// A helper method to initialize the test expectation
- (void)enqueueChannelEndJobExpectation {
  XCTestExpectation *channelEndJobExpectation = [self expectationWithDescription:@"Channel job should be finished"];
  dispatch_async(self.logsDispatchQueue, ^{
    [channelEndJobExpectation fulfill];
  });
}

@end
