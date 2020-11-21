// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockCommonSchemaLog.h"

static NSString *const kMSACTypeMockCommonSchemaLog = @"mockCommonSchemaLog";

@implementation MSACMockCommonSchemaLog

- (instancetype)init {
  if ((self = [super init])) {
    self.type = kMSACTypeMockCommonSchemaLog;
  }
  return self;
}

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary];
  return dict;
}

@end
