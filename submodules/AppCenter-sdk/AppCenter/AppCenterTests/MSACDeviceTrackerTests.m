// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDevice.h"
#import "MSACDeviceHistoryInfo.h"
#import "MSACDeviceInternal.h"
#import "MSACDeviceTracker.h"
#import "MSACDeviceTrackerPrivate.h"
#import "MSACMockUserDefaults.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+Date.h"
#import "MSACWrapperSdkInternal.h"

static NSString *const kMSACDeviceManufacturerTest = @"Apple";

@interface MSACDeviceTrackerTests : XCTestCase

@property(nonatomic) MSACDeviceTracker *sut;

@end

@implementation MSACDeviceTrackerTests

- (void)setUp {
  [super setUp];
  [MSACDeviceTracker resetSharedInstance];

  // System Under Test.
  self.sut = [MSACDeviceTracker sharedInstance];
}

- (void)tearDown {
  [MSACDeviceTracker resetSharedInstance];
  [super tearDown];
}

- (void)testDeviceInfo {

  assertThat(self.sut.device.sdkVersion, notNilValue());
  assertThatInteger([self.sut.device.sdkVersion length], greaterThan(@(0)));

  assertThat(self.sut.device.model, notNilValue());
  assertThatInteger([self.sut.device.model length], greaterThan(@(0)));

  assertThat(self.sut.device.oemName, is(kMSACDeviceManufacturerTest));

  assertThat(self.sut.device.osName, notNilValue());
  assertThatInteger([self.sut.device.osName length], greaterThan(@(0)));

  assertThat(self.sut.device.osVersion, notNilValue());
  assertThatInteger([self.sut.device.osVersion length], greaterThan(@(0)));
  assertThatFloat([self.sut.device.osVersion floatValue], greaterThan(@(0.0)));

  assertThat(self.sut.device.locale, notNilValue());
  assertThatInteger([self.sut.device.locale length], greaterThan(@(0)));

  assertThat(self.sut.device.timeZoneOffset, notNilValue());

  assertThat(self.sut.device.screenSize, notNilValue());

  // Can't access carrier name and country in test context but it's optional and in that case it has to be nil.
  assertThat(self.sut.device.carrierCountry, nilValue());
  assertThat(self.sut.device.carrierName, nilValue());

  // Can't access a valid main bundle from test context so we can't test for App namespace (bundle ID), version and build.
}

- (void)testDeviceModel {

  // When
  NSString *model = [self.sut deviceModel];

  // Then
  assertThat(model, notNilValue());
  assertThatInteger([model length], greaterThan(@(0)));
}

- (void)testDeviceOSName {

// If
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  NSString *expected = @"macOS";
#else
  NSString *expected = @"iMock OS";
  id deviceMock = OCMClassMock([UIDevice class]);
  OCMStub([deviceMock systemName]).andReturn(expected);
#endif

// When
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  NSString *osName = [self.sut osName];
#else
  NSString *osName = [self.sut osName:deviceMock];
  [deviceMock stopMocking];
#endif

  // Then
  assertThat(osName, is(expected));
}

- (void)testDeviceOSVersion {

  // If
  NSString *expected = @"4.5.6";

#if TARGET_OS_OSX
  id processInfoMock;
  if (@available(macOS 10.10, *)) {
    processInfoMock = OCMClassMock([NSProcessInfo class]);
    OCMStub([processInfoMock processInfo]).andReturn(processInfoMock);
    NSOperatingSystemVersion osSystemVersionMock;
    osSystemVersionMock.majorVersion = 4;
    osSystemVersionMock.minorVersion = 5;
    osSystemVersionMock.patchVersion = 6;
    OCMStub([processInfoMock operatingSystemVersion]).andReturn(osSystemVersionMock);
  } else {

    // TODO: No way to mock C-style functions like Gestalt. Skip the test on machine running on macOS version <= 10.9.
  }
#else
  id deviceMock = OCMClassMock([UIDevice class]);
  OCMStub([(UIDevice *)deviceMock systemVersion]).andReturn(expected);
#endif

// When
#if TARGET_OS_OSX
  // TODO: No way to mock C-style functions like Gestalt. Skip the test on machine running on macOS version <= 10.9.
  NSString *osVersion = expected;
  if (@available(macOS 10.10, *)) {
    osVersion = [self.sut osVersion];
  }
#else
  NSString *osVersion = [self.sut osVersion:deviceMock];
  [deviceMock stopMocking];
#endif

  // Then
  assertThat(osVersion, is(expected));

#if (TARGET_OS_OSX || TARGET_OS_MACCATALYST) && __MAC_OS_X_VERSION_MAX_ALLOWED > 1090
  [processInfoMock stopMocking];
#endif
}

