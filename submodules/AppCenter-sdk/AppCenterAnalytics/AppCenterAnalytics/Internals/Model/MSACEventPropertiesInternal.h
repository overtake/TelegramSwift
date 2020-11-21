// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACEventProperties.h"

@class MSACTypedProperty;

NS_ASSUME_NONNULL_BEGIN

/**
 * Typed event properties.
 */
@interface MSACEventProperties () <NSCoding>

/**
 * String and date properties.
 */
@property(nonatomic) NSMutableDictionary<NSString *, MSACTypedProperty *> *properties;

/**
 * Creates an instance of EventProperties with a string-string properties dictionary.
 *
 * @param properties A dictionary of properties with string keys and string values.
 *
 * @return An instance of EventProperties.
 */
- (instancetype)initWithStringDictionary:(NSDictionary<NSString *, NSString *> *)properties;

/**
 * Serialize this object to an array.
 *
 * @return An array representing this object.
 */
- (NSMutableArray *)serializeToArray;

/**
 * Indicates whether there are any properties in the collection.
 *
 * @return `YES` if there are no properties in the collection, `NO` otherwise.
 */
- (BOOL)isEmpty;

/**
 * Merge event properties.
 *
 * @param eventProperties The new properites to be merged.
 */
- (void)mergeEventProperties:(MSACEventProperties *__nonnull)eventProperties;

@end

NS_ASSUME_NONNULL_END
