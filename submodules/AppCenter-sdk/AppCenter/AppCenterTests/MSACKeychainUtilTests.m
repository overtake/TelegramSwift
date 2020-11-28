// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACKeychainUtil.h"
#import "MSACKeychainUtilPrivate.h"
#import "MSACTestFrameworks.h"

@interface MSACKeychainUtilTests : XCTestCase
@property(nonatomic) id keychainUtilMock;
@property(nonatomic, copy) NSString *acServiceName;

@end

@implementation MSACKeychainUtilTests

- (void)setUp {
  [super setUp];
  self.keychainUtilMock = OCMClassMock([MSACKeychainUtil class]);
  self.acServiceName = [NSString stringWithFormat:@"%@.%@", [self getBundleIdentifier], kMSACServiceSuffix];
}

- (void)tearDown {
  [super tearDown];
  [self.keychainUtilMock stopMocking];
}

#if !TARGET_OS_TV
- (void)testKeychain {

  // If
  NSString *key = @"Test Key";
  NSString *value = @"Test Value";
  NSDictionary *expectedAddItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecValueData : (NSData * _Nonnull)[value dataUsingEncoding:NSUTF8StringEncoding],
    (__bridge id)kSecAttrAccessible : (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  };
  NSDictionary *expectedDeleteItemQuery =
      @{(__bridge id)kSecAttrService : self.acServiceName, (__bridge id)kSecClass : @"genp", (__bridge id)kSecAttrAccount : key};
  NSDictionary *expectedMatchItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
    (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
  };

  // Expect these stubbed calls.
  OCMStub([self.keychainUtilMock addSecItem:[expectedAddItemQuery mutableCopy]]).andReturn(noErr);
  OCMStub([self.keychainUtilMock deleteSecItem:[expectedDeleteItemQuery mutableCopy]]).andReturn(noErr);
  OCMStub([self.keychainUtilMock secItemCopyMatchingQuery:[expectedMatchItemQuery mutableCopy] result:[OCMArg anyPointer]])
      .andReturn(noErr);

  // Reject any other calls.
  OCMReject([self.keychainUtilMock addSecItem:[OCMArg any]]);
  OCMReject([self.keychainUtilMock deleteSecItem:[OCMArg any]]);
  OCMReject([self.keychainUtilMock secItemCopyMatchingQuery:[OCMArg any] result:[OCMArg anyPointer]]);

  // When
  [MSACKeychainUtil storeString:value forKey:key];
  [MSACKeychainUtil stringForKey:key statusCode:nil];
  [MSACKeychainUtil deleteStringForKey:key];

  // Then
  OCMVerifyAll(self.keychainUtilMock);
}

- (void)testKeychainGetStringSetsError {

  // If
  NSString *key = @"Test Key";
  OSStatus statusExpected = errSecNoAccessForItem;
  OCMStub([self.keychainUtilMock secItemCopyMatchingQuery:[OCMArg any] result:[OCMArg anyPointer]]).andReturn(statusExpected);

  // When
  OSStatus statusReceived;
  NSString *result = [MSACKeychainUtil stringForKey:key statusCode:&statusReceived];

  // Then
  XCTAssertNil(result);
  XCTAssertEqual(statusReceived, statusExpected);
}

- (void)testKeychainGetStringAllowsNilErrorArgument {

  // If
  NSString *key = @"Test Key";
  OSStatus statusExpected = errSecNoAccessForItem;
  OCMStub([self.keychainUtilMock secItemCopyMatchingQuery:[OCMArg any] result:[OCMArg anyPointer]]).andReturn(statusExpected);

  // When
  NSString *result = [MSACKeychainUtil stringForKey:key statusCode:nil];

  // Then
  XCTAssertNil(result);
}

- (void)testStoreStringHandlesDuplicateItemError {

  // If
  NSString *key = @"testKey";
  NSString *value = @"testValue";
  __block int addSecItemCallsCount = 0;
  OCMStub([self.keychainUtilMock addSecItem:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    ++addSecItemCallsCount;
    int returnValue = addSecItemCallsCount > 1 ? noErr : errSecDuplicateItem;
    [invocation setReturnValue:&returnValue];
  });

  // When
  BOOL actualResult = [MSACKeychainUtil storeString:value forKey:key];

  // Then
  XCTAssertEqual(addSecItemCallsCount, 2);
  XCTAssertEqual(actualResult, YES);
  OCMVerify([self.keychainUtilMock deleteSecItem:OCMOCK_ANY]);
}

#endif

// Before SDK 12.2 (bundled with Xcode 10.*) when running in a unit test bundle the bundle identifier is null.
// 12.2 and after the above bundle identifier is com.apple.dt.xctest.tool.
- (NSString *)getBundleIdentifier {
#if ((defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_2) ||                                     \
     (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_14_4))
  return @"com.apple.dt.xctest.tool";
#else
  return @"(null)";
#endif
}

@end
