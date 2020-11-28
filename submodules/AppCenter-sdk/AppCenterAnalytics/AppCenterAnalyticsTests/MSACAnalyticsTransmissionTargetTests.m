// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalyticsAuthenticationProviderInternal.h"
#import "MSACAnalyticsInternal.h"
#import "MSACAnalyticsPrivate.h"
#import "MSACAnalyticsTransmissionTargetInternal.h"
#import "MSACAnalyticsTransmissionTargetPrivate.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppExtension.h"
#import "MSACBooleanTypedProperty.h"
#import "MSACCSExtensions.h"
#import "MSACChannelUnitDefault.h"
#import "MSACDateTimeTypedProperty.h"
#import "MSACDoubleTypedProperty.h"
#import "MSACEventLog.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLongTypedProperty.h"
#import "MSACMockUserDefaults.h"
#import "MSACPropertyConfiguratorInternal.h"
#import "MSACPropertyConfiguratorPrivate.h"
#import "MSACStringTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUserExtension.h"
#import "MSACUserIdContextPrivate.h"

static NSString *const kMSACTypeEvent = @"event";
static NSString *const kMSACTestTransmissionToken = @"TestTransmissionToken";
static NSString *const kMSACTestTransmissionToken2 = @"TestTransmissionToken2";

@interface MSACAnalyticsTransmissionTargetTests : XCTestCase

@property(nonatomic) MSACMockUserDefaults *settingsMock;
@property(nonatomic) id analyticsClassMock;
@property(nonatomic) id<MSACChannelGroupProtocol> channelGroupMock;

@end

@implementation MSACAnalyticsTransmissionTargetTests

- (void)setUp {
  [super setUp];
  [MSACUserIdContext resetSharedInstance];

  // Mock NSUserDefaults
  self.settingsMock = [MSACMockUserDefaults new];

  // Analytics enabled state can prevent targets from tracking events.
  id analyticsClassMock = OCMClassMock([MSACAnalytics class]);
  self.analyticsClassMock = OCMPartialMock([MSACAnalytics sharedInstance]);
  OCMStub([analyticsClassMock sharedInstance]).andReturn(self.analyticsClassMock);
  self.channelGroupMock = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [MSACAppCenter sharedInstance].sdkConfigured = YES;
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:@"appsecret"
                                transmissionTargetToken:@"token"
                                        fromApplication:YES];
}

- (void)tearDown {
  [self.settingsMock stopMocking];
  [self.analyticsClassMock stopMocking];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  MSACAnalyticsTransmissionTarget.authenticationProvider = nil;
#pragma clang diagnostic pop
  [super tearDown];
}

#pragma mark - Tests

- (void)testInitialization {

  // When
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];

  // Then
  XCTAssertNotNil(sut);
  XCTAssertEqual(kMSACTestTransmissionToken, sut.transmissionTargetToken);
  XCTAssertTrue([sut.propertyConfigurator.eventProperties isEmpty]);
  XCTAssertNil(MSACAnalyticsTransmissionTarget.authenticationProvider);
}

- (void)testTrackEvent {

  // If
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";

  // When
  [sut trackEvent:eventName];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut flags:MSACFlagsDefault]);
}

- (void)testTrackEventWithProperties {

  // If
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  NSDictionary *properties = @{@"prop1" : @"val1", @"prop2" : @"val2"};
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  for (NSString *key in properties.allKeys) {
    [expectedProperties setString:properties[key] forKey:key];
  }

  // When
  [sut trackEvent:eventName withProperties:properties];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify([self.analyticsClassMock trackEvent:eventName
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:sut
                                          flags:MSACFlagsDefault]);
}

- (void)testTrackEventWithNilDictionaryProperties {

  // If
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // When
  [sut trackEvent:eventName withProperties:nil];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut flags:MSACFlagsDefault]);
}

- (void)testTrackEventWithNilEventProperties {

  // If
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // When
  [sut trackEvent:eventName withTypedProperties:nil];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut flags:MSACFlagsDefault]);
}

- (void)testTrackEventWithPropertiesWithNormalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withProperties:nil flags:MSACFlagsNormal];

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
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withProperties:nil flags:MSACFlagsCritical];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsCritical);
}

- (void)testTrackEventWithPropertiesWithInvalidFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withProperties:nil flags:42];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testTrackEventWithTypedPropertiesWithNormalPersistenceFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withTypedProperties:nil flags:MSACFlagsNormal];

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
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withTypedProperties:nil flags:MSACFlagsCritical];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsCritical);
}

