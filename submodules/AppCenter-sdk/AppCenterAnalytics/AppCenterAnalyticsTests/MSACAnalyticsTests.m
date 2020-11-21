// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalytics+Validation.h"
#import "MSACAnalyticsCategory.h"
#import "MSACAnalyticsPrivate.h"
#import "MSACAnalyticsTransmissionTargetPrivate.h"
#import "MSACAppCenter.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppCenterPrivate.h"
#import "MSACAppCenterUserDefaultsPrivate.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACChannelGroupDefault.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACChannelUnitDefault.h"
#import "MSACConstants+Internal.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventLog.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACMockUserDefaults.h"
#import "MSACPageLog.h"
#import "MSACSessionContextPrivate.h"
#import "MSACSessionTrackerPrivate.h"
#import "MSACStringTypedProperty.h"
#import "MSACTestFrameworks.h"

static NSString *const kMSACAnalyticsGroupId = @"Analytics";
static NSString *const kMSACTypeEvent = @"event";
static NSString *const kMSACTypePage = @"page";
static NSString *const kMSACTestAppSecret = @"TestAppSecret";
static NSString *const kMSACTestTransmissionToken = @"AnalyticsTestTransmissionToken";
static NSString *const kMSACTestTransmissionToken2 = @"AnalyticsTestTransmissionToken2";
static NSString *const kMSACAnalyticsServiceName = @"Analytics";

@class MSACMockAnalyticsDelegate;

@interface MSACAnalyticsTests : XCTestCase <MSACAnalyticsDelegate>

@property(nonatomic) MSACMockUserDefaults *settingsMock;
@property(nonatomic) id sessionContextMock;
@property(nonatomic) id channelGroupMock;
@property(nonatomic) id channelUnitMock;
@property(nonatomic) id channelUnitCriticalMock;

@end

@interface MSACServiceAbstract ()

- (BOOL)isEnabled;

- (void)setEnabled:(BOOL)enabled;

@end

@interface MSACAnalytics ()

- (BOOL)channelUnit:(id<MSACChannelUnitProtocol>)channelUnit shouldFilterLog:(id<MSACLog>)log;

@end

/*
 * FIXME: Log manager mock is holding sessionTracker instance even after dealloc and this causes session tracker test failures. There is a
 * PR in OCMock that seems a related issue. https://github.com/erikdoe/ocmock/pull/348 Stopping session tracker after applyEnabledState
 * calls for hack to avoid failures.
 */
@implementation MSACAnalyticsTests

- (void)setUp {
  [super setUp];
  [MSACAppCenter resetSharedInstance];

  // Mock NSUserDefaults.
  self.settingsMock = [MSACMockUserDefaults new];

  // Mock session context.
  [MSACSessionContext resetSharedInstance];
  self.sessionContextMock = OCMClassMock([MSACSessionContext class]);
  OCMStub([self.sessionContextMock sharedInstance]).andReturn(self.sessionContextMock);

  // Mock channel.
  self.channelGroupMock = OCMClassMock([MSACChannelGroupDefault class]);
  self.channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  self.channelUnitCriticalMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  [MSACAnalytics sharedInstance].criticalChannelUnit = self.channelUnitCriticalMock;
  OCMStub([self.channelGroupMock alloc]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:OCMOCK_ANY]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:hasProperty(@"groupId", endsWith(kMSACCriticalChannelSuffix))])
      .andReturn(self.channelUnitCriticalMock);
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:hasProperty(@"groupId", equalTo(kMSACAnalyticsGroupId))])
      .andReturn(self.channelUnitMock);
}

- (void)tearDown {
  [MSACSessionContext resetSharedInstance];
  [MSACAnalytics resetSharedInstance];
  [self.settingsMock stopMocking];
  [self.sessionContextMock stopMocking];
  [super tearDown];
}

#pragma mark - Tests

- (void)testMigrateOnInit {
  NSString *key = [NSString stringWithFormat:kMSACMockMigrationKey, @"Analytics"];
  XCTAssertNotNil([self.settingsMock objectForKey:key]);
}

- (void)testValidateEventName {
  const int maxEventNameLength = 256;

  // If
  NSString *validEventName = @"validEventName";
  NSString *shortEventName = @"e";
  NSString *eventName256 = [@"" stringByPaddingToLength:maxEventNameLength withString:@"eventName256" startingAtIndex:0];
  NSString *nullableEventName = nil;
  NSString *emptyEventName = @"";
  NSString *tooLongEventName = [@"" stringByPaddingToLength:(maxEventNameLength + 1) withString:@"tooLongEventName" startingAtIndex:0];

  // When
  NSString *valid = [[MSACAnalytics sharedInstance] validateEventName:validEventName forLogType:kMSACTypeEvent];
  NSString *validShortEventName = [[MSACAnalytics sharedInstance] validateEventName:shortEventName forLogType:kMSACTypeEvent];
  NSString *validEventName256 = [[MSACAnalytics sharedInstance] validateEventName:eventName256 forLogType:kMSACTypeEvent];
  NSString *validNullableEventName = [[MSACAnalytics sharedInstance] validateEventName:nullableEventName forLogType:kMSACTypeEvent];
  NSString *validEmptyEventName = [[MSACAnalytics sharedInstance] validateEventName:emptyEventName forLogType:kMSACTypeEvent];
  NSString *validTooLongEventName = [[MSACAnalytics sharedInstance] validateEventName:tooLongEventName forLogType:kMSACTypeEvent];

  // Then
  XCTAssertNotNil(valid);
  XCTAssertNotNil(validShortEventName);
  XCTAssertNotNil(validEventName256);
  XCTAssertNil(validNullableEventName);
  XCTAssertNil(validEmptyEventName);
  XCTAssertNotNil(validTooLongEventName);
  XCTAssertEqual([validTooLongEventName length], maxEventNameLength);
}

