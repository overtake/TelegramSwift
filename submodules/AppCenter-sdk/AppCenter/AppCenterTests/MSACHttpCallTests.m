// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "AppCenter+Internal.h"
#import "HTTPStubs.h"
#import "MSACAppCenterErrors.h"
#import "MSACCompression.h"
#import "MSACConstants+Internal.h"
#import "MSACDevice.h"
#import "MSACDeviceInternal.h"
#import "MSACHttpCall.h"
#import "MSACHttpIngestionPrivate.h"
#import "MSACHttpTestUtil.h"
#import "MSACMockLog.h"
#import "MSACTestFrameworks.h"
#import "NSURLRequest+HTTPBodyTesting.h"
@interface MSACHttpCallTests : XCTestCase
@end

@implementation MSACHttpCallTests

- (void)testCompressHTTPBodyWhenLarge {

  // If

  // HTTP body is big enough to be compressed.
  NSString *longString = [@"" stringByPaddingToLength:kMSACHTTPMinGZipLength withString:@"h" startingAtIndex:0];
  NSData *longData = [longString dataUsingEncoding:NSUTF8StringEncoding];
  NSData *expectedData = [MSACCompression compressData:longData];
  NSDictionary *expectedHeaders =
      @{kMSACHeaderContentEncodingKey : kMSACHeaderContentEncoding, kMSACHeaderContentTypeKey : kMSACAppCenterContentType};

  // When
  MSACHttpCall *call =
      [[MSACHttpCall alloc] initWithUrl:[NSURL new]
                                 method:@"POST"
                                headers:nil
                                   data:longData
                         retryIntervals:@[]
                     compressionEnabled:YES
                      completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error){
                      }];

  // Then
  XCTAssertEqualObjects(call.data, expectedData);
  XCTAssertEqualObjects(call.headers, expectedHeaders);
}

- (void)testDoesNotCompressHTTPBodyWhenSmall {

  // If

  // HTTP body is small and will not be compressed.
  NSData *shortData = [NSData dataWithBytes:"hi" length:2];
  NSDictionary *expectedHeaders = @{kMSACHeaderContentTypeKey : kMSACAppCenterContentType};

  // When
  MSACHttpCall *call =
      [[MSACHttpCall alloc] initWithUrl:[NSURL new]
                                 method:@"POST"
                                headers:nil
                                   data:shortData
                         retryIntervals:@[]
                     compressionEnabled:YES
                      completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error){
                      }];

  // Then
  XCTAssertEqualObjects(call.data, shortData);
  XCTAssertEqualObjects(call.headers, expectedHeaders);
}

- (void)testDoesNotCompressHTTPBodyWhenDisabled {

  // If

  // HTTP body is big enough to be compressed.
  NSString *longString = [@"" stringByPaddingToLength:kMSACHTTPMinGZipLength withString:@"h" startingAtIndex:0];
  NSData *longData = [longString dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *expectedHeaders = @{kMSACHeaderContentTypeKey : kMSACAppCenterContentType};

  // When
  MSACHttpCall *call =
      [[MSACHttpCall alloc] initWithUrl:[NSURL new]
                                 method:@"POST"
                                headers:nil
                                   data:longData
                         retryIntervals:@[]
                     compressionEnabled:NO
                      completionHandler:^(__unused NSData *responseBody, __unused NSHTTPURLResponse *response, __unused NSError *error){
                      }];

  // Then
  XCTAssertEqualObjects(call.data, longData);
  XCTAssertEqualObjects(call.headers, expectedHeaders);
}

@end
