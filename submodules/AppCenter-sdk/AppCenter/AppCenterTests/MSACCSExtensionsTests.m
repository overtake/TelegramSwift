// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppExtension.h"
#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACDeviceExtension.h"
#import "MSACLocExtension.h"
#import "MSACMetadataExtension.h"
#import "MSACModelTestsUtililty.h"
#import "MSACNetExtension.h"
#import "MSACOSExtension.h"
#import "MSACOrderedDictionaryPrivate.h"
#import "MSACProtocolExtension.h"
#import "MSACSDKExtension.h"
#import "MSACTestFrameworks.h"
#import "MSACUserExtension.h"
#import "MSACUtility.h"

@interface MSACCSExtensionsTests : XCTestCase
@property(nonatomic) MSACCSExtensions *ext;
@property(nonatomic) NSMutableDictionary *extDummyValues;
@property(nonatomic) MSACUserExtension *userExt;
@property(nonatomic) NSDictionary *userExtDummyValues;
@property(nonatomic) MSACLocExtension *locExt;
@property(nonatomic) NSDictionary *locExtDummyValues;
@property(nonatomic) MSACOSExtension *osExt;
@property(nonatomic) NSDictionary *osExtDummyValues;
@property(nonatomic) MSACAppExtension *appExt;
@property(nonatomic) NSDictionary *appExtDummyValues;
@property(nonatomic) MSACProtocolExtension *protocolExt;
@property(nonatomic) NSDictionary *protocolExtDummyValues;
@property(nonatomic) MSACNetExtension *netExt;
@property(nonatomic) NSDictionary *netExtDummyValues;
@property(nonatomic) MSACSDKExtension *sdkExt;
@property(nonatomic) NSMutableDictionary *sdkExtDummyValues;
@property(nonatomic) MSACDeviceExtension *deviceExt;
@property(nonatomic) NSMutableDictionary *deviceExtDummyValues;
@property(nonatomic) MSACMetadataExtension *metadataExt;
@property(nonatomic) NSDictionary *metadataExtDummyValues;
@property(nonatomic) MSACCSData *data;
@property(nonatomic) NSDictionary *orderedDummyValues;
@property(nonatomic) NSDictionary *unorderedDummyValues;

@end

@implementation MSACCSExtensionsTests

