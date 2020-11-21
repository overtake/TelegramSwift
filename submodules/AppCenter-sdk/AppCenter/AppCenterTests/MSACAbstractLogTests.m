// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAbstractLogInternal.h"
#import "MSACAbstractLogPrivate.h"
#import "MSACAppExtension.h"
#import "MSACCSExtensions.h"
#import "MSACDevice.h"
#import "MSACLocExtension.h"
#import "MSACNetExtension.h"
#import "MSACOSExtension.h"
#import "MSACProtocolExtension.h"
#import "MSACSDKExtension.h"
#import "MSACTestFrameworks.h"
#import "MSACUserExtension.h"
#import "MSACUtility.h"

@interface MSACAbstractLogTests : XCTestCase

@property(nonatomic, strong) MSACAbstractLog *sut;

@end

@implementation MSACAbstractLogTests

#pragma mark - Setup

- (void)setUp {
  [super setUp];
  self.sut = [MSACAbstractLog new];
  self.sut.type = @"fake";
  self.sut.timestamp = [NSDate dateWithTimeIntervalSince1970:0];
  self.sut.sid = @"FAKE-SESSION-ID";
  self.sut.distributionGroupId = @"FAKE-GROUP-ID";
  self.sut.userId = @"FAKE-USER-ID";
  self.sut.device = OCMPartialMock([MSACDevice new]);
}

#pragma mark - Tests

- (void)testInitializationWorks {
  XCTAssertNotNil(self.sut);
}

- (void)testSerializingToDictionaryWorks {

  // When
  NSMutableDictionary *actual = [self.sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"type"], equalTo(@"fake"));
  assertThat(actual[@"timestamp"], equalTo(@"1970-01-01T00:00:00.000Z"));
  assertThat(actual[@"sid"], equalTo(@"FAKE-SESSION-ID"));
  assertThat(actual[@"distributionGroupId"], equalTo(@"FAKE-GROUP-ID"));
  assertThat(actual[@"userId"], equalTo(@"FAKE-USER-ID"));
  assertThat(actual[@"device"], equalTo(@{}));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // When
  NSData *serializedLog = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedLog];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACAbstractLog class]));

  MSACAbstractLog *actualLog = actual;
  assertThat(actualLog.type, equalTo(self.sut.type));
  assertThat(actualLog.timestamp, equalTo(self.sut.timestamp));
  assertThat(actualLog.sid, equalTo(self.sut.sid));
  assertThat(actualLog.distributionGroupId, equalTo(self.sut.distributionGroupId));
  assertThat(actualLog.userId, equalTo(self.sut.userId));
  assertThat(actualLog.device, equalTo(self.sut.device));
}

- (void)testIsValid {

  // If
  id device = OCMClassMock([MSACDevice class]);
  OCMStub([device isValid]).andReturn(YES);
  self.sut.type = @"fake";
  self.sut.timestamp = [NSDate dateWithTimeIntervalSince1970:42];
  self.sut.device = device;

  // Then
  XCTAssertTrue([self.sut isValid]);

  // When
  self.sut.type = nil;
  self.sut.timestamp = [NSDate dateWithTimeIntervalSince1970:42];
  self.sut.device = device;

  // Then
  XCTAssertFalse([self.sut isValid]);

  // When
  self.sut.type = @"fake";
  self.sut.timestamp = nil;
  self.sut.device = device;

  // Then
  XCTAssertFalse([self.sut isValid]);

  // When
  self.sut.type = @"fake";
  self.sut.timestamp = [NSDate dateWithTimeIntervalSince1970:42];
  self.sut.device = nil;

  // Then
  XCTAssertFalse([self.sut isValid]);
}

