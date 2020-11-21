// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenter.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppCenterPrivate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACLoggerInternal.h"
#import "MSACTestFrameworks.h"

@interface MSACLoggerTests : XCTestCase

@end

@implementation MSACLoggerTests

- (void)setUp {
  [super setUp];

  [MSACLogger setCurrentLogLevel:MSACLogLevelAssert];
  [MSACLogger setIsUserDefinedLogLevel:NO];
}

- (void)testDefaultLogLevels {

  // If
  // Mock channels to avoid background activity.
  id channelGroupMock = OCMClassMock([MSACChannelGroupDefault class]);
  id channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([channelGroupMock alloc]).andReturn(channelGroupMock);
  OCMStub([channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:OCMOCK_ANY]).andReturn(channelGroupMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);

  // Check default loglevel before MSACAppCenter was started.
  XCTAssertTrue([MSACLogger currentLogLevel] == MSACLogLevelAssert);

  // Need to set sdkConfigured to NO to make sure the start-logic goes through once, otherwise this test will fail randomly as other tests
  // might call start:withServices, too.
  [MSACAppCenter resetSharedInstance];
  [MSACAppCenter sharedInstance].sdkConfigured = NO;
  [MSACAppCenter start:MSAC_UUID_STRING withServices:nil];

  // Then
  XCTAssertTrue([MSACLogger currentLogLevel] == MSACLogLevelWarning);

  // Clear
  [channelGroupMock stopMocking];
}

- (void)testSetLoglevels {

  // Check isUserDefinedLogLevel
  XCTAssertFalse([MSACLogger isUserDefinedLogLevel]);
  [MSACLogger setCurrentLogLevel:MSACLogLevelVerbose];
  XCTAssertTrue([MSACLogger isUserDefinedLogLevel]);
}

- (void)testSetCurrentLoglevelWorks {
  [MSACLogger setCurrentLogLevel:MSACLogLevelWarning];
  XCTAssertTrue([MSACLogger currentLogLevel] == MSACLogLevelWarning);
}

- (void)testLoglevelNoneDoesNotLogMessages {

  // If
  MSACLogMessageProvider messageProvider = ^() {
    // Then
    XCTFail(@"Log shouldn't be printed.");
    return @"";
  };

  // When
  [MSACLogger setCurrentLogLevel:MSACLogLevelNone];
  [MSACLogger logMessage:messageProvider level:MSACLogLevelNone tag:@"TAG" file:nil function:nil line:0];
}

@end