- (void)setUp {
  [super setUp];

  // Set up all extensions with dummy values.
  self.userExtDummyValues = [MSACModelTestsUtililty userExtensionDummies];
  self.userExt = [MSACModelTestsUtililty userExtensionWithDummyValues:self.userExtDummyValues];
  self.locExtDummyValues = [MSACModelTestsUtililty locExtensionDummies];
  ;
  self.locExt = [MSACModelTestsUtililty locExtensionWithDummyValues:self.locExtDummyValues];
  self.osExtDummyValues = [MSACModelTestsUtililty osExtensionDummies];
  self.osExt = [MSACModelTestsUtililty osExtensionWithDummyValues:self.osExtDummyValues];
  self.appExtDummyValues = [MSACModelTestsUtililty appExtensionDummies];
  self.appExt = [MSACModelTestsUtililty appExtensionWithDummyValues:self.appExtDummyValues];
  self.protocolExtDummyValues = [MSACModelTestsUtililty protocolExtensionDummies];
  self.protocolExt = [MSACModelTestsUtililty protocolExtensionWithDummyValues:self.protocolExtDummyValues];
  self.netExtDummyValues = [MSACModelTestsUtililty netExtensionDummies];
  self.netExt = [MSACModelTestsUtililty netExtensionWithDummyValues:self.netExtDummyValues];
  self.sdkExtDummyValues = [MSACModelTestsUtililty sdkExtensionDummies];
  self.sdkExt = [MSACModelTestsUtililty sdkExtensionWithDummyValues:self.sdkExtDummyValues];
  self.deviceExtDummyValues = [MSACModelTestsUtililty deviceExtensionDummies];
  self.deviceExt = [MSACModelTestsUtililty deviceExtensionWithDummyValues:self.deviceExtDummyValues];
  self.metadataExtDummyValues = [MSACModelTestsUtililty metadataExtensionDummies];
  self.metadataExt = [MSACModelTestsUtililty metadataExtensionWithDummyValues:self.metadataExtDummyValues];
  self.orderedDummyValues = [MSACModelTestsUtililty orderedDataDummies];
  self.unorderedDummyValues = [MSACModelTestsUtililty unorderedDataDummies];
  self.data = [MSACModelTestsUtililty dataWithDummyValues:self.unorderedDummyValues];
  self.extDummyValues = [MSACModelTestsUtililty extensionDummies];
  self.ext = [MSACModelTestsUtililty extensionsWithDummyValues:self.extDummyValues];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - MSACCSExtensions

- (void)testExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.ext serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict[kMSACCSAppExt], [self.extDummyValues[kMSACCSAppExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSNetExt], [self.extDummyValues[kMSACCSNetExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSLocExt], [self.extDummyValues[kMSACCSLocExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSSDKExt], [self.extDummyValues[kMSACCSSDKExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSUserExt], [self.extDummyValues[kMSACCSUserExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSProtocolExt], [self.extDummyValues[kMSACCSProtocolExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSOSExt], [self.extDummyValues[kMSACCSOSExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSDeviceExt], [self.extDummyValues[kMSACCSDeviceExt] serializeToDictionary]);
  XCTAssertEqualObjects(dict[kMSACCSMetadataExt], [self.extDummyValues[kMSACCSMetadataExt] serializeToDictionary]);
}

- (void)testExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedExt = [MSACUtility archiveKeyedData:self.ext];
  MSACCSExtensions *actualExt = [MSACUtility unarchiveKeyedData:serializedExt];

  // Then
  XCTAssertNotNil(actualExt);
  XCTAssertEqualObjects(self.ext, actualExt);
  XCTAssertTrue([actualExt isMemberOfClass:[MSACCSExtensions class]]);
  XCTAssertEqualObjects(actualExt.metadataExt, self.extDummyValues[kMSACCSMetadataExt]);
  XCTAssertEqualObjects(actualExt.userExt, self.extDummyValues[kMSACCSUserExt]);
  XCTAssertEqualObjects(actualExt.locExt, self.extDummyValues[kMSACCSLocExt]);
  XCTAssertEqualObjects(actualExt.appExt, self.extDummyValues[kMSACCSAppExt]);
  XCTAssertEqualObjects(actualExt.protocolExt, self.extDummyValues[kMSACCSProtocolExt]);
  XCTAssertEqualObjects(actualExt.osExt, self.extDummyValues[kMSACCSOSExt]);
  XCTAssertEqualObjects(actualExt.netExt, self.extDummyValues[kMSACCSNetExt]);
  XCTAssertEqualObjects(actualExt.sdkExt, self.extDummyValues[kMSACCSSDKExt]);
}

- (void)testExtIsValid {

  // If
  MSACCSExtensions *ext = [MSACCSExtensions new];

  // Then
  XCTAssertTrue([ext isValid]);
}

- (void)testExtIsEqual {

  // If
  MSACCSExtensions *anotherExt = [MSACCSExtensions new];

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt = [MSACModelTestsUtililty extensionsWithDummyValues:self.extDummyValues];

  // Then
  XCTAssertEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.metadataExt = OCMClassMock([MSACMetadataExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.metadataExt = self.extDummyValues[kMSACCSMetadataExt];
  anotherExt.userExt = OCMClassMock([MSACUserExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.userExt = self.extDummyValues[kMSACCSUserExt];
  anotherExt.locExt = OCMClassMock([MSACLocExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.locExt = self.extDummyValues[kMSACCSLocExt];
  anotherExt.osExt = OCMClassMock([MSACOSExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.osExt = self.extDummyValues[kMSACCSOSExt];
  anotherExt.appExt = OCMClassMock([MSACAppExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.appExt = self.extDummyValues[kMSACCSAppExt];
  anotherExt.protocolExt = OCMClassMock([MSACProtocolExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.protocolExt = self.extDummyValues[kMSACCSProtocolExt];
  anotherExt.netExt = OCMClassMock([MSACNetExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);

  // If
  anotherExt.netExt = self.extDummyValues[kMSACCSNetExt];
  anotherExt.sdkExt = OCMClassMock([MSACSDKExtension class]);

  // Then
  XCTAssertNotEqualObjects(anotherExt, self.ext);
}

#pragma mark - MSACMetadataExtension

- (void)testMetadataExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.metadataExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.metadataExtDummyValues);
}

- (void)testMetadataExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedMetadataExt = [MSACUtility archiveKeyedData:self.metadataExt];
  MSACMetadataExtension *actualMetadataExt = (MSACMetadataExtension *)[MSACUtility unarchiveKeyedData:serializedMetadataExt];

  // Then
  XCTAssertNotNil(actualMetadataExt);
  XCTAssertEqualObjects(self.metadataExt, actualMetadataExt);
  XCTAssertTrue([actualMetadataExt isMemberOfClass:[MSACMetadataExtension class]]);
  XCTAssertEqualObjects(actualMetadataExt.metadata, self.metadataExtDummyValues);
}

- (void)testMetadataExtIsValid {

  // If
  MSACMetadataExtension *metadataExt = [MSACMetadataExtension new];

  // Then
  XCTAssertTrue([metadataExt isValid]);
}

- (void)testMetadataExtIsEqual {

  // If
  MSACMetadataExtension *anotherMetadataExt = [MSACMetadataExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherMetadataExt, self.metadataExt);

  // If
  anotherMetadataExt = [MSACModelTestsUtililty metadataExtensionWithDummyValues:self.metadataExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherMetadataExt, self.metadataExt);

  // If
  anotherMetadataExt.metadata = @{};

  // Then
  XCTAssertNotEqualObjects(anotherMetadataExt, self.metadataExt);
}

#pragma mark - MSACUserExtension

- (void)testUserExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.userExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict[kMSACUserLocalId], self.userExtDummyValues[kMSACUserLocalId]);
  XCTAssertEqualObjects(dict[kMSACUserLocale], self.userExtDummyValues[kMSACUserLocale]);
}

- (void)testUserExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedUserExt = [MSACUtility archiveKeyedData:self.userExt];
  MSACUserExtension *actualUserExt = (MSACUserExtension *)[MSACUtility unarchiveKeyedData:serializedUserExt];

  // Then
  XCTAssertNotNil(actualUserExt);
  XCTAssertEqualObjects(self.userExt, actualUserExt);
  XCTAssertTrue([actualUserExt isMemberOfClass:[MSACUserExtension class]]);
  XCTAssertEqualObjects(actualUserExt.localId, self.userExtDummyValues[kMSACUserLocalId]);
  XCTAssertEqualObjects(actualUserExt.locale, self.userExtDummyValues[kMSACUserLocale]);
}

- (void)testUserExtIsValid {

  // If
  MSACUserExtension *userExt = [MSACUserExtension new];

  // Then
  XCTAssertTrue([userExt isValid]);
}

- (void)testUserExtIsEqual {

  // If
  MSACUserExtension *anotherUserExt = [MSACUserExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherUserExt, self.userExt);

  // If
  anotherUserExt = [MSACModelTestsUtililty userExtensionWithDummyValues:self.userExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherUserExt, self.userExt);

  // If
  anotherUserExt.locale = @"fr-fr";

  // Then
  XCTAssertNotEqualObjects(anotherUserExt, self.userExt);

  // If
  anotherUserExt.locale = self.userExtDummyValues[kMSACUserLocale];
  anotherUserExt.localId = @"42";

  // Then
  XCTAssertNotEqualObjects(anotherUserExt, self.userExt);
}

#pragma mark - MSACLocExtension

- (void)testLocExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.locExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict[kMSACTimezone], self.locExtDummyValues[kMSACTimezone]);
}

- (void)testLocExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedlocExt = [MSACUtility archiveKeyedData:self.locExt];
  MSACLocExtension *actualLocExt = (MSACLocExtension *)[MSACUtility unarchiveKeyedData:serializedlocExt];

  // Then
  XCTAssertNotNil(actualLocExt);
  XCTAssertEqualObjects(self.locExt, actualLocExt);
  XCTAssertTrue([actualLocExt isMemberOfClass:[MSACLocExtension class]]);
  XCTAssertEqualObjects(actualLocExt.tz, self.locExtDummyValues[kMSACTimezone]);
}

- (void)testLocExtIsValid {

  // If
  MSACLocExtension *locExt = [MSACLocExtension new];

  // Then
  XCTAssertTrue([locExt isValid]);
}

- (void)testLocExtIsEqual {

  // If
  MSACLocExtension *anotherLocExt = [MSACLocExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherLocExt, self.locExt);

  // If
  anotherLocExt = [MSACModelTestsUtililty locExtensionWithDummyValues:self.locExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherLocExt, self.locExt);

  // If
  anotherLocExt.tz = @"+02:00";

  // Then
  XCTAssertNotEqualObjects(anotherLocExt, self.locExt);
}

#pragma mark - MSACOSExtension

- (void)testOSExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.osExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.osExtDummyValues);
}

- (void)testOSExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedOSExt = [MSACUtility archiveKeyedData:self.osExt];
  MSACOSExtension *actualOSExt = (MSACOSExtension *)[MSACUtility unarchiveKeyedData:serializedOSExt];

  // Then
  XCTAssertNotNil(actualOSExt);
  XCTAssertEqualObjects(self.osExt, actualOSExt);
  XCTAssertTrue([actualOSExt isMemberOfClass:[MSACOSExtension class]]);
  XCTAssertEqualObjects(actualOSExt.name, self.osExtDummyValues[kMSACOSName]);
  XCTAssertEqualObjects(actualOSExt.ver, self.osExtDummyValues[kMSACOSVer]);
}

- (void)testOSExtIsValid {

  // If
  MSACOSExtension *osExt = [MSACOSExtension new];

  // Then
  XCTAssertTrue([osExt isValid]);
}

- (void)testOSExtIsEqual {

  // If
  MSACOSExtension *anotherOSExt = [MSACOSExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherOSExt, self.osExt);

  // If
  anotherOSExt = [MSACModelTestsUtililty osExtensionWithDummyValues:self.osExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherOSExt, self.osExt);

  // If
  anotherOSExt.name = @"macOS";

  // Then
  XCTAssertNotEqualObjects(anotherOSExt, self.osExt);

  // If
  anotherOSExt.name = self.osExtDummyValues[kMSACOSName];
  anotherOSExt.ver = @"10.13.4";

  // Then
  XCTAssertNotEqualObjects(anotherOSExt, self.osExt);
}

#pragma mark - MSACAppExtension

- (void)testAppExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.appExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.appExtDummyValues);
}

- (void)testAppExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedAppExt = [MSACUtility archiveKeyedData:self.appExt];
  MSACAppExtension *actualAppExt = (MSACAppExtension *)[MSACUtility unarchiveKeyedData:serializedAppExt];

  // Then
  XCTAssertNotNil(actualAppExt);
  XCTAssertEqualObjects(self.appExt, actualAppExt);
  XCTAssertTrue([actualAppExt isMemberOfClass:[MSACAppExtension class]]);
  XCTAssertEqualObjects(actualAppExt.appId, self.appExtDummyValues[kMSACAppId]);
  XCTAssertEqualObjects(actualAppExt.ver, self.appExtDummyValues[kMSACAppVer]);
  XCTAssertEqualObjects(actualAppExt.locale, self.appExtDummyValues[kMSACAppLocale]);
  XCTAssertEqualObjects(actualAppExt.userId, self.appExtDummyValues[kMSACAppUserId]);
}

- (void)testAppExtIsValid {

  // If
  MSACAppExtension *appExt = [MSACAppExtension new];

  // Then
  XCTAssertTrue([appExt isValid]);
}

- (void)testAppExtIsEqual {

  // If
  MSACAppExtension *anotherAppExt = [MSACAppExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherAppExt, self.appExt);

  // If
  anotherAppExt = [MSACModelTestsUtililty appExtensionWithDummyValues:self.appExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherAppExt, self.appExt);

  // If
  anotherAppExt.appId = @"com.another.bundle.id";

  // Then
  XCTAssertNotEqualObjects(anotherAppExt, self.appExt);

  // If
  anotherAppExt.appId = self.appExtDummyValues[kMSACAppId];
  anotherAppExt.ver = @"10.13.4";

  // Then
  XCTAssertNotEqualObjects(anotherAppExt, self.appExt);

  // If
  anotherAppExt.ver = self.appExtDummyValues[kMSACAppVer];
  anotherAppExt.locale = @"fr-ca";

  // Then
  XCTAssertNotEqualObjects(anotherAppExt, self.appExt);

  // If
  anotherAppExt.locale = self.appExtDummyValues[kMSACAppLocale];
  anotherAppExt.userId = @"c:charlie";

  // Then
  XCTAssertNotEqualObjects(anotherAppExt, self.appExt);
}

#pragma mark - MSACProtocolExtension

- (void)testProtocolExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.protocolExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.protocolExtDummyValues);
}

- (void)testProtocolExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedProtocolExt = [MSACUtility archiveKeyedData:self.protocolExt];
  MSACProtocolExtension *actualProtocolExt = (MSACProtocolExtension *)[MSACUtility unarchiveKeyedData:serializedProtocolExt];

  // Then
  XCTAssertNotNil(actualProtocolExt);
  XCTAssertEqualObjects(self.protocolExt, actualProtocolExt);
  XCTAssertTrue([actualProtocolExt isMemberOfClass:[MSACProtocolExtension class]]);
  XCTAssertEqualObjects(actualProtocolExt.ticketKeys, self.protocolExtDummyValues[kMSACTicketKeys]);
  XCTAssertEqualObjects(actualProtocolExt.devMake, self.protocolExtDummyValues[kMSACDevMake]);
  XCTAssertEqualObjects(actualProtocolExt.devModel, self.protocolExtDummyValues[kMSACDevModel]);
}

