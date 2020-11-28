// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashSmashStackBottom.h"

@implementation MSCrashSmashStackBottom

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"Smash the bottom of the stack";
}

- (NSString *)desc {
  return @""
          "Overwrite data below the current stack pointer. This will destroy the current function. "
          "Reporting of this crash is expected to fail. Succeeding is basically luck.";
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

  memset(sp, 0xa5, 0x100);
}

@end