- (void)testDeviceLocale {

  // If
  NSString *expected = @"en_US";
  id localeMock = OCMClassMock([NSLocale class]);
  OCMStub([localeMock preferredLanguages]).andReturn(@[ @"en-US" ]);

  // When
  NSString *locale = [self.sut locale:localeMock];

  // Then
  assertThat(locale, is(expected));
  [localeMock stopMocking];
}

- (void)testDeviceLocaleWithScriptCode {

  // If
  NSString *expected = @"zh-Hans_CN";
  id localeMock = OCMClassMock([NSLocale class]);
  OCMStub([localeMock preferredLanguages]).andReturn(@[ @"zh-Hans-CN" ]);

  // When
  NSString *locale = [self.sut locale:localeMock];

  // Then
  assertThat(locale, is(expected));
  [localeMock stopMocking];
}

- (void)testDeviceLocaleWithoutCountryCode {

  // If
  NSString *expected = @"zh-Hant_CN";
  id localeMock = OCMClassMock([NSLocale class]);
  OCMStub([localeMock preferredLanguages]).andReturn(@[ @"zh-Hant" ]);
  OCMStub([localeMock objectForKey:NSLocaleCountryCode]).andReturn(@"CN");

  // When
  NSString *locale = [self.sut locale:localeMock];

  // Then
  assertThat(locale, is(expected));
  [localeMock stopMocking];
}

- (void)testDeviceTimezoneOffset {

  // If
  NSNumber *expected = @(-420);
  id tzMock = OCMClassMock([NSTimeZone class]);
  OCMStub([tzMock secondsFromGMT]).andReturn(-25200);

  // When
  NSNumber *tz = [self.sut timeZoneOffset:tzMock];

  // Then
  assertThat(tz, is(expected));
  [tzMock stopMocking];
}

- (void)testDeviceScreenSize {

  // When
  NSString *screenSize = [self.sut screenSize];

  // Then
  assertThat(screenSize, notNilValue());
  assertThatInteger([screenSize length], greaterThan(@(0)));
}

#if TARGET_OS_IOS
- (void)testCarrierName {

  // If
  NSString *expected = @"MobileParadise";
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock carrierName]).andReturn(expected);

  // When
  NSString *carrierName = [self.sut carrierName:carrierMock];

  // Then
  assertThat(carrierName, is(expected));
  [carrierMock stopMocking];
}
#endif

#if TARGET_OS_IOS
- (void)testNoCarrierName {

  // If
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock carrierName]).andReturn(nil);

  // When
  NSString *carrierName = [self.sut carrierName:carrierMock];

  // Then
  assertThat(carrierName, nilValue());
  [carrierMock stopMocking];
}
#endif

#if TARGET_OS_IOS
- (void)testNonValidCarrierName {

  // If
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock carrierName]).andReturn(@"Carrier");

  // When
  NSString *carrierName = [self.sut carrierName:carrierMock];

  // Then
  assertThat(carrierName, nilValue());
  [carrierMock stopMocking];
}
#endif

#if TARGET_OS_IOS
- (void)testCarrierCountry {

  // If
  NSString *expected = @"US";
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock isoCountryCode]).andReturn(expected);

  // When
  NSString *carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, is(expected));
  [carrierMock stopMocking];
}
#endif

#if TARGET_OS_IOS
- (void)testNoCarrierCountry {

  // If
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock isoCountryCode]).andReturn(nil);

  // When
  NSString *carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, nilValue());
  [carrierMock stopMocking];
}
#endif

#if TARGET_OS_IOS
- (void)testCarrierCountryNotOverridden {

  // If
  NSString *expected = @"US";
  id carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock isoCountryCode]).andReturn(expected);

  // When
  NSString *carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, is(expected));

  // If
  [self.sut setCountryCode:@"AU"];
  MSACDevice *device = self.sut.device;

  // Then
  XCTAssertEqual(device.carrierCountry, @"AU");

  // When
  carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, is(expected));
  [carrierMock stopMocking];
}
#endif

