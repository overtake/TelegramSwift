// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenterInternal.h"
#import "MSACAppCenterUserDefaultsPrivate.h"
#import "MSACAppleErrorLog.h"
#import "MSACApplicationForwarder.h"
#import "MSACChannelGroupDefault.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitDefault.h"
#import "MSACCrashHandlerSetupDelegate.h"
#import "MSACCrashReporter.h"
#import "MSACCrashesBufferedLog.hpp"
#import "MSACCrashesCXXExceptionHandler.h"
#import "MSACCrashesInternal.h"
#import "MSACCrashesPrivate.h"
#import "MSACCrashesTestUtil.h"
#import "MSACCrashesUtil.h"
#import "MSACDeviceTrackerPrivate.h"
#import "MSACErrorAttachmentLogInternal.h"
#import "MSACErrorLogFormatter.h"
#import "MSACException.h"
#import "MSACHandledErrorLog.h"
#import "MSACLoggerInternal.h"
#import "MSACMockCrashesDelegate.h"
#import "MSACMockUserDefaults.h"
#import "MSACSessionContextPrivate.h"
#import "MSACTestFrameworks.h"
#import "MSACUserIdContextPrivate.h"
#import "MSACUtility+File.h"
#import "MSACWrapperCrashesHelper.h"

@class MSACMockCrashesDelegate;

static NSString *const kMSACTestAppSecret = @"TestAppSecret";
static NSString *const kMSACFatal = @"fatal";
static NSString *const kMSACTypeHandledError = @"handledError";
static unsigned int kAttachmentsPerCrashReport = 3;

@interface MSACCrashes ()

+ (void)notifyWithUserConfirmation:(MSACUserConfirmation)userConfirmation;
- (void)startDelayedCrashProcessing;
- (void)startCrashProcessing;
- (void)shouldAlwaysSend;
- (void)emptyLogBufferFiles;
- (void)handleUserConfirmation:(MSACUserConfirmation)userConfirmation;
- (void)applicationWillEnterForeground;
- (void)didReceiveMemoryWarning:(NSNotification *)notification;

@property(nonatomic) dispatch_group_t bufferFileGroup;

@property dispatch_source_t memoryPressureSource;

@end

@interface MSACCrashesTests : XCTestCase <MSACCrashesDelegate>

@property(nonatomic) MSACCrashes *sut;

@property(nonatomic) id deviceTrackerMock;

@property(nonatomic) MSACMockUserDefaults *settingsMock;

@property(nonatomic) id sessionContextMock;

@end

@implementation MSACCrashesTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.settingsMock = [MSACMockUserDefaults new];
  self.sut = [MSACCrashes new];
  [MSACDeviceTracker resetSharedInstance];
  self.deviceTrackerMock = OCMClassMock([MSACDeviceTracker class]);
  OCMStub([self.deviceTrackerMock sharedInstance]).andReturn(self.deviceTrackerMock);
  [MSACSessionContext resetSharedInstance];
  self.sessionContextMock = OCMClassMock([MSACSessionContext class]);
  OCMStub([self.sessionContextMock sharedInstance]).andReturn(self.sessionContextMock);
}

- (void)tearDown {
  [super tearDown];

  // Reset mocked shared instances and stop mocking them.
  [self.settingsMock stopMocking];
  [self.deviceTrackerMock stopMocking];
  [self.sessionContextMock stopMocking];
  [MSACDeviceTracker resetSharedInstance];
  [MSACSessionContext resetSharedInstance];

  // Make sure sessionTracker removes all observers.
  [MSACCrashes resetSharedInstance];

  // Wait for creation of buffers.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // Delete all files.
  [self.sut deleteAllFromCrashesDirectory];
  NSString *logBufferDir = [MSACCrashesUtil logBufferDir];
  [MSACUtility deleteItemForPathComponent:logBufferDir];
}

#pragma mark - Tests

- (void)testMigrateOnInit {
  NSString *key = [NSString stringWithFormat:kMSACMockMigrationKey, @"Crashes"];
  XCTAssertNotNil([self.settingsMock objectForKey:key]);
}

- (void)testNewInstanceWasInitialisedCorrectly {

  // When
  // An instance of MSACCrashes is created.

  // Then
  assertThat(self.sut, notNilValue());
  assertThat(self.sut.crashFiles, isEmpty());
  assertThat(self.sut.analyzerInProgressFilePathComponent, notNilValue());
  XCTAssertTrue(msACCrashesLogBuffer.size() == ms_crashes_log_buffer_size);

  // Wait for creation of buffers.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);
  NSArray *files = [MSACUtility contentsOfDirectory:self.sut.logBufferPathComponent propertiesForKeys:nil];
  assertThat(files, hasCountOf(ms_crashes_log_buffer_size));
}

- (void)testStartingManagerInitializesPLCrashReporter {

  // When
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.plCrashReporter, notNilValue());
}

- (void)testStartingManagerWritesLastCrashReportToCrashesDir {

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());

  // When
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));
}

