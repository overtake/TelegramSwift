// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACModelTestsUtililty.h"
#import "MSACAppExtension.h"
#import "MSACCSData.h"
#import "MSACCSExtensions.h"
#import "MSACDeviceExtension.h"
#import "MSACDeviceInternal.h"
#import "MSACLocExtension.h"
#import "MSACMetadataExtension.h"
#import "MSACNetExtension.h"
#import "MSACOSExtension.h"
#import "MSACProtocolExtension.h"
#import "MSACSDKExtension.h"
#import "MSACUserExtension.h"
#import "MSACUtility.h"
#import "MSACWrapperSdkInternal.h"

@implementation MSACModelTestsUtililty

#pragma mark - MSACDevice

+ (NSDictionary *)deviceDummies {
  return @{
    kMSACSDKVersion : @"3.0.1",
    kMSACSDKName : @"appcenter-ios",
    kMSACModel : @"iPhone 7.2",
    kMSACOEMName : @"Apple",
    kMSACACOSName : @"iOS",
    kMSACOSVersion : @"9.3.20",
    kMSACOSBuild : @"320",
    kMSACLocale : @"US-EN",
    kMSACTimeZoneOffset : @(9),
    kMSACScreenSize : @"750x1334",
    kMSACAppVersion : @"3.4.5",
    kMSACAppBuild : @"178",
    kMSACAppNamespace : @"com.contoso.apple.app",
    kMSACCarrierName : @"Some-Telecom",
    kMSACCarrierCountry : @"US",
    kMSACWrapperSDKName : @"wrapper-sdk",
    kMSACWrapperSDKVersion : @"6.7.8",
    kMSACWrapperRuntimeVersion : @"9.10",
    kMSACLiveUpdatePackageHash : @"b10a8db164e0754105b7a99be72e3fe5",
    kMSACLiveUpdateReleaseLabel : @"live-update-release",
    kMSACLiveUpdateDeploymentKey : @"deployment-key"
  };
}

+ (NSMutableDictionary *)extensionDummies {

  // Set up all extensions with dummy values.
  NSDictionary *userExtDummyValues = [MSACModelTestsUtililty userExtensionDummies];
  MSACUserExtension *userExt = [MSACModelTestsUtililty userExtensionWithDummyValues:userExtDummyValues];
  NSDictionary *locExtDummyValues = [MSACModelTestsUtililty locExtensionDummies];
  MSACLocExtension *locExt = [MSACModelTestsUtililty locExtensionWithDummyValues:locExtDummyValues];
  NSDictionary *osExtDummyValues = [MSACModelTestsUtililty osExtensionDummies];
  MSACOSExtension *osExt = [MSACModelTestsUtililty osExtensionWithDummyValues:osExtDummyValues];
  NSDictionary *appExtDummyValues = [MSACModelTestsUtililty appExtensionDummies];
  MSACAppExtension *appExt = [MSACModelTestsUtililty appExtensionWithDummyValues:appExtDummyValues];
  NSDictionary *protocolExtDummyValues = [MSACModelTestsUtililty protocolExtensionDummies];
  MSACProtocolExtension *protocolExt = [MSACModelTestsUtililty protocolExtensionWithDummyValues:protocolExtDummyValues];
  NSDictionary *netExtDummyValues = [MSACModelTestsUtililty netExtensionDummies];
  MSACNetExtension *netExt = [MSACModelTestsUtililty netExtensionWithDummyValues:netExtDummyValues];
  NSDictionary *sdkExtDummyValues = [MSACModelTestsUtililty sdkExtensionDummies];
  MSACSDKExtension *sdkExt = [MSACModelTestsUtililty sdkExtensionWithDummyValues:sdkExtDummyValues];
  NSDictionary *deviceExtDummyValues = [MSACModelTestsUtililty deviceExtensionDummies];
  MSACDeviceExtension *deviceExt = [MSACModelTestsUtililty deviceExtensionWithDummyValues:deviceExtDummyValues];

  return [@{
    kMSACCSUserExt : userExt,
    kMSACCSLocExt : locExt,
    kMSACCSOSExt : osExt,
    kMSACCSAppExt : appExt,
    kMSACCSProtocolExt : protocolExt,
    kMSACCSNetExt : netExt,
    kMSACCSSDKExt : sdkExt,
    kMSACCSDeviceExt : deviceExt
  } mutableCopy];
}