- (void)testTrackEventWithTypedPropertiesWithInvalidFlag {

  // If
  __block NSString *actualType;
  __block NSString *actualName;
  __block MSACFlags actualFlags;
  NSString *expectedName = @"event";
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  OCMStub([[channelUnitMock ignoringNonObjectArgs] enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:(MSACFlags)0])
      .andDo(^(NSInvocation *invocation) {
        MSACEventLog *log;
        [invocation getArgument:&log atIndex:2];
        actualType = log.type;
        actualName = log.name;
        MSACFlags flags;
        [invocation getArgument:&flags atIndex:3];
        actualFlags = flags;
      });
  MSACAnalyticsTransmissionTarget *sut = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                                     parentTarget:nil
                                                                                                     channelGroup:self.channelGroupMock];
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter configureWithAppSecret:appSecret];
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:appSecret
                                transmissionTargetToken:nil
                                        fromApplication:YES];

  // When
  [sut trackEvent:expectedName withTypedProperties:nil flags:42];

  // Then
  XCTAssertEqual(actualType, kMSACTypeEvent);
  XCTAssertEqual(actualName, expectedName);
  XCTAssertEqual(actualFlags, MSACFlagsNormal);
}

- (void)testTrackEventSetsUserIdForDefaultTransmissionTarget {

  // If
  __block MSACEventLog *log;
  [[MSACUserIdContext sharedInstance] setUserId:@"c:test"];
  [MSACAnalytics resetSharedInstance];
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:@"appsecret"
                                transmissionTargetToken:@"token"
                                        fromApplication:YES];
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&log atIndex:2];
      });

  // When
  [MSACAnalytics trackEvent:@"Some event"];

  // Then
  XCTAssertNotNil(log);
  XCTAssertEqual(log.userId, @"c:test");
}

- (void)testTrackEventDoesNotOverrideUserIdOfDefaultTransmissionTarget {

  // If
  __block MSACEventLog *log;
  [[MSACUserIdContext sharedInstance] setUserId:@"c:alice"];
  [MSACAnalytics resetSharedInstance];
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:@"appsecret"
                                transmissionTargetToken:@"defaultToken"
                                        fromApplication:YES];
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"anotherToken"];
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACEventLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&log atIndex:2];
      });

  // When
  [MSACAnalytics trackEvent:@"Some event" withTypedProperties:nil forTransmissionTarget:target flags:MSACFlagsDefault];

  // Then
  XCTAssertNotNil(log);
  XCTAssertNil(log.userId);
}

- (void)testTransmissionTargetForToken {

  // If
  NSDictionary *properties = [NSDictionary new];
  MSACEventProperties *emptyProperties = [MSACEventProperties new];
  NSString *event1 = @"event1";
  NSString *event2 = @"event2";
  NSString *event3 = @"event3";

  MSACAnalyticsTransmissionTarget *parentTransmissionTarget =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];
  MSACAnalyticsTransmissionTarget *childTransmissionTarget;

  // When
  childTransmissionTarget = [parentTransmissionTarget transmissionTargetForToken:kMSACTestTransmissionToken2];
  [childTransmissionTarget trackEvent:event1 withProperties:properties];

  // Then
  XCTAssertEqualObjects(kMSACTestTransmissionToken2, childTransmissionTarget.transmissionTargetToken);
  XCTAssertEqualObjects(childTransmissionTarget, parentTransmissionTarget.childTransmissionTargets[kMSACTestTransmissionToken2]);

  // When
  MSACAnalyticsTransmissionTarget *childTransmissionTarget2 =
      [parentTransmissionTarget transmissionTargetForToken:kMSACTestTransmissionToken2];
  [childTransmissionTarget2 trackEvent:event2 withProperties:properties];

  // Then
  XCTAssertEqualObjects(childTransmissionTarget, childTransmissionTarget2);
  XCTAssertEqualObjects(childTransmissionTarget2, parentTransmissionTarget.childTransmissionTargets[kMSACTestTransmissionToken2]);

  // When
  MSACAnalyticsTransmissionTarget *childTransmissionTarget3 =
      [parentTransmissionTarget transmissionTargetForToken:kMSACTestTransmissionToken];
  [childTransmissionTarget3 trackEvent:event3 withProperties:properties];

  // Then
  XCTAssertNotEqualObjects(parentTransmissionTarget, childTransmissionTarget3);
  XCTAssertEqualObjects(childTransmissionTarget3, parentTransmissionTarget.childTransmissionTargets[kMSACTestTransmissionToken]);
  OCMVerify([self.analyticsClassMock trackEvent:event1
                            withTypedProperties:emptyProperties
                          forTransmissionTarget:childTransmissionTarget
                                          flags:MSACFlagsDefault]);
  OCMVerify([self.analyticsClassMock trackEvent:event2
                            withTypedProperties:emptyProperties
                          forTransmissionTarget:childTransmissionTarget2
                                          flags:MSACFlagsDefault]);
  OCMVerify([self.analyticsClassMock trackEvent:event3
                            withTypedProperties:emptyProperties
                          forTransmissionTarget:childTransmissionTarget3
                                          flags:MSACFlagsDefault]);
}

