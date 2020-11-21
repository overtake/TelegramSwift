// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MSAC_LOG_WITH_PROPERTIES_H
#define MSAC_LOG_WITH_PROPERTIES_H

#import <Foundation/Foundation.h>

#import "MSACAbstractLog.h"

NS_SWIFT_NAME(LogWithProperties)
@interface MSACLogWithProperties : MSACAbstractLog

/**
 * Additional key/value pair parameters. [optional]
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *properties;

@end

#endif