- (void)testIsEqual {

  // If
  self.sut.tag = [NSObject new];
  MSACAbstractLog *log = [MSACAbstractLog new];
  log.type = self.sut.type;
  log.timestamp = self.sut.timestamp;
  log.sid = self.sut.sid;
  log.distributionGroupId = self.sut.distributionGroupId;
  log.userId = self.sut.userId;
  log.device = self.sut.device;
  log.tag = self.sut.tag;

  // Then
  XCTAssertTrue([self.sut isEqual:log]);

  // When
  self.sut.type = @"new-fake";

  // Then
  XCTAssertFalse([self.sut isEqual:log]);

  // When
  self.sut.tag = [NSObject new];

  // Then
  XCTAssertFalse([self.sut isEqual:log]);

  // When
  self.sut.type = @"fake";
  self.sut.distributionGroupId = @"FAKE-NEW-GROUP-ID";
  self.sut.tag = [NSObject new];

  // Then
  XCTAssertFalse([self.sut isEqual:log]);

  // When
  self.sut.distributionGroupId = @"FAKE-GROUP-ID";
  self.sut.userId = @"FAKE-NEW-USER-ID";

  // Then
  XCTAssertFalse([self.sut isEqual:log]);
}

- (void)testSerializingToJsonWorks {

  // When
  NSString *actual = [self.sut serializeLogWithPrettyPrinting:false];
  NSData *actualData = [actual dataUsingEncoding:NSUTF8StringEncoding];
  id actualDict = [NSJSONSerialization JSONObjectWithData:actualData options:0 error:nil];

  // Then
  assertThat(actualDict, instanceOf([NSDictionary class]));
  assertThat([actualDict objectForKey:@"type"], equalTo(@"fake"));
  assertThat([actualDict objectForKey:@"timestamp"], equalTo(@"1970-01-01T00:00:00.000Z"));
  assertThat([actualDict objectForKey:@"sid"], equalTo(@"FAKE-SESSION-ID"));
  assertThat([actualDict objectForKey:@"distributionGroupId"], equalTo(@"FAKE-GROUP-ID"));
  assertThat([actualDict objectForKey:@"userId"], equalTo(@"FAKE-USER-ID"));
  assertThat([actualDict objectForKey:@"device"], equalTo(@{}));
}

- (void)testTransmissionTargetsWork {

  // If
  NSString *transmissionTargetToken1 = @"t1";
  NSString *transmissionTargetToken = @"t2";

  // When
  [self.sut addTransmissionTargetToken:transmissionTargetToken1];
  [self.sut addTransmissionTargetToken:transmissionTargetToken1];
  [self.sut addTransmissionTargetToken:transmissionTargetToken];
  NSSet *transmissionTargets = [self.sut transmissionTargetTokens];

  // Then
  XCTAssertEqual([transmissionTargets count], (uint)2);
  XCTAssertTrue([transmissionTargets containsObject:transmissionTargetToken1]);
  XCTAssertTrue([transmissionTargets containsObject:transmissionTargetToken]);
}

- (void)testNoCommonSchemaLogCreatedWhenNilTargetTokenArray {

  // If
  self.sut.transmissionTargetTokens = nil;

  // When
  NSArray<MSACCommonSchemaLog *> *csLogs = [self.sut toCommonSchemaLogsWithFlags:MSACFlagsDefault];

  // Then
  XCTAssertNil(csLogs);
}

- (void)testNoCommonSchemaLogCreatedWhenEmptyTargetTokenArray {

  // If
  self.sut.transmissionTargetTokens = [@[] mutableCopy];

  // When
  NSArray<MSACCommonSchemaLog *> *csLogs = [self.sut toCommonSchemaLogsWithFlags:MSACFlagsDefault];

  // Then
  XCTAssertNil(csLogs);
}

