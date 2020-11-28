// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "HTTPStubs.h"

#import "MSACConstants.h"
#import "MSACHttpTestUtil.h"
#import "MSACTestFrameworks.h"

/*
 * TODO: We need to reduce this response time from UID_MAX to 2.0 because [OHHTTPStubs removeAllStubs] is called before timeout and it
 * results a crash with succeeded test. Testing on Xcode 8 doesn't have any issues on it but Xcode 9 complains. Keep in mind that 2 sec
 * timeout is not somewhat we get from accurate testing, it is a heuristic number and it might fail any unit tests.
 */
static NSTimeInterval const kMSACStubbedResponseTimeout = 2.0;
static NSString *const kMSACStub500Name = @"httpStub_500";
static NSString *const kMSACStub404Name = @"httpStub_404";
static NSString *const kMSACStub200Name = @"httpStub_200";
static NSString *const kMSACStubNetworkDownName = @"httpStub_NetworkDown";
static NSString *const kMSACStubLongResponseTimeOutName = @"httpStub_LongResponseTimeOut";

@implementation MSACHttpTestUtil

+ (void)stubHttp500Response {
  [[self class] stubResponseWithCode:MSACHTTPCodesNo500InternalServerError name:kMSACStub500Name];
}

+ (void)stubHttp404Response {
  [[self class] stubResponseWithCode:MSACHTTPCodesNo404NotFound name:kMSACStub404Name];
}

+ (void)stubHttp200Response {
  [[self class] stubResponseWithCode:MSACHTTPCodesNo200OK name:kMSACStub200Name];
}

+ (void)removeAllStubs {
  [HTTPStubs removeAllStubs];
}

+ (void)stubNetworkDownResponse {
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
  [[self class] stubResponseWithError:error name:kMSACStubNetworkDownName];
}

+ (void)stubLongTimeOutResponse {
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        HTTPStubsResponse *responseStub = [HTTPStubsResponse new];
        responseStub.statusCode = MSACHTTPCodesNo200OK;
        return [responseStub responseTime:kMSACStubbedResponseTimeout];
      }]
      .name = kMSACStubLongResponseTimeOutName;
}

+ (void)stubResponseWithCode:(NSInteger)code name:(NSString *)name {
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        HTTPStubsResponse *responseStub = [HTTPStubsResponse new];
        responseStub.statusCode = (int)code;
        return responseStub;
      }]
      .name = name;
}

+ (void)stubResponseWithData:(NSData *)data statusCode:(int)code headers:(NSDictionary *)headers name:(NSString *)name {
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        return [HTTPStubsResponse responseWithData:data statusCode:code headers:headers];
      }]
      .name = name;
}

+ (void)stubResponseWithError:(NSError *)error name:(NSString *)name {
  [HTTPStubs
      stubRequestsPassingTest:^BOOL(__unused NSURLRequest *request) {
        return YES;
      }
      withStubResponse:^HTTPStubsResponse *(__unused NSURLRequest *request) {
        return [HTTPStubsResponse responseWithError:error];
      }]
      .name = name;
}

+ (NSHTTPURLResponse *)createMockResponseForStatusCode:(int)statusCode headers:(NSDictionary *)headers {
  NSHTTPURLResponse *mockedResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([mockedResponse statusCode]).andReturn(statusCode);
  OCMStub([mockedResponse allHeaderFields]).andReturn(headers);
  return mockedResponse;
}

@end
