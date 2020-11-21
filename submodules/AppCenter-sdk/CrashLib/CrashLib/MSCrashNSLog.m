// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashNSLog.h"

@implementation MSCrashNSLog

- (NSString *)category {
  return @"Objective-C";
}

- (NSString *)title {
  return @"Access a non-object as an object";
}

- (NSString *)desc {
  return @"Call NSLog(@\"%@\", 16);, causing a crash when the runtime attempts to treat 16 as a pointer to an object.";
}

- (void)crash {
#if __i386__ && !TARGET_IPHONE_SIMULATOR
#define __bridge
#endif

  NSLog(@"%@", (__bridge id) (void *) 16);
}

@end
