// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashCustomView.h"

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_OSX
@interface MSCustomView : NSView
#else
@interface MSCustomView : UIView
#endif

@end

@implementation MSCustomView

#if TARGET_OS_OSX
-(void)drawRect:(NSRect)rect {
#else
-(void)drawRect:(CGRect)rect {
#endif
  [super drawRect:rect];
  @throw [NSException exceptionWithName:NSGenericException reason:@"Objective-C exception from drawing custom view."
                               userInfo:@{NSLocalizedDescriptionKey: @"Something goes wrong in drawRect:"}];
}

@end

@implementation MSCrashCustomView

- (NSString *)category {
  return @"Exceptions";
}

- (NSString *)title {
  return @"Throw Objective-C exception during drawing custom view";
}

- (NSString *)desc {
  return @"Throw an uncaught Objective-C exception during drawing custom view.";
}

- (void)crash {
  MSCustomView* view = [[MSCustomView new] initWithFrame:CGRectMake(0, 0, 100, 100)];
#if TARGET_OS_OSX
  [NSApplication.sharedApplication.mainWindow.contentView addSubview:view];
#else
  UIApplication.sharedApplication.keyWindow.rootViewController.view = view;
#endif
}

@end
