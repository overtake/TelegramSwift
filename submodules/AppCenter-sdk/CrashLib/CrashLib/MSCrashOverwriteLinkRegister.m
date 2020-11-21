// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashOverwriteLinkRegister.h"

@implementation MSCrashOverwriteLinkRegister

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"Overwrite link register, then crash";
}

- (NSString *)desc {
  return @""
          "Trigger a crash after first overwriting the link register. "
          "Crash reporters that insert a stack frame based on the link register can generate duplicate or incorrect stack frames in the report. "
          "This does not apply to architectures that do not use a link register, such as x86-64.";
}

- (void)crash {
  /* Call a method to trigger modification of LR. We use the result below to
   * convince the compiler to order this function the way we want it. */
  uintptr_t ptr = (uintptr_t) [NSObject class];

  /* Make-work code that simply advances the PC to better demonstrate the discrepency. We use the
   * 'ptr' value here to make sure the compiler doesn't optimize-away this code, or re-order it below
   * the method call. */
  ptr += ptr;
  ptr -= 42;
  ptr += ptr % (ptr - 42);

  /* Crash within the method (using a write to the NULL page); the link register will be pointing at
   * the make-work code. We use the 'ptr' value to control compiler ordering. */
  *((uintptr_t volatile *) NULL) = ptr;
}


@end
