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


#import <XCTest/XCTest.h>

#if OHHTTPSTUBS_USE_STATIC_LIBRARY || SWIFT_PACKAGE
#import "HTTPStubs.h"
#else
@import OHHTTPStubs;
#endif

@interface WithContentsOfURLTests : XCTestCase @end

static const NSTimeInterval kResponseTimeMaxDelay = 2.5;

@implementation WithContentsOfURLTests

-(void)setUp
{
    [super setUp];
    [HTTPStubs removeAllStubs];
}

static const NSTimeInterval kRequestTime = 0.1;
static const NSTimeInterval kResponseTime = 0.5;

///////////////////////////////////////////////////////////////////////////////////
#pragma mark [NSString stringWithContentsOfURL:encoding:error:]
///////////////////////////////////////////////////////////////////////////////////

-(void)test_NSString_stringWithContentsOfURL_mainQueue
{
    NSString* testString = NSStringFromSelector(_cmd);

    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        return [[HTTPStubsResponse responseWithData:[testString dataUsingEncoding:NSUTF8StringEncoding]
                                           statusCode:200
                                              headers:nil]
                requestTime:kRequestTime responseTime:kResponseTime];
    }];

    NSDate* startDate = [NSDate date];

    NSString* string = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.iana.org/domains/example/"]
                                            encoding:NSUTF8StringEncoding
                                               error:NULL];

    XCTAssertEqualObjects(string, testString, @"Invalid returned string");
    XCTAssertGreaterThan(-[startDate timeIntervalSinceNow], kResponseTime+kRequestTime, @"Invalid response time");
}

-(void)test_NSString_stringWithContentsOfURL_parallelQueue
{
    XCTestExpectation* expectation = [self expectationWithDescription:@"Synchronous download finished"];
    [[NSOperationQueue new] addOperationWithBlock:^{
        [self test_NSString_stringWithContentsOfURL_mainQueue];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];
}

///////////////////////////////////////////////////////////////////////////////////
#pragma mark [NSData dataWithContentsOfURL:]
///////////////////////////////////////////////////////////////////////////////////

-(void)test_NSData_dataWithContentsOfURL_mainQueue
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

    NSDate* startDate = [NSDate date];

    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://www.iana.org/domains/example/"]];

    XCTAssertEqualObjects(data, testData, @"Invalid returned string");
    XCTAssertGreaterThan(-[startDate timeIntervalSinceNow], kRequestTime+kResponseTime, @"Invalid response time");
}

-(void)test_NSData_dataWithContentsOfURL_parallelQueue
{
    XCTestExpectation* expectation = [self expectationWithDescription:@"Synchronous download finished"];
    [[NSOperationQueue new] addOperationWithBlock:^{
        [self test_NSData_dataWithContentsOfURL_mainQueue];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kRequestTime+kResponseTime+kResponseTimeMaxDelay handler:nil];
}

@end
