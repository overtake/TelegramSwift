// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDevice.h"
#import "MSACDeviceInternal.h"
#import "MSACErrorReportPrivate.h"
#import "MSACTestFrameworks.h"
#import "MSACWrapperSdkInternal.h"

@interface MSACErrorReportTests : XCTestCase

@end

@implementation MSACErrorReportTests

- (void)testInitializationWorks {
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

  MSACDevice *device = [[MSACDevice alloc] init];
  device.sdkVersion = sdkVersion;
  device.model = model;
  device.oemName = oemName;
  device.osName = osName;
  device.osVersion = osVersion;
  device.osApiLevel = osApiLevel;
  device.locale = locale;
  device.timeZoneOffset = timeZoneOffset;
  device.screenSize = screenSize;
  device.appVersion = appVersion;
  device.carrierName = carrierName;
  device.carrierCountry = carrierCountry;
  device.wrapperSdkVersion = wrapperSdkVersion;
  device.wrapperSdkName = wrapperSdkName;
  device.wrapperRuntimeVersion = wrapperRuntimeVersion;
  device.liveUpdateReleaseLabel = liveUpdateReleaseLabel;
  device.liveUpdateDeploymentKey = liveUpdateDeploymentKey;
  device.liveUpdatePackageHash = liveUpdatePackageHash;

  NSString *errorId = @"errorReportId";
  NSString *reporterKey = @"reporterKey";
  NSString *signal = @"signal";
  NSString *exceptionName = @"exception_name";
  NSString *exceptionReason = @"exception_reason";
  NSDate *appStartTime = [NSDate new];
  NSDate *appErrorTime = [NSDate dateWithTimeIntervalSinceNow:20];
  NSUInteger processIdentifier = 4;

  // When
  MSACErrorReport *sut = [[MSACErrorReport alloc] initWithErrorId:errorId
                                                      reporterKey:reporterKey
                                                           signal:signal
                                                    exceptionName:exceptionName
                                                  exceptionReason:exceptionReason
                                                     appStartTime:appStartTime
                                                     appErrorTime:appErrorTime
                                                           device:device
                                             appProcessIdentifier:processIdentifier];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.incidentIdentifier, equalTo(errorId));
  assertThat(sut.reporterKey, equalTo(reporterKey));
  assertThat(sut.signal, equalTo(signal));
  assertThat(sut.exceptionName, equalTo(exceptionName));
  assertThat(sut.exceptionReason, equalTo(exceptionReason));
  assertThat(sut.appStartTime, equalTo(appStartTime));
  assertThat(sut.appErrorTime, equalTo(appErrorTime));
  assertThat(sut.device, equalTo(device));
  assertThatUnsignedInteger(sut.appProcessIdentifier, equalToUnsignedInteger(processIdentifier));
}

- (void)testIsAppKill {

  // When
  MSACErrorReport *sut = [MSACErrorReport new];

  // Then
  XCTAssertFalse([sut isAppKill]);

  // When
  sut = [[MSACErrorReport alloc] initWithErrorId:nil
                                     reporterKey:nil
                                          signal:@"SIGSEGV"
                                   exceptionName:nil
                                 exceptionReason:nil
                                    appStartTime:nil
                                    appErrorTime:nil
                                          device:nil
                            appProcessIdentifier:0];

  // Then
  XCTAssertFalse([sut isAppKill]);

  // When
  sut = [[MSACErrorReport alloc] initWithErrorId:nil
                                     reporterKey:nil
                                          signal:@"SIGKILL"
                                   exceptionName:nil
                                 exceptionReason:nil
                                    appStartTime:nil
                                    appErrorTime:nil
                                          device:nil
                            appProcessIdentifier:0];

  // Then
  XCTAssertTrue([sut isAppKill]);
}

@end
