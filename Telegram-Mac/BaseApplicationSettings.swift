//
//  BaseApplicationSettings.swift
//  Telegram
//
//  Created by keepcoder on 05/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
class BaseApplicationSettings: PreferencesEntry, Equatable {
    let handleInAppKeys: Bool
    let sidebar: Bool
    let showCallsTab: Bool
    let latestArticles: Bool
    let predictEmoji: Bool
    static var defaultSettings: BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: false, sidebar: true, showCallsTab: true, latestArticles: true, predictEmoji: true)
    }
    
    init(handleInAppKeys: Bool, sidebar: Bool, showCallsTab: Bool, latestArticles: Bool, predictEmoji: Bool) {
        self.handleInAppKeys = handleInAppKeys
        self.sidebar = sidebar
        self.showCallsTab = showCallsTab
        self.latestArticles = latestArticles
        self.predictEmoji = predictEmoji
    }
    
    required init(decoder: PostboxDecoder) {
        self.showCallsTab = decoder.decodeInt32ForKey("c", orElse: 1) != 0
        self.handleInAppKeys = decoder.decodeInt32ForKey("h", orElse: 0) != 0
        self.sidebar = decoder.decodeInt32ForKey("e", orElse: 0) != 0
        self.latestArticles = decoder.decodeInt32ForKey("la", orElse: 1) != 0
        self.predictEmoji = decoder.decodeInt32ForKey("pe", orElse: 1) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.showCallsTab ? 1 : 0, forKey: "c")
        encoder.encodeInt32(self.handleInAppKeys ? 1 : 0, forKey: "h")
        encoder.encodeInt32(self.sidebar ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.latestArticles ? 1 : 0, forKey: "la")
        encoder.encodeInt32(self.predictEmoji ? 1 : 0, forKey: "pe")
    }
    
    func withUpdatedShowCallsTab(_ showCallsTab: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji)
    }
    
    func withUpdatedSidebar(_ sidebar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji)
    }
    
    func withUpdatedInAppKeyHandle(_ handleInAppKeys: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji)
    }
    
    func withUpdatedLatestArticles(_ latestArticles: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: latestArticles, predictEmoji: self.predictEmoji)
    }
    
    func withUpdatedPredictEmoji(_ predictEmoji: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: predictEmoji)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? BaseApplicationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: BaseApplicationSettings, rhs: BaseApplicationSettings) -> Bool {
        if lhs.showCallsTab != rhs.showCallsTab {
            return false
        }
        if lhs.handleInAppKeys != rhs.handleInAppKeys {
            return false
        }
        if lhs.sidebar != rhs.sidebar {
            return false
        }
        if lhs.latestArticles != rhs.latestArticles {
            return false
        }
        if lhs.predictEmoji != rhs.predictEmoji {
            return false
        }
        return true
    }

}


func baseAppSettings(accountManager: AccountManager) -> Signal<BaseApplicationSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.baseAppSettings]) |> map { prefs in
        return prefs.entries[ApplicationSharedPreferencesKeys.baseAppSettings] as? BaseApplicationSettings ?? BaseApplicationSettings.defaultSettings
    }
}

func updateBaseAppSettingsInteractively(accountManager: AccountManager, _ f: @escaping (BaseApplicationSettings) -> BaseApplicationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.baseAppSettings, { entry in
            let currentSettings: BaseApplicationSettings
            if let entry = entry as? BaseApplicationSettings {
                currentSettings = entry
            } else {
                currentSettings = BaseApplicationSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
