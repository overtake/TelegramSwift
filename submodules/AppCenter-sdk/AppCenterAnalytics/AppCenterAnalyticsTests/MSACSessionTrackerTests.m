// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalytics.h"
#import "MSACLogWithProperties.h"
#import "MSACSessionContextPrivate.h"
#import "MSACSessionTrackerPrivate.h"
#import "MSACSessionTrackerUtil.h"
#import "MSACStartServiceLog.h"
#import "MSACStartSessionLog.h"
#import "MSACTestFrameworks.h"

static NSTimeInterval const kMSACTestSessionTimeout = 1.5;

@interface MSACSessionTrackerTests : XCTestCase

@property(nonatomic) MSACSessionTracker *sut;
@property(nonatomic) id context;

@end

@implementation MSACSessionTrackerTests

- (void)setUp {
  [super setUp];

  self.sut = [[MSACSessionTracker alloc] init];
  [self.sut setSessionTimeout:kMSACTestSessionTimeout];
  [self.sut start];
}

- (void)tearDown {
  [super tearDown];
  [MSACSessionContext resetSharedInstance];

  // This is required to remove observers in dealloc.
  self.sut = nil;
}

- (void)testSession {

  // When
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(expectedSid);

  // When
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertEqual(expectedSid, sid);
}

// Apps is in foreground for longer than the timeout time, still same session
- (void)testLongForegroundSession {

  // If
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(expectedSid);

  // When

  // Mock a log creation
  self.sut.lastCreatedLogTime = [NSDate date];

  // Wait for longer than timeout in foreground
  [NSThread sleepForTimeInterval:kMSACTestSessionTimeout + 1];

  // Get a session
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertEqual(expectedSid, sid);
}

- (void)testShortBackgroundSession {

  // If
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(expectedSid);

  // When

  // Mock a log creation
  self.sut.lastCreatedLogTime = [NSDate date];

  // Enter background
  [MSACSessionTrackerUtil simulateDidEnterBackgroundNotification];

  // Wait for shorter than the timeout time in background
  [NSThread sleepForTimeInterval:kMSACTestSessionTimeout - 1];

  // Enter foreground
  [MSACSessionTrackerUtil simulateWillEnterForegroundNotification];

  // Get a session
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertEqual(expectedSid, sid);
}

- (void)testLongBackgroundSession {

  // If
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(expectedSid);

  // When

  // Mock a log creation
  self.sut.lastCreatedLogTime = [NSDate date];

  // Enter background
  [MSACSessionTrackerUtil simulateDidEnterBackgroundNotification];

  // Wait for longer than the timeout time in background
  [NSThread sleepForTimeInterval:kMSACTestSessionTimeout + 1];

  // Enter foreground
  [MSACSessionTrackerUtil simulateWillEnterForegroundNotification];

  // Get a session
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertNotEqual(expectedSid, sid);
}

- (void)testLongBackgroundSessionWithSessionTrackingStopped {

  // If
  [self.sut stop];

  // When

  // Mock a log creation
  self.sut.lastCreatedLogTime = [NSDate date];

  // Get a session
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNil(expectedSid);

  // When

  // Enter background
  [MSACSessionTrackerUtil simulateDidEnterBackgroundNotification];

  // Wait for longer than the timeout time in background
  [NSThread sleepForTimeInterval:kMSACTestSessionTimeout + 1];

  [[NSNotificationCenter defaultCenter]
#if TARGET_OS_OSX
      postNotificationName:NSApplicationWillBecomeActiveNotification
#else
      postNotificationName:UIApplicationWillEnterForegroundNotification
#endif
                    object:self];

  // Get a session
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertNil(sid);
}

