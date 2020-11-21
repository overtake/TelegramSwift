// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <inttypes.h>

#import "MSACAppCenterInternal.h"
#import "MSACAppleErrorLog.h"
#import "MSACCrashReporter.h"
#import "MSACCrashesInternal.h"
#import "MSACCrashesPrivate.h"
#import "MSACCrashesTestUtil.h"
#import "MSACDeviceTrackerPrivate.h"
#import "MSACErrorLogFormatterPrivate.h"
#import "MSACException.h"
#import "MSACMockUserDefaults.h"
#import "MSACTestFrameworks.h"
#import "MSACThread.h"
#import "MSACWrapperSdkInternal.h"

static NSString *kFixture = @"fixtureName";
static NSString *kThreadNumber = @"crashedThreadNumber";
static NSString *kFramesCount = @"crashedThreadStackFrames";
static NSString *kBinariesCount = @"binariesCount";

static NSArray *kMacOSCrashReportsParameters = @[
  @{kThreadNumber : @0, kFramesCount : @21, kBinariesCount : @10, kFixture : @"macOS_report_abort"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_builtin_trap"},
  @{kThreadNumber : @0, kFramesCount : @30, kBinariesCount : @11, kFixture : @"macOS_report_corrupt_malloc_internal_info"},
  @{kThreadNumber : @0, kFramesCount : @21, kBinariesCount : @10, kFixture : @"macOS_report_corrupt_objc_runtime_structure"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_dereference_bad_pointer"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_dereference_null_pointer"},
  @{kThreadNumber : @0, kFramesCount : @21, kBinariesCount : @9, kFixture : @"macOS_report_dwarf_unwinding"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_execute_privileged_instruction"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_execute_undefined_instruction"},
  @{kThreadNumber : @0, kFramesCount : @20, kBinariesCount : @9, kFixture : @"macOS_report_jump_into_nx_page"},
  @{kThreadNumber : @0, kFramesCount : @26, kBinariesCount : @13, kFixture : @"macOS_report_objc_access_non_object_as_object"},
  @{kThreadNumber : @0, kFramesCount : @20, kBinariesCount : @12, kFixture : @"macOS_report_objc_crash_inside_msgsend"},
  @{kThreadNumber : @0, kFramesCount : @21, kBinariesCount : @12, kFixture : @"macOS_report_objc_message_released_object"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @11, kFixture : @"macOS_report_overwrite_link_register"},
  @{kThreadNumber : @0, kFramesCount : @21, kBinariesCount : @10, kFixture : @"macOS_report_pthread_lock"},
  @{kThreadNumber : @0, kFramesCount : @1, kBinariesCount : @9, kFixture : @"macOS_report_smash_the_bottom_of_the_stack"},
  @{kThreadNumber : @0, kFramesCount : @1, kBinariesCount : @10, kFixture : @"macOS_report_smash_the_top_of_the_stack"},
  @{kThreadNumber : @0, kFramesCount : @512, kBinariesCount : @8, kFixture : @"macOS_report_stack_overflow"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_swift"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @13, kFixture : @"macOS_report_throw_cpp_exception"},
  @{kThreadNumber : @0, kFramesCount : @19, kBinariesCount : @9, kFixture : @"macOS_report_write_to_readonly_page"}
];

@interface MSACErrorLogFormatter ()

+ (NSString *)selectorForRegisterWithName:(NSString *)regName ofThread:(PLCrashReportThreadInfo *)thread report:(PLCrashReport *)report;

@end

@interface MSACErrorLogFormatterTests : XCTestCase

@property(nonatomic) id deviceMock;
@property(nonatomic) id deviceTrackerMock;

@end

@implementation MSACErrorLogFormatterTests

- (void)setUp {
  [MSACDeviceTracker resetSharedInstance];
  self.deviceMock = OCMPartialMock([MSACDevice new]);
  OCMStub([self.deviceMock isValid]).andReturn(YES);
  self.deviceTrackerMock = OCMClassMock([MSACDeviceTracker class]);
  OCMStub([self.deviceTrackerMock sharedInstance]).andReturn(self.deviceTrackerMock);
  OCMStub([self.deviceTrackerMock device]).andReturn(self.deviceMock);
  OCMStub([self.deviceTrackerMock deviceForTimestamp:OCMOCK_ANY]).andReturn(self.deviceMock);
}

- (void)tearDown {
  [self.deviceMock stopMocking];
  [self.deviceTrackerMock stopMocking];
  [MSACDeviceTracker resetSharedInstance];
}

- (void)testCreateErrorReport {
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_signal"];
  XCTAssertNotNil(crashData);

  MSACMockUserDefaults *defaults = [MSACMockUserDefaults new];
  NSError *error = nil;
  PLCrashReport *crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];

  MSACErrorReport *errorReport = [MSACErrorLogFormatter errorReportFromCrashReport:crashReport];
  XCTAssertNotNil(errorReport);
  XCTAssertNotNil(errorReport.incidentIdentifier);
  assertThat(errorReport.reporterKey, equalTo([[MSACAppCenter installId] UUIDString]));
  XCTAssertEqual(errorReport.signal, crashReport.signalInfo.name);
  XCTAssertEqual(errorReport.exceptionName, nil);
  XCTAssertEqual(errorReport.exceptionReason, nil);

  // FIXME: PLCrashReporter doesn't support millisecond precision, here is a workaround to fill 999 for its millisecond.
  XCTAssertEqual([errorReport.appErrorTime timeIntervalSince1970], [crashReport.systemInfo.timestamp timeIntervalSince1970] + 0.999);
  assertThat(errorReport.appStartTime, equalTo(crashReport.processInfo.processStartTime));

  XCTAssertEqualObjects(errorReport.device, self.deviceMock);
  XCTAssertEqual(errorReport.appProcessIdentifier, crashReport.processInfo.processID);

  crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);
  error = nil;

  crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];
  errorReport = [MSACErrorLogFormatter errorReportFromCrashReport:crashReport];
  XCTAssertNotNil(errorReport);
  XCTAssertNotNil(errorReport.incidentIdentifier);
  assertThat(errorReport.reporterKey, equalTo([[MSACAppCenter installId] UUIDString]));
  XCTAssertEqual(errorReport.signal, crashReport.signalInfo.name);
  assertThat(errorReport.exceptionName, equalTo(crashReport.exceptionInfo.exceptionName));
  assertThat(errorReport.exceptionReason, equalTo(crashReport.exceptionInfo.exceptionReason));

  // FIXME: PLCrashReporter doesn't support millisecond precision, here is a workaround to fill 999 for its millisecond.
  XCTAssertEqual([errorReport.appErrorTime timeIntervalSince1970], [crashReport.systemInfo.timestamp timeIntervalSince1970] + 0.999);
  assertThat(errorReport.appStartTime, equalTo(crashReport.processInfo.processStartTime));
  XCTAssertEqualObjects(errorReport.device, self.deviceMock);
  XCTAssertEqual(errorReport.appProcessIdentifier, crashReport.processInfo.processID);
  [defaults stopMocking];
}

