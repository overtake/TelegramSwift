// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSAC_Reachability.h"

@interface MSACMockReachability : NSObject

/**
 * A property indicating the current status of the network.
 */
@property(class) NetworkStatus currentNetworkStatus;

/**
 * Start to mock the MSAC_Reachability.
 */
+ (id)startMocking;

@end