- (void)testProtocolExtIsValid {

  // If
  MSACProtocolExtension *protocolExt = [MSACProtocolExtension new];

  // Then
  XCTAssertTrue([protocolExt isValid]);
}

- (void)testProtocolExtIsEqual {

  // If
  MSACProtocolExtension *anotherProtocolExt = [MSACProtocolExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherProtocolExt, self.protocolExt);

  // If
  anotherProtocolExt = [MSACModelTestsUtililty protocolExtensionWithDummyValues:self.protocolExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherProtocolExt, self.protocolExt);

  // If
  anotherProtocolExt.devMake = @"Android";

  // Then
  XCTAssertNotEqualObjects(anotherProtocolExt, self.protocolExt);

  // If
  anotherProtocolExt.devMake = self.protocolExtDummyValues[kMSACDevMake];
  anotherProtocolExt.devModel = @"Samsung Galaxy 8";

  // Then
  XCTAssertNotEqualObjects(anotherProtocolExt, self.protocolExt);
}

#pragma mark - MSACNetExtension

- (void)testNetExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.netExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.netExtDummyValues);
}

- (void)testNetExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedNetExt = [MSACUtility archiveKeyedData:self.netExt];
  MSACNetExtension *actualNetExt = (MSACNetExtension *)[MSACUtility unarchiveKeyedData:serializedNetExt];

  // Then
  XCTAssertNotNil(actualNetExt);
  XCTAssertEqualObjects(self.netExt, actualNetExt);
  XCTAssertTrue([actualNetExt isMemberOfClass:[MSACNetExtension class]]);
  XCTAssertEqualObjects(actualNetExt.provider, self.netExtDummyValues[kMSACNetProvider]);
}