- (void)testErrorIdFromCrashReport {
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_signal"];
  XCTAssertNotNil(crashData);

  NSError *error = nil;
  PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];

  NSString *expected = (__bridge NSString *)CFUUIDCreateString(NULL, report.uuidRef);
  NSString *actual = [MSACErrorLogFormatter errorIdForCrashReport:report];
  assertThat(actual, equalTo(expected));
}

- (void)testCrashProbeReports {

  // Crash with _pthread_list_lock held
  [self assertIsCrashProbeReportValidConverted:@"live_report_pthread_lock"];

  // Throw C++ exception
  [self assertIsCrashProbeReportValidConverted:@"live_report_cpp_exception"];

  // Throw Objective-C exception
  [self assertIsCrashProbeReportValidConverted:@"live_report_objc_exception"];

  // Crash inside objc_msgSend()
  [self assertIsCrashProbeReportValidConverted:@"live_report_objc_msgsend"];

  // Message a released object
  [self assertIsCrashProbeReportValidConverted:@"live_report_objc_released"];

  // Write to a read-only page
  [self assertIsCrashProbeReportValidConverted:@"live_report_write_readonly"];

  // Execute an undefined instruction
  [self assertIsCrashProbeReportValidConverted:@"live_report_undefined_instr"];

  // Dereference a NULL pointer
  [self assertIsCrashProbeReportValidConverted:@"live_report_null_ptr"];

  // Dereference a bad pointer
  [self assertIsCrashProbeReportValidConverted:@"live_report_bad_ptr"];

  // Jump into an NX page
  [self assertIsCrashProbeReportValidConverted:@"live_report_jump_into_nx"];

  // Call __builtin_trap()
  [self assertIsCrashProbeReportValidConverted:@"live_report_call_trap"];

  // Call abort()
  [self assertIsCrashProbeReportValidConverted:@"live_report_call_abort"];

  // Corrupt the Objective-C runtime's structures
  [self assertIsCrashProbeReportValidConverted:@"live_report_corrupt_objc"];

  // Overwrite link register, then crash
  [self assertIsCrashProbeReportValidConverted:@"live_report_overwrite_link"];

  // Smash the bottom of the stack
  [self assertIsCrashProbeReportValidConverted:@"live_report_smash_bottom"];

  // Smash the top of the stack
  [self assertIsCrashProbeReportValidConverted:@"live_report_smash_top"];

  // Swift
  [self assertIsCrashProbeReportValidConverted:@"live_report_swift_crash"];
}