- (void)testApplyEnabledStateWorks {
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  MSACServiceAbstract *service = [MSACAnalytics sharedInstance];

  [service setEnabled:YES];
  XCTAssertTrue([service isEnabled]);

  [service setEnabled:NO];
  XCTAssertFalse([service isEnabled]);

  [service setEnabled:YES];
  XCTAssertTrue([service isEnabled]);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testSetTransmissionIntervalApplied {

  // If
  NSUInteger testInterval = 5;

  // When
  [MSACAnalytics setTransmissionInterval:testInterval];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // Then
  OCMVerify(
      [self.channelGroupMock addChannelUnitWithConfiguration:allOf(hasProperty(@"flushInterval", equalToUnsignedInteger(testInterval)),
                                                                   hasProperty(@"groupId", equalTo(kMSACAnalyticsGroupId)), nil)]);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testSetTransmissionIntervalNotApplied {

  // If
  NSUInteger testInterval = 2;

  // When
  [MSACAnalytics setTransmissionInterval:testInterval];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // Then
  OCMVerify([self.channelGroupMock addChannelUnitWithConfiguration:allOf(hasProperty(@"flushInterval", equalToUnsignedInteger(3)),
                                                                         hasProperty(@"groupId", equalTo(kMSACAnalyticsGroupId)), nil)]);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testSetTransmissionIntervalNotAppliedIfHigherThanDay {

  // If
  NSUInteger testInterval = 25 * 60 * 60;

  // When
  [MSACAnalytics setTransmissionInterval:testInterval];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // Then
  OCMVerify([self.channelGroupMock addChannelUnitWithConfiguration:allOf(hasProperty(@"flushInterval", equalToUnsignedInteger(3)),
                                                                         hasProperty(@"groupId", equalTo(kMSACAnalyticsGroupId)), nil)]);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testSetTransmissionIntervalNotAppliedAfterStart {

  // If
  NSUInteger testInterval = 5;
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));

  // When
  [[MSACAnalytics sharedInstance] startWithChannelGroup:channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // Make sure that interval is not set after service start.
  [MSACAnalytics setTransmissionInterval:testInterval];

  // Then
  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
  XCTAssertNotEqual([MSACAnalytics sharedInstance].flushInterval, testInterval);
}

- (void)testDisablingAnalyticsClearsSessionHistory {
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  MSACServiceAbstract *service = [MSACAnalytics sharedInstance];

  [service setEnabled:NO];
  XCTAssertFalse([service isEnabled]);

  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:NO]);
}

- (void)testTrackPageCalledWhenAutoPageTrackingEnabled {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  id analyticsCategoryMock = OCMClassMock([MSACAnalyticsCategory class]);
  NSString *testPageName = @"TestPage";
  OCMStub([analyticsCategoryMock missedPageViewName]).andReturn(testPageName);
  [MSACAnalytics setAutoPageTrackingEnabled:YES];
  MSACServiceAbstract *service = [MSACAnalytics sharedInstance];
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];

  // When
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for block in applyEnabledState to be dispatched"];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertTrue([service isEnabled]);
                                 OCMVerify([analyticsMock trackPage:testPageName withProperties:nil]);
                               }];
}

- (void)testSettingDelegateWorks {
  id<MSACAnalyticsDelegate> delegateMock = OCMProtocolMock(@protocol(MSACAnalyticsDelegate));
  [MSACAnalytics setDelegate:delegateMock];
  XCTAssertNotNil([MSACAnalytics sharedInstance].delegate);
  XCTAssertEqual([MSACAnalytics sharedInstance].delegate, delegateMock);
}

- (void)testAnalyticsDelegateWithoutImplementations {

  // If
  [MSACAnalytics setDelegate:self];

  // When
  MSACEventLog *eventLog = [MSACEventLog new];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock willSendLog:eventLog];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock didSucceedSendingLog:eventLog];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock didFailSendingLog:eventLog withError:nil];

  // Then - no crashes
}

- (void)testAnalyticsDelegateMethodsAreCalled {

  // If
  id<MSACAnalyticsDelegate> delegateMock = OCMProtocolMock(@protocol(MSACAnalyticsDelegate));
  [MSACAnalytics setDelegate:delegateMock];

  // When
  MSACEventLog *eventLog = [MSACEventLog new];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock willSendLog:eventLog];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock didSucceedSendingLog:eventLog];
  [[MSACAnalytics sharedInstance] channel:self.channelUnitMock didFailSendingLog:eventLog withError:nil];

  // Then
  OCMVerify([delegateMock analytics:[MSACAnalytics sharedInstance] willSendEventLog:eventLog]);
  OCMVerify([delegateMock analytics:[MSACAnalytics sharedInstance] didSucceedSendingEventLog:eventLog]);
  OCMVerify([delegateMock analytics:[MSACAnalytics sharedInstance] didFailSendingEventLog:eventLog withError:nil]);
}

