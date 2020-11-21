/***********************************************************************************
 *
 * Copyright (c) 2015 Jinlian (Sunny) Wang
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


////////////////////////////////////////////////////////////////////////////////

#import <XCTest/XCTest.h>

#if OHHTTPSTUBS_USE_STATIC_LIBRARY || SWIFT_PACKAGE
#import "HTTPStubs.h"
#import "HTTPStubs+Mocktail.h"
#import "HTTPStubsResponse+JSON.h"
#else
@import OHHTTPStubs;
#endif

@interface MocktailTests : XCTestCase
@property(nonatomic, strong) NSURLSession *session;
@end

@implementation MocktailTests

- (void)setUp
{
    [super setUp];
    [HTTPStubs removeAllStubs];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

- (void)tearDown
{
    [super tearDown];
    [self.session invalidateAndCancel];
    self.session = nil;
}

- (void)testMocktailLoginSuccess
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    [HTTPStubs stubRequestsUsingMocktailNamed:@"login" inBundle:bundle error: &error];
    XCTAssertNil(error, @"Error while stubbing 'login.tail':%@", [error localizedDescription]);
    [self runLogin];
}

- (void)testMocktailsAtFolder
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    [HTTPStubs stubRequestsUsingMocktailsAtPath:@"MocktailFolder" inBundle:bundle error:&error];
    XCTAssertNil(error, @"Error while stubbing Mocktails at folder 'MocktailFolder': %@", [error localizedDescription]);
    [self runLogin];
    [self runGetCards];
}

- (void)testMocktailHeaders
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    [HTTPStubs stubRequestsUsingMocktailNamed:@"login_headers" inBundle:bundle error: &error];
    XCTAssertNil(error, @"Error while stubbing 'login_headers.tail':%@", [error localizedDescription]);
    NSHTTPURLResponse *response = [self runLogin];
    XCTAssertEqualObjects(response.allHeaderFields[@"Connection"], @"Close");
}

- (void)testMocktailContentType
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    [HTTPStubs stubRequestsUsingMocktailNamed:@"login_content_type" inBundle:bundle error: &error];
    XCTAssertNil(error, @"Error while stubbing 'login_content_type.tail':%@", [error localizedDescription]);
    [self runLogin];
}

- (void)testMocktailContentTypeAndHeaders
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    [HTTPStubs stubRequestsUsingMocktailNamed:@"login_content_type_and_headers" inBundle:bundle error: &error];
    XCTAssertNil(error, @"Error while stubbing 'login_content_type_and_headers.tail':%@", [error localizedDescription]);
    NSHTTPURLResponse *response = [self runLogin];
    XCTAssertEqualObjects(response.allHeaderFields[@"Connection"], @"Close");
}

- (NSHTTPURLResponse *)runLogin
{
    NSURL *url = [NSURL URLWithString:@"http://happywebservice.com/users"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];

    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    request.HTTPMethod = @"POST";
    NSDictionary *mapData = @{@"iloveit": @"happyuser1",
                             @"password": @"username"};
    NSData *postData = [NSJSONSerialization dataWithJSONObject:mapData options:0 error:NULL];
    request.HTTPBody = postData;

    XCTestExpectation* expectation = [self expectationWithDescription:@"NSURLSessionDataTask completed"];

    __block NSHTTPURLResponse *capturedResponse;
    NSURLSessionDataTask *postDataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) capturedResponse = (id)response;
        XCTAssertNil(error, @"Error while logging in.");
        NSDictionary *json = nil;
        if(!error && [@"application/json" isEqual:response.MIMEType])
        {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        }

        XCTAssertNotNil(json, @"The response is not a json object");
        XCTAssertEqualObjects(json[@"status"], @"SUCCESS", @"The response does to return a successful status");
        XCTAssertNotNil(json[@"user_token"], @"The response does not contain a user token");

        [expectation fulfill];
    }];

    [postDataTask resume];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    return capturedResponse;
}

- (NSHTTPURLResponse *)runGetCards
{
    NSURL *url = [NSURL URLWithString:@"http://happywebservice.com/cards"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];

    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    request.HTTPMethod = @"GET";

    XCTestExpectation* expectation = [self expectationWithDescription:@"NSURLSessionDataTask completed"];

    __block NSHTTPURLResponse *capturedResponse;
    NSURLSessionDataTask *getDataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) capturedResponse = (id)response;
        XCTAssertNil(error, @"Error while getting cards.");

        NSArray *json = nil;
        if(!error && [@"application/json" isEqual:response.MIMEType])
        {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        }

        XCTAssertNotNil(json, @"The response is not a json object");
        XCTAssertEqual(json.count, 2, @"The response does not contain 2 cards");
        XCTAssertEqualObjects([json firstObject][@"amount"], @"$25.28", @"The first card amount does not match");

        [expectation fulfill];
    }];

    [getDataTask resume];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    return capturedResponse;
}

@end
