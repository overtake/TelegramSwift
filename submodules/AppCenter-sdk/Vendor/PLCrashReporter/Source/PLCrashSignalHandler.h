/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
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
#import "PLCrashMacros.h"

PLCR_C_BEGIN_DECLS

typedef struct PLCrashSignalHandlerCallback PLCrashSignalHandlerCallback;

/**
 * @internal
 * Signal handler callback function
 *
 * @param signo The received signal.
 * @param info The signal info.
 * @param uap The signal thread context.
 * @param context The previously specified context for this handler.
 * @param next A borrowed reference to the next signal handler's callback, or NULL if this is the final registered callback.
 * May be used to forward the signal via PLCrashSignalHandlerForward.
 *
 * @return Return true if the signal was handled and execution should continue, false if the signal was not handled.
 */
typedef bool (*PLCrashSignalHandlerCallbackFunc)(int signo, siginfo_t *info, ucontext_t *uap, void *context, PLCrashSignalHandlerCallback *next);

void plcrash_signal_handler (int signo, siginfo_t *info, void *uapVoid);

bool PLCrashSignalHandlerForward (PLCrashSignalHandlerCallback *next, int signal, siginfo_t *info, ucontext_t *uap);

@interface PLCrashSignalHandler : NSObject {
@private
    /** Signal stack */
    stack_t _sigstk;
}


+ (PLCrashSignalHandler *) sharedHandler;

+ (void) resetHandlers;

- (BOOL) registerHandlerForSignal: (int) signo
                         callback: (PLCrashSignalHandlerCallbackFunc) callback
                          context: (void *) context
                            error: (NSError **) outError;

@end

PLCR_C_END_DECLS