- (void)testAnalyticsLogsVerificationIsCalled {

  // If
  MSACEventLog *eventLog = [MSACEventLog new];
  eventLog.name = @"test";
  eventLog.properties = @{@"test" : @"test"};
  MSACPageLog *pageLog = [MSACPageLog new];
  MSACLogWithNameAndProperties *analyticsLog = [MSACLogWithNameAndProperties new];
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMExpect([analyticsMock validateLog:eventLog]).andForwardToRealObject();
  OCMExpect([analyticsMock validateEventName:@"test" forLogType:@"event"]).andForwardToRealObject();
  OCMExpect([analyticsMock validateProperties:OCMOCK_ANY forLogName:@"test" andType:@"event"]).andForwardToRealObject();
  OCMExpect([analyticsMock validateLog:pageLog]).andForwardToRealObject();
  OCMExpect([analyticsMock validateEventName:OCMOCK_ANY forLogType:@"page"]).andForwardToRealObject();
  OCMReject([analyticsMock validateProperties:OCMOCK_ANY forLogName:OCMOCK_ANY andType:@"page"]);
  OCMReject([analyticsMock validateLog:analyticsLog]);

  // When
  [[MSACAnalytics sharedInstance] channelUnit:nil shouldFilterLog:eventLog];
  [[MSACAnalytics sharedInstance] channelUnit:nil shouldFilterLog:pageLog];
  [[MSACAnalytics sharedInstance] channelUnit:nil shouldFilterLog:analyticsLog];

  // Then
  OCMVerifyAll(analyticsMock);
}

- (void)testAnalyticsLogsVerificationIsCalledWithWrongClass {

  // If
  NSObject *notAnalyticsLog = [NSObject new];

  // When
  BOOL wrongClass = [MSACLogWithNameAndProperties isEqual:notAnalyticsLog];
  BOOL wrongType = [MSACLogWithNameAndProperties isEqual:@"invalid equal test"];

  // Then
  XCTAssertFalse(wrongClass);
  XCTAssertFalse(wrongType);
}

- (void)testTrackEventWithoutProperties {

  // If
  __block NSString *name;
  __block NSString *type;
  NSString *expectedName = @"gotACoffee";
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName];

  // Then
  assertThat(type, is(kMSACTypeEvent));
  assertThat(name, is(expectedName));
}

- (void)testTrackEventWithPropertiesNilWhenAnalyticsDisabled {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsMock isEnabled]).andReturn(NO);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMReject([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withProperties:nil forTransmissionTarget:nil flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testTrackEventWithTypedPropertiesNilWhenAnalyticsDisabled {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsMock isEnabled]).andReturn(NO);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMReject([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withTypedProperties:nil forTransmissionTarget:nil flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testTrackEventWithPropertiesNilWhenTransmissionTargetDisabled {

  // If
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMReject([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"test"];
  [target setEnabled:NO];
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withProperties:nil forTransmissionTarget:target flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testTrackEventWithPropertiesWhenTransmissionTargetProvided {

  // If
  __block NSUInteger propertiesCount = 0;
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        propertiesCount = log.typedProperties.properties.count;
      });

  // When
  NSMutableDictionary *properties = [NSMutableDictionary new];
  for (int i = 0; i < 100; i++) {
    properties[[@"prop" stringByAppendingFormat:@"%d", i]] = [@"val" stringByAppendingFormat:@"%d", i];
  }
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"test"];
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withProperties:properties forTransmissionTarget:target flags:MSACFlagsDefault];

  // Then
  XCTAssertEqual(properties.count, propertiesCount);
}

- (void)testTrackEventSetsTagWhenTransmissionTargetProvided {

  // If
  __block NSObject *tag;
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        tag = log.tag;
      });

  // When
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"test"];
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withProperties:nil forTransmissionTarget:target flags:MSACFlagsDefault];

  // Then
  XCTAssertEqualObjects(tag, target);
}

- (void)testTrackEventDoesNotSetUserIdForAppCenter {

  // If
  __block MSACEventLog *log;
  [MSACAppCenter setUserId:@"c:test"];
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&log atIndex:2];
      });

  // When
  [MSACAnalytics trackEvent:@"Some event"];

  // Then
  XCTAssertNotNil(log);
  XCTAssertNil(log.userId);
}

