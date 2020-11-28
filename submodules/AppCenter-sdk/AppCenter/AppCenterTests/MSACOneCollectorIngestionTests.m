// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "MSACAppCenterErrors.h"
#import "MSACConstants+Internal.h"
#import "MSACDeviceInternal.h"
#import "MSACHttpClient.h"
#import "MSACHttpIngestionPrivate.h"
#import "MSACHttpTestUtil.h"
#import "MSACLoggerInternal.h"
#import "MSACMockCommonSchemaLog.h"
#import "MSACModelTestsUtililty.h"
#import "MSACOneCollectorIngestion.h"
#import "MSACOneCollectorIngestionPrivate.h"
#import "MSACTestFrameworks.h"
#import "MSACTicketCache.h"
#import "MSACUtility+StringFormatting.h"

static NSTimeInterval const kMSACTestTimeout = 5.0;
static NSString *const kMSACBaseUrl = @"https://test.com";

@interface MSACOneCollectorIngestionTests : XCTestCase

@property(nonatomic) MSACOneCollectorIngestion *sut;
@property(nonatomic) id reachabilityMock;
@property(nonatomic) NetworkStatus currentNetworkStatus;
@property(nonatomic) MSACHttpClient *httpClientMock;
@end

@implementation MSACOneCollectorIngestionTests

- (void)setUp {
  [super setUp];

  self.httpClientMock = OCMPartialMock([MSACHttpClient new]);
  self.reachabilityMock = OCMClassMock([MSAC_Reachability class]);
  self.currentNetworkStatus = ReachableViaWiFi;
  OCMStub([self.reachabilityMock currentReachabilityStatus]).andDo(^(NSInvocation *invocation) {
    NetworkStatus test = self.currentNetworkStatus;
    [invocation setReturnValue:&test];
  });

  // sut: System under test
  self.sut = [[MSACOneCollectorIngestion alloc] initWithHttpClient:self.httpClientMock baseUrl:kMSACBaseUrl];
}

- (void)tearDown {
  [super tearDown];
  [self.reachabilityMock stopMocking];
  [MSACHttpTestUtil removeAllStubs];

  /*
   * Setting the variable to nil. We are experiencing test failure on Xcode 9 beta because the instance that was used for previous test
   * method is not disposed and still listening to network changes in other tests.
   */
  self.sut = nil;
}

