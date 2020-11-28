// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kMSACMockMigrationKey = @"%@AppCenterMigratedKey";

@interface MSACMockUserDefaults : NSUserDefaults

/**
 * Clear dictionary.
 */
- (void)stopMocking;

/**
 * Migrates values for the old keys to new keys.
 * @param migratedKeys a dictionary for keys that contains old key as a key of dictionary and new key as a value.
 * @param service service name.
 */
- (void)migrateKeys:(NSDictionary *)migratedKeys forService:(nonnull NSString *)service;

/**
 * Get an object in the settings, returning object if key was found, NULL otherwise.
 *
 * @param key a unique key to identify the value.
 */
- (nullable id)objectForKey:(NSString *)aKey;

@end

NS_ASSUME_NONNULL_END
