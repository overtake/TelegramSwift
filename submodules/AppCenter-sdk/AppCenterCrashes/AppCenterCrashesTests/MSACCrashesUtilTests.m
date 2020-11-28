// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACCrashesUtil.h"
#import "MSACCrashesUtilPrivate.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+File.h"

@interface MSACCrashesUtilTests : XCTestCase

@property(nonatomic) id bundleMock;

@end

@implementation MSACCrashesUtilTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([self.bundleMock mainBundle]).andReturn(self.bundleMock);
  OCMStub([self.bundleMock bundleIdentifier]).andReturn(@"com.test.app");
  [MSACCrashesUtil resetDirectory];
}

- (void)tearDown {
  [self.bundleMock stopMocking];
  [MSACCrashesUtil resetDirectory];
  [super tearDown];
}

#pragma mark - Tests

- (void)testCreateCrashesDir {

  // If
  NSString *expectedDir;
#if TARGET_OS_TV
  expectedDir = @"/Library/Caches/com.microsoft.appcenter/crashes";
#else
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  expectedDir = [self getPathWithBundleIdentifier:@"/Library/Application%%20Support/%@/com.microsoft.appcenter/crashes"];
#else
  expectedDir = @"/Library/Application%20Support/com.microsoft.appcenter/crashes";
#endif
#endif

  // When
  [MSACCrashesUtil crashesDir];

  // Then
  NSString *crashesDir = [[MSACUtility fullURLForPathComponent:kMSACCrashesDirectory] absoluteString];
  XCTAssertNotNil(crashesDir);
  XCTAssertTrue([crashesDir rangeOfString:expectedDir].location != NSNotFound);
  BOOL dirExists = [MSACUtility fileExistsForPathComponent:kMSACCrashesDirectory];
  XCTAssertTrue(dirExists);
}

- (void)testCreateLogBufferDir {

  // If
  NSString *expectedDir;
#if TARGET_OS_TV
  expectedDir = @"/Library/Caches/com.microsoft.appcenter/crasheslogbuffer";
#else
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  expectedDir = [self getPathWithBundleIdentifier:@"/Library/Application%%20Support/%@/com.microsoft.appcenter/crasheslogbuffer"];
#else
  expectedDir = @"/Library/Application%20Support/com.microsoft.appcenter/crasheslogbuffer";
#endif
#endif

  // When
  [MSACCrashesUtil logBufferDir];

  // Then
  NSString *bufferDir = [[MSACUtility fullURLForPathComponent:@"crasheslogbuffer"] absoluteString];
  XCTAssertNotNil(bufferDir);
  XCTAssertTrue([bufferDir rangeOfString:expectedDir].location != NSNotFound);
  BOOL dirExists = [MSACUtility fileExistsForPathComponent:@"crasheslogbuffer"];
  XCTAssertTrue(dirExists);
}

- (void)testCreateWrapperExceptionDir {

  // If
  NSString *expectedDir;
#if TARGET_OS_TV
  expectedDir = @"/Library/Caches/com.microsoft.appcenter/crasheswrapperexceptions";
#else
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  expectedDir = [self getPathWithBundleIdentifier:@"/Library/Application%%20Support/%@/com.microsoft.appcenter/crasheswrapperexceptions"];
#else
  expectedDir = @"/Library/Application%20Support/com.microsoft.appcenter/crasheswrapperexceptions";
#endif
#endif

  // When
  [MSACCrashesUtil wrapperExceptionsDir];

  // Then
  NSString *crashesWrapperExceptionDir = [[MSACUtility fullURLForPathComponent:kMSACWrapperExceptionsDirectory] absoluteString];
  XCTAssertNotNil(crashesWrapperExceptionDir);
  XCTAssertTrue([crashesWrapperExceptionDir rangeOfString:expectedDir].location != NSNotFound);
  BOOL dirExists = [MSACUtility fileExistsForPathComponent:kMSACWrapperExceptionsDirectory];
  XCTAssertTrue(dirExists);
}

// Before SDK 12.2 (bundled with Xcode 10.*) when running in a unit test bundle the bundle identifier is null.
// 12.2 and after the above bundle identifier is com.apple.dt.xctest.tool.
- (NSString *)getPathWithBundleIdentifier:(NSString *)path {
  NSString *bundleId;
#if ((defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_2) ||                                     \
     (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_14_4))
  bundleId = @"com.apple.dt.xctest.tool";
#else
  bundleId = @"(null)";
#endif
  return [NSString stringWithFormat:path, bundleId];
}

@end
