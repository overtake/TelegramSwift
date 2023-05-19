//
//  BaseApplicationSettings.swift
//  Telegram
//
//  Created by keepcoder on 05/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore

public class BaseApplicationSettings: Codable, Equatable {
    public let handleInAppKeys: Bool
    public let sidebar: Bool
    public let showCallsTab: Bool
    public let latestArticles: Bool
    public let predictEmoji: Bool
    public let bigEmoji: Bool
    public let statusBar: Bool
    public static var defaultSettings: BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: false, sidebar: true, showCallsTab: true, latestArticles: true, predictEmoji: true, bigEmoji: true, statusBar: true)
    }
    
    init(handleInAppKeys: Bool, sidebar: Bool, showCallsTab: Bool, latestArticles: Bool, predictEmoji: Bool, bigEmoji: Bool, statusBar: Bool) {
        self.handleInAppKeys = handleInAppKeys
        self.sidebar = sidebar
        self.showCallsTab = showCallsTab
        self.latestArticles = latestArticles
        self.predictEmoji = predictEmoji
        self.bigEmoji = bigEmoji
        self.statusBar = statusBar
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.showCallsTab = try container.decode(Int32.self, forKey: "c") != 0
        self.handleInAppKeys = try container.decode(Int32.self, forKey: "h") != 0
        self.sidebar = try container.decode(Int32.self, forKey: "e") != 0
        self.latestArticles = try container.decode(Int32.self, forKey: "la") != 0
        self.predictEmoji = try container.decode(Int32.self, forKey: "pe") != 0
        self.bigEmoji = try container.decode(Int32.self, forKey: "bi") != 0
        self.statusBar = try container.decode(Int32.self, forKey: "sb") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        
        try container.encode(Int32(self.showCallsTab ? 1 : 0), forKey: "c")
        try container.encode(Int32(self.handleInAppKeys ? 1 : 0), forKey: "h")
        try container.encode(Int32(self.sidebar ? 1 : 0), forKey: "e")
        try container.encode(Int32(self.latestArticles ? 1 : 0), forKey: "la")
        try container.encode(Int32(self.predictEmoji ? 1 : 0), forKey: "pe")
        try container.encode(Int32(self.bigEmoji ? 1 : 0), forKey: "bi")
        try container.encode(Int32(self.statusBar ? 1 : 0), forKey: "sb")
    }
    
    public func withUpdatedShowCallsTab(_ showCallsTab: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedSidebar(_ sidebar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedInAppKeyHandle(_ handleInAppKeys: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedLatestArticles(_ latestArticles: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedPredictEmoji(_ predictEmoji: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedBigEmoji(_ bigEmoji: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: bigEmoji, statusBar: self.statusBar)
    }
    
    public func withUpdatedStatusBar(_ statusBar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: statusBar)
    }
    public static func ==(lhs: BaseApplicationSettings, rhs: BaseApplicationSettings) -> Bool {
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
        if lhs.bigEmoji != rhs.bigEmoji {
            return false
        }
        if lhs.statusBar != rhs.statusBar {
            return false
        }
        return true
    }
}


public func baseAppSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<BaseApplicationSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.baseAppSettings]) |> map { prefs in
        return prefs.entries[ApplicationSharedPreferencesKeys.baseAppSettings]?.get(BaseApplicationSettings.self) ?? BaseApplicationSettings.defaultSettings
    }
}

public func updateBaseAppSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (BaseApplicationSettings) -> BaseApplicationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.baseAppSettings, { entry in
            let currentSettings: BaseApplicationSettings
            if let entry = entry?.get(BaseApplicationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = BaseApplicationSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
