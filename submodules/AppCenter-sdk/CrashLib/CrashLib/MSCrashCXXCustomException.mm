// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashCXXCustomException.h"

class my_custom_exception {
};

@implementation MSCrashCXXCustomException

- (NSString *)category {
  return @"Exceptions";
}

- (NSString *)title {
  return @"Throw Custom C++ exception";
}

- (NSString *)desc {
  return @"Throw an uncaught C++ exception that cannot be cast to std::exception.";
}

- (void)crash __attribute__((noreturn)) {
  throw new my_custom_exception;
}

@end
