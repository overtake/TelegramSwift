// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACException.h"
#import "MSACTestFrameworks.h"
#import "MSACWrapperExceptionInternal.h"

@interface MSACWrapperExceptionTests : XCTestCase

@property(nonatomic) MSACWrapperException *sut;

@end

@implementation MSACWrapperExceptionTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.sut = [self wrapperException];
}

#pragma mark - Helper

- (MSACWrapperException *)wrapperException {
  MSACWrapperException *exception = [MSACWrapperException new];
  exception.processId = @4;
  exception.exceptionData = [@"data string" dataUsingEncoding:NSUTF8StringEncoding];
  exception.modelException = [[MSACException alloc] init];
  exception.modelException.type = @"type";
  exception.modelException.message = @"message";
  exception.modelException.wrapperSdkName = @"wrapper sdk name";
  return exception;
}

#pragma mark - Tests

- (void)testInitializationWorks {
  XCTAssertNotNil(self.sut);
}

- (void)testSerializationToDictionaryWorks {
  NSDictionary *actual = [self.sut serializeToDictionary];
  XCTAssertNotNil(actual);
  assertThat(actual[@"processId"], equalTo(self.sut.processId));
  assertThat(actual[@"exceptionData"], equalTo(self.sut.exceptionData));

  // Exception fields.
  NSDictionary *exceptionDictionary = actual[@"modelException"];
  XCTAssertNotNil(exceptionDictionary);
  assertThat(exceptionDictionary[@"type"], equalTo(self.sut.modelException.type));
  assertThat(exceptionDictionary[@"message"], equalTo(self.sut.modelException.message));
  assertThat(exceptionDictionary[@"wrapperSdkName"], equalTo(self.sut.modelException.wrapperSdkName));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // When
  NSData *serializedWrapperException = [MSACUtility archiveKeyedData:self.sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedWrapperException];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACWrapperException class]));

  // The MSACAppleErrorLog.
  MSACWrapperException *actualWrapperException = actual;
  assertThat(actualWrapperException.processId, equalTo(self.sut.processId));
  assertThat(actualWrapperException.exceptionData, equalTo(self.sut.exceptionData));

  // The exception field.
  assertThat(actualWrapperException.modelException.type, equalTo(self.sut.modelException.type));
  assertThat(actualWrapperException.modelException.message, equalTo(self.sut.modelException.message));
  assertThat(actualWrapperException.modelException.wrapperSdkName, equalTo(self.sut.modelException.wrapperSdkName));
}

@end
