// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDevice.h"
#import "MSACDeviceInternal.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"
#import "MSACWrapperSdkInternal.h"

@interface MSACDeviceLogTests : XCTestCase

@property(nonatomic) MSACDevice *sut;

@end

@implementation MSACDeviceLogTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.sut = [MSACDevice new];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Tests

- (void)testSerializingDeviceToDictionaryWorks {

  // If
  NSString *sdkVersion = @"3.0.1";
  NSString *model = @"iPhone 7.2";
  NSString *oemName = @"Apple";
  NSString *osName = @"iOS";
  NSString *osVersion = @"9.3.20";
  NSNumber *osApiLevel = @(320);
  NSString *locale = @"US-EN";
  NSNumber *timeZoneOffset = @(9);
  NSString *screenSize = @"750x1334";
  NSString *appVersion = @"3.4.5 (34)";
  NSString *carrierName = @"T-Mobile";
  NSString *carrierCountry = @"United States";
  NSString *wrapperSdkVersion = @"6.7.8";
  NSString *wrapperSdkName = @"wrapper-sdk";
  NSString *wrapperRuntimeVersion = @"9.10";
  NSString *liveUpdateReleaseLabel = @"live-update-release";
  NSString *liveUpdateDeploymentKey = @"deployment-key";
  NSString *liveUpdatePackageHash = @"b10a8db164e0754105b7a99be72e3fe5";

  self.sut.sdkVersion = sdkVersion;
  self.sut.model = model;
  self.sut.oemName = oemName;
  self.sut.osName = osName;
  self.sut.osVersion = osVersion;
  self.sut.osApiLevel = osApiLevel;
  self.sut.locale = locale;
  self.sut.timeZoneOffset = timeZoneOffset;
  self.sut.screenSize = screenSize;
  self.sut.appVersion = appVersion;
  self.sut.carrierName = carrierName;
  self.sut.carrierCountry = carrierCountry;
  self.sut.wrapperSdkVersion = wrapperSdkVersion;
  self.sut.wrapperSdkName = wrapperSdkName;
  self.sut.wrapperRuntimeVersion = wrapperRuntimeVersion;
  self.sut.liveUpdateReleaseLabel = liveUpdateReleaseLabel;
  self.sut.liveUpdateDeploymentKey = liveUpdateDeploymentKey;
  self.sut.liveUpdatePackageHash = liveUpdatePackageHash;

  // When
  NSMutableDictionary *actual = [self.sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"sdkVersion"], equalTo(sdkVersion));
  assertThat(actual[@"model"], equalTo(model));
  assertThat(actual[@"oemName"], equalTo(oemName));
  assertThat(actual[@"osName"], equalTo(osName));
  assertThat(actual[@"osVersion"], equalTo(osVersion));
  assertThat(actual[@"osApiLevel"], equalTo(osApiLevel));
  assertThat(actual[@"locale"], equalTo(locale));
  assertThat(actual[@"timeZoneOffset"], equalTo(timeZoneOffset));
  assertThat(actual[@"screenSize"], equalTo(screenSize));
  assertThat(actual[@"appVersion"], equalTo(appVersion));
  assertThat(actual[@"carrierName"], equalTo(carrierName));
  assertThat(actual[@"carrierCountry"], equalTo(carrierCountry));
  assertThat(actual[@"wrapperSdkVersion"], equalTo(wrapperSdkVersion));
  assertThat(actual[@"wrapperSdkName"], equalTo(wrapperSdkName));
  assertThat(actual[@"liveUpdateReleaseLabel"], equalTo(liveUpdateReleaseLabel));
  assertThat(actual[@"liveUpdateDeploymentKey"], equalTo(liveUpdateDeploymentKey));
  assertThat(actual[@"liveUpdatePackageHash"], equalTo(liveUpdatePackageHash));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  NSString *sdkVersion = @"3.0.1";
  NSString *model = @"iPhone 7.2";
  NSString *oemName = @"Apple";
  NSString *osName = @"iOS";
  NSString *osVersion = @"9.3.20";
  NSNumber *osApiLevel = @(320);
  NSString *locale = @"US-EN";
  NSNumber *timeZoneOffset = @(9);
  NSString *screenSize = @"750x1334";
  NSString *appVersion = @"3.4.5 (34)";
  NSString *carrierName = @"T-Mobile";
  NSString *carrierCountry = @"United States";
  NSString *wrapperSdkVersion = @"6.7.8";
  NSString *wrapperSdkName = @"wrapper-sdk";
  NSString *wrapperRuntimeVersion = @"9.10";
  NSString *liveUpdateReleaseLabel = @"live-update-release";
  NSString *liveUpdateDeploymentKey = @"deployment-key";
  NSString *liveUpdatePackageHash = @"b10a8db164e0754105b7a99be72e3fe5";

  self.sut.sdkVersion = sdkVersion;
  self.sut.model = model;
  self.sut.oemName = oemName;
  self.sut.osName = osName;
  self.sut.osVersion = osVersion;
  self.sut.osApiLevel = osApiLevel;
  self.sut.locale = locale;
  self.sut.timeZoneOffset = timeZoneOffset;
  self.sut.screenSize = screenSize;
  self.sut.appVersion = appVersion;
  self.sut.carrierName = carrierName;
  self.sut.carrierCountry = carrierCountry;
  self.sut.wrapperSdkVersion = wrapperSdkVersion;
  self.sut.wrapperSdkName = wrapperSdkName;
  self.sut.wrapperRuntimeVersion = wrapperRuntimeVersion;
  self.sut.liveUpdateReleaseLabel = liveUpdateReleaseLabel;
  self.sut.liveUpdateDeploymentKey = liveUpdateDeploymentKey;
  self.sut.liveUpdatePackageHash = liveUpdatePackageHash;

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACDevice class]));

  MSACDevice *actualDevice = actual;
  assertThat(actualDevice.sdkVersion, equalTo(sdkVersion));
  assertThat(actualDevice.model, equalTo(model));
  assertThat(actualDevice.oemName, equalTo(oemName));
  assertThat(actualDevice.osName, equalTo(osName));
  assertThat(actualDevice.osVersion, equalTo(osVersion));
  assertThat(actualDevice.osApiLevel, equalTo(osApiLevel));
  assertThat(actualDevice.locale, equalTo(locale));
  assertThat(actualDevice.timeZoneOffset, equalTo(timeZoneOffset));
  assertThat(actualDevice.screenSize, equalTo(screenSize));
  assertThat(actualDevice.appVersion, equalTo(appVersion));
  assertThat(actualDevice.carrierName, equalTo(carrierName));
  assertThat(actualDevice.carrierCountry, equalTo(carrierCountry));
  assertThat(actualDevice.wrapperSdkVersion, equalTo(wrapperSdkVersion));
  assertThat(actualDevice.wrapperSdkName, equalTo(wrapperSdkName));
  assertThat(actualDevice.wrapperRuntimeVersion, equalTo(wrapperRuntimeVersion));
  assertThat(actualDevice.liveUpdateReleaseLabel, equalTo(liveUpdateReleaseLabel));
  assertThat(actualDevice.liveUpdateDeploymentKey, equalTo(liveUpdateDeploymentKey));
  assertThat(actualDevice.liveUpdatePackageHash, equalTo(liveUpdatePackageHash));
}