- (void)testSettingDelegateWorks {

  // When
  id<MSACCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashesDelegate));
  [MSACCrashes setDelegate:delegateMock];

  // Then
  id<MSACCrashesDelegate> strongDelegate = [MSACCrashes sharedInstance].delegate;
  XCTAssertNotNil(strongDelegate);
  XCTAssertEqual(strongDelegate, delegateMock);
}

- (void)testDidFailSendingErrorReportIsCalled {

  // If
  id<MSACCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashesDelegate));
  XCTestExpectation *expectation = [self expectationWithDescription:@"didFailSendingErrorReportCalled"];
  MSACAppleErrorLog *errorLog = OCMClassMock([MSACAppleErrorLog class]);
  MSACErrorReport *errorReport = OCMClassMock([MSACErrorReport class]);
  id errorLogFormatterMock = OCMClassMock([MSACErrorLogFormatter class]);
  OCMStub(ClassMethod([errorLogFormatterMock errorReportFromLog:errorLog])).andReturn(errorReport);
  OCMStub([delegateMock crashes:self.sut didFailSendingErrorReport:errorReport withError:nil]).andDo(^(__unused NSInvocation *invocation) {
    [expectation fulfill];
  });

  // When
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [self.sut setDelegate:delegateMock];
  id<MSACChannelProtocol> channel = [MSACCrashes sharedInstance].channelUnit;
  id<MSACLog> log = errorLog;
  [self.sut channel:channel didFailSendingLog:log withError:nil];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testDidSucceedSendingErrorReportIsCalled {

  // If
  id<MSACCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashesDelegate));
  XCTestExpectation *expectation = [self expectationWithDescription:@"didSucceedSendingErrorReportCalled"];
  MSACAppleErrorLog *errorLog = OCMClassMock([MSACAppleErrorLog class]);
  MSACErrorReport *errorReport = OCMClassMock([MSACErrorReport class]);
  id errorLogFormatterMock = OCMClassMock([MSACErrorLogFormatter class]);
  OCMStub(ClassMethod([errorLogFormatterMock errorReportFromLog:errorLog])).andReturn(errorReport);
  OCMStub([delegateMock crashes:self.sut didSucceedSendingErrorReport:errorReport]).andDo(^(__unused NSInvocation *invocation) {
    [expectation fulfill];
  });

  // When
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [self.sut setDelegate:delegateMock];
  id<MSACChannelProtocol> channel = [MSACCrashes sharedInstance].channelUnit;
  id<MSACLog> log = errorLog;
  [self.sut channel:channel didSucceedSendingLog:log];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testWillSendErrorReportIsCalled {

  // If
  id<MSACCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashesDelegate));
  XCTestExpectation *expectation = [self expectationWithDescription:@"willSendErrorReportCalled"];
  MSACAppleErrorLog *errorLog = OCMClassMock([MSACAppleErrorLog class]);
  MSACErrorReport *errorReport = OCMClassMock([MSACErrorReport class]);
  id errorLogFormatterMock = OCMClassMock([MSACErrorLogFormatter class]);
  OCMStub(ClassMethod([errorLogFormatterMock errorReportFromLog:errorLog])).andReturn(errorReport);
  OCMStub([delegateMock crashes:self.sut willSendErrorReport:errorReport]).andDo(^(__unused NSInvocation *invocation) {
    [expectation fulfill];
  });

  // When
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [self.sut setDelegate:delegateMock];
  id<MSACChannelProtocol> channel = [MSACCrashes sharedInstance].channelUnit;
  id<MSACLog> log = errorLog;
  [self.sut channel:channel willSendLog:log];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testCrashHandlerSetupDelegateMethodsAreCalled {

  // If
  id<MSACCrashHandlerSetupDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashHandlerSetupDelegate));
  [MSACWrapperCrashesHelper setCrashHandlerSetupDelegate:delegateMock];

  // When
  [self.sut applyEnabledState:YES];

  // Then
  OCMVerify([delegateMock willSetUpCrashHandlers]);
  OCMVerify([delegateMock didSetUpCrashHandlers]);
  OCMVerify([delegateMock shouldEnableUncaughtExceptionHandler]);
}

- (void)testSettingAdditionalHandlers {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock isDebuggerAttached]).andReturn(NO);
  id exceptionHandlerManagerClass = OCMClassMock([MSACCrashesUncaughtCXXExceptionHandlerManager class]);
  id applicationForwarderClass = OCMClassMock([MSACApplicationForwarder class]);

  // When
  [self.sut applyEnabledState:YES];

  // Then
  OCMVerify([exceptionHandlerManagerClass addCXXExceptionHandler:(MSACCrashesUncaughtCXXExceptionHandler)[OCMArg anyPointer]]);
  OCMVerify([applicationForwarderClass registerForwarding]);

  // Clear
  [appCenterMock stopMocking];
  [exceptionHandlerManagerClass stopMocking];
  [applicationForwarderClass stopMocking];
}

