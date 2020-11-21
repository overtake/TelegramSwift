/***********************************************************************************
 *
 * Copyright (c) 2012 Olivier Halligon
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

#if SWIFT_PACKAGE
#warning "Skipping AFNetworking tests, due to AFNetworking not supporting Swift Package Manager.
#else

#import <XCTest/XCTest.h>
#import <Availability.h>

#if OHHTTPSTUBS_USE_STATIC_LIBRARY
#import "HTTPStubs.h"
#import "HTTPStubsResponse+JSON.h"
#else
@import OHHTTPStubs;
#endif

#import "AFHTTPSessionManager.h"

static const NSTimeInterval kResponseTimeMaxDelay = 2.5;

@interface AFNetworkingTests : XCTestCase @end

@implementation AFNetworkingTests

-(void)setUp
{
    [super setUp];
    [HTTPStubs removeAllStubs];
}

-(void)test_AFHTTPRequestOperation_success
{
    static const NSTimeInterval kRequestTime = 0.05;
    static const NSTimeInterval kResponseTime = 0.1;
    NSData* expectedResponse = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:expectedResponse statusCode:200 headers:nil]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    XCTestExpectation* expectation = [self expectationWithDescription:@"AFHTTPRequestOperation request finished"];

    NSURL *URL = [NSURL URLWithString:@"http://www.iana.org/domains/example/"];

    __block __strong id response = nil;
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
    [manager GET:URL.absoluteString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        response = responseObject; // keep strong reference
        [expectation fulfill];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        XCTFail(@"Unexpected network failure");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];

    XCTAssertEqualObjects(response, expectedResponse, @"Unexpected data received");
}

-(void)test_AFHTTPRequestOperation_multiple_choices
{
    static const NSTimeInterval kRequestTime = 0.05;
    static const NSTimeInterval kResponseTime = 0.1;
    NSData* expectedResponse = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:expectedResponse statusCode:300 headers:@{@"Location":@"http://www.iana.org/domains/another/example"}]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    XCTestExpectation* expectation = [self expectationWithDescription:@"AFHTTPRequestOperation request finished"];

    NSURL *URL = [NSURL URLWithString:@"http://www.iana.org/domains/example/"];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPResponseSerializer* serializer = [AFHTTPResponseSerializer serializer];
    [serializer  setAcceptableStatusCodes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 101)]];
    [manager setResponseSerializer:serializer];

    __block __strong id response = nil;
    [manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest * (NSURLSession * session, NSURLSessionTask * task, NSURLResponse * response, NSURLRequest * request) {
        if (response == nil) {
            return request;
        }
        XCTFail(@"Unexpected redirect");
        return nil;
    }];

    [manager GET:URL.absoluteString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        response = responseObject; // keep strong reference
        [expectation fulfill];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        XCTFail(@"Unexpected network failure");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];

    XCTAssertEqualObjects(response, expectedResponse, @"Unexpected data received");
}

-(void)test_AFHTTPRequestOperation_redirect
{
    static const NSTimeInterval kRequestTime = 0.05;
    static const NSTimeInterval kResponseTime = 0.1;

    NSURL* redirectURL = [NSURL URLWithString:@"https://httpbin.org/get"];
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:[NSData data] statusCode:302 headers:@{@"Location":redirectURL.absoluteString}]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    XCTestExpectation* redirectExpectation = [self expectationWithDescription:@"AFHTTPRequestOperation request was redirected"];
    XCTestExpectation* expectation = [self expectationWithDescription:@"AFHTTPRequestOperation request finished"];

    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://httpbin.org/redirect/1"]];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPResponseSerializer *serializer = [AFHTTPResponseSerializer serializer];
    serializer.acceptableStatusCodes = [NSIndexSet indexSetWithIndex:302];
    [manager setResponseSerializer:serializer];

    __block __strong NSURL* url = nil;
    [manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest * (NSURLSession * session, NSURLSessionTask * task, NSURLResponse * response, NSURLRequest * request) {
        if (response == nil) {
            return request;
        }
        url = request.URL;
        [redirectExpectation fulfill];
        return nil;
    }];

    [manager GET:req.URL.absoluteString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        // Expect the 302 response when the redirection block returns nil (don't follow redirects)
        [expectation fulfill];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        XCTFail(@"Unexpected network failure");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];

    XCTAssertEqualObjects(url, redirectURL, @"Unexpected data received");
}

/*
 * In order to establish that test_AFHTTPRequestOperation_redirect was incorrect and needed fixing, I needed
 * to demonstrate identical behaviour--that is, returning the redirect response itself to the success block--
 * when running without the NSURLProtocol stubbing the request. The test below, if enabled, establishes this,
 * as it is identical to test_AFHTTPRequestOperation_redirect except that it does not stub the requests.
 */
