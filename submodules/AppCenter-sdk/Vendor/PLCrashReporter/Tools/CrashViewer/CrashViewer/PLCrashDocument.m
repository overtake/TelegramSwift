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

#import "PLCrashDocument.h"
#import <CrashReporter/CrashReporter.h>
#import "PLAsyncTask.h"
#import "PLCrashWindowController.h"

@interface PLCrashDocument ()
@end

@implementation PLCrashDocument

- (void)makeWindowControllers
{
    PLCrashWindowController *controller = [[PLCrashWindowController alloc] initWithWindowNibName: @"PLCrashWindow"];
    controller.shouldCascadeWindows = YES;
    [self addWindowController: controller];
}

- (BOOL) readFromData: (NSData *)data ofType: (NSString *)typeName error: (__autoreleasing NSError **)outError
{
    if ([typeName isEqual: @"PLCrash"]) {
        PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: outError];
        if (!report)
            return NO;

        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report
                                                                withTextFormat: PLCrashReportTextFormatiOS];
        self.reportText = text;
        return YES;
    } else if ([typeName isEqual: @"com.apple.crashreport"] || [typeName isEqual: @"public.plain-text"]) {
        NSString *text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        self.reportText = text;
        return text != nil;
    }
    return NO;
}

@end
