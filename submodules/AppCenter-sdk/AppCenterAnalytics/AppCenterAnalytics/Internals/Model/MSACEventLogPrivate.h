// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACEventLog.h"

@interface MSACEventLog ()

/**
 * Maps each typed property string identifier to a CS type identifier.
 */
@property(nonatomic) NSDictionary *metadataTypeIdMapping;

/**
 * Convert AppCenter properties to Common Schema 3.0 Part C properties.
 */
- (void)setPropertiesAndMetadataForCSLog:(MSACCommonSchemaLog *)csLog;

@end
