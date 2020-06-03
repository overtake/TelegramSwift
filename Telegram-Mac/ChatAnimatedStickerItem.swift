//
//  ChatAnimatedStickerItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

final class ChatAnimatedStickerMediaLayoutParameters : ChatMediaLayoutParameters {
    let playPolicy: LottiePlayPolicy?
    let alwaysAccept: Bool?
    let cache: ASCachePurpose?
    let hidePlayer: Bool
    init(playPolicy: LottiePlayPolicy?, alwaysAccept: Bool? = nil, cache: ASCachePurpose? = nil, hidePlayer: Bool = false, media: TelegramMediaFile) {
        self.playPolicy = playPolicy
        self.alwaysAccept = alwaysAccept
        self.cache = cache
        self.hidePlayer = hidePlayer
        super.init(presentation: .empty, media: media, automaticDownload: true, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
}

class ChatAnimatedStickerItem: ChatMediaItem {

}
