// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include <Foundation/Foundation.h>

#if !TARGET_OS_TV
#import "MSACCustomProperties.h"
#import "MSACCustomPropertiesLog.h"
#endif

#import "MSACAppCenter.h"
#import "MSACAppCenterIngestion.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppCenterPrivate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACDeviceTrackerPrivate.h"
#import "MSACHttpIngestionPrivate.h"
#import "MSACMockSecondService.h"
#import "MSACMockService.h"
#import "MSACMockUserDefaults.h"
#import "MSACOneCollectorChannelDelegate.h"
#import "MSACOneCollectorChannelDelegatePrivate.h"
#import "MSACOneCollectorIngestion.h"
#import "MSACSessionContextPrivate.h"
#import "MSACStartServiceLog.h"
#import "MSACTestFrameworks.h"
#import "MSACUserIdContextPrivate.h"

static NSString *const kMSACInstallIdStringExample = @"F18499DA-5C3D-4F05-B4E8-D8C9C06A6F09";

// NSUUID can return this nullified InstallId while creating a UUID from a nil string, we want to avoid this.
static NSString *const kMSACNullifiedInstallIdString = @"00000000-0000-0000-0000-000000000000";

@interface MSACAppCenterTest : XCTestCase

@property(nonatomic) MSACAppCenter *sut;
@property(nonatomic) MSACMockUserDefaults *settingsMock;
@property(nonatomic) NSString *installId;
@property(nonatomic) id deviceTrackerMock;
@property(nonatomic) id sessionContextMock;
@property(nonatomic) id channelGroupMock;
@property(nonatomic) id channelUnitMock;

@end

@implementation MSACAppCenterTest

- (void)setUp {
  [super setUp];
  [MSACAppCenter resetSharedInstance];
  [MSACUserIdContext resetSharedInstance];

  // System Under Test.
  self.sut = [[MSACAppCenter alloc] init];
  self.settingsMock = [MSACMockUserDefaults new];
  self.channelGroupMock = OCMClassMock([MSACChannelGroupDefault class]);
  self.channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock alloc]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:OCMOCK_ANY]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(self.channelUnitMock);

  // Device tracker.
  [MSACDeviceTracker resetSharedInstance];
  self.deviceTrackerMock = OCMClassMock([MSACDeviceTracker class]);
  OCMStub([self.deviceTrackerMock sharedInstance]).andReturn(self.deviceTrackerMock);

  // Session context.
  [MSACSessionContext resetSharedInstance];
  self.sessionContextMock = OCMClassMock([MSACSessionContext class]);
  OCMStub([self.sessionContextMock sharedInstance]).andReturn(self.sessionContextMock);
}

- (void)tearDown {
  [self.settingsMock stopMocking];
  [self.channelGroupMock stopMocking];
  [self.deviceTrackerMock stopMocking];
  [self.sessionContextMock stopMocking];
  [MSACMockService resetSharedInstance];
  [MSACMockSecondService resetSharedInstance];
  [MSACDeviceTracker resetSharedInstance];
  [MSACSessionContext resetSharedInstance];
  [super tearDown];
}

#pragma mark - install Id

- (void)testGetInstallIdFromEmptyStorage {

  // If
  // InstallId is removed from the storage.
  [self.settingsMock removeObjectForKey:kMSACInstallIdKey];

  // When
  NSUUID *installId = self.sut.installId;
  NSString *installIdString = [installId UUIDString];

  // Then
  assertThat(installId, notNilValue());
  assertThat(installIdString, notNilValue());
  assertThatInteger([installIdString length], greaterThan(@(0)));
  assertThat(installIdString, isNot(kMSACNullifiedInstallIdString));
}