- (void)testTrackEventWithTypedPropertiesNilWhenTransmissionTargetDisabled {

  // If
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMReject([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"test"];
  [target setEnabled:NO];
  [[MSACAnalytics sharedInstance] trackEvent:@"Some event" withTypedProperties:nil forTransmissionTarget:target flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);

  // FIXME: logManager holds session tracker somehow and it causes other test failures. Stop it for hack.
  [[MSACAnalytics sharedInstance].sessionTracker stop];
}

- (void)testTrackEventWithPropertiesNilAndInvalidName {

  // If
  NSString *invalidEventName = nil;
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMExpect([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);

  // Will be validated in shouldFilterLog callback instead.
  OCMReject([analyticsMock validateEventName:OCMOCK_ANY forLogType:OCMOCK_ANY]);
  OCMReject([analyticsMock validateProperties:OCMOCK_ANY forLogName:OCMOCK_ANY andType:OCMOCK_ANY]);
  [[MSACAnalytics sharedInstance] trackEvent:invalidEventName withProperties:nil forTransmissionTarget:nil flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);
  OCMVerifyAll(analyticsMock);
}

- (void)testTrackEventWithTypedPropertiesNilAndInvalidName {

  // If
  NSString *invalidEventName = nil;
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMExpect([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);

  // Will be validated in shouldFilterLog callback instead.
  OCMReject([analyticsMock validateEventName:OCMOCK_ANY forLogType:OCMOCK_ANY]);
  OCMReject([analyticsMock validateProperties:OCMOCK_ANY forLogName:OCMOCK_ANY andType:OCMOCK_ANY]);
  [[MSACAnalytics sharedInstance] trackEvent:invalidEventName withTypedProperties:nil forTransmissionTarget:nil flags:MSACFlagsDefault];

  // Then
  OCMVerifyAll(self.channelUnitMock);
  OCMVerifyAll(analyticsMock);
}

- (void)testTrackEventWithProperties {

  // If
  __block NSString *type;
  __block NSString *name;
  __block MSACEventProperties *eventProperties;
  NSString *expectedName = @"gotACoffee";
  NSDictionary *expectedProperties = @{@"milk" : @"yes", @"cookie" : @"of course"};
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
        eventProperties = log.typedProperties;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withProperties:expectedProperties];

  // Then
  assertThat(type, is(kMSACTypeEvent));
  assertThat(name, is(expectedName));
  for (MSACTypedProperty *typedProperty in [eventProperties.properties objectEnumerator]) {
    assertThat(typedProperty, isA([MSACStringTypedProperty class]));
    MSACStringTypedProperty *stringTypedProperty = (MSACStringTypedProperty *)typedProperty;
    assertThat(stringTypedProperty.value, equalTo(expectedProperties[stringTypedProperty.name]));
  }
  XCTAssertEqual([expectedProperties count], [eventProperties.properties count]);
}

- (void)testTrackEventWithTypedProperties {

  // If
  __block NSString *type;
  __block NSString *name;
  __block MSACEventProperties *eventProperties;
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  [expectedProperties setString:@"string" forKey:@"stringKey"];
  [expectedProperties setBool:YES forKey:@"boolKey"];
  [expectedProperties setDate:[NSDate new] forKey:@"dateKey"];
  [expectedProperties setInt64:123 forKey:@"longKey"];
  [expectedProperties setDouble:1.23e2 forKey:@"doubleKey"];
  NSString *expectedName = @"gotACoffee";
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
        eventProperties = log.typedProperties;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withTypedProperties:expectedProperties];

  // Then
  assertThat(type, is(kMSACTypeEvent));
  assertThat(name, is(expectedName));

  for (NSString *propertyKey in eventProperties.properties) {
    MSACTypedProperty *typedProperty = eventProperties.properties[propertyKey];
    XCTAssertEqual(typedProperty.name, propertyKey);
    if ([typedProperty isKindOfClass:[MSACBooleanTypedProperty class]]) {
      MSACBooleanTypedProperty *expectedProperty = (MSACBooleanTypedProperty *)expectedProperties.properties[propertyKey];
      MSACBooleanTypedProperty *property = (MSACBooleanTypedProperty *)eventProperties.properties[propertyKey];
      XCTAssertEqual(property.value, expectedProperty.value);
    } else if ([typedProperty isKindOfClass:[MSACDoubleTypedProperty class]]) {
      MSACDoubleTypedProperty *expectedProperty = (MSACDoubleTypedProperty *)expectedProperties.properties[propertyKey];
      MSACDoubleTypedProperty *property = (MSACDoubleTypedProperty *)eventProperties.properties[propertyKey];
      XCTAssertEqual(property.value, expectedProperty.value);
    } else if ([typedProperty isKindOfClass:[MSACLongTypedProperty class]]) {
      MSACLongTypedProperty *expectedProperty = (MSACLongTypedProperty *)expectedProperties.properties[propertyKey];
      MSACLongTypedProperty *property = (MSACLongTypedProperty *)eventProperties.properties[propertyKey];
      XCTAssertEqual(property.value, expectedProperty.value);
    } else if ([typedProperty isKindOfClass:[MSACStringTypedProperty class]]) {
      MSACStringTypedProperty *expectedProperty = (MSACStringTypedProperty *)expectedProperties.properties[propertyKey];
      MSACStringTypedProperty *property = (MSACStringTypedProperty *)eventProperties.properties[propertyKey];
      XCTAssertEqualObjects(property.value, expectedProperty.value);
    } else if ([typedProperty isKindOfClass:[MSACDateTimeTypedProperty class]]) {
      MSACDateTimeTypedProperty *expectedProperty = (MSACDateTimeTypedProperty *)expectedProperties.properties[propertyKey];
      MSACDateTimeTypedProperty *property = (MSACDateTimeTypedProperty *)eventProperties.properties[propertyKey];
      XCTAssertEqual(property.value, expectedProperty.value);
    }
    [expectedProperties.properties removeObjectForKey:propertyKey];
  }
  XCTAssertEqual([expectedProperties.properties count], 0);
}

- (void)testTrackEventWithPropertiesWithNormalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMStub([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withProperties:nil flags:MSACFlagsNormal];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testTrackEventWithPropertiesWithCriticalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMReject([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0]);
  OCMStub([[self.channelUnitCriticalMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withProperties:nil flags:MSACFlagsCritical];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  XCTAssertEqual(actualFlags, MSACFlagsPersistenceCritical);
  OCMVerifyAll(self.channelUnitMock);
#pragma clang diagnostic pop
}

- (void)testTrackEventWithPropertiesWithInvalidFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMStub([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withProperties:nil flags:42];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testPersistanceFlagsSeparateChannels {

  // If
  NSString *expectedCriticalEvent = @"Having a cup of coffee";
  NSString *expectedEvent = @"Washing a cup after having a coffee";
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  OCMExpect([self.channelUnitCriticalMock enqueueItem:OCMOCK_ANY flags:MSACFlagsPersistenceCritical]);
  OCMExpect([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsPersistenceNormal]);

  // When
  [[MSACAnalytics sharedInstance] trackEvent:expectedCriticalEvent
                         withTypedProperties:nil
                       forTransmissionTarget:nil
                                       flags:MSACFlagsPersistenceCritical];
  [[MSACAnalytics sharedInstance] trackEvent:expectedEvent
                         withTypedProperties:nil
                       forTransmissionTarget:nil
                                       flags:MSACFlagsPersistenceNormal];
#pragma clang diagnostic pop

  // Then
  OCMVerifyAll(self.channelUnitCriticalMock);
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testTrackEventWithTypedPropertiesWithNormalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMStub([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withTypedProperties:nil flags:MSACFlagsNormal];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testTrackEventWithTypedPropertiesWithCriticalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMStub([[self.channelUnitCriticalMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  OCMReject([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0]);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withTypedProperties:nil flags:MSACFlagsCritical];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  XCTAssertEqual(actualFlags, MSACFlagsPersistenceCritical);
#pragma clang diagnostic pop
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testTrackEventWithTypedPropertiesWithInvalidFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"gotACoffee";
  OCMStub([[self.channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:expectedName withTypedProperties:nil flags:42];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testTrackPageWithoutProperties {

  // If
  __block NSString *name;
  __block NSString *type;
  NSString *expectedName = @"HomeSweetHome";
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackPage:expectedName];

  // Then
  assertThat(type, is(kMSACTypePage));
  assertThat(name, is(expectedName));
}

- (void)testTrackPageWithProperties {

  // If
  __block NSString *type;
  __block NSString *name;
  __block NSDictionary<NSString *, NSString *> *properties;
  NSString *expectedName = @"HomeSweetHome";
  NSDictionary *expectedProperties = @{@"Sofa" : @"yes", @"TV" : @"of course"};
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
        properties = log.properties;
      });
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackPage:expectedName withProperties:expectedProperties];

  // Then
  assertThat(type, is(kMSACTypePage));
  assertThat(name, is(expectedName));
  assertThat(properties, is(expectedProperties));
}

- (void)testTrackPageWhenAnalyticsDisabled {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsMock isEnabled]).andReturn(NO);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMReject([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);
  [[MSACAnalytics sharedInstance] trackPage:@"Some page" withProperties:nil];

  // Then
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testTrackPageWithInvalidName {

  // If
  NSString *invalidPageName = nil;
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMExpect([self.channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]);

  // Will be validated in shouldFilterLog callback instead.
  OCMReject([analyticsMock validateEventName:OCMOCK_ANY forLogType:OCMOCK_ANY]);
  OCMReject([analyticsMock validateProperties:OCMOCK_ANY forLogName:OCMOCK_ANY andType:OCMOCK_ANY]);
  [[MSACAnalytics sharedInstance] trackPage:invalidPageName withProperties:nil];

  // Then
  OCMVerifyAll(self.channelUnitMock);
  OCMVerifyAll(analyticsMock);
}

- (void)testAutoPageTracking {

  // For now auto page tracking is disabled by default
  XCTAssertFalse([MSACAnalytics isAutoPageTrackingEnabled]);

  // When
  [MSACAnalytics setAutoPageTrackingEnabled:YES];

  // Then
  XCTAssertTrue([MSACAnalytics isAutoPageTrackingEnabled]);

  // When
  [MSACAnalytics setAutoPageTrackingEnabled:NO];

  // Then
  XCTAssertFalse([MSACAnalytics isAutoPageTrackingEnabled]);
}

- (void)testInitializationPriorityCorrect {
  XCTAssertTrue([[MSACAnalytics sharedInstance] initializationPriority] == MSACInitializationPriorityDefault);
}

- (void)testServiceNameIsCorrect {
  XCTAssertEqual([MSACAnalytics serviceName], kMSACAnalyticsServiceName);
}

#if TARGET_OS_IOS

// TODO: Modify for testing each platform when page tracking will be supported on each platform.
- (void)testViewWillAppearSwizzlingWithAnalyticsAvailable {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsMock isAutoPageTrackingEnabled]).andReturn(YES);
  OCMStub([analyticsMock isAvailable]).andReturn(YES);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

// When
#if TARGET_OS_OSX
  NSViewController *viewController = [[NSViewController alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
  if ([viewController respondsToSelector:@selector(viewWillAppear)]) {
    [viewController viewWillAppear];
  }
#pragma clang diagnostic pop
#else
  UIViewController *viewController = [[UIViewController alloc] init];
  [viewController viewWillAppear:NO];
#endif

  // Then
  OCMVerify([analyticsMock isAutoPageTrackingEnabled]);
  XCTAssertNil([MSACAnalyticsCategory missedPageViewName]);
}

- (void)testViewWillAppearSwizzlingWithAnalyticsNotAvailable {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsMock isAutoPageTrackingEnabled]).andReturn(YES);
  OCMStub([analyticsMock isAvailable]).andReturn(NO);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

// When
#if TARGET_OS_OSX
  NSViewController *viewController = [[NSViewController alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
  if ([viewController respondsToSelector:@selector(viewWillAppear)]) {
    [viewController viewWillAppear];
  }
#pragma clang diagnostic pop
#else
  UIViewController *viewController = [[UIViewController alloc] init];
  [viewController viewWillAppear:NO];
#endif

  // Then
  OCMVerify([analyticsMock isAutoPageTrackingEnabled]);
  XCTAssertNotNil([MSACAnalyticsCategory missedPageViewName]);
}

- (void)testViewWillAppearSwizzlingWithShouldTrackPageDisabled {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  OCMExpect([analyticsMock isAutoPageTrackingEnabled]).andReturn(YES);
  OCMReject([analyticsMock isAvailable]);
#if TARGET_OS_OSX
  NSPageController *containerController = [[NSPageController alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
  if ([containerController respondsToSelector:@selector(viewWillAppear)]) {
    [containerController viewWillAppear];
  }
#pragma clang diagnostic pop
#else
  UIPageViewController *containerController = [[UIPageViewController alloc] init];
  [containerController viewWillAppear:NO];
#endif

  // Then
  OCMVerifyAll(analyticsMock);
}

#endif

- (void)testStartWithTransmissionTargetAndAppSecretUsesTransmissionTarget {

  // If
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  __block MSACEventLog *log;
  __block int invocations = 0;
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        ++invocations;
        [invocation getArgument:&log atIndex:2];
      });
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:kMSACTestTransmissionToken
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:@"eventName"];

  // Then
  OCMVerify([self.channelUnitMock enqueueItem:log flags:MSACFlagsDefault]);
  XCTAssertTrue([[log transmissionTargetTokens] containsObject:kMSACTestTransmissionToken]);
  XCTAssertEqual([[log transmissionTargetTokens] count], (unsigned long)1);
  XCTAssertEqual(invocations, 1);
}

- (void)testStartWithTransmissionTargetWithoutAppSecretUsesTransmissionTarget {

  // If
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  __block MSACEventLog *log;
  __block int invocations = 0;
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACLogWithProperties class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        ++invocations;
        [invocation getArgument:&log atIndex:2];
      });
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:nil
                                transmissionTargetToken:kMSACTestTransmissionToken
                                        fromApplication:YES];

  // When
  [MSACAnalytics trackEvent:@"eventName"];

  // Then
  OCMVerify([self.channelUnitMock enqueueItem:log flags:MSACFlagsDefault]);
  XCTAssertTrue([[log transmissionTargetTokens] containsObject:kMSACTestTransmissionToken]);
  XCTAssertEqual([[log transmissionTargetTokens] count], (unsigned long)1);
  XCTAssertEqual(invocations, 1);
}

- (void)testGetTransmissionTargetCreatesTransmissionTargetOnce {

  // When
  MSACAnalyticsTransmissionTarget *transmissionTarget1 = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];
  MSACAnalyticsTransmissionTarget *transmissionTarget2 = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];

  // Then
  XCTAssertNotNil(transmissionTarget1);
  XCTAssertEqual(transmissionTarget1, transmissionTarget2);
}

