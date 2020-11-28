// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAbstractLogInternal.h"
#import "MSACAnalyticsConstants.h"
#import "MSACAppExtension.h"
#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACDeviceInternal.h"
#import "MSACEventLogPrivate.h"
#import "MSACEventPropertiesInternal.h"
#import "MSACLocExtension.h"
#import "MSACMetadataExtension.h"
#import "MSACNetExtension.h"
#import "MSACOSExtension.h"
#import "MSACProtocolExtension.h"
#import "MSACSDKExtension.h"
#import "MSACStringTypedProperty.h"
#import "MSACTestFrameworks.h"
#import "MSACUserExtension.h"
#import "MSACUserIdContext.h"
#import "MSACUtility+Date.h"
#import "MSACUtility.h"

@interface MSACEventLogTests : XCTestCase

@property(nonatomic) MSACEventLog *sut;

@end

@implementation MSACEventLogTests

#pragma mark - Houskeeping

- (void)setUp {
  [super setUp];
  self.sut = [MSACEventLog new];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Tests

- (void)testSerializingEventToDictionaryWorks {

  // If
  NSString *typeName = @"event";
  NSString *eventId = MSAC_UUID_STRING;
  NSString *eventName = @"eventName";
  MSACDevice *device = [MSACDevice new];
  NSString *sessionId = @"1234567890";
  NSDictionary *properties = @{@"Key" : @"Value"};
  NSDate *timestamp = [NSDate date];

  self.sut.eventId = eventId;
  self.sut.name = eventName;
  self.sut.device = device;
  self.sut.timestamp = timestamp;
  self.sut.sid = sessionId;
  self.sut.properties = properties;

  // When
  NSMutableDictionary *actual = [self.sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"id"], equalTo(eventId));
  assertThat(actual[@"name"], equalTo(eventName));
  assertThat(actual[@"device"], notNilValue());
  assertThat(actual[@"sid"], equalTo(sessionId));
  assertThat(actual[@"type"], equalTo(typeName));
  assertThat(actual[@"properties"], equalTo(properties));
  assertThat(actual[@"device"], notNilValue());
  assertThat(actual[@"timestamp"], equalTo([MSACUtility dateToISO8601:timestamp]));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  NSString *typeName = @"event";
  NSString *eventId = MSAC_UUID_STRING;
  NSString *eventName = @"eventName";
  MSACDevice *device = [MSACDevice new];
  NSString *sessionId = @"1234567890";
  NSDate *timestamp = [NSDate date];
  NSDictionary *properties = @{@"Key" : @"Value"};

  self.sut.eventId = eventId;
  self.sut.name = eventName;
  self.sut.device = device;
  self.sut.timestamp = timestamp;
  self.sut.sid = sessionId;
  self.sut.properties = properties;

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACEventLog class]));
  MSACEventLog *actualEvent = actual;
  assertThat(actualEvent.name, equalTo(eventName));
  assertThat(actualEvent.eventId, equalTo(eventId));
  assertThat(actualEvent.device, notNilValue());
  assertThat(actualEvent.timestamp, equalTo(timestamp));
  assertThat(actualEvent.type, equalTo(typeName));
  assertThat(actualEvent.sid, equalTo(sessionId));
  assertThat(actualEvent.properties, equalTo(properties));
  XCTAssertTrue([self.sut isEqual:actualEvent]);
}

- (void)testIsValid {

  // If
  self.sut.device = OCMClassMock([MSACDevice class]);
  OCMStub([self.sut.device isValid]).andReturn(YES);
  self.sut.timestamp = [NSDate date];
  self.sut.sid = @"1234567890";

  // Then
  XCTAssertFalse([self.sut isValid]);

  // When
  self.sut.eventId = MSAC_UUID_STRING;

  // Then
  XCTAssertFalse([self.sut isValid]);

  // When
  self.sut.name = @"eventName";

  // Then
  XCTAssertTrue([self.sut isValid]);
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([self.sut isEqual:nil]);
}

