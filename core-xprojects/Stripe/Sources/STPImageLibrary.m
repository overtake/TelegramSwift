//
//  STPImages.m
//  Stripe
//
//  Created by Jack Flintermann on 6/30/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPImageLibrary.h"
#import "STPImageLibrary+Private.h"

// Dummy class for locating the framework bundle


@implementation STPImageLibrary

+ (NSImage *)applePayCardImage {
    return [self safeImageNamed:@"stp_card_applepay"];
}

+ (NSImage *)amexCardImage {
    return [self brandImageForCardBrand:STPCardBrandAmex];
}

+ (NSImage *)dinersClubCardImage {
    return [self brandImageForCardBrand:STPCardBrandDinersClub];
}

+ (NSImage *)discoverCardImage {
    return [self brandImageForCardBrand:STPCardBrandDiscover];
}

+ (NSImage *)jcbCardImage {
    return [self brandImageForCardBrand:STPCardBrandJCB];
}

+ (NSImage *)masterCardCardImage {
    return [self brandImageForCardBrand:STPCardBrandMasterCard];
}

+ (NSImage *)visaCardImage {
    return [self brandImageForCardBrand:STPCardBrandVisa];
}

+ (NSImage *)unknownCardCardImage {
    return [self brandImageForCardBrand:STPCardBrandUnknown];
}

+ (NSImage *)brandImageForCardBrand:(STPCardBrand)brand {
    return [self brandImageForCardBrand:brand template:NO];
}

+ (NSImage *)templatedBrandImageForCardBrand:(STPCardBrand)brand {
    return [self brandImageForCardBrand:brand template:YES];
}

+ (NSImage *)cvcImageForCardBrand:(STPCardBrand)brand {
    NSString *imageName = brand == STPCardBrandAmex ? @"stp_card_cvc_amex" : @"stp_card_cvc";
    return [self safeImageNamed:imageName];
}

+ (NSImage *)safeImageNamed:(NSString *)imageName {
    return [self safeImageNamed:imageName templateIfAvailable:NO];
}

@end

@implementation STPImageLibrary (Private)

+ (NSImage *)addIcon {
    return [self safeImageNamed:@"stp_icon_add" templateIfAvailable:YES];
}

+ (NSImage *)leftChevronIcon {
    return [self safeImageNamed:@"stp_icon_chevron_left" templateIfAvailable:YES];
}

+ (NSImage *)smallRightChevronIcon {
    return [self safeImageNamed:@"stp_icon_chevron_right_small" templateIfAvailable:YES];
}

+ (NSImage *)checkmarkIcon {
    return [self safeImageNamed:@"stp_icon_checkmark" templateIfAvailable:YES];
}

+ (NSImage *)largeCardFrontImage {
    return [self safeImageNamed:@"stp_card_form_front" templateIfAvailable:YES];
}

+ (NSImage *)largeCardBackImage {
    return [self safeImageNamed:@"stp_card_form_back" templateIfAvailable:YES];
}

+ (NSImage *)largeCardApplePayImage {
    return [self safeImageNamed:@"stp_card_form_applepay" templateIfAvailable:YES];
}

+ (NSImage *)safeImageNamed:(NSString *)imageName
        templateIfAvailable:(BOOL)templateIfAvailable {
    
    NSImage *image = [NSImage imageNamed:imageName];
//    [image setTemplate:templateIfAvailable];
    
    return image;
}

+ (NSImage *)brandImageForCardBrand:(STPCardBrand)brand
                           template:(BOOL)isTemplate {
    BOOL shouldUseTemplate = isTemplate;
    NSString *imageName;
    switch (brand) {
            case STPCardBrandAmex:
            imageName = shouldUseTemplate ? @"stp_card_amex_template" : @"stp_card_amex";
            break;
            case STPCardBrandDinersClub:
            imageName = shouldUseTemplate ? @"stp_card_diners_template" : @"stp_card_diners";
            break;
            case STPCardBrandDiscover:
            imageName = shouldUseTemplate ? @"stp_card_discover_template" : @"stp_card_discover";
            break;
            case STPCardBrandJCB:
            imageName = shouldUseTemplate ? @"stp_card_jcb_template" : @"stp_card_jcb";
            break;
            case STPCardBrandMasterCard:
            imageName = shouldUseTemplate ? @"stp_card_mastercard_template" : @"stp_card_mastercard";
            break;
            case STPCardBrandUnknown:
            shouldUseTemplate = YES;
            imageName = @"stp_card_unknown";
            break;
            case STPCardBrandVisa:
            imageName = shouldUseTemplate ? @"stp_card_visa_template" : @"stp_card_visa";
            break;
    }
    NSImage *image = [self safeImageNamed:imageName
                      templateIfAvailable:shouldUseTemplate];
    return image;
}

@end
