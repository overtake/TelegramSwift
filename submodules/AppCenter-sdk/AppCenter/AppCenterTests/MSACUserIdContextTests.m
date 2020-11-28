// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockUserDefaults.h"
#import "MSACTestFrameworks.h"
#import "MSACUserIdContextDelegate.h"
#import "MSACUserIdContextPrivate.h"
#import "MSACUtility.h"

@interface MSACUserIdContextTests : XCTestCase

@property(nonatomic) MSACUserIdContext *sut;
@property(nonatomic) MSACMockUserDefaults *settingsMock;

@end

@implementation MSACUserIdContextTests

#pragma mark - Houskeeping

- (void)setUp {
  [super setUp];

  self.settingsMock = [MSACMockUserDefaults new];
  self.sut = [MSACUserIdContext sharedInstance];
}

- (void)tearDown {
  [MSACUserIdContext resetSharedInstance];
  [self.settingsMock stopMocking];
  [super tearDown];
}

#pragma mark - Tests

- (void)testSetUserId {

  // If
  NSString *expectedUserId = @"alice";

  // When
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];

  // Then
  NSData *data = [self.settingsMock objectForKey:@"UserIdHistory"];
  XCTAssertNotNil(data);
  NSMutableArray *savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqualObjects([savedData[0] userId], expectedUserId);
}

- (void)testClearUserIdHistory {

  // When
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId1"];
  [MSACUserIdContext resetSharedInstance];
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId2"];

  // Then
  NSData *data = [self.settingsMock objectForKey:@"UserIdHistory"];
  XCTAssertNotNil(data);
  NSMutableArray *savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];

  XCTAssertEqual([savedData count], 2);

  // When
  [[MSACUserIdContext sharedInstance] clearUserIdHistory];

  // Then
  data = [self.settingsMock objectForKey:@"UserIdHistory"];
  XCTAssertNotNil(data);

  // Should keep the current userId.
  savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqual([savedData count], 1);
}

- (void)testUserId {

  // If
  NSString *expectedUserId = @"UserId";

  // When
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];

  // Then
  XCTAssertEqualObjects(expectedUserId, [[MSACUserIdContext sharedInstance] userId]);
}

- (void)testUserIdAt {

  // If
  __block NSDate *date;
  id dateMock = OCMClassMock([NSDate class]);

  // When
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId1"];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:1000];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId2"];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:2000];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId3"];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:3000];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId4"];
  [dateMock stopMocking];

  [MSACUserIdContext resetSharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:4000];
    [invocation setReturnValue:&date];
  });
  [[MSACUserIdContext sharedInstance] setUserId:@"UserId5"];
  [dateMock stopMocking];

  // Then
  XCTAssertNil([[MSACUserIdContext sharedInstance] userIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:0]]);
  XCTAssertEqualObjects(@"UserId3", [[MSACUserIdContext sharedInstance] userIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:2500]]);
  XCTAssertEqualObjects(@"UserId5", [[MSACUserIdContext sharedInstance] userIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:5000]]);
}

- (void)testPrefixedUserIdFromUserId {

  // Then
  XCTAssertEqualObjects([MSACUserIdContext prefixedUserIdFromUserId:@"c:alice"], @"c:alice");
  XCTAssertEqualObjects([MSACUserIdContext prefixedUserIdFromUserId:@"alice"], @"c:alice");
  XCTAssertEqualObjects([MSACUserIdContext prefixedUserIdFromUserId:@":"], @":");
  XCTAssertNil([MSACUserIdContext prefixedUserIdFromUserId:nil]);
}

- (void)testDelegateCalledOnUserIdChanged {

  // If
  XCTAssertNil([self.sut currentUserIdInfo].userId);
  NSString *expectedUserId = @"Robert";
  id delegateMock = OCMProtocolMock(@protocol(MSACUserIdContextDelegate));
  [self.sut addDelegate:delegateMock];
  OCMExpect([delegateMock userIdContext:self.sut didUpdateUserId:expectedUserId]);

  // When
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];

  // Then
  XCTAssertEqual([self.sut userId], expectedUserId);
  OCMVerify([delegateMock userIdContext:self.sut didUpdateUserId:expectedUserId]);
}

- (void)testDelegateCalledOnUserIdChangedToNil {

  // If
  NSString *userId = @"Robert";
  [[MSACUserIdContext sharedInstance] setUserId:userId];
  id delegateMock = OCMProtocolMock(@protocol(MSACUserIdContextDelegate));
  [self.sut addDelegate:delegateMock];
  OCMExpect([delegateMock userIdContext:self.sut didUpdateUserId:nil]);

  // When
  [[MSACUserIdContext sharedInstance] setUserId:nil];

  // Then
  XCTAssertEqual([self.sut userId], nil);
  OCMVerify([delegateMock userIdContext:self.sut didUpdateUserId:nil]);
}

- (void)testDelegateNotCalledOnUserIdSame {

  // If
  NSString *expectedUserId = @"Patrick";
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];
  id delegateMock = OCMProtocolMock(@protocol(MSACUserIdContextDelegate));
  [self.sut addDelegate:delegateMock];
  OCMReject([delegateMock userIdContext:self.sut didUpdateUserId:expectedUserId]);

  // When
  [[MSACUserIdContext sharedInstance] setUserId:expectedUserId];

  // Then
  OCMVerifyAll(delegateMock);
}

- (void)testRemoveDelegate {

  // If
  id delegateMock = OCMProtocolMock(@protocol(MSACUserIdContextDelegate));
  [self.sut addDelegate:delegateMock];

  // When
  [self.sut removeDelegate:delegateMock];

  // Then
  XCTAssertEqual([[self.sut delegates] count], 0);
}

@end