- (void)testConvertACPropertiesToCSPropertiesWhenACPropertiesNil {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertNil(csLog.data.properties);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testConvertDateTimePropertyToCSProperty {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:10000];
  [acProperties setDate:date forKey:@"time"];
  self.sut.typedProperties = acProperties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties[@"time"], [MSACUtility dateToISO8601:date]);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata[kMSACFieldDelimiter][@"time"], @(kMSACDateTimeMetadataTypeId));
}

- (void)testConvertLongPropertyToCSProperty {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  int64_t largeNumber = 1234567890;
  [acProperties setInt64:largeNumber forKey:@"largeNumber"];
  self.sut.typedProperties = acProperties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties[@"largeNumber"], @(largeNumber));
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata[kMSACFieldDelimiter][@"largeNumber"], @(kMSACLongMetadataTypeId));
}

- (void)testConvertDoublePropertyToCSProperty {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  double pi = 3.1415926;
  [acProperties setDouble:pi forKey:@"pi"];
  self.sut.typedProperties = acProperties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties[@"pi"], @(pi));
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata[kMSACFieldDelimiter][@"pi"], @(kMSACDoubleMetadataTypeId));
}

- (void)testConvertStringPropertyToCSProperty {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  NSString *stringValue = @"hello";
  [acProperties setString:stringValue forKey:@"text"];
  self.sut.typedProperties = acProperties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties[@"text"], stringValue);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testConvertBooleanPropertyToCSProperty {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  BOOL boolValue = YES;
  [acProperties setBool:boolValue forKey:@"BoolKey"];
  self.sut.typedProperties = acProperties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties[@"BoolKey"], @(boolValue));
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testConvertACPropertiesToCSPropertiesWhenPropertiesAreNotNested {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setString:@"value" forKey:@"key"];
  [acProperties setString:@"value2" forKey:@"key2"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties = @{@"key" : @"value", @"key2" : @"value2"};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
}

- (void)testConvertACPropertiesToCSPropertiesWhenPropertiesAreNested {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setInt64:1 forKey:@"p.a"];
  [acProperties setDouble:2.0 forKey:@"p.b"];
  [acProperties setBool:YES forKey:@"p.c"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties = @{@"p" : @{@"a" : @1, @"b" : @2.0, @"c" : @YES}};
  NSDictionary *expectedMetadata = @{@"f" : @{@"p" : @{@"f" : @{@"a" : @(kMSACLongMetadataTypeId), @"b" : @(kMSACDoubleMetadataTypeId)}}}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
}

- (void)testConvertACPropertiesToCSPropertiesWhenPropertiesAreNestedWithSiblings {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setString:@"value" forKey:@"key"];
  [acProperties setString:@"1" forKey:@"nes.a"];
  [acProperties setString:@"2" forKey:@"nes.t.ed"];
  [acProperties setString:@"3" forKey:@"nes.t.ed2"];
  [acProperties setString:@"value2" forKey:@"key2"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedResult = @{@"key" : @"value", @"nes" : @{@"a" : @"1", @"t" : @{@"ed" : @"2", @"ed2" : @"3"}}, @"key2" : @"value2"};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedResult);
}

- (void)testPropertiesAreNotNestedWhenAtTheSameDepth {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setInt64:1 forKey:@"a.b"];
  [acProperties setDouble:2.2 forKey:@"b.c"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties = @{@"a" : @{@"b" : @1}, @"b" : @{@"c" : @2.2}};
  NSDictionary *expectedMetadata =
      @{@"f" : @{@"a" : @{@"f" : @{@"b" : @(kMSACLongMetadataTypeId)}}, @"b" : @{@"f" : @{@"c" : @(kMSACDoubleMetadataTypeId)}}}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
}

- (void)testMetadataDoesNotCreateLevelsForPropertyWhenPropertyIsString {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setInt64:1 forKey:@"a.b"];
  [acProperties setString:@"2.2" forKey:@"b.c"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties = @{@"a" : @{@"b" : @1}, @"b" : @{@"c" : @"2.2"}};
  NSDictionary *expectedMetadata = @{
    @"f" : @{
      @"a" : @{@"f" : @{@"b" : @(kMSACLongMetadataTypeId)}},
    }
  };

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
}

- (void)testOverridePropertiesWhenStringPropertyIsDeeper {
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];

  // set "a.b" property first, "a.b.c.d" property later.
  [acProperties setDouble:1.4 forKey:@"a.b"];
  [acProperties setString:@"hello" forKey:@"a.b.c.d"];
  self.sut.typedProperties = acProperties;
  [self setupAndAssert:csLog];

  // reset
  csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  acProperties = [MSACEventProperties new];

  // set "a.b.c.d" property first, "a.b" property later.
  [acProperties setString:@"hello" forKey:@"a.b.c.d"];
  [acProperties setDouble:1.4 forKey:@"a.b"];
  self.sut.typedProperties = acProperties;
  [self setupAndAssert:csLog];
}