- (void)testStartWithAppSecretOnly {

  // When
  NSString *appSecret = MSAC_UUID_STRING;
  [MSACAppCenter start:appSecret withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertNil([[MSACAppCenter sharedInstance] defaultTransmissionTargetToken]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] appSecret] isEqualToString:appSecret]);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
  OCMVerify([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:MSACStartServiceLog.class] flags:MSACFlagsDefault]);
}

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (void)testStartWithAppSecretAndTransmissionTokenForIos {

  // If
  NSString *appSecret = MSAC_UUID_STRING;
  NSString *transmissionTargetKey = @"target=";
  NSString *appSecretKey = @"ios=";
  NSString *transmissionTargetString = @"transmissionTargetToken";
  NSString *secret = [NSString stringWithFormat:@"%@%@;%@%@", appSecretKey, appSecret, transmissionTargetKey, transmissionTargetString];

  // When
  [MSACAppCenter start:secret withServices:@[ MSACMockService.class ]];
  [MSACAppCenter startService:MSACMockSecondService.class];

  // Then
  XCTAssertTrue([[[MSACAppCenter sharedInstance] appSecret] isEqualToString:appSecret]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([[[MSACMockService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
  XCTAssertTrue([[[MSACMockSecondService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  OCMVerify([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:MSACStartServiceLog.class] flags:MSACFlagsDefault]);
}
#endif

#if TARGET_OS_MACCATALYST
- (void)testStartWithAppSecretAndTransmissionTokenForMacCatalyst {

  // If
  NSString *appSecret = MSAC_UUID_STRING;
  NSString *transmissionTargetKey = @"target=";
  NSString *appSecretKey = @"macos=";
  NSString *transmissionTargetString = @"transmissionTargetToken";
  NSString *secret = [NSString stringWithFormat:@"%@%@;%@%@", appSecretKey, appSecret, transmissionTargetKey, transmissionTargetString];

  // When
  [MSACAppCenter start:secret withServices:@[ MSACMockService.class ]];
  [MSACAppCenter startService:MSACMockSecondService.class];

  // Then
  XCTAssertTrue([[[MSACAppCenter sharedInstance] appSecret] isEqualToString:appSecret]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([[[MSACMockService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
  XCTAssertTrue([[[MSACMockSecondService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  OCMVerify([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:MSACStartServiceLog.class] flags:MSACFlagsDefault]);
}
#endif

- (void)testStartWithAppSecretAndTransmissionToken {

  // If
  NSString *appSecret = MSAC_UUID_STRING;
  NSString *transmissionTargetKey = @"target=";
  NSString *transmissionTargetString = @"transmissionTargetToken";
  NSString *secret = [NSString stringWithFormat:@"%@;%@%@", appSecret, transmissionTargetKey, transmissionTargetString];

  // When
  [MSACAppCenter start:secret withServices:@[ MSACMockService.class ]];
  [MSACAppCenter startService:MSACMockSecondService.class];

  // Then
  XCTAssertTrue([[[MSACAppCenter sharedInstance] appSecret] isEqualToString:appSecret]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([[[MSACMockService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
  XCTAssertTrue([[[MSACMockSecondService sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  OCMVerify([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:MSACStartServiceLog.class] flags:MSACFlagsDefault]);
}

- (void)testStartWithNoAppSecret {

  // If
  NSArray *services = @[ MSACMockService.class, MSACMockSecondService.class ];

  // When
  [MSACAppCenter startWithServices:services];

  // Then
  XCTAssertNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testStartWithTransmissionTokenOnly {

  // If
  NSString *transmissionTargetKey = @"target=";
  NSString *transmissionTargetString = @"transmissionTargetToken";
  NSString *secret = [NSString stringWithFormat:@"%@%@", transmissionTargetKey, transmissionTargetString];

  // When
  [MSACAppCenter start:secret withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testStartSameServiceFromLibraryAndThenApplication {

  // When
  [MSACAppCenter startFromLibraryWithServices:@[ MSACMockSecondService.class ]];

  // Then
  XCTAssertNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertFalse([MSACAppCenter isConfigured]);
  XCTAssertNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockSecondService.class ]];

  // Then
  XCTAssertNotNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertTrue([MSACAppCenter isConfigured]);
  XCTAssertNotNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testStartServicesFromLibraryAndThenApplication {

  // When
  [MSACAppCenter startFromLibraryWithServices:@[ MSACMockSecondService.class ]];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];

  // Then
  XCTAssertNotNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertNotNil([MSACMockService sharedInstance].appSecret);
  XCTAssertNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testStartSameServiceFromApplicationAndThenLibrary {

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockSecondService.class ]];

  // Then
  XCTAssertNotNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertTrue([MSACAppCenter isConfigured]);
  XCTAssertNotNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);

  // When
  [MSACAppCenter startFromLibraryWithServices:@[ MSACMockSecondService.class ]];

  // Then
  XCTAssertNotNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertTrue([MSACAppCenter isConfigured]);
  XCTAssertNotNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testStartServicesFromApplicationAndThenLibrary {

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];
  [MSACAppCenter startFromLibraryWithServices:@[ MSACMockSecondService.class ]];

  // Then
  XCTAssertNotNil([[MSACAppCenter sharedInstance] appSecret]);
  XCTAssertNotNil([MSACMockService sharedInstance].appSecret);
  XCTAssertNil([MSACMockSecondService sharedInstance].appSecret);
  XCTAssertTrue([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);
}

- (void)testConfigureWithNoAppSecret {

  // When
  [MSACAppCenter configure];

  // Then
  XCTAssertTrue([MSACAppCenter isConfigured]);
}

- (void)testGetInstallIdFroMSACtorage {

  // If
  // Expected installId is added to the storage.
  [self.settingsMock setObject:kMSACInstallIdStringExample forKey:kMSACInstallIdKey];

  // When
  NSUUID *installId = self.sut.installId;

  // Then
  assertThat(installId, is(MSAC_UUID_FROM_STRING(kMSACInstallIdStringExample)));
  assertThat([installId UUIDString], is(kMSACInstallIdStringExample));
}

- (void)testGetInstallIdFromBadStorage {

  // If
  // Unexpected installId is added to the storage.
  [self.settingsMock setObject:MSAC_UUID_FROM_STRING(@"42") forKey:kMSACInstallIdKey];

  // When
  NSUUID *installId = self.sut.installId;
  NSString *installIdString = [installId UUIDString];

  // Then
  assertThat(installId, notNilValue());
  assertThat(installIdString, notNilValue());
  assertThatInteger([installIdString length], greaterThan(@(0)));
  assertThat(installIdString, isNot(kMSACNullifiedInstallIdString));
  assertThat([installId UUIDString], isNot(@"42"));
}

- (void)testGetInstallIdTwice {

  // If
  // InstallId is removed from the storage.
  [self.settingsMock removeObjectForKey:kMSACInstallIdKey];

  // When
  NSUUID *installId1 = self.sut.installId;
  NSString *installId1String = [installId1 UUIDString];

  // Then
  assertThat(installId1, notNilValue());
  assertThat(installId1String, notNilValue());
  assertThatInteger([installId1String length], greaterThan(@(0)));
  assertThat(installId1String, isNot(kMSACNullifiedInstallIdString));

  // When
  // Second pick
  NSUUID *installId2 = self.sut.installId;

  // Then
  assertThat(installId1, is(installId2));
  assertThat([installId1 UUIDString], is([installId2 UUIDString]));
}

- (void)testInstallIdPersistency {

  // If
  // InstallId is removed from the storage.
  [self.settingsMock removeObjectForKey:kMSACInstallIdKey];

  // When
  NSUUID *installId1 = self.sut.installId;
  self.sut = [[MSACAppCenter alloc] init];
  NSUUID *installId2 = self.sut.installId;

  // Then
  assertThat(installId1, is(installId2));
  assertThat([installId1 UUIDString], is([installId2 UUIDString]));
}

- (void)testSetEnabled {

  // If
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];

  // When
  [self.settingsMock setObject:@NO forKey:kMSACAppCenterIsEnabledKey];

  // Then
  XCTAssertFalse([MSACAppCenter isEnabled]);

  // When
  [self.settingsMock setObject:@YES forKey:kMSACAppCenterIsEnabledKey];

  // Then
  XCTAssertTrue([MSACAppCenter isEnabled]);

  // When
  [MSACAppCenter setEnabled:NO];

  // Then
  XCTAssertFalse([MSACAppCenter isEnabled]);
  XCTAssertFalse([MSACMockService isEnabled]);
  XCTAssertFalse(((NSNumber *)[self.settingsMock objectForKey:kMSACAppCenterIsEnabledKey]).boolValue);
  OCMVerify([self.deviceTrackerMock clearDevices]);
  OCMVerify([self.sessionContextMock clearSessionHistoryAndKeepCurrentSession:NO]);

  // When
  [MSACAppCenter setEnabled:YES];

  // Then
  XCTAssertTrue([MSACAppCenter isEnabled]);
  XCTAssertTrue([MSACMockService isEnabled]);
  XCTAssertTrue(((NSNumber *)[self.settingsMock objectForKey:kMSACAppCenterIsEnabledKey]).boolValue);
}

- (void)testClearUserIdHistoryWhenAppCenterIsDisabled {

  // If
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];
  [[MSACUserIdContext sharedInstance] setUserId:@"alice"];
  [MSACUserIdContext resetSharedInstance];
  [[MSACUserIdContext sharedInstance] setUserId:@"bob"];

  // Then
  XCTAssertEqual(2, [[MSACUserIdContext sharedInstance].userIdHistory count]);

  // When
  [MSACAppCenter setEnabled:NO];

  // Then
  XCTAssertFalse([MSACAppCenter isEnabled]);

  // Clearing history won't remove the most recent userId.
  XCTAssertEqual(1, [[MSACUserIdContext sharedInstance].userIdHistory count]);
}

- (void)testSetLogUrl {

  // If
  NSString *fakeUrl = @"http://testUrl:1234";
  NSString *updateUrl = @"http://testUrlUpdate:1234";

  // When
  [MSACAppCenter setLogUrl:fakeUrl];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];

  // Then
  XCTAssertTrue([[[MSACAppCenter sharedInstance] logUrl] isEqualToString:fakeUrl]);

  // Cast to void to get rid of warning that says "Expression result unused".
  OCMVerify((void)[self.channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:equalTo(fakeUrl)]);

  // When
  [MSACAppCenter setLogUrl:updateUrl];

  // Then
  OCMVerify([self.channelGroupMock setLogUrl:equalTo(updateUrl)]);
}

- (void)testDefaultLogUrl {

  // If
  NSString *defaultUrl = @"https://in.appcenter.ms";

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];

  // Then
  XCTAssertNil([[MSACAppCenter sharedInstance] logUrl]);

  // Cast to void to get rid of warning that says "Expression result unused".
  OCMVerify((void)[self.channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:equalTo(defaultUrl)]);
}

- (void)testDefaultLogUrlWithNoAppsecret {
  NSString *defaultUrl = @"https://mobile.events.data.microsoft.com";

  [MSACAppCenter startWithServices:nil];
  NSURL *endPointLogUrl = [[[[MSACAppCenter sharedInstance] oneCollectorChannelDelegate] oneCollectorIngestion] sendURL];
  XCTAssertTrue([[endPointLogUrl absoluteString] containsString:defaultUrl]);
}

- (void)testSetLogUrlWithNoAppsecret {
  NSString *fakeUrl = @"http://testUrl:1234";
  NSString *updateUrl = @"http://testUrlUpdate:1234";

  [MSACAppCenter setLogUrl:fakeUrl];
  [MSACAppCenter startWithServices:nil];
  XCTAssertTrue([[[MSACAppCenter sharedInstance] logUrl] isEqualToString:fakeUrl]);
  NSURL *endPointLogUrl = [[[[MSACAppCenter sharedInstance] oneCollectorChannelDelegate] oneCollectorIngestion] sendURL];
  XCTAssertTrue([[endPointLogUrl absoluteString] containsString:fakeUrl]);

  [MSACAppCenter setLogUrl:updateUrl];
  XCTAssertTrue([[[MSACAppCenter sharedInstance] logUrl] isEqualToString:updateUrl]);
  endPointLogUrl = [[[[MSACAppCenter sharedInstance] oneCollectorChannelDelegate] oneCollectorIngestion] sendURL];
  XCTAssertTrue([[endPointLogUrl absoluteString] containsString:updateUrl]);
}

- (void)testSdkVersion {
  NSString *version = [NSString stringWithUTF8String:APP_CENTER_C_VERSION];
  XCTAssertTrue([[MSACAppCenter sdkVersion] isEqualToString:version]);
}

- (void)testDisableServicesWithEnvironmentVariable {
  const char *disableVariableCstr = [kMSACDisableVariable UTF8String];
  const char *disableAllCstr = [kMSACDisableAll UTF8String];

  // If
  setenv(disableVariableCstr, disableAllCstr, 1);
  [[MSACMockService sharedInstance] setStarted:NO];
  [[MSACMockSecondService sharedInstance] setStarted:NO];

  // When
  [MSACAppCenter start:@"AppSecret" withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertFalse([MSACMockSecondService sharedInstance].started);

  // If
  setenv(disableVariableCstr, [[MSACMockService serviceName] UTF8String], 1);
  [[MSACMockService sharedInstance] setStarted:NO];
  [[MSACMockSecondService sharedInstance] setStarted:NO];
  [MSACAppCenter resetSharedInstance];

  // When
  [MSACAppCenter start:@"AppSecret" withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertTrue([MSACMockSecondService sharedInstance].started);

  // If
  NSString *disableList =
      [NSString stringWithFormat:@"%@,SomeService,%@", [MSACMockService serviceName], [MSACMockSecondService serviceName]];
  setenv(disableVariableCstr, [disableList UTF8String], 1);
  [[MSACMockService sharedInstance] setStarted:NO];
  [[MSACMockSecondService sharedInstance] setStarted:NO];
  [MSACAppCenter resetSharedInstance];

  // When
  [MSACAppCenter start:@"AppSecret" withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertFalse([MSACMockSecondService sharedInstance].started);

  // Repeat previous test but with some whitespace.
  // If
  disableList = [NSString stringWithFormat:@" %@ , SomeService,%@ ", [MSACMockService serviceName], [MSACMockSecondService serviceName]];
  setenv(disableVariableCstr, [disableList UTF8String], 1);
  [[MSACMockService sharedInstance] setStarted:NO];
  [[MSACMockSecondService sharedInstance] setStarted:NO];
  [MSACAppCenter resetSharedInstance];

  // When
  [MSACAppCenter start:@"AppSecret" withServices:@[ MSACMockService.class, MSACMockSecondService.class ]];

  // Then
  XCTAssertFalse([MSACMockService sharedInstance].started);
  XCTAssertFalse([MSACMockSecondService sharedInstance].started);

  // Special tear down.
  setenv(disableVariableCstr, "", 1);
}

- (void)testIsRunningInAppCenterTestCloudWithEnvironmentVariable {

  // If
  const char *isRunningVariableCstr = [kMSACRunningInAppCenter UTF8String];
  const char *isRunningCstr = [kMSACTrueEnvironmentString UTF8String];
  setenv(isRunningVariableCstr, isRunningCstr, 1);

  // Then
  XCTAssertTrue([MSACAppCenter isRunningInAppCenterTestCloud]);

  // If
  setenv(isRunningVariableCstr, "", 1);

  // Then
  XCTAssertFalse([MSACAppCenter isRunningInAppCenterTestCloud]);
}

#if !TARGET_OS_TV
- (void)testSetCustomPropertiesWithEmptyPropertiesDoesNotEnqueueCustomPropertiesLog {

  // If
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];
  id channelUnit = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACCustomPropertiesLog class]] flags:MSACFlagsDefault]).andDo(nil);
  [MSACAppCenter sharedInstance].channelUnit = channelUnit;

  // When
  OCMReject([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACCustomPropertiesLog class]] flags:MSACFlagsDefault]);
  MSACCustomProperties *customProperties = [MSACCustomProperties new];
  [MSACAppCenter setCustomProperties:customProperties];

  // Then
  OCMVerifyAll(channelUnit);
}

- (void)testSetCustomProperties {

  // If
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];
  id channelUnit = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACCustomPropertiesLog class]] flags:MSACFlagsDefault]).andDo(nil);
  [MSACAppCenter sharedInstance].channelUnit = channelUnit;

  // When
  MSACCustomProperties *customProperties = [MSACCustomProperties new];
  [customProperties setString:@"test" forKey:@"test"];
  [MSACAppCenter setCustomProperties:customProperties];

  // Then
  OCMVerify([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACCustomPropertiesLog class]] flags:MSACFlagsDefault]);

  // When
  // Not allow processLog more
  OCMReject([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACCustomPropertiesLog class]] flags:MSACFlagsDefault]);
  [MSACAppCenter setCustomProperties:nil];
  [MSACAppCenter setCustomProperties:[MSACCustomProperties new]];

  // Then
  OCMVerifyAll(channelUnit);
}
#endif

- (void)testConfigureWithAppSecret {
  [MSACAppCenter configureWithAppSecret:@"App-Secret"];
  XCTAssertTrue([MSACAppCenter isConfigured]);
}

- (void)testConfigureWithAppSecretAndTransmissionToken {

  // If
  NSString *appSecret = MSAC_UUID_STRING;
  NSString *transmissionTargetKey = @"target=";
  NSString *transmissionTargetString = @"transmissionTargetToken";
  NSString *secret = [NSString stringWithFormat:@"%@;%@%@", appSecret, transmissionTargetKey, transmissionTargetString];

  // When
  [MSACAppCenter configureWithAppSecret:secret];

  // Then
  XCTAssertTrue([MSACAppCenter isConfigured]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] appSecret] isEqualToString:appSecret]);
  XCTAssertTrue([[[MSACAppCenter sharedInstance] defaultTransmissionTargetToken] isEqualToString:transmissionTargetString]);
}

- (void)testStartServiceWithInvalidValues {
  NSUInteger servicesCount = [[MSACAppCenter sharedInstance] services].count;
  [MSACAppCenter startService:[MSACAppCenter class]];
  [MSACAppCenter startService:[NSString class]];
  [MSACAppCenter startService:nil];
  XCTAssertEqual(servicesCount, [[MSACAppCenter sharedInstance] services].count);
}

- (void)testStartServiceWithoutAppSecret {
  [MSACAppCenter startService:[MSACMockService class]];
  XCTAssertEqual((uint)0, [[MSACAppCenter sharedInstance] services].count);
  [MSACAppCenter startService:[MSACMockSecondService class]];
  XCTAssertEqual((uint)0, [[MSACAppCenter sharedInstance] services].count);
}

- (void)testStartWithoutServices {

  // Not allow processLog.
  OCMReject([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACStartServiceLog class]] flags:MSACFlagsDefault]);

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];

  // Then
  OCMVerifyAll(self.channelUnitMock);
}

- (void)testStartServiceLogIsSentAfterStartService {

  // If
  [MSACAppCenter configureWithAppSecret:MSAC_UUID_STRING];
  id channelUnit = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACStartServiceLog class]] flags:MSACFlagsDefault]).andDo(nil);
  [MSACAppCenter sharedInstance].channelUnit = channelUnit;

  // When
  [MSACAppCenter startService:MSACMockService.class];

  // Then
  OCMVerify([channelUnit enqueueItem:[OCMArg isKindOfClass:[MSACStartServiceLog class]] flags:MSACFlagsDefault]);
}

