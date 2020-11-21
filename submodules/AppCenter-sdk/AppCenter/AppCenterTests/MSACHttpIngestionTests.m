// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACDevice.h"
#import "MSACHttpClient.h"
#import "MSACHttpIngestionPrivate.h"
#import "MSACTestFrameworks.h"

@interface MSACHttpIngestionTests : XCTestCase

@property(nonatomic) MSACHttpIngestion *sut;
@property(nonatomic) MSACHttpClient *httpClientMock;

@end

@implementation MSACHttpIngestionTests

- (void)setUp {
  [super setUp];
  NSDictionary *queryStrings = @{@"api-version" : @"1.0.0"};
  self.httpClientMock = OCMPartialMock([MSACHttpClient new]);

  // sut: System under test
  self.sut = [[MSACHttpIngestion alloc] initWithHttpClient:self.httpClientMock
                                                   baseUrl:@"https://www.contoso.com"
                                                   apiPath:@"/test-path"
                                                   headers:nil
                                              queryStrings:queryStrings
                                            retryIntervals:@[ @(0.5), @(1), @(1.5) ]];
}

- (void)tearDown {
  [super tearDown];
  self.sut = nil;
}

- (void)testValidETagFromResponse {

  // If
  NSString *expectedETag = @"IAmAnETag";
  NSHTTPURLResponse *response = [NSHTTPURLResponse new];
  id responseMock = OCMPartialMock(response);
  OCMStub([responseMock allHeaderFields]).andReturn(@{@"Etag" : expectedETag});

  // When
  NSString *eTag = [MSACHttpIngestion eTagFromResponse:responseMock];

  // Then
  XCTAssertEqualObjects(expectedETag, eTag);
}

- (void)testInvalidETagFromResponse {

  // If
  NSHTTPURLResponse *response = [NSHTTPURLResponse new];
  id responseMock = OCMPartialMock(response);
  OCMStub([responseMock allHeaderFields]).andReturn(@{@"Etag1" : @"IAmAnETag"});

  // When
  NSString *eTag = [MSACHttpIngestion eTagFromResponse:responseMock];

  // Then
  XCTAssertNil(eTag);
}

- (void)testNoETagFromResponse {

  // If
  NSHTTPURLResponse *response = [NSHTTPURLResponse new];

  // When
  NSString *eTag = [MSACHttpIngestion eTagFromResponse:response];

  // Then
  XCTAssertNil(eTag);
}

@end