- (void)testConvertACPropertiesToCSPropertiesWithPartBData {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setInt64:1 forKey:@"p.a"];
  [acProperties setDouble:2.0 forKey:@"p.b"];
  [acProperties setBool:YES forKey:@"p.c"];
  [acProperties setInt64:6 forKey:@"baseData.long"];
  [acProperties setString:@"hello" forKey:@"baseData.string"];
  [acProperties setString:@"type" forKey:@"baseType"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties =
      @{@"p" : @{@"a" : @1, @"b" : @2.0, @"c" : @YES}, @"baseData" : @{@"long" : @6, @"string" : @"hello"}, @"baseType" : @"type"};
  NSDictionary *expectedMetadata = @{
    @"f" : @{
      @"p" : @{@"f" : @{@"a" : @(kMSACLongMetadataTypeId), @"b" : @(kMSACDoubleMetadataTypeId)}},
      @"baseData" : @{@"f" : @{@"long" : @(kMSACLongMetadataTypeId)}}
    }
  };

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
}

- (void)setupAndAssert:(MSACCommonSchemaLog *)csLog {

  // If
  NSDictionary *possibleProperties1 = @{@"a" : @{@"b" : @1.4}};
  NSDictionary *possibleProperties2 = @{@"a" : @{@"b" : @{@"c" : @{@"d" : @"hello"}}}};
  NSDictionary *possibleMetadata1 = @{@"f" : @{@"a" : @{@"f" : @{@"b" : @(kMSACDoubleMetadataTypeId)}}}};
  NSDictionary *possibleMetadata2 = nil;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual([csLog.data.properties count], 1);

  // Since there is no guarantee which property will overwrite the other, test both possibilities.
  if ([csLog.data.properties isEqualToDictionary:possibleProperties1]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata1);
  } else if ([csLog.data.properties isEqualToDictionary:possibleProperties2]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata2);
  } else {
    XCTFail(@"csLog.data.properties did not equal either expectation");
  }
}

- (void)testOverridePropertiesWhenLongPropertyIsDeeper {
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];

  // set "a.b" property first, "a.b.c.d" property later.
  [acProperties setString:@"hello" forKey:@"a.b"];
  [acProperties setInt64:249 forKey:@"a.b.c.d"];
  self.sut.typedProperties = acProperties;
  [self setupPropertiesAndAssert:csLog];

  // reset
  csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  acProperties = [MSACEventProperties new];

  // set "a.b.c.d" property first, "a.b" property later.
  [acProperties setInt64:249 forKey:@"a.b.c.d"];
  [acProperties setString:@"hello" forKey:@"a.b"];
  self.sut.typedProperties = acProperties;
  [self setupPropertiesAndAssert:csLog];
}

- (void)setupPropertiesAndAssert:(MSACCommonSchemaLog *)csLog {

  // If
  NSDictionary *possibleProperties1 = @{@"a" : @{@"b" : @"hello"}};
  NSDictionary *possibleProperties2 = @{@"a" : @{@"b" : @{@"c" : @{@"d" : @249}}}};
  NSDictionary *possibleMetadata1 = nil;
  NSDictionary *possibleMetadata2 =
      @{@"f" : @{@"a" : @{@"f" : @{@"b" : @{@"f" : @{@"c" : @{@"f" : @{@"d" : @(kMSACLongMetadataTypeId)}}}}}}}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual([csLog.data.properties count], 1);

  // Since there is no guarantee which property will overwrite the other, test both possibilities.
  if ([csLog.data.properties isEqualToDictionary:possibleProperties1]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata1);
  } else if ([csLog.data.properties isEqualToDictionary:possibleProperties2]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata2);
  } else {
    XCTFail(@"csLog.data.properties did not equal either expectation");
  }
}