- (void)testSettingUserConfirmationHandler {

  // When
  MSACUserConfirmationHandler userConfirmationHandler = ^BOOL(__unused NSArray<MSACErrorReport *> *_Nonnull errorReports) {
    return NO;
  };
  [MSACCrashes setUserConfirmationHandler:userConfirmationHandler];

  // Then
  XCTAssertNotNil([MSACCrashes sharedInstance].userConfirmationHandler);
  XCTAssertEqual([MSACCrashes sharedInstance].userConfirmationHandler, userConfirmationHandler);
}

- (void)testCrashesDelegateWithoutImplementations {

  // When
  MSACMockCrashesDelegate *delegateMock = OCMPartialMock([MSACMockCrashesDelegate new]);
  [MSACCrashes setDelegate:delegateMock];

  // Then
  assertThatBool([[MSACCrashes sharedInstance] shouldProcessErrorReport:nil], isTrue());
}

- (void)testProcessCrashes {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);

  // When
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));

  // When
  OCMStub([self.sut shouldAlwaysSend]).andReturn(YES);
  [self.sut startCrashProcessing];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));

  // When
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(1));

  // When
  MSACUserConfirmationHandler userConfirmationHandlerYES =
      ^BOOL(__attribute__((unused)) NSArray<MSACErrorReport *> *_Nonnull errorReports) {
        return YES;
      };

  self.sut.userConfirmationHandler = userConfirmationHandlerYES;
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [self.sut startCrashProcessing];
  [self.sut notifyWithUserConfirmation:MSACUserConfirmationDontSend];
  self.sut.userConfirmationHandler = nil;

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(0));

  // When
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(1));

  // When
  MSACUserConfirmationHandler userConfirmationHandlerNO = ^BOOL(__attribute__((unused)) NSArray<MSACErrorReport *> *_Nonnull errorReports) {
    return NO;
  };
  self.sut.userConfirmationHandler = userConfirmationHandlerNO;
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [self.sut startCrashProcessing];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(0));
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testProcessCrashesWithErrorAttachments {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);

  // When
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  NSString *validString = @"valid";
  NSData *validData = [validString dataUsingEncoding:NSUTF8StringEncoding];
  NSData *emptyData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *hugeData = [[NSMutableData alloc] initWithLength:7 * 1024 * 1024 + 1];
  NSArray *invalidLogs = @[
    [self attachmentWithAttachmentId:nil attachmentData:validData contentType:validString],
    [self attachmentWithAttachmentId:@"" attachmentData:validData contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:nil contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:emptyData contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:validData contentType:nil],
    [self attachmentWithAttachmentId:validString attachmentData:validData contentType:@""],
    [self attachmentWithAttachmentId:validString attachmentData:hugeData contentType:validString]
  ];
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  for (NSUInteger i = 0; i < invalidLogs.count; i++) {
    OCMReject([channelUnitMock enqueueItem:invalidLogs[i] flags:MSACFlagsDefault]);
  }
  MSACErrorAttachmentLog *validLog = [self attachmentWithAttachmentId:validString attachmentData:validData contentType:validString];
  NSMutableArray *logs = invalidLogs.mutableCopy;
  [logs addObject:validLog];
  id crashesDelegateMock = OCMProtocolMock(@protocol(MSACCrashesDelegate));
  OCMStub([crashesDelegateMock attachmentsWithCrashes:OCMOCK_ANY forErrorReport:OCMOCK_ANY]).andReturn(logs);
  OCMStub([crashesDelegateMock crashes:OCMOCK_ANY shouldProcessErrorReport:OCMOCK_ANY]).andReturn(YES);
  [self.sut startWithChannelGroup:channelGroupMock appSecret:kMSACTestAppSecret transmissionTargetToken:nil fromApplication:YES];
  [self.sut setDelegate:crashesDelegateMock];

  // Then
  OCMExpect([channelUnitMock enqueueItem:validLog flags:MSACFlagsDefault]);
  [self.sut startCrashProcessing];
  OCMVerifyAll(channelUnitMock);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testProcessCrashesOnEnterForeground {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);

  // When
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));

  // When
  [self.sut applicationWillEnterForeground];

  // Then
  OCMVerify([self.sut startDelayedCrashProcessing]);
}

- (void)testDeleteAllFromCrashesDirectory {

  // If
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_signal"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // When
  [self.sut deleteAllFromCrashesDirectory];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
}

- (void)testDeleteCrashReportsOnDisabled {

  // If
  MSACMockUserDefaults *settings = [MSACMockUserDefaults new];
  [settings setObject:@(YES) forKey:self.sut.isEnabledKey];
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // When
  [self.sut setEnabled:NO];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(0));
  [settings stopMocking];
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testDeleteCrashReportsFromDisabledToEnabled {

  // If
  MSACMockUserDefaults *settings = [MSACMockUserDefaults new];
  [settings setObject:@(NO) forKey:self.sut.isEnabledKey];
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                        appSecret:kMSACTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];

  // When
  [self.sut setEnabled:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([MSACUtility contentsOfDirectory:self.sut.crashesPathComponent propertiesForKeys:nil].count, equalToLong(0));
  [settings stopMocking];
}