- (void)testProcessIdAndExceptionForObjectiveCExceptionCrash {
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);
  NSError *error = nil;
  PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
  PLCrashReportExceptionInfo *plExceptionInfo = report.exceptionInfo;
  MSACAppleErrorLog *errorLog = [MSACErrorLogFormatter errorLogFromCrashReport:report];

  PLCrashReportThreadInfo *crashedThread = [MSACErrorLogFormatter findCrashedThreadInReport:report];

  for (MSACThread *thread in errorLog.threads) {
    if ([thread.threadId isEqualToNumber:@(crashedThread.threadNumber)]) {
      MSACException *exception = thread.exception;
      XCTAssertNotNil(exception);
      XCTAssertEqual(exception.message, plExceptionInfo.exceptionReason);
      XCTAssertEqual(exception.type, plExceptionInfo.exceptionName);
    } else {
      XCTAssertNil(thread.exception);
    }
  }
}

- (void)testSelectorForRegisterWithName {

  // If
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);

  // When
  NSError *error = nil;
  PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
  PLCrashReportThreadInfo *crashedThread = [MSACErrorLogFormatter findCrashedThreadInReport:report];
  PLCrashReportRegisterInfo *reg = crashedThread.registers[0];
  [MSACErrorLogFormatter selectorForRegisterWithName:reg.registerName ofThread:crashedThread report:report];

  // Selector may not be found here, but we are sure that its operation will not lead to an application crash
  // XCTAssertNotNil(foundSelector);
}

- (void)testAddProcessInfoAndApplicationPath {

  // If
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);

  // When
  NSError *error = nil;
  PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
  MSACAppleErrorLog *actual = [MSACAppleErrorLog new];
  actual = [MSACErrorLogFormatter addProcessInfoAndApplicationPathTo:actual fromCrashReport:report];

  // Then
  assertThat(actual.processId, equalTo(@(report.processInfo.processID)));
  XCTAssertEqual(actual.processName, report.processInfo.processName);
  XCTAssertNotNil(actual.applicationPath);

  /*
   * Not using the report.processInfo.processPath directly to compare.
   * The path will be anonymized in the Simulator for iOS.
   * The path will be exactly same as the one in the fixture for macOS.
   * To cover both scenario, it will be checking with endsWith instead of equalTo.
   */
  assertThat(actual.applicationPath, endsWith(@"/Library/Application Support/iPhone Simulator/7.0/Applications"
                                              @"/E196971A-6809-48AF-BB06-FD67014A35B2/HockeySDK-iOSDemo.app/HockeySDK-iOSDemo"));

  XCTAssertEqual(actual.parentProcessName, report.processInfo.parentProcessName);
  assertThat(actual.parentProcessId, equalTo(@(report.processInfo.parentProcessID)));
}

- (void)testCreateErrorLogForException {
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);

  NSError *error = nil;
  PLCrashReport *crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];

  MSACAppleErrorLog *errorLog = [MSACErrorLogFormatter errorLogFromCrashReport:crashReport];

  MSACException *lastExceptionStackTrace = nil;

  for (MSACThread *thread in errorLog.threads) {
    if (thread.exception) {
      lastExceptionStackTrace = thread.exception;
      break;
    }
  }

  XCTAssertNotNil(errorLog);
  XCTAssertNotNil(lastExceptionStackTrace);
}

