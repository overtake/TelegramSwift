// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashSmashStackTop.h"

@implementation MSCrashSmashStackTop

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"Smash the top of the stack";
}

- (NSString *)desc {
  return @""
          "Overwrite data above the current stack pointer. This will destroy the current stack trace. "
          "Reporting of this crash is expected to fail. Succeeding is basically luck. "
          "Apple added additional checks that prevent this crash from happening in iOS 12 and up.";
}

- (void)crash {
  void *sp = NULL;

#if __i386__
  asm volatile ( "mov %%esp, %0" : "=X" (sp) : : );
#elif __x86_64__
  asm volatile ( "mov %%rsp, %0" : "=X" (sp) : : );
#elif __arm__ && __ARM_ARCH == 7
  asm volatile ( "mov %0, sp" : "=X" (sp) : : );
#elif __arm__ && __ARM_ARCH == 6
  asm volatile ( "mov %0, sp" : "=X" (sp) : : );
#elif __arm64__
  asm volatile ( "mov %0, sp" : "=X" (sp) : : );
#endif

  memset(sp - 0x100, 0xa5, 0x100);
}

@end