- (void)testTransmissionTargetEnabledState {

  // If
  NSDictionary *properties = @{@"prop1" : @"val1", @"prop2" : @"val2"};
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  for (NSString *key in properties.allKeys) {
    [expectedProperties setString:properties[key] forKey:key];
  }
  NSString *event1 = @"event1";
  NSString *event2 = @"event2";
  NSString *event3 = @"event3";
  NSString *event4 = @"event4";
  MSACAnalyticsTransmissionTarget *transmissionTarget, *transmissionTarget2;
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Events tracked when disabled mustn't be sent.
  OCMReject([self.analyticsClassMock trackEvent:event2
                                 withProperties:properties
                          forTransmissionTarget:transmissionTarget
                                          flags:MSACFlagsDefault]);
  OCMReject([self.analyticsClassMock trackEvent:event3
                                 withProperties:properties
                          forTransmissionTarget:transmissionTarget2
                                          flags:MSACFlagsDefault]);

  // When

  // Target enabled by default.
  transmissionTarget = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                   parentTarget:nil
                                                                                   channelGroup:self.channelGroupMock];
  [transmissionTarget setEnabled:YES];

  // Then
  XCTAssertTrue([transmissionTarget isEnabled]);
  [transmissionTarget trackEvent:event1 withProperties:properties];

  // When

  // Disabling, track event won't work.
  [transmissionTarget setEnabled:NO];
  [transmissionTarget trackEvent:event2 withProperties:properties];

  // Then
  XCTAssertFalse([transmissionTarget isEnabled]);

  // When

  // Allocating a new object with the same token should return the enabled state
  // for this token.
  transmissionTarget2 = [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                                    parentTarget:nil
                                                                                    channelGroup:self.channelGroupMock];
  [transmissionTarget2 trackEvent:event3 withProperties:properties];

  // Then
  XCTAssertFalse([transmissionTarget2 isEnabled]);

  // When

  // Re-enabling
  [transmissionTarget2 setEnabled:YES];
  [transmissionTarget2 trackEvent:event4 withProperties:properties];

  // Then
  XCTAssertTrue([transmissionTarget2 isEnabled]);
  OCMVerify([self.analyticsClassMock trackEvent:event1
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:transmissionTarget
                                          flags:MSACFlagsDefault]);
  OCMVerify([self.analyticsClassMock trackEvent:event4
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:transmissionTarget2
                                          flags:MSACFlagsDefault]);
}

- (void)testTransmissionTargetNestedEnabledState {

  // If
  MSACAnalyticsTransmissionTarget *target =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];

  // When

  // Create a child while parent is enabled, child also enabled.
  MSACAnalyticsTransmissionTarget *childTarget = [target transmissionTargetForToken:@"childTarget1-guid"];

  // Then
  XCTAssertTrue([childTarget isEnabled]);

  // If
  MSACAnalyticsTransmissionTarget *subChildTarget = [childTarget transmissionTargetForToken:@"subChildTarget1-guid"];

  // When

  // Disabling the parent disables its children.
  [target setEnabled:NO];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);

  // When

  // Enabling a child while parent is disabled won't work.
  [childTarget setEnabled:YES];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);

  // When

  // Adding another child, it's state should reflect its parent.
  MSACAnalyticsTransmissionTarget *childTarget2 = [target transmissionTargetForToken:@"childTarget2-guid"];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);
  XCTAssertFalse([childTarget2 isEnabled]);

  // When

  // Enabling a parent enables its children.
  [target setEnabled:YES];

  // Then
  XCTAssertTrue([target isEnabled]);
  XCTAssertTrue([childTarget isEnabled]);
  XCTAssertTrue([subChildTarget isEnabled]);
  XCTAssertTrue([childTarget2 isEnabled]);

  // When

  // Disabling a child only disables its children.
  [childTarget setEnabled:NO];

  // Then
  XCTAssertTrue([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);
  XCTAssertTrue([childTarget2 isEnabled]);
}

