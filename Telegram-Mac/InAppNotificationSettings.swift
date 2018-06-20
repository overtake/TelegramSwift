//
//  InAppNotificationSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 31/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
struct InAppNotificationSettings: PreferencesEntry, Equatable {
    let enabled: Bool
    let playSounds: Bool
    let tone: String
    let displayPreviews: Bool
    let muteUntil: Int32
    static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(enabled: true, playSounds: true, tone: "Default", displayPreviews: true, muteUntil: 0)
    }
    
    init(enabled:Bool, playSounds: Bool, tone: String, displayPreviews: Bool, muteUntil: Int32) {
        self.enabled = enabled
        self.playSounds = playSounds
        self.tone = tone
        self.displayPreviews = displayPreviews
        self.muteUntil = muteUntil
    }
    
    init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("e", orElse: 0) != 0
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.tone = decoder.decodeStringForKey("t", orElse: "")
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.muteUntil = decoder.decodeInt32ForKey("m2", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeString(self.tone, forKey: "t")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.muteUntil, forKey: "m2")
    }
    
    func withUpdatedEnables(_ enabled: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil)
    }
    
    func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil)
    }
    
    func withUpdatedTone(_ tone: String) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: tone, displayPreviews: self.displayPreviews, muteUntil: self.muteUntil)
    }
    
    func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: displayPreviews, muteUntil: self.muteUntil)
    }
    
    func withUpdatedMuteUntil(_ muteUntil: Int32) -> InAppNotificationSettings {
        return InAppNotificationSettings(enabled: self.enabled, playSounds: self.playSounds, tone: self.tone, displayPreviews: self.displayPreviews, muteUntil: muteUntil)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: InAppNotificationSettings, rhs: InAppNotificationSettings) -> Bool {
        if lhs.enabled != rhs.enabled {
            return false
        }
        if lhs.playSounds != rhs.playSounds {
            return false
        }
        if lhs.tone != rhs.tone {
            return false
        }
        if lhs.displayPreviews != rhs.displayPreviews {
            return false
        }
        if lhs.muteUntil != rhs.muteUntil {
            return false
        }
        return true
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

func appNotificationSettings(postbox: Postbox) -> Signal<InAppNotificationSettings, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.inAppNotificationSettings]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings) ?? InAppNotificationSettings.defaultSettings
    }
}
