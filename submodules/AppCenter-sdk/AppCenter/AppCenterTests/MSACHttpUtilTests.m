// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACHttpUtil.h"
#import "MSACTestFrameworks.h"

@interface MSACHttpUtilTests : XCTestCase

@end

@implementation MSACHttpUtilTests

- (void)testLargeSecret {

  // If
  NSString *secret = @"shhhh-its-a-secret";
  NSString *hiddenSecret;

  // When
  hiddenSecret = [MSACHttpUtil hideSecret:secret];

  // Then
  NSString *fullyHiddenSecret = [@"" stringByPaddingToLength:hiddenSecret.length
                                                  withString:kMSACHidingStringForAppSecret
                                             startingAtIndex:0];
  NSString *appSecretHiddenPart = [hiddenSecret commonPrefixWithString:fullyHiddenSecret options:0];
  NSString *appSecretVisiblePart = [hiddenSecret substringFromIndex:appSecretHiddenPart.length];
  assertThatInteger(secret.length - appSecretHiddenPart.length, equalToShort(kMSACMaxCharactersDisplayedForAppSecret));
  assertThat(appSecretVisiblePart, is([secret substringFromIndex:appSecretHiddenPart.length]));
}

- (void)testShortSecret {

  // If
  NSString *secret = @"";
  for (short i = 1; i <= kMSACMaxCharactersDisplayedForAppSecret - 1; i++)
    secret = [NSString stringWithFormat:@"%@%hd", secret, i];
  NSString *hiddenSecret;

  // When
  hiddenSecret = [MSACHttpUtil hideSecret:secret];

  // Then
  NSString *fullyHiddenSecret = [@"" stringByPaddingToLength:hiddenSecret.length
                                                  withString:kMSACHidingStringForAppSecret
                                             startingAtIndex:0];
  assertThatInteger(hiddenSecret.length, equalToUnsignedInteger(secret.length));
  assertThat(hiddenSecret, is(fullyHiddenSecret));
}

- (void)testIsNoInternetConnectionError {

  // When
  NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isNoInternetConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isNoInternetConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateHasBadDate userInfo:nil];

  // Then
  XCTAssertFalse([MSACHttpUtil isNoInternetConnectionError:error]);
}

- (void)testSSLConnectionErrorDetected {

  // When
  NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorSecureConnectionFailed userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateHasBadDate userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateUntrusted userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateHasUnknownRoot userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateNotYetValid userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorClientCertificateRejected userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorClientCertificateRequired userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotLoadFromNetwork userInfo:nil];

  // Then
  XCTAssertTrue([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorFailingURLErrorKey code:NSURLErrorCannotLoadFromNetwork userInfo:nil];

  // Then
  XCTAssertFalse([MSACHttpUtil isSSLConnectionError:error]);

  // When
  error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:10 userInfo:nil];

  // Then
  XCTAssertFalse([MSACHttpUtil isSSLConnectionError:error]);
}

- (void)testHideSecretInString {

  // If
  NSString *secret = @"12345678-1234-1234-1234-123456789012";
  NSString *string = [NSString stringWithFormat:@"this-%@-should-be-encoded", secret];
  NSString *expectedEncodeString = [NSString stringWithFormat:@"this-%@56789012-should-be-encoded", [@"" stringByPaddingToLength:28
                                                                                                                      withString:@"*"
                                                                                                                 startingAtIndex:0]];

  // When
  NSString *encodeString = [MSACHttpUtil hideSecretInString:string secret:secret];

  // Then
  XCTAssertEqualObjects(encodeString, expectedEncodeString);
}

- (void)testIsRecoverableError {
  for (int i = 0; i < 530; i++) {

    // When
    BOOL result = [MSACHttpUtil isRecoverableError:i];

    // Then
    if (i >= 500) {
      XCTAssertTrue(result);
    } else if (i == 408) {
      XCTAssertTrue(result);
    } else if (i == 429) {
      XCTAssertTrue(result);
    } else if (i == 0) {
      XCTAssertTrue(result);
    } else {
      XCTAssertFalse(result);
    }
  }
}

@end
