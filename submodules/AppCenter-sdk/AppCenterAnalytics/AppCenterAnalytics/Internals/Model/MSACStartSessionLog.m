// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACStartSessionLog.h"

static NSString *const kMSACTypeEndSession = @"startSession";

@implementation MSACStartSessionLog

- (instancetype)init {
  if ((self = [super init])) {
    self.type = kMSACTypeEndSession;
  }
  return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
}

@end
