//
//  ChatAnimatedStickerItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import InAppSettings
import SwiftSignalKit
import Postbox
import TelegramMedia

final class ChatAnimatedStickerMediaLayoutParameters : ChatMediaLayoutParameters {
    let playPolicy: LottiePlayPolicy?
    let alwaysAccept: Bool?
    let cache: ASCachePurpose?
    let hidePlayer: Bool?
    var colors: [LottieColor]
    let playOnHover: Bool?
    let thumbAtFrame: Int
    let shimmer: Bool
    let noThumb: Bool
    init(playPolicy: LottiePlayPolicy?, alwaysAccept: Bool? = nil, cache: ASCachePurpose? = nil, hidePlayer: Bool = false, media: TelegramMediaFile, colors: [LottieColor] = [], playOnHover: Bool? = nil, shimmer: Bool = true, thumbAtFrame: Int = 0, noThumb: Bool = false) {
        self.playPolicy = playPolicy
        self.alwaysAccept = alwaysAccept
        self.cache = cache
        self.hidePlayer = hidePlayer
        self.colors = colors
        self.playOnHover = playOnHover
        self.shimmer = shimmer
        self.thumbAtFrame = thumbAtFrame
        self.noThumb = noThumb
        super.init(presentation: .empty, media: media, automaticDownload: true, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
}

class ChatAnimatedStickerItem: ChatMediaItem {
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
        let file = (object.message!.anyMedia as! TelegramMediaFile)
        
        let isPremiumSticker = file.isPremiumSticker
        
        let mirror = ((renderType == .bubble && isIncoming) || renderType == .list)
        parameters?.runEmojiScreenEffect = { [weak chatInteraction] emoji in
            chatInteraction?.runEmojiScreenEffect(emoji, object.message!, mirror, false)
        }
        parameters?.runPremiumScreenEffect = { [weak chatInteraction] message in
            chatInteraction?.runPremiumScreenEffect(message, mirror, false)
        }
        parameters?.mirror = mirror && isPremiumSticker

    }
}