- (void)testGetTransmissionTargetNeverReturnsDefault {

  // If
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:nil
                                transmissionTargetToken:kMSACTestTransmissionToken
                                        fromApplication:NO];

  // When
  MSACAnalyticsTransmissionTarget *transmissionTarget = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];

  // Then
  XCTAssertNotNil([MSACAnalytics sharedInstance].defaultTransmissionTarget);
  XCTAssertNotNil(transmissionTarget);
  XCTAssertNotEqual([MSACAnalytics sharedInstance].defaultTransmissionTarget, transmissionTarget);
}

- (void)testDefaultTransmissionTargetMirrorAnalyticsEnableState {

  // If
  MSACAnalytics *service = [MSACAnalytics sharedInstance];
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];

  // When
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:kMSACTestTransmissionToken
                                        fromApplication:YES];

  // Then
  XCTAssertNotNil([MSACAnalytics sharedInstance].defaultTransmissionTarget);
  XCTAssertTrue([service isEnabled]);
  XCTAssertTrue([service.defaultTransmissionTarget isEnabled]);

  // When
  [service setEnabled:NO];

  // Then
  XCTAssertFalse([service isEnabled]);
  XCTAssertFalse([service.defaultTransmissionTarget isEnabled]);

  // When
  [service setEnabled:YES];

  // Then
  XCTAssertTrue([service isEnabled]);
  XCTAssertTrue([service.defaultTransmissionTarget isEnabled]);
}

