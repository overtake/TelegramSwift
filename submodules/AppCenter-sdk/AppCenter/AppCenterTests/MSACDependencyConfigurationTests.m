// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenter.h"
#import "MSACAppCenterPrivate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACDependencyConfiguration.h"
#import "MSACHttpClient.h"
#import "MSACTestFrameworks.h"

@interface MSACDependencyConfigurationTests : XCTestCase

@property id channelGroupDefaultClassMock;

@end

@implementation MSACDependencyConfigurationTests

- (void)setUp {
  [MSACAppCenter resetSharedInstance];
  self.channelGroupDefaultClassMock = OCMClassMock([MSACChannelGroupDefault class]);
  OCMStub([self.channelGroupDefaultClassMock alloc]).andReturn(self.channelGroupDefaultClassMock);
  OCMStub([self.channelGroupDefaultClassMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:OCMOCK_ANY]).andReturn(nil);
}

- (void)tearDown {
  [self.channelGroupDefaultClassMock stopMocking];
  [MSACAppCenter resetSharedInstance];
  [super tearDown];
}

- (void)testNotSettingDependencyCallUsesDefaultHttpClient {

  // If
  id httpClientClassMock = OCMClassMock([MSACHttpClient class]);
  OCMStub([httpClientClassMock new]).andReturn(httpClientClassMock);

  // When
  [MSACAppCenter configureWithAppSecret:@"App-Secret"];

  // Then
  // Cast to void to get rid of warning that says "Expression result unused".
  OCMVerify((void)[self.channelGroupDefaultClassMock initWithHttpClient:httpClientClassMock installId:OCMOCK_ANY logUrl:OCMOCK_ANY]);

  // Cleanup
  [httpClientClassMock stopMocking];
}

- (void)testDependencyCallUsesInjectedHttpClient {

  // If
  id httpClientClassMock = OCMClassMock([MSACHttpClient class]);

  // This stub is still required due to `oneCollectorChannelDelegate` that requires `MSACHttpClient` instantiation.
  // Without this stub, `[MSACHttpClientTests testDeleteRecoverableErrorWithoutHeadersRetried]` test will fail for macOS because
  // channel is paused by this `MSACHttpClient` instance somehow.
  OCMStub([httpClientClassMock alloc]).andReturn(httpClientClassMock);
  [MSACDependencyConfiguration setHttpClient:httpClientClassMock];

  // When
  [MSACAppCenter configureWithAppSecret:@"App-Secret"];

  // Then
  // Cast to void to get rid of warning that says "Expression result unused".
  OCMVerify((void)[self.channelGroupDefaultClassMock initWithHttpClient:httpClientClassMock installId:OCMOCK_ANY logUrl:OCMOCK_ANY]);

  // Cleanup
  MSACDependencyConfiguration.httpClient = nil;
  [httpClientClassMock stopMocking];
}

@end
