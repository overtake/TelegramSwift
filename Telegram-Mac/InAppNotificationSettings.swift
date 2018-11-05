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
    let totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    let totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory
    let totalUnreadCountIncludeTags: PeerSummaryCounterTags

    static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(enabled: true, playSounds: true, tone: "Default", displayPreviews: true, muteUntil: 0, totalUnreadCountDisplayStyle: .raw, totalUnreadCountDisplayCategory: .chats, totalUnreadCountIncludeTags: [.regularChatsAndPrivateGroups, .channels, .publicGroups])
    }
    
    init(enabled:Bool, playSounds: Bool, tone: String, displayPreviews: Bool, muteUntil: Int32, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: PeerSummaryCounterTags) {
        self.enabled = enabled
        self.playSounds = playSounds
        self.tone = tone
        self.displayPreviews = displayPreviews
        self.muteUntil = muteUntil
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
        self.totalUnreadCountDisplayCategory = totalUnreadCountDisplayCategory
        self.totalUnreadCountIncludeTags = totalUnreadCountIncludeTags
    }
    
    init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("e", orElse: 0) != 0
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.tone = decoder.decodeStringForKey("t", orElse: "")
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.muteUntil = decoder.decodeInt32ForKey("m2", orElse: 0)
        
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: decoder.decodeInt32ForKey("tds", orElse: 1)) ?? .raw
        self.totalUnreadCountDisplayCategory = TotalUnreadCountDisplayCategory(rawValue: decoder.decodeInt32ForKey("totalUnreadCountDisplayCategory", orElse: 1)) ?? .chats
        if let value = decoder.decodeOptionalInt32ForKey("totalUnreadCountIncludeTags") {
            self.totalUnreadCountIncludeTags = PeerSummaryCounterTags(rawValue: value)
        } else {
            self.totalUnreadCountIncludeTags = [.regularChatsAndPrivateGroups, .channels, .publicGroups]
        }

    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeString(self.tone, forKey: "t")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.muteUntil, forKey: "m2")
        encoder.encodeInt32(self.totalUnreadCountDisplayStyle.rawValue, forKey: "tds")
        encoder.encodeInt32(self.totalUnreadCountDisplayCategory.rawValue, forKey: "totalUnreadCountDisplayCategory")
        encoder.encodeInt32(self.totalUnreadCountIncludeTags.rawValue, forKey: "totalUnreadCountIncludeTags")
    }
    
    func withUpdatedEnables(_ enabled: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedTone(_ tone: String) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: displayPreviews, muteUntil: self.muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedMuteUntil(_ muteUntil: Int32) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedTotalUnreadCountDisplayCategory(_ totalUnreadCountDisplayCategory: TotalUnreadCountDisplayCategory) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedTotalUnreadCountDisplayStyle(_ totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: self.totalUnreadCountIncludeTags)
    }
    
    func withUpdatedTotalUnreadCountIncludeTags(_ totalUnreadCountIncludeTags: PeerSummaryCounterTags) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle, totalUnreadCountDisplayCategory: self.totalUnreadCountDisplayCategory, totalUnreadCountIncludeTags: totalUnreadCountIncludeTags)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
}

func updateInAppNotificationSettingsInteractively(postbox: Postbox, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings, { entry in
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

func appNotificationSettings(postbox: Postbox) -> Signal<InAppNotificationSettings, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.inAppNotificationSettings]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings) ?? InAppNotificationSettings.defaultSettings
    }
}