- (void)testOverrideValueToValueProperties {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setInt64:123 forKey:@"a.b"];
  [acProperties setDouble:2.43 forKey:@"a.b"];
  self.sut.typedProperties = acProperties;
  NSDictionary *possibleProperties1 = @{@"a" : @{@"b" : @123}};
  NSDictionary *possibleProperties2 = @{@"a" : @{@"b" : @2.43}};
  NSDictionary *possibleMetadata1 = @{@"f" : @{@"a" : @{@"f" : @{@"b" : @(kMSACLongMetadataTypeId)}}}};
  NSDictionary *possibleMetadata2 = @{@"f" : @{@"a" : @{@"f" : @{@"b" : @(kMSACDoubleMetadataTypeId)}}}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual([csLog.data.properties count], 1);

  // Since there is no guarantee which property will overwrite the other, test both possibilities.
  if ([csLog.data.properties isEqualToDictionary:possibleProperties1]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata1);
  } else if ([csLog.data.properties isEqualToDictionary:possibleProperties2]) {
    XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, possibleMetadata2);
  } else {
    XCTFail(@"csLog.data.properties did not equal either expectation");
  }
}

- (void)testConversionWhenSiblingsHaveDifferentTypesAndOnlyOneNeedsMetadataAndTheyAreOneLevelDeep {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *acProperties = [MSACEventProperties new];
  [acProperties setString:@"hello" forKey:@"a.b"];
  [acProperties setInt64:123 forKey:@"a.c"];
  [acProperties setString:@"hello" forKey:@"a.e"];
  self.sut.typedProperties = acProperties;
  NSDictionary *expectedProperties = @{@"a" : @{@"c" : @123, @"b" : @"hello", @"e" : @"hello"}};
  NSDictionary *expectedMetadata = @{@"f" : @{@"a" : @{@"f" : @{@"c" : @(kMSACLongMetadataTypeId)}}}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual([csLog.data.properties count], 1);
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
}

- (void)testToCommonSchemaLogForTargetToken {

  // If
  NSString *targetToken = @"aTarget-Token";
  NSString *name = @"SolarEclipse";
  MSACEventProperties *eventProperties = [MSACEventProperties new];
  [eventProperties setString:@"hello" forKey:@"aStringValue"];
  [eventProperties setInt64:1234567890l forKey:@"aLongValue"];
  [eventProperties setDouble:3.14 forKey:@"aDoubleValue"];
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:10000];
  NSString *dateString = [MSACUtility dateToISO8601:date];
  [eventProperties setDate:date forKey:@"aDateTimeValue"];
  [eventProperties setBool:YES forKey:@"aBooleanValue"];
  NSDictionary *expectedProperties = @{
    @"aStringValue" : @"hello",
    @"aLongValue" : @1234567890,
    @"aDoubleValue" : @3.14,
    @"aDateTimeValue" : dateString,
    @"aBooleanValue" : @YES
  };
  NSDictionary *expectedMetadata = @{@"f" : @{@"aLongValue" : @4, @"aDoubleValue" : @6, @"aDateTimeValue" : @9}};
  NSDate *timestamp = [NSDate date];
  NSString *userId = @"alice";
  MSACDevice *device = [MSACDevice new];
  NSString *oemName = @"Peach";
  NSString *model = @"pPhone1,6";
  NSString *locale = @"en_US";
  NSString *osName = @"pOS";
  NSString *osVer = @"1.2.4";
  NSString *osBuild = @"2342EEWF";
  NSString *appNamespace = @"com.contoso.peach.app";
  NSString *appVersion = @"3.1.2";
  NSString *carrierName = @"P-Telecom";
  NSString *sdkVersion = @"1.0.0";
  device.oemName = oemName;
  device.model = model;
  device.locale = locale;
  device.osName = osName;
  device.osVersion = osVer;
  device.osBuild = osBuild;
  device.appNamespace = appNamespace;
  device.appVersion = appVersion;
  device.carrierName = carrierName;
  device.sdkName = @"appcenter.ios";
  device.sdkVersion = sdkVersion;
  device.timeZoneOffset = @(-420);
  self.sut.device = device;
  self.sut.timestamp = timestamp;
  self.sut.name = name;
  self.sut.typedProperties = eventProperties;
  self.sut.tag = [NSObject new];
  self.sut.userId = userId;

  // When
  MSACCommonSchemaLog *csLog = [self.sut toCommonSchemaLogForTargetToken:targetToken flags:MSACFlagsDefault];

  // Then
  XCTAssertEqualObjects(csLog.ver, kMSACCSVerValue);
  XCTAssertEqualObjects(csLog.name, name);
  XCTAssertEqualObjects(csLog.timestamp, timestamp);
  XCTAssertEqualObjects(csLog.iKey, @"o:aTarget");
  XCTAssertEqualObjects(csLog.ext.protocolExt.devMake, oemName);
  XCTAssertEqualObjects(csLog.ext.protocolExt.devModel, model);
  XCTAssertEqualObjects(csLog.ext.userExt.localId, [MSACUserIdContext prefixedUserIdFromUserId:userId]);
  XCTAssertEqualObjects(csLog.ext.appExt.locale, [[[NSBundle mainBundle] preferredLocalizations] firstObject]);
  XCTAssertEqualObjects(csLog.ext.osExt.name, osName);
  XCTAssertEqualObjects(csLog.ext.osExt.ver, @"Version 1.2.4 (Build 2342EEWF)");
  XCTAssertEqualObjects(csLog.ext.appExt.appId, @"I:com.contoso.peach.app");
  XCTAssertEqualObjects(csLog.ext.appExt.ver, device.appVersion);
  XCTAssertEqualObjects(csLog.ext.netExt.provider, carrierName);
  XCTAssertEqualObjects(csLog.ext.sdkExt.libVer, @"appcenter.ios-1.0.0");
  XCTAssertEqualObjects(csLog.ext.locExt.tz, @"-07:00");
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertEqualObjects(csLog.ext.metadataExt.metadata, expectedMetadata);
  XCTAssertEqualObjects(csLog.tag, self.sut.tag);
}

