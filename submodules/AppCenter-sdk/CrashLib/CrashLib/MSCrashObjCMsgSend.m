// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashObjCMsgSend.h"
#import <objc/message.h>

@implementation MSCrashObjCMsgSend

- (NSString *)category {
  return @"Objective-C";
}

- (NSString *)title {
  return @"Crash inside objc_msgSend()";
}

- (NSString *)desc {
  return @"Send a message to an invalid object, resulting in a crash inside objc_msgSend().";
}

- (void)crash {
  struct {
      void *isa;
  } corruptObj = {
          .isa = (void *) 42
  };

#if __i386__ && !TARGET_IPHONE_SIMULATOR
#define __bridge
#endif
  [(__bridge id) &corruptObj stringWithFormat:
          @"%u, %u, %u, %u, %u, %u, %f, %f, %c, %c, %s, %s, %@, %@"
                  " %u, %u, %u, %u, %u, %u, %f, %f, %c, %c, %s, %s, %@, %@",
          0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 9.0, 10.0, 'a', 'b', "C", "D", @"E", @"F",
          0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 9.0, 10.0, 'a', 'b', "C", "D", @"E", @"F"];
}

@end
