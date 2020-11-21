// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenterInternal.h"
#import "MSACChannelGroupProtocol.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitProtocol.h"
#import "MSACCrashesInternal.h"
#import "MSACCrashesPrivate.h"
#import "MSACCrashesTestUtil.h"
#import "MSACCrashesUtil.h"
#import "MSACDeviceTrackerPrivate.h"
#import "MSACErrorAttachmentLog.h"
#import "MSACException.h"
#import "MSACHandledErrorLog.h"
#import "MSACHttpClient.h"
#import "MSACLogWithProperties.h"
#import "MSACTestFrameworks.h"
#import "MSACWrapperCrashesHelper.h"
#import "MSAC_Reachability.h"

@interface MSACWrapperCrashesHelperTests : XCTestCase

@property(nonatomic) id httpClientMock;
@property(nonatomic) id reachabilityMock;
@property(nonatomic) id deviceTrackerMock;

@end

static NSString *const kMSACTestAppSecret = @"TestAppSecret";
static NSString *const kMSACTypeHandledError = @"handledError";

@implementation MSACWrapperCrashesHelperTests

- (void)setUp {
  self.httpClientMock = OCMClassMock([MSACHttpClient class]);
  OCMStub([self.httpClientMock alloc]).andReturn(self.httpClientMock);
  self.reachabilityMock = OCMClassMock([MSAC_Reachability class]);
  OCMStub([self.reachabilityMock reachabilityForInternetConnection]).andReturn(self.reachabilityMock);
  [MSACDeviceTracker resetSharedInstance];
  self.deviceTrackerMock = OCMClassMock([MSACDeviceTracker class]);
  OCMStub([self.deviceTrackerMock sharedInstance]).andReturn(self.deviceTrackerMock);
}

- (void)tearDown {
  [super tearDown];
  [self.httpClientMock stopMocking];
  [self.reachabilityMock stopMocking];
  [self.deviceTrackerMock stopMocking];
  [MSACDeviceTracker resetSharedInstance];
  [MSACCrashes resetSharedInstance];
}

- (void)testSettingAndGettingDelegateWorks {

  // If
  id<MSACCrashHandlerSetupDelegate> delegateMock = OCMProtocolMock(@protocol(MSACCrashHandlerSetupDelegate));
  [MSACWrapperCrashesHelper setCrashHandlerSetupDelegate:delegateMock];

  // When
  id<MSACCrashHandlerSetupDelegate> retrievedDelegate = [MSACWrapperCrashesHelper crashHandlerSetupDelegate];

  // Then
  assertThat(delegateMock, equalTo(retrievedDelegate));
}