- (void)testLongListOfImmediateChildren {

  // If
  short maxChildren = 50;
  NSMutableArray<MSACAnalyticsTransmissionTarget *> *childrenTargets;
  MSACAnalyticsTransmissionTarget *parentTarget =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];
  for (short i = 1; i <= maxChildren; i++) {
    [childrenTargets addObject:[parentTarget transmissionTargetForToken:[NSString stringWithFormat:@"Child%d-guid", i]]];
  }

  // When
  [self measureBlock:^{
    [parentTarget setEnabled:NO];
  }];

  // Then
  XCTAssertFalse(parentTarget.isEnabled);
  for (MSACAnalyticsTransmissionTarget *child in childrenTargets) {
    XCTAssertFalse(child.isEnabled);
  }
}

- (void)testLongListOfSubChildren {

  // If
  short maxSubChildren = 50;
  NSMutableArray<MSACAnalyticsTransmissionTarget *> *childrenTargets;
  MSACAnalyticsTransmissionTarget *parentTarget =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];
  MSACAnalyticsTransmissionTarget *currentChildren = [parentTarget transmissionTargetForToken:@"Child1-guid"];
  [childrenTargets addObject:currentChildren];
  for (short i = 2; i <= maxSubChildren; i++) {
    currentChildren = [currentChildren transmissionTargetForToken:[NSString stringWithFormat:@"SubChild%d-guid", i]];
    [childrenTargets addObject:currentChildren];
  }

  // When
  [self measureBlock:^{
    [parentTarget setEnabled:NO];
  }];

  // Then
  XCTAssertFalse(parentTarget.isEnabled);
  for (MSACAnalyticsTransmissionTarget *child in childrenTargets) {
    XCTAssertFalse(child.isEnabled);
  }
}

- (void)testMergingEventPropertiesWithCommonPropertiesOnly {

  // If

  // Common properties only.
  MSACAnalyticsTransmissionTarget *target =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];

  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];

  // When
  [target trackEvent:eventName];

  // Then
  OCMVerify([self.analyticsClassMock trackEvent:eventName
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:target
                                          flags:MSACFlagsDefault]);
}

- (void)testMergingEventPropertiesWithCommonAndTrackEventProperties {

  // If
  MSACAnalyticsTransmissionTarget *target =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];

  // Common properties.
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];
  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];

  // Track event properties.
  NSString *propTrackKey = @"propTrackKey";
  NSString *propTrackValue = @"propTrackValue";
  NSString *propTrackKey2 = @"sharedPropKey";
  NSString *propTrackValue2 = @"propTrackValue2";
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [expectedProperties setString:propTrackValue forKey:propTrackKey];
  [expectedProperties setString:propTrackValue2 forKey:propTrackKey2];

  // When
  [target trackEvent:eventName withProperties:@{propTrackKey : propTrackValue, propTrackKey2 : propTrackValue2}];

  // Then
  OCMVerify([self.analyticsClassMock trackEvent:eventName
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:target
                                          flags:MSACFlagsDefault]);
}

- (void)testMergingEventPropertiesWithCommonAndTrackEventTypedProperties {

  // If
  MSACAnalyticsTransmissionTarget *target =
      [[MSACAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSACTestTransmissionToken
                                                                  parentTarget:nil
                                                                  channelGroup:self.channelGroupMock];

  // Common properties.
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];
  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];

  // Track event properties.
  NSString *propTrackKey = @"propTrackKey";
  NSString *propTrackValue = @"propTrackValue";
  NSString *propTrackKey2 = @"sharedPropKey";
  BOOL propTrackValue2 = YES;
  MSACEventProperties *expectedProperties = [MSACEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [expectedProperties setString:propTrackValue forKey:propTrackKey];
  [expectedProperties setBool:propTrackValue2 forKey:propTrackKey2];
  MSACEventProperties *trackEventProperties = [MSACEventProperties new];
  [trackEventProperties setString:propTrackValue forKey:propTrackKey];
  [trackEventProperties setBool:propTrackValue2 forKey:propTrackKey2];

  // When
  [target trackEvent:eventName withTypedProperties:trackEventProperties];

  // Then
  OCMVerify([self.analyticsClassMock trackEvent:eventName
                            withTypedProperties:expectedProperties
                          forTransmissionTarget:target
                                          flags:MSACFlagsDefault]);
}

