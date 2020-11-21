// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrash.h"

static NSMutableSet *crashTypes = nil;

@implementation MSCrash

+ (void)initialize {
  static dispatch_once_t predicate = 0;

  dispatch_once(&predicate, ^{
      crashTypes = [[NSMutableSet alloc] init];
  });
}

+ (NSArray *)allCrashes {
  return crashTypes.allObjects;
}

+ (void)registerCrash:(MSCrash *)crash {
  [crashTypes addObject:crash];
}

+ (void)removeAllCrashes {
  [crashTypes removeAllObjects];
}

+ (void)unregisterCrash:(MSCrash *)crash {
  [crashTypes removeObject:crash];
}

- (NSString *)category {
  return @"NONE";
}

- (NSString *)title {
  return @"NONE";
}

- (NSString *)desc {
  return @"NONE";
}

- (void)crash {
  NSLog(@"I'm supposed to crash here.");
}

@end
