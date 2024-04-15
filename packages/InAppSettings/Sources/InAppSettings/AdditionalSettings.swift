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
import TelegramCore


public struct AdditionalSettings: Codable, Equatable {
    public let useTouchId: Bool
    public let previewChats: Bool
    public static var defaultSettings: AdditionalSettings {
        return AdditionalSettings(useTouchId: false, previewChats: true)
    }
    
    public init(useTouchId: Bool, previewChats: Bool) {
        self.useTouchId = useTouchId
        self.previewChats = previewChats
    }
    
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.useTouchId = try container.decode(Bool.self, forKey: "ti")
        self.previewChats = try container.decodeIfPresent(Bool.self, forKey: "pc") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.useTouchId, forKey: "ti")
        try container.encode(self.previewChats, forKey: "pc")
    }
    
    
    public static func ==(lhs: AdditionalSettings, rhs: AdditionalSettings) -> Bool {
        return lhs.useTouchId == rhs.useTouchId && lhs.previewChats == rhs.previewChats
    }
    
    public func withUpdatedTouchId(_ useTouchId: Bool) -> AdditionalSettings {
        return AdditionalSettings(useTouchId: useTouchId, previewChats: self.previewChats)
    }
    public func withUpdatedPreviewChats(_ previewChats: Bool) -> AdditionalSettings {
        return AdditionalSettings(useTouchId: self.useTouchId, previewChats: previewChats)
    }
}

public func updateAdditionalSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (AdditionalSettings) -> AdditionalSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.additionalSettings, { entry in
            let currentSettings: AdditionalSettings
            if let entry = entry?.get(AdditionalSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = AdditionalSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

public func additionalSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<AdditionalSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.additionalSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.additionalSettings]?.get(AdditionalSettings.self) ?? AdditionalSettings.defaultSettings
    }
}