+ (NSDictionary *)metadataExtensionDummies {
  return @{kMSACFieldDelimiter : @{@"baseData" : @{kMSACFieldDelimiter : @{@"screenSize" : @2}}}};
}

+ (NSDictionary *)userExtensionDummies {
  return @{kMSACUserLocalId : @"c:bob", kMSACUserLocale : @"en-us"};
}

+ (NSDictionary *)locExtensionDummies {
  return @{kMSACTimezone : @"-03:00"};
}

+ (NSDictionary *)osExtensionDummies {
  return @{kMSACOSName : @"iOS", kMSACOSVer : @"9.0"};
}

+ (NSDictionary *)appExtensionDummies {
  return @{kMSACAppId : @"com.some.bundle.id", kMSACAppVer : @"3.4.1", kMSACAppLocale : @"en-us", kMSACAppUserId : @"c:alice"};
}

+ (NSDictionary *)protocolExtensionDummies {
  return @{kMSACTicketKeys : @[ @"ticketKey1", @"ticketKey2" ], kMSACDevMake : @"Apple", kMSACDevModel : @"iPhone X"};
}

+ (NSDictionary *)netExtensionDummies {
  return @{kMSACNetProvider : @"Verizon"};
}

+ (NSMutableDictionary *)sdkExtensionDummies {
  return [@{kMSACSDKLibVer : @"1.2.0", kMSACSDKEpoch : MSAC_UUID_STRING, kMSACSDKSeq : @1, kMSACSDKInstallId : [NSUUID new]} mutableCopy];
}

+ (NSMutableDictionary *)deviceExtensionDummies {
  return [@{kMSACDeviceLocalId : @"00000000-0000-0000-0000-000000000000"} mutableCopy];
}

+ (MSACOrderedDictionary *)orderedDataDummies {
  MSACOrderedDictionary *data = [MSACOrderedDictionary new];
  [data setObject:@"aBaseType" forKey:@"baseType"];
  [data setObject:@"someValue" forKey:@"baseData"];
  [data setObject:@"anothervalue" forKey:@"anested.key"];
  [data setObject:@"aValue" forKey:@"aKey"];
  [data setObject:@"yetanothervalue" forKey:@"anotherkey"];
  return data;
}

+ (NSDictionary *)unorderedDataDummies {
  NSDictionary *data = @{
    @"baseType" : @"aBaseType",
    @"baseData" : @"someValue",
    @"anested.key" : @"anothervalue",
    @"aKey" : @"aValue",
    @"anotherkey" : @"yetanothervalue"
  };

  return data;
}

+ (MSACDevice *)dummyDevice {
  NSDictionary *dummyValues = [self deviceDummies];
  MSACDevice *device = [MSACDevice new];
  device.sdkVersion = dummyValues[kMSACSDKVersion];
  device.sdkName = dummyValues[kMSACSDKName];
  device.model = dummyValues[kMSACModel];
  device.oemName = dummyValues[kMSACOEMName];
  device.osName = dummyValues[kMSACACOSName];
  device.osVersion = dummyValues[kMSACOSVersion];
  device.osBuild = dummyValues[kMSACOSBuild];
  device.locale = dummyValues[kMSACLocale];
  device.timeZoneOffset = dummyValues[kMSACTimeZoneOffset];
  device.screenSize = dummyValues[kMSACScreenSize];
  device.appVersion = dummyValues[kMSACAppVersion];
  device.appBuild = dummyValues[kMSACAppBuild];
  device.appNamespace = dummyValues[kMSACAppNamespace];
  device.carrierName = dummyValues[kMSACCarrierName];
  device.carrierCountry = dummyValues[kMSACCarrierCountry];
  device.wrapperSdkVersion = dummyValues[kMSACWrapperSDKVersion];
  device.wrapperSdkName = dummyValues[kMSACWrapperSDKName];
  device.wrapperRuntimeVersion = dummyValues[kMSACWrapperRuntimeVersion];
  device.liveUpdateReleaseLabel = dummyValues[kMSACLiveUpdateReleaseLabel];
  device.liveUpdateDeploymentKey = dummyValues[kMSACLiveUpdateDeploymentKey];
  device.liveUpdatePackageHash = dummyValues[kMSACLiveUpdatePackageHash];
  return device;
}

#pragma mark - MSACAbstractLog

