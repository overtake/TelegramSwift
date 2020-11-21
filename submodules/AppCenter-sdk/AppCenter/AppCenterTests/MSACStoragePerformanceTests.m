// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACLogDBStorage.h"
#import "MSACStartServiceLog.h"
#import "MSACTestFrameworks.h"

static const int kMSACNumLogs = 50;
static const int kMSACNumServices = 5;
static NSString *const kMSACTestGroupId = @"TestGroupId";

@interface MSACStoragePerformanceTests : XCTestCase
@end

@interface MSACStoragePerformanceTests ()

@property(nonatomic) MSACLogDBStorage *dbStorage;

@end

@implementation MSACStoragePerformanceTests

@synthesize dbStorage;

- (void)setUp {
  [super setUp];
  self.dbStorage = [MSACLogDBStorage new];
}

- (void)tearDown {
  [self.dbStorage deleteLogsWithGroupId:kMSACTestGroupId];
  [super tearDown];
}

#pragma mark - Database storage tests

- (void)testDatabaseWriteShortLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithShortServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

- (void)testDatabaseWriteLongLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithLongServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

- (void)testDatabaseWriteVeryLongLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithVeryLongServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

#pragma mark - File storage tests

- (void)testFileStorageWriteShortLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithShortServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

- (void)testFileStorageWriteLongLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithLongServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

- (void)testFileStorageWriteVeryLongLogsPerformance {
  NSArray<MSACStartServiceLog *> *arrayOfLogs = [self generateLogsWithVeryLongServicesNames:kMSACNumLogs withNumService:kMSACNumServices];
  [self measureBlock:^{
    for (MSACStartServiceLog *log in arrayOfLogs) {
      [self.dbStorage saveLog:log withGroupId:kMSACTestGroupId flags:MSACFlagsDefault];
    }
  }];
}

#pragma mark - Private

- (NSArray<MSACStartServiceLog *> *)generateLogsWithShortServicesNames:(int)numLogs withNumService:(int)numServices {
  NSMutableArray<MSACStartServiceLog *> *dic = [NSMutableArray new];
  for (int i = 0; i < numLogs; ++i) {
    MSACStartServiceLog *log = [MSACStartServiceLog new];
    log.services = [self generateServicesWithShortNames:numServices];
    [dic addObject:log];
  }
  return dic;
}

- (NSArray<MSACStartServiceLog *> *)generateLogsWithLongServicesNames:(int)numLogs withNumService:(int)numServices {
  NSMutableArray<MSACStartServiceLog *> *dic = [NSMutableArray new];
  for (int i = 0; i < numLogs; ++i) {
    MSACStartServiceLog *log = [MSACStartServiceLog new];
    log.services = [self generateServicesWithLongNames:numServices];
    [dic addObject:log];
  }
  return dic;
}

- (NSArray<MSACStartServiceLog *> *)generateLogsWithVeryLongServicesNames:(int)numLogs withNumService:(int)numServices {
  NSMutableArray<MSACStartServiceLog *> *dic = [NSMutableArray new];
  for (int i = 0; i < numLogs; ++i) {
    MSACStartServiceLog *log = [MSACStartServiceLog new];
    log.services = [self generateServicesWithVeryLongNames:numServices];
    [dic addObject:log];
  }
  return dic;
}

- (NSArray<NSString *> *)generateServicesWithShortNames:(int)numServices {
  NSMutableArray<NSString *> *dic = [NSMutableArray new];
  for (int i = 0; i < numServices; ++i) {
    [dic addObject:[[NSUUID UUID] UUIDString]];
  }
  return dic;
}

- (NSArray<NSString *> *)generateServicesWithLongNames:(int)numServices {
  NSMutableArray<NSString *> *dic = [NSMutableArray new];
  for (int i = 0; i < numServices; ++i) {
    NSString *value = @"";
    for (int j = 0; j < 10; ++j) {
      value = [value stringByAppendingString:[[NSUUID UUID] UUIDString]];
    }
    [dic addObject:value];
  }
  return dic;
}

- (NSArray<NSString *> *)generateServicesWithVeryLongNames:(int)numServices {
  NSMutableArray<NSString *> *dic = [NSMutableArray new];
  for (int i = 0; i < numServices; ++i) {
    NSString *value = @"";
    for (int j = 0; j < 50; ++j) {
      value = [value stringByAppendingString:[[NSUUID UUID] UUIDString]];
    }
    [dic addObject:value];
  }
  return dic;
}

@end
