// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "HTTPStubs.h"
#import "NSURLRequest+HTTPBodyTesting.h"

#import "AppCenter+Internal.h"
#import "MSACAppCenterErrors.h"
#import "MSACConstants+Internal.h"
#import "MSACDevice.h"
#import "MSACDeviceInternal.h"
#import "MSACHttpCall.h"
#import "MSACHttpClientPrivate.h"
#import "MSACHttpTestUtil.h"
#import "MSACMockLog.h"
#import "MSACTestFrameworks.h"
#import "MSACTestUtil.h"
#import "MSAC_Reachability.h"

static NSTimeInterval const kMSACTestTimeout = 5.0;

@interface MSACHttpClientTests : XCTestCase

@property(nonatomic) id reachabilityMock;
@property(nonatomic) NetworkStatus currentNetworkStatus;

@end

@interface MSACHttpClient ()

- (instancetype)initWithMaxHttpConnectionsPerHost:(NSNumber *)maxHttpConnectionsPerHost reachability:(MSAC_Reachability *)reachability;

@end

@implementation MSACHttpClientTests

- (void)setUp {
  [super setUp];

  // Mock reachability.
  self.reachabilityMock = OCMClassMock([MSAC_Reachability class]);
  self.currentNetworkStatus = ReachableViaWiFi;
  OCMStub([self.reachabilityMock currentReachabilityStatus]).andDo(^(NSInvocation *invocation) {
    NetworkStatus test = self.currentNetworkStatus;
    [invocation setReturnValue:&test];
  });
}

- (void)tearDown {
  [MSACHttpTestUtil removeAllStubs];
  [self.reachabilityMock stopMocking];
  [super tearDown];
}

- (void)testInitWithMaxHttpConnectionsPerHost {

  // When
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:2];

  // Then
  XCTAssertEqual(httpClient.sessionConfiguration.HTTPMaximumConnectionsPerHost, 2);
}

- (void)testPostSuccessWithoutHeaders {

  // If
  __block NSURLRequest *actualRequest;

  // Stub HTTP response.
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        NSData *responsePayload = [@"OK" dataUsingEncoding:kCFStringEncodingUTF8];
        return [HTTPStubsResponse responseWithData:responsePayload statusCode:MSACHTTPCodesNo200OK headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Response 200"];
  MSACHttpClient *httpClient = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"POST";
  NSData *payload = [@"somePayload" dataUsingEncoding:kCFStringEncodingUTF8];

  // When
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:payload
      completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
        // Then
        XCTAssertEqual(response.statusCode, MSACHTTPCodesNo200OK);
        XCTAssertEqualObjects(responseBody, [@"OK" dataUsingEncoding:kCFStringEncodingUTF8]);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  XCTAssertEqualObjects(actualRequest.URL, url);
  XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
  XCTAssertEqualObjects(actualRequest.OHHTTPStubs_HTTPBody, payload);
}

- (void)testSendAsyncEnablesCompressionByDefaultAndUsesDefaultRetries {

  // If
  MSACHttpClient *httpClient = OCMPartialMock([MSACHttpClient new]);
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"GET";
  NSArray *defaultRetryIntervals = @[ @10, @(5 * 60), @(20 * 60) ];
  OCMStub([httpClient sendCallAsync:OCMOCK_ANY]).andDo(nil);

  // When
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:nil
      completionHandler:^(NSData *_Nullable responseBody __unused, NSHTTPURLResponse *_Nullable response __unused,
                          NSError *_Nullable error __unused){
      }];

  // Then
  OCMVerify([httpClient sendAsync:url
                           method:method
                          headers:nil
                             data:nil
                   retryIntervals:defaultRetryIntervals
               compressionEnabled:YES
                completionHandler:OCMOCK_ANY]);
}

- (void)testGetWithHeadersResultInFatalNSError {

  // If
  __block NSURLRequest *actualRequest;

  // Stub HTTP response.
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorBadURL userInfo:nil];
        return [HTTPStubsResponse responseWithError:error];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Network error"];
  MSACHttpClient *httpClient = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"GET";

  // When
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:nil
      completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
        // Then
        XCTAssertNil(response);
        XCTAssertNil(responseBody);
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Then
  XCTAssertEqualObjects(actualRequest.URL, url);
  XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
}

- (void)testDeleteUnrecoverableErrorWithoutHeadersNotRetried {

  // If
  __block int numRequests = 0;
  __block NSURLRequest *actualRequest;
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        ++numRequests;
        actualRequest = request;
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo400BadRequest headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  MSACHttpClient *httpClient = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:nil
      completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
        // Then
        XCTAssertEqual(response.statusCode, MSACHTTPCodesNo400BadRequest);
        XCTAssertNotNil(responseBody);
        XCTAssertNil(error);
        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  // Then
  XCTAssertEqualObjects(actualRequest.URL, url);
  XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
  XCTAssertEqual(numRequests, 1);
}