- (void)testInvalidBaseType {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setInt64:1 forKey:@"baseType"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testInvalidBaseData {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setInt64:1 forKey:@"baseData"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testBaseDataMissing {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setString:@"type" forKey:@"baseType"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testBaseTypeMissing {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setString:@"test" forKey:@"baseData.test"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testInvalidBaseTypeRemovesBaseData {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setString:@"test" forKey:@"baseData.test"];
  [properties setInt64:23 forKey:@"baseType"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testInvalidBaseDataRemovesBaseType {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setString:@"test" forKey:@"baseData"];
  [properties setString:@"type" forKey:@"baseType"];
  self.sut.typedProperties = properties;

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqual(0, csLog.data.properties.count);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

- (void)testInvalidBaseTypeAsObjectOverridingValidBaseType {

  // If
  MSACCommonSchemaLog *csLog = [MSACCommonSchemaLog new];
  csLog.data = [MSACCSData new];
  csLog.ext = [MSACCSExtensions new];
  csLog.ext.metadataExt = [MSACMetadataExtension new];
  MSACEventProperties *properties = [MSACEventProperties new];
  [properties setString:@"Some.Type" forKey:@"baseType"];
  [properties setString:@"invalid" forKey:@"baseType.something"];
  [properties setString:@"valid" forKey:@"baseData.something"];
  self.sut.typedProperties = properties;
  NSDictionary *expectedProperties = @{@"baseType" : @"Some.Type", @"baseData" : @{@"something" : @"valid"}};

  // When
  [self.sut setPropertiesAndMetadataForCSLog:csLog];

  // Then
  XCTAssertEqualObjects(csLog.data.properties, expectedProperties);
  XCTAssertNil(csLog.ext.metadataExt.metadata);
}

@end
