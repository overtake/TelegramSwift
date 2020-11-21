// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashPrivInst.h"

@implementation MSCrashPrivInst

- (NSString *)category {
  return @"SIGILL";
}

- (NSString *)title {
  return @"Execute a privileged instruction";
}

- (NSString *)desc {
  return @"Attempt to execute an instruction that can only be executed in supervisor mode.";
}

- (void)crash {
#if __i386__
  asm volatile ( "hlt" : : : );
#elif __x86_64__
  asm volatile ( "hlt" : : : );
#elif __arm__ && __ARM_ARCH == 7 && __thumb__
  asm volatile ( ".long 0xf7f08000" : : : );
#elif __arm__ && __ARM_ARCH == 7
  asm volatile ( ".long 0xe1400070" : : : );
#elif __arm__ && __ARM_ARCH == 6 && __thumb__
  asm volatile ( ".long 0xf5ff8f00" : : : );
#elif __arm__ && __ARM_ARCH == 6
  asm volatile ( ".long 0xe14ff000" : : : );
#elif __arm64__
  /* Invalidate all EL1&0 regime stage 1 and 2 TLB entries. This should
   * not be possible from userspace, for hopefully obvious reasons :-) */
  asm volatile ( "tlbi alle1" : : : );
#endif
}

@end
