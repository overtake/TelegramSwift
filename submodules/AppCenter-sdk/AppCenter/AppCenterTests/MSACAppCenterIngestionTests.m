// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "MSACAppCenterErrors.h"
#import "MSACAppCenterIngestion.h"
#import "MSACConstants+Internal.h"
#import "MSACDeviceInternal.h"
#import "MSACHttpClient.h"
#import "MSACHttpIngestionPrivate.h"
#import "MSACHttpTestUtil.h"
#import "MSACHttpUtil.h"
#import "MSACLoggerInternal.h"
#import "MSACMockLog.h"
#import "MSACTestFrameworks.h"
#import "MSACTestUtil.h"

static NSTimeInterval const kMSACTestTimeout = 5.0;
static NSString *const kMSACBaseUrl = @"https://test.com";
static NSString *const kMSACTestAppSecret = @"TestAppSecret";

@interface MSACAppCenterIngestionTests : XCTestCase

@property(nonatomic) MSACAppCenterIngestion *sut;
@property(nonatomic) id deviceMock;
@property(nonatomic) id reachabilityMock;
@property(nonatomic) NetworkStatus currentNetworkStatus;
@property(nonatomic) id httpClientMock;

@end

/*
 * TODO: Separate base MSACHttpIngestion tests from this test and instantiate MSACAppCenterIngestion with initWithBaseUrl:, not the one with
 * multiple parameters. Look at comments in each method. Add testHeaders to verify headers are populated properly. Look at testHeaders in
 * MSACOneCollectorIngestionTests.
 */
@implementation MSACAppCenterIngestionTests

- (void)setUp {
  [super setUp];

  NSDictionary *headers = @{@"Content-Type" : @"application/json", @"App-Secret" : kMSACTestAppSecret, @"Install-ID" : MSAC_UUID_STRING};
  NSDictionary *queryStrings = @{@"api-version" : @"1.0.0"};
  self.httpClientMock = OCMPartialMock([MSACHttpClient new]);
  self.deviceMock = OCMPartialMock([MSACDevice new]);
  OCMStub([self.deviceMock isValid]).andReturn(YES);

  // Mock reachability.
  self.reachabilityMock = OCMClassMock([MSAC_Reachability class]);
  self.currentNetworkStatus = ReachableViaWiFi;
  OCMStub([self.reachabilityMock currentReachabilityStatus]).andDo(^(NSInvocation *invocation) {
    NetworkStatus test = self.currentNetworkStatus;
    [invocation setReturnValue:&test];
  });

  // sut: System under test
  self.sut = [[MSACAppCenterIngestion alloc] initWithHttpClient:self.httpClientMock
                                                        baseUrl:kMSACBaseUrl
                                                        apiPath:@"/test-path"
                                                        headers:headers
                                                   queryStrings:queryStrings
                                                 retryIntervals:@[ @(0.5), @(1), @(1.5) ]];
  [self.sut setAppSecret:kMSACTestAppSecret];
}

- (void)tearDown {
  [MSACHttpTestUtil removeAllStubs];

  /*
   * Setting the variable to nil. We are experiencing test failure on Xcode 9 beta because the instance that was used for previous test
   * method is not disposed and still listening to network changes in other tests.
   */
  [MSAC_NOTIFICATION_CENTER removeObserver:self.sut name:kMSACReachabilityChangedNotification object:nil];
  self.sut = nil;

  // Stop mock.
  [self.deviceMock stopMocking];
  [self.httpClientMock stopMocking];
  [self.reachabilityMock stopMocking];
  [super tearDown];
}

- (void)testSendBatchLogs {

  // Stub http response
  [MSACHttpTestUtil stubHttp200Response];
  NSString *containerId = @"1";
  MSACLogContainer *container = [MSACTestUtil createLogContainerWithId:containerId device:self.deviceMock];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Response 200"];
  [self.sut sendAsync:container
      completionHandler:^(NSString *batchId, NSHTTPURLResponse *response, __unused NSData *data, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(containerId, batchId);
        XCTAssertEqual((MSACHTTPCodesNo)response.statusCode, MSACHTTPCodesNo200OK);

        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testInvalidContainer {
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Http call complete."];
  MSACAbstractLog *log = [MSACAbstractLog new];
  log.sid = MSAC_UUID_STRING;
  log.timestamp = [NSDate date];

  // Log does not have device info, therefore, it's an invalid log
  MSACLogContainer *container = [[MSACLogContainer alloc] initWithBatchId:@"1" andLogs:(NSArray<id<MSACLog>> *)@[ log ]];

  // Then
  OCMReject([self.httpClientMock sendAsync:OCMOCK_ANY
                                    method:OCMOCK_ANY
                                   headers:OCMOCK_ANY
                                      data:OCMOCK_ANY
                            retryIntervals:OCMOCK_ANY
                        compressionEnabled:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY]);

  // When
  [self.sut sendAsync:container
      completionHandler:^(__unused NSString *batchId, __unused NSHTTPURLResponse *response, __unused NSData *data, NSError *error) {
        XCTAssertEqual(error.domain, kMSACACErrorDomain);
        XCTAssertEqual(error.code, MSACACLogInvalidContainerErrorCode);
        [expectation fulfill];
      }];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testNilContainer {

  MSACLogContainer *container = nil;

  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Network Down"];
  [self.sut sendAsync:container
      completionHandler:^(__unused NSString *batchId, __unused NSHTTPURLResponse *response, __unused NSData *data, NSError *error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testHttpClientDelegateObfuscateHeaderValue {

  // If
  id mockLogger = OCMClassMock([MSACLogger class]);
  id mockHttpUtil = OCMClassMock([MSACHttpUtil class]);
  OCMStub([mockLogger currentLogLevel]).andReturn(MSACLogLevelVerbose);
  OCMStub(ClassMethod([mockHttpUtil hideSecret:OCMOCK_ANY])).andDo(nil);
  NSDictionary<NSString *, NSString *> *headers = @{kMSACHeaderAppSecretKey : kMSACTestAppSecret};
  NSURL *url = [NSURL new];

  // When
  [self.sut willSendHTTPRequestToURL:url withHeaders:headers];

  // Then
  OCMVerify([mockHttpUtil hideSecret:kMSACTestAppSecret]);

  [mockLogger stopMocking];
  [mockHttpUtil stopMocking];
}

- (void)testSetBaseURL {

  // If
  NSString *path = @"path";
  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", @"https://www.contoso.com/", path]];
  self.sut.apiPath = path;

  // Query should be the same.
  NSString *query = self.sut.sendURL.query;

  // When
  [self.sut setBaseURL:(NSString * _Nonnull)[url.URLByDeletingLastPathComponent absoluteString]];

  // Then
  XCTAssertNotNil(query);
  NSString *expectedURLString = [NSString stringWithFormat:@"%@?%@", url.absoluteString, query];
  XCTAssertTrue([[self.sut.sendURL absoluteString] isEqualToString:expectedURLString]);
}

- (void)testSetInvalidBaseURL {

  // If
  NSURL *expected = self.sut.sendURL;
  NSString *invalidURL = @"\notGood";

  // When
  [self.sut setBaseURL:invalidURL];

  // Then
  assertThat(self.sut.sendURL, is(expected));
}

- (void)testObfuscateResponsePayload {

  // If
  NSString *payload = @"I am the payload for testing";

  // When
  NSString *actual = [self.sut obfuscateResponsePayload:payload];

  // Then
  XCTAssertEqual(actual, payload);
}

@end
