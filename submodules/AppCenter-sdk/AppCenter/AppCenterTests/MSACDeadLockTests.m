// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAbstractLog.h"
#import "MSACAppCenter.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppCenterPrivate.h"
#import "MSACChannelDelegate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACChannelUnitProtocol.h"
#import "MSACMockService.h"
#import "MSACTestFrameworks.h"

@interface MSACDeadLockTests : XCTestCase
@end

@interface MSACDummyService1 : MSACMockService <MSACChannelDelegate>
@end

@interface MSACDummyService2 : MSACMockService
@end

static MSACDummyService1 *sharedInstanceService1 = nil;
static MSACDummyService2 *sharedInstanceService2 = nil;

@implementation MSACDummyService1

+ (instancetype)sharedInstance {
  if (sharedInstanceService1 == nil) {
    sharedInstanceService1 = [[self alloc] init];
  }
  return sharedInstanceService1;
}

- (MSACInitializationPriority)initializationPriority {
  return MSACInitializationPriorityMax;
}

- (NSString *)serviceName {
  return @"service1";
}

- (NSString *)groupId {
  return @"service1";
}

- (void)channel:(__unused id<MSACChannelProtocol>)channel
    didPrepareLog:(__unused id<MSACLog>)log
       internalId:(__unused NSString *)internalId
            flags:(__unused MSACFlags)flags {

  // Operation locking AC while in ChannelDelegate.
  NSUUID *__unused deviceId = [MSACAppCenter installId];
}

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup
                    appSecret:(nullable NSString *)appSecret
      transmissionTargetToken:(nullable NSString *)token
              fromApplication:(BOOL)fromApplication {
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:token fromApplication:fromApplication];
  id mockLog = OCMPartialMock([MSACAbstractLog new]);
  OCMStub([mockLog isValid]).andReturn(YES);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // Log enqueued from background thread (i.e. crash logs).
    [self.channelUnit enqueueItem:mockLog flags:MSACFlagsDefault];
  });
}

@end

@implementation MSACDummyService2

+ (instancetype)sharedInstance {
  if (sharedInstanceService2 == nil) {
    sharedInstanceService2 = [[self alloc] init];
  }
  return sharedInstanceService2;
}

- (NSString *)serviceName {
  return @"service2";
}

- (NSString *)groupId {
  return @"service2";
}

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup
                    appSecret:(nullable NSString *)appSecret
      transmissionTargetToken:(nullable NSString *)token
              fromApplication:(BOOL)fromApplication {
  [NSThread sleepForTimeInterval:.1];
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:token fromApplication:fromApplication];
}

@end

@implementation MSACDeadLockTests

- (void)setUp {
  [super setUp];
  [MSACAppCenter resetSharedInstance];
}

- (void)testDeadLockAtStartup {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Not blocked."];

  // When
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // Start the SDK with interlocking sensible services.
    [MSACAppCenter start:@"AppSecret" withServices:@ [[MSACDummyService1 class], [MSACDummyService2 class]]];
    [expectation fulfill];
  });

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Wait background queue.
  __block MSACChannelGroupDefault *channelGroup = [MSACAppCenter sharedInstance].channelGroup;
  dispatch_sync(channelGroup.logsDispatchQueue, ^{
    dispatch_suspend(channelGroup.logsDispatchQueue);
  });
}

@end
