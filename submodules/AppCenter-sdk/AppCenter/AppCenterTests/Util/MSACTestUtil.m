// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACTestUtil.h"
#import "MSACDevice.h"
#import "MSACLogContainer.h"
#import "MSACMockLog.h"
#import "MSACUtility+StringFormatting.h"

@implementation MSACTestUtil

+ (MSACLogContainer *)createLogContainerWithId:(NSString *)batchId device:(MSACDevice *)device {
  MSACMockLog *log1 = [[MSACMockLog alloc] init];
  log1.sid = MSAC_UUID_STRING;
  log1.timestamp = [NSDate date];
  log1.device = device;

  MSACMockLog *log2 = [[MSACMockLog alloc] init];
  log2.sid = MSAC_UUID_STRING;
  log2.timestamp = [NSDate date];
  log2.device = device;

  MSACLogContainer *logContainer = [[MSACLogContainer alloc] initWithBatchId:batchId andLogs:(NSArray<id<MSACLog>> *)@[ log1, log2 ]];
  return logContainer;
}

@end