- (void)testAppVersion {

  // If
  NSString *expected = @"7.8.9";
  NSDictionary<NSString *, id> *plist = @{@"CFBundleShortVersionString" : expected};
  id bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock infoDictionary]).andReturn(plist);

  // When
  NSString *appVersion = [self.sut appVersion:bundleMock];

  // Then
  assertThat(appVersion, is(expected));
  [bundleMock stopMocking];
}

- (void)testAppBuild {

  // If
  NSString *expected = @"42";
  NSDictionary<NSString *, id> *plist = @{@"CFBundleVersion" : expected};
  id bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock infoDictionary]).andReturn(plist);

  // When
  NSString *appBuild = [self.sut appBuild:bundleMock];

  // Then
  assertThat(appBuild, is(expected));
  [bundleMock stopMocking];
}

- (void)testAppNamespace {

  // If
  NSString *expected = @"com.microsoft.test.app";
  id bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock bundleIdentifier]).andReturn(expected);

  // When
  NSString *appNamespace = [self.sut appNamespace:bundleMock];

  // Then
  assertThat(appNamespace, is(expected));
  [bundleMock stopMocking];
}

- (void)testWrapperSdk {

  // If
  MSACWrapperSdk *wrapperSdk = [[MSACWrapperSdk alloc] initWithWrapperSdkVersion:@"10.11.12"
                                                                  wrapperSdkName:@"Wrapper SDK for iOS"
                                                           wrapperRuntimeVersion:@"13.14"
                                                          liveUpdateReleaseLabel:@"Release Label"
                                                         liveUpdateDeploymentKey:@"Deployment Key"
                                                           liveUpdatePackageHash:@"Package Hash"];

  // When
  [self.sut setWrapperSdk:wrapperSdk];
  MSACDevice *device = self.sut.device;

  // Then
  XCTAssertEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);
  XCTAssertEqual(device.wrapperSdkName, wrapperSdk.wrapperSdkName);
  XCTAssertEqual(device.wrapperRuntimeVersion, wrapperSdk.wrapperRuntimeVersion);
  XCTAssertEqual(device.liveUpdateReleaseLabel, wrapperSdk.liveUpdateReleaseLabel);
  XCTAssertEqual(device.liveUpdateDeploymentKey, wrapperSdk.liveUpdateDeploymentKey);
  XCTAssertEqual(device.liveUpdatePackageHash, wrapperSdk.liveUpdatePackageHash);

  // Update wrapper SDK
  // If
  wrapperSdk.wrapperSdkVersion = @"10.11.13";

  // When
  [self.sut setWrapperSdk:wrapperSdk];

  // Then
  XCTAssertNotEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);

  // When
  device = self.sut.device;

  // Then
  XCTAssertEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);
}

- (void)testCountryCode {

  // When
  [self.sut setCountryCode:@"AU"];
  MSACDevice *device = self.sut.device;

  // Then
  XCTAssertEqual(device.carrierCountry, @"AU");

  // When
  [self.sut setCountryCode:@"GB"];

  // Then
  XCTAssertNotEqual(device.carrierCountry, @"GB");

  // When
  device = self.sut.device;

  // Then
  XCTAssertEqual(device.carrierCountry, @"GB");

  // When
  [self.sut setCountryCode:nil];

  // Then
  XCTAssertEqual(device.carrierCountry, @"GB");

  // When
  device = self.sut.device;

  // Then
  XCTAssertNil(device.carrierCountry);
}

- (void)testCreationOfNewDeviceWorks {

  // When
  MSACDevice *expected = [self.sut updatedDevice];

  // Then

  assertThat(expected.sdkVersion, notNilValue());
  assertThatInteger([expected.sdkVersion length], greaterThan(@(0)));

  assertThat(expected.model, notNilValue());
  assertThatInteger([expected.model length], greaterThan(@(0)));

  assertThat(expected.oemName, is(kMSACDeviceManufacturerTest));

  assertThat(expected.osName, notNilValue());
  assertThatInteger([expected.osName length], greaterThan(@(0)));

  assertThat(expected.osVersion, notNilValue());
  assertThatInteger([expected.osVersion length], greaterThan(@(0)));
  assertThatFloat([expected.osVersion floatValue], greaterThan(@(0.0)));

  assertThat(expected.locale, notNilValue());
  assertThatInteger([expected.locale length], greaterThan(@(0)));

  assertThat(expected.timeZoneOffset, notNilValue());

  assertThat(expected.screenSize, notNilValue());

  // Can't access carrier name and country in test context but it's optional and in that case it has to be nil.
  assertThat(expected.carrierCountry, nilValue());
  assertThat(expected.carrierName, nilValue());

  // Can't access a valid main bundle from test context so we can't test for App namespace (bundle ID), version and build.

  XCTAssertNotEqual(expected, self.sut.device);
}

