// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@interface MSACSessionTrackerUtil : NSObject

+ (void)simulateDidEnterBackgroundNotification;

+ (void)simulateWillEnterForegroundNotification;

@end