- (void)testTrackModelExceptionWithExceptionOnly {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSACException *exception;
  NSString *expectedUserId = @"alice";
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSACChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [MSACAppCenter setUserId:expectedUserId];
  [[MSACCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                            appSecret:kMSACTestAppSecret
                              transmissionTargetToken:nil
                                      fromApplication:YES];

  // When
  MSACException *expectedException = [MSACException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSString *actualErrorId = [MSACWrapperCrashesHelper trackModelException:expectedException withProperties:nil withAttachments:nil];

  // Then
  assertThat(type, is(kMSACTypeHandledError));
  assertThat(userId, is(expectedUserId));
  assertThat(errorId, notNilValue());
  assertThat(exception, is(expectedException));

  // Verify the errorId returned by trackModelException is the same one that enqueued to the channel.
  assertThat(actualErrorId, is(errorId));
}

- (void)testTrackModelExceptionWithExceptionAndProperties {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSACException *exception;
  __block NSDictionary<NSString *, NSString *> *properties;
  NSString *expectedUserId = @"alice";
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSACChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
        properties = log.properties;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [MSACAppCenter setUserId:expectedUserId];
  [[MSACCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                            appSecret:kMSACTestAppSecret
                              transmissionTargetToken:nil
                                      fromApplication:YES];

  // When
  MSACException *expectedException = [MSACException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSDictionary *expectedProperties = @{@"milk" : @"yes", @"cookie" : @"of course"};
  NSString *actualErrorId = [MSACWrapperCrashesHelper trackModelException:expectedException
                                                           withProperties:expectedProperties
                                                          withAttachments:nil];

  // Then
  assertThat(type, is(kMSACTypeHandledError));
  assertThat(userId, is(expectedUserId));
  assertThat(errorId, notNilValue());
  assertThat(exception, is(expectedException));
  assertThat(properties, is(expectedProperties));

  // Verify the errorId returned by trackModelException is the same one that enqueued to the channel.
  assertThat(actualErrorId, is(errorId));
}

- (void)testTrackModelExceptionWithExceptionAndAttachments {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSACException *exception;
  __block NSMutableArray<MSACErrorAttachmentLog *> *errorAttachmentLogs = [NSMutableArray new];
  NSString *expectedUserId = @"alice";
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSACChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACHandledErrorLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
      });
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACErrorAttachmentLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACErrorAttachmentLog *log;
        [invocation getArgument:&log atIndex:2];
        [errorAttachmentLogs addObject:log];
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [MSACAppCenter setUserId:expectedUserId];
  [[MSACCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                            appSecret:kMSACTestAppSecret
                              transmissionTargetToken:nil
                                      fromApplication:YES];
  NSData *expectedData = [@"<file><request>Please attach me</request><reason>I am a nice "
                          @"data.</reason></file>" dataUsingEncoding:NSUTF8StringEncoding];
  MSACErrorAttachmentLog *errorAttachmentLog1 = [[MSACErrorAttachmentLog alloc] initWithFilename:@"text.txt"
                                                                                  attachmentText:@"Please attach me, I am a nice text."];
  MSACErrorAttachmentLog *errorAttachmentLog2 = [[MSACErrorAttachmentLog alloc] initWithFilename:@"binary.xml"
                                                                                attachmentBinary:expectedData
                                                                                     contentType:@"text/xml"];
  NSArray<MSACErrorAttachmentLog *> *attachments = @[ errorAttachmentLog1, errorAttachmentLog2 ];

  // When
  MSACException *expectedException = [MSACException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSString *actualErrorId = [MSACWrapperCrashesHelper trackModelException:expectedException withProperties:nil withAttachments:attachments];

  // Then
  XCTAssertEqual(type, kMSACTypeHandledError);
  XCTAssertEqualObjects(userId, expectedUserId);
  XCTAssertNotNil(errorId);
  XCTAssertEqualObjects(exception, expectedException);
  XCTAssertEqual([errorAttachmentLogs count], [attachments count]);
  XCTAssertEqualObjects(errorAttachmentLogs[0], errorAttachmentLog1);
  XCTAssertEqualObjects(errorAttachmentLogs[1], errorAttachmentLog2);

  // Verify the errorId returned by trackModelException is the same one that enqueued to the channel.
  XCTAssertEqualObjects(actualErrorId, errorId);
}

- (void)testTrackModelExceptionWithAllParameters {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSACException *exception;
  __block NSDictionary<NSString *, NSString *> *properties;
  __block NSMutableArray<MSACErrorAttachmentLog *> *errorAttachmentLogs = [NSMutableArray new];
  NSString *expectedUserId = @"alice";
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSACChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSACChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACHandledErrorLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
        properties = log.properties;
      });
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACErrorAttachmentLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACErrorAttachmentLog *log;
        [invocation getArgument:&log atIndex:2];
        [errorAttachmentLogs addObject:log];
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [MSACAppCenter setUserId:expectedUserId];
  [[MSACCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                            appSecret:kMSACTestAppSecret
                              transmissionTargetToken:nil
                                      fromApplication:YES];
  NSData *expectedData = [@"<file><request>Please attach me</request><reason>I am a nice "
                          @"data.</reason></file>" dataUsingEncoding:NSUTF8StringEncoding];
  MSACErrorAttachmentLog *errorAttachmentLog1 = [[MSACErrorAttachmentLog alloc] initWithFilename:@"text.txt"
                                                                                  attachmentText:@"Please attach me, I am a nice text."];
  MSACErrorAttachmentLog *errorAttachmentLog2 = [[MSACErrorAttachmentLog alloc] initWithFilename:@"binary.xml"
                                                                                attachmentBinary:expectedData
                                                                                     contentType:@"text/xml"];
  NSArray<MSACErrorAttachmentLog *> *attachments = @[ errorAttachmentLog1, errorAttachmentLog2 ];

  // When
  MSACException *expectedException = [MSACException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSDictionary *expectedProperties = @{@"milk" : @"yes", @"cookie" : @"of course"};
  NSString *actualErrorId = [MSACWrapperCrashesHelper trackModelException:expectedException
                                                           withProperties:expectedProperties
                                                          withAttachments:attachments];

  // Then
  XCTAssertEqual(type, kMSACTypeHandledError);
  XCTAssertEqualObjects(userId, expectedUserId);
  XCTAssertNotNil(errorId);
  XCTAssertEqualObjects(exception, expectedException);
  XCTAssertEqualObjects(properties, expectedProperties);
  XCTAssertEqual([errorAttachmentLogs count], [attachments count]);
  XCTAssertEqualObjects(errorAttachmentLogs[0], errorAttachmentLog1);
  XCTAssertEqualObjects(errorAttachmentLogs[1], errorAttachmentLog2);

  // Verify the errorId returned by trackModelException is the same one that enqueued to the channel.
  XCTAssertEqualObjects(actualErrorId, errorId);
}

@end
