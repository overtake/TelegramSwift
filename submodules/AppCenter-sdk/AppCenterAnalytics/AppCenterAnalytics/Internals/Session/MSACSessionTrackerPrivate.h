// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACSessionContext.h"
#import "MSACSessionTracker.h"

@interface MSACSessionTracker ()

/**
 * Session context. This should be the shared instance, unless tests need to override.
 */
@property(nonatomic) MSACSessionContext *context;

/**
 * Flag to indicate if session tracking has started or not.
 */
@property(nonatomic, getter=isStarted) BOOL started;

/**
 *  Renew session Id.
 */
- (void)renewSessionId;

@end
