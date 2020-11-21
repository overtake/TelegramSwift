// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACTestSessionInfo.h"
#import <Foundation/Foundation.h>

@implementation MSACTestSessionInfo

- (instancetype)initWithTimestamp:(NSDate *)timestamp andSessionId:(NSString *)sessionId {
  self = [super initWithTimestamp:timestamp];
  if (self) {
    _sessionId = sessionId;
  }
  return self;
}

@end
