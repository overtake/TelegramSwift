// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenter.h"
#import "MSACAppCenterInternal.h"
#import "MSACAppCenterPrivate.h"
#import "MSACChannelGroupDefault.h"
#import "MSACChannelUnitConfiguration.h"
#import "MSACConstants+Internal.h"
#import "MSACMockUserDefaults.h"
#import "MSACSessionContextPrivate.h"
#import "MSACTestFrameworks.h"

@interface MSACServiceAbstractImplementation : MSACServiceAbstract <MSACServiceInternal>

@end

@implementation MSACServiceAbstractImplementation

@synthesize channelUnitConfiguration = _channelUnitConfiguration;

+ (instancetype)sharedInstance {
  static id sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  if ((self = [super init])) {
    _channelUnitConfiguration = [[MSACChannelUnitConfiguration alloc] initWithGroupId:[self groupId]
                                                                             priority:MSACPriorityDefault
                                                                        flushInterval:3.0
                                                                       batchSizeLimit:50
                                                                  pendingBatchesLimit:3];
  }
  return self;
}

+ (NSString *)serviceName {
  return @"Service";
}

- (void)startWithChannelGroup:(id<MSACChannelGroupProtocol>)channelGroup appSecret:(NSString *)appSecret {
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:nil fromApplication:YES];
}

- (MSACInitializationPriority)initializationPriority {
  return MSACInitializationPriorityDefault;
}

+ (NSString *)logTag {
  return @"MSServiceAbstractTest";
}

- (NSString *)groupId {
  return @"groupId";
}

@end

@interface MSACServiceAbstractTest : XCTestCase

@property(nonatomic) id settingsMock;
@property(nonatomic) id sessionContextMock;
@property(nonatomic) id channelGroupMock;
@property(nonatomic) id channelUnitMock;

/**
 * System Under test.
 */
@property(nonatomic) MSACServiceAbstractImplementation *abstractService;

@end

@implementation MSACServiceAbstractTest

- (void)setUp {
  [super setUp];
  [MSACAppCenter resetSharedInstance];

  // Set up the mocked storage.
  self.settingsMock = [MSACMockUserDefaults new];

  // Session context.
  [MSACSessionContext resetSharedInstance];
  self.sessionContextMock = OCMClassMock([MSACSessionContext class]);
  OCMStub([self.sessionContextMock sharedInstance]).andReturn(self.sessionContextMock);

  // Set up the mock channel.
  self.channelGroupMock = OCMClassMock([MSACChannelGroupDefault class]);
  self.channelUnitMock = OCMProtocolMock(@protocol(MSACChannelUnitProtocol));
  OCMStub([self.channelGroupMock alloc]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock initWithHttpClient:OCMOCK_ANY installId:OCMOCK_ANY logUrl:OCMOCK_ANY]).andReturn(self.channelGroupMock);
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(self.channelUnitMock);

  // System Under Test.
  self.abstractService = [MSACServiceAbstractImplementation new];
}

- (void)tearDown {
  [self.channelGroupMock stopMocking];
  [self.settingsMock stopMocking];
  [self.sessionContextMock stopMocking];
  [MSACAppCenter resetSharedInstance];
  [MSACSessionContext resetSharedInstance];
  [super tearDown];
}

- (void)testIsEnabledTrueByDefault {

  // When
  BOOL isEnabled = [self.abstractService isEnabled];

  // Then
  XCTAssertTrue(isEnabled);
}

- (void)testDisableService {

  // If
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];

  // When
  [self.abstractService setEnabled:NO];

  // Then
  XCTAssertFalse([self.abstractService isEnabled]);
}

- (void)testEnableService {

  // If
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];

  // When
  [self.abstractService setEnabled:YES];

  // Then
  XCTAssertTrue([self.abstractService isEnabled]);
}

- (void)testDisableServiceOnServiceDisabled {

  // If
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];

  // When
  [self.abstractService setEnabled:NO];

  // Then
  XCTAssertFalse([self.abstractService isEnabled]);
}

- (void)testEnableServiceOnServiceEnabled {

  // If
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];

  // When
  [self.abstractService setEnabled:YES];

  // Then
  XCTAssertTrue([self.abstractService isEnabled]);
}

