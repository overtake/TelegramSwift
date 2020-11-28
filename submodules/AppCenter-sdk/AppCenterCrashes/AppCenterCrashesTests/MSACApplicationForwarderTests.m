// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenterInternal.h"
#import "MSACApplicationForwarder.h"
#import "MSACCrashesPrivate.h"
#import "MSACMockNSUserDefaults.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+Application.h"

#if TARGET_OS_OSX
static NSException *lastException;
static void exceptionHandler(NSException *exception) { lastException = exception; }
#endif

@interface MSACApplicationForwarderTests : XCTestCase

@end

@implementation MSACApplicationForwarderTests

- (void)tearDown {
  [super tearDown];
  [MSACCrashes resetSharedInstance];
}

#if TARGET_OS_OSX
- (void)testRegisterForwarding {
  NSException *testException = [NSException new];

  // If
  id applicationMock = OCMPartialMock([NSApplication sharedApplication]);
  id appCenterMock = OCMClassMock([MSACAppCenter class]);
  OCMStub([appCenterMock isDebuggerAttached]).andReturn(NO);
  id crashesMock = OCMPartialMock([MSACCrashes sharedInstance]);
  OCMStub([crashesMock exceptionHandler]).andReturn((NSUncaughtExceptionHandler *)exceptionHandler);

  // When
  [MSACApplicationForwarder registerForwarding];
  [applicationMock reportException:testException];

  // Then
  XCTAssertNil(lastException);

  // Disable swizzling.
  id bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock objectForInfoDictionaryKey:@"AppCenterApplicationForwarderEnabled"]).andReturn(@NO);
  OCMStub([bundleMock mainBundle]).andReturn(bundleMock);

  // When
  [MSACApplicationForwarder registerForwarding];
  [applicationMock reportException:testException];

  // Then
  XCTAssertNil(lastException);

  // Enable crash on exсeptions.
  MSACMockNSUserDefaults *settings = [MSACMockNSUserDefaults new];
  [settings setObject:@YES forKey:@"NSApplicationCrashOnExceptions"];

  // When
  [MSACApplicationForwarder registerForwarding];
  [applicationMock reportException:testException];

  // Then
  XCTAssertNil(lastException);

  // Enable swizzling
  [bundleMock stopMocking];

  // When
  [MSACApplicationForwarder registerForwarding];
  [applicationMock reportException:testException];

  // Then
  XCTAssertEqual(lastException, testException);
  [settings stopMocking];
  [applicationMock stopMocking];
  [appCenterMock stopMocking];
  [crashesMock stopMocking];
}
#endif

@end