- (void)testEnableStatePropagateToTransmissionTargets {

  // If
  [MSACAppCenter configureWithAppSecret:kMSACTestAppSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:NO];
  MSACServiceAbstract *analytics = [MSACAnalytics sharedInstance];
  [analytics setEnabled:NO];

  // When

  // Analytics is disabled, targets must match Analytics enabled state.
  MSACAnalyticsTransmissionTarget *transmissionTarget = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];
  MSACAnalyticsTransmissionTarget *transmissionTarget2 = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken2];

  // Then
  XCTAssertFalse([transmissionTarget isEnabled]);
  XCTAssertFalse([transmissionTarget2 isEnabled]);

  // When

  // Trying re-enabling will fail since Analytics is still disabled.
  [transmissionTarget setEnabled:YES];

  // Then
  XCTAssertFalse([transmissionTarget isEnabled]);
  XCTAssertFalse([transmissionTarget2 isEnabled]);

  // When

  // Enabling Analytics will enable all targets.
  [analytics setEnabled:YES];

  // Then
  XCTAssertTrue([transmissionTarget isEnabled]);
  XCTAssertTrue([transmissionTarget2 isEnabled]);

  // Disabling Analytics will disable all targets.
  [analytics setEnabled:NO];

  // Then
  XCTAssertFalse([transmissionTarget isEnabled]);
  XCTAssertFalse([transmissionTarget2 isEnabled]);
}

- (void)testAppSecretNotRequired {
  XCTAssertFalse([[MSACAnalytics sharedInstance] isAppSecretRequired]);
}

