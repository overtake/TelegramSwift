//
//  ChatMusicRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
class ChatMediaMusicLayoutParameters : ChatMediaLayoutParameters {
    let resource: TelegramMediaResource
    let title:String?
    let performer:String?
    let isWebpage: Bool
    let nameLayout:TextViewLayout
    let showPlayer:(APController) -> Void
    let durationLayout:TextViewLayout
    let sizeLayout:TextViewLayout
    init(nameLayout:TextViewLayout, durationLayout:TextViewLayout, sizeLayout:TextViewLayout, resource:TelegramMediaResource, isWebpage: Bool, title:String?, performer:String?, showPlayer:@escaping(APController) -> Void, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.nameLayout = nameLayout
        self.sizeLayout = sizeLayout
        self.durationLayout = durationLayout
        self.showPlayer = showPlayer
        self.isWebpage = isWebpage
        self.title = title
        self.performer = performer
        self.resource = resource
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload)
    }
    
    var file: TelegramMediaFile {
        return media as! TelegramMediaFile
    }
    
    override func makeLabelsForWidth(_ width: CGFloat) {
        nameLayout.measure(width: width - 40)
        durationLayout.measure(width: width - 40)
        sizeLayout.measure(width: width - 40)
    }
}

class ChatMusicRowItem: ChatMediaItem {
    
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
        

        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: chatInteraction.isLogInteraction, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: account, renderType: object.renderType), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(account, object.renderType == .bubble))
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if isForceRightLine {
            return rightSize.height
        }
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            if parameters.durationLayout.layoutSize.width + 50 + rightSize.width + insetBetweenContentAndDate > contentSize.width {
                return rightSize.height
            }
        }
        
        return super.additionalLineForDateInBubbleState
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            parameters.makeLabelsForWidth(width)
            return NSMakeSize(max(parameters.nameLayout.layoutSize.width, parameters.durationLayout.layoutSize.width) + 50, 40)
        }
        return NSZeroSize
    }
}
