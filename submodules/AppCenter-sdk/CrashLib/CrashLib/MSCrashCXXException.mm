// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashCXXException.h"
#import <exception>

class kaboom_exception : public std::exception {
    virtual const char *what() const throw();
};

const char *kaboom_exception::what() const throw() {
  return "If this had been a real exception, you would be cursing now.";
}

@implementation MSCrashCXXException

- (NSString *)category {
  return @"Exceptions";
}

- (NSString *)title {
  return @"Throw C++ exception";
}

- (NSString *)desc {
  return @""
          "Throw an uncaught C++ exception. "
          "This is a difficult case for crash reporters to handle, "
          "as it involves the destruction of the data necessary to generate a correct backtrace.";
}

- (void)crash __attribute__((noreturn)) {
  throw new kaboom_exception;
}

@end
