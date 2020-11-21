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

#import <Foundation/Foundation.h>

@interface PLAsyncTask : NSObject {
    NSTask *_task;
    NSMutableData *_stdinData;
    NSMutableData *_stdoutData;
    NSMutableData *_stderrData;
    NSUInteger _stdinPosition;
    void (^_completionHandler)(PLAsyncTask *, NSData *, NSData *);
}

@property(nonatomic, copy) NSString *launchPath;
@property(nonatomic, copy) NSArray *arguments;
@property(nonatomic, copy) NSDictionary *environment;
@property(nonatomic, copy) NSData *stdinData;
@property(nonatomic, readonly) int terminationStatus;
@property(nonatomic, readonly) NSTaskTerminationReason terminationReason; 

- (void)terminate;
- (void)launchWithCompletionHandler:(void(^)(PLAsyncTask *, NSData *, NSData *))handler;

@end
