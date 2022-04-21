//
//  STPImages.h
//  Stripe
//
//  Created by Jack Flintermann on 6/30/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Stripe/STPCardBrand.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  This class lets you access card icons used by the Stripe SDK. All icons are 32 x 20 points.
 */
@interface STPImageLibrary : NSObject

/**
 *  An icon representing Apple Pay.
 */
+ (NSImage *)applePayCardImage;

/**
 *  An icon representing American Express.
 */
+ (NSImage *)amexCardImage;

/**
 *  An icon representing Diners Club.
 */
+ (NSImage *)dinersClubCardImage;

/**
 *  An icon representing Discover.
 */
+ (NSImage *)discoverCardImage;

/**
 *  An icon representing JCB.
 */
+ (NSImage *)jcbCardImage;

/**
 *  An icon representing MasterCard.
 */
+ (NSImage *)masterCardCardImage;

/**
 *  An icon representing Visa.
 */
+ (NSImage *)visaCardImage;

/**
 *  An icon to use when the type of the card is unknown.
 */
+ (NSImage *)unknownCardCardImage;

/**
 *  This returns the appropriate icon for the specified card brand.
 */
+ (NSImage *)brandImageForCardBrand:(STPCardBrand)brand;

/**
 *  This returns the appropriate icon for the specified card brand as a 
 *  single color template that can be tinted
 */
+ (NSImage *)templatedBrandImageForCardBrand:(STPCardBrand)brand;

/**
 *  This returns a small icon indicating the CVC location for the given card brand.
 */
+ (NSImage *)cvcImageForCardBrand:(STPCardBrand)brand;


@end

NS_ASSUME_NONNULL_END
