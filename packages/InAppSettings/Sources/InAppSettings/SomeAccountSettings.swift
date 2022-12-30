//
//  File.swift
//  
//
//  Created by Mike Renoir on 30.12.2022.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore


public struct SomeAccountSettings: Codable, Equatable {
    public var lastChatReindexTime: Int32?
    public var appVersion: String?
    public static var defaultSettings: SomeAccountSettings {
        return SomeAccountSettings(lastChatReindexTime: nil, appVersion: nil)
    }
    
    public init(lastChatReindexTime: Int32?, appVersion: String?) {
        self.lastChatReindexTime = lastChatReindexTime
        self.appVersion = appVersion
    }

}

public func updateSomeSettingsInteractively(postbox: Postbox, _ f: @escaping (SomeAccountSettings) -> SomeAccountSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.someSettings, { entry in
            let settings = entry?.get(SomeAccountSettings.self) ?? SomeAccountSettings.defaultSettings
            return PreferencesEntry(f(settings))
            
        })
    }
}

public func someAccountSetings(postbox: Postbox) -> Signal<SomeAccountSettings, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.someSettings]) |> map { preferences in
        return preferences.values[ApplicationSpecificPreferencesKeys.someSettings]?.get(SomeAccountSettings.self) ?? SomeAccountSettings.defaultSettings
    }
}
