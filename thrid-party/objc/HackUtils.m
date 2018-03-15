//
//  HackUtils.m
//  Messenger for Telegram
//
//  Created by Dmitry Kondratyev on 3/25/14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "HackUtils.h"
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
@implementation HackUtils

+ (NSArray *)findElementsByClass:(NSString *)className inView:(NSView *)view {
//    [self printViews:view];
    NSArray *array = [self findElementsByClass:className inView:view array:nil];
    return array;
}

+ (NSArray *)findElementsByClass:(NSString *)className inView:(NSView *)view array:(NSMutableArray *)array {
    if(!array)
        array = [[NSMutableArray alloc] init];
    
    for (NSView *viewC in view.subviews) {
        
//        MTLog(@"viewC.className %@ %@", viewC.className, className);
        
        if([viewC.className isEqualToString:className]) {
            [array addObject:viewC];
        }
        
        if([viewC respondsToSelector:@selector(subviews)]) {
            [self findElementsByClass:className inView:viewC array:array];
        }
    }
    return array;
}



+ (void)printViews:(NSView *)containerView {
    [self printViews:containerView j:0];
}

+ (void)printViews:(NSView *)containerView j:(int)j {
    for (id c in containerView.subviews) {
        NSString *lol = @"";
        for(int i = 0; i < j; i++) {
            lol = [lol stringByAppendingString:@"  "];
        }
        NSLog(@"%@ %@", lol, NSStringFromClass([c class]));
        if([c respondsToSelector:@selector(subviews)]) {
            [self printViews:c j:j + 1];
        }
    }
}

@end
