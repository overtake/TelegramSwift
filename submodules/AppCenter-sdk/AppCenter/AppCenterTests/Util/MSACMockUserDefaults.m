// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACMockUserDefaults.h"
#import "MSACAppCenterUserDefaults.h"
#import "MSACAppCenterUserDefaultsPrivate.h"
#import "MSACTestFrameworks.h"

@interface MSACMockUserDefaults ()

@property(nonatomic) NSMutableDictionary<NSString *, NSObject *> *dictionary;
@property(nonatomic) id mockMSACUserDefaults;

@end

@implementation MSACMockUserDefaults

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary new];

    // Mock MSACUserDefaults shared method to return this instance.
    _mockMSACUserDefaults = OCMClassMock([MSACAppCenterUserDefaults class]);
    OCMStub([_mockMSACUserDefaults shared]).andReturn(self);
  }
  return self;
}

- (void)migrateKeys:(__unused NSDictionary *)migratedKeys forService:(nonnull NSString *)service {
  [self setObject:@YES forKey:[NSString stringWithFormat:kMSACMockMigrationKey, service]];
}

- (void)setObject:(id)anObject forKey:(NSString *)aKey {

  // Don't store nil objects.
  if (!anObject) {
    return;
  }
  [self.dictionary setObject:anObject forKey:aKey];
}

- (nullable id)objectForKey:(NSString *)aKey {
  return self.dictionary[aKey];
}

- (void)removeObjectForKey:(NSString *)aKey {
  [self.dictionary removeObjectForKey:aKey];
}

- (void)stopMocking {
  [self.dictionary removeAllObjects];
  [self.mockMSACUserDefaults stopMocking];
}

@end
