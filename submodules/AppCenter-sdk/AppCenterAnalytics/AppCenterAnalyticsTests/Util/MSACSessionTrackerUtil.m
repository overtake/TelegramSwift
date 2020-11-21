// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#import "MSACSessionTrackerUtil.h"

@implementation MSACSessionTrackerUtil

+ (void)simulateDidEnterBackgroundNotification {
  [[NSNotificationCenter defaultCenter]
#if TARGET_OS_OSX
      postNotificationName:NSApplicationDidResignActiveNotification
#else
      postNotificationName:UIApplicationDidEnterBackgroundNotification
#endif
                    object:self];
}

+ (void)simulateWillEnterForegroundNotification {
  [[NSNotificationCenter defaultCenter]
#if TARGET_OS_OSX
      postNotificationName:NSApplicationWillBecomeActiveNotification
#else
      postNotificationName:UIApplicationWillEnterForegroundNotification
#endif
                    object:self];
}

@end
