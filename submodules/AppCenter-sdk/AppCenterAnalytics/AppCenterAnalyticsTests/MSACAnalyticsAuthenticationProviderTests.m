// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalyticsAuthenticationProviderInternal.h"
#import "MSACTestFrameworks.h"
#import "MSACTicketCache.h"
#import "MSACUtility+StringFormatting.h"

@interface MSACAnalyticsAuthenticationProviderTests : XCTestCase

@property(nonatomic) MSACAnalyticsAuthenticationProvider *sut;

@property(nonatomic) NSDate *today;

@property(nonatomic) NSString *ticketKey;

@property(nonatomic) NSString *token;

@end

@implementation MSACAnalyticsAuthenticationProviderTests

- (void)setUp {
  [super setUp];

  self.today = [NSDate date];
  self.ticketKey = @"ticketKey1";
  self.token = @"authenticationToken";
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  OCMStub([mockDelegate authenticationProvider:OCMOCK_ANY
             acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, self.today, nil])]);
  self.sut = [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaDelegate
                                                                           ticketKey:self.ticketKey
                                                                            delegate:mockDelegate];
  self.sut = [self createAuthenticationProviderWithTicketKey:self.ticketKey delegate:mockDelegate];
}

- (void)tearDown {
  [super tearDown];

  self.sut = nil;
  [[MSACTicketCache sharedInstance] clearCache];
}

- (MSACAnalyticsAuthenticationProvider *)createAuthenticationProviderWithTicketKey:(NSString *)ticketKey
                                                                          delegate:
                                                                              (id<MSACAnalyticsAuthenticationProviderDelegate>)delegate {

  return [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaCompact
                                                                       ticketKey:ticketKey
                                                                        delegate:delegate];
}

- (void)testInitialization {

  // Then
  XCTAssertNotNil(self.sut);
  XCTAssertEqual(self.sut.type, MSACAnalyticsAuthenticationTypeMsaCompact);
  XCTAssertNotNil(self.sut.ticketKey);
  XCTAssertNotNil(self.sut.ticketKeyHash);
  XCTAssertTrue([self.sut.ticketKeyHash isEqualToString:[MSACUtility sha256:@"ticketKey1"]]);
  XCTAssertNotNil(self.sut.delegate);
}

- (void)testExpiryDateIsValid {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  NSTimeInterval plusDay = (24 * 60 * 60);
  OCMStub([mockDelegate
                 authenticationProvider:OCMOCK_ANY
      acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, [self.today dateByAddingTimeInterval:plusDay], nil])]);
  self.sut = [self createAuthenticationProviderWithTicketKey:self.ticketKey delegate:mockDelegate];
  id sutMock = OCMPartialMock(self.sut);

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expiry date is valid"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 OCMReject([sutMock acquireTokenAsync]);
                                 [self.sut checkTokenExpiry];
                                 OCMVerifyAll(sutMock);
                               }];
}

- (void)testExpiryDateIsExpired {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  NSTimeInterval minusDay = -(24 * 60 * 60);
  OCMStub([mockDelegate
                 authenticationProvider:OCMOCK_ANY
      acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, [self.today dateByAddingTimeInterval:minusDay], nil])]);
  self.sut = [self createAuthenticationProviderWithTicketKey:self.ticketKey delegate:mockDelegate];
  id sutMock = OCMPartialMock(self.sut);

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expiry date is expired"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 [self.sut checkTokenExpiry];
                                 OCMVerify([sutMock acquireTokenAsync]);
                               }];
}

- (void)testCompletionHandlerIsCalled {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  OCMStub([mockDelegate authenticationProvider:OCMOCK_ANY
             acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, self.today, nil])]);
  self.sut = [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaCompact
                                                                           ticketKey:self.ticketKey
                                                                            delegate:mockDelegate];

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler is called"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertTrue([self.sut.expiryDate isEqualToDate:self.today]);
                                 NSString *savedToken = [[MSACTicketCache sharedInstance] ticketFor:self.sut.ticketKeyHash];
                                 NSString *tokenWithPrefixString = [NSString stringWithFormat:@"p:%@", self.token];
                                 XCTAssertTrue([savedToken isEqualToString:tokenWithPrefixString]);
                               }];
}

- (void)testCompletionHandlerIsCalledForMSADelegateType {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  OCMStub([mockDelegate authenticationProvider:OCMOCK_ANY
             acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, self.today, nil])]);
  self.sut = [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaDelegate
                                                                           ticketKey:self.ticketKey
                                                                            delegate:mockDelegate];

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler is called"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertTrue([self.sut.expiryDate isEqualToDate:self.today]);
                                 NSString *savedToken = [[MSACTicketCache sharedInstance] ticketFor:self.sut.ticketKeyHash];
                                 NSString *tokenWithPrefixString = [NSString stringWithFormat:@"d:%@", self.token];
                                 XCTAssertTrue([savedToken isEqualToString:tokenWithPrefixString]);
                               }];
}

- (void)testDelegateReturnsNullToken {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  OCMStub([mockDelegate authenticationProvider:OCMOCK_ANY
             acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:[NSNull null], self.today, nil])]);
  self.sut = [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaDelegate
                                                                           ticketKey:self.ticketKey
                                                                            delegate:mockDelegate];

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler is called"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertNil(self.sut.expiryDate);
                                 NSString *savedToken = [[MSACTicketCache sharedInstance] ticketFor:self.sut.ticketKeyHash];
                                 XCTAssertNil(savedToken);
                               }];
}

- (void)testDelegateReturnsNullExpiryDate {

  // If
  id mockDelegate = OCMProtocolMock(@protocol(MSACAnalyticsAuthenticationProviderDelegate));
  OCMStub([mockDelegate authenticationProvider:OCMOCK_ANY
             acquireTokenWithCompletionHandler:([OCMArg invokeBlockWithArgs:self.token, [NSNull null], nil])]);
  self.sut = [[MSACAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSACAnalyticsAuthenticationTypeMsaDelegate
                                                                           ticketKey:self.ticketKey
                                                                            delegate:mockDelegate];

  // When
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler is called"];
  [self.sut acquireTokenAsync];
  dispatch_async(dispatch_get_main_queue(), ^{
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }

                                 // Then
                                 XCTAssertNil(self.sut.expiryDate);
                                 NSString *savedToken = [[MSACTicketCache sharedInstance] ticketFor:self.sut.ticketKeyHash];
                                 XCTAssertNil(savedToken);
                               }];
}

@end
