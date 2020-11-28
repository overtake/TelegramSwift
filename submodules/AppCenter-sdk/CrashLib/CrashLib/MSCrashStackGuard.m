// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashStackGuard.h"

@implementation MSCrashStackGuard

- (NSString *)category {
  return @"SIGSEGV";
}

- (NSString *)title {
  return @"Stack overflow";
}

- (NSString *)desc {
  return @""
          "Execute an infinitely recursive method, which overflows the stack and "
          "causes a crash by attempting to write to the guard page at the end.";
}

- (void)crash {
  [self crash];

  /* This is unreachable, but prevents clang from applying TCO to the above when
   * optimization is enabled. */
  NSLog(@"I'm here from the tail call prevention department.");
}

@end