- (void)testSetupLogBufferWorks {

  // If
  // Wait for creation of buffers.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // Then
  NSArray<NSURL *> *first = [MSACUtility contentsOfDirectory:self.sut.logBufferPathComponent
                                           propertiesForKeys:@[ NSURLNameKey, NSURLFileSizeKey, NSURLIsRegularFileKey ]];
  XCTAssertTrue(first.count == ms_crashes_log_buffer_size);
  for (NSURL *path in first) {
    unsigned long long fileSize =
        [[[NSFileManager defaultManager] attributesOfItemAtPath:([path absoluteString] ?: @"") error:nil] fileSize];
    XCTAssertTrue(fileSize == 0);
  }

  // When
  [self.sut setupLogBuffer];

  // Then
  NSArray *second = [MSACUtility contentsOfDirectory:self.sut.logBufferPathComponent propertiesForKeys:nil];
  for (NSUInteger i = 0; i < ms_crashes_log_buffer_size; i++) {
    XCTAssertTrue([([first[i] absoluteString] ?: @"") isEqualToString:([second[i] absoluteString] ?: @"")]);
  }
}

- (void)testEmptyLogBufferFiles {

  // If
  NSString *testName = @"aFilename";
  NSString *dataString = @"someBufferedData";
  NSData *someData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSString *filePath =
      [NSString stringWithFormat:@"%@/%@", self.sut.logBufferPathComponent, [testName stringByAppendingString:@".mscrasheslogbuffer"]];
  [MSACUtility createFileAtPathComponent:filePath withData:someData atomically:YES forceOverwrite:YES];

  // When
  BOOL success = [MSACUtility fileExistsForPathComponent:filePath];
  XCTAssertTrue(success);

  // Then
  NSData *data = [MSACUtility loadDataForPathComponent:filePath];
  XCTAssertTrue([data length] == 16);

  // When
  [self.sut emptyLogBufferFiles];

  // Then
  data = [MSACUtility loadDataForPathComponent:filePath];
  XCTAssertTrue([data length] == 0);
}

- (void)testBufferIndexIncrement {

  // When
  MSACLogWithProperties *log = [MSACLogWithProperties new];
  [self.sut channel:nil didPrepareLog:log internalId:MSAC_UUID_STRING flags:MSACFlagsNormal];

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == 1);
}

- (void)testBufferIndexOverflow {

  // When
  for (int i = 0; i < ms_crashes_log_buffer_size; i++) {
    MSACLogWithProperties *log = [MSACLogWithProperties new];
    [self.sut channel:nil didPrepareLog:log internalId:MSAC_UUID_STRING flags:MSACFlagsDefault];
  }

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);

  // When
  MSACLogWithProperties *log = [MSACLogWithProperties new];
  [self.sut channel:nil didPrepareLog:log internalId:MSAC_UUID_STRING flags:MSACFlagsDefault];
  NSNumberFormatter *timestampFormatter = [[NSNumberFormatter alloc] init];
  timestampFormatter.numberStyle = NSNumberFormatterDecimalStyle;
  int indexOfLatestObject = 0;
  NSTimeInterval oldestTimestamp = DBL_MAX;
  for (auto it = msACCrashesLogBuffer.begin(), end = msACCrashesLogBuffer.end(); it != end; ++it) {

    // Remember the timestamp if the log is older than the previous one or the initial one.
    if (oldestTimestamp > it->timestamp) {
      oldestTimestamp = it->timestamp;
      indexOfLatestObject = static_cast<int>(it - msACCrashesLogBuffer.begin());
    }
  }
  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);
  XCTAssertTrue(indexOfLatestObject == 1);

  // If
  int numberOfLogs = 50;
  // When
  for (int i = 0; i < numberOfLogs; i++) {
    MSACLogWithProperties *aLog = [MSACLogWithProperties new];
    [self.sut channel:nil didPrepareLog:aLog internalId:MSAC_UUID_STRING flags:MSACFlagsDefault];
  }

  indexOfLatestObject = 0;
  oldestTimestamp = DBL_MAX;
  for (auto it = msACCrashesLogBuffer.begin(), end = msACCrashesLogBuffer.end(); it != end; ++it) {

    // Remember the timestamp if the log is older than the previous one or the initial one.
    if (oldestTimestamp > it->timestamp) {
      oldestTimestamp = it->timestamp;
      indexOfLatestObject = static_cast<int>(it - msACCrashesLogBuffer.begin());
    }
  }

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);
  XCTAssertTrue(indexOfLatestObject == (1 + (numberOfLogs % ms_crashes_log_buffer_size)));
}

