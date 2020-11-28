// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@interface MSCrash : NSObject

+ (NSArray *)allCrashes;

+ (void)registerCrash:(MSCrash *)crash;

+ (void)unregisterCrash:(MSCrash *)crash;

+ (void)removeAllCrashes;

@property(nonatomic, copy, readonly) NSString *category;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *desc;

- (void)crash;

@end
