// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACAnalyticsInternal.h"

@class MSACCommonSchemaLog;
@class MSACLogWithNameAndProperties;

NS_ASSUME_NONNULL_BEGIN

/*
 * Workaround for exporting symbols from category object files.
 */
extern NSString *MSACAnalyticsValidationCategory;

@interface MSACAnalytics (Validation)

/**
 * Validate AppCenter log.
 *
 * @param log The AppCenter log.
 *
 * @return YES if AppCenter log is valid; NO otherwise.
 */
- (BOOL)validateLog:(MSACLogWithNameAndProperties *)log;

/**
 * Validate event name
 *
 * @return YES if event name is valid; NO otherwise.
 */
- (nullable NSString *)validateEventName:(NSString *)eventName forLogType:(NSString *)logType;

/**
 * Validate keys and values of properties. Intended for testing. Uses MSACUtility+PropertyValidation internally.
 *
 * @return dictionary which contains only valid properties.
 */
- (NSDictionary<NSString *, NSString *> *)validateProperties:(NSDictionary<NSString *, NSString *> *)properties
                                                  forLogName:(NSString *)logName
                                                     andType:(NSString *)logType;

/**
 * Validate MSACEventProperties for App Center's ingestion.
 *
 * @return MSACEventProperties object which contains only valid properties.
 */
- (MSACEventProperties *)validateAppCenterEventProperties:(MSACEventProperties *)properties;

@end

NS_ASSUME_NONNULL_END