- (void)testBufferIndexOnPersistingLog {

  // When
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  [commonSchemaLog addTransmissionTargetToken:MSAC_UUID_STRING];
  NSString *uuid1 = MSAC_UUID_STRING;
  NSString *uuid2 = MSAC_UUID_STRING;
  NSString *uuid3 = MSAC_UUID_STRING;
  [self.sut channel:nil didPrepareLog:[MSACLogWithProperties new] internalId:uuid1 flags:MSACFlagsDefault];
  [self.sut channel:nil didPrepareLog:commonSchemaLog internalId:uuid2 flags:MSACFlagsDefault];

  // Don't buffer event if log is related to crash.
  [self.sut channel:nil didPrepareLog:[MSACAppleErrorLog new] internalId:uuid3 flags:MSACFlagsDefault];

  // Then
  assertThatLong([self crashesLogBufferCount], equalToLong(2));

  // When
  [self.sut channel:nil didCompleteEnqueueingLog:nil internalId:uuid3];

  // Then
  assertThatLong([self crashesLogBufferCount], equalToLong(2));

  // When
  [self.sut channel:nil didCompleteEnqueueingLog:nil internalId:uuid2];

  // Then
  assertThatLong([self crashesLogBufferCount], equalToLong(1));

  // When
  [self.sut channel:nil didCompleteEnqueueingLog:nil internalId:uuid1];

  // Then
  assertThatLong([self crashesLogBufferCount], equalToLong(0));
}

- (void)testLogBufferSave {

  // Wait for creation of buffers.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  __block NSUInteger numInvocations = 0;
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"CrashesBuffer"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]).andDo(^(__unused NSInvocation *invocation) {
    numInvocations++;
  });

  // When
  MSACCommonSchemaLog *commonSchemaLog = [MSACCommonSchemaLog new];
  [commonSchemaLog addTransmissionTargetToken:MSAC_UUID_STRING];
  NSString *uuid1 = MSAC_UUID_STRING;
  NSString *uuid2 = MSAC_UUID_STRING;
  NSString *uuid3 = MSAC_UUID_STRING;
  [self.sut channel:nil didPrepareLog:[MSACLogWithProperties new] internalId:uuid1 flags:MSACFlagsDefault];
  [self.sut channel:nil didPrepareLog:commonSchemaLog internalId:uuid2 flags:MSACFlagsDefault];

  // Don't buffer event if log is related to crash.
  [self.sut channel:nil didPrepareLog:[MSACAppleErrorLog new] internalId:uuid3 flags:MSACFlagsDefault];

  // Then
  assertThatLong([self crashesLogBufferCount], equalToLong(2));

  // When
  // Save on crash.
  ms_save_log_buffer();

  // Recreate crashes.
  [self.sut startWithChannelGroup:channelGroupMock appSecret:kMSACTestAppSecret transmissionTargetToken:nil fromApplication:YES];

  // Then
  XCTAssertEqual(2U, numInvocations);
}

- (void)testInitializationPriorityCorrect {
  XCTAssertTrue([[MSACCrashes sharedInstance] initializationPriority] == MSACInitializationPriorityMax);
}

// The Mach exception handler is not supported on tvOS.
#if TARGET_OS_TV
- (void)testMachExceptionHandlerDisabledOnTvOS {

  // Then
  XCTAssertFalse([[MSACCrashes sharedInstance] isMachExceptionHandlerEnabled]);
}
#else
- (void)testDisableMachExceptionWorks {

  // Then
  XCTAssertTrue([[MSACCrashes sharedInstance] isMachExceptionHandlerEnabled]);

  // When
  [MSACCrashes disableMachExceptionHandler];

  // Then
  XCTAssertFalse([[MSACCrashes sharedInstance] isMachExceptionHandlerEnabled]);

  // Then
  XCTAssertTrue([self.sut isMachExceptionHandlerEnabled]);

  // When
  [self.sut setEnableMachExceptionHandler:NO];

  // Then
  XCTAssertFalse([self.sut isMachExceptionHandlerEnabled]);
}

#endif

- (void)testAbstractErrorLogSerialization {
  MSACAbstractErrorLog *log = [MSACAbstractErrorLog new];

  // When
  NSDictionary *serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertFalse([static_cast<NSNumber *>(serializedLog[kMSACFatal]) boolValue]);

  // If
  log.fatal = NO;

  // When
  serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertFalse([static_cast<NSNumber *>(serializedLog[kMSACFatal]) boolValue]);

  // If
  log.fatal = YES;

  // When
  serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertTrue([static_cast<NSNumber *>(serializedLog[kMSACFatal]) boolValue]);
}

#pragma mark - Automatic Processing Tests