- (void)testDisabledCoreStatus {

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];
  [MSACAppCenter setEnabled:NO];

  // Then
  XCTAssertFalse([MSACMockService isEnabled]);
  OCMVerify([self.channelGroupMock setEnabled:NO andDeleteDataOnDisabled:YES]);
}

- (void)testDisabledCorePersistedStatus {

  // If
  [self.settingsMock setObject:@NO forKey:kMSACAppCenterIsEnabledKey];

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@[ MSACMockService.class ]];

  // Then
  XCTAssertFalse([MSACMockService isEnabled]);
  OCMVerify([self.channelGroupMock setEnabled:NO andDeleteDataOnDisabled:YES]);
}

- (void)testStartServiceLogWithDisabledCore {

  // If
  __block NSInteger logsProcessed = 0;
  __block MSACStartServiceLog *log = nil;
  OCMStub([self.channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSACStartServiceLog class]] flags:MSACFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&log atIndex:2];
        logsProcessed++;
      });

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];
  [MSACAppCenter setEnabled:NO];
  [MSACAppCenter startService:MSACMockService.class];
  [MSACAppCenter startService:MSACMockSecondService.class];

  // Then
  assertThatInteger(logsProcessed, equalToInteger(0));
  XCTAssertFalse([MSACMockService isEnabled]);
  XCTAssertFalse([MSACMockSecondService isEnabled]);
  XCTAssertNil(log);

  // When
  [MSACAppCenter setEnabled:YES];

  // Then
  assertThatInteger(logsProcessed, equalToInteger(1));
  XCTAssertNotNil(log);
  NSArray *expected = @[ @"MSMockService", @"MSMockSecondService" ];
  XCTAssertTrue([log.services isEqual:expected]);
}

