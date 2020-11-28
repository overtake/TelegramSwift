// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACTestFrameworks.h"
#import "MSACTicketCache.h"

@interface MSACTicketCacheTests : XCTestCase

@property(nonatomic) MSACTicketCache *sut;

@end

@implementation MSACTicketCacheTests

- (void)setUp {
  [super setUp];

  self.sut = [MSACTicketCache sharedInstance];
}

- (void)tearDown {
  [super tearDown];

  [self.sut clearCache];
}

- (void)testInitialization {

  // When

  // Then
  XCTAssertNotNil(self.sut);
  XCTAssertEqual([MSACTicketCache sharedInstance], [MSACTicketCache sharedInstance]);
  XCTAssertNotNil(self.sut.tickets);
  XCTAssertTrue(self.sut.tickets.count == 0);
}

- (void)testAddingTickets {

  // When
  [self.sut setTicket:@"ticket1" forKey:@"ticketKey1"];

  // Then
  XCTAssertTrue(self.sut.tickets.count == 1);

  // When
  [self.sut setTicket:@"ticket2" forKey:@"ticketKey2"];

  // Then
  XCTAssertTrue(self.sut.tickets.count == 2);
  XCTAssertTrue([[self.sut ticketFor:@"ticketKey1"] isEqualToString:@"ticket1"]);
  XCTAssertTrue([[self.sut ticketFor:@"ticketKey2"] isEqualToString:@"ticket2"]);
  XCTAssertNil([self.sut ticketFor:@"foo"]);
}

- (void)testClearingTickets {

  // If
  [self.sut setTicket:@"ticket1" forKey:@"ticketKey1"];
  [self.sut setTicket:@"ticket2" forKey:@"ticketKey2"];
  [self.sut setTicket:@"ticket3" forKey:@"ticketKey3"];

  // When
  [self.sut clearCache];

  // Then
  XCTAssertTrue(self.sut.tickets.count == 0);
}

@end