- (void)testRecoverableNSErrorRetriedWhenNetworkReturns {

  /*
   * The test scenario:
   * 1. Request is sent.
   * 2. Network goes down during request.
   * 3. Test must ensure that the completion handler is not called here.
   * 4. Network returns.
   * 5. Test must verify that the completion handler is called now.
   */

  // If
  __block BOOL completionHandlerCalled = NO;
  __block BOOL firstTime = YES;
  __block NSURLRequest *actualRequest;
  dispatch_semaphore_t networkDownSemaphore = dispatch_semaphore_create(0);
  NSArray *retryIntervals = @[ @1, @2 ];
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        if (firstTime) {
          firstTime = NO;
          NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotLoadFromNetwork userInfo:nil];

          // Simulate network outage mid-request
          [self simulateReachabilityChangedNotification:NotReachable];

          // Network is down so it is now okay for the test to bring the network back.
          dispatch_semaphore_signal(networkDownSemaphore);
          return [HTTPStubsResponse responseWithError:error];
        }
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:self.reachabilityMock];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:retryIntervals
      compressionEnabled:YES
       completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error) {
         completionHandlerCalled = YES;
         XCTAssertNotNil(responseBody);
         XCTAssertNotNil(response);
         XCTAssertEqual(response.statusCode, MSACHTTPCodesNo204NoContent);
         XCTAssertNil(error);
         [expectation fulfill];
       }];

  // Wait a little to ensure that the completion handler is not invoked yet.
  sleep(1);

  // Then
  XCTAssertFalse(completionHandlerCalled);

  // When

  // Only bring the network back once it went down.
  dispatch_semaphore_wait(networkDownSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMSACTestTimeout * NSEC_PER_SEC)));

  // Restore the network and wait for completion handler to be called.
  [self simulateReachabilityChangedNotification:ReachableViaWiFi];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testRecoverableHttpErrorThenPauseResume {

  // If
  __block BOOL completionHandlerCalled = NO;
  __block BOOL firstTime = YES;
  __block NSURLRequest *actualRequest;
  dispatch_semaphore_t networkDownSemaphore = dispatch_semaphore_create(0);
  NSArray *retryIntervals = @[ @5, @2 ];
  __block MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:self.reachabilityMock];
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        if (firstTime) {

          // Simulate network outage while waiting for retry.
          int64_t nanoseconds = (int64_t)(1 * NSEC_PER_SEC);
          dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, nanoseconds);
          dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self simulateReachabilityChangedNotification:NotReachable];
            dispatch_semaphore_signal(networkDownSemaphore);
          });
          firstTime = NO;
          return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo503ServiceUnavailable headers:nil];
        }
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:retryIntervals
      compressionEnabled:YES
       completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error) {
         completionHandlerCalled = YES;
         XCTAssertNotNil(responseBody);
         XCTAssertNotNil(response);
         XCTAssertEqual(response.statusCode, MSACHTTPCodesNo204NoContent);
         XCTAssertNil(error);
         [expectation fulfill];
       }];

  // Wait a little to ensure that the completion handler is not invoked yet.
  sleep(1);

  // Then
  XCTAssertFalse(completionHandlerCalled);

  // When

  // Only bring the network back once it went down.
  dispatch_semaphore_wait(networkDownSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMSACTestTimeout * NSEC_PER_SEC)));

  // Restore the network and wait for completion handler to be called.
  [self simulateReachabilityChangedNotification:ReachableViaWiFi];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testNetworkDownAndThenUpAgain {

  // If
  __block int numRequests = 0;
  __block NSURLRequest *actualRequest;
  __block BOOL completionHandlerCalled = NO;
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        ++numRequests;
        actualRequest = request;
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:self.reachabilityMock];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [self simulateReachabilityChangedNotification:NotReachable];
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:@[ @1 ]
      compressionEnabled:YES
       completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
         // Then
         XCTAssertEqual(response.statusCode, MSACHTTPCodesNo204NoContent);
         XCTAssertEqualObjects(responseBody, [NSData data]);
         XCTAssertNil(error);
         completionHandlerCalled = YES;
         [expectation fulfill];
       }];

  // Wait a while to make sure that the requests are not sent while the network is down.
  sleep(1);

  // Then
  XCTAssertFalse(completionHandlerCalled);
  XCTAssertEqual(numRequests, 0);

  // When
  [self simulateReachabilityChangedNotification:ReachableViaWiFi];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertEqualObjects(actualRequest.URL, url);
                                 XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
                                 XCTAssertEqual(numRequests, 1);
                               }];
}

