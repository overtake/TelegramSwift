// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@protocol MSACSerializableObject <NSCoding>

/**
 * Serialize this object to a dictionary.
 *
 * @return A dictionary representing this object.
 */
- (NSMutableDictionary *)serializeToDictionary;

@end