- (void)testEventPropertiesCascading {

  // If
  [MSACAnalytics resetSharedInstance];
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [MSACAppCenter sharedInstance].sdkConfigured = YES;
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:@"appsecret"
                                transmissionTargetToken:@"token"
                                        fromApplication:YES];

  // Prepare target instances.
  MSACAnalyticsTransmissionTarget *grandParent = [MSACAnalytics transmissionTargetForToken:@"grand-parent"];
  MSACAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setEventPropertyString:@"1" forKey:@"a"];
  [grandParent.propertyConfigurator setEventPropertyString:@"2" forKey:@"b"];
  [grandParent.propertyConfigurator setEventPropertyString:@"3" forKey:@"c"];

  // Override some properties.
  [parent.propertyConfigurator setEventPropertyString:@"11" forKey:@"a"];
  [parent.propertyConfigurator setEventPropertyString:@"22" forKey:@"b"];

  // Set a new property in parent.
  [parent.propertyConfigurator setEventPropertyString:@"44" forKey:@"d"];

  // Just to show we still get value from parent which is inherited from grand parent, if we remove an override.
  [parent.propertyConfigurator setEventPropertyString:@"33" forKey:@"c"];
  [parent.propertyConfigurator removeEventPropertyForKey:@"c"];

  // Override a property.
  [child.propertyConfigurator setEventPropertyString:@"444" forKey:@"d"];

  // Set new properties in child.
  [child.propertyConfigurator setEventPropertyString:@"555" forKey:@"e"];
  [child.propertyConfigurator setEventPropertyString:@"666" forKey:@"f"];

  // Track event in child. Override some properties in trackEvent.
  NSMutableDictionary<NSString *, NSString *> *properties = [NSMutableDictionary new];
  [properties setValue:@"6666" forKey:@"f"];
  [properties setValue:@"7777" forKey:@"g"];

  // Mock channel group.
  __block MSACEventLog *eventLog;
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]).andDo(^(NSInvocation *invocation) {
    id<MSACLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    eventLog = (MSACEventLog *)log;
  });

  // When
  [child trackEvent:@"eventName" withProperties:properties];

  // Then
  XCTAssertNotNil(eventLog);
  XCTAssertEqual([eventLog.typedProperties.properties count], 7);
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"a"]).value, @"11");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"b"]).value, @"22");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"c"]).value, @"3");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"d"]).value, @"444");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"e"]).value, @"555");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"f"]).value, @"6666");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"g"]).value, @"7777");
}

- (void)testEventPropertiesCascadingWithTypes {

  // If
  [MSACAnalytics resetSharedInstance];
  id<MSACChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [MSACAppCenter sharedInstance].sdkConfigured = YES;
  [[MSACAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                              appSecret:@"appsecret"
                                transmissionTargetToken:@"token"
                                        fromApplication:YES];

  // Prepare target instances.
  MSACAnalyticsTransmissionTarget *grandParent = [MSACAnalytics transmissionTargetForToken:@"grand-parent"];
  MSACAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setEventPropertyString:@"1" forKey:@"a"];
  [grandParent.propertyConfigurator setEventPropertyDouble:2.0 forKey:@"b"];
  [grandParent.propertyConfigurator setEventPropertyString:@"3" forKey:@"c"];

  // Override some properties.
  [parent.propertyConfigurator setEventPropertyInt64:11 forKey:@"a"];
  [parent.propertyConfigurator setEventPropertyString:@"22" forKey:@"b"];

  // Set a new property in parent.
  [parent.propertyConfigurator setEventPropertyInt64:44 forKey:@"d"];

  // Just to show we still get value from parent which is inherited from grand parent, if we remove an override.
  [parent.propertyConfigurator setEventPropertyString:@"33" forKey:@"c"];
  [parent.propertyConfigurator removeEventPropertyForKey:@"c"];

  // Override a property.
  [child.propertyConfigurator setEventPropertyBool:YES forKey:@"d"];

  // Set new properties in child.
  [child.propertyConfigurator setEventPropertyDouble:55.5 forKey:@"e"];
  [child.propertyConfigurator setEventPropertyString:@"666" forKey:@"f"];

  // Track event in child. Override some properties in trackEvent.
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setDate:[NSDate dateWithTimeIntervalSince1970:6666] forKey:@"f"];
  [properties setString:@"7777" forKey:@"g"];

  // Mock channel group.
  __block MSACEventLog *eventLog;
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY flags:MSACFlagsDefault]).andDo(^(NSInvocation *invocation) {
    id<MSACLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    eventLog = (MSACEventLog *)log;
  });

  // When
  [child trackEvent:@"eventName" withTypedProperties:properties];

  // Then
  XCTAssertNotNil(eventLog);
  XCTAssertEqual([eventLog.typedProperties.properties count], 7);
  XCTAssertEqual(((MSACLongTypedProperty *)eventLog.typedProperties.properties[@"a"]).value, 11);
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"b"]).value, @"22");
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"c"]).value, @"3");
  XCTAssertEqual(((MSACBooleanTypedProperty *)eventLog.typedProperties.properties[@"d"]).value, YES);
  XCTAssertEqual(((MSACDoubleTypedProperty *)eventLog.typedProperties.properties[@"e"]).value, 55.5);
  XCTAssertEqualObjects(((MSACDateTimeTypedProperty *)eventLog.typedProperties.properties[@"f"]).value,
                        [NSDate dateWithTimeIntervalSince1970:6666]);
  XCTAssertEqualObjects(((MSACStringTypedProperty *)eventLog.typedProperties.properties[@"g"]).value, @"7777");
}

