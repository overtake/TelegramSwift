// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashAsyncSafeThread.h"
#import <pthread.h>

@implementation MSCrashAsyncSafeThread

- (NSString *)category {
  return @"Async-Safety";
}

- (NSString *)title {
  return @"Crash with _pthread_list_lock held";
}

- (NSString *)desc {
  return @""
          "Triggers a crash with libsystem_pthread's _pthread_list_lock held, "
          "causing non-async-safe crash reporters that use pthread APIs to deadlock.";
}

- (void)crash {
  pthread_getname_np(pthread_self(), ((char *) 0x1), 1);

  /* This is unreachable, but prevents clang from applying TCO to the above when
   * optimization is enabled. */
  NSLog(@"I'm here from the tail call prevention department.");
}

@end
