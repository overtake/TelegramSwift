/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PLCrashReporterConfig.h"

/**
 * Crash Reporter Configuration.
 *
 * Supports configuring the behavior of PLCrashReporter instances.
 */
@implementation PLCrashReporterConfig

@synthesize signalHandlerType = _signalHandlerType;
@synthesize symbolicationStrategy = _symbolicationStrategy;
@synthesize shouldRegisterUncaughtExceptionHandler = _shouldRegisterUncaughtExceptionHandler;

/**
 * Return the default local configuration.
 */
+ (instancetype) defaultConfiguration {
    return [[self alloc] init];
}

/**
 * Initialize a new PLCrashReporterConfig instance using the default configuration. The default configuration
 * is appropriate for use in release builds.
 */
- (instancetype) init {
    return [self initWithSignalHandlerType: PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy: PLCrashReporterSymbolicationStrategyNone];
}

/**
 * Initialize a new PLCrashReporterConfig instance.
 *
 * @param signalHandlerType The requested signal handler type.
 * @param symbolicationStrategy A local symbolication strategy.
 */
- (instancetype) initWithSignalHandlerType: (PLCrashReporterSignalHandlerType) signalHandlerType
                     symbolicationStrategy: (PLCrashReporterSymbolicationStrategy) symbolicationStrategy
{
  return [self initWithSignalHandlerType:signalHandlerType symbolicationStrategy:symbolicationStrategy shouldRegisterUncaughtExceptionHandler:YES];
}

/**
 * Initialize a new PLCrashReporterConfig instance.
 *
 * @param signalHandlerType The requested signal handler type.
 * @param symbolicationStrategy A local symbolication strategy.
 * @param shouldRegisterUncaughtExceptionHandler Flag indicating if an uncaught exception handler should be set.
 */
- (instancetype) initWithSignalHandlerType: (PLCrashReporterSignalHandlerType) signalHandlerType
                     symbolicationStrategy: (PLCrashReporterSymbolicationStrategy) symbolicationStrategy
               shouldRegisterUncaughtExceptionHandler: (BOOL) shouldRegisterUncaughtExceptionHandler
{
  if ((self = [super init]) == nil)
    return nil;
  
  _signalHandlerType = signalHandlerType;
  _symbolicationStrategy = symbolicationStrategy;
  _shouldRegisterUncaughtExceptionHandler = shouldRegisterUncaughtExceptionHandler;
  
  return self;
}

@end
