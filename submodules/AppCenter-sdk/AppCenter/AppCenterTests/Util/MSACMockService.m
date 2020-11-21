// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockService.h"
#import "MSACChannelGroupProtocol.h"
#import "MSACChannelUnitConfiguration.h"

static NSString *const kMSACServiceName = @"MSMockService";
static NSString *const kMSACGroupId = @"MSMock";
static MSACMockService *sharedInstance = nil;

@implementation MSACMockService

@synthesize channelGroup = _channelGroup;
@synthesize channelUnit = _channelUnit;
@synthesize channelUnitConfiguration = _channelUnitConfiguration;
@synthesize appSecret = _appSecret;
@synthesize defaultTransmissionTargetToken = _defaultTransmissionTargetToken;

- (instancetype)init {
  if ((self = [super init])) {

    // Init channel configuration.
    _channelUnitConfiguration = [[MSACChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:[self groupId]];
  }
  return self;
}

+ (instancetype)sharedInstance {
  if (sharedInstance == nil) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

+ (void)resetSharedInstance {
  sharedInstance = nil;
}

+ (NSString *)serviceName {
  return kMSACServiceName;
}

+ (NSString *)logTag {
  return @"AppCenterTest";
}

- (NSString *)groupId {
  return kMSACGroupId;
}

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup
                    appSecret:(nullable NSString *)appSecret
      transmissionTargetToken:(nullable NSString *)token
              fromApplication:(BOOL)fromApplication {
  self.startedFromApplication = fromApplication;
  self.channelGroup = channelGroup;
  self.appSecret = appSecret;
  self.defaultTransmissionTargetToken = token;
  self.started = YES;
  self.channelUnit = [self.channelGroup addChannelUnitWithConfiguration:self.channelUnitConfiguration];
}

- (void)applyEnabledState:(BOOL)__unused isEnabled {
}

- (BOOL)isAvailable {
  return self.started;
}

- (MSACInitializationPriority)initializationPriority {
  return MSACInitializationPriorityDefault;
}

@end