+ (NSDictionary *)abstractLogDummies {
  return @{
    kMSACType : @"fakeLogType",
    kMSACTimestamp : [NSDate dateWithTimeIntervalSince1970:42],
    kMSACSId : @"FAKE-SESSION-ID",
    kMSACDistributionGroupId : @"FAKE-GROUP-ID",
    kMSACDevice : [self dummyDevice]
  };
}

+ (void)populateAbstractLogWithDummies:(MSACAbstractLog *)log {
  NSDictionary *dummyValues = [self abstractLogDummies];
  log.type = dummyValues[kMSACType];
  log.timestamp = dummyValues[kMSACTimestamp];
  log.sid = dummyValues[kMSACSId];
  log.distributionGroupId = dummyValues[kMSACDistributionGroupId];
  log.device = dummyValues[kMSACDevice];
}

#pragma mark - Extensions

+ (MSACCSExtensions *)extensionsWithDummyValues:(NSDictionary *)dummyValues {
  MSACCSExtensions *ext = [MSACCSExtensions new];
  ext.userExt = dummyValues[kMSACCSUserExt];
  ext.locExt = dummyValues[kMSACCSLocExt];
  ext.osExt = dummyValues[kMSACCSOSExt];
  ext.appExt = dummyValues[kMSACCSAppExt];
  ext.protocolExt = dummyValues[kMSACCSProtocolExt];
  ext.netExt = dummyValues[kMSACCSNetExt];
  ext.sdkExt = dummyValues[kMSACCSSDKExt];
  ext.deviceExt = dummyValues[kMSACCSDeviceExt];
  return ext;
}

+ (MSACUserExtension *)userExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACUserExtension *userExt = [MSACUserExtension new];
  userExt.localId = dummyValues[kMSACUserLocalId];
  userExt.locale = dummyValues[kMSACUserLocale];
  return userExt;
}

+ (MSACLocExtension *)locExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACLocExtension *locExt = [MSACLocExtension new];
  locExt.tz = dummyValues[kMSACTimezone];
  return locExt;
}

+ (MSACOSExtension *)osExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACOSExtension *osExt = [MSACOSExtension new];
  osExt.name = dummyValues[kMSACOSName];
  osExt.ver = dummyValues[kMSACOSVer];
  return osExt;
}

+ (MSACAppExtension *)appExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACAppExtension *appExt = [MSACAppExtension new];
  appExt.appId = dummyValues[kMSACAppId];
  appExt.ver = dummyValues[kMSACAppVer];
  appExt.locale = dummyValues[kMSACAppLocale];
  appExt.userId = dummyValues[kMSACAppUserId];
  return appExt;
}

+ (MSACProtocolExtension *)protocolExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACProtocolExtension *protocolExt = [MSACProtocolExtension new];
  protocolExt.ticketKeys = dummyValues[kMSACTicketKeys];
  protocolExt.devMake = dummyValues[kMSACDevMake];
  protocolExt.devModel = dummyValues[kMSACDevModel];
  return protocolExt;
}

+ (MSACNetExtension *)netExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACNetExtension *netExt = [MSACNetExtension new];
  netExt.provider = dummyValues[kMSACNetProvider];
  return netExt;
}

+ (MSACSDKExtension *)sdkExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACSDKExtension *sdkExt = [MSACSDKExtension new];
  sdkExt.libVer = dummyValues[kMSACSDKLibVer];
  sdkExt.epoch = dummyValues[kMSACSDKEpoch];
  sdkExt.seq = [dummyValues[kMSACSDKSeq] longLongValue];
  sdkExt.installId = dummyValues[kMSACSDKInstallId];
  return sdkExt;
}

+ (MSACDeviceExtension *)deviceExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACDeviceExtension *deviceExt = [MSACDeviceExtension new];
  deviceExt.localId = dummyValues[kMSACDeviceLocalId];
  return deviceExt;
}

+ (MSACMetadataExtension *)metadataExtensionWithDummyValues:(NSDictionary *)dummyValues {
  MSACMetadataExtension *metadataExt = [MSACMetadataExtension new];
  metadataExt.metadata = dummyValues;
  return metadataExt;
}

+ (MSACCSData *)dataWithDummyValues:(NSDictionary *)dummyValues {
  MSACCSData *data = [MSACCSData new];
  data.properties = [dummyValues mutableCopy];
  return data;
}

@end
