// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAppCenterUserDefaults.h"
#import "MSACAppCenterUserDefaultsPrivate.h"
#import "MSACLoggerInternal.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility.h"
#import "MSACWrapperLogger.h"

@interface MSACUserDefaultsTests : XCTestCase

@end

static NSString *const kMSACAppCenterUserDefaultsMigratedKey = @"MSAppCenter310AppCenterUserDefaultsMigratedKey";

@implementation MSACUserDefaultsTests

- (void)setUp {
  for (NSString *key in [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
  }
  [MSACAppCenterUserDefaults resetSharedInstance];
}

- (void)testSettingsAlreadyMigrated {

  // If
  NSString *testValue = @"testValue";
  [[NSUserDefaults standardUserDefaults] setObject:testValue forKey:@"pastDevicesKey"];
  [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:kMSACAppCenterUserDefaultsMigratedKey];

  // When
  [MSACAppCenterUserDefaults shared];

  // Then
  XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"MSAppCenterPastDevices"]);
}

- (void)testPrefixIsAppendedOnSetAndGet {

  // If
  NSString *value = @"testValue";
  NSString *key = @"testKey";

  // When
  MSACAppCenterUserDefaults *userDefaults = [MSACAppCenterUserDefaults shared];
  [userDefaults setObject:value forKey:key];

  // Then
  XCTAssertEqual(value, [[NSUserDefaults standardUserDefaults] objectForKey:[kMSACUserDefaultsPrefix stringByAppendingString:key]]);
  XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:key]);
  XCTAssertEqual(value, [userDefaults objectForKey:key]);

  // When
  [userDefaults removeObjectForKey:key];

  // Then
  XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:[kMSACUserDefaultsPrefix stringByAppendingString:key]]);
}

- (void)testMigrateUserDefaultSettings {
  NSArray *suffixes = @[ @"-suffix1", @"/suffix2", @"suffix3" ];
  NSString *wildcard = @"okeyTestWildcard";
  NSString *expectedWildcard = @"MSAppCenterOkeyTestWildcard";

  // If
  NSDictionary *keys = @{
    @"MSAppCenterKeyTest1" : @"okeyTest1",
    @"MSAppCenterKeyTest2" : @"okeyTest2",
    @"MSAppCenterKeyTest3" : @"okeyTest3",
    @"MSAppCenterKeyTest4" : @"okeyTest4",
    expectedWildcard : MSACPrefixKeyFrom(wildcard)
  };
  MSACAppCenterUserDefaults *userDefaults = [MSACAppCenterUserDefaults shared];
  NSMutableArray *expectedKeysArray = [[keys allKeys] mutableCopy];
  NSMutableArray *oldKeysArray = [[keys allValues] mutableCopy];
  for (NSString *suffix in suffixes) {
    [expectedKeysArray addObject:[expectedWildcard stringByAppendingString:suffix]];
    [oldKeysArray addObject:[wildcard stringByAppendingString:suffix]];
  }
  for (NSUInteger i = 0; i < [keys count]; i++) {
    if ([oldKeysArray[i] isKindOfClass:[MSACUserDefaultsPrefixKey class]]) {
      continue;
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"Test %tu", i] forKey:oldKeysArray[i]];
  }
  for (NSString *suffix in suffixes) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"Test %@", suffix]
                                              forKey:[wildcard stringByAppendingString:suffix]];
  }

  // Check that in MSACUserDefaultsTest the same keys.
  NSArray *userDefaultKeys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
  for (NSString *oldKey in oldKeysArray) {
    if ([oldKey isKindOfClass:[MSACUserDefaultsPrefixKey class]]) {
      continue;
    }
    XCTAssertTrue([userDefaultKeys containsObject:oldKey]);
  }
  XCTAssertFalse([userDefaultKeys containsObject:expectedKeysArray]);

  // When
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMSACAppCenterUserDefaultsMigratedKey];
  [userDefaults migrateKeys:keys forService:@"AppCenter"];

  // Then
  userDefaultKeys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
  XCTAssertFalse([userDefaultKeys containsObject:oldKeysArray]);
  for (NSString *expectedKey in expectedKeysArray) {
    if ([expectedKey isEqualToString:expectedWildcard]) {
      continue;
    }
    XCTAssertTrue([userDefaultKeys containsObject:expectedKey]);
  }
  for (NSString *oldKey in oldKeysArray) {
    if ([oldKey isKindOfClass:[MSACUserDefaultsPrefixKey class]]) {
      continue;
    }
    XCTAssertFalse([userDefaultKeys containsObject:oldKey]);
  }
}

- (void)testUnexpectedKeyTypeInMigrateUserDefaultSettings {

  // If
  NSDictionary *keys = @{@"MSAppCenterKeyTest1" : @"okeyTest1"};
  MSACAppCenterUserDefaults *userDefaults = [MSACAppCenterUserDefaults shared];

  // When
  [[NSUserDefaults standardUserDefaults] setObject:@"Test 1" forKey:@"YES"];

  // Then
  XCTAssertNoThrow([userDefaults migrateKeys:keys forService:@"AppCenter"]);
}

@end
