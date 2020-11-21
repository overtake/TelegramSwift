// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashCorruptObjC.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>

@implementation MSCrashCorruptObjC

- (NSString *)category {
  return @"Various";
}

- (NSString *)title {
  return @"Corrupt the Objective-C runtime's structures";
}

- (NSString *)desc {
  return @""
          "Write garbage into data areas used by the Objective-C runtime to track classes and objects. "
          "Bugs of this nature are why crash reporters cannot use Objective-C in their crash handling code, "
          "as attempting to do so is likely to lead to a crash in the crash reporting code.";
}

- (void)crash {
  Class objClass = [NSObject class];

  // VERY VERY PRIVATE INTERNAL RUNTIME DETAILS VERY VERY EVIL THIS IS BAD!!!
  struct objc_cache_t {
      uintptr_t mask;            /* total = mask + 1 */
      uintptr_t occupied;
      void *buckets[1];
  };
  struct objc_class_t {
      struct objc_class_t *isa;
      struct objc_class_t *superclass;
      struct objc_cache_t cache;
      IMP *vtable;
      uintptr_t data_NEVER_USE;  // class_rw_t * plus custom rr/alloc flags
  };

#if __i386__ && !TARGET_IPHONE_SIMULATOR
#define __bridge
#endif

  struct objc_class_t *objClassInternal = (__bridge struct objc_class_t *) objClass;

  // Trashes NSObject's method cache
  memset(&objClassInternal->cache, 0xa5, sizeof(struct objc_cache_t));

  [self description];
}

@end