- (void)testSessionTrackerStarted {

  // When
  [MSACAppCenter startFromLibraryWithServices:@ [[MSACAnalytics class]]];

  // Then
  XCTAssertFalse([MSACAnalytics sharedInstance].sessionTracker.started);

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACAnalytics class]]];

  // Then
  XCTAssertTrue([MSACAnalytics sharedInstance].sessionTracker.started);
}

- (void)testSessionTrackerStartedWithToken {

  // When
  [MSACAppCenter startFromLibraryWithServices:@ [[MSACAnalytics class]]];

  // Then
  XCTAssertNil([MSACAnalytics sharedInstance].defaultTransmissionTarget);

  // When
  [[MSACAnalytics sharedInstance] updateConfigurationWithAppSecret:kMSACTestAppSecret transmissionTargetToken:kMSACTestTransmissionToken];

  // Then
  XCTAssertNotNil([MSACAnalytics sharedInstance].defaultTransmissionTarget);
}

- (void)testAutoPageTrackingWhenStartedFromLibrary {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  id analyticsCategoryMock = OCMClassMock([MSACAnalyticsCategory class]);
  NSString *testPageName = @"TestPage";
  OCMStub([analyticsCategoryMock missedPageViewName]).andReturn(testPageName);
  [MSACAnalytics setAutoPageTrackingEnabled:YES];
  MSACServiceAbstract *service = [MSACAnalytics sharedInstance];

  // When
  [[MSACAnalytics sharedInstance] startWithChannelGroup:OCMProtocolMock(@protocol(MSACChannelGroupProtocol))
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:NO];

  // Then
  XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for block in applyEnabledState to be dispatched"];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertTrue([service isEnabled]);
                                 OCMReject([analyticsMock trackPage:testPageName withProperties:nil]);
                               }];
}

#pragma mark - Property validation tests

- (void)testRemoveInvalidPropertiesWithEmptyValue {

  // If
  NSDictionary *emptyValueProperties = @{@"aValidKey" : @""};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:emptyValueProperties];

  // Then
  XCTAssertTrue(result.count == 1);
  XCTAssertEqualObjects(result, emptyValueProperties);
}

- (void)testRemoveInvalidPropertiesWithEmptyKey {

  // If
  NSDictionary *emptyKeyProperties = @{@"" : @"aValidValue"};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:emptyKeyProperties];

  // Then
  XCTAssertTrue(result.count == 1);
}

- (void)testremoveInvalidPropertiesWithNonStringKey {

  // If
  NSDictionary *numberAsKeyProperties = @{@(42) : @"aValidValue"};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:numberAsKeyProperties];

  // Then
  XCTAssertTrue(result.count == 0);
}

- (void)testValidateLogDataWithNonStringValue {

  // If
  NSDictionary *numberAsValueProperties = @{@"aValidKey" : @(42)};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:numberAsValueProperties];

  // Then
  XCTAssertTrue(result.count == 0);
}

- (void)testValidateLogDataWithCorrectNestedProperties {

  // If
  NSDictionary *correctlyNestedProperties = @{@"aValidKey1" : @"aValidValue1", @"aValidKey2.aValidKey2" : @"aValidValue3"};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:correctlyNestedProperties];

  // Then
  XCTAssertTrue(result.count == 2);
  XCTAssertEqualObjects(result, correctlyNestedProperties);
}

- (void)testValidateLogDataWithIncorrectNestedProperties {

  // If
  NSDictionary *incorrectNestedProperties = @{
    @"aValidKey1" : @"aValidValue1",
    @"aValidKey2" : @1,
  };

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:incorrectNestedProperties];

  // Then
  XCTAssertTrue(result.count == 1);
  XCTAssertNil(result[@"aValidKey2"]);
  XCTAssertNotNil(result[@"aValidKey1"]);
  XCTAssertEqualObjects(result[@"aValidKey1"], @"aValidValue1");
  XCTAssertNotEqualObjects(result, incorrectNestedProperties);
}

- (void)testDictionaryContainsInvalidPropertiesKey {

  // If
  NSDictionary *incorrectNestedProperties = @{@1 : @"aValidValue1", @"aValidKey2" : @"aValidValue2"};

  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:incorrectNestedProperties];

  // Then
  XCTAssertTrue(result.count == 1);
  XCTAssertNotNil(result[@"aValidKey2"]);
}

- (void)testDictionaryContainsValidNestedProperties {
  NSDictionary *properties = @{@"aValidKey2" : @"aValidValue1", @"aValidKey1.avalidKey2" : @"aValidValue1"};
  // When
  NSDictionary *result = [[MSACAnalytics sharedInstance] removeInvalidProperties:properties];

  // Then
  XCTAssertEqualObjects(result, properties);
}

- (void)testPropertyNameIsTruncatedInACopyWhenValidatingForAppCenter {

  // If
  MSACEventProperties *properties = [MSACEventProperties new];
  NSString *longKey = [@"" stringByPaddingToLength:kMSACMaxPropertyKeyLength + 2 withString:@"hi" startingAtIndex:0];
  NSString *truncatedKey = [longKey substringToIndex:kMSACMaxPropertyKeyLength - 1];
  [properties setString:@"test" forKey:longKey];
  MSACStringTypedProperty *originalProperty = (MSACStringTypedProperty *)properties.properties[longKey];

  // When
  MSACEventProperties *validProperties = [[MSACAnalytics sharedInstance] validateAppCenterEventProperties:properties];

  // Then
  MSACStringTypedProperty *validProperty = (MSACStringTypedProperty *)validProperties.properties[truncatedKey];
  XCTAssertNotNil(validProperty);
  XCTAssertEqualObjects(validProperty.name, truncatedKey);
  XCTAssertNotEqual(originalProperty, validProperty);
  XCTAssertEqualObjects(originalProperty.name, longKey);
}