- (void)testAnonymizedPathWorks {
  NSString *testPath = @"/var/containers/Bundle/Application/2A0B0E6F-0BF2-419D-A699-FCDF8ADECD8C/Puppet.app/Puppet";
  NSString *expected = testPath;
  NSString *actual = [MSACErrorLogFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));

  testPath = @"/Users/someone/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/"
             @"Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  expected = @"/Users/USER/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/"
             @"Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  actual = [MSACErrorLogFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));
  XCTAssertFalse([actual hasPrefix:@"/Users/someone"]);
  XCTAssertTrue([actual hasPrefix:@"/Users/USER/"]);
}

- (void)testOSXImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;

  appBundlePath = @"/Applications/MyTestApp.App";

  // Test with default OS X app path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/MacOS/MyApp"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];

  // Test with OS X LoginItems app helper path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/Library/LoginItems/net.hockeyapp.helper.app/Contents/MacOS/Helper"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];

  // Test with OS X app in Resources folder
  processPath = @"/Applications/MyTestApp.App/Contents/Resources/Helper";
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
}

- (void)testiOSImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;

  appBundlePath = @"/private/var/mobile/Containers/Bundle/Application/9107B4E2-CD8C-486E-A3B2-82A5B818F2A0/MyApp.app";

  // Test with iOS App
  processPath = [appBundlePath stringByAppendingString:@"/MyApp"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];

  // Test with iOS App Extension
  processPath = [appBundlePath stringByAppendingString:@"/Plugins/MyAppExtension.appex/MyAppExtension"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];
}

#pragma mark - Helpers

- (void)testOSXNonAppSpecificImagesForProcessPath:(NSString *)processPath {

  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];

  // OS X frameworks
  [nonAppSpecificImagePaths addObject:@"cl_kernels"];
  [nonAppSpecificImagePaths addObject:@""];
  [nonAppSpecificImagePaths addObject:@"???"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/CFNetwork.framework/Versions/A/CFNetwork"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libsystem_platform.dylib"];
  [nonAppSpecificImagePaths
      addObject:@"/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/vecLib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Sharing.framework/Versions/A/Sharing"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libbsm.0.dylib"];

  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}

- (void)testiOSAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/MyFrameworkLib.framework/MyFrameworkLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/libSwiftMyLib.framework/libSwiftMyLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCoreGraphics.dylib"]];

  for (NSString *swiftFrameworkPath in swiftFrameworkPaths) {
    [self assertIsSwiftFrameworkWithFrameworkPath:swiftFrameworkPath processPath:processPath];
  }
}

- (void)testiOSNonAppSpecificImagesForProcessPath:(NSString *)processPath {

  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];

  // iOS frameworks
  [nonAppSpecificImagePaths
      addObject:@"/System/Library/AccessibilityBundles/AccessibilitySettingsLoader.bundle/AccessibilitySettingsLoader"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/AVFoundation"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/libAVFAudio.dylib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/AOSNotification.framework/AOSNotification"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/"
                                      @"AccessibilityUI.framework/AccessibilityUI"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/"
                                      @"AccessibilityUIUtilities.framework/AccessibilityUIUtilities"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSafeCategoryBundle.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSpeechManager.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAccessibility.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcache.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcommonCrypto.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcompiler_rt.dylib"];

  // iOS Jailbreak libraries
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/MobileSubstrate.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WeeLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WinterBoard.dylib"];

  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}

- (void)assertIsAppFrameworkWithFrameworkPath:(NSString *)frameworkPath processPath:(NSString *)processPath {
  MSACBinaryImageType imageType = [MSACErrorLogFormatter imageTypeForImagePath:frameworkPath processPath:processPath];
  XCTAssertEqual(imageType, MSACBinaryImageTypeAppFramework, @"Test framework %@ with process %@", frameworkPath, processPath);
}

- (void)assertIsAppBinaryWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  MSACBinaryImageType imageType = [MSACErrorLogFormatter imageTypeForImagePath:imagePath processPath:processPath];
  XCTAssertEqual(imageType, MSACBinaryImageTypeAppBinary, @"Test app %@ with process %@", imagePath, processPath);
}

