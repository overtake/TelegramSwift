// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACServiceAbstractInternal.h"

@interface MSACMockService : MSACServiceAbstract <MSACServiceInternal>

+ (void)resetSharedInstance;

@end
