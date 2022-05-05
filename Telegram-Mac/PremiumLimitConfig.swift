//
//  PremiumLimitConfig.swift
//  Telegram
//
//  Created by Mike Renoir on 05.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore



final class PremiumLimitConfig {
    let channels_limit_default: Int32
    let channels_limit_premium: Int32
    
    let channels_public_limit_default: Int32
    let channels_public_limit_premium: Int32
    
    let saved_gifs_limit_default: Int32
    let saved_gifs_limit_premium: Int32
    
    let stickers_faved_limit_default: Int32
    let stickers_faved_limit_premium: Int32
    
    let dialog_filters_limit_default: Int32
    let dialog_filters_limit_premium: Int32
    
    let dialog_filters_chats_limit_default: Int32
    let dialog_filters_chats_limit_premium: Int32
    
    let dialog_filters_pinned_limit_default: Int32
    let dialog_filters_pinned_limit_premium: Int32
    
    
    let dialog_pinned_limit_default: Int32
    let dialog_pinned_limit_premium: Int32

    init(appConfiguration: AppConfiguration) {
        if let data = appConfiguration.data {
            self.channels_limit_default = Int32(data["channels_limit_default"] as? Double ?? 500)
            self.channels_limit_premium = Int32(data["channels_limit_premium"] as? Double ?? 1000)

            self.channels_public_limit_default = Int32(data["channels_public_limit_default"] as? Double ?? 5)
            self.channels_public_limit_premium = Int32(data["channels_public_limit_premium"] as? Double ?? 10)

            self.saved_gifs_limit_default = Int32(data["saved_gifs_limit_default"] as? Double ?? 25)
            self.saved_gifs_limit_premium = Int32(data["saved_gifs_limit_premium"] as? Double ?? 200)

            self.stickers_faved_limit_default = Int32(data["stickers_faved_limit_default"] as? Double ?? 5)
            self.stickers_faved_limit_premium = Int32(data["stickers_faved_limit_premium"] as? Double ?? 200)

            self.dialog_filters_limit_default = Int32(data["dialog_filters_limit_default"] as? Double ?? 10)
            self.dialog_filters_limit_premium = Int32(data["dialog_filters_limit_premium"] as? Double ?? 20)

            self.dialog_filters_chats_limit_default = Int32(data["dialog_filters_chats_limit_default"] as? Double ?? 100)
            self.dialog_filters_chats_limit_premium = Int32(data["dialog_filters_chats_limit_premium"] as? Double ?? 200)

            self.dialog_filters_pinned_limit_default = Int32(data["dialog_filters_chats_limit_default"] as? Double ?? 100)
            self.dialog_filters_pinned_limit_premium = Int32(data["dialog_filters_chats_limit_premium"] as? Double ?? 200)

            self.dialog_pinned_limit_default = Int32(data["dialog_pinned_limit_default"] as? Double ?? 5)
            self.dialog_pinned_limit_premium =  Int32(data["dialog_pinned_limit_premium"] as? Double ?? 10)
            
        } else {
            self.channels_limit_default = 500
            self.channels_limit_premium = 1000

            self.channels_public_limit_default = 5
            self.channels_public_limit_premium = 10

            self.saved_gifs_limit_default = 25
            self.saved_gifs_limit_premium = 200

            self.stickers_faved_limit_default = 5
            self.stickers_faved_limit_premium = 200
            
            self.dialog_filters_limit_default = 10
            self.dialog_filters_limit_premium = 20

            self.dialog_filters_chats_limit_default = 100
            self.dialog_filters_chats_limit_premium = 200

            self.dialog_filters_pinned_limit_default = 100
            self.dialog_filters_pinned_limit_premium = 200
            
            self.dialog_pinned_limit_default = 5
            self.dialog_pinned_limit_premium = 10

        }
    }
}
