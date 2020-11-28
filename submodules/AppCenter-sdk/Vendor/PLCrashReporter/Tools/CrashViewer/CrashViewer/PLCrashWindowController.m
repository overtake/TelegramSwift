/*
 * Author: Joe Ranieri <joe@alacatialabs.com>
 *
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
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

#import "PLCrashWindowController.h"
#import "PLAsyncTask.h"
#import "PLCrashDocument.h"
#import "PLProgressIndicatorController.h"

@interface PLCrashWindowController ()
/** The currently executing symbolication task, if any. */
@property(nonatomic, retain) PLAsyncTask *symbolicationTask;

/** The progress wheel displayed in the window. Used on pre-10.10 systems. */
@property(nonatomic, retain) NSProgressIndicator *indicator;

/** The progress wheel displayed in the window. Used on 10.10 and higher. */
@property(nonatomic, retain) PLProgressIndicatorController *indicatorController;

/** The text view displaying the crash log. */
@property(nonatomic, assign) IBOutlet NSTextView *textView;

/** Is the window in the process of closing? */
@property(nonatomic) BOOL closing;

/** The alert being displayed if there's an error symbolicating the log. */
@property(nonatomic, retain) NSAlert *alert;

/** The symbolication error alert's accessory view. */
@property(nonatomic, weak) IBOutlet NSView *alertAccessoryView;

/** The error log on the symbolication error alert's accessory view. */
@property(nonatomic, assign) IBOutlet NSTextView *alertTextView;
@end

@implementation PLCrashWindowController

- (void) windowDidLoad
{
    [super windowDidLoad];

    self.textView.font = [NSFont fontWithName: @"Menlo" size: 12];
    self.textView.string = [self.document reportText];

    if (self.symbolicationCommand.length) {
        [self addProgressIndicator];
        [self startSymbolicatingCrash: [self.document reportText]];
    }
}

- (void) windowWillClose: (NSNotification *)notification
{
    self.closing = YES;
    if (self.symbolicationTask)
        [self.symbolicationTask terminate];
}

/** The command to execute to symbolicate a crash log. This may be nil. */
- (NSString *) symbolicationCommand
{
    return [[NSUserDefaults standardUserDefaults] stringForKey: @"symbolicationCommand"];
}

/**
 * Asynchronously executes the user's symbolication command, passing the crash
 * report as stdin.
 */
- (void) startSymbolicatingCrash: (NSString *)crashText
{
    PLAsyncTask *symbolicationTaks = [[PLAsyncTask alloc] init];
    symbolicationTaks.launchPath = @"/bin/sh";
    symbolicationTaks.arguments = @[@"-c", self.symbolicationCommand];
    symbolicationTaks.stdinData = [crashText dataUsingEncoding: NSUTF8StringEncoding];

    [symbolicationTaks launchWithCompletionHandler: ^(PLAsyncTask *task, NSData *stdoutData, NSData *stderrData) {
        /* The data arguments aren't guaranteed to be valid after returning from
         * this callback, so make our strings immediately. */
        NSString *stdoutText = [[NSString alloc] initWithData: stdoutData encoding: NSUTF8StringEncoding];
        NSString *stderrText = [[NSString alloc] initWithData: stderrData encoding: NSUTF8StringEncoding];
        self.symbolicationTask = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeProgressIndicator];
            if (self.closing)
                return;

            if (task.terminationStatus == 0) {
                self.textView.string = stdoutText;
            } else if (stderrText.length) {
                [self displaySymbolicationError: stderrText];
            } else {
                [self displaySymbolicationError: stdoutText];
            }
        });
    }];
    self.symbolicationTask = symbolicationTaks;
}

/** Displays the error received while invoking the symbolication command. */
- (void) displaySymbolicationError: (NSString *)details
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Symbolication failed";
    alert.informativeText = @"The symbolication command returned a non-zero status code.";
    alert.accessoryView = self.alertAccessoryView;
    self.alertTextView.string = details;

    [alert beginSheetModalForWindow: self.window completionHandler: ^(NSModalResponse returnCode) {
        /* This dialog is informational only and we have no action to take. */
    }];
}

/** 
 * Adds an indeterminate progress wheel to the top right of the window to
 * indicate that symbolication is in progress.
 */
- (void) addProgressIndicator
{
    if (NSClassFromString(@"NSTitlebarAccessoryViewController")) {
        PLProgressIndicatorController *indicator = [[PLProgressIndicatorController alloc] init];
        indicator.layoutAttribute = NSLayoutAttributeRight;
        [self.window addTitlebarAccessoryViewController: indicator];
        self.indicatorController = indicator;
    } else {
        NSProgressIndicator *indicator = [[NSProgressIndicator alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)];
        indicator.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
        indicator.style = NSProgressIndicatorSpinningStyle;
        indicator.controlSize = NSSmallControlSize;

        NSView *themeFrame = [self.window.contentView superview];
        NSSize frameSize = themeFrame.frame.size;
        [indicator setFrameOrigin: NSMakePoint(frameSize.width - 18, frameSize.height - 18)];
        [themeFrame addSubview: indicator];

        [indicator startAnimation: nil];
        self.indicator = indicator;
    }
}

/** Removes the progress wheel added by -addProgressIndicator. */
- (void) removeProgressIndicator
{
    if (self.indicatorController) {
        [self.indicatorController removeFromParentViewController];
        self.indicatorController = nil;
    } else {
        [self.indicator removeFromSuperview];
        self.indicator = nil;
    }
}

@end
