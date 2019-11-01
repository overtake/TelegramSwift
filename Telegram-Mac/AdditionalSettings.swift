//
//  AdditionalSettings.swift
//  Telegram
//
//  Created by keepcoder on 13/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


import Cocoa
import Postbox
import SwiftSignalKit



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

func updateAdditionalSettingsInteractively(accountManager: AccountManager, _ f: @escaping (AdditionalSettings) -> AdditionalSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.additionalSettings, { entry in
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

func additionalSettings(accountManager: AccountManager) -> Signal<AdditionalSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.additionalSettings]) |> map { view in
        return (view.entries[ApplicationSharedPreferencesKeys.additionalSettings] as? AdditionalSettings) ?? AdditionalSettings.defaultSettings
    }
}