- (void)testCommonSchemaLogsCorrectWhenConverted {

  // If
  NSArray *expectedIKeys = @[ @"o:iKey1", @"o:iKey2" ];
  NSSet *expectedTokens = [NSSet setWithArray:@[ @"iKey1-dummytoken", @"iKey2-dummytoken" ]];
  self.sut.transmissionTargetTokens = expectedTokens;
  OCMStub(self.sut.device.oemName).andReturn(@"fakeOem");
  OCMStub(self.sut.device.model).andReturn(@"fakeModel");
  OCMStub(self.sut.device.locale).andReturn(@"en_US");
  NSString *expectedLocale = @"en-US";
  OCMStub(self.sut.device.osVersion).andReturn(@"12.0.0");
  OCMStub(self.sut.device.osBuild).andReturn(@"F12332");
  NSString *expectedVersion = @"Version 12.0.0 (Build F12332)";
  OCMStub(self.sut.device.osName).andReturn(@"fakeOS");
  OCMStub(self.sut.device.appVersion).andReturn(@"1234");
  OCMStub(self.sut.device.appNamespace).andReturn(@"com.microsoft.tests");
  NSString *expectedAppId = @"I:com.microsoft.tests";
  OCMStub(self.sut.device.carrierName).andReturn(@"testCarrier");
  OCMStub(self.sut.device.sdkName).andReturn(@"AppCenter");
  OCMStub(self.sut.device.sdkVersion).andReturn(@"1.0.0");
  NSString *expectedLibVersion = @"AppCenter-1.0.0";
  OCMStub(self.sut.device.timeZoneOffset).andReturn(@100);
  NSString *expectedTimeZoneOffset = @"+01:40";
  id bundleMock = OCMClassMock([NSBundle class]);
  NSString *expectedAppLocale = @"fr_DE";
  OCMStub([bundleMock mainBundle]).andReturn(bundleMock);
  OCMStub([bundleMock preferredLocalizations]).andReturn(@[ expectedAppLocale ]);
  MSACFlags expectedFlags = MSACFlagsNormal;
  NSString *prefixedUserId = [NSString stringWithFormat:@"c:%@", self.sut.userId];

  // When
  NSArray<MSACCommonSchemaLog *> *csLogs = [self.sut toCommonSchemaLogsWithFlags:MSACFlagsNormal];

  // Then
  XCTAssertEqual(csLogs.count, expectedTokens.count);
  for (MSACCommonSchemaLog *log in csLogs) {

    // Root.
    for (NSString *token in log.transmissionTargetTokens) {
      XCTAssertTrue([expectedTokens containsObject:token]);
    }
    XCTAssertEqualObjects(log.ver, @"3.0");
    XCTAssertEqualObjects(self.sut.timestamp, log.timestamp);
    XCTAssertTrue([expectedIKeys containsObject:log.iKey]);
    XCTAssertEqual(expectedFlags, log.flags);

    // Extension.
    XCTAssertNotNil(log.ext);

    // Protocol extension.
    XCTAssertNotNil(log.ext.protocolExt);
    XCTAssertEqualObjects(log.ext.protocolExt.devMake, self.sut.device.oemName);
    XCTAssertEqualObjects(log.ext.protocolExt.devModel, self.sut.device.model);

    // User extension.
    XCTAssertNotNil(log.ext.userExt);
    XCTAssertEqualObjects(log.ext.userExt.localId, prefixedUserId);
    XCTAssertEqualObjects(log.ext.userExt.locale, expectedLocale);

    // OS extension.
    XCTAssertNotNil(log.ext.osExt);
    XCTAssertEqualObjects(log.ext.osExt.name, self.sut.device.osName);
    XCTAssertEqualObjects(log.ext.osExt.ver, expectedVersion);

    // App extension.
    XCTAssertNotNil(log.ext.appExt);
    XCTAssertEqualObjects(log.ext.appExt.appId, expectedAppId);
    XCTAssertEqualObjects(log.ext.appExt.ver, self.sut.device.appVersion);
    XCTAssertEqualObjects(log.ext.appExt.locale, expectedAppLocale);

    // Network extension.
    XCTAssertNotNil(log.ext.netExt);
    XCTAssertEqualObjects(log.ext.netExt.provider, self.sut.device.carrierName);

    // SDK extension.
    XCTAssertNotNil(log.ext.sdkExt);
    XCTAssertEqualObjects(log.ext.sdkExt.libVer, expectedLibVersion);

    // Loc extension.
    XCTAssertNotNil(log.ext.locExt);
    XCTAssertEqualObjects(log.ext.locExt.tz, expectedTimeZoneOffset);

    // Device extension.
    XCTAssertNotNil(log.ext.deviceExt);

    // Clean up.
    [bundleMock stopMocking];
  }
}

@end