- (void)testSortingServicesWorks {

  // If
  id<MSACServiceCommon> mockServiceMaxPrio = OCMProtocolMock(@protocol(MSACServiceCommon));
  OCMStub([mockServiceMaxPrio sharedInstance]).andReturn(mockServiceMaxPrio);
  OCMStub([mockServiceMaxPrio initializationPriority]).andReturn(MSACInitializationPriorityMax);

  id<MSACServiceCommon> mockServiceDefaultPrio = OCMProtocolMock(@protocol(MSACServiceCommon));
  OCMStub([mockServiceDefaultPrio sharedInstance]).andReturn(mockServiceDefaultPrio);
  OCMStub([mockServiceDefaultPrio initializationPriority]).andReturn(MSACInitializationPriorityDefault);

  // When
  NSArray<MSACServiceAbstract *> *sorted = [self.sut sortServices:@[ (Class)mockServiceDefaultPrio, (Class)mockServiceMaxPrio ]];

  // Then
  XCTAssertTrue([sorted[0] initializationPriority] == MSACInitializationPriorityMax);
  XCTAssertTrue([sorted[1] initializationPriority] == MSACInitializationPriorityDefault);
}

- (void)testChannelOneCollectorDelegateSet {

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];

  // Then
  OCMVerify([self.channelGroupMock addDelegate:[OCMArg isKindOfClass:[MSACOneCollectorChannelDelegate class]]]);
}

