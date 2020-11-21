/*
 * Author: Joe Ranieri <joe@alacatialabs.com>
 *
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * Copyright (c) Xojo, Inc.
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

#import "PLAsyncTask.h"

/** A wrapper around NSTask that makes asynchronous operations easier. */
@implementation PLAsyncTask
@synthesize stdinData = _stdinData;

- (id) init
{
    if ((self = [super init]) == nil)
        return nil;

    _task = [[NSTask alloc] init];
    _stderrData = [[NSMutableData alloc] init];
    _stdoutData = [[NSMutableData alloc] init];
    return self;
}

- (void) setLaunchPath:(NSString *)launchPath
{
    _task.launchPath = launchPath;
}

- (NSString *) launchPath
{
    return _task.launchPath;
}

- (void) setArguments: (NSArray *)arguments
{
    _task.arguments = arguments;
}

- (NSArray *) arguments
{
    return _task.arguments;
}

- (void) setEnvironment: (NSDictionary *)environment
{
    _task.environment = environment;
}

- (NSDictionary *) environment
{
    return _task.environment;
}

- (int) terminationStatus
{
    return _task.terminationStatus;
}

- (NSTaskTerminationReason) terminationReason
{
    return _task.terminationReason;
}

- (void) terminate
{
    [_task terminate];
}

/**
 * Launches the task asynchronously, invoking the handler when the task
 * terminates.
 *
 * @param handler The handler to invoke. The parameters sent to the handler
 *                are the task, the data from stdout, and the data from stderr.
 */
- (void) launchWithCompletionHandler: (void (^)(PLAsyncTask *, NSData *, NSData *))handler
{
    _completionHandler = [handler copy];

    NSPipe *stdoutPipe = [NSPipe pipe];
    NSFileHandle *stdoutFileHandle = stdoutPipe.fileHandleForReading;
    stdoutFileHandle.readabilityHandler = ^(NSFileHandle *handle) {
        [self->_stdoutData appendData:handle.availableData];
    };
    _task.standardOutput = stdoutPipe;

    NSPipe *stderrPipe = [NSPipe pipe];
    NSFileHandle *stderrFileHandle = stderrPipe.fileHandleForReading;
    stderrFileHandle.readabilityHandler = ^(NSFileHandle *handle) {
        [self->_stderrData appendData:handle.availableData];
    };
    _task.standardError = stderrPipe;

    if (self.stdinData.length) {
        NSPipe *stdinPipe = [NSPipe pipe];
        NSFileHandle *stdinFileHandle = stdinPipe.fileHandleForWriting;
        fcntl(stdinFileHandle.fileDescriptor, F_SETFL, O_NONBLOCK);

        stdinFileHandle.writeabilityHandler = ^(NSFileHandle *handle) {
            /* -[NSFileHandle write:] raises exceptions, doesn't tell us how
             * much data was written, and ugly in general. Drop down to the
             * POSIX level to do this nicer. */
            ssize_t result = write(handle.fileDescriptor,
                                   (const char *)self.stdinData.bytes + self->_stdinPosition,
                                   self.stdinData.length - self->_stdinPosition);
            if (result > 0) {
                self->_stdinPosition += result;
                if (self->_stdinPosition == self.stdinData.length) {
                    handle.writeabilityHandler = nil;
                    [handle closeFile];
                }
            } else if (errno != EAGAIN && errno != EINTR) {
                /* Something fatal happened. We don't currently have a way to
                 * report this error back to our caller... */
                handle.writeabilityHandler = nil;
            }
        };
        
        _task.standardInput = stdinPipe;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    _task.terminationHandler = ^(NSTask *task) {
        /* We can't set the task's standardOutput/standardError to nil in this
         * block because it raises an exception. We at least need to nil out the
         * readability handlers though, because otherwise they'll eat 100% CPU.
         */
        [task.standardOutput fileHandleForReading].readabilityHandler = nil;
        [task.standardError fileHandleForReading].readabilityHandler = nil;
        [task.standardInput fileHandleForWriting].writeabilityHandler = nil;
        task.terminationHandler = nil;

        self->_completionHandler(self, self->_stdoutData, self->_stderrData);
        self->_completionHandler = nil;

        self->_stdoutData.length = 0;
        self->_stderrData.length = 0;
        self->_stdinPosition = 0;
    };
#pragma clang diagnostic pop

    [_task launch];
}

@end