- (void)testIsEnabledToPersistence {

  // If
  BOOL expected = NO;

  // When
  [self.abstractService setEnabled:expected];

  // Then
  XCTAssertTrue(self.abstractService.isEnabled == expected);

  // Also check that the sut did access the persistence.
  XCTAssertTrue([[self.settingsMock objectForKey:self.abstractService.isEnabledKey] boolValue] == expected);
}

- (void)testIsEnabledFromPersistence {

  // If
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];

  // Then
  XCTAssertFalse([self.abstractService isEnabled]);

  // If
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];

  // Then
  XCTAssertTrue([self.abstractService isEnabled]);
}

- (void)testCanBeUsed {

  // If
  [MSACAppCenter resetSharedInstance];

  // Then
  XCTAssertFalse([[MSACServiceAbstractImplementation sharedInstance] canBeUsed]);

  // When
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // Then
  XCTAssertTrue([[MSACServiceAbstractImplementation sharedInstance] canBeUsed]);
}

- (void)testEnableServiceOnCoreDisabled {

  // If
  [MSACAppCenter resetSharedInstance];
  [self.settingsMock setObject:@NO forKey:kMSACAppCenterIsEnabledKey];
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // When
  [[MSACServiceAbstractImplementation class] setEnabled:YES];

  // Then
  XCTAssertFalse([[MSACServiceAbstractImplementation class] isEnabled]);
}

- (void)testDisableServiceOnCoreEnabled {

  // If
  [MSACAppCenter resetSharedInstance];
  [self.settingsMock setObject:@YES forKey:kMSACAppCenterIsEnabledKey];
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // When
  [[MSACServiceAbstractImplementation class] setEnabled:NO];

  // Then
  XCTAssertFalse([[MSACServiceAbstractImplementation class] isEnabled]);
}

- (void)testEnableServiceOnCoreEnabled {

  // If
  [MSACAppCenter resetSharedInstance];
  [self.settingsMock setObject:@YES forKey:kMSACAppCenterIsEnabledKey];
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // When
  [[MSACServiceAbstractImplementation class] setEnabled:YES];

  // Then
  XCTAssertTrue([[MSACServiceAbstractImplementation class] isEnabled]);
}

- (void)testReenableCoreOnServiceDisabled {

  // If
  [self.settingsMock setObject:@YES forKey:kMSACAppCenterIsEnabledKey];
  [self.settingsMock setObject:@NO forKey:self.abstractService.isEnabledKey];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // When
  [MSACAppCenter setEnabled:YES];

  // Then
  XCTAssertTrue([[MSACServiceAbstractImplementation class] isEnabled]);
}

- (void)testReenableCoreOnServiceEnabled {

  // If
  [self.settingsMock setObject:@YES forKey:kMSACAppCenterIsEnabledKey];
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];
  [MSACAppCenter start:MSAC_UUID_STRING withServices:@ [[MSACServiceAbstractImplementation class]]];

  // When
  [MSACAppCenter setEnabled:YES];

  // Then
  XCTAssertTrue([[MSACServiceAbstractImplementation class] isEnabled]);
}

- (void)testLogDeletedOnDisabled {

  // If
  self.abstractService.channelGroup = self.channelGroupMock;
  self.abstractService.channelUnit = self.channelUnitMock;
  [self.settingsMock setObject:@YES forKey:self.abstractService.isEnabledKey];

  // When
  [self.abstractService setEnabled:NO];

  // Then
  // Check that log deletion has been triggered.
  OCMVerify([self.channelUnitMock setEnabled:NO andDeleteDataOnDisabled:YES]);

  // GroupId from the service must match the groupId used to delete logs.
  XCTAssertTrue(self.abstractService.channelUnitConfiguration.groupId == self.abstractService.groupId);
}

- (void)testEnableChannelUnitOnStartWithChannelGroup {

  // When
  [self.abstractService startWithChannelGroup:self.channelGroupMock appSecret:@"TestAppSecret"];

  // Then
  OCMVerify([self.channelUnitMock setEnabled:YES andDeleteDataOnDisabled:YES]);
}

- (void)testInitializationPriorityCorrect {
  XCTAssertTrue([self.abstractService initializationPriority] == MSACInitializationPriorityDefault);
}

- (void)testAppSecretRequiredByDefault {
  XCTAssertTrue([self.abstractService isAppSecretRequired]);
}

@end
