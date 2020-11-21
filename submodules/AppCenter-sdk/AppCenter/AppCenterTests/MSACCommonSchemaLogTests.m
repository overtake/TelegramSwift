// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppExtension.h"
#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACCommonSchemaLog.h"
#import "MSACConstants.h"
#import "MSACDevice.h"
#import "MSACLocExtension.h"
#import "MSACLogContainer.h"
#import "MSACModelTestsUtililty.h"
#import "MSACNetExtension.h"
#import "MSACOSExtension.h"
#import "MSACProtocolExtension.h"
#import "MSACSDKExtension.h"
#import "MSACTestFrameworks.h"
#import "MSACUserExtension.h"
#import "MSACUtility+Date.h"

@interface MSACCommonSchemaLogTests : XCTestCase
@property(nonatomic) MSACCommonSchemaLog *commonSchemaLog;
@property(nonatomic) NSMutableDictionary *csLogDummyValues;
@end

@implementation MSACCommonSchemaLogTests

- (void)setUp {
  [super setUp];
  id device = OCMClassMock([MSACDevice class]);
  OCMStub([device isValid]).andReturn(YES);
  NSDictionary *abstractDummies = [MSACModelTestsUtililty abstractLogDummies];
  self.csLogDummyValues = [@{
    kMSACCSVer : @"3.0",
    kMSACCSName : @"1DS",
    kMSACCSTime : abstractDummies[kMSACTimestamp],
    kMSACCSIKey : @"o:60cd0b94-6060-11e8-9c2d-fa7ae01bbebc",
    kMSACCSFlags : @(MSACFlagsNormal),
    kMSACCSExt : [self extWithDummyValues],
    kMSACCSData : [self dataWithDummyValues]
  } mutableCopy];
  [self.csLogDummyValues addEntriesFromDictionary:abstractDummies];
  self.commonSchemaLog = [self csLogWithDummyValues:self.csLogDummyValues];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - MSACCommonSchemaLog

- (void)testCSLogJSONSerializingToDictionary {

  // If
  MSACOrderedDictionary *expectedSerializedLog = [MSACOrderedDictionary new];
  [expectedSerializedLog setObject:@"3.0" forKey:kMSACCSVer];
  [expectedSerializedLog setObject:@"1DS" forKey:kMSACCSName];
  [expectedSerializedLog setObject:[MSACUtility dateToISO8601:self.csLogDummyValues[kMSACCSTime]] forKey:kMSACCSTime];
  [expectedSerializedLog setObject:@"o:60cd0b94-6060-11e8-9c2d-fa7ae01bbebc" forKey:kMSACCSIKey];
  [expectedSerializedLog setObject:@(MSACFlagsNormal) forKey:kMSACCSFlags];
  [expectedSerializedLog setObject:[self.csLogDummyValues[kMSACCSExt] serializeToDictionary] forKey:kMSACCSExt];
  [expectedSerializedLog setObject:[self.csLogDummyValues[kMSACCSData] serializeToDictionary] forKey:kMSACCSData];

  // When
  NSMutableDictionary *serializedLog = [self.commonSchemaLog serializeToDictionary];

  // Then
  XCTAssertNotNil(serializedLog);
  XCTAssertTrue([expectedSerializedLog isEqualToDictionary:serializedLog]);
}

- (void)testCSLogNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedCSLog = [MSACUtility archiveKeyedData:self.commonSchemaLog];
  MSACCommonSchemaLog *actualCSLog = (MSACCommonSchemaLog *)[MSACUtility unarchiveKeyedData:serializedCSLog];

  // Then
  XCTAssertNotNil(actualCSLog);
  XCTAssertEqualObjects(self.commonSchemaLog, actualCSLog);
  XCTAssertTrue([actualCSLog isMemberOfClass:[MSACCommonSchemaLog class]]);
  XCTAssertEqualObjects(actualCSLog.ver, self.csLogDummyValues[kMSACCSVer]);
  XCTAssertEqualObjects(actualCSLog.name, self.csLogDummyValues[kMSACCSName]);
  XCTAssertEqualObjects(actualCSLog.timestamp, self.csLogDummyValues[kMSACCSTime]);
  XCTAssertEqual(actualCSLog.popSample, [self.csLogDummyValues[kMSACCSPopSample] doubleValue]);
  XCTAssertEqualObjects(actualCSLog.iKey, self.csLogDummyValues[kMSACCSIKey]);
  XCTAssertEqual(actualCSLog.flags, [self.csLogDummyValues[kMSACCSFlags] longLongValue]);
  XCTAssertEqualObjects(actualCSLog.cV, self.csLogDummyValues[kMSACCSCV]);
  XCTAssertEqualObjects(actualCSLog.ext, self.csLogDummyValues[kMSACCSExt]);
  XCTAssertEqualObjects(actualCSLog.data, self.csLogDummyValues[kMSACCSData]);
}

- (void)testCSLogIsValid {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];

  // Then
  XCTAssertFalse([csLog isValid]);

  // If
  csLog.ver = self.csLogDummyValues[kMSACCSVer];

  // Then
  XCTAssertFalse([csLog isValid]);

  // If
  csLog.name = self.csLogDummyValues[kMSACCSName];

  // Then
  XCTAssertFalse([csLog isValid]);

  // If
  csLog.timestamp = self.csLogDummyValues[kMSACCSTime];

  // Then
  XCTAssertTrue([csLog isValid]);

  // IF
  [MSACModelTestsUtililty populateAbstractLogWithDummies:csLog];

  // Then
  XCTAssertTrue([csLog isValid]);
}

