// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACLog.h"
#import "MSACLogConversion.h"

@protocol MSACMockLogWithConversion <MSACLog, MSACLogConversion, NSObject>
@end
