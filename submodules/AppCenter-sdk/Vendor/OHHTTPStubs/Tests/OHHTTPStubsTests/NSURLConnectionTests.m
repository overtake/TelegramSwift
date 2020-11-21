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

#import <Availability.h>
// tvOS & watchOS deprecate use of NSURLConnection but these tests are based on it
#if (!defined(__TV_OS_VERSION_MIN_REQUIRED) && !defined(__WATCH_OS_VERSION_MIN_REQUIRED))

#import <XCTest/XCTest.h>

#if OHHTTPSTUBS_USE_STATIC_LIBRARY || SWIFT_PACKAGE
#import "HTTPStubs.h"
#else
@import OHHTTPStubs;
#endif

@interface NSURLConnectionTests : XCTestCase @end

static const NSTimeInterval kResponseTimeMaxDelay = 2.5;

@implementation NSURLConnectionTests

-(void)setUp
{
    [super setUp];
    [HTTPStubs removeAllStubs];
}

static const NSTimeInterval kRequestTime = 0.1;
static const NSTimeInterval kResponseTime = 0.5;

///////////////////////////////////////////////////////////////////////////////////
#pragma mark [NSURLConnection sendSynchronousRequest:returningResponse:error:]
///////////////////////////////////////////////////////////////////////////////////

-(void)test_NSURLConnection_sendSyncronousRequest_mainQueue
{
    NSData* testData = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];

    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:testData
                                           statusCode:200
                                              headers:nil]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.iana.org/domains/example/"]];
    NSDate* startDate = [NSDate date];

    NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:NULL error:NULL];

    XCTAssertEqualObjects(data, testData, @"Invalid data response");
    XCTAssertGreaterThan(-[startDate timeIntervalSinceNow], kRequestTime+kResponseTime, @"Invalid response time");
}

-(void)test_NSURLConnection_sendSyncronousRequest_parallelQueue
{
    XCTestExpectation* expectation = [self expectationWithDescription:@"Synchronous request completed"];
    [[NSOperationQueue new] addOperationWithBlock:^{
        [self test_NSURLConnection_sendSyncronousRequest_mainQueue];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];
}

///////////////////////////////////////////////////////////////////////////////////
#pragma mark Single [NSURLConnection sendAsynchronousRequest:queue:completionHandler:]
///////////////////////////////////////////////////////////////////////////////////

-(void)_test_NSURLConnection_sendAsyncronousRequest_onOperationQueue:(NSOperationQueue*)queue
{
    NSData* testData = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];

    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:testData
                                           statusCode:200
                                              headers:nil]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    XCTestExpectation* expectation = [self expectationWithDescription:@"Asynchronous request finished"];

    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.iana.org/domains/example/"]];
    NSDate* startDate = [NSDate date];

    [NSURLConnection sendAsynchronousRequest:req queue:queue completionHandler:^(NSURLResponse* resp, NSData* data, NSError* error)
     {
         XCTAssertEqualObjects(data, testData, @"Invalid data response");
         XCTAssertGreaterThan(-[startDate timeIntervalSinceNow], kRequestTime+kResponseTime, @"Invalid response time");

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];
}


-(void)test_NSURLConnection_sendAsyncronousRequest_mainQueue
{
    [self _test_NSURLConnection_sendAsyncronousRequest_onOperationQueue:NSOperationQueue.mainQueue];
}


-(void)test_NSURLConnection_sendAsyncronousRequest_parallelQueue
{
    [self _test_NSURLConnection_sendAsyncronousRequest_onOperationQueue:[NSOperationQueue new]];
}


///////////////////////////////////////////////////////////////////////////////////
#pragma mark Multiple Parallel [NSURLConnection sendAsynchronousRequest:queue:completionHandler:]
///////////////////////////////////////////////////////////////////////////////////

-(void)_test_NSURLConnection_sendMultipleAsyncronousRequestsOnOperationQueue:(NSOperationQueue*)queue
{
    __block BOOL testFinished = NO;
    NSData* (^dataForRequest)(NSURLRequest*) = ^(NSURLRequest* req) {
        return [[NSString stringWithFormat:@"<Response for URL %@>",req.URL.absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
    };

    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        NSData* retData = dataForRequest(request);
        NSTimeInterval responseTime = [request.URL.lastPathComponent doubleValue];
        return [[HTTPStubsResponse responseWithData:retData
                                           statusCode:200
                                              headers:nil]
                requestTime:responseTime*.1 responseTime:responseTime];
    }];

    // Reusable code to send a request that will respond in the given response time
    void (^sendAsyncRequest)(NSTimeInterval) = ^(NSTimeInterval responseTime)
    {
        NSString* desc = [NSString stringWithFormat:@"Asynchronous request with response time %.f finished", responseTime];
        XCTestExpectation* expectation = [self expectationWithDescription:desc];

        NSString* urlString = [NSString stringWithFormat:@"http://dummyrequest/concurrent/time/%f",responseTime];
        NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
//        [SenTestLog testLogWithFormat:@"== Sending request %@\n", req];
        NSDate* startDate = [NSDate date];
        [NSURLConnection sendAsynchronousRequest:req queue:queue completionHandler:^(NSURLResponse* resp, NSData* data, NSError* error)
         {
//             [SenTestLog testLogWithFormat:@"== Received response for request %@\n", req];
             XCTAssertEqualObjects(data, dataForRequest(req), @"Invalid data response");
             XCTAssertGreaterThan(-[startDate timeIntervalSinceNow], (responseTime*.1)+responseTime, @"Invalid response time");

             if (!testFinished) [expectation fulfill];
         }];
    };

    static NSTimeInterval time3 = 1.5, time2 = 1.0, time1 = 0.5;
    sendAsyncRequest(time3); // send this one first, should receive last
    sendAsyncRequest(time2); // send this one next, shoud receive 2nd
    sendAsyncRequest(time1); // send this one last, should receive first

    [self waitForExpectationsWithTimeout:MAX(time1,MAX(time2,time3))+kResponseTimeMaxDelay handler:nil];
    testFinished = YES;
}

-(void)test_NSURLConnection_sendMultipleAsyncronousRequests_mainQueue
{
    [self _test_NSURLConnection_sendMultipleAsyncronousRequestsOnOperationQueue:NSOperationQueue.mainQueue];
}

-(void)test_NSURLConnection_sendMultipleAsyncronousRequests_parallelQueue
{
    [self _test_NSURLConnection_sendMultipleAsyncronousRequestsOnOperationQueue:[NSOperationQueue new]];
}


@end

#endif
