// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalyticsAuthenticationProvider.h"
#import "MSACAnalyticsAuthenticationProviderDelegate.h"
#import "MSACAnalyticsInternal.h"
#import "MSACLogger.h"
#import "MSACTicketCache.h"
#import "MSACUtility+StringFormatting.h"

// Number of seconds to refresh token before it expires.
static int kMSRefreshThreshold = 10 * 60;

@interface MSACAnalyticsAuthenticationProvider ()

@property(nonatomic) NSDate *expiryDate;

/**
 * Completion block that will be used to get an updated authentication token.
 */
@property(nonatomic, copy) MSACAnalyticsAuthenticationProviderCompletionBlock completionHandler;

@end

@implementation MSACAnalyticsAuthenticationProvider

- (instancetype)initWithAuthenticationType:(MSACAnalyticsAuthenticationType)type
                                 ticketKey:(NSString *)ticketKey
                                  delegate:(id<MSACAnalyticsAuthenticationProviderDelegate>)delegate {
  if ((self = [super init])) {
    _type = type;
    _ticketKey = ticketKey;
    if (ticketKey) {
      _ticketKeyHash = [MSACUtility sha256:ticketKey];
    }
    _delegate = delegate;
  }
  return self;
}

- (void)acquireTokenAsync {
  id<MSACAnalyticsAuthenticationProviderDelegate> strongDelegate = self.delegate;
  if (strongDelegate) {
    if (!self.completionHandler) {
      MSACAnalyticsAuthenticationProvider *__weak weakSelf = self;
      self.completionHandler = ^void(NSString *token, NSDate *expiryDate) {
        MSACAnalyticsAuthenticationProvider *strongSelf = weakSelf;
        [strongSelf handleTokenUpdateWithToken:token expiryDate:expiryDate withCompletionHandler:strongSelf.completionHandler];
      };
      [strongDelegate authenticationProvider:self acquireTokenWithCompletionHandler:self.completionHandler];
    }
  } else {
    MSACLogError([MSACAnalytics logTag], @"No completionhandler to acquire token has been set.");
  }
}

- (void)handleTokenUpdateWithToken:(NSString *)token
                        expiryDate:(NSDate *)expiryDate
             withCompletionHandler:(MSACAnalyticsAuthenticationProviderCompletionBlock)completionHandler {
  @synchronized(self) {
    if (self.completionHandler == completionHandler) {
      self.completionHandler = nil;
      MSACLogDebug([MSACAnalytics logTag], @"Got result back from MSAcquireTokenCompletionBlock.");
      if (!token) {
        MSACLogError([MSACAnalytics logTag], @"Token must not be null");
        return;
      }
      if (!expiryDate) {
        MSACLogError([MSACAnalytics logTag], @"Date must not be null");
        return;
      }
      NSString *tokenPrefix;
      switch (self.type) {
      case MSACAnalyticsAuthenticationTypeMsaCompact:
        tokenPrefix = @"p";
        break;
      case MSACAnalyticsAuthenticationTypeMsaDelegate:
        tokenPrefix = @"d";
        break;
      }
      [[MSACTicketCache sharedInstance] setTicket:[NSString stringWithFormat:@"%@:%@", tokenPrefix, token] forKey:self.ticketKeyHash];
      self.expiryDate = expiryDate;
    }
  }
}

- (void)checkTokenExpiry {
  @synchronized(self) {
    if (self.expiryDate &&
        (long long)[self.expiryDate timeIntervalSince1970] <= ((long long)[[NSDate date] timeIntervalSince1970] + kMSRefreshThreshold)) {
      [self acquireTokenAsync];
    }
  }
}

@end
