// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACException.h"
#import "MSACStackFrame.h"
#import "MSACTestFrameworks.h"
#import "MSACThread.h"

@interface MSACThreadTests : XCTestCase

@end

@implementation MSACThreadTests

#pragma mark - Helper

- (MSACThread *)thread {
  NSNumber *threadId = @(12);
  NSString *name = @"thread_name";

  MSACException *exception = [MSACException new];
  exception.type = @"exception_type";
  exception.message = @"message";
  MSACStackFrame *frame = [self stackFrame];
  exception.frames = @[ frame ];

  MSACThread *thread = [MSACThread new];
  thread.threadId = threadId;
  thread.name = name;
  thread.exception = exception;
  thread.frames = [@[ frame ] mutableCopy];

  return thread;
}

- (MSACStackFrame *)stackFrame {
  NSString *address = @"address";
  NSString *code = @"code";

  MSACStackFrame *threadFrame = [MSACStackFrame new];
  threadFrame.address = address;
  threadFrame.code = code;

  return threadFrame;
}

#pragma mark - Tests

- (void)testSerializingBinaryToDictionaryWorks {

  // If
  MSACThread *sut = [self thread];

  // When
  NSMutableDictionary *actual = [sut serializeToDictionary];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual[@"id"], equalTo(sut.threadId));
  assertThat(actual[@"name"], equalTo(sut.name));
  assertThat([actual[@"exception"] valueForKey:@"type"], equalTo(sut.exception.type));
  assertThat([actual[@"exception"] valueForKey:@"message"], equalTo(sut.exception.message));

  NSArray *actualFrames = [actual[@"exception"] valueForKey:@"frames"];
  XCTAssertEqual(actualFrames.count, sut.exception.frames.count);
  NSDictionary *actualFrame = [actualFrames firstObject];
  MSACStackFrame *expectedFrame = [sut.exception.frames firstObject];
  assertThat([actualFrame valueForKey:@"code"], equalTo(expectedFrame.code));
  assertThat([actualFrame valueForKey:@"address"], equalTo(expectedFrame.address));
}

- (void)testNSCodingSerializationAndDeserializationWorks {
  // If
  MSACThread *sut = [self thread];

  // When
  NSData *serializedEvent = [MSACUtility archiveKeyedData:sut];
  id actual = [MSACUtility unarchiveKeyedData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSACThread class]));

  MSACThread *actualThread = actual;
  assertThat(actualThread, equalTo(actual));
  assertThat(actualThread.threadId, equalTo(sut.threadId));
  assertThat(actualThread.name, equalTo(sut.name));
  assertThat(actualThread.exception.type, equalTo(sut.exception.type));
  assertThat(actualThread.exception.message, equalTo(sut.exception.message));
  assertThatUnsignedLong(actualThread.exception.frames.count, equalToUnsignedLong(sut.exception.frames.count));

  assertThatInteger(actualThread.frames.count, equalToInteger(1));
}

- (void)testIsValid {

  // When
  MSACThread *thread = [MSACThread new];

  // Then
  XCTAssertFalse([thread isValid]);

  // When
  thread.threadId = @123;

  // Then
  XCTAssertFalse([thread isValid]);

  // When
  [thread.frames addObject:[MSACStackFrame new]];

  // Then
  XCTAssertTrue([thread isValid]);
}

- (void)testIsNotEqualToNil {

  // Then
  XCTAssertFalse([[MSACThread new] isEqual:nil]);
}

@end