- (void)testTooLongInBackground {

  // If
  [self.sut renewSessionId];
  NSString *expectedSid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(expectedSid);

  // When
  [MSACSessionTrackerUtil simulateWillEnterForegroundNotification];
  [NSThread sleepForTimeInterval:1];

  // Enter background
  [MSACSessionTrackerUtil simulateDidEnterBackgroundNotification];

  // Mock a log creation while app is in background
  self.sut.lastCreatedLogTime = [NSDate date];

  // Wait for longer than timeout in background
  [NSThread sleepForTimeInterval:kMSACTestSessionTimeout + 1];

  // Get a session
  [self.sut renewSessionId];
  NSString *sid = [self.sut.context sessionId];

  // Then
  XCTAssertNotNil(sid);
  XCTAssertNotEqual(expectedSid, sid);
}

- (void)testStartSessionOnStart {

  // Clean up session context and stop session tracker which is initialized in setUp.
  [MSACSessionContext resetSharedInstance];
  [self.sut stop];

  // If
  id analyticsMock = OCMClassMock([MSACAnalytics class]);
  OCMStub([analyticsMock isAvailable]).andReturn(YES);
  OCMStub([analyticsMock sharedInstance]).andReturn(analyticsMock);
  [self.sut setSessionTimeout:kMSACTestSessionTimeout];
  id<MSACSessionTrackerDelegate> delegateMock = OCMProtocolMock(@protocol(MSACSessionTrackerDelegate));
  self.sut.delegate = delegateMock;

  // When
  [self.sut start];

  // Then
  OCMVerify([delegateMock sessionTracker:self.sut processLog:[OCMArg isKindOfClass:[MSACStartSessionLog class]]]);
}

- (void)testStartSessionOnAppForegrounded {

  // If
  id analyticsMock = OCMClassMock([MSACAnalytics class]);
  OCMStub([analyticsMock isAvailable]).andReturn(YES);
  OCMStub([analyticsMock sharedInstance]).andReturn(analyticsMock);
  MSACSessionTracker *sut = [[MSACSessionTracker alloc] init];
  [sut setSessionTimeout:0];
  id<MSACSessionTrackerDelegate> delegateMock = OCMProtocolMock(@protocol(MSACSessionTrackerDelegate));
  [sut start];

  // When
  [MSACSessionTrackerUtil simulateDidEnterBackgroundNotification];
  [NSThread sleepForTimeInterval:0.1];
  sut.delegate = delegateMock;
  [MSACSessionTrackerUtil simulateWillEnterForegroundNotification];

  // Then
  OCMVerify([delegateMock sessionTracker:sut processLog:[OCMArg isKindOfClass:[MSACStartSessionLog class]]]);
}

- (void)testDidEnqueueLog {

  // When
  MSACLogWithProperties *log = [MSACLogWithProperties new];

  // Then
  XCTAssertNil(log.sid);
  XCTAssertNil(log.timestamp);

  // When
  [self.sut channel:nil prepareLog:log];

  // Then
  XCTAssertNil(log.timestamp);
  XCTAssertEqual(log.sid, [self.sut.context sessionId]);
}

- (void)testNoStartSessionWithStartSessionLog {

  // When
  MSACLogWithProperties *log = [MSACLogWithProperties new];

  // Then
  XCTAssertNil(log.sid);
  XCTAssertNil(log.timestamp);

  // When
  [self.sut channel:nil prepareLog:log];

  // Then
  XCTAssertNil(log.timestamp);
  XCTAssertEqual(log.sid, [self.sut.context sessionId]);

  // If
  MSACStartSessionLog *sessionLog = [MSACStartSessionLog new];

  // Then
  XCTAssertNil(sessionLog.sid);
  XCTAssertNil(sessionLog.timestamp);

  // When
  [self.sut channel:nil prepareLog:sessionLog];

  // Then
  XCTAssertNil(sessionLog.timestamp);
  XCTAssertNil(sessionLog.sid);

  // If
  MSACStartServiceLog *serviceLog = [MSACStartServiceLog new];

  // Then
  XCTAssertNil(serviceLog.sid);
  XCTAssertNil(serviceLog.timestamp);

  // When
  [self.sut channel:nil prepareLog:serviceLog];

  // Then
  XCTAssertNil(serviceLog.timestamp);
  XCTAssertNil(serviceLog.sid);
}

@end