- (void)testSendOrAwaitWhenAlwaysSendIsTrue {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  [self.sut setAutomaticProcessingEnabled:NO];
  OCMStub([self.sut shouldAlwaysSend]).andReturn(YES);
  __block NSUInteger numInvocations = 0;
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsCritical])
      .andDo(^(NSInvocation *invocation) {
        (void)invocation;
        numInvocations++;
      });
  [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];
  NSMutableArray *reportIds = [self idListFromReports:[self.sut unprocessedCrashReports]];

  // When
  BOOL alwaysSendVal = [self.sut sendCrashReportsOrAwaitUserConfirmationForFilteredIds:reportIds];

  // Then
  XCTAssertEqual([reportIds count], numInvocations);
  XCTAssertTrue(alwaysSendVal);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testSendOrAwaitWhenAlwaysSendIsFalseAndNotifyAlwaysSend {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  [self.sut setAutomaticProcessingEnabled:NO];
  OCMStub([self.sut shouldAlwaysSend]).andReturn(NO);
  __block NSUInteger numInvocations = 0;
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsCritical])
      .andDo(^(NSInvocation *invocation) {
        (void)invocation;
        numInvocations++;
      });
  [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];
  NSMutableArray *reports = [self idListFromReports:[self.sut unprocessedCrashReports]];

  // When
  BOOL alwaysSendVal = [self.sut sendCrashReportsOrAwaitUserConfirmationForFilteredIds:reports];

  // Then
  XCTAssertEqual(numInvocations, 0U);
  XCTAssertFalse(alwaysSendVal);

  // When
  [self.sut notifyWithUserConfirmation:MSACUserConfirmationAlways];

  // Then
  XCTAssertEqual([reports count], numInvocations);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testSendOrAwaitWhenAlwaysSendIsFalseAndNotifySend {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  [self.sut setAutomaticProcessingEnabled:NO];
  OCMStub([self.sut shouldAlwaysSend]).andReturn(NO);
  __block NSUInteger numInvocations = 0;
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsCritical])
      .andDo(^(NSInvocation *invocation) {
        (void)invocation;
        numInvocations++;
      });
  [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];
  NSMutableArray *reportIds = [self idListFromReports:[self.sut unprocessedCrashReports]];

  // When
  BOOL alwaysSendVal = [self.sut sendCrashReportsOrAwaitUserConfirmationForFilteredIds:reportIds];

  // Then
  XCTAssertEqual(0U, numInvocations);
  XCTAssertFalse(alwaysSendVal);

  // When
  [self.sut notifyWithUserConfirmation:MSACUserConfirmationSend];

  // Then
  XCTAssertEqual([reportIds count], numInvocations);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testSendOrAwaitWhenAlwaysSendIsFalseAndNotifyDontSend {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  [self.sut setAutomaticProcessingEnabled:NO];
  [self.sut applyEnabledState:YES];
  OCMStub([self.sut shouldAlwaysSend]).andReturn(NO);
  __block int numInvocations = 0;
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsCritical])
      .andDo(^(NSInvocation *invocation) {
        (void)invocation;
        numInvocations++;
      });
  NSMutableArray *reportIds = [self idListFromReports:[self.sut unprocessedCrashReports]];

  // When
  BOOL alwaysSendVal = [self.sut sendCrashReportsOrAwaitUserConfirmationForFilteredIds:reportIds];
  [self.sut notifyWithUserConfirmation:MSACUserConfirmationDontSend];

  // Then
  XCTAssertFalse(alwaysSendVal);
  XCTAssertEqual(0, numInvocations);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:YES]);
}

- (void)testGetUnprocessedCrashReportsWhenThereAreNone {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self.sut setAutomaticProcessingEnabled:NO];
  [self startCrashes:self.sut withReports:NO withChannelGroup:channelGroupMock];

  // When
  NSArray<MSACErrorReport *> *reports = [self.sut unprocessedCrashReports];

  // Then
  XCTAssertEqual([reports count], 0U);
}

- (void)testSendErrorAttachments {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  [self.sut setAutomaticProcessingEnabled:NO];
  MSACErrorReport *report = OCMPartialMock([MSACErrorReport new]);
  OCMStub([report incidentIdentifier]).andReturn(@"incidentId");
  __block NSUInteger numInvocations = 0;
  __block NSMutableArray<MSACErrorAttachmentLog *> *enqueuedAttachments = [[NSMutableArray alloc] init];
  NSMutableArray<MSACErrorAttachmentLog *> *attachments = [[NSMutableArray alloc] init];
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]).andDo(^(NSInvocation *invocation) {
    numInvocations++;
    MSACErrorAttachmentLog *attachmentLog;
    [invocation getArgument:&attachmentLog atIndex:2];
    [enqueuedAttachments addObject:attachmentLog];
  });
  [self startCrashes:self.sut withReports:NO withChannelGroup:channelGroupMock];

  // When
  [attachments addObject:[[MSACErrorAttachmentLog alloc] initWithFilename:@"name" attachmentText:@"text1"]];
  [attachments addObject:[[MSACErrorAttachmentLog alloc] initWithFilename:@"name" attachmentText:@"text2"]];
  [attachments addObject:[[MSACErrorAttachmentLog alloc] initWithFilename:@"name" attachmentText:@"text3"]];
  [self.sut sendErrorAttachments:attachments withIncidentIdentifier:report.incidentIdentifier];

  // Then
  XCTAssertEqual([attachments count], numInvocations);
  for (MSACErrorAttachmentLog *log in enqueuedAttachments) {
    XCTAssertTrue([attachments containsObject:log]);
  }
}

