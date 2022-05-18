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
    let channels_limit_default: Int
    let channels_limit_premium: Int
    
    let channels_public_limit_default: Int
    let channels_public_limit_premium: Int
    
    let saved_gifs_limit_default: Int
    let saved_gifs_limit_premium: Int
    
    let stickers_faved_limit_default: Int
    let stickers_faved_limit_premium: Int
    
    let dialog_filters_limit_default: Int
    let dialog_filters_limit_premium: Int
    
    let dialog_filters_chats_limit_default: Int
    let dialog_filters_chats_limit_premium: Int
    
    let dialog_filters_pinned_limit_default: Int
    let dialog_filters_pinned_limit_premium: Int
    
    
    let dialog_pinned_limit_default: Int
    let dialog_pinned_limit_premium: Int

    let caption_length_limit_default: Int
    let caption_length_limit_premium: Int
    
    let upload_max_fileparts_default: Int
    let upload_max_fileparts_premium: Int
    
    let dialogs_folder_pinned_limit_default: Int
    let dialogs_folder_pinned_limit_premium: Int

    
    init(appConfiguration: AppConfiguration) {
        if let data = appConfiguration.data {
            self.channels_limit_default = Int(data["channels_limit_default"] as? Double ?? 500)
            self.channels_limit_premium = Int(data["channels_limit_premium"] as? Double ?? 1000)

            self.channels_public_limit_default = Int(data["channels_public_limit_default"] as? Double ?? 5)
            self.channels_public_limit_premium = Int(data["channels_public_limit_premium"] as? Double ?? 10)

            self.saved_gifs_limit_default = Int(data["saved_gifs_limit_default"] as? Double ?? 25)
            self.saved_gifs_limit_premium = Int(data["saved_gifs_limit_premium"] as? Double ?? 200)

            self.stickers_faved_limit_default = Int(data["stickers_faved_limit_default"] as? Double ?? 5)
            self.stickers_faved_limit_premium = Int(data["stickers_faved_limit_premium"] as? Double ?? 200)

            self.dialog_filters_limit_default = Int(data["dialog_filters_limit_default"] as? Double ?? 10)
            self.dialog_filters_limit_premium = Int(data["dialog_filters_limit_premium"] as? Double ?? 20)

            self.dialog_filters_chats_limit_default = Int(data["dialog_filters_chats_limit_default"] as? Double ?? 100)
            self.dialog_filters_chats_limit_premium = Int(data["dialog_filters_chats_limit_premium"] as? Double ?? 200)

            self.dialog_filters_pinned_limit_default = Int(data["dialog_filters_chats_limit_default"] as? Double ?? 100)
            self.dialog_filters_pinned_limit_premium = Int(data["dialog_filters_chats_limit_premium"] as? Double ?? 200)

            self.dialog_pinned_limit_default = Int(data["dialog_pinned_limit_default"] as? Double ?? 5)
            self.dialog_pinned_limit_premium =  Int(data["dialog_pinned_limit_premium"] as? Double ?? 10)
            
            self.caption_length_limit_default = Int(data["caption_length_limit_default"] as? Double ?? 1024)
            self.caption_length_limit_premium = Int(data["caption_length_limit_premium"] as? Double ?? 2048)
            
            self.upload_max_fileparts_default = Int(data["upload_max_fileparts_default"] as? Double ?? 4000) / 2 * 1024 * 1024
            self.upload_max_fileparts_premium = Int(data["upload_max_fileparts_premium"] as? Double ?? 8000) / 2 * 1024 * 1024

            self.dialogs_folder_pinned_limit_default = Int(data["dialogs_folder_pinned_limit_default"] as? Double ?? 100)
            self.dialogs_folder_pinned_limit_premium = Int(data["dialogs_folder_pinned_limit_premium"] as? Double ?? 200)

            
            
            
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
            
            self.caption_length_limit_default = 1024
            self.caption_length_limit_premium = 2048
            
            self.upload_max_fileparts_default = 4000 / 2 * 1024 * 1024
            self.upload_max_fileparts_premium = 8000 / 2 * 1024 * 1024
            
            self.dialogs_folder_pinned_limit_default = 100
            self.dialogs_folder_pinned_limit_premium = 200

        }
    }
}


func fileSizeLimitExceed(context: AccountContext, fileSize: Int64) -> Bool {
    if context.isPremium {
        return fileSize <= context.premiumLimits.upload_max_fileparts_premium
    } else {
        return fileSize <= context.premiumLimits.upload_max_fileparts_default
    }
}

func showFileLimit(context: AccountContext, fileSize: Int64?) {
    if context.isPremium {
        alert(for: context.window, info: strings().appMaxFileSizeNew(String.prettySized(with: context.premiumLimits.upload_max_fileparts_premium, afterDot: 0, round: true)))
    } else {
        showPremiumLimit(context: context, type: fileSize != nil ? .uploadFile(Int(fileSize!)) : .uploadFile(nil))
    }
}
