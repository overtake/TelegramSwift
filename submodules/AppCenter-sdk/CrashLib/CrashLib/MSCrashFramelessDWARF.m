// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashFramelessDWARF.h"

/* Our assembly implemented test function */
extern void MSFramelessDWARF_test(void);

/* Called by the assembly code paths to trigger the actual NULL dereference */
extern void MSFramelessDWARF_test_crash(void);

void MSFramelessDWARF_test_crash(void) {
  *((volatile uint8_t *) NULL) = 0xFF;
}

@implementation MSCrashFramelessDWARF

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"DWARF Unwinding";
}

- (NSString *)desc {
  return @""
          "Trigger a crash in a frame that requires DWARF or Compact Unwind support to correctly unwind. "
          "Unwinders that do not support DWARF will terminate on the second frame. "
          "The tests will fail for all unwinders on ARMv6 and ARMv7 (DWARF/eh_frame is unsupported). ";
}

- (void)crash {
  MSFramelessDWARF_test();
}


@end
