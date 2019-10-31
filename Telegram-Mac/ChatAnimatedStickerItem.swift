//
//  ChatAnimatedStickerItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

final class ChatAnimatedStickerMediaLayoutParameters : ChatMediaLayoutParameters {
    let playPolicy: LottiePlayPolicy?
    let alwaysAccept: Bool?
    let cache: ASCachePurpose?
    init(playPolicy: LottiePlayPolicy?, alwaysAccept: Bool? = nil, cache: ASCachePurpose? = nil, media: TelegramMediaFile) {
        self.playPolicy = playPolicy
        self.alwaysAccept = alwaysAccept
        self.cache = cache
        super.init(presentation: .empty, media: media, automaticDownload: true, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
}

class ChatAnimatedStickerItem: ChatMediaItem {

}