- (void)testAppExtensionCommonSchemaPropertiesWithoutOverriding {

  // If

  // Prepare target instance.
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"target"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"en-us";

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNil(target.propertyConfigurator.appVersion);
  XCTAssertNil(target.propertyConfigurator.appName);
  XCTAssertNil(target.propertyConfigurator.appLocale);
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"en-us");
}

- (void)testOverridingDefaultCommonSchemaProperties {

  // If

  // Prepare target instances.
  MSACAnalyticsTransmissionTarget *parent = [MSACAnalytics transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];
  [parent.propertyConfigurator setUserId:@"c:bob"];

  // Set a log with default values.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.userExt = [MSACUserExtension new];
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqual(log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqual(log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertEqual(log.ext.userExt.localId, parent.propertyConfigurator.userId);
}

- (void)testOverridingCommonSchemaProperties {

  // If

  // Prepare target instance.
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"target"];

  // Set properties to the target.
  [target.propertyConfigurator setAppVersion:@"8.4.1"];
  [target.propertyConfigurator setAppName:@"NewAppName"];
  [target.propertyConfigurator setAppLocale:@"en-us"];
  [target.propertyConfigurator setUserId:@"c:bob"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"target"];
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  log.ext.userExt = [MSACUserExtension new];
  log.ext.userExt.localId = @"c:alice";

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, target.propertyConfigurator.appVersion);
  XCTAssertEqual(log.ext.appExt.name, target.propertyConfigurator.appName);
  XCTAssertEqual(log.ext.appExt.locale, target.propertyConfigurator.appLocale);
  XCTAssertEqual(log.ext.userExt.localId, target.propertyConfigurator.userId);
}

