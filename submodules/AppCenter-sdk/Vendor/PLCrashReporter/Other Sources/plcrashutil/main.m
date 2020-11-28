/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
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
#import <CrashReporter/CrashReporter.h>

#import <stdlib.h>
#import <stdio.h>
#import <getopt.h>

/*
 * Print command line usage.
 */
static void print_usage () {
    fprintf(stderr, "Usage: plcrashutil <command> <options>\n"
                    "Commands:\n"
                    "  convert --format=<format> <file>\n"
                    "      Covert a plcrash file to the given format.\n\n"
                    "      Supported formats:\n"
                    "        ios - Standard Apple iOS-compatible text crash log\n"
                    "        iphone - Synonym for 'iOS'.\n");
}

/*
 * Run a conversion.
 */
static int convert_command (int argc, char *argv[]) {
    const char *format = "iphone";
    const char *input_file;
    FILE *output = stdout;

    /* options descriptor */
    static struct option longopts[] = {
        { "format",     required_argument,      NULL,          'f' },
        { NULL,         0,                      NULL,           0 }
    };    

    /* Read the options */
    char ch;
    while ((ch = getopt_long(argc, argv, "f:", longopts, NULL)) != -1) {
        switch (ch) {
            case 'f':
                format = optarg;
                break;
            default:
                print_usage();
                return 1;
        }
    }
    argc -= optind;
    argv += optind;

    /* Ensure there's an input file specified */
    if (argc < 1) {
        fprintf(stderr, "No input file supplied\n");
        print_usage();
        return 1;
    } else {
        input_file = argv[0];
    }
    
    /* Verify that the format is supported. Only one is actually supported currently */
    PLCrashReportTextFormat textFormat;
    if (strcasecmp(format, "iphone") == 0 || strcasecmp(format, "ios")) {
        textFormat = PLCrashReportTextFormatiOS;
    } else {
        fprintf(stderr, "Unsupported format requested\n");
        print_usage();
        return 1;
    }

    /* Try reading the file in */
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile: [NSString stringWithUTF8String: input_file] 
                                          options: NSMappedRead error: &error];
    if (data == nil) {
        fprintf(stderr, "Could not read input file: %s\n", [[error localizedDescription] UTF8String]);
        return 1;
    }
    
    /* Decode it */
    PLCrashReport *crashLog = [[PLCrashReport alloc] initWithData: data error: &error];
    if (crashLog == nil) {
        fprintf(stderr, "Could not decode crash log: %s\n", [[error localizedDescription] UTF8String]);
        return 1;
    }

    /* Format the report */
    NSString* report = [PLCrashReportTextFormatter stringValueForCrashReport: crashLog withTextFormat: textFormat];
    fprintf(output, "%s", [report UTF8String]);     
    return 0;
}

int main (int argc, char *argv[]) {
    @autoreleasepool {
        int ret = 0;

        if (argc < 2) {
            print_usage();
            exit(1);
        }

        /* Convert command */
        if (strcmp(argv[1], "convert") == 0) {
            ret = convert_command(argc - 2, argv + 2);
        } else {
            print_usage();
            ret = 1;
        }
        exit(ret);
    }
}
