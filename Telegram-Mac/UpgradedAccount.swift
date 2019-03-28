//
//  UpgradedAccount.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


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


public func upgradedAccounts(accountManager: AccountManager, rootPath: String) -> Signal<Never, NoError> {
    return accountManager.transaction { transaction -> (Int32, AccountRecordId?) in
        return (transaction.getVersion(), transaction.getCurrent()?.0)
        }
        |> mapToSignal { version, currentId -> Signal<Never, NoError> in
            var signal: Signal<Never, NoError> = .complete()
            if version < 1 {
                if let currentId = currentId {
                    let upgradePreferences = accountPreferenceEntries(rootPath: rootPath, id: currentId, keys: Set(preferencesKeyMapping.keys.map({ $0.key }) + applicationSpecificPreferencesKeyMapping.keys.map({ $0.key })))
                        |> mapToSignal { path, values -> Signal<Void, NoError> in
                            return accountManager.transaction { transaction -> Void in
                                for (key, value) in values {
                                    var upgradedKey: ValueBoxKey?
                                    for (k, v) in preferencesKeyMapping {
                                        if k.key == key {
                                            upgradedKey = v.key
                                            break
                                        }
                                    }
                                    for (k, v) in applicationSpecificPreferencesKeyMapping {
                                        if k.key == key {
                                            upgradedKey = v.key
                                            break
                                        }
                                    }
                                    if let upgradedKey = upgradedKey {
                                        transaction.updateSharedData(upgradedKey, { _ in
                                            return upgradedSharedDataValue(value)
                                        })
                                    }
                                }
                                
                                transaction.setVersion(1)
                            }
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradePreferences)
                } else {
                    let upgradePreferences = accountManager.transaction { transaction -> Void in
                        transaction.setVersion(1)
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradePreferences)
                }
            }
            if version < 2 {
                if let currentId = currentId {
                    let upgradeNotices = accountNoticeEntries(rootPath: rootPath, id: currentId)
                        |> mapToSignal { path, values -> Signal<Void, NoError> in
                            return accountManager.transaction { transaction -> Void in
                                for (key, value) in values {
                                    transaction.setNotice(NoticeEntryKey(namespace: ValueBoxKey(length: 0), key: key), value)
                                }
                                
                                transaction.setVersion(2)
                            }
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradeNotices)
                } else {
                    let upgradeNotices = accountManager.transaction { transaction -> Void in
                        transaction.setVersion(2)
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradeNotices)
                }
                
                let upgradeSortOrder = accountManager.transaction { transaction -> Void in
                    var index: Int32 = 0
                    for record in transaction.getRecords() {
                        transaction.updateRecord(record.id, { _ in
                            return AccountRecord(id: record.id, attributes: record.attributes + [AccountSortOrderAttribute(order: index)], temporarySessionId: record.temporarySessionId)
                        })
                        index += 1
                    }
                    }
                    |> ignoreValues
                signal = signal |> then(upgradeSortOrder)
            }
            if version < 3 {
                if let currentId = currentId {
                    let upgradeAccessChallengeData = accountLegacyAccessChallengeData(rootPath: rootPath, id: currentId)
                        |> mapToSignal { accessChallengeData -> Signal<Void, NoError> in
                            return accountManager.transaction { transaction -> Void in
                                if case .none = transaction.getAccessChallengeData() {
                                    transaction.setAccessChallengeData(accessChallengeData)
                                }
                                
                                transaction.setVersion(3)
                            }
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradeAccessChallengeData)
                } else {
                    let upgradeAccessChallengeData = accountManager.transaction { transaction -> Void in
                        transaction.setVersion(3)
                        }
                        |> ignoreValues
                    signal = signal |> then(upgradeAccessChallengeData)
                }
            }
            return signal
    }
}
