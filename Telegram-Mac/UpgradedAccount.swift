//
//  UpgradedAccount.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import SwiftSignalKit


private enum LegacyPreferencesKeyValues: Int32 {
    case cacheStorageSettings = 1
    case localizationSettings = 2
    case proxySettings = 5
    
    var key: ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: self.rawValue)
        return key
    }
}

private enum UpgradedSharedDataKeyValues: Int32 {
    case cacheStorageSettings = 2
    case localizationSettings = 3
    case proxySettings = 4
    
    var key: ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: self.rawValue)
        return key
    }
}



private enum LegacyApplicationSpecificPreferencesKeyValues: Int32 {
    case inAppNotificationSettings = 0
    case baseAppSettings = 1
    case themeSettings = 22
    case autoNight = 26
    case additionalSettings = 15
    case voiceCallSettings = 34
    var key: ValueBoxKey {
        return applicationSpecificPreferencesKey(self.rawValue)
    }
}

private enum UpgradedApplicationSpecificSharedDataKeyValues: Int32 {
    case inAppNotificationSettings = 0
    case baseAppSettings = 1
    case themeSettings = 22
    case autoNight = 26
    case additionalSettings = 15
    case voiceCallSettings = 34
    var key: ValueBoxKey {
        return applicationSpecificSharedDataKey(self.rawValue)
    }
}

private let preferencesKeyMapping: [LegacyPreferencesKeyValues: UpgradedSharedDataKeyValues] = [
    .cacheStorageSettings: .cacheStorageSettings,
    .localizationSettings: .localizationSettings,
    .proxySettings: .proxySettings
]



private let applicationSpecificPreferencesKeyMapping: [LegacyApplicationSpecificPreferencesKeyValues: UpgradedApplicationSpecificSharedDataKeyValues] = [
    .inAppNotificationSettings: .inAppNotificationSettings,
    .themeSettings: .themeSettings
]

private func upgradedSharedDataValue(_ value: PreferencesEntry?) -> PreferencesEntry? {
    return value
}


public func upgradedAccounts(accountManager: AccountManager<TelegramAccountManagerTypes>, rootPath: String, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<Float, NoError> {
    return .complete()
}