- (void)testDeleteRecoverableErrorWithoutHeadersRetried {

  // If
  __block int numRequests = 0;
  __block NSURLRequest *actualRequest;
  NSArray *retryIntervals = @[ @1, @2 ];
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        ++numRequests;
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo500InternalServerError headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:nil];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:retryIntervals
      compressionEnabled:YES
       completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
         // Then
         XCTAssertEqual(response.statusCode, MSACHTTPCodesNo500InternalServerError);
         XCTAssertNotNil(responseBody);
         XCTAssertNil(error);
         [expectation fulfill];
       }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Then
  XCTAssertEqualObjects(actualRequest.URL, url);
  XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
  XCTAssertEqual(numRequests, 1 + [retryIntervals count]);
}

- (void)testPauseThenResumeDoesNotResendCalls {

  // Scenario is pausing the client while there is a call that is being sent but hasn't completed yet, and then calling resume.

  // If
  __block int numRequests = 0;
  dispatch_semaphore_t responseSemaphore = dispatch_semaphore_create(0);
  dispatch_semaphore_t pauseSemaphore = dispatch_semaphore_create(0);
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        ++numRequests;

        // Use this semaphore to prevent the pause from occurring before the call is enqueued.
        dispatch_semaphore_signal(responseSemaphore);

        // Don't let the request finish before pausing.
        dispatch_semaphore_wait(pauseSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMSACTestTimeout * NSEC_PER_SEC)));
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:self.reachabilityMock];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:@[]
      compressionEnabled:YES
       completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error){
       }];

  // Don't pause until the call has been enqueued.
  dispatch_semaphore_wait(responseSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMSACTestTimeout * NSEC_PER_SEC)));
  [self simulateReachabilityChangedNotification:NotReachable];
  dispatch_semaphore_signal(pauseSemaphore);
  [self simulateReachabilityChangedNotification:ReachableViaWiFi];

  // Wait a while to make sure that the request is not sent after resuming.
  sleep(1);

  // Then
  XCTAssertEqual(numRequests, 1);
}

- (void)testDisablingCancelsCalls {

  // If
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  dispatch_semaphore_t responseSemaphore = dispatch_semaphore_create(0);
  dispatch_semaphore_t testCompletedSemaphore = dispatch_semaphore_create(0);
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        dispatch_semaphore_signal(responseSemaphore);

        // Sleep to ensure that the call is really canceled instead of waiting for the response.
        dispatch_semaphore_wait(testCompletedSemaphore, DISPATCH_TIME_FOREVER);
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:nil];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:@[ @1 ]
      compressionEnabled:YES
       completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
         // Then
         XCTAssertNotNil(error);
         XCTAssertNil(response);
         XCTAssertNil(responseBody);
         [expectation fulfill];
       }];

  // Don't disable until the call has been enqueued.
  dispatch_semaphore_wait(responseSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMSACTestTimeout * NSEC_PER_SEC)));
  [httpClient setEnabled:NO andDeleteDataOnDisabled:YES];

  // Then
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clean up.
  dispatch_semaphore_signal(testCompletedSemaphore);
}