- (void)testIsEqual {

  // If
  NSString *sdkVersion = @"3.0.1";
  NSString *model = @"iPhone 7.2";
  NSString *oemName = @"Apple";
  NSString *osName = @"iOS";
  NSString *osVersion = @"9.3.20";
  NSNumber *osApiLevel = @(320);
  NSString *locale = @"US-EN";
  NSNumber *timeZoneOffset = @(9);
  NSString *screenSize = @"750x1334";
  NSString *appVersion = @"3.4.5 (34)";
  NSString *carrierName = @"T-Mobile";
  NSString *carrierCountry = @"United States";
  NSString *wrapperSdkVersion = @"6.7.8";
  NSString *wrapperSdkName = @"wrapper-sdk";
  NSString *wrapperRuntimeVersion = @"9.10";
  NSString *liveUpdateReleaseLabel = @"live-update-release";
  NSString *liveUpdateDeploymentKey = @"deployment-key";
  NSString *liveUpdatePackageHash = @"b10a8db164e0754105b7a99be72e3fe5";

  self.sut.sdkVersion = sdkVersion;
  self.sut.model = model;
  self.sut.oemName = oemName;
  self.sut.osName = osName;
  self.sut.osVersion = osVersion;
  self.sut.osApiLevel = osApiLevel;
  self.sut.locale = locale;
  self.sut.timeZoneOffset = timeZoneOffset;
  self.sut.screenSize = screenSize;
  self.sut.appVersion = appVersion;
  self.sut.carrierName = carrierName;
  self.sut.carrierCountry = carrierCountry;
  self.sut.wrapperSdkVersion = wrapperSdkVersion;
  self.sut.wrapperSdkName = wrapperSdkName;
  self.sut.wrapperRuntimeVersion = wrapperRuntimeVersion;
  self.sut.liveUpdateReleaseLabel = liveUpdateReleaseLabel;
  self.sut.liveUpdateDeploymentKey = liveUpdateDeploymentKey;
  self.sut.liveUpdatePackageHash = liveUpdatePackageHash;

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];
  MSACDevice *actualDevice = actual;

  // Then
  XCTAssertTrue([self.sut isEqual:actualDevice]);

  // When
  self.sut.carrierCountry = @"newCarrierCountry";

  // Then
  XCTAssertFalse([self.sut isEqual:actualDevice]);

  // When
  self.sut.carrierCountry = carrierCountry;
  self.sut.wrapperSdkName = @"new-wrapper-sdk";

  // Then
  XCTAssertFalse([self.sut isEqual:actualDevice]);
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([[MSACWrapperSdk new] isEqual:nil]);
}

@end
