// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACLogWithProperties.h"

NS_SWIFT_NAME(LogWithNameAndProperties)
@interface MSACLogWithNameAndProperties : MSACLogWithProperties

/**
 * Name of the event.
 */
@property(nonatomic, copy) NSString *name;

@end
