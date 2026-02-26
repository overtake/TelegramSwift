//
//  STPImageLibrary+Private.h
//  Stripe
//
//  Created by Jack Flintermann on 6/30/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPImageLibrary.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface STPImageLibrary (Private)

+ (NSImage *)addIcon;
+ (NSImage *)leftChevronIcon;
+ (NSImage *)smallRightChevronIcon;
+ (NSImage *)checkmarkIcon;
+ (NSImage *)largeCardFrontImage;
+ (NSImage *)largeCardBackImage;
+ (NSImage *)largeCardApplePayImage;

+ (NSImage *)safeImageNamed:(NSString *)imageName
        templateIfAvailable:(BOOL)templateIfAvailable;
+ (NSImage *)brandImageForCardBrand:(STPCardBrand)brand
                           template:(BOOL)isTemplate;

@end

NS_ASSUME_NONNULL_END
