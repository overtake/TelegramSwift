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
    
}


func unauthorizedConfiguration(network: Network) -> Signal<UnauthorizedConfiguration, NoError> {
    return network.request(Api.functions.help.getAppConfig()) |> retryRequest
        |> map { result -> UnauthorizedConfiguration in
            if let data = JSON(apiJson: result), let rawQr = data["qr_login_code"] as? String, let qr = QRLoginType(rawValue: rawQr) {
                return UnauthorizedConfiguration(qr: .secondary)
            } else {
                return .defaultValue
            }
        }
}


func managedAppConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getAppConfig())
            |> retryRequest
            |> mapToSignal { result -> Signal<Void, NoError> in
                return postbox.transaction { transaction -> Void in
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