- (void)testGetUnprocessedCrashReports {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self.sut setAutomaticProcessingEnabled:NO];
  NSArray *reports = [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];

  // When
  NSArray *retrievedReports = [self.sut unprocessedCrashReports];

  // Then
  XCTAssertEqual([reports count], [retrievedReports count]);
  for (MSACErrorReport *retrievedReport in retrievedReports) {
    BOOL foundReport = NO;
    for (MSACErrorReport *report in reports) {
      if ([report.incidentIdentifier isEqualToString:retrievedReport.incidentIdentifier]) {
        foundReport = YES;
        break;
      }
    }
    XCTAssertTrue(foundReport);
  }
}

- (void)testStartingCrashesWithoutAutomaticProcessing {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self.sut setAutomaticProcessingEnabled:NO];
  NSArray *reports = [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];

  // When
  NSArray *retrievedReports = [self.sut unprocessedCrashReports];

  // Then
  XCTAssertEqual([reports count], [retrievedReports count]);
  for (MSACErrorReport *retrievedReport in retrievedReports) {
    BOOL foundReport = NO;
    for (MSACErrorReport *report in reports) {
      if ([report.incidentIdentifier isEqualToString:retrievedReport.incidentIdentifier]) {
        foundReport = YES;
        break;
      }
    }
    XCTAssertTrue(foundReport);
  }
}

- (void)testStartingCrashesWithAutomaticProcessing {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];

  // When
  NSArray *retrievedReports = [self.sut unprocessedCrashReports];

  // Then
  XCTAssertEqual([retrievedReports count], 0U);
}

- (void)testErrorOnIncorrectNotifyWithUserConfirmationCall {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self startCrashes:self.sut withReports:YES withChannelGroup:channelGroupMock];

  // Then
  OCMReject([self.sut handleUserConfirmation:MSACUserConfirmationAlways]);

  // When
  [self.sut notifyWithUserConfirmation:MSACUserConfirmationAlways];
}

- (void)testCrashesSetCorrectUserIdToLogs {

  // Wait for creation of buffers to avoid corruption on OCMPartialMock.
  dispatch_group_wait(self.sut.bufferFileGroup, DISPATCH_TIME_FOREVER);

  // If
  __block XCTestExpectation *expectation = [self expectationWithDescription:@"Channel received a log"];
  __block NSString *expectedUserId = @"bob";
  __block NSString *actualUserId;
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut startDelayedCrashProcessing]).andDo(nil);
  id channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  assertThatBool([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsCritical]).andDo(^(NSInvocation *invocation) {
    MSACAbstractLog *log;
    [invocation getArgument:&log atIndex:2];
    actualUserId = log.userId;
    [expectation fulfill];
  });
  [self.sut startWithChannelGroup:channelGroupMock appSecret:kMSACTestAppSecret transmissionTargetToken:nil fromApplication:YES];

  // Mock history
  MSACMockUserDefaults *settings = [MSACMockUserDefaults new];
  __block NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  __block NSDate *date;

  // When
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    // 5 mins ago.
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setYear:2013];
    [dateComponents setMonth:9];
    [dateComponents setDay:25];
    [dateComponents setHour:10];
    [dateComponents setMinute:50];
    [dateComponents setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    date = [calendar dateFromComponents:dateComponents];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"alice"];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];
  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    // 1 mins ago.
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setYear:2013];
    [dateComponents setMonth:9];
    [dateComponents setDay:25];
    [dateComponents setHour:10];
    [dateComponents setMinute:54];
    [dateComponents setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    date = [calendar dateFromComponents:dateComponents];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];
  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    // 5 mins after.
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setYear:2013];
    [dateComponents setMonth:9];
    [dateComponents setDay:25];
    [dateComponents setHour:11];
    [dateComponents setMinute:0];
    [dateComponents setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    date = [calendar dateFromComponents:dateComponents];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"charlie"];
  [dateMock stopMocking];

  // Process crash.
  [self.sut startCrashProcessing];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // The fixture's timestamp is 2013-09-25 10:55:49
                                 XCTAssertEqualObjects(actualUserId, expectedUserId);
                               }];

  [settings stopMocking];
}

#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST

- (void)testMemoryWarningObserverNotExtension {

  // If
  id defaultCenterMock = OCMClassMock([NSNotificationCenter class]);
  OCMStub([defaultCenterMock defaultCenter]).andReturn(defaultCenterMock);

  // When
  [self.sut applyEnabledState:YES];

  // Then
  OCMVerify([defaultCenterMock addObserver:self.sut
                                  selector:[OCMArg anySelector]
                                      name:UIApplicationDidReceiveMemoryWarningNotification
                                    object:nil]);

  // When
  [self.sut applyEnabledState:NO];

  // Then
  OCMVerify([defaultCenterMock removeObserver:self.sut]);

  // Clear
  [defaultCenterMock stopMocking];
}