- (void)testNSUserDefaultsDeviceHistory {
  MSACMockUserDefaults *defaults = [MSACMockUserDefaults new];

  // When
  [self.sut clearDevices];

  // Restore past devices from NSUserDefaults.
  NSData *devices = [defaults objectForKey:kMSACPastDevicesKey];
  NSArray *arrayFromData = (NSArray *)[[MSACUtility unarchiveKeyedData:devices] mutableCopy];

  NSMutableArray<MSACDeviceHistoryInfo *> *deviceHistory = [NSMutableArray arrayWithArray:arrayFromData];

  // Then
  XCTAssertTrue([deviceHistory count] == 1);

  [defaults stopMocking];
}

- (void)testClearingDeviceHistoryWorks {

  MSACMockUserDefaults *defaults = [MSACMockUserDefaults new];

  // When
  // If the storage is empty, remember the current device.
  [self.sut clearDevices];

  // Then
  XCTAssertTrue([self.sut.deviceHistory count] == 1);
  XCTAssertNotNil([defaults objectForKey:kMSACPastDevicesKey]);

  [defaults stopMocking];
}

- (void)testEnqueuingAndRefreshWorks {

  // If
  [self.sut clearDevices];

  // When
  MSACDevice *first = [self.sut device];
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *second = [self.sut device];
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *third = [self.sut device];

  // Then
  XCTAssertTrue([[self.sut deviceHistory] count] == 3);
  XCTAssertTrue([self.sut.deviceHistory[0].device isEqual:first]);
  XCTAssertTrue([self.sut.deviceHistory[1].device isEqual:second]);
  XCTAssertTrue([self.sut.deviceHistory[2].device isEqual:third]);

  // When
  // We haven't called setNeedsRefresh: so device won't be refreshed.
  MSACDevice *fourth = [self.sut device];

  // Then
  XCTAssertTrue([[self.sut deviceHistory] count] == 3);
  XCTAssertTrue([fourth isEqual:third]);

  // When
  [MSACDeviceTracker refreshDeviceNextTime];
  fourth = [self.sut device];

  // Then
  XCTAssertTrue([[self.sut deviceHistory] count] == 4);
  XCTAssertTrue([self.sut.deviceHistory[3].device isEqual:fourth]);

  // When
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *fifth = [self.sut device];

  // Then
  XCTAssertTrue([[self.sut deviceHistory] count] == 5);
  XCTAssertTrue([self.sut.deviceHistory[4].device isEqual:fifth]);

  // When
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *sixth = [self.sut device];

  // Then
  // The new device should be added at the end and the first one removed so that second is at index 0
  XCTAssertTrue([[self.sut deviceHistory] count] == 5);
  XCTAssertTrue([self.sut.deviceHistory[0].device isEqual:second]);
  XCTAssertTrue([self.sut.deviceHistory[4].device isEqual:sixth]);

  // When
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *seventh = [self.sut device];

  // Then
  // The new device should be added at the end and the first one removed so that third is at index 0
  XCTAssertTrue([[self.sut deviceHistory] count] == 5);
  XCTAssertTrue([self.sut.deviceHistory[0].device isEqual:third]);
  XCTAssertTrue([self.sut.deviceHistory[4].device isEqual:seventh]);
}

- (void)testHistoryReturnsClosestDevice {

  // If
  [self.sut clearDevices];

  // When
  MSACDevice *actual = [self.sut deviceForTimestamp:[NSDate dateWithTimeIntervalSince1970:1]];

  // Then
  XCTAssertTrue([actual isEqual:self.sut.device]);
  XCTAssertTrue([[self.sut deviceHistory] count] == 1);

  // If
  MSACDevice *first = [self.sut device];
  [MSACDeviceTracker refreshDeviceNextTime];
  [self.sut device]; // we don't need the second device history info
  [MSACDeviceTracker refreshDeviceNextTime];
  MSACDevice *third = [self.sut device];

  // When
  actual = [self.sut deviceForTimestamp:[NSDate dateWithTimeIntervalSince1970:1]];

  // Then
  XCTAssertTrue([actual isEqual:first]);

  // When
  actual = [self.sut deviceForTimestamp:[NSDate date]];

  // Then
  XCTAssertTrue([actual isEqual:third]);
}

@end