- (void)testNetExtIsValid {

  // If
  MSACNetExtension *netExt = [MSACNetExtension new];

  // Then
  XCTAssertTrue([netExt isValid]);
}

- (void)testNetExtIsEqual {

  // If
  MSACNetExtension *anotherNetExt = [MSACNetExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherNetExt, self.netExt);

  // If
  anotherNetExt = [MSACModelTestsUtililty netExtensionWithDummyValues:self.netExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherNetExt, self.netExt);

  // If
  anotherNetExt.provider = @"Sprint";

  // Then
  XCTAssertNotEqualObjects(anotherNetExt, self.netExt);
}

#pragma mark - MSACSDKExtension

- (void)testSDKExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.sdkExt serializeToDictionary];

  // Then
  self.sdkExtDummyValues[kMSACSDKInstallId] = [((NSUUID *)self.sdkExtDummyValues[kMSACSDKInstallId]) UUIDString];
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.sdkExtDummyValues);
}

- (void)testSDKExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedSDKExt = [MSACUtility archiveKeyedData:self.sdkExt];
  MSACSDKExtension *actualSDKExt = (MSACSDKExtension *)[MSACUtility unarchiveKeyedData:serializedSDKExt];

  // Then
  XCTAssertNotNil(actualSDKExt);
  XCTAssertEqualObjects(self.sdkExt, actualSDKExt);
  XCTAssertTrue([actualSDKExt isMemberOfClass:[MSACSDKExtension class]]);
  XCTAssertEqualObjects(actualSDKExt.libVer, self.sdkExtDummyValues[kMSACSDKLibVer]);
  XCTAssertEqualObjects(actualSDKExt.epoch, self.sdkExtDummyValues[kMSACSDKEpoch]);
  XCTAssertTrue(actualSDKExt.seq == [self.sdkExtDummyValues[kMSACSDKSeq] longLongValue]);
  XCTAssertEqualObjects(actualSDKExt.installId, self.sdkExtDummyValues[kMSACSDKInstallId]);
}