#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
- (void)testAppIsBackgrounded {

  // If
  id<MSACChannelGroupProtocol> channelGroup = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self.sut configureWithAppSecret:@"AppSecret" transmissionTargetToken:nil fromApplication:YES];
  self.sut.channelGroup = channelGroup;

  // When
  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:self.sut];
  // Then
  OCMVerify([channelGroup pauseWithIdentifyingObject:self.sut]);
}

- (void)testAppIsForegrounded {

  // If
  id<MSACChannelGroupProtocol> channelGroup = OCMProtocolMock(@protocol(MSACChannelGroupProtocol));
  [self.sut configureWithAppSecret:@"AppSecret" transmissionTargetToken:nil fromApplication:YES];
  self.sut.channelGroup = channelGroup;

  // When
  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification

                                                      object:self.sut];
  // Then
  OCMVerify([channelGroup resumeWithIdentifyingObject:self.sut]);
}
#endif

- (void)testSetStorageSizeSetsProperties {

  // If
  long dbSize = 2 * 1024 * 1024;
  void (^completionBlock)(BOOL) = ^(__unused BOOL success) {
  };

  // When
  [MSACAppCenter setMaxStorageSize:dbSize completionHandler:completionBlock];

  // Then
  XCTAssertNotNil([MSACAppCenter sharedInstance].requestedMaxStorageSizeInBytes);
  XCTAssertEqualObjects(@(dbSize), [MSACAppCenter sharedInstance].requestedMaxStorageSizeInBytes);
  XCTAssertNotNil([MSACAppCenter sharedInstance].maxStorageSizeCompletionHandler);
  XCTAssertEqual(completionBlock, [MSACAppCenter sharedInstance].maxStorageSizeCompletionHandler);
}