- (void)testHeaders {

  // If
  id ticketCacheMock = OCMPartialMock([MSACTicketCache sharedInstance]);
  OCMStub([ticketCacheMock ticketFor:@"ticketKey1"]).andReturn(@"ticketKey1Token");
  OCMStub([ticketCacheMock ticketFor:@"ticketKey2"]).andReturn(@"ticketKey2Token");

  // When
  NSString *containerId = @"1";
  MSACLogContainer *container = [self createLogContainerWithId:containerId];
  NSDictionary *headers = [self.sut getHeadersWithData:container eTag:nil];
  NSArray *keys = [headers allKeys];

  // Then
  XCTAssertTrue([keys containsObject:kMSACHeaderContentTypeKey]);
  XCTAssertTrue([[headers objectForKey:kMSACHeaderContentTypeKey] isEqualToString:kMSACOneCollectorContentType]);
  XCTAssertTrue([keys containsObject:kMSACOneCollectorClientVersionKey]);
  NSString *expectedClientVersion = [NSString stringWithFormat:kMSACOneCollectorClientVersionFormat, [MSACUtility sdkVersion]];
  XCTAssertTrue([[headers objectForKey:kMSACOneCollectorClientVersionKey] isEqualToString:expectedClientVersion]);
  XCTAssertNil([headers objectForKey:kMSACHeaderAppSecretKey]);
  XCTAssertTrue([keys containsObject:kMSACOneCollectorApiKey]);
  NSArray *tokens = [[headers objectForKey:kMSACOneCollectorApiKey] componentsSeparatedByString:@","];
  XCTAssertTrue([tokens count] == 3);
  for (NSString *token in @[ @"token1", @"token2", @"token3" ]) {
    XCTAssertTrue([tokens containsObject:token]);
  }
  XCTAssertTrue([keys containsObject:kMSACOneCollectorUploadTimeKey]);
  NSString *uploadTimeString = [headers objectForKey:kMSACOneCollectorUploadTimeKey];
  NSNumberFormatter *formatter = [NSNumberFormatter new];
  [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
  XCTAssertNotNil([formatter numberFromString:uploadTimeString]);
  XCTAssertTrue([keys containsObject:kMSACOneCollectorTicketsKey]);
  NSString *ticketsHeader = [headers objectForKey:kMSACOneCollectorTicketsKey];
  XCTAssertTrue([ticketsHeader isEqualToString:@"{\"ticketKey2\":\"ticketKey2Token\",\"ticketKey1\":\"ticketKey1Token\"}"]);
}

- (void)testHttpClientDelegateObfuscateHeaderValue {

  // If
  id mockLogger = OCMClassMock([MSACLogger class]);
  id ingestionMock = OCMPartialMock(self.sut);
  OCMStub([mockLogger currentLogLevel]).andReturn(MSACLogLevelVerbose);
  OCMStub([ingestionMock obfuscateTargetTokens:OCMOCK_ANY]).andDo(nil);
  OCMStub([ingestionMock obfuscateTickets:OCMOCK_ANY]).andDo(nil);
  NSString *tokenValue = @"12345678";
  NSString *ticketValue = @"something";
  NSDictionary<NSString *, NSString *> *headers = @{kMSACOneCollectorApiKey : tokenValue, kMSACOneCollectorTicketsKey : ticketValue};
  NSURL *url = [NSURL new];

  // When
  [ingestionMock willSendHTTPRequestToURL:url withHeaders:headers];

  // Then
  OCMVerify([ingestionMock obfuscateTargetTokens:tokenValue]);
  OCMVerify([ingestionMock obfuscateTickets:ticketValue]);

  [mockLogger stopMocking];
  [ingestionMock stopMocking];
}

- (void)testObfuscateTargetTokens {

  // If
  NSString *testString = @"12345678";

  // When
  NSString *result = [self.sut obfuscateTargetTokens:testString];

  // Then
  XCTAssertTrue([result isEqualToString:@"********"]);

  // If
  testString = @"ThisWillBeObfuscated, ThisWillBeObfuscated, ThisWillBeObfuscated";

  // When
  result = [self.sut obfuscateTargetTokens:testString];

  // Then
  XCTAssertTrue([result isEqualToString:@"************fuscated,*************fuscated,*************fuscated"]);
}

- (void)testObfuscateTickets {

  // If
  NSString *testString = @"something";

  // When
  NSString *result = [self.sut obfuscateTickets:testString];

  // Then
  XCTAssertTrue([result isEqualToString:testString]);

  // If
  testString = @"{\"ticketKey1\":\"p:AuthorizationValue1\",\"ticketKey2\":\"d:AuthorizationValue2\"}";

  // When
  result = [self.sut obfuscateTickets:testString];

  // Then
  XCTAssertTrue([result isEqualToString:@"{\"ticketKey1\":\"p:***\",\"ticketKey2\":\"d:***\"}"]);
}

- (void)testGetPayload {

  // If
  NSString *containerId = @"1";
  MSACMockCommonSchemaLog *log1 = [[MSACMockCommonSchemaLog alloc] init];
  [log1 addTransmissionTargetToken:@"token1"];
  MSACMockCommonSchemaLog *log2 = [[MSACMockCommonSchemaLog alloc] init];
  [log2 addTransmissionTargetToken:@"token2"];
  MSACLogContainer *logContainer = [[MSACLogContainer alloc] initWithBatchId:containerId andLogs:(NSArray<id<MSACLog>> *)@[ log1, log2 ]];

  // When
  NSData *payload = [self.sut getPayloadWithData:logContainer];

  // Then
  XCTAssertNotNil(payload);
  NSString *containerString =
      [NSString stringWithFormat:@"%@%@%@%@", [log1 serializeLogWithPrettyPrinting:NO], kMSACOneCollectorLogSeparator,
                                 [log2 serializeLogWithPrettyPrinting:NO], kMSACOneCollectorLogSeparator];
  NSData *httpBodyData = [containerString dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(httpBodyData, payload);
}

- (void)testSendBatchLogs {

  // When

  // Stub http response
  [MSACHttpTestUtil stubHttp200Response];
  NSString *containerId = @"1";
  MSACLogContainer *container = [self createLogContainerWithId:containerId];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Response 200"];
  [self.sut sendAsync:container
      completionHandler:^(NSString *batchId, NSHTTPURLResponse *response, __attribute__((unused)) NSData *data, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(containerId, batchId);
        XCTAssertEqual((MSACHTTPCodesNo)response.statusCode, MSACHTTPCodesNo200OK);
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testInvalidContainer {

  // If
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Response 200"];
  MSACAbstractLog *log = [MSACAbstractLog new];
  log.sid = MSAC_UUID_STRING;
  log.timestamp = [NSDate date];

  // Log does not have device info, therefore, it's an invalid log.
  MSACLogContainer *container = [[MSACLogContainer alloc] initWithBatchId:@"1" andLogs:(NSArray<id<MSACLog>> *)@[ log ]];
  OCMReject([self.httpClientMock sendAsync:OCMOCK_ANY
                                    method:OCMOCK_ANY
                                   headers:OCMOCK_ANY
                                      data:OCMOCK_ANY
                            retryIntervals:OCMOCK_ANY
                        compressionEnabled:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY]);

  // When
  [self.sut sendAsync:container
      completionHandler:^(__attribute__((unused)) NSString *batchId, __attribute__((unused)) NSHTTPURLResponse *response,
                          __attribute__((unused)) NSData *data, NSError *error) {
        // Then
        XCTAssertEqual(error.domain, kMSACACErrorDomain);
        XCTAssertEqual(error.code, MSACACLogInvalidContainerErrorCode);
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testNilContainer {

  // If
  MSACLogContainer *container = nil;

  // When
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Network Down"];
  [self.sut sendAsync:container
      completionHandler:^(__attribute__((unused)) NSString *batchId, __attribute__((unused)) NSHTTPURLResponse *response,
                          __attribute__((unused)) NSData *data, NSError *error) {
        // Then
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testSetBaseURL {

  // If
  NSString *path = @"path";
  NSURL *expectedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", @"https://www.contoso.com/", path]];
  self.sut.apiPath = path;

  // Query should be the same.
  NSString *query = self.sut.sendURL.query;

  // When
  [self.sut setBaseURL:(NSString * _Nonnull)[expectedURL.URLByDeletingLastPathComponent absoluteString]];

  // Then
  XCTAssertNil(query);
  XCTAssertTrue([[self.sut.sendURL absoluteString] isEqualToString:(NSString * _Nonnull) expectedURL.absoluteString]);
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

#pragma mark - Test Helpers

- (MSACLogContainer *)createLogContainerWithId:(NSString *)batchId {
  id deviceMock = OCMPartialMock([MSACDevice new]);
  OCMStub([deviceMock isValid]).andReturn(YES);
  MSACMockCommonSchemaLog *log1 = [[MSACMockCommonSchemaLog alloc] init];
  log1.name = @"log1";
  log1.ver = @"3.0";
  log1.sid = MSAC_UUID_STRING;
  log1.timestamp = [NSDate date];
  log1.device = deviceMock;
  [log1 addTransmissionTargetToken:@"token1"];
  [log1 addTransmissionTargetToken:@"token2"];
  log1.ext = [MSACModelTestsUtililty extensionsWithDummyValues:[MSACModelTestsUtililty extensionDummies]];
  MSACMockCommonSchemaLog *log2 = [[MSACMockCommonSchemaLog alloc] init];
  log2.name = @"log2";
  log2.ver = @"3.0";
  log2.sid = MSAC_UUID_STRING;
  log2.timestamp = [NSDate date];
  log2.device = deviceMock;
  [log2 addTransmissionTargetToken:@"token2"];
  [log2 addTransmissionTargetToken:@"token3"];
  log2.ext = [MSACModelTestsUtililty extensionsWithDummyValues:[MSACModelTestsUtililty extensionDummies]];
  MSACLogContainer *logContainer = [[MSACLogContainer alloc] initWithBatchId:batchId andLogs:(NSArray<id<MSACLog>> *)@[ log1, log2 ]];
  return logContainer;
}

- (void)testHideTokenInResponse {

  // If
  id mockUtility = OCMClassMock([MSACUtility class]);
  id mockLogger = OCMClassMock([MSACLogger class]);
  OCMStub([mockLogger currentLogLevel]).andReturn(MSACLogLevelVerbose);
  OCMStub(ClassMethod([mockUtility obfuscateString:OCMOCK_ANY
                               searchingForPattern:kMSACTokenKeyValuePattern
                             toReplaceWithTemplate:kMSACTokenKeyValueObfuscatedTemplate]));
  NSData *data = [@"{\"token\":\"secrets\"}" dataUsingEncoding:NSUTF8StringEncoding];
  MSACLogContainer *logContainer = [self createLogContainerWithId:@"1"];
  XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"Request completed."];

  // When
  [MSACHttpTestUtil stubResponseWithData:data statusCode:MSACHTTPCodesNo200OK headers:self.sut.httpHeaders name:NSStringFromSelector(_cmd)];
  [self.sut sendAsync:logContainer
      completionHandler:^(__unused NSString *batchId, __unused NSHTTPURLResponse *response, __unused NSData *responseData,
                          __unused NSError *error) {
        [requestCompletedExpectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 OCMVerify(ClassMethod([mockUtility obfuscateString:OCMOCK_ANY
                                                                searchingForPattern:kMSACTokenKeyValuePattern
                                                              toReplaceWithTemplate:kMSACTokenKeyValueObfuscatedTemplate]));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [mockUtility stopMocking];
  [mockLogger stopMocking];
}

@end
