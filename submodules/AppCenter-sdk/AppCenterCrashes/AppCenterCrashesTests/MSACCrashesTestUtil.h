// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@class MSACException;

@interface MSACCrashesTestUtil : NSObject

+ (BOOL)createTempDirectory:(NSString *)directory;

+ (BOOL)copyFixtureCrashReportWithFileName:(NSString *)filename;

+ (NSData *)dataOfFixtureCrashReportWithFileName:(NSString *)filename;

+ (MSACException *)exception;

@end
