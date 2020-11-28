// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACStackFrame.h"
#import "MSACTestFrameworks.h"

@interface MSACStackFrameTests : XCTestCase

@end

@implementation MSACStackFrameTests

#pragma mark - Helper

- (MSACStackFrame *)stackFrame {
  NSString *address = @"address";
  NSString *code = @"code";
  NSString *className = @"class_name";
  NSString *methodName = @"method_name";
  NSNumber *lineNumber = @123;
  NSString *fileName = @"file_name";

  MSACStackFrame *threadFrame = [MSACStackFrame new];
  threadFrame.address = address;
  threadFrame.code = code;
  threadFrame.className = className;
  threadFrame.methodName = methodName;
  threadFrame.lineNumber = lineNumber;
  threadFrame.fileName = fileName;

  return threadFrame;
}

#pragma mark - Tests

- (void)testSerializingBinaryToDictionaryWorks {

  // If
  MSACStackFrame *sut = [self stackFrame];

  // When
  NSMutableDictionary *actual = [sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"address"], equalTo(sut.address));
  assertThat(actual[@"code"], equalTo(sut.code));
  assertThat(actual[@"className"], equalTo(sut.className));
  assertThat(actual[@"methodName"], equalTo(sut.methodName));
  assertThat(actual[@"lineNumber"], equalTo(sut.lineNumber));
  assertThat(actual[@"fileName"], equalTo(sut.fileName));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // If
  MSACStackFrame *sut = [self stackFrame];

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACStackFrame class]));

  MSACStackFrame *actualThreadFrame = actual;
  assertThat(actualThreadFrame, equalTo(sut));
  assertThat(actualThreadFrame.address, equalTo(sut.address));
  assertThat(actualThreadFrame.code, equalTo(sut.code));
  assertThat(actualThreadFrame.className, equalTo(sut.className));
  assertThat(actualThreadFrame.methodName, equalTo(sut.methodName));
  assertThat(actualThreadFrame.lineNumber, equalTo(sut.lineNumber));
  assertThat(actualThreadFrame.fileName, equalTo(sut.fileName));
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([[MSACStackFrame new] isEqual:nil]);
}

@end