- (void)testPropertyValueIsTruncatedInACopyWhenValidatingForAppCenter {

  // If
  MSACEventProperties *properties = [MSACEventProperties new];
  NSString *key = @"key";
  NSString *longValue = [@"" stringByPaddingToLength:kMSACMaxPropertyValueLength + 2 withString:@"hi" startingAtIndex:0];
  NSString *truncatedValue = [longValue substringToIndex:kMSACMaxPropertyValueLength - 1];
  [properties setString:longValue forKey:key];
  MSACStringTypedProperty *originalProperty = (MSACStringTypedProperty *)properties.properties[key];

  // When
  MSACEventProperties *validProperties = [[MSACAnalytics sharedInstance] validateAppCenterEventProperties:properties];

  // Then
  MSACStringTypedProperty *validProperty = (MSACStringTypedProperty *)validProperties.properties[key];
  XCTAssertEqualObjects(validProperty.value, truncatedValue);
  XCTAssertNotEqual(originalProperty, validProperty);
  XCTAssertEqualObjects(originalProperty.value, longValue);
}

- (void)testAppCenterCopyHas20PropertiesWhenSelfHasMoreThan20 {

  // If
  MSACEventProperties *properties = [MSACEventProperties new];

  // When
  for (int i = 0; i < kMSACMaxPropertiesPerLog + 5; i++) {
    [properties setBool:YES forKey:[@(i) stringValue]];
  }
  MSACEventProperties *validProperties = [[MSACAnalytics sharedInstance] validateAppCenterEventProperties:properties];

  // Then
  XCTAssertEqual([validProperties.properties count], kMSACMaxPropertiesPerLog);
}

- (void)testPause {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock sharedInstance]).andReturn(appCenterMock);
  OCMStub([appCenterMock isSdkConfigured]).andReturn(YES);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics pause];

  // Then
  OCMVerify([self.channelUnitMock pauseWithIdentifyingObject:[MSACAnalytics sharedInstance]]);
  [appCenterMock stopMocking];
}

- (void)testResume {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock sharedInstance]).andReturn(appCenterMock);
  OCMStub([appCenterMock isSdkConfigured]).andReturn(YES);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [MSACAnalytics resume];

  // Then
  OCMVerify([self.channelUnitMock resumeWithIdentifyingObject:[MSACAnalytics sharedInstance]]);
  [appCenterMock stopMocking];
}

- (void)testEnablingAnalyticsResumesIt {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock sharedInstance]).andReturn(appCenterMock);
  OCMStub([appCenterMock isSdkConfigured]).andReturn(YES);
  OCMStub(ClassMethod([appCenterMock isEnabled])).andReturn(YES);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:kMSACTestAppSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];
  [MSACAnalytics setEnabled:NO];

  // Reset ChannelUnitMock since it's already called at startup and we want to
  // verify at enabling time.
  [MSACAnalytics sharedInstance].channelUnit = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));

  // When
  [MSACAnalytics setEnabled:YES];

  // Then
  OCMVerify([[MSACAnalytics sharedInstance].channelUnit resumeWithIdentifyingObject:[MSACAnalytics sharedInstance]]);
  [appCenterMock stopMocking];
}

- (void)testPauseTransmissionTargetInOneCollectorChannelUnitWhenPausedWithTargetKey {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock sharedInstance]).andReturn(appCenterMock);
  OCMStub([appCenterMock isSdkConfigured]).andReturn(YES);
  OCMStub(ClassMethod([appCenterMock isEnabled])).andReturn(YES);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock channelUnitForGroupId:@"Analytics/one"]).andReturn(oneCollectorChannelUnitMock);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:channelGroupMock appSecret:nil transmissionTargetToken:nil fromApplication:YES];
  // When
  [MSACAnalytics pauseTransmissionTargetForToken:kMSACTestTransmissionToken];

  // Then
  OCMVerify([oneCollectorChannelUnitMock pauseSendingLogsWithToken:kMSACTestTransmissionToken]);
  [appCenterMock stopMocking];
}

- (void)testResumeTransmissionTargetInOneCollectorChannelUnitWhenResumedWithTargetKey {

  // If
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock sharedInstance]).andReturn(appCenterMock);
  OCMStub([appCenterMock isSdkConfigured]).andReturn(YES);
  OCMStub(ClassMethod([appCenterMock isEnabled])).andReturn(YES);
  id<MSACChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  id<MSACChannelUnitProtocol> oneCollectorChannelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock channelUnitForGroupId:@"Analytics/one"]).andReturn(oneCollectorChannelUnitMock);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:channelGroupMock appSecret:nil transmissionTargetToken:nil fromApplication:YES];
  // When
  [MSACAnalytics resumeTransmissionTargetForToken:kMSACTestTransmissionToken];

  // Then
  OCMVerify([oneCollectorChannelUnitMock resumeSendingLogsWithToken:kMSACTestTransmissionToken]);
  [appCenterMock stopMocking];
}

#if TARGET_OS_IOS

// TODO: Modify for testing each platform when page tracking will be supported on each platform.
- (void)testViewWillAppearSwizzling {

  // If
  id analyticsMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  UIViewController *viewController = [[UIViewController alloc] init];

  // When
  [MSACAnalyticsCategory activateCategory];
  [viewController viewWillAppear:NO];

  // Then
  OCMVerify([analyticsMock isAutoPageTrackingEnabled]);

  // Clear
  [analyticsMock stopMocking];
}

#endif

@end
