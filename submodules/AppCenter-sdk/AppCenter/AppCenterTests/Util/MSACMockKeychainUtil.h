// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACKeychainUtil.h"

@interface MSACMockKeychainUtil : MSACKeychainUtil

+ (void)mockStatusCode:(OSStatus)statusCode forKey:(NSString *)key;

@end
