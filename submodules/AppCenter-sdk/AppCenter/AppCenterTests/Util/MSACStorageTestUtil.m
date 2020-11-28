// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <sqlite3.h>

#import "MSACStorageTestUtil.h"
#import "MSACUtility+File.h"

@implementation MSACStorageTestUtil

- (instancetype)initWithDbFileName:(NSString *)fileName {
  if ((self = [super init])) {
    _path = fileName;
  }
  return self;
}

- (void)deleteDatabase {
  if (self.path) {
    [MSACUtility deleteItemForPathComponent:self.path];
  }
}

- (long)getDataLengthInBytes {
  sqlite3 *db = [self openDatabase];
  sqlite3_stmt *statement = NULL;
  sqlite3_prepare_v2(db, "PRAGMA page_count;", -1, &statement, NULL);
  sqlite3_step(statement);
  int pageCount = sqlite3_column_int(statement, 0);
  sqlite3_finalize(statement);
  sqlite3_prepare_v2(db, "PRAGMA page_size;", -1, &statement, NULL);
  sqlite3_step(statement);
  int pageSize = sqlite3_column_int(statement, 0);
  sqlite3_finalize(statement);
  sqlite3_close(db);
  return (long)pageCount * pageSize;
}

- (sqlite3 *)openDatabase {
  sqlite3 *db = NULL;
  NSURL *dbURL = [MSACUtility createFileAtPathComponent:self.path withData:nil atomically:NO forceOverwrite:NO];
  sqlite3_open_v2([[dbURL absoluteString] UTF8String], &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, NULL);
  return db;
}

@end
