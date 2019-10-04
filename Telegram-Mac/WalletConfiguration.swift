//
//  WalletConfiguration.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

public struct WalletConfiguration {
    static var defaultValue: WalletConfiguration {
        return WalletConfiguration(config: nil)
    }
    
    public let config: String?
    
    fileprivate init(config: String?) {
        self.config = config
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String {
            return WalletConfiguration(config: config)
        } else {
            return .defaultValue
        }
    }
}

func walletConfiguration(postbox: Postbox) -> Signal<WalletConfiguration, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]) |> map { view in
        let appConfiguration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
        let configuration = WalletConfiguration.with(appConfiguration: appConfiguration)
        return configuration
    } |> deliverOnMainQueue
}
