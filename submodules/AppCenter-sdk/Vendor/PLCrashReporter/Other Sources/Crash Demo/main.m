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
#import "CrashReporter.h"

#import <sys/types.h>
#import <sys/sysctl.h>

#include <Availability.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
@interface DemoCrashAppDelegate : NSObject <UIApplicationDelegate> @end
@implementation DemoCrashAppDelegate
- (BOOL) application: (UIApplication *) application didFinishLaunchingWithOptions: (NSDictionary *) launchOptions {
    UIWindow *window = [[UIWindow alloc] init];
    window.rootViewController = [[UIViewController alloc] init];
    [window makeKeyAndVisible];
    return YES;
}
@end
#endif /* TARGET_OS_IPHONE */

/* A custom post-crash callback */
static void post_crash_callback (siginfo_t *info, ucontext_t *uap, void *context) {
    // this is not async-safe, but this is a test implementation
   
    NSLog(@"post crash callback: signo=%d, uap=%p, context=%p", info->si_signo, uap, context);
}


__attribute__((noinline)) static void stackFrame (void) {
    /* Trigger a crash */
    ((char *)NULL)[1] = 0;
}

/* If a crash report exists, make it accessible via iTunes document sharing. This is a no-op on Mac OS X. */
static void save_crash_report (PLCrashReporter *reporter) {
    if (![reporter hasPendingCrashReport]) 
        return;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    if (![fm createDirectoryAtPath: documentsDirectory withIntermediateDirectories: YES attributes:nil error: &error]) {
        NSLog(@"Could not create documents directory: %@", error);
        return;
    }

    NSData *data = [reporter loadPendingCrashReportDataAndReturnError: &error];
    if (data == nil) {
        NSLog(@"Failed to load crash report data: %@", error);
        return;
    }
    [reporter purgePendingCrashReport];

    PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: &error];
    if (report == nil) {
       NSLog(@"Failed to parse crash report: %@", error);
       return;
   }
    NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report withTextFormat: PLCrashReportTextFormatiOS];
    NSLog(@"%@", text);

    NSString *outputPath = [documentsDirectory stringByAppendingPathComponent: @"demo.plcrash"];
    if (![data writeToFile: outputPath atomically: YES]) {
        NSLog(@"Failed to write crash report");
    }
    NSLog(@"Saved crash report to: %@", outputPath);
}


/*
 * On iOS 6.x, when using Xcode 4, returning *immediately* from main()
 * while a debugger is attached will cause an immediate launchd respawn of the
 * application without the debugger enabled.
 *
 * This is not documented anywhere, and certainly occurs entirely by accident.
 * That said, it's enormously useful when performing integration tests on signal/exception
 * handlers, as it means we can use the standard Xcode build+run functionality without having
 * the debugger catch our signals (thus requiring that we manually relaunch the app after it has
 * installed).
 *
 * This may break at any point in the future, in which case we can remove it and go back
 * to the old, annoying, and slow approach of manually relaunching the application. Or,
 * perhaps Apple will bless us with the ability to run applications without the debugger
 * enabled.
 */
static bool debugger_should_exit (void) {
#if TARGET_OS_IPHONE
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        NSLog(@"sysctl() failed: %s", strerror(errno));
        return false;
    }

    if ((info.kp_proc.p_flag & P_TRACED) != 0)
        return true;
#endif
    return false;
}

int main (int argc, char *argv[]) {
    @autoreleasepool {
        NSError *error = nil;

        /*
         * Standalone "logic" tests aren't supported by XCTest when targeting an actual iOS device; instead,
         * they require a host application under which the tests will run.
         *
         * The DemoCrash application serves as a test host; we simply look for the existence of the XCTest framework
         * and assume that, should it be available, we're running as a test harness.
         */
#if TARGET_OS_IPHONE
        if (NSClassFromString(@"XCTestCase") != nil) {
            return UIApplicationMain(argc, argv, nil, @"DemoCrashAppDelegate");
        }
#endif /* TARGET_IPHONE_OS */

        /* Configure our reporter */
        PLCrashReporterSignalHandlerType signalHandlerType =
#if !TARGET_OS_TV
            PLCrashReporterSignalHandlerTypeMach;
#else
            PLCrashReporterSignalHandlerTypeBSD;
#endif
        PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType: signalHandlerType
                                                                            symbolicationStrategy: PLCrashReporterSymbolicationStrategyAll];
        PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: config];

        /* Save any existing crash report. */
        save_crash_report(reporter);

        if (debugger_should_exit()) {
            NSLog(@"The demo crash app should be run without a debugger present. Exiting ...");
            return 0;
        }

        /* Set up post-crash callbacks */
        PLCrashReporterCallbacks cb = {
            .version = 0,
            .context = (void *) 0xABABABAB,
            .handleSignal = post_crash_callback
        };
        [reporter setCrashCallbacks: &cb];

        /* Enable the crash reporter */
        if (![reporter enableCrashReporterAndReturnError: &error]) {
            NSLog(@"Could not enable crash reporter: %@", error);
        }
        /* Add another stack frame */
        stackFrame();
    }
}
