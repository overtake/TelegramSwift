// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <exception>
#import <stdexcept>
#import <string>

#import "MSACCrashesCXXExceptionHandler.h"
#import "MSACCrashesCXXExceptionWrapperException.h"
#import "MSACTestFrameworks.h"

static void handler1(__attribute__((unused)) const MSACCrashesUncaughtCXXExceptionInfo *__nonnull info) {}

static void handler2(__attribute__((unused)) const MSACCrashesUncaughtCXXExceptionInfo *__nonnull info) {}

static int terminates = 0;
static void count_terminates() { terminates++; }

static const MSACCrashesUncaughtCXXExceptionInfo *last_info = nullptr;
static char last_exception_message[32] = {0};
static void info_handler(const MSACCrashesUncaughtCXXExceptionInfo *__nonnull info) {
  last_info = info;
  if (info->exception_message) {
    std::strcpy(last_exception_message, info->exception_message);
  } else {
    std::memset(last_exception_message, 0, sizeof(last_exception_message));
  }
}

@interface MSACCrashesCXXExceptionWrapperException ()

@property(readonly, nonatomic) const MSACCrashesUncaughtCXXExceptionInfo *info;

- (NSArray *)callStackReturnAddresses;

@end

@interface MSACCrashesCXXExceptionTests : XCTestCase

@end

@implementation MSACCrashesCXXExceptionTests

- (void)testTerminateHandler {

  // If
  // Replace original terminate handler.
  terminates = 0;
  std::terminate_handler original_terminate = std::set_terminate(count_terminates);

  // Add some handler via SDK to initialize.
  [MSACCrashesUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:info_handler];

  // When
  // Throw reference to std::exception.
  try {
    throw std::runtime_error("test1");
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 1);
  XCTAssertEqual(std::strcmp(last_exception_message, "test1"), 0);

  // When
  // Throw pointer to std::exception.
  try {
    throw new std::runtime_error("test2");
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 2);
  XCTAssertEqual(std::strcmp(last_exception_message, "test2"), 0);

  // When
  // Throw reference to std::string.
  try {
    throw std::string("test3");
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 3);
  XCTAssertEqual(std::strcmp(last_exception_message, "test3"), 0);

  // When
  // Throw pointer to std::string.
  try {
    throw new std::string("test4");
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 4);
  XCTAssertEqual(std::strcmp(last_exception_message, "test4"), 0);

  // When
  // Throw pointer to chars.
  try {
    throw "test5";
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 5);
  XCTAssertEqual(std::strcmp(last_exception_message, "test5"), 0);

  // When
  // Throw Objective-C exception.
  @try {
    @throw [NSException exceptionWithName:NSGenericException reason:@"test6" userInfo:nil];
  } @catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 6);

  // When
  // Throw something else.
  try {
    throw 42;
  } catch (...) {
    std::get_terminate()();
  }

  // Then
  XCTAssertEqual(terminates, 7);
  XCTAssertEqual(last_info->exception_message, nullptr);

  // Restore original terminate handler.
  std::set_terminate(original_terminate);
}

- (void)testHandlersCount {

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 0U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:handler1];

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 1U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:handler2];

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 2U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager removeCXXExceptionHandler:handler1];

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 1U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager removeCXXExceptionHandler:handler1];

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 1U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager removeCXXExceptionHandler:handler2];

  // Then
  XCTAssertEqual([MSACCrashesUncaughtCXXExceptionHandlerManager countCXXExceptionHandler], 0U);

  // When
  [MSACCrashesUncaughtCXXExceptionHandlerManager removeCXXExceptionHandler:handler2];
}

- (void)testWrapperException {
  // If
  const uintptr_t frames[2] = {0x123, 0x234};
  MSACCrashesUncaughtCXXExceptionInfo info = {
      .exception = nullptr,
      .exception_type_name = nullptr,
      .exception_message = nullptr,
      .exception_frames_count = 2,
      .exception_frames = frames,
  };

  // When
  MSACCrashesCXXExceptionWrapperException *wrapperException =
      [[MSACCrashesCXXExceptionWrapperException alloc] initWithCXXExceptionInfo:&info];

  // Then
  XCTAssertNotNil(wrapperException);
  XCTAssertEqual(&info, wrapperException.info);

  // When
  NSArray *callStackReturnAddresses = [wrapperException callStackReturnAddresses];

  // Then
  XCTAssertTrue(callStackReturnAddresses.count == 2);
}

@end