#endif

- (void)testMemoryPressureSourceInExtensionAndMacOS {

  // If
#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
  id bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock mainBundle]).andReturn(bundleMock);
  OCMStub([bundleMock executablePath]).andReturn(@"/Application/Executable/Path.appex/42");
#endif

  // When
  [self.sut applyEnabledState:YES];

  // Then
  XCTAssertNotNil(self.sut.memoryPressureSource);

  // When
  [self.sut applyEnabledState:NO];

  // Then
  XCTAssertNil(self.sut.memoryPressureSource);

  // Clear
#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
  [bundleMock stopMocking];
#endif
}

- (void)testDidReceiveMemoryWarning {

  // If
  id crashes = OCMPartialMock(self.sut);
  OCMStub([crashes startDelayedCrashProcessing]).andDo(nil);
  OCMStub([crashes sharedInstance]).andReturn(crashes);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  MSACMockUserDefaults *settings = [MSACMockUserDefaults new];

  // Then
  XCTAssertFalse([MSACCrashes hasReceivedMemoryWarningInLastSession]);

  // When
  [crashes didReceiveMemoryWarning:nil];

  // Then
  XCTAssertFalse([MSACCrashes hasReceivedMemoryWarningInLastSession]);
  XCTAssertTrue(((NSNumber *)[settings objectForKey:kMSACAppDidReceiveMemoryWarningKey]).boolValue);

  // When
  [crashes startWithChannelGroup:channelGroupMock appSecret:kMSACTestAppSecret transmissionTargetToken:nil fromApplication:YES];

  // Then
  XCTAssertTrue([MSACCrashes hasReceivedMemoryWarningInLastSession]);
  XCTAssertFalse(((NSNumber *)[settings objectForKey:kMSACAppDidReceiveMemoryWarningKey]).boolValue);

  // Clear
  [settings stopMocking];
}

#pragma mark Helper

/**
 * Start Crashes (self.sut) with zero or one crash files on disk.
 */
- (NSMutableArray<MSACErrorReport *> *)startCrashes:(MSACCrashes *)crashes
                                        withReports:(BOOL)startWithReports
                                   withChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup {
  NSMutableArray<MSACErrorReport *> *reports = [NSMutableArray<MSACErrorReport *> new];
  if (startWithReports) {
    for (NSString *fileName in @[ @"live_report_exception" ]) {
      XCTAssertTrue([MSACCrashesTestUtil copyFixtureCrashReportWithFileName:fileName]);
      NSData *data = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:fileName];
      NSError *error;
      PLCrashReport *report = [[PLCrashReport alloc] initWithData:data error:&error];
      [reports addObject:[MSACErrorLogFormatter errorReportFromCrashReport:report]];
    }
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"Start the Crashes module"];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [crashes startWithChannelGroup:channelGroup appSecret:kMSACTestAppSecret transmissionTargetToken:nil fromApplication:YES];
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 if (startWithReports) {
                                   assertThat(crashes.crashFiles, hasCountOf(1));
                                 }
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  return reports;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
- (NSArray<MSACErrorAttachmentLog *> *)attachmentsWithCrashes:(MSACCrashes *)crashes forErrorReport:(MSACErrorReport *)errorReport {
  id deviceMock = OCMPartialMock([MSACDevice new]);
  OCMStub([deviceMock isValid]).andReturn(YES);

  NSMutableArray *logs = [NSMutableArray new];
  for (unsigned int i = 0; i < kAttachmentsPerCrashReport; ++i) {
    NSString *text = [NSString stringWithFormat:@"%d", i];
    MSACErrorAttachmentLog *log = [[MSACErrorAttachmentLog alloc] initWithFilename:text attachmentText:text];
    log.timestamp = [NSDate dateWithTimeIntervalSince1970:42];
    log.device = deviceMock;
    [logs addObject:log];
  }
  return logs;
}
#pragma clang diagnostic pop

- (NSInteger)crashesLogBufferCount {
  NSInteger bufferCount = 0;
  for (auto it = msACCrashesLogBuffer.begin(), end = msACCrashesLogBuffer.end(); it != end; ++it) {
    if (!it->internalId.empty()) {
      bufferCount++;
    }
  }
  return bufferCount;
}

- (MSACErrorAttachmentLog *)attachmentWithAttachmentId:(NSString *)attachmentId
                                        attachmentData:(NSData *)attachmentData
                                           contentType:(NSString *)contentType {
  MSACErrorAttachmentLog *log = [MSACErrorAttachmentLog alloc];
  log.attachmentId = attachmentId;
  log.data = attachmentData;
  log.contentType = contentType;
  return log;
}

- (NSMutableArray *)idListFromReports:(NSArray *)reports {
  NSMutableArray *ids = [NSMutableArray new];
  for (MSACErrorReport *report in reports) {
    [ids addObject:report.incidentIdentifier];
  }
  return ids;
}

@end