- (void)testSetStorageHandlerCannotBeCalledAfterStart {

  // If
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];
  long dbSize = 2 * 1024 * 1024;

  // When
  [MSACAppCenter setMaxStorageSize:dbSize
                 completionHandler:^(BOOL success) {
                   // Then
                   XCTAssertFalse(success);
                 }];
}

- (void)testSetStorageHandlerCanOnlyBeCalledOnce {

  // If
  long dbSize = 2 * 1024 * 1024;

  // When
  [MSACAppCenter setMaxStorageSize:dbSize
                 completionHandler:^(__unused BOOL success){
                 }];
  [MSACAppCenter setMaxStorageSize:dbSize + 1
                 completionHandler:^(__unused BOOL success){
                 }];

  // Then
  XCTAssertEqual(dbSize, [[MSACAppCenter sharedInstance].requestedMaxStorageSizeInBytes longValue]);
}

- (void)testSetStorageSizeBelowMaximumLogSizeFails {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler invoked."];

  // When
  [MSACAppCenter setMaxStorageSize:10
                 completionHandler:^(BOOL success) {
                   // Then
                   XCTAssertFalse(success);
                   [expectation fulfill];
                 }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testSetValidUserIdForAppCenter {

  // If
  NSString *userId = @"user123";

  // When
  [MSACAppCenter setUserId:userId];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);

  // When
  [MSACAppCenter startFromLibraryWithServices:@[ MSACMockService.class ]];
  [MSACAppCenter setUserId:userId];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);

  // When
  [MSACAppCenter configureWithAppSecret:@"AppSecret"];
  [MSACAppCenter setUserId:userId];

  // Then
  XCTAssertEqual([[MSACUserIdContext sharedInstance] userId], userId);

  // When
  [MSACAppCenter setUserId:nil];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);
}

