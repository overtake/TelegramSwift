//
//  ChatVideoMessageItem.swift
//  Telegram
//
//  Created by keepcoder on 14/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox


class ChatMediaVideoMessageLayoutParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool
    let resource: TelegramMediaResource
    let showPlayer:(APController) -> Void
    let isMarked:Bool
    let duration: Double
    let durationLayout:TextViewLayout
    
    var transcribe:()->Void = {}
    fileprivate(set) var transcribeData: ChatMediaVoiceLayoutParameters.TranscribeData?
    
    init(showPlayer:@escaping(APController) -> Void, duration: Double, isMarked:Bool, isWebpage: Bool, resource: TelegramMediaResource, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool, autoplayMedia: AutoplayMediaPreferences, isRevealed: Bool?) {
        self.showPlayer = showPlayer
        self.duration = duration
        self.isMarked = isMarked
        self.isWebpage = isWebpage
        self.resource = resource
        self.durationLayout = TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: duration), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: autoplayMedia, isRevealed: isRevealed)
    }
    
    func duration(for duration:TimeInterval) -> TextViewLayout {
        return TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: Int(duration)), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
    }
}

class ChatVideoMessageItem: ChatMediaItem {

    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, theme: theme)


        let parameters: ChatMediaVideoMessageLayoutParameters = ChatMediaLayoutParameters.layout(for: media as! TelegramMediaFile, isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), autoplayMedia: object.autoplayMedia) as! ChatMediaVideoMessageLayoutParameters
        
        let message = object.message!
        parameters.transcribe = { [weak self] in
            self?.chatInteraction.transcribeAudio(message)
        }
        if context.isPremium {
            
            var pending: Bool
            if let transcribe = message.audioTranscription {
                pending = transcribe.isPending
            } else {
                pending = false
            }
            let bgColor: NSColor
            let fgColor: NSColor
            if renderType == .list {
                bgColor = theme.colors.accent.withAlphaComponent(0.1)
                fgColor = parameters.presentation.activityBackground
            } else {
                bgColor = theme.chatServiceItemColor
                fgColor = theme.chatServiceItemTextColor
            }
            
            parameters.transcribeData = .init(state: .possible, text: nil, isPending: pending, fontColor: fgColor, backgroundColor: bgColor)
        }
        self.parameters = parameters
    }
    
    var canTranscribe: Bool {
        return canTranscribeMessage(message!, context: context)
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
