//
//  InAppNotificationSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 31/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//
import Postbox
import SwiftSignalKit
import TelegramCore


public enum TotalUnreadCountDisplayStyle: Int32 {
    case filtered = 0
    case raw = 1
    
    var category: ChatListTotalUnreadStateCategory {
        switch self {
        case .filtered:
            return .filtered
        case .raw:
            return .raw
        }
    }
}

public enum TotalUnreadCountDisplayCategory: Int32 {
    case chats = 0
    case messages = 1
    
    var statsType: ChatListTotalUnreadStateStats {
        switch self {
        case .chats:
            return .chats
        case .messages:
            return .messages
        }
    }
}



private enum PeerMessageSoundValue: Int32 {
    case none
    case bundledModern
    case bundledClassic
    case `default`
}

final class PeerMessageSoundNativeCodable : Codable {
    
    let value: PeerMessageSound
    init(_ value: PeerMessageSound) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
                
        switch try container.decode(Int32.self, forKey: "s1.v") {
            case PeerMessageSoundValue.none.rawValue:
                self.value = .none
            case PeerMessageSoundValue.bundledModern.rawValue:
                self.value = .bundledModern(id: try container.decode(Int32.self, forKey: "s1.i"))
            case PeerMessageSoundValue.bundledClassic.rawValue:
                self.value = .bundledClassic(id: try container.decode(Int32.self, forKey: "s1.i"))
            case PeerMessageSoundValue.default.rawValue:
                self.value = .default
            default:
                self.value = .bundledModern(id: 0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        switch self.value {
            case .none:
                try container.encode(PeerMessageSoundValue.none.rawValue, forKey: "s1.v")
            case let .bundledModern(id):
                try container.encode(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s1.v")
                try container.encode(id, forKey: "s1.i")
            case let .bundledClassic(id):
                try container.encode(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s1.v")
                try container.encode(id, forKey: "s1.i")
            case .default:
                try container.encode(PeerMessageSoundValue.default.rawValue, forKey: "s1.v")
        }
    }
}



public struct InAppNotificationSettings: Codable, Equatable {
    public let enabled: Bool
    public let playSounds: Bool
    public let tone: PeerMessageSound
    public let displayPreviews: Bool
    public let muteUntil: Int32
    public let notifyAllAccounts: Bool
    public let totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    public let totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory
    public let totalUnreadCountIncludeTags: PeerSummaryCounterTags
    public let showNotificationsOutOfFocus: Bool
    public let badgeEnabled: Bool
    public let requestUserAttention: Bool
    public static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(enabled: true, playSounds: true, tone: .default, displayPreviews: true, muteUntil: 0, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .chats, totalUnreadCountIncludeTags: .all, notifyAllAccounts: true, showNotificationsOutOfFocus: true, badgeEnabled: true, requestUserAttention: false)
    }
    
    init(enabled:Bool, playSounds: Bool, tone: PeerMessageSound, displayPreviews: Bool, muteUntil: Int32, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags, notifyAllAccounts: Bool, showNotificationsOutOfFocus: Bool, badgeEnabled: Bool, requestUserAttention: Bool) {
        self.enabled = enabled
        self.playSounds = playSounds
        self.tone = tone
        self.displayPreviews = displayPreviews
        self.muteUntil = muteUntil
        self.notifyAllAccounts = notifyAllAccounts
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
        self.totalUnreadCountDisplayCategory = totalUnreadCountDisplayCategory
        self.totalUnreadCountIncludeTags = totalUnreadCountIncludeTags
        self.showNotificationsOutOfFocus = showNotificationsOutOfFocus
        self.badgeEnabled = badgeEnabled
        self.requestUserAttention = requestUserAttention
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.enabled = try container.decode(Int32.self, forKey: "e") != 0
        self.playSounds = try container.decode(Int32.self, forKey: "s") != 0
        self.tone = try container.decodeIfPresent(PeerMessageSoundNativeCodable.self, forKey: "tone")?.value ?? .default
        self.displayPreviews = try container.decode(Int32.self, forKey: "p") != 0
        self.muteUntil = try container.decode(Int32.self, forKey: "m2")
        self.notifyAllAccounts = try container.decode(Bool.self, forKey: "naa")
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: try container.decode(Int32.self, forKey: "tds")) ?? .filtered
        self.totalUnreadCountDisplayCategory = TotalUnreadCountDisplayCategory(rawValue: try container.decode(Int32.self, forKey: "totalUnreadCountDisplayCategory")) ?? .chats

        if let value = try container.decodeIfPresent(Int32.self, forKey: "totalUnreadCountIncludeTags_2") {
            self.totalUnreadCountIncludeTags = PeerSummaryCounterTags(rawValue: value)
        } else {
            self.totalUnreadCountIncludeTags = .all
        }
        self.showNotificationsOutOfFocus = try container.decode(Int32.self, forKey: "snoof") != 0
        self.badgeEnabled = try container.decode(Bool.self, forKey: "badge")
        self.requestUserAttention = try container.decode(Bool.self, forKey: "requestUserAttention")

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(Int32(self.enabled ? 1 : 0), forKey: "e")
        try container.encode(Int32(self.playSounds ? 1 : 0), forKey: "s")
        try container.encode(PeerMessageSoundNativeCodable(self.tone), forKey: "tone")
        try container.encode(Int32(self.displayPreviews ? 1 : 0), forKey: "p")
        try container.encode(self.muteUntil, forKey: "m2")
        try container.encode(self.notifyAllAccounts, forKey: "naa")
        try container.encode(self.totalUnreadCountDisplayStyle.rawValue, forKey: "tds")
        try container.encode(self.totalUnreadCountDisplayCategory.rawValue, forKey: "totalUnreadCountDisplayCategory")
        try container.encode(self.totalUnreadCountIncludeTags.rawValue, forKey: "totalUnreadCountIncludeTags_2")
        try container.encode(Int32(self.showNotificationsOutOfFocus ? 1 : 0), forKey: "snoof")
        try container.encode(self.badgeEnabled, forKey: "badge")
        try container.encode(self.requestUserAttention, forKey: "requestUserAttention")
    }
    
    public func withUpdatedEnables(_ enabled: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedTone(_ tone: PeerMessageSound) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedMuteUntil(_ muteUntil: Int32) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedTotalUnreadCountDisplayCategory(_ totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedTotalUnreadCountDisplayStyle(_ totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedNotifyAllAccounts(_ notifyAllAccounts: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedTotalUnreadCountIncludeTags(_ totalUnreadCountIncludeTags: PeerSummaryCounterTags) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedSnoof(_ showNotificationsOutOfFocus: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    
    public func withUpdatedBadgeEnabled(_ badgeEnabled: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: badgeEnabled, requestUserAttention: self.requestUserAttention)
    }
    public func withUpdatedRequestUserAttention(_ requestUserAttention: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus, badgeEnabled: self.badgeEnabled, requestUserAttention: requestUserAttention)
    }
}

public func updateInAppNotificationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    
    return accountManager.transaction { transaction in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.inAppNotificationSettings, { entry in
            let currentSettings: InAppNotificationSettings
            if let entry = entry?.get(InAppNotificationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = InAppNotificationSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

public func appNotificationSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<InAppNotificationSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.inAppNotificationSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
    }
}
public func globalNotificationSettings(postbox: Postbox) -> Signal<GlobalNotificationSettingsSet, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.globalNotifications]) |> map { view in
        let viewSettings: GlobalNotificationSettingsSet
        if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            viewSettings = settings.effective
        } else {
            viewSettings = GlobalNotificationSettingsSet.defaultSettings
        }
        return viewSettings
    }
}