- (void)testOverridingCommonSchemaPropertiesFromParent {

  // If

  // Prepare target instances.
  MSACAnalyticsTransmissionTarget *parent = [MSACAnalytics transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];
  [parent.propertyConfigurator setUserId:@"c:bob"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  log.ext.userExt = [MSACUserExtension new];
  log.ext.userExt.localId = @"c:alice";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqualObjects(log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(log.ext.userExt.localId, parent.propertyConfigurator.userId);
}

- (void)testOverridingCommonSchemaPropertiesDoNothingWhenTargetIsDisabled {

  // If

  // Prepare target instances.
  MSACAnalyticsTransmissionTarget *grandParent = [MSACAnalytics transmissionTargetForToken:@"grand-parent"];
  MSACAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setAppVersion:@"8.4.1"];
  [grandParent.propertyConfigurator setAppName:@"GrandParentAppName"];
  [grandParent.propertyConfigurator setAppLocale:@"en-us"];
  [grandParent.propertyConfigurator setUserId:@"c:alice"];

  // Set common properties to child.
  [child.propertyConfigurator setAppVersion:@"1.4.8"];
  [child.propertyConfigurator setAppName:@"ChildAppName"];
  [child.propertyConfigurator setAppLocale:@"fr-ca"];
  [child.propertyConfigurator setUserId:@"c:bob"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  log.ext.userExt = [MSACUserExtension new];
  log.ext.userExt.localId = @"c:charlie";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];
  [log addTransmissionTargetToken:@"grand-parent"];

  [grandParent setEnabled:NO];

  // When
  [grandParent.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"zh-cn");
  XCTAssertEqual(log.ext.userExt.localId, @"c:charlie");

  // If
  [child setEnabled:NO];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNotEqual(log.ext.appExt.ver, child.propertyConfigurator.appVersion);
  XCTAssertNotEqual(log.ext.appExt.name, child.propertyConfigurator.appName);
  XCTAssertNotEqual(log.ext.appExt.locale, child.propertyConfigurator.appLocale);
  XCTAssertNotEqual(log.ext.userExt.localId, child.propertyConfigurator.userId);

  // If

  // Reset a log.
  log = [MSACCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSACCSExtensions new];
  log.ext.appExt = [MSACAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  log.ext.userExt = [MSACUserExtension new];
  log.ext.userExt.localId = @"c:charlie";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];
  [log addTransmissionTargetToken:@"grand-parent"];

  // When
  [parent.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"zh-cn");
  XCTAssertEqual(log.ext.userExt.localId, @"c:charlie");
}

- (void)testOverridingCommonSchemaPropertiesWithTwoChildrenUnderTheSameParent {

  // If
  MSACAnalyticsTransmissionTarget *parent = [MSACAnalytics transmissionTargetForToken:@"parent"];
  MSACAnalyticsTransmissionTarget *child1 = [parent transmissionTargetForToken:@"child1"];
  MSACAnalyticsTransmissionTarget *child2 = [parent transmissionTargetForToken:@"child2"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];
  [parent.propertyConfigurator setUserId:@"c:alice"];

  // Set common properties to child1.
  [child1.propertyConfigurator setAppVersion:@"1.4.8"];
  [child1.propertyConfigurator setAppName:@"Child1AppName"];
  [child1.propertyConfigurator setAppLocale:@"fr-ca"];
  [child1.propertyConfigurator setUserId:@"c:bob"];

  // Parent log.
  MSACCommonSchemaLog *parentLog = [MSACCommonSchemaLog new];
  parentLog.tag = parent;
  parentLog.ext = [MSACCSExtensions new];
  parentLog.ext.appExt = [MSACAppExtension new];
  parentLog.ext.appExt.ver = @"0.0.1";
  parentLog.ext.appExt.name = @"base1AppName";
  parentLog.ext.appExt.locale = @"zh-cn";
  parentLog.ext.userExt = [MSACUserExtension new];
  parentLog.ext.userExt.localId = @"c:charlie";
  [parentLog addTransmissionTargetToken:@"parent"];

  // Child1 log.
  MSACCommonSchemaLog *child1Log = [MSACCommonSchemaLog new];
  child1Log.tag = child1;
  child1Log.ext = [MSACCSExtensions new];
  child1Log.ext.appExt = [MSACAppExtension new];
  child1Log.ext.appExt.ver = @"0.0.1";
  child1Log.ext.appExt.name = @"base1AppName";
  child1Log.ext.appExt.locale = @"zh-cn";
  child1Log.ext.userExt = [MSACUserExtension new];
  child1Log.ext.userExt.localId = @"c:charlie";
  [child1Log addTransmissionTargetToken:@"child1"];

  // Child2 log.
  MSACCommonSchemaLog *child2Log = [MSACCommonSchemaLog new];
  child2Log.tag = child2;
  child2Log.ext = [MSACCSExtensions new];
  child2Log.ext.appExt = [MSACAppExtension new];
  child2Log.ext.appExt.ver = @"0.0.2";
  child2Log.ext.appExt.name = @"base2AppName";
  child2Log.ext.appExt.locale = @"en-us";
  child2Log.ext.userExt = [MSACUserExtension new];
  child2Log.ext.userExt.localId = @"c:charlie";
  [child2Log addTransmissionTargetToken:@"child2"];

  // When
  [parent.propertyConfigurator channel:nil prepareLog:parentLog];
  [child1.propertyConfigurator channel:nil prepareLog:child1Log];
  [child2.propertyConfigurator channel:nil prepareLog:child2Log];

  // Then
  XCTAssertEqualObjects(parentLog.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(parentLog.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(parentLog.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(parentLog.ext.userExt.localId, parent.propertyConfigurator.userId);
  XCTAssertEqualObjects(child1Log.ext.appExt.ver, child1.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(child1Log.ext.appExt.name, child1.propertyConfigurator.appName);
  XCTAssertEqualObjects(child1Log.ext.appExt.locale, child1.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(child1Log.ext.userExt.localId, child1.propertyConfigurator.userId);
  XCTAssertEqualObjects(child2Log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(child2Log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(child2Log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(child2Log.ext.userExt.localId, parent.propertyConfigurator.userId);
  XCTAssertNil(child2.propertyConfigurator.appVersion);
  XCTAssertNil(child2.propertyConfigurator.appName);
  XCTAssertNil(child2.propertyConfigurator.appLocale);
  XCTAssertNil(child2.propertyConfigurator.userId);
}

- (void)testOverridingInvalidUserId {

  // If
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"invalidUserAppIdTest"];

  // Set invalid user identifier.
  [target.propertyConfigurator setUserId:@"invalid:invalid"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"invalidUserAppIdTest"];
  log.ext = [MSACCSExtensions new];
  log.ext.userExt = [MSACUserExtension new];

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNil(log.ext.userExt.localId);
}

- (void)testOverridingValidUserIdThenUnset {

  // If
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"unsetUserIdTest"];

  // Set properties to the target.
  [target.propertyConfigurator setUserId:@"c:alice"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"unsetUserIdTest"];
  log.ext = [MSACCSExtensions new];
  log.ext.userExt = [MSACUserExtension new];

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.userExt.localId, @"c:alice");

  // If

  // Unset userId.
  [target.propertyConfigurator setUserId:nil];

  // Reset a log.
  log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"target"];
  log.ext = [MSACCSExtensions new];
  log.ext.userExt = [MSACUserExtension new];

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNil(log.ext.userExt.localId);
}

- (void)testOverridingValidUserIdWithInvalidOne {

  // If
  MSACAnalyticsTransmissionTarget *target = [MSACAnalytics transmissionTargetForToken:@"target"];

  // Set valid userId.
  [target.propertyConfigurator setUserId:@"c:alice"];

  // Set a log.
  MSACCommonSchemaLog *log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"target"];
  log.ext = [MSACCSExtensions new];
  log.ext.userExt = [MSACUserExtension new];

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.userExt.localId, @"c:alice");

  // If

  // Set invalid userId on existing target having a valid userId.
  [target.propertyConfigurator setUserId:@"invalid:invalid"];

  // Reset a log.
  log = [MSACCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"target"];
  log.ext = [MSACCSExtensions new];
  log.ext.userExt = [MSACUserExtension new];

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then the value did not change.
  XCTAssertEqual(log.ext.userExt.localId, @"c:alice");
}

- (void)testAddAuthenticationProvider {

  // If
  MSACAnalyticsAuthenticationProvider *provider = [[MSACAnalyticsAuthenticationProvider alloc]
      initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaCompact
                       ticketKey:@"ticketKey"
                        delegate:OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate))];

  // When
  [MSACAnalyticsTransmissionTarget addAuthenticationProvider:provider];

  // Then
  XCTAssertNotNil(MSACAnalyticsTransmissionTarget.authenticationProvider);
  XCTAssertEqual(provider, MSACAnalyticsTransmissionTarget.authenticationProvider);

  // If
  MSACAnalyticsAuthenticationProvider *provider2 =
      [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaDelegate
                                                                    ticketKey:@"ticketKey2"
                                                                     delegate:OCMOCK_ANY];

  // When
  dispatch_async(dispatch_get_main_queue(), ^{
    [MSACAnalyticsTransmissionTarget addAuthenticationProvider:provider2];
  });
  [MSACAnalyticsTransmissionTarget addAuthenticationProvider:provider];
  dispatch_async(dispatch_get_main_queue(), ^{
    [MSACAnalyticsTransmissionTarget addAuthenticationProvider:provider2];
  });

  // Then
  XCTAssertEqual(provider, MSACAnalyticsTransmissionTarget.authenticationProvider);
}

- (void)testPauseSucceedsWhenTargetIsEnabled {

  // If
  MSACAnalyticsTransmissionTarget *sut = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];

  // When
  [sut pause];

  // Then
  OCMVerify([self.analyticsClassMock pauseTransmissionTargetForToken:kMSACTestTransmissionToken]);
}

