// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashDelayedObjCException.h"

@implementation MSCrashDelayedObjCException

- (NSString *)category {
    return @"Exceptions";
}

- (NSString *)title {
    return @"Throw Objective-C exception outside of IBAction";
}

- (NSString *)desc {
    return @"Throw an uncaught Objective-C exception outside of IBAction.";
}

- (void)crash {
    [self performSelector:@selector(delayedException) withObject:nil afterDelay:0.1];
}

- (void)delayedException {
    @throw [NSException exceptionWithName:NSGenericException reason:@"An uncaught exception!"
                                 userInfo:@{NSLocalizedDescriptionKey: @"Catching your exceptions!"}];
}

@end
