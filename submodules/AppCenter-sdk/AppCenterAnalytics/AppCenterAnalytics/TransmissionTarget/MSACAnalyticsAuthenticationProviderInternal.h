// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAnalyticsAuthenticationProvider.h"

@interface MSACAnalyticsAuthenticationProvider ()

@property(nonatomic) signed char isAlreadyAcquiringToken;

@property(nonatomic, strong) NSDate *expiryDate;

/**
 * Request a new token from the app.
 */
- (void)acquireTokenAsync;

@end
