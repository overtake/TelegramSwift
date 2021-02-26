//
//  STPAddress.m
//  Stripe
//
//  Created by Ben Guo on 4/13/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPAddress.h"
#import "STPCardValidator.h"
#import "STPPostalCodeValidator.h"

@implementation STPAddress


- (BOOL)containsRequiredFields:(STPBillingAddressFields)requiredFields {
    BOOL containsFields = YES;
    switch (requiredFields) {
        case STPBillingAddressFieldsNone:
            return YES;
        case STPBillingAddressFieldsZip:
            return [STPPostalCodeValidator stringIsValidPostalCode:self.postalCode 
                                                       countryCode:self.country];
        case STPBillingAddressFieldsFull:
            return [self hasValidPostalAddress];
    }
    return containsFields;
}

- (BOOL)hasValidPostalAddress {
    return (self.line1.length > 0 
            && self.city.length > 0 
            && self.country.length > 0 
            && (self.state.length > 0 || ![self.country isEqualToString:@"US"])  
            && [STPPostalCodeValidator stringIsValidPostalCode:self.postalCode 
                                                   countryCode:self.country]);
}


@end