- (void)testSDKExtIsValid {

  // If
  MSACSDKExtension *sdkExt = [MSACSDKExtension new];

  // Then
  XCTAssertTrue([sdkExt isValid]);
}

- (void)testSDKExtIsEqual {

  // If
  MSACSDKExtension *anotherSDKExt = [MSACSDKExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherSDKExt, self.sdkExt);

  // If
  anotherSDKExt = [MSACModelTestsUtililty sdkExtensionWithDummyValues:self.sdkExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherSDKExt, self.sdkExt);

  // If
  anotherSDKExt.libVer = @"2.1.0";

  // Then
  XCTAssertNotEqualObjects(anotherSDKExt, self.sdkExt);

  // If
  anotherSDKExt.libVer = self.sdkExtDummyValues[kMSACSDKLibVer];
  anotherSDKExt.epoch = @"other_epoch_value";

  // Then
  XCTAssertNotEqualObjects(anotherSDKExt, self.sdkExt);

  // If
  anotherSDKExt.epoch = self.sdkExtDummyValues[kMSACSDKEpoch];
  anotherSDKExt.seq = 2;

  // Then
  XCTAssertNotEqualObjects(anotherSDKExt, self.sdkExt);

  // If
  anotherSDKExt.seq = [self.sdkExtDummyValues[kMSACSDKSeq] longLongValue];
  anotherSDKExt.installId = [NSUUID new];

  // Then
  XCTAssertNotEqualObjects(anotherSDKExt, self.appExt);
}

