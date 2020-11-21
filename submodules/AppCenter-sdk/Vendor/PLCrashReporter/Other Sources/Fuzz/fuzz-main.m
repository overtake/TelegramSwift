/*
 *  fuzz-main.c
 *  CrashReporter
 *
 *  Created by Landon Fuller on 3/6/09.
 *  Copyright 2009 Plausible Labs Cooperative, Inc.. All rights reserved.
 */

#import <CrashReporter/CrashReporter.h>

int main (int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSError *error;
    
    if (argc < 2)
        return 1;

    /* Try to open and decode a crash report passed as the second argument */
    NSString *file = [NSString stringWithUTF8String: argv[1]];
    NSData *data = [NSData dataWithContentsOfFile: file];
    if (data == nil) {
        NSLog(@"Could not load crash report data from %@", file);
        exit(1);
    }

    PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: &error];
    if (report)
        [report release];

    [pool release];
}
