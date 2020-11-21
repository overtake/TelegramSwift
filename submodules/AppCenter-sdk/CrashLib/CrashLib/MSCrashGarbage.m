// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashGarbage.h"
#import <sys/mman.h>

@implementation MSCrashGarbage

- (NSString *)category {
  return @"SIGSEGV";
}

- (NSString *)title {
  return @"Dereference a bad pointer";
}

- (NSString *)desc {
  return @"Attempt to read from a garbage pointer that's not mapped but also isn't NULL.";
}

- (void)crash {
  void *ptr = mmap(NULL, (size_t) getpagesize(), PROT_NONE, MAP_ANON | MAP_PRIVATE, -1, 0);

  if (ptr != MAP_FAILED)
    munmap(ptr, (size_t) getpagesize());

#if __i386__
  asm volatile ( "mov %0, %%eax\n\tmov (%%eax), %%eax" : : "X" (ptr) : "memory", "eax" );
#elif __x86_64__
  asm volatile ( "mov %0, %%rax\n\tmov (%%rax), %%rax" : : "X" (ptr) : "memory", "rax" );
#elif __arm__ && __ARM_ARCH == 7
  asm volatile ( "mov r4, %0\n\tldr r4, [r4]" : : "X" (ptr) : "memory", "r4" );
#elif __arm__ && __ARM_ARCH == 6
  asm volatile ( "mov r4, %0\n\tldr r4, [r4]" : : "X" (ptr) : "memory", "r4" );
#elif __arm64__
  asm volatile ( "mov x4, %0\n\tldr x4, [x4]" : : "X" (ptr) : "memory", "x4" );
#endif
}

@end
