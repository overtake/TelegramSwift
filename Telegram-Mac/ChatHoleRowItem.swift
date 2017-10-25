//
//  ChatHoleRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

class ChatHoleRowItem: ChatRowItem {

    

    override var height: CGFloat {
        return 30
    }
    
    override open var animatable:Bool {
        return false
    }
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry:ChatHistoryEntry) {
        super.init(initialSize, chatInteraction, entry)
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatHoleRowView.self
    }
}
