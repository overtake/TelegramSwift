//
//  QRLoginConfiguration.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramApi

enum QRLoginType : String {
    case primary = "primary"
    case secondary = "secondary"
    case disabled = "disabled"
}
 struct UnauthorizedConfiguration {
    static var defaultValue: UnauthorizedConfiguration {
        return UnauthorizedConfiguration(qr: .disabled)
    }
    
    let qr: QRLoginType
    
    fileprivate init(qr: QRLoginType) {
        self.qr = qr
    }
    public static func with(appConfiguration: AppConfiguration) -> UnauthorizedConfiguration {
        if let data = appConfiguration.data, let rawType = data["qr_login_code"] as? String, let qr = QRLoginType(rawValue: rawType) {
            return UnauthorizedConfiguration(qr: qr)
        } else {
            return .defaultValue
        }
    }
}


func unauthorizedConfiguration(accountManager: AccountManager) -> Signal<UnauthorizedConfiguration, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.appConfiguration]) |> mapToSignal { view in
        if let appConfiguration = view.entries[ApplicationSharedPreferencesKeys.appConfiguration] as? AppConfiguration {
            let configuration = UnauthorizedConfiguration.with(appConfiguration: appConfiguration)
            return .single(configuration)
        } else {
            return .never()
        }
    } |> deliverOnMainQueue
}

private func currentUnauthorizedAppConfiguration(transaction: AccountManagerModifier) -> AppConfiguration {
    if let entry = transaction.getSharedData(ApplicationSharedPreferencesKeys.appConfiguration) as? AppConfiguration {
        return entry
    } else {
        return AppConfiguration.defaultValue
    }
}

private func updateAppConfiguration(transaction: AccountManagerModifier, _ f: (AppConfiguration) -> AppConfiguration) {
    let current = currentUnauthorizedAppConfiguration(transaction: transaction)
    let updated = f(current)
    transaction.updateSharedData(ApplicationSharedPreferencesKeys.appConfiguration, { _ in
        return updated
    })
}


func managedAppConfigurationUpdates(accountManager: AccountManager, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getAppConfig())
            |> retryRequest
            |> mapToSignal { result -> Signal<Void, NoError> in
                return accountManager.transaction { transaction -> Void in
                    if let data = JSON(apiJson: result) {
                        updateAppConfiguration(transaction: transaction, { configuration -> AppConfiguration in
                            var configuration = configuration
                            configuration.data = data
                            return configuration
                        })
                    }
                }
            }).start()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(12.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
