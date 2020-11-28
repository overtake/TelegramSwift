// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACServiceAbstractInternal.h"

@interface MSACMockSecondService : MSACServiceAbstract <MSACServiceInternal>

+ (void)resetSharedInstance;

@end