#pragma mark - MSACDeviceExtension

- (void)testDeviceExtJSONSerializingToDictionary {

  // When
  NSMutableDictionary *dict = [self.deviceExt serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);
  XCTAssertEqualObjects(dict, self.deviceExtDummyValues);
}

- (void)testDeviceExtNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedDeviceExt = [MSACUtility archiveKeyedData:self.deviceExt];
  MSACDeviceExtension *actualDeviceExt = (MSACDeviceExtension *)[MSACUtility unarchiveKeyedData:serializedDeviceExt];

  // Then
  XCTAssertNotNil(actualDeviceExt);
  XCTAssertEqualObjects(self.deviceExt, actualDeviceExt);
  XCTAssertTrue([actualDeviceExt isMemberOfClass:[MSACDeviceExtension class]]);
  XCTAssertEqualObjects(actualDeviceExt.localId, self.deviceExtDummyValues[kMSACDeviceLocalId]);
}

- (void)testDeviceExtIsValid {

  // When
  MSACDeviceExtension *deviceExt = [MSACDeviceExtension new];

  // Then
  XCTAssertTrue([deviceExt isValid]);
}

- (void)testDeviceExtIsEqual {

  // When
  MSACDeviceExtension *anotherDeviceExt = [MSACDeviceExtension new];

  // Then
  XCTAssertNotEqualObjects(anotherDeviceExt, self.deviceExt);

  // When
  anotherDeviceExt = [MSACModelTestsUtililty deviceExtensionWithDummyValues:self.deviceExtDummyValues];

  // Then
  XCTAssertEqualObjects(anotherDeviceExt, self.deviceExt);

  // When
  anotherDeviceExt.localId = [[[NSUUID alloc] initWithUUIDString:@"11111111-1111-1111-1111-11111111111"] UUIDString];

  // Then
  XCTAssertNotEqualObjects(anotherDeviceExt, self.deviceExt);
}

