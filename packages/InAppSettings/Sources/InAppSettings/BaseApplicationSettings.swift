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

public enum LiteModeKey : String {
    case any
    case emoji_effects
    case emoji
    case blur
    case dynamic_background
    case gif
    case video
    case stickers
    case animations
    case menu_animations
}

public struct LiteMode : Codable, Equatable {
    
    
    public static var allKeys: [LiteModeKey] {
        return [.video, .gif, .stickers, .emoji, .emoji_effects, .animations, .blur, .menu_animations]
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LiteMode.CodingKeys.self)
        try container.encode(self.enabled, forKey: LiteMode.CodingKeys.enabled)
        try container.encode(self.lowBatteryPercent, forKey: LiteMode.CodingKeys.lowBatteryPercent)
        try container.encode(self.keys.map { $0.rawValue }, forKey: LiteMode.CodingKeys.keys)
    }
    
    enum CodingKeys: CodingKey {
        case enabled
        case lowBatteryPercent
        case keys
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<LiteMode.CodingKeys> = try decoder.container(keyedBy: LiteMode.CodingKeys.self)
        self.enabled = try container.decode(Bool.self, forKey: LiteMode.CodingKeys.enabled)
        self.lowBatteryPercent = try container.decode(Int32.self, forKey: LiteMode.CodingKeys.lowBatteryPercent)
        let keys = try container.decode([String].self, forKey: LiteMode.CodingKeys.keys)
        self.keys = keys.compactMap {
            .init(rawValue: $0)
        }
    }
    
    init(enabled: Bool, lowBatteryPercent: Int32, keys: [LiteModeKey]) {
        self.enabled = enabled
        self.lowBatteryPercent = lowBatteryPercent
        self.keys = keys
    }
    
    public var enabled: Bool
    public var lowBatteryPercent: Int32
    public var keys: [LiteModeKey]
    
    public static var standart: LiteMode {
        return .init(enabled: false, lowBatteryPercent: 100, keys: LiteMode.allKeys)
    }
    
    public func isEnabled(key: LiteModeKey) -> Bool {
        return self.keys.contains(key)
    }
            
}

public class BaseApplicationSettings: Codable, Equatable {
    
    
    
    public struct TranslatePaywall : Codable, Equatable {
        public var timestamp: Int32
        public var count: Int32
        
        public static func initialize() -> TranslatePaywall {
            return .init(timestamp: Int32(Date().timeIntervalSince1970 - 5), count: 1)
        }
        
        public var show: Bool {
            if count < 3 {
                return false
            }
            if Int32(Date().timeIntervalSince1970) > timestamp {
                return true
            }
            return false
        }
        public func increase() -> TranslatePaywall {
            return .init(timestamp: self.timestamp, count: self.count + 1)
        }
        public func flush() -> TranslatePaywall {
            return .init(timestamp: Int32(Date().timeIntervalSince1970) + 7 * 24 * 60 * 60, count: 1)
        }
    }
    
    public let handleInAppKeys: Bool
    public let sidebar: Bool
    public let showCallsTab: Bool
    public let latestArticles: Bool
    public let predictEmoji: Bool
    public let bigEmoji: Bool
    public let statusBar: Bool
    public let translateChats: Bool
    public let doNotTranslate: Set<String>
    public let paywall: TranslatePaywall?
    public let liteMode: LiteMode
    public let highQualityStories: Bool

    public static var defaultSettings: BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: false, sidebar: true, showCallsTab: true, latestArticles: true, predictEmoji: true, bigEmoji: true, statusBar: true, translateChannels: true, doNotTranslate: Set(), paywall: nil, liteMode: .standart, highQualityStories: false)
    }
    
    init(handleInAppKeys: Bool, sidebar: Bool, showCallsTab: Bool, latestArticles: Bool, predictEmoji: Bool, bigEmoji: Bool, statusBar: Bool, translateChannels: Bool, doNotTranslate: Set<String>, paywall: TranslatePaywall?, liteMode: LiteMode, highQualityStories: Bool) {
        self.handleInAppKeys = handleInAppKeys
        self.sidebar = sidebar
        self.showCallsTab = showCallsTab
        self.latestArticles = latestArticles
        self.predictEmoji = predictEmoji
        self.bigEmoji = bigEmoji
        self.statusBar = statusBar
        self.translateChats = translateChannels
        self.doNotTranslate = doNotTranslate
        self.paywall = paywall
        self.liteMode = liteMode
        self.highQualityStories = highQualityStories
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
        self.translateChats = try container.decodeIfPresent(Int32.self, forKey: "tc") ?? 1 != 0
        self.doNotTranslate = try container.decodeIfPresent(Set<String>.self, forKey: "dnt2") ?? Set()
        self.paywall = try container.decodeIfPresent(TranslatePaywall.self, forKey: "tp7")
        self.liteMode = try container.decodeIfPresent(LiteMode.self, forKey: "lm5") ?? LiteMode.standart
        self.highQualityStories =  try container.decodeIfPresent(Bool.self, forKey: "hqs") ?? false
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
        try container.encode(Int32(self.translateChats ? 1 : 0), forKey: "tc")
        try container.encode(self.doNotTranslate, forKey: "dnt2")
        try container.encode(self.liteMode, forKey: "lm5")
        if let paywall = paywall {
            try container.encode(paywall, forKey: "tp7")
        }
        try container.encode(self.highQualityStories, forKey: "hqs")
    }
    
    public func withUpdatedShowCallsTab(_ showCallsTab: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedSidebar(_ sidebar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    public func withUpdatedTranslateChannels(_ translateChannels: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: translateChannels, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedInAppKeyHandle(_ handleInAppKeys: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedLatestArticles(_ latestArticles: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedPredictEmoji(_ predictEmoji: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedBigEmoji(_ bigEmoji: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    
    public func withUpdatedStatusBar(_ statusBar: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    public func withUpdatedDoNotTranslate(_ doNotTranslate: Set<String>) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    public func withUpdatedPaywall(_ paywall: TranslatePaywall?) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: paywall, liteMode: self.liteMode, highQualityStories: self.highQualityStories)
    }
    public func withUpdatedStoriesQuaility(_ highQualityStories: Bool) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: self.paywall, liteMode: self.liteMode, highQualityStories: highQualityStories)
    }
    public func updateLiteMode(_ f: (LiteMode)->LiteMode) -> BaseApplicationSettings {
        return BaseApplicationSettings(handleInAppKeys: self.handleInAppKeys, sidebar: self.sidebar, showCallsTab: self.showCallsTab, latestArticles: self.latestArticles, predictEmoji: self.predictEmoji, bigEmoji: self.bigEmoji, statusBar: self.statusBar, translateChannels: self.translateChats, doNotTranslate: self.doNotTranslate, paywall: paywall, liteMode: f(self.liteMode), highQualityStories: self.highQualityStories)
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
        if lhs.translateChats != rhs.translateChats {
            return false
        }
        if lhs.doNotTranslate != rhs.doNotTranslate {
            return false
        }
        if lhs.paywall != rhs.paywall {
            return false
        }
        if lhs.liteMode != rhs.liteMode {
            return false
        }
        if lhs.highQualityStories != rhs.highQualityStories {
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
