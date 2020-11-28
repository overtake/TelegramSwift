// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockReachability.h"
#import "MSACTestFrameworks.h"

static NSString *const kMSACNetworkReachabilityChangedNotificationName = @"kMSNetworkReachabilityChangedNotification";

@implementation MSACMockReachability

static NetworkStatus _currentNetworkStatus;

+ (void)setCurrentNetworkStatus:(NetworkStatus)networkStatus {
  _currentNetworkStatus = networkStatus;
}

+ (NetworkStatus)currentNetworkStatus {
  return _currentNetworkStatus;
}

+ (id)startMocking {
  id mockReachability = OCMClassMock([MSAC_Reachability class]);
  OCMStub([mockReachability reachabilityForInternetConnection]).andReturn(mockReachability);
  OCMStub([mockReachability currentReachabilityStatus]).andDo(^(NSInvocation *invocation) {
    NetworkStatus status = self.currentNetworkStatus;
    [invocation setReturnValue:&status];
  });
  OCMStub([mockReachability startNotifier]).andDo(^(__unused NSInvocation *invocation) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kMSACNetworkReachabilityChangedNotificationName object:mockReachability];
  });
  return mockReachability;
}

@end