- (void)testSetUserIdWithoutSecret {

  // If
  NSString *userId = @"user123";

  // When
  [MSACAppCenter configure];
  [MSACAppCenter setUserId:userId];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);
}

- (void)testSetInvalidUserIdForAppCenter {

  // If
  NSString *userId = @"";
  for (int i = 0; i < 257; i++) {
    userId = [userId stringByAppendingString:@"x"];
  }
  [MSACAppCenter configureWithAppSecret:@"AppSecret"];

  // When
  [MSACAppCenter setUserId:userId];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);
}

- (void)testSetInvalidUserIdForTransmissionTarget {

  // If
  [MSACAppCenter configureWithAppSecret:@"target=transmissionTargetToken"];

  // When
  // Set an empty userId
  [MSACAppCenter setUserId:@""];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);

  // When
  // Set another empty userId
  [MSACAppCenter setUserId:@"c:"];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);

  // When
  // Set a userId with invalid prefix
  [MSACAppCenter setUserId:@"foobar:alice"];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userId]);

  // When
  // Set a valid userId without prefix
  [MSACAppCenter setUserId:@"alice"];

  // Then
  XCTAssertEqual([[MSACUserIdContext sharedInstance] userId], @"alice");

  // When
  // Set a valid userId with prefix c:
  [MSACAppCenter setUserId:@"c:alice"];

  // Then
  XCTAssertEqual([[MSACUserIdContext sharedInstance] userId], @"c:alice");

  // When
  // Set a userId with invalid prefix again
  [MSACAppCenter setUserId:@"foobar:alice"];

  // Then
  // Current userId shouldn't be overridden by the invalid one.
  XCTAssertEqual([[MSACUserIdContext sharedInstance] userId], @"c:alice");
}

