// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACCrashesTestUtil.h"
#import "MSACException.h"
#import "MSACStackFrame.h"
#import "MSACTestFrameworks.h"

@interface MSACExceptionsTests : XCTestCase

@end

@implementation MSACExceptionsTests

#pragma mark - Tests

- (void)testSerializingBinaryToDictionaryWorks {

  // If
  MSACException *sut = [MSACCrashesTestUtil exception];
  sut.innerExceptions = @[ [MSACCrashesTestUtil exception] ];

  // When
  NSMutableDictionary *actual = [sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"type"], equalTo(sut.type));
  assertThat(actual[@"message"], equalTo(sut.message));
  assertThat(actual[@"stackTrace"], equalTo(sut.stackTrace));
  assertThat(actual[@"wrapperSdkName"], equalTo(sut.wrapperSdkName));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  MSACException *sut = [MSACCrashesTestUtil exception];
  sut.innerExceptions = @[ [MSACCrashesTestUtil exception] ];

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACException class]));

  MSACException *actualException = actual;

  assertThat(actualException, equalTo(sut));
  assertThat(actualException.type, equalTo(sut.type));
  assertThat(actualException.message, equalTo(sut.message));
  assertThat(actualException.stackTrace, equalTo(sut.stackTrace));
  assertThat(actualException.wrapperSdkName, equalTo(sut.wrapperSdkName));
  assertThatInteger(actualException.frames.count, equalToInteger(1));
  assertThat(actualException.frames.firstObject.address, equalTo(@"frameAddress"));
  assertThat(actualException.frames.firstObject.code, equalTo(@"frameSymbol"));
}

@end
