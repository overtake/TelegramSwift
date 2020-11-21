// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACLoggerInternal.h"
#import "MSACTestFrameworks.h"
#import "MSACWrapperLogger.h"

@interface MSACWrapperLoggerTests : XCTestCase

@end

@implementation MSACWrapperLoggerTests

- (void)testWrapperLogger {

  // If
  __block XCTestExpectation *expectation = [self expectationWithDescription:@"Wrapper logger"];
  __block NSString *expectedMessage = @"expectedMessage";
  NSString *tag = @"TAG";
  __block NSString *message = nil;
  MSACLogMessageProvider messageProvider = ^() {
    message = expectedMessage;
    [expectation fulfill];
    return message;
  };

  // When
  [MSACLogger setCurrentLogLevel:MSACLogLevelDebug];
  [MSACWrapperLogger MSACWrapperLog:messageProvider tag:tag level:MSACLogLevelDebug];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(expectedMessage, message);
                               }];
}

@end