- (void)testDisableThenEnable {

  // If
  __block NSURLRequest *actualRequest;

  // Stub HTTP response.
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        NSData *responsePayload = [@"OK" dataUsingEncoding:kCFStringEncodingUTF8];
        return [HTTPStubsResponse responseWithData:responsePayload statusCode:MSACHTTPCodesNo200OK headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Response 200"];
  MSACHttpClient *httpClient = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"POST";
  NSData *payload = [@"somePayload" dataUsingEncoding:kCFStringEncodingUTF8];

  // When
  [httpClient setEnabled:NO];
  [httpClient setEnabled:YES];
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:payload
      completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
        // Then
        XCTAssertEqual(response.statusCode, MSACHTTPCodesNo200OK);
        XCTAssertEqualObjects(responseBody, [@"OK" dataUsingEncoding:kCFStringEncodingUTF8]);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Then
  XCTAssertEqualObjects(actualRequest.URL, url);
  XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
  XCTAssertEqualObjects(actualRequest.OHHTTPStubs_HTTPBody, payload);
}

- (void)testRetryHeaderInResponse {

  // If
  __block int numRequests = 0;
  __block NSURLRequest *actualRequest;
  NSArray *retryIntervals = @[ @1000000000, @100000000 ];
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        ++numRequests;
        if (numRequests < 3) {
          return [HTTPStubsResponse responseWithData:[NSData data]
                                          statusCode:MSACHTTPCodesNo429TooManyRequests
                                             headers:@{@"x-ms-retry-after-ms" : @"100"}];
        }
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  MSACHttpClient *httpClient = [[MSACHttpClient alloc] initWithMaxHttpConnectionsPerHost:nil reachability:nil];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"DELETE";

  // When
  [httpClient sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:retryIntervals
      compressionEnabled:YES
       completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
         // Then
         XCTAssertEqual(response.statusCode, MSACHTTPCodesNo204NoContent);
         XCTAssertNotNil(responseBody);
         XCTAssertNil(error);
         [expectation fulfill];
       }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertEqualObjects(actualRequest.URL, url);
                                 XCTAssertEqualObjects(actualRequest.HTTPMethod, method);
                                 XCTAssertEqual(numRequests, 1 + [retryIntervals count]);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testSendAsyncWhileDisabled {

  // If
  __block NSURLRequest *actualRequest;
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        actualRequest = request;
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:MSACHTTPCodesNo204NoContent headers:nil];
      }];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@""];
  MSACHttpClient *httpClient = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"GET";

  // When
  [httpClient setEnabled:NO andDeleteDataOnDisabled:NO];
  [httpClient sendAsync:url
                 method:method
                headers:nil
                   data:nil
      completionHandler:^(NSData *responseBody, NSHTTPURLResponse *response, NSError *error) {
        // Then
        XCTAssertNil(response);
        XCTAssertNil(responseBody);
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Then
  XCTAssertNil(actualRequest);
}

- (void)testPausedWhenAllRetriesUsed {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Used all retries."];
  NSString *containerId = @"1";
  MSACLogContainer *container = OCMPartialMock([MSACLogContainer new]);
  OCMStub([container isValid]).andReturn(YES);
  OCMStub([container batchId]).andReturn(containerId);
  MSACHttpClient *sut = [MSACHttpClient new];
  NSURL *url = [NSURL URLWithString:@"https://mock/something?a=b"];
  NSString *method = @"GET";

  // Mock the call to intercept the retry.
  NSArray *intervals = @[ @(0.5), @(1) ];

  // Respond with a retryable error.
  [MSACHttpTestUtil stubHttp500Response];

  // Send the call.
  [sut sendAsync:url
                  method:method
                 headers:nil
                    data:nil
          retryIntervals:intervals
      compressionEnabled:YES
       completionHandler:^(NSData *_Nullable responseBody __unused, NSHTTPURLResponse *_Nullable response __unused,
                           NSError *_Nullable error __unused) {
         [expectation fulfill];
       }];
  [self waitForExpectationsWithTimeout:kMSACTestTimeout
                               handler:^(NSError *error) {
                                 XCTAssertTrue(sut.paused);
                                 XCTAssertTrue([sut.pendingCalls count] == 0);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testRetryStoppedWhilePaused {

  // If
  XCTestExpectation *responseReceivedExpectation = [self expectationWithDescription:@"Request completed."];
  MSACDevice *device = OCMPartialMock([MSACDevice new]);
  OCMStub([device isValid]).andReturn(YES);
  MSACHttpClient *httpClient = [MSACHttpClient new];

  // Mock the call to intercept the retry.
  NSArray *intervals = @[ @(UINT_MAX), @(UINT_MAX) ];
  MSACHttpCall *httpCall =
      [[MSACHttpCall alloc] initWithUrl:[[NSURL alloc] initWithString:@""]
                                 method:@"GET"
                                headers:nil
                                   data:nil
                         retryIntervals:intervals
                     compressionEnabled:YES
                      completionHandler:^(NSData *_Nullable responseBody __unused, NSHTTPURLResponse *_Nullable response __unused,
                                          NSError *_Nullable error __unused){
                      }];

  // A non-zero number that should be reset by the end.
  httpCall.retryCount = 1;
  id mockHttpClient = OCMPartialMock(httpClient);
  [httpClient.pendingCalls addObject:httpCall];

  OCMStub([mockHttpClient requestCompletedWithHttpCall:httpCall data:OCMOCK_ANY response:OCMOCK_ANY error:OCMOCK_ANY])
      .andForwardToRealObject()
      .andDo(^(NSInvocation *invocation __unused) {
        [responseReceivedExpectation fulfill];
      });

  // Respond with a retryable error.
  [MSACHttpTestUtil stubHttp500Response];

  // Send the call.
  [httpClient sendCallAsync:httpCall];
  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 // When
                                 // Pause now that the call is retrying.
                                 [httpClient pause];

                                 // Then
                                 // Retry must be stopped.
                                 if (@available(macOS 10.10, tvOS 9.0, watchOS 2.0, *)) {
                                   XCTAssertNotEqual(0, dispatch_testcancel(httpCall.timerSource));
                                 }
                                 XCTAssertEqual(httpCall.retryCount, 0);
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)simulateReachabilityChangedNotification:(NetworkStatus)status {
  self.currentNetworkStatus = status;
  [[NSNotificationCenter defaultCenter] postNotificationName:kMSACReachabilityChangedNotification object:self.reachabilityMock];
}

@end
