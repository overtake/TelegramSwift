// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACHistoryInfo.h"

@interface MSACTestSessionInfo : MSACHistoryInfo

@property(nonatomic, copy) NSString *sessionId;

- (instancetype)initWithTimestamp:(NSDate *)timestamp andSessionId:(NSString *)sessionId;

@end
