// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAbstractLogInternal.h"
#import "MSACAbstractLogPrivate.h"
#import "MSACDevice.h"

@class MSACMetadataExtension;
@class MSACUserExtension;
@class MSACLocExtension;
@class MSACOSExtension;
@class MSACAppExtension;
@class MSACProtocolExtension;
@class MSACNetExtension;
@class MSACSDKExtension;
@class MSACDeviceExtension;

@interface MSACModelTestsUtililty : NSObject

/**
 * Get dummy values for device model.
 *
 * @return Dummy values for device model.
 */
+ (NSDictionary *)deviceDummies;

/**
 * Get dummy values for common schema extensions.
 *
 * @return Dummy values for common schema extensions.
 */
+ (NSMutableDictionary *)extensionDummies;

/**
 * Get dummy values for common schema metadata extensions.
 *
 * @return Dummy values for common schema metadata extensions.
 */
+ (NSDictionary *)metadataExtensionDummies;

/**
 * Get dummy values for common schema user extensions.
 *
 * @return Dummy values for common schema user extensions.
 */
+ (NSDictionary *)userExtensionDummies;

/**
 * Get dummy values for common schema location extensions.
 *
 * @return Dummy values for common schema location extensions.
 */
+ (NSDictionary *)locExtensionDummies;

/**
 * Get dummy values for common schema os extensions.
 *
 * @return Dummy values for common schema os extensions.
 */
+ (NSDictionary *)osExtensionDummies;

/**
 * Get dummy values for common schema app extensions.
 *
 * @return Dummy values for common schema app extensions.
 */
+ (NSDictionary *)appExtensionDummies;

/**
 * Get dummy values for common schema protocol extensions.
 *
 * @return Dummy values for common schema protocol extensions.
 */
+ (NSDictionary *)protocolExtensionDummies;

/**
 * Get dummy values for common schema network extensions.
 *
 * @return Dummy values for common schema network extensions.
 */
+ (NSDictionary *)netExtensionDummies;

/**
 * Get dummy values for common schema sdk extensions.
 *
 * @return Dummy values for common schema sdk extensions.
 */
+ (NSMutableDictionary *)sdkExtensionDummies;

/**
 * Get dummy values for common schema sdk extensions.
 *
 * @return Dummy values for common schema device extensions.
 */
+ (NSMutableDictionary *)deviceExtensionDummies;

/**
 * Get ordered dummy values data, e.g. properties.
 *
 * @return Ordered dummy values data, e.g. properties.
 */
+ (NSDictionary *)orderedDataDummies;

/**
 * Get unordered dummy values data, e.g. properties.
 *
 * @return Unordered dummy values data, e.g. properties.
 */
+ (NSDictionary *)unorderedDataDummies;

/**
 * Get dummy values for abstract log.
 *
 * @return Dummy values for abstract log.
 */
+ (NSDictionary *)abstractLogDummies;

/**
 * Get a dummy device model.
 *
 * @return A dummy device model.
 */
+ (MSACDevice *)dummyDevice;

/**
 * Populate dummy common schema extensions.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return The dummy common schema extensions.
 */
+ (MSACCSExtensions *)extensionsWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema user extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema user extension.
 */
+ (MSACMetadataExtension *)metadataExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema user extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema user extension.
 */
+ (MSACUserExtension *)userExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema location extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema location extension.
 */
+ (MSACLocExtension *)locExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema os extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema os extension.
 */
+ (MSACOSExtension *)osExtensionWithDummyValues:(NSDictionary *)dummyValues;
/**
 * Populate a dummy common schema app extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema app extension.
 */
+ (MSACAppExtension *)appExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema protocol extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema protocol extension.
 */
+ (MSACProtocolExtension *)protocolExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema network extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema network extension.
 */
+ (MSACNetExtension *)netExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema sdk extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema sdk extension.
 */
+ (MSACSDKExtension *)sdkExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema device extension.
 *
 * @param dummyValues Dummy values to create the extension.
 *
 * @return A dummy common schema device extension.
 */
+ (MSACDeviceExtension *)deviceExtensionWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate a dummy common schema data.
 *
 * @param dummyValues Dummy values to create the data.
 *
 * @return A dummy common schema data.
 */
+ (MSACCSData *)dataWithDummyValues:(NSDictionary *)dummyValues;

/**
 * Populate an abstract log with dummy values.
 *
 * @param log An abstract log to be filled with dummy values.
 */
+ (void)populateAbstractLogWithDummies:(MSACAbstractLog *)log;

@end