- (void)assertIsSwiftFrameworkWithFrameworkPath:(NSString *)swiftFrameworkPath processPath:(NSString *)processPath {
  MSACBinaryImageType imageType = [MSACErrorLogFormatter imageTypeForImagePath:swiftFrameworkPath processPath:processPath];
  XCTAssertEqual(imageType, MSACBinaryImageTypeOther, @"Test swift image %@ with process %@", swiftFrameworkPath, processPath);
}

- (void)assertIsOtherWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  MSACBinaryImageType imageType = [MSACErrorLogFormatter imageTypeForImagePath:imagePath processPath:processPath];
  XCTAssertEqual(imageType, MSACBinaryImageTypeOther, @"Test other image %@ with process %@", imagePath, processPath);
}

- (void)testErrorLogFromCrashReportWithWrapper {

  // If
  MSACMockUserDefaults *defaults = [MSACMockUserDefaults new];

  // When
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_exception"];

  // Then
  XCTAssertNotNil(crashData);

  // If
  NSError *error = nil;
  PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
  MSACDevice *device = self.deviceMock;
  device.wrapperSdkVersion = @"10.11.12";
  device.wrapperSdkName = @"Wrapper SDK for iOS";
  device.wrapperRuntimeVersion = @"13.14";
  device.liveUpdateReleaseLabel = @"Release Label";
  device.liveUpdateDeploymentKey = @"Deployment Key";
  device.liveUpdatePackageHash = @"Package Hash";

  // When
  MSACAppleErrorLog *errorLog = [MSACErrorLogFormatter errorLogFromCrashReport:report];

  // Then
  XCTAssertEqualObjects(errorLog.device.wrapperSdkName, @"Wrapper SDK for iOS");
  [defaults stopMocking];
}

- (void)assertIsCrashProbeReportValidConverted:(NSString *)filename {
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:filename];
  XCTAssertNotNil(crashData);

  NSError *error = nil;
  PLCrashReport *crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];
  XCTAssertNotNil(crashReport);
  PLCrashReportThreadInfo *crashedThread = [MSACErrorLogFormatter findCrashedThreadInReport:crashReport];
  XCTAssertNotNil(crashedThread);
  MSACAppleErrorLog *errorLog = [MSACErrorLogFormatter errorLogFromCrashReport:crashReport];
  XCTAssertNotNil(errorLog);

  NSString *actualId = [MSACErrorLogFormatter errorIdForCrashReport:crashReport];
  assertThat(errorLog.errorId, equalTo(actualId));

  assertThat(errorLog.processId, equalTo(@(crashReport.processInfo.processID)));
  assertThat(errorLog.processName, equalTo(crashReport.processInfo.processName));
  assertThat(errorLog.parentProcessId, equalTo(@(crashReport.processInfo.parentProcessID)));
  assertThat(errorLog.parentProcessName, equalTo(crashReport.processInfo.parentProcessName));
  assertThat(errorLog.errorThreadId, equalTo(@(crashedThread.threadNumber)));

  // FIXME: PLCrashReporter doesn't support millisecond precision, here is a workaround to fill 999 for its millisecond.
  XCTAssertEqual([errorLog.timestamp timeIntervalSince1970], [crashReport.systemInfo.timestamp timeIntervalSince1970] + 0.999);
  assertThat(errorLog.appLaunchTimestamp, equalTo(crashReport.processInfo.processStartTime));

  NSArray *images = crashReport.images;
  for (PLCrashReportBinaryImageInfo *image in images) {
    if (image.codeType != nil && image.codeType.typeEncoding == PLCrashReportProcessorTypeEncodingMach) {
      XCTAssertEqual(errorLog.primaryArchitectureId.unsignedLongLongValue, image.codeType.type, @"Report: %@, Image: %@", filename,
                     [image.imageName lastPathComponent]);
      XCTAssertEqual(errorLog.architectureVariantId.unsignedLongLongValue, image.codeType.subtype, @"Report: %@, Image: %@", filename,
                     [image.imageName lastPathComponent]);
    }
  }

  XCTAssertNotNil(errorLog.applicationPath);

  // Not using the report.processInfo.processPath directly to compare as it will be anonymized in the Simulator.
  assertThat(errorLog.applicationPath, equalTo(@"/private/var/mobile/Containers/Bundle/Application/253BCE7D-4032-4FB2-AC63-C16F5C0BCBFA/"
                                               @"CrashProbeiOS.app/CrashProbeiOS"));

  NSString *signalAddress = [NSString stringWithFormat:@"0x%" PRIx64, crashReport.signalInfo.address];
  assertThat(errorLog.osExceptionType, equalTo(crashReport.signalInfo.name));
  assertThat(errorLog.osExceptionCode, equalTo(crashReport.signalInfo.code));
  assertThat(errorLog.osExceptionAddress, equalTo(signalAddress));

  if (crashReport.hasExceptionInfo) {
    assertThat(errorLog.exceptionType, equalTo(crashReport.exceptionInfo.exceptionName));
    assertThat(errorLog.exceptionReason, equalTo(crashReport.exceptionInfo.exceptionReason));
  } else {
    XCTAssertEqual(errorLog.exceptionType, nil);
    XCTAssertEqual(errorLog.exceptionReason, nil);
  }

  assertThat(errorLog.threads, hasCountOf([crashReport.threads count]));
  for (NSUInteger i = 0; i < [errorLog.threads count]; i++) {
    MSACThread *thread = errorLog.threads[i];
    PLCrashReportThreadInfo *plThread = crashReport.threads[i];

    assertThat(thread.threadId, equalTo(@(plThread.threadNumber)));
    if (crashReport.hasExceptionInfo && [thread.threadId isEqualToNumber:@(crashedThread.threadNumber)]) {
      XCTAssertNotNil(thread.exception);
    } else {
      XCTAssertNil(thread.exception);
    }
  }
  assertThat(errorLog.registers, hasCountOf([crashedThread.registers count]));
}

