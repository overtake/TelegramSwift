// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACMockUserDefaults.h"
#import "MSACSessionContextPrivate.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"

@interface MSACSessionContextTests : XCTestCase

@property(nonatomic) MSACSessionContext *sut;
@property(nonatomic) MSACMockUserDefaults *settingsMock;

@end

@implementation MSACSessionContextTests

#pragma mark - Houskeeping

- (void)setUp {
  [super setUp];
  [MSACSessionContext resetSharedInstance];

  self.settingsMock = [MSACMockUserDefaults new];
  self.sut = [MSACSessionContext sharedInstance];
}

- (void)tearDown {
  [MSACSessionContext resetSharedInstance];
  [self.settingsMock stopMocking];
  [super tearDown];
}

#pragma mark - Tests

- (void)testSetSessionId {

  // If
  NSString *expectedSessionId = @"Session";

  // When
  [self.sut setSessionId:expectedSessionId];

  // Then
  NSData *data = [self.settingsMock objectForKey:@"SessionIdHistory"];
  XCTAssertNotNil(data);
  NSMutableArray *savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqualObjects([savedData[0] sessionId], expectedSessionId);
}

- (void)testClearSessionHistory {

  // When
  [self.sut setSessionId:@"Session1"];
  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];
  [self.sut setSessionId:@"Session2"];

  // Then
  NSData *data = [self.settingsMock objectForKey:@"SessionIdHistory"];
  XCTAssertNotNil(data);
  NSMutableArray *savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqual([savedData count], 2);

  // When
  [self.sut clearSessionHistoryAndKeepCurrentSession:NO];

  // Then
  data = [self.settingsMock objectForKey:@"SessionIdHistory"];
  XCTAssertNotNil(data);

  // Should keep the current session.
  savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqual([savedData count], 0);
}

- (void)testClearSessionHistoryExceptCurrentOne {

  // When
  [self.sut setSessionId:@"Session1"];
  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];
  [self.sut setSessionId:@"Session2"];

  // Then
  NSData *data = [self.settingsMock objectForKey:@"SessionIdHistory"];
  XCTAssertNotNil(data);
  NSMutableArray *savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqual([savedData count], 2);

  // When
  [self.sut clearSessionHistoryAndKeepCurrentSession:YES];

  // Then
  data = [self.settingsMock objectForKey:@"SessionIdHistory"];
  XCTAssertNotNil(data);

  // Should keep the current session.
  savedData = (NSMutableArray *)[[MSACUtility unarchiveKeyedData:data] mutableCopy];
  XCTAssertEqual([savedData count], 1);
}

- (void)testSessionId {

  // If
  NSString *expectedSessionId = @"Session";

  // When
  [self.sut setSessionId:expectedSessionId];

  // Then
  XCTAssertEqualObjects(expectedSessionId, [self.sut sessionId]);
}

- (void)testSessionIdAt {

  // If
  __block NSDate *date;
  id dateMock = OCMClassMock([NSDate class]);

  // When
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    [invocation setReturnValue:&date];
  });
  [self.sut setSessionId:@"Session1"];
  [dateMock stopMocking];

  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:1000];
    [invocation setReturnValue:&date];
  });
  [self.sut setSessionId:@"Session2"];
  [dateMock stopMocking];

  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:2000];
    [invocation setReturnValue:&date];
  });
  [self.sut setSessionId:@"Session3"];
  [dateMock stopMocking];

  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:3000];
    [invocation setReturnValue:&date];
  });
  [self.sut setSessionId:@"Session4"];
  [dateMock stopMocking];

  [MSACSessionContext resetSharedInstance];
  self.sut = [MSACSessionContext sharedInstance];

  dateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([dateMock date])).andDo(^(NSInvocation *invocation) {
    date = [[NSDate alloc] initWithTimeIntervalSince1970:4000];
    [invocation setReturnValue:&date];
  });
  [self.sut setSessionId:@"Session5"];
  [dateMock stopMocking];

  // Then
  XCTAssertNil([self.sut sessionIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:0]]);
  XCTAssertEqualObjects(@"Session3", [self.sut sessionIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:2500]]);
  XCTAssertEqualObjects(@"Session5", [self.sut sessionIdAt:[[NSDate alloc] initWithTimeIntervalSince1970:5000]]);
}

@end
