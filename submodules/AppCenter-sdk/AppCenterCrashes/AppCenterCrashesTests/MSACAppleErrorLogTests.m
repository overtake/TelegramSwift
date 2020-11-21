// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppleErrorLog.h"
#import "MSACBinary.h"
#import "MSACCrashesTestUtil.h"
#import "MSACException.h"
#import "MSACTestFrameworks.h"
#import "MSACThread.h"

@interface MSACAppleErrorLogTests : XCTestCase

@property(nonatomic) MSACAppleErrorLog *sut;

@end

@implementation MSACAppleErrorLogTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];

  self.sut = [self appleErrorLog];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Helper

- (MSACAppleErrorLog *)appleErrorLog {

  MSACAppleErrorLog *appleLog = [MSACAppleErrorLog new];
  appleLog.type = @"iOS Error";
  appleLog.primaryArchitectureId = @1;
  appleLog.architectureVariantId = @123;
  appleLog.applicationPath = @"user/something/something/mypath";
  appleLog.osExceptionType = @"NSSuperOSException";
  appleLog.osExceptionCode = @"0x08aeee81";
  appleLog.osExceptionAddress = @"0x124342345";
  appleLog.exceptionType = @"NSExceptionType";
  appleLog.exceptionReason = @"Trying to access array[12]";
  appleLog.selectorRegisterValue = @"release()";
  appleLog.threads = @ [[MSACThread new]];
  appleLog.binaries = @ [[MSACBinary new]];
  appleLog.exception = [MSACCrashesTestUtil exception];
  appleLog.errorId = @"123";
  appleLog.processId = @123;
  appleLog.processName = @"123";
  appleLog.parentProcessId = @234;
  appleLog.parentProcessName = @"234";
  appleLog.errorThreadId = @2;
  appleLog.errorThreadName = @"2";
  appleLog.fatal = YES;
  appleLog.appLaunchTimestamp = [NSDate dateWithTimeIntervalSince1970:42];
  appleLog.architecture = @"test";

  return appleLog;
}

#pragma mark - Tests

- (void)testInitializationWorks {
  XCTAssertNotNil(self.sut);
}

- (void)testSerializationToDictionaryWorks {
  NSDictionary *actual = [self.sut serializeToDictionary];
  XCTAssertNotNil(actual);
  assertThat(actual[@"type"], equalTo(self.sut.type));
  assertThat(actual[@"primaryArchitectureId"], equalTo(self.sut.primaryArchitectureId));
  assertThat(actual[@"architectureVariantId"], equalTo(self.sut.architectureVariantId));
  assertThat(actual[@"applicationPath"], equalTo(self.sut.applicationPath));
  assertThat(actual[@"osExceptionType"], equalTo(self.sut.osExceptionType));
  assertThat(actual[@"osExceptionCode"], equalTo(self.sut.osExceptionCode));
  assertThat(actual[@"osExceptionAddress"], equalTo(self.sut.osExceptionAddress));
  assertThat(actual[@"exceptionType"], equalTo(self.sut.exceptionType));
  assertThat(actual[@"exceptionReason"], equalTo(self.sut.exceptionReason));
  assertThat(actual[@"selectorRegisterValue"], equalTo(self.sut.selectorRegisterValue));
  assertThat(actual[@"id"], equalTo(self.sut.errorId));
  assertThat(actual[@"processId"], equalTo(self.sut.processId));
  assertThat(actual[@"processName"], equalTo(self.sut.processName));
  assertThat(actual[@"parentProcessId"], equalTo(self.sut.parentProcessId));
  assertThat(actual[@"parentProcessName"], equalTo(self.sut.parentProcessName));
  assertThat(actual[@"errorThreadId"], equalTo(self.sut.errorThreadId));
  assertThat(actual[@"errorThreadName"], equalTo(self.sut.errorThreadName));
  XCTAssertEqual([actual[@"fatal"] boolValue], self.sut.fatal);
  assertThat(actual[@"appLaunchTimestamp"], equalTo(@"1970-01-01T00:00:42.000Z"));
  assertThat(actual[@"architecture"], equalTo(self.sut.architecture));

  // Exception fields.
  NSDictionary *exceptionDictionary = actual[@"exception"];
  XCTAssertNotNil(exceptionDictionary);
  assertThat(exceptionDictionary[@"type"], equalTo(self.sut.exception.type));
  assertThat(exceptionDictionary[@"message"], equalTo(self.sut.exception.message));
  assertThat(exceptionDictionary[@"wrapperSdkName"], equalTo(self.sut.exception.wrapperSdkName));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACAppleErrorLog class]));

  // The MSACAppleErrorLog.
  MSACAppleErrorLog *actualLog = actual;
  assertThat(actualLog, equalTo(self.sut));
  XCTAssertTrue([actualLog isEqual:self.sut]);
  assertThat(actualLog.type, equalTo(self.sut.type));
  assertThat(actualLog.primaryArchitectureId, equalTo(self.sut.primaryArchitectureId));
  assertThat(actualLog.architectureVariantId, equalTo(self.sut.architectureVariantId));
  assertThat(actualLog.architecture, equalTo(self.sut.architecture));
  assertThat(actualLog.applicationPath, equalTo(self.sut.applicationPath));
  assertThat(actualLog.osExceptionType, equalTo(self.sut.osExceptionType));
  assertThat(actualLog.osExceptionCode, equalTo(self.sut.osExceptionCode));
  assertThat(actualLog.osExceptionAddress, equalTo(self.sut.osExceptionAddress));
  assertThat(actualLog.exceptionType, equalTo(self.sut.exceptionType));
  assertThat(actualLog.exceptionReason, equalTo(self.sut.exceptionReason));
  assertThat(actualLog.selectorRegisterValue, equalTo(self.sut.selectorRegisterValue));

  // The exception field.
  MSACException *actualException = actualLog.exception;
  assertThat(actualException.type, equalTo(self.sut.exception.type));
  assertThat(actualException.message, equalTo(self.sut.exception.message));
  assertThat(actualException.wrapperSdkName, equalTo(self.sut.exception.wrapperSdkName));
}

- (void)testIsEqual {

  // When
  MSACAppleErrorLog *first = [self appleErrorLog];
  MSACAppleErrorLog *second = [self appleErrorLog];

  // Then
  XCTAssertTrue([first isEqual:second]);

  // When
  second.processId = @345;

  // Then
  XCTAssertFalse([first isEqual:second]);
}

- (void)testIsValid {

  // When
  MSACAppleErrorLog *log = [MSACAppleErrorLog new];
  log.device = OCMClassMock([MSACDevice class]);
  OCMStub([log.device isValid]).andReturn(YES);
  log.sid = @"sid";
  log.timestamp = [NSDate dateWithTimeIntervalSince1970:42];
  log.errorId = @"errorId";
  log.processId = @123;
  log.processName = @"processName";
  log.appLaunchTimestamp = [NSDate dateWithTimeIntervalSince1970:442];
  log.sid = MSAC_UUID_STRING;

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.primaryArchitectureId = @456;

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.applicationPath = @"applicationPath";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionType = @"exceptionType";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionCode = @"exceptionCode";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionAddress = @"exceptionAddress";

  // Then
  XCTAssertTrue([log isValid]);
}

@end
