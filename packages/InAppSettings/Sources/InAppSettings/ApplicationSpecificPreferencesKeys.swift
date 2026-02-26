//
//  ApplicationSpecificPreferencesKeys.swift
//  TelegramMac
//
//  Created by keepcoder on 31/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore
import Postbox

private enum ApplicationSpecificPreferencesKeyValues: Int32 {
    case inAppNotificationSettings
    case baseAppSettings
    case additionalSettings = 15
    case themeSettings = 22
    case readArticles = 25
    case autoNight = 26
    case stickerSettings = 29
    case launchSettings = 30
    case automaticMediaDownloadSettings = 31
    case autoplayMedia = 32
    case voiceCallSettings = 34
    case walletPasscodeTimeout = 37
    case passcodeSettings = 38
    case appConfiguration = 39
    case chatListSettings = 47
    case voipDerivedState = 49
    case instantViewAppearance = 50
    case recentEmoji = 52
    case downloadedPaths = 53
    case someSettings = 54
    case dockSettings = 55
}

public struct ApplicationSpecificPreferencesKeys {
    public static let automaticMediaDownloadSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.automaticMediaDownloadSettings.rawValue)
    public static let recentEmoji = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.recentEmoji.rawValue)
    public static let instantViewAppearance = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.instantViewAppearance.rawValue)
    public static let readArticles = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.readArticles.rawValue)
    public static let stickerSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.stickerSettings.rawValue)
    public static let launchSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.launchSettings.rawValue)
    public static let autoplayMedia = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.autoplayMedia.rawValue)
    public static let downloadedPaths = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.downloadedPaths.rawValue)
    public static let walletPasscodeTimeout = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.walletPasscodeTimeout.rawValue)
    public static let chatListSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatListSettings.rawValue)
    public static let voipDerivedState = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.voipDerivedState.rawValue)
    public static let someSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.someSettings.rawValue)
}

public struct ApplicationSharedPreferencesKeys {
    public static let baseAppSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.baseAppSettings.rawValue)
    public static let inAppNotificationSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.inAppNotificationSettings.rawValue)
    public static let themeSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.themeSettings.rawValue)
    public static let autoNight = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.autoNight.rawValue)
    public static let additionalSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.additionalSettings.rawValue)
    public static let voiceCallSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.voiceCallSettings.rawValue)
    public static let passcodeSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.passcodeSettings.rawValue)
    public static let appConfiguration = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.appConfiguration.rawValue)
    public static let dockSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.dockSettings.rawValue)
}


private enum ApplicationSpecificItemCacheCollectionIdValues: Int8 {
    case instantPageStoredState = 0
    case cachedInstantPages = 1
    case pendingInAppPurchaseState = 3
    case storyPostState = 5
    case webAppPermissionsState = 6
    case translationState = 8

}

public struct ApplicationSpecificItemCacheCollectionId {
    public static let instantPageStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.instantPageStoredState.rawValue)
    public static let cachedInstantPages = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedInstantPages.rawValue)
    public static let translationState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.translationState.rawValue)
    public static let pendingInAppPurchaseState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.pendingInAppPurchaseState.rawValue)
    public static let storyPostState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.storyPostState.rawValue)
    public static let webAppPermissionsState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.webAppPermissionsState.rawValue)

}
private enum ApplicationSpecificOrderedItemListCollectionIdValues: Int32 {
    case settingsSearchRecentItems = 0
}

public struct ApplicationSpecificOrderedItemListCollectionId {
    public static let settingsSearchRecentItems = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.settingsSearchRecentItems.rawValue)
}
