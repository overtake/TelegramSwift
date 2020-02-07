//
//  ApplicationSpecificPreferencesKeys.swift
//  TelegramMac
//
//  Created by keepcoder on 31/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore
import SyncCore
import SyncCore
private enum ApplicationSpecificPreferencesKeyValues: Int32 {
    case inAppNotificationSettings
    case baseAppSettings
    case generatedMediaStoreSettings
    case instantViewAppearance = 11
    case additionalSettings = 15
    case themeSettings = 22
    case readArticles = 25
    case autoNight = 26
    case stickerSettings = 29
    case launchSettings = 30
    case automaticMediaDownloadSettings = 31
    case autoplayMedia = 32
    case voiceCallSettings = 34
    case downloadedPaths = 35
    case recentEmoji = 36
    case walletPasscodeTimeout = 37
    case passcodeSettings = 38
    case appConfiguration = 39
    case chatListSettings = 47
}

struct ApplicationSpecificPreferencesKeys {
    static let automaticMediaDownloadSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.automaticMediaDownloadSettings.rawValue)
    static let generatedMediaStoreSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.generatedMediaStoreSettings.rawValue)
    static let recentEmoji = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.recentEmoji.rawValue)
    static let instantViewAppearance = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.instantViewAppearance.rawValue)
    static let readArticles = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.readArticles.rawValue)
    static let stickerSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.stickerSettings.rawValue)
    static let launchSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.launchSettings.rawValue)
    static let autoplayMedia = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.autoplayMedia.rawValue)
    static let downloadedPaths = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.downloadedPaths.rawValue)
    static let walletPasscodeTimeout = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.walletPasscodeTimeout.rawValue)
    static let chatListSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatListSettings.rawValue)

}

struct ApplicationSharedPreferencesKeys {
    static let baseAppSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.baseAppSettings.rawValue)
    static let inAppNotificationSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.inAppNotificationSettings.rawValue)
    static let themeSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.themeSettings.rawValue)
    static let autoNight = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.autoNight.rawValue)
    static let additionalSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.additionalSettings.rawValue)
    static let voiceCallSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.voiceCallSettings.rawValue)
    static let passcodeSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.passcodeSettings.rawValue)
    static let appConfiguration = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.appConfiguration.rawValue)
}


private enum ApplicationSpecificItemCacheCollectionIdValues: Int8 {
    case instantPageStoredState = 0
    case cachedInstantPages = 1
}

public struct ApplicationSpecificItemCacheCollectionId {
    public static let instantPageStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.instantPageStoredState.rawValue)
    public static let cachedInstantPages = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedInstantPages.rawValue)
}
private enum ApplicationSpecificOrderedItemListCollectionIdValues: Int32 {
    case settingsSearchRecentItems = 0
}

public struct ApplicationSpecificOrderedItemListCollectionId {
    public static let settingsSearchRecentItems = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.settingsSearchRecentItems.rawValue)
}