- (void)testResumeSucceedsWhenTargetIsEnabled {

  // If
  MSACAnalyticsTransmissionTarget *sut = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];

  // When
  [sut resume];

  // Then
  OCMVerify([self.analyticsClassMock resumeTransmissionTargetForToken:kMSACTestTransmissionToken]);
}

- (void)testPauseDoesNotPauseWhenTargetIsDisabled {

  // If
  MSACAnalyticsTransmissionTarget *sut = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Then
  OCMReject([self.analyticsClassMock pauseTransmissionTargetForToken:kMSACTestTransmissionToken]);

  // When
  [MSACAnalytics setEnabled:NO];
  [sut pause];
}

- (void)testResumeDoesNotResumeWhenTargetIsDisabled {

  // If
  MSACAnalyticsTransmissionTarget *sut = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Then
  OCMReject([self.analyticsClassMock resumeTransmissionTargetForToken:kMSACTestTransmissionToken]);

  // When
  [sut setEnabled:NO];
  [sut resume];
}

- (void)testPausedAndDisabledTargetIsResumedWhenEnabled {

  // If
  MSACAnalyticsTransmissionTarget *sut = [MSACAnalytics transmissionTargetForToken:kMSACTestTransmissionToken];
  [sut pause];
  [sut setEnabled:NO];

  // When
  [sut setEnabled:YES];

  // Then
  OCMVerify([self.analyticsClassMock resumeTransmissionTargetForToken:kMSACTestTransmissionToken]);
}

@end