#pragma mark - MSACCSData

- (void)testDataJSONSerializingToDictionaryIsOrdered {

  // When
  MSACOrderedDictionary *dict = (MSACOrderedDictionary *)[self.data serializeToDictionary];

  // Then
  XCTAssertNotNil(dict);

  // Only verify the order for baseType and baseData fields.
  XCTAssertTrue([dict.order[0] isEqualToString:@"baseType"]);
  XCTAssertTrue([dict.order[1] isEqualToString:@"baseData"]);
  XCTAssertEqualObjects(dict[@"aKey"], @"aValue");
  XCTAssertEqualObjects(dict[@"anested.key"], @"anothervalue");
  XCTAssertEqualObjects(dict[@"anotherkey"], @"yetanothervalue");
}

- (void)testDataNSCodingSerializationAndDeserialization {

  // When
  NSData *serializedData = [MSACUtility archiveKeyedData:self.data];
  MSACCSData *actualData = (MSACCSData *)[MSACUtility unarchiveKeyedData:serializedData];

  // Then
  XCTAssertNotNil(actualData);
  XCTAssertEqualObjects(self.data, actualData);
  XCTAssertTrue([actualData isMemberOfClass:[MSACCSData class]]);
  XCTAssertEqualObjects(actualData.properties, self.orderedDummyValues);
}

- (void)testInvalidDataNSCodingDeserialization {

  // When
  MSACCSData *actualData = (MSACCSData *)[MSACUtility unarchiveKeyedData:@"invalid data"];

  // Then
  XCTAssertNil(nil);
}

- (void)testDataIsValid {

  // If
  MSACCSData *data = [MSACCSData new];

  // Then
  XCTAssertTrue([data isValid]);
}

- (void)testDataIsEqual {

  // If
  MSACCSData *anotherData = [MSACCSData new];

  // Then
  XCTAssertNotEqualObjects(anotherData, self.data);

  // If
  anotherData = [MSACModelTestsUtililty dataWithDummyValues:self.unorderedDummyValues];

  // Then
  XCTAssertEqualObjects(anotherData, self.data);

  // If
  anotherData.properties = [@{@"part.c.key" : @"part.c.value"} mutableCopy];

  // Then
  XCTAssertNotEqualObjects(anotherData, self.data);
}

@end
