//
//  PasscodeSettings.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore



struct PasscodeSettings: Codable, Equatable {
    
    let timeout: Int32?
    
    static var defaultValue: PasscodeSettings {
        return PasscodeSettings(timeout: 60 * 5)
    }
    
    init(timeout: Int32?) {
        self.timeout = timeout
    }
    
    
    init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeOptionalInt32ForKey("t")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let timeout = self.timeout {
            encoder.encodeInt32(timeout, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.timeout = try container.decodeIfPresent(Int32.self, forKey: "t")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.timeout, forKey: "t")
    }
    
    
    func withUpdatedTimeout(_ timeout: Int32?) -> PasscodeSettings {
        return PasscodeSettings(timeout: timeout)
    }
}


func passcodeSettings(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) -> PasscodeSettings {
    return transaction.getSharedData(ApplicationSharedPreferencesKeys.passcodeSettings)?.get(PasscodeSettings.self) ?? PasscodeSettings.defaultValue
}

func passcodeSettingsView(_ accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<PasscodeSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.passcodeSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.passcodeSettings]?.get(PasscodeSettings.self) ?? PasscodeSettings.defaultValue
    }
}

func updatePasscodeSettings(_ accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping(PasscodeSettings) -> PasscodeSettings) -> Signal<Never, NoError> {
    return accountManager.transaction { transaction in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.passcodeSettings, { entry in
            let current = entry?.get(PasscodeSettings.self) ?? PasscodeSettings.defaultValue
            
            return PreferencesEntry(f(current))
        })
    }  |> ignoreValues
}