- (void)testCSLogIsEqual {

  // If
  MSACCommonSchemaLog *anotherCommonSchemaLog = [MSACCommonSchemaLog new];

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog = [self csLogWithDummyValues:self.csLogDummyValues];

  // Then
  XCTAssertEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.ver = @"2.0";

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.ver = self.csLogDummyValues[kMSACCSVer];
  anotherCommonSchemaLog.name = @"Alpha SDK";

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.name = self.csLogDummyValues[kMSACCSName];
  anotherCommonSchemaLog.timestamp = [NSDate date];

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.timestamp = self.csLogDummyValues[kMSACCSTime];
  anotherCommonSchemaLog.popSample = 101;

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.popSample = [self.csLogDummyValues[kMSACCSPopSample] doubleValue];
  anotherCommonSchemaLog.iKey = @"o:0bcff4a2-6377-11e8-adc0-fa7ae01bbebc";

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.iKey = self.csLogDummyValues[kMSACCSIKey];
  anotherCommonSchemaLog.flags = 31415927;

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.flags = [self.csLogDummyValues[kMSACCSFlags] longLongValue];
  anotherCommonSchemaLog.cV = @"HyCFaiQoBkyEp0L3.1.3";

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.cV = self.csLogDummyValues[kMSACCSCV];
  anotherCommonSchemaLog.ext = OCMClassMock([MSACCSExtensions class]);

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.ext = self.csLogDummyValues[kMSACCSExt];
  anotherCommonSchemaLog.data = OCMClassMock([MSACCSData class]);

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.data = self.csLogDummyValues[kMSACCSData];
  anotherCommonSchemaLog.flags = -1;

  // Then
  XCTAssertNotEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);

  // If
  anotherCommonSchemaLog.flags = [self.csLogDummyValues[kMSACCSFlags] longLongValue];

  // Then
  XCTAssertEqualObjects(anotherCommonSchemaLog, self.commonSchemaLog);
}

- (void)testOrderedDictionaryPerformance {
  NSMutableArray *logs = [NSMutableArray new];
  for (int i = 0; i < 10000; i++) {
    [logs addObject:self.commonSchemaLog];
  }
  MSACLogContainer *logContainer = [MSACLogContainer new];
  [logContainer setLogs:logs];
  [self measureBlock:^{
    [logContainer serializeLog];
  }];
}

#pragma mark - Helper

- (MSACCSExtensions *)extWithDummyValues {
  MSACCSExtensions *ext = [MSACCSExtensions new];
  ext.userExt = [self userExtWithDummyValues];
  ext.locExt = [self locExtWithDummyValues];
  ext.osExt = [self osExtWithDummyValues];
  ext.appExt = [self appExtWithDummyValues];
  ext.protocolExt = [self protocolExtWithDummyValues];
  ext.netExt = [self netExtWithDummyValues];
  ext.sdkExt = [self sdkExtWithDummyValues];
  return ext;
}

- (MSACUserExtension *)userExtWithDummyValues {
  MSACUserExtension *userExt = [MSACUserExtension new];
  userExt.localId = @"c:alice";
  userExt.locale = @"en-us";
  return userExt;
}

- (MSACLocExtension *)locExtWithDummyValues {
  MSACLocExtension *locExt = [MSACLocExtension new];
  locExt.tz = @"-05:00";
  return locExt;
}

- (MSACOSExtension *)osExtWithDummyValues {
  MSACOSExtension *osExt = [MSACOSExtension new];
  osExt.name = @"Android";
  osExt.ver = @"Android P";
  return osExt;
}

- (MSACAppExtension *)appExtWithDummyValues {
  MSACAppExtension *appExt = [MSACAppExtension new];
  appExt.appId = @"com.mamamia.bundle.id";
  appExt.ver = @"1.0.0";
  appExt.locale = @"fr-ca";
  appExt.userId = @"c:alice";
  return appExt;
}

- (MSACProtocolExtension *)protocolExtWithDummyValues {
  MSACProtocolExtension *protocolExt = [MSACProtocolExtension new];
  protocolExt.devMake = @"Samsung";
  protocolExt.devModel = @"Samsung Galaxy S8";
  return protocolExt;
}

- (MSACNetExtension *)netExtWithDummyValues {
  MSACNetExtension *netExt = [MSACNetExtension new];
  netExt.provider = @"M-Telecom";
  return netExt;
}

- (MSACSDKExtension *)sdkExtWithDummyValues {
  MSACSDKExtension *sdkExt = [MSACSDKExtension new];
  sdkExt.libVer = @"3.1.4";
  sdkExt.epoch = MSAC_UUID_STRING;
  sdkExt.seq = 1;
  sdkExt.installId = [NSUUID new];
  return sdkExt;
}

- (MSACCSData *)dataWithDummyValues {
  MSACCSData *data = [MSACCSData new];
  data.properties = [[MSACModelTestsUtililty unorderedDataDummies] copy];
  return data;
}

- (MSACCommonSchemaLog *)csLogWithDummyValues:(NSDictionary *)dummyValues {
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];

  /*
   * These are deliberately out of order to verify that they are reordered properly when serialized.
   * Correct order is ver, name, timestamp, (popSample), iKey, flags.
   */
  csLog.name = dummyValues[kMSACCSName];
  csLog.timestamp = dummyValues[kMSACCSTime];
  csLog.ver = dummyValues[kMSACCSVer];
  csLog.iKey = dummyValues[kMSACCSIKey];
  csLog.flags = [dummyValues[kMSACCSFlags] longLongValue];
  csLog.ext = dummyValues[kMSACCSExt];
  csLog.data = dummyValues[kMSACCSData];
  [MSACModelTestsUtililty populateAbstractLogWithDummies:csLog];
  return csLog;
}

@end
