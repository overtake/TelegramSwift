// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashUndefInst.h"

@implementation MSCrashUndefInst

- (NSString *)category {
  return @"SIGILL";
}

- (NSString *)title {
  return @"Execute an undefined instruction";
}

- (NSString *)desc {
  return @"Attempt to execute an instructiondinn not to be defined on the current architecture.";
}

- (void)crash {
#if __i386__
  asm volatile ( "ud2" : : : );
#elif __x86_64__
  asm volatile ( "ud2" : : : );
#elif __arm__ && __ARM_ARCH == 7 && __thumb__
  asm volatile ( ".word 0xde00" : : : );
#elif __arm__ && __ARM_ARCH == 7
  asm volatile ( ".long 0xf7f8a000" : : : );
#elif __arm__ && __ARM_ARCH == 6 && __thumb__
  asm volatile ( ".word 0xde00" : : : );
#elif __arm__ && __ARM_ARCH == 6
  asm volatile ( ".long 0xf7f8a000" : : : );
#elif __arm64__
  asm volatile ( ".long 0xf7f8a000" : : : );
#endif
}

@end
