// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACCrashes.h"
#import "MSACException.h"
#import "MSACTestFrameworks.h"
#import "MSACWrapperException.h"
#import "MSACWrapperExceptionManagerInternal.h"

// Copied from MSACWrapperExceptionManager.m
static NSString *const kMSACLastWrapperExceptionFileName = @"last_saved_wrapper_exception";

@interface MSACWrapperExceptionManagerTests : XCTestCase
@end

// Expose private methods for use in tests
@interface MSACWrapperExceptionManager ()

+ (MSACWrapperException *)loadWrapperExceptionWithBaseFilename:(NSString *)baseFilename;

@end

@implementation MSACWrapperExceptionManagerTests

#pragma mark - Housekeeping

- (void)tearDown {
  [super tearDown];
  [MSACWrapperExceptionManager deleteAllWrapperExceptions];
}

#pragma mark - Helper

- (MSACException *)getModelException {
  MSACException *exception = [[MSACException alloc] init];
  exception.message = @"a message";
  exception.type = @"a type";
  return exception;
}

- (NSData *)getData {
  return [@"some string" dataUsingEncoding:NSUTF8StringEncoding];
}

- (MSACWrapperException *)getWrapperException {
  MSACWrapperException *wrapperException = [[MSACWrapperException alloc] init];
  wrapperException.modelException = [self getModelException];
  wrapperException.exceptionData = [self getData];
  wrapperException.processId = @(rand());
  return wrapperException;
}

- (void)assertWrapperException:(MSACWrapperException *)wrapperException isEqualToOther:(MSACWrapperException *)other {

  // Test that the exceptions are the same.
  assertThat(other.processId, equalTo(wrapperException.processId));
  assertThat(other.exceptionData, equalTo(wrapperException.exceptionData));
  assertThat(other.modelException, equalTo(wrapperException.modelException));

  // The exception field.
  assertThat(other.modelException.type, equalTo(wrapperException.modelException.type));
  assertThat(other.modelException.message, equalTo(wrapperException.modelException.message));
  assertThat(other.modelException.wrapperSdkName, equalTo(wrapperException.modelException.wrapperSdkName));
}

#pragma mark - Test

- (void)testSaveAndLoadWrapperExceptionWorks {

  // If
  MSACWrapperException *wrapperException = [self getWrapperException];

  // When
  [MSACWrapperExceptionManager saveWrapperException:wrapperException];
  MSACWrapperException *loadedException =
      [MSACWrapperExceptionManager loadWrapperExceptionWithBaseFilename:kMSACLastWrapperExceptionFileName];

  // Then
  XCTAssertNotNil(loadedException);
  [self assertWrapperException:wrapperException isEqualToOther:loadedException];
}

- (void)testSaveCorrelateWrapperExceptionWhenExists {

  // If
  int numReports = 4;
  NSMutableArray *mockReports = [NSMutableArray new];
  for (int i = 0; i < numReports; ++i) {
    id reportMock = OCMPartialMock([MSACErrorReport new]);
    OCMStub([reportMock appProcessIdentifier]).andReturn(i);
    OCMStub([reportMock incidentIdentifier]).andReturn([[NSUUID UUID] UUIDString]);
    [mockReports addObject:reportMock];
  }
  MSACErrorReport *report = mockReports[(NSUInteger)(rand() % numReports)];
  MSACWrapperException *wrapperException = [self getWrapperException];
  wrapperException.processId = @([report appProcessIdentifier]);

  // When
  [MSACWrapperExceptionManager saveWrapperException:wrapperException];
  [MSACWrapperExceptionManager correlateLastSavedWrapperExceptionToReport:mockReports];
  MSACWrapperException *loadedException = [MSACWrapperExceptionManager loadWrapperExceptionWithUUIDString:[report incidentIdentifier]];

  // Then
  XCTAssertNotNil(loadedException);
  [self assertWrapperException:wrapperException isEqualToOther:loadedException];
}

- (void)testSaveCorrelateWrapperExceptionWhenNotExists {

  // If
  MSACWrapperException *wrapperException = [self getWrapperException];
  wrapperException.processId = @4;
  NSMutableArray *mockReports = [NSMutableArray new];
  id reportMock = OCMPartialMock([MSACErrorReport new]);
  OCMStub([reportMock appProcessIdentifier]).andReturn(9);
  NSString *uuidString = [[NSUUID UUID] UUIDString];
  OCMStub([reportMock incidentIdentifier]).andReturn(uuidString);
  [mockReports addObject:reportMock];

  // When
  [MSACWrapperExceptionManager saveWrapperException:wrapperException];
  [MSACWrapperExceptionManager correlateLastSavedWrapperExceptionToReport:mockReports];
  MSACWrapperException *loadedException = [MSACWrapperExceptionManager loadWrapperExceptionWithUUIDString:uuidString];

  // Then
  XCTAssertNil(loadedException);
}

@end
