//
//  AdditionalSettings.swift
//  Telegram
//
//  Created by keepcoder on 13/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


import Cocoa
import PostboxMac
import SwiftSignalKitMac



public struct AdditionalSettings: PreferencesEntry, Equatable {
    public let useTouchId: Bool
    
    public static var defaultSettings: AdditionalSettings {
        return AdditionalSettings(useTouchId: false)
    }
    
    init(useTouchId: Bool) {
        self.useTouchId = useTouchId
    }
    
    public init(decoder: PostboxDecoder) {
        self.useTouchId = decoder.decodeBoolForKey("ti", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.useTouchId, forKey: "ti")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AdditionalSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: AdditionalSettings, rhs: AdditionalSettings) -> Bool {
        return lhs.useTouchId == rhs.useTouchId
    }
    
    func withUpdatedTouchId(_ useTouchId: Bool) -> AdditionalSettings {
        return AdditionalSettings(useTouchId: useTouchId)
    }
}

func updateAdditionalSettingsInteractively(postbox: Postbox, _ f: @escaping (AdditionalSettings) -> AdditionalSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.additionalSettings, { entry in
            let currentSettings: AdditionalSettings
            if let entry = entry as? AdditionalSettings {
                currentSettings = entry
            } else {
                currentSettings = AdditionalSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

func additionalSettings(postbox: Postbox) -> Signal<AdditionalSettings, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.additionalSettings]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.additionalSettings] as? AdditionalSettings) ?? AdditionalSettings.defaultSettings
    }
}

