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



struct PasscodeSettings: PreferencesEntry, Equatable {
    
    let timeout: Int32?
    
    static var defaultValue: PasscodeSettings {
        return PasscodeSettings(timeout: 60 * 5)
    }
    
    init(timeout: Int32?) {
        self.timeout = timeout
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let other = to as? PasscodeSettings {
            return other == self
        } else {
            return false
        }
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
    
    
    func withUpdatedTimeout(_ timeout: Int32?) -> PasscodeSettings {
        return PasscodeSettings(timeout: timeout)
    }
}


func passcodeSettings(_ transaction: AccountManagerModifier) -> PasscodeSettings {
    return transaction.getSharedData(ApplicationSharedPreferencesKeys.passcodeSettings) as? PasscodeSettings ?? PasscodeSettings.defaultValue
}

func passcodeSettingsView(_ accountManager: AccountManager) -> Signal<PasscodeSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.passcodeSettings]) |> map { view in
        return view.entries[ApplicationSharedPreferencesKeys.passcodeSettings] as? PasscodeSettings ?? PasscodeSettings.defaultValue
    }
}

func updatePasscodeSettings(_ accountManager: AccountManager, _ f: @escaping(PasscodeSettings) -> PasscodeSettings) -> Signal<Never, NoError> {
    return accountManager.transaction { transaction in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.passcodeSettings, { entry in
            let current = entry as? PasscodeSettings ?? PasscodeSettings.defaultValue
            
            return f(current)
        })
    }  |> ignoreValues
}
