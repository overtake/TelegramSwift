// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashReleasedObject.h"
#import <objc/message.h>

@implementation MSCrashReleasedObject

- (NSString *)category {
  return @"Objective-C";
}

- (NSString *)title {
  return @"Message a released object";
}

- (NSString *)desc {
  return @"Send a message to an object whose memory has already been freed.";
}

- (void)crash {
#if __i386__ && !TARGET_IPHONE_SIMULATOR
  NSObject *object = [[NSObject alloc] init];
#else
  NSObject *__unsafe_unretained object = (__bridge NSObject *) CFBridgingRetain([[NSObject alloc] init]);
#endif

#if __i386__ && !TARGET_IPHONE_SIMULATOR
  [object release];
#else
  CFRelease((__bridge CFTypeRef) object);
#endif
  ^__attribute__((noreturn)) {
      for (;;) {
        [object self];
        [object description];
        [object debugDescription];
      }
  }();
}

@end
