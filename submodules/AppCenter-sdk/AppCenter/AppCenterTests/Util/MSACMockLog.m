// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockLog.h"

static NSString *const kMSACTypeMockLog = @"mockLog";

@implementation MSACMockLog

- (instancetype)init {
  if ((self = [super init])) {
    self.type = kMSACTypeMockLog;
  }
  return self;
}

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary];
  return dict;
}

@end
