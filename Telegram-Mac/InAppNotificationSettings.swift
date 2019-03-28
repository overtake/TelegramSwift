//
//  InAppNotificationSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 31/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


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

import PostboxMac
import SwiftSignalKitMac

struct InAppNotificationSettings: PreferencesEntry, Equatable {
    let enabled: Bool
    let playSounds: Bool
    let tone: String
    let displayPreviews: Bool
    let muteUntil: Int32
    let notifyAllAccounts: Bool
    let totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    let totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory
    let totalUnreadCountIncludeTags: PeerSummaryCounterTags
    let showNotificationsOutOfFocus: Bool
    static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(enabled: true, playSounds: true, tone: "Default", displayPreviews: true, muteUntil: 0, totalUnreadCountDisplayStyle: .filtered, totalUnreadCountDisplayCategory: .chats, totalUnreadCountIncludeTags: [.regularChatsAndPrivateGroups, .channels, .publicGroups], notifyAllAccounts: true, showNotificationsOutOfFocus: true)
    }
    
    init(enabled:Bool, playSounds: Bool, tone: String, displayPreviews: Bool, muteUntil: Int32, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags, notifyAllAccounts: Bool, showNotificationsOutOfFocus: Bool) {
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
    }
    
    init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("e", orElse: 0) != 0
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.tone = decoder.decodeStringForKey("t", orElse: "")
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.muteUntil = decoder.decodeInt32ForKey("m2", orElse: 0)
        self.notifyAllAccounts = decoder.decodeBoolForKey("naa", orElse: true)
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: decoder.decodeInt32ForKey("tds", orElse: 1)) ?? .filtered
        self.totalUnreadCountDisplayCategory = TotalUnreadCountDisplayCategory(rawValue: decoder.decodeInt32ForKey("totalUnreadCountDisplayCategory", orElse: 1)) ?? .chats
        if let value = decoder.decodeOptionalInt32ForKey("totalUnreadCountIncludeTags") {
            self.totalUnreadCountIncludeTags = PeerSummaryCounterTags(rawValue: value)
        } else {
            self.totalUnreadCountIncludeTags = [.regularChatsAndPrivateGroups, .channels, .publicGroups]
        }
        self.showNotificationsOutOfFocus = decoder.decodeInt32ForKey("snoof", orElse: 1) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeString(self.tone, forKey: "t")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.muteUntil, forKey: "m2")
        encoder.encodeBool(self.notifyAllAccounts, forKey: "naa")
        encoder.encodeInt32(self.totalUnreadCountDisplayStyle.rawValue, forKey: "tds")
        encoder.encodeInt32(self.totalUnreadCountDisplayCategory.rawValue, forKey: "totalUnreadCountDisplayCategory")
        encoder.encodeInt32(self.totalUnreadCountIncludeTags.rawValue, forKey: "totalUnreadCountIncludeTags")
        encoder.encodeInt32(self.showNotificationsOutOfFocus ? 1 : 0, forKey: "snoof")
    }
    
    func withUpdatedEnables(_ enabled: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedTone(_ tone: String) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedMuteUntil(_ muteUntil: Int32) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedTotalUnreadCountDisplayCategory(_ totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedTotalUnreadCountDisplayStyle(_ totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedNotifyAllAccounts(_ notifyAllAccounts: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags, notifyAllAccounts: notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedTotalUnreadCountIncludeTags(_ totalUnreadCountIncludeTags: PeerSummaryCounterTags) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: self.showNotificationsOutOfFocus)
    }
    
    func withUpdatedSnoof(_ showNotificationsOutOfFocus: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags, notifyAllAccounts: self.notifyAllAccounts, showNotificationsOutOfFocus: showNotificationsOutOfFocus)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
}

func updateInAppNotificationSettingsInteractively(accountManager: AccountManager, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    
    return accountManager.transaction { transaction in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.inAppNotificationSettings, { entry in
            let currentSettings: InAppNotificationSettings
            if let entry = entry as? InAppNotificationSettings {
                currentSettings = entry
            } else {
                currentSettings = InAppNotificationSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

func appNotificationSettings(accountManager: AccountManager) -> Signal<InAppNotificationSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.inAppNotificationSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
    }
}
