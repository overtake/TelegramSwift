// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashCorruptMalloc.h"
#import <malloc/malloc.h>
#import <mach/mach.h>

@implementation MSCrashCorruptMalloc

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"Corrupt malloc()'s internal tracking information";
}

- (NSString *)desc {
  return @""
          "Write garbage into data areas used by malloc to track memory allocations. "
          "This simulates the kind of heap overflow and/or heap corruption likely to occur in an application; "
          "if the crash reporter itself uses malloc, the corrupted heap will likely trigger a crash in the crash reporter itself.";
}

- (void)crash {
  /* Smash the heap, and keep smashing it until we eventually hit something non-writable, or trigger
   * a malloc error (e.g., in NSLog). */
  uint8_t *memory = malloc(10);
  while (true) {
    NSLog(@"Smashing [%p - %p]", memory, memory + PAGE_SIZE);
    memset((void *) trunc_page((vm_address_t) memory), 0xAB, PAGE_SIZE);
    memory += PAGE_SIZE;
  }
}

@end