- (void)testFormat32BitAddress {

  // If
  uint64_t address32Bit = 0x123456789;

  // When
  NSString *actual = [MSACErrorLogFormatter formatAddress:address32Bit is64bit:NO];
  NSString *expected = [NSString stringWithFormat:@"0x%0*" PRIx64, 8, address32Bit];

  // Then
  XCTAssertEqualObjects(expected, actual);
}

- (void)testFormat64BitAddress {

  // If
  uint64_t address64Bit = 0x1234567890abcdef;

  // When
  NSString *actual = [MSACErrorLogFormatter formatAddress:address64Bit is64bit:YES];
  NSString *expected = [NSString stringWithFormat:@"0x%0*" PRIx64, 16, address64Bit];

  // Then
  XCTAssertEqualObjects(expected, actual);
}

- (void)testBinaryImageCountFromReportIsCorrect {

  // If
  NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:@"live_report_arm64e"];
  NSError *error = nil;
  PLCrashReport *crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];
  NSUInteger expectedCount = 16;

  // When
  NSArray *binaryImages = [MSACErrorLogFormatter extractBinaryImagesFromReport:crashReport is64bit:YES];

  // Then
  XCTAssertEqual(expectedCount, binaryImages.count);
}

#if TARGET_OS_OSX && !TARGET_OS_MACCATALYST
- (void)testCrashReportsParametersFromMacOSReport {
  for (unsigned long i = 0; i < kMacOSCrashReportsParameters.count; i++) {

    // If
    NSData *crashData = [MSACCrashesTestUtil dataOfFixtureCrashReportWithFileName:kMacOSCrashReportsParameters[i][kFixture]];
    NSError *error = nil;
    PLCrashReport *crashReport = [[PLCrashReport alloc] initWithData:crashData error:&error];

    // When
    NSArray *binaryImages = [MSACErrorLogFormatter extractBinaryImagesFromReport:crashReport is64bit:YES];
    PLCrashReportThreadInfo *crashedThread = [MSACErrorLogFormatter findCrashedThreadInReport:crashReport];

    // Then
    int expectedBinariesCount = [kMacOSCrashReportsParameters[i][kBinariesCount] intValue];
    int expectedThreadNumber = [kMacOSCrashReportsParameters[i][kThreadNumber] intValue];
    int expectedFramesCount = [kMacOSCrashReportsParameters[i][kFramesCount] intValue];
    XCTAssertEqual(expectedBinariesCount, binaryImages.count);
    XCTAssertEqual(expectedThreadNumber, crashedThread.threadNumber);
    XCTAssertEqual(expectedFramesCount, crashedThread.stackFrames.count);
  }
}
#endif

@end
