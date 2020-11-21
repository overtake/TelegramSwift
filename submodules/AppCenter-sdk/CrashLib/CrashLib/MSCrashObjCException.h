// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrash.h"

@interface MSCrashObjCException : MSCrash

- (void)crash __attribute__((noreturn));

@end