#if 0
-(void)test_AFHTTPRequestOperation_redirect_baseline
{
    NSURL* redirectURL = [NSURL URLWithString:@"https://httpbin.org/get"];

    XCTestExpectation* redirectExpectation = [self expectationWithDescription:@"AFHTTPRequestOperation request was redirected"];
    XCTestExpectation* expectation = [self expectationWithDescription:@"AFHTTPRequestOperation request finished"];

    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://httpbin.org/redirect/1"]];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPResponseSerializer *serializer = [AFHTTPResponseSerializer serializer];
    serializer.acceptableStatusCodes = [NSIndexSet indexSetWithIndex:302];
    [manager setResponseSerializer:serializer];

    __block __strong NSURL* url = nil;
    [manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest * (NSURLSession * session, NSURLSessionTask * task, NSURLResponse * response, NSURLRequest * request) {
        if (response == nil) {
            return request;
        }
        url = request.URL;
        [redirectExpectation fulfill];
        return nil;
    }];

    [manager GET:req.URL.absoluteString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        // Expect the 302 response when the redirection block returns nil (don't follow redirects)
        [expectation fulfill];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        XCTFail(@"Unexpected network failure");
        [expectation fulfill];
    }];

    // Allow a longer timeout as this test actually hits the network
    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertEqualObjects(url, redirectURL, @"Unexpected data received");
}
#endif


@end



#pragma mark - NSURLSession / AFHTTPURLSession support

// Compile this only if SDK version (…MAX_ALLOWED) is iOS7+/10.9+ because NSURLSession is a class only known starting these SDKs
// (this code won't compile if we use an eariler SDKs, like when building with Xcode4)
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) \
|| (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090) \
|| (defined(__TV_OS_VERSION_MIN_REQUIRED) || defined(__WATCH_OS_VERSION_MIN_REQUIRED))


#import "AFHTTPSessionManager.h"

@interface AFNetworkingTests (NSURLSession) @end
@implementation AFNetworkingTests (NSURLSession)

- (void)test_AFHTTPURLSessionCustom
{
    if ([NSURLSession class] && [NSURLSessionConfiguration class])
    {
        static const NSTimeInterval kRequestTime = 0.1;
        static const NSTimeInterval kResponseTime = 0.2;
        NSDictionary *expectedResponseDict = @{@"Success" : @"Yes"};

        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.scheme isEqualToString:@"stubs"];
        } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
            return [[HTTPStubsResponse responseWithJSONObject:expectedResponseDict statusCode:200 headers:nil]
                    requestTime:kRequestTime responseTime:kResponseTime];
        }];

        XCTestExpectation* expectation = [self expectationWithDescription:@"AFHTTPSessionManager request finished"];

        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURL* baseURL = [NSURL URLWithString:@"stubs://stubs/"];
        AFHTTPSessionManager *sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL
                                                                        sessionConfiguration:sessionConfig];

        __block __strong id response = nil;
        [sessionManager GET:@"foo"
                 parameters:nil
                   progress:nil
                    success:^(NSURLSessionDataTask *task, id responseObject) {
                        response = responseObject; // keep strong reference
                        [expectation fulfill];
                    }
                    failure:^(NSURLSessionDataTask *task, NSError *error) {
                        XCTFail(@"Unexpected network failure");
                        [expectation fulfill];
                    }];

        [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];

        XCTAssertEqualObjects(response, expectedResponseDict, @"Unexpected data received");
    }
    else
    {
        NSLog(@"/!\\ Test skipped because the NSURLSession class is not available on this OS version. Run the tests a target with a more recent OS.\n");
    }
}

@end

#else
#warning Unit Tests using NSURLSession were not compiled nor executed, because NSURLSession is only available since iOS7/OSX10.9 SDK. \
-------- Compile using iOS7 or OSX10.9 SDK then launch the tests on the iOS7 simulator or an OSX10.9 target for them to be executed.
#endif
#endif
