//
//  ChatVideoMessageItem.swift
//  Telegram
//
//  Created by keepcoder on 14/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac


class ChatMediaVideoMessageLayoutParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool
    let resource: TelegramMediaResource
    let showPlayer:(APController) -> Void
    let isMarked:Bool
    let duration:Int
    let durationLayout:TextViewLayout
    init(showPlayer:@escaping(APController) -> Void, duration:Int, isMarked:Bool, isWebpage: Bool, resource: TelegramMediaResource, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.showPlayer = showPlayer
        self.duration = duration
        self.isMarked = isMarked
        self.isWebpage = isWebpage
        self.resource = resource
        self.durationLayout = TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: duration), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload)
    }
    
    func duration(for duration:TimeInterval) -> TextViewLayout {
        return TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: Int(duration)), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
    }
}

class ChatVideoMessageItem: ChatMediaItem {

    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        super.init(initialSize, chatInteraction, account, object, downloadSettings)


        self.parameters = ChatMediaLayoutParameters.layout(for: media as! TelegramMediaFile, isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: account, renderType: object.renderType), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(account, object.renderType == .bubble))
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            parameters.durationLayout.measure(width: width - 50)
            
        }
        return super.makeContentSize(width)
    }
    
}
