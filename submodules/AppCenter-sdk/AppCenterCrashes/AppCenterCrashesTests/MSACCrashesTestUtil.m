// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACCrashesTestUtil.h"
#import "MSACException.h"
#import "MSACStackFrame.h"

@implementation MSACCrashesTestUtil

+ (BOOL)createTempDirectory:(NSString *)directory {
  NSFileManager *fm = [[NSFileManager alloc] init];

  if (![fm fileExistsAtPath:directory]) {
    NSDictionary *attributes = @{NSFilePosixPermissions : @0755};
    NSError *error;
    [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:attributes error:&error];
    if (error)
      return NO;
  }

  return YES;
}

+ (BOOL)copyFixtureCrashReportWithFileName:(NSString *)filename {
  NSFileManager *fm = [[NSFileManager alloc] init];

  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  if (!bundleIdentifier) {
    const char *progname = getprogname();
    if (progname == NULL) {
      return NO;
    }
    bundleIdentifier = [NSString stringWithUTF8String:progname];
  }

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

  // create the PLCR cache dir
  NSString *plcrRootCrashesDir = [paths[0] stringByAppendingPathComponent:@"com.plausiblelabs.crashreporter.data"];
  if (![MSACCrashesTestUtil createTempDirectory:plcrRootCrashesDir])
    return NO;

  NSString *plcrCrashesDir = [plcrRootCrashesDir stringByAppendingPathComponent:bundleIdentifier];
  if (![MSACCrashesTestUtil createTempDirectory:plcrCrashesDir])
    return NO;

  NSString *filePath = [[NSBundle bundleForClass:self.class] pathForResource:filename ofType:@"plcrash"];
  if (!filePath)
    return NO;

  NSError *error = nil;
  [fm copyItemAtPath:filePath toPath:[plcrCrashesDir stringByAppendingPathComponent:@"live_report.plcrash"] error:&error];
  return error == nil;
}

+ (NSData *)dataOfFixtureCrashReportWithFileName:(NSString *)filename {

  // the bundle identifier when running with unit tets is "otest"
  const char *progname = getprogname();
  if (progname == NULL) {
    return nil;
  }
  NSString *filePath = [[NSBundle bundleForClass:self.class] pathForResource:filename ofType:@"plcrash"];
  if (!filePath) {
    return nil;
  } else {
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    return data;
  }
}

+ (MSACException *)exception {
  NSString *type = @"exceptionType";
  NSString *message = @"message";
  NSString *stackTrace = @"at (wrapper managed-to-native) UIKit.UIApplication:UIApplicationMain "
                         @"(int,string[],intptr,intptr) \n at UIKit.UIApplication.Main "
                         @"(System.String[] args, "
                         @"System.IntPtr principal, System.IntPtr delegate) [0x00005] in "
                         @"/Users/builder/data/lanes/3969/44931ae8/source/xamarin-macios/src/"
                         @"UIKit/"
                         @"UIApplication.cs:79 \n at UIKit.UIApplication.Main (System.String[] "
                         @"args, System.String "
                         @"principalClassName, System.String delegateClassName) [0x00038] in "
                         @"/Users/builder/data/lanes/3969/44931ae8/source/xamarin-macios/src/"
                         @"UIKit/"
                         @"UIApplication.cs:63 \n   at HockeySDKXamarinDemo.Application.Main "
                         @"(System.String[] args) "
                         @"[0x00008] in "
                         @"/Users/benny/Repositories/MSAC/HockeySDK-XamarinDemo/iOS/Main.cs:17";
  NSString *wrapperSdkName = @"appcenter.xamarin";
  MSACStackFrame *frame = [MSACStackFrame new];
  frame.address = @"frameAddress";
  frame.code = @"frameSymbol";
  NSArray<MSACStackFrame *> *frames = @[ frame ];

  MSACException *exception = [MSACException new];
  exception.type = type;
  exception.message = message;
  exception.stackTrace = stackTrace;
  exception.wrapperSdkName = wrapperSdkName;
  exception.frames = frames;

  return exception;
}

@end
