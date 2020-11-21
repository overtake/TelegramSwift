// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockSecondService.h"
#import "MSACChannelUnitConfiguration.h"

static NSString *const kMSACServiceName = @"MSMockSecondService";
static NSString *const kMSACGroupId = @"MSSecondMock";
static MSACMockSecondService *sharedInstance = nil;

@implementation MSACMockSecondService

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

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)__unused logManager appSecret:(NSString *)__unused appSecret {
  self.started = YES;
}

- (void)applyEnabledState:(BOOL)__unused isEnabled {
}

- (BOOL)isAppSecretRequired {
  return NO;
}

- (BOOL)isAvailable {
  return self.started;
}

- (MSACInitializationPriority)initializationPriority {
  return MSACInitializationPriorityDefault;
}

@end
