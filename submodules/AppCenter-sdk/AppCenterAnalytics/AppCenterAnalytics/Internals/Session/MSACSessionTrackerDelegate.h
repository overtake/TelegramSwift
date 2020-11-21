// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "AppCenter+Internal.h"

@protocol MSACSessionTrackerDelegate <NSObject>

@required

- (void)sessionTracker:(id)sessionTracker processLog:(id<MSACLog>)log;

@end