- (void)testNoUserIdWhenSetUserIdIsNotCalledInNextVersion {

  // If
  // An app calls setUserId in version 1.
  __block NSDate *date;
  NSMutableArray *history = [NSMutableArray new];
  [history addObject:[[MSACUserIdHistoryInfo alloc] initWithTimestamp:[NSDate dateWithTimeIntervalSince1970:0] andUserId:@"alice"]];
  [history addObject:[[MSACUserIdHistoryInfo alloc] initWithTimestamp:[NSDate dateWithTimeIntervalSince1970:3000] andUserId:@"bob"]];
  [self.settingsMock setObject:[MSACUtility archiveKeyedData:history] forKey:@"UserIdHistory"];
  [MSACUserIdContext resetSharedInstance];

  // When
  // setUserId call is removed in version 2.
  id dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:4000];
    [invocation setReturnValue:&date];
  });
  [MSACAppCenter configureWithAppSecret:@"AppSecret"];
  [dateMock stopMocking];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userIdAt:[NSDate dateWithTimeIntervalSince1970:5000]]);

  // When
  // Version 2 app launched again.
  [MSACUserIdContext resetSharedInstance];
  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:7000];
    [invocation setReturnValue:&date];
  });
  [MSACAppCenter configureWithAppSecret:@"AppSecret"];
  [dateMock stopMocking];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userIdAt:[NSDate dateWithTimeIntervalSince1970:5000]]);
}

@end
