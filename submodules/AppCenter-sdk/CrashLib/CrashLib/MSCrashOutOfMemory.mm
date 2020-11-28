// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashOutOfMemory.h"

@interface MSCrashOutOfMemory ()

@property NSMutableArray *buffers;

@property size_t allocated;

@end

@implementation MSCrashOutOfMemory

- (instancetype)init {
  self = [super init];
  if (self) {
    _buffers = [NSMutableArray new];
    _allocated = 0;
  }
  return self;
}

- (NSString *)category {
  return @"Memory";
}

- (NSString *)title {
  return @"Produce memory shortage (OOM)";
}

- (NSString *)desc {
  return @""
          "Execute an infinite loop with excessive memory allocation which "
          "causes an OS to terminate app.";
}

- (void)crash {
  const size_t blockSize = 128 * 1024 * 1024;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
    void *buffer = malloc(blockSize);
    memset(buffer, 42, blockSize);
    [self.buffers addObject:[NSValue valueWithPointer:buffer]];
    self.allocated += blockSize;
    NSLog(@"Allocated %zu MB", self.allocated / (1024 * 1024));
    [self crash];
  });
}

@end
