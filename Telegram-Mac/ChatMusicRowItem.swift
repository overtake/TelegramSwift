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
    init(nameLayout:TextViewLayout, durationLayout:TextViewLayout, sizeLayout:TextViewLayout, resource:TelegramMediaResource, isWebpage: Bool, title:String?, performer:String?, showPlayer:@escaping(APController) -> Void) {
        self.nameLayout = nameLayout
        self.sizeLayout = sizeLayout
        self.durationLayout = durationLayout
        self.showPlayer = showPlayer
        self.isWebpage = isWebpage
        self.title = title
        self.performer = performer
        self.resource = resource
    }
    
    override func makeLabelsForWidth(_ width: CGFloat) {
        nameLayout.measure(width: width - 20)
        durationLayout.measure(width: width - 20)
        sizeLayout.measure(width: width - 20)
    }
}

class ChatMusicRowItem: ChatMediaItem {
    
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        super.init(initialSize, chatInteraction, account, object)
        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: chatInteraction.isLogInteraction, chatInteraction: chatInteraction)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            parameters.makeLabelsForWidth(width)
            return NSMakeSize(parameters.nameLayout.layoutSize.width + 50, 40)
        }
        return NSZeroSize
    }
}
