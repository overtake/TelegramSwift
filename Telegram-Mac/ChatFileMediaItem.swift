//
//  ChatFileMediaItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit

class ChatFileLayoutParameters : ChatMediaLayoutParameters {
    var nameNode:TextNode = TextNode()
    var name:(TextNodeLayout, TextNode)?
    let hasThumb:Bool
    let fileName:String
    init(fileName:String, hasThumb: Bool) {
        self.fileName = fileName
        self.hasThumb = hasThumb
    }
    override func makeLabelsForWidth(_ width: CGFloat) {
        self.name = TextNode.layoutText(maybeNode: nameNode, .initialize(string: fileName , color: theme.colors.text, font: .medium(.text)), nil, 1, .middle, NSMakeSize(width - (hasThumb ? 80 : 50), 20), nil,false, .left)

    }
}

class ChatFileMediaItem: ChatMediaItem {

    
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        super.init(initialSize, chatInteraction, account, object)
        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: false, chatInteraction: chatInteraction)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        let parameters = self.parameters as! ChatFileLayoutParameters
        
        parameters.makeLabelsForWidth(width)
        
        return NSMakeSize(width, parameters.hasThumb ? 70 : 40)
    }
    
    
    
    override func contentNode() -> ChatMediaContentView.Type {
        return ChatFileContentView.self
    }
    
}
