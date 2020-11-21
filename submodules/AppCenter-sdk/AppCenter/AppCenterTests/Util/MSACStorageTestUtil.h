// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@interface MSACStorageTestUtil : NSObject

/**
 * The relative path to the DB.
 */
@property(nonatomic, copy) NSString *path;

/**
 * Custom init.
 *
 * @param fileName The file name of the db.
 *
 * @return The instance.
 */
- (instancetype)initWithDbFileName:(NSString *)fileName;

/**
 * Delete the database file, this can't be undone. Only used while testing.
 */
- (void)deleteDatabase;

/**
 * Get the size of the data in the test db.
 *
 * @return tThe size of the data in the db.
 */
- (long)getDataLengthInBytes;

/**
 * Open the test database. Make sure to close the handle once you're done!
 *
 * @return The handle to the db.
 */
- (sqlite3 *)openDatabase;

@end
