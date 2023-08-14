//
//  HackUtils.h
//  Telegram
//
//  Created by Dmytro Kondratiev on 23/05/2014.
//  Copyright © 2014 Telegram. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@interface HackUtils : NSObject

+ (NSArray *)findElementsByClass:(NSString *)className inView:(NSView *)view;
+ (void)printViews:(NSView *)containerView;
@end

