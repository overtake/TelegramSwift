// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashNULL.h"

@implementation MSCrashNULL

- (NSString *)category {
  return @"SIGSEGV";
}

- (NSString *)title {
  return @"Dereference a NULL pointer";
}

- (NSString *)desc {
  return @"Attempt to read from 0x0, which causes a segmentation violation.";
}

- (void)crash {
  volatile char *ptr = NULL;
  (void) *ptr;
}

@end
