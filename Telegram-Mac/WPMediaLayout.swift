//
//  WPMediaLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac



class WPMediaLayout: WPLayout {

    var mediaSize:NSSize = NSZeroSize
    private(set) var media:TelegramMediaFile
    var parameters:ChatMediaLayoutParameters?
    override init(with content: TelegramMediaWebpageLoadedContent, account: Account, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation) {
        self.media = content.file! 
        super.init(with: content, account: account, chatInteraction: chatInteraction, parent:parent, fontSize: fontSize, presentation: presentation)
        
        self.parameters = ChatMediaLayoutParameters.layout(for: self.media, isWebpage: true, chatInteraction: chatInteraction, presentation: .make(for: parent, account: account, renderType: presentation.renderType))
    }
    
    override func measure(width: CGFloat) {
        super.measure(width: width)
        
        var contentSize = ChatLayoutUtils.contentSize(for: media, with: width - insets.left)
        self.mediaSize = contentSize
        
        textLayout?.measure(width: contentSize.width)
        
        if let textLayout = textLayout {
            contentSize.height += textLayout.layoutSize.height + 6
        }
        
        if let parameters = parameters as? ChatFileLayoutParameters {
            parameters.name = TextNode.layoutText(maybeNode: parameters.nameNode, NSAttributedString.initialize(string: parameters.fileName , color: theme.colors.text, font: .medium(.text)), nil, 1, .middle, NSMakeSize(width - (parameters.hasThumb ? 80 : 50), 20), nil,false, .left)
        }
        
        parameters?.makeLabelsForWidth(contentSize.width - 50)
        
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            contentSize.width = 50 + max(parameters.nameLayout.layoutSize.width, parameters.durationLayout.layoutSize.width)
        }
        
        layout(with: contentSize)
        
    }
    
    public func contentNode() -> ChatMediaContentView.Type {
      return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return WPMediaContentView.self
    }
    
    
    
}
